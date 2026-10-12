"""The orchestrator loop: one agent on top of the tool layer.

The model picks tools and fills in plain arguments. Validation, date resolution and the
permission gate belong to the tool layer (mydata.tools.Registry), which every agent goes
through. This loop adds what is specific to our own assistant: the grounding check, stopping
to ask when a lookup is ambiguous, conversation history, progress events, and logging.
"""

from __future__ import annotations

import json
import time as _time
from dataclasses import asdict, dataclass, field
from datetime import date
from typing import Any, Callable, Literal

from ..tools import Registry, default_registry
from .ollama import ChatModel

SYSTEM_PROMPT = """You are myAssistant, a personal assistant that runs on the user's own computer. \
You can search and send the user's mail, look up contacts, read and add calendar events, and search photos, \
using the tools provided.

Rules:
- Pass dates and times exactly as the user said them, for example "next friday", "last December", \
"tomorrow at 3pm". Never work out calendar dates yourself.
- Only fill in tool arguments the user's request gives you. Leave the rest out.
- Email addresses come from find_contact. Never guess one.
- If the request needs no tool, answer directly.
- If none of the tools can do what the user asks, say so plainly and do not call any tool.
"""

# not_run: a valid call in the same reply as a gated or ambiguous call; recorded, never executed.
Status = Literal["ok", "unknown_tool", "invalid_args", "bad_date", "gated", "ambiguous", "error", "not_run"]
Outcome = Literal["answered", "pending_approval", "clarify", "step_limit", "model_error"]

# What the user sees while a tool runs.
PROGRESS = {
    "search_mail": "Searching mail",
    "send_mail": "Preparing email",
    "search_photos": "Searching photos",
    "find_contact": "Looking up contact",
    "list_events": "Checking calendar",
    "create_event": "Adding to calendar",
}

EventSink = Callable[[dict], None]


def request_prefix(registry: Registry, names: list[str] | None = None, system_prompt: str = SYSTEM_PROMPT
                   ) -> tuple[dict, list[dict]]:
    """The start of every request: the system message and the tool definitions. Ollama caches the prompt it
    renders from these, so they must be byte-identical across requests (and the warm-up request); everything
    request-specific (history, the user's message) comes after them."""
    return {"role": "system", "content": system_prompt}, registry.definitions(names)


@dataclass
class CallRecord:
    step: int
    tool: str
    args: dict
    status: Status
    error: str | None = None
    invented_args: list[str] = field(default_factory=list)
    # Optional arguments the grounding check removed, with the reason.
    dropped_args: dict[str, str] = field(default_factory=dict)
    resolved: dict[str, dict] = field(default_factory=dict)
    result: Any = None
    approval_id: str | None = None


@dataclass
class Run:
    model: str
    request: str
    today: str
    calls: list[CallRecord] = field(default_factory=list)
    tools_shown: list[str] = field(default_factory=list)
    outcome: Outcome = "answered"
    final_text: str = ""
    pending: dict | None = None  # the gated call awaiting approval
    clarify_options: list[dict] | None = None
    undo_log: list[dict] = field(default_factory=list)
    seconds_to_first_tool_call: float | None = None
    seconds_total: float = 0.0
    model_calls: int = 0
    # Per model call: Ollama timing/token stats, so a model reload inside a timed run is visible.
    model_replies: list[dict] = field(default_factory=list)
    messages: list[dict] = field(default_factory=list)
    error: str | None = None

    def to_json(self) -> dict:
        return asdict(self)


