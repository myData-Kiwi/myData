"""The account, sync, contacts and calendar routes: app tokens only, plain 400s, and the password is never
echoed, logged or stored outside the secret store. Invented data only (tests/fake_dav)."""

from __future__ import annotations

import json

import pytest
from starlette.testclient import TestClient

import fake_dav
from fake_dav import FakeDav
from mydata.service.auth import AgentStore

from service_helpers import Host, make_app

SOURCE_ROUTES = [("GET", "/accounts"), ("POST", "/accounts"), ("DELETE", "/accounts/x"), ("POST", "/accounts/x/sync"),
                 ("GET", "/sync"), ("GET", "/contacts"), ("GET", "/contacts/x"), ("GET", "/calendars"),
                 ("GET", "/events?start=2026-03-01&end=2026-03-02"), ("GET", "/contacts/x/photo"), ("GET", "/sources"),
                 ("PUT", "/sources/mac"), ("POST", "/sources/mac/request-access"), ("POST", "/sources/mac/sync"),
                 ("PUT", "/sources/mac/reader")]
BODY = {"provider": "icloud", "email": fake_dav.USERNAME, "password": fake_dav.PASSWORD}


@pytest.fixture
def host(tmp_path):
    return Host(tmp_path, FakeDav())


def client(host) -> TestClient:
    return TestClient(host.app, base_url="http://127.0.0.1")


def test_agent_tokens_never_reach_the_source_routes(host):
    _agent, token = AgentStore(host.home).create("some agent")
    with client(host) as c:
        for method, path in SOURCE_ROUTES:
            r = c.request(method, path, headers={"Authorization": f"Bearer {token}"},
                          json=BODY if method == "POST" else None)
            assert r.status_code == 403, (method, path)
            assert fake_dav.PASSWORD not in r.text
        r = c.get("/accounts", headers={"Authorization": "Bearer nope"})
        assert r.status_code == 401
    assert host.sources.accounts.list() == []


def test_a_rejected_password_is_a_plain_400_and_nothing_is_stored(host):
    with client(host) as c:
        r = c.post("/accounts", headers=host.auth, json={**BODY, "password": "wrong-invented-pw-zz"})
        assert r.status_code == 400
        assert r.json() == {"detail": "Apple did not accept this sign-in. Use the email of your Apple Account, which "
                                      "may differ from an address on your own domain, and an app-specific password "
                                      "made at account.apple.com."}
        assert c.get("/accounts", headers=host.auth).json() == []
        assert c.get("/status", headers=host.auth).json()["mode"] == "demo"
    assert host.secrets.keys() == [] and not (host.home / "accounts.json").exists()


def test_invalid_bodies_never_echo_the_password(host):
    secret = "invented-secret-not-to-echo"
    with client(host) as c:
        for body in ({"provider": "gmail", "email": "a@example.com", "password": secret},
                     {"provider": "icloud", "password": secret},
                     {"provider": "icloud", "email": "a@example.com", "password": secret * 20},
                     {"provider": "icloud", "email": "x", "password": secret}):
            r = c.post("/accounts", headers=host.auth, json=body)
            assert r.status_code == 422, body
            assert secret not in r.text
        r = c.post("/accounts", headers=host.auth, json={"provider": "icloud", "email": "not-an-address",
                                                          "password": secret})
        assert r.status_code == 400 and secret not in r.text
        r = c.post("/accounts", headers=host.auth, content=b'{"password": "' + secret.encode() + b'", ')
        assert r.status_code == 422 and secret not in r.text


def test_added_account_is_listed_without_its_password_anywhere(host, tmp_path):
    with client(host) as c:
        r = c.post("/accounts", headers=host.auth, json=BODY)
        assert r.status_code == 201
        account = r.json()
        assert set(account) == {"id", "provider", "email", "created_at", "label", "backups_kept_until"}
        assert c.get("/accounts", headers=host.auth).json() == [account]
        assert c.get("/status", headers=host.auth).json()["mode"] == "real"
        r = c.post(f"/accounts/{account['id']}/sync", headers=host.auth)
        assert r.status_code == 202 and r.json()["account_id"] == account["id"]
        texts = [c.get(p, headers=host.auth).text for p in ("/accounts", "/sync", "/status", "/tools")]
    assert all(fake_dav.PASSWORD not in t for t in texts)
    assert host.secrets.get(f"account:{account['id']}") == fake_dav.PASSWORD
    for path in tmp_path.rglob("*"):  # nothing the host wrote holds it: accounts.json, logs, tokens, state
        if path.is_file():
            assert fake_dav.PASSWORD.encode() not in path.read_bytes(), path


def test_not_found_and_bad_ranges(host):
    with client(host) as c:
        assert c.delete("/accounts/nope", headers=host.auth).status_code == 404
        assert c.post("/accounts/nope/sync", headers=host.auth).status_code == 404
        assert c.get("/contacts/nope", headers=host.auth).status_code == 404
        r = c.get("/events?start=2026-03-10&end=2026-03-09", headers=host.auth)
        assert r.status_code == 400 and r.json()["detail"] == "end is before start"
        assert c.get("/events?start=2026-01-01&end=2027-12-31", headers=host.auth).status_code == 400
        assert c.get("/events?start=2026-13-01&end=2026-03-09", headers=host.auth).status_code == 422
        assert c.get("/contacts?limit=0", headers=host.auth).status_code == 422
        # An empty mirror answers with empty lists, in either mode.
        assert c.get("/contacts", headers=host.auth).json() == []
        assert c.get("/calendars", headers=host.auth).json() == []
        assert c.get("/events?start=2026-03-01&end=2026-03-31", headers=host.auth).json() == {"events": [],
                                                                                              "coverage": []}
        assert c.get("/sync", headers=host.auth).json() == {"mode": "demo", "accounts": []}


def test_without_sources_the_routes_answer_503_and_sync_reports_demo(tmp_path):
    app, _, _ = make_app(tmp_path)
    with TestClient(app, base_url="http://127.0.0.1") as c:
        auth = {"Authorization": f"Bearer {'t' * 43}"}
        assert c.get("/accounts", headers=auth).status_code == 503
        assert c.get("/contacts", headers=auth).status_code == 503
        assert c.get("/sync", headers=auth).json() == {"mode": "demo", "accounts": []}
        status = c.get("/status", headers=auth).json()
        assert status["mode"] == "demo"


def test_validation_errors_still_say_what_is_wrong(host):
    with client(host) as c:
        r = c.post("/accounts", headers=host.auth, json={"provider": "icloud", "email": "a@example.com"})
    detail = r.json()["detail"]
    assert detail[0]["loc"] == ["body", "password"] and detail[0]["type"] == "missing"
    assert all("input" not in e for e in detail)
    json.dumps(detail)
