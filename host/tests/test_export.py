"""The export (sources/export.py, `mydata export`): the raw style (the stored text) and the clean style (one vCard
version, a VTIMEZONE for every zone used), as files that parse and import back to the same cards and events.
Synthetic data only."""

from __future__ import annotations

import json
import os
import sqlite3
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import icalendar
import pytest
import recurring_ical_events
import vobject

from mydata.service.config import source_checkout
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.dav.sync import Item
from mydata.sources.export import ExportError, components, export, export_raw, merge_calendar

import test_contacts_store as con
from synthetic_home import CALENDAR_FILES, populate

GROUP = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:group-1@example.org\r\nFN:Book club\r\nN:Book club;;;;\r\n"
         "X-ADDRESSBOOKSERVER-KIND:group\r\nX-ADDRESSBOOKSERVER-MEMBER:urn:uuid:ava-1\r\nEND:VCARD\r\n")


def _mode(path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


@pytest.fixture
def home(tmp_path):
    h = tmp_path / "home"
    h.mkdir()
    populate(h)
    return h


def _stored(home, sql):
    with sqlite3.connect(home / "calendar.sqlite" if "events" in sql else home / "contacts.sqlite") as db:
        return [r[0] for r in db.execute(sql)]


def test_contacts_export_as_one_vcf_per_address_book(home, tmp_path):
    out = tmp_path / "export"
    summary = export_raw(home, out)
    raws = _stored(home, "SELECT raw_vcard FROM contacts WHERE deleted_at IS NULL")
    assert summary["contacts"] == [{"file": "contacts/Card.vcf", "name": "Card", "source": "iCloud",
                                    "cards": len(raws)}]
    text = (out / "contacts" / "Card.vcf").read_bytes().decode("utf-8")
    parsed = list(vobject.readComponents(text))
    assert len(parsed) == len(raws) == len(con.ALL)
    for raw in raws:  # every stored card is in the file as stored, with CRLF line endings
        assert raw.replace("\r\n", "\n").strip("\n").replace("\n", "\r\n") in text
    assert "\n" not in text.replace("\r\n", "")
    # readable only by the user
    assert _mode(out) == _mode(out / "contacts") == 0o700
    assert {_mode(p) for p in out.rglob("*") if p.is_file()} == {0o600}
    assert json.loads((out / "export.json").read_text()) == summary


def test_deleted_cards_are_left_out_and_group_cards_kept_apart(home, tmp_path):
    store = ContactsStore(home / "contacts.sqlite")
    group = Item(href="/1/carddavhome/card/group-1.vcf", etag='"1"', data=GROUP)
    store.apply("acc-1", con.BOOK, con.result([group]))
    store.apply("acc-1", con.BOOK, con.result(deleted=["/1/carddavhome/card/ava-fictional.vcf"]))
    summary = export_raw(home, tmp_path / "export")
    [entry] = summary["contacts"]
    assert entry["cards"] == len(con.ALL) - 1 and entry["groups"] == 1
    people = (tmp_path / "export" / "contacts" / "Card.vcf").read_text()
    assert "Ava Fictional" not in people and "Book club" not in people
    assert "X-ADDRESSBOOKSERVER-KIND:group" in (tmp_path / "export" / entry["groups_file"]).read_text()


@pytest.mark.parametrize("line", ["KIND;VALUE=text:group", "item1.X-ADDRESSBOOKSERVER-KIND:group", "kind:Group"])
def test_the_export_and_the_store_agree_on_group_cards(home, tmp_path, line):
    """A group the store hides from lists and counts is never exported, nor counted, as a person."""
    store = ContactsStore(home / "contacts.sqlite")
    card = GROUP.replace("X-ADDRESSBOOKSERVER-KIND:group", line)
    store.apply("acc-1", con.BOOK, con.result([Item(href="/1/carddavhome/card/group-1.vcf", etag='"1"', data=card)]))
    [entry] = export_raw(home, tmp_path / "export")["contacts"]
    assert entry["cards"] == store.counts("acc-1")["contacts"] and entry["groups"] == 1
    assert "Book club" not in (tmp_path / "export" / "contacts" / "Card.vcf").read_text()


def test_each_calendar_exports_as_one_vcalendar_that_expands_the_same(home, tmp_path):
    out = tmp_path / "export"
    summary = export_raw(home, out)
    assert [(c["file"], c["resources"]) for c in summary["calendars"]] == [
        ("calendars/Home.ics", len(CALENDAR_FILES)), ("calendars/Work.ics", 1)]
    raws = _stored(home, "SELECT e.raw_ics FROM events e JOIN calendars c ON c.id = e.calendar_id "
                         "WHERE c.name = 'Home' AND e.deleted_at IS NULL")
    cal = icalendar.Calendar.from_ical((out / "calendars" / "Home.ics").read_bytes())
    assert cal["X-WR-CALNAME"].to_ical() == b"Home" and cal["VERSION"] == "2.0"
    zones = [z["TZID"] for z in cal.walk("VTIMEZONE")]
    assert len(zones) == len(set(zones))
    originals = [icalendar.Calendar.from_ical(r) for r in raws]
    assert sorted(str(e["UID"]) for e in cal.walk("VEVENT")) == sorted(
        str(e["UID"]) for c in originals for e in c.walk("VEVENT"))
    # Imported, the file gives exactly the occurrences the stored resources give.
    window = (datetime(2025, 1, 1), datetime(2028, 1, 1))

    def occ(c):
        return sorted((str(o["UID"]), o.decoded("DTSTART").isoformat()) for o in recurring_ical_events.of(c).between(*window))

    assert occ(cal) == sorted(x for c in originals for x in occ(c))


def test_merge_keeps_lines_as_stored_and_each_time_zone_once():
    one = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example//EN\r\nMETHOD:PUBLISH\r\n"
           "BEGIN:VTIMEZONE\r\nTZID:Pacific/Auckland\r\nBEGIN:STANDARD\r\nDTSTART:19700405T030000\r\n"
           "TZOFFSETFROM:+1300\r\nTZOFFSETTO:+1200\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\n"
           "BEGIN:VEVENT\r\nUID:a@example.org\r\nDTSTAMP:20260101T000000Z\r\n"
           "DTSTART;TZID=Pacific/Auckland:20260105T090000\r\nSUMMARY:A long summary that is folded onto a seco\r\n"
           " nd line as stored\r\nBEGIN:VALARM\r\nACTION:DISPLAY\r\nTRIGGER:-PT10M\r\nEND:VALARM\r\nEND:VEVENT\r\n"
           "END:VCALENDAR\r\n")
    two = one.replace("a@example.org", "b@example.org").replace("\r\n", "\n")  # stored with LF
    merged = merge_calendar([one, two], "Whānau, family; and friends — a name long enough to need folding")
    assert merged.count("BEGIN:VTIMEZONE") == 1 and merged.count("BEGIN:VEVENT") == 2
    assert merged.count("BEGIN:VALARM") == 2 and "METHOD" not in merged
    assert "SUMMARY:A long summary that is folded onto a seco\r\n nd line as stored\r\n" in merged
    assert all(len(line.encode()) <= 75 for line in merged.split("\r\n"))
    cal = icalendar.Calendar.from_ical(merged)
    # TEXT, escaped as RFC 5545 says, and folded without splitting a character
    assert cal["X-WR-CALNAME"].to_ical().decode() == (r"Whānau\, family\; and friends — a name long enough "
                                                      r"to need folding")
    assert [str(e["SUMMARY"]) for e in cal.walk("VEVENT")] == ["A long summary that is folded onto a second line "
                                                                "as stored"] * 2
    assert [len(c) for c in components(one)] == [8, 11]


