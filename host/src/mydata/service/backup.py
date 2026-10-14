"""Snapshots of the host's databases, the restore drill, and restoring.

A snapshot is a consistent copy of every *.sqlite in the host folder (sqlite3's online backup, so the
host keeps running), in <home>/backups/<UTC time, e.g. 20261013T101500Z>/, with manifest.json: per file
its sha256, size, schema version and row counts, plus the host version and why it was taken. Each copy
must pass integrity_check (other findings are recorded as warnings). Files are copied one by one: one
that cannot be copied is listed as failed and the others are still kept, so one damaged database never
stops the others being backed up. A snapshot is built in a hidden folder and renamed into place when
complete, so a crash never leaves one that looks whole. Folders are 0700 and files 0600, like the rest
of the host folder.

When snapshots are taken:
  - every hour while the host runs (BackupService), skipped when no database file changed since the last
    snapshot (their size and modification times are compared, so nothing is opened);
  - always before a migration: open_store() takes one before it opens a store whose file is at an older
    schema version, and refuses to open it (the error shows in /status's last_error) if that file could
    not be copied;
  - before a restore, and on `mydata backup now`.

Retention (retention(), pure): the newest snapshot of each of the 24 most recent hours, 30 most recent days
and 12 most recent months that have one (UTC), and every snapshot not taken by the hourly timer for at
least 90 days, except that of those taken before a migration only the newest 3 per migration are.

The restore drill (verify()) copies a snapshot into a temporary folder inside backups/, opens each
database with this code (running its migrations there), runs the checks, compares row counts with the
manifest, and records the result in backups/last_verify.json. restore() needs the host stopped: it holds
the host's pid lock while it works, so no host can start meanwhile, takes a snapshot of the current state
(a database too damaged to copy is kept in it byte for byte, so damage never blocks a restore), then puts
the snapshot's files back.

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
import signal
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
from ..sources._db import Database, MigrationError, check, table_counts
from .config import private_dir, private_file
from .logs import log

logger = logging.getLogger("mydata.backup")

BACKUPS = "backups"
MANIFEST = "manifest.json"
DAMAGED = "damaged"  # in a snapshot taken before a restore: files SQLite could not copy, kept byte for byte
LAST_VERIFY = "last_verify.json"
FORMAT = 1
HOURLY, DAILY, MONTHLY = 24, 30, 12
KEEP_OTHER = timedelta(days=90)  # snapshots taken before a migration or restore, or by hand
PER_MIGRATION = 3  # of those taken before a migration, at most this many per file and version
REUSE_FOR = timedelta(days=30)  # a snapshot before a migration is used again for a retry while this young
INTERVAL = 60 * 60.0

_NAME = re.compile(r"^(\d{8}T\d{6}Z)(?:-(\d+))?$")
_STAMP = "%Y%m%dT%H%M%SZ"
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


def take_snapshot(home: Path, reason: str, *, only_if_changed: bool = False, now: datetime | None = None,
                  require: Iterable[str] = (), keep_damaged: bool = False,
                  extra: dict | None = None) -> Snapshot | None:
    """Copy every database in the host folder into a new snapshot. None when there is nothing to copy, or
    (only_if_changed) when no database changed since the newest snapshot.

    Each file is copied on its own: one that cannot be (unreadable, or its copy fails integrity_check) is
    listed under the manifest's "failed" ({file, reason}) and the others are still copied. With
    keep_damaged (before a restore, which must not be blocked by the damage it is there to repair), such a
    file is kept as it is, with its -wal, -shm and -journal, in the snapshot's damaged/ folder ("kept").
    Raises BackupError, leaving nothing behind, when a file named in `require` failed, when nothing at all
    was kept, or on any other failure. `extra` is added to the manifest."""
    home = Path(home)
    required = set(require)
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
            entries, failed = [], []
            for src in files:
                dst = work / src.name
                # Before SQLite opens it: closing a connection can fold the WAL into a damaged file, or drop it.
                kept = _keep_as_is(src, private_dir(work / DAMAGED)) if keep_damaged else None
                try:
                    try:
                        _copy_database(src, dst)
                    except sqlite3.Error as e:
                        raise BackupError(f"{src.name} could not be copied ({type(e).__name__}: {e})") from None
                    entries.append(_describe(dst))
                except BackupError as e:
                    dst.unlink(missing_ok=True)
                    if src.name in required:
                        raise
                    failed.append({"file": src.name, "reason": str(e), **({"kept": kept} if kept else {})})
                    log(logger, logging.ERROR, "a database could not be snapshotted", file=src.name, error=str(e))
                else:
                    for k in kept or ():
                        (work / k["file"]).unlink()
            if not entries and not any(f.get("kept") for f in failed):
                raise BackupError("; ".join(f["reason"] for f in failed))
            manifest = {"format": FORMAT, "created_at": _iso(at), "reason": reason, "host_version": __version__,
                        "files": entries, "sources": sources, **(extra or {})}
            if failed:
                manifest["failed"] = failed
            if (work / DAMAGED).exists() and not any((work / DAMAGED).iterdir()):
                (work / DAMAGED).rmdir()
            _write_json(work / MANIFEST, manifest)
            final = _place(work, root, at)
        except BaseException:
            shutil.rmtree(work, ignore_errors=True)
            raise
    log(logger, logging.INFO, "snapshot taken", snapshot=final.name, reason=reason, files=len(entries),
        failed=len(failed))
    return Snapshot(final.name, final, at)


def _keep_as_is(src: Path, folder: Path) -> list[dict]:
    """Byte copies of a database SQLite cannot copy, with the files beside it, for a person to look at."""
    kept = []
    for p in (src, *(src.with_name(src.name + s) for s in ("-wal", "-shm", "-journal"))):
        if not p.exists():
            continue
        dst = folder / p.name
        try:
            fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.close(fd)
            shutil.copyfile(p, dst)
        except OSError as e:
            raise BackupError(f"{p.name} could not be kept as it is ({type(e).__name__})") from None
        kept.append({"file": f"{DAMAGED}/{p.name}", "sha256": _sha256(dst), "size": dst.stat().st_size})
    return kept


def failures(snap: Snapshot) -> list[dict]:
    """The files a snapshot could not copy ({file, reason, kept?}); empty when it holds them all."""
    try:
        failed = snap.manifest.get("failed", [])
    except (OSError, ValueError):
        return []
    return failed if isinstance(failed, list) else []


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


def retention(snapshots: Iterable[tuple], now: datetime, *, hourly: int = HOURLY, daily: int = DAILY,
              monthly: int = MONTHLY, keep_other: timedelta = KEEP_OTHER,
              per_migration: int = PER_MIGRATION) -> set[str]:
    """Which snapshots to keep, given (name, taken at, reason[, migration]) for each: the newest in each of
    the `hourly` most recent hours that have one, the `daily` most recent days and the `monthly` most recent
    months (UTC), plus every snapshot not taken by the hourly timer that is younger than `keep_other`; of
    those taken before a migration, only the newest `per_migration` for each migration (its file and
    versions), so a migration that keeps failing cannot fill the disk."""
    items = [(s[0], s[1], s[2], s[3] if len(s) > 3 else None) for s in snapshots]
    items.sort(key=lambda s: (s[1], _suffix(s[0])), reverse=True)
    keep: set[str] = set()
    for count, bucket in ((hourly, "%Y-%m-%dT%H"), (daily, "%Y-%m-%d"), (monthly, "%Y-%m")):
        seen: set[str] = set()
        for name, at, _reason, _migration in items:
            key = at.astimezone(timezone.utc).strftime(bucket)
            if key in seen:
                continue
            if len(seen) >= count:
                break
            seen.add(key)
            keep.add(name)
    per: dict = {}
    for name, at, reason, migration in items:
        if reason == "hourly" or now - at >= keep_other:
            continue
        if reason == "pre-migration":
            per[migration] = per.get(migration, 0) + 1
            if per[migration] > per_migration:
                continue
        keep.add(name)
    return keep


def prune(home: Path, now: datetime | None = None) -> list[str]:
    """Delete the snapshots retention() does not keep, and leftovers of interrupted work older than an
    hour. Returns the names deleted."""
    now = _utc(now)
    snaps = list_snapshots(home)
    described = []
    for s in snaps:
        try:
            m = s.manifest
            reason = m.get("reason", "hourly")
            migration = m.get("migration")
            migration = tuple(migration.get(k) for k in ("file", "from", "to")) if isinstance(migration, dict) else None
        except (OSError, ValueError, AttributeError):
            reason, migration = "hourly", None
        described.append((s.name, s.created_at, reason, migration))
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
    (MigrationRefused, logged as an error, so /status shows it) rather than migrate unprotected.

    A migration that fails is rolled back, logged as an error naming the snapshot taken before it, and
    raised as MigrationError. Trying again later takes no second snapshot while the file is unchanged and the newest snapshot
    taken before a migration, younger than REUSE_FOR, still holds it exactly."""
    path = Path(home) / filename
    pending = Database.pending(path, cls.MIGRATIONS)
    if pending is None:
        return cls(path)
    current, target = pending
    snap = _holding(home, filename, current)
    if snap is None:
        try:
            snap = take_snapshot(home, "pre-migration", require=[filename],
                                 extra={"migration": {"file": filename, "from": current, "to": target}})
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
    try:
        return cls(path)
    except Exception as e:
        message = (f"{filename} could not be updated from schema version {current} to {target} "
                   f"({type(e).__name__}: {e}). The update was rolled back and the file is as it was; snapshot "
                   f"{snap.name} holds it as it was before.")
        log(logger, logging.ERROR, message, file=filename, snapshot=snap.name)
        raise MigrationError(message) from None


