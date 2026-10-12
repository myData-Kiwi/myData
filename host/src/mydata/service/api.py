"""The host's HTTP API. Bound to localhost; every request needs the token (security.GuardMiddleware).

  GET  /status                 host version, model state and download progress
  POST /assistant/messages     one user message; the reply streams as server-sent events
  GET  /approvals              approvals, optionally filtered by status
  GET  /approvals/{id}         one approval
  POST /approvals/{id}         approve or reject; approving runs exactly the held call, once
  PUT  /assistant/settings     switch the assistant on or off
  POST /shutdown               stop the host (the myData app and the mydata command only)
  GET  /tools                  the tool registry
  GET  /agents                 agent tokens (never the tokens themselves), and which are connected
  POST /agents                 create an agent token; the token is returned once
  DELETE /agents/{id}          revoke an agent token
  /mcp                         MCP (Streamable HTTP) over the same registry and gate

App tokens can use every route. Agent tokens can use only /mcp (security.GuardMiddleware).
"""

from __future__ import annotations

import asyncio
import json
import os
import threading
import time
from contextlib import asynccontextmanager
from typing import Any, Callable, Literal

import psutil

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from starlette.routing import Route

from .. import __version__
from ..tools import ApprovalError, Registry
from .assistant import Assistant
from .auth import Authenticator
from .logs import LAST_ERROR
from .state import HostState
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
    state: Literal["starting", "ollama_starting", "ollama_missing", "pulling", "loading", "ready", "error",
                   "disabled"]
    loaded: bool
    progress: Progress | None = None
    error: str | None = None
    ollama_reachable: bool
    ollama_started_by_host: bool


class MemoryOut(BaseModel):
    host_bytes: int = Field(description="memory the host process uses")
    model_bytes: int | None = Field(default=None, description="memory the loaded model uses in Ollama")


class ErrorOut(BaseModel):
    at: str
    message: str
    logger: str


class StatusOut(BaseModel):
    version: str
    ready: bool = Field(description="true when the assistant can answer")
    assistant_enabled: bool = Field(description="false when the user switched the assistant off")
    memory: MemoryOut
    last_error: ErrorOut | None = None
    uptime_seconds: float
    model: ModelOut
    agents_connected: int = Field(description="agent tokens used in the last five minutes")
    today: str = Field(description="the date the host treats as today")
    demo_date: bool = Field(description="true while today is pinned to the demo data's date")


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
    decided_by: str | None = Field(default=None, description="which app decided, e.g. app:myassistant")
    result: Any = None
    error: str | None = None
    context: dict[str, Any] = {}


class AssistantSettingsIn(BaseModel):
    enabled: bool


class DecisionIn(BaseModel):
    decision: Literal["approve", "reject"]


class AgentOut(BaseModel):
    id: str
    name: str
    created_at: str
    revoked: bool
    revoked_at: str | None = None
    last_seen_at: str | None = None
    connected: bool


class AgentIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)


class AgentCreated(AgentOut):
    token: str = Field(description="shown once; give it to the agent as its bearer token for /mcp")


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


