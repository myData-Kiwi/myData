"""The export: the stored vCard and iCalendar text, written as files another app can import.

    <out>/contacts/<address book>.vcf          every card of one address book
    <out>/contacts/<address book> (groups).vcf group cards, kept apart: imported into Contacts they
                                               would become contacts named after the group
    <out>/calendars/<calendar>.ics             one VCALENDAR per calendar: every VEVENT (with its overrides
                                               and alarms), each VTIMEZONE once
    <out>/export.json                          what each file holds, and what was not exported

One file per address book and per calendar is what Contacts (File, Import) and Calendar (File, Import)
take in one go; a folder of single-object files would need one import per file. Lines are copied as
stored (folding included); only line endings become CRLF. A calendar's own properties (its PRODID, METHOD)
are replaced by the export's, plus X-WR-CALNAME with the calendar's name.

Two styles:
- **clean** (the default): every card in one vCard version (3.0 unless asked for 4.0), converted with the
  line editor (vcard_edit.convert), which changes only the lines that differ between versions; a card it
  cannot read is written as stored and counted. Each calendar gets a VTIMEZONE, generated from the zone data
  (ical_edit.vtimezone, 1970 to 2038), for every TZID its events use and no stored resource defines: the
  host stores TZIDs only for what it writes itself, and Outlook names ("W. Europe Standard Time") are
  mapped to their zone. A TZID no zone data knows is listed in export.json. Every calendar file is read
  back and compared with what went into it; anything lost stops the export (ExportError).
- **raw**: the stored text as it is, nothing converted or added.

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

from collections import Counter

from ..service.config import inside_checkout, private_dir, private_file
from . import ical_edit
from .mac import MAC_ID
from .owned import OWNED_ACCOUNT
from .vcard import card_kind
from .vcard_edit import VCardError, convert, escape_text, fold, parse_line, unescape_text

PRODID = "-//myData//raw export//EN"
STYLES = ("clean", "raw")
VCARD_VERSIONS = ("3.0", "4.0")
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
            return unescape_text(value.split(":", 1)[1]).strip()  # a writer may escape its commas
    return None


def _zone_rules(component: list[str]) -> tuple:
    """What a VTIMEZONE says about its zone: its STANDARD and DAYLIGHT parts' offsets, starts and rules, in
    any order and whatever else they carry (TZNAME, LAST-MODIFIED)."""
    parts, current = [], None
    for line in _logical(component):
        upper = line.upper()
        if upper in ("BEGIN:STANDARD", "BEGIN:DAYLIGHT"):
            current = [upper]
        elif upper in ("END:STANDARD", "END:DAYLIGHT") and current is not None:
            parts.append(tuple(sorted(current)))
            current = None
        elif current is not None and re.match(r"(TZOFFSETFROM|TZOFFSETTO|DTSTART|RRULE|RDATE)[;:]", upper):
            current.append(upper.replace(" ", ""))
    return tuple(sorted(parts))


def _logical(component: list[str]) -> list[str]:
    """A component's lines unfolded."""
    out: list[str] = []
    for line in component:
        if line[:1] in (" ", "\t") and out:
            out[-1] += line[1:]
        else:
            out.append(line)
    return out


def _rename_tzid(component: list[str], old: str, new: str) -> list[str]:
    """The component with every reference to TZID `old` (a TZID parameter, or a VTIMEZONE's own TZID) made
    `new`; the lines that do not name it are kept as they are."""
    out: list[str] = []
    for i, line in enumerate(component):
        if line[:1] in (" ", "\t"):
            continue
        group = [line]
        for cont in component[i + 1:]:
            if cont[:1] not in (" ", "\t"):
                break
            group.append(cont)
        prop = parse_line(group[0] + "".join(c[1:] for c in group[1:]))
        changed = False
        if prop is not None and prop.key == "TZID" and unescape_text(prop.value).strip() == old:
            prop.value, changed = escape_text(new), True
        elif prop is not None:
            for n, values in prop.params:
                if n is not None and n.upper() == "TZID" and old in values:
                    values[:] = [new if v == old else v for v in values]
                    changed = True
        out += fold(prop.render()).rstrip("\r\n").split("\r\n") if changed else group
    return out


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
    for its TZID), then everything else in order. Two VTIMEZONEs with one TZID that is no zone's name
    (Outlook calls every custom zone "Customized Time Zone") and different rules are two zones: the later
    one is renamed ("Customized Time Zone (2)") in its own resource, so its events keep their offsets. With
    a zone's name (an IANA or Windows one) the first is kept: it is the same zone, written differently."""
    zones: dict[str, list[str]] = {}
    others: list[list[str]] = []
    for raw in raws:
        comps = components(raw)
        renames: dict[str, str] = {}
        for comp in comps:
            tzid = _tzid(comp) if _kind(comp) == "VTIMEZONE" else None
            if tzid is not None and tzid in zones and ical_edit.iana_zone(tzid) is None and \
                    _zone_rules(zones[tzid]) != _zone_rules(comp):
                same = next((t for t, z in zones.items() if t.startswith(tzid) and _zone_rules(z) == _zone_rules(comp)),
                            None)
                n = 2
                while same is None and f"{tzid} ({n})" in zones:
                    n += 1
                renames[tzid] = same or f"{tzid} ({n})"
        for comp in comps:
            for old, new in renames.items():
                comp = _rename_tzid(comp, old, new)
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
    if account_id == OWNED_ACCOUNT:
        return "myData"
    return "This Mac" if account_id == MAC_ID else "iCloud"


