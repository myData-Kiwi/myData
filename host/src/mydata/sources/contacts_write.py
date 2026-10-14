"""Writing owned contacts: create, edit, delete to Recently deleted, restore, purge the trash, and undo.

Only owned cards are ever written (an address book whose mode is 'owned': sources/owned.py). A followed card
(This Mac, an iCloud account) is refused with ReadOnly whatever the caller asks; it changes only when its
source does. The owned address book is created on first need: one per host for now, named "myData", under
the owned account id.

Every write is one transaction holding:

- the card's new state: its raw text (new cards are vCard 3.0 with a UID; an edit goes through the line
  editor, so lines it does not change stay byte for byte), the parsed columns, `rev` + 1 and a new etag
  (http_etag: the revision and the text's hash; a delete or a restore moves it on too);
- a `revisions` row (the revision, its raw text when the text changed, the operation and the actor: the
  app's name);
- a `changes` row (the change feed: add, modify or delete);
- an `undo_log` row, whose id the caller gets back.

Concurrency: an edit, a delete and a delete for good name the etag they were made from (If-Match; the API
requires it, 428 without), and a restore may; a card that changed since is refused with PreconditionFailed,
which carries the current etag, and nothing is written.

Undo (undo()) never goes back in place: it writes a new revision forward, and only when the card is still at
the revision the action wrote (anything later, an edit or another undo, refuses it: UndoRefused). An action
is undone at most once; the log is in the database, so undo works across a restart of the host. Undoing a
create moves the card to Recently deleted; undoing an edit writes the text from before it again; undoing a
delete restores the card; undoing a restore deletes it again. An undo is not itself undone.

Delete is soft: `deleted_at` is set and `purge_after` is 30 days later. expire_trash() (the host runs it
daily) purges cards past their date through purge permits (owned.purge), with their revisions, which hold
their text, and purge_now() does the same for one card when the user deletes it for good from Recently
deleted (only at the etag the user saw there, so a card restored, changed and deleted again elsewhere is
never purged unseen); its `origins` rows go too (an imported vCard 2.1 keeps its original text there), except
that a card merged into one that stays hands them to it, without their text (_settle_origins); the change feed,
undo log and merges rows hold no contact data and stay. The host log records
who purged what (ids only). Copies in the host's snapshots stay until those expire (backup.kept_until).

Group cards are not contacts here (they are never found by id), so they are never written; a contact's
membership in a group is by UID, which no edit changes.
"""

from __future__ import annotations

import sqlite3
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from . import contact_form, owned
from ._db import new_id
from .contacts_store import ContactsStore, card_fields, http_etag
from .vcard_edit import VCard, VCardError, new_card

TRASH_DAYS = 30
BOOK_NAME = "myData"
BOOK_URL = "owned://contacts/mydata"

Clock = Callable[[], datetime]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(at: datetime) -> str:
    """A time as every column of the stores writes it (_db.now): ISO 8601 in UTC to the second."""
    return at.astimezone(timezone.utc).isoformat(timespec="seconds")


class WriteError(Exception):
    """A write was refused; nothing was written. The message is for the user and holds no contact data."""


class NotFound(WriteError):
    pass


class ReadOnly(WriteError):
    """The card is followed: a copy of a source, changed only by its source."""


class InTrash(WriteError):
    """The card is in Recently deleted: restore it first."""


class PreconditionFailed(WriteError):
    """The card changed since the etag the caller named."""

    def __init__(self, message: str, etag: str):
        super().__init__(message)
        self.etag = etag


class UndoRefused(WriteError):
    pass


@dataclass(frozen=True)
class Written:
    contact_id: str
    undo_id: str | None  # None when nothing changed (an edit that changed no line)
    # The owned address book was created, or brought back after it was deleted: owned data appeared, so the
    # host may switch to real mode.
    book_created: bool = False


# ---------------------------------------------------------------- helpers

