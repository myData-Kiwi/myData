"""The read-only DAV client: the single place the host talks HTTP to a contacts or calendar server.

Every HTTP call goes through DavClient.request. It refuses any method other than PROPFIND, REPORT,
OPTIONS and GET before any I/O, and so does the transport underneath it (a second lock, in case code
ever reaches the httpx client directly). The mirror is read-only by construction: there is no code
path that can write to the user's iCloud.

Credentials: HTTP Basic, sent only over HTTPS (plain HTTP only to loopback, for tests) and only to the
host the client first talked to, or to a host in the same trusted family (any *.icloud.com host when
the first host was one, because iCloud moves accounts to partition hosts such as p42-contacts.icloud.com).
The password is held in a wrapper whose repr is a placeholder, and no message this module produces
contains it.
"""

from __future__ import annotations

import base64
import ipaddress
import logging
from dataclasses import dataclass, field
from typing import Iterable

import httpx

from mydata import __version__

log = logging.getLogger("mydata.dav")

ALLOWED_METHODS = frozenset({"PROPFIND", "REPORT", "OPTIONS", "GET"})
REDIRECT_STATUSES = frozenset({301, 302, 303, 307, 308})
MAX_REDIRECTS = 5
# Families whose subdomains share one account's credentials. Any other host gets credentials only if
# it is exactly the host the client first talked to.
TRUSTED_FAMILIES = ("icloud.com",)


class ReadOnlyViolation(Exception):
    """A method other than PROPFIND, REPORT, OPTIONS or GET was attempted. Nothing was sent."""


class DavError(Exception):
    """A DAV request failed. `status` is the HTTP status, or None for a network or protocol error.
    The message never contains credentials."""

    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


@dataclass
class DavResponse:
    status: int
    headers: dict[str, str]  # lower-case names
    body: bytes = field(repr=False)
    url: str  # the final URL, after redirects; relative hrefs in the body resolve against it

    @property
    def ok(self) -> bool:
        return 200 <= self.status < 300


class _Secret:
    """Holds the password. Its repr and str never show it, and it cannot be pickled."""

    __slots__ = ("_value",)

    def __init__(self, value: str):
        self._value = value

    def reveal(self) -> str:
        return self._value

    def __repr__(self) -> str:
        return "<secret>"

    __str__ = __repr__

    def __reduce__(self):
        raise TypeError("secrets cannot be pickled")


def _check_method(method: object) -> str:
    if not isinstance(method, str) or method.upper() not in ALLOWED_METHODS:
        shown = method if isinstance(method, str) and method.isalpha() and len(method) < 20 else "?"
        raise ReadOnlyViolation(f"HTTP method {shown!r} is not allowed: the DAV mirror is read-only "
                                f"(allowed: {', '.join(sorted(ALLOWED_METHODS))})")
    return method.upper()


class _ReadOnlyTransport(httpx.BaseTransport):
    """Second lock: refuses non-read methods even if something bypasses DavClient.request."""

    def __init__(self, inner: httpx.BaseTransport):
        self._inner = inner

    def handle_request(self, request: httpx.Request) -> httpx.Response:
        _check_method(request.method)
        return self._inner.handle_request(request)

    def close(self) -> None:
        self._inner.close()


def _is_loopback(host: str) -> bool:
    if host == "localhost":
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def _in_family(host: str, family: str) -> bool:
    return host == family or host.endswith("." + family)


