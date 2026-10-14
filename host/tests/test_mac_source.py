"""This Mac, through the host as mydatad builds it, with the fake helper (tests/fake_mac) speaking the protocol
over the real Unix socket: permissions asked only when the user presses Allow, snapshots into the stores, the
tools and the API, per-account and per-calendar choice, change notifications, turning it off, the window
rule, a Mac-less host, and statuses kept across a restart. Invented data only."""

from __future__ import annotations

import logging
import shutil
import socket
import tempfile
import time
from datetime import date
from pathlib import Path

import pytest
from starlette.testclient import TestClient

import fake_dav
from fake_dav import FakeDav
from fake_mac import FakeLauncher, FakeMac, data
from mydata.service.backup import kept_until
from mydata.service.sync import SyncService
from mydata.sources.accounts import Accounts
from mydata.sources.mac import MAC_ID
from mydata.sources.mac.socket import socket_path

from owned_data import add_owned, owned_rows
from service_helpers import TODAY, Host, call, parse_sse

pytestmark = pytest.mark.skipif(not hasattr(socket, "AF_UNIX"), reason="needs Unix sockets")

WINDOW = {"start": "2025-03-18", "end": "2028-03-18"}  # TODAY (18 March 2026) - 1 year, + 2 years


def wait(predicate, timeout: float = 5.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if predicate():
                return True
        except Exception:  # noqa: BLE001 - not there yet
            pass
        time.sleep(0.02)
    return False


@pytest.fixture
def home(monkeypatch):
    monkeypatch.setenv("TZ", "Pacific/Auckland")
    path = Path(tempfile.mkdtemp(prefix="md-", dir="/tmp"))  # short: a socket path is at most 104 bytes
    yield path
    shutil.rmtree(path, ignore_errors=True)


@pytest.fixture
def make_host(home):
    hosts: list[Host] = []

    def make(mac: FakeMac | None = None, **kw) -> Host:
        h = Host(home, FakeDav(), mac=mac, **kw)
        hosts.append(h)
        return h

    yield make
    for h in hosts:
        h.sources.stop()


class Client:
    def __init__(self, host: Host):
        self.host = host
        self.c = TestClient(host.app, base_url="http://127.0.0.1")

    def __enter__(self):
        self.c.__enter__()
        return self

    def __exit__(self, *exc):
        self.c.__exit__(*exc)

    def get(self, path):
        r = self.c.get(path, headers=self.host.auth)
        assert r.status_code == 200, (path, r.status_code, r.text)
        return r.json()

    def put(self, path, body, status=200):
        r = self.c.put(path, headers=self.host.auth, json=body)
        assert r.status_code == status, (path, r.status_code, r.text)
        return r.json()

    def post(self, path, body=None, status=200):
        r = self.c.post(path, headers=self.host.auth, json=body)
        assert r.status_code == status, (path, r.status_code, r.text)
        return r.json()

    def mac(self) -> dict:
        return next(s for s in self.get("/sources")["sources"] if s["id"] == "mac")

    def names(self) -> list[str]:
        return [x["display_name"] for x in self.get("/contacts")]


def on(c: Client, mac: FakeMac) -> None:
    c.put("/sources/mac", {"enabled": True})
    assert wait(lambda: c.host.sources.mac.connected), "the fake reader did not connect"


ALL_NAMES = ["Acme Plumbing (Example)", "Ava Q Fictional", "Sam Example", "Sam Example"]
OWNED_NAMES = ["Olive Owned", "Pip Keepsake"]  # tests/owned_data.py


def _owned(home):
    """Owned contacts and a calendar in the host folder before the host starts (the "survives" twins)."""
    add_owned(home)
    return owned_rows(home)


# ---------------------------------------------------------------- permission


def test_off_by_default_and_turning_on_asks_nothing_and_reads_nothing(make_host, home):
    mac = FakeMac()
    h = make_host(mac)
    with Client(h) as c:
        status = c.get("/status")
        assert status["mac_available"] is True and status["mode"] == "demo"
        src = c.mac()
        assert src["enabled"] is False and src["contacts_status"] == "unknown" and src["notes_included"] is False
        assert src["backups_kept_until"] == kept_until().isoformat()  # what a turn-off dialog says
        assert mac.launches == [] and not socket_path(home).exists()  # nothing runs while it is off

        on(c, mac)
        assert c.get("/status")["mode"] == "real" and h.models.rewarms == 1
        assert [t["name"] for t in c.get("/tools")] == ["find_contact", "list_events"]
        src = c.mac()
        assert (src["contacts_status"], src["calendars_status"]) == ("notDetermined", "notDetermined")
        assert src["reader_running"] is True
        time.sleep(0.2)  # a few maintenance ticks
        assert mac.helper.commands == []  # no prompt, no read: nobody pressed Allow
        assert c.get("/contacts") == [] and c.get("/calendars") == []
        assert mac.launches == [(socket_path(home), None)]


def test_the_first_run_choice_is_recorded_whether_on_or_off(make_host, home):
    """The myData app asks "Use the contacts and calendars on this Mac" once: `decided` turns true on Skip
    (enabled false) as on Allow (enabled true), and survives a restart."""
    h = make_host(FakeMac())
    with Client(h) as c:
        assert c.mac()["decided"] is False
        src = c.put("/sources/mac", {"enabled": False, "contact_containers": None, "calendars": None})
        assert src["decided"] is True and src["enabled"] is False
    h.sources.stop()
    with Client(make_host(FakeMac())) as c:
        assert c.mac()["decided"] is True


def test_allow_grants_then_reads(make_host):
    mac = FakeMac(answer="grant")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        src = c.post("/sources/mac/request-access", {"what": "contacts"})
        assert src["contacts_status"] == "authorized" and src["calendars_status"] == "notDetermined"
        assert wait(lambda: sorted(c.names()) == ALL_NAMES)
        assert mac.helper.commands[:2] == [
            {"cmd": "request_access", "what": "contacts"},
            {"cmd": "read", "what": "contacts", "containers": None, "calendars": None, **{
                "window_start": WINDOW["start"], "window_end": WINDOW["end"]}}]
        assert c.get("/calendars") == []

        src = c.post("/sources/mac/request-access", {"what": "calendars"})
        assert src["calendars_status"] == "fullAccess"
        assert wait(lambda: len(c.get("/calendars")) == 3)
        assert wait(lambda: c.mac()["window"] == WINDOW)


def test_deny_reads_nothing_and_the_tool_says_it_has_no_access(make_host):
    mac = FakeMac(answer="deny")
    h = make_host(mac, scripts=[[[call("list_events", date="March 20")]]])
    with Client(h) as c:
        on(c, mac)
        for what in ("contacts", "calendars"):
            c.post("/sources/mac/request-access", {"what": what})
        src = c.mac()
        assert (src["contacts_status"], src["calendars_status"]) == ("denied", "denied")
        assert [x["cmd"] for x in mac.helper.commands] == ["request_access", "request_access"]
        assert c.get("/contacts") == [] and MAC_ID not in h.sources.contacts.account_ids()
        events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,
                                    json={"text": "What's on March 20?"}).text)
        result = dict(events)["result"]
        assert result["header"] == "myData cannot read the calendars on this Mac: access to them is not allowed."
        assert not result["header"].startswith("No ")
        body = c.get("/events?start=2026-03-20&end=2026-03-20")
        assert body == {"events": [], "coverage": [{"source": "mac", "account_id": "mac", "covered_start": None,
                                                    "covered_end": None, "complete": False, "reason": "no_access"}]}


