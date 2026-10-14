"""The contacts store: <home>/contacts.sqlite.

Copies of the user's address books, and the contacts the host owns. Each vCard is one row, keyed by (account, address book
URL, href); the raw card is kept beside the parsed fields. Duplicates are kept as they are. A card
deleted upstream gets the soft-delete marker; removing an account hard-deletes its rows. Sync state
(sync token, ctag, etags) is stored per address book in the same file.

Every address book is followed (a copy of a source) or owned (the host holds the only copy; see
sources/owned.py, whose triggers keep it from being deleted). Hard deletes here only ever touch followed
address books. Each card records its kind (`kind`: a group card, as iCloud sends groups, is never listed,
counted or found as a contact), its vCard version as received, a sha256 of its raw text (`raw_sha256`;
`etag` stays the source's ETag) and `rev`, which goes up by one whenever its raw text changes.

Owned cards are written only by sources/contacts_write.py (create, edit, Recently deleted, undo): their `rev`
also goes up on a delete or restore, and their `etag` column holds the API's etag (http_etag), since they
have no source. The undo log (`undo_log`) is in this file too.

Imports (sources/importer.py) write owned cards with an `origins` row naming where each came from (source kind,
account, UID), and, for a file, a `shadows` row for each followed card with the same name and the same email or
phone. The shadowing rule (_SHADOWED): a followed card an owned contact was imported from, or that a file import hid
behind it, matched by account and UID and never by the followed row's id, is left out of lists, counts, search and
find_contact while that owned contact is live (or was merged, `merged_into`, into one that is:
sources/contacts_merge.py). An owned contact whose followed copy changed since the import carries
`changed_in_source`.

The "This Mac" source (account_id "mac") is stored the same way: one synthetic address book per
Contacts container (url mac://contacts/<container id>) and a vCard generated from what the helper read
(sources/mac/cards.py), which holds no note.
"""

from __future__ import annotations

import json
import re
import sqlite3
from collections.abc import Iterable
from pathlib import Path

from . import owned
from ._db import Database, backfill, new_id, now
from ._mirror import load_state, retire_collections, soft_delete_missing, upsert_collection
from .dav.discovery import Collection
from .dav.sync import CollectionState, SyncResult
from .mac import MAC_ID
from .vcard import ParsedContact, card_kind, card_version, parse_vcard, phone_search_forms
from .vcard import photo as card_photo
from .views import compare_names

_SEARCH_COLUMNS = (
    "display_name", "full_name", "given_name", "family_name", "nickname", "organisation", "search_emails",
    "search_phones",
)
_NAME_COLUMNS = ("display_name", "full_name", "given_name", "family_name", "nickname")

