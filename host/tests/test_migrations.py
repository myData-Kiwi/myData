"""The migration runner (sources/_db.py): foreign keys are off while migrations run, so rebuilding a
parent table never cascades into its children, and the checks afterwards roll back a migration that
leaves the file broken."""

import sqlite3

import pytest

from mydata.sources._db import Database, MigrationError, check
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


def test_rebuilding_the_address_books_keeps_the_contacts_and_their_search_index(tmp_path):
    """The real contacts schema: a future migration that rebuilds address_books (the parent) keeps every
    contact, and searching still finds them."""
    from test_contacts_store import ALL, BOOK, item, result

    path = tmp_path / "contacts.sqlite"
    ContactsStore(path).apply("acc-1", BOOK, result([item(n) for n in ALL], full=True))
    with sqlite3.connect(path) as c:
        before = c.execute("SELECT COUNT(*) FROM contacts").fetchone()[0]
    create = ContactsStore.MIGRATIONS[1][0].replace("CREATE TABLE address_books", "CREATE TABLE address_books_new")
    rebuild = [create, "INSERT INTO address_books_new SELECT * FROM address_books", "DROP TABLE address_books",
               "ALTER TABLE address_books_new RENAME TO address_books"]
    Database(path, {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: rebuild})
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