def test_request_access_needs_the_source_on(make_host):
    h = make_host(FakeMac())
    with Client(h) as c:
        r = c.c.post("/sources/mac/request-access", headers=h.auth, json={"what": "contacts"})
        assert r.status_code == 409 and r.json()["detail"] == "Turn on This Mac first."
        assert c.c.post("/sources/mac/sync", headers=h.auth).status_code == 409
        assert c.c.post("/sources/mac/request-access", headers=h.auth, json={"what": "photos"}).status_code == 422


def test_access_taken_away_deletes_what_was_read(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and len(c.get("/calendars")) == 3)
        mac.status["contacts"] = "denied"  # turned off in System Settings
        mac.helper.send({"type": "status", **mac.status})
        assert wait(lambda: c.names() == [])
        assert len(c.get("/calendars")) == 3  # calendars are still allowed


def test_access_not_asked_yet_keeps_what_was_read(make_host):
    # What macOS reports for a rebuilt (ad hoc signed) myData: not a refusal, so the copy stays, unread.
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and len(c.get("/calendars")) == 3)
        mac.status.update(contacts="notDetermined", calendars="notDetermined")
        mac.helper.send({"type": "status", **mac.status})
        assert wait(lambda: c.mac()["contacts_status"] == "notDetermined")
        assert len(c.names()) == 4 and len(c.get("/calendars")) == 3
        mac.status.update(contacts="unknown", calendars="unknown")  # a status a later macOS adds
        mac.helper.send({"type": "status", **mac.status})
        assert wait(lambda: c.mac()["contacts_status"] == "unknown")
        assert len(c.names()) == 4 and len(c.get("/calendars")) == 3


def test_access_taken_away_survives_owned_data(make_host, home):
    before = _owned(home)
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 + 2 and len(c.get("/calendars")) == 3 + 1)
        mac.status.update(contacts="denied", calendars="denied")
        mac.helper.send({"type": "status", **mac.status})
        assert wait(lambda: sorted(c.names()) == OWNED_NAMES)
        assert wait(lambda: [x["name"] for x in c.get("/calendars")] == ["Kept (owned)"])
    assert owned_rows(home) == before


# ---------------------------------------------------------------- data in, through the stores, tools and API


