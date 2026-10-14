"""Who is calling: app tokens and agent tokens.

- App tokens: one per app that acts for the user (the myData app, myAssistant, myContacts, myCalendar,
  the mydata command). The host creates them on start, each in its own file readable only by the user
  (<home>/app-tokens/<app>). Each app's token has scopes (APP_SCOPES), and every route declares the
  scope it needs (api.py): myContacts reads and edits contacts, myCalendar reads calendars, myAssistant
  talks to the assistant and approves, the myData app administers the host and imports contacts, and the
  mydata command can do everything. Approvals record which app decided; only the myData app and the
  mydata command may stop the host (POST /shutdown).
- Agent tokens: for MCP agents. Created, listed and revoked with `mydata agent ...` or from the
  myData app. Only their SHA-256 hash is stored (<home>/agents.json). An agent token reaches
  /mcp and nothing else: no approvals, no assistant, no status.

A known limit: any process running as the same user can read the app-token files (0600 keeps out other
users, not other programs of this one) and use the API with them. It is to be hardened before the host
sends mail (the owned-data plan, 2(f).4).
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import sys
import tempfile
import threading
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from .security import ensure_token

APPS = ("mydata", "myassistant", "mycontacts", "mycalendar", "cli")

# Every scope, and what it allows. Each route in api.py declares the one it needs; /mcp needs "mcp" from
# an app token (agent tokens reach /mcp only, and need no scope there).
SCOPES = {
    "status": "GET /status and GET /appearance: the host's state and the theme every app follows",
    "admin": "agent tokens, the theme, switching the assistant on or off, the tool list",
    "assistant": "talk to the assistant, and ask the host to get the model ready again",
    "approve": "list held calls and approve or reject them",
    "contacts:read": "the contacts the host holds",
    "contacts:write": "create, change, merge and delete the contacts the host owns, restore them, and undo those "
                      "changes",
    "contacts:import": "import contacts from a file or a followed account, read and undo imports (the myData app "
                       "and the command only: an import is done in one place, which keeps its history)",
    "calendar:read": "the calendars and events the host holds",
    "calendar:write": "change calendars and events (nothing uses it yet)",
    "sources:read": "the sources, linked accounts and their sync status",
    "sources:manage": "link and remove accounts, turn This Mac on or off, sync now",
    "shutdown": "stop the host",
    "mcp": "/mcp with an app token",
}

APP_SCOPES: dict[str, frozenset[str]] = {
    "mydata": frozenset({"status", "admin", "approve", "contacts:read", "contacts:write", "contacts:import",
                         "calendar:read", "calendar:write", "sources:read", "sources:manage", "shutdown", "mcp"}),
    "myassistant": frozenset({"status", "assistant", "approve", "contacts:read", "calendar:read"}),
    "mycontacts": frozenset({"status", "contacts:read", "contacts:write", "sources:read"}),
    "mycalendar": frozenset({"status", "calendar:read", "sources:read"}),
    "cli": frozenset(SCOPES),
}
assert set(APP_SCOPES) == set(APPS) and all(s <= set(SCOPES) for s in APP_SCOPES.values())

# The apps that own the host's lifetime: only they may stop it (POST /shutdown).
LIFETIME_APPS = tuple(a for a in APPS if "shutdown" in APP_SCOPES[a])
AGENT_PREFIX = "mda_"
# An agent counts as connected if it made a request this recently.
CONNECTED_WITHIN = 300.0


@dataclass(frozen=True)
class Principal:
    kind: str  # "app" or "agent"
    id: str  # app name, or agent id
    name: str

    @property
    def label(self) -> str:
        return f"{self.kind}:{self.name}"

    @property
    def scopes(self) -> frozenset[str]:
        """An app token's scopes; an agent token has none (it reaches /mcp only)."""
        return APP_SCOPES.get(self.id, frozenset()) if self.kind == "app" else frozenset()

    def allows(self, scope: str) -> bool:
        return scope in self.scopes


def app_token_path(home: Path, app: str) -> Path:
    if app not in APPS:
        raise ValueError(f"unknown app {app!r}")
    return home / "app-tokens" / app


