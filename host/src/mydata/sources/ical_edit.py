"""Edit an iCalendar resource (one event: its master VEVENT and its overrides) and refuse any write that loses
something.

Edits go through icalendar (7.3), written with sorted=False so properties keep their order, and a replaced
property keeps its place. Every property the edit did not change (icalendar reads it as it did) is then
written back as the input wrote it, line for line: icalendar re-escapes and normalises what it re-serialises
(REQUEST-STATUS's ';', an INTEGER's leading zeros, the commas of an Outlook TZID). Before a write is accepted,
the new text is read back and compared, component by component, with the text that came in: the count of each
property (of each value, for EXDATE, RDATE, CATEGORIES and RESOURCES) and of each of its parameters, and the
value and parameters of every property the edit did not change. If anything went down or changed that the
edit did not change on purpose, the write is refused (PropertyLossError); icalendar has dropped properties
before (#1870). The text is also compared with the edited object, so a property lost while writing is caught
as well. The input is counted from its own text, not from icalendar's reading of it, so a line icalendar
skips is caught too.

Time zones: the writer stores TZIDs only, written as the event's own DTSTART writes them (an Outlook
"W. Europe Standard Time" stays that, though icalendar reads it as Europe/Berlin). It never adds a VTIMEZONE;
the export adds them (vtimezone()). A VTIMEZONE a resource came with is kept.

Repeating events (RFC 5545). A changed occurrence is named by its original start (its RECURRENCE-ID). Never
RANGE=THISANDFUTURE, which few clients read.

- edit_this: an override (a VEVENT with that RECURRENCE-ID) is added as a copy of the master, or the
  existing one is changed.
- delete_this: an EXDATE with DTSTART's value type and TZID, and the occurrence's override is removed.
- edit_all: the master changes. When only the time of day moves, every EXDATE, RDATE, override and date-time
  UNTIL moves with it, on the series' own clock (a value written in UTC too), so deleted and changed
  occurrences stay deleted and changed and the last one stays in. An edit that leaves an
  EXDATE or override on a time that is no longer an occurrence (a new date, zone or rule) is refused unless
  the caller passes exceptions="drop", which removes them.
- edit_following: the series is split. The old one ends before the occurrence (COUNT recounted, else UNTIL:
  in UTC for zoned and UTC times, local for floating times, a date for all-day events); the new one is a new
  resource with a new UID, X-MYDATA-SPLIT-FROM naming the old UID, and the EXDATEs, RDATEs and overrides from
  that occurrence on. Then the changes are made to it as edit_all makes them.

A field of an override that equals the master's old value follows the master's change (it was not changed for
that occurrence); a field it changed is kept. Changed components get a new DTSTAMP and LAST-MODIFIED, and
SEQUENCE goes up when a time or the rule changes.

Nonexistent local times (the hour skipped when clocks go forward, 02:30 on 27 September 2026 in Auckland) are
kept as written and mean the offset before the gap (RFC 5545 3.3.5), as zoneinfo and recurring-ical-events
read them: 02:30 NZST, 14:30 UTC.
"""

from __future__ import annotations

import copy
import re
import uuid
from collections import Counter
from collections.abc import Mapping
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import icalendar
from dateutil import rrule as du
from icalendar.prop import vBroken, vCategory, vDDDLists, vDDDTypes

from .vcard_edit import parse_line, split_unescaped, unescape_text

PRODID = "-//myData//iCalendar editor//EN"
SPLIT_FROM = "X-MYDATA-SPLIT-FROM"

_MULTI = {"EXDATE", "RDATE", "CATEGORIES", "RESOURCES"}
_IDENTIFIED = {"VEVENT", "VTODO", "VJOURNAL"}
_TIMING = {"DTSTART", "DTEND", "DURATION", "RRULE", "RDATE", "EXDATE", "EXRULE"}
_SERIES_ONLY = ("RRULE", "RDATE", "EXDATE", "EXRULE")
_STAMPS = ("DTSTAMP", "LAST-MODIFIED", "SEQUENCE")


class IcsError(ValueError):
    """The text is not an event this module can edit, or the edit cannot be made as asked."""


class PropertyLossError(IcsError):
    """The written text lost something the edit did not remove; nothing is written."""


# ---------------------------------------------------------------- counting what a text holds

class _Node:
    __slots__ = ("name", "props", "children", "ref")

    def __init__(self, name: str, ref=None):
        self.name = name
        # (NAME, PARAM NAMES, value, values counted, the value with its parameters, index of the line or None)
        self.props: list[tuple[str, list[str], str, int, tuple, int | None]] = []
        self.children: list[_Node] = []
        self.ref = ref  # the icalendar component, for a tree made from one


def _lines(text: str) -> list[str]:
    """Each content line with its folded continuations and line endings, as written (blank lines left out)."""
    out: list[str] = []
    for phys in re.findall(r"[^\r\n]*(?:\r\n|\n|\r)|[^\r\n]+\Z", text):
        if out and phys[:1] in (" ", "\t"):
            out[-1] += phys
        elif phys.strip():
            out.append(phys)
    return out


def _unfold(text: str) -> list[str]:
    return [re.sub(r"(?:\r\n|\r|\n)[ \t]", "", line).rstrip("\r\n") for line in _lines(text)]


def _norm(prop) -> tuple:
    """A property's value and parameters, compared without their order, quoting or the case of their names."""
    return prop.value, tuple(sorted(((n or "").upper(), tuple(v)) for n, v in prop.params))


def _text_tree(text: str) -> tuple[_Node, list[str]]:
    lines = _lines(text)
    root = _Node("")
    stack = [root]
    for i, raw in enumerate(lines):
        prop = parse_line(re.sub(r"(?:\r\n|\r|\n)[ \t]", "", raw).rstrip("\r\n"))
        if prop is None:
            continue
        key = prop.key
        if key == "BEGIN":
            node = _Node(prop.value.strip().upper())
            stack[-1].children.append(node)
            stack.append(node)
        elif key == "END":
            if len(stack) > 1:
                stack.pop()
        else:
            values = len([v for v in split_unescaped(prop.value, ",") if v.strip()]) if key in _MULTI else 1
            stack[-1].props.append((key, [(n or "").upper() for n, _v in prop.params], prop.value, values,
                                    _norm(prop), i))
    return root, lines


