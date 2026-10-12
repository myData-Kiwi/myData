"""The host's HTTP API. Bound to localhost; every request needs the token (security.GuardMiddleware).

  GET  /status                 host version, model state and download progress
  POST /assistant/messages     one user message; the reply streams as server-sent events
  GET  /approvals              approvals, optionally filtered by status
  GET  /approvals/{id}         one approval
  POST /approvals/{id}         approve or reject; approving runs exactly the held call, once
  GET  /tools                  the tool registry
  /mcp                         MCP (Streamable HTTP) over the same registry and gate
"""

from __future__ import annotations

import asyncio
import json
import threading
import time
from contextlib import asynccontextmanager
from typing import Any, Literal

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from starlette.routing import Route

from .. import __version__
from ..tools import ApprovalError, Registry
from .assistant import Assistant
from .mcp import build_mcp
from .model import ModelManager
from .security import GuardMiddleware

# ---------------------------------------------------------------- schemas


class Progress(BaseModel):
    status: str
    completed: int
    total: int
    percent: float


class ModelOut(BaseModel):
    name: str
    state: Literal["starting", "ollama_starting", "ollama_missing", "pulling", "loading", "ready", "error"]
    loaded: bool
    progress: Progress | None = None
    error: str | None = None
    ollama_reachable: bool
    ollama_started_by_host: bool


class StatusOut(BaseModel):
    version: str
    ready: bool = Field(description="true when the assistant can answer")
    uptime_seconds: float
    model: ModelOut


class MessageIn(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    conversation_id: str | None = Field(default=None, description="omit to start a new conversation")


class ApprovalOut(BaseModel):
    id: str
    tool: str
    args: dict[str, Any] = Field(description="exactly what will run if approved")
    summary: str
    caller: str
    created_at: str
    status: Literal["pending", "approved", "rejected", "failed"]
    decided_at: str | None = None
    result: Any = None
    error: str | None = None
    context: dict[str, Any] = {}


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]


class ToolOut(BaseModel):
    name: str
    description: str
    input_schema: dict[str, Any]
    permission: Literal["read", "reversible", "irreversible"]


SSE_DESCRIPTION = """Server-sent events, one JSON object per `data:` line, `event:` naming the type:
`conversation` {conversation_id}, `progress` {tool, label}, `delta` {text}, `step` {},
`pending_approval` {approval}, `clarify` {options, text}, `message` {text, outcome}, `error` {message}, `done` {}.
`delta` text is provisional: on `step` discard what has streamed so far; `message.text` is the reply."""


# ---------------------------------------------------------------- app


def create_app(token: str, registry: Registry, models: ModelManager, assistant: Assistant):
    """The ASGI app: FastAPI routes plus /mcp, wrapped in the token and Host checks."""
    started = time.time()
    session_manager = build_mcp(registry)

    @asynccontextmanager
    async def lifespan(_app):
        async with session_manager.run():
            yield

    app = FastAPI(title="myData host", version=__version__, lifespan=lifespan, docs_url=None, redoc_url=None,
                  description="Local API of the myData host. Listens on localhost only; every request needs "
                              "`Authorization: Bearer <token>` from the token file in the host's folder.")

    @app.get("/status", response_model=StatusOut)
    def status() -> StatusOut:
        m = models.status()
        return StatusOut(version=__version__, ready=m.state == "ready", uptime_seconds=round(time.time() - started, 1),
                         model=ModelOut(**m.to_json()))

    @app.post("/model/retry", response_model=StatusOut)
    def retry() -> StatusOut:
        """Try again to get the model ready (after an error, or once Ollama is installed)."""
        models.retry()
        return status()

    @app.post("/assistant/messages", response_class=StreamingResponse,
              responses={200: {"content": {"text/event-stream": {"schema": {"type": "string"}}},
                               "description": SSE_DESCRIPTION},
                         503: {"description": "the model is not ready yet; see GET /status"}})
    async def messages(body: MessageIn):
        if not models.ready():
            raise HTTPException(503, "the model is not ready yet; see GET /status")
        return StreamingResponse(_sse(assistant, body.text, body.conversation_id), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

    @app.get("/approvals", response_model=list[ApprovalOut])
    def approvals(status: Literal["pending", "approved", "rejected", "failed"] | None = None) -> list[ApprovalOut]:
        return [ApprovalOut(**a.to_json()) for a in registry.approvals(status)]

    @app.get("/approvals/{approval_id}", response_model=ApprovalOut, responses={404: {"description": "no such approval"}})
    def approval(approval_id: str) -> ApprovalOut:
        a = registry.approval(approval_id)
        if a is None:
            raise HTTPException(404, "no such approval")
        return ApprovalOut(**a.to_json())

    @app.post("/approvals/{approval_id}", response_model=ApprovalOut,
              responses={404: {"description": "no such approval"}, 409: {"description": "already decided"}})
    def decide(approval_id: str, body: DecisionIn) -> ApprovalOut:
        try:
            a = registry.decide(approval_id, body.decision == "approve", decided_by="user")
        except ApprovalError as e:
            code = 404 if "no such" in str(e) else 409
            raise HTTPException(code, str(e)) from None
        assistant.note_decision(a)
        return ApprovalOut(**a.to_json())

    @app.get("/tools", response_model=list[ToolOut])
    def tools() -> list[ToolOut]:
        return [ToolOut(**t) for t in registry.describe()]

    app.router.routes.append(Route("/mcp", endpoint=_mcp_endpoint(session_manager)))
    app.state.session_manager = session_manager
    return GuardMiddleware(app, token)


def _mcp_endpoint(session_manager):
    async def endpoint(scope, receive, send):
        await session_manager.handle_request(scope, receive, send)
    # A class instance would be treated as a raw ASGI app; wrap the function the same way.
    return _ASGI(endpoint)


class _ASGI:
    def __init__(self, fn):
        self.fn = fn

    async def __call__(self, scope, receive, send):
        await self.fn(scope, receive, send)


async def _sse(assistant: Assistant, text: str, conversation_id: str | None):
    """Run the blocking assistant in a thread and forward its events as SSE."""
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue()
    done = object()

    def work() -> None:
        try:
            for event in assistant.reply(text, conversation_id):
                loop.call_soon_threadsafe(queue.put_nowait, event)
        except Exception as e:  # never leave the stream hanging
            loop.call_soon_threadsafe(queue.put_nowait, {"type": "error", "message": f"{type(e).__name__}: {e}"})
            loop.call_soon_threadsafe(queue.put_nowait, {"type": "done"})
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, done)

    threading.Thread(target=work, name="sse", daemon=True).start()
    while True:
        event = await queue.get()
        if event is done:
            return
        kind = event.pop("type")
        yield f"event: {kind}\ndata: {json.dumps(event, ensure_ascii=False, default=str)}\n\n"
