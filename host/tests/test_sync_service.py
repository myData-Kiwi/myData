"""The sync service in mydatad: mirrors each account from the fake iCloud server, reports status, backs off
on errors, never logs secrets or personal fields, and never brings back data of a removed account.
Invented data only (tests/fake_dav)."""

from __future__ import annotations

import io
import json
import logging
import time

import httpx
import pytest

import fake_dav
from fake_dav import FakeDav
from mydata.service.logs import JsonFormatter
from mydata.service.sync import (MSG_KEYCHAIN_MISSING, MSG_PASSWORD, MSG_UNREACHABLE, SyncService, backoff_delay,
                                 user_message)
from mydata.sources.accounts import Accounts, secret_key
from mydata.sources.dav.client import DavError
from mydata.sources.providers import VerificationError
from mydata.sources.secrets import MemorySecretStore

MIN = 60.0


class Clock:
    def __init__(self, t: float = 1_800_000_000.0):
        self.t = t

    def __call__(self) -> float:
        return self.t


def make(tmp_path, fake=None, **kw):
    fake = fake or FakeDav()
    secrets = MemorySecretStore()
    sources = SyncService(tmp_path, Accounts(tmp_path, secrets), transport=kw.pop("transport", fake.transport), **kw)
    return sources, fake, secrets


def add(sources, fake=None):
    return sources.add_account("icloud", fake_dav.USERNAME, fake_dav.PASSWORD)


# ---------------------------------------------------------------- mirroring


def test_first_sync_mirrors_contacts_and_event_calendars(tmp_path):
    sources, fake, secrets = make(tmp_path)
    account = add(sources)
    assert secrets.keys() == [secret_key(account.id)]
    status = sources.sync_account(account.id)
    assert status["state"] == "idle" and status["last_error"] is None and status["last_success"]
    assert status["counts"] == {"address_books": 1, "contacts": 6, "calendars": 3, "events": 5}
    names = sorted(c["display_name"] for c in sources.contacts.list())
    assert names == ["Acme Plumbing (Example)", "Ava Fictional", "Ben Madeup", "Sam Example", "Sam Example",
                     "someone@example.net"]
    assert sorted(c["name"] for c in sources.calendar.calendars()) == ["Holidays (example)", "Home", "Work"]
    assert (tmp_path / "contacts.sqlite").exists() and (tmp_path / "calendar.sqlite").exists()
    assert fake.methods <= fake_dav.READ_METHODS


def test_later_syncs_pick_up_changes_and_soft_delete_upstream_deletions(tmp_path):
    from fake_dav.data import vcard
    sources, fake, _ = make(tmp_path)
    account = add(sources)
    sources.sync_account(account.id)
    ben = next(c for c in sources.contacts.list() if c["display_name"] == "Ben Madeup")
    fake.delete_item("card", "ben-madeup.vcf")
    fake.add_item("card", "zoe.vcf", vcard("fake-uid-zoe", "Zoe Example", emails=[("HOME", "zoe@example.org")]))
    status = sources.sync_account(account.id)
    assert status["counts"]["contacts"] == 6
    names = {c["display_name"] for c in sources.contacts.list()}
    assert "Zoe Example" in names and "Ben Madeup" not in names
    gone = sources.contacts.get(ben["id"], include_deleted=True)
    assert gone["deleted_at"] is not None  # upstream deletion: the soft-delete marker, not a hard delete


def test_two_accounts_are_kept_apart_and_removing_one_hard_deletes_only_its_data(tmp_path):
    sources, fake, secrets = make(tmp_path)
    a = add(sources)
    b = sources.accounts.add("icloud", "ben.invented@example.net", fake_dav.PASSWORD, verify=lambda e, p: None)
    fake.username = "ben.invented@example.net"
    sources.sync_account(b.id)
    fake.username = fake_dav.USERNAME
    sources.sync_account(a.id)
    assert sources.contacts.account_ids() == sorted([a.id, b.id])
    assert len(sources.contacts.list()) == 12  # duplicates across accounts are mirrored as they are
    sources.remove_account(b.id)
    assert sources.contacts.account_ids() == [a.id] and sources.calendar.account_ids() == [a.id]
    assert secrets.keys() == [secret_key(a.id)]
    assert [s["account_id"] for s in sources.status()] == [a.id]


