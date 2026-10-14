"""The migration runner (sources/_db.py): foreign keys are off while migrations run, so rebuilding a
parent table never cascades into its children, and the checks afterwards roll back a migration that
leaves the file broken."""

import re
import sqlite3

import pytest

from mydata.sources._db import Database, MigrationError, backfill, check
from mydata.sources.contacts_store import ContactsStore

V1 = {1: ["CREATE TABLE books (id TEXT PRIMARY KEY, name TEXT)",
          "CREATE TABLE cards (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id) ON DELETE CASCADE)"]}

# SQLite's 12-step rebuild of the parent table (new table, copy, drop, rename), e.g. to add a constraint.
REBUILD_BOOKS = ["CREATE TABLE books_new (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '')",
                 "INSERT INTO books_new SELECT id, COALESCE(name, '') FROM books",
                 "DROP TABLE books",
                 "ALTER TABLE books_new RENAME TO books"]


def _seed(path, cards=5):
    db = Database(path, V1)
    with db.transaction() as c:
        c.execute("INSERT INTO books VALUES ('b', 'Book')")
        c.executemany("INSERT INTO cards VALUES (?, 'b')", [(f"c{i}",) for i in range(cards)])
    return db


def _count(db, table):
    with db.connect() as c:
        return c.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def _version(db):
    with db.connect() as c:
        return c.execute("SELECT MAX(version) FROM schema_version").fetchone()[0]