def test_this_macs_calendars_are_named_as_not_exported(home, tmp_path):
    with sqlite3.connect(home / "calendar.sqlite") as db:
        db.execute("INSERT INTO calendars (id, account_id, url, name, created_at, modified_at) "
                   "VALUES ('m1', 'mac', 'mac://calendars/x', 'On My Mac', 'now', 'now')")
    summary = export_raw(home, tmp_path / "export")
    assert [s["calendar"] for s in summary["not_exported"]] == ["On My Mac"]
    assert not (tmp_path / "export" / "calendars" / "On My Mac.ics").exists()


def test_the_export_refuses_the_checkout_and_a_folder_in_use(home, tmp_path):
    inside = source_checkout() / "host" / "export-test-never-created"
    with pytest.raises(ExportError, match="inside the source checkout"):
        export_raw(home, inside)
    assert not inside.exists()
    used = tmp_path / "used"
    used.mkdir()
    (used / "notes.txt").write_text("x")
    with pytest.raises(ExportError, match="not an empty folder"):
        export_raw(home, used)


def test_an_empty_home_exports_nothing(tmp_path):
    summary = export_raw(tmp_path, tmp_path / "out")
    assert summary == {"format": 2, "style": "raw", "vcard_version": None, "contacts": [], "calendars": [],
                       "not_exported": []}
    assert not (tmp_path / "contacts.sqlite").exists()  # nothing is created


