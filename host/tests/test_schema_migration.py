"""Migrating real-shaped files: each synthetic dump of a released schema (tests/fixtures/schema/*-v<N>.sql)
is loaded into a file built by the released migrations up to N, then opened the way the host opens it
(backup.open_store: a snapshot first, then today's migrations with the runner's checks). Every field of
every row must be unchanged, and the columns a migration adds must hold what it backfilled."""

from __future__ import annotations

import hashlib
import re
import sqlite3
from pathlib import Path

import pytest

from mydata.service.backup import list_snapshots, open_store
from mydata.sources._db import Database, check
from mydata.sources.calendar_store import CalendarStore
from mydata.sources.contacts_store import ContactsStore

DUMPS = Path(__file__).parent / "fixtures" / "schema"
STORES = {"contacts": ContactsStore, "calendar": CalendarStore}
CASES = sorted((m["store"], int(m["v"])) for p in DUMPS.glob("*.sql")
               if (m := re.fullmatch(r"(?P<store>\w+)-v(?P<v>\d+)\.sql", p.name)))

# What migration 2 of contacts.sqlite reads from each card that is not a plain individual (make_dump.py).
KINDS = {"group-book-club@example.org": "group", "urn:uuid:group-choir-1": "group", "urn:uuid:org-library-1": "org"}


def test_every_store_has_a_dump_of_its_current_schema():
    """A new schema version ships with its dump (make_dump.py), so the next migration is tested on it."""
    assert {(s, max(cls.MIGRATIONS)) for s, cls in STORES.items()} <= set(CASES)


def _build(home: Path, store: str, version: int) -> Path:
    cls = STORES[store]
    path = home / f"{store}.sqlite"
    Database(path, {v: steps for v, steps in cls.MIGRATIONS.items() if v <= version})
    db = sqlite3.connect(path)
    try:
        with db:
            db.executescript((DUMPS / f"{store}-v{version}.sql").read_text())
        assert db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == version
    finally:
        db.close()
    return path


def _rows(path: Path) -> dict[str, tuple[list[str], list[tuple]]]:
    """{table: (columns, rows by rowid)} for every table but SQLite's, schema_version and search indexes."""
    db = sqlite3.connect(path)
    try:
        fts = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE sql LIKE 'CREATE VIRTUAL TABLE%'")]
        tables = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE "
                                           "'sqlite_%' AND name != 'schema_version' AND sql NOT LIKE 'CREATE VIRTUAL%'")
                  if not any(r[0].startswith(f + "_") for f in fts)]
        out = {}
        for t in tables:
            cols = [r[1] for r in db.execute(f'PRAGMA table_info("{t}")')]
            out[t] = (cols, db.execute(f'SELECT {", ".join(cols)} FROM "{t}" ORDER BY rowid').fetchall())
        return out
    finally:
        db.close()


@pytest.mark.parametrize("store, version", CASES)
def test_a_released_schema_migrates_keeping_every_field(tmp_path, store, version):
    path = _build(tmp_path, store, version)
    before = _rows(path)
    assert sum(len(rows) for _, rows in before.values()) > 10

    opened = open_store(STORES[store], tmp_path, path.name)
    target = max(STORES[store].MIGRATIONS)
    if version < target:  # the host snapshots a file before migrating it
        [snap] = list_snapshots(tmp_path)
        assert snap.manifest["migration"] == {"file": path.name, "from": version, "to": target}

    after = _rows(path)
    for table, (cols, rows) in before.items():
        new_cols, new_rows = after[table]
        assert new_cols[:len(cols)] == cols, table  # columns are only ever added, at the end
        assert [r[:len(cols)] for r in new_rows] == rows, table  # every field of every row, in order
    with opened.db.connect() as db:
        assert check(db) == []
        assert db.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0] == target  # each version once


