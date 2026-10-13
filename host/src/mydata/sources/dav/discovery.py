"""Find a user's address books or calendars, starting from one URL.

start URL -> /.well-known/carddav|caldav (RFC 6764; redirects followed by the client, including to
partition hosts) -> current-user-principal (RFC 5397) -> addressbook-home-set (RFC 6352) or
calendar-home-set (RFC 4791) -> the collections in each home (PROPFIND Depth 1).
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Literal

from . import davxml as X
from .client import DavClient, DavError, expect
from .davxml import CALDAV, CARDDAV, CS, DAV, ICAL, q

log = logging.getLogger("mydata.dav")

Kind = Literal["contacts", "calendar"]


@dataclass
class Collection:
    url: str
    kind: Kind
    display_name: str
    color: str | None = None
    ctag: str | None = None
    sync_token: str | None = None  # None: the server did not report one (no RFC 6578 support seen)
    # Calendars: the supported-calendar-component-set, e.g. ("VEVENT", "VTODO"); () when the server
    # does not state it (which RFC 4791 says means "any"). Always () for address books.
    components: tuple[str, ...] = ()


@dataclass
class Discovery:
    principal_url: str
    home_urls: list[str] = field(default_factory=list)
    collections: list[Collection] = field(default_factory=list)


_SPEC = {
    "contacts": {"well_known": "/.well-known/carddav", "home": q(CARDDAV, "addressbook-home-set"),
                 "type": q(CARDDAV, "addressbook")},
    "calendar": {"well_known": "/.well-known/caldav", "home": q(CALDAV, "calendar-home-set"),
                 "type": q(CALDAV, "calendar")},
}

_COLLECTION_PROPS = [
    q(DAV, "resourcetype"), q(DAV, "displayname"), q(CS, "getctag"), q(DAV, "sync-token"),
    q(CALDAV, "supported-calendar-component-set"), q(ICAL, "calendar-color"),
]


def _propfind(client: DavClient, url: str, props: list[str], depth: str, what: str) -> tuple[X.Multistatus, str]:
    """The parsed answer and the URL that gave it (after redirects): relative hrefs in the answer resolve
    against that URL (RFC 4918), not against the one asked for."""
    resp = expect(client.request("PROPFIND", url, body=X.propfind_body(props), depth=depth), 207, what=what)
    try:
        return X.parse_multistatus(resp.body), resp.url
    except X.XmlError as e:
        raise DavError(f"{what}: {e}") from None


def _principal(client: DavClient, start_url: str, kind: Kind) -> str:
    """The principal URL, from the well-known URL first and the start URL itself as a fallback."""
    candidates = [X.absolute_url(start_url, _SPEC[kind]["well_known"]), start_url]
    last: DavError | None = None
    for url in candidates:
        try:
            resp = client.request("PROPFIND", url, body=X.propfind_body([q(DAV, "current-user-principal")]),
                                  depth="0")
        except DavError as e:
            if e.status == 401:
                raise
            last = e
            continue
        if resp.status != 207:
            last = DavError(f"principal lookup failed (HTTP {resp.status})", resp.status)
            continue
        try:
            ms = X.parse_multistatus(resp.body)
        except X.XmlError as e:
            last = DavError(f"principal lookup: {e}")
            continue
        for r in ms.responses:
            hrefs = r.hrefs(q(DAV, "current-user-principal"))
            if hrefs:
                return X.absolute_url(resp.url, hrefs[0])
        last = DavError("the server did not report a principal")
    assert last is not None
    raise last


_COLOR = re.compile(r"^#([0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?$")


def _color(raw: str | None) -> str | None:
    """#RRGGBB. iCloud sends #RRGGBBAA; the alpha is dropped. Anything else is kept as sent."""
    if not raw:
        return None
    m = _COLOR.match(raw.strip())
    return f"#{m.group(1).upper()}" if m else raw.strip()


def _components(r: X.DavProps) -> tuple[str, ...]:
    el = r.props.get(q(CALDAV, "supported-calendar-component-set"))
    if el is None:
        return ()
    return tuple(c.get("name", "").upper() for c in el.findall(q(CALDAV, "comp")) if c.get("name"))


def _default_name(url: str) -> str:
    return url.rstrip("/").rsplit("/", 1)[-1] or url


def discover(client: DavClient, start_url: str, kind: Kind) -> Discovery:
    """Discover the principal, home sets and collections of one kind. Raises DavError (status 401 for
    rejected credentials). Calendars that cannot hold events (no VEVENT in their stated component set,
    such as an iCloud reminders list) are left out."""
    if kind not in _SPEC:
        raise ValueError(f"unknown kind {kind!r}")
    spec = _SPEC[kind]
    principal = _principal(client, start_url, kind)

    ms, answered_by = _propfind(client, principal, [spec["home"]], "0", "home-set lookup")
    homes: list[str] = []
    for r in ms.responses:
        for href in r.hrefs(spec["home"]):
            url = X.absolute_url(answered_by, href)
            if url not in homes:
                homes.append(url)
    if not homes:
        what = "an address book" if kind == "contacts" else "a calendar"
        raise DavError(f"the server did not report {what} home")

    collections: list[Collection] = []
    seen: set[str] = set()
    for home in homes:
        resp_ms, base = _propfind(client, home, _COLLECTION_PROPS, "1", "collection listing")
        for r in resp_ms.responses:
            url = X.absolute_url(base, r.href)
            if X.same_path(X.canonical_path(base, r.href), X.canonical_path(base, base)):
                continue  # the home itself
            if spec["type"] not in r.resourcetypes():
                continue
            components = _components(r) if kind == "calendar" else ()
            if kind == "calendar" and components and "VEVENT" not in components:
                log.debug("skipping a calendar without VEVENT")
                continue
            key = X.canonical_path(base, r.href)
            if key in seen:
                continue
            seen.add(key)
            collections.append(Collection(
                url=url, kind=kind, display_name=r.text(q(DAV, "displayname")) or _default_name(url),
                color=_color(r.text(q(ICAL, "calendar-color"))) if kind == "calendar" else None,
                ctag=r.text(q(CS, "getctag")) or None, sync_token=r.text(q(DAV, "sync-token")) or None,
                components=components))
    return Discovery(principal_url=principal, home_urls=homes, collections=collections)
