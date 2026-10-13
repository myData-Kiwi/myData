"""The messages between the host and the myDataReader helper: JSON lines over a Unix socket, UTF-8, one
object per line. The helper connects to the host's socket (the path it is given with --socket).

helper -> host
  hello               {"version", "contacts", "calendars"}       statuses at connect
  status              {"contacts", "calendars"}                  after request_access, and on any change
  contact_containers  {"items": [{"id", "name", "kind"}]}
  calendars           {"items": [{"id", "name", "source_id", "source_name", "source_kind", "color"}]}
  contacts_snapshot   {"container_id", "part", "last", "items": [contact]}   every contact of one container
  events_snapshot     {"window_start", "window_end", "part", "last", "items": [occurrence]}   every occurrence
                                                                 in the window
  changed             {"what": "contacts" | "calendars"}         informational; snapshots follow
  error               {"message"}

host -> helper
  {"cmd": "status"} | {"cmd": "request_access", "what"} |
  {"cmd": "read", "what": "contacts"|"calendars"|"all", "containers": [ids]|null, "calendars": [ids]|null,
   "window_start", "window_end"} | {"cmd": "quit"}

A snapshot is complete for what was asked: the host replaces that container's (or the chosen calendars')
rows. A large snapshot comes in parts, each one line well under the socket's line limit: "part" counts
from 0 and "last" is true on the final one. The host keeps the parts and replaces the rows only when the
last part arrives; a part out of order drops the whole snapshot. Without "part" and "last" a message is
the whole snapshot (part 0, last).

Statuses: contacts notDetermined | restricted | denied | authorized; calendars notDetermined | restricted
| denied | fullAccess | writeOnly. Any other value (the helper sends "unknown" for one a later macOS adds)
is read as "unknown": not readable, and it does not stop the rest of the message being used.

Unknown message types are ignored, so either side can be newer. A known type with a wrong shape is a
ProtocolError; one bad item inside a snapshot is skipped (and counted), not the whole snapshot.
"""

from __future__ import annotations

import base64
import binascii
import json
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from ..vcard import MAX_PHOTO_BYTES, image_type

VERSION = 1

UNKNOWN = "unknown"  # a status this host does not know (a later macOS), or not reported yet
CONTACT_STATUSES = ("notDetermined", "restricted", "denied", "authorized")
CALENDAR_STATUSES = ("notDetermined", "restricted", "denied", "fullAccess", "writeOnly")
CONTAINER_KINDS = ("cardDAV", "exchange", "local", "unassigned")
SOURCE_KINDS = ("local", "exchange", "calDAV", "mobileMe", "subscribed", "birthdays")
READ_KINDS = ("contacts", "calendars", "all")
ACCESS_KINDS = ("contacts", "calendars")

# Statuses that let the helper read: the same test the helper makes (Session.swift) before reading.
CONTACTS_READABLE = ("authorized",)
CALENDARS_READABLE = ("fullAccess",)

# The most parts one snapshot may come in (the helper keeps each part to a few MB).
MAX_PARTS = 1000


_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
_BIRTHDAY = re.compile(r"^(?:\d{4}|-)-\d{2}-\d{2}$")


class ProtocolError(ValueError):
    """A message the host cannot use. The text names the message type and field, never a value."""


# ---------------------------------------------------------------- helpers


def _str(obj: dict, key: str, *, required: bool = False, limit: int = 10_000) -> str:
    value = obj.get(key)
    if value is None:
        if required:
            raise ProtocolError(f"{key} is missing")
        return ""
    if not isinstance(value, str):
        raise ProtocolError(f"{key} is not a string")
    if required and not value:
        raise ProtocolError(f"{key} is empty")
    return value[:limit]


def _bool(obj: dict, key: str) -> bool:
    value = obj.get(key, False)
    if not isinstance(value, bool):
        raise ProtocolError(f"{key} is not true or false")
    return value


def _list(obj: dict, key: str) -> list:
    value = obj.get(key)
    if value is None:
        return []
    if not isinstance(value, list):
        raise ProtocolError(f"{key} is not a list")
    return value


def _status(value: Any, allowed: tuple[str, ...]) -> str:
    """A status the host knows, or UNKNOWN (not readable) for anything else, so that a value a later macOS
    adds never makes the host drop the whole hello or status message."""
    return value if isinstance(value, str) and value in allowed else UNKNOWN


def _part(obj: dict) -> tuple[int, bool]:
    part, last = obj.get("part", 0), obj.get("last", True)
    if not isinstance(part, int) or isinstance(part, bool) or not 0 <= part < MAX_PARTS:
        raise ProtocolError(f"part is not a number from 0 to {MAX_PARTS - 1}")
    if not isinstance(last, bool):
        raise ProtocolError("last is not true or false")
    return part, last


def _day(value: Any, key: str) -> date:
    if not isinstance(value, str):
        raise ProtocolError(f"{key} is not a date")
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise ProtocolError(f"{key} is not a date (YYYY-MM-DD)") from None


