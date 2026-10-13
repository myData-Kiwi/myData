"""Turn a tool's result into what the app shows, without a model: a kind, a one-line header, and items.

The header is written here, in code ("3 events on Friday 20 March"), so a list request needs no second
model call. Items carry only display fields; the app renders them as lists and cards.
"""

from __future__ import annotations

import calendar
from datetime import date
from typing import Any

from ..tools.dates import Resolved


def _day(d: date) -> str:
    return f"{d:%A} {d.day} {d:%B}"


def _span(r: Resolved | None) -> str:
    """'on Friday 20 March', 'from Monday 16 to Sunday 22 March', or '' (no date given)."""
    if r is None:
        return ""
    if r.start == r.end:
        return f"on {_day(r.start)}"
    whole_month = (r.start.day == 1 and (r.start.year, r.start.month) == (r.end.year, r.end.month)
                   and r.end.day == calendar.monthrange(r.end.year, r.end.month)[1])
    if whole_month:
        return f"in {r.start:%B %Y}"
    if r.start.month == 1 and r.start.day == 1 and r.end.month == 12 and r.end.day == 31 and r.start.year == r.end.year:
        return f"in {r.start.year}"
    if r.start.year == r.end.year:
        if r.start.month == r.end.month:
            return f"from {r.start:%A} {r.start.day} to {_day(r.end)}"
        return f"from {_day(r.start)} to {_day(r.end)}"
    return f"from {_day(r.start)} {r.start.year} to {_day(r.end)} {r.end.year}"


def _count(n: int, one: str, many: str) -> str:
    return f"No {many}" if n == 0 else f"1 {one}" if n == 1 else f"{n} {many}"


def _join(*parts: str) -> str:
    return " ".join(p for p in parts if p)


def _fmt_date(iso: str) -> str:
    return _day(date.fromisoformat(iso))


def _short(iso: str) -> str:
    d = date.fromisoformat(iso)
    return f"{d.day} {d:%b %Y}"


_SOURCE_NAMES = {"icloud": "iCloud"}


def _events_header(args: dict, when: Resolved | None, result: dict) -> str:
    """The header for list_events. When the asked days are not all held (This Mac keeps a window), it
    never says "No events" for days it does not hold: it says which days the limited source holds, and
    counts the events of the days held, or of the sources that hold every asked day ("in your iCloud
    calendars"), never the rest."""
    events = result.get("events", [])
    about = f"matching “{args['query']}”" if args.get("query") else ""
    if not result.get("outside_window"):
        return _join(_count(len(events), "event", "events"), about, _span(when) if when else "coming up")
    asked = when or Resolved(date.fromisoformat(result["from"]), date.fromisoformat(result["to"]))
    covered = result.get("covered")
    if not covered:
        limit = ("myData cannot read the calendars on this Mac: access to them is not allowed"
                 if result.get("reason") == "no_access" else "The calendars on this Mac have not been read yet")
        first = last = None
    else:
        limit = f"Events on this Mac are kept from {_short(covered['start'])} to {_short(covered['end'])}"
        first = max(asked.start, date.fromisoformat(covered["start"]))
        last = min(asked.end, date.fromisoformat(covered["end"]))
    others = result.get("complete_sources") or []
    if others:
        names = " and ".join(_SOURCE_NAMES.get(o, o) for o in others)
        if first is not None and first <= last:  # partly held: every day for the others, some for this Mac
            counted = _join(_count(len(events), "event", "events"), about, _span(asked))
            return f"{counted}. {limit}; on other days only your {names} calendars are shown."
        counted = _join(_count(len(events), "event", "events"), f"in your {names} calendars", about, _span(asked))
        return f"{counted}. {limit}."
    if not covered:
        return f"{limit}."
    if first > last:
        return f"{limit}; {'that date is' if asked.start == asked.end else 'those dates are'} outside it."
    return f"{_join(_count(len(events), 'event', 'events'), about, _span(Resolved(first, last)))}. {limit}."


def present(tool: str, args: dict, resolved: dict[str, Resolved], result: Any) -> dict | None:
    """{"kind", "header", "items"} for a read or reversible tool's result; None if there is nothing to show."""
    if not isinstance(result, dict):
        return None
    when = resolved.get("date")
    if tool == "list_events":
        events = result.get("events", [])
        header = _events_header(args, when, result)
        items = [{"title": e["title"], "date": e["date"], "day": _fmt_date(e["date"]), "start": e.get("start"),
                  "end": e.get("end"), "location": e.get("location") or None} for e in events]
        return {"kind": "events", "header": header, "items": items}
    if tool == "search_mail":
        msgs = result.get("messages", [])
        n = result.get("count", len(msgs))
        header = _join(_count(n, "email", "emails"), f"from {args['sender']}" if args.get("sender") else "",
                       f"about “{args['query']}”" if args.get("query") else "", _span(when))
        items = [{"from": m["from"], "subject": m["subject"], "date": m["date"], "day": _fmt_date(m["date"]),
                  "snippet": (m.get("body") or "")[:160]} for m in msgs]
        return {"kind": "mail", "header": header, "items": items}
    if tool == "find_contact":
        matches = result.get("matches", [])
        if len(matches) == 1:
            header = f"{matches[0]['name']}"
        else:
            header = _join(_count(len(matches), "contact", "contacts"), f"named “{args.get('name', '')}”")
        items = [{"name": c["name"], "email": c.get("email"), "phone": c.get("phone")} for c in matches]
        return {"kind": "contacts", "header": header, "items": items}
    if tool == "search_photos":
        photos = result.get("photos", [])
        header = _join(_count(result.get("count", len(photos)), "photo", "photos"),
                       f"of {args['person']}" if args.get("person") else "",
                       f"in {args['place']}" if args.get("place") else "",
                       f"showing “{args['query']}”" if args.get("query") else "", _span(when))
        items = [{"id": p["id"], "taken": p["taken"], "day": _fmt_date(p["taken"]), "place": p.get("place"),
                  "people": p.get("people", []), "tags": p.get("tags", [])} for p in photos]
        return {"kind": "photos", "header": header, "items": items}
    if tool == "create_event" and result.get("status") == "created":
        at = f" at {args['time']}" if args.get("time") else ""
        header = f"Added “{result['title']}” on {_fmt_date(result['date'])}{at}"
        item = {"title": result["title"], "date": result["date"], "day": _fmt_date(result["date"]),
                "start": args.get("time"), "location": args.get("location")}
        return {"kind": "event_created", "header": header, "items": [item]}
    return None