def test_snapshots_reach_contacts_calendars_events_and_photos(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"] == WINDOW)
        assert sorted(c.names()) == ALL_NAMES
        contacts = c.get("/contacts")
        ava = next(x for x in contacts if x["display_name"] == "Ava Q Fictional")
        assert ava["source"] == "mac" and ava["notes_included"] is False and ava["note"] == ""
        assert ava["account_id"] == MAC_ID and ava["nickname"] == "Avi" and ava["birthday"] == "1990-04-12"
        assert ava["emails"] == [{"value": "ava.fictional@example.com", "label": "home"},
                                 {"value": "ava@work.example.net", "label": "work"}]
        assert ava["phones"] == [{"value": "+1 202 555 0101", "label": "mobile"}] and ava["has_photo"] is True
        assert "NOTE" not in c.get(f"/contacts/{ava['id']}?raw=1")["raw_vcard"]
        assert [x["display_name"] for x in c.get("/contacts?query=fictional")] == ["Ava Q Fictional"]

        r = c.c.get(f"/contacts/{ava['id']}/photo", headers=h.auth)
        assert r.status_code == 200 and r.headers["content-type"] == "image/jpeg" and r.content == data.PHOTO_BYTES
        sam = next(x for x in contacts if x["display_name"] == "Sam Example" and x["emails"])
        assert c.c.get(f"/contacts/{sam['id']}/photo", headers=h.auth).status_code == 404  # initials instead
        assert c.c.get("/contacts/nope/photo", headers=h.auth).status_code == 404

        calendars = {x["name"]: x for x in c.get("/calendars")}
        assert set(calendars) == {"Home", "Work", "Family (shared)"} and calendars["Home"]["color"] == "#1BADF8"
        body = c.get("/events?start=2026-03-16&end=2026-03-31")
        assert body["coverage"] == [{"source": "mac", "account_id": "mac", "covered_start": WINDOW["start"],
                                     "covered_end": WINDOW["end"], "complete": True, "reason": None}]
        events = body["events"]
        assert [(e["title"], e["start"][:16]) for e in events] == [
            ("Team standup", "2026-03-16T09:30"),
            ("Dinner with Ava (invented)", "2026-03-20T19:00"),
            ("Dinner with Ava (invented)", "2026-03-20T19:00"),
            ("Team standup (moved)", "2026-03-24T10:00"),
            ("Lake trip", "2026-03-27"),
        ]
        # The same event in two calendars is two rows: same external id, one per calendar.
        dinners = [e for e in events if e["title"].startswith("Dinner")]
        assert {e["calendar_id"] for e in dinners} == {calendars["Home"]["id"], calendars["Family (shared)"]["id"]}
        assert {e["uid"] for e in dinners} == {"ext-dinner-0001"} and len({e["event_id"] for e in dinners}) == 2
        moved = next(e for e in events if e["title"] == "Team standup (moved)")
        assert moved["recurrence_id"] == "2026-03-23T09:30:00+13:00" and moved["time_zone"] == "Pacific/Auckland"
        trip = next(e for e in events if e["title"] == "Lake trip")
        assert trip["all_day"] is True and trip["end"] == "2026-03-30" and trip["source"] == "mac"
        home_only = c.get(f"/events?start=2026-03-16&end=2026-03-31&calendar={calendars['Home']['id']}")["events"]
        assert [e["title"] for e in home_only] == ["Dinner with Ava (invented)", "Lake trip"]

        src = c.mac()
        assert src["notes_included"] is False and src["last_update"] and src["last_error"] is None
        assert [(x["name"], x["included"]) for x in src["contact_containers"]] == [("iCloud", True), ("On My Mac", True)]
        assert [(x["name"], x["source_name"], x["included"]) for x in src["calendars"]] == [
            ("Home", "iCloud", True), ("Work", "iCloud", True), ("Family (shared)", "On My Mac", True)]
        sync_counts = h.sources.calendar.counts(MAC_ID)
        assert sync_counts == {"calendars": 3, "events": 6}  # the far-future one is outside the window


def test_the_host_asks_for_one_year_back_and_two_ahead_and_records_the_window_the_reader_sends(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: c.mac()["window"] == WINDOW)
        assert mac.helper.commands == [{"cmd": "read", "what": "all", "containers": None, "calendars": None,
                                        "window_start": "2025-03-18", "window_end": "2028-03-18"}]
        time.sleep(0.3)  # many maintenance ticks: the helper re-reads on its own; the host does not repeat it
        assert len(mac.helper.commands) == 1
        # A new day: the helper moves the window and sends a snapshot; the host records the new window.
        items = [o for o in mac.occurrences if o["start"][:4] in ("2025", "2026")]
        mac.helper.send({"type": "events_snapshot", "window_start": "2025-03-19", "window_end": "2028-03-19",
                         "items": items})
        assert wait(lambda: c.mac()["window"] == {"start": "2025-03-19", "end": "2028-03-19"})
        body = c.get("/events?start=2025-03-18&end=2025-03-18")
        assert body["coverage"][0]["complete"] is False and body["coverage"][0]["covered_start"] == "2025-03-19"


def test_choosing_accounts_and_calendars_deletes_what_is_left_out(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and len(c.get("/calendars")) == 3 and c.mac()["window"])

        assert c.mac()["all_calendars"] is True and c.mac()["all_contact_containers"] is True
        src = c.put("/sources/mac", {"calendars": [data.HOME]})
        assert src["all_calendars"] is False and src["all_contact_containers"] is True
        assert [(x["name"], x["included"]) for x in src["calendars"]] == [
            ("Home", True), ("Work", False), ("Family (shared)", False)]
        assert [x["name"] for x in c.get("/calendars")] == ["Home"]  # deleted at once
        assert wait(lambda: mac.helper.last_read["calendars"] == [data.HOME])
        titles = lambda: [e["title"] for e in c.get("/events?start=2026-03-16&end=2026-03-31")["events"]]  # noqa: E731
        assert wait(lambda: titles() == ["Dinner with Ava (invented)", "Lake trip"])

        src = c.put("/sources/mac", {"contact_containers": [data.LOCAL_CONTAINER]})
        assert [(x["name"], x["included"]) for x in src["contact_containers"]] == [("iCloud", False),
                                                                                  ("On My Mac", True)]
        assert sorted(c.names()) == ["Acme Plumbing (Example)", "Sam Example"]
        assert wait(lambda: mac.helper.last_read["containers"] == [data.LOCAL_CONTAINER])
        assert b"ava.fictional" not in (h.home / "contacts.sqlite").read_bytes()  # gone from the file too
        assert c.mac()["enabled"] is True and c.mac()["calendars"][0]["included"] is True  # unset fields kept

        # What the generated client sends: every field, null meaning everything.
        src = c.put("/sources/mac", {"enabled": None, "calendars": None, "contact_containers": None})
        assert src["enabled"] is True and src["all_calendars"] is True and src["all_contact_containers"] is True
        assert wait(lambda: len(c.names()) == 4 and len(c.get("/calendars")) == 3)


def test_choosing_accounts_and_calendars_survives_owned_data(make_host, home):
    before = _owned(home)
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 + 2 and len(c.get("/calendars")) == 3 + 1 and c.mac()["window"])
        c.put("/sources/mac", {"calendars": [data.HOME], "contact_containers": [data.LOCAL_CONTAINER]})
        assert sorted(x["name"] for x in c.get("/calendars")) == ["Home", "Kept (owned)"]
        assert wait(lambda: mac.helper.last_read["calendars"] == [data.HOME])
        assert wait(lambda: sorted(c.names()) == sorted(["Acme Plumbing (Example)", "Sam Example", *OWNED_NAMES]))
        titles = lambda: [e["title"] for e in c.get("/events?start=2026-03-16&end=2026-03-31")["events"]]  # noqa: E731
        assert wait(lambda: titles() == ["Owned picnic (invented)", "Dinner with Ava (invented)", "Lake trip"])
    assert owned_rows(home) == before