def test_the_export_command(home, tmp_path):
    env = {**os.environ, "MYDATA_HOME": str(home)}
    out = tmp_path / "export"
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "export", "--out", str(out)], env=env,
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert f"Exported {len(con.ALL)} card(s) from 1 address book(s)" in r.stdout
    assert (out / "calendars" / "Work.ics").is_file()
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "export", "--out", str(out)], env=env,
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 1 and "not an empty folder" in r.stderr


# ---------------------------------------------------------------- the clean export (the default)

def _owned_written_by_the_writers(home):
    """An owned calendar holding events the ICS writer made: TZIDs only, no VTIMEZONE, one series split."""
    from mydata.sources import ical_edit as ie
    from mydata.sources._db import now
    from mydata.sources.calendar_store import CalendarStore
    from mydata.sources.owned import OWNED_ACCOUNT

    nz = ZoneInfo("Pacific/Auckland")
    stamp = datetime(2026, 10, 13, 9, 30, tzinfo=timezone.utc)
    weekly = ie.new_event("Owned stand-up", datetime(2026, 3, 2, 9, tzinfo=nz), datetime(2026, 3, 2, 9, 30, tzinfo=nz),
                          uid="owned-weekly@example.org", rrule="FREQ=WEEKLY;COUNT=10;BYDAY=MO", now=stamp)
    weekly = ie.delete_this(weekly, datetime(2026, 3, 16, 9, tzinfo=nz), now=stamp)
    weekly = ie.edit_this(weekly, datetime(2026, 3, 23, 9, tzinfo=nz), {"SUMMARY": "Owned stand-up (moved)",
                                                                        "DTSTART": datetime(2026, 3, 23, 11, tzinfo=nz)},
                          now=stamp)
    old, new = ie.edit_following(weekly, datetime(2026, 4, 6, 9, tzinfo=nz), {"DTSTART": datetime(2026, 4, 6, 10, tzinfo=nz)},
                                 new_uid="owned-weekly-2@example.org", now=stamp)
    store = CalendarStore(home / "calendar.sqlite")
    with store.db.transaction() as db:
        db.execute("INSERT INTO calendars (id, account_id, url, name, mode, created_at, modified_at) "
                   "VALUES ('owned-cal-2', ?, 'owned://calendars/cal-2', 'Written here', 'owned', ?, ?)",
                   (OWNED_ACCOUNT, now(), now()))
        for href, text in (("a.ics", old), ("b.ics", new), ("c.ics", (Path(__file__).parent / "fixtures" / "ics" /
                                                                     "zones-without-vtimezone.ics").read_text())):
            CalendarStore._upsert_resource(db, OWNED_ACCOUNT, "owned-cal-2", "owned://calendars/cal-2", href, "", text,
                                           now())


@pytest.fixture
def full_home(home):
    from owned_data import add_owned
    add_owned(home)
    _owned_written_by_the_writers(home)
    return home


def _resources(ics_text: str) -> list[str]:
    """An exported calendar cut back into one resource per UID (the zones copied into each), as an import would."""
    comps = components(ics_text)
    zones = [c for c in comps if c[0].upper() == "BEGIN:VTIMEZONE"]
    by_uid: dict[str, list[list[str]]] = {}
    for comp in comps:
        if comp[0].upper() == "BEGIN:VTIMEZONE":
            continue
        uid = str(icalendar.Calendar.from_ical("BEGIN:VCALENDAR\r\n" + "\r\n".join(comp) + "\r\nEND:VCALENDAR\r\n")
                  .subcomponents[0].get("UID"))
        by_uid.setdefault(uid, []).append(comp)
    head = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Example Corp//Re-import test//EN"]
    return ["\r\n".join(head + [line for z in zones for line in z] + [line for c in group for line in c]
                        + ["END:VCALENDAR"]) + "\r\n" for group in by_uid.values()]


FIELDS = ("display_name", "given_name", "family_name", "nickname", "organisation", "job_title", "emails", "phones",
          "addresses", "birthday", "urls", "note", "has_photo")


def _cards_by_uid(store) -> dict:
    out = {}
    for c in store.list():
        full = store.get(c["id"])
        out[full["uid"] or full["display_name"]] = ({k: full.get(k) for k in FIELDS}, store.photo(c["id"]))
    return out


def _events(store) -> list[tuple]:
    tz = ZoneInfo("Pacific/Auckland")
    return sorted((e["uid"], e["title"], e["start"], e["end"], e["all_day"], e["location"], e["notes"])
                  for e in store.events_between(datetime(2020, 1, 1, tzinfo=tz), datetime(2030, 1, 1, tzinfo=tz), tz=tz))


