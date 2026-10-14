"""Our own assistant, served by the host: conversations on top of the orchestrator.

Conversations are kept in memory (lost when the host restarts, and ended when the host switches between
demo and real mode). Each switch moves the conversation epoch on (modes.py); a conversation belongs to the
epoch it started in, and a message to one from another epoch starts a new conversation instead. A message
runs the orchestrator in a worker thread and yields events as they happen:

  reset             {"mode", "epoch"}                       the conversation named in the request was ended by
                                                            a switch of mode; a new one starts (its
                                                            conversation event follows)
  conversation      {"conversation_id"}                     first event of every reply (after a reset)
  progress          {"tool", "label"}                       a tool is running ("Searching mail")
  result            {"tool", "kind", "header", "items"}     a tool's result, shown at once (kind: events, mail,
                                                            contacts, photos, event_created); header by code
  delta             {"text"}                                reply text as it is generated (provisional)
  step              {}                                      the model moved on to tool calls: discard the
                                                            delta text so far; "message" is authoritative
  pending_approval  {"approval": {...}}                     an irreversible call is held for the user
  clarify           {"options": [...], "text"}              a lookup matched several; the user must pick
  message           {"text", "outcome", "by"}               the final reply; by "code" when the shown result
                                                            was the answer (text = its header, nothing new)
  error             {"message"}                             the request failed
  done              {}                                      last event
"""

from __future__ import annotations

import json
import logging
import re
import secrets
import threading
import time
from datetime import date
from pathlib import Path
from typing import Callable, Iterable, Iterator

from ..orchestrator.engine import SYSTEM_PROMPT, Engine, Run, request_prefix
from ..orchestrator.ollama import ChatModel, OllamaChat
from ..tools import Approval, Registry, Tool
from .config import Settings, private_dir
from .logs import log, open_private

logger = logging.getLogger("mydata.assistant")

# Conversation ids the host makes carry their epoch ("e3.<random>"), so one from before a restart is still
# known to be from an older epoch.
_EPOCH_ID = re.compile(r"^e(\d+)\.")


