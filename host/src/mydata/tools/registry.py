"""The tool layer: one registry of tools, and the permission gate.

Every agent (our orchestrator, an MCP client, anything else) reaches tools only through
Registry.invoke. Each tool declares a name, description, argument schema and permission:

- read: runs.
- reversible: runs, and its undo is recorded.
- irreversible: never runs from invoke. invoke stores the exact call under an approval id and
  returns "pending_approval". Only Registry.decide(approval_id, approve=True), which the host calls
  when the user approves, runs it, and it runs exactly the stored arguments, once.

Validation (unknown tool, unknown or missing arguments) and date resolution also live here, so
every agent gets the same checks and the same dates.
"""

from __future__ import annotations

import copy
import hashlib
import json
import logging
import secrets
import threading
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timezone
from typing import Any, Callable, Iterable, Literal

from .dates import Bias, DateParseError, Resolved, parse_time, resolve

logger = logging.getLogger("mydata.tools")

Permission = Literal["read", "reversible", "irreversible"]

# JSON schema "type" -> Python types. bool is not a number here, as in JSON.
_JSON_TYPES = {"string": (str,), "integer": (int,), "number": (int, float), "boolean": (bool,), "array": (list,),
               "object": (dict,)}
Status = Literal["ok", "unknown_tool", "invalid_args", "bad_date", "pending_approval", "ambiguous", "error"]


@dataclass
class ToolResult:
    data: Any
    # Several equally good matches: the caller should stop and ask the user to pick.
    ambiguous: list[dict] | None = None
    # Reversible writes return how to undo them.
    undo: dict | None = None


@dataclass(frozen=True)
class Tool:
    name: str
    description: str
    parameters: dict
    permission: Permission
    handler: Callable[[dict, dict[str, Resolved], date], ToolResult] = field(repr=False, compare=False)
    # Parameters holding date phrases, and which way a bare phrase leans.
    date_params: dict[str, Bias] = field(default_factory=dict)
    time_params: tuple[str, ...] = ()

    def definition(self) -> dict:
        """The function definition shown to a model (Ollama / OpenAI tool format)."""
        return {
            "type": "function",
            "function": {"name": self.name, "description": self.description, "parameters": self.parameters},
        }

    def describe(self) -> dict:
        return {"name": self.name, "description": self.description, "input_schema": self.parameters,
                "permission": self.permission}


@dataclass
class Approval:
    id: str
    tool: str
    args: dict
    digest: str
    caller: str
    created_at: str
    summary: str
    context: dict = field(default_factory=dict)
    status: Literal["pending", "approved", "rejected", "failed"] = "pending"
    decided_at: str | None = None
    decided_by: str | None = None
    result: Any = None
    error: str | None = None

    def to_json(self) -> dict:
        return asdict(self)


@dataclass
class Invocation:
    status: Status
    tool: str
    args: dict
    result: Any = None
    error: str | None = None
    invented_args: list[str] = field(default_factory=list)
    resolved: dict[str, dict] = field(default_factory=dict)
    approval: Approval | None = None
    options: list[dict] | None = None  # for "ambiguous"
    undo: dict | None = None

    def to_json(self) -> dict:
        out = asdict(self)
        out["approval"] = self.approval.to_json() if self.approval else None
        return out


class ApprovalError(Exception):
    """An approval id that does not exist or was already decided."""


