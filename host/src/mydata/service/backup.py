"""Snapshots of the host's databases, the restore drill, and restoring.

A snapshot is a consistent copy of every *.sqlite in the host folder (sqlite3's online backup, so the
host keeps running), in <home>/backups/<UTC time, e.g. 20261013T101500Z>/, with manifest.json: per file
its sha256, size, schema version and row counts, plus the host version and why it was taken. Each copy
must pass integrity_check, or there is no snapshot (other findings are recorded as warnings). A
snapshot is built in a hidden folder and renamed into place when complete, so a crash never leaves one
that looks whole. Folders are 0700 and files 0600, like the rest of the host folder.

When snapshots are taken:
  - every hour while the host runs (BackupService), skipped when no database file changed since the last
    snapshot (their size and modification times are compared, so nothing is opened);
  - always before a migration: open_store() takes one before it opens a store whose file is at an older
    schema version, and refuses to open it (the error shows in /status's last_error) if that fails;
  - before a restore, and on `mydata backup now`.

Retention (retention(), pure): the newest snapshot of each of the 24 most recent hours, 30 most recent days
and 12 most recent months that have one (UTC), and every snapshot not taken by the hourly timer for at
least 90 days.

The restore drill (verify()) copies a snapshot into a temporary folder inside backups/, opens each
database with this code (running its migrations there), runs the checks, compares row counts with the
manifest, and records the result in backups/last_verify.json. restore() needs the host stopped: it holds
the host's pid lock while it works, so no host can start meanwhile, takes a snapshot of the current state,
then puts the snapshot's files back.

Nothing here logs or reports row contents: messages name files, tables and counts only.
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import secrets
import shutil
import sqlite3
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Iterable

from .. import __version__
from ..sources._db import Database, check, fts_tables
from .config import private_dir, private_file
from .logs import log

logger = logging.getLogger("mydata.backup")

BACKUPS = "backups"
MANIFEST = "manifest.json"
LAST_VERIFY = "last_verify.json"
FORMAT = 1
HOURLY, DAILY, MONTHLY = 24, 30, 12
KEEP_OTHER = timedelta(days=90)  # snapshots taken before a migration or restore, or by hand
INTERVAL = 60 * 60.0

_NAME = re.compile(r"^(\d{8}T\d{6}Z)(?:-(\d+))?$")
_STAMP = "%Y%m%dT%H%M%SZ"
_SHADOW = ("_data", "_idx", "_content", "_docsize", "_config")  # FTS5's own tables
_take_lock = threading.Lock()


class BackupError(Exception):
    """A snapshot, drill or restore could not be done. The message is for the user and holds no data."""


class MigrationRefused(BackupError):
    """A store needs migrating, and the snapshot before it failed: the store is not opened."""


def _stores() -> dict[str, type]:
    """The stores this code knows, by file name: the drill opens these with their own class (migrating)."""
    from ..sources.calendar_store import CalendarStore
    from ..sources.contacts_store import ContactsStore
    return {"contacts.sqlite": ContactsStore, "calendar.sqlite": CalendarStore}


def backups_dir(home: Path) -> Path:
    return Path(home) / BACKUPS


def database_files(home: Path) -> list[Path]:
    """Every database in the host folder (its top level: snapshots are never copied again)."""
    return sorted(p for p in Path(home).glob("*.sqlite") if p.is_file())


def _utc(now: datetime | None = None) -> datetime:
    return (now or datetime.now(timezone.utc)).astimezone(timezone.utc).replace(microsecond=0)


def _iso(at: datetime) -> str:
    return at.isoformat(timespec="seconds")


def parse_name(name: str) -> datetime | None:
    """The time a snapshot folder's name says it was taken (UTC), or None for any other name."""
    m = _NAME.match(name)
    if not m:
        return None
    return datetime.strptime(m.group(1), _STAMP).replace(tzinfo=timezone.utc)