def _clock(store: ContactsStore) -> Clock:
    return getattr(store, "clock", None) or utc_now


def _row(db: sqlite3.Connection, contact_id: str) -> sqlite3.Row:
    row = db.execute("SELECT c.*, b.mode AS book_mode FROM contacts c JOIN address_books b ON b.id = c.address_book_id "
                     "WHERE c.id = ? AND c.kind != 'group'", (contact_id,)).fetchone()
    if row is None:
        raise NotFound("There is no such contact.")
    if row["book_mode"] != owned.OWNED:
        raise ReadOnly("This contact is followed from another source and cannot be changed here; change it where it "
                       "comes from.")
    return row


def _book(db: sqlite3.Connection, at: str) -> tuple[str, bool]:
    """The owned address book (created on first need) and whether it was created or brought back now (a deleted
    book does not count as owned data: owned.has_owned)."""
    row = db.execute("SELECT id, deleted_at FROM address_books WHERE account_id = ? AND url = ? AND mode = ?",
                     (owned.OWNED_ACCOUNT, BOOK_URL, owned.OWNED)).fetchone()
    if row is not None:
        if row["deleted_at"] is not None:
            db.execute("UPDATE address_books SET deleted_at = NULL, modified_at = ? WHERE id = ?", (at, row["id"]))
            return row["id"], True
        return row["id"], False
    book_id = new_id()
    db.execute("INSERT INTO address_books (id, account_id, url, name, mode, created_at, modified_at) "
               "VALUES (?, ?, ?, ?, ?, ?, ?)", (book_id, owned.OWNED_ACCOUNT, BOOK_URL, BOOK_NAME, owned.OWNED, at, at))
    return book_id, True


def _baseline(db: sqlite3.Connection, row: sqlite3.Row) -> None:
    """A card whose current text no revision holds gets it as a revision at its current `rev`, so an undo
    always finds the text to go back to. That is a card written before it had revisions, or one whose text an
    owned-row writer other than this module changed (an import writing again through the store): without
    this, undoing the next edit would go back past that change and lose it."""
    latest = db.execute("SELECT rev, raw FROM revisions WHERE object_id = ? AND raw IS NOT NULL ORDER BY rev DESC "
                        "LIMIT 1", (row["id"],)).fetchone()
    if latest is not None and owned.raw_hash(latest["raw"]) == row["raw_sha256"]:
        return
    # A revision already at this rev (a delete, a restore) keeps its operation and gains the text it stands at.
    db.execute("INSERT INTO revisions (object_id, rev, raw, op, actor, at) VALUES (?, ?, ?, 'baseline', 'unknown', ?) "
               "ON CONFLICT (object_id, rev) DO UPDATE SET raw = excluded.raw",
               (row["id"], row["rev"], row["raw_vcard"], row["modified_at"]))


def _record(db: sqlite3.Connection, row_id: str, book_id: str, href: str, rev: int, raw: str | None, op: str,
            change: str, actor: str, at: str, *, undo_op: str | None, prior_rev: int | None = None) -> str | None:
    db.execute("INSERT INTO revisions (object_id, rev, raw, op, actor, at) VALUES (?, ?, ?, ?, ?, ?)",
               (row_id, rev, raw, op, actor, at))
    db.execute("INSERT INTO changes (collection_id, object_id, href, op, at) VALUES (?, ?, ?, ?, ?)",
               (book_id, row_id, href, change, at))
    if undo_op is None:
        return None
    undo_id = new_id()
    db.execute("INSERT INTO undo_log (id, object_id, op, actor, rev, prior_rev, at) VALUES (?, ?, ?, ?, ?, ?, ?)",
               (undo_id, row_id, undo_op, actor, rev, prior_rev, at))
    return undo_id


def _check_etag(row: sqlite3.Row, if_match: str | None) -> None:
    current = http_etag(row["rev"], row["raw_sha256"])
    if if_match is not None and if_match.strip() not in (current,):
        raise PreconditionFailed("This contact changed since it was read. Reload it and try again.", current)