def _labeled(items: list, *, limit: int = 100) -> list[dict]:
    out = []
    for raw in items[:limit]:
        if not isinstance(raw, dict):
            continue
        value = raw.get("value")
        if not isinstance(value, str) or not value.strip():
            continue
        label = raw.get("label")
        out.append({"value": value.strip()[:1000], "label": label.strip()[:100] if isinstance(label, str) else ""})
    return out


# ---------------------------------------------------------------- helper -> host


@dataclass(frozen=True)
class Hello:
    version: int
    contacts: str
    calendars: str


@dataclass(frozen=True)
class Status:
    contacts: str
    calendars: str


@dataclass(frozen=True)
class Container:
    id: str
    name: str
    kind: str


@dataclass(frozen=True)
class ContactContainers:
    items: list[Container]


@dataclass(frozen=True)
class MacCalendar:
    id: str
    name: str
    source_id: str
    source_name: str
    source_kind: str
    color: str | None


@dataclass(frozen=True)
class Calendars:
    items: list[MacCalendar]


@dataclass
class MacContact:
    id: str
    given_name: str = ""
    family_name: str = ""
    middle_name: str = ""
    nickname: str = ""
    organisation: str = ""
    job_title: str = ""
    kind: str = "person"  # person | organisation
    emails: list[dict] = field(default_factory=list)
    phones: list[dict] = field(default_factory=list)
    addresses: list[dict] = field(default_factory=list)
    birthday: str | None = None  # YYYY-MM-DD or --MM-DD
    urls: list[dict] = field(default_factory=list)
    photo: bytes | None = None  # JPEG (or PNG) bytes; None when there is none or it is not allowed


@dataclass(frozen=True)
class ContactsSnapshot:
    container_id: str
    items: list[MacContact]
    skipped: int = 0
    part: int = 0
    last: bool = True


@dataclass(frozen=True)
class Occurrence:
    calendar_id: str
    external_id: str
    occurrence_date: str
    start: str  # ISO date-time with offset, or YYYY-MM-DD (all-day)
    end: str  # as start; exclusive for all-day
    all_day: bool
    time_zone: str | None
    title: str
    location: str
    notes: str
    detached: bool
    recurring: bool


@dataclass(frozen=True)
class EventsSnapshot:
    window_start: date
    window_end: date
    items: list[Occurrence]
    skipped: int = 0
    part: int = 0
    last: bool = True


@dataclass(frozen=True)
class Changed:
    what: str


@dataclass(frozen=True)
class HelperError:
    message: str


Message = Hello | Status | ContactContainers | Calendars | ContactsSnapshot | EventsSnapshot | Changed | HelperError


def _contact(raw: Any) -> MacContact:
    if not isinstance(raw, dict):
        raise ProtocolError("a contact is not an object")
    kind = raw.get("kind") or "person"
    if kind not in ("person", "organisation"):
        raise ProtocolError("contact kind is not person or organisation")
    birthday = raw.get("birthday")
    if birthday is not None and (not isinstance(birthday, str) or not _BIRTHDAY.match(birthday)):
        birthday = None  # an unreadable birthday drops only the birthday
    addresses = []
    for a in _list(raw, "addresses")[:50]:
        if not isinstance(a, dict):
            continue
        address = {k: (a.get(k) if isinstance(a.get(k), str) else "")[:500]
                   for k in ("label", "street", "city", "region", "postcode", "country")}
        if any(v.strip() for k, v in address.items() if k != "label"):
            addresses.append(address)
    photo = None
    encoded = raw.get("photo_jpeg_base64")
    if isinstance(encoded, str) and encoded:
        try:
            photo = base64.b64decode(encoded, validate=True)
        except (binascii.Error, ValueError):
            photo = None
        if photo is not None and (len(photo) > MAX_PHOTO_BYTES or image_type(photo) is None):
            photo = None
    return MacContact(
        id=_str(raw, "id", required=True, limit=500),
        given_name=_str(raw, "given_name", limit=500), family_name=_str(raw, "family_name", limit=500),
        middle_name=_str(raw, "middle_name", limit=500), nickname=_str(raw, "nickname", limit=500),
        organisation=_str(raw, "organisation", limit=500), job_title=_str(raw, "job_title", limit=500),
        kind=kind, emails=_labeled(_list(raw, "emails")), phones=_labeled(_list(raw, "phones")),
        addresses=addresses, birthday=birthday, urls=_labeled(_list(raw, "urls")), photo=photo,
    )


def _timestamp(value: Any, key: str, all_day: bool) -> str:
    if not isinstance(value, str):
        raise ProtocolError(f"{key} is not a string")
    if all_day:
        _day(value, key)
        return value
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise ProtocolError(f"{key} is not an ISO 8601 date-time") from None
    if parsed.tzinfo is None:
        raise ProtocolError(f"{key} has no UTC offset")
    return parsed.isoformat()