def clean_card(raw: str, version: str) -> tuple[str, str]:
    """One stored card for the clean export, and what was done: "kept" (already that version), "converted",
    or "as stored" (a card the line editor cannot read)."""
    text = _crlf(_lines(raw))
    try:
        out = convert(text, version)
    except VCardError:
        return text, "as stored"
    return out, "kept" if out == text else "converted"


def _strip_ordinals(counts: Counter) -> Counter:
    """Counts with each component's ordinal left out, so two resources holding the same UID add up."""
    out: Counter = Counter()
    for entry, n in counts.items():
        key = tuple(part[:-1] for part in entry[0])
        out[(key,) + entry[1:]] += n
    return out


def _check_calendar(raws: list[str], merged: str) -> None:
    """Every event, override and alarm of the stored resources is in the merged file, with every property
    and parameter (calendar-level properties and VTIMEZONEs, which are merged, aside)."""
    try:
        written = _strip_ordinals(ical_edit.inventory(merged))
        stored: Counter = Counter()
        for raw in raws:
            stored.update(_strip_ordinals(ical_edit.inventory(raw)))
    except Exception as exc:  # noqa: BLE001 - an unreadable stored resource
        raise ExportError(f"a calendar could not be read back: {type(exc).__name__}") from exc
    lost = []
    for entry, n in stored.items():
        path = entry[0]
        if len(path) < 2 or path[1][0] == "VTIMEZONE":
            continue
        if written.get(entry, 0) < n:
            lost.append(" ".join(str(x) for x in entry[1:]) or path[-1][0])
    if lost:
        raise ExportError("the calendar file would lose " + ", ".join(sorted(set(lost))) + "; nothing was exported")


def clean_calendar(raws: list[str], name: str) -> tuple[str, list[str], list[str]]:
    """The merged calendar with a generated VTIMEZONE for each TZID the events use and nothing defines.
    Returns (text, the TZIDs given a VTIMEZONE, the TZIDs no zone data knows)."""
    merged = merge_calendar(raws, name)
    defined = set(ical_edit.defined_tzids(merged))
    added, missing, zones = [], [], []
    for tzid in ical_edit.referenced_tzids(merged):
        if tzid in defined:
            continue
        zone = ical_edit.vtimezone(tzid)
        if zone is None:
            missing.append(tzid)
            continue
        added.append(tzid)
        zones.extend(_lines(zone))
    if zones:
        lines = _lines(merged)
        header = next(i for i, line in enumerate(lines) if line.upper().startswith("BEGIN:") and i > 0)
        merged = _crlf(lines[:header] + zones + lines[header:])
    _check_calendar(raws, merged)
    return merged, added, missing


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
    """The raw export (the stored text as it is) of the host folder into `out`."""
    return export(home, out, style="raw")


def export(home: Path, out: Path, *, style: str = "clean", vcard_version: str = "3.0") -> dict:
    """Write the host folder's contacts and calendars into `out` (see the module docstring). Returns the
    summary that is also written as export.json. Every file is made and checked before the first is
    written, so a refused export leaves the folder as it was."""
    if style not in STYLES:
        raise ExportError(f"unknown export style {style!r}")
    if vcard_version not in VCARD_VERSIONS:
        raise ExportError(f"vCard {vcard_version} cannot be written; choose 3.0 or 4.0")
    out = check_destination(out)
    clean = style == "clean"
    summary: dict = {"format": 2, "style": style, "vcard_version": vcard_version if clean else None,
                     "contacts": [], "calendars": [], "not_exported": []}
    files: dict[str, str] = {}  # path inside `out` -> text

    def cards_text(raws: list[str], done: Counter) -> str:
        if not clean:
            return "".join(_crlf(_lines(c)) for c in raws)
        texts = []
        for raw in raws:
            text, how = clean_card(raw, vcard_version)
            texts.append(text)
            done[how] += 1
        return "".join(texts)

    db = _connect(Path(home) / "contacts.sqlite")
    if db is not None:
        try:
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
                done: Counter = Counter()
                files[entry["file"]] = cards_text(people, done)
                if groups:
                    gstem = _file_name(f"{book['name']} (groups)", "Groups", used)
                    entry.update(groups_file=f"contacts/{gstem}.vcf", groups=len(groups))
                    files[entry["groups_file"]] = cards_text(groups, done)
                if clean:
                    entry.update(converted=done["converted"], as_stored=done["as stored"])
                summary["contacts"].append(entry)
        finally:
            db.close()
    db = _connect(Path(home) / "calendar.sqlite")
    if db is not None:
        try:
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
                entry = {"file": f"calendars/{stem}.ics", "name": cal["name"], "source": _source(cal["account_id"]),
                         "resources": len(raws)}
                if clean:
                    text, added, unknown = clean_calendar(raws, cal["name"])
                    entry.update(zones_added=added, zones_unknown=unknown)
                else:
                    text = merge_calendar(raws, cal["name"])
                files[entry["file"]] = text
                summary["calendars"].append(entry)
        finally:
            db.close()
    private_dir(out)
    for kind in ("contacts", "calendars"):
        if (kind == "contacts" and (Path(home) / "contacts.sqlite").is_file()) or \
                (kind == "calendars" and (Path(home) / "calendar.sqlite").is_file()):
            private_dir(out / kind)
    for rel, text in files.items():
        _write(out / rel, text)
    _write(out / "export.json", json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    return summary
