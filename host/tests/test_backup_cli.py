"""mydata backup now / list / verify / restore, run as the command on a temporary host folder with synthetic
data. The restore drill is part of the test suite here (there is no CI)."""

import os
import subprocess
import sys

from mydata.service.backup import list_snapshots
from mydata.service.config import Settings
from mydata.service.daemon import acquire_pid_lock
from mydata.sources.contacts_store import ContactsStore

from synthetic_home import count, populate


def _mydata(home, *args):
    return subprocess.run([sys.executable, "-m", "mydata.cli", *args], env={**os.environ, "MYDATA_HOME": str(home)},
                          capture_output=True, text=True, timeout=60)


def test_backup_now_list_verify_and_restore(tmp_path):
    home = tmp_path / "home"
    r = _mydata(home, "backup", "now")
    assert r.returncode == 0 and "Nothing to back up" in r.stdout
    populate(home)
    contacts = count(home / "contacts.sqlite", "contacts")

    r = _mydata(home, "backup", "now")
    assert r.returncode == 0, r.stderr
    assert "contacts.sqlite" in r.stdout and "calendar.sqlite" in r.stdout
    [snap] = list_snapshots(home)

    r = _mydata(home, "backup", "verify")
    assert r.returncode == 0, r.stderr
    assert f"Snapshot {snap.name} restores cleanly" in r.stdout

    r = _mydata(home, "backup", "list")
    assert r.returncode == 0
    assert snap.name in r.stdout and "manual" in r.stdout and "passed" in r.stdout

    ContactsStore(home / "contacts.sqlite").delete_account("acc-1")
    r = _mydata(home, "backup", "restore", snap.name)  # no answer on stdin: not restored
    assert r.returncode == 1 and "Not restored" in r.stdout
    assert count(home / "contacts.sqlite", "contacts") == 0
    r = _mydata(home, "backup", "restore", snap.name, "--yes")
    assert r.returncode == 0, r.stderr
    assert count(home / "contacts.sqlite", "contacts") == contacts
    assert "The state it replaced is snapshot" in r.stdout
    assert [s.manifest["reason"] for s in list_snapshots(home)] == ["pre-restore", "manual"]


def test_restore_refuses_while_the_host_runs(tmp_path):
    populate(tmp_path)
    assert _mydata(tmp_path, "backup", "now").returncode == 0
    [snap] = list_snapshots(tmp_path)
    fd = acquire_pid_lock(Settings(home=tmp_path))  # stands in for a running mydatad
    try:
        r = _mydata(tmp_path, "backup", "restore", snap.name, "--yes")
    finally:
        os.close(fd)
    assert r.returncode == 1 and "the host is running" in r.stderr
    assert len(list_snapshots(tmp_path)) == 1


def test_verify_reports_problems_with_exit_1(tmp_path):
    populate(tmp_path)
    assert _mydata(tmp_path, "backup", "now").returncode == 0
    [snap] = list_snapshots(tmp_path)
    with open(snap.path / "calendar.sqlite", "ab") as fh:
        fh.write(b"\0")
    r = _mydata(tmp_path, "backup", "verify", snap.name)
    assert r.returncode == 1
    assert "calendar.sqlite has changed since the snapshot was taken" in r.stderr
    r = _mydata(tmp_path, "backup", "verify", "19990101T000000Z")
    assert r.returncode == 1 and "no snapshot named" in r.stderr
