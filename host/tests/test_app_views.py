"""What myContacts and myCalendar read from the host: their own app tokens (which can read but never stop
the host), the contact list's letters and captions, a contact's page grouped by kind, and the calendar list
grouped by source with each This Mac calendar's account. Invented data only (tests/fake_dav, tests/fake_mac)."""

from __future__ import annotations

import shutil
import socket
import stat
import sys
import tempfile
import time
from pathlib import Path

import pytest
from starlette.testclient import TestClient

import fake_dav
from fake_dav import FakeDav
from fake_mac import FakeMac
from mydata.service.auth import APPS, LIFETIME_APPS, ensure_app_tokens
from mydata.sources.views import (account_caption, contact_caption, contact_fields, data_colour, display_label,
                                  sort_letter, source_heading, source_in_sentence)

from service_helpers import Host

BODY = {"provider": "icloud", "email": fake_dav.USERNAME, "password": fake_dav.PASSWORD}


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


def bearer(home: Path, app: str) -> dict:
    return {"Authorization": f"Bearer {(home / 'app-tokens' / app).read_text().strip()}"}


# ---------------------------------------------------------------- app tokens


@pytest.mark.skipif(sys.platform.startswith("win"), reason="POSIX permissions")
def test_mycontacts_and_mycalendar_get_their_own_private_tokens(tmp_path):
    tokens = ensure_app_tokens(tmp_path)
    assert {"mycontacts", "mycalendar"} <= set(APPS) and set(LIFETIME_APPS) == {"mydata", "cli"}
    assert len(set(tokens.values())) == len(APPS)
    for app in ("mycontacts", "mycalendar"):
        assert stat.S_IMODE((tmp_path / "app-tokens" / app).stat().st_mode) == 0o600


def test_each_app_reads_what_it_shows_and_never_stops_the_host(home):
    """Their tokens are made by the host as mydatad builds it. (That host's /shutdown really stops the test
    process, so only refusals are tried here; tests/test_app_support.py shows the myData app may stop it.)
    tests/test_scopes.py has every route for every app."""
    h = Host(home, FakeDav())
    reads = {"mycontacts": ("/status", "/appearance", "/sources", "/contacts"),
             "mycalendar": ("/status", "/appearance", "/sources", "/calendars",
                            "/events?start=2026-03-01&end=2026-03-31"),
             "myassistant": ("/status", "/appearance", "/contacts", "/calendars",
                             "/events?start=2026-03-01&end=2026-03-31", "/approvals")}
    with TestClient(h.app, base_url="http://127.0.0.1") as c:
        for app, paths in reads.items():
            auth = bearer(home, app)
            for path in paths:
                assert c.get(path, headers=auth).status_code == 200, (app, path)
            r = c.post("/shutdown", headers=auth)
            assert r.status_code == 403, app
            assert r.json()["detail"] == "only the myData app can stop the host"
        # Each reads only its own kind of data.
        assert c.get("/calendars", headers=bearer(home, "mycontacts")).status_code == 403
        assert c.get("/contacts", headers=bearer(home, "mycalendar")).status_code == 403
        assert c.get("/sources", headers=bearer(home, "myassistant")).status_code == 403