def _object_tree(component, root: _Node | None = None) -> _Node:
    node = _Node(component.name.upper(), component)
    for name, value in component.property_items(recursive=False, sorted=False):
        if name.upper() in ("BEGIN", "END"):
            continue
        values = value if isinstance(value, list) else [value]
        for v in values:
            # by type, never hasattr: a property icalendar could not read (vBroken) raises on any attribute
            if isinstance(v, vDDDLists):
                n = len(v.dts)
            elif isinstance(v, vCategory):
                n = len(v.cats)
            else:
                n = 1
            text = v.to_ical() if hasattr(type(v), "to_ical") else str(v)
            text = text.decode("utf-8") if isinstance(text, bytes) else str(text)
            params = [p.upper() for p in getattr(v, "params", {}).keys()]
            node.props.append((name.upper(), params, text, n if name.upper() in _MULTI else 1, (), None))
    for sub in component.subcomponents:
        node.children.append(_object_tree(sub))
    if root is not None:
        root.children.append(node)
    return node


def _ident(node: _Node) -> tuple:
    def first(name: str) -> str:
        return next((unescape_text(p[2]).strip() for p in node.props if p[0] == name), "")

    if node.name in _IDENTIFIED:
        return node.name, first("UID"), first("RECURRENCE-ID").upper()
    if node.name == "VTIMEZONE":
        return node.name, first("TZID")
    return (node.name,)


def _keyed(root: _Node) -> dict[tuple, _Node]:
    """Every component by its key: its path of (name, UID, RECURRENCE-ID or TZID), with an ordinal for
    components that share one (two VALARMs)."""
    out: dict[tuple, _Node] = {}

    def walk(node: _Node, path: tuple) -> None:
        seen: Counter = Counter()
        for child in node.children:
            ident = _ident(child)
            key = path + (ident + (seen[ident],),)
            seen[ident] += 1
            out[key] = child
            walk(child, key)

    walk(root, ())
    return out


def _count(root: _Node) -> Counter:
    counts: Counter = Counter()
    for key, node in _keyed(root).items():
        counts[(key,)] += 1
        for name, params, _value, n, _norm_, _i in node.props:
            counts[(key, name)] += n
            for p in params:
                counts[(key, name, p)] += 1
    return counts


def _values(root: _Node) -> dict[tuple, Counter]:
    """Per (component key, NAME): how many times each value-with-parameters occurs."""
    out: dict[tuple, Counter] = {}
    for key, node in _keyed(root).items():
        for name, _params, _value, _n, norm, _i in node.props:
            out.setdefault((key, name), Counter())[norm] += 1
    return out


def inventory(text: str) -> Counter:
    """What the text holds, counted from its own lines: per component, each property (each value of
    EXDATE, RDATE, CATEGORIES, RESOURCES) and each of its parameters."""
    return _count(_text_tree(text)[0])


def _describe(entry: tuple) -> str:
    key = entry[0]
    where = "/".join(":".join(str(x) for x in part[:-1] if x != "") or part[0] for part in key)
    return where + ("" if len(entry) == 1 else " " + ";".join(entry[1:]))


def _signatures(component) -> dict[str, tuple]:
    """Per property name, icalendar's reading of each value: its text and parameters, in order."""
    out: dict[str, list] = {}
    for name, value in component.property_items(recursive=False, sorted=False):
        name = name.upper()
        if name in ("BEGIN", "END"):
            continue
        for v in value if isinstance(value, list) else [value]:
            text = v.to_ical() if hasattr(type(v), "to_ical") else str(v)
            params = tuple(sorted((k.upper(), str(x)) for k, x in getattr(v, "params", {}).items()))
            out.setdefault(name, []).append((text, params))
    return {k: tuple(v) for k, v in out.items()}


def _crlf(raw: str) -> str:
    return re.sub(r"\r\n|\r|\n", "\r\n", raw if raw.endswith(("\r", "\n")) else raw + "\n")


# ---------------------------------------------------------------- one edit, checked before it is written

# What the writer reads from a component: icalendar must have read these, and an event holds one of each.
_READ = ("DTSTART", "DTEND", "DUE", "DURATION", "RECURRENCE-ID", "EXDATE", "RDATE", "RRULE", "SEQUENCE", "UID")
_ONE = ("DTSTART", "DTEND", "DUE", "DURATION", "RECURRENCE-ID", "UID", "SEQUENCE")