_MIGRATIONS = {
    1: [
        """CREATE TABLE address_books (
            seq INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            account_id TEXT NOT NULL,
            url TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            color TEXT,
            sync_token TEXT,
            ctag TEXT,
            etags TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            deleted_at TEXT,
            UNIQUE (account_id, url)
        )""",
        """CREATE TABLE contacts (
            seq INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            account_id TEXT NOT NULL,
            address_book_id TEXT NOT NULL REFERENCES address_books(id) ON DELETE CASCADE,
            collection_url TEXT NOT NULL,
            href TEXT NOT NULL,
            etag TEXT NOT NULL DEFAULT '',
            uid TEXT NOT NULL DEFAULT '',
            display_name TEXT NOT NULL DEFAULT '',
            full_name TEXT NOT NULL DEFAULT '',
            given_name TEXT NOT NULL DEFAULT '',
            family_name TEXT NOT NULL DEFAULT '',
            nickname TEXT NOT NULL DEFAULT '',
            organisation TEXT NOT NULL DEFAULT '',
            emails TEXT NOT NULL DEFAULT '[]',
            phones TEXT NOT NULL DEFAULT '[]',
            addresses TEXT NOT NULL DEFAULT '[]',
            birthday TEXT,
            note TEXT NOT NULL DEFAULT '',
            has_photo INTEGER NOT NULL DEFAULT 0,
            raw_vcard TEXT NOT NULL,
            search_emails TEXT NOT NULL DEFAULT '',
            search_phones TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            deleted_at TEXT,
            UNIQUE (account_id, collection_url, href)
        )""",
        "CREATE INDEX contacts_book ON contacts (address_book_id, deleted_at)",
        "CREATE INDEX contacts_account ON contacts (account_id)",
        "CREATE INDEX contacts_name ON contacts (display_name COLLATE NOCASE)",
        f"""CREATE VIRTUAL TABLE contacts_fts USING fts5(
            {", ".join(_SEARCH_COLUMNS)},
            content='contacts', content_rowid='seq',
            tokenize='unicode61 remove_diacritics 2'
        )""",
        f"""CREATE TRIGGER contacts_fts_insert AFTER INSERT ON contacts BEGIN
            INSERT INTO contacts_fts (rowid, {", ".join(_SEARCH_COLUMNS)})
            VALUES (new.seq, {", ".join("new." + c for c in _SEARCH_COLUMNS)});
        END""",
        f"""CREATE TRIGGER contacts_fts_delete AFTER DELETE ON contacts BEGIN
            INSERT INTO contacts_fts (contacts_fts, rowid, {", ".join(_SEARCH_COLUMNS)})
            VALUES ('delete', old.seq, {", ".join("old." + c for c in _SEARCH_COLUMNS)});
        END""",
        f"""CREATE TRIGGER contacts_fts_update AFTER UPDATE ON contacts BEGIN
            INSERT INTO contacts_fts (contacts_fts, rowid, {", ".join(_SEARCH_COLUMNS)})
            VALUES ('delete', old.seq, {", ".join("old." + c for c in _SEARCH_COLUMNS)});
            INSERT INTO contacts_fts (rowid, {", ".join(_SEARCH_COLUMNS)})
            VALUES (new.seq, {", ".join("new." + c for c in _SEARCH_COLUMNS)});
        END""",
    ],
    # Owned and followed address books, and what cards gain with them (sources/owned.py). Additive only.
    2: [
        owned.mode_column("address_books"),
        "ALTER TABLE contacts ADD COLUMN rev INTEGER NOT NULL DEFAULT 1",
        "ALTER TABLE contacts ADD COLUMN raw_sha256 TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE contacts ADD COLUMN purge_after TEXT",
        # No CHECK on kind: vCard 4.0 lets KIND take values this host does not know yet, and a CHECK could
        # only be widened by rebuilding the table.
        "ALTER TABLE contacts ADD COLUMN kind TEXT NOT NULL DEFAULT 'individual'",
        "ALTER TABLE contacts ADD COLUMN version TEXT NOT NULL DEFAULT ''",
        backfill("contacts", "raw_vcard", "UPDATE contacts SET raw_sha256 = ?, kind = ?, version = ? WHERE seq = ?",
                 lambda raw: (owned.raw_hash(raw), card_kind(raw), card_version(raw))),
        *owned.shared_tables(),
        *owned.protection(*owned.CONTACTS),
    ],
    # Editing owned contacts (sources/contacts_write.py): the persisted undo log. Additive only.
    3: [
        """CREATE TABLE undo_log (
            id TEXT PRIMARY KEY,
            object_id TEXT NOT NULL,
            op TEXT NOT NULL CHECK (op IN ('create', 'update', 'delete', 'restore')),
            actor TEXT NOT NULL,
            rev INTEGER NOT NULL,
            prior_rev INTEGER,
            at TEXT NOT NULL,
            undone_at TEXT,
            undone_by TEXT,
            undone_rev INTEGER
        )""",
        "CREATE INDEX undo_log_object ON undo_log (object_id)",
    ],
    # Contact import (sources/importer.py) and merges (sources/contacts_merge.py). Additive only.
    4: [
        # The live contact a merged (soft-deleted) card went into: its origins still shadow their followed copies.
        "ALTER TABLE contacts ADD COLUMN merged_into TEXT",
        "ALTER TABLE origins ADD COLUMN source_account TEXT NOT NULL DEFAULT ''",
        # create (the import made the row), update (it changed an earlier import's row), link (an owned row the
        # user kept instead of the followed copy: nothing written to it)
        "ALTER TABLE origins ADD COLUMN action TEXT NOT NULL DEFAULT 'create'",
        "ALTER TABLE origins ADD COLUMN prior_rev INTEGER",
        "ALTER TABLE origins ADD COLUMN undone_at TEXT",
        "CREATE INDEX origins_account ON origins (source_account, source_uid)",
        "CREATE INDEX origins_import ON origins (import_id)",
        "ALTER TABLE imports ADD COLUMN actor TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE imports ADD COLUMN source_account TEXT NOT NULL DEFAULT ''",
        "ALTER TABLE imports ADD COLUMN address_book_id TEXT",
        "ALTER TABLE imports ADD COLUMN undone_at TEXT",
        "ALTER TABLE imports ADD COLUMN undone_by TEXT",
        """CREATE TABLE merges (
            id TEXT PRIMARY KEY,
            merged_id TEXT NOT NULL,
            merged_rev INTEGER NOT NULL,
            originals TEXT NOT NULL,
            links TEXT NOT NULL DEFAULT '{}',
            actor TEXT NOT NULL,
            at TEXT NOT NULL,
            undone_at TEXT,
            undone_by TEXT
        )""",
    ],
    # The contact an origin now belongs to once the merged original it named was deleted for good
    # (contacts_write._settle_origins): the merged card, so it keeps shadowing the followed copy. Additive only.
    5: [
        "ALTER TABLE origins ADD COLUMN held_by TEXT",
        "CREATE INDEX origins_held_by ON origins (held_by)",
    ],
    # Followed cards a file import hides behind the owned contact it wrote (sources/importer.py): the same name and
    # the same email or phone. Keyed by the followed card's account and UID, as origins are. Additive only.
    6: [
        """CREATE TABLE shadows (
            object_id TEXT NOT NULL,
            import_id TEXT NOT NULL REFERENCES imports(id),
            source_account TEXT NOT NULL,
            source_uid TEXT NOT NULL,
            source_hash TEXT NOT NULL,
            held_by TEXT,
            undone_at TEXT,
            PRIMARY KEY (object_id, import_id, source_account, source_uid)
        )""",
        "CREATE INDEX shadows_source ON shadows (source_account, source_uid)",
        "CREATE INDEX shadows_import ON shadows (import_id)",
        "CREATE INDEX shadows_held_by ON shadows (held_by)",
    ],
}