def test_a_change_on_the_mac_reaches_the_host(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"])
        before = {e["title"]: e["event_id"] for e in c.get("/events?start=2026-03-16&end=2026-03-31")["events"]}

        mac.contacts[data.LOCAL_CONTAINER].append({"id": "contact-ben-0005", "given_name": "Ben",
                                                   "family_name": "Madeup", "emails": [], "phones": []})
        mac.helper.notify("contacts")
        assert wait(lambda: "Ben Madeup" in c.names())

        mac.occurrences = [o for o in mac.occurrences if o["title"] != "Lake trip"]
        mac.helper.notify("calendars")
        assert wait(lambda: "Lake trip" not in [e["title"] for e in
                                                c.get("/events?start=2026-03-16&end=2026-03-31")["events"]])
        after = {e["title"]: e["event_id"] for e in c.get("/events?start=2026-03-16&end=2026-03-31")["events"]}
        assert after["Team standup"] == before["Team standup"]  # unchanged occurrences keep their id


# ---------------------------------------------------------------- off, stop, restart


def test_turning_off_stops_the_reader_and_deletes_everything(make_host, home):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"])
        helper = mac.helper
        src = c.put("/sources/mac", {"enabled": False})
        assert src["enabled"] is False and src["contact_containers"] == [] and src["calendars"] == []
        assert src["window"] is None and src["last_update"] is None
        assert helper.finished.wait(3) and helper.commands[-1] == {"cmd": "quit"}
        assert not socket_path(home).exists()
        assert c.get("/contacts") == [] and c.get("/calendars") == []
        assert c.get("/events?start=2026-03-16&end=2026-03-31") == {"events": [], "coverage": []}
        assert MAC_ID not in h.sources.contacts.account_ids() and MAC_ID not in h.sources.calendar.account_ids()
        assert c.get("/status")["mode"] == "demo" and h.models.rewarms == 2
        for name in ("contacts.sqlite", "calendar.sqlite", "state.json"):
            raw = (home / name).read_bytes()
            assert b"Fictional" not in raw and b"Dinner" not in raw and b"Example Bistro" not in raw, name
        time.sleep(0.2)
        assert len(mac.launches) == 1  # nothing starts it again


def test_turning_off_survives_owned_data_and_stays_in_real_mode(make_host, home):
    before = _owned(home)
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        assert c.get("/status")["mode"] == "real"  # owned data alone
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 + 2 and c.mac()["window"])
        c.put("/sources/mac", {"enabled": False})
        assert sorted(c.names()) == OWNED_NAMES and [x["name"] for x in c.get("/calendars")] == ["Kept (owned)"]
        assert [e["title"] for e in c.get("/events?start=2026-03-16&end=2026-03-31")["events"]] == [
            "Owned picnic (invented)"]
        assert MAC_ID not in h.sources.contacts.account_ids() and MAC_ID not in h.sources.calendar.account_ids()
        assert c.get("/status")["mode"] == "real"
    assert owned_rows(home) == before


