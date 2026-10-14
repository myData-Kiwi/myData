"""The raw export (sources/export.py, `mydata export`): the stored text, as files that parse back to the same
cards and events. Synthetic data only."""

from __future__ import annotations

import json
import os
import sqlite3
import stat
import subprocess
import sys
from datetime import datetime

import icalendar
import pytest
import recurring_ical_events
import vobject

from mydata.service.config import source_checkout
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.dav.sync import Item
from mydata.sources.export import ExportError, components, export_raw, merge_calendar

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
    assert summary == {"format": 1, "contacts": [], "calendars": [], "not_exported": []}
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