class Assistant:
    def __init__(self, settings: Settings, registry: Registry,
                 model_factory: Callable[[], ChatModel] | None = None, today: Callable[[], date] = date.today,
                 system_prompt: str = SYSTEM_PROMPT):
        self.settings = settings
        self.registry = registry
        # Fixed within a mode (demo or real; see modes.py), so the cached prompt prefix stays identical.
        self.system_prompt = system_prompt
        # keep_alive -1: while the assistant is on, the model stays loaded (switching it off unloads it).
        self._model_factory = model_factory or (lambda: OllamaChat(
            settings.model, host=settings.ollama_url, think=settings.think, options={"num_ctx": settings.num_ctx},
            keep_alive=-1))
        self._today = today
        self.today = today
        self._conversations: dict[str, list[dict]] = {}
        # The epoch each conversation id seen since the host started belongs to (ended ones included).
        self._epoch_of: dict[str, int] = {}
        self._lock = threading.Lock()
        # One model on one machine: answer one message at a time.
        self._busy = threading.Lock()

    @property
    def conversation_epoch(self) -> int:
        """Moved on by every switch between demo and real mode (modes.py); reported in GET /status. Kept by
        the registry, so that moving it on fails every pending approval (tools/registry.py)."""
        return self.registry.conversation_epoch

    @conversation_epoch.setter
    def conversation_epoch(self, epoch: int) -> None:
        self.registry.set_epoch(epoch)

    def warm(self) -> None:
        """Load the model and cache the shared prompt prefix (see engine.request_prefix)."""
        model = self._model_factory()
        model.warm(*self.prefix())

    def prefix(self) -> tuple[dict, list[dict]]:
        """The system message and tool definitions every request in the current mode starts with."""
        return request_prefix(self.registry, system_prompt=self.system_prompt, followup=self.settings.followup)

    def apply_mode(self, mode: str, tools: Iterable[Tool], today: Callable[[], date], system_prompt: str,
                   epoch: int | None = None) -> None:
        """Switch to another mode's tools, date and system prompt (modes.py). Waits for a message being
        answered to finish, so no request sees half of each.

        It also fails every pending approval, nothing run (tools/registry.py): a call held over one mode's
        data and tools never runs in the other.

        A change of mode ends every conversation: their history holds the other mode's tool results. After
        real -> demo (the last account removed) that is the removed account's contacts and events, which
        must go with it; after demo -> real it is fake demo data that the model would take as real. A
        message to an old conversation id starts a new conversation, after a `reset` event.

        `epoch` is the conversation epoch from now on (the controller keeps it in state.json); without one, a
        change of mode moves it on by one."""
        with self._busy:
            if epoch is None:
                epoch = self.conversation_epoch + (1 if mode != self.registry.mode else 0)
            ending = mode != self.registry.mode or epoch != self.conversation_epoch
            self.registry.replace_tools(tools, today=today, mode=mode, epoch=epoch)
            if ending:
                self._end_conversations(epoch, mode)
            self._today = today
            self.today = today
            self.system_prompt = system_prompt

    def end_conversations(self, epoch: int) -> None:
        """End every conversation and move to `epoch`, keeping the mode (the mode changed while the host was
        stopped, so state.json already had the next epoch). A new epoch fails every pending approval."""
        with self._busy:
            self._end_conversations(epoch, self.registry.mode)

    def _end_conversations(self, epoch: int, mode: str) -> None:
        with self._lock:
            dropped = len(self._conversations)
            self._conversations.clear()
            self.conversation_epoch = epoch
        log(logger, logging.INFO, "conversations ended by a mode switch", count=dropped, mode=mode, epoch=epoch)

    # ---------------------------------------------------------------- conversations

    def history(self, conversation_id: str) -> list[dict]:
        with self._lock:
            return list(self._conversations.get(conversation_id, []))

    def _new_id(self) -> str:
        """A new conversation id in the current epoch. Call with self._lock held."""
        cid = f"e{self.conversation_epoch}.{secrets.token_urlsafe(12)}"
        self._epoch_of[cid] = self.conversation_epoch
        return cid

    def _current(self, conversation_id: str | None) -> tuple[str, dict | None]:
        """The conversation a message goes to: the one named, or a new one when none is named or the named
        one is from another epoch. In the second case, also the `reset` event that says so."""
        with self._lock:
            epoch = self.conversation_epoch
            if conversation_id is None:
                return self._new_id(), None
            began = self._epoch_of.get(conversation_id)
            if began is None:
                stamp = _EPOCH_ID.match(conversation_id)
                # An id the host has not seen, without a stamp (made by a client), joins the current epoch.
                began = self._epoch_of[conversation_id] = int(stamp.group(1)) if stamp else epoch
            if began == epoch:
                return conversation_id, None
            return self._new_id(), {"type": "reset", "mode": self.registry.mode, "epoch": epoch}

    def _live(self, conversation_id: str) -> bool:
        """Whether the conversation belongs to the current epoch."""
        with self._lock:
            return self._epoch_of.get(conversation_id, self.conversation_epoch) == self.conversation_epoch

    def _append(self, conversation_id: str, messages: list[dict]) -> None:
        with self._lock:
            self._conversations.setdefault(conversation_id, []).extend(messages)

    # ---------------------------------------------------------------- one message

    def reply(self, text: str, conversation_id: str | None = None) -> Iterator[dict]:
        """Run one user message; yields events (see module docstring). Blocking: run in a thread."""
        cid, reset = self._current(conversation_id)
        if reset is not None:
            yield reset
        yield {"type": "conversation", "conversation_id": cid}
        events: list[dict] = []
        cond = threading.Condition()
        finished: dict = {}

        def emit(e: dict) -> None:
            if e["type"] == "tool_call":
                e = {"type": "progress", "tool": e["tool"], "label": e["label"]}
            elif e["type"] in ("tool_result", "clarify", "pending_approval"):
                return  # tool_result is internal; the other two are sent at the end, with their text
            with cond:
                events.append(e)
                cond.notify()

        def work() -> None:
            nonlocal cid
            try:
                # Read the history, run, and save the turn under one lock, so a second message to the same
                # conversation always sees this one.
                with self._busy:
                    if not self._live(cid):  # a switch of mode ended it while this message waited its turn
                        cid, reset = self._current(cid)
                        for e in (reset, {"type": "conversation", "conversation_id": cid}):
                            if e is not None:
                                with cond:
                                    events.append(e)
                                    cond.notify()
                    history = self.history(cid)
                    engine = Engine(self._model_factory(), self._today(), registry=self.registry,
                                    system_prompt=self.system_prompt, caller="assistant",
                                    followup=self.settings.followup)
                    run = engine.run(text, history=history, on_event=emit, context={"conversation_id": cid})
                    final = self._settle(cid, len(history), run)
                    self._log(cid, run)
                result = ("final", final)
            except Exception as e:  # never leave the stream waiting
                logger.exception("assistant request failed")
                result = ("final", [{"type": "error", "message": f"{type(e).__name__}: {e}"}, {"type": "done"}])
            with cond:
                finished[result[0]] = result[1]
                cond.notify()

        threading.Thread(target=work, name=f"assistant-{cid}", daemon=True).start()
        while True:
            with cond:
                while not events and not finished:
                    cond.wait()
                batch, events[:] = list(events), []
                done = bool(finished)
            yield from batch
            if done:
                break
        yield from finished["final"]

    def _settle(self, cid: str, history_len: int, run: Run) -> list[dict]:
        """Save this turn to the conversation and return the closing events."""
        new = run.messages[1 + history_len:]  # the user's message and everything after it
        out: list[dict] = []
        if run.outcome == "pending_approval":
            p = run.pending
            approval = self.registry.approval(p["approval_id"])
            reply = "I've prepared that. It is waiting for your approval."
            new += [{"role": "tool", "tool_name": p["tool"],
                     "content": json.dumps({"status": "pending_approval", "approval_id": p["approval_id"]})},
                    {"role": "assistant", "content": reply}]
            out += [{"type": "pending_approval", "approval": approval.to_json() if approval else None},
                    {"type": "message", "text": reply, "outcome": run.outcome}]
        elif run.outcome == "clarify":
            names = [o.get("name", "?") for o in run.clarify_options or []]
            question = "I found more than one match: " + ", ".join(names) + ". Which one do you mean?"
            amb = next((c for c in run.calls if c.status == "ambiguous"), None)
            new += [{"role": "tool", "tool_name": amb.tool if amb else "find_contact",
                     "content": json.dumps({"matches": run.clarify_options})},
                    {"role": "assistant", "content": question}]
            out += [{"type": "clarify", "options": run.clarify_options, "text": question},
                    {"type": "message", "text": question, "outcome": run.outcome}]
        elif run.outcome == "model_error":
            new = []  # a failed turn leaves nothing in the conversation
            out.append({"type": "error", "message": f"The model could not answer: {run.error}"})
        elif run.outcome == "step_limit":
            reply = "I couldn't finish that in a few steps. Could you break it into smaller requests?"
            new += [{"role": "assistant", "content": reply}]
            out.append({"type": "message", "text": reply, "outcome": run.outcome})
        else:
            out.append({"type": "message", "text": run.final_text, "outcome": run.outcome, "by": run.reply_by})
        self._append(cid, new)
        return out + [{"type": "done"}]

    # ---------------------------------------------------------------- approvals

    def note_decision(self, approval: Approval) -> None:
        """Tell the conversation that held a call what the user decided."""
        cid = approval.context.get("conversation_id")
        if not cid or not self._live(cid):  # a conversation ended by a switch of mode stays ended
            return
        if approval.status == "approved":
            text = f"(The user approved: {approval.summary}. Done.)"
        elif approval.status == "rejected":
            text = f"(The user rejected: {approval.summary}. Nothing was done.)"
        else:
            text = f"(Approved, but it failed: {approval.error})"
        self._append(cid, [{"role": "assistant", "content": text}])

    # ---------------------------------------------------------------- log

    def _log(self, cid: str, run: Run) -> None:
        """Every request, with the tools called and the outcome: future test data.

        Each entry says its mode. In real mode the tool results (the user's mirrored contacts and events)
        are left out, and so are the argument values, which the model can copy from them: each call keeps
        its tool and status, the shape of each argument (its name, type and length) and only the size of its
        result, and a reply written by code (the results' headers) is left out too. The request text and a
        reply the model wrote are kept. Demo mode logs everything (its data is invented)."""
        mode = self.registry.mode
        entry = {"ts": time.time(), "conversation_id": cid, "mode": mode, **run.to_json()}
        entry.pop("messages", None)
        if mode != "demo":
            entry = redact_real(entry)
        path: Path = private_dir(self.settings.log_dir) / "assistant.jsonl"
        with open_private(path) as fh:
            fh.write(json.dumps(entry, ensure_ascii=False, default=str) + "\n")
        log(logger, logging.INFO, "assistant request", conversation_id=cid, outcome=run.outcome,
            tools=[f"{c.tool}:{c.status}" for c in run.calls], seconds=run.seconds_total)


