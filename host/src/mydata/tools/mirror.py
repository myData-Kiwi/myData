"""The tools in real mode: find_contact and list_events over the user's mirrored contacts and calendars.

They keep the built-in tools' definitions exactly (name, description, schema, permission, date
parameters) and only swap the handlers, so the model sees the same tools it was measured with, and
their results have the fake tools' shape: present.py, grounding and the clarify-on-several-matches path
work unchanged. Tools with no real source yet (search_mail, send_mail, search_photos, create_event) are
not offered at all.

What goes back to the model is kept small: names, emails and phones for contacts; title, day, times
and place for events. Event notes are left out: they are free text from other people and can carry
instructions (see "Untrusted input" in CLAUDE.md).

The window rule: a source may hold only some days (This Mac keeps one year back and two years ahead).
It is decided per source, never by "some source holds it all": whenever a source does not hold every asked
day, list_events never answers "nothing found" for the days it does not hold. Its result says which days
that source holds ({"outside_window": true, "covered": {"start", "end"}}, or "covered": null with a
"reason" when the Mac's calendars are not read at all), and which sources hold every asked day
("complete_sources", for example ["icloud"]). With no such source it looks only at the days held; with
one, it looks at every asked day, and the header says the other source's events are only for its days.
present.py writes the header from that.
"""

from __future__ import annotations

import dataclasses
from datetime import date, datetime, time, timedelta, tzinfo
from typing import Callable, Protocol

from .builtin import TOOLS, _matches_query
from .dates import Resolved
from .registry import Registry, Tool, ToolResult

# The tools real mode offers, in the order the model sees them (the built-in order).
MIRROR_TOOL_NAMES = ("find_contact", "list_events")

# With no date, list_events shows what is coming up: today and the next 60 days (as the fake does).
UPCOMING_DAYS = 60

# At most this many events go to the model (the app is shown them all). A daily series alone gives about
# 60 occurrences in the default window; every one in the prompt would crowd the context (num_ctx) and
# stay in the conversation's history. A cut list says so: "count" (all of them) and "truncated": true.
MODEL_EVENT_LIMIT = 20


class ContactSource(Protocol):
    def find_by_name(self, name: str) -> list[dict]: ...


class EventSource(Protocol):
    def events_between(self, start: datetime, end: datetime, calendar_ids: list[str] | None = None,
                       tz: tzinfo | None = None) -> list[dict]: ...


# coverage(start, end) -> [{"source", "account_id", "covered_start", "covered_end", "complete", "reason"?}]
Coverage = Callable[[date, date], list[dict]]


@dataclasses.dataclass(frozen=True)
class Held:
    """What the sources hold of an asked range [start, end] (held_range)."""

    limit: dict | None  # the first source that does not hold every asked day; None when they all do
    days: tuple[date, date] | None  # the part of the range `limit` holds (None: no day of it); the whole range
    # when limit is None
    complete: tuple[str, ...]  # the sources ("icloud", ...) holding every asked day, when limit is not None


def held_range(coverage: list[dict], start: date, end: date) -> Held:
    """Which part of [start, end] the sources hold, decided per source: one source holding everything never
    hides another's limit."""
    limits = [c for c in coverage if not c.get("complete")]
    if not limits:
        return Held(None, (start, end), ())
    limit = next((c for c in limits if c.get("covered_start") and c.get("covered_end")), limits[0])
    complete = tuple(sorted({c["source"] for c in coverage if c.get("complete")} - {limit["source"]}))
    if not limit.get("covered_start"):
        return Held(limit, None, complete)
    first = max(start, date.fromisoformat(limit["covered_start"]))
    last = min(end, date.fromisoformat(limit["covered_end"]))
    return Held(limit, (first, last) if first <= last else None, complete)


def _on_days(item: dict, days: tuple[date, date] | None) -> bool:
    """Whether an event item (event_item) falls on any of `days`."""
    if days is None:
        return False
    first = date.fromisoformat(item["date"])
    last = date.fromisoformat(item.get("end_date") or item["date"])
    return first <= days[1] and last >= days[0]


def _local_zone() -> tzinfo:
    from ..sources.ical import local_timezone
    return local_timezone()


def local_today(tz: Callable[[], tzinfo] = _local_zone) -> Callable[[], date]:
    """Today in the machine's zone (the real date: real mode ignores [dev] pin_today)."""
    return lambda: datetime.now(tz()).date()


