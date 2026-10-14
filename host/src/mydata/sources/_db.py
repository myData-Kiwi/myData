"""Shared SQLite plumbing for the mirror stores: one file per service, WAL, foreign keys on,
a schema_version table and numbered migrations, files readable only by the user.

Migrations run on a connection of their own with foreign keys off, set before BEGIN (inside a
transaction the pragma does nothing). With them on, rebuilding a parent table (create, copy, drop,
rename) deletes every child row through ON DELETE CASCADE. Afterwards no table that still exists may
hold fewer rows than before (unless the migration declares it may: `may_shrink`), and foreign_key_check
and integrity_check must pass, or the whole migration is rolled back. A search index that does not match
its table is rebuilt, but only when no table lost rows: a lossy rebuild must not be hidden by repairing
the index that would show it. Every other connection (connect()) has foreign keys on.

Callers that hold data take a snapshot first (service/backup.py, open_store); pending() says whether a
file has a migration to run."""

from __future__ import annotations

import os
import sqlite3
import sys
import uuid
from collections.abc import Iterable, Iterator, Mapping, Sequence
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

# A migration is a list of SQL statements, applied in one transaction. Never edit a released one:
# add the next number.
Migrations = dict[int, Sequence[str]]

_SHADOW = ("_data", "_idx", "_content", "_docsize", "_config")  # FTS5's own tables


class MigrationError(RuntimeError):
    """A migration left the file broken (rows lost, a foreign key without its row, a failed integrity
    check); it was rolled back."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def new_id() -> str:
    """A device-generated record ID."""
    return str(uuid.uuid4())


class Database:
    def __init__(self, path: Path, migrations: Migrations, *, may_shrink: Mapping[int, Iterable[str]] | None = None):
        """may_shrink: {version: tables} a migration is meant to remove rows from (deduplicating, say); every
        other table must keep at least its row count."""
        self.path = Path(path)
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not self.path.exists():
            # Create the file readable only by the user before SQLite opens it; SQLite gives the
            # -wal and -shm files the same permissions as the database.
            fd = os.open(self.path, os.O_CREAT | os.O_WRONLY, 0o600)
            os.close(fd)
        if not sys.platform.startswith("win"):
            os.chmod(self.path, 0o600)
        self._migrate(migrations, may_shrink or {})

    @contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        """A connection for one unit of work: committed on success, rolled back on error, then closed."""
        db = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        db.row_factory = sqlite3.Row
        try:
            db.execute("PRAGMA foreign_keys=ON")
            # Deleted rows are overwritten, so removing an account leaves no readable remains in the file.
            db.execute("PRAGMA secure_delete=ON")
            db.execute("PRAGMA busy_timeout=30000")
            yield db
        finally:
            db.close()

    @contextmanager
    def transaction(self) -> Iterator[sqlite3.Connection]:
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            try:
                yield db
            except BaseException:
                db.execute("ROLLBACK")
                raise
            db.execute("COMMIT")

    @staticmethod
    def version(db: sqlite3.Connection) -> int:
        """The schema version of an open database (0 for a new file)."""
        if db.execute("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'schema_version'").fetchone() is None:
            return 0
        return db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] or 0

    @classmethod
    def pending(cls, path: Path, migrations: Migrations) -> tuple[int, int] | None:
        """(current, target) when the file at `path` holds data at an older schema version, so opening it
        would migrate it; None when it is missing, new (version 0) or up to date. Never creates the file."""
        path = Path(path)
        if not path.exists():
            return None
        db = sqlite3.connect(path, timeout=30, isolation_level=None)
        try:
            db.execute("PRAGMA busy_timeout=30000")
            current = cls.version(db)
        finally:
            db.close()
        target = max(migrations)
        return (current, target) if 0 < current < target else None

    def _migrate(self, migrations: Migrations, may_shrink: Mapping[int, Iterable[str]]) -> None:
        db = sqlite3.connect(self.path, timeout=30, isolation_level=None)
        try:
            db.execute("PRAGMA busy_timeout=30000")
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("PRAGMA foreign_keys=OFF")  # before BEGIN: it is ignored inside a transaction
            db.execute("BEGIN IMMEDIATE")
            try:
                db.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")
                current = self.version(db)
                newest = max(migrations)
                if current > newest:
                    raise RuntimeError(
                        f"database schema version {current} is newer than this host understands ({newest})"
                    )
                todo = sorted(v for v in migrations if v > current)
                before = table_counts(db) if todo else {}
                for version in todo:
                    for statement in migrations[version]:
                        db.execute(statement)
                    db.execute("INSERT INTO schema_version (version) VALUES (?)", (version,))
                if todo:
                    allowed = {t for v in todo for t in may_shrink.get(v, ())}
                    after = table_counts(db)
                    problems = [f"{t} has {after[t]} rows, it had {n} before" for t, n in sorted(before.items())
                                if t in after and after[t] < n and t not in allowed]
                    problems += check(db, repair_fts=not problems)
                    if problems:
                        raise MigrationError(f"migrating {self.path.name} to version {newest} was rolled back: "
                                             + "; ".join(problems))
            except BaseException:
                db.execute("ROLLBACK")
                raise
            db.execute("COMMIT")
            db.execute("PRAGMA foreign_keys=ON")
        finally:
            db.close()

    def checkpoint(self) -> None:
        """Fold the WAL back into the file and truncate it (used after hard deletes)."""
        with self.connect() as db:
            db.execute("PRAGMA wal_checkpoint(TRUNCATE)")


def fts_tables(db: sqlite3.Connection) -> list[str]:
    """The FTS5 tables in an open database."""
    return [r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND sql LIKE 'CREATE VIRTUAL TABLE%USING fts5%'")]


def table_counts(db: sqlite3.Connection) -> dict[str, int]:
    """Row counts of the main tables: not SQLite's own, not schema_version, not search indexes."""
    fts = fts_tables(db)
    shadow = {f + s for f in fts for s in _SHADOW}
    names = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
                                      "AND sql NOT LIKE 'CREATE VIRTUAL TABLE%' ORDER BY name")]
    return {n: db.execute(f'SELECT COUNT(*) FROM "{n}"').fetchone()[0]
            for n in names if n != "schema_version" and n not in shadow}


