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
                                 "/approvals/{approval_id}", "/tools", "/agents", "/agents/{agent_id}"}
