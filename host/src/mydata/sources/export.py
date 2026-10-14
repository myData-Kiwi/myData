"""The raw export: the stored vCard and iCalendar text, written as files another app can import.

    <out>/contacts/<address book>.vcf          every card of one address book, as stored
    <out>/contacts/<address book> (groups).vcf iCloud group cards, kept apart: imported into Contacts they
                                               would become contacts named after the group
    <out>/calendars/<calendar>.ics             one VCALENDAR per calendar: every VEVENT (with its overrides
                                               and alarms) as stored, each VTIMEZONE once
    <out>/export.json                          what each file holds, and what was not exported

One file per address book and per calendar is what Contacts (File, Import) and Calendar (File, Import)
take in one go; a folder of single-object files would need one import per file. Lines are copied as
stored (folding included); only line endings become CRLF. A calendar's own properties (its PRODID, METHOD)
are replaced by the export's, plus X-WR-CALNAME with the calendar's name.

Not exported: rows marked deleted, and This Mac's events, which the host holds only as expanded
occurrences (no rule, no original event): export those from Calendar itself. This Mac's cards are the
ones the host generated from what the helper read (no notes).

The files are read directly, without opening the stores, so nothing is migrated. The export folder must
be new or empty and outside the source checkout; it and its files are readable only by the user.
"""

from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path

from ..service.config import inside_checkout, private_dir, private_file
from .mac import MAC_ID
from .vcard import card_kind

PRODID = "-//myData//raw export//EN"
_UNSAFE = re.compile(r'[\x00-\x1f\x7f/\\:*?"<>|]')


class ExportError(Exception):
    pass


