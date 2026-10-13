"""Shared SQLite plumbing for the mirror stores: one file per service, WAL, foreign keys on,
a schema_version table and numbered migrations, files readable only by the user."""

from __future__ import annotations

import os
import sqlite3
import sys
import uuid
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

# A migration is a list of SQL statements, applied in one transaction. Never edit a released one:
# add the next number.
Migrations = dict[int, Sequence[str]]


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def new_id() -> str:
    """A device-generated record ID."""
    return str(uuid.uuid4())


class Database:
    def __init__(self, path: Path, migrations: Migrations):
        self.path = Path(path)
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not self.path.exists():
            # Create the file readable only by the user before SQLite opens it; SQLite gives the
            # -wal and -shm files the same permissions as the database.
            fd = os.open(self.path, os.O_CREAT | os.O_WRONLY, 0o600)
            os.close(fd)
        if not sys.platform.startswith("win"):
            os.chmod(self.path, 0o600)
        with self.connect() as db:
            db.execute("PRAGMA journal_mode=WAL")
            self._migrate(db, migrations)

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
    def _migrate(db: sqlite3.Connection, migrations: Migrations) -> None:
        db.execute("BEGIN IMMEDIATE")
        try:
            db.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")
            row = db.execute("SELECT MAX(version) FROM schema_version").fetchone()
            current = row[0] or 0
            newest = max(migrations)
            if current > newest:
                raise RuntimeError(
                    f"database schema version {current} is newer than this host understands ({newest})"
                )
            for version in sorted(v for v in migrations if v > current):
                for statement in migrations[version]:
                    db.execute(statement)
                db.execute("INSERT INTO schema_version (version) VALUES (?)", (version,))
        except BaseException:
            db.execute("ROLLBACK")
            raise
        db.execute("COMMIT")

    def checkpoint(self) -> None:
        """Fold the WAL back into the file and truncate it (used after hard deletes)."""
        with self.connect() as db:
            db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