def check(db: sqlite3.Connection, *, repair_fts: bool = False) -> list[str]:
    """What is wrong with an open database: foreign keys without their row, integrity_check, and each FTS5
    table's integrity-check against its content table. Empty when all is well. With repair_fts, a search
    index that does not match its table is rebuilt from it (it holds nothing else) and checked again.
    Messages name tables and counts, never row contents."""
    problems = []
    broken: dict[str, int] = {}
    try:
        for row in db.execute("PRAGMA foreign_key_check"):
            broken[row[0]] = broken.get(row[0], 0) + 1
    except sqlite3.OperationalError as e:  # e.g. a parent key that is no longer unique ("foreign key mismatch")
        problems.append(f"foreign key definitions are broken ({e})")
    problems += [f"{n} row(s) of {table} point to a missing row (foreign key)" for table, n in sorted(broken.items())]
    result = [r[0] for r in db.execute("PRAGMA integrity_check")]
    if result != ["ok"]:
        problems.append("integrity_check: " + "; ".join(result[:5]))
    for table in fts_tables(db):
        if not _fts_ok(db, table) and not (repair_fts and _fts_rebuilt(db, table)):
            problems.append(f"the search index {table} does not match its table")
    return problems


def _fts_ok(db: sqlite3.Connection, table: str) -> bool:
    try:  # rank 1: also compare the index with an external content table
        db.execute(f'INSERT INTO "{table}" ("{table}", rank) VALUES (\'integrity-check\', 1)')
        return True
    except sqlite3.DatabaseError:
        return False


def _fts_rebuilt(db: sqlite3.Connection, table: str) -> bool:
    db.execute(f'INSERT INTO "{table}" ("{table}") VALUES (\'rebuild\')')
    return _fts_ok(db, table)
