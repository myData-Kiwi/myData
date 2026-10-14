"""End to end, through the host as mydatad builds it: link an iCloud account (the fake server), let the
sync thread mirror it, read it back through the API, ask the assistant in real mode, then remove the
account and find the host back in demo mode with nothing left behind. Invented data only."""

from __future__ import annotations

import time

import pytest
from starlette.testclient import TestClient

import fake_dav
from fake_dav import FakeDav
from mydata.orchestrator.engine import SYSTEM_PROMPT
from mydata.service.modes import REAL_SYSTEM_PROMPT
from mydata.tools import TOOLS

from service_helpers import Host, call, parse_sse

SAM = [[call("find_contact", name="Sam")]]
MARCH_24 = [[call("list_events", date="March 24")], {"content": "Just the standup, moved to Tuesday."}]


def _wait(predicate, timeout=15.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.05)
    return False


@pytest.fixture
def host(tmp_path, monkeypatch):
    monkeypatch.setenv("TZ", "Pacific/Auckland")  # the host's local zone, read by the mirror and /events
    h = Host(tmp_path, FakeDav(), scripts=[SAM, MARCH_24])
    h.sources.poll = 0.05
    h.sources.start()
    yield h
    h.sources.stop()


def test_link_sync_read_ask_and_remove(host):
    with TestClient(host.app, base_url="http://127.0.0.1") as c:
        get = lambda path: c.get(path, headers=host.auth)  # noqa: E731
        assert get("/status").json()["mode"] == "demo"
        assert get("/status").json()["demo_date"] is True

        # ---- link: verified against the fake iCloud, then synced by the background thread
        r = c.post("/accounts", headers=host.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                          "password": fake_dav.PASSWORD})
        assert r.status_code == 201, r.text
        account_id = r.json()["id"]
        status = get("/status").json()
        assert status["mode"] == "real" and status["demo_date"] is False and status["today"] == "2026-03-18"
        assert [t["name"] for t in get("/tools").json()] == ["find_contact", "list_events"]
        assert host.models.rewarms == 1
        assert _wait(lambda: (get("/sync").json()["accounts"] or [{}])[0].get("last_success"))
        sync = get("/sync").json()
        assert sync["mode"] == "real"
        (acct,) = sync["accounts"]
        assert acct["account_id"] == account_id and acct["state"] == "idle" and acct["last_error"] is None
        assert acct["counts"] == {"address_books": 1, "contacts": 6, "calendars": 3, "events": 5}
        assert acct["next_attempt"] > acct["last_success"]

        # ---- contacts
        contacts = get("/contacts").json()
        assert [x["display_name"] for x in contacts] == ["Acme Plumbing (Example)", "Ava Fictional", "Ben Madeup",
                                                         "Sam Example", "Sam Example", "someone@example.net"]
        ava = next(x for x in contacts if x["display_name"] == "Ava Fictional")
        assert ava["emails"][0] == {"value": "ava.fictional@example.com", "label": "home"}
        assert ava["has_photo"] is True and ava["account_id"] == account_id and ava["deleted_at"] is None
        assert {x["id"] for x in get("/contacts?query=sam").json()} == {x["id"] for x in contacts[3:5]}
        assert [x["display_name"] for x in get("/contacts?limit=2&offset=1").json()] == ["Ava Fictional",
                                                                                         "Ben Madeup"]
        detail = get(f"/contacts/{ava['id']}").json()
        assert detail["raw_vcard"] is None and detail["nickname"] == "Avi" and detail["birthday"] == "1990-04-12"
        raw = get(f"/contacts/{ava['id']}?raw=1").json()["raw_vcard"]
        assert raw.startswith("BEGIN:VCARD") and "PHOTO" in raw  # the photo stays in the raw card

        # ---- calendars and expanded events (reminders, a VTODO-only list, is not mirrored)
        calendars = get("/calendars").json()
        assert sorted(x["name"] for x in calendars) == ["Holidays (example)", "Home", "Work"]
        work = next(x["id"] for x in calendars if x["name"] == "Work")
        body = get("/events?start=2026-03-02&end=2026-03-31").json()
        assert body["coverage"] == [{"source": "icloud", "account_id": account_id, "covered_start": None,
                                     "covered_end": None, "complete": True, "reason": None}]
        events = body["events"]
        assert {e["source"] for e in events} == {"icloud"}
        assert [(e["title"], e["start"][:16]) for e in events] == [
            ("Team standup", "2026-03-02T09:30"),
            ("Team standup", "2026-03-09T09:30"),  # 16 March is an EXDATE
            ("Made-up Day", "2026-03-18"),
            ("Dentist (invented)", "2026-03-20T15:00"),  # 02:00 UTC is 15:00 in Auckland (NZDT)
            ("Team standup (moved)", "2026-03-24T10:00"),  # the override replaces 23 March
            ("Lake trip", "2026-03-27"),
            ("Team standup", "2026-03-30T09:30"),
        ]
        lake = next(e for e in events if e["title"] == "Lake trip")
        assert lake["all_day"] is True and lake["end"] == "2026-03-30"  # exclusive end
        moved = next(e for e in events if e["title"] == "Team standup (moved)")
        assert moved["recurrence_id"].startswith("2026-03-23T09:30") and moved["time_zone"] == "Pacific/Auckland"
        only_work = get(f"/events?start=2026-03-02&end=2026-03-31&calendar={work}").json()["events"]
        assert {e["calendar_id"] for e in only_work} == {work} and len(only_work) == 4

        # ---- the assistant, in real mode: an ambiguous name makes the code ask
        events = parse_sse(c.post("/assistant/messages", headers=host.auth,
                                  json={"text": "Find Sam", "conversation_id": "c1"}).text)
        kinds = [k for k, _ in events]
        assert "clarify" in kinds
        clarify = dict(events)["clarify"]
        assert [o["name"] for o in clarify["options"]] == ["Sam Example", "Sam Example"]
        assert {o["email"] for o in clarify["options"]} == {"sam.example@example.com", None}

        # ---- ... and a date phrase lists the expanded occurrences
        events = parse_sse(c.post("/assistant/messages", headers=host.auth,
                                  json={"text": "What's on March 24?", "conversation_id": "c1"}).text)
        result = dict(events)["result"]
        assert result["kind"] == "events" and result["header"] == "1 event on Tuesday 24 March"
        assert result["items"] == [{"title": "Team standup (moved)", "date": "2026-03-24", "day": "Tuesday 24 March",
                                    "start": "10:00", "end": "10:15", "location": None}]
        assert dict(events)["message"]["outcome"] == "answered"
        assert host.tools_seen and all(seen == ["find_contact", "list_events"] for seen in host.tools_seen)
        assert host.assistant.system_prompt == REAL_SYSTEM_PROMPT
        assert "sam.example@example.com" in str(host.assistant.history("c1"))  # the clarify options

        # The request log says the mode, and in real mode holds no mirrored data.
        logged = (host.assistant.settings.log_dir / "assistant.jsonl").read_text()
        assert logged.count('"mode": "real"') == 2
        assert "sam.example@example.com" not in logged and "Team standup" not in logged

        # ---- remove: data and secret gone, back to demo mode, the conversation ended with it
        r = c.delete(f"/accounts/{account_id}", headers=host.auth)
        assert r.status_code == 200 and r.json()["id"] == account_id
        assert get("/accounts").json() == [] and get("/contacts").json() == [] and get("/calendars").json() == []
        assert get("/events?start=2026-03-01&end=2026-03-31").json() == {"events": [], "coverage": []}
        assert get("/sync").json() == {"mode": "demo", "accounts": []}
        assert [s["kind"] for s in get("/sources").json()["sources"]] == (["mac"] if host.sources.mac_available
                                                                          else [])
        status = get("/status").json()
        assert status["mode"] == "demo" and status["demo_date"] is True and status["today"] == "2026-03-18"
        assert [t["name"] for t in get("/tools").json()] == list(TOOLS)
        assert host.assistant.system_prompt == SYSTEM_PROMPT and host.models.rewarms == 2
        assert host.assistant.history("c1") == []  # it held the removed account's contacts

    assert host.secrets.keys() == []
    assert host.sources.contacts.account_ids() == [] and host.sources.calendar.account_ids() == []
    assert host.sources.status() == []