def test_host_stop_quits_the_reader_and_a_crashed_reader_is_started_again(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        first = mac.helper
        first.close()  # the reader crashed
        assert wait(lambda: len(mac.helpers) == 2 and h.sources.mac.connected)
        assert wait(lambda: c.mac()["reader_running"] is True)
    second = mac.helper
    h.sources.stop()
    assert second.finished.wait(3) and second.commands[-1] == {"cmd": "quit"}


def test_a_second_connection_is_refused_while_the_reader_is_connected(make_host, home):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        intruder = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        intruder.connect(str(socket_path(home)))
        intruder.settimeout(3)
        try:
            assert intruder.recv(1) == b""
        except ConnectionResetError:
            pass
        assert h.sources.mac._socket.rejected == 1 and h.sources.mac.connected
        assert wait(lambda: len(c.names()) == 4)


def test_a_reader_that_cannot_be_found_is_reported(make_host):
    mac = FakeMac()
    mac.launcher = FakeLauncher(mac, fail=True)
    h = make_host(mac)
    with Client(h) as c:
        c.put("/sources/mac", {"enabled": True})
        assert wait(lambda: c.mac()["last_error"] == "The reader was not found. Open the myData app once, so the "
                                                     "host can find it.")
        assert wait(lambda: len(mac.launches) >= 2)  # retried


def test_the_reader_path_from_the_app_is_checked_and_used(make_host, home):
    import plistlib
    mac = FakeMac()
    h = make_host(mac)
    import os
    app = home / "Applications" / "myData.app" / "Contents" / "Helpers" / "myDataReader.app"
    (app / "Contents").mkdir(parents=True)
    with (app / "Contents" / "Info.plist").open("wb") as fh:
        plistlib.dump({"CFBundleIdentifier": "kiwi.mydata.reader"}, fh)
    with (app.parents[2] / "Contents" / "Info.plist").open("wb") as fh:
        plistlib.dump({"CFBundleIdentifier": "kiwi.mydata.mydata"}, fh)
    # The reader's bundle id inside an app that is not myData: refused.
    other = home / "NotMyData.app" / "Contents" / "Helpers" / "myDataReader.app"
    (other / "Contents").mkdir(parents=True)
    with (other / "Contents" / "Info.plist").open("wb") as fh:
        plistlib.dump({"CFBundleIdentifier": "kiwi.mydata.reader", "CFBundleExecutable": "anything"}, fh)
    with Client(h) as c:
        r = c.c.put("/sources/mac/reader", headers=h.auth, json={"path": str(home / "evil.app")})
        assert r.status_code == 400
        r = c.c.put("/sources/mac/reader", headers=h.auth, json={"path": str(other)})
        assert r.status_code == 400 and "not inside the myData app" in r.json()["detail"]
        c.put("/sources/mac/reader", {"path": str(app)})
        on(c, mac)
        assert mac.launches[-1] == (socket_path(home), Path(os.path.realpath(app)))


def test_status_survives_a_restart(make_host, home):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: c.mac()["window"] and len(c.names()) == 4)
        r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                        "password": fake_dav.PASSWORD})
        account = r.json()["id"]
        h.sources.sync_account(account)
        before_mac, before_icloud = c.mac(), h.sources.account_status(account)
        assert before_icloud["last_success"] and before_icloud["counts"]["contacts"] == 6
    h.sources.stop()

    again = SyncService(home, Accounts(home, h.secrets), platform="darwin", mac_launcher=FakeLauncher(FakeMac()))
    restored = again.account_status(account)
    assert {k: restored[k] for k in ("last_success", "last_error", "last_attempt", "counts", "state")} == \
        {k: before_icloud[k] for k in ("last_success", "last_error", "last_attempt", "counts", "state")}
    mac_after = again.mac.public()
    assert mac_after["enabled"] is True and mac_after["last_update"] == before_mac["last_update"]
    assert mac_after["window"] == WINDOW and mac_after["contacts_status"] == "authorized"
    assert again.any_source_on()


def test_mac_rows_are_never_taken_for_a_removed_accounts_leftovers(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4)
        r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                        "password": fake_dav.PASSWORD})
        c.c.delete(f"/accounts/{r.json()['id']}", headers=h.auth)
        assert len(c.names()) == 4 and c.get("/status")["mode"] == "real"  # This Mac is still on


def test_removing_an_account_beside_this_mac_survives_owned_data(make_host, home):
    before = _owned(home)
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 + 2)
        r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                        "password": fake_dav.PASSWORD})
        h.sources.sync_account(r.json()["id"])
        c.c.delete(f"/accounts/{r.json()['id']}", headers=h.auth)
        assert len(c.names()) == 4 + 2
    assert owned_rows(home) == before


# ---------------------------------------------------------------- the window rule, through the assistant


@pytest.mark.parametrize("phrase, header", [
    ("March 20", "2 events on Friday 20 March"),
    # partly outside: counted only for the days held, and says which days those are
    ("from March 13 2028 to March 24 2028",
     "No events from Monday 13 to Saturday 18 March. Events on this Mac are kept from 18 Mar 2025 to 18 Mar 2028."),
    # entirely outside: never "No events"
    ("January 10 2029", "Events on this Mac are kept from 18 Mar 2025 to 18 Mar 2028; that date is outside it."),
    ("March 2024", "Events on this Mac are kept from 18 Mar 2025 to 18 Mar 2028; those dates are outside it."),
])
def test_list_events_never_says_nothing_found_for_days_it_does_not_hold(make_host, phrase, header):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, scripts=[[[call("list_events", date=phrase)]]])
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: c.mac()["window"] == WINDOW)
        events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,
                                    json={"text": f"What's on {phrase}?"}).text)
        assert dict(events)["result"]["header"] == header