def test_rebuilding_a_parent_table_keeps_its_children(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    db = Database(path, {**V1, 2: REBUILD_BOOKS})
    assert _count(db, "books") == 1
    assert _count(db, "cards") == 5
    assert _version(db) == 2


def test_foreign_keys_are_on_again_after_migrating(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    db = Database(path, {**V1, 2: REBUILD_BOOKS})
    with db.connect() as c:
        assert c.execute("PRAGMA foreign_keys").fetchone()[0] == 1
    with db.transaction() as c:  # the cascade still works for ordinary deletes
        c.execute("DELETE FROM books WHERE id = 'b'")
    assert _count(db, "cards") == 0


def test_a_migration_that_breaks_a_foreign_key_is_rolled_back(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    # Drops the parent without a replacement: with foreign keys off nothing stops it, the check must.
    bad = ["CREATE TABLE books_new (id TEXT PRIMARY KEY, name TEXT)",
           "DROP TABLE books",
           "ALTER TABLE books_new RENAME TO books"]
    with pytest.raises(MigrationError, match="foreign key"):
        Database(path, {**V1, 2: bad})
    db = Database(path, V1)  # the file is as it was: version 1, every row there
    assert _version(db) == 1
    assert (_count(db, "books"), _count(db, "cards")) == (1, 5)


def test_a_failing_statement_rolls_the_whole_migration_back(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    with pytest.raises(sqlite3.OperationalError):
        Database(path, {**V1, 2: ["DROP TABLE cards", "SELECT * FROM no_such_table"]})
    db = Database(path, V1)
    assert _version(db) == 1 and _count(db, "cards") == 5


def test_a_function_step_backfills_what_sql_cannot_compute(tmp_path):
    import hashlib

    path = tmp_path / "t.sqlite"
    _seed(path)
    backfill = lambda c: c.executemany(  # noqa: E731
        "UPDATE cards SET digest = ? WHERE id = ?",
        [(hashlib.sha256(i.encode()).hexdigest(), i) for (i,) in c.execute("SELECT id FROM cards").fetchall()])
    db = Database(path, {**V1, 2: ["ALTER TABLE cards ADD COLUMN digest TEXT NOT NULL DEFAULT ''", backfill]})
    with db.connect() as c:
        rows = c.execute("SELECT id, digest FROM cards").fetchall()
    assert len(rows) == 5 and all(d == hashlib.sha256(i.encode()).hexdigest() for i, d in rows)


@pytest.mark.parametrize("rows", [0, 1, 3, 7])
def test_backfill_reads_a_batch_at_a_time_and_reaches_every_row(tmp_path, rows):
    """Gaps in seq (deleted rows) and a last batch that is short, full or empty all end with every row set."""
    path = tmp_path / "t.sqlite"
    db = Database(path, {1: ["CREATE TABLE items (seq INTEGER PRIMARY KEY, raw TEXT NOT NULL)"]})
    with db.transaction() as c:
        c.executemany("INSERT INTO items (seq, raw) VALUES (?, ?)", [(i * 2 + 5, f"r{i}") for i in range(rows)])
    seen = []
    step = backfill("items", "raw", "UPDATE items SET up = ? WHERE seq = ?",
                    lambda raw: (seen.append(raw) or raw.upper(),), size=3)
    db = Database(path, {1: [], 2: ["ALTER TABLE items ADD COLUMN up TEXT NOT NULL DEFAULT ''", step]})
    with db.connect() as c:
        assert [tuple(r) for r in c.execute("SELECT raw, up FROM items ORDER BY seq")] == [
            (f"r{i}", f"R{i}") for i in range(rows)]
    assert seen == [f"r{i}" for i in range(rows)]  # each row once


def test_a_migration_that_drops_a_trigger_is_rolled_back(tmp_path):
    """Dropping a table drops its triggers, and nothing else would notice: a rebuild must make them again."""
    path = tmp_path / "t.sqlite"
    guard = ("CREATE TRIGGER books_guard BEFORE DELETE ON books WHEN OLD.name = 'Kept' "
             "BEGIN SELECT RAISE(ABORT, 'kept'); END")
    db = _seed(path)
    Database(path, {**V1, 2: [guard]})
    with pytest.raises(MigrationError, match="the trigger books_guard is gone"):
        Database(path, {**V1, 2: [guard], 3: REBUILD_BOOKS})
    assert _version(db) == 2
    db = Database(path, {**V1, 2: [guard], 3: [*REBUILD_BOOKS, guard]})
    assert _version(db) == 3 and _count(db, "cards") == 5


def test_a_newer_file_is_refused(tmp_path):
    path = tmp_path / "t.sqlite"
    Database(path, {**V1, 2: ["CREATE TABLE extra (x)"]})
    with pytest.raises(RuntimeError, match="newer"):
        Database(path, V1)


def test_pending_reports_the_versions_of_an_existing_file(tmp_path):
    path = tmp_path / "t.sqlite"
    assert Database.pending(path, V1) is None  # no file: nothing to protect
    _seed(path)
    assert Database.pending(path, V1) is None  # up to date
    assert Database.pending(path, {**V1, 2: REBUILD_BOOKS, 3: []}) == (1, 3)
    assert not (tmp_path / "missing.sqlite").exists()
    Database.pending(tmp_path / "missing.sqlite", V1)
    assert not (tmp_path / "missing.sqlite").exists()  # never creates the file


def _rebuild(path, table: str) -> tuple[list[str], list[str], list[str]]:
    """The steps of rebuilding `table` as it is in the file: dropping the triggers that name it (a rename
    fails while a trigger names a missing table), the rebuild itself, and creating those triggers again."""
    with sqlite3.connect(path) as c:
        [create] = c.execute("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?", (table,)).fetchone()
        triggers = [(n, q) for n, q in c.execute("SELECT name, sql FROM sqlite_master WHERE type = 'trigger'")
                    if re.search(rf"\b{table}\b", q)]
    create = create.replace(f"CREATE TABLE {table}", f"CREATE TABLE {table}_new", 1)
    return ([f"DROP TRIGGER {n}" for n, _ in triggers],
            [create, f"INSERT INTO {table}_new SELECT * FROM {table}", f"DROP TABLE {table}",
             f"ALTER TABLE {table}_new RENAME TO {table}"],
            [q for _, q in triggers])


def test_rebuilding_the_address_books_keeps_the_contacts_and_their_search_index(tmp_path):
    """The real contacts schema: a future migration that rebuilds address_books (the parent) keeps every
    contact, and searching still finds them. Dropping the table drops its triggers, so the rebuild makes them
    again (without them the runner rolls it back: next test)."""
    from test_contacts_store import ALL, BOOK, item, result

    path = tmp_path / "contacts.sqlite"
    ContactsStore(path).apply("acc-1", BOOK, result([item(n) for n in ALL], full=True))
    with sqlite3.connect(path) as c:
        before = c.execute("SELECT COUNT(*) FROM contacts").fetchone()[0]
    drop, rebuild, again = _rebuild(path, "address_books")
    assert "address_books_keep_owned" in " ".join(again)  # the owned-data guards (sources/owned.py)
    with pytest.raises(MigrationError, match="the trigger address_books_keep_owned is gone"):
        Database(path, {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: drop + rebuild})
    Database(path, {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: drop + rebuild + again})
    with sqlite3.connect(path) as c:
        assert before == len(ALL)
        assert c.execute("SELECT COUNT(*) FROM contacts").fetchone()[0] == before
        assert c.execute("SELECT COUNT(*) FROM contacts_fts WHERE contacts_fts MATCH 'Fictional'").fetchone()[0] == 1


def test_a_search_index_out_of_step_is_rebuilt_while_migrating(tmp_path):
    path = tmp_path / "t.sqlite"
    v1 = {1: ["CREATE TABLE notes (seq INTEGER PRIMARY KEY, body TEXT)",
              "CREATE VIRTUAL TABLE notes_fts USING fts5(body, content='notes', content_rowid='seq')"]}
    db = Database(path, v1)
    with db.transaction() as c:  # written without the index: it no longer matches its table
        c.execute("INSERT INTO notes VALUES (1, 'kiwi')")
    with db.connect() as c:
        assert check(c) == ["the search index notes_fts does not match its table"]
    db = Database(path, {**v1, 2: ["CREATE TABLE extra (x)"]})
    with db.connect() as c:
        assert check(c) == []
        assert c.execute("SELECT COUNT(*) FROM notes_fts WHERE notes_fts MATCH 'kiwi'").fetchone()[0] == 1


def test_a_parent_key_that_is_no_longer_unique_is_rolled_back(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    loose = ["CREATE TABLE books_new AS SELECT * FROM books", "DROP TABLE books",  # loses the PRIMARY KEY
             "ALTER TABLE books_new RENAME TO books"]
    with pytest.raises(MigrationError, match="foreign key"):
        Database(path, {**V1, 2: loose})
    assert _version(Database(path, V1)) == 1


def test_a_migration_that_loses_rows_is_rolled_back(tmp_path):
    """A rebuild that copies only some rows of a table with no children: nothing else notices it, and the
    search index that would show it must not be rebuilt over the loss."""
    from test_contacts_store import ALL, BOOK, item, result

    path = tmp_path / "contacts.sqlite"
    ContactsStore(path).apply("acc-1", BOOK, result([item(n) for n in ALL], full=True))
    drop, rebuild, again = _rebuild(path, "contacts")
    rebuild[1] += " WHERE seq % 2 = 0"
    lossy = drop + rebuild + again
    with pytest.raises(MigrationError, match=f"contacts has {len(ALL) // 2} rows, it had {len(ALL)} before"):
        Database(path, {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: lossy})
    with sqlite3.connect(path) as c:
        assert c.execute("SELECT COUNT(*) FROM contacts").fetchone()[0] == len(ALL)
        assert c.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == max(ContactsStore.MIGRATIONS)


def test_a_migration_may_declare_the_tables_it_shrinks(tmp_path):
    path = tmp_path / "t.sqlite"
    _seed(path)
    dedupe = ["DELETE FROM cards WHERE id IN ('c1', 'c2')"]
    with pytest.raises(MigrationError, match="cards has 3 rows, it had 5 before"):
        Database(path, {**V1, 2: dedupe})
    db = Database(path, {**V1, 2: dedupe}, may_shrink={2: ["cards"]})
    assert (_version(db), _count(db, "cards")) == (2, 3)


@pytest.mark.parametrize("sql", [
    # A card at the owned card's (account, collection, href): the owned one would be replaced.
    "INSERT OR REPLACE INTO contacts (id, account_id, address_book_id, collection_url, href, raw_vcard, created_at, "
    "modified_at) SELECT 'new', account_id, address_book_id, collection_url, href, 'x', 't', 't' FROM contacts "
    "WHERE address_book_id = 'owned-book-1' LIMIT 1",
    # The owned book itself, by its id: with foreign keys off nothing cascades, but the book would be gone.
    "INSERT OR REPLACE INTO address_books (id, account_id, url, created_at, modified_at) "
    "VALUES ('owned-book-1', 'acc-x', 'https://dav.example.invalid/b/', 't', 't')",
])
def test_a_migration_cannot_replace_owned_data(tmp_path, sql):
    """Migrations run with recursive_triggers on, as every other connection does: a row INSERT OR REPLACE
    removes runs the triggers that keep owned data, so the migration is rolled back. Row counts alone would
    not notice: a replace deletes one row and inserts one."""
    from mydata.sources import contacts_store
    from owned_data import add_owned, owned_rows

    add_owned(tmp_path)
    before = owned_rows(tmp_path)
    newest = max(contacts_store._MIGRATIONS)
    with pytest.raises(sqlite3.IntegrityError, match="owned data is never deleted"):
        Database(tmp_path / "contacts.sqlite", {**contacts_store._MIGRATIONS, newest + 1: [sql]})
    assert owned_rows(tmp_path) == before
    assert Database.pending(tmp_path / "contacts.sqlite", {**contacts_store._MIGRATIONS, newest + 1: []}) == (
        newest, newest + 1)