def test_link_sync_and_remove_survives_owned_data(tmp_path, monkeypatch):
    """Twin of the test above with owned contacts and a calendar on the host from the start: the host is in
    real mode for them alone, linking and removing an account leaves them as they were, and the host stays in
    real mode afterwards."""
    from owned_data import add_owned, owned_rows

    monkeypatch.setenv("TZ", "Pacific/Auckland")
    add_owned(tmp_path)
    before = owned_rows(tmp_path)
    host = Host(tmp_path, FakeDav())
    host.sources.poll = 0.05
    host.sources.start()
    try:
        with TestClient(host.app, base_url="http://127.0.0.1") as c:
            get = lambda path: c.get(path, headers=host.auth)  # noqa: E731
            assert get("/status").json()["mode"] == "real"  # owned data is the user's: no demo data over it
            warms = host.models.rewarms
            r = c.post("/accounts", headers=host.auth, json={"provider": "icloud", "email": fake_dav.USERNAME,
                                                              "password": fake_dav.PASSWORD})
            account_id = r.json()["id"]
            assert _wait(lambda: (get("/sync").json()["accounts"] or [{}])[0].get("last_success"))
            assert len(get("/contacts").json()) == 6 + 2
            assert c.delete(f"/accounts/{account_id}", headers=host.auth).status_code == 200
            assert [x["display_name"] for x in get("/contacts").json()] == ["Olive Owned", "Pip Keepsake"]
            assert [x["name"] for x in get("/calendars").json()] == ["Kept (owned)"]
            assert get("/status").json()["mode"] == "real" and host.models.rewarms == warms  # no switch
    finally:
        host.sources.stop()
    assert owned_rows(tmp_path) == before
