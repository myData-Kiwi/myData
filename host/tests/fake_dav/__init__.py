"""A fake iCloud-shaped CardDAV/CalDAV server for tests. Invented data only; no network.

Shape (like iCloud): discovery starts at contacts.icloud.com / caldav.icloud.com, whose
/.well-known/carddav|caldav redirect to a principal on a partition host (p42-contacts.icloud.com,
p42-caldav.icloud.com). The principal reports the home sets (with an explicit :443, as iCloud does),
and the homes hold the collections. The host names are only routing keys inside an httpx
MockTransport: nothing leaves the process.

Use:
    fake = FakeDav()
    client = fake.client()          # a DavClient with the fake's invented credentials and transport
    ... or DavClient(USERNAME, PASSWORD, transport=fake.transport)

Switches and helpers: supports_sync (sync-collection on/off), sync_page_size (truncate sync answers
with 507), expire_tokens(), add_item / update_item / delete_item, well_known (off: well-known 404s).
The same logic is also a Starlette app (`fake.app`) for driving it as a real server.

Every method seen is recorded (`fake.requests`, `fake.methods`). Writes (PUT, DELETE, POST, PROPPATCH,
MKCOL, MKCALENDAR, MOVE, COPY, ...) are answered 405 and recorded. Fakes made with audit=True (the
default) also report into a session-wide record that conftest checks at the end of the run: the whole
test run may only ever send PROPFIND, REPORT, OPTIONS and GET.
"""

from __future__ import annotations

import base64
import hashlib
from dataclasses import dataclass, field
from urllib.parse import quote, unquote
from xml.sax.saxutils import escape

import defusedxml.ElementTree as SafeET
import httpx

from . import data as D

USERNAME = "ava.fictional@example.com"
PASSWORD = "fake-app-pw-abcd-efgh"  # invented
PRINCIPAL_ID = "1234567"

DAV = "DAV:"
CARDDAV = "urn:ietf:params:xml:ns:carddav"
CALDAV = "urn:ietf:params:xml:ns:caldav"
CS = "http://calendarserver.org/ns/"
ICAL = "http://apple.com/ns/ical/"
_PREFIX = {DAV: "D", CARDDAV: "A", CALDAV: "C", CS: "CS", ICAL: "I"}
_NSDECL = " ".join(f'xmlns:{p}="{ns}"' for ns, p in _PREFIX.items())

READ_METHODS = frozenset({"PROPFIND", "REPORT", "OPTIONS", "GET"})

# Methods seen by every audited fake during this test session.
SESSION_METHODS: set[str] = set()


def audit_violations() -> list[str]:
    return sorted(SESSION_METHODS - READ_METHODS)


def _q(ns: str, name: str) -> str:
    return f"{{{ns}}}{name}"


@dataclass
class FakeItem:
    data: str
    etag: str


@dataclass
class FakeCollection:
    key: str
    kind: str  # "contacts" | "calendar"
    host: str
    path: str
    name: str
    color: str | None = None
    components: tuple[str, ...] | None = None
    items: dict[str, FakeItem] = field(default_factory=dict)
    changes: dict[str, int] = field(default_factory=dict)  # item name -> revision of its last change
    ctag: str = "ctag-0"
    min_rev: int = 0  # tokens older than this are expired


