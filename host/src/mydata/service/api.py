"""The host's HTTP API. Bound to localhost; every request needs the token (security.GuardMiddleware).

  GET  /status                 host version, model state and download progress
  POST /assistant/messages     one user message; the reply streams as server-sent events
  GET  /approvals              approvals, optionally filtered by status
  GET  /approvals/{id}         one approval
  POST /approvals/{id}         approve or reject; approving runs exactly the held call, once
  PUT  /assistant/settings     switch the assistant on or off
  GET  /appearance             the theme every app uses, and the themes to choose from
  PUT  /appearance             set the theme every app uses (light or dark mode is per device, not here)
  POST /shutdown               stop the host (the myData app and the mydata command only)
  GET  /tools                  the tool registry
  GET  /agents                 agent tokens (never the tokens themselves), and which are connected
  POST /agents                 create an agent token; the token is returned once
  DELETE /agents/{id}          revoke an agent token
  GET  /accounts               linked accounts (never a password)
  POST /accounts               link an account; the password is verified with the provider first
  DELETE /accounts/{id}        unlink an account; its mirrored data and its Keychain item are deleted
  POST /accounts/{id}/sync     sync the account now
  GET  /sync                   the mode (demo or real) and every account's sync status
  GET  /contacts               mirrored contacts, listed or searched
  GET  /contacts/{id}          one contact (the raw vCard only with ?raw=1)
  GET  /calendars              mirrored calendars
  GET  /events                 events between two dates, recurring ones expanded
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
from datetime import date, datetime, time as dtime, timedelta
from typing import Any, Callable, Literal

import psutil

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field, SecretStr
from starlette.routing import Route

from .. import __version__
from ..tools import ApprovalError, Registry
from .appearance import DEFAULT_THEME, THEME_IDS, THEMES
from .assistant import Assistant
from .auth import Authenticator
from .logs import LAST_ERROR
from .state import HostState
from .mcp import build_mcp
from .model import ModelManager
from .security import GuardMiddleware
from .sync import SyncService

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
    theme: str = Field(description="the theme every app uses; mode is per device and not stored here")
    mode: Literal["demo", "real"] = Field(description="demo: no linked account, the tools serve fake data and "
                                                      "the date is pinned; real: the tools serve the linked "
                                                      "accounts' mirrored data, with the real date")


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


class ThemeOut(BaseModel):
    id: str
    name: str


class AppearanceOut(BaseModel):
    theme: str = Field(description="the theme every app uses; mode is per device and not stored here")
    themes: list[ThemeOut] = Field(description="every theme, in the order to show them")
    chosen: bool = Field(description="false until someone has chosen a theme; first run offers the choice")


class AppearanceIn(BaseModel):
    theme: str = Field(description="a theme id from GET /appearance")


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


# ---------------------------------------------------------------- sources: accounts, sync, contacts, calendars


class AccountIn(BaseModel):
    provider: Literal["icloud"]
    email: str = Field(min_length=3, max_length=254, description="the account's email address (Apple Account)")
    password: SecretStr = Field(min_length=1, max_length=256,
                                description="an app-specific password. Verified with the provider, then kept only "
                                            "in the Keychain; never returned, logged or written to a file")


class AccountOut(BaseModel):
    id: str
    provider: str
    email: str
    created_at: str
    label: str


class SyncCounts(BaseModel):
    address_books: int = 0
    contacts: int = 0
    calendars: int = 0
    events: int = 0


class AccountSyncOut(BaseModel):
    account_id: str
    state: Literal["idle", "syncing", "error"]
    last_success: str | None = None
    last_error: str | None = Field(default=None, description="a short message for the user; never a secret")
    last_attempt: str | None = None
    next_attempt: str | None = None
    counts: SyncCounts


class SyncOut(BaseModel):
    mode: Literal["demo", "real"]
    accounts: list[AccountSyncOut]


class LabeledValue(BaseModel):
    value: str
    label: str = ""


class PostalAddress(BaseModel):
    label: str = ""
    street: str = ""
    locality: str = ""
    region: str = ""
    postal_code: str = ""
    country: str = ""


class ContactOut(BaseModel):
    id: str
    account_id: str
    address_book_id: str
    display_name: str = Field(description="the name to show: never empty (organisation, email or phone when "
                                          "the card has no name)")
    full_name: str = ""
    given_name: str = ""
    family_name: str = ""
    nickname: str = ""
    organisation: str = ""
    emails: list[LabeledValue] = []
    phones: list[LabeledValue] = []
    addresses: list[PostalAddress] = []
    birthday: str | None = None
    note: str = ""
    has_photo: bool = False
    created_at: str
    modified_at: str
    deleted_at: str | None = None


class ContactDetailOut(ContactOut):
    raw_vcard: str | None = Field(default=None, description="the card as the server sent it; only with ?raw=1")


class CalendarOut(BaseModel):
    id: str
    account_id: str
    name: str
    color: str | None = None


class EventOut(BaseModel):
    event_id: str
    calendar_id: str
    uid: str
    recurrence_id: str | None = None
    title: str
    location: str = ""
    notes: str = ""
    start: str = Field(description="ISO date-time in the host's time zone, or YYYY-MM-DD for an all-day event")
    end: str = Field(description="as start; an all-day event's end is the day after its last day (exclusive)")
    all_day: bool
    time_zone: str | None = Field(default=None, description="the event's own zone; none for all-day events")


MAX_EVENT_DAYS = 400


SSE_DESCRIPTION = """Server-sent events, one JSON object per `data:` line, `event:` naming the type:
`conversation` {conversation_id}, `progress` {tool, label}, `result` {tool, kind, header, items}, `delta` {text},
`step` {}, `pending_approval` {approval}, `clarify` {options, text}, `message` {text, outcome, by}, `error`
{message}, `done` {}. A `result` is a tool's result, sent the moment the tool returns, with a header written by
code; kind is events, mail, contacts, photos or event_created. `delta` text is provisional: on `step` discard
what has streamed so far; `message.text` is the reply, and `message.by` is "code" when the shown result was the
answer (its text is then the result's header) or "model" for a sentence the model wrote."""


# ---------------------------------------------------------------- app


def create_app(auth: Authenticator, registry: Registry, models: ModelManager, assistant: Assistant,
               state: HostState | None = None, shutdown: Callable[[], None] | None = None,
               sources: SyncService | None = None):
    """The ASGI app: FastAPI routes plus /mcp, wrapped in the token and Host checks. Without `sources`
    (the OpenAPI document, older tests) the account and mirror routes answer 503."""
    started = time.time()
    session_manager = build_mcp(registry)
    # Without a state file (the OpenAPI document), the theme lives in memory only.
    no_state = {"theme": DEFAULT_THEME, "chosen": False}

    def current_theme() -> str:
        return state.theme if state is not None else no_state["theme"]

    def current_mode() -> str:
        return "real" if registry.mode == "real" else "demo"

    def need_sources() -> SyncService:
        if sources is None:
            raise HTTPException(503, "accounts are not available in this host")
        return sources

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
                         today=assistant.today().isoformat(),
                         demo_date=registry.mode == "demo" and assistant.settings.pin_today is not None,
                         theme=current_theme(), mode=current_mode())

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

    def appearance_out() -> AppearanceOut:
        chosen = state.theme_chosen if state is not None else no_state["chosen"]
        return AppearanceOut(theme=current_theme(), themes=[ThemeOut(id=i, name=n) for i, n in THEMES],
                             chosen=chosen)

    @app.get("/appearance", tags=["appearance"], response_model=AppearanceOut)
    def appearance() -> AppearanceOut:
        """The theme every app uses, and the themes to choose from. Light or dark mode is per device."""
        return appearance_out()

    @app.put("/appearance", tags=["appearance"], response_model=AppearanceOut,
             responses={400: {"description": "no such theme"}})
    def set_appearance(body: AppearanceIn) -> AppearanceOut:
        """Set the theme every app uses. Apps follow the change through GET /status."""
        if body.theme not in THEME_IDS:
            raise HTTPException(400, f"no such theme: {body.theme}; choose one of {', '.join(THEME_IDS)}")
        if state is not None:
            state.set_theme(body.theme)
        else:
            no_state["theme"] = body.theme
            no_state["chosen"] = True
        return appearance_out()

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

    @app.exception_handler(RequestValidationError)
    async def validation_error(_request: Request, exc: RequestValidationError) -> JSONResponse:
        """FastAPI's 422, without the submitted values: a rejected body can hold a password."""
        errors = [{k: v for k, v in e.items() if k != "input"} for e in exc.errors()]
        return JSONResponse(status_code=422, content={"detail": jsonable_encoder(errors)})

    _routes_sources(app, need_sources, current_mode)
    app.router.routes.append(Route("/mcp", endpoint=_mcp_endpoint(session_manager)))
    app.state.session_manager = session_manager
    return GuardMiddleware(app, auth)


