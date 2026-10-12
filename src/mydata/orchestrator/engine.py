"""The orchestrator loop.

The model picks tools and fills in plain arguments. Everything else happens
here, in code: validating arguments, resolving date phrases, the permission
gate, stopping to ask when a lookup is ambiguous, and logging.
"""

from __future__ import annotations

import json
import time as _time
from dataclasses import asdict, dataclass, field
from datetime import date
from typing import Any, Literal

from .dates import DateParseError, Resolved, parse_time, resolve
from .ollama import ChatModel
from .tools import TOOLS, Tool

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
    tools: dict[str, Tool] = field(default_factory=lambda: dict(TOOLS))
    system_prompt: str = SYSTEM_PROMPT
    max_steps: int = 6
    # Show the model only the tools routing.select_tools picks for the request (fix b).
    route: bool = True
    # Check every argument against the request and earlier results (grounding.py, fix c).
    ground: bool = True

    def run(self, request: str, tool_names: list[str] | None = None) -> Run:
        if tool_names is None and self.route:
            from .routing import select_tools
            tool_names = select_tools(request)
        tools = {n: self.tools[n] for n in (tool_names or self.tools)}
        definitions = [t.definition() for t in tools.values()]
        messages: list[dict] = [
            {"role": "system", "content": self.system_prompt},
            {"role": "user", "content": request},
        ]
        run = Run(model=self.model.name, request=request, today=self.today.isoformat(), messages=messages,
                  tools_shown=list(tools))
        started = _time.perf_counter()
        try:
            self._loop(run, messages, tools, definitions, started)
        except Exception as e:  # a model or transport failure is a result, not a crash
            run.outcome = "model_error"
            run.error = f"{type(e).__name__}: {e}"
        run.seconds_total = round(_time.perf_counter() - started, 3)
        return run

    def _loop(self, run: Run, messages: list[dict], tools: dict[str, Tool], definitions: list[dict], started: float) -> None:
        for step in range(self.max_steps):
            reply = self.model.chat(messages, definitions)
            run.model_calls += 1
            run.model_replies.append({"stats": reply.get("stats"), "thinking": reply.get("thinking") or ""})
            calls = reply.get("tool_calls") or []
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
                record, result = self._execute(step, fn.get("name", ""), fn.get("arguments"), tools, run)
                run.calls.append(record)
                if record.status in ("gated", "ambiguous"):
                    # Stop here, but record what else the model asked for in the same reply.
                    for rest in calls[i + 1:]:
                        rfn = rest.get("function") or {}
                        run.calls.append(self._validate(step, rfn.get("name", ""), rfn.get("arguments"), tools, run)[0])
                    if record.status == "gated":
                        run.outcome = "pending_approval"
                        run.pending = {"tool": record.tool, "args": record.args}
                    else:
                        run.outcome = "clarify"
                        run.clarify_options = result
                    return
                messages.append({"role": "tool", "tool_name": record.tool, "content": json.dumps(record.result)})
        run.outcome = "step_limit"

    def _execute(self, step: int, name: str, raw_args: Any, tools: dict[str, Tool], run: Run) -> tuple[CallRecord, Any]:
        rec, resolved = self._validate(step, name, raw_args, tools, run)
        if rec.status != "not_run":
            return rec, None
        rec.status = "ok"
        tool = tools[name]

        # Permission gate: irreversible tools never run without the user's approval.
        if tool.permission == "irreversible":
            rec.status = "gated"
            return rec, None

        try:
            result = tool.handler(rec.args, resolved, self.today)
        except Exception as e:
            rec.status = "error"
            rec.error = f"{type(e).__name__}: {e}"
            rec.result = {"error": "the tool failed"}
            return rec, None
        rec.result = result.data
        if result.undo:
            run.undo_log.append(result.undo)
        if result.ambiguous:
            rec.status = "ambiguous"
            return rec, result.ambiguous
        return rec, None

    def _validate(self, step: int, name: str, raw_args: Any, tools: dict[str, Tool], run: Run
                  ) -> tuple[CallRecord, dict[str, Resolved]]:
        """Check a call without running it. A valid call comes back with status "not_run"."""
        args = _parse_args(raw_args)
        tool = tools.get(name)
        if tool is None:
            rec = CallRecord(step, name, args, "unknown_tool", error=f"there is no tool called '{name}'")
            rec.result = {"error": rec.error}
            return rec, {}

        props = tool.parameters["properties"]
        invented = [k for k in args if k not in props]
        args = {k: v for k, v in args.items() if v not in (None, "")}
        missing = [k for k in tool.parameters.get("required", []) if k not in args]
        if invented or missing:
            parts = []
            if invented:
                parts.append(f"unknown argument(s): {', '.join(invented)}")
            if missing:
                parts.append(f"missing required argument(s): {', '.join(missing)}")
            rec = CallRecord(step, name, args, "invalid_args", error="; ".join(parts), invented_args=invented)
            rec.result = {"error": rec.error}
            return rec, {}

        dropped: dict[str, str] = {}
        if self.ground:
            from . import grounding

            # Values must come from the request or an earlier result. Unfounded optional arguments
            # are removed; an unfounded required one fails the call and the model is told why.
            sources = grounding.Sources(run.request, [c.result for c in run.calls if c.status == "ok"])
            args, dropped, failing = grounding.check(name, args, tool.parameters.get("required", []),
                                                     set(tool.date_params), sources)
            if failing:
                msg = "; ".join(f"{k}: {v}" for k, v in failing.items())
                rec = CallRecord(step, name, args, "invalid_args", error=f"ungrounded {msg}", dropped_args=dropped)
                rec.result = {"error": f"{msg}. Use only what the user said or a tool returned."}
                return rec, {}

        resolved: dict[str, Resolved] = {}
        try:
            for p, bias in tool.date_params.items():
                if p in args:
                    resolved[p] = resolve(str(args[p]), self.today, bias)
            for p in tool.time_params:
                if p in args:
                    parse_time(str(args[p]))
        except DateParseError as e:
            rec = CallRecord(step, name, args, "bad_date", error=str(e))
            rec.result = {"error": f"{e}. Pass the date as the user said it."}
            return rec, {}

        return CallRecord(step, name, args, "not_run", resolved={k: v.to_json() for k, v in resolved.items()},
                          dropped_args=dropped), resolved


def _parse_args(raw: Any) -> dict:
    if isinstance(raw, dict):
        return dict(raw)
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {"_raw": raw}
        except json.JSONDecodeError:
            return {"_raw": raw}
    return {}