def test_mycontacts_and_mycalendar_tokens_only_read(home):
    """myContacts writes only the contacts the host owns (tests/test_contacts_api.py) and myCalendar writes
    nothing: their scopes reach no other route that changes anything, so their tokens cannot approve (or even list) held calls, mint an agent token, link or remove an account,
    change This Mac (or ask macOS for access), change settings, talk to the assistant or use /mcp.
    myAssistant's token can approve and the myData app's can change sources (the routes answer something
    other than 403)."""
    h = Host(home, FakeDav())
    writes = [
        ("get", "/approvals", None),
        ("post", "/approvals/nope", {"decision": "approve"}),
        ("post", "/agents", {"name": "Example agent"}),
        ("delete", "/agents/nope", None),
        ("post", "/accounts", BODY),
        ("delete", "/accounts/nope", None),
        ("post", "/accounts/nope/sync", None),
        ("put", "/sources/mac", {"enabled": True}),
        ("post", "/sources/mac/request-access", None),
        ("post", "/sources/mac/sync", None),
        ("put", "/appearance", {"theme": "graphite"}),
        ("put", "/assistant/settings", {"enabled": True}),
        ("post", "/assistant/messages", {"text": "hello"}),
        ("post", "/model/retry", None),
        ("post", "/mcp", {"jsonrpc": "2.0", "id": 1, "method": "tools/list"}),
        ("post", "/shutdown", None),
    ]
    with TestClient(h.app, base_url="http://127.0.0.1") as c:
        for app in ("mycontacts", "mycalendar"):
            auth = bearer(home, app)
            for method, path, body in writes:
                kwargs = {"headers": auth} if body is None else {"headers": auth, "json": body}
                r = getattr(c, method)(path, **kwargs)
                assert r.status_code == 403, (app, method, path, r.status_code)
                assert r.json()["detail"].startswith(f"the {app} app cannot use") or path == "/shutdown", (app, path)
            assert c.get("/status", headers=auth).status_code == 200
        assert c.post("/approvals/nope", headers=bearer(home, "myassistant"),
                      json={"decision": "approve"}).status_code == 404
        assert c.put("/sources/mac", headers=bearer(home, "myassistant"), json={"enabled": False}).status_code == 403
        assert c.put("/sources/mac", headers=h.auth, json={"enabled": False}).status_code != 403


def test_the_contact_list_is_in_order_ignoring_case_and_accents(home):
    """SQLite's NOCASE folds ASCII only, so "Émile" and "Ölaf" used to come after "Zed" and split their
    letter groups. The host orders by the name without accents, and each letter group stays together."""
    from mydata.sources.dav.discovery import Collection
    from mydata.sources.dav.sync import CollectionState, Item, SyncResult

    h = Host(home, FakeDav())
    names = ["Zed Example", "Ölaf Example", "Eve Example", "émile Example", "Ava Example", "Élodie Example",
             "Ezra Example", "oscar Example", "+1 202 555 0123"]
    items = [Item(href=f"/ab/{i}.vcf", etag='"1"',
                  data=f"BEGIN:VCARD\r\nVERSION:3.0\r\nUID:x-{i}\r\nFN:{n}\r\nEND:VCARD\r\n")
             for i, n in enumerate(names)]
    h.sources.contacts.apply("acct-1", Collection("https://dav.example.com/ab/", "contacts", "Contacts"),
                             SyncResult(changed=items, deleted=[], state=CollectionState(), full=True))
    with TestClient(h.app, base_url="http://127.0.0.1") as c:
        rows = c.get("/contacts", headers=h.auth).json()
        paged = c.get("/contacts?limit=4", headers=h.auth).json() + \
            c.get("/contacts?limit=100&offset=4", headers=h.auth).json()
    order = [r["display_name"] for r in rows]
    assert order == ["+1 202 555 0123", "Ava Example", "Élodie Example", "émile Example", "Eve Example",
                     "Ezra Example", "Ölaf Example", "oscar Example", "Zed Example"]
    assert [r["display_name"] for r in paged] == order
    letters = [r["sort_letter"] for r in rows]
    assert letters == ["#", "A", "E", "E", "E", "E", "O", "O", "Z"]


# ---------------------------------------------------------------- plain rules


