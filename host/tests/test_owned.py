"""Owned data is kept by the database itself (sources/owned.py): deleting an owned collection or a row in
one aborts unless a purge permit exists, including through a foreign-key cascade; purge() is the one way
to delete it. Invented data only (tests/owned_data.py)."""

from __future__ import annotations

import sqlite3

import pytest

from mydata.sources import owned
from mydata.sources.calendar_store import CalendarStore
from mydata.sources.contacts_store import ContactsStore

import test_contacts_store as con
from owned_data import WORDS, add_owned, owned_rows

ABORT = "owned data is never"


@pytest.fixture
def home(tmp_path):
    ids = add_owned(tmp_path)
    contacts = ContactsStore(tmp_path / "contacts.sqlite")
    contacts.apply("acc-1", con.BOOK, con.result([con.item("ava-fictional.vcf")], full=True))
    return tmp_path, ids, contacts, CalendarStore(tmp_path / "calendar.sqlite")


def _raw(path, sql, params=(), foreign_keys=True):
    """A plain connection, as any code (or a slip in one) might open: the triggers apply to every one."""
    db = sqlite3.connect(path, isolation_level=None)
    try:
        db.execute(f"PRAGMA foreign_keys={'ON' if foreign_keys else 'OFF'}")
        return db.execute(sql, params).rowcount
    finally:
        db.close()


@pytest.mark.parametrize("sql", [
    "DELETE FROM contacts WHERE address_book_id = 'owned-book-1'",
    "DELETE FROM contacts",
    "DELETE FROM address_books WHERE id = 'owned-book-1'",  # with foreign keys on: the cascade is caught too
    "DELETE FROM address_books",
])
def test_deleting_owned_contacts_without_a_permit_aborts(home, sql):
    path, ids, _, _ = home
    before = owned_rows(path)
    with pytest.raises(sqlite3.IntegrityError, match=ABORT):
        _raw(path / "contacts.sqlite", sql)
    assert owned_rows(path) == before


@pytest.mark.parametrize("sql", [
    "DELETE FROM events WHERE calendar_id = 'owned-cal-1'",
    "DELETE FROM calendars WHERE id = 'owned-cal-1'",
    "DELETE FROM calendars",
])
def test_deleting_owned_events_without_a_permit_aborts(home, sql):
    path, _, _, _ = home
    before = owned_rows(path)
    with pytest.raises(sqlite3.IntegrityError, match=ABORT):
        _raw(path / "calendar.sqlite", sql)
    assert owned_rows(path) == before


def test_an_owned_collection_is_kept_with_foreign_keys_off_too(home):
    path, _, _, _ = home
    with pytest.raises(sqlite3.IntegrityError, match=ABORT):
        _raw(path / "contacts.sqlite", "DELETE FROM address_books WHERE id = 'owned-book-1'", foreign_keys=False)


def test_a_permit_for_the_collection_alone_does_not_let_the_cascade_take_its_rows(home):
    """The cascade runs after the collection's row is gone, so a row's own trigger cannot see it was owned:
    the collection's trigger checks that every row has a permit before deleting anything."""
    path, ids, _, _ = home
    db = sqlite3.connect(path / "contacts.sqlite", isolation_level=None)
    db.execute("PRAGMA foreign_keys=ON")
    db.execute("BEGIN")
    db.execute("INSERT INTO purge_permits VALUES ('owned-book-1')")
    with pytest.raises(sqlite3.IntegrityError, match=ABORT):
        db.execute("DELETE FROM address_books WHERE id = 'owned-book-1'")
    db.execute("ROLLBACK")
    db.close()


def test_owned_data_cannot_be_turned_followed_nor_moved_out(home):
    path, ids, _, _ = home
    with pytest.raises(sqlite3.IntegrityError, match="never made followed"):
        _raw(path / "contacts.sqlite", "UPDATE address_books SET mode = 'followed' WHERE id = 'owned-book-1'")
    followed = _raw_one(path / "contacts.sqlite", "SELECT id FROM address_books WHERE mode = 'followed'")
    with pytest.raises(sqlite3.IntegrityError, match="never moved"):
        _raw(path / "contacts.sqlite", "UPDATE contacts SET address_book_id = ? WHERE id = ?",
             (followed, ids["contacts"][0]))
    with pytest.raises(sqlite3.IntegrityError, match="CHECK"):  # not a value a trigger would miss
        _raw(path / "contacts.sqlite", "UPDATE address_books SET mode = 'Owned' WHERE mode = 'followed'")


def test_insert_or_replace_cannot_remove_an_owned_row(home):
    path, ids, contacts, _ = home
    with contacts.db.connect() as db:  # the stores' connections turn recursive_triggers on
        row = db.execute("SELECT * FROM contacts WHERE id = ?", (ids["contacts"][0],)).fetchone()
        cols = row.keys()
        values = [row[c] if c != "seq" else None for c in cols]
        with pytest.raises(sqlite3.IntegrityError, match=ABORT):
            db.execute(f"INSERT OR REPLACE INTO contacts ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})",
                       values)


def test_followed_data_is_deleted_as_before(home):
    path, _, contacts, _ = home
    assert _raw(path / "contacts.sqlite", "DELETE FROM address_books WHERE account_id = 'acc-1'") == 1
    assert _raw_one(path / "contacts.sqlite", "SELECT COUNT(*) FROM contacts WHERE account_id = 'acc-1'") == 0


def test_purge_deletes_owned_rows_and_collections_and_leaves_no_permit(home):
    path, ids, contacts, calendar = home
    one = ids["contacts"][0]
    assert contacts.purge(contact_ids=[one]) == {"collections": 0, "rows": 1}
    assert contacts.get(one) is None and len(contacts.list()) == 2  # the other owned card and Ava
    assert contacts.purge(address_book_ids=ids["address_books"]) == {"collections": 1, "rows": 1}
    assert [c["display_name"] for c in contacts.list()] == ["Ava Fictional"]
    assert calendar.purge(calendar_ids=ids["calendars"]) == {"collections": 1, "rows": 1}
    assert calendar.calendars() == []
    for name in ("contacts.sqlite", "calendar.sqlite"):
        assert _raw_one(path / name, "SELECT COUNT(*) FROM purge_permits") == 0
        raw = (path / name).read_bytes()
        assert not any(w in raw for w in WORDS), name  # secure_delete, the index rewritten, checkpointed


def test_purge_runs_only_inside_a_transaction(home):
    path, ids, contacts, _ = home
    with contacts.db.connect() as db:
        with pytest.raises(RuntimeError, match="transaction"):
            owned.purge(db, owned.CONTACTS, row_ids=ids["contacts"])


def test_a_failed_purge_rolls_back_with_its_permits(home):
    path, ids, contacts, _ = home
    before = owned_rows(path)
    with pytest.raises(sqlite3.IntegrityError):
        with contacts.db.transaction() as db:
            owned.purge(db, owned.CONTACTS, row_ids=ids["contacts"])
            db.execute("INSERT INTO address_books (id) VALUES (NULL)")  # fails: everything rolls back
    assert owned_rows(path) == before
    assert _raw_one(path / "contacts.sqlite", "SELECT COUNT(*) FROM purge_permits") == 0


def _raw_one(path, sql, params=()):
    db = sqlite3.connect(path)
    try:
        return db.execute(sql, params).fetchone()[0]
    finally:
        db.close()