def _fingerprint(path: Path) -> list:
    """What changes when a database is written to: size and modification time of the file and its WAL."""
    out = []
    for p in (path, path.with_name(path.name + "-wal")):
        try:
            st = p.stat()
            out += [st.st_mtime_ns, st.st_size]
        except FileNotFoundError:
            out += [None, None]
    return out


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def table_counts(db: sqlite3.Connection) -> dict[str, int]:
    """Row counts of the main tables: not SQLite's own, not schema_version, not search indexes."""
    fts = fts_tables(db)
    shadow = {f + s for f in fts for s in _SHADOW}
    names = [r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
                                      "AND sql NOT LIKE 'CREATE VIRTUAL TABLE%' ORDER BY name")]
    return {n: db.execute(f'SELECT COUNT(*) FROM "{n}"').fetchone()[0]
            for n in names if n != "schema_version" and n not in shadow}


def _write_json(path: Path, data: dict) -> None:
    """Atomically, readable only by the user."""
    tmp = path.with_name(f".{path.name}.{secrets.token_hex(4)}")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, indent=2)
            fh.write("\n")
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


# ---------------------------------------------------------------- snapshots


@dataclass
class Snapshot:
    name: str
    path: Path
    created_at: datetime

    @property
    def manifest(self) -> dict:
        return json.loads((self.path / MANIFEST).read_text())


def list_snapshots(home: Path) -> list[Snapshot]:
    """Complete snapshots (those with a manifest), newest first. Only names are read, so this is cheap."""
    root = backups_dir(home)
    try:
        names = os.listdir(root)
    except FileNotFoundError:
        return []
    out = []
    for name in names:
        at = parse_name(name)
        if at is not None and (root / name / MANIFEST).is_file():
            out.append(Snapshot(name, root / name, at))
    out.sort(key=lambda s: (s.created_at, _suffix(s.name)), reverse=True)
    return out


def _suffix(name: str) -> int:
    m = _NAME.match(name)
    return int(m.group(2)) if m and m.group(2) else 1


def find_snapshot(home: Path, name: str | None) -> Snapshot:
    """A snapshot by name, or the newest one when name is None."""
    snaps = list_snapshots(home)
    if not snaps:
        raise BackupError("there are no snapshots yet (mydata backup now takes one)")
    if name is None:
        return snaps[0]
    for s in snaps:
        if s.name == name:
            return s
    raise BackupError(f"no snapshot named {name!r} (mydata backup list shows them)")


def _copy_database(src: Path, dst: Path) -> None:
    """A consistent copy of a live database (WAL included), as one self-contained file."""
    fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.close(fd)
    source = sqlite3.connect(src, timeout=30, isolation_level=None)
    try:
        source.execute("PRAGMA busy_timeout=30000")
        copy = sqlite3.connect(dst, isolation_level=None)
        try:
            source.backup(copy)
            copy.execute("PRAGMA journal_mode=DELETE")  # no -wal or -shm beside the copy
        finally:
            copy.close()
    finally:
        source.close()


def _describe(path: Path) -> dict:
    """Check a copy and say what it holds. Raises BackupError if integrity_check fails. Other findings
    (a foreign key without its row, a search index out of step) are the live file's, copied faithfully:
    they are recorded as warnings, and the restore drill reports them."""
    db = sqlite3.connect(path, isolation_level=None)
    try:
        result = [r[0] for r in db.execute("PRAGMA integrity_check")]
        if result != ["ok"]:
            raise BackupError(f"the copy of {path.name} failed integrity_check: " + "; ".join(result[:5]))
        info = {"file": path.name, "schema_version": Database.version(db), "row_counts": table_counts(db)}
        warnings = check(db)
        if warnings:
            info["warnings"] = warnings
    except sqlite3.DatabaseError as e:
        raise BackupError(f"the copy of {path.name} cannot be read ({e})") from None
    finally:
        db.close()
    return {**info, "sha256": _sha256(path), "size": path.stat().st_size}