def _holding(home: Path, filename: str, version: int) -> Snapshot | None:
    """The newest snapshot taken before a migration, if it holds `filename` exactly as it is now (same
    size and modification times, same schema version) and is young enough to be kept a while longer."""
    for s in list_snapshots(home):
        if _utc() - s.created_at >= REUSE_FOR:
            return None
        try:
            m = s.manifest
            if m.get("reason") != "pre-migration":
                continue
            entry = next((f for f in m.get("files", []) if f.get("file") == filename), None)
            same = (m.get("sources", {}).get(filename) == _fingerprint(Path(home) / filename)
                    and entry is not None and entry.get("schema_version") == version)
        except (OSError, ValueError, AttributeError):
            return None
        return s if same else None
    return None


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


RESTORING = "restoring"  # in the pid file while a restore holds the host's lock


def _ignore_signals() -> dict:
    """SIGTERM and SIGINT are ignored while a restore swaps files (main thread only: elsewhere Python
    cannot change handlers). Returns the handlers to put back."""
    if threading.current_thread() is not threading.main_thread():
        return {}
    saved = {}
    for sig in (signal.SIGTERM, signal.SIGINT):
        saved[sig] = signal.signal(sig, signal.SIG_IGN)
    return saved


def _restore_signals(saved: dict) -> None:
    for sig, handler in saved.items():
        signal.signal(sig, handler)


