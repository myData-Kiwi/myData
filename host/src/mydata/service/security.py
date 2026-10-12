"""The API token, and the checks every request passes before reaching any route.

- Token: created on first start, 256 bits from secrets, stored in a file only the current user
  can read (mode 0600). Every request must send `Authorization: Bearer <token>`.
- Host header: must name this machine (127.0.0.1, localhost or ::1, any port). This blocks DNS
  rebinding, where a web page in a browser points its own domain at 127.0.0.1.
"""

from __future__ import annotations

import hmac
import json
import logging
import os
import re
import secrets
import stat
import sys
import tempfile
from pathlib import Path

logger = logging.getLogger("mydata.security")

# The whole Host header must name this machine, with an optional port.
_LOCAL_HOST = re.compile(r"(\[::1\]|127\.0\.0\.1|localhost)(:\d{1,5})?")


class TokenError(Exception):
    pass


def _token_problem(path: Path) -> str | None:
    """Why an existing token file cannot be trusted, or None if it can."""
    st = os.lstat(path)
    if not stat.S_ISREG(st.st_mode):
        return "is not a regular file"
    if not sys.platform.startswith("win"):
        if st.st_uid != os.getuid():
            return "belongs to another user"
        if stat.S_IMODE(st.st_mode) & 0o077:
            return "was readable by other users"
    if len(path.read_text().strip()) < 32:
        return "is empty or too short"
    return None


def _write_private(path: Path, token: str, replace: bool) -> bool:
    """Write the token to a private temp file, then put it in place in one step, so the token path never
    holds a partial token. With replace=False it never overwrites; returns False if the file appeared."""
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".token.")
    try:
        if not sys.platform.startswith("win"):
            os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as fh:
            fh.write(token)
            fh.flush()
            os.fsync(fh.fileno())
        if replace:
            os.replace(tmp, path)
            return True
        try:
            os.link(tmp, path)
            return True
        except FileExistsError:
            return False
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def ensure_token(path: Path) -> str:
    """Return the token, creating it on first start. A token file that may have been exposed or is
    damaged (readable by others, not a regular file, someone else's, empty) is replaced, not reused."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if not os.path.lexists(path):
        if _write_private(path, secrets.token_urlsafe(32), replace=False):
            return path.read_text().strip()
    problem = _token_problem(path)
    if problem:
        logger.warning("token file replaced", extra={"fields": {"reason": problem, "path": str(path)}})
        _write_private(path, secrets.token_urlsafe(32), replace=True)
    return path.read_text().strip()


def read_token(path: Path) -> str:
    """For clients such as the mydata command: read the token, refusing one that cannot be trusted."""
    if not os.path.lexists(path):
        raise TokenError(f"no token at {path}; is the host set up?")
    problem = _token_problem(path)
    if problem:
        raise TokenError(f"the token file {path} {problem}; restart the host to replace it")
    return path.read_text().strip()


def _host_ok(host_header: str) -> bool:
    return _LOCAL_HOST.fullmatch(host_header.strip().lower()) is not None


class GuardMiddleware:
    """Pure ASGI middleware (does not buffer streamed responses) in front of every route, /mcp included.

    - Host header must name this machine (421 otherwise).
    - `Authorization: Bearer <token>` must be an app token or a live agent token (401 otherwise).
    - Agent tokens reach /mcp only (403 anywhere else).
    The caller is passed on as scope["state"]["principal"] (auth.Principal), for the routes to record."""

    def __init__(self, app, authenticate):
        self.app = app
        self._authenticate = authenticate

    async def __call__(self, scope, receive, send):
        if scope["type"] == "websocket":  # the API has no WebSocket routes
            return await send({"type": "websocket.close", "code": 1008})
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        headers = dict(scope.get("headers") or [])
        if not _host_ok(headers.get(b"host", b"").decode("latin-1")):
            return await _reject(send, 421, "requests must be addressed to this machine")
        auth = headers.get(b"authorization", b"")
        principal = self._authenticate(auth[7:]) if auth.startswith(b"Bearer ") and len(auth) > 7 else None
        if principal is None:
            return await _reject(send, 401, "missing or wrong token", {"www-authenticate": "Bearer"})
        if principal.kind == "agent" and scope.get("path") != "/mcp":
            return await _reject(send, 403, "agent tokens can only use /mcp")
        scope.setdefault("state", {})["principal"] = principal
        return await self.app(scope, receive, send)


async def _reject(send, status: int, message: str, extra: dict | None = None) -> None:
    body = json.dumps({"detail": message}).encode()
    headers = [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())]
    headers += [(k.encode(), v.encode()) for k, v in (extra or {}).items()]
    await send({"type": "http.response.start", "status": status, "headers": headers})
    await send({"type": "http.response.body", "body": body})