def create_app(auth: Authenticator, registry: Registry, models: ModelManager, assistant: Assistant,
               state: HostState | None = None, shutdown: Callable[[], None] | None = None):
    """The ASGI app: FastAPI routes plus /mcp, wrapped in the token and Host checks."""
    started = time.time()
    session_manager = build_mcp(registry)

    @asynccontextmanager
    async def lifespan(_app):
        async with session_manager.run():
            yield

    app = FastAPI(title="myData host", version=__version__, lifespan=lifespan, docs_url=None, redoc_url=None,
                  # operation ids = function names, so the generated client reads status(), decide(), ...
                  generate_unique_id_function=lambda route: route.name,
                  description="Local API of the myData host. Listens on localhost only; every request needs "
                              "`Authorization: Bearer <token>` from the token file in the host's folder.")

    @app.get("/status", tags=["host"], response_model=StatusOut)
    def status() -> StatusOut:
        m = models.status()
        return StatusOut(version=__version__, ready=m.state == "ready", assistant_enabled=models.enabled,
                         memory=MemoryOut(host_bytes=psutil.Process(os.getpid()).memory_info().rss,
                                          model_bytes=models.model_bytes() if m.state == "ready" else None),
                         last_error=ErrorOut(**LAST_ERROR.last) if LAST_ERROR.last else None,
                         uptime_seconds=round(time.time() - started, 1),
                         model=ModelOut(**m.to_json()),
                         agents_connected=sum(a["connected"] for a in auth.agents.list()),
                         today=assistant.today().isoformat(), demo_date=assistant.settings.pin_today is not None)

    @app.post("/model/retry", tags=["host"], response_model=StatusOut)
    def retry() -> StatusOut:
        """Try again to get the model ready (after an error, or once Ollama is installed)."""
        models.retry()
        return status()

    @app.post("/assistant/messages", tags=["assistant"], response_class=StreamingResponse,
              responses={200: {"content": {"text/event-stream": {"schema": {"type": "string"}}},
                               "description": SSE_DESCRIPTION},
                         503: {"description": "the model is not ready yet; see GET /status"}})
    async def messages(body: MessageIn):
        if not models.enabled:
            raise HTTPException(503, "the assistant is switched off; switch it on in the myData app")
        if not models.ready():
            raise HTTPException(503, "the model is not ready yet; see GET /status")
        return StreamingResponse(_sse(assistant, body.text, body.conversation_id), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

    @app.put("/assistant/settings", tags=["assistant"], response_model=StatusOut)
    def assistant_settings(body: AssistantSettingsIn) -> StatusOut:
        """Switch the assistant on (the model is prepared, downloading it if needed) or off (nothing is
        downloaded or loaded; the rest of myData works without it)."""
        if state is not None:
            state.set_assistant_enabled(body.enabled)
        models.set_enabled(body.enabled)
        return status()

    @app.post("/shutdown", tags=["host"], status_code=202, responses={403: {"description": "only the myData app can stop the host"}})
    def shutdown_host(request: Request) -> dict:
        """Stop the host. Only the myData app (which owns the host's lifetime) and the mydata command may."""
        if request.state.principal.label not in ("app:mydata", "app:cli"):
            raise HTTPException(403, "only the myData app can stop the host")
        if shutdown is not None:
            threading.Timer(0.2, shutdown).start()  # after this response is sent
        return {"stopping": True}

    @app.get("/approvals", tags=["approvals"], response_model=list[ApprovalOut])
    def approvals(status: Literal["pending", "approved", "rejected", "failed"] | None = None) -> list[ApprovalOut]:
        return [ApprovalOut(**a.to_json()) for a in registry.approvals(status)]

    @app.get("/approvals/{approval_id}", tags=["approvals"], response_model=ApprovalOut, responses={404: {"description": "no such approval"}})
    def approval(approval_id: str) -> ApprovalOut:
        a = registry.approval(approval_id)
        if a is None:
            raise HTTPException(404, "no such approval")
        return ApprovalOut(**a.to_json())

    @app.post("/approvals/{approval_id}", tags=["approvals"], response_model=ApprovalOut,
              responses={404: {"description": "no such approval"}, 409: {"description": "already decided"}})
    def decide(approval_id: str, body: DecisionIn, request: Request) -> ApprovalOut:
        try:
            a = registry.decide(approval_id, body.decision == "approve", decided_by=request.state.principal.label)
        except ApprovalError as e:
            code = 404 if "no such" in str(e) else 409
            raise HTTPException(code, str(e)) from None
        assistant.note_decision(a)
        return ApprovalOut(**a.to_json())

    @app.get("/tools", tags=["tools"], response_model=list[ToolOut])
    def tools() -> list[ToolOut]:
        return [ToolOut(**t) for t in registry.describe()]

    @app.get("/agents", tags=["agents"], response_model=list[AgentOut])
    def agents() -> list[AgentOut]:
        return [AgentOut(**a) for a in auth.agents.list()]

    @app.post("/agents", tags=["agents"], response_model=AgentCreated, status_code=201)
    def create_agent(body: AgentIn) -> AgentCreated:
        try:
            agent, token = auth.agents.create(body.name)
        except ValueError as e:
            raise HTTPException(422, str(e)) from None
        return AgentCreated(**agent.public(None), token=token)

    @app.delete("/agents/{agent_id}", tags=["agents"], response_model=AgentOut, responses={404: {"description": "no such agent"}})
    def revoke_agent(agent_id: str) -> AgentOut:
        try:
            agent = auth.agents.revoke(agent_id)
        except KeyError as e:
            raise HTTPException(404, str(e)) from None
        return AgentOut(**agent.public(None))

    app.router.routes.append(Route("/mcp", endpoint=_mcp_endpoint(session_manager)))
    app.state.session_manager = session_manager
    return GuardMiddleware(app, auth)


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