def test_the_tool_result_says_which_days_are_held(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: c.mac()["window"] == WINDOW)
        tool = h.assistant.registry.get("list_events")
        from mydata.tools.dates import Resolved
        inside = tool.handler({}, {"date": Resolved(date(2026, 3, 20), date(2026, 3, 20))}, TODAY).data
        assert "outside_window" not in inside and len(inside["events"]) == 2
        partly = tool.handler({}, {"date": Resolved(date(2028, 3, 1), date(2028, 3, 31))}, TODAY).data
        assert partly["outside_window"] is True and partly["covered"] == WINDOW
        outside = tool.handler({}, {"date": Resolved(date(2029, 1, 10), date(2029, 1, 10))}, TODAY).data
        assert outside == {"from": "2029-01-10", "to": "2029-01-10", "events": [], "outside_window": True,
                           "covered": WINDOW}
        body = c.get("/events?start=2028-03-01&end=2028-03-31")
        assert body["coverage"][0]["complete"] is False and body["coverage"][0]["covered_end"] == WINDOW["end"]


KEPT = "Events on this Mac are kept from 18 Mar 2025 to 18 Mar 2028"


@pytest.mark.parametrize("phrase, header", [
    # Outside the Mac's window: the iCloud account holds those days, the Mac's other calendars do not.
    ("January 10 2029", f"No events in your iCloud calendars on Wednesday 10 January. {KEPT}."),
    ("April 12 2029", f"1 event in your iCloud calendars on Thursday 12 April. {KEPT}."),
    # Partly inside: every day for iCloud, the held days for the Mac, and it says so.
    ("from March 13 2028 to April 30 2028",
     f"1 event from Monday 13 March to Sunday 30 April. {KEPT}; on other days only your iCloud calendars are shown."),
    # inside: both sources (the Mac's dinner in two calendars, iCloud's dentist), no limit to mention
    ("March 20", "3 events on Friday 20 March"),
])
def test_an_icloud_account_never_hides_the_macs_window(make_host, phrase, header):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, scripts=[[[call("list_events", date=phrase)]]])
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: c.mac()["window"] == WINDOW)
        r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                        "password": fake_dav.PASSWORD})
        h.sources.sync_account(r.json()["id"])
        events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,
                                    json={"text": f"What's on {phrase}?"}).text)
        assert dict(events)["result"]["header"] == header
        body = c.get("/events?start=2029-01-10&end=2029-01-10")
        assert {(x["source"], x["complete"]) for x in body["coverage"]} == {("icloud", True), ("mac", False)}
        assert next(x for x in body["coverage"] if x["source"] == "mac")["covered_end"] == WINDOW["end"]


def test_the_macs_events_count_only_on_the_days_it_holds():
    """With another source holding every asked day, list_events reads them all, but a Mac event outside the
    Mac's window (which the store should not hold anyway) is never shown as if the Mac held that day."""
    from mydata.tools.dates import Resolved
    from mydata.tools.mirror import held_range, mirror_tools

    rows = [{"event_id": "e1", "calendar_id": "k1", "uid": "u1", "recurrence_id": None, "title": "Kept (invented)",
             "location": "", "notes": "", "start": "2028-03-18T09:00:00+13:00", "end": "2028-03-18T10:00:00+13:00",
             "all_day": False, "time_zone": None, "source": "mac"},
            {"event_id": "e2", "calendar_id": "k1", "uid": "u2", "recurrence_id": None, "title": "Stale (invented)",
             "location": "", "notes": "", "start": "2028-03-25T09:00:00+13:00", "end": "2028-03-25T10:00:00+13:00",
             "all_day": False, "time_zone": None, "source": "mac"},
            {"event_id": "e3", "calendar_id": "k2", "uid": "u3", "recurrence_id": None, "title": "iCloud (invented)",
             "location": "", "notes": "", "start": "2028-03-25T09:00:00+13:00", "end": "2028-03-25T10:00:00+13:00",
             "all_day": False, "time_zone": None, "source": "icloud"}]

    class Calendar:
        def events_between(self, start, end, calendar_ids=None, tz=None):
            return rows

    def coverage(start, end):
        return [{"source": "icloud", "account_id": "a", "covered_start": None, "covered_end": None, "complete": True},
                {"source": "mac", "account_id": "mac", "covered_start": "2025-03-18", "covered_end": "2028-03-18",
                 "complete": end <= date(2028, 3, 18)}]

    from zoneinfo import ZoneInfo
    tool = next(t for t in mirror_tools(None, Calendar(), tz=lambda: ZoneInfo("Pacific/Auckland"), coverage=coverage)
                if t.name == "list_events")
    out = tool.handler({}, {"date": Resolved(date(2028, 3, 13), date(2028, 3, 31))}, TODAY).data
    assert [e["title"] for e in out["events"]] == ["Kept (invented)", "iCloud (invented)"]
    assert out["outside_window"] is True and out["complete_sources"] == ["icloud"]
    # Per source: one complete source never makes the range "all held".
    held = held_range(coverage(date(2029, 1, 1), date(2029, 1, 7)), date(2029, 1, 1), date(2029, 1, 7))
    assert held.limit["source"] == "mac" and held.days is None and held.complete == ("icloud",)