@pytest.mark.parametrize("name,letter", [
    ("Ava Fictional", "A"), ("émile Example", "E"), ("Øyvind Example", "Ø"), ("Ölaf", "O"), ("zed", "Z"),
    ("+1 202 555 0101", "#"), ("42 Example Street", "#"), ("someone@example.net", "S"), ("", "#"), ("  ", "#"),
    ("Ψ Example", "Ψ"), ("Ярослава", "Я"), ("田中", "#"), ("김", "#"), ("😀 Fun", "#"),
    # Also in mydata_ui's contactGroupLetter test, so the two agree.
    ("Æsa Example", "Æ"), ("Łukasz Example", "Ł"), ("Ёжик Example", "Е"), ("Άννα Example", "Α"), ("ßtest", "ß"),
    ("ひかり Example", "ひ"), ("ㄱ Example", "#"),
])
def test_sort_letter(name, letter):
    assert sort_letter(name) == letter


def test_contact_caption_is_the_organisation_else_the_first_email_or_phone_that_is_not_the_name():
    email = [{"value": "ava@example.com", "label": "home"}]
    phone = [{"value": "+1 202 555 0101", "label": "mobile"}]
    assert contact_caption("Ava Fictional", "Example Labs", email, phone) == "Example Labs"
    assert contact_caption("Ava Fictional", "", email, phone) == "ava@example.com"
    assert contact_caption("Ava Fictional", "", [], phone) == "+1 202 555 0101"
    # The name shown is the organisation (a company's card): not repeated.
    assert contact_caption("Acme Plumbing (Example)", "Acme Plumbing (Example)", [], phone) == "+1 202 555 0101"
    # The name shown is the email: the next value instead, or nothing.
    assert contact_caption("ava@example.com", "", email, []) is None
    assert contact_caption("ava@example.com", "", email, phone) == "+1 202 555 0101"
    assert contact_caption("Ava Fictional", "", [], []) is None


def test_contact_caption_compares_ignoring_case_accents_and_phone_spacing():
    """The same rule as contactCaption in mydata_ui (its tests hold these cases too)."""
    phone = [{"value": "+1 202 555 0101", "label": "mobile"}]
    assert contact_caption("AVA@example.com", "", [{"value": "ava@example.com"}], []) is None
    assert contact_caption("Example Labs", "example labs", [{"value": "info@example.com"}], []) == "info@example.com"
    assert contact_caption("Élodie Example", "Elodie Example", [{"value": "elodie@example.com"}], []) == \
        "elodie@example.com"
    assert contact_caption("ava@example.com", "", [{"value": "AVA@example.com"}, {"value": "ava.work@example.com"}],
                           []) == "ava.work@example.com"
    # A card named by its phone number: the same digits, however spaced, are the name; another number is not.
    assert contact_caption("+1 202 555 0101", "", [], [{"value": "+12025550101"}]) is None
    assert contact_caption("+44 7700 900456", "", [], [{"value": "+447700900456"}, {"value": "+44 7700 900789"}]) \
        == "+44 7700 900789"
    # Digits are compared only when the name is a phone number.
    assert contact_caption("Example 2000", "", [], [{"value": "2000"}]) == "2000"
    assert contact_caption("Ava Fictional", "", [], phone) == "+1 202 555 0101"


def test_labels_are_sentence_case_and_custom_labels_stay_as_written():
    assert [display_label(x) for x in ("mobile", "iphone", "home", "WORK", "homefax", "homepage", "", None)] == [
        "Mobile", "iPhone", "Home", "Work", "Home fax", "Home page", "", ""]
    assert display_label("Gym buddy") == "Gym buddy" and display_label("bike club") == "bike club"


def test_account_captions_follow_datacolour():
    assert account_caption("calDAV", "iCloud") == "iCloud"
    assert account_caption("calDAV", "Google") == "Google"
    assert account_caption("exchange", "Exchange") == "Exchange"
    assert account_caption("exchange", "") == "Exchange" and account_caption("mobileMe", "") == "iCloud"
    assert account_caption("local", "On My Mac") == "Only on this Mac"
    assert account_caption("birthdays", "Other") == "Birthdays from Contacts"
    assert account_caption("subscribed", "Other") == "Subscribed"
    assert account_caption("calDAV", "") is None


