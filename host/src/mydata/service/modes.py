"""Demo mode and real mode.

- demo (no source on: no linked account, and This Mac off or absent): exactly the behaviour before accounts existed: the six fake tools over
  canned data, the date pinned by [dev] pin_today, the original system prompt.
- real (any source on: a linked account, or This Mac turned on): the real date and the machine's time zone; only find_contact and
  list_events, over the mirrored contacts and calendars (tools/mirror.py); a system prompt that says
  what the assistant cannot do yet.

Within a mode the tool list and the system prompt never change, so the prompt prefix Ollama caches stays
byte-identical (tests/test_prompt_prefix.py). Switching mode (an account added or removed) swaps the
tools in the host's one registry, ends every conversation (their history holds the other mode's data:
see Assistant.apply_mode), and re-warms the model with the new prefix. MCP agents get no tools in real
mode (mcp.py).
"""

from __future__ import annotations

import logging
import threading
from dataclasses import dataclass
from datetime import date, tzinfo
from typing import Callable, Literal

from ..orchestrator.engine import SYSTEM_PROMPT
from ..tools.mirror import _local_zone, local_today, mirror_tools
from ..tools.registry import Tool
from .logs import log

logger = logging.getLogger("mydata.modes")

Mode = Literal["demo", "real"]

DEMO_SYSTEM_PROMPT = SYSTEM_PROMPT

_DEMO_CAN = ("You can search and send the user's mail, look up contacts, read and add calendar events, and search "
             "photos, using the tools provided.")
_REAL_CAN = ("You can look up contacts and read calendar events, using the tools provided. "
             "You cannot read or send mail, search photos or add calendar events yet: if the user asks for one of "
             "these, say that you cannot do that yet.")
assert _DEMO_CAN in SYSTEM_PROMPT, "the demo system prompt changed; update modes.py"
# The demo prompt with its list of abilities cut down to the two real tools, plus one sentence on the rest.
REAL_SYSTEM_PROMPT = SYSTEM_PROMPT.replace(_DEMO_CAN, _REAL_CAN)


@dataclass(frozen=True)
class ModeSpec:
    name: Mode
    tools: tuple[Tool, ...]
    today: Callable[[], date]
    system_prompt: str


class ModeController:
    """Decides the mode from the linked accounts and applies it to the assistant (and so to the registry
    every agent uses). `real_today` and `real_tz` are for tests; real mode otherwise uses the real date
    and the machine's zone."""

    def __init__(self, assistant, sync, *, on_change: Callable[[Mode], None] | None = None,
                 real_today: Callable[[], date] | None = None, real_tz: Callable[[], tzinfo] | None = None):
        self.assistant = assistant
        self.sync = sync
        self.on_change = on_change
        self._real_tz = real_tz or _local_zone
        self._real_today = real_today or local_today(self._real_tz)
        registry = assistant.registry
        # Demo is whatever the host was built with: the built-in tools, the pinned date, the original prompt.
        self._demo = ModeSpec("demo", tuple(registry.get(n) for n in registry.names()), assistant.today,
                              assistant.system_prompt)
        self._mode: Mode = registry.mode if registry.mode in ("demo", "real") else "demo"
        self._lock = threading.Lock()

    @property
    def mode(self) -> Mode:
        return self._mode

    def wanted(self) -> Mode:
        any_on = getattr(self.sync, "any_source_on", None)
        on = any_on() if any_on is not None else bool(self.sync.accounts.list())
        return "real" if on else "demo"

    def spec(self, mode: Mode) -> ModeSpec:
        if mode == "demo":
            return self._demo
        tools = mirror_tools(self.sync.contacts, self.sync.calendar, tz=self._real_tz,
                             coverage=getattr(self.sync, "coverage", None))
        return ModeSpec("real", tuple(tools), self._real_today, REAL_SYSTEM_PROMPT)

    def refresh(self) -> Mode:
        """Switch mode if the accounts call for it. Returns the mode now in force."""
        with self._lock:
            try:
                want = self.wanted()
            except Exception:  # an unreadable accounts.json keeps the current mode
                logger.exception("could not read the accounts; the mode is unchanged")
                return self._mode
            if want == self._mode and self.assistant.registry.mode == want:
                return want
            spec = self.spec(want)
            self.assistant.apply_mode(spec.name, spec.tools, spec.today, spec.system_prompt)
            previous, self._mode = self._mode, want
            log(logger, logging.INFO, "mode switched", previous=previous, mode=want,
                tools=[t.name for t in spec.tools])
        if self.on_change is not None:
            try:
                self.on_change(want)
            except Exception:
                logger.exception("after switching mode")
        return want
