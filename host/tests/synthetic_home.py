"""A host folder holding synthetic contacts and calendars (the invented DAV fixtures), for the backup,
restore and export tests. Never a real home."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from mydata.sources.calendar_store import CalendarStore
from mydata.sources.contacts_store import ContactsStore

import test_calendar_store as cal
import test_contacts_store as con

CALENDAR_FILES = ["weekly-london.ics", "allday-single.ics", "custom-tz.ics", "floating.ics", "yearly-forever.ics"]


def populate(home: Path) -> tuple[ContactsStore, CalendarStore]:
    """contacts.sqlite with every fixture card in one address book; calendar.sqlite with two calendars."""
    contacts = ContactsStore(Path(home) / "contacts.sqlite")
    contacts.apply("acc-1", con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    calendar = CalendarStore(Path(home) / "calendar.sqlite")
    calendar.apply("acc-1", cal.HOME, cal.result([cal.item(n) for n in CALENDAR_FILES], full=True))
    calendar.apply("acc-1", cal.WORK, cal.result([cal.item("outlook-tz.ics", collection=cal.WORK)], full=True))
    return contacts, calendar


def count(path: Path, table: str, where: str = "") -> int:
    with sqlite3.connect(path) as db:
        return db.execute(f"SELECT COUNT(*) FROM {table} {where}").fetchone()[0]
