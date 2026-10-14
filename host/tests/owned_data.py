"""Owned data for the "survives" tests: an owned address book and an owned calendar (sources/owned.py),
written straight into a store's file the way the future writers will, beside the mirror's followed data.
Every operation that deletes followed data has a twin test showing these rows come through it unchanged.
Invented data only."""

from __future__ import annotations

import sqlite3
from pathlib import Path

from mydata.sources._db import now
from mydata.sources.calendar_store import CalendarStore
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.owned import OWNED_ACCOUNT

BOOK_URL = "owned://contacts/book-1"
CALENDAR_URL = "owned://calendars/cal-1"

CARDS = {
    "olive.vcf": "BEGIN:VCARD\r\nVERSION:3.0\r\nUID:olive-owned@example.org\r\nFN:Olive Owned\r\nN:Owned;Olive;;;\r\n"
                 "EMAIL;TYPE=INTERNET:olive@example.org\r\nTEL;TYPE=CELL:+1 555 0123\r\nEND:VCARD\r\n",
    "pip.vcf": "BEGIN:VCARD\nVERSION:4.0\nUID:urn:uuid:pip-owned-1\nFN:Pip Keepsake\nN:Keepsake;Pip;;;\n"
               "EMAIL:pip@example.invalid\nEND:VCARD\n",
}
EVENTS = {
    "picnic.ics": "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//myData//test//EN\r\nBEGIN:VEVENT\r\n"
                  "UID:owned-picnic-1@example.org\r\nDTSTAMP:20260301T000000Z\r\nDTSTART:20260320T010000Z\r\n"
                  "DTEND:20260320T020000Z\r\nSUMMARY:Owned picnic (invented)\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n",
}
WORDS = (b"Olive Owned", b"pip@example.invalid", b"Owned picnic")


def add_owned(home: Path) -> dict[str, list[str]]:
    """An owned address book with two cards in <home>/contacts.sqlite and an owned calendar with one event in
    <home>/calendar.sqlite (each file created if missing). Returns their ids."""
    ids: dict[str, list[str]] = {}
    stamp = now()
    contacts = ContactsStore(Path(home) / "contacts.sqlite")
    with contacts.db.transaction() as db:
        book = "owned-book-1"
        db.execute("INSERT INTO address_books (id, account_id, url, name, mode, created_at, modified_at) "
                   "VALUES (?, ?, ?, 'Kept (owned)', 'owned', ?, ?)", (book, OWNED_ACCOUNT, BOOK_URL, stamp, stamp))
        for href, card in CARDS.items():
            ContactsStore._upsert_card(db, OWNED_ACCOUNT, book, BOOK_URL, href, "", card, stamp)
        ids["address_books"] = [book]
        ids["contacts"] = [r[0] for r in db.execute("SELECT id FROM contacts WHERE address_book_id = ?", (book,))]
    calendar = CalendarStore(Path(home) / "calendar.sqlite")
    with calendar.db.transaction() as db:
        cal = "owned-cal-1"
        db.execute("INSERT INTO calendars (id, account_id, url, name, mode, created_at, modified_at) "
                   "VALUES (?, ?, ?, 'Kept (owned)', 'owned', ?, ?)", (cal, OWNED_ACCOUNT, CALENDAR_URL, stamp, stamp))
        for href, text in EVENTS.items():
            CalendarStore._upsert_resource(db, OWNED_ACCOUNT, cal, CALENDAR_URL, href, "", text, stamp)
        ids["calendars"] = [cal]
        ids["events"] = [r[0] for r in db.execute("SELECT id FROM events WHERE calendar_id = ?", (cal,))]
    return ids


def owned_rows(home: Path) -> dict[str, list[tuple]]:
    """Every column of every owned collection and of every row in one, from both files: equal before and after
    an operation means the owned data came through it untouched (not deleted, not soft-deleted, not changed)."""
    out = {}
    for name, (collections, rows, fk) in (("contacts.sqlite", ("address_books", "contacts", "address_book_id")),
                                          ("calendar.sqlite", ("calendars", "events", "calendar_id"))):
        with sqlite3.connect(Path(home) / name) as db:
            out[collections] = db.execute(f"SELECT * FROM {collections} WHERE mode = 'owned' ORDER BY id").fetchall()
            out[rows] = db.execute(f"SELECT * FROM {rows} WHERE {fk} IN (SELECT id FROM {collections} "
                                   f"WHERE mode = 'owned') ORDER BY id").fetchall()
    assert out["address_books"] and len(out["contacts"]) == len(CARDS), "no owned contacts to compare"
    assert out["calendars"] and len(out["events"]) == len(EVENTS), "no owned events to compare"
    return out
