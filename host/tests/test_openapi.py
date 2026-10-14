"""host/openapi.json is generated from the app; the Dart client is generated from it. It must not go stale."""

import json
from pathlib import Path

from mydata.service.openapi import openapi_document

COMMITTED = Path(__file__).parent.parent / "openapi.json"


def test_committed_openapi_matches_the_app():
    assert json.loads(COMMITTED.read_text()) == json.loads(json.dumps(openapi_document())), \
        "openapi.json is stale: run `uv run mydata openapi --out openapi.json`"


def test_openapi_declares_bearer_auth_and_localhost_server():
    doc = openapi_document()
    assert doc["security"] == [{"bearer": []}]
    assert doc["servers"][0]["url"].startswith("http://127.0.0.1:")
    assert set(doc["paths"]) == {"/status", "/model/retry", "/assistant/messages", "/approvals",
                                 "/approvals/{approval_id}", "/tools", "/agents", "/agents/{agent_id}",
                                 "/assistant/settings", "/shutdown", "/appearance", "/accounts",
                                 "/accounts/{account_id}", "/accounts/{account_id}/sync", "/sync", "/contacts",
                                 "/contacts/{contact_id}", "/contacts/{contact_id}/photo", "/calendars", "/events",
                                 "/sources", "/sources/mac", "/sources/mac/request-access", "/sources/mac/sync",
                                 "/sources/mac/reader"}


def test_source_routes_are_tagged_and_the_password_is_write_only():
    doc = openapi_document()
    for path in ("/accounts", "/accounts/{account_id}", "/accounts/{account_id}/sync", "/sync", "/contacts",
                 "/contacts/{contact_id}", "/contacts/{contact_id}/photo", "/calendars", "/events", "/sources",
                 "/sources/mac", "/sources/mac/request-access", "/sources/mac/sync", "/sources/mac/reader"):
        for op in doc["paths"][path].values():
            assert op["tags"] == ["sources"], path
    password = doc["components"]["schemas"]["AccountIn"]["properties"]["password"]
    assert password.get("writeOnly") is True and password.get("format") == "password"
    for name, schema in doc["components"]["schemas"].items():
        if name != "AccountIn":
            assert "password" not in schema.get("properties", {}), f"{name} exposes a password field"
    assert "mode" in doc["components"]["schemas"]["StatusOut"]["required"]


def test_every_operation_names_its_scope():
    from mydata.service.auth import SCOPES
    doc = openapi_document()
    for path, item in doc["paths"].items():
        for method, op in item.items():
            assert op["x-mydata-scopes"] and set(op["x-mydata-scopes"]) <= set(SCOPES), (method, path)
    assert doc["paths"]["/approvals"]["get"]["x-mydata-scopes"] == ["approve"]
    assert doc["paths"]["/contacts"]["get"]["x-mydata-scopes"] == ["contacts:read"]