def _write_text(db: sqlite3.Connection, row: sqlite3.Row, text: str, at: str, *, fields: dict | None = None) -> int:
    """Write `text` as the card's next revision. `fields`: card_fields(None, text) when the caller has them."""
    rev = row["rev"] + 1
    fields = fields if fields is not None else card_fields(None, text)
    fields["etag"] = http_etag(rev, fields["raw_sha256"])
    assignments = ", ".join(f"{k} = ?" for k in fields)
    done = db.execute(f"UPDATE contacts SET {assignments}, rev = ?, modified_at = ? WHERE id = ? AND rev = ?",
                      [*fields.values(), rev, at, row["id"], row["rev"]]).rowcount
    if done != 1:
        raise PreconditionFailed("This contact changed while it was being saved. Reload it and try again.",
                                 http_etag(row["rev"], row["raw_sha256"]))
    return rev


def _set_deleted(db: sqlite3.Connection, row: sqlite3.Row, deleted: bool, at: datetime) -> int:
    rev = row["rev"] + 1
    when = stamp(at)
    purge = stamp(at + timedelta(days=TRASH_DAYS)) if deleted else None
    db.execute("UPDATE contacts SET deleted_at = ?, purge_after = ?, rev = ?, etag = ?, modified_at = ? "
               "WHERE id = ? AND rev = ?", (when if deleted else None, purge, rev, http_etag(rev, row["raw_sha256"]),
                                            when, row["id"], row["rev"]))
    return rev


# ---------------------------------------------------------------- the writes

def create(store: ContactsStore, form: dict, *, actor: str) -> Written:
    """A new owned contact from a form (contact_form.check raises FormError for a bad one)."""
    values = contact_form.check(form, creating=True)
    at = _clock(store)()
    try:
        card = new_card("")
        contact_form.apply(card, values)
        text = card.to_text(now=at)
    except VCardError as e:
        raise WriteError("This contact cannot be written as a vCard.") from e
    when = stamp(at)
    with store.db.transaction() as db:
        book_id, created = _book(db, when)
        uid = card.first("UID").value
        row_id, href = new_id(), f"{uid}.vcf"
        fields = card_fields(None, text)
        fields["etag"] = http_etag(1, fields["raw_sha256"])
        columns = ["id", "account_id", "address_book_id", "collection_url", "href", *fields, "rev", "created_at",
                   "modified_at"]
        db.execute(f"INSERT INTO contacts ({', '.join(columns)}) VALUES ({', '.join('?' * len(columns))})",
                   [row_id, owned.OWNED_ACCOUNT, book_id, BOOK_URL, href, *fields.values(), 1, when, when])
        undo_id = _record(db, row_id, book_id, href, 1, text, "create", "add", actor, when, undo_op="create")
    return Written(row_id, undo_id, created)


def update(store: ContactsStore, contact_id: str, form: dict, *, if_match: str, actor: str) -> Written:
    """Change the fields given in the form, from the card at etag `if_match`. Only the lines whose values
    differ are written; an edit that changes nothing writes nothing (undo_id None)."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        _check_etag(row, if_match)
        if row["deleted_at"] is not None:
            raise InTrash("This contact is in Recently deleted. Restore it first.")
        try:
            card = VCard.parse(row["raw_vcard"])
            current = contact_form.read(card)
        except VCardError as e:
            raise WriteError("This contact's card cannot be edited here.") from e
        # Only what differs from the card is checked: a value it already holds never blocks the edit.
        values = contact_form.check(form, creating=False, current=current)
        try:
            contact_form.apply(card, values)
        except VCardError as e:
            raise WriteError("This contact's card cannot be edited here.") from e
        if not card.changed:
            return Written(contact_id, None)
        text = card.to_text(now=at)
        _baseline(db, row)
        rev = _write_text(db, row, text, when)
        undo_id = _record(db, contact_id, row["address_book_id"], row["href"], rev, text, "update", "modify", actor,
                          when, undo_op="update", prior_rev=row["rev"])
    return Written(contact_id, undo_id)


def delete(store: ContactsStore, contact_id: str, *, if_match: str | None = None, actor: str) -> Written:
    """Move the card to Recently deleted, to be purged after TRASH_DAYS. The API always passes `if_match`."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        _check_etag(row, if_match)
        if row["deleted_at"] is not None:
            raise InTrash("This contact is already in Recently deleted.")
        _baseline(db, row)
        rev = _set_deleted(db, row, True, at)
        undo_id = _record(db, contact_id, row["address_book_id"], row["href"], rev, None, "delete", "delete", actor,
                          when, undo_op="delete")
    return Written(contact_id, undo_id)