def call_digest(tool: str, args: dict) -> str:
    return hashlib.sha256(json.dumps([tool, args], sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class Registry:
    def __init__(self, tools: Iterable[Tool], today: Callable[[], date] = date.today):
        self._tools: dict[str, Tool] = {}
        for t in tools:
            if t.name in self._tools:
                raise ValueError(f"duplicate tool {t.name!r}")
            self._tools[t.name] = t
        self._today = today
        self._lock = threading.Lock()
        self._approvals: dict[str, Approval] = {}
        # Pending calls keep their resolved dates, so approving later runs the dates the user saw.
        self._approval_dates: dict[str, dict[str, Resolved]] = {}
        self.undo_log: list[dict] = []

    # ---------------------------------------------------------------- catalogue

    def names(self) -> list[str]:
        return list(self._tools)

    def get(self, name: str) -> Tool | None:
        return self._tools.get(name)

    def __contains__(self, name: str) -> bool:
        return name in self._tools

    def definitions(self, names: Iterable[str] | None = None) -> list[dict]:
        return [self._tools[n].definition() for n in (self._tools if names is None else names)]

    def describe(self) -> list[dict]:
        return [t.describe() for t in self._tools.values()]

    # ---------------------------------------------------------------- calls

    def validate(self, name: str, raw_args: Any, today: date | None = None, *, dates: bool = True
                 ) -> tuple[Invocation, dict[str, Resolved]]:
        """Check a call without running it. A valid call comes back with status "ok" and no result.
        With dates=False only the shape is checked (tool exists, no unknown or missing arguments)."""
        today = today or self._today()
        args = parse_args(raw_args)
        tool = self._tools.get(name)
        if tool is None:
            err = f"there is no tool called '{name}'"
            return Invocation("unknown_tool", name, args, result={"error": err}, error=err), {}

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
            err = "; ".join(parts)
            return Invocation("invalid_args", name, args, result={"error": err}, error=err,
                              invented_args=invented), {}

        wrong = []
        for k, v in args.items():
            want = props[k].get("type")
            ok = isinstance(v, _JSON_TYPES.get(want, (object,))) and not (want in ("integer", "number")
                                                                            and isinstance(v, bool))
            if not ok:
                wrong.append(f"argument '{k}' must be a {want}")
        if wrong:
            err = "; ".join(wrong)
            return Invocation("invalid_args", name, args, result={"error": err}, error=err), {}

        resolved: dict[str, Resolved] = {}
        if not dates:
            return Invocation("ok", name, args), resolved
        try:
            for p, bias in tool.date_params.items():
                if p in args:
                    resolved[p] = resolve(str(args[p]), today, bias)
            for p in tool.time_params:
                if p in args:
                    parse_time(str(args[p]))
        except DateParseError as e:
            return Invocation("bad_date", name, args, result={"error": f"{e}. Pass the date as the user said it."},
                              error=str(e)), {}
        return Invocation("ok", name, args, resolved={k: v.to_json() for k, v in resolved.items()}), resolved

    def invoke(self, name: str, raw_args: Any, *, caller: str, today: date | None = None,
               context: dict | None = None) -> Invocation:
        """Validate and run a call. Irreversible tools are held for approval instead of run."""
        today = today or self._today()
        inv, resolved = self.validate(name, raw_args, today)
        if inv.status == "ok":
            tool = self._tools[name]
            if tool.permission == "irreversible":
                inv.status = "pending_approval"
                inv.approval = self._hold(tool, inv.args, resolved, caller, context or {})
            else:
                inv = self._run(tool, inv, resolved, today)
        # Audit: which tool, by whom, how it ended. Argument values stay out of the log.
        logger.info("tool call", extra={"fields": {
            "tool": name, "caller": caller, "status": inv.status, "error": inv.error,
            "approval_id": inv.approval.id if inv.approval else None}})
        return inv

    def _run(self, tool: Tool, inv: Invocation, resolved: dict[str, Resolved], today: date) -> Invocation:
        try:
            result = tool.handler(inv.args, resolved, today)
        except Exception as e:
            inv.status = "error"
            inv.error = f"{type(e).__name__}: {e}"
            inv.result = {"error": "the tool failed"}
            return inv
        inv.result = result.data
        if result.undo:
            inv.undo = result.undo
            with self._lock:
                self.undo_log.append({"tool": tool.name, "undo": result.undo, "at": _now()})
        if result.ambiguous:
            inv.status = "ambiguous"
            inv.options = result.ambiguous
        return inv

    # ---------------------------------------------------------------- the gate

    def _hold(self, tool: Tool, args: dict, resolved: dict[str, Resolved], caller: str, context: dict) -> Approval:
        frozen = copy.deepcopy(args)
        approval = Approval(
            id=secrets.token_urlsafe(16), tool=tool.name, args=frozen, digest=call_digest(tool.name, frozen),
            caller=caller, created_at=_now(), summary=summarize(tool.name, frozen), context=dict(context),
        )
        with self._lock:
            self._approvals[approval.id] = approval
            self._approval_dates[approval.id] = dict(resolved)
        return copy.deepcopy(approval)

    def approval(self, approval_id: str) -> Approval | None:
        with self._lock:
            a = self._approvals.get(approval_id)
            return copy.deepcopy(a) if a else None

    def approvals(self, status: str | None = None) -> list[Approval]:
        with self._lock:
            return [copy.deepcopy(a) for a in self._approvals.values() if status is None or a.status == status]

    def decide(self, approval_id: str, approve: bool, *, decided_by: str) -> Approval:
        """The only way an irreversible tool runs: the user approved this exact stored call."""
        with self._lock:
            a = self._approvals.get(approval_id)
            if a is None:
                raise ApprovalError("no such approval")
            if a.status != "pending":
                raise ApprovalError(f"approval already {a.status}")
            # Claim it inside the lock so two concurrent approvals cannot both run the call.
            a.status = "approved" if approve else "rejected"
            a.decided_at = _now()
            a.decided_by = decided_by
            resolved = self._approval_dates.pop(approval_id, {})
        if not approve:
            self._audit(a)
            return copy.deepcopy(a)

        tool = self._tools[a.tool]
        if call_digest(a.tool, a.args) != a.digest:  # defensive: stored arguments must be untouched
            a.status, a.error = "failed", "stored call changed after it was held"
            return copy.deepcopy(a)
        inv = Invocation("ok", a.tool, copy.deepcopy(a.args))
        inv = self._run(tool, inv, resolved, self._today())
        with self._lock:
            if inv.status == "error":
                a.status, a.error = "failed", inv.error
            a.result = inv.result
        self._audit(a)
        return copy.deepcopy(a)

    def _audit(self, a: Approval) -> None:
        """The record of what ran: the held call is identified by id and digest, not its contents."""
        logger.info("approval decided", extra={"fields": {
            "approval_id": a.id, "tool": a.tool, "caller": a.caller, "decided_by": a.decided_by,
            "status": a.status, "digest": a.digest, "error": a.error,
            "conversation_id": a.context.get("conversation_id")}})


def summarize(tool: str, args: dict) -> str:
    """One line for the approval card: exactly what will happen."""
    if tool == "send_mail":
        return f"Send email to {args.get('to')}: {args.get('subject', '')!r}"
    pairs = ", ".join(f"{k}={v!r}" for k, v in args.items())
    return f"{tool}({pairs})"


def parse_args(raw: Any) -> dict:
    if isinstance(raw, dict):
        return dict(raw)
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {"_raw": raw}
        except json.JSONDecodeError:
            return {"_raw": raw}
    return {}