def contact_match(row: dict) -> dict:
    """A find_by_name row in the fake tool's shape: one email and phone (the first), plus every one."""
    emails, phones = list(row.get("emails") or []), list(row.get("phones") or [])
    return {"id": row["id"], "name": row["name"], "email": emails[0] if emails else None,
            "phone": phones[0] if phones else None, "emails": emails, "phones": phones}


def event_item(occ: dict) -> dict:
    """An expanded occurrence in the fake tool's shape: date (YYYY-MM-DD), start and end (HH:MM, None for
    all-day events), location. end_date is added when an event ends on a later day than it starts."""
    if occ["all_day"]:
        first = date.fromisoformat(occ["start"])
        last = date.fromisoformat(occ["end"]) - timedelta(days=1)  # the stored end is exclusive
        item = {"id": occ["event_id"], "title": occ["title"], "date": first.isoformat(), "start": None,
                "end": None, "location": occ["location"] or "", "all_day": True}
    else:
        start = datetime.fromisoformat(occ["start"])
        end = datetime.fromisoformat(occ["end"])
        first, last = start.date(), (end - timedelta(microseconds=1)).date() if end > start else start.date()
        item = {"id": occ["event_id"], "title": occ["title"], "date": first.isoformat(),
                "start": start.strftime("%H:%M"), "end": end.strftime("%H:%M"), "location": occ["location"] or ""}
    if last > first:
        item["end_date"] = last.isoformat()
    return item


def mirror_tools(contacts: ContactSource, calendar: EventSource, *,
                 tz: Callable[[], tzinfo] = _local_zone, coverage: Coverage | None = None) -> list[Tool]:
    """find_contact and list_events backed by the mirror. tz gives the zone events are shown in (the
    machine's own, read on every call so a changed system zone applies at once). coverage says which
    days the sources hold (None: every source holds everything)."""

    def find_contact(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
        matches = [contact_match(r) for r in contacts.find_by_name(args["name"])]
        if len(matches) > 1:
            return ToolResult({"matches": matches}, ambiguous=matches)
        return ToolResult({"matches": matches})

    def list_events(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
        zone = tz()
        window = dates.get("date") or Resolved(today, today + timedelta(days=UPCOMING_DAYS))
        held = held_range(coverage(window.start, window.end) if coverage else [], window.start, window.end)
        limit = held.limit
        # With a source that holds every asked day, look at all of them; else only at the days held.
        span = (window.start, window.end) if limit is not None and held.complete else held.days
        events: list[dict] = []
        if span is not None:
            start = datetime.combine(span[0], time.min, tzinfo=zone)
            end = datetime.combine(span[1] + timedelta(days=1), time.min, tzinfo=zone)
            for o in calendar.events_between(start, end, tz=zone):
                if not _matches_query(f"{o['title']} {o['location'] or ''}", args.get("query")):
                    continue
                item = event_item(o)
                # The limited source's events count only on the days it holds.
                if limit is not None and o.get("source") == limit["source"] and not _on_days(item, held.days):
                    continue
                events.append(item)
        full = {"from": window.start.isoformat(), "to": window.end.isoformat(), "events": events}
        if limit is not None:
            full["outside_window"] = True
            full["covered"] = ({"start": limit["covered_start"], "end": limit["covered_end"]}
                               if limit.get("covered_start") else None)
            if full["covered"] is None:
                full["reason"] = limit.get("reason") or "not_read_yet"
            if held.complete:
                full["complete_sources"] = list(held.complete)
        if len(events) <= MODEL_EVENT_LIMIT:
            return ToolResult(full)
        cut = {**full, "events": events[:MODEL_EVENT_LIMIT], "count": len(events), "truncated": True}
        return ToolResult(cut, display=full)

    handlers = {"find_contact": find_contact, "list_events": list_events}
    return [dataclasses.replace(TOOLS[name], handler=handlers[name]) for name in MIRROR_TOOL_NAMES]


def mirror_registry(contacts: ContactSource, calendar: EventSource, *, today: Callable[[], date] | None = None,
                    tz: Callable[[], tzinfo] = _local_zone, coverage: Coverage | None = None) -> Registry:
    """A registry in real mode on its own (the host swaps tools into its one registry instead)."""
    return Registry(mirror_tools(contacts, calendar, tz=tz, coverage=coverage), today=today or local_today(tz),
                    mode="real")