class _Edit:
    """One edit of one resource. Components are known by their key in the input (computed once, kept by
    identity), so allow() is cheap and a component whose key changes (an override moved with its series) is
    followed. A component the edit adds is adopted from the one it was copied from, so the lines it shares with
    that one are written as they came too."""

    def __init__(self, text: str):
        self.text = text
        self.before_root, self.before_lines = _text_tree(text)
        self.before_keyed = _keyed(self.before_root)
        self.before = _count(self.before_root)
        try:
            self.cal = icalendar.Calendar.from_ical(text)
        except Exception as exc:  # noqa: BLE001 - icalendar raises several types for bad input
            raise IcsError("not a readable iCalendar resource") from exc
        if not isinstance(self.cal, icalendar.Calendar):
            raise IcsError("not a VCALENDAR")
        for component in self.cal.walk():
            if component.name not in _IDENTIFIED:
                continue
            for name in _READ:
                values = component.get(name)
                if isinstance(values, list) and name in _ONE:
                    raise IcsError(f"the event has more than one {name}")
                if any(isinstance(v, vBroken) for v in _as_list(values)):
                    raise IcsError(f"the event has a {name} that cannot be read")
        root = _Node("")
        _object_tree(self.cal, root)
        self._keys: dict[int, tuple] = {}
        self._held: list = []  # the components keyed, kept alive so their ids stay theirs
        self._read: dict[tuple, dict[str, tuple]] = {}  # how icalendar read each component's properties
        for key, node in _keyed(root).items():
            self._keys[id(node.ref)] = key
            self._held.append(node.ref)
            self._read[key] = _signatures(node.ref)
        self._source: dict[tuple, tuple] = {}  # an adopted component's key -> the key it was copied from
        self.allowed_components: set[tuple] = set()
        self.allowed_props: set[tuple] = set()
        self.renamed: dict[tuple, tuple] = {}

    def key(self, component) -> tuple | None:
        """The component's key in the input (or the one it was adopted under); None if the edit added it
        without adopting it."""
        return self._keys.get(id(component))

    def adopt(self, component, source) -> None:
        """A component the edit made as a copy of `source` (and its subcomponents as copies of source's): the
        lines the copy did not change are written as source's were."""
        key = ("+", len(self._held))
        self._keys[id(component)] = key
        self._held.append(component)
        source_key = self.key(source)
        if source_key is not None:
            self._source[key] = self._source.get(source_key, source_key)
        for sub, src in zip(component.subcomponents, source.subcomponents):
            self.adopt(sub, src)

    def allow(self, component, prop: str | None = None) -> None:
        """The edit removes this component (prop None) or changes this property: its count may go down."""
        key = self.key(component)
        if key is None:
            return  # added by the edit: nothing of it was in the input
        if prop is None:
            self.allowed_components.add(key)
        else:
            self.allowed_props.add((key, prop.upper()))

    def _permitted(self, entry: tuple) -> bool:
        key = entry[0]
        if any(key[:i] in self.allowed_components for i in range(1, len(key) + 1)):
            return True
        return len(entry) >= 2 and (key, entry[1]) in self.allowed_props

    def _map(self, entry: tuple) -> tuple:
        new = self.renamed.get(entry[0])
        return entry if new is None else (new,) + entry[1:]

    def render(self, cal) -> str:
        """cal as text: written by icalendar, then the lines of every property of a component from the input
        (or adopted from one) that the edit did not change (icalendar's reading of it is as it was) put back as
        the input wrote them. icalendar re-escapes and normalises
        values it reads (REQUEST-STATUS's ';', an INTEGER's leading zeros, a TZID's commas); this way an edit
        changes only what it changed."""
        out = cal.to_ical(sorted=False).decode("utf-8")
        out_root, out_lines = _text_tree(out)
        obj_root = _Node("")
        _object_tree(cal, obj_root)
        objects = {k: n.ref for k, n in _keyed(obj_root).items()}
        for after_key, node in _keyed(out_root).items():
            ref = objects.get(after_key)
            key = self.key(ref) if ref is not None else None
            if key is None:
                continue
            if cal is self.cal and key[0] != "+" and key != after_key:
                self.renamed[key] = after_key
            source_key = self._source.get(key, key)
            source = self.before_keyed.get(source_key)
            if source is None or source_key not in self._read:
                continue
            read, now = self._read[source_key], _signatures(ref)
            for name in {p[0] for p in node.props}:
                was, is_ = read.get(name, ()), now.get(name, ())
                before = [p[5] for p in source.props if p[0] == name]
                after = [p[5] for p in node.props if p[0] == name]
                # unchanged, or only added to (what an edit adds comes after what was there); and every line of
                # it read by icalendar, so line i is value i
                if (key, name) in self.allowed_props or is_[:len(was)] != was or len(before) != len(was) \
                        or len(after) != len(is_):
                    continue  # changed by the edit: written as icalendar writes it, and checked
                for b, a in zip(before, after):
                    out_lines[a] = _crlf(self.before_lines[b])
        return "".join(out_lines)

    def result(self) -> str:
        out = self.render(self.cal)
        check(self.text, out, allowed=self._permitted, renamed=self._map, written_from=self.cal)
        return out

    # -- the event

    def events(self) -> list:
        return [c for c in self.cal.subcomponents if c.name == "VEVENT"]

    def master(self, required: bool = True):
        masters = [e for e in self.events() if e.get("RECURRENCE-ID") is None]
        if len(masters) > 1:
            raise IcsError("more than one event without RECURRENCE-ID in one resource")
        if not masters and required:
            raise IcsError("the resource has no master event (only overrides)")
        if masters and masters[0].get("DTSTART") is None:
            raise IcsError("the event has no DTSTART")
        return masters[0] if masters else None

    def overrides(self) -> list:
        return [e for e in self.events() if e.get("RECURRENCE-ID") is not None]

    def override(self, start):
        return next((o for o in self.overrides() if _same(o["RECURRENCE-ID"].dt, start)), None)


def check(before_text: str, after_text: str, *, allowed=lambda entry: False, renamed=lambda entry: entry,
          written_from=None) -> None:
    """Refuse (PropertyLossError) a written text that lost or changed anything: compared with the text that
    came in (minus what `allowed` permits, with components `renamed`), every property, value and parameter
    must still be there, and every property's value and parameters must read the same; compared with the
    object it was written from, nothing may be missing."""
    try:
        icalendar.Calendar.from_ical(after_text)
    except Exception as exc:  # noqa: BLE001
        raise PropertyLossError("the written text does not read back") from exc
    before_root, _ = _text_tree(before_text)
    after_root, _ = _text_tree(after_text)
    after = _count(after_root)
    lost = []
    for entry, n in _count(before_root).items():
        mapped = renamed(entry)
        if after.get(mapped, 0) < n and not allowed(entry):
            lost.append(f"{_describe(entry)} ({n} -> {after.get(mapped, 0)})")
    after_values = _values(after_root)
    for (key, name), values in _values(before_root).items():
        mapped = renamed((key, name))
        missing = values - after_values.get((mapped[0], name), Counter())
        if missing and not allowed((key, name)) and after.get(mapped, 0) >= sum(values.values()):
            lost.append(f"{_describe((key, name))} changed")
    if written_from is not None:
        root = _Node("")
        _object_tree(written_from, root)
        for entry, n in _count(root).items():
            if after.get(entry, 0) < n:
                lost.append(f"{_describe(entry)} lost while writing ({n} -> {after.get(entry, 0)})")
    if lost:
        raise PropertyLossError("refused: the write would lose " + "; ".join(sorted(lost)))


# ---------------------------------------------------------------- dates and times

def _is_dt(value) -> bool:
    return isinstance(value, datetime)


def _is_utc(value) -> bool:
    if not _is_dt(value) or value.tzinfo is None:
        return False
    return value.tzinfo is timezone.utc or getattr(value.tzinfo, "key", None) in ("UTC", "Etc/UTC")


def _zone(value) -> object:
    """What makes two values the same kind: date, floating, UTC, or their zone."""
    if not _is_dt(value):
        return "date"
    if value.tzinfo is None:
        return None
    if _is_utc(value):
        return "UTC"
    return getattr(value.tzinfo, "key", None) or str(value.tzinfo)


def _instant(value):
    """A comparable form: dates as dates, floating times as wall times, others in UTC."""
    if not _is_dt(value) or value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc)