def test_data_colours_are_opaque_rrggbb_or_none():
    assert data_colour("#34aadcff") == "#34AADC" and data_colour("#1BADF8") == "#1BADF8"
    assert [data_colour(x) for x in (None, "", "red", "#123", "#12345G", 3)] == [None] * 6


def test_source_names():
    assert (source_heading("mac", None), source_in_sentence("mac", None)) == ("This Mac", "this Mac")
    assert source_heading("a1", "you@example.com") == "iCloud account you@example.com"
    assert source_in_sentence("a1", "you@example.com") == "the iCloud account you@example.com"


def test_contact_fields_order_labels_and_notes():
    contact = {
        "phones": [{"value": "+1 202 555 0101", "label": "mobile"}],
        "emails": [{"value": "ava@example.com", "label": "Bike club"}],
        "addresses": [{"label": "home", "street": "1 Example Street\nFlat 2", "locality": "Testville", "region": "",
                       "postal_code": "00000", "country": "Exampleland"},
                      {"label": "work", "street": "", "locality": "", "region": "", "postal_code": "",
                       "country": ""}],
        "birthday": "--07-04", "note": "Line one\nLine two",
    }
    urls = [{"value": "example.com/ava", "label": "homepage"}]
    groups = contact_fields(contact, urls=urls, notes_included=True)
    assert [(g["kind"], g["title"]) for g in groups] == [("phone", "Phone"), ("email", "Email"),
                                                         ("address", "Address"), ("birthday", "Birthday"),
                                                         ("url", "Links"), ("note", "Notes")]
    by = {g["kind"]: g["items"] for g in groups}
    assert by["phone"] == [{"label": "Mobile", "value": "+1 202 555 0101"}]
    assert by["email"] == [{"label": "Bike club", "value": "ava@example.com"}]
    (address,) = by["address"]  # the empty one is left out
    assert address["label"] == "Home" and address["value"] == "1 Example Street\nFlat 2\nTestville 00000\nExampleland"
    assert address["address"]["postal_code"] == "00000"
    assert by["birthday"] == [{"label": "", "value": "--07-04"}]
    assert by["url"] == [{"label": "Home page", "value": "example.com/ava"}]
    assert by["note"] == [{"label": "", "value": "Line one\nLine two"}]
    # A source that never reads notes has no Notes group, and an empty kind is left out entirely.
    assert [g["kind"] for g in contact_fields({**contact, "phones": []}, urls=[], notes_included=False)] == [
        "email", "address", "birthday"]


# ---------------------------------------------------------------- through the API


EXTRA_CALENDARS = [
    {"id": "cal-birthdays-0004", "name": "Birthdays", "source_id": "source-other", "source_name": "Other",
     "source_kind": "birthdays", "color": "#8E8E93"},
    {"id": "cal-holidays-0005", "name": "Holidays (example)", "source_id": "source-other", "source_name": "Other",
     "source_kind": "subscribed", "color": None},
    {"id": "cal-google-0006", "name": "Football (example)", "source_id": "source-google", "source_name": "Google",
     "source_kind": "calDAV", "color": "#0B8043"},
    {"id": "cal-exchange-0007", "name": "Office (example)", "source_id": "source-ex", "source_name": "",
     "source_kind": "exchange", "color": "#FFCC00"},
]