def ensure_app_tokens(home: Path) -> dict[str, str]:
    """Create (or repair) every app's token; returns {app: token}."""
    d = home / "app-tokens"
    d.mkdir(parents=True, exist_ok=True)
    if not sys.platform.startswith("win"):
        os.chmod(d, 0o700)
    return {app: ensure_token(app_token_path(home, app)) for app in APPS}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@dataclass
class Agent:
    id: str
    name: str
    token_sha256: str
    created_at: str
    revoked_at: str | None = None
    extra: dict = field(default_factory=dict)

    def public(self, last_seen: float | None) -> dict:
        return {"id": self.id, "name": self.name, "created_at": self.created_at, "revoked": self.revoked_at is not None,
                "revoked_at": self.revoked_at,
                "last_seen_at": datetime.fromtimestamp(last_seen, timezone.utc).isoformat(timespec="seconds")
                if last_seen else None,
                "connected": bool(last_seen and time.time() - last_seen < CONNECTED_WITHIN
                                  and self.revoked_at is None)}


class AgentStore:
    """agents.json, shared by the host and the mydata command. Re-read when it changes on disk, so a
    token revoked from the command line stops working on the next request."""

    def __init__(self, home: Path):
        self.path = home / "agents.json"
        self._lock = threading.Lock()
        self._mtime: float | None = None
        self._agents: list[Agent] = []
        self._last_seen: dict[str, float] = {}

    # ---------------------------------------------------------------- file

    def _load(self) -> None:
        try:
            mtime = self.path.stat().st_mtime_ns
        except FileNotFoundError:
            self._agents, self._mtime = [], None
            return
        if mtime == self._mtime:
            return
        raw = json.loads(self.path.read_text() or "[]")
        self._agents = [Agent(**a) for a in raw]
        self._mtime = mtime

    def _save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".agents.")
        try:
            if not sys.platform.startswith("win"):
                os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as fh:
                json.dump([asdict(a) for a in self._agents], fh, indent=2)
            os.replace(tmp, self.path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        self._mtime = self.path.stat().st_mtime_ns

    # ---------------------------------------------------------------- operations

    def create(self, name: str) -> tuple[Agent, str]:
        name = name.strip()
        if not name or len(name) > 64:
            raise ValueError("an agent name must be 1 to 64 characters")
        token = AGENT_PREFIX + secrets.token_urlsafe(32)
        with self._lock:
            self._load()
            agent = Agent(id=secrets.token_hex(6), name=name, token_sha256=_hash(token), created_at=_now())
            self._agents.append(agent)
            self._save()
        return agent, token

    def revoke(self, ref: str) -> Agent:
        with self._lock:
            self._load()
            matches = [a for a in self._agents if a.revoked_at is None and ref in (a.id, a.name)]
            if not matches:
                raise KeyError(f"no active agent {ref!r}")
            if len(matches) > 1:
                raise KeyError(f"{ref!r} matches several agents; use the id")
            matches[0].revoked_at = _now()
            self._save()
            return matches[0]

    def list(self) -> list[dict]:
        with self._lock:
            self._load()
            return [a.public(self._last_seen.get(a.id)) for a in self._agents]

    def authenticate(self, token: str) -> Principal | None:
        if not token.startswith(AGENT_PREFIX):
            return None
        digest = _hash(token)
        with self._lock:
            self._load()
            for a in self._agents:
                if a.revoked_at is None and hmac.compare_digest(a.token_sha256, digest):
                    self._last_seen[a.id] = time.time()
                    return Principal("agent", a.id, a.name)
        return None


class Authenticator:
    """Maps a bearer token to who is calling, or None."""

    def __init__(self, app_tokens: dict[str, str], agents: AgentStore):
        self._apps = {app: tok.encode() for app, tok in app_tokens.items()}
        self.agents = agents

    def __call__(self, token: bytes) -> Principal | None:
        found = None
        for app, expected in self._apps.items():  # compare against every app token: no early exit
            if hmac.compare_digest(token, expected):
                found = Principal("app", app, app)
        if found:
            return found
        try:
            return self.agents.authenticate(token.decode("ascii"))
        except UnicodeDecodeError:
            return None
