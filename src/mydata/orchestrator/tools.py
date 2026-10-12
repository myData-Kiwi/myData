"""Tool registry: definitions shown to the model, permission class, and handlers.

The handlers here are fakes over canned data (see fixtures.py). They exist so
chained requests have something real-looking to chain on. The engine records
every call's arguments regardless of what the handler does.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any, Callable, Literal

from . import fixtures
from .dates import Bias, Resolved

Permission = Literal["read", "write", "irreversible"]

DATE_HELP = (
    "The date exactly as the user said it, for example 'next friday', 'last December', "
    "'tomorrow', 'March 30', 'the last two weeks'. Do not convert it to a calendar date."
)


@dataclass
class ToolResult:
    data: Any
    # Several equally good matches: the engine stops and asks the user to pick.
    ambiguous: list[dict] | None = None
    # Reversible writes return how to undo them.
    undo: dict | None = None


@dataclass
class Tool:
    name: str
    description: str
    parameters: dict
    permission: Permission
    handler: Callable[[dict, dict[str, Resolved], date], ToolResult]
    # Parameters holding date phrases, and which way a bare phrase leans.
    date_params: dict[str, Bias] = field(default_factory=dict)
    time_params: tuple[str, ...] = ()

    def definition(self) -> dict:
        return {
            "type": "function",
            "function": {"name": self.name, "description": self.description, "parameters": self.parameters},
        }


def _schema(props: dict, required: list[str]) -> dict:
    return {"type": "object", "properties": props, "required": required, "additionalProperties": False}


def _words(text: str) -> list[str]:
    return [w for w in re.findall(r"[a-z0-9]+", text.lower()) if len(w) > 1]


def _matches_query(text: str, query: str | None) -> bool:
    if not query:
        return True
    hay = text.lower()
    words = [w for w in _words(query) if w not in {"the", "my", "and", "for", "about", "from", "of", "to", "me"}]
    return any(w in hay for w in words) if words else True


def _in_range(iso: str, r: Resolved | None) -> bool:
    if r is None:
        return True
    d = date.fromisoformat(iso)
    return r.start <= d <= r.end


# ---------------------------------------------------------------- handlers


def _search_mail(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    sender = (args.get("sender") or "").lower()
    hits = [
        m for m in fixtures.MAIL
        if (not sender or any(w in m["from"].lower() for w in _words(sender)))
        and _matches_query(m["subject"] + " " + m["body"], args.get("query"))
        and _in_range(m["date"], dates.get("date"))
    ]
    return ToolResult({"count": len(hits), "messages": hits[:5]})


def _send_mail(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    # Only reached after approval. Nothing is sent: this is a fake.
    return ToolResult({"status": "sent", "to": args["to"]})


def _search_photos(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    def ok(p: dict) -> bool:
        if args.get("place") and not _matches_query(p["place"], args["place"]):
            return False
        if args.get("person") and not any(_matches_query(n, args["person"]) for n in p["people"]):
            return False
        if args.get("query") and not _matches_query(" ".join(p["tags"]), args["query"]):
            return False
        return _in_range(p["taken"], dates.get("date"))

    hits = [p for p in fixtures.PHOTOS if ok(p)]
    return ToolResult({"count": len(hits), "photos": hits})


def find_contacts(name: str) -> list[dict]:
    words = [w for w in _words(re.sub(r"'s\b", "", name)) if w not in {"dr"}]
    if not words:
        return []
    out = []
    for c in fixtures.CONTACTS:
        tokens = _words(c["name"])
        if all(any(t.startswith(w) for t in tokens) for w in words):
            out.append(c)
    return out


def _find_contact(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    matches = find_contacts(args["name"])
    if len(matches) > 1:
        return ToolResult({"matches": matches}, ambiguous=matches)
    return ToolResult({"matches": matches})


def _list_events(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    window = dates.get("date") or Resolved(today, today + timedelta(days=60))
    hits = [
        e for e in fixtures.EVENTS
        if _in_range(e["date"], window) and _matches_query(e["title"] + " " + e["location"], args.get("query"))
    ]
    hits.sort(key=lambda e: (e["date"], e["start"]))
    return ToolResult({"from": window.start.isoformat(), "to": window.end.isoformat(), "events": hits})


def _create_event(args: dict, dates: dict[str, Resolved], today: date) -> ToolResult:
    event_id = "e-new-" + re.sub(r"[^a-z0-9]+", "-", args["title"].lower()).strip("-")[:24]
    d = dates["date"]
    return ToolResult(
        {"status": "created", "id": event_id, "date": d.start.isoformat(), "title": args["title"]},
        undo={"action": "delete_event", "id": event_id},
    )


# ---------------------------------------------------------------- registry


TOOLS: dict[str, Tool] = {
    t.name: t
    for t in [
        Tool(
            name="search_mail",
            description="Search the user's email. Returns matching messages with sender, date, subject and body.",
            parameters=_schema(
                {
                    "query": {"type": "string", "description": "Words to look for in the subject or body."},
                    "sender": {"type": "string", "description": "Name or address of the sender, as the user said it."},
                    "date": {"type": "string", "description": DATE_HELP},
                },
                [],
            ),
            permission="read",
            handler=_search_mail,
            date_params={"date": "past"},
        ),
        Tool(
            name="send_mail",
            description="Send an email. The user must approve before it is sent.",
            parameters=_schema(
                {
                    "to": {"type": "string", "description": "Recipient email address, taken from a find_contact result. Never guess an address."},
                    "subject": {"type": "string", "description": "Subject line."},
                    "body": {"type": "string", "description": "Message text."},
                },
                ["to", "subject", "body"],
            ),
            permission="irreversible",
            handler=_send_mail,
        ),
        Tool(
            name="search_photos",
            description="Search the user's photo library by what is in the picture, who is in it, where and when it was taken.",
            parameters=_schema(
                {
                    "query": {"type": "string", "description": "What the photo shows, for example 'beach at sunset'."},
                    "person": {"type": "string", "description": "Name of a person who appears in the photo."},
                    "place": {"type": "string", "description": "A named location such as a city, region or country."},
                    "date": {"type": "string", "description": DATE_HELP},
                },
                [],
            ),
            permission="read",
            handler=_search_photos,
            date_params={"date": "past"},
        ),
        Tool(
            name="find_contact",
            description="Look up a person in the user's contacts by name. Returns name, email and phone.",
            parameters=_schema(
                {"name": {"type": "string", "description": "The name as the user said it."}},
                ["name"],
            ),
            permission="read",
            handler=_find_contact,
        ),
        Tool(
            name="list_events",
            description="List calendar events. With no date, lists upcoming events.",
            parameters=_schema(
                {
                    "date": {"type": "string", "description": DATE_HELP},
                    "query": {"type": "string", "description": "Words to look for in the event title or location."},
                },
                [],
            ),
            permission="read",
            handler=_list_events,
            date_params={"date": "future"},
        ),
        Tool(
            name="create_event",
            description="Add an event to the user's calendar.",
            parameters=_schema(
                {
                    "title": {"type": "string", "description": "Short title for the event."},
                    "date": {"type": "string", "description": DATE_HELP},
                    "time": {"type": "string", "description": "Start time as the user said it, for example '3pm' or '09:40'."},
                    "location": {"type": "string", "description": "Where the event takes place."},
                    "duration_minutes": {"type": "integer", "description": "Length of the event in minutes."},
                },
                ["title", "date"],
            ),
            permission="write",
            handler=_create_event,
            date_params={"date": "future"},
            time_params=("time",),
        ),
    ]
}