@pytest.mark.skipif(not hasattr(socket, "AF_UNIX"), reason="needs Unix sockets")
def test_this_mac_and_an_icloud_account_through_the_api(home):
    """Both sources on: This Mac's calendars first, each with its account on the Mac; the iCloud account's
    calendars after, headed by its email, with no caption. A calendar seen through both is listed twice."""
    mac = FakeMac("authorized", "fullAccess")
    mac.calendars.extend(EXTRA_CALENDARS)
    h = Host(home, FakeDav(), mac=mac)
    auth = h.auth
    try:
        with TestClient(h.app, base_url="http://127.0.0.1") as c:
            get = lambda path: c.get(path, headers=auth)  # noqa: E731
            assert c.put("/sources/mac", headers=auth, json={"enabled": True}).status_code == 200
            assert wait(lambda: len(get("/calendars").json()) == 7 and len(get("/contacts").json()) == 4)
            r = c.post("/accounts", headers=auth, json=BODY)
            assert r.status_code == 201, r.text
            account_id = r.json()["id"]
            h.sources.sync_account(account_id)

            calendars = get("/calendars").json()
            rows = [(x["source"], x["source_label"], x["name"], x["account_caption"], x["color"]) for x in calendars]
            icloud = f"iCloud account {fake_dav.USERNAME}"
            assert rows == [
                ("mac", "This Mac", "Birthdays", "Birthdays from Contacts", "#8E8E93"),
                ("mac", "This Mac", "Family (shared)", "Only on this Mac", None),
                ("mac", "This Mac", "Football (example)", "Google", "#0B8043"),
                ("mac", "This Mac", "Holidays (example)", "Subscribed", None),
                ("mac", "This Mac", "Home", "iCloud", "#1BADF8"),
                ("mac", "This Mac", "Office (example)", "Exchange", "#FFCC00"),
                ("mac", "This Mac", "Work", "iCloud", "#CC73E1"),
                ("icloud", icloud, "Holidays (example)", None, None),
                ("icloud", icloud, "Home", None, "#34AADC"),  # iCloud's #RRGGBBAA, drawn opaque
                ("icloud", icloud, "Work", None, "#CC73E1"),
            ]
            assert {x["account_id"] for x in calendars if x["source"] == "icloud"} == {account_id}

            # ---- the contact list: letters and captions
            contacts = get("/contacts").json()
            view = [(x["display_name"], x["sort_letter"], x["caption"], x["source"]) for x in contacts]
            assert ("Acme Plumbing (Example)", "A", "+44 7700 900123", "mac") in view
            assert ("Ava Q Fictional", "A", "Example Labs", "mac") in view
            assert ("Ava Fictional", "A", "ava.fictional@example.com", "icloud") in view
            assert ("Ben Madeup", "B", "Example Widgets Ltd", "icloud") in view
            assert ("someone@example.net", "S", None, "icloud") in view
            assert ("Sam Example", "S", "+44 7700 900103", "mac") in view
            assert all("fields" not in x for x in contacts)  # the page's fields come with the contact only

            # ---- a contact from this Mac: no Notes group, ever
            mac_ava = get(f"/contacts/{next(x['id'] for x in contacts if x['display_name'] == 'Ava Q Fictional')}"
                          ).json()
            assert mac_ava["source"] == "mac" and mac_ava["source_label"] == "this Mac"
            assert (mac_ava["job_title"], mac_ava["organisation"]) == ("Inventor", "Example Labs")
            assert mac_ava["notes_included"] is False and mac_ava["has_photo"] is True
            assert mac_ava["raw_vcard"] is None
            groups = {g["kind"]: g for g in mac_ava["fields"]}
            assert [g["kind"] for g in mac_ava["fields"]] == ["phone", "email", "address", "birthday", "url"]
            assert groups["phone"]["items"] == [{"label": "Mobile", "value": "+1 202 555 0101", "address": None}]
            assert [(i["label"], i["value"]) for i in groups["email"]["items"]] == [
                ("Home", "ava.fictional@example.com"), ("Work", "ava@work.example.net")]
            (address,) = groups["address"]["items"]
            assert address["label"] == "Home" and address["value"] == "1 Example Street\nTestville 00000\nExampleland"
            assert address["address"]["locality"] == "Testville"
            assert groups["birthday"]["items"][0]["value"] == "1990-04-12"
            assert groups["url"]["title"] == "Links" and [(i["label"], i["value"]) for i in groups["url"]["items"]] \
                == [("Home page", "https://www.example.org/ava")]
            assert mac_ava["urls"] == [{"value": "https://www.example.org/ava", "label": "homepage"}]
            sam = get(f"/contacts/{next(x['id'] for x in contacts if x['display_name'] == 'Sam Example' and x['source'] == 'mac' and x['emails'])}").json()  # noqa: E501
            assert [(g["kind"], [i["value"] for i in g["items"]]) for g in sam["fields"]] == [
                ("email", ["sam.example@example.com"]), ("birthday", ["--07-04"])]  # no year: day and month only

            # ---- a contact from the iCloud account: its note is read
            icloud_ava = get(f"/contacts/{next(x['id'] for x in contacts if x['display_name'] == 'Ava Fictional')}"
                             ).json()
            assert icloud_ava["source_label"] == f"the iCloud account {fake_dav.USERNAME}"
            assert icloud_ava["notes_included"] is True and icloud_ava["job_title"] == ""
            assert [g["kind"] for g in icloud_ava["fields"]] == ["phone", "email", "birthday", "note"]
            assert icloud_ava["fields"][-1] == {"kind": "note", "title": "Notes", "items": [
                {"label": "", "value": "Met at the invented book club.", "address": None}]}
            assert icloud_ava["fields"][0]["items"][0]["label"] == "Mobile"  # TYPE=CELL

            # ---- events carry what EventRow needs: the event's own zone, none for all-day events
            events = get("/events?start=2026-03-16&end=2026-03-31").json()["events"]
            for e in events:
                assert {"calendar_id", "title", "location", "start", "end", "all_day", "time_zone"} <= set(e)
                assert (e["time_zone"] is None) == e["all_day"], e["title"]
            trip = next(e for e in events if e["title"] == "Lake trip" and e["source"] == "mac")
            assert (trip["start"], trip["end"], trip["time_zone"]) == ("2026-03-27", "2026-03-30", None)
            dinner = next(e for e in events if e["title"].startswith("Dinner"))
            assert dinner["time_zone"] == "Pacific/Auckland" and dinner["location"] == "Example Bistro"
    finally:
        h.sources.stop()