# Cards that are people or organisations: a group card is kept (and exported) but never shown as a contact.
_PEOPLE = "kind != 'group'"

# The shadowing rule (the owned-data plan, 2(a)): a followed card that an owned contact was imported from (an
# origin naming the same account and UID, never the followed row's id), or that a file import hid behind the owned
# contact it wrote (a shadow: the same name and the same email or phone, also keyed by account and UID), is hidden
# from lists, counts, search and find_contact while that owned contact is live, or was merged into one that is (also
# once the merged original is deleted for good: its origins and shadows are then held by the merged card,
# `held_by`). `c` is the followed row. A followed card that changes later stays hidden (its UID does not change);
# the owned contact is then flagged (changed_in_source). Deleting the owned contact shows the followed card again.
_LIVE_OWNER = """(oc.deleted_at IS NULL OR (oc.merged_into IS NOT NULL AND EXISTS (
        SELECT 1 FROM contacts m WHERE m.id = oc.merged_into AND m.deleted_at IS NULL)))"""
_SHADOWED = f"""(c.account_id != '{owned.OWNED_ACCOUNT}' AND c.uid != '' AND (EXISTS (
    SELECT 1 FROM origins o JOIN contacts oc ON oc.id = COALESCE(o.held_by, o.object_id)
    WHERE o.source_account = c.account_id AND o.source_uid = c.uid AND o.source_kind != 'file'
    AND o.undone_at IS NULL AND {_LIVE_OWNER}) OR EXISTS (
    SELECT 1 FROM shadows s JOIN contacts oc ON oc.id = COALESCE(s.held_by, s.object_id)
    WHERE s.source_account = c.account_id AND s.source_uid = c.uid AND s.undone_at IS NULL AND {_LIVE_OWNER})))"""