def _added(path: Path, table: str) -> list[dict]:
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    try:
        return [dict(r) for r in db.execute(f"SELECT * FROM {table} ORDER BY rowid")]
    finally:
        db.close()


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def test_contacts_v1_gains_modes_kinds_versions_and_hashes(tmp_path):
    path = _build(tmp_path, "contacts", 1)
    store = open_store(ContactsStore, tmp_path, path.name)
    books = _added(path, "address_books")
    assert books and {b["mode"] for b in books} == {"followed"}
    cards = _added(path, "contacts")
    assert len(cards) == 16
    for c in cards:
        assert c["raw_sha256"] == _sha(c["raw_vcard"]) and c["rev"] == 1 and c["purge_after"] is None
        assert c["kind"] == KINDS.get(c["uid"], "individual"), c["uid"]
        assert c["version"] == re.search(r"^VERSION:(.*?)\r?$", c["raw_vcard"], re.M).group(1)
    assert {c["version"] for c in cards} == {"3.0", "4.0"}
    for table in ("revisions", "changes", "imports", "origins", "meta", "purge_permits"):
        assert _added(path, table) == []
    # The group cards are kept, and no longer shown or found as contacts.
    names = {c["display_name"] for c in store.list()}
    assert "Ava Fictional" in names and "Kim Invented" in names and "Example Library" in names
    assert not names & {"Book club", "Choir (example)"}
    assert store.find_by_name("Book club") == [] and store.search("choir") == []
    assert store.counts("acc-1")["contacts"] == len([c for c in cards if c["account_id"] == "acc-1"
                                                     and c["deleted_at"] is None and c["uid"] not in
                                                     ("group-book-club@example.org", "urn:uuid:group-choir-1")])


def test_calendar_v2_gains_modes_and_hashes(tmp_path):
    path = _build(tmp_path, "calendar", 2)
    store = open_store(CalendarStore, tmp_path, path.name)
    assert {c["mode"] for c in _added(path, "calendars")} == {"followed"}
    events = _added(path, "events")
    assert events and all(e["raw_sha256"] == _sha(e["raw_ics"]) and e["rev"] == 1 and e["purge_after"] is None
                          for e in events)
    assert len(_added(path, "occurrences")) == 6 and len(_added(path, "coverage")) == 1
    assert {c["name"] for c in store.calendars()} >= {"Home", "Work", "Family (shared)"}


# ---------------------------------------------------------------- mydata db check-migration


def _sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_check_migration_tries_the_migrations_on_copies_only(tmp_path):
    from mydata.service.backup import check_migration

    contacts, calendar = _build(tmp_path, "contacts", 1), _build(tmp_path, "calendar", 2)
    before = {p.name: _sha_file(p) for p in (contacts, calendar)}
    results = check_migration(tmp_path)
    assert [(r["file"], r["from"], r["to"], r["problems"]) for r in results] == [
        ("calendar.sqlite", 2, max(CalendarStore.MIGRATIONS), []),
        ("contacts.sqlite", 1, max(ContactsStore.MIGRATIONS), [])]
    assert all(r["rows"] > 10 for r in results)
    assert {p.name: _sha_file(p) for p in (contacts, calendar)} == before  # the live files only read
    assert list_snapshots(tmp_path) == [] and not list((tmp_path / "backups").glob(".check-*"))


class _Lossy(ContactsStore):
    MIGRATIONS = {**ContactsStore.MIGRATIONS,
                  max(ContactsStore.MIGRATIONS) + 1: ["UPDATE contacts SET display_name = 'x' WHERE seq = 2"]}


class _Failing(ContactsStore):
    MIGRATIONS = {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: ["DELETE FROM contacts"]}


def test_check_migration_reports_a_changed_row_and_a_rolled_back_migration(tmp_path, monkeypatch):
    import mydata.service.backup as backup

    path = _build(tmp_path, "contacts", 1)
    monkeypatch.setattr(backup, "_stores", lambda: {"contacts.sqlite": _Lossy})
    [result] = backup.check_migration(tmp_path)
    assert result["problems"] == ["contacts: some of its 16 rows changed"]
    monkeypatch.setattr(backup, "_stores", lambda: {"contacts.sqlite": _Failing})
    [result] = backup.check_migration(tmp_path)
    assert len(result["problems"]) == 1 and "MigrationError" in result["problems"][0]
    assert "contacts has 0 rows, it had 16 before" in result["problems"][0]
    assert "Ava" not in repr(result)  # counts and names of tables, never values
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == 1


def test_the_check_migration_command(tmp_path):
    import os
    import subprocess
    import sys

    _build(tmp_path, "contacts", 1)
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "db", "check-migration"],
                       env={**os.environ, "MYDATA_HOME": str(tmp_path)}, capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert r.stdout == (f"contacts.sqlite (from schema version 1 to {max(ContactsStore.MIGRATIONS)}): every one of "
                        f"its 20 rows kept, checks passed (on a copy)\n")  # 4 address books, 16 cards