class DavClient:
    ALLOWED_METHODS = ALLOWED_METHODS

    def __init__(self, username: str, password: str, *, transport: httpx.BaseTransport | None = None,
                 timeout: float = 30, user_agent: str = f"myData/{__version__}",
                 trusted_families: Iterable[str] = TRUSTED_FAMILIES):
        self.username = username
        self._password = _Secret(password)
        self._user_agent = user_agent
        self._families = tuple(f.lower() for f in trusted_families)
        self._origin: str | None = None  # the first host this client talked to
        self._http = httpx.Client(transport=_ReadOnlyTransport(transport or httpx.HTTPTransport()),
                                  timeout=timeout, follow_redirects=False, trust_env=False)

    def __repr__(self) -> str:
        return f"DavClient(username={self.username!r})"

    __str__ = __repr__

    def __reduce__(self):
        raise TypeError("DavClient cannot be pickled")

    def __enter__(self) -> "DavClient":
        return self

    def __exit__(self, *exc) -> None:
        self.close()

    def close(self) -> None:
        self._http.close()

    # --- credentials ----------------------------------------------------------------------------------

    def _authorization(self) -> str:
        raw = f"{self.username}:{self._password.reveal()}".encode()
        return "Basic " + base64.b64encode(raw).decode("ascii")

    def _may_authenticate(self, host: str) -> bool:
        if self._origin is None:
            return True
        if host == self._origin:
            return True
        return any(_in_family(host, f) and _in_family(self._origin, f) for f in self._families)

    def _scrub(self, text: str) -> str:
        """Remove the password (and the Basic header that carries it) from text we did not write."""
        pw = self._password.reveal()
        if pw:
            text = text.replace(pw, "***")
            text = text.replace(self._authorization().split(" ", 1)[1], "***")
        return text

    # --- the one place HTTP happens --------------------------------------------------------------------

    def request(self, method: str, url: str, *, headers: dict[str, str] | None = None,
                body: bytes | None = None, depth: str | None = None) -> DavResponse:
        """Send one read request, following redirects (same method, at most MAX_REDIRECTS).
        Returns the response for any status except 401, which raises DavError(status=401)."""
        method = _check_method(method)  # before anything else: no I/O for a write method
        base_headers = {"User-Agent": self._user_agent}
        if body is not None:
            base_headers["Content-Type"] = "application/xml; charset=utf-8"
        if depth is not None:
            base_headers["Depth"] = str(depth)
        for k, v in (headers or {}).items():
            if k.lower() == "authorization":
                raise ValueError("credentials are added by DavClient; do not pass Authorization")
            base_headers[k] = v

        current = url
        for _hop in range(MAX_REDIRECTS + 1):
            target = self._target(current)
            host = target.host
            if not self._may_authenticate(host):
                raise DavError(f"refusing to send credentials to {host}: it is not {self._origin} or a "
                               "host in the same trusted family")
            if target.scheme != "https" and not _is_loopback(host):
                raise DavError(f"refusing to send credentials over plain HTTP to {host}")
            if self._origin is None:
                self._origin = host
            req_headers = dict(base_headers, Authorization=self._authorization())
            try:
                resp = self._http.request(method, target, headers=req_headers, content=body)
            except ReadOnlyViolation:
                raise
            except httpx.HTTPError as e:
                detail = self._scrub(str(e))[:200]
                raise DavError(f"could not reach {host}: {type(e).__name__}" + (f" ({detail})" if detail else "")
                               ) from None
            # Host only: the path of an iCloud URL holds the account's identifier (DSID).
            log.debug("%s %s -> %s", method, host, resp.status_code)
            if resp.status_code in REDIRECT_STATUSES:
                location = resp.headers.get("location")
                if not location:
                    raise DavError(f"redirect from {host} without a Location", resp.status_code)
                current = str(target.join(location))
                continue
            if resp.status_code == 401:
                raise DavError(f"{host} did not accept the username and password (HTTP 401)", 401)
            return DavResponse(status=resp.status_code,
                               headers={k.lower(): v for k, v in resp.headers.items()},
                               body=resp.content, url=str(target))
        raise DavError(f"too many redirects (more than {MAX_REDIRECTS}) starting at {httpx.URL(url).host}")

    @staticmethod
    def _target(url: str) -> httpx.URL:
        try:
            target = httpx.URL(url)
        except (httpx.InvalidURL, TypeError) as e:
            raise DavError(f"invalid URL ({type(e).__name__})") from None
        if target.scheme not in ("https", "http") or not target.host:
            raise DavError("only absolute http(s) URLs are allowed")
        if target.userinfo:
            raise DavError("URLs must not carry credentials")
        return target


def expect(resp: DavResponse, *statuses: int, what: str = "request") -> DavResponse:
    """Raise DavError unless the response has one of the given statuses."""
    if resp.status not in statuses:
        raise DavError(f"{what} failed at {httpx.URL(resp.url).host} (HTTP {resp.status})", resp.status)
    return resp