def restore(store: ContactsStore, contact_id: str, *, if_match: str | None = None, actor: str) -> Written:
    """Bring a card back from Recently deleted (from etag `if_match`, when given)."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        if row["deleted_at"] is None:
            raise NotFound("This contact is not in Recently deleted.")
        _check_etag(row, if_match)
        _baseline(db, row)
        rev = _set_deleted(db, row, False, at)
        # A merged original brought back on its own is a contact again, no longer part of the merge (whose undo is
        # then refused): its origins stop counting for the merged card, and deleting it again hides nothing.
        db.execute("UPDATE contacts SET merged_into = NULL WHERE id = ?", (contact_id,))
        undo_id = _record(db, contact_id, row["address_book_id"], row["href"], rev, None, "restore", "add", actor,
                          when, undo_op="restore")
    return Written(contact_id, undo_id)


def undo(store: ContactsStore, undo_id: str, *, actor: str) -> Written:
    """Undo one action, writing a new revision forward (see the module docstring)."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        entry = db.execute("SELECT * FROM undo_log WHERE id = ?", (undo_id,)).fetchone()
        if entry is None:
            raise NotFound("There is nothing to undo with that id.")
        if entry["undone_at"] is not None:
            raise UndoRefused("This was already undone.")
        try:
            row = _row(db, entry["object_id"])
        except NotFound:
            raise UndoRefused("This contact was deleted for good, so this cannot be undone.") from None
        if row["rev"] != entry["rev"]:
            raise UndoRefused("This contact changed since, so this cannot be undone.")
        op = entry["op"]
        if op == "update":
            prior = db.execute("SELECT rev, raw FROM revisions WHERE object_id = ? AND rev <= ? AND raw IS NOT NULL "
                               "ORDER BY rev DESC LIMIT 1", (row["id"], entry["prior_rev"])).fetchone()
            # Every revision from that text up to the one the edit started from must be recorded (a delete or a
            # restore keeps the text); a gap is a change written around this module, which undo would lose.
            recorded = 0 if prior is None else db.execute(
                "SELECT COUNT(*) FROM revisions WHERE object_id = ? AND rev > ? AND rev <= ?",
                (row["id"], prior["rev"], entry["prior_rev"])).fetchone()[0]
            if prior is None or recorded != entry["prior_rev"] - prior["rev"]:
                raise UndoRefused("The earlier version of this contact is not kept, so this cannot be undone.")
            rev = _write_text(db, row, prior["raw"], when)
            raw, change = prior["raw"], "modify"
        else:
            deleting = op in ("create", "restore")  # undoing a delete restores; the others go to the trash
            rev = _set_deleted(db, row, deleting, at)
            raw, change = None, "delete" if deleting else "add"
        _record(db, row["id"], row["address_book_id"], row["href"], rev, raw, "undo", change, actor, when,
                undo_op=None)
        db.execute("UPDATE undo_log SET undone_at = ?, undone_by = ?, undone_rev = ? WHERE id = ?",
                   (when, actor, rev, undo_id))
    return Written(row["id"], None)


# ---------------------------------------------------------------- the trash