def take_snapshot(home: Path, reason: str, *, only_if_changed: bool = False,
                  now: datetime | None = None) -> Snapshot | None:
    """Copy every database in the host folder into a new snapshot. None when there is nothing to copy, or
    (only_if_changed) when no database changed since the newest snapshot. Raises BackupError on failure,
    leaving nothing behind."""
    home = Path(home)
    with _take_lock:
        files = database_files(home)
        if not files:
            return None
        sources = {p.name: _fingerprint(p) for p in files}  # before copying: a write meanwhile shows next time
        if only_if_changed:
            snaps = list_snapshots(home)
            try:
                if snaps and snaps[0].manifest.get("sources") == sources:
                    return None
            except (OSError, ValueError):
                pass
        at = _utc(now)
        root = private_dir(backups_dir(home))
        work = private_dir(root / f".partial-{at.strftime(_STAMP)}-{secrets.token_hex(4)}")
        try:
            entries = []
            for src in files:
                dst = work / src.name
                try:
                    _copy_database(src, dst)
                except sqlite3.Error as e:
                    raise BackupError(f"{src.name} could not be copied ({type(e).__name__}: {e})") from None
                entries.append(_describe(dst))
            manifest = {"format": FORMAT, "created_at": _iso(at), "reason": reason, "host_version": __version__,
                        "files": entries, "sources": sources}
            _write_json(work / MANIFEST, manifest)
            final = _place(work, root, at)
        except BaseException:
            shutil.rmtree(work, ignore_errors=True)
            raise
    log(logger, logging.INFO, "snapshot taken", snapshot=final.name, reason=reason, files=len(entries))
    return Snapshot(final.name, final, at)


def _place(work: Path, root: Path, at: datetime) -> Path:
    """Rename the finished folder to its name; a second snapshot in the same second gets -2, -3, ..."""
    base = at.strftime(_STAMP)
    for n in range(1, 100):
        final = root / (base if n == 1 else f"{base}-{n}")
        if final.exists():
            continue
        try:
            os.rename(work, final)
            return final
        except OSError:
            if not final.exists():
                raise
    raise BackupError("too many snapshots in one second")


def retention(snapshots: Iterable[tuple[str, datetime, str]], now: datetime, *, hourly: int = HOURLY,
              daily: int = DAILY, monthly: int = MONTHLY, keep_other: timedelta = KEEP_OTHER) -> set[str]:
    """Which snapshots to keep, given (name, taken at, reason) for each: the newest in each of the `hourly`
    most recent hours that have one, the `daily` most recent days and the `monthly` most recent months
    (UTC), plus every snapshot not taken by the hourly timer that is younger than `keep_other`."""
    items = sorted(snapshots, key=lambda s: (s[1], _suffix(s[0])), reverse=True)
    keep: set[str] = set()
    for count, bucket in ((hourly, "%Y-%m-%dT%H"), (daily, "%Y-%m-%d"), (monthly, "%Y-%m")):
        seen: set[str] = set()
        for name, at, _reason in items:
            key = at.astimezone(timezone.utc).strftime(bucket)
            if key in seen:
                continue
            if len(seen) >= count:
                break
            seen.add(key)
            keep.add(name)
    keep |= {name for name, at, reason in items if reason != "hourly" and now - at < keep_other}
    return keep


def prune(home: Path, now: datetime | None = None) -> list[str]:
    """Delete the snapshots retention() does not keep, and leftovers of interrupted work older than an
    hour. Returns the names deleted."""
    now = _utc(now)
    snaps = list_snapshots(home)
    described = []
    for s in snaps:
        try:
            reason = s.manifest.get("reason", "hourly")
        except (OSError, ValueError):
            reason = "hourly"
        described.append((s.name, s.created_at, reason))
    keep = retention(described, now)
    removed = []
    for s in snaps:
        if s.name not in keep:
            shutil.rmtree(s.path, ignore_errors=True)
            removed.append(s.name)
    root = backups_dir(home)
    for leftover in root.glob(".partial-*") if root.exists() else ():
        if leftover.is_dir() and time.time() - leftover.stat().st_mtime > 3600:
            shutil.rmtree(leftover, ignore_errors=True)
    if removed:
        log(logger, logging.INFO, "old snapshots removed", count=len(removed))
    return removed


# ---------------------------------------------------------------- before a migration


