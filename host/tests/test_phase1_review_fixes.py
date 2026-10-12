"""Regression tests for the defects found in the phase-1 review, each as the reviewer reproduced it."""

from __future__ import annotations

import asyncio
import json
import logging
import threading
import time

import httpx2
import pytest
from mcp import Client
from mcp.client.streamable_http import streamable_http_client
from starlette.testclient import TestClient

from mydata.orchestrator.engine import Engine
from mydata.orchestrator.grounding import Sources, check
from mydata.service.assistant import Assistant
from mydata.service.config import Settings
from mydata.service.model import ModelManager
from mydata.tools.dates import DateParseError, resolve

from service_helpers import (SEND_TO_NISHA, TODAY, TOKEN, Scripted, call, make_app, parse_sse, serve,
                             spied_registry)

AUTH = {"Authorization": f"Bearer {TOKEN}"}


# ---------------------------------------------------------------- argument types reach no approval


@pytest.mark.parametrize("args", [
    {"to": ["a@x.com", "evil@y.com"], "subject": "s", "body": "b"},
    {"to": "a@x.com", "subject": {"x": 1}, "body": "b"},
    {"to": "a@x.com", "subject": "s", "body": 5},
    {"to": {"$x": [1]}, "subject": [], "body": {}},
])
def test_wrongly_typed_arguments_are_rejected_before_any_hold(args):
    registry, spy = spied_registry()
    inv = registry.invoke("send_mail", args, caller="test")
    assert inv.status == "invalid_args" and registry.approvals() == [] and spy.calls == []


def test_booleans_are_not_numbers():
    registry, _ = spied_registry()
    inv = registry.invoke("create_event", {"title": "Gym", "date": "tomorrow", "duration_minutes": True},
                          caller="test", today=TODAY)
    assert inv.status == "invalid_args"


def test_mcp_typed_arguments_are_errors(tmp_path):
    app, registry, spy = make_app(tmp_path)

    async def go():
        async with httpx2.AsyncClient(headers=AUTH) as http:
            async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as c:
                return await c.call_tool("send_mail", {"to": ["a@x.com"], "subject": 0, "body": False})

    with serve(app) as (base, _):
        res = asyncio.run(go())
    assert res.is_error and registry.approvals() == [] and spy.calls == []


# ---------------------------------------------------------------- grounding: every address must be known


@pytest.mark.parametrize("to", ["nisha.patel@example.com, attacker@evil.example",
                                "xnisha.patel@example.com.evil.example", "Nisha <attacker@evil.example>",
                                "someone"])
def test_grounding_rejects_any_unknown_address(to):
    src = Sources("email nisha", [{"matches": [{"email": "nisha.patel@example.com"}]}])
    _, _, failing = check("send_mail", {"to": to, "subject": "s", "body": "b"}, ["to", "subject", "body"], set(), src)
    assert "to" in failing


def test_grounding_keeps_a_known_address_with_display_name():
    src = Sources("email nisha", [{"matches": [{"email": "nisha.patel@example.com"}]}])
    _, _, failing = check("send_mail", {"to": "Nisha Patel <nisha.patel@example.com>", "subject": "s", "body": "b"},
                          ["to", "subject", "body"], set(), src)
    assert not failing


# ---------------------------------------------------------------- dates cannot crash the host


@pytest.mark.parametrize("phrase", ["monday " * 1200, "friday " * 40, "x" * 5000])
def test_pathological_date_phrases_are_bad_dates(phrase):
    with pytest.raises(DateParseError):
        resolve(phrase, TODAY, "future")


def test_mcp_call_with_pathological_date_is_a_tool_error(tmp_path):
    app, *_ = make_app(tmp_path)

    async def go():
        async with httpx2.AsyncClient(headers=AUTH) as http:
            async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as c:
                return await c.call_tool("list_events", {"date": "monday " * 1200})

    with serve(app) as (base, _):
        res = asyncio.run(go())
    assert res.is_error and json.loads(res.content[0].text)["status"] == "bad_date"


# ---------------------------------------------------------------- audit log


def test_tool_calls_and_decisions_are_logged_without_argument_values(caplog):
    registry, _ = spied_registry()
    with caplog.at_level(logging.INFO, logger="mydata.tools"):
        inv = registry.invoke("send_mail", {"to": "nisha.patel@example.com", "subject": "Secret", "body": "Hidden"},
                              caller="mcp")
        registry.decide(inv.approval.id, True, decided_by="user")
    records = [(r.getMessage(), r.fields) for r in caplog.records]
    assert ("tool call", {"tool": "send_mail", "caller": "mcp", "status": "pending_approval", "error": None,
                          "approval_id": inv.approval.id}) in records
    decided = next(f for m, f in records if m == "approval decided")
    assert decided["decided_by"] == "user" and decided["status"] == "approved" and decided["caller"] == "mcp"
    assert "Hidden" not in json.dumps(records) and "Secret" not in json.dumps(records)
    assert registry.approval(inv.approval.id).decided_by == "user"


