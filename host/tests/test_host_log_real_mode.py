"""The host log (mydatad.log) in real mode keeps no value from the user's data.

The registry's "tool call" and "approval decided" lines carry the error of a failed call. A bad date quotes
the phrase the model passed (it can be a description built from a contact: "the day of Ava Fictional's
housewarming"), and a handler's exception text can hold a value. In real mode those lines keep only the
error's kind and length. Demo mode logs the text, as before. Invented data only.
"""

from __future__ import annotations

import dataclasses
import json
import logging

from mydata.service.logs import JsonFormatter
from mydata.tools.registry import Registry, log_error

from service_helpers import spied_registry

PHRASE = "the day of Ava Fictional's housewarming"
SECRET = "Ava Fictional <ava@example.org>"


def _boom(args, dates, today):
    raise KeyError(SECRET)


def _registry(mode: str) -> Registry:
    registry, _ = spied_registry()
    tools = [dataclasses.replace(registry.get(n), handler=_boom) if n == "find_contact" else registry.get(n)
             for n in registry.names()]
    registry.replace_tools(tools, mode=mode)
    return registry


def _logged(caplog) -> str:
    fmt = JsonFormatter()
    return "\n".join(fmt.format(r) for r in caplog.records if r.name == "mydata.tools")


def test_real_mode_tool_call_lines_keep_no_phrase_or_exception_text(caplog):
    caplog.set_level(logging.INFO, logger="mydata.tools")
    registry = _registry("real")
    assert registry.invoke("list_events", {"date": PHRASE}, caller="test").status == "bad_date"
    inv = registry.invoke("find_contact", {"name": "Ava"}, caller="test")
    assert inv.status == "error" and SECRET in inv.error  # the caller still gets it; only the log does not
    text = _logged(caplog)
    assert "tool call" in text
    assert "Ava Fictional" not in text and "ava@example.org" not in text and "housewarming" not in text
    lines = [json.loads(line) for line in text.splitlines()]
    assert lines[0]["status"] == "bad_date" and lines[0]["error"]["length"] > 0
    assert lines[1]["error"] == {"kind": "KeyError", "length": len(inv.error)}


def test_real_mode_approval_errors_keep_no_exception_text(caplog):
    """A held call that fails when run: the approval line keeps the kind, not the text."""
    caplog.set_level(logging.INFO, logger="mydata.tools")
    registry, _ = spied_registry()
    tools = [dataclasses.replace(registry.get(n), handler=_boom) if n == "send_mail" else registry.get(n)
             for n in registry.names()]
    registry.replace_tools(tools, mode="real")
    inv = registry.invoke("send_mail", {"to": "ava@example.org", "subject": "Hi", "body": "Hello"}, caller="test")
    a = registry.decide(inv.approval.id, True, decided_by="user")
    assert a.status == "failed" and SECRET in a.error
    text = _logged(caplog)
    assert "approval decided" in text and "ava@example.org" not in text and "Ava Fictional" not in text


def test_demo_mode_logs_the_error_text_as_before(caplog):
    caplog.set_level(logging.INFO, logger="mydata.tools")
    registry = _registry("demo")
    registry.invoke("list_events", {"date": PHRASE}, caller="test")
    assert "housewarming" in _logged(caplog)


def test_log_error():
    assert log_error(None, "real") is None
    assert log_error("KeyError: 'x'", "demo") == "KeyError: 'x'"
    assert log_error("KeyError: 'x'", "real") == {"kind": "KeyError", "length": 13}
    assert log_error(f"could not understand the date '{PHRASE}'", "real")["kind"] is None
    assert log_error("Ava: x", "real")["kind"] == "Ava"  # only the registry's own formats reach it