def open_store(cls, home: Path, filename: str):
    """Open a store (ContactsStore, CalendarStore) from the host folder. When its file holds data at an
    older schema version, so opening it migrates it, take a snapshot first; if that fails, refuse
    (MigrationRefused, logged as an error, so /status shows it) rather than migrate unprotected."""
    path = Path(home) / filename
    pending = Database.pending(path, cls.MIGRATIONS)
    if pending is not None:
        current, target = pending
        try:
            snap = take_snapshot(home, "pre-migration")
            if snap is None:
                raise BackupError(f"{filename} was not found to copy")
        except Exception as e:
            reason = str(e) if isinstance(e, BackupError) else type(e).__name__
            message = (f"{filename} needs updating from schema version {current} to {target}, but the snapshot "
                       f"before it failed ({reason}). It was not updated and cannot be opened until a snapshot "
                       f"succeeds.")
            log(logger, logging.ERROR, message, file=filename)
            raise MigrationRefused(message) from None
        log(logger, logging.INFO, "snapshot taken before a migration", file=filename, snapshot=snap.name,
            from_version=current, to_version=target)
    return cls(path)


# ---------------------------------------------------------------- the restore drill


def _check_files(snap: Snapshot, manifest: dict) -> list[str]:
    problems = []
    for entry in manifest.get("files", []):
        path = snap.path / entry["file"]
        if not path.is_file():
            problems.append(f"{entry['file']} is missing from the snapshot")
        elif _sha256(path) != entry.get("sha256"):
            problems.append(f"{entry['file']} has changed since the snapshot was taken (sha256)")
    return problems


def _drill(snap: Snapshot, manifest: dict, work: Path) -> list[str]:
    problems = _check_files(snap, manifest)
    if problems:
        return problems
    stores = _stores()
    for entry in manifest.get("files", []):
        name = entry["file"]
        copy = work / name
        shutil.copyfile(snap.path / name, copy)
        private_file(copy)
        try:
            if name in stores:
                stores[name](copy)  # this code's migrations, as the host would run them
            db = sqlite3.connect(copy, isolation_level=None)
            try:
                problems += [f"{name}: {p}" for p in check(db)]
                counts = table_counts(db)
            finally:
                db.close()
        except Exception as e:
            problems.append(f"{name} could not be opened with this host ({type(e).__name__}: {e})")
            continue
        for table, n in sorted(entry.get("row_counts", {}).items()):
            if table not in counts:
                problems.append(f"{name}: table {table} is missing after opening it")
            elif counts[table] != n:
                problems.append(f"{name}: {table} has {counts[table]} rows, the manifest says {n}")
    return problems