def test_adding_with_a_wrong_password_stores_nothing(tmp_path):
    sources, _, secrets = make(tmp_path)
    with pytest.raises(VerificationError) as e:
        sources.add_account("icloud", fake_dav.USERNAME, "wrong-invented-pw")
    assert "wrong-invented-pw" not in str(e.value)
    assert sources.accounts.list() == [] and secrets.keys() == []


# ---------------------------------------------------------------- errors and backoff


def test_backoff_steps():
    assert [backoff_delay(n) / MIN for n in range(1, 8)] == [15, 30, 60, 120, 240, 240, 240]


def test_rejected_password_backs_off_and_success_resets(tmp_path):
    clock = Clock()
    sources, fake, _ = make(tmp_path, clock=clock)
    account = add(sources)
    sources.sync_account(account.id)
    fake.password = "revoked-invented-pw"  # the user revoked the app-specific password at Apple
    waits = []
    for _ in range(6):
        status = sources.sync_account(account.id)
        assert status["state"] == "error" and status["last_error"] == MSG_PASSWORD
        waits.append(sources._entry(account.id).due - clock.t)
        clock.t += 1
    assert [w / MIN for w in waits] == [15, 30, 60, 120, 240, 240]
    fake.password = fake_dav.PASSWORD
    status = sources.sync_account(account.id)
    assert status["state"] == "idle" and status["last_error"] is None
    assert sources._entry(account.id).due - clock.t == 15 * MIN and sources._entry(account.id).failures == 0


def test_run_due_respects_the_schedule(tmp_path):
    clock = Clock()
    sources, fake, _ = make(tmp_path, clock=clock)
    account = add(sources)
    assert sources.run_due() == 1  # a new account is due at once
    assert sources.run_due() == 0
    clock.t += 15 * MIN
    assert sources.run_due() == 1
    sources.request_sync(account.id)  # Sync now
    assert sources.run_due() == 1


def test_user_messages_hold_no_details():
    assert user_message(DavError("p42 said no", 401)) == MSG_PASSWORD
    assert user_message(DavError("could not reach p42: ConnectError (secret detail)")) == MSG_UNREACHABLE
    assert user_message(DavError("x", 503)) == "iCloud answered with an error (HTTP 503). The host will try again."
    assert user_message(KeyError("account:abc")) == MSG_KEYCHAIN_MISSING
    assert user_message(ValueError("Ava Fictional's card")) == "Sync failed (ValueError). The host will try again."


def test_unreachable_server(tmp_path):
    def down(request):
        raise httpx.ConnectError("no route", request=request)
    sources, _, _ = make(tmp_path, transport=httpx.MockTransport(down))
    account = sources.accounts.add("icloud", fake_dav.USERNAME, fake_dav.PASSWORD, verify=lambda e, p: None)
    assert sources.sync_account(account.id)["last_error"] == MSG_UNREACHABLE


def test_missing_keychain_item(tmp_path):
    sources, _, secrets = make(tmp_path)
    account = add(sources)
    secrets.delete(secret_key(account.id))
    assert sources.sync_account(account.id)["last_error"] == MSG_KEYCHAIN_MISSING


# ---------------------------------------------------------------- logs


@pytest.fixture
def captured():
    """Every log record, rendered by the host's own formatter (message plus structured fields)."""
    buf = io.StringIO()
    handler = logging.StreamHandler(buf)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    old = root.level
    root.addHandler(handler)
    root.setLevel(logging.DEBUG)
    yield buf
    root.removeHandler(handler)
    root.setLevel(old)