class FakeDav:
    def __init__(self, *, username: str = USERNAME, password: str = PASSWORD,
                 contacts_host: str = "contacts.icloud.com", calendar_host: str = "caldav.icloud.com",
                 contacts_partition: str = "p42-contacts.icloud.com",
                 calendar_partition: str = "p42-caldav.icloud.com",
                 supports_sync: bool = True, sync_page_size: int | None = None, well_known: bool = True,
                 audit: bool = True, contacts: dict[str, str] | None = None,
                 calendars: dict[str, dict] | None = None):
        self.username, self.password = username, password
        self.contacts_host, self.calendar_host = contacts_host, calendar_host
        self.contacts_partition, self.calendar_partition = contacts_partition, calendar_partition
        self.supports_sync = supports_sync
        self.sync_page_size = sync_page_size
        self.well_known = well_known
        self.audit = audit
        self.requests: list[tuple[str, str, str]] = []  # (method, host, path)
        self.reports: list[tuple[str, int]] = []  # (report name, number of hrefs asked for)
        self.rev = 0
        self.collections: dict[str, FakeCollection] = {}
        p = PRINCIPAL_ID
        self.principal_path = f"/{p}/principal/"
        self.card_home = f"/{p}/carddavhome/"
        self.cal_home = f"/{p}/calendars/"
        self.inbox_path = f"/{p}/calendars/inbox/"

        book = FakeCollection("card", "contacts", contacts_partition, f"{self.card_home}card/", "Contacts")
        self.collections[book.path] = book
        for name, text in (D.CONTACTS if contacts is None else contacts).items():
            self._put(book, name, text)
        for key, spec in (D.CALENDARS if calendars is None else calendars).items():
            cal = FakeCollection(key, "calendar", calendar_partition, f"{self.cal_home}{key}/", spec["name"],
                                 spec.get("color"), spec.get("components"))
            self.collections[cal.path] = cal
            for name, text in spec["items"].items():
                self._put(cal, name, text)

    # --- test helpers ----------------------------------------------------------------------------------

    @property
    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self._handle_httpx)

    def client(self, **kw):
        from mydata.sources.dav.client import DavClient
        return DavClient(kw.pop("username", self.username), kw.pop("password", self.password),
                         transport=kw.pop("transport", self.transport), **kw)

    @property
    def methods(self) -> set[str]:
        return {m for m, _, _ in self.requests}

    def collection(self, ref: str) -> FakeCollection:
        """A collection by key ("card", "home", "work", ...) or path."""
        if ref in self.collections:
            return self.collections[ref]
        for c in self.collections.values():
            if c.key == ref:
                return c
        raise KeyError(ref)

    def url(self, ref: str) -> str:
        c = self.collection(ref)
        return f"https://{c.host}{c.path}"

    def href(self, ref: str, name: str) -> str:
        return self.collection(ref).path + quote(name)

    def add_item(self, ref: str, name: str, text: str) -> str:
        c = self.collection(ref)
        assert name not in c.items, name
        self._put(c, name, text)
        return self.href(ref, name)

    def update_item(self, ref: str, name: str, text: str) -> str:
        c = self.collection(ref)
        assert name in c.items, name
        self._put(c, name, text)
        return self.href(ref, name)

    def delete_item(self, ref: str, name: str) -> str:
        c = self.collection(ref)
        del c.items[name]
        self._bump(c, name)
        return self.href(ref, name)

    def expire_tokens(self, ref: str | None = None) -> None:
        """Make every sync token issued so far for the collection (or all) invalid."""
        self.rev += 1
        for c in ([self.collection(ref)] if ref else self.collections.values()):
            c.min_rev = self.rev

    def token(self, ref: str) -> str:
        return self._token(self.collection(ref), self.rev)

    # --- state ----------------------------------------------------------------------------------------

    def _bump(self, c: FakeCollection, name: str) -> int:
        self.rev += 1
        c.changes[name] = self.rev
        c.ctag = f"ctag-{self.rev}"
        return self.rev

    def _put(self, c: FakeCollection, name: str, text: str) -> None:
        rev = self._bump(c, name)
        c.items[name] = FakeItem(text, '"' + hashlib.sha1(f"{rev}:{text}".encode()).hexdigest()[:16] + '"')

    @staticmethod
    def _token(c: FakeCollection, rev: int) -> str:
        return f"https://example.com/fake-sync/{c.key}/{rev}"

    def _parse_token(self, c: FakeCollection, token: str) -> int | None:
        prefix = f"https://example.com/fake-sync/{c.key}/"
        if not token.startswith(prefix):
            return None
        try:
            rev = int(token[len(prefix):])
        except ValueError:
            return None
        return rev if c.min_rev <= rev <= self.rev else None

    # --- HTTP -------------------------------------------------------------------------------------------

    def _handle_httpx(self, request: httpx.Request) -> httpx.Response:
        host = request.url.host
        if host not in (self.contacts_host, self.calendar_host, self.contacts_partition, self.calendar_partition):
            raise httpx.ConnectError(f"fake DNS: unknown host {host}", request=request)
        raw_path = request.url.raw_path.split(b"?", 1)[0].decode("ascii")
        status, headers, body = self.handle(request.method, host, raw_path, dict(request.headers),
                                            request.read())
        return httpx.Response(status, headers=headers, content=body)

    @property
    def app(self):
        """The same server as a Starlette app."""
        from starlette.applications import Starlette
        from starlette.requests import Request
        from starlette.responses import Response
        from starlette.routing import Route

        async def endpoint(request: Request) -> Response:
            body = await request.body()
            status, headers, content = self.handle(request.method, request.url.hostname or "",
                                                   request.scope.get("raw_path", b"/").decode("ascii")
                                                   or request.url.path,
                                                   dict(request.headers), body)
            return Response(content, status_code=status, headers=headers)

        methods = ["GET", "PUT", "POST", "DELETE", "PATCH", "OPTIONS", "PROPFIND", "PROPPATCH", "REPORT",
                   "MKCOL", "MKCALENDAR", "MOVE", "COPY", "LOCK", "UNLOCK", "ACL"]
        return Starlette(routes=[Route("/{path:path}", endpoint, methods=methods)])

    def handle(self, method: str, host: str, raw_path: str, headers: dict[str, str], body: bytes
               ) -> tuple[int, dict[str, str], bytes]:
        method = method.upper()
        path = unquote(raw_path) or "/"
        self.requests.append((method, host, path))
        if self.audit:
            SESSION_METHODS.add(method)
        if method not in READ_METHODS:
            return 405, {"Allow": ", ".join(sorted(READ_METHODS))}, b"read-only fake"
        if not self._authorised(headers):
            return 401, {"WWW-Authenticate": 'Basic realm="fake"'}, b"unauthorised"

        start = host in (self.contacts_host, self.calendar_host)
        if path in ("/.well-known/carddav", "/.well-known/caldav"):
            if not self.well_known:
                return 404, {}, b""
            target = self.contacts_partition if path.endswith("carddav") else self.calendar_partition
            return 301, {"Location": f"https://{target}{self.principal_path}"}, b""
        if method == "OPTIONS":
            return 200, {"DAV": "1, 2, 3, access-control, addressbook, calendar-access",
                         "Allow": ", ".join(sorted(READ_METHODS))}, b""

        res = self._resource(host, path, start)
        if res is None:
            return 404, {}, b"not found"
        if method == "GET":
            if res[0] != "item":
                return 405, {}, b""
            c, name = res[1], res[2]
            ctype = "text/vcard; charset=utf-8" if c.kind == "contacts" else "text/calendar; charset=utf-8"
            return 200, {"ETag": c.items[name].etag, "Content-Type": ctype}, c.items[name].data.encode()
        if method == "PROPFIND":
            return self._propfind(host, path, res, headers, body)
        return self._report(host, path, res, body)

    def _authorised(self, headers: dict[str, str]) -> bool:
        auth = {k.lower(): v for k, v in headers.items()}.get("authorization", "")
        if not auth.startswith("Basic "):
            return False
        try:
            user, _, pw = base64.b64decode(auth[6:]).decode().partition(":")
        except Exception:
            return False
        return user == self.username and pw == self.password

    def _resource(self, host: str, path: str, start: bool):
        if start:
            return ("root",) if path == "/" else None
        contacts = host == self.contacts_partition
        if path == self.principal_path:
            return ("principal",)
        if contacts and path == self.card_home:
            return ("home", "contacts")
        if not contacts and path == self.cal_home:
            return ("home", "calendar")
        if not contacts and path == self.inbox_path:
            return ("inbox",)
        for c in self.collections.values():
            if c.host != host:
                continue
            if path == c.path:
                return ("collection", c)
            if path.startswith(c.path) and path[len(c.path):] in c.items:
                return ("item", c, path[len(c.path):])
        return None

    # --- PROPFIND ---------------------------------------------------------------------------------------

    def _props(self, host: str, res) -> dict[str, str]:
        """Clark name -> inner XML for every property the resource has."""
        p: dict[str, str] = {}
        partition = self.contacts_partition if host in (self.contacts_host, self.contacts_partition) \
            else self.calendar_partition
        principal = f"https://{partition}{self.principal_path}" if res[0] == "root" else self.principal_path
        p[_q(DAV, "current-user-principal")] = f"<D:href>{principal}</D:href>"
        kind = res[0]
        if kind == "root":
            p[_q(DAV, "resourcetype")] = "<D:collection/>"
        elif kind == "principal":
            p[_q(DAV, "resourcetype")] = "<D:principal/>"
            p[_q(DAV, "displayname")] = "Ava Fictional"
            p[_q(CARDDAV, "addressbook-home-set")] = \
                f"<D:href>https://{self.contacts_partition}:443{self.card_home}</D:href>"
            p[_q(CALDAV, "calendar-home-set")] = \
                f"<D:href>https://{self.calendar_partition}:443{self.cal_home}</D:href>"
        elif kind == "home":
            p[_q(DAV, "resourcetype")] = "<D:collection/>"
        elif kind == "inbox":
            p[_q(DAV, "resourcetype")] = "<D:collection/><C:schedule-inbox/>"
        elif kind == "collection":
            c: FakeCollection = res[1]
            t = "<A:addressbook/>" if c.kind == "contacts" else "<C:calendar/>"
            p[_q(DAV, "resourcetype")] = "<D:collection/>" + t
            p[_q(DAV, "displayname")] = escape(c.name)
            p[_q(CS, "getctag")] = c.ctag
            if self.supports_sync:
                p[_q(DAV, "sync-token")] = escape(self._token(c, self.rev))
            if c.kind == "calendar":
                if c.components is not None:
                    p[_q(CALDAV, "supported-calendar-component-set")] = "".join(
                        f'<C:comp name="{n}"/>' for n in c.components)
                if c.color:
                    p[_q(ICAL, "calendar-color")] = c.color
        elif kind == "item":
            c, name = res[1], res[2]
            p[_q(DAV, "resourcetype")] = ""
            p[_q(DAV, "getetag")] = escape(c.items[name].etag)
            p[_q(DAV, "getcontenttype")] = "text/vcard" if c.kind == "contacts" else "text/calendar"
        return p

    def _children(self, host: str, res) -> list[tuple[str, tuple]]:
        if res[0] == "home":
            out = [(c.path, ("collection", c)) for c in self.collections.values()
                   if c.kind == res[1] and c.host == host]
            if res[1] == "calendar":
                out.append((self.inbox_path, ("inbox",)))
            return out
        if res[0] == "collection":
            c = res[1]
            return [(c.path + quote(n), ("item", c, n)) for n in c.items]
        return []

    def _propfind(self, host, path, res, headers, body):
        depth = {k.lower(): v for k, v in headers.items()}.get("depth", "infinity")
        if depth not in ("0", "1"):
            return 403, {}, b'<?xml version="1.0"?><D:error xmlns:D="DAV:"><D:propfind-finite-depth/></D:error>'
        wanted: list[str] | None = None
        if body.strip():
            root = SafeET.fromstring(body)
            prop = root.find(_q(DAV, "prop"))
            if prop is not None:
                wanted = [child.tag for child in prop]
        href = quote(path)
        entries = [(href, res)] + (self._children(host, res) if depth == "1" else [])
        out = [self._response(h, self._props(host, r), wanted) for h, r in entries]
        return self._multistatus(out)

    @staticmethod
    def _el(clark: str, inner: str | None) -> str:
        ns, local = clark[1:].split("}", 1)
        prefix = _PREFIX.get(ns)
        if prefix is None:
            open_tag = f'X:{local} xmlns:X="{escape(ns)}"'
            close = f"X:{local}"
        else:
            open_tag = close = f"{prefix}:{local}"
        return f"<{open_tag}/>" if not inner else f"<{open_tag}>{inner}</{close}>"

    def _response(self, href: str, props: dict[str, str], wanted: list[str] | None) -> str:
        names = list(props) if wanted is None else wanted
        found = [n for n in names if n in props]
        missing = [n for n in names if n not in props]
        parts = [f"<D:response><D:href>{escape(href)}</D:href>"]
        if found:
            parts.append("<D:propstat><D:prop>" + "".join(self._el(n, props[n]) for n in found)
                         + "</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat>")
        if missing:
            parts.append("<D:propstat><D:prop>" + "".join(self._el(n, None) for n in missing)
                         + "</D:prop><D:status>HTTP/1.1 404 Not Found</D:status></D:propstat>")
        parts.append("</D:response>")
        return "".join(parts)

    @staticmethod
    def _multistatus(responses: list[str], extra: str = "") -> tuple[int, dict, bytes]:
        xml = (f'<?xml version="1.0" encoding="UTF-8"?><D:multistatus {_NSDECL}>' + "".join(responses) + extra
               + "</D:multistatus>")
        return 207, {"Content-Type": "application/xml; charset=utf-8"}, xml.encode()

    # --- REPORT -----------------------------------------------------------------------------------------

    def _report(self, host, path, res, body):
        try:
            root = SafeET.fromstring(body)
        except Exception:
            return 400, {}, b"bad xml"
        if root.tag == _q(DAV, "sync-collection"):
            return self._sync(res, root)
        if root.tag in (_q(CARDDAV, "addressbook-multiget"), _q(CALDAV, "calendar-multiget")):
            return self._multiget(res, root)
        return 403, {}, b'<D:error xmlns:D="DAV:"><D:supported-report/></D:error>'

    def _sync(self, res, root):
        if res[0] != "collection":
            return 403, {}, b'<D:error xmlns:D="DAV:"><D:supported-report/></D:error>'
        self.reports.append(("sync-collection", 0))
        if not self.supports_sync:
            return 501, {}, b"sync-collection not implemented"
        c: FakeCollection = res[1]
        token = (root.findtext(_q(DAV, "sync-token")) or "").strip()
        if token:
            since = self._parse_token(c, token)
            if since is None:
                return 403, {"Content-Type": "application/xml"}, \
                    b'<?xml version="1.0"?><D:error xmlns:D="DAV:"><D:valid-sync-token/></D:error>'
            changes = sorted((rev, n) for n, rev in c.changes.items() if rev > since)
        else:
            changes = sorted((c.changes[n], n) for n in c.items)
        truncated = self.sync_page_size is not None and len(changes) > self.sync_page_size
        if truncated:
            changes = changes[:self.sync_page_size]
            new_rev = changes[-1][0]
        else:
            new_rev = self.rev
        prop = root.find(_q(DAV, "prop"))
        wanted = [child.tag for child in prop] if prop is not None else [_q(DAV, "getetag")]
        out = []
        for _rev, name in changes:
            href = c.path + quote(name)
            if name in c.items:
                out.append(self._response(href, self._props(c.host, ("item", c, name)), wanted))
            else:
                out.append(f"<D:response><D:href>{escape(href)}</D:href>"
                           "<D:status>HTTP/1.1 404 Not Found</D:status></D:response>")
        if truncated:
            out.append(f"<D:response><D:href>{escape(c.path)}</D:href>"
                       "<D:status>HTTP/1.1 507 Insufficient Storage</D:status></D:response>")
        return self._multistatus(out, f"<D:sync-token>{escape(self._token(c, new_rev))}</D:sync-token>")

    def _multiget(self, res, root):
        if res[0] != "collection":
            return 403, {}, b""
        c: FakeCollection = res[1]
        is_card = root.tag == _q(CARDDAV, "addressbook-multiget")
        if is_card != (c.kind == "contacts"):
            return 403, {}, b""
        hrefs = [(h.text or "").strip() for h in root.findall(_q(DAV, "href"))]
        self.reports.append((root.tag.split("}", 1)[1], len(hrefs)))
        data_tag = _q(CARDDAV, "address-data") if is_card else _q(CALDAV, "calendar-data")
        out = []
        for href in hrefs:
            path = unquote(href.split("://", 1)[-1][href.split("://", 1)[-1].find("/"):]) if "://" in href \
                else unquote(href)
            name = path[len(c.path):] if path.startswith(c.path) else None
            if name is None or name not in c.items:
                out.append(f"<D:response><D:href>{escape(href)}</D:href>"
                           "<D:status>HTTP/1.1 404 Not Found</D:status></D:response>")
                continue
            props = self._props(c.host, ("item", c, name))
            props[data_tag] = escape(c.items[name].data).replace("\r", "&#13;")
            out.append(self._response(href, props, [_q(DAV, "getetag"), data_tag]))
        return self._multistatus(out)
