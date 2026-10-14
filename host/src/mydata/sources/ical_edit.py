"""Edit an iCalendar resource (one event: its master VEVENT and its overrides) and refuse any write that loses
something.

Edits go through icalendar (7.3), written with sorted=False so properties keep their order, and a replaced
property keeps its place. Before a write is accepted, the new text is read back and compared, component by
component, with the text that came in: the count of each property (of each value, for EXDATE, RDATE,
CATEGORIES and RESOURCES) and of each of its parameters. If anything went down that the edit did not remove
on purpose, the write is refused (PropertyLossError); icalendar has dropped properties before (#1870). The
text is also compared with the edited object, so a property lost while writing is caught as well. The input
is counted from its own text, not from icalendar's reading of it, so a line icalendar skips is caught too.

Time zones: the writer stores TZIDs only, written as the event's own DTSTART writes them (an Outlook
"W. Europe Standard Time" stays that, though icalendar reads it as Europe/Berlin). It never adds a VTIMEZONE;
the export adds them (vtimezone()). A VTIMEZONE a resource came with is kept.

Repeating events (RFC 5545). A changed occurrence is named by its original start (its RECURRENCE-ID). Never
RANGE=THISANDFUTURE, which few clients read.

- edit_this: an override (a VEVENT with that RECURRENCE-ID) is added as a copy of the master, or the
  existing one is changed.
- delete_this: an EXDATE with DTSTART's value type and TZID, and the occurrence's override is removed.
- edit_all: the master changes. When only the time of day moves, every EXDATE, RDATE, override and date-time
  UNTIL moves with it, so deleted and changed occurrences stay deleted and changed. An edit that leaves an
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


def inventory(text: str) -> Counter:
    """What the text holds, counted from its own lines: per component, each property (each value of
    EXDATE, RDATE, CATEGORIES, RESOURCES) and each of its parameters."""
    return _count(_text_tree(text)[0])


def _describe(entry: tuple) -> str:
    key = entry[0]
    where = "/".join(":".join(str(x) for x in part[:-1] if x != "") or part[0] for part in key)
    return where + ("" if len(entry) == 1 else " " + ";".join(entry[1:]))


# ---------------------------------------------------------------- one edit, checked before it is written

# What the writer reads from a component: icalendar must have read these, and an event holds one of each.
_READ = ("DTSTART", "DTEND", "DUE", "DURATION", "RECURRENCE-ID", "EXDATE", "RDATE", "RRULE", "SEQUENCE", "UID")
_ONE = ("DTSTART", "DTEND", "DUE", "DURATION", "RECURRENCE-ID", "UID", "SEQUENCE")


class _Edit:
    """One edit of one resource. Components are known by their key in the input (computed once, kept by
    identity), so allow() is cheap and a component whose key changes (an override moved with its series) is
    followed."""

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
        for key, node in _keyed(root).items():
            self._keys[id(node.ref)] = key
            self._held.append(node.ref)
        self.allowed_components: set[tuple] = set()
        self.allowed_props: set[tuple] = set()
        self.renamed: dict[tuple, tuple] = {}

    def key(self, component) -> tuple | None:
        """The component's key in the input; None if the edit added it."""
        return self._keys.get(id(component))

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
        """cal as text; a component of the input whose key changed is noted in `renamed`."""
        out = cal.to_ical(sorted=False).decode("utf-8")
        out_root, _ = _text_tree(out)
        obj_root = _Node("")
        _object_tree(cal, obj_root)
        objects = {k: n.ref for k, n in _keyed(obj_root).items()}
        for after_key in _keyed(out_root):
            ref = objects.get(after_key)
            key = self.key(ref) if ref is not None else None
            if key is not None and key != after_key:
                self.renamed[key] = after_key
        return out

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
    """Refuse (PropertyLossError) a written text that lost anything: compared with the text that came in
    (minus what `allowed` permits, with components `renamed`), and with the object it was written from."""
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
    """A property value written like template_prop: its value type, and its TZID text when it has one."""
    tzid = template_prop.params.get("TZID") if template_prop is not None else None
    prop = vDDDLists([value]) if multi else vDDDTypes(value)
    if not _is_dt(value):
        prop.params["VALUE"] = "DATE"  # vDDDLists leaves it out, and the type must match DTSTART's
    if tzid and _is_dt(value) and value.tzinfo is not None and not _is_utc(value) and \
            _zone(value) == _zone(_first_dt(template_prop)):
        prop.params["TZID"] = tzid
    return prop


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


def _end(start, length: timedelta):
    """start + length, as _duration measures it, written in start's zone. Across the hour skipped in spring
    the end is the exact length later, never before the start, as wall-clock adding would make it."""
    if _is_dt(start) and start.tzinfo is not None:
        return (start.astimezone(timezone.utc) + length).astimezone(start.tzinfo)
    return _add_wall(start, length)


def _as_list(value) -> list:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