@dataclass
class Engine:
    model: ChatModel
    today: date
    registry: Registry = field(default_factory=default_registry)
    system_prompt: str = SYSTEM_PROMPT
    max_steps: int = 6
    # Show the model only the tools routing.select_tools picks for the request (fix b). Off: in round 2
    # it gained nothing, added 0.6 s and hides tools that chains need (results/2026-10-11-b-REPORT.md).
    route: bool = False
    # Check every argument against the request and earlier results (grounding.py, fix c).
    ground: bool = True
    # Who the tool layer records as the caller of each tool.
    caller: str = "assistant"

    def run(self, request: str, tool_names: list[str] | None = None, *, history: list[dict] | None = None,
            on_event: EventSink | None = None, context: dict | None = None) -> Run:
        """Answer one user message. history: earlier messages of the conversation (no system prompt).
        on_event: receives progress events (tool_call, tool_result, pending_approval, clarify, delta).
        context: recorded with any approval this run creates (e.g. the conversation id)."""
        if tool_names is None and self.route:
            from .routing import select_tools
            tool_names = select_tools(request)
        names = list(tool_names or self.registry.names())
        unknown = [n for n in names if n not in self.registry]
        if unknown:
            raise KeyError(f"unknown tools: {unknown}")
        system, definitions = request_prefix(self.registry, names, self.system_prompt)
        messages: list[dict] = [system, *(history or []), {"role": "user", "content": request}]
        run = Run(model=self.model.name, request=request, today=self.today.isoformat(), messages=messages,
                  tools_shown=list(names))
        emit = on_event or (lambda _e: None)
        started = _time.perf_counter()
        try:
            self._loop(run, messages, set(names), definitions, started, emit, on_event is not None, context or {})
        except Exception as e:  # a model or transport failure is a result, not a crash
            run.outcome = "model_error"
            run.error = f"{type(e).__name__}: {e}"
        run.seconds_total = round(_time.perf_counter() - started, 3)
        return run

    def _chat(self, messages: list[dict], definitions: list[dict], emit: EventSink, stream: bool) -> dict:
        if stream and getattr(self.model, "streams", False):
            return self.model.chat(messages, definitions, on_delta=lambda text: emit({"type": "delta", "text": text}))
        return self.model.chat(messages, definitions)

    def _loop(self, run: Run, messages: list[dict], shown: set[str], definitions: list[dict], started: float,
              emit: EventSink, stream: bool, context: dict) -> None:
        for step in range(self.max_steps):
            t0 = _time.perf_counter()
            reply = self._chat(messages, definitions, emit, stream)
            run.model_calls += 1
            run.model_replies.append({"stats": reply.get("stats"), "thinking": reply.get("thinking") or "",
                                      "started": round(t0 - started, 3),
                                      "seconds": round(_time.perf_counter() - t0, 3)})
            calls = reply.get("tool_calls") or []
            if calls and stream:
                emit({"type": "step"})  # any text streamed in this step was not the answer
            msg = {"role": "assistant", "content": reply.get("content", "")}
            if calls:
                msg["tool_calls"] = calls
            if reply.get("thinking"):
                # gpt-oss expects its reasoning back between tool steps of one turn.
                msg["thinking"] = reply["thinking"]
            messages.append(msg)
            if not calls:
                run.outcome = "answered"
                run.final_text = reply.get("content", "")
                return
            if run.seconds_to_first_tool_call is None:
                run.seconds_to_first_tool_call = round(_time.perf_counter() - started, 3)

            for i, raw in enumerate(calls):
                fn = raw.get("function") or {}
                name = fn.get("name", "")
                if name in PROGRESS:
                    emit({"type": "tool_call", "tool": name, "label": PROGRESS[name]})
                record, options = self._execute(step, name, fn.get("arguments"), shown, run, context)
                run.calls.append(record)
                emit({"type": "tool_result", "tool": record.tool, "status": record.status})
                if record.status in ("gated", "ambiguous"):
                    # Stop here, but record what else the model asked for in the same reply.
                    for rest in calls[i + 1:]:
                        rfn = rest.get("function") or {}
                        run.calls.append(self._check(step, rfn.get("name", ""), rfn.get("arguments"), shown, run))
                    if record.status == "gated":
                        approval = self.registry.approval(record.approval_id)
                        run.outcome = "pending_approval"
                        run.pending = {"tool": record.tool, "args": record.args, "approval_id": record.approval_id,
                                       "summary": approval.summary if approval else ""}
                        emit({"type": "pending_approval", "approval": approval.to_json() if approval else None})
                    else:
                        run.outcome = "clarify"
                        run.clarify_options = options
                        emit({"type": "clarify", "options": options})
                    return
                messages.append({"role": "tool", "tool_name": record.tool, "content": json.dumps(record.result)})
        run.outcome = "step_limit"

    def _check(self, step: int, name: str, raw_args: Any, shown: set[str], run: Run) -> CallRecord:
        """Shape check plus grounding, without running anything. A valid call comes back as "not_run"."""
        if name not in shown:
            err = f"there is no tool called '{name}'"
            return CallRecord(step, name, _args(raw_args), "unknown_tool", error=err, result={"error": err})
        inv, _ = self.registry.validate(name, raw_args, self.today, dates=False)
        if inv.status != "ok":
            return CallRecord(step, name, inv.args, inv.status, error=inv.error, invented_args=inv.invented_args,
                              result=inv.result)
        args, dropped = inv.args, {}
        if self.ground:
            from . import grounding

            # Values must come from the request or an earlier result. Unfounded optional arguments
            # are removed; an unfounded required one fails the call and the model is told why.
            tool = self.registry.get(name)
            sources = grounding.Sources(run.request, [c.result for c in run.calls if c.status == "ok"])
            args, dropped, failing = grounding.check(name, args, tool.parameters.get("required", []),
                                                     set(tool.date_params), sources)
            if failing:
                msg = "; ".join(f"{k}: {v}" for k, v in failing.items())
                return CallRecord(step, name, args, "invalid_args", error=f"ungrounded {msg}", dropped_args=dropped,
                                  result={"error": f"{msg}. Use only what the user said or a tool returned."})
        full, _ = self.registry.validate(name, args, self.today)
        if full.status != "ok":
            return CallRecord(step, name, full.args, full.status, error=full.error, result=full.result,
                              dropped_args=dropped)
        return CallRecord(step, name, full.args, "not_run", resolved=full.resolved, dropped_args=dropped)

    def _execute(self, step: int, name: str, raw_args: Any, shown: set[str], run: Run, context: dict
                 ) -> tuple[CallRecord, list[dict] | None]:
        rec = self._check(step, name, raw_args, shown, run)
        if rec.status != "not_run":
            return rec, None
        inv = self.registry.invoke(name, rec.args, caller=self.caller, today=self.today, context=context)
        rec.resolved = inv.resolved or rec.resolved
        if inv.status == "pending_approval":
            rec.status, rec.approval_id = "gated", inv.approval.id
            return rec, None
        rec.status = inv.status
        rec.result, rec.error = inv.result, inv.error
        if inv.undo:
            run.undo_log.append(inv.undo)
        if inv.status == "ambiguous":
            return rec, inv.options
        return rec, None


def _args(raw: Any) -> dict:
    from ..tools.registry import parse_args
    return parse_args(raw)