def _routes_sources(app: FastAPI, need: Callable[[], SyncService], current_mode: Callable[[], str]) -> None:
    """Accounts, sync status and the mirrored contacts and calendars. App tokens only (the guard keeps agent
    tokens to /mcp)."""
    from ..sources.providers import VerificationError
    from ..sources.secrets import SecretStoreError
    unavailable = {503: {"description": "accounts are not available in this host"}}

    @app.get("/accounts", tags=["sources"], response_model=list[AccountOut], responses=unavailable)
    def accounts() -> list[AccountOut]:
        """Linked accounts. Passwords are never returned."""
        return [AccountOut(**a.public()) for a in need().accounts.list()]

    @app.post("/accounts", tags=["sources"], response_model=AccountOut, status_code=201,
              responses={400: {"description": "the provider did not accept the details, or the account is "
                                              "already linked; the message says which"}, **unavailable})
    def add_account(body: AccountIn) -> AccountOut:
        """Link an account. The provider checks the email and password first (discovery); nothing is stored
        unless that succeeds. Then the host mirrors its contacts and calendars, read-only, and switches to
        real mode."""
        service = need()
        try:
            account = service.add_account(body.provider, body.email, body.password.get_secret_value())
        except (ValueError, VerificationError) as e:
            raise HTTPException(400, str(e)) from None
        except SecretStoreError as e:
            raise HTTPException(503, f"{e}. Nothing was stored.") from None
        return AccountOut(**account.public())

    @app.delete("/accounts/{account_id}", tags=["sources"], response_model=AccountOut,
                responses={404: {"description": "no such account"}, **unavailable})
    def remove_account(account_id: str) -> AccountOut:
        """Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Nothing
        changes at the provider. With no account left the host returns to demo mode."""
        service = need()
        try:
            account = service.remove_account(account_id)
        except KeyError:
            raise HTTPException(404, "no such account") from None
        except SecretStoreError as e:
            raise HTTPException(503, str(e)) from None
        return AccountOut(**account.public())

    @app.post("/accounts/{account_id}/sync", tags=["sources"], response_model=AccountSyncOut, status_code=202,
              responses={404: {"description": "no such account"}, **unavailable})
    def sync_account(account_id: str) -> AccountSyncOut:
        """Sync now: the account is synced next, in the background. Follow it with GET /sync."""
        try:
            return AccountSyncOut(**need().request_sync(account_id))
        except KeyError:
            raise HTTPException(404, "no such account") from None

    @app.get("/sync", tags=["sources"], response_model=SyncOut)
    def sync_status() -> SyncOut:
        """The mode, and each account's sync status."""
        return SyncOut(mode=current_mode(), accounts=[AccountSyncOut(**r) for r in _status_rows(need)])

    @app.get("/contacts", tags=["sources"], response_model=list[ContactOut], responses=unavailable)
    def contacts(query: str | None = Query(default=None, max_length=200,
                                           description="search names, organisation, emails and phones"),
                 limit: int = Query(default=100, ge=1, le=1000), offset: int = Query(default=0, ge=0)
                 ) -> list[ContactOut]:
        """Mirrored contacts by name, or the ones matching `query` (every word, as a prefix)."""
        store = need().contacts
        if query and query.strip():
            rows = store.search(query, limit=limit + offset)[offset:]
        else:
            rows = store.list(limit=limit, offset=offset)
        return [ContactOut(**r) for r in rows]

    @app.get("/contacts/{contact_id}", tags=["sources"], response_model=ContactDetailOut,
             responses={404: {"description": "no such contact"}, **unavailable})
    def contact(contact_id: str, raw: bool = Query(default=False, description="include the raw vCard")
                ) -> ContactDetailOut:
        row = need().contacts.get(contact_id)
        if row is None:
            raise HTTPException(404, "no such contact")
        if not raw:
            row.pop("raw_vcard", None)
        return ContactDetailOut(**row)

    @app.get("/calendars", tags=["sources"], response_model=list[CalendarOut], responses=unavailable)
    def calendars() -> list[CalendarOut]:
        return [CalendarOut(**c) for c in need().calendar.calendars()]

    @app.get("/events", tags=["sources"], response_model=list[EventOut],
             responses={400: {"description": "end is before start, or the range is too long"}, **unavailable})
    def events(start: date = Query(description="first day, YYYY-MM-DD"),
               end: date = Query(description="last day, YYYY-MM-DD (included)"),
               calendar: list[str] | None = Query(default=None, description="calendar ids; repeat for several. "
                                                                             "Omit for every calendar")
               ) -> list[EventOut]:
        """Events overlapping the days from start to end (both included), in the host's time zone, with
        recurring events expanded into occurrences."""
        from ..sources.ical import local_timezone
        if end < start:
            raise HTTPException(400, "end is before start")
        if (end - start).days >= MAX_EVENT_DAYS:
            raise HTTPException(400, f"ask for at most {MAX_EVENT_DAYS} days at a time")
        tz = local_timezone()
        rows = need().calendar.events_between(datetime.combine(start, dtime.min, tzinfo=tz),
                                              datetime.combine(end + timedelta(days=1), dtime.min, tzinfo=tz),
                                              calendar_ids=calendar, tz=tz)
        return [EventOut(**r) for r in rows]


def _status_rows(need: Callable[[], SyncService]) -> list[dict]:
    try:
        service = need()
    except HTTPException:
        return []
    return service.status()


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
