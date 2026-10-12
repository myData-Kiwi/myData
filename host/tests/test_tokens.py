"""App tokens can do everything; agent tokens reach only /mcp. Approvals record which app decided."""

from __future__ import annotations

import asyncio
import json
import os
import stat
import subprocess
import sys

import httpx
import httpx2
import pytest
from mcp import Client
from mcp.client.streamable_http import streamable_http_client
from starlette.testclient import TestClient

from mydata.service.auth import APPS, AgentStore, ensure_app_tokens
from mydata.service.config import DEFAULT_CONFIG

from service_helpers import ASSISTANT_TOKEN, TOKEN, free_port, make_app, serve

ARGS = {"to": "nisha.patel@example.com", "subject": "Late", "body": "I'll be late tomorrow."}
APP_ROUTES = [("GET", "/status"), ("POST", "/model/retry"), ("GET", "/tools"), ("GET", "/approvals"),
              ("GET", "/approvals/x"), ("POST", "/approvals/x"), ("POST", "/assistant/messages"), ("GET", "/agents"),
              ("POST", "/agents"), ("DELETE", "/agents/x"), ("GET", "/openapi.json"), ("GET", "/nothing")]


def _bearer(t):
    return {"Authorization": f"Bearer {t}"}


async def _mcp(base, token, fn):
    async with httpx2.AsyncClient(headers=_bearer(token)) as http:
        async with Client(streamable_http_client(f"{base}/mcp", http_client=http)) as c:
            return await fn(c)


@pytest.mark.parametrize("method,path", APP_ROUTES)
def test_agent_token_is_refused_everywhere_but_mcp(tmp_path, method, path):
    app, registry, spy = make_app(tmp_path)
    _, agent_token = app.auth.agents.create("helper")
    with TestClient(app, base_url="http://127.0.0.1") as c:
        r = c.request(method, path, headers=_bearer(agent_token), json={"decision": "approve", "text": "hi", "name": "x"})
    assert r.status_code == 403


def test_agent_cannot_approve_list_or_read_pending_calls(tmp_path):
    app, registry, spy = make_app(tmp_path)
    _, a_token = app.auth.agents.create("agent-a")
    _, b_token = app.auth.agents.create("agent-b")
    with serve(app) as (base, _):
        held = asyncio.run(_mcp(base, a_token, lambda c: c.call_tool("send_mail", ARGS)))
        approval_id = json.loads(held.content[0].text)["approval_id"]
        for token in (a_token, b_token):
            h = _bearer(token)
            assert httpx.get(f"{base}/approvals", headers=h).status_code == 403
            assert httpx.get(f"{base}/approvals/{approval_id}", headers=h).status_code == 403
            assert httpx.post(f"{base}/approvals/{approval_id}", json={"decision": "approve"}, headers=h).status_code == 403
        tools = asyncio.run(_mcp(base, b_token, lambda c: c.list_tools()))
        assert not any("approv" in t.name for t in tools.tools)
        assert spy.calls == []
        a = registry.approval(approval_id)
        assert a.status == "pending" and a.caller == "agent:agent-a"
        # Only an app can decide, and the record says which one.
        r = httpx.post(f"{base}/approvals/{approval_id}", json={"decision": "approve"}, headers=_bearer(ASSISTANT_TOKEN))
    assert r.json()["status"] == "approved" and r.json()["decided_by"] == "app:myassistant"
    assert spy.calls == [ARGS]


def test_revoked_agent_token_stops_working_immediately(tmp_path):
    app, *_ = make_app(tmp_path)
    agent, token = app.auth.agents.create("temp")
    with serve(app) as (base, _):
        assert asyncio.run(_mcp(base, token, lambda c: c.list_tools())).tools
        AgentStore(tmp_path).revoke(agent.id)  # e.g. from `mydata agent revoke` in another process
        r = httpx.post(f"{base}/mcp", headers={**_bearer(token), "Content-Type": "application/json"}, json={})
    assert r.status_code == 401


def test_agents_endpoints_and_connected(tmp_path):
    app, *_ = make_app(tmp_path)
    with serve(app) as (base, _):
        h = _bearer(TOKEN)
        created = httpx.post(f"{base}/agents", json={"name": "Claude Desktop"}, headers=h).json()
        assert created["token"].startswith("mda_")
        assert all("token" not in a for a in httpx.get(f"{base}/agents", headers=h).json())
        asyncio.run(_mcp(base, created["token"], lambda c: c.list_tools()))
        listed = httpx.get(f"{base}/agents", headers=h).json()
        assert listed[0]["connected"] and httpx.get(f"{base}/status", headers=h).json()["agents_connected"] == 1
        assert httpx.delete(f"{base}/agents/{created['id']}", headers=h).json()["revoked"]
    stored = (tmp_path / "agents.json").read_text()
    assert created["token"] not in stored  # only the hash is kept


@pytest.mark.skipif(sys.platform.startswith("win"), reason="POSIX permissions")
def test_app_tokens_are_separate_and_private(tmp_path):
    tokens = ensure_app_tokens(tmp_path)
    assert set(tokens) == set(APPS) and len(set(tokens.values())) == len(APPS)
    assert stat.S_IMODE((tmp_path / "app-tokens").stat().st_mode) == 0o700
    for app in APPS:
        assert stat.S_IMODE((tmp_path / "app-tokens" / app).stat().st_mode) == 0o600
    if (tmp_path / "agents.json").exists():
        assert stat.S_IMODE((tmp_path / "agents.json").stat().st_mode) == 0o600


def test_cli_agent_commands(tmp_path):
    env = {**os.environ, "MYDATA_HOME": str(tmp_path)}
    (tmp_path / "config.toml").write_text(DEFAULT_CONFIG)

    def run(*args):
        return subprocess.run([sys.executable, "-m", "mydata.cli", "agent", *args], env=env, capture_output=True,
                              text=True, timeout=30)

    r = run("create", "Claude Desktop")
    assert r.returncode == 0 and "mda_" in r.stdout
    token = next(w for w in r.stdout.split() if w.startswith("mda_"))
    assert "Claude Desktop" in run("list").stdout
    assert stat.S_IMODE((tmp_path / "agents.json").stat().st_mode) == 0o600
    assert run("revoke", "Claude Desktop").returncode == 0
    assert "revoked" in run("list").stdout
    assert run("revoke", "nobody").returncode == 1
    assert AgentStore(tmp_path).authenticate(token) is None