def _result_size(result) -> dict | None:
    """What a tool result is, without its contents: the length of each list, and the date span."""
    if not isinstance(result, dict):
        return None
    out: dict = {k: len(v) for k, v in result.items() if isinstance(v, list)}
    for key in ("from", "to", "count", "truncated", "status", "outside_window"):
        if key in result and not isinstance(result[key], (list, dict)):
            out[key] = result[key]
    return out


_JSON_TYPE = {str: "string", bool: "boolean", int: "integer", float: "number", list: "array", dict: "object",
              type(None): "null"}


def value_shape(value) -> dict:
    """What a value is, without the value: its JSON type, and the length of a string, list or object."""
    out: dict = {"type": _JSON_TYPE.get(type(value), "other")}
    if isinstance(value, (str, list, dict)):
        out["length"] = len(value)
    return out


def arg_shapes(args) -> dict:
    """Each argument's name with its shape (value_shape), never its value."""
    if not isinstance(args, dict):
        return {"_args": value_shape(args)}
    return {str(k): value_shape(v) for k, v in args.items()}


def _text_shape(text: str | None) -> dict | None:
    return None if text is None else value_shape(text)


def _redact_call(c: dict) -> dict:
    """A call record with no values: argument shapes, the names of resolved and dropped arguments, the size
    of the result, and the length of an error (a grounding error quotes the value it rejected)."""
    return {**c, "args": arg_shapes(c.get("args")), "result": _result_size(c.get("result")),
            "resolved": sorted(c.get("resolved") or {}), "dropped_args": sorted(c.get("dropped_args") or {}),
            "error": _text_shape(c.get("error"))}


def redact_real(entry: dict) -> dict:
    """A request-log entry without the user's data (for real mode): no tool results and no argument values."""
    entry = dict(entry)
    entry["calls"] = [_redact_call(c) for c in entry.get("calls", [])]
    if entry.get("pending"):
        p = entry["pending"]
        entry["pending"] = {"tool": p.get("tool"), "approval_id": p.get("approval_id"),
                            "args": arg_shapes(p.get("args")), "summary": _text_shape(p.get("summary"))}
    entry["undo_log"] = len(entry.get("undo_log") or [])
    entry["model_replies"] = [{**m, "thinking": _text_shape(m.get("thinking"))} if isinstance(m, dict) else m
                              for m in entry.get("model_replies") or []]
    entry["results"] = [{"tool": r.get("tool"), "kind": r.get("kind"), "items": len(r.get("items") or [])}
                        for r in entry.get("results", [])]
    if entry.get("clarify_options") is not None:
        entry["clarify_options"] = len(entry["clarify_options"])
    if entry.get("reply_by") == "code":  # the reply is the results' headers ("Ava Fictional"): data too
        entry["final_text"] = None
    return entry
