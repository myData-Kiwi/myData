"""Token scopes: every route declares the scope it needs, and each app token reaches exactly the routes its
app's scopes allow.

The routes are read from the FastAPI app itself, so a new route without a scope (or one missing from the
table below) fails here, and the host refuses to start with it. Invented data only.
"""

from __future__ import annotations

import re

import pytest
from fastapi.routing import APIRoute
from starlette.routing import Route
from starlette.testclient import TestClient

from mydata.service import api
from mydata.service.api import create_app, route_scopes
from mydata.service.assistant import Assistant
from mydata.service.auth import APP_SCOPES, APPS, LIFETIME_APPS, SCOPES, AgentStore, Authenticator
from mydata.service.config import Settings

from service_helpers import TODAY, ReadyModels, Scripted, spied_registry

# What each route needs. Written out here, not read from api.py, so a change of scope is a change to this
# table too.
ROUTE_SCOPES = {
    ("GET", "/status"): ("status",),
    ("GET", "/appearance"): ("status",),
    ("POST", "/model/retry"): ("assistant", "admin"),
    ("POST", "/assistant/messages"): ("assistant",),
    ("PUT", "/assistant/settings"): ("admin",),
    ("PUT", "/appearance"): ("admin",),
    ("GET", "/tools"): ("admin",),
    ("GET", "/agents"): ("admin",),
    ("POST", "/agents"): ("admin",),
    ("DELETE", "/agents/{agent_id}"): ("admin",),
    ("GET", "/approvals"): ("approve",),
    ("GET", "/approvals/{approval_id}"): ("approve",),
    ("POST", "/approvals/{approval_id}"): ("approve",),
    ("POST", "/shutdown"): ("shutdown",),
    ("GET", "/contacts"): ("contacts:read",),
    ("GET", "/contacts/duplicates"): ("contacts:read",),
    ("GET", "/contacts/{contact_id}"): ("contacts:read",),
    ("GET", "/contacts/{contact_id}/photo"): ("contacts:read",),
    ("POST", "/contacts"): ("contacts:write",),
    ("PATCH", "/contacts/{contact_id}"): ("contacts:write",),
    ("DELETE", "/contacts/{contact_id}"): ("contacts:write",),
    ("GET", "/trash"): ("contacts:read",),
    ("POST", "/trash/{item_id}/restore"): ("contacts:write",),
    ("DELETE", "/trash/{item_id}"): ("contacts:write",),
    ("POST", "/undo/{undo_id}"): ("contacts:write",),
    ("GET", "/contacts/{contact_id}/followed-changes"): ("contacts:read",),
    ("POST", "/contacts/{contact_id}/followed-changes/save"): ("contacts:write",),
    ("POST", "/contacts/{contact_id}/followed-changes/keep"): ("contacts:write",),
    ("POST", "/contacts/merge"): ("contacts:write",),
    ("POST", "/contacts/merge/preview"): ("contacts:write",),
    ("POST", "/contacts/not-duplicates"): ("contacts:write",),
    ("POST", "/import/contacts/preview"): ("contacts:import",),
    ("POST", "/import/contacts/from-source/{account_id}/preview"): ("contacts:import",),
    ("GET", "/import/previews/{preview_id}"): ("contacts:import",),
    ("GET", "/import/previews/{preview_id}/items/{index}"): ("contacts:import",),
    ("DELETE", "/import/previews/{preview_id}"): ("contacts:import",),
    ("POST", "/import/previews/{preview_id}/commit"): ("contacts:import",),
    ("GET", "/imports"): ("contacts:import",),
    ("POST", "/imports/{import_id}/undo"): ("contacts:import",),
    ("GET", "/calendars"): ("calendar:read",),
    ("GET", "/events"): ("calendar:read",),
    ("GET", "/sources"): ("sources:read",),
    ("GET", "/accounts"): ("sources:read",),
    ("GET", "/sync"): ("sources:read",),
    ("POST", "/accounts"): ("sources:manage",),
    ("DELETE", "/accounts/{account_id}"): ("sources:manage",),
    ("POST", "/accounts/{account_id}/sync"): ("sources:manage",),
    ("PUT", "/sources/mac"): ("sources:manage",),
    ("POST", "/sources/mac/request-access"): ("sources:manage",),
    ("POST", "/sources/mac/sync"): ("sources:manage",),
    ("PUT", "/sources/mac/reader"): ("sources:manage",),
}

# Each app's scopes, as agreed in the owned-data plan (phase 0c; myContacts gains contacts:write with editing,
# phase 3; importing is contacts:import, the myData app's and the command's only: ImportFlow, Decisions 2). calendar:write is reserved: only the myData app and the command hold it, and no route uses it yet.
EXPECTED_SCOPES = {
    "mydata": {"status", "admin", "approve", "contacts:read", "contacts:write", "contacts:import", "calendar:read",
               "calendar:write", "sources:read", "sources:manage", "shutdown", "mcp"},
    "myassistant": {"status", "assistant", "approve", "contacts:read", "calendar:read"},
    "mycontacts": {"status", "contacts:read", "contacts:write", "sources:read"},
    "mycalendar": {"status", "calendar:read", "sources:read"},
    "cli": set(SCOPES),
}