def _same(a, b) -> bool:
    if _is_dt(a) != _is_dt(b):
        return False
    if _is_dt(a) and (a.tzinfo is None) != (b.tzinfo is None):
        return a.replace(tzinfo=None) == b.replace(tzinfo=None)
    return _instant(a) == _instant(b)


def _like(value, template):
    """value in template's kind: a date for an all-day series, a wall time in template's zone, UTC, or floating."""
    if not _is_dt(template):
        if _is_dt(value):
            raise IcsError("an all-day event's occurrence is a date, not a time")
        return value
    if not _is_dt(value):
        raise IcsError("a timed event's occurrence is a date and time, not a date")
    if template.tzinfo is None:
        return value.replace(tzinfo=None)
    if value.tzinfo is None:
        return value.replace(tzinfo=template.tzinfo)
    if value.tzinfo is template.tzinfo:
        return value
    return value.astimezone(template.tzinfo)


def _wall(value) -> datetime:
    return value.replace(tzinfo=None) if _is_dt(value) else datetime.combine(value, time.min)


def _add_wall(value, delta: timedelta):
    """value moved by delta on the wall clock (in UTC for UTC values); dates by whole days."""
    if not _is_dt(value):
        return value + timedelta(days=delta.days)
    if value.tzinfo is None or _is_utc(value):
        return value + delta
    return (value.replace(tzinfo=None) + delta).replace(tzinfo=value.tzinfo)


def _date_prop(value, template_prop, *, multi: bool = False):
    """A property value written like template_prop: its value type, and its TZID text when it has one. A
    TZID icalendar cannot resolve (no VTIMEZONE, not a zone it knows) reads as a floating time; a floating
    value written like it keeps that TZID."""
    tzid = template_prop.params.get("TZID") if template_prop is not None else None
    prop = vDDDLists([value]) if multi else vDDDTypes(value)
    if not _is_dt(value):
        prop.params["VALUE"] = "DATE"  # vDDDLists leaves it out, and the type must match DTSTART's
    if tzid and _is_dt(value) and not _is_utc(value):
        current = _first_dt(template_prop)
        if (value.tzinfo is not None and _zone(value) == _zone(current)) or \
                (value.tzinfo is None and _is_dt(current) and current.tzinfo is None):
            prop.params["TZID"] = tzid
    return prop


def _own_zone(value, current):
    """A new DTSTART, DTEND or DUE in the event's own zone, unless the caller names another: a floating value
    is a wall time in it (UTC for a UTC event), and one in UTC or at a fixed offset (an ISO time ending in Z
    or +01:00) is the same moment in it. A value in another named zone (a ZoneInfo) moves the event there."""
    if not (_is_dt(value) and _is_dt(current)) or current.tzinfo is None:
        return value
    if value.tzinfo is None:
        return value.replace(tzinfo=current.tzinfo)
    if not _is_utc(current) and (_is_utc(value) or getattr(value.tzinfo, "key", None) is None):
        return value.astimezone(current.tzinfo)
    return value


def _first_dt(prop):
    return prop.dts[0].dt if hasattr(prop, "dts") else prop.dt


def _duration(event) -> timedelta | None:
    """How long the event lasts (None when it has no DTEND): exact for zoned and UTC times (RFC 5545 3.8.5.3:
    every occurrence lasts exactly as long), on the wall clock for floating times, whole days for dates."""
    if event.get("DTEND") is None:
        return None
    start, end = event["DTSTART"].dt, event["DTEND"].dt
    if _is_dt(start) and _is_dt(end) and start.tzinfo is not None and end.tzinfo is not None:
        return end.astimezone(timezone.utc) - start.astimezone(timezone.utc)
    return _wall(end) - _wall(start)


def _end(start, length: timedelta, end_prop=None):
    """start + length, as _duration measures it, written in start's zone, or in the zone of end_prop (the DTEND
    it replaces) when that is another (a flight's end in the arrival zone). Across the hour skipped in spring
    the end is the exact length later, never before the start, as wall-clock adding would make it."""
    if _is_dt(start) and start.tzinfo is not None:
        end = (start.astimezone(timezone.utc) + length).astimezone(start.tzinfo)
        own = end_prop.dt if end_prop is not None else None
        if _is_dt(own) and own.tzinfo is not None and _zone(own) != _zone(end):
            end = end.astimezone(own.tzinfo)
        return end
    return _add_wall(start, length)


def _as_list(value) -> list:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


# ---------------------------------------------------------------- the occurrences of a master

def _rule_text(rule, dtstart) -> str:
    """The RRULE as dateutil reads it, with an UNTIL that does not match DTSTART's kind (RFC 5545 wants it
    to; some writers do not) read as recurring-ical-events, the calendar store's reader, reads it: for a zoned
    or UTC start, a date is that day at 00:00 UTC and a floating time is UTC; for a floating start, a UTC time
    is the wall time written and a date is that day at 00:00; for an all-day start, the date written. Never in
    the host's own zone."""
    rule = copy.deepcopy(rule)
    until = rule.get("UNTIL")
    if until:
        u = until[0]
        if not _is_dt(dtstart):
            u = u.date() if _is_dt(u) else u
        elif dtstart.tzinfo is not None:
            if not _is_dt(u):
                u = datetime.combine(u, time.min, tzinfo=timezone.utc)
            elif u.tzinfo is None:
                u = u.replace(tzinfo=timezone.utc)
            u = u.astimezone(timezone.utc)
        else:
            u = datetime.combine(u, time.min) if not _is_dt(u) else u.replace(tzinfo=None)
        rule["UNTIL"] = [u]
    return rule.to_ical().decode("ascii")


def _dt_start(master):
    start = master["DTSTART"].dt
    return start if _is_dt(start) else datetime.combine(start, time.min)


def _from_du(value, template):
    return value.date() if not _is_dt(template) else value


def _rule(master):
    rules = _as_list(master.get("RRULE"))
    if len(rules) > 1:
        raise IcsError("an event with more than one RRULE")
    if not rules:
        return None
    try:
        return du.rrulestr(_rule_text(rules[0], master["DTSTART"].dt), dtstart=_dt_start(master))
    except (ValueError, TypeError) as exc:
        raise IcsError(f"the event's RRULE cannot be read: {exc}") from exc


def _date_values(event, name: str) -> list:
    out = []
    for prop in _as_list(event.get(name)):
        for item in getattr(prop, "dts", []):
            value = item.dt
            out.append(value[0] if isinstance(value, tuple) else value)
    return out