# A card shown as a contact: a person or organisation, not shadowed by an owned copy.
_VISIBLE = f"c.{_PEOPLE} AND NOT {_SHADOWED}"

_PUBLIC_FIELDS = (
    "id", "account_id", "address_book_id", "collection_url", "href", "etag", "uid", "display_name", "full_name",
    "given_name", "family_name", "nickname", "organisation", "birthday", "note", "created_at", "modified_at",
    "deleted_at",
)


def fts_query(text: str, columns: Iterable[str] | None = None) -> str | None:
    """Turn user text into a safe FTS5 expression: every word becomes a quoted prefix term, all must
    match. User text never reaches FTS syntax unquoted. None when the text has no words."""
    words = re.findall(r"\w+", text)
    if not words:
        return None
    terms = " AND ".join('"' + w.replace('"', '""') + '"*' for w in words)
    if columns:
        return "{" + " ".join(columns) + "} : (" + terms + ")"
    return terms


def http_etag(rev: int, raw_sha256: str) -> str:
    """A card's ETag as the API gives it (and as an owned card's `etag` column holds it): its revision and
    the start of its text's sha256, quoted. It changes with every write, a delete or restore included."""
    return f'"{rev}-{raw_sha256[:16]}"'


def source_of(account_id: str) -> str:
    """Which kind of source a card's account is: "mac" (This Mac), "mydata" (owned: the host holds the only
    copy) or "icloud" (a CardDAV account)."""
    if account_id == MAC_ID:
        return "mac"
    return "mydata" if account_id == owned.OWNED_ACCOUNT else "icloud"


def _row(row: sqlite3.Row, *, raw: bool = False) -> dict:
    out = {k: row[k] for k in _PUBLIC_FIELDS}
    out["emails"] = json.loads(row["emails"])
    out["phones"] = json.loads(row["phones"])
    out["addresses"] = json.loads(row["addresses"])
    out["has_photo"] = bool(row["has_photo"])
    # Where the card came from, and whether its notes were read (never on a Mac: see sources/mac).
    out["source"] = source_of(row["account_id"])
    out["notes_included"] = row["account_id"] != MAC_ID
    # Owned cards (always under the owned account id: sources/owned.py) are the ones the apps may change.
    out["editable"] = row["account_id"] == owned.OWNED_ACCOUNT
    out["http_etag"] = http_etag(row["rev"], row["raw_sha256"])
    out["rev"] = row["rev"]
    out["purge_after"] = row["purge_after"]
    out["changed_in_source"] = None  # set by _annotated for owned rows (ContactsStore.changed_in_source)
    if raw:
        out["raw_vcard"] = row["raw_vcard"]
    return out


# FTS5 secure-delete (SQLite 3.42+): a deleted or changed contact's words are removed from the index
# itself, instead of being hidden behind a tombstone while the old bytes stay in the file.
_FTS_SECURE_DELETE = sqlite3.sqlite_version_info >= (3, 42, 0)


