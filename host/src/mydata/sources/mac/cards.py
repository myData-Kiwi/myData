"""A Mac contact as a vCard 3.0 text, so the contacts mirror stores it like a CardDAV card (raw_vcard)
and its search, find_by_name, get and the API work unchanged.

The card is generated from the fields the helper read, and holds no NOTE: contact notes are never read
on a Mac (reading them needs an entitlement Apple grants case by case). Labels travel as Apple's
grouped X-ABLabel lines, which vcard.parse_vcard already reads. A photo goes in as PHOTO;ENCODING=b.
"""

from __future__ import annotations

import base64
import hashlib

from ..vcard import image_type
from .protocol import MacContact

PRODID = "-//myData//This Mac//EN"


def _escape(value: str) -> str:
    return (value.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,")
            .replace("\r\n", "\\n").replace("\n", "\\n").replace("\r", "\\n"))


def _plain(value: str) -> str:
    """A value that is not text-typed (email, phone, URL): one line, no escaping."""
    return " ".join(value.replace("\r", " ").replace("\n", " ").split())


def _fold(line: str) -> list[str]:
    """RFC 6350 folding: at most 75 octets per line, never splitting a UTF-8 character."""
    out, current, size = [], [], 0
    for ch in line:
        n = len(ch.encode("utf-8"))
        limit = 75 if not out else 74  # a continuation line starts with one space
        if size + n > limit:
            out.append("".join(current))
            current, size = [], 0
        current.append(ch)
        size += n
    out.append("".join(current))
    return [out[0], *(" " + part for part in out[1:])]


def full_name(c: MacContact) -> str:
    if c.kind == "organisation" and c.organisation.strip():
        return c.organisation.strip()
    return " ".join(p.strip() for p in (c.given_name, c.middle_name, c.family_name) if p.strip())


def to_vcard(c: MacContact) -> str:
    lines = ["BEGIN:VCARD", "VERSION:3.0", f"PRODID:{PRODID}", f"UID:{_escape(c.id)}",
             f"FN:{_escape(full_name(c))}",
             "N:" + ";".join(_escape(p) for p in (c.family_name, c.given_name, c.middle_name, "", ""))]
    if c.nickname:
        lines.append(f"NICKNAME:{_escape(c.nickname)}")
    if c.organisation:
        lines.append(f"ORG:{_escape(c.organisation)}")
    if c.job_title:
        lines.append(f"TITLE:{_escape(c.job_title)}")
    if c.kind == "organisation":
        lines.append("X-ABShowAs:COMPANY")
    group = 0

    def labeled(prop: str, value: str, label: str) -> None:
        nonlocal group
        group += 1
        lines.append(f"item{group}.{prop}:{value}")
        if label:
            lines.append(f"item{group}.X-ABLabel:{_escape(label)}")

    for e in c.emails:
        labeled("EMAIL;TYPE=INTERNET", _plain(e["value"]), e.get("label", ""))
    for p in c.phones:
        labeled("TEL", _plain(p["value"]), p.get("label", ""))
    for a in c.addresses:
        # ADR: post office box; extended address; street; locality; region; postal code; country
        parts = ["", "", *(_escape(a.get(k, "")) for k in ("street", "city", "region", "postcode", "country"))]
        labeled("ADR", ";".join(parts), a.get("label", ""))
    if c.birthday:
        lines.append(f"BDAY:{c.birthday}")
    for u in c.urls:
        labeled("URL", _plain(u["value"]), u.get("label", ""))
    if c.photo and image_type(c.photo):
        kind = "JPEG" if image_type(c.photo) == "image/jpeg" else "PNG"
        lines.append(f"PHOTO;ENCODING=b;TYPE={kind}:{base64.b64encode(c.photo).decode('ascii')}")
    lines.append("END:VCARD")
    return "\r\n".join(part for line in lines for part in _fold(line)) + "\r\n"


def etag(card: str) -> str:
    """A stand-in for a server's ETag: unchanged contacts are then not rewritten."""
    return hashlib.sha256(card.encode("utf-8")).hexdigest()[:32]