def _starts_between(master, low, high, *, exdates: bool = True) -> list:
    """The series' starts in [low, high] (in the master's kind): DTSTART, the RRULE's, the RDATEs, less the
    EXDATEs (unless exdates is False). An EXDATE that is a date on a timed series removes every start on that
    day (the day on the series' own clock), as recurring-ical-events reads it."""
    template = master["DTSTART"].dt
    rule = _rule(master)
    found = []
    if rule is not None:
        lo, hi = _du_bound(low, template), _du_bound(high, template)
        found += [_from_du(v, template) for v in rule.between(lo, hi, inc=True)]
    for value in [template, *_date_values(master, "RDATE")]:
        try:
            value = _like(value, template)
        except IcsError:
            continue
        if _le(low, value) and _le(value, high):
            found.append(value)
    if exdates:
        values = _date_values(master, "EXDATE")
        gone = [_like(v, template) for v in values if _is_dt(v) == _is_dt(template)]
        days = {v for v in values if not _is_dt(v)} if _is_dt(template) else set()
        found = [v for v in found if not any(_same(v, g) for g in gone) and _wall(v).date() not in days]
    unique = []
    for v in sorted(found, key=lambda v: _instant(v) if _is_dt(v) and v.tzinfo else _wall(v)):
        if not unique or not _same(unique[-1], v):
            unique.append(v)
    return unique


def _du_bound(value, template):
    if not _is_dt(template):
        return datetime.combine(value, time.min) if not _is_dt(value) else value
    return value


def _le(a, b) -> bool:
    if _is_dt(a) and a.tzinfo is not None and _is_dt(b) and b.tzinfo is not None:
        return _instant(a) <= _instant(b)
    return _wall(a) <= _wall(b)


def occurrence(master, start, *, exdates: bool = True):
    """The series' own value for the occurrence that starts at `start` (any kind that names the same
    moment); IcsError when there is none."""
    template = master["DTSTART"].dt
    wanted = _like(start, template)
    span = timedelta(days=2)
    for value in _starts_between(master, _add_wall(wanted, -span), _add_wall(wanted, span), exdates=exdates):
        if _same(value, wanted):
            return value
    raise IcsError(f"{start} is not an occurrence of this event")


def _rule_starts_before(master, start) -> int:
    """How many starts the RRULE gives before `start` (EXDATEs count: COUNT counts them)."""
    rule = _rule(master)
    template = master["DTSTART"].dt
    n = 0
    for value in rule:
        if not _le(_from_du(value, template), start) or _same(_from_du(value, template), start):
            break
        n += 1
    return n


def _is_rule_start(master, start) -> bool:
    rule = _rule(master)
    if rule is None:
        return False
    template = master["DTSTART"].dt
    lo = _du_bound(_add_wall(start, -timedelta(days=1)), template)
    hi = _du_bound(_add_wall(start, timedelta(days=1)), template)
    return any(_same(_from_du(v, template), start) for v in rule.between(lo, hi, inc=True)) or _same(start, template)


# ---------------------------------------------------------------- changing components

def _set(component, name: str, value) -> None:
    """Set a property, keeping its place among the others (a new one goes last); None removes it."""
    name = name.upper()
    items = list(component.items())
    present = any(k.upper() == name for k, _v in items)
    if value is None:
        component.pop(name, None)
        return
    if not present:
        if hasattr(value, "params") or isinstance(value, list):
            component[name] = value
        else:
            component.add(name, value)
        return
    component.clear()
    for k, v in items:
        if k.upper() == name:
            if hasattr(value, "params") or isinstance(value, list):
                component[k] = value
            else:
                component.add(name, value)
        else:
            component[k] = v


def _value(component, name: str, value):
    """A change's value as a property, written like the property it replaces where that matters (dates)."""
    if value is None or hasattr(value, "params") or isinstance(value, list):
        return value
    if isinstance(value, (date, datetime)) and name in ("DTSTART", "DTEND", "DUE", "RECURRENCE-ID"):
        template = component.get(name) or component.get("DTSTART")
        if template is not None:
            value = _own_zone(value, template.dt)
        return _date_prop(value, template)
    if name == "RRULE":
        return icalendar.vRecur.from_ical(value) if isinstance(value, str) else icalendar.vRecur(value)
    return value


def _touch(edit: _Edit, component, now: datetime, *, timing: bool) -> None:
    for name in _STAMPS:
        edit.allow(component, name)
    stamp = now.astimezone(timezone.utc).replace(microsecond=0)
    _set(component, "DTSTAMP", vDDDTypes(stamp))
    _set(component, "LAST-MODIFIED", vDDDTypes(stamp))
    if timing:
        _set(component, "SEQUENCE", int(component.get("SEQUENCE", 0)) + 1)


def _remove(parent, component) -> None:
    """Remove this very component (list.remove would take the first one equal to it)."""
    parent.subcomponents[:] = [c for c in parent.subcomponents if c is not component]


def _same_value(a, b) -> bool:
    """Whether two values of a property (one value, or a list of them) are the same, parameters included."""
    if a is None or b is None:
        return a is None and b is None
    a, b = _as_list(a), _as_list(b)

    def sign(v):
        text = v.to_ical() if hasattr(type(v), "to_ical") else v
        return text, tuple(sorted((k.upper(), str(x)) for k, x in getattr(v, "params", {}).items()))

    return len(a) == len(b) and all(sign(x) == sign(y) for x, y in zip(a, b))


def _apply(edit: _Edit, component, changes: Mapping[str, object]) -> None:
    for name, value in changes.items():
        name = name.upper()
        if name in ("UID", "RECURRENCE-ID", "BEGIN", "END"):
            raise IcsError(f"{name} cannot be changed")
        edit.allow(component, name)
        _set(component, name, _value(component, name, value))


def _now(now: datetime | None) -> datetime:
    return now or datetime.now(timezone.utc)


def _check_changes(changes: Mapping[str, object]) -> dict[str, object]:
    out = {k.upper(): v for k, v in changes.items()}
    for name in out:
        if name in _SERIES_ONLY[1:]:
            raise IcsError(f"{name} is changed through the occurrence functions, not as a field")
    return out


# ---------------------------------------------------------------- the four edits of a repeating event