# ---------------------------------------------------------------- the occurrences of a master

def _rule_text(rule, dtstart) -> str:
    """The RRULE as dateutil reads it, with UNTIL made to agree with DTSTART's kind (RFC 5545 wants that;
    some writers do not)."""
    rule = copy.deepcopy(rule)
    until = rule.get("UNTIL")
    if until:
        u = until[0]
        if not _is_dt(dtstart):
            u = u.date() if _is_dt(u) else u
        elif dtstart.tzinfo is not None:
            if not _is_dt(u):
                u = datetime.combine(u, time(23, 59, 59), tzinfo=dtstart.tzinfo)
            elif u.tzinfo is None:
                u = u.replace(tzinfo=dtstart.tzinfo)
            u = u.astimezone(timezone.utc)
        else:
            u = (u.replace(tzinfo=None) if _is_dt(u) and u.tzinfo is not None and not _is_utc(u) else
                 u.astimezone(dtstart.tzinfo).replace(tzinfo=None) if _is_dt(u) and u.tzinfo is not None else
                 datetime.combine(u, time(23, 59, 59)) if not _is_dt(u) else u)
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
    EXDATEs (unless exdates is False)."""
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
        gone = [_like(v, template) for v in _date_values(master, "EXDATE") if _is_dt(v) == _is_dt(template)]
        found = [v for v in found if not any(_same(v, g) for g in gone)]
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
    if a is None or b is None:
        return a is None and b is None
    try:
        return a.to_ical() == b.to_ical()
    except AttributeError:
        return a == b


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
    if "DTSTART" in changes and "DTEND" not in changes and override.get("DTEND") is not None:
        length = _duration(override)
        new_start = _value(override, "DTSTART", changes["DTSTART"])
        changes["DTEND"] = _date_prop(_end(new_start.dt, length) if length is not None else new_start.dt,
                                      override["DTEND"])
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
            override["DTEND"] = _date_prop(_end(start, length), master["DTEND"])
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
    """(EXDATE values, overrides) that are occurrences of the series as it is now (stale ones are left alone)."""
    template = master["DTSTART"].dt
    exdates = [v for v in _date_values(master, "EXDATE") if _is_dt(v) == _is_dt(template)]
    live_ex = []
    for v in exdates:
        try:
            occurrence(master, v, exdates=False)
            live_ex.append(v)
        except IcsError:
            pass
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
            changes["DTEND"] = _date_prop(_end(new_start, old_length), master["DTEND"])
    delta = _wall(new_start) - _wall(old_start)
    time_only = (_is_dt(old_start) and _is_dt(new_start) and _zone(old_start) == _zone(new_start)
                 and _wall(old_start).date() == _wall(new_start).date() and delta != timedelta(0))

    _apply(edit, master, changes)
    if time_only:
        def shift(v):
            return _add_wall(v, delta) if _is_dt(v) else v

        _rewrite_dates(edit, master, "EXDATE", shift)
        _rewrite_dates(edit, master, "RDATE", shift)
        if "RRULE" not in changes and master.get("RRULE") is not None:
            rule = master["RRULE"]
            until = rule.get("UNTIL")
            if until and _is_dt(until[0]):
                edit.allow(master, "RRULE")
                rule["UNTIL"] = [_add_wall(until[0], delta)]
        for o in edit.overrides():
            edit.allow(o, "RECURRENCE-ID")
            rid = o["RECURRENCE-ID"]
            unmoved = _same(o["DTSTART"].dt, rid.dt) if o.get("DTSTART") is not None else False
            _set(o, "RECURRENCE-ID", _date_prop(_add_wall(rid.dt, delta), rid))
            if unmoved:
                edit.allow(o, "DTSTART")
                edit.allow(o, "DTEND")
                length = _duration(o)
                _set(o, "DTSTART", _date_prop(_add_wall(o["DTSTART"].dt, delta), o["DTSTART"]))
                if length is not None:
                    _set(o, "DTEND", _date_prop(_end(o["DTSTART"].dt, length), o["DTEND"]))
            _touch(edit, o, now, timing=True)

    # Exceptions that were occurrences before and are not now: refuse, or drop them when asked.
    if time_only:
        live_ex = [_add_wall(v, delta) for v in live_ex]
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
        if old_length is not None and "DTEND" in changes and "DTSTART" not in changes and \
                o.get("DTEND") is not None and _duration(o) == old_length:
            edit.allow(o, "DTEND")
            _set(o, "DTEND", _date_prop(_end(o["DTSTART"].dt, _duration(master)), o["DTEND"]))
    _touch(edit, master, now, timing=bool(_TIMING & changes.keys()))
    return edit.result()


def _still(master, value) -> bool:
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
        """Whether a date value (EXDATE, RDATE, RECURRENCE-ID) belongs to the new series."""
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
        _set(new_master, "DTEND", _date_prop(_end(start, length), master["DTEND"]))
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

