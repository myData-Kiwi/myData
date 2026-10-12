"""Request sets and the canned data each one runs against.

Each set is a frozen module with CASES (and TYPES). A set may bring its own DATA;
while it runs, the fake tools read that data instead of orchestrator/fixtures.py.
Only the data changes: tool definitions, prompt and engine are the same for every set.
"""

from __future__ import annotations

import importlib
import inspect
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date
from types import ModuleType
from typing import Iterator

from ..orchestrator import fixtures

SETS = {
    "2026-10-11": "mydata.feasibility.cases",
    "2026-10-11-b": "mydata.feasibility.cases_2026_10_11_b",
}
DEFAULT_SET = "2026-10-11"


@dataclass(frozen=True)
class CaseSet:
    name: str
    module: ModuleType
    cases: list[dict]
    types: dict[str, str]
    today: date
    data: dict | None

    @property
    def source(self) -> str:
        return inspect.getsource(self.module)


def load_set(name: str = DEFAULT_SET) -> CaseSet:
    if name not in SETS:
        raise SystemExit(f"unknown request set {name!r}; known: {', '.join(SETS)}")
    module = importlib.import_module(SETS[name])
    return CaseSet(
        name=name,
        module=module,
        cases=module.CASES,
        types=module.TYPES,
        today=getattr(module, "TODAY", fixtures.TODAY),
        data=getattr(module, "DATA", None),
    )


_FIELDS = {"contacts": "CONTACTS", "events": "EVENTS", "mail": "MAIL", "photos": "PHOTOS"}


@contextmanager
def use_data(data: dict | None) -> Iterator[None]:
    """Point the fake tools at a set's own data for the duration of a run."""
    if data is None:
        yield
        return
    saved = {attr: getattr(fixtures, attr) for attr in _FIELDS.values()}
    try:
        for key, attr in _FIELDS.items():
            setattr(fixtures, attr, data[key])
        yield
    finally:
        for attr, value in saved.items():
            setattr(fixtures, attr, value)