TOKENS = {app: f"{app}-" + "k" * 40 for app in APPS}


def _app(tmp_path):
    registry, spy = spied_registry()
    assistant = Assistant(Settings(home=tmp_path), registry, model_factory=lambda: Scripted([]), today=lambda: TODAY)
    return create_app(Authenticator(dict(TOKENS), AgentStore(tmp_path)), registry, ReadyModels(), assistant), spy


def _declared(guarded) -> dict[tuple[str, str], tuple[str, ...] | None]:
    out = {}
    for r in guarded.app.routes:
        if isinstance(r, APIRoute):
            for method in r.methods:
                out[(method, r.path)] = route_scopes(r)
    return out


def test_every_route_declares_a_scope_and_the_table_names_every_route(tmp_path):
    guarded, _ = _app(tmp_path)
    declared = _declared(guarded)
    assert all(v is not None for v in declared.values()), [k for k, v in declared.items() if v is None]
    assert declared == ROUTE_SCOPES
    # The only other routes: /mcp (the guard checks its scope) and nothing else.
    others = [r.path for r in guarded.app.routes if not isinstance(r, APIRoute)]
    assert others == ["/mcp"] and all(isinstance(r, (APIRoute, Route)) for r in guarded.app.routes)


def test_every_scope_is_used_or_reserved():
    used = {s for scopes in ROUTE_SCOPES.values() for s in scopes} | {"mcp"}
    assert set(SCOPES) - used == {"calendar:write"}


def test_each_app_has_exactly_its_scopes():
    assert {app: set(s) for app, s in APP_SCOPES.items()} == EXPECTED_SCOPES
    assert set(LIFETIME_APPS) == {"mydata", "cli"}
    assert "contacts:write" in APP_SCOPES["mycontacts"]  # editing contacts, phase 3
    assert "contacts:write" not in APP_SCOPES["mycalendar"] and "contacts:write" not in APP_SCOPES["myassistant"]
    assert {a for a in APPS if "contacts:import" in APP_SCOPES[a]} == {"mydata", "cli"}


def _call(c: TestClient, method: str, path: str, token: str):
    concrete = re.sub(r"\{[^}]+\}", "x", path)
    # No body and no query: a route the token may use answers 422, 404 or the like, never 403, and runs
    # nothing that needs a body.
    return c.request(method, concrete, headers={"Authorization": f"Bearer {token}"})


@pytest.mark.parametrize("app", APPS)
def test_each_app_token_reaches_exactly_its_routes(tmp_path, app):
    guarded, spy = _app(tmp_path)
    expected = {k for k, scopes in ROUTE_SCOPES.items() if set(scopes) & EXPECTED_SCOPES[app]}
    reached, refused = set(), set()
    with TestClient(guarded, base_url="http://127.0.0.1", raise_server_exceptions=False) as c:
        for (method, path) in ROUTE_SCOPES:
            r = _call(c, method, path, TOKENS[app])
            if r.status_code == 403:
                refused.add((method, path))
                detail = r.json()["detail"]
                assert detail == "only the myData app can stop the host" if path == "/shutdown" else \
                    detail.startswith(f"the {app} app cannot use this"), detail
            else:
                reached.add((method, path))
        mcp = c.post("/mcp", headers={"Authorization": f"Bearer {TOKENS[app]}"},
                     json={"jsonrpc": "2.0", "id": 1, "method": "tools/list"})
    assert reached == expected, (app, sorted(reached ^ expected))
    assert refused == set(ROUTE_SCOPES) - expected
    assert (mcp.status_code == 403) == ("mcp" not in EXPECTED_SCOPES[app]), (app, mcp.status_code)
    assert spy.calls == []


def test_only_the_apps_that_approve_see_held_calls(tmp_path):
    """myContacts and myCalendar cannot list, read or decide approvals; myAssistant and myData can."""
    guarded, _ = _app(tmp_path)
    with TestClient(guarded, base_url="http://127.0.0.1") as c:
        for app in APPS:
            r = c.get("/approvals", headers={"Authorization": f"Bearer {TOKENS[app]}"})
            assert (r.status_code == 200) == (app in ("mydata", "myassistant", "cli")), app


def test_the_host_refuses_to_start_with_a_route_without_a_scope(tmp_path, monkeypatch):
    original = api._routes_mac

    def with_an_open_route(app, need):
        original(app, need)

        @app.get("/open")
        def open_route() -> dict:
            return {}

    monkeypatch.setattr(api, "_routes_mac", with_an_open_route)
    with pytest.raises(RuntimeError, match="routes without a scope: \\['/open'\\]"):
        _app(tmp_path)


def test_a_scope_must_exist():
    with pytest.raises(ValueError):
        api.Needs("contacts:delete")
    with pytest.raises(ValueError):
        api.Needs()


def test_agent_tokens_have_no_scopes(tmp_path):
    store = AgentStore(tmp_path)
    _, token = store.create("helper")
    principal = Authenticator({}, store)(token.encode())
    assert principal.kind == "agent" and principal.scopes == frozenset()