@pytest.mark.parametrize("version", ["3.0", "4.0"])
def test_the_clean_export_reimports_into_the_stores_unchanged(full_home, tmp_path, version):
    from mydata.sources.calendar_store import CalendarStore
    from mydata.sources.vcard_edit import split_cards

    out = tmp_path / "export"
    summary = export(full_home, out, vcard_version=version)
    assert summary["style"] == "clean" and summary["vcard_version"] == version
    original = ContactsStore(full_home / "contacts.sqlite")
    again = ContactsStore(tmp_path / "again-contacts.sqlite")
    for entry in summary["contacts"]:
        text = (out / entry["file"]).read_text(encoding="utf-8")
        cards = split_cards(text)
        assert {c.version for c in cards} == {version} and len(cards) == entry["cards"]
        items = [Item(href=f"/re/{i}.vcf", etag='"1"', data=c.to_text()) for i, c in enumerate(cards)]
        book = con.BOOK if entry["source"] != "myData" else con.OTHER_BOOK
        again.apply("acc-re", book, con.result(items, full=True))
    assert _cards_by_uid(again) == _cards_by_uid(original)

    calendars = CalendarStore(full_home / "calendar.sqlite")
    again_cal = CalendarStore(tmp_path / "again-calendar.sqlite")
    for i, entry in enumerate(summary["calendars"]):
        text = (out / entry["file"]).read_text(encoding="utf-8")
        collection = icalendar_collection(i)
        path = collection.url.split("example.com", 1)[1]
        items = [Item(href=f"{path}{n}.ics", etag='"1"', data=r) for n, r in enumerate(_resources(text))]
        again_cal.apply("acc-re", collection, cal_result(items))
    assert _events(again_cal) == _events(calendars)


def icalendar_collection(i):
    from mydata.sources.dav.discovery import Collection
    return Collection(url=f"https://cal.example.com/re/{i}/", kind="calendar", display_name=f"Re {i}",
                      components=("VEVENT",))


def cal_result(items):
    import test_calendar_store as cal
    return cal.result(items, full=True)


def test_the_clean_export_converts_only_what_differs_and_adds_missing_zones(full_home, tmp_path):
    out = tmp_path / "export"
    summary = export(full_home, out)
    books = {b["name"]: b for b in summary["contacts"]}
    assert books["Card"]["converted"] == 1 and books["Card"]["as_stored"] == 0  # the one vCard 4.0
    assert books["Kept (owned)"]["source"] == "myData" and books["Kept (owned)"]["converted"] == 1
    files = "".join((out / "contacts" / name).read_bytes().decode("utf-8") for name in ("Card.vcf", "Kept (owned).vcf"))
    for raw in _stored(full_home, "SELECT raw_vcard FROM contacts WHERE deleted_at IS NULL"):
        if "VERSION:3.0" in raw:  # stored as 3.0: copied as stored, line for line
            assert raw.replace("\r\n", "\n").strip("\n").replace("\n", "\r\n") + "\r\n" in files
    assert "VERSION:4.0" not in files and files.count("BEGIN:VCARD") == len(con.ALL) + 2
    cals = {c["name"]: c for c in summary["calendars"]}
    assert cals["Written here"]["zones_added"] == ["Pacific/Auckland", "W. Europe Standard Time"]
    assert cals["Written here"]["zones_unknown"] == ["Invented Islands Time"]
    assert cals["Home"]["zones_added"] == cals["Work"]["zones_added"] == []  # iCloud sends its VTIMEZONEs
    written = (out / "calendars" / "Written here.ics").read_text()
    cal = icalendar.Calendar.from_ical(written)
    assert sorted(str(z["TZID"]) for z in cal.walk("VTIMEZONE")) == ["Pacific/Auckland", "W. Europe Standard Time"]
    assert written.count("BEGIN:VTIMEZONE") == 2 and "X-MYDATA-SPLIT-FROM:owned-weekly@example.org" in written
    assert json.loads((out / "export.json").read_text()) == summary


def test_a_calendar_that_would_lose_something_stops_the_export_before_any_file(full_home, tmp_path, monkeypatch):
    import mydata.sources.export as export_module
    real = export_module.merge_calendar

    def lossy(raws, name):
        return real(raws, name).replace("SUMMARY:Owned stand-up (moved)\r\n", "")

    monkeypatch.setattr(export_module, "merge_calendar", lossy)
    out = tmp_path / "export"
    with pytest.raises(ExportError, match="would lose SUMMARY"):
        export(full_home, out)
    assert not out.exists()