class ContactsStore:
    MIGRATIONS = _MIGRATIONS  # read by service/backup.open_store to snapshot before a migration
    # The writer's clock (sources/contacts_write.py): None is the real time; tests set a fixed one.
    clock = None

    def __init__(self, path: Path):
        self.db = Database(path, self.MIGRATIONS)
        if _FTS_SECURE_DELETE:
            with self.db.connect() as db:  # a persistent index setting; setting it again changes nothing
                db.execute("INSERT INTO contacts_fts (contacts_fts, rank) VALUES ('secure-delete', 1)")

    # ------------------------------------------------------------------ sync

    def apply(self, account_id: str, collection: Collection, result: SyncResult) -> None:
        """Store one sync result for one address book, in one transaction.

        Changed items are upserted by (account, address book URL, href); deleted hrefs get the soft-delete
        marker. For a full result, anything not present upstream is soft-deleted too, where present means
        a changed href or an href in result.state.etags (the full listing). The new sync state is saved.
        """
        if collection.kind != "contacts":
            raise ValueError("ContactsStore only stores address books")
        stamp = now()
        with self.db.transaction() as db:
            book_id = upsert_collection(db, "address_books", account_id, collection, result.state, stamp)
            for item in result.changed:
                self._upsert_card(db, account_id, book_id, collection.url, item.href, item.etag, item.data, stamp)
            for href in result.deleted:
                db.execute(
                    "UPDATE contacts SET deleted_at = ?, modified_at = ? "
                    "WHERE account_id = ? AND collection_url = ? AND href = ? AND deleted_at IS NULL",
                    (stamp, stamp, account_id, collection.url, href),
                )
            if result.full:
                present = {i.href for i in result.changed} | set(result.state.etags)
                soft_delete_missing(db, "contacts", account_id, collection.url, present, stamp)

    @staticmethod
    def _upsert_card(db, account_id, book_id, collection_url, href, etag, data, stamp) -> None:
        fields = card_fields(etag, data)
        existing = db.execute(
            "SELECT id, etag, raw_vcard, deleted_at FROM contacts WHERE account_id = ? AND collection_url = ? AND href = ?",
            (account_id, collection_url, href),
        ).fetchone()
        if existing is None:
            columns = ["id", "account_id", "address_book_id", "collection_url", "href", *fields, "created_at",
                       "modified_at"]
            values = [new_id(), account_id, book_id, collection_url, href, *fields.values(), stamp, stamp]
            db.execute(
                f"INSERT INTO contacts ({', '.join(columns)}) VALUES ({', '.join('?' * len(columns))})",
                values,
            )
            return
        if existing["etag"] == fields["etag"] and existing["raw_vcard"] == data and existing["deleted_at"] is None:
            return
        assignments = ", ".join(f"{k} = ?" for k in fields)
        db.execute(
            f"UPDATE contacts SET {assignments}, rev = rev + (raw_vcard IS NOT ?), address_book_id = ?, "
            "modified_at = ?, deleted_at = NULL WHERE id = ?",
            [*fields.values(), data, book_id, stamp, existing["id"]],
        )

    def collection_state(self, account_id: str, collection_url: str) -> CollectionState:
        """The saved sync state for an address book (empty when it has never been synced)."""
        with self.db.connect() as db:
            return load_state(db, "address_books", account_id, collection_url)

    def mark_collections_gone(self, account_id: str, present_urls: Iterable[str]) -> None:
        """Soft-delete this account's address books that discovery no longer finds, and their cards."""
        with self.db.transaction() as db:
            retire_collections(db, "address_books", "contacts", "address_book_id", account_id, set(present_urls), now())

    def delete_account(self, account_id: str) -> None:
        """Hard-delete everything mirrored from one account (cards, address books, sync state), leaving no
        readable trace in the file: the full-text index is rewritten too (its old segments would otherwise
        keep the names, emails and phone numbers until a merge), and secure_delete zeroes the freed pages.
        Only the account's followed address books go; an owned one is never touched."""
        with self.db.transaction() as db:
            self._delete_followed(db, owned.followed_ids(db, "address_books", account_id))
        self.db.checkpoint()

    @staticmethod
    def _delete_followed(db, book_ids: list[str]) -> None:
        """Hard-delete these address books and their cards: ids from owned.followed_ids, never anything else."""
        for book_id in book_ids:
            db.execute("DELETE FROM contacts WHERE address_book_id = ?", (book_id,))
            db.execute("DELETE FROM address_books WHERE id = ?", (book_id,))
        if book_ids:
            db.execute("INSERT INTO contacts_fts (contacts_fts) VALUES ('optimize')")

    def purge(self, *, address_book_ids: Iterable[str] = (), contact_ids: Iterable[str] = ()) -> dict[str, int]:
        """Hard-delete cards, and address books with every card in them, owned ones included (owned.purge).
        Only for the trash expiry and "Forget", which do not exist yet. Leaves no readable trace, as
        delete_account does."""
        with self.db.transaction() as db:
            book_ids, contact_ids = list(address_book_ids), list(contact_ids)
            for book_id in book_ids:
                contact_ids += [r[0] for r in db.execute("SELECT id FROM contacts WHERE address_book_id = ?",
                                                         (book_id,))]
            gone = owned.purge(db, owned.CONTACTS, collection_ids=book_ids, row_ids=contact_ids)
            db.executemany("DELETE FROM origins WHERE object_id = ?", [(i,) for i in contact_ids])
            db.executemany("DELETE FROM shadows WHERE object_id = ? OR held_by = ?", [(i, i) for i in contact_ids])
            db.execute("INSERT INTO contacts_fts (contacts_fts) VALUES ('optimize')")
        self.db.checkpoint()
        return gone

    def address_book_ids(self, account_id: str) -> dict[str, str]:
        """{address book URL: id} for the account's address books (not soft-deleted)."""
        with self.db.connect() as db:
            rows = db.execute("SELECT id, url FROM address_books WHERE account_id = ? AND deleted_at IS NULL",
                              (account_id,)).fetchall()
        return {r["url"]: r["id"] for r in rows}

    def delete_collections(self, account_id: str, urls: Iterable[str]) -> int:
        """Hard-delete these followed address books of the account and their cards, as delete_account does for
        a whole account (the full-text index is rewritten too). Returns how many address books went."""
        urls = list(urls)
        if not urls:
            return 0
        with self.db.transaction() as db:
            gone = owned.followed_ids(db, "address_books", account_id, urls)
            self._delete_followed(db, gone)
        if gone:
            self.db.checkpoint()
        return len(gone)

    def photo(self, contact_id: str) -> tuple[bytes, str] | None:
        """The contact's photo (bytes, media type), JPEG or PNG; None when it has none or is unknown."""
        with self.db.connect() as db:
            row = db.execute(f"SELECT raw_vcard, has_photo FROM contacts WHERE id = ? AND deleted_at IS NULL "
                             f"AND {_PEOPLE}", (contact_id,)).fetchone()
        if row is None or not row["has_photo"]:
            return None
        return card_photo(row["raw_vcard"])

    def account_ids(self) -> list[str]:
        """Every account with followed address books in this file (to find data left by an account that was
        removed). Owned address books are not a source's: they never count."""
        with self.db.connect() as db:
            rows = db.execute("SELECT DISTINCT account_id FROM address_books WHERE mode = 'followed'").fetchall()
        return sorted(r[0] for r in rows)

    def counts(self, account_id: str) -> dict[str, int]:
        """How many address books and contacts (not soft-deleted) the account has in the mirror. A card shadowed
        by an owned copy imported from it is not counted (_SHADOWED)."""
        with self.db.connect() as db:
            books = db.execute("SELECT COUNT(*) FROM address_books WHERE account_id = ? AND deleted_at IS NULL",
                               (account_id,)).fetchone()[0]
            cards = db.execute(f"SELECT COUNT(*) FROM contacts c WHERE c.account_id = ? AND c.deleted_at IS NULL "
                               f"AND {_VISIBLE}", (account_id,)).fetchone()[0]
        return {"address_books": books, "contacts": cards}

    # ------------------------------------------------------------------ reading

    def address_books(self) -> list[dict]:
        with self.db.connect() as db:
            rows = db.execute(
                "SELECT b.id, b.account_id, b.url, b.name, b.color, "
                f"(SELECT COUNT(*) FROM contacts c WHERE c.address_book_id = b.id AND c.deleted_at IS NULL "
                f"AND {_VISIBLE}) AS count "
                "FROM address_books b WHERE b.deleted_at IS NULL ORDER BY b.name COLLATE NOCASE, b.url"
            ).fetchall()
        return [dict(r) for r in rows]

    def list(self, limit: int = 500, offset: int = 0) -> list[dict]:
        """Contacts by name, ignoring case and accents (views.sort_key), so a letter group is never split by
        an accented name: SQLite's NOCASE folds ASCII only and would put "Émile" after "Zed". A followed card an
        owned contact was imported from is left out (_SHADOWED)."""
        limit, offset = _bounded(limit), max(int(offset), 0)
        with self.db.connect() as db:
            db.create_collation("MYDATA_NAME", compare_names)
            rows = db.execute(
                f"SELECT c.* FROM contacts c WHERE c.deleted_at IS NULL AND {_VISIBLE} "
                "ORDER BY c.display_name COLLATE MYDATA_NAME, c.id LIMIT ? OFFSET ?",
                (limit, offset),
            ).fetchall()
            return _annotated(db, rows)

    def get(self, contact_id: str, *, include_deleted: bool = False) -> dict | None:
        """One contact with its raw vCard, or None (also None when soft-deleted, unless asked, and for a group
        card, which is not a contact)."""
        with self.db.connect() as db:
            row = db.execute(f"SELECT * FROM contacts WHERE id = ? AND {_PEOPLE}", (contact_id,)).fetchone()
            if row is None or (row["deleted_at"] is not None and not include_deleted):
                return None
            return _annotated(db, [row], raw=True)[0]

    def search(self, query: str, limit: int = 50) -> list[dict]:
        """Full-text search over names, nickname, organisation, emails and phones. Every word must match,
        as a prefix, ignoring case and accents."""
        expr = fts_query(query)
        if expr is None:
            return []
        with self.db.connect() as db:
            return _annotated(db, self._match(expr, _bounded(limit), db))

    def find_by_name(self, name: str) -> list[dict]:
        """Contacts whose name matches every word of `name` as a prefix (for the find_contact tool), owned and
        followed alike. Duplicates come back as separate matches, but a followed card an owned contact was
        imported from is not one (_SHADOWED: one match per person imported from a source still followed). A
        possessive "'s" is ignored."""
        cleaned = re.sub(r"['’]s\b", "", name)
        expr = fts_query(cleaned, _NAME_COLUMNS)
        if expr is None:
            return []
        return [
            {
                "id": r["id"],
                "name": r["display_name"],
                "emails": [e["value"] for e in json.loads(r["emails"])],
                "phones": [p["value"] for p in json.loads(r["phones"])],
            }
            for r in self._match(expr, 50)
        ]

    def _match(self, expr: str, limit: int, db: sqlite3.Connection | None = None) -> list[sqlite3.Row]:
        if db is None:
            with self.db.connect() as own:
                return self._match(expr, limit, own)
        return db.execute(
            "SELECT c.* FROM contacts_fts JOIN contacts c ON c.seq = contacts_fts.rowid "
            f"WHERE contacts_fts MATCH ? AND c.deleted_at IS NULL AND {_VISIBLE} "
            "ORDER BY bm25(contacts_fts), c.display_name COLLATE NOCASE, c.id LIMIT ?",
            (expr, limit),
        ).fetchall()

    def changed_in_source(self, contact_ids: Iterable[str]) -> dict[str, str]:
        """{owned contact id: followed account id} for owned contacts imported from a followed source whose
        followed copy changed after the import (its text's hash is not the one the import recorded)."""
        with self.db.connect() as db:
            return changed_in_source(db, list(contact_ids))