def remove_leftovers(home: Path) -> list[str]:
    """Delete the staged copies (.<file>.restoring) a killed restore left in the host folder. Call only
    while holding the host's lock (a restore, or the running host): then nobody is writing them."""
    removed = []
    for p in Path(home).glob(".*.restoring"):
        p.unlink(missing_ok=True)
        removed.append(p.name)
    return removed


def restore(home: Path, name: str, *, now: datetime | None = None) -> dict:
    """Put a snapshot's databases back in the host folder. The host must be stopped: its pid lock is held
    throughout, so it cannot start meanwhile (HostRunning if it is running). The current state is
    snapshotted first; a database too damaged to copy is kept in that snapshot's damaged/ folder as it was.
    Databases that are not in the snapshot are left as they are. Returns {snapshot, before (the snapshot of
    the current state, or None), restored, untouched, damaged (files kept as they were in `before`)}."""
    from .config import Settings
    from .daemon import acquire_pid_lock

    home = Path(home)
    snap = find_snapshot(home, name)
    settings = Settings(home=home)
    # The lock without this process's pid in the file: `mydata stop`, or an app replacing the host, must
    # find no host to stop, rather than kill the restore halfway.
    fd = acquire_pid_lock(settings, marker=RESTORING)
    if fd is None:
        raise HostRunning("the host is running; stop it first (mydata stop, or Quit in the myData app)")
    signals = _ignore_signals()
    try:
        remove_leftovers(home)  # under the lock: any found are from a restore that was killed
        manifest = snap.manifest
        problems = _check_files(snap, manifest)
        if problems:
            raise BackupError("the snapshot is damaged: " + "; ".join(problems))
        before = take_snapshot(home, "pre-restore", now=now, keep_damaged=True)
        # Every copy first, then the swaps: an interruption while copying leaves the databases as they were.
        staged = []
        try:
            for entry in manifest["files"]:
                tmp = home / f".{entry['file']}.restoring"
                staged.append(tmp)
                shutil.copyfile(snap.path / entry["file"], tmp)
                private_file(tmp)
                with open(tmp, "rb") as fh:
                    os.fsync(fh.fileno())
        except BaseException:
            for tmp in staged:
                tmp.unlink(missing_ok=True)
            raise
        restored = []
        for entry, tmp in zip(manifest["files"], staged):
            target = home / entry["file"]
            # A WAL or journal left beside the old file would be applied to the restored one.
            for suffix in ("-wal", "-shm", "-journal"):
                target.with_name(target.name + suffix).unlink(missing_ok=True)
            os.replace(tmp, target)
            restored.append(entry["file"])
        untouched = [p.name for p in database_files(home) if p.name not in restored]
    finally:
        _restore_signals(signals)
        settings.pid_path.unlink(missing_ok=True)
        os.close(fd)
    damaged = [f["file"] for f in failures(before)] if before else []
    log(logger, logging.WARNING, "snapshot restored", snapshot=snap.name, before=before.name if before else None,
        files=len(restored), damaged=len(damaged))
    return {"snapshot": snap.name, "before": before.name if before else None, "restored": restored,
            "untouched": untouched, "damaged": damaged}


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
            remove_leftovers(self.home)  # the host holds its lock
            snap = take_snapshot(self.home, "hourly", only_if_changed=True, now=now)
            prune(self.home, now)
            newest = snap or next(iter(list_snapshots(self.home)), None)
        except Exception as e:
            reason = str(e) if isinstance(e, BackupError) else type(e).__name__
            self.error = f"The hourly snapshot failed ({reason}). The host will try again."
            log(logger, logging.ERROR, self.error)
            return None
        failed = failures(newest) if newest is not None else []
        # A file that cannot be copied stays an error until a snapshot holds it again.
        self.error = (f"The hourly snapshot left out {', '.join(f['file'] for f in failed)} "
                      f"({'; '.join(f['reason'] for f in failed)}). The other databases were copied; the host will "
                      f"try again." if failed else None)
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
        filevault(self.platform)  # asked here once, so /status never waits for it
        while not self._stopping.is_set():
            self.run_once()
            self._stopping.wait(self.interval)