def test_the_raw_style_is_the_stored_text(full_home, tmp_path):
    out = tmp_path / "export"
    summary = export(full_home, out, style="raw")
    assert "VERSION:4.0" in (out / "contacts" / "Card.vcf").read_text()
    assert "BEGIN:VTIMEZONE" not in (out / "calendars" / "Written here.ics").read_text()
    assert all("zones_added" not in c for c in summary["calendars"])
    with pytest.raises(ExportError, match="3.0 or 4.0"):
        export(full_home, tmp_path / "x", vcard_version="2.1")


def test_the_export_command_writes_vcard_4_or_the_raw_text(full_home, tmp_path):
    env = {**os.environ, "MYDATA_HOME": str(full_home)}
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "export", "--out", str(tmp_path / "v4"), "--vcard", "4.0"],
                       env=env, capture_output=True, text=True, timeout=60)
    assert r.returncode == 0, r.stderr
    assert "(vCard 4.0)" in r.stdout and "no zone data for Invented Islands Time" in r.stdout
    assert "VERSION:3.0" not in (tmp_path / "v4" / "contacts" / "Card.vcf").read_text()
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "export", "--out", str(tmp_path / "raw"), "--raw"],
                       env=env, capture_output=True, text=True, timeout=60)
    assert r.returncode == 0 and "(the stored text as it is)" in r.stdout
    assert json.loads((tmp_path / "raw" / "export.json").read_text())["style"] == "raw"


def _custom_zone(uid: str, tzid_line: str, tzid_param: str, offset: str) -> str:
    return ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Outlook-like//EN\r\nBEGIN:VTIMEZONE\r\n"
            f"{tzid_line}\r\nBEGIN:STANDARD\r\nDTSTART:16010101T000000\r\nTZOFFSETFROM:{offset}\r\n"
            f"TZOFFSETTO:{offset}\r\nEND:STANDARD\r\nEND:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:{uid}\r\n"
            f"DTSTAMP:20260101T000000Z\r\nDTSTART;TZID={tzid_param}:20261102T090000\r\nSUMMARY:Call\r\nEND:VEVENT\r\n"
            "END:VCALENDAR\r\n")


def _starts(text: str) -> list[str]:
    window = (datetime(2026, 1, 1, tzinfo=timezone.utc), datetime(2027, 1, 1, tzinfo=timezone.utc))
    return sorted((str(o["UID"]), o["DTSTART"].dt.astimezone(timezone.utc).isoformat())
                  for o in recurring_ical_events.of(icalendar.Calendar.from_ical(text)).between(*window))


def test_a_vtimezone_whose_tzid_is_escaped_defines_the_zone_its_events_name():
    from mydata.sources.export import clean_calendar

    escaped = _custom_zone("a@example.org", r"TZID:(UTC+01:00) Amsterdam\, Berlin",
                           '"(UTC+01:00) Amsterdam, Berlin"', "+0100")
    plain = _custom_zone("b@example.org", "TZID:(UTC+01:00) Amsterdam, Berlin", '"(UTC+01:00) Amsterdam, Berlin"',
                         "+0100")
    text, added, unknown = clean_calendar([escaped, plain], "Work")
    assert unknown == [] and added == [] and text.count("BEGIN:VTIMEZONE") == 1


def test_two_custom_zones_with_one_name_stay_two_zones():
    first = _custom_zone("a@example.org", "TZID:Customized Time Zone", '"Customized Time Zone"', "+0530")
    second = _custom_zone("b@example.org", "TZID:Customized Time Zone", '"Customized Time Zone"', "-0300")
    again = _custom_zone("c@example.org", "TZID:Customized Time Zone", '"Customized Time Zone"', "-0300")
    merged = merge_calendar([first, second, again], "Work")
    assert merged.count("BEGIN:VTIMEZONE") == 2 and "TZID:Customized Time Zone (2)\r\n" in merged
    # each event at 09:00 in its own zone (icalendar keeps one zone per TZID per process, so each resource's own
    # reading is not a fair reference)
    assert _starts(merged) == [("a@example.org", "2026-11-02T03:30:00+00:00"),
                               ("b@example.org", "2026-11-02T12:00:00+00:00"),
                               ("c@example.org", "2026-11-02T12:00:00+00:00")]
    # a zone's own name: the same zone written twice, kept once
    nz = [_custom_zone(u, "TZID:Pacific/Auckland", "Pacific/Auckland", off) for u, off in (("d@example.org", "+1300"),
                                                                                            ("e@example.org", "+1200"))]
    assert merge_calendar(nz, "Home").count("BEGIN:VTIMEZONE") == 1