def edit_this(text: str, recurrence_id, changes: Mapping[str, object], *, now: datetime | None = None) -> str:
    """Change one occurrence: its override, made from the master if there is none yet."""
    changes = _check_changes(changes)
    if "RRULE" in changes:
        raise IcsError("one occurrence has no rule")
    edit = _Edit(text)
    master = edit.master(required=False)
    override = None
    if master is not None:
        start = occurrence(master, recurrence_id)
        override = edit.override(start)
    else:
        override = next((o for o in edit.overrides() if _same(o["RECURRENCE-ID"].dt, recurrence_id)), None)
        if override is None:
            raise IcsError(f"{recurrence_id} is not an occurrence of this event")
    if override is None:
        override = _new_override(master, start, _now(now))
        edit.cal.add_component(override)
        edit.adopt(override, master)
    if "DTSTART" in changes and "DTEND" not in changes and override.get("DTEND") is not None:
        length = _duration(override)
        new_start = _value(override, "DTSTART", changes["DTSTART"])
        changes["DTEND"] = _date_prop(_end(new_start.dt, length, override["DTEND"]) if length is not None
                                      else new_start.dt, override["DTEND"])
    _apply(edit, override, changes)
    _touch(edit, override, _now(now), timing=bool(_TIMING & changes.keys()))
    return edit.result()


def _new_override(master, start, now: datetime):
    override = icalendar.Event()
    length = _duration(master)
    for name, value in master.property_items(recursive=False, sorted=False):
        name = name.upper()
        if name in ("BEGIN", "END") or name in _SERIES_ONLY:
            continue
        if name == "DTSTART":
            override["DTSTART"] = _date_prop(start, master["DTSTART"])
            override["RECURRENCE-ID"] = _date_prop(start, master["DTSTART"])
        elif name == "DTEND":
            override["DTEND"] = _date_prop(_end(start, length, master["DTEND"]), master["DTEND"])
        else:
            override[name] = copy.deepcopy(master[name])
    for sub in master.subcomponents:
        override.add_component(copy.deepcopy(sub))
    return override


def delete_this(text: str, recurrence_id, *, now: datetime | None = None) -> str:
    """Remove one occurrence: an EXDATE written like DTSTART, and its override if it has one."""
    edit = _Edit(text)
    master = edit.master()
    try:
        start = occurrence(master, recurrence_id)
    except IcsError:
        override = edit.override(_like(recurrence_id, master["DTSTART"].dt))
        if override is None:
            raise
        start = _like(override["RECURRENCE-ID"].dt, master["DTSTART"].dt)
    override = edit.override(start)
    if override is not None:
        edit.allow(override)
        _remove(edit.cal, override)
    master.add("EXDATE", _date_prop(start, master["DTSTART"], multi=True))
    _touch(edit, master, _now(now), timing=True)
    return edit.result()


def _exceptions(edit: _Edit, master) -> tuple[list, list]:
    """(EXDATE values, overrides) that are occurrences of the series as it is now (stale ones are left alone);
    a date EXDATE of a timed series counts when the series has a start that day."""
    live_ex = [v for v in _date_values(master, "EXDATE") if _still(master, v)]
    live_ov = []
    for o in edit.overrides():
        try:
            occurrence(master, o["RECURRENCE-ID"].dt, exdates=False)
            live_ov.append(o)
        except IcsError:
            pass
    return live_ex, live_ov


def _map_dates(prop, fn):
    """The same EXDATE or RDATE property with each value passed through fn (None drops it); None when empty."""
    values = []
    for item in prop.dts:
        v = item.dt
        new = (fn(v[0]), v[1] if isinstance(v[1], timedelta) else fn(v[1])) if isinstance(v, tuple) else fn(v)
        if new is not None and (not isinstance(new, tuple) or new[0] is not None):
            values.append(new)
    if not values:
        return None
    out = vDDDLists(values)
    out.params = icalendar.Parameters(prop.params)
    return out


def _rewrite_dates(edit: _Edit, component, name: str, fn) -> None:
    props = _as_list(component.get(name))
    if not props:
        return
    edit.allow(component, name)
    kept = [p for p in (_map_dates(prop, fn) for prop in props) if p is not None]
    _set(component, name, None)
    for p in kept:
        component.add(name, p)


def edit_all(text: str, changes: Mapping[str, object], *, exceptions: str = "keep",
             now: datetime | None = None) -> str:
    """Change every occurrence (see the module docstring for what moves with a new time)."""
    if exceptions not in ("keep", "drop"):
        raise IcsError("exceptions must be 'keep' or 'drop'")
    changes = _check_changes(changes)
    edit = _Edit(text)
    master = edit.master()
    now = _now(now)
    old = {name: copy.deepcopy(master.get(name)) for name in changes}
    old_start = master["DTSTART"].dt
    old_length = _duration(master)
    live_ex, live_ov = _exceptions(edit, master)

    new_start = old_start
    if "DTSTART" in changes:
        new_start = _value(master, "DTSTART", changes["DTSTART"]).dt
        if "DTEND" not in changes and master.get("DTEND") is not None:
            changes["DTEND"] = _date_prop(_end(new_start, old_length, master["DTEND"]), master["DTEND"])
    delta = _wall(new_start) - _wall(old_start)
    time_only = (_is_dt(old_start) and _is_dt(new_start) and _zone(old_start) == _zone(new_start)
                 and _wall(old_start).date() == _wall(new_start).date() and delta != timedelta(0))

    old_master = copy.deepcopy(master)
    _apply(edit, master, changes)
    shift = _shifter(old_master, delta)
    if time_only:
        _rewrite_dates(edit, master, "EXDATE", shift)
        _rewrite_dates(edit, master, "RDATE", shift)
        if "RRULE" not in changes and master.get("RRULE") is not None:
            rule = master["RRULE"]
            until = rule.get("UNTIL")
            if until and _is_dt(until[0]):
                edit.allow(master, "RRULE")
                rule["UNTIL"] = [_moved_until(old_master, until[0], delta)]
        for o in edit.overrides():
            edit.allow(o, "RECURRENCE-ID")
            rid = o["RECURRENCE-ID"]
            unmoved = _same(o["DTSTART"].dt, rid.dt) if o.get("DTSTART") is not None else False
            _set(o, "RECURRENCE-ID", _date_prop(shift(rid.dt), rid))
            if unmoved:
                edit.allow(o, "DTSTART")
                edit.allow(o, "DTEND")
                length = _duration(o)
                if length == old_length:  # its length was not changed for it: it follows the master's
                    length = _duration(master)
                _set(o, "DTSTART", _date_prop(shift(o["DTSTART"].dt), o["DTSTART"]))
                if length is not None:
                    _set(o, "DTEND", _date_prop(_end(o["DTSTART"].dt, length, o["DTEND"]), o["DTEND"]))
            _touch(edit, o, now, timing=True)

    # Exceptions that were occurrences before and are not now: refuse, or drop them when asked.
    if time_only:
        live_ex = [shift(v) for v in live_ex]
    stale_ex = [v for v in live_ex if not _still(master, v)]
    stale_ov = [o for o in live_ov if not _still(master, o["RECURRENCE-ID"].dt)]
    if stale_ex or stale_ov:
        if exceptions != "drop":
            raise IcsError(f"the change leaves {len(stale_ex)} deleted and {len(stale_ov)} changed occurrence(s) on "
                           "times that are no longer occurrences; pass exceptions='drop' to remove them")
        _rewrite_dates(edit, master, "EXDATE", lambda v: None if any(_same(v, s) for s in stale_ex) else v)
        for o in stale_ov:
            edit.allow(o)
            _remove(edit.cal, o)

    # Fields an override did not change follow the master.
    for o in edit.overrides():
        for name, before in old.items():
            if name in _TIMING or name in ("DTSTART", "DTEND"):
                continue
            if _same_value(o.get(name), before):
                edit.allow(o, name)
                _set(o, name, copy.deepcopy(master.get(name)))
        if old_length is not None and "DTEND" in changes and o.get("DTEND") is not None and \
                _duration(o) == old_length != _duration(master):
            edit.allow(o, "DTEND")
            _set(o, "DTEND", _date_prop(_end(o["DTSTART"].dt, _duration(master), o["DTEND"]), o["DTEND"]))
    _touch(edit, master, now, timing=bool(_TIMING & changes.keys()))
    return edit.result()