def changed_in_source(db: sqlite3.Connection, ids: list[str]) -> dict[str, str]:
    """See ContactsStore.changed_in_source. An owned contact's origins and shadows are its own and those of the cards
    merged into it (held by it once those are deleted for good); for each (account, UID) only the newest origin and
    the newest shadow count (a later import from the source moved it on), and the followed card has changed when its
    text is neither."""
    links: dict[tuple[str, str, str], list[bool]] = {}  # (owner, account, UID): [is the followed card that text]
    for start in range(0, len(ids), 400):
        chunk = ids[start:start + 400]
        marks = ", ".join("?" * len(chunk))
        objects = ("WITH objects(owner, object_id) AS ("
                   f"  SELECT id, id FROM contacts WHERE id IN ({marks})"
                   f"  UNION ALL SELECT merged_into, id FROM contacts WHERE merged_into IN ({marks})"
                   f"  UNION ALL SELECT DISTINCT held_by, object_id FROM origins WHERE held_by IN ({marks})), ")
        followed = (f"JOIN contacts f ON f.account_id = o.source_account AND f.uid = o.source_uid "
                    f"AND f.deleted_at IS NULL AND f.account_id != '{owned.OWNED_ACCOUNT}'")
        rows = db.execute(
            objects + "latest AS (SELECT objects.owner, o.source_account, o.source_uid, MAX(o.rowid) AS rid "
            "  FROM origins o JOIN objects ON objects.object_id = o.object_id "
            "  WHERE o.source_kind != 'file' AND o.undone_at IS NULL "
            "  GROUP BY objects.owner, o.source_account, o.source_uid) "
            "SELECT DISTINCT latest.owner, o.source_account, o.source_uid, f.raw_sha256 = o.source_hash AS same "
            f"FROM latest JOIN origins o ON o.rowid = latest.rid {followed}",
            [*chunk, *chunk, *chunk]).fetchall()
        rows += db.execute(
            objects + "latest AS (SELECT objects.owner, o.source_account, o.source_uid, MAX(o.rowid) AS rid "
            "  FROM shadows o JOIN objects ON objects.object_id = COALESCE(o.held_by, o.object_id) "
            "  WHERE o.undone_at IS NULL GROUP BY objects.owner, o.source_account, o.source_uid) "
            "SELECT DISTINCT latest.owner, o.source_account, o.source_uid, f.raw_sha256 = o.source_hash AS same "
            f"FROM latest JOIN shadows o ON o.rowid = latest.rid {followed}",
            [*chunk, *chunk, *chunk]).fetchall()
        for owner, account, uid, same in rows:
            links.setdefault((owner, account, uid), []).append(bool(same))
    out: dict[str, str] = {}
    for (owner, account, _uid), same in sorted(links.items()):
        if not any(same):
            out.setdefault(owner, account)
    return out


