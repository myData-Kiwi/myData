"""The permission gate cannot be bypassed: not in the registry, not over HTTP, not over MCP.
An irreversible tool runs only when the user approves that exact held call, and only once."""

from __future__ import annotations

import asyncio
import json
import threading

import httpx
from starlette.testclient import TestClient
import httpx2
import mcp_types as types
import pytest
from mcp import Client
from mcp.client.streamable_http import streamable_http_client

from mydata.tools import ApprovalError

from service_helpers import ASSISTANT_TOKEN, SEND_TO_NISHA, TODAY, TOKEN, make_app, parse_sse, serve, spied_registry

AUTH = {"Authorization": f"Bearer {TOKEN}"}
ASSISTANT_AUTH = {"Authorization": f"Bearer {ASSISTANT_TOKEN}"}
ARGS = {"to": "nisha.patel@example.com", "subject": "Late", "body": "I'll be late tomorrow."}


# ---------------------------------------------------------------- registry


def test_irreversible_call_is_held_not_run():
    registry, spy = spied_registry()
    inv = registry.invoke("send_mail", ARGS, caller="test")
    assert inv.status == "pending_approval" and inv.result is None
    assert spy.calls == []
    assert registry.approval(inv.approval.id).status == "pending"


def test_approval_runs_exactly_the_held_call_once():
    registry, spy = spied_registry()
    inv = registry.invoke("send_mail", ARGS, caller="test")
    inv.approval.args["to"] = "attacker@example.com"  # the caller's copy; the held call must not change
    a = registry.decide(inv.approval.id, True, decided_by="user")
    assert a.status == "approved" and spy.calls == [ARGS]
    with pytest.raises(ApprovalError):
        registry.decide(inv.approval.id, True, decided_by="user")
    assert len(spy.calls) == 1


def test_rejected_call_never_runs():
    registry, spy = spied_registry()
    inv = registry.invoke("send_mail", ARGS, caller="test")
    assert registry.decide(inv.approval.id, False, decided_by="user").status == "rejected"
    with pytest.raises(ApprovalError):
        registry.decide(inv.approval.id, True, decided_by="user")
    assert spy.calls == []