@pytest.mark.parametrize("icloud", [False, True])
def test_calendars_listed_but_no_events_snapshot_is_never_read_as_empty(make_host, icloud):
    """The helper lists the Mac's calendars, then EventKit fails (or the events have not arrived yet): the
    Mac holds no day, so list_events never says "No events" for the Mac, and /events marks it incomplete."""
    mac = FakeMac("authorized", "fullAccess")
    mac.events_fail = True
    h = make_host(mac, scripts=[[[call("list_events", date="January 10 2031")]], [[call("list_events",
                                                                                         date="March 20")]]])
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.get("/calendars")) == 3)  # the calendars are stored
        assert wait(lambda: "reported a problem" in (c.mac()["last_error"] or ""))
        assert c.mac()["window"] is None
        if icloud:
            r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                            "password": fake_dav.PASSWORD})
            h.sources.sync_account(r.json()["id"])
        not_read = "The calendars on this Mac have not been read yet"
        for text in ("What's on January 10 2031?", "What's on March 20?"):
            events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,
                                        json={"text": text}).text)
            header = dict(events)["result"]["header"]
            assert not_read in header, header
            assert icloud or not header.startswith("No ")
        body = c.get("/events?start=2031-01-10&end=2031-01-10")
        mac_rows = [x for x in body["coverage"] if x["source"] == "mac"]
        assert mac_rows == [{"source": "mac", "account_id": "mac", "covered_start": None, "covered_end": None,
                             "complete": False, "reason": "not_read_yet"}]
        assert h.sources.calendar.coverage(date(2031, 1, 10), date(2031, 1, 10)) == (
            [{"source": "icloud", "account_id": h.sources.accounts.list()[0].id, "covered_start": None,
              "covered_end": None, "complete": True}] if icloud else [])


# ---------------------------------------------------------------- not a Mac


def test_on_other_systems_this_mac_is_absent_not_broken(make_host):
    h = make_host(platform="linux")
    assert h.sources.mac is None
    with Client(h) as c:
        assert c.get("/sources")["sources"] == []
        assert c.get("/status")["mac_available"] is False
        for method, path, body in (("PUT", "/sources/mac", {"enabled": True}),
                                   ("POST", "/sources/mac/request-access", {"what": "contacts"}),
                                   ("POST", "/sources/mac/sync", None), ("PUT", "/sources/mac/reader", {"path": "/x"})):
            r = c.c.request(method, path, headers=h.auth, json=body)
            assert r.status_code == 404 and "not a Mac" in r.json()["detail"], path
        r = c.c.post("/accounts", headers=h.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                        "password": fake_dav.PASSWORD})
        (src,) = c.get("/sources")["sources"]
        assert src["kind"] == "icloud" and src["email"] == fake_dav.USERNAME and src["notes_included"] is True
        assert src["id"] == r.json()["id"]


# ---------------------------------------------------------------- privacy


def test_logs_and_the_request_log_hold_no_photo_and_no_mirrored_data(make_host, caplog):
    caplog.set_level(logging.DEBUG)
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, scripts=[[[call("find_contact", name="Ava")]], [[call("list_events", date="March 20")]]])
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"])
        for text in ("Find Ava", "What's on March 20?"):
            events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,
                                        json={"text": text}).text)
            assert dict(events)["result"]["items"]
    logged = (h.home / "logs" / "assistant.jsonl").read_text()
    for text in (logged, caplog.text):
        assert data.PHOTO_BASE64[:24] not in text and "invented-photo-bytes" not in text
        assert "ava.fictional@example.com" not in text and "Example Bistro" not in text
        assert "Dinner with Ava" not in text and "Fictional" not in text


def test_a_message_over_the_size_limit_is_reported_and_the_reader_restarted(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, mac_options={"max_line": 4096})
    with Client(h) as c:
        on(c, mac)
        mac.helper.send({"type": "error", "message": "x" * 10_000})
        assert wait(lambda: "more than the host takes in one piece" in (c.mac()["last_error"] or ""))
        assert wait(lambda: len(mac.helpers) >= 2)


SLOW = (0.05, 0.4, 0.8, 2.5)  # relaunch pauses long enough to see which one was used


def test_a_reader_that_fails_the_same_way_every_time_backs_off(make_host):
    """An over-long snapshot fails again on every read, so the host goes straight to the longest pause
    instead of restarting the reader every few seconds; Sync now tries at once."""
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, mac_options={"max_line": 4096, "relaunch": SLOW})
    mac.contacts[data.ICLOUD_CONTAINER] = mac.contacts[data.ICLOUD_CONTAINER] * 40  # far over 4 KB
    with Client(h) as c:
        c.put("/sources/mac", {"enabled": True})  # it connects, reads, and is dropped at once
        assert wait(lambda: "more than the host takes in one piece" in (c.mac()["last_error"] or ""))
        started = time.monotonic()
        assert wait(lambda: len(mac.helpers) >= 2, timeout=5)
        assert time.monotonic() - started >= 2.0  # the longest pause, not the first (0.05 s)
        assert wait(lambda: mac.helpers[1].finished.is_set(), timeout=5)  # it failed again
        time.sleep(1.0)
        assert len(mac.helpers) == 2  # and waits the longest pause again
        c.post("/sources/mac/sync", status=202)
        assert wait(lambda: len(mac.helpers) == 3, timeout=1)


