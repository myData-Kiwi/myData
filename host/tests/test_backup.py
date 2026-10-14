"""Snapshots, retention, the snapshot before a migration, the restore drill and restore (service/backup.py).
Every test uses a temporary host folder with synthetic data (tests/synthetic_home.py)."""

from __future__ import annotations

import json
import logging
import os
import sqlite3
import stat
import subprocess
import time
from datetime import datetime, timedelta, timezone

import pytest

from mydata import __version__
from mydata.service import backup
from mydata.service.backup import (BackupError, BackupService, HostRunning, MigrationRefused, find_snapshot,
                                   list_snapshots, open_store, prune, restore, retention, take_snapshot, verify)
from mydata.service.config import Settings
from mydata.service.daemon import acquire_pid_lock
from mydata.service.logs import LAST_ERROR
from mydata.sources.accounts import Accounts
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.secrets import MemorySecretStore
from mydata.service.sync import SyncService
from mydata.sources._db import MigrationError

from synthetic_home import count, populate

NOW = datetime(2026, 10, 13, 12, 0, 0, tzinfo=timezone.utc)


def mode(path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


@pytest.fixture
def home(tmp_path):
    h = tmp_path / "home"
    h.mkdir(mode=0o700)
    populate(h)
    return h


# ---------------------------------------------------------------- snapshots


def test_a_snapshot_copies_every_database_with_a_manifest(home):
    snap = take_snapshot(home, "manual", now=NOW)
    assert snap.name == "20261013T120000Z"
    assert sorted(p.name for p in snap.path.iterdir()) == ["calendar.sqlite", "contacts.sqlite", "manifest.json"]
    m = snap.manifest
    assert (m["format"], m["reason"], m["host_version"], m["created_at"]) == (1, "manual", __version__,
                                                                              "2026-10-13T12:00:00+00:00")
    by_file = {f["file"]: f for f in m["files"]}
    contacts = by_file["contacts.sqlite"]
    assert contacts["schema_version"] == max(ContactsStore.MIGRATIONS)
    assert contacts["row_counts"] == {"address_books": 1, "contacts": count(home / "contacts.sqlite", "contacts"),
                                      **{t: 0 for t in ("changes", "imports", "merges", "meta", "origins", "purge_permits",
                                                        "decisions", "revisions", "shadows", "undo_log")}}
    assert by_file["calendar.sqlite"]["row_counts"]["events"] == count(home / "calendar.sqlite", "events") == 6
    for f in m["files"]:
        copy = snap.path / f["file"]
        assert f["size"] == copy.stat().st_size
        assert f["sha256"] == backup._sha256(copy)
        assert "warnings" not in f
        with sqlite3.connect(copy) as db:
            assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
            assert db.execute("PRAGMA journal_mode").fetchone()[0] == "delete"  # one self-contained file
    # private, like the rest of the host folder
    assert mode(home / "backups") == mode(snap.path) == 0o700
    assert {mode(p) for p in snap.path.iterdir()} == {0o600}
    assert not list((home / "backups").glob(".partial-*"))


def test_an_unchanged_home_is_not_snapshotted_again(home):
    assert take_snapshot(home, "hourly", only_if_changed=True, now=NOW) is not None
    assert take_snapshot(home, "hourly", only_if_changed=True, now=NOW + timedelta(hours=1)) is None
    contacts = ContactsStore(home / "contacts.sqlite")
    with contacts.db.transaction() as db:
        db.execute("UPDATE address_books SET name = 'Renamed'")
    later = take_snapshot(home, "hourly", only_if_changed=True, now=NOW + timedelta(hours=2))
    assert later is not None and later.name == "20261013T140000Z"
    assert take_snapshot(home, "hourly", only_if_changed=True, now=NOW + timedelta(hours=3)) is None
    # a snapshot taken by hand is taken anyway
    assert take_snapshot(home, "manual", now=NOW + timedelta(hours=3)) is not None


def test_nothing_to_copy_is_no_snapshot(tmp_path):
    assert take_snapshot(tmp_path, "manual") is None
    assert not (tmp_path / "backups").exists()


def test_two_snapshots_in_one_second_get_their_own_names(home):
    a = take_snapshot(home, "manual", now=NOW)
    b = take_snapshot(home, "manual", now=NOW)
    assert (a.name, b.name) == ("20261013T120000Z", "20261013T120000Z-2")
    assert [s.name for s in list_snapshots(home)] == [b.name, a.name]
    assert find_snapshot(home, None).name == b.name


def test_a_failed_snapshot_leaves_nothing_behind(home, monkeypatch):
    def broken(src, dst):
        raise sqlite3.OperationalError("disk I/O error")

    monkeypatch.setattr(backup, "_copy_database", broken)
    with pytest.raises(BackupError, match="could not be copied"):
        take_snapshot(home, "manual", now=NOW)
    assert list((home / "backups").iterdir()) == []


def test_a_copy_that_fails_integrity_check_is_no_snapshot(home, monkeypatch):
    real = backup._copy_database

    def corrupt(src, dst):
        real(src, dst)
        with open(dst, "r+b") as fh:  # break the header of every page after the first
            page = 4096
            for offset in range(page, os.path.getsize(dst), page):
                fh.seek(offset)
                fh.write(b"\x00" * 12)

    monkeypatch.setattr(backup, "_copy_database", corrupt)
    with pytest.raises(BackupError):
        take_snapshot(home, "manual", now=NOW)
    assert list_snapshots(home) == []


def _garble(path, pages=(2, 3)):
    """Overwrite whole pages of a database with noise: it opens, but its pages are broken."""
    with open(path, "r+b") as fh:
        for n in pages:
            fh.seek((n - 1) * 4096)
            fh.write(bytes((i * 37 + 11) % 256 for i in range(4096)))


def test_one_damaged_database_does_not_stop_the_others_being_copied(home):
    (home / "calendar.sqlite").write_bytes(b"not a database at all" * 100)
    snap = take_snapshot(home, "hourly", now=NOW)
    assert [f["file"] for f in snap.manifest["files"]] == ["contacts.sqlite"]
    [failed] = backup.failures(snap)
    assert failed["file"] == "calendar.sqlite" and "could not be copied" in failed["reason"]
    assert "kept" not in failed and not (snap.path / backup.DAMAGED).exists()
    assert sorted(p.name for p in snap.path.iterdir()) == ["contacts.sqlite", "manifest.json"]
    assert verify(home)["ok"] is True  # what the snapshot holds restores cleanly


def test_the_hourly_snapshot_reports_a_file_it_left_out_until_one_holds_it(home):
    service = BackupService(home, platform="linux")
    _garble(home / "calendar.sqlite")
    assert service.run_once(NOW) is not None
    assert service.error.startswith("The hourly snapshot left out calendar.sqlite (the copy of calendar.sqlite ")
    assert "The other databases were copied" in service.error
    assert service.run_once(NOW + timedelta(hours=1)) is None  # nothing changed: no new copy, still an error
    assert service.error is not None and len(list_snapshots(home)) == 1
    (home / "calendar.sqlite").unlink()
    assert service.run_once(NOW + timedelta(hours=2)) is not None
    assert service.error is None


def test_a_migration_needs_only_its_own_file_copied(home):
    (home / "calendar.sqlite").write_bytes(b"not a database at all" * 100)
    open_store(NextContactsStore, home, "contacts.sqlite")
    [snap] = list_snapshots(home)
    assert snap.manifest["reason"] == "pre-migration"
    assert [f["file"] for f in snap.manifest["files"]] == ["contacts.sqlite"]


def test_a_migration_is_refused_when_its_own_file_cannot_be_copied(home):
    with sqlite3.connect(home / "contacts.sqlite") as db:
        pages = [r[0] for r in db.execute("SELECT pageno FROM dbstat WHERE name = 'contacts'")]
    _garble(home / "contacts.sqlite", pages)
    with sqlite3.connect(home / "contacts.sqlite") as db:  # still reads its version, so it would migrate
        assert db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == max(ContactsStore.MIGRATIONS)
    with pytest.raises(MigrationRefused, match="contacts.sqlite"):
        open_store(NextContactsStore, home, "contacts.sqlite")
    assert list_snapshots(home) == [] and not list((home / "backups").glob(".partial-*"))


# ---------------------------------------------------------------- retention


def test_retention_keeps_24_hourly_30_daily_12_monthly():
    snaps, at = [], datetime(2025, 1, 1, tzinfo=timezone.utc)
    while at <= NOW:
        snaps.append((at.strftime("%Y%m%dT%H%M%SZ"), at, "hourly"))
        at += timedelta(hours=1)
    keep = retention(snaps, NOW)
    kept = sorted(at for name, at, _ in snaps if name in keep)
    # The last 24 hours; the last hour of each of the 28 days before (14 September to 11 October); the last
    # hour of each of the 10 months before those (November 2025 to August 2026).
    assert len(kept) == 24 + 28 + 10
    assert kept[-24:] == [NOW - timedelta(hours=h) for h in range(23, -1, -1)]
    days = [k for k in kept if datetime(2026, 9, 14, tzinfo=timezone.utc) <= k < NOW - timedelta(hours=23)]
    assert len(days) == 28 and all(k.hour == 23 for k in days)
    months = [k.strftime("%Y-%m-%d %H") for k in kept if k < datetime(2026, 9, 14, tzinfo=timezone.utc)]
    assert months == ["2025-11-30 23", "2025-12-31 23", "2026-01-31 23", "2026-02-28 23", "2026-03-31 23",
                      "2026-04-30 23", "2026-05-31 23", "2026-06-30 23", "2026-07-31 23", "2026-08-31 23"]


def test_retention_counts_periods_that_have_a_snapshot():
    # A host that ran only now and then: the 24 most recent hours *with a snapshot* are kept, however old.
    # One every 3 days back to 18 June: 24 hours and 30 days with one (s0-s29), and June's newest (s35, 30 June).
    snaps = [(f"s{i}", NOW - timedelta(days=3 * i), "hourly") for i in range(40)]
    assert retention(snaps, NOW) == {f"s{i}" for i in range(30)} | {"s35"}


def test_snapshots_before_a_migration_or_restore_are_kept_90_days():
    snaps = [("hourly-new", NOW - timedelta(minutes=5), "hourly"),
             ("migration", NOW - timedelta(minutes=30), "pre-migration"),
             ("restore-old", NOW - timedelta(days=91), "pre-restore"),
             ("manual", NOW - timedelta(days=60), "manual")]
    keep = retention(snaps, NOW, hourly=1, daily=1, monthly=1)
    assert keep == {"hourly-new", "migration", "manual"}


@pytest.mark.parametrize("now,expected", [("2026-10-13T12:00:00", "2027-10-01"), ("2026-12-31T23:59:59", "2027-12-01"),
                                          ("2026-01-01T00:00:00", "2027-01-01")])
def test_deleted_data_leaves_the_snapshots_within_12_months(now, expected):
    at = datetime.fromisoformat(now).replace(tzinfo=timezone.utc)
    until = backup.kept_until(at)
    assert until.isoformat() == expected
    # Simulated: hourly snapshots from a month before the deletion (holding the data) to a year after it.
    snaps, t = [], at - timedelta(days=31)
    while t <= at + timedelta(days=400):
        snaps.append((t.strftime("%Y%m%dT%H%M%SZ"), t, "hourly"))
        t += timedelta(hours=6)
    holding = {name for name, t, _ in snaps if t <= at}

    def held_on(day):
        moment = datetime(day.year, day.month, day.day, 6, tzinfo=timezone.utc)
        return bool(retention([s for s in snaps if s[1] <= moment], moment) & holding)

    assert not held_on(until)
    if at.day == 31:  # deleted at the very end of a month: that month's snapshot holds it, so the bound is exact
        assert held_on(until - timedelta(days=1))


def test_prune_removes_what_retention_drops(home):
    for h in range(30):
        take_snapshot(home, "hourly", now=NOW - timedelta(hours=h))
    stale = home / "backups" / ".partial-20200101T000000Z-dead"
    stale.mkdir()
    os.utime(stale, (0, 0))
    removed = prune(home, NOW)
    # The 30 hours span two days and one month, whose newest are already among the last 24 hours.
    assert sorted(removed) == [(NOW - timedelta(hours=h)).strftime("%Y%m%dT%H%M%SZ") for h in range(29, 23, -1)]
    assert len(list_snapshots(home)) == 24
    assert not stale.exists()


# ---------------------------------------------------------------- before a migration


class NextContactsStore(ContactsStore):
    """The contacts store as a later build would have it: one more (additive) migration."""
    MIGRATIONS = {**ContactsStore.MIGRATIONS, max(ContactsStore.MIGRATIONS) + 1: ["CREATE TABLE next_build (k TEXT, v TEXT)"]}


def test_a_snapshot_is_taken_before_a_migration(home):
    open_store(ContactsStore, home, "contacts.sqlite")  # up to date: nothing to protect
    assert list_snapshots(home) == []
    store = open_store(NextContactsStore, home, "contacts.sqlite")
    [snap] = list_snapshots(home)
    m = snap.manifest
    assert m["reason"] == "pre-migration"
    entry = next(f for f in m["files"] if f["file"] == "contacts.sqlite")
    assert entry["schema_version"] == max(ContactsStore.MIGRATIONS)  # the state before the migration
    with store.db.connect() as db:
        assert db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == max(NextContactsStore.MIGRATIONS)
    open_store(NextContactsStore, home, "contacts.sqlite")  # migrated now: no second snapshot
    assert len(list_snapshots(home)) == 1


def test_a_new_file_needs_no_snapshot(tmp_path):
    open_store(NextContactsStore, tmp_path, "contacts.sqlite")
    assert list_snapshots(tmp_path) == []


def test_no_migration_without_its_snapshot(home, monkeypatch):
    def fail(*_a, **_kw):
        raise BackupError("the disk is full")

    monkeypatch.setattr(backup, "take_snapshot", fail)
    LAST_ERROR.last = None
    logging.getLogger().addHandler(LAST_ERROR)
    try:
        with pytest.raises(MigrationRefused, match="snapshot before it failed"):
            open_store(NextContactsStore, home, "contacts.sqlite")
        assert "was not updated" in LAST_ERROR.last["message"]  # what /status shows as last_error
        assert "the disk is full" in LAST_ERROR.last["message"]
    finally:
        logging.getLogger().removeHandler(LAST_ERROR)
    assert count(home / "contacts.sqlite", "schema_version") == len(ContactsStore.MIGRATIONS)  # untouched


def test_the_sync_service_opens_its_stores_through_the_snapshot_hook(home, monkeypatch):
    import mydata.service.sync as sync
    monkeypatch.setattr(sync, "ContactsStore", NextContactsStore)
    sources = SyncService(home, Accounts(home, MemorySecretStore()), platform="linux")
    sources.contacts.list()
    assert [s.manifest["reason"] for s in list_snapshots(home)] == ["pre-migration"]


CURRENT = max(ContactsStore.MIGRATIONS)


class BrokenNextContactsStore(ContactsStore):
    """A later build whose migration fails (NOT NULL without a default, on a table with rows)."""
    MIGRATIONS = {**ContactsStore.MIGRATIONS,
                  max(ContactsStore.MIGRATIONS) + 1: ["ALTER TABLE contacts ADD COLUMN next_build TEXT",
                                                      "UPDATE contacts SET display_name = NULL"]}


def test_a_failing_migration_takes_one_snapshot_however_often_it_is_tried(home):
    LAST_ERROR.last = None
    logging.getLogger().addHandler(LAST_ERROR)
    try:
        for _ in range(5):
            with pytest.raises(MigrationError):
                open_store(BrokenNextContactsStore, home, "contacts.sqlite")
        [snap] = list_snapshots(home)
        message = LAST_ERROR.last["message"]
        assert message.startswith(f"contacts.sqlite could not be updated from schema version {CURRENT} to "
                                  f"{CURRENT + 1} (IntegrityError")
        assert f"rolled back and the file is as it was; snapshot {snap.name} holds it" in message
    finally:
        logging.getLogger().removeHandler(LAST_ERROR)
    assert snap.manifest["migration"] == {"file": "contacts.sqlite", "from": CURRENT, "to": CURRENT + 1}
    assert count(home / "contacts.sqlite", "schema_version") == len(ContactsStore.MIGRATIONS)
    # The file changed meanwhile: the old snapshot no longer holds it, so a new one is taken.
    with ContactsStore(home / "contacts.sqlite").db.transaction() as db:
        db.execute("UPDATE address_books SET name = 'Renamed'")
    with pytest.raises(MigrationError):
        open_store(BrokenNextContactsStore, home, "contacts.sqlite")
    assert len(list_snapshots(home)) == 2


def test_a_snapshot_too_old_to_be_kept_long_is_not_used_again(home, monkeypatch):
    with pytest.raises(MigrationError):
        open_store(BrokenNextContactsStore, home, "contacts.sqlite")
    monkeypatch.setattr(backup, "_utc", lambda now=None: datetime.now(timezone.utc) + backup.REUSE_FOR)
    with pytest.raises(MigrationError):
        open_store(BrokenNextContactsStore, home, "contacts.sqlite")
    assert len(list_snapshots(home)) == 2


def test_the_sync_service_does_not_retry_a_failed_store_on_every_access(home, monkeypatch):
    import mydata.service.sync as sync
    monkeypatch.setattr(sync, "ContactsStore", BrokenNextContactsStore)
    calls = []
    real = sync.open_store
    monkeypatch.setattr(sync, "open_store", lambda *a: (a[2] == "contacts.sqlite" and calls.append(a)) or real(*a))
    clock = [1000.0]
    sources = SyncService(home, Accounts(home, MemorySecretStore()), platform="linux", clock=lambda: clock[0])
    for _ in range(10):
        with pytest.raises(MigrationError):
            sources.contacts
    assert len(calls) == 1 and len(list_snapshots(home)) == 1
    assert sources.calendar.calendars()  # the other store is not affected
    clock[0] += sync.STORE_RETRY
    monkeypatch.setattr(sync, "ContactsStore", NextContactsStore)  # e.g. a fixed build
    assert sources.contacts.list() and len(calls) == 2
    assert len(list_snapshots(home)) == 1  # the file had not changed: the same snapshot protects it


def test_only_the_newest_snapshots_before_each_migration_are_kept_90_days():
    one, other = ("contacts.sqlite", 1, 2), ("calendar.sqlite", 1, 2)
    snaps = [(f"m{i}", NOW - timedelta(hours=i + 1), "pre-migration", one) for i in range(6)]
    snaps += [("c0", NOW - timedelta(hours=2), "pre-migration", other), ("old", NOW - timedelta(days=2), "pre-migration")]
    snaps += [(f"manual{i}", NOW - timedelta(hours=i + 1), "manual") for i in range(5)]
    keep = retention(snaps, NOW, hourly=0, daily=0, monthly=0)
    assert keep == {"m0", "m1", "m2", "c0", "old"} | {f"manual{i}" for i in range(5)}


def test_prune_keeps_three_snapshots_per_migration(home):
    day = NOW - timedelta(days=40)  # only the newest is that day's and that month's
    names = [take_snapshot(home, "pre-migration", now=day + timedelta(hours=h),
                           extra={"migration": {"file": "contacts.sqlite", "from": 1, "to": 2}}).name
             for h in range(5)]
    for h in range(24):  # fill the hourly window
        take_snapshot(home, "hourly", now=NOW - timedelta(hours=h))
    assert sorted(prune(home, NOW)) == names[:2]
    assert sorted(s.name for s in list_snapshots(home))[:3] == names[2:]


# ---------------------------------------------------------------- the restore drill


def test_the_restore_drill_passes_on_a_good_snapshot(home):
    snap = take_snapshot(home, "manual", now=NOW)
    result = verify(home, now=NOW + timedelta(minutes=1))
    assert result == {"at": "2026-10-13T12:01:00+00:00", "snapshot": snap.name, "ok": True, "problems": []}
    path = home / "backups" / "last_verify.json"
    assert json.loads(path.read_text()) == result and mode(path) == 0o600
    assert not list((home / "backups").glob(".verify-*"))  # the temporary copy is gone
    assert snap.manifest["files"][0]["sha256"] == backup._sha256(snap.path / snap.manifest["files"][0]["file"])


def test_the_drill_runs_this_codes_migrations(home, monkeypatch):
    take_snapshot(home, "manual", now=NOW)
    monkeypatch.setattr(backup, "_stores", lambda: {"contacts.sqlite": NextContactsStore})
    assert verify(home)["ok"] is True
    assert count(home / "contacts.sqlite", "schema_version") == len(ContactsStore.MIGRATIONS)  # live file untouched


def test_the_drill_counts_rows_before_this_codes_migrations_change_them(home, monkeypatch):
    class Renamed(ContactsStore):  # a later build that renames a table: the snapshot is still faithful
        MIGRATIONS = {**ContactsStore.MIGRATIONS,
                      max(ContactsStore.MIGRATIONS) + 1: ["ALTER TABLE address_books RENAME TO books"]}

    take_snapshot(home, "manual", now=NOW)
    monkeypatch.setattr(backup, "_stores", lambda: {"contacts.sqlite": Renamed})
    assert verify(home)["problems"] == []


def test_the_drill_finds_a_damaged_snapshot(home):
    snap = take_snapshot(home, "manual", now=NOW)
    with open(snap.path / "contacts.sqlite", "ab") as fh:
        fh.write(b"\0")
    result = verify(home, snap.name)
    assert result["ok"] is False
    assert result["problems"] == ["contacts.sqlite has changed since the snapshot was taken (sha256)"]
    assert backup.last_verify(home)["ok"] is False


def test_the_drill_compares_row_counts(home):
    snap = take_snapshot(home, "manual", now=NOW)
    m = snap.manifest
    next(f for f in m["files"] if f["file"] == "calendar.sqlite")["row_counts"]["events"] = 99
    (snap.path / "manifest.json").write_text(json.dumps(m))
    assert verify(home)["problems"] == ["calendar.sqlite: events has 6 rows, the manifest says 99"]


def test_the_drill_checks_the_search_index(home):
    with sqlite3.connect(home / "contacts.sqlite") as db:  # the index loses a row its table still has
        db.execute("INSERT INTO contacts_fts (contacts_fts) VALUES ('delete-all')")
    snap = take_snapshot(home, "manual", now=NOW)
    entry = next(f for f in snap.manifest["files"] if f["file"] == "contacts.sqlite")
    assert entry["warnings"] == ["the search index contacts_fts does not match its table"]
    result = verify(home)
    assert result["ok"] is False
    assert result["problems"] == ["contacts.sqlite: the search index contacts_fts does not match its table"]


def test_the_drill_needs_a_snapshot(tmp_path):
    with pytest.raises(BackupError, match="no snapshots"):
        verify(tmp_path)
    populate(tmp_path)
    take_snapshot(tmp_path, "manual")
    with pytest.raises(BackupError, match="no snapshot named"):
        verify(tmp_path, "20000101T000000Z")


# ---------------------------------------------------------------- restore


def test_restore_puts_a_snapshot_back_and_keeps_the_state_it_replaced(home):
    snap = take_snapshot(home, "manual", now=NOW)
    before = count(home / "contacts.sqlite", "contacts")
    contacts = ContactsStore(home / "contacts.sqlite")
    contacts.delete_account("acc-1")
    assert count(home / "contacts.sqlite", "contacts") == 0
    (home / "contacts.sqlite-wal").write_bytes(b"stale")  # a leftover WAL must not be applied
    out = restore(home, snap.name, now=NOW + timedelta(hours=1))
    assert out["snapshot"] == snap.name and sorted(out["restored"]) == ["calendar.sqlite", "contacts.sqlite"]
    assert count(home / "contacts.sqlite", "contacts") == before
    assert not (home / "contacts.sqlite-wal").exists()
    assert mode(home / "contacts.sqlite") == 0o600
    pre = find_snapshot(home, out["before"])
    assert pre.manifest["reason"] == "pre-restore"
    entry = next(f for f in pre.manifest["files"] if f["file"] == "contacts.sqlite")
    assert entry["row_counts"]["contacts"] == 0  # the state that was replaced is kept
    assert not (home / "mydatad.pid").exists()  # the lock is released
    assert ContactsStore(home / "contacts.sqlite").list()  # the host opens it as usual


@pytest.mark.parametrize("damage", ["pages", "garbage"])
def test_restore_puts_a_snapshot_back_over_a_damaged_database(home, damage):
    snap = take_snapshot(home, "manual", now=NOW)
    live = home / "calendar.sqlite"
    if damage == "pages":
        _garble(live)
    else:
        live.write_bytes(b"not a database at all" * 100)
    (home / "calendar.sqlite-wal").write_bytes(b"a wal beside it")
    damaged = live.read_bytes()
    out = restore(home, snap.name, now=NOW + timedelta(hours=1))
    assert sorted(out["restored"]) == ["calendar.sqlite", "contacts.sqlite"] and out["damaged"] == ["calendar.sqlite"]
    assert count(live, "events") == 6
    pre = find_snapshot(home, out["before"])
    assert pre.manifest["reason"] == "pre-restore"
    assert [f["file"] for f in pre.manifest["files"]] == ["contacts.sqlite"]  # the healthy one, copied as usual
    [failed] = backup.failures(pre)
    assert [k["file"] for k in failed["kept"]] == ["damaged/calendar.sqlite", "damaged/calendar.sqlite-wal"]
    kept = pre.path / "damaged"
    assert (kept / "calendar.sqlite").read_bytes() == damaged  # byte for byte, to look at later
    assert (kept / "calendar.sqlite-wal").read_bytes() == b"a wal beside it"
    assert mode(kept) == 0o700 and {mode(p) for p in kept.iterdir()} == {0o600}
    assert failed["kept"][0]["sha256"] == backup._sha256(kept / "calendar.sqlite")
    assert verify(home, pre.name)["ok"] is True  # the drill checks what the snapshot holds


def test_a_restore_cannot_be_stopped_as_if_it_were_the_host(home, monkeypatch):
    import signal

    from mydata.service.daemon import daemon_pid
    snap = take_snapshot(home, "manual", now=NOW)
    stale = home / ".contacts.sqlite.restoring"
    stale.write_bytes(b"a copy from a restore that was killed")
    (home / "mydatad.pid").write_text("99999")  # an old pid nobody holds the lock on
    seen = {}
    real = backup.take_snapshot

    def during(*a, **kw):
        settings = Settings(home=home)
        seen["pid"] = daemon_pid(settings)
        seen["file"] = settings.pid_path.read_text()
        seen["sigterm"] = signal.getsignal(signal.SIGTERM)
        seen["stale"] = stale.exists()
        return real(*a, **kw)

    before = signal.getsignal(signal.SIGTERM)
    monkeypatch.setattr(backup, "take_snapshot", during)
    restore(home, snap.name, now=NOW + timedelta(hours=1))
    # mydata stop finds no host to stop, and a SIGTERM would be ignored meanwhile
    assert seen == {"pid": None, "file": "restoring", "sigterm": signal.SIG_IGN, "stale": False}
    assert signal.getsignal(signal.SIGTERM) == before
    assert not list(home.glob(".*.restoring"))


def test_restore_refuses_while_the_host_runs(home):
    snap = take_snapshot(home, "manual", now=NOW)
    fd = acquire_pid_lock(Settings(home=home))  # stands in for a running mydatad
    try:
        with pytest.raises(HostRunning, match="stop it first"):
            restore(home, snap.name)
    finally:
        os.close(fd)
    assert len(list_snapshots(home)) == 1  # nothing was done


def test_restore_refuses_a_damaged_snapshot(home):
    snap = take_snapshot(home, "manual", now=NOW)
    (snap.path / "calendar.sqlite").unlink()
    with pytest.raises(BackupError, match="damaged"):
        restore(home, snap.name)
    assert count(home / "calendar.sqlite", "events") == 6


# ---------------------------------------------------------------- status and the hourly timer


def test_status_reports_the_last_snapshot_and_drill(home, monkeypatch):
    monkeypatch.setattr(backup, "_filevault", None)
    assert backup.status(home, platform="linux") == {"last_snapshot_at": None, "last_verified_at": None,
                                                     "last_verify_ok": None, "filevault": "unknown",
                                                     "error": None}
    take_snapshot(home, "manual", now=NOW)
    verify(home, now=NOW + timedelta(minutes=2))
    st = backup.status(home, platform="linux")
    assert st["last_snapshot_at"] == "2026-10-13T12:00:00+00:00"
    assert (st["last_verified_at"], st["last_verify_ok"]) == ("2026-10-13T12:02:00+00:00", True)


def test_status_answers_when_the_snapshots_folder_cannot_be_read(home, monkeypatch):
    monkeypatch.setattr(backup, "_filevault", None)
    (home / "backups").write_text("a file where the folder should be")
    st = backup.status(home, platform="linux")
    assert st["last_snapshot_at"] is None
    assert st["error"] == "The snapshots folder cannot be read (NotADirectoryError)."


def test_leftovers_of_killed_drills_and_restores_are_removed(home):
    take_snapshot(home, "manual", now=NOW)
    old_drill = home / "backups" / ".verify-dead"
    new_drill = home / "backups" / ".verify-busy"  # a drill running now, from the mydata command
    old_check = home / "backups" / ".check-dead"  # a killed `mydata db check-migration`
    new_check = home / "backups" / ".check-busy"
    for d in (old_drill, new_drill, old_check, new_check):
        d.mkdir()
        (d / "contacts.sqlite").write_bytes(b"a full copy")
    os.utime(old_drill, (0, 0))
    os.utime(old_check, (0, 0))
    prune(home, NOW)
    assert not old_drill.exists() and new_drill.exists()
    assert not old_check.exists() and new_check.exists()
    staged = home / ".calendar.sqlite.restoring"
    staged.write_bytes(b"a full copy")
    BackupService(home, platform="linux").run_once(NOW)  # the running host holds the lock
    assert not staged.exists()


def test_status_has_a_backup_section(home):
    import fake_dav
    from service_helpers import Host
    from starlette.testclient import TestClient

    take_snapshot(home, "manual", now=NOW)
    verify(home, now=NOW)
    host = Host(home, fake_dav.FakeDav())
    st = TestClient(host.app, base_url="http://127.0.0.1").get("/status", headers=host.auth).json()
    assert st["backup"] == {"last_snapshot_at": "2026-10-13T12:00:00+00:00",
                            "last_verified_at": "2026-10-13T12:00:00+00:00", "last_verify_ok": True,
                            "filevault": "unknown", "error": None}


@pytest.mark.parametrize("out,expected", [("true\n", "on"), ("false\n", "off"), ("", "unknown")])
def test_filevault_is_asked_once_without_a_prompt(monkeypatch, out, expected):
    monkeypatch.setattr(backup, "_filevault", None)
    calls = []

    def run(cmd, **kw):
        calls.append((cmd, kw))
        return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")

    assert backup.filevault("darwin", run) == expected
    assert backup.filevault("darwin", run) == expected
    assert len(calls) == 1 and calls[0][0] == ["/usr/bin/fdesetup", "isactive"]
    assert calls[0][1]["stdin"] == subprocess.DEVNULL and calls[0][1]["timeout"] <= 5


def test_filevault_unknown_when_fdesetup_fails(monkeypatch):
    monkeypatch.setattr(backup, "_filevault", None)

    def run(cmd, **kw):
        raise subprocess.TimeoutExpired(cmd, 5)

    assert backup.filevault("darwin", run) == "unknown"


def test_the_hourly_snapshot_skips_an_unchanged_home_and_reports_failures(home, monkeypatch):
    service = BackupService(home, platform="linux")
    assert service.run_once(NOW) is not None
    assert service.run_once(NOW + timedelta(hours=1)) is None and service.error is None

    def fail(*_a, **_kw):
        raise BackupError("the disk is full")

    monkeypatch.setattr(backup, "take_snapshot", fail)
    assert service.run_once(NOW + timedelta(hours=2)) is None
    assert service.error == "The hourly snapshot failed (the disk is full). The host will try again."
    assert service.status()["error"] == service.error


def test_the_timer_starts_and_stops(home):
    service = BackupService(home, interval=3600, platform="linux")
    service.start()
    for _ in range(100):
        if list_snapshots(home):
            break
        time.sleep(0.05)
    service.stop()
    assert [s.manifest["reason"] for s in list_snapshots(home)] == ["hourly"]


def test_stores_are_opened_only_through_the_snapshot_hook():
    """Constructing a store migrates its file: outside backup.py (open_store, and the drill's temporary
    copies) no host code may do it directly."""
    import re
    from pathlib import Path

    src = Path(backup.__file__).parents[1]
    direct = re.compile(r"\b(ContactsStore|CalendarStore)\(|\bDatabase\(")
    allowed = {"service/backup.py", "sources/_db.py", "sources/contacts_store.py", "sources/calendar_store.py"}
    found = [f"{p.relative_to(src)}:{n}" for p in src.rglob("*.py") if str(p.relative_to(src)) not in allowed
             for n, line in enumerate(p.read_text().splitlines(), 1) if direct.search(line)]
    assert found == []


def test_the_host_starts_and_reports_a_store_it_cannot_open(home, monkeypatch):
    """Real mode, a contacts migration that fails and a calendar file that is not a database: the host is
    still built, /status answers with the error, and the mirror's routes and tools say what is wrong."""
    import fake_dav
    import mydata.service.sync as sync
    from service_helpers import Host
    from starlette.testclient import TestClient

    Accounts(home, MemorySecretStore()).add("icloud", "ava.fictional@example.org", "invented-pw",
                                            verify=lambda e, p: None)
    monkeypatch.setattr(sync, "ContactsStore", BrokenNextContactsStore)
    (home / "calendar.sqlite").write_bytes(b"not a database at all" * 100)
    LAST_ERROR.last = None
    logging.getLogger().addHandler(LAST_ERROR)
    try:
        host = Host(home, fake_dav.FakeDav())
        assert host.modes.mode == "real"
        assert list_snapshots(home) == []  # building the host opened no store
        client = TestClient(host.app, base_url="http://127.0.0.1")
        r = client.get("/contacts", headers=host.auth)
        assert r.status_code == 503 and "contacts.sqlite could not be updated" in r.json()["detail"]
        st = client.get("/status", headers=host.auth)
        assert st.status_code == 200 and "contacts.sqlite could not be updated" in st.json()["last_error"]["message"]
        result = host.assistant.registry.invoke("find_contact", {"name": "Ava"}, caller="test")
        assert result.status == "error" and "MigrationError" in result.error
    finally:
        logging.getLogger().removeHandler(LAST_ERROR)
