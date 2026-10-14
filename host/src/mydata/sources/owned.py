"""Owned and followed data in the contacts and calendar stores, and what keeps owned data from being deleted.

Every collection (an address book, a calendar) has a mode:

- **followed**: a read-only copy of a source (an iCloud account, This Mac). Turning the source off, taking
  its access away, leaving a collection out of the selection or removing the account deletes it outright;
  the source still has it.
- **owned**: the host holds the only copy (nothing creates one yet: the import and the editors come later).
  Its rows use the account id OWNED_ACCOUNT, since `account_id` is NOT NULL.

The database itself refuses to delete owned data, whatever the code asks (the triggers below, added by
each store's migration):

- an owned collection cannot be deleted, nor turned into a followed one, unless a purge permit names it
  and every row in it;
- a row in an owned collection cannot be deleted, nor moved to a collection that is not owned, unless a
  permit names it. SQLite runs these triggers for foreign-key cascades too, and the connection turns on
  recursive_triggers so a row removed by INSERT OR REPLACE runs them as well.

A permit is a row of `purge_permits`, written by purge() in the same transaction as the delete and removed
before it commits. Only the trash expiry and "Forget" (both later) may call purge().

The other tables added with modes are empty until the writers and the import exist: `revisions` (each
version of an owned row's raw text), `changes` (the change feed), `imports`, `origins` (where an imported
row came from, keyed by the source's UID and never by a followed row's id) and `meta`.

Times in every new table are text in the unit the existing columns use: ISO 8601 in UTC to the second,
as _db.now() writes them ("2026-10-13T09:30:00+00:00").
"""

from __future__ import annotations

import hashlib
import sqlite3
from collections.abc import Iterable, Sequence

OWNED = "owned"
FOLLOWED = "followed"
OWNED_ACCOUNT = "local"  # the account_id of owned collections and rows; never a source's id

# (collections table, rows table, the rows' column naming their collection) per store
CONTACTS = ("address_books", "contacts", "address_book_id")
CALENDAR = ("calendars", "events", "calendar_id")
OCCURRENCES = ("occurrences", "calendar_id")  # This Mac's rows: always followed, protected all the same


def raw_hash(raw: str) -> str:
    """The sha256 of a row's raw text (hex): `raw_sha256`, kept beside the upstream `etag` so an owned row's
    own ETag can be made from it."""
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def mode_column(collections: str) -> str:
    """A CHECK keeps the value exact: 'Owned' would slip past every trigger."""
    return (f"ALTER TABLE {collections} ADD COLUMN mode TEXT NOT NULL DEFAULT '{FOLLOWED}' "
            f"CHECK (mode IN ('{OWNED}', '{FOLLOWED}'))")


def shared_tables() -> list[str]:
    """The tables both stores gain with modes (see the module docstring)."""
    return [
        "CREATE TABLE purge_permits (object_id TEXT PRIMARY KEY)",
        """CREATE TABLE revisions (
            object_id TEXT NOT NULL,
            rev INTEGER NOT NULL,
            raw TEXT,
            op TEXT NOT NULL,
            actor TEXT NOT NULL,
            approval_id TEXT,
            batch_id TEXT,
            at TEXT NOT NULL,
            PRIMARY KEY (object_id, rev)
        )""",
        """CREATE TABLE changes (
            token INTEGER PRIMARY KEY AUTOINCREMENT,
            collection_id TEXT NOT NULL,
            object_id TEXT NOT NULL,
            href TEXT NOT NULL,
            op TEXT NOT NULL CHECK (op IN ('add', 'modify', 'delete')),
            at TEXT NOT NULL
        )""",
        "CREATE INDEX changes_collection ON changes (collection_id, token)",
        """CREATE TABLE imports (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            label TEXT NOT NULL DEFAULT '',
            started_at TEXT NOT NULL,
            finished_at TEXT,
            counts TEXT NOT NULL DEFAULT '{}',
            status TEXT NOT NULL
        )""",
        """CREATE TABLE origins (
            object_id TEXT NOT NULL,
            import_id TEXT NOT NULL REFERENCES imports(id),
            source_kind TEXT NOT NULL,
            source_uid TEXT NOT NULL,
            source_hash TEXT NOT NULL,
            source_raw TEXT,
            imported_rev INTEGER NOT NULL,
            PRIMARY KEY (object_id, import_id)
        )""",
        "CREATE INDEX origins_source ON origins (source_kind, source_uid)",
        "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)",
    ]


