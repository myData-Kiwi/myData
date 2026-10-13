"""Read iCalendar resources for the calendar mirror: summarise a resource when it is stored, and
expand it into occurrences when it is queried.

A resource is one CalDAV object: a VCALENDAR holding one event's master VEVENT and its RECURRENCE-ID
overrides (and possibly VTIMEZONEs, or VTODOs, which are ignored). Expansion is done by
recurring-ical-events; this module only decides which occurrences overlap a range and how to write
them out.

Time rules:
- Timed events with a zone are converted to the caller's zone for output; ``time_zone`` keeps the
  event's own zone name.
- Floating times (no zone) are read in the caller's zone.
- All-day events are dates; their end is exclusive (RFC 5545), and they occupy whole days in the
  caller's zone when deciding overlap.
- Ambiguous local times (the repeated hour when clocks go back) take the first occurrence, as
  RFC 5545 says; zoneinfo's fold=0 does exactly that.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone, tzinfo
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import icalendar
import recurring_ical_events

# How far a stored resource's bounds are widened, so floating and all-day times (which have no fixed
# instant) are found from any zone. Real offsets lie within -12 and +14 hours.
_SLACK = timedelta(days=1)


def local_timezone() -> tzinfo:
    """The machine's own zone, as an IANA ZoneInfo when it can be named (macOS and Linux link
    /etc/localtime into the zoneinfo tree), else whatever offset the OS reports right now."""
    tz_env = os.environ.get("TZ", "").lstrip(":")
    if tz_env:
        try:
            return ZoneInfo(tz_env)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    try:
        target = os.path.realpath("/etc/localtime")
        marker = "zoneinfo/"
        if marker in target:
            return ZoneInfo(target.split(marker, 1)[1])
    except (OSError, ZoneInfoNotFoundError, ValueError):
        pass
    return datetime.now().astimezone().tzinfo or timezone.utc


@dataclass
class ParsedResource:
    """What the store keeps beside the raw text of one calendar resource."""

    uid: str
    title: str
    has_event: bool
    range_start: str | None  # UTC, widened by a day; None when unknown
    range_end: str | None  # UTC, widened by a day; None when the series never ends (or unknown)


def parse_calendar(text: str) -> icalendar.Calendar:
    return icalendar.Calendar.from_ical(text)


def _events(cal: icalendar.Calendar) -> list:
    return [c for c in cal.walk("VEVENT")]


def _utc(value, *, end: bool = False) -> datetime:
    """An instant for bounds only: aware -> UTC; naive or date -> read as UTC (the slack covers it)."""
    if isinstance(value, datetime):
        if value.tzinfo is None or value.utcoffset() is None:
            return value.replace(tzinfo=None)
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    if isinstance(value, date):
        return datetime.combine(value, time.min)
    raise TypeError(f"not a date or time: {type(value).__name__}")


def _duration(event) -> timedelta:
    start = event.get("DTSTART")
    if start is None:
        return timedelta(0)
    start = start.dt
    if event.get("DTEND") is not None:
        end = event["DTEND"].dt
        try:
            if isinstance(start, datetime) and isinstance(end, datetime):
                if (start.tzinfo is None) != (end.tzinfo is None):
                    return max(_utc(end) - _utc(start), timedelta(0))
            return max(end - start, timedelta(0))
        except TypeError:
            return max(_utc(end) - _utc(start), timedelta(0))
    if event.get("DURATION") is not None:
        return max(event["DURATION"].dt, timedelta(0))
    return timedelta(days=1) if not isinstance(start, datetime) else timedelta(0)


def summarise(text: str) -> ParsedResource:
    """Summarise a resource for storage. Raises ValueError when the text is not iCalendar."""
    try:
        cal = parse_calendar(text)
    except Exception as exc:  # noqa: BLE001 - icalendar raises several types for bad input
        raise ValueError("not a readable iCalendar resource") from exc
    events = [e for e in _events(cal) if e.get("DTSTART") is not None]
    if not events:
        uid = next((str(c.get("UID")) for c in cal.walk() if c.get("UID")), "")
        return ParsedResource(uid=uid, title="", has_event=False, range_start=None, range_end=None)

    master = next((e for e in events if e.get("RECURRENCE-ID") is None), events[0])
    starts: list[datetime] = []
    ends: list[datetime] = []
    unbounded = False
    for event in events:
        start = event["DTSTART"].dt
        length = _duration(event)
        starts.append(_utc(start))
        ends.append(_later(_utc(start), length))
        for rdate in _rdates(event):
            starts.append(_utc(rdate))
            ends.append(_later(_utc(rdate), length))
        for rule in _as_list(event.get("RRULE")):
            until = rule.get("UNTIL")
            if not until:
                unbounded = True  # infinite, or COUNT: expand at query time instead
                continue
            ends.append(_later(_utc(until[0]), length))
    # Bounds at the edge of what datetime holds (year 1, or an UNTIL in 9999) are left open (None)
    # rather than overflowing: an open bound only means the resource is always parsed for a query.
    range_start = _format(_later(min(starts), -_SLACK))
    range_end = None if unbounded or None in ends else _format(_later(max(ends), _SLACK))
    return ParsedResource(
        uid=str(master.get("UID") or ""),
        title=str(master.get("SUMMARY") or ""),
        has_event=True,
        range_start=range_start,
        range_end=range_end,
    )


def _later(value: datetime | None, delta: timedelta) -> datetime | None:
    """value + delta, or None when that leaves the range datetime can hold."""
    if value is None:
        return None
    try:
        return value + delta
    except OverflowError:
        return None


def _format(value: datetime | None) -> str | None:
    """The stored form of a bound. Written by hand: strftime does not zero-pad years before 1000 on
    every platform, and the bounds are compared as strings."""
    if value is None:
        return None
    return (f"{value.year:04d}-{value.month:02d}-{value.day:02d}T"
            f"{value.hour:02d}:{value.minute:02d}:{value.second:02d}")


def _as_list(value) -> list:
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def _rdates(event) -> list:
    out = []
    for prop in _as_list(event.get("RDATE")):
        for item in getattr(prop, "dts", []):
            value = item.dt
            if isinstance(value, tuple):  # PERIOD
                value = value[0]
            out.append(value)
    return out


def bound(value: datetime) -> str:
    """A query instant in the same form as the stored bounds."""
    return _format(value.astimezone(timezone.utc).replace(tzinfo=None))


def _zone_name(value, prop) -> str | None:
    if not isinstance(value, datetime) or value.tzinfo is None:
        return None
    tz = value.tzinfo
    key = getattr(tz, "key", None)
    if key:
        return key
    if tz is timezone.utc or str(tz) == "UTC":
        return "UTC"
    tzid = prop.params.get("TZID") if prop is not None else None
    return str(tzid) if tzid else str(tz)


def _instant(value, tz: tzinfo) -> datetime:
    """An occurrence boundary as a UTC instant: dates are midnight in tz, floating times are in tz.

    Everything is compared in UTC: Python compares two datetimes that share a tzinfo by wall time,
    which is wrong across a clock change."""
    if isinstance(value, datetime):
        aware = value.replace(tzinfo=tz) if value.tzinfo is None else value
    else:
        aware = datetime.combine(value, time.min, tzinfo=tz)
    return aware.astimezone(timezone.utc)


def _exact_end(occ, events: list, tz: tzinfo) -> datetime | None:
    """For a timed occurrence whose source VEVENT gives a DURATION: RFC 5545 makes its days nominal
    (wall clock) and its hours, minutes and seconds exact, so across a clock change the end differs
    from plain wall-clock addition. None when the source has no DURATION."""
    rid = occ.get("RECURRENCE-ID")
    source = None
    if rid is not None:
        source = next((e for e in events if e.get("RECURRENCE-ID") is not None
                       and _same_time(e["RECURRENCE-ID"].dt, rid.dt)), None)
    if source is None:
        source = next((e for e in events if e.get("RECURRENCE-ID") is None), None)
    if source is None or source.get("DURATION") is None or source.get("DTEND") is not None:
        return None
    length = source["DURATION"].dt
    if not isinstance(length, timedelta) or length < timedelta(0):
        return None
    start = occ["DTSTART"].dt
    wall = start + timedelta(days=length.days)
    return _instant(wall, tz) + (length - timedelta(days=length.days))


def _same_time(a, b) -> bool:
    try:
        return a == b
    except TypeError:
        return False


def occurrences(text: str, start: datetime, end: datetime, tz: tzinfo) -> list[dict]:
    """Occurrences of the resource's VEVENTs that overlap [start, end). start and end are aware.

    Each item: uid, recurrence_id, title, location, notes, start, end, all_day, time_zone, plus
    "_sort" (a UTC datetime for ordering). Cancelled occurrences are left out.
    """
    start_utc, end_utc = start.astimezone(timezone.utc), end.astimezone(timezone.utc)
    cal = parse_calendar(text)
    events = _events(cal)
    recurring = any(
        e.get("RRULE") is not None or e.get("RDATE") is not None or e.get("RECURRENCE-ID") is not None
        for e in events
    )
    query = recurring_ical_events.of(cal, components=["VEVENT"])
    out = []
    for occ in query.between(start - _SLACK, end + _SLACK):
        if str(occ.get("STATUS") or "").upper() == "CANCELLED":
            continue
        dtstart_prop = occ.get("DTSTART")
        if dtstart_prop is None:
            continue
        o_start = dtstart_prop.dt
        all_day = not isinstance(o_start, datetime)
        dtend_prop = occ.get("DTEND")
        if dtend_prop is not None:
            o_end = dtend_prop.dt
        else:
            o_end = o_start + (timedelta(days=1) if all_day else _duration(occ))
        if all_day:
            if isinstance(o_end, datetime):
                o_end = o_end.date()
            if o_end <= o_start:
                o_end = o_start + timedelta(days=1)

        a_start = _instant(o_start, tz)
        a_end = None if all_day else _exact_end(occ, events, tz)
        if a_end is None:
            a_end = _instant(o_end, tz)
        a_end = max(a_end, a_start)
        if a_end == a_start:
            overlaps = start_utc <= a_start < end_utc
        else:
            overlaps = a_start < end_utc and a_end > start_utc
        if not overlaps:
            continue

        if all_day:
            start_s, end_s = o_start.isoformat(), o_end.isoformat()
        else:
            start_s, end_s = a_start.astimezone(tz).isoformat(), a_end.astimezone(tz).isoformat()
        rid = occ.get("RECURRENCE-ID")
        recurrence_id = rid.dt.isoformat() if recurring and rid is not None else None
        out.append(
            {
                "uid": str(occ.get("UID") or ""),
                "recurrence_id": recurrence_id,
                "title": str(occ.get("SUMMARY") or ""),
                "location": str(occ.get("LOCATION") or ""),
                "notes": str(occ.get("DESCRIPTION") or ""),
                "start": start_s,
                "end": end_s,
                "all_day": all_day,
                "time_zone": None if all_day else _zone_name(o_start, dtstart_prop),
                "_sort": a_start,
            }
        )
    return out