def verify(home: Path, name: str | None = None, *, now: datetime | None = None) -> dict:
    """Restore a snapshot (the newest by default) into a temporary folder and check it as the host would
    open it. Records {at, snapshot, ok, problems} in backups/last_verify.json and returns it."""
    snap = find_snapshot(home, name)
    root = private_dir(backups_dir(home))
    work = private_dir(root / f".verify-{secrets.token_hex(4)}")
    try:
        try:
            manifest = snap.manifest
        except (OSError, ValueError):
            problems = ["the manifest cannot be read"]
        else:
            problems = _drill(snap, manifest, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    result = {"at": _iso(_utc(now)), "snapshot": snap.name, "ok": not problems, "problems": problems}
    _write_json(root / LAST_VERIFY, result)
    log(logger, logging.INFO if result["ok"] else logging.WARNING, "restore drill", snapshot=snap.name,
        ok=result["ok"], problems=len(problems))
    return result


def last_verify(home: Path) -> dict | None:
    try:
        data = json.loads((backups_dir(home) / LAST_VERIFY).read_text())
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


# ---------------------------------------------------------------- restore


class HostRunning(BackupError):
    pass


def restore(home: Path, name: str, *, now: datetime | None = None) -> dict:
    """Put a snapshot's databases back in the host folder. The host must be stopped: its pid lock is held
    throughout, so it cannot start meanwhile (HostRunning if it is running). The current state is
    snapshotted first. Databases that are not in the snapshot are left as they are.
    Returns {snapshot, before (the snapshot of the current state, or None), restored, untouched}."""
    from .config import Settings
    from .daemon import acquire_pid_lock

    home = Path(home)
    snap = find_snapshot(home, name)
    settings = Settings(home=home)
    fd = acquire_pid_lock(settings)
    if fd is None:
        raise HostRunning("the host is running; stop it first (mydata stop, or Quit in the myData app)")
    try:
        manifest = snap.manifest
        problems = _check_files(snap, manifest)
        if problems:
            raise BackupError("the snapshot is damaged: " + "; ".join(problems))
        before = take_snapshot(home, "pre-restore", now=now)
        restored = []
        for entry in manifest["files"]:
            target = home / entry["file"]
            tmp = home / f".{entry['file']}.restoring"
            shutil.copyfile(snap.path / entry["file"], tmp)
            private_file(tmp)
            with open(tmp, "rb") as fh:
                os.fsync(fh.fileno())
            # A WAL or journal left beside the old file would be applied to the restored one.
            for suffix in ("-wal", "-shm", "-journal"):
                target.with_name(target.name + suffix).unlink(missing_ok=True)
            os.replace(tmp, target)
            restored.append(entry["file"])
        untouched = [p.name for p in database_files(home) if p.name not in restored]
    finally:
        settings.pid_path.unlink(missing_ok=True)
        os.close(fd)
    log(logger, logging.WARNING, "snapshot restored", snapshot=snap.name, before=before.name if before else None,
        files=len(restored))
    return {"snapshot": snap.name, "before": before.name if before else None, "restored": restored,
            "untouched": untouched}


# ---------------------------------------------------------------- status


_filevault: str | None = None
_filevault_lock = threading.Lock()


def filevault(platform: str = sys.platform, run: Callable = subprocess.run) -> str:
    """"on", "off" or "unknown": whether the disk is encrypted (macOS FileVault). Asked once per process with
    `fdesetup isactive`, which needs no administrator and never shows a prompt; unknown elsewhere."""
    global _filevault
    if platform != "darwin":
        return "unknown"
    with _filevault_lock:
        if _filevault is None:
            try:
                out = run(["/usr/bin/fdesetup", "isactive"], capture_output=True, text=True, timeout=5,
                          stdin=subprocess.DEVNULL).stdout.strip()
                _filevault = {"true": "on", "false": "off"}.get(out, "unknown")
            except (OSError, subprocess.SubprocessError):
                _filevault = "unknown"
        return _filevault


def status(home: Path, *, error: str | None = None, platform: str = sys.platform) -> dict:
    """For /status: the newest snapshot, the last restore drill, FileVault, and the last snapshot error."""
    snaps = list_snapshots(home)
    verified = last_verify(home) or {}
    ok = verified.get("ok")
    return {"last_snapshot_at": _iso(snaps[0].created_at) if snaps else None,
            "last_verified_at": verified.get("at") if isinstance(verified.get("at"), str) else None,
            "last_verify_ok": ok if isinstance(ok, bool) else None,
            "filevault": filevault(platform), "error": error}


class BackupService:
    """The hourly snapshot while the host runs: at start, then every `interval` seconds; skipped when no
    database changed. A failure is logged as an error (so /status shows it) and tried again next time."""

    def __init__(self, home: Path, *, interval: float = INTERVAL, platform: str = sys.platform):
        self.home = Path(home)
        self.interval = interval
        self.platform = platform
        self.error: str | None = None
        self._stopping = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self, now: datetime | None = None) -> Snapshot | None:
        try:
            snap = take_snapshot(self.home, "hourly", only_if_changed=True, now=now)
            prune(self.home, now)
        except Exception as e:
            reason = str(e) if isinstance(e, BackupError) else type(e).__name__
            self.error = f"The hourly snapshot failed ({reason}). The host will try again."
            log(logger, logging.ERROR, self.error)
            return None
        self.error = None
        return snap

    def status(self) -> dict:
        return status(self.home, error=self.error, platform=self.platform)

    def start(self) -> None:
        if self._thread is None:
            self._thread = threading.Thread(target=self._loop, name="mydata-backup", daemon=True)
            self._thread.start()

    def stop(self, timeout: float = 30) -> None:
        self._stopping.set()
        if self._thread is not None:
            self._thread.join(timeout)
            self._thread = None

    def _loop(self) -> None:
        while not self._stopping.is_set():
            self.run_once()
            self._stopping.wait(self.interval)
