"""WebDAV XML: request bodies and multistatus parsing.

Server XML is parsed with defusedxml only (no entities, no external references). Request bodies are
built with ElementTree so hrefs and tokens are escaped properly.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET  # building request bodies only; never used to parse server XML
from dataclasses import dataclass, field
from urllib.parse import quote, unquote, urljoin, urlsplit, urlunsplit

import defusedxml.ElementTree as SafeET
from defusedxml import DefusedXmlException

DAV = "DAV:"
CARDDAV = "urn:ietf:params:xml:ns:carddav"
CALDAV = "urn:ietf:params:xml:ns:caldav"
CS = "http://calendarserver.org/ns/"
ICAL = "http://apple.com/ns/ical/"

PREFIXES = {DAV: "D", CARDDAV: "A", CALDAV: "C", CS: "CS", ICAL: "I"}


def q(ns: str, name: str) -> str:
    """Clark notation: {namespace}name."""
    return f"{{{ns}}}{name}"


class XmlError(ValueError):
    """The server sent XML we cannot read. The message never includes the body."""


@dataclass
class DavProps:
    """One <D:response> of a multistatus."""

    href: str
    status: int | None = None  # response-level <D:status>, if any (sync-collection uses it for deletions)
    props: dict[str, ET.Element] = field(default_factory=dict)  # Clark name -> element, 2xx propstat only

    def text(self, name: str) -> str | None:
        el = self.props.get(name)
        if el is None:
            return None
        return (el.text or "").strip() if len(el) == 0 else None

    def raw_text(self, name: str) -> str | None:
        """Element text without stripping (item data)."""
        el = self.props.get(name)
        return None if el is None else (el.text or "")

    def hrefs(self, name: str) -> list[str]:
        el = self.props.get(name)
        if el is None:
            return []
        return [(h.text or "").strip() for h in el.iter(q(DAV, "href")) if (h.text or "").strip()]

    def resourcetypes(self) -> set[str]:
        el = self.props.get(q(DAV, "resourcetype"))
        return set() if el is None else {child.tag for child in el}


@dataclass
class Multistatus:
    responses: list[DavProps]
    sync_token: str | None = None


_STATUS = re.compile(r"HTTP/\d(?:\.\d)?\s+(\d{3})")


def _status(el: ET.Element | None) -> int | None:
    if el is None or not el.text:
        return None
    m = _STATUS.search(el.text)
    return int(m.group(1)) if m else None


def parse_xml(body: bytes) -> ET.Element:
    try:
        return SafeET.fromstring(body)
    except (ET.ParseError, DefusedXmlException, ValueError) as e:
        raise XmlError(f"malformed XML from server ({type(e).__name__})") from None


def parse_multistatus(body: bytes) -> Multistatus:
    root = parse_xml(body)
    if root.tag != q(DAV, "multistatus"):
        raise XmlError("expected a DAV multistatus")
    out: list[DavProps] = []
    for resp in root.findall(q(DAV, "response")):
        href_el = resp.find(q(DAV, "href"))
        if href_el is None or not (href_el.text or "").strip():
            continue
        item = DavProps(href=href_el.text.strip(), status=_status(resp.find(q(DAV, "status"))))
        for ps in resp.findall(q(DAV, "propstat")):
            code = _status(ps.find(q(DAV, "status")))
            prop = ps.find(q(DAV, "prop"))
            if prop is None or code is None or not 200 <= code < 300:
                continue
            for child in prop:
                item.props[child.tag] = child
        out.append(item)
    token_el = root.find(q(DAV, "sync-token"))
    token = (token_el.text or "").strip() if token_el is not None else None
    return Multistatus(out, token or None)


# --- hrefs -------------------------------------------------------------------------------------------

# Characters left as they are when an href path is re-encoded (RFC 3986 pchar plus "/").
_SAFE = "/:@!$&'()*+,;=-._~"


def canonical_path(base_url: str, href: str) -> str:
    """The href as an absolute, consistently percent-encoded path. Servers may send the same member as
    a relative or absolute URL, or with different escaping; this makes them compare equal."""
    path = urlsplit(urljoin(base_url, href)).path or "/"
    return quote(unquote(path), safe=_SAFE)


def absolute_url(base_url: str, href: str) -> str:
    """href resolved against base_url, with a default port (:443 for https, :80 for http) dropped so
    the same collection always has the same URL (iCloud writes home sets with an explicit :443)."""
    parts = urlsplit(urljoin(base_url, href))
    netloc = parts.netloc
    if (parts.scheme, parts.port) in (("https", 443), ("http", 80)):
        netloc = netloc.rsplit(":", 1)[0]
    return urlunsplit((parts.scheme, netloc.lower(), parts.path, parts.query, ""))


def same_path(a: str, b: str) -> bool:
    return a.rstrip("/") == b.rstrip("/")


# --- request bodies -----------------------------------------------------------------------------------

def _el(tag: str, parent: ET.Element | None = None, text: str | None = None) -> ET.Element:
    el = ET.Element(tag) if parent is None else ET.SubElement(parent, tag)
    if text is not None:
        el.text = text
    return el


def _serialize(root: ET.Element) -> bytes:
    for ns, prefix in PREFIXES.items():
        ET.register_namespace(prefix, ns)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def propfind_body(props: list[str]) -> bytes:
    root = _el(q(DAV, "propfind"))
    prop = _el(q(DAV, "prop"), root)
    for name in props:
        _el(name, prop)
    return _serialize(root)


def sync_collection_body(token: str | None, props: list[str]) -> bytes:
    root = _el(q(DAV, "sync-collection"))
    _el(q(DAV, "sync-token"), root, token or "")
    _el(q(DAV, "sync-level"), root, "1")
    prop = _el(q(DAV, "prop"), root)
    for name in props:
        _el(name, prop)
    return _serialize(root)


def multiget_body(kind: str, hrefs: list[str]) -> bytes:
    if kind == "contacts":
        root, data = _el(q(CARDDAV, "addressbook-multiget")), q(CARDDAV, "address-data")
    else:
        root, data = _el(q(CALDAV, "calendar-multiget")), q(CALDAV, "calendar-data")
    prop = _el(q(DAV, "prop"), root)
    _el(q(DAV, "getetag"), prop)
    _el(data, prop)
    for href in hrefs:
        _el(q(DAV, "href"), root, href)
    return _serialize(root)