def test_concurrent_approvals_run_once():
    registry, spy = spied_registry()
    inv = registry.invoke("send_mail", ARGS, caller="test")
    results = []

    def approve():
        try:
            results.append(registry.decide(inv.approval.id, True, decided_by="user").status)
        except ApprovalError:
            results.append("refused")

    threads = [threading.Thread(target=approve) for _ in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert results.count("approved") == 1 and len(spy.calls) == 1


def test_invalid_irreversible_call_is_not_held():
    registry, spy = spied_registry()
    assert registry.invoke("send_mail", {"to": "x@example.com"}, caller="test").status == "invalid_args"
    assert registry.approvals() == [] and spy.calls == []


# ---------------------------------------------------------------- HTTP


def _client(app):
    return TestClient(app, base_url="http://127.0.0.1")


def test_http_assistant_holds_send_and_only_approval_runs_it(tmp_path):
    app, registry, spy = make_app(tmp_path, [SEND_TO_NISHA])
    with _client(app) as c:
        r = c.post("/assistant/messages", json={"text": "Look up Nisha Patel's email and send her a note saying "
                                                         "I'll be late tomorrow"}, headers=ASSISTANT_AUTH)
        events = parse_sse(r.text)
        kinds = [k for k, _ in events]
        assert "pending_approval" in kinds and kinds[-1] == "done"
        approval = next(d for k, d in events if k == "pending_approval")["approval"]
        assert approval["args"] == ARGS and spy.calls == []

        assert [a["id"] for a in c.get("/approvals?status=pending", headers=AUTH).json()] == [approval["id"]]
        # Extra fields in the decision cannot change what runs.
        r = c.post(f"/approvals/{approval['id']}", headers=AUTH,
                   json={"decision": "approve", "args": {"to": "attacker@example.com"}, "tool": "create_event"})
        assert r.status_code == 200 and r.json()["status"] == "approved"
        assert spy.calls == [ARGS]
        assert c.post(f"/approvals/{approval['id']}", json={"decision": "approve"}, headers=AUTH).status_code == 409
        assert c.post("/approvals/nope", json={"decision": "approve"}, headers=AUTH).status_code == 404
    assert len(spy.calls) == 1


def test_http_has_no_route_that_runs_a_tool_directly(tmp_path):
    app, registry, spy = make_app(tmp_path)
    with _client(app) as c:
        for method, path in [("POST", "/tools/send_mail"), ("POST", "/tools"), ("PUT", "/approvals/x"),
                             ("POST", "/tools/send_mail/call")]:
            r = c.request(method, path, json={"args": ARGS}, headers=AUTH)
            assert r.status_code in (404, 405)
    assert spy.calls == [] and registry.approvals() == []


def test_http_rejects_bad_decision_values(tmp_path):
    app, registry, spy = make_app(tmp_path)
    inv = registry.invoke("send_mail", ARGS, caller="test")
    with _client(app) as c:
        for body in ({}, {"decision": "yes"}, {"decision": True}, {"decision": "APPROVE"}):
            assert c.post(f"/approvals/{inv.approval.id}", json=body, headers=AUTH).status_code == 422
    assert spy.calls == []


# ---------------------------------------------------------------- MCP


async def _mcp(base: str, fn):
    async with httpx2.AsyncClient(headers=AUTH, timeout=httpx2.Timeout(30.0)) as http:
        async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as client:
            return await fn(client)


def _text(res: types.CallToolResult) -> dict:
    return json.loads(res.content[0].text)


def test_mcp_lists_the_registry_and_no_approval_tool(tmp_path):
    app, registry, spy = make_app(tmp_path)
    with serve(app) as (base, _):
        names = asyncio.run(_mcp(base, lambda c: c.list_tools()))
    tools = {t.name for t in names.tools}
    assert tools == set(registry.names())
    assert not any("approv" in n or "decide" in n for n in tools)


def test_mcp_send_mail_is_held_and_cannot_be_approved_over_mcp(tmp_path):
    app, registry, spy = make_app(tmp_path)

    async def scenario(c):
        held = await c.call_tool("send_mail", ARGS)
        approve = await c.call_tool("approve", {"approval_id": _text(held)["approval_id"]})
        bad = await c.call_tool("send_mail", {"to": "x@example.com"})
        return held, approve, bad

    with serve(app) as (base, _):
        held, approve, bad = asyncio.run(_mcp(base, scenario))
    payload = _text(held)
    assert not held.is_error and payload["status"] == "pending_approval"
    assert approve.is_error and _text(approve)["status"] == "unknown_tool"
    assert bad.is_error
    assert spy.calls == []
    a = registry.approval(payload["approval_id"])
    assert a.status == "pending" and a.caller == "app:mydata" and a.args == ARGS


def test_mcp_read_tool_runs(tmp_path):
    app, registry, spy = make_app(tmp_path)
    with serve(app) as (base, _):
        res = asyncio.run(_mcp(base, lambda c: c.call_tool("find_contact", {"name": "Nisha Patel"})))
    assert not res.is_error and _text(res)["result"]["matches"][0]["email"] == "nisha.patel@example.com"


def test_mcp_held_call_runs_only_after_user_approves_over_http(tmp_path):
    app, registry, spy = make_app(tmp_path)
    with serve(app) as (base, _):
        held = asyncio.run(_mcp(base, lambda c: c.call_tool("send_mail", ARGS)))
        assert spy.calls == []
        r = httpx.post(f"{base}/approvals/{_text(held)['approval_id']}", json={"decision": "approve"}, headers=AUTH)
    assert r.json()["status"] == "approved" and spy.calls == [ARGS]