PERSONAL = ["Ava", "Fictional", "Ben Madeup", "Sam Example", "Plumbing", "someone@", "ava.fictional@example.com",
            "555 01", "5550", "7700", "Dentist", "Lake trip", "standup", "Example Street", "birthday", "Made-up Day"]


def test_logs_hold_counts_and_ids_but_no_password_or_personal_fields(tmp_path, captured):
    sources, fake, _ = make(tmp_path)
    account = add(sources)
    sources.sync_account(account.id)
    fake.password = "revoked-invented-pw"
    sources.sync_account(account.id)
    sources.remove_account(account.id)
    text = captured.getvalue()
    assert fake_dav.PASSWORD not in text and "revoked-invented-pw" not in text
    import base64
    assert base64.b64encode(f"{fake_dav.USERNAME}:{fake_dav.PASSWORD}".encode()).decode() not in text
    lines = [json.loads(line) for line in text.splitlines() if line.strip()]
    info = "\n".join(json.dumps(r) for r in lines if r["level"] != "DEBUG")
    for word in PERSONAL:
        assert word not in info, f"{word!r} reached the log"
    synced = [r for r in lines if r["msg"] == "collection synced"]
    assert len(synced) == 4 and all(r["collection_id"] and r["account_id"] == account.id for r in synced)
    finished = next(r for r in lines if r["msg"] == "sync finished")
    assert finished["contacts"] == 6 and finished["events"] == 5
    failed = next(r for r in lines if r["msg"] == "sync failed")
    assert failed["error"] == "DavError" and failed["status"] == 401


# ---------------------------------------------------------------- removal races


def test_removing_the_account_mid_sync_leaves_no_data(tmp_path):
    fake = FakeDav()
    box = {}

    def handler(request):
        if box.get("armed") and request.url.host == fake.calendar_host and "removed" not in box:
            box["removed"] = True
            box["sources"].remove_account(box["id"])  # contacts are already stored at this point
        return fake.transport.handle_request(request)

    sources, _, secrets = make(tmp_path, fake, transport=httpx.MockTransport(handler))
    account = add(sources)
    box.update(sources=sources, id=account.id, armed=True)
    status = sources.sync_account(account.id)
    assert box["removed"] and status["state"] == "idle"
    assert sources.contacts.account_ids() == [] and sources.calendar.account_ids() == []
    assert sources.status() == [] and secrets.keys() == []


def test_data_left_by_a_removal_elsewhere_is_purged(tmp_path):
    sources, fake, secrets = make(tmp_path)
    account = add(sources)
    sources.check_accounts()
    sources.sync_account(account.id)
    # `mydata account remove` in another process: its data hook ran before the host's last write landed.
    Accounts(tmp_path, secrets).remove(account.id, on_remove=lambda a: None)
    assert sources.contacts.account_ids() == [account.id]
    sources.check_accounts()
    assert sources.contacts.account_ids() == [] and sources.calendar.account_ids() == []


# ---------------------------------------------------------------- the thread


def _wait(predicate, timeout=10.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.02)
    return False


def test_thread_syncs_at_start_and_on_demand(tmp_path):
    from fake_dav.data import vcard
    sources, fake, _ = make(tmp_path, poll=0.05)
    account = sources.accounts.add("icloud", fake_dav.USERNAME, fake_dav.PASSWORD, verify=lambda e, p: None)
    changed = []
    sources.on_accounts_changed = lambda: changed.append(True)
    sources.start()
    try:
        assert _wait(lambda: sources.status()[0]["last_success"] is not None)
        assert changed  # the loop noticed the account (added "elsewhere") and told the mode switch
        assert sources.status()[0]["counts"]["contacts"] == 6
        fake.add_item("card", "zoe.vcf", vcard("fake-uid-zoe", "Zoe Example"))
        sources.request_sync(account.id)
        assert _wait(lambda: sources.status()[0]["counts"]["contacts"] == 7)
    finally:
        sources.stop()
    assert not sources._thread.is_alive()