# ---------------------------------------------------------------- assistant turns


class Slow(Scripted):
    def chat(self, messages, tools):
        self.seen = [m["role"] + ":" + str(m.get("content", ""))[:30] for m in messages]
        time.sleep(0.3)
        return super().chat(messages, tools)


def _assistant(tmp_path, factory):
    registry, spy = spied_registry()
    return Assistant(Settings(home=tmp_path), registry, model_factory=factory, today=lambda: TODAY), registry


def test_second_message_waits_and_sees_the_first_turn(tmp_path):
    models = []

    def factory():
        m = Slow([{"content": "It is at 3:30."}])
        models.append(m)
        return m

    a, _ = _assistant(tmp_path, factory)
    out = {}
    t1 = threading.Thread(target=lambda: out.setdefault(1, list(a.reply("When is my dentist?", "c"))))
    t1.start()
    time.sleep(0.1)
    list(a.reply("Thanks", "c"))
    t1.join()
    assert any("When is my dentist?" in s for s in models[1].seen)
    assert any("It is at 3:30." in s for s in models[1].seen)


def test_failed_turn_leaves_nothing_in_history(tmp_path):
    class Boom:
        name = "boom"

        def chat(self, messages, tools):
            raise RuntimeError("model fell over")

    a, _ = _assistant(tmp_path, Boom)
    events = list(a.reply("What's on next Friday?", "c"))
    assert [e["type"] for e in events] == ["conversation", "error", "done"]
    assert a.history("c") == []


def test_clarify_names_the_tool_that_matched_several(tmp_path):
    a, _ = _assistant(tmp_path, lambda: Scripted([[call("find_contact", name="Patel"),
                                                   call("list_events", date="tomorrow")]]))
    events = list(a.reply("Message Patel about tomorrow", "c"))
    assert any(e["type"] == "clarify" for e in events)
    tool_msgs = [m for m in a.history("c") if m["role"] == "tool"]
    assert tool_msgs[-1]["tool_name"] == "find_contact"


def test_worker_failure_before_the_engine_runs_ends_the_stream(tmp_path):
    def factory():
        raise RuntimeError("cannot build the model client")

    a, _ = _assistant(tmp_path, factory)
    events = list(a.reply("hi", "c"))
    assert [e["type"] for e in events][-2:] == ["error", "done"]


def test_step_event_marks_streamed_text_before_tool_calls(tmp_path):
    class Streaming(Scripted):
        streams = True

        def chat(self, messages, tools, on_delta=None):
            r = super().chat(messages, tools)
            if on_delta:
                on_delta(r["content"] or "Let me check. ")
            return r

    a, _ = _assistant(tmp_path, lambda: Streaming([[call("list_events", date="tomorrow")],
                                                    {"content": "Nothing tomorrow."}]))
    kinds = [e["type"] for e in a.reply("What's on tomorrow?", "c")]
    assert kinds.index("step") < kinds.index("progress") and kinds[-2:] == ["message", "done"]


def test_http_pending_approval_event_and_conversation_continue(tmp_path):
    app, registry, spy = make_app(tmp_path, [SEND_TO_NISHA, [{"content": "Okay."}]])
    with TestClient(app, base_url="http://127.0.0.1") as c:
        first = parse_sse(c.post("/assistant/messages", headers=AUTH,
                                 json={"text": "Tell Nisha Patel I'll be late tomorrow"}).text)
        cid = first[0][1]["conversation_id"]
        assert [k for k, _ in first][-3:] == ["pending_approval", "message", "done"]
        second = parse_sse(c.post("/assistant/messages", headers=AUTH,
                                  json={"text": "thanks", "conversation_id": cid}).text)
    assert second[-2] == ("message", {"text": "Okay.", "outcome": "answered", "by": "model"})
    assert spy.calls == []


# ---------------------------------------------------------------- model manager notices a dead Ollama


def test_ready_model_with_dead_ollama_reports_error(tmp_path):
    mm = ModelManager(Settings(home=tmp_path, ollama_url="http://127.0.0.1:1"))
    mm._set(state="ready", loaded=True, ollama_reachable=True)
    s = mm.status()
    assert s.state == "error" and not s.loaded and "stopped responding" in s.error


# ---------------------------------------------------------------- engine


def test_engine_rejects_unknown_tool_names():
    with pytest.raises(KeyError):
        Engine(Scripted([]), TODAY).run("hi", tool_names=["contacts"])