def protection(collections: str, rows: str, fk: str, also: Sequence[tuple[str, str]] = ()) -> list[str]:
    """The triggers that keep owned data (see the module docstring). `also`: further (rows table, column)
    pairs whose rows belong to a collection the same way."""
    permitted = "SELECT object_id FROM purge_permits"
    unpermitted = " OR ".join(f"EXISTS (SELECT 1 FROM {t} WHERE {c} = OLD.id AND id NOT IN ({permitted}))"
                              for t, c in ((rows, fk), *also))
    out = [
        # The parent row is already gone when a cascade deletes its children, so a child's trigger cannot
        # see that it was owned: the collection's own trigger checks every row before the cascade starts.
        f"""CREATE TRIGGER {collections}_keep_owned BEFORE DELETE ON {collections}
            WHEN OLD.mode = '{OWNED}' AND (OLD.id NOT IN ({permitted}) OR {unpermitted})
            BEGIN SELECT RAISE(ABORT, 'owned data is never deleted without a purge permit'); END""",
        f"""CREATE TRIGGER {collections}_stay_owned BEFORE UPDATE OF mode ON {collections}
            WHEN OLD.mode = '{OWNED}' AND NEW.mode IS NOT '{OWNED}' AND OLD.id NOT IN ({permitted})
            BEGIN SELECT RAISE(ABORT, 'an owned collection is never made followed without a purge permit'); END""",
    ]
    for table, column in ((rows, fk), *also):
        owner = f"(SELECT mode FROM {collections} WHERE id = OLD.{column})"
        out += [
            f"""CREATE TRIGGER {table}_keep_owned BEFORE DELETE ON {table}
                WHEN {owner} = '{OWNED}' AND OLD.id NOT IN ({permitted})
                BEGIN SELECT RAISE(ABORT, 'owned data is never deleted without a purge permit'); END""",
            f"""CREATE TRIGGER {table}_stay_owned BEFORE UPDATE OF {column} ON {table}
                WHEN {owner} = '{OWNED}' AND (SELECT mode FROM {collections} WHERE id = NEW.{column}) IS NOT '{OWNED}'
                AND OLD.id NOT IN ({permitted})
                BEGIN SELECT RAISE(ABORT, 'owned data is never moved out of its collection without a purge permit');
                END""",
        ]
    return out


def purge(db: sqlite3.Connection, store: tuple[str, str, str], *, collection_ids: Iterable[str] = (),
          row_ids: Iterable[str] = (), also: Sequence[tuple[str, str]] = ()) -> dict[str, int]:
    """Hard-delete rows, and collections with everything in them, owned or not. The only code that may delete
    owned data: the trash expiry and "Forget" (not built yet). It must run inside the caller's transaction,
    which it leaves holding no permit. Returns {"collections", "rows"} deleted."""
    if not db.in_transaction:
        raise RuntimeError("purge runs inside the caller's transaction")
    collections, rows, fk = store
    collection_ids, row_ids = list(dict.fromkeys(collection_ids)), list(dict.fromkeys(row_ids))
    for cid in collection_ids:  # every row in a purged collection goes with it
        for table, column in ((rows, fk), *also):
            row_ids += [r[0] for r in db.execute(f"SELECT id FROM {table} WHERE {column} = ?", (cid,))]
    db.executemany("INSERT OR IGNORE INTO purge_permits (object_id) VALUES (?)",
                   [(i,) for i in [*collection_ids, *row_ids]])
    try:
        gone = {"collections": 0, "rows": 0}
        for i in row_ids:
            for table, _ in ((rows, fk), *also):
                gone["rows"] += db.execute(f"DELETE FROM {table} WHERE id = ?", (i,)).rowcount
        for cid in collection_ids:
            gone["collections"] += db.execute(f"DELETE FROM {collections} WHERE id = ?", (cid,)).rowcount
    finally:
        db.execute("DELETE FROM purge_permits")
    return gone


def followed_ids(db: sqlite3.Connection, collections: str, account_id: str,
                 urls: Iterable[str] | None = None) -> list[str]:
    """The ids of the account's followed collections (of these URLs, when given): the only collections the
    mirror's hard deletes may touch. Never an owned one, whatever its account id."""
    sql = f"SELECT id FROM {collections} WHERE account_id = ? AND mode = '{FOLLOWED}'"
    params: list = [account_id]
    if urls is not None:
        urls = list(urls)
        if not urls:
            return []
        sql += f" AND url IN ({', '.join('?' * len(urls))})"
        params += urls
    return [r[0] for r in db.execute(sql, params)]