def test_the_pauses_grow_until_a_snapshot_is_stored(make_host):
    """A hello alone does not prove the reader works: one that says hello and then crashes is restarted
    after growing pauses. A stored snapshot resets them."""
    mac = FakeMac()  # nothing allowed yet: the helper says hello and is not asked to read
    h = make_host(mac, mac_options={"relaunch": SLOW})
    with Client(h) as c:
        c.put("/sources/mac", {"enabled": True})
        times = []
        for n in range(1, 4):
            assert wait(lambda: len(mac.helpers) == n and mac.helper.connected.is_set(), timeout=5)
            assert wait(lambda: h.sources.mac.connected, timeout=5)  # said hello
            times.append(time.monotonic())
            mac.helper.close()  # then crashed
        gaps = [b - a for a, b in zip(times, times[1:])]
        assert gaps[0] < 0.35 and gaps[1] >= 0.35  # 0.05 s, then 0.4 s: not reset by the hello
        assert wait(lambda: len(mac.helpers) == 4 and h.sources.mac.connected, timeout=5)

        mac.status = {"contacts": "authorized", "calendars": "fullAccess"}
        mac.helper.send({"type": "status", **mac.status})  # allowed in System Settings: the host reads
        assert wait(lambda: c.mac()["window"] == WINDOW and len(c.names()) == 4)
        assert h.sources.mac._failures == 0
        before = time.monotonic()
        mac.helper.close()
        assert wait(lambda: len(mac.helpers) == 5, timeout=5)
        assert time.monotonic() - before < 0.35  # the short pause again


def test_snapshots_in_parts_are_stored_when_the_last_part_arrives(make_host):
    mac = FakeMac("authorized", "fullAccess")
    mac.part_size = 1
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: sorted(c.names()) == ALL_NAMES and c.mac()["window"] == WINDOW)
        assert len(c.get("/events?start=2025-05-01&end=2026-04-30")["events"]) == 6

        # A part goes missing: nothing is replaced, and the rows stay as they were.
        helper = mac.helper
        ava = data.CONTACTS[data.ICLOUD_CONTAINER][0]
        helper.send({"type": "contacts_snapshot", "container_id": data.ICLOUD_CONTAINER, "part": 0, "last": False,
                     "items": [ava]})
        helper.send({"type": "contacts_snapshot", "container_id": data.ICLOUD_CONTAINER, "part": 2, "last": True,
                     "items": []})
        # Parts of an empty snapshot replace everything with nothing only once the last one is in.
        helper.send({"type": "events_snapshot", "window_start": WINDOW["start"], "window_end": WINDOW["end"],
                     "part": 0, "last": False, "items": []})
        time.sleep(0.3)
        assert sorted(c.names()) == ALL_NAMES
        assert len(c.get("/events?start=2025-05-01&end=2026-04-30")["events"]) == 6
        helper.send({"type": "events_snapshot", "window_start": WINDOW["start"], "window_end": WINDOW["end"],
                     "part": 1, "last": True, "items": []})
        assert wait(lambda: c.get("/events?start=2025-05-01&end=2026-04-30")["events"] == [])


def test_a_status_from_a_later_macos_does_not_strand_the_reader(make_host):
    mac = FakeMac("someStateFromALaterMacOS", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        on(c, mac)  # the hello was taken
        src = c.mac()
        assert (src["contacts_status"], src["calendars_status"]) == ("unknown", "fullAccess")
        assert wait(lambda: c.mac()["window"] == WINDOW)  # calendars are read
        assert c.get("/contacts") == []  # contacts are not: "unknown" is not readable


def test_a_broken_run_folder_is_reported_not_retried_in_a_loop(make_host, home, caplog):
    caplog.set_level(logging.WARNING)
    (home / "run").write_text("not a folder")
    mac = FakeMac()
    h = make_host(mac)
    with Client(h) as c:
        c.put("/sources/mac", {"enabled": True})
        assert wait(lambda: "run folder" in (c.mac()["last_error"] or ""))
        assert mac.launches == []
    assert "source loop failed" not in caplog.text


# ---------------------------------------------------------------- what the apps are shown


def test_result_items_carry_what_opens_them_in_their_own_app(make_host):
    """myAssistant opens a contact in myContacts by its id and an event's day in myCalendar: in real mode the
    result event says so ("mode": "real"), a contact item carries the id GET /contacts gives, and an event item
    its local day."""
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac, scripts=[[[call("find_contact", name="Ava")]], [[call("list_events", date="March 24")]]])
    with Client(h) as c:
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"] == WINDOW)
        ava_id = next(x["id"] for x in c.get("/contacts") if x["display_name"] == "Ava Q Fictional")

        events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,

                                    json={"text": "Ava's details"}).text)
        result = dict(events)["result"]
        assert result["mode"] == "real" and result["kind"] == "contacts"
        assert [i["id"] for i in result["items"]] == [ava_id]
        assert c.get(f"/contacts/{ava_id}")["display_name"] == "Ava Q Fictional"  # the id myContacts opens

        events = parse_sse(c.c.post("/assistant/messages", headers=h.assistant_auth,

                                    json={"text": "What's on March 24?"}).text)
        result = dict(events)["result"]
        assert result["mode"] == "real" and [i["date"] for i in result["items"]] == ["2026-03-24"]


def test_sources_report_what_this_mac_holds_while_it_is_on(make_host):
    mac = FakeMac("authorized", "fullAccess")
    h = make_host(mac)
    with Client(h) as c:
        assert c.mac()["counts"] is None  # off: it holds nothing
        on(c, mac)
        assert wait(lambda: len(c.names()) == 4 and c.mac()["window"] == WINDOW)
        assert c.mac()["counts"] == {"address_books": 2, "contacts": 4, "calendars": 3, "events": 6}
        c.put("/sources/mac", {"enabled": False})
        assert c.mac()["counts"] is None