def trash(store: ContactsStore) -> list[dict]:
    """Owned contacts in Recently deleted, the most recently deleted first."""
    from .contacts_store import _row as public_row
    with store.db.connect() as db:
        rows = db.execute("SELECT c.* FROM contacts c JOIN address_books b ON b.id = c.address_book_id "
                          "WHERE b.mode = ? AND c.deleted_at IS NOT NULL AND c.kind != 'group' "
                          "ORDER BY c.deleted_at DESC, c.id", (owned.OWNED,)).fetchall()
    return [public_row(r) for r in rows]


def purge_now(store: ContactsStore, contact_id: str, *, if_match: str) -> None:
    """Delete one card in Recently deleted for good now, because the user asked, with its revisions, as
    expire_trash does for cards whose time is over. A card that is not in Recently deleted is refused
    (NotFound), so a contact in use is never purged by mistake; a followed one is refused (ReadOnly); one
    whose etag is not `if_match` (restored, changed and deleted again since the user saw it) is refused
    (PreconditionFailed). The caller logs who asked."""
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        if row["deleted_at"] is None:
            raise NotFound("This contact is not in Recently deleted.")
        current = http_etag(row["rev"], row["raw_sha256"])
        if not if_match or if_match.strip() != current:
            raise PreconditionFailed("This contact changed since it was read. Look at it again first.", current)
        _settle_origins(db, [contact_id])
        owned.purge(db, owned.CONTACTS, row_ids=[contact_id])
        db.execute("DELETE FROM revisions WHERE object_id = ?", (contact_id,))
        db.execute("INSERT INTO contacts_fts (contacts_fts) VALUES ('optimize')")
    store.db.checkpoint()


def _settle_origins(db: sqlite3.Connection, ids: list[str]) -> None:
    """Before the cards `ids` are purged: the origins they hold (their own, and those held for originals merged
    into them) go with them, except those of a card merged into one that stays (merged_into, followed past cards
    purged now): the merged card holds them from now on (`held_by`), without the original's text (source_raw), so
    it keeps shadowing the followed copies and importing again still knows them (contacts_store._SHADOWED)."""
    purged = set(ids)
    for contact_id in ids:
        successor, seen = contact_id, {contact_id}
        while successor in purged:
            row = db.execute("SELECT merged_into FROM contacts WHERE id = ?", (successor,)).fetchone()
            successor = row["merged_into"] if row is not None else None
            if successor is None or successor in seen:
                successor = None
                break
            seen.add(successor)
        if successor is not None and db.execute("SELECT 1 FROM contacts WHERE id = ?", (successor,)).fetchone():
            db.execute("UPDATE origins SET held_by = ?, source_raw = NULL WHERE held_by = ? OR (held_by IS NULL "
                       "AND object_id = ?)", (successor, contact_id, contact_id))
        else:
            db.execute("DELETE FROM origins WHERE held_by = ? OR (held_by IS NULL AND object_id = ?)",
                       (contact_id, contact_id))


def expire_trash(store: ContactsStore, now: datetime | None = None) -> int:
    """Purge the owned contacts whose time in Recently deleted is over (purge_after <= now), with their
    revisions. Returns how many went."""
    when = stamp(now or _clock(store)())
    with store.db.transaction() as db:
        ids = [r[0] for r in db.execute(
            "SELECT c.id FROM contacts c JOIN address_books b ON b.id = c.address_book_id WHERE b.mode = ? "
            "AND c.deleted_at IS NOT NULL AND c.purge_after IS NOT NULL AND c.purge_after <= ?", (owned.OWNED, when))]
        if not ids:
            return 0
        _settle_origins(db, ids)
        gone = owned.purge(db, owned.CONTACTS, row_ids=ids)["rows"]
        db.executemany("DELETE FROM revisions WHERE object_id = ?", [(i,) for i in ids])
        db.execute("INSERT INTO contacts_fts (contacts_fts) VALUES ('optimize')")
    store.db.checkpoint()
    return gone
