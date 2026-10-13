"""The feasibility harness runs only on demo data.

Its results (results/, committed to the repository) hold every request, tool call and tool result.
With the fake tools that is invented data. With a real-mode registry it would be the user's contacts and
calendar, so every command that writes results checks first and refuses:

- a registry must be in demo mode and hold exactly the built-in fake tools (same handlers);
- a host status (GET /status) must report mode "demo".
"""

from __future__ import annotations

from typing import Any

from ..tools import TOOLS, Registry, default_registry


class RealDataRefused(RuntimeError):
    """The harness was pointed at real data; nothing was written."""


def ensure_demo(target: Registry | dict[str, Any]) -> None:
    """Raise RealDataRefused unless `target` (a Registry, or a host's /status answer) is demo mode."""
    if isinstance(target, Registry):
        problems = []
        if target.mode != "demo":
            problems.append(f"its mode is {target.mode!r}")
        names = target.names()
        if set(names) != set(TOOLS):
            problems.append(f"its tools are {sorted(names)}, not the built-in demo tools")
        foreign = [n for n in names if n in TOOLS and target.get(n).handler is not TOOLS[n].handler]
        if foreign:
            problems.append(f"{', '.join(foreign)} do not use the fake demo data")
        if problems:
            raise RealDataRefused("The feasibility harness only runs on demo data and has written nothing: this "
                                  "registry is not the demo registry (" + "; ".join(problems) + ").")
        return
    if isinstance(target, dict):
        mode = target.get("mode")
        if mode != "demo":
            raise RealDataRefused(f"The feasibility harness only runs on demo data and has written nothing: the host "
                                  f"is in {mode or 'an unknown'} mode. Results must never hold the user's own data.")
        return
    raise TypeError(f"expected a Registry or a host status, not {type(target).__name__}")


def demo_registry(today) -> Registry:
    """The built-in demo registry, checked."""
    registry = default_registry(today=today)
    ensure_demo(registry)
    return registry