def _in_kind_of(value, like):
    """value (a time on the series' clock) written in like's kind: UTC, its own zone, or floating."""
    if value.tzinfo is None or like.tzinfo is None:
        return value.replace(tzinfo=like.tzinfo) if value.tzinfo is None else value.replace(tzinfo=None)
    if _is_utc(like):
        return value.astimezone(timezone.utc)
    return value if _zone(value) == _zone(like) else value.astimezone(like.tzinfo)


def _shifter(old_master, delta: timedelta):
    """The function that moves an EXDATE, RDATE or RECURRENCE-ID with a change of the series' time of day:
    on the series' own clock (its DTSTART zone), whatever zone the value is written in, and written back in
    that zone. A value in UTC on a zoned series moves by the wall-clock change in that zone, which differs from
    the UTC change on a day the clocks change. A value that names an occurrence is moved from the occurrence's
    own wall time, so one in the skipped hour (02:30 read as 14:30 UTC) moves as the occurrence does."""
    template = old_master["DTSTART"].dt

    def shift(v):
        if not _is_dt(v):
            return v
        if template.tzinfo is None:
            return _add_wall(v, delta)
        try:
            wall = occurrence(old_master, v, exdates=False)
        except IcsError:
            wall = _like(v, template)
        return _in_kind_of(_add_wall(wall, delta), v)

    return shift


def _moved_until(old_master, until, delta: timedelta):
    """The UNTIL that ends the moved series after the same occurrence: the old last start of the rule moved on
    the series' clock (in UTC for zoned and UTC series, local for floating ones). Adding the change to UNTIL
    in UTC loses the last occurrence when it falls on the far side of a clock change from its new time."""
    template = old_master["DTSTART"].dt
    last = None
    for value in _rule(old_master):
        last = value
    if last is None:
        return _shifter(old_master, delta)(until)
    moved = _add_wall(_from_du(last, template), delta)
    return moved if moved.tzinfo is None else moved.astimezone(timezone.utc)


def _still(master, value) -> bool:
    """Whether value (an EXDATE or RECURRENCE-ID) names an occurrence of the series, EXDATEs left aside; a
    date on a timed series, whether the series starts on that day."""
    template = master["DTSTART"].dt
    if _is_dt(template) and not _is_dt(value):
        day = datetime.combine(value, time.min)
        span = _starts_between(master, _like(day - timedelta(days=1), template), _like(day + timedelta(days=2),
                               template), exdates=False)
        return any(_wall(v).date() == value for v in span)
    try:
        occurrence(master, value, exdates=False)
        return True
    except IcsError:
        return False


def _until_before(start, template):
    """The UNTIL that ends a series just before `start`: in UTC for zoned and UTC times, local for floating
    times, the day before for all-day events."""
    if not _is_dt(template):
        return start - timedelta(days=1)
    if template.tzinfo is None:
        return start - timedelta(seconds=1)
    return start.astimezone(timezone.utc) - timedelta(seconds=1)


