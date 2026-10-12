"""Our own assistant, served by the host: conversations on top of the orchestrator.

Conversations are kept in memory (phase 1: lost when the host restarts). A message runs the
orchestrator in a worker thread and yields events as they happen:

  conversation      {"conversation_id"}                     first event of every reply
  progress          {"tool", "label"}                       a tool is running ("Searching mail")
  delta             {"text"}                                reply text as it is generated (provisional)
  step              {}                                      the model moved on to tool calls: discard the
                                                            delta text so far; "message" is authoritative
  pending_approval  {"approval": {...}}                     an irreversible call is held for the user
  clarify           {"options": [...], "text"}              a lookup matched several; the user must pick
  message           {"text", "outcome"}                     the final reply
  error             {"message"}                             the request failed
  done              {}                                      last event
"""

from __future__ import annotations

import json
import logging
import secrets
import threading
import time
from datetime import date
from pathlib import Path
from typing import Callable, Iterator

from ..orchestrator.engine import Engine, Run, request_prefix
from ..orchestrator.ollama import ChatModel, OllamaChat
from ..tools import Approval, Registry
from .config import Settings
from .logs import log

logger = logging.getLogger("mydata.assistant")


class Assistant:
    def __init__(self, settings: Settings, registry: Registry,
                 model_factory: Callable[[], ChatModel] | None = None, today: Callable[[], date] = date.today):
        self.settings = settings
        self.registry = registry
        # keep_alive -1: while the assistant is on, the model stays loaded (switching it off unloads it).
        self._model_factory = model_factory or (lambda: OllamaChat(
            settings.model, host=settings.ollama_url, think=settings.think, options={"num_ctx": settings.num_ctx},
            keep_alive=-1))
        self._today = today
        self.today = today
        self._conversations: dict[str, list[dict]] = {}
        self._lock = threading.Lock()
        # One model on one machine: answer one message at a time.
        self._busy = threading.Lock()

    def warm(self) -> None:
        """Load the model and cache the shared prompt prefix (see engine.request_prefix)."""
        model = self._model_factory()
        model.warm(*request_prefix(self.registry))

    # ---------------------------------------------------------------- conversations

    def history(self, conversation_id: str) -> list[dict]:
        with self._lock:
            return list(self._conversations.get(conversation_id, []))

    def _append(self, conversation_id: str, messages: list[dict]) -> None:
        with self._lock:
            self._conversations.setdefault(conversation_id, []).extend(messages)

    # ---------------------------------------------------------------- one message

    def reply(self, text: str, conversation_id: str | None = None) -> Iterator[dict]:
        """Run one user message; yields events (see module docstring). Blocking: run in a thread."""
        cid = conversation_id or secrets.token_urlsafe(12)
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
            try:
                # Read the history, run, and save the turn under one lock, so a second message to the same
                # conversation always sees this one.
                with self._busy:
                    history = self.history(cid)
                    engine = Engine(self._model_factory(), self._today(), registry=self.registry,
                                    caller="assistant")
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
            out.append({"type": "message", "text": run.final_text, "outcome": run.outcome})
        self._append(cid, new)
        return out + [{"type": "done"}]

    # ---------------------------------------------------------------- approvals

    def note_decision(self, approval: Approval) -> None:
        """Tell the conversation that held a call what the user decided."""
        cid = approval.context.get("conversation_id")
        if not cid:
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
        """Every request, with the tools called and the outcome: future test data."""
        entry = {"ts": time.time(), "conversation_id": cid, **run.to_json()}
        entry.pop("messages", None)
        path: Path = self.settings.log_dir / "assistant.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False, default=str) + "\n")
        log(logger, logging.INFO, "assistant request", conversation_id=cid, outcome=run.outcome,
            tools=[f"{c.tool}:{c.status}" for c in run.calls], seconds=run.seconds_total)