def _lines(text: str) -> list[str]:
    return [line for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n") if line != ""]


def _crlf(lines: list[str]) -> str:
    return "".join(line + "\r\n" for line in lines)


def is_group_card(raw: str) -> bool:
    """The store's own rule (vcard.card_kind), so the export and every app agree on what is a group."""
    return card_kind(raw) == "group"


def components(raw_ics: str) -> list[list[str]]:
    """The components directly inside the VCALENDAR(s) of one stored resource (VEVENT, VTIMEZONE, ...), each
    as its content lines, unchanged."""
    out: list[list[str]] = []
    depth, current = 0, None
    for line in _lines(raw_ics):
        if line[0] in " \t":  # a folded continuation of the line before
            if current is not None:
                current.append(line)
            continue
        upper = line.upper()
        if upper.startswith("BEGIN:"):
            depth += 1
            if depth == 2:
                current = [line]
                continue
        elif upper.startswith("END:"):
            depth -= 1
            if depth == 1 and current is not None:
                current.append(line)
                out.append(current)
                current = None
                continue
        if current is not None:
            current.append(line)
    return out


def _kind(component: list[str]) -> str:
    return component[0].split(":", 1)[1].strip().upper()


def _tzid(component: list[str]) -> str | None:
    """The TZID of a VTIMEZONE (its own property, not one of a nested STANDARD or DAYLIGHT)."""
    depth = 0
    for i, line in enumerate(component):
        upper = line.upper()
        if upper.startswith("BEGIN:"):
            depth += 1
        elif upper.startswith("END:"):
            depth -= 1
        elif depth == 1 and re.match(r"TZID[;:]", upper):
            value = line
            for cont in component[i + 1:]:
                if cont[:1] not in (" ", "\t"):
                    break
                value += cont[1:]
            return value.split(":", 1)[1].strip()
    return None


def _escape(text: str) -> str:
    return (text.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n"))


def _fold(line: str) -> list[str]:
    """RFC 5545 folding: at most 75 octets per line, never inside a UTF-8 character."""
    out, current = [], ""
    for ch in line:
        limit = 75 if not out else 74  # a continuation line starts with a space
        if len((current + ch).encode()) > limit:
            out.append(current)
            current = ch
        else:
            current += ch
    out.append(current)
    return [out[0]] + [" " + part for part in out[1:]]


def merge_calendar(raws: list[str], name: str) -> str:
    """One VCALENDAR holding every component of the stored resources: each VTIMEZONE once (the first seen
    for its TZID), then everything else in order."""
    zones: dict[str, list[str]] = {}
    others: list[list[str]] = []
    for raw in raws:
        for comp in components(raw):
            if _kind(comp) == "VTIMEZONE":
                tzid = _tzid(comp)
                if tzid is not None and tzid not in zones:
                    zones[tzid] = comp
            else:
                others.append(comp)
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", f"PRODID:{PRODID}", "CALSCALE:GREGORIAN"]
    if name:
        lines += _fold(f"X-WR-CALNAME:{_escape(name)}")
    for comp in [*zones.values(), *others]:
        lines += comp
    lines.append("END:VCALENDAR")
    return _crlf(lines)


def _file_name(name: str, fallback: str, used: set[str]) -> str:
    base = _UNSAFE.sub("_", name).strip(" .")[:80] or fallback
    candidate, n = base, 2
    while candidate.casefold() in used:
        candidate, n = f"{base} ({n})", n + 1
    used.add(candidate.casefold())
    return candidate


def _source(account_id: str) -> str:
    return "This Mac" if account_id == MAC_ID else "iCloud"


def _write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="")
    private_file(path)


def _connect(path: Path) -> sqlite3.Connection | None:
    if not path.is_file():
        return None
    db = sqlite3.connect(path, timeout=30)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA busy_timeout=30000")
    db.execute("PRAGMA query_only=ON")
    return db


def check_destination(out: Path) -> Path:
    """The export folder: outside the source checkout, and new or empty."""
    out = Path(out).expanduser().absolute()
    if inside_checkout(out):
        raise ExportError(f"{out} is inside the source checkout; personal data is never written there. "
                          f"Choose a folder outside the repository.")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        raise ExportError(f"{out} already exists and is not an empty folder; choose a new one")
    return out


def export_raw(home: Path, out: Path) -> dict:
    """Write the raw export of the host folder's contacts and calendars into `out`. Returns the summary
    that is also written as export.json."""
    out = check_destination(out)
    summary: dict = {"format": 1, "contacts": [], "calendars": [], "not_exported": []}
    private_dir(out)
    db = _connect(Path(home) / "contacts.sqlite")
    if db is not None:
        try:
            folder = private_dir(out / "contacts")
            used: set[str] = set()
            for book in db.execute("SELECT id, account_id, name FROM address_books WHERE deleted_at IS NULL "
                                   "ORDER BY account_id, name, id"):
                cards = [r["raw_vcard"] for r in db.execute(
                    "SELECT raw_vcard FROM contacts WHERE address_book_id = ? AND deleted_at IS NULL "
                    "ORDER BY display_name COLLATE NOCASE, id", (book["id"],))]
                people = [c for c in cards if not is_group_card(c)]
                groups = [c for c in cards if is_group_card(c)]
                stem = _file_name(book["name"], "Address book", used)
                entry = {"file": f"contacts/{stem}.vcf", "name": book["name"], "source": _source(book["account_id"]),
                         "cards": len(people)}
                _write(folder / f"{stem}.vcf", "".join(_crlf(_lines(c)) for c in people))
                if groups:
                    gstem = _file_name(f"{book['name']} (groups)", "Groups", used)
                    _write(folder / f"{gstem}.vcf", "".join(_crlf(_lines(c)) for c in groups))
                    entry.update(groups_file=f"contacts/{gstem}.vcf", groups=len(groups))
                summary["contacts"].append(entry)
        finally:
            db.close()
    db = _connect(Path(home) / "calendar.sqlite")
    if db is not None:
        try:
            folder = private_dir(out / "calendars")
            used = set()
            for cal in db.execute("SELECT id, account_id, name FROM calendars WHERE deleted_at IS NULL "
                                  "ORDER BY account_id, name, id"):
                if cal["account_id"] == MAC_ID:
                    occurrences = db.execute("SELECT COUNT(*) FROM occurrences WHERE calendar_id = ? AND "
                                             "deleted_at IS NULL", (cal["id"],)).fetchone()[0]
                    summary["not_exported"].append({
                        "calendar": cal["name"], "source": "This Mac", "occurrences": occurrences,
                        "why": "This Mac gives the host expanded occurrences only, not the events themselves; "
                               "export this calendar from Calendar (File, Export)"})
                    continue
                raws = [r["raw_ics"] for r in db.execute(
                    "SELECT raw_ics FROM events WHERE calendar_id = ? AND deleted_at IS NULL ORDER BY range_start, id",
                    (cal["id"],))]
                stem = _file_name(cal["name"], "Calendar", used)
                _write(folder / f"{stem}.ics", merge_calendar(raws, cal["name"]))
                summary["calendars"].append({"file": f"calendars/{stem}.ics", "name": cal["name"],
                                             "source": _source(cal["account_id"]), "resources": len(raws)})
        finally:
            db.close()
    _write(out / "export.json", json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    return summary