def test_a_card_with_a_title_and_web_addresses_from_icloud(home):
    """TITLE and URL are read from the card itself, so cards mirrored before this change have them too."""
    from mydata.sources.dav.discovery import Collection
    from mydata.sources.dav.sync import CollectionState, Item, SyncResult

    h = Host(home, FakeDav())
    card = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:x-1\r\nFN:Rua Example\r\nN:Example;Rua;;;\r\nORG:Example Labs;\r\n"
            "TITLE:Head of research\\, imaginary\r\nitem1.URL:example.com/rua\r\nitem1.X-ABLabel:_$!<HomePage>!$_\r\n"
            "URL;TYPE=WORK:javascript:alert(1)\r\nitem2.TEL:+1 202 555 0109\r\nitem2.X-ABLabel:Bike club\r\n"
            "NOTE:   \r\nEND:VCARD\r\n")
    h.sources.contacts.apply("acct-1", Collection("https://dav.example.com/ab/", "contacts", "Contacts"),
                             SyncResult(changed=[Item(href="/ab/x-1.vcf", etag='"1"', data=card)], deleted=[],
                                        state=CollectionState(), full=True))
    with TestClient(h.app, base_url="http://127.0.0.1") as c:
        (row,) = c.get("/contacts", headers=h.auth).json()
        assert (row["sort_letter"], row["caption"]) == ("R", "Example Labs")
        detail = c.get(f"/contacts/{row['id']}", headers=h.auth).json()
    assert detail["job_title"] == "Head of research, imaginary"
    assert detail["source_label"] == "an iCloud account"  # an account no longer linked: no email to name
    # A blank note is no note; every web address is passed on as written (the app decides what is a link).
    assert [(g["kind"], [(i["label"], i["value"]) for i in g["items"]]) for g in detail["fields"]] == [
        ("phone", [("Bike club", "+1 202 555 0109")]),
        ("url", [("Home page", "example.com/rua"), ("Work", "javascript:alert(1)")]),
    ]