def edit_following(text: str, recurrence_id, changes: Mapping[str, object], *, exceptions: str = "keep",
                   new_uid: str | None = None, now: datetime | None = None) -> tuple[str, str | None]:
    """Change this occurrence and every later one: the series is split (see the module docstring). Returns
    (the old resource, the new one); from the first occurrence it is edit_all, and the second is None."""
    changes = _check_changes(changes)
    edit = _Edit(text)
    master = edit.master()
    now = _now(now)
    template = master["DTSTART"].dt
    start = occurrence(master, recurrence_id)
    if _same(start, template):
        return edit_all(text, changes, exceptions=exceptions, now=now), None
    if master.get("RRULE") is None or not _is_rule_start(master, start):
        raise IcsError("this and following can only start from an occurrence of the rule (not an extra date, "
                       "RDATE); change this event or all events instead")

    def later(v) -> bool:
        """Whether a date value (EXDATE, RDATE, RECURRENCE-ID) belongs to the new series; a date EXDATE of a
        timed series does from the day of the split on."""
        if _is_dt(template) and not _is_dt(v):
            return v >= _wall(start).date()
        return _is_dt(v) == _is_dt(template) and _le(start, _like(v, template))

    # The new series: a copy of the master from this occurrence on, with what lies after it.
    uid = new_uid or str(uuid.uuid4()).upper()
    old_uid = str(master.get("UID"))
    new_master = copy.deepcopy(master)
    rule = new_master["RRULE"]
    old_rule = master["RRULE"]
    if old_rule.get("COUNT"):
        before = _rule_starts_before(master, start)
        rule["COUNT"] = [int(old_rule["COUNT"][0]) - before]
        old_rule["COUNT"] = [before]
    else:
        old_rule.pop("UNTIL", None)
        old_rule["UNTIL"] = [_until_before(start, template)]
    edit.allow(master, "RRULE")

    new_cal = icalendar.Calendar()
    for name in ("VERSION", "PRODID", "CALSCALE"):
        if edit.cal.get(name) is not None:
            new_cal[name] = copy.deepcopy(edit.cal[name])
    if new_cal.get("VERSION") is None:
        new_cal.add("VERSION", "2.0")
    if new_cal.get("PRODID") is None:
        new_cal.add("PRODID", PRODID)
    for tz in edit.cal.walk("VTIMEZONE"):
        new_cal.add_component(copy.deepcopy(tz))
    _set(new_master, "UID", uid)
    _set(new_master, "DTSTART", _date_prop(start, master["DTSTART"]))
    length = _duration(master)
    if master.get("DTEND") is not None:
        _set(new_master, "DTEND", _date_prop(_end(start, length, master["DTEND"]), master["DTEND"]))
    _set(new_master, SPLIT_FROM, old_uid)
    _set(new_master, "SEQUENCE", 0)
    stamp = vDDDTypes(now.astimezone(timezone.utc).replace(microsecond=0))
    _set(new_master, "CREATED", stamp)
    _set(new_master, "DTSTAMP", copy.deepcopy(stamp))
    for name in ("EXDATE", "RDATE"):
        _set(new_master, name, None)
        for prop in _as_list(master.get(name)):
            moved = _map_dates(prop, lambda v: v if later(v) else None)
            if moved is not None:
                new_master.add(name, moved)
        _rewrite_dates(edit, master, name, lambda v: None if later(v) else v)
    new_cal.add_component(new_master)
    for o in list(edit.overrides()):
        if later(o["RECURRENCE-ID"].dt):
            moved = copy.deepcopy(o)
            _set(moved, "UID", uid)
            new_cal.add_component(moved)
            edit.allow(o)
            _remove(edit.cal, o)
    _touch(edit, master, now, timing=True)
    old_text = edit.result()
    new_text = new_cal.to_ical(sorted=False).decode("utf-8")
    check(new_text, new_text, written_from=new_cal)
    if changes:
        new_text = edit_all(new_text, changes, exceptions=exceptions, now=now)
    return old_text, new_text


# ---------------------------------------------------------------- simple events, and time zones for the export

def edit_event(text: str, changes: Mapping[str, object], *, now: datetime | None = None) -> str:
    """Change an event that does not repeat (for a repeating one, use edit_all)."""
    edit = _Edit(text)
    master = edit.master()
    if master.get("RRULE") is not None or master.get("RDATE") is not None or edit.overrides():
        raise IcsError("a repeating event: use edit_this, edit_all or edit_following")
    return edit_all(text, changes, now=now)


def new_event(summary: str, start, end=None, *, uid: str | None = None, rrule: str | None = None,
              now: datetime | None = None, **fields) -> str:
    """A new resource: one VEVENT with a UID (a random UUID unless given) and TZIDs only (no VTIMEZONE)."""
    cal = icalendar.Calendar()
    cal.add("VERSION", "2.0")
    cal.add("PRODID", PRODID)
    event = icalendar.Event()
    stamp = _now(now).astimezone(timezone.utc).replace(microsecond=0)
    event.add("UID", uid or str(uuid.uuid4()).upper())
    event.add("DTSTAMP", stamp)
    event.add("CREATED", stamp)
    event.add("SEQUENCE", 0)
    event.add("DTSTART", start)
    if end is not None:
        event.add("DTEND", end)
    event.add("SUMMARY", summary)
    if rrule:
        event.add("RRULE", icalendar.vRecur.from_ical(rrule))
    for name, value in fields.items():
        event.add(name.upper().replace("_", "-"), value)
    cal.add_component(event)
    out = cal.to_ical(sorted=False).decode("utf-8")
    check(out, out, written_from=cal)
    return out


def iana_zone(tzid: str) -> str | None:
    """The IANA name for a TZID: itself, or the zone a Windows name (Outlook, Exchange) stands for."""
    from icalendar.timezone.windows_to_olson import WINDOWS_TO_OLSON

    name = tzid.strip().strip('"')
    try:
        ZoneInfo(name)
        return name
    except (ZoneInfoNotFoundError, ValueError):
        pass
    mapped = WINDOWS_TO_OLSON.get(name)
    return mapped


def vtimezone(tzid: str, first: date = date(1970, 1, 1), last: date = date(2038, 1, 1)) -> str | None:
    """A VTIMEZONE for a TZID, generated from the zone data and named with that TZID, covering first to last
    (icalendar's limit is 1970 to 2038 by default; outside it the last offset holds). None when the TZID is
    neither an IANA nor a Windows zone name."""
    name = iana_zone(tzid)
    if name is None:
        return None
    zone = icalendar.Timezone.from_tzid(name, first_date=first, last_date=last)
    _set(zone, "TZID", tzid.strip().strip('"'))
    return zone.to_ical(sorted=False).decode("utf-8")


def referenced_tzids(text: str) -> list[str]:
    """Every TZID a component's property names (outside VTIMEZONEs), in order of first use."""
    out: list[str] = []
    depth_tz = 0
    for line in _unfold(text):
        prop = parse_line(line)
        if prop is None:
            continue
        if prop.key == "BEGIN" and prop.value.strip().upper() == "VTIMEZONE":
            depth_tz += 1
        elif prop.key == "END" and prop.value.strip().upper() == "VTIMEZONE":
            depth_tz -= 1
        elif depth_tz == 0:
            for tzid in prop.param("TZID"):
                if tzid not in out:
                    out.append(tzid)
    return out


def defined_tzids(text: str) -> list[str]:
    """The TZIDs the text's own VTIMEZONEs define."""
    out: list[str] = []
    inside = False
    for line in _unfold(text):
        prop = parse_line(line)
        if prop is None:
            continue
        if prop.key == "BEGIN" and prop.value.strip().upper() == "VTIMEZONE":
            inside = True
        elif prop.key == "END" and prop.value.strip().upper() == "VTIMEZONE":
            inside = False
        elif inside and prop.key == "TZID" and prop.value.strip() not in out:
            out.append(prop.value.strip())
    return out