def _annotated(db: sqlite3.Connection, rows: list[sqlite3.Row], *, raw: bool = False) -> list[dict]:
    """Rows as _row gives them, owned ones with `changed_in_source` (the followed account whose copy changed
    since the import, or None)."""
    owned_ids = [r["id"] for r in rows if r["account_id"] == owned.OWNED_ACCOUNT]
    changed = changed_in_source(db, owned_ids) if owned_ids else {}
    out = []
    for r in rows:
        item = _row(r, raw=raw)
        item["changed_in_source"] = changed.get(r["id"])
        out.append(item)
    return out


def card_fields(etag: str | None, data: str, parsed: ParsedContact | None = None) -> dict:
    """Every column a card's raw text decides (the parsed fields, the search columns, its hash, kind and
    version), with its etag: for the mirror's upsert and the owned-contact writer alike. `parsed`: the card as
    parse_vcard already read it (the importer reads each card once)."""
    card = parsed if parsed is not None else parse_vcard(data)
    return {
        "etag": etag or "",
        "uid": card.uid,
        "display_name": card.display_name,
        "full_name": card.full_name,
        "given_name": card.given_name,
        "family_name": card.family_name,
        "nickname": card.nickname,
        "organisation": card.organisation,
        "emails": json.dumps(card.emails, ensure_ascii=False),
        "phones": json.dumps(card.phones, ensure_ascii=False),
        "addresses": json.dumps(card.addresses, ensure_ascii=False),
        "birthday": card.birthday,
        "note": card.note,
        "has_photo": int(card.has_photo),
        "raw_vcard": data,
        "raw_sha256": owned.raw_hash(data),
        "kind": card_kind(data),
        "version": card_version(data),
        "search_emails": " ".join(e["value"] for e in card.emails),
        "search_phones": " ".join(
            [p["value"] for p in card.phones] + [f for p in card.phones for f in phone_search_forms(p["value"])]
        ),
    }


def _bounded(limit: int) -> int:
    return min(max(int(limit), 1), 5000)
