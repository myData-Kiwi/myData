"""The committed OpenAPI document (host/openapi.json), generated from the app itself.

Regenerate with `uv run mydata openapi --out openapi.json`; tests/test_openapi.py fails if it is stale.
The Dart client in app/ is generated from this file.
"""

from __future__ import annotations

from pathlib import Path

from ..tools import default_registry
from .api import create_app
from .auth import AgentStore, Authenticator
from .assistant import Assistant
from .config import Settings
from .model import ModelManager


def openapi_document() -> dict:
    settings = Settings(home=Path("/nonexistent"))
    registry = default_registry()
    auth = Authenticator({"mydata": "x" * 43}, AgentStore(Path("/nonexistent")))
    guarded = create_app(auth, registry, ModelManager(settings), Assistant(settings, registry))
    doc = guarded.app.openapi()
    doc["components"].setdefault("securitySchemes", {})["bearer"] = {"type": "http", "scheme": "bearer"}
    doc["security"] = [{"bearer": []}]
    # Every route also answers 401 (no or wrong token) and 421 (Host is not this machine), from the guard.
    doc["components"]["schemas"]["GuardError"] = {"type": "object", "properties": {"detail": {"type": "string"}},
                                                  "required": ["detail"], "title": "GuardError"}
    err = {"application/json": {"schema": {"$ref": "#/components/schemas/GuardError"}}}
    for item in doc["paths"].values():
        for op in item.values():
            op["responses"].setdefault("401", {"description": "missing or wrong token", "content": err})
            op["responses"].setdefault("403", {"description": "agent tokens can only use /mcp", "content": err})
            op["responses"].setdefault("421", {"description": "the Host header is not this machine", "content": err})
    doc["servers"] = [{"url": "http://127.0.0.1:47821", "description": "this machine only"}]
    # FastAPI's validation error says a location item is "string or integer"; the Dart generator cannot
    # express that union, so the published spec leaves the item type open.
    loc = doc["components"]["schemas"].get("ValidationError", {}).get("properties", {}).get("loc")
    if loc:
        loc["items"] = {}
    return doc