def _occurrence(raw: Any) -> Occurrence:
    if not isinstance(raw, dict):
        raise ProtocolError("an occurrence is not an object")
    all_day = _bool(raw, "all_day")
    start = _timestamp(raw.get("start"), "start", all_day)
    end = _timestamp(raw.get("end"), "end", all_day)
    if all_day and date.fromisoformat(end) <= date.fromisoformat(start):
        end = date.fromordinal(date.fromisoformat(start).toordinal() + 1).isoformat()
    if not all_day and datetime.fromisoformat(end) < datetime.fromisoformat(start):
        end = start
    zone = raw.get("time_zone")
    return Occurrence(
        calendar_id=_str(raw, "calendar_id", required=True, limit=500),
        external_id=_str(raw, "external_id", required=True, limit=1000),
        occurrence_date=_str(raw, "occurrence_date", required=True, limit=64),
        start=start, end=end, all_day=all_day,
        time_zone=None if all_day or not isinstance(zone, str) or not zone else zone[:100],
        title=_str(raw, "title", limit=2000), location=_str(raw, "location", limit=2000),
        notes=_str(raw, "notes", limit=20_000), detached=_bool(raw, "detached"), recurring=_bool(raw, "recurring"),
    )


def _items(raw: list, parse) -> tuple[list, int]:
    out, skipped = [], 0
    for item in raw:
        try:
            out.append(parse(item))
        except ProtocolError:
            skipped += 1
    return out, skipped


def parse(line: bytes | str) -> Message | None:
    """One line from the helper as a message, or None for a type this host does not know."""
    try:
        obj = json.loads(line)
    except (ValueError, UnicodeDecodeError):
        raise ProtocolError("the line is not JSON") from None
    if not isinstance(obj, dict):
        raise ProtocolError("the line is not a JSON object")
    kind = obj.get("type")
    if kind == "hello":
        version = obj.get("version")
        if not isinstance(version, int) or isinstance(version, bool):
            raise ProtocolError("hello has no version")
        return Hello(version, _status(obj.get("contacts"), CONTACT_STATUSES),
                     _status(obj.get("calendars"), CALENDAR_STATUSES))
    if kind == "status":
        return Status(_status(obj.get("contacts"), CONTACT_STATUSES), _status(obj.get("calendars"), CALENDAR_STATUSES))
    if kind == "contact_containers":
        items = []
        for raw in _list(obj, "items"):
            if not isinstance(raw, dict):
                raise ProtocolError("a container is not an object")
            ckind = raw.get("kind")
            items.append(Container(_str(raw, "id", required=True, limit=500), _str(raw, "name", limit=500),
                                   ckind if ckind in CONTAINER_KINDS else "unassigned"))
        return ContactContainers(items)
    if kind == "calendars":
        items = []
        for raw in _list(obj, "items"):
            if not isinstance(raw, dict):
                raise ProtocolError("a calendar is not an object")
            color = raw.get("color")
            skind = raw.get("source_kind")
            items.append(MacCalendar(
                _str(raw, "id", required=True, limit=500), _str(raw, "name", limit=500),
                _str(raw, "source_id", limit=500), _str(raw, "source_name", limit=500),
                skind if skind in SOURCE_KINDS else "local",
                color.upper() if isinstance(color, str) and _COLOR.match(color) else None))
        return Calendars(items)
    if kind == "contacts_snapshot":
        part, last = _part(obj)
        items, skipped = _items(_list(obj, "items"), _contact)
        return ContactsSnapshot(_str(obj, "container_id", required=True, limit=500), items, skipped, part, last)
    if kind == "events_snapshot":
        start, end = _day(obj.get("window_start"), "window_start"), _day(obj.get("window_end"), "window_end")
        if end < start:
            raise ProtocolError("window_end is before window_start")
        part, last = _part(obj)
        items, skipped = _items(_list(obj, "items"), _occurrence)
        return EventsSnapshot(start, end, items, skipped, part, last)
    if kind == "changed":
        what = obj.get("what")
        if what not in ("contacts", "calendars"):
            raise ProtocolError("changed.what is not contacts or calendars")
        return Changed(what)
    if kind == "error":
        return HelperError(_str(obj, "message", limit=300))
    return None


# ---------------------------------------------------------------- host -> helper


def encode(obj: dict) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def cmd_status() -> dict:
    return {"cmd": "status"}


def cmd_request_access(what: str) -> dict:
    if what not in ACCESS_KINDS:
        raise ValueError(f"request_access is for contacts or calendars, not {what!r}")
    return {"cmd": "request_access", "what": what}


def cmd_read(what: str, containers: list[str] | None, calendars: list[str] | None,
             window: tuple[date, date] | None) -> dict:
    if what not in READ_KINDS:
        raise ValueError(f"read is for contacts, calendars or all, not {what!r}")
    out: dict = {"cmd": "read", "what": what, "containers": containers, "calendars": calendars}
    if window is not None:
        out["window_start"], out["window_end"] = window[0].isoformat(), window[1].isoformat()
    return out


def cmd_quit() -> dict:
    return {"cmd": "quit"}
