"""The iCalendar writer (sources/ical_edit.py): the property guard, the four edits of a repeating event across a
clock change (the Auckland 02:30 gap pinned), COUNT, UNTIL, RDATE, all-day, floating and Outlook zones.
Occurrences are checked with recurring-ical-events, the library the calendar store reads with. Synthetic
corpora only (tests/fixtures/ics)."""

from __future__ import annotations

import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import icalendar
import pytest
import recurring_ical_events
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from mydata.sources import ical_edit as ie
from mydata.sources.ical_edit import IcsError, PropertyLossError

FIXTURES = Path(__file__).parent / "fixtures" / "ics"
NZ = ZoneInfo("Pacific/Auckland")
UTC = timezone.utc
NOW = datetime(2026, 10, 13, 9, 30, tzinfo=UTC)
WINDOW = (datetime(2025, 1, 1, tzinfo=UTC), datetime(2028, 1, 1, tzinfo=UTC))


def load(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _start_key(value) -> str:
    if isinstance(value, datetime) and value.tzinfo is not None:
        return value.astimezone(UTC).isoformat()
    return value.isoformat()


def occ(*texts: str, fields=("SUMMARY",)) -> list[tuple]:
    """Every occurrence of the resources, as (start instant, end instant, fields...), sorted."""
    out = []
    for text in texts:
        if text is None:
            continue
        for o in recurring_ical_events.of(icalendar.Calendar.from_ical(text)).between(*WINDOW):
            end = o.get("DTEND")
            out.append((_start_key(o["DTSTART"].dt), _start_key(end.dt) if end is not None else None,
                        *(str(o.get(f, "")) for f in fields)))
    return sorted(out)


def local_times(text: str, tz=NZ) -> list[str]:
    return [datetime.fromisoformat(s).astimezone(tz).strftime("%m-%d %H:%M%z") for s, *_ in occ(text)]


def event(text: str, rid=None):
    cal = icalendar.Calendar.from_ical(text)
    for e in cal.walk("VEVENT"):
        r = e.get("RECURRENCE-ID")
        if (rid is None and r is None) or (rid is not None and r is not None and r.dt == rid):
            return e
    raise AssertionError(f"no event {rid}")


ALL = sorted(p.name for p in FIXTURES.glob("*.ics"))


# ---------------------------------------------------------------- the guard

@pytest.mark.parametrize("name", ALL)
def test_every_fixture_reads_and_writes_through_the_guard_unchanged_in_meaning(name):
    text = load(name)
    out = ie._Edit(text).result()
    assert ie.inventory(out) == ie.inventory(text)
    assert occ(out, fields=("SUMMARY", "LOCATION")) == occ(text, fields=("SUMMARY", "LOCATION"))


def test_a_property_lost_while_writing_refuses_the_write(monkeypatch):
    real = icalendar.Calendar.to_ical

    def dropping(self, sorted=True):  # noqa: A002 - icalendar's own argument name
        return b"".join(line for line in real(self, sorted=sorted).splitlines(keepends=True)
                        if not line.startswith(b"CATEGORIES"))

    monkeypatch.setattr(icalendar.Calendar, "to_ical", dropping)
    with pytest.raises(PropertyLossError, match="CATEGORIES"):
        ie.edit_all(load("auckland-weekly.ics"), {"SUMMARY": "Renamed"}, now=NOW)


def test_an_edit_that_removes_what_it_did_not_declare_is_refused():
    edit = ie._Edit(load("outlook-windows.ics"))
    edit.master().pop("X-MICROSOFT-CDO-IMPORTANCE")
    with pytest.raises(PropertyLossError, match="X-MICROSOFT-CDO-IMPORTANCE"):
        edit.result()
    edit = ie._Edit(load("outlook-windows.ics"))
    edit.master()["ATTENDEE"].params.pop("RSVP")
    with pytest.raises(PropertyLossError, match="ATTENDEE;RSVP"):
        edit.result()
    edit = ie._Edit(load("auckland-weekly.ics"))
    edit.master()["EXDATE"] = icalendar.prop.vDDDLists([])
    with pytest.raises(PropertyLossError, match="EXDATE"):
        edit.result()


def test_the_check_compares_with_the_input_text_not_icalendars_reading_of_it():
    before = load("auckland-count.ics")
    after = before.replace("LOCATION:Room 9\n", "")
    with pytest.raises(PropertyLossError, match="LOCATION"):
        ie.check(before, after)
    ie.check(before, before)
    with pytest.raises(PropertyLossError, match="does not read back"):
        ie.check(before, "BEGIN:VCALENDAR\nnot ical")


def test_an_unreadable_resource_is_refused():
    with pytest.raises(IcsError, match="not a readable"):
        ie.edit_all("this is not a calendar", {"SUMMARY": "x"})


# ---------------------------------------------------------------- this event

def test_edit_this_adds_an_override_copied_from_the_master():
    text = load("auckland-weekly.ics")
    rid = datetime(2026, 4, 6, 9, tzinfo=NZ)  # the first Monday after clocks go back
    out = ie.edit_this(text, rid, {"SUMMARY": "Only this one"}, now=NOW)
    assert "RECURRENCE-ID;TZID=Pacific/Auckland:20260406T090000\r\n" in out
    o = event(out, rid)
    assert str(o["SUMMARY"]) == "Only this one" and str(o["LOCATION"]) == "Room 1"
    assert len(o.subcomponents) == 1 and o.subcomponents[0].name == "VALARM"
    assert o.get("RRULE") is None and o.get("EXDATE") is None and str(o["UID"]) == str(event(text)["UID"])
    before, after = occ(text), occ(out)
    assert [x[:2] for x in before] == [x[:2] for x in after]
    changed = [a for b, a in zip(before, after) if a != b]
    assert changed == [("2026-04-05T21:00:00+00:00", "2026-04-05T21:30:00+00:00", "Only this one")]


def test_edit_this_changes_an_existing_override_and_nothing_else():
    text = load("auckland-weekly.ics")
    out = ie.edit_this(text, datetime(2026, 3, 23, 9, tzinfo=NZ), {"LOCATION": "Room 7"}, now=NOW)
    assert out.count("BEGIN:VEVENT") == 2
    o = event(out, datetime(2026, 3, 23, 9, tzinfo=NZ))
    assert str(o["LOCATION"]) == "Room 7" and str(o["SUMMARY"]) == "Stand-up moved"
    assert str(event(out)["LOCATION"]) == "Room 1"
    assert int(o["SEQUENCE"]) == 3  # not a change of time


def test_edit_this_moving_the_start_keeps_the_length():
    text = load("auckland-count.ics")
    out = ie.edit_this(text, datetime(2026, 3, 30, 9, tzinfo=NZ), {"DTSTART": datetime(2026, 3, 31, 14, tzinfo=NZ)},
                       now=NOW)
    o = event(out, datetime(2026, 3, 30, 9, tzinfo=NZ))
    assert o["DTEND"].dt == datetime(2026, 3, 31, 15, tzinfo=NZ) and int(o["SEQUENCE"]) == 1
    assert "03-31 14:00+1300" in local_times(out) and "03-30 09:00+1300" not in local_times(out)


@pytest.mark.parametrize("rid", [datetime(2026, 3, 3, 9, tzinfo=NZ),  # a Tuesday
                                 datetime(2026, 3, 16, 9, tzinfo=NZ),  # deleted (EXDATE)
                                 datetime(2026, 6, 8, 9, tzinfo=NZ),  # after UNTIL
                                 date(2026, 3, 2)])  # a date for a timed event
def test_edit_this_refuses_what_is_not_an_occurrence(rid):
    with pytest.raises(IcsError):
        ie.edit_this(load("auckland-weekly.ics"), rid, {"SUMMARY": "x"}, now=NOW)


def test_an_occurrence_can_be_named_by_any_form_of_its_moment():
    text = load("auckland-weekly.ics")
    a = ie.edit_this(text, datetime(2026, 4, 5, 21, tzinfo=UTC), {"SUMMARY": "x"}, now=NOW)
    b = ie.edit_this(text, datetime(2026, 4, 6, 9, tzinfo=NZ), {"SUMMARY": "x"}, now=NOW)
    assert a == b


def test_uid_and_recurrence_id_cannot_be_changed_as_fields():
    for name in ("UID", "RECURRENCE-ID"):
        with pytest.raises(IcsError, match="cannot be changed"):
            ie.edit_all(load("auckland-count.ics"), {name: "x"}, now=NOW)
    with pytest.raises(IcsError, match="occurrence functions"):
        ie.edit_all(load("auckland-count.ics"), {"EXDATE": datetime(2026, 3, 30, 9, tzinfo=NZ)}, now=NOW)


# ---------------------------------------------------------------- delete this event

@pytest.mark.parametrize("name, rid, line", [
    ("auckland-weekly.ics", datetime(2026, 4, 13, 9, tzinfo=NZ), "EXDATE;TZID=Pacific/Auckland:20260413T090000"),
    ("allday-weekly.ics", date(2026, 3, 28), "EXDATE;VALUE=DATE:20260328"),
    ("utc-floating.ics", datetime(2026, 3, 24, 8, tzinfo=UTC), "EXDATE:20260324T080000Z"),
    ("floating-weekly.ics", datetime(2026, 4, 7, 7), "EXDATE:20260407T070000"),
    ("outlook-windows.ics", datetime(2026, 3, 23, 10, tzinfo=ZoneInfo("Europe/Berlin")),
     "EXDATE;TZID=W. Europe Standard Time:20260323T100000"),
])
def test_delete_this_writes_an_exdate_like_dtstart(name, rid, line):
    text = load(name)
    out = ie.delete_this(text, rid, now=NOW)
    assert line + "\r\n" in out
    gone = [x for x in occ(text) if x not in occ(out)]
    assert len(gone) == 1 and len(occ(out)) == len(occ(text)) - 1
    assert gone[0][0] == _start_key(rid)
    assert int(event(out).get("SEQUENCE", 0)) == int(event(text).get("SEQUENCE", 0)) + 1


def test_delete_this_removes_the_occurrences_override():
    text = load("auckland-weekly.ics")
    out = ie.delete_this(text, datetime(2026, 3, 23, 9, tzinfo=NZ), now=NOW)
    assert out.count("BEGIN:VEVENT") == 1 and "Stand-up moved" not in out
    assert "EXDATE;TZID=Pacific/Auckland:20260323T090000\r\n" in out
    assert "03-23" not in " ".join(local_times(out))


def test_delete_this_removes_an_extra_date():
    text = load("allday-weekly.ics")
    out = ie.delete_this(text, date(2026, 4, 2), now=NOW)
    assert "EXDATE;VALUE=DATE:20260402\r\n" in out
    assert ("2026-04-02", "2026-04-03", "Market day") not in occ(out)


# ---------------------------------------------------------------- all events

def test_moving_the_time_of_every_event_moves_its_exceptions_across_the_clock_change():
    text = load("auckland-weekly.ics")
    out = ie.edit_all(text, {"DTSTART": datetime(2026, 3, 2, 10, 30, tzinfo=NZ)}, now=NOW)
    times = local_times(out)
    assert times[:4] == ["03-02 10:30+1300", "03-09 10:30+1300", "03-23 11:00+1300", "03-30 10:30+1300"]
    assert times[4] == "04-06 10:30+1200" and times[-1] == "06-01 10:30+1200"  # after clocks go back
    assert len(times) == len(local_times(text))  # 03-16 stays deleted, 03-23 stays moved
    assert "EXDATE;TZID=Pacific/Auckland:20260316T103000\r\n" in out
    assert "RECURRENCE-ID;TZID=Pacific/Auckland:20260323T103000\r\n" in out
    assert "DTSTART;TZID=Pacific/Auckland:20260323T110000\r\n" in out  # the override's own move is kept
    assert "DTEND;TZID=Pacific/Auckland:20260302T110000\r\n" in out  # the length is kept
    # UNTIL ends the series at its last occurrence, moved (01 Jun 10:30 NZST)
    assert "UNTIL=20260531T223000Z" in out and int(event(out)["SEQUENCE"]) == 4


@pytest.mark.parametrize("name, new_start", [
    ("utc-floating.ics", datetime(2026, 3, 23, 9, tzinfo=UTC)),
    ("floating-weekly.ics", datetime(2026, 3, 24, 8)),
])
def test_a_tight_until_moves_with_the_time_so_no_occurrence_is_lost(name, new_start):
    text = load(name)
    out = ie.edit_all(text, {"DTSTART": new_start}, now=NOW)
    assert len(occ(out)) == len(occ(text))
    if name == "utc-floating.ics":
        assert "RDATE:20260328T090000Z" in out and "UNTIL=20260403T090000Z" in out
    else:
        assert "UNTIL=20260512T080000;" in out or "UNTIL=20260512T080000\r\n" in out


def test_a_field_follows_into_overrides_that_did_not_change_it():
    text = load("auckland-count.ics")
    out = ie.edit_all(text, {"LOCATION": "Room 3", "SUMMARY": "Planning v2"}, now=NOW)
    by_day = {datetime.fromisoformat(s).astimezone(NZ).strftime("%m-%d"): (summary, location)
              for s, _e, summary, location in occ(out, fields=("SUMMARY", "LOCATION"))}
    assert by_day["03-23"] == ("Planning v2", "Room 3")
    assert by_day["04-20"] == ("Planning v2", "Room 9")  # its own room is kept
    assert by_day["05-04"] == ("Planning (long one)", "Room 3")  # its own title is kept


def test_a_new_date_with_exceptions_is_refused_unless_they_are_dropped():
    text = load("auckland-count.ics")
    changes = {"DTSTART": datetime(2026, 3, 24, 9, tzinfo=NZ), "RRULE": "FREQ=WEEKLY;COUNT=8;BYDAY=TU"}
    with pytest.raises(IcsError, match="exceptions='drop'"):
        ie.edit_all(text, changes, now=NOW)
    out = ie.edit_all(text, changes, exceptions="drop", now=NOW)
    assert "EXDATE" not in out and out.count("BEGIN:VEVENT") == 1
    assert len(occ(out)) == 8 and all("+1" in t and t[:5] >= "03-24" for t in local_times(out))


def test_ending_a_series_earlier_keeps_the_exceptions_still_inside_it():
    text = load("auckland-count.ics")
    with pytest.raises(IcsError):  # the override on 05-04 would fall outside
        ie.edit_all(text, {"RRULE": "FREQ=WEEKLY;COUNT=6;BYDAY=MO"}, now=NOW)
    out = ie.edit_all(text, {"RRULE": "FREQ=WEEKLY;COUNT=6;BYDAY=MO"}, exceptions="drop", now=NOW)
    assert "EXDATE;TZID=Pacific/Auckland:20260413T090000" in out and "Room 9" in out
    assert "long one" not in out and len(occ(out)) == 5


def test_an_event_that_does_not_repeat():
    text = ie.new_event("Dentist", datetime(2026, 5, 4, 15, tzinfo=NZ), datetime(2026, 5, 4, 16, tzinfo=NZ),
                        uid="dentist-0001@example.org", now=NOW, location="Example Street 1")
    assert "BEGIN:VTIMEZONE" not in text and "DTSTART;TZID=Pacific/Auckland:20260504T150000" in text
    out = ie.edit_event(text, {"DTSTART": datetime(2026, 5, 5, 8, tzinfo=NZ)}, now=NOW)
    assert occ(out) == [("2026-05-04T20:00:00+00:00", "2026-05-04T21:00:00+00:00", "Dentist")]
    with pytest.raises(IcsError, match="repeating"):
        ie.edit_event(load("auckland-count.ics"), {"SUMMARY": "x"})
    assert ie.new_event("A", date(2026, 1, 1)) != ie.new_event("A", date(2026, 1, 1))  # a new UID each time


# ---------------------------------------------------------------- this and following

def test_split_with_count_recounts_both_series():
    text = load("auckland-count.ics")
    rid = datetime(2026, 4, 27, 9, tzinfo=NZ)
    old, new = ie.edit_following(text, rid, {}, new_uid="split-0001@example.org", now=NOW)
    assert "COUNT=5" in old and "COUNT=3" in new
    assert occ(old, new, fields=("SUMMARY", "LOCATION")) == occ(text, fields=("SUMMARY", "LOCATION"))
    m = event(new)
    assert str(m["UID"]) == "split-0001@example.org" and m["DTSTART"].dt == rid
    assert str(m["X-MYDATA-SPLIT-FROM"]) == "7A1B0000-0000-4000-8000-00000000E002"
    assert "EXDATE" in old and "EXDATE" not in new  # 04-13 is before the split
    assert "Room 9" in old and "long one" in new and "long one" not in old
    assert "UID:split-0001@example.org" in new.split("RECURRENCE-ID")[0].rsplit("BEGIN:VEVENT", 1)[1]
    for text_ in (old, new):
        assert "RANGE" not in text_
    assert all(s < rid.astimezone(UTC).isoformat() for s, *_ in occ(old))
    assert all(s >= rid.astimezone(UTC).isoformat() for s, *_ in occ(new))


def test_split_with_until_ends_the_old_series_in_utc_and_changes_the_new_one():
    text = load("auckland-weekly.ics")
    rid = datetime(2026, 4, 6, 9, tzinfo=NZ)  # 2026-04-05 21:00 UTC, the day after clocks go back
    old, new = ie.edit_following(text, rid, {"DTSTART": datetime(2026, 4, 6, 10, tzinfo=NZ)}, now=NOW)
    assert "UNTIL=20260405T205959Z" in old and "UNTIL=20260531T220000Z" in new
    assert local_times(old) == ["03-02 09:00+1300", "03-09 09:00+1300", "03-23 11:00+1300", "03-30 09:00+1300"]
    assert local_times(new)[0] == "04-06 10:00+1200" and set(t[-10:] for t in local_times(new)) == {"10:00+1200"}
    assert len(local_times(old)) + len(local_times(new)) == len(local_times(text))
    assert "BEGIN:VTIMEZONE" in new  # the zone the resource came with is kept with it
    m = event(new)
    assert int(m["SEQUENCE"]) == 1 and m["DTEND"].dt == datetime(2026, 4, 6, 10, 30, tzinfo=NZ)


@pytest.mark.parametrize("name, rid, until", [
    ("allday-weekly.ics", date(2026, 4, 18), "UNTIL=20260417"),
    ("floating-weekly.ics", datetime(2026, 4, 21, 7), "UNTIL=20260421T065959"),
    ("utc-floating.ics", datetime(2026, 3, 30, 8, tzinfo=UTC), "UNTIL=20260330T075959Z"),
    ("outlook-windows.ics", datetime(2026, 4, 6, 10, tzinfo=ZoneInfo("Europe/Berlin")), "COUNT=3"),
])
def test_split_keeps_every_occurrence_for_each_kind_of_time(name, rid, until):
    text = load(name)
    old, new = ie.edit_following(text, rid, {}, now=NOW)
    assert until in old
    assert occ(old, new) == occ(text)


def test_split_moves_later_extra_dates_and_overrides_with_the_new_series():
    text = load("allday-weekly.ics")
    old, new = ie.edit_following(text, date(2026, 3, 28), {"SUMMARY": "Night market"}, now=NOW)
    assert "RDATE;VALUE=DATE:20260402" in new and "RDATE" not in old
    assert "EXDATE;VALUE=DATE:20260321" in old and "EXDATE" not in new
    assert "Easter hours" in new and "Easter hours" not in old
    titles = {s: t for s, _e, t in occ(new)}
    assert titles["2026-04-02"] == "Night market" and titles["2026-04-11"] == "Market day (Easter hours)"
    assert [x[:2] for x in occ(old, new)] == [x[:2] for x in occ(text)]


def test_split_keeps_outlook_zone_names():
    text = load("outlook-windows.ics")
    old, new = ie.edit_following(text, datetime(2026, 3, 23, 10, tzinfo=ZoneInfo("Europe/Berlin")), {}, now=NOW)
    assert "DTSTART;TZID=W. Europe Standard Time:20260323T100000" in new
    assert 'EXDATE;TZID="W. Europe Standard Time":20260330T100000' in new  # moved as it was written
    assert "TZID:W. Europe Standard Time" in new and 'ORGANIZER;CN="Example, Owner"' in new
    assert "COUNT=1" in old and "COUNT=5" in new


def test_split_from_the_first_occurrence_is_all_events_and_from_an_extra_date_is_refused():
    text = load("auckland-count.ics")
    old, new = ie.edit_following(text, datetime(2026, 3, 23, 9, tzinfo=NZ), {"SUMMARY": "All"}, now=NOW)
    assert new is None and old == ie.edit_all(text, {"SUMMARY": "All"}, now=NOW)
    with pytest.raises(IcsError, match="RDATE"):
        ie.edit_following(load("utc-floating.ics"), datetime(2026, 3, 28, 8, tzinfo=UTC), {}, now=NOW)


# ---------------------------------------------------------------- the 02:30 gap in Auckland (27 September 2026)

GAP_INSTANTS = ["2026-09-23T14:30:00+00:00", "2026-09-24T14:30:00+00:00", "2026-09-25T14:30:00+00:00",
                "2026-09-26T14:30:00+00:00",  # 02:30 does not exist on the 27th: the offset before the gap (+12)
                "2026-09-27T13:30:00+00:00", "2026-09-28T13:30:00+00:00", "2026-09-29T13:30:00+00:00"]


def test_the_gap_is_read_with_the_offset_before_it():
    assert [s for s, *_ in occ(load("auckland-gap.ics"))] == GAP_INSTANTS


@pytest.mark.parametrize("rid", [datetime(2026, 9, 27, 2, 30, tzinfo=NZ), datetime(2026, 9, 26, 14, 30, tzinfo=UTC)])
def test_the_gap_occurrence_can_be_changed_and_deleted(rid):
    text = load("auckland-gap.ics")
    out = ie.edit_this(text, rid, {"SUMMARY": "Skipped hour"}, now=NOW)
    assert "RECURRENCE-ID;TZID=Pacific/Auckland:20260927T023000\r\n" in out
    assert ("2026-09-26T14:30:00+00:00", "2026-09-26T15:00:00+00:00", "Skipped hour") in occ(out)
    out = ie.delete_this(text, rid, now=NOW)
    assert "EXDATE;TZID=Pacific/Auckland:20260927T023000\r\n" in out
    assert [s for s, *_ in occ(out)] == GAP_INSTANTS[:3] + GAP_INSTANTS[4:]


def test_the_gap_series_splits_and_moves_cleanly():
    text = load("auckland-gap.ics")
    old, new = ie.edit_following(text, datetime(2026, 9, 27, 2, 30, tzinfo=NZ), {}, now=NOW)
    assert "COUNT=3" in old and "COUNT=4" in new and "DTSTART;TZID=Pacific/Auckland:20260927T023000" in new
    assert [s for s, *_ in occ(old, new)] == GAP_INSTANTS
    moved = ie.edit_all(text, {"DTSTART": datetime(2026, 9, 24, 3, 30, tzinfo=NZ)}, now=NOW)
    assert local_times(moved) == ["09-24 03:30+1200", "09-25 03:30+1200", "09-26 03:30+1200", "09-27 03:30+1300",
                                  "09-28 03:30+1300", "09-29 03:30+1300", "09-30 03:30+1300"]


# ---------------------------------------------------------------- zones for the export

def test_vtimezones_are_generated_for_iana_and_windows_names_only():
    assert ie.iana_zone("W. Europe Standard Time") == "Europe/Berlin" and ie.iana_zone("Pacific/Auckland")
    assert ie.iana_zone("Invented Islands Time") is None and ie.vtimezone("Invented Islands Time") is None
    tz = ie.vtimezone("W. Europe Standard Time")
    assert tz.startswith("BEGIN:VTIMEZONE\r\nTZID:W. Europe Standard Time\r\n")
    cal = icalendar.Calendar.from_ical("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:x\r\n" + tz +
                                       load("zones-without-vtimezone.ics").split("VERSION:2.0\n", 1)[1]
                                       .split("BEGIN:VEVENT\nUID:unknown")[0].replace("\n", "\r\n") + "END:VCALENDAR\r\n")
    start = cal.walk("VEVENT")[0]["DTSTART"].dt
    assert start.utcoffset() == timedelta(hours=1)
    text = load("zones-without-vtimezone.ics")
    assert ie.referenced_tzids(text) == ["W. Europe Standard Time", "Invented Islands Time"]
    assert ie.defined_tzids(text) == [] and ie.defined_tzids(load("outlook-windows.ics")) == ["W. Europe Standard Time"]


# ---------------------------------------------------------------- property tests

ZONES = ["Pacific/Auckland", "Europe/London", "America/New_York", "UTC", "floating", "date"]


def _fmt(value) -> str:
    if not isinstance(value, datetime):
        return value.strftime("%Y%m%d")
    if value.tzinfo is not None and value.utcoffset() == timedelta(0) and getattr(value.tzinfo, "key", "") == "UTC":
        return value.strftime("%Y%m%dT%H%M%SZ")
    return value.strftime("%Y%m%dT%H%M%S")


@st.composite
def series(draw):
    zone = draw(st.sampled_from(ZONES))
    day = draw(st.dates(min_value=date(2026, 3, 1), max_value=date(2026, 11, 30)))
    hour, minute = draw(st.sampled_from([0, 1, 2, 3, 9, 23])), draw(st.sampled_from([0, 30]))
    freq = draw(st.sampled_from(["DAILY", "WEEKLY"]))
    interval = draw(st.integers(1, 3))
    n = draw(st.integers(3, 12))
    if zone == "date":
        start, prop = day, f"DTSTART;VALUE=DATE:{_fmt(day)}"
    elif zone == "floating":
        start = datetime(day.year, day.month, day.day, hour, minute)
        prop = f"DTSTART:{_fmt(start)}"
    else:
        tz = ZoneInfo(zone)
        start = datetime(day.year, day.month, day.day, hour, minute, tzinfo=tz)
        prop = f"DTSTART:{_fmt(start)}" if zone == "UTC" else f"DTSTART;TZID={zone}:{_fmt(start)}"
    step = timedelta(days=interval * (7 if freq == "WEEKLY" else 1))
    if draw(st.booleans()):
        end = f"COUNT={n}"
    else:
        last = start + step * (n - 1)
        if zone == "date":
            end = f"UNTIL={_fmt(last)}"
        elif zone == "floating":
            end = f"UNTIL={_fmt(last)}"
        else:  # tight: the last start itself, in UTC
            end = "UNTIL=" + last.astimezone(UTC).strftime("%Y%m%dT%H%M%SZ")
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Example Corp//Property test//EN", "BEGIN:VEVENT",
             "UID:prop-series@example.org", "DTSTAMP:20260101T000000Z", prop,
             f"RRULE:FREQ={freq};INTERVAL={interval};{end}", "SUMMARY:Series", "END:VEVENT"]
    text = "\r\n".join(lines + ["END:VCALENDAR"]) + "\r\n"
    starts = [o.get("RECURRENCE-ID").dt for o in recurring_ical_events.of(
        icalendar.Calendar.from_ical(text)).between(*WINDOW)]
    exdate = draw(st.sampled_from([None, *starts[1:]]))
    if exdate is not None:
        in_utc = zone not in ("date", "floating", "UTC") and draw(st.booleans())  # some writers use UTC
        ex = (f"EXDATE;VALUE=DATE:{_fmt(exdate)}" if zone == "date" else
              f"EXDATE:{_fmt(exdate.astimezone(UTC))}Z" if in_utc else
              f"EXDATE:{_fmt(exdate)}" if zone in ("UTC", "floating") else f"EXDATE;TZID={zone}:{_fmt(exdate)}")
        text = text.replace("SUMMARY:Series", ex + "\r\nSUMMARY:Series")
    return text, zone


@settings(max_examples=150, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@given(series(), st.data())
def test_splitting_any_series_anywhere_keeps_every_occurrence(case, data):
    text, _zone = case
    rids = [o.get("RECURRENCE-ID").dt for o in recurring_ical_events.of(
        icalendar.Calendar.from_ical(text)).between(*WINDOW)]
    rid = data.draw(st.sampled_from(rids))
    old, new = ie.edit_following(text, rid, {}, now=NOW)
    assert occ(old, new) == occ(text)
    if new is not None:
        assert "RANGE" not in old + new
        assert occ(old) and occ(new)


@settings(max_examples=150, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@given(series(), st.data())
def test_editing_or_deleting_any_occurrence_touches_only_that_one(case, data):
    text, _zone = case
    rids = [o.get("RECURRENCE-ID").dt for o in recurring_ical_events.of(
        icalendar.Calendar.from_ical(text)).between(*WINDOW)]
    rid = data.draw(st.sampled_from(rids))
    edited = ie.edit_this(text, rid, {"SUMMARY": "Changed"}, now=NOW)
    before, after = occ(text), occ(edited)
    assert [x[0] for x in before] == [x[0] for x in after]
    changed = [i for i, x in enumerate(after) if x[2] == "Changed"]
    assert len(changed) == 1
    # every other occurrence is as it was; the changed one keeps its start (its end can differ only where the
    # reader adds a length on the wall clock across the skipped hour, and the override has the exact one)
    assert [x for i, x in enumerate(after) if i not in changed] == [x for i, x in enumerate(before) if i not in changed]
    deleted = ie.delete_this(text, rid, now=NOW)
    assert len(occ(deleted)) == len(before) - 1


_TEXT = st.text(st.characters(blacklist_categories=("Cs", "Cc")) | st.sampled_from(["\n", ",", ";", "\\", ":"]),
                min_size=1, max_size=100)


@settings(max_examples=150, deadline=None)
@given(_TEXT, _TEXT, _TEXT)
def test_text_fields_read_back_exactly_and_nothing_else_moves(summary, description, location):
    text = load("outlook-windows.ics")
    out = ie.edit_all(text, {"SUMMARY": summary, "DESCRIPTION": description, "LOCATION": location}, now=NOW)
    m = event(out)
    assert (str(m["SUMMARY"]), str(m["DESCRIPTION"]), str(m["LOCATION"])) == (summary, description, location)
    before, after = ie.inventory(text), ie.inventory(out)
    assert all(after[k] >= n for k, n in before.items() if "SUMMARY" not in k)


def _days(text: str, zone: str) -> list[str]:
    out = []
    for s, *_ in occ(text):
        value = datetime.fromisoformat(s)
        if value.tzinfo is not None and zone not in ("UTC", "floating"):
            value = value.astimezone(ZoneInfo(zone))
        out.append(value.date().isoformat() if isinstance(value, datetime) else value.isoformat())
    return out


@settings(max_examples=150, deadline=None, suppress_health_check=[HealthCheck.too_slow])
@given(series(), st.integers(-23 * 60, 23 * 60))
def test_moving_the_time_of_any_series_keeps_its_days_and_exceptions(case, minutes):
    text, zone = case
    start = event(text)["DTSTART"].dt
    if not isinstance(start, datetime):
        return
    new = (start.replace(tzinfo=None) + timedelta(minutes=minutes)).replace(tzinfo=start.tzinfo)
    if new.date() != start.date():
        return
    out = ie.edit_all(text, {"DTSTART": new}, now=NOW)
    assert _days(out, zone) == _days(text, zone)
    assert ("EXDATE" in out) == ("EXDATE" in text)


# ---------------------------------------------------------------- what an edit does not change, it writes as it came

_ODD = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Odd lines//EN\r\nBEGIN:VTIMEZONE\r\n"
        "TZID:(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna\r\nBEGIN:STANDARD\r\n"
        "DTSTART:16011028T030000\r\nRRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10\r\nTZOFFSETFROM:+0200\r\n"
        "TZOFFSETTO:+0100\r\nEND:STANDARD\r\nBEGIN:DAYLIGHT\r\nDTSTART:16010325T020000\r\n"
        "RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3\r\nTZOFFSETFROM:+0100\r\nTZOFFSETTO:+0200\r\nEND:DAYLIGHT\r\n"
        "END:VTIMEZONE\r\nBEGIN:VEVENT\r\nUID:odd@example.org\r\nDTSTAMP:20260101T000000Z\r\n"
        'DTSTART;TZID="(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna":20261102T090000\r\n'
        'DTEND;TZID="(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna":20261102T100000\r\n'
        "RRULE:FREQ=WEEKLY;COUNT=4\r\nSUMMARY:Odd\r\nREQUEST-STATUS:2.0;Success\r\n"
        "X-CUSTOM-NUM;VALUE=INTEGER:007\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
_ODD_LINES = ["REQUEST-STATUS:2.0;Success\r\n", "X-CUSTOM-NUM;VALUE=INTEGER:007\r\n",
              "TZID:(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna\r\n"]


def test_lines_icalendar_would_rewrite_are_written_as_they_came():
    berlin = ZoneInfo("Europe/Berlin")
    edited = ie.edit_all(_ODD, {"SUMMARY": "Renamed"}, now=NOW)
    this = ie.edit_this(_ODD, datetime(2026, 11, 9, 9, tzinfo=berlin), {"SUMMARY": "Once"}, now=NOW)
    single = ie.edit_event(_ODD.replace("RRULE:FREQ=WEEKLY;COUNT=4\r\n", ""), {"SUMMARY": "Single"}, now=NOW)
    for out in (edited, this, single):
        assert all(line in out for line in _ODD_LINES)
        assert ie.defined_tzids(out) == [_ODD_LINES[2][5:-2]]
    assert this.count("REQUEST-STATUS:2.0;Success\r\n") == 2  # the new override is a copy of the master
    assert "SUMMARY:Renamed\r\n" in edited and "SUMMARY:Single\r\n" in single
    # unchanged lines of a resource with LF endings come back with the CRLF icalendar writes
    assert "REQUEST-STATUS:2.0;Success\r\n" in ie.edit_all(_ODD.replace("\r\n", "\n"), {"SUMMARY": "x"}, now=NOW)


def test_a_value_that_changed_without_being_declared_is_refused():
    before = load("auckland-weekly.ics")
    after = before.replace(r"value with \; semicolon", "value with ; semicolon")
    with pytest.raises(PropertyLossError, match="X-CUSTOM changed"):
        ie.check(before, after)
    with pytest.raises(PropertyLossError, match="LOCATION changed"):
        ie.check(before, before.replace("LOCATION:Room 1", "LOCATION:Room 2", 1))
    edit = ie._Edit(before)
    edit.master()["LOCATION"] = icalendar.vText("Room 3")
    with pytest.raises(PropertyLossError, match="LOCATION changed"):
        edit.result()


def test_a_field_an_override_set_with_other_parameters_does_not_follow_the_master():
    text = load("outlook-windows.ics").replace("SUMMARY;LANGUAGE=en-gb:Weekly sync (late)",
                                                "SUMMARY;LANGUAGE=de:Weekly sync")
    out = ie.edit_all(text, {"SUMMARY": "Team sync"}, now=NOW)
    late = event(out, datetime(2026, 4, 6, 10, tzinfo=ZoneInfo("Europe/Berlin")))
    assert str(late["SUMMARY"]) == "Weekly sync" and late["SUMMARY"].params["LANGUAGE"] == "de"
    assert str(event(out)["SUMMARY"]) == "Team sync"


@pytest.mark.parametrize("line", ["PRIORITY:high", "GEO:abc", "CREATED:2026-01-01", "DTSTAMP:garbage",
                                  "X-FOO;VALUE=DATE:notadate", "SEQUENCE:1.5"])
def test_a_property_icalendar_cannot_read_is_kept_or_refused_without_its_value(line):
    text = load("auckland-weekly.ics").replace("LOCATION:Room 1\n", f"LOCATION:Room 1\n{line}\n", 1)
    rid = datetime(2026, 3, 9, 9, tzinfo=NZ)
    try:
        out = ie.delete_this(text, rid, now=NOW)
    except IcsError as exc:
        assert line.split(":", 1)[1] not in str(exc) and line.split(":")[0].split(";")[0] in str(exc)
        return
    assert len(occ(out)) == len(occ(text)) - 1
    if not line.startswith("DTSTAMP"):  # the edit sets DTSTAMP
        assert line + "\r\n" in out


def test_a_repeated_dtstart_is_refused():
    text = load("auckland-weekly.ics").replace("DTSTART;TZID=Pacific/Auckland:20260302T090000\n",
                                               "DTSTART;TZID=Pacific/Auckland:20260302T090000\n"
                                               "DTSTART;TZID=Pacific/Auckland:20260302T100000\n")
    with pytest.raises(IcsError, match="more than one DTSTART"):
        ie.delete_this(text, datetime(2026, 3, 9, 9, tzinfo=NZ), now=NOW)


# ---------------------------------------------------------------- large series

def test_moving_every_event_of_a_series_with_500_overrides_takes_well_under_a_few_seconds():
    berlin = ZoneInfo("Europe/Berlin")
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Example Corp//Many//EN", "BEGIN:VEVENT",
             "UID:many@example.org", "DTSTAMP:20260101T000000Z", "DTSTART;TZID=Europe/Berlin:20260101T090000",
             "DTEND;TZID=Europe/Berlin:20260101T100000", "RRULE:FREQ=DAILY;COUNT=1000", "SUMMARY:Daily",
             "END:VEVENT"]
    for i in range(500):
        day = datetime(2026, 1, 1, 9) + timedelta(days=2 * i)
        lines += ["BEGIN:VEVENT", "UID:many@example.org", "DTSTAMP:20260101T000000Z",
                  f"RECURRENCE-ID;TZID=Europe/Berlin:{day:%Y%m%dT%H%M%S}", f"DTSTART;TZID=Europe/Berlin:{day:%Y%m%dT%H%M%S}",
                  f"DTEND;TZID=Europe/Berlin:{day + timedelta(hours=1):%Y%m%dT%H%M%S}", f"SUMMARY:Changed {i}",
                  "END:VEVENT"]
    text = "\r\n".join(lines + ["END:VCALENDAR"]) + "\r\n"
    started = time.monotonic()
    out = ie.edit_all(text, {"DTSTART": datetime(2026, 1, 1, 10, tzinfo=berlin)}, now=NOW)
    assert time.monotonic() - started < 5
    assert out.count("BEGIN:VEVENT") == 501 and "SUMMARY:Changed 499\r\n" in out
    assert event(out, datetime(2026, 1, 3, 10, tzinfo=berlin))["DTSTART"].dt.hour == 10


# ---------------------------------------------------------------- the writer reads a series as the reader does

_UNTILS = [("DTSTART:20261001T090000", u) for u in ("20261004T000000Z", "20261004", "20261004T090000",
                                                     "20261004T085959Z", "20261004T090000Z")] + \
          [("DTSTART;TZID=America/New_York:20261001T090000", u) for u in ("20261008", "20261008T130000",
                                                                          "20261008T130000Z", "20261008T125959Z")] + \
          [("DTSTART;VALUE=DATE:20261001", u) for u in ("20261004", "20261004T000000Z", "20261003T235959Z")] + \
          [("DTSTART:20261001T090000Z", u) for u in ("20261004", "20261004T090000", "20261004T090000Z")]


@pytest.fixture(params=["Pacific/Auckland", "UTC"])
def host_zone(request, monkeypatch):
    """The host's own time zone, which must not matter."""
    monkeypatch.setenv("TZ", request.param)
    time.tzset()
    yield request.param
    monkeypatch.undo()
    time.tzset()


@pytest.mark.parametrize("start, until", _UNTILS)
def test_an_until_of_another_kind_ends_the_series_where_the_reader_ends_it(start, until, host_zone):
    text = (f"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Until//EN\r\nBEGIN:VEVENT\r\n"
            f"UID:until@example.org\r\nDTSTAMP:20260101T000000Z\r\n{start}\r\nRRULE:FREQ=DAILY;UNTIL={until}\r\n"
            "SUMMARY:Daily\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
    master = event(text)
    first = master["DTSTART"].dt
    writer = ie._starts_between(master, first - timedelta(days=5), first + timedelta(days=30))
    reader = [o["DTSTART"].dt for o in recurring_ical_events.of(icalendar.Calendar.from_ical(text)).between(*WINDOW)]
    assert sorted(writer, key=_start_key) == sorted(reader, key=_start_key)
    after_last = (max(reader, key=_start_key) + timedelta(days=1))
    with pytest.raises(IcsError, match="not an occurrence"):
        ie.edit_this(text, after_last, {"SUMMARY": "Extra"}, now=NOW)


_DAY_EXDATE = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Day exdate//EN\r\nBEGIN:VEVENT\r\n"
               "UID:day-exdate@example.org\r\nDTSTAMP:20260101T000000Z\r\n"
               "DTSTART;TZID=Pacific/Auckland:20261026T090000\r\nDTEND;TZID=Pacific/Auckland:20261026T100000\r\n"
               "RRULE:FREQ=WEEKLY;COUNT=4\r\nEXDATE;VALUE=DATE:20261109\r\nSUMMARY:Weekly\r\nEND:VEVENT\r\n"
               "END:VCALENDAR\r\n")


def test_a_date_exdate_on_a_timed_series_removes_that_day_for_the_writer_too():
    assert local_times(_DAY_EXDATE) == ["10-26 09:00+1300", "11-02 09:00+1300", "11-16 09:00+1300"]
    deleted = datetime(2026, 11, 9, 9, tzinfo=NZ)
    for edit in (lambda: ie.edit_this(_DAY_EXDATE, deleted, {"SUMMARY": "X"}, now=NOW),
                 lambda: ie.delete_this(_DAY_EXDATE, deleted, now=NOW),
                 lambda: ie.edit_following(_DAY_EXDATE, deleted, {"SUMMARY": "X"}, now=NOW)):
        with pytest.raises(IcsError, match="not an occurrence"):
            edit()
    # split before the deleted day: the day stays deleted, in the new series
    old, new = ie.edit_following(_DAY_EXDATE, datetime(2026, 11, 2, 9, tzinfo=NZ), {"SUMMARY": "Later"}, now=NOW)
    assert occ(old, new) == [(s, e, "Later" if s >= "2026-11-01" else "Weekly") for s, e, _ in occ(_DAY_EXDATE)]
    assert "EXDATE;VALUE=DATE:20261109" in new and "EXDATE" not in old
    # a new time of day keeps the day deleted; a new day of the week leaves it off the series
    moved = ie.edit_all(_DAY_EXDATE, {"DTSTART": datetime(2026, 10, 26, 7, tzinfo=NZ)}, now=NOW)
    assert local_times(moved) == ["10-26 07:00+1300", "11-02 07:00+1300", "11-16 07:00+1300"]
    with pytest.raises(IcsError, match="1 deleted"):
        ie.edit_all(_DAY_EXDATE, {"DTSTART": datetime(2026, 10, 27, 9, tzinfo=NZ)}, now=NOW)


def _daily_auckland(start: str, end: str, extra: str = "") -> str:
    return ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Clock change//EN\r\nBEGIN:VEVENT\r\n"
            f"UID:clock@example.org\r\nDTSTAMP:20260101T000000Z\r\nDTSTART;TZID=Pacific/Auckland:{start}\r\n"
            f"RRULE:FREQ=DAILY;{end}\r\n{extra}SUMMARY:Daily\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")


def test_a_tight_utc_until_on_the_day_clocks_change_keeps_the_last_occurrence():
    # the last occurrence, 27 Sep 04:00 NZDT, is 15:00 UTC; at 01:00 it is still NZST, 13:00 UTC
    text = _daily_auckland("20260924T040000", "UNTIL=20260926T150000Z")
    assert local_times(text)[-1] == "09-27 04:00+1300" and len(occ(text)) == 4
    out = ie.edit_all(text, {"DTSTART": datetime(2026, 9, 24, 1, tzinfo=NZ)}, now=NOW)
    assert local_times(out) == ["09-24 01:00+1200", "09-25 01:00+1200", "09-26 01:00+1200", "09-27 01:00+1200"]
    assert "UNTIL=20260926T130000Z" in out
    old, new = ie.edit_following(text, datetime(2026, 9, 25, 4, tzinfo=NZ), {"DTSTART": datetime(2026, 9, 25, 1,
                                 tzinfo=NZ)}, now=NOW)
    assert local_times(old) == ["09-24 04:00+1200"] and len(occ(new)) == 3


def test_a_utc_exdate_on_the_day_clocks_change_moves_with_its_occurrence():
    text = _daily_auckland("20260924T010000", "COUNT=5", "EXDATE:20260926T130000Z\r\n")  # 27 Sep 01:00 NZST
    assert "09-27 01:00+1200" not in local_times(text) and len(occ(text)) == 4
    out = ie.edit_all(text, {"DTSTART": datetime(2026, 9, 24, 4, tzinfo=NZ)}, now=NOW)
    assert local_times(out) == ["09-24 04:00+1200", "09-25 04:00+1200", "09-26 04:00+1200", "09-28 04:00+1300"]
    assert "EXDATE:20260926T150000Z" in out  # 27 Sep 04:00 NZDT, still in UTC


def test_a_utc_recurrence_id_on_the_day_clocks_change_moves_with_its_occurrence():
    text = _daily_auckland("20260924T010000", "COUNT=5").replace(
        "END:VCALENDAR", "BEGIN:VEVENT\r\nUID:clock@example.org\r\nDTSTAMP:20260101T000000Z\r\n"
        "RECURRENCE-ID:20260926T130000Z\r\nDTSTART:20260926T130000Z\r\nSUMMARY:Changed\r\nEND:VEVENT\r\n"
        "END:VCALENDAR")
    assert [s for s, _e, summary in occ(text) if summary == "Changed"] == ["2026-09-26T13:00:00+00:00"]
    assert len(occ(text)) == 5
    out = ie.edit_all(text, {"DTSTART": datetime(2026, 9, 24, 4, tzinfo=NZ)}, now=NOW)
    assert local_times(out) == ["09-24 04:00+1200", "09-25 04:00+1200", "09-26 04:00+1200", "09-27 04:00+1300",
                                "09-28 04:00+1300"]
    assert [s for s, _e, summary in occ(out) if summary == "Changed"] == ["2026-09-26T15:00:00+00:00"]
    assert "RECURRENCE-ID:20260926T150000Z" in out


def test_a_new_start_and_end_give_overrides_that_kept_the_length_the_new_one():
    # the 23 Mar override changes only LOCATION: it keeps the series' time and length
    text = load("auckland-weekly.ics").replace(
        "DTSTART;TZID=Pacific/Auckland:20260323T110000\nDTEND;TZID=Pacific/Auckland:20260323T113000\n"
        "SUMMARY:Stand-up moved", "DTSTART;TZID=Pacific/Auckland:20260323T090000\n"
        "DTEND;TZID=Pacific/Auckland:20260323T093000\nSUMMARY:Stand-up\\, team; weekly")
    head, _, tail = text.rpartition("LOCATION:Room 1")
    text = head + "LOCATION:Room 9" + tail
    changes = {"DTSTART": datetime(2026, 3, 2, 13, tzinfo=NZ), "DTEND": datetime(2026, 3, 2, 15, tzinfo=NZ)}
    out = ie.edit_all(text, changes, now=NOW)
    lengths = {e for s, e, *_ in occ(out) for e in [datetime.fromisoformat(e) - datetime.fromisoformat(s)]}
    assert lengths == {timedelta(hours=2)}
    room9 = event(out, datetime(2026, 3, 23, 13, tzinfo=NZ))
    assert str(room9["LOCATION"]) == "Room 9" and room9["DTEND"].dt == datetime(2026, 3, 23, 15, tzinfo=NZ)
    old, new = ie.edit_following(text, datetime(2026, 3, 9, 9, tzinfo=NZ), {
        "DTSTART": datetime(2026, 3, 9, 13, tzinfo=NZ), "DTEND": datetime(2026, 3, 9, 15, tzinfo=NZ)}, now=NOW)
    assert {datetime.fromisoformat(e) - datetime.fromisoformat(s) for s, e, *_ in occ(new)} == {timedelta(hours=2)}


# ---------------------------------------------------------------- an edit keeps the event's zone

def test_a_new_start_given_in_utc_or_without_a_zone_keeps_the_series_zone():
    text = load("auckland-weekly.ics")
    ten_nz = datetime(2026, 3, 2, 10, tzinfo=NZ)
    for given in (ten_nz.astimezone(UTC), ten_nz.astimezone(timezone(timedelta(hours=1))), ten_nz.replace(tzinfo=None)):
        out = ie.edit_all(text, {"DTSTART": given}, now=NOW)
        assert "DTSTART;TZID=Pacific/Auckland:20260302T100000\r\n" in out
        # every occurrence at 10:00 on both sides of the clock change; 03-23's own move to 11:00 is kept
        assert set(t[6:] for t in local_times(out)) == {"10:00+1300", "10:00+1200", "11:00+1300"}
    out = ie.edit_this(text, datetime(2026, 4, 13, 9, tzinfo=NZ), {"DTSTART": datetime(2026, 4, 13, 0, tzinfo=UTC)},
                       now=NOW)
    assert "DTSTART;TZID=Pacific/Auckland:20260413T120000\r\n" in out
    # another named zone is a move to it
    out = ie.edit_event(load("zones-without-vtimezone.ics").split("BEGIN:VEVENT\nUID:unknown")[0] + "END:VCALENDAR\n",
                        {"DTSTART": datetime(2026, 3, 20, 9, tzinfo=ZoneInfo("America/New_York"))}, now=NOW)
    assert "DTSTART;TZID=America/New_York:20260320T090000\r\n" in out


_UNKNOWN_ZONE = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Unknown zone//EN\r\nBEGIN:VEVENT\r\n"
                 "UID:unknown-zone-series@example.org\r\nDTSTAMP:20260101T000000Z\r\n"
                 "DTSTART;TZID=Custom Zone/Nowhere:20260105T090000\r\nDTEND;TZID=Custom Zone/Nowhere:20260105T100000\r\n"
                 "RRULE:FREQ=WEEKLY;COUNT=4\r\nSUMMARY:Weekly\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")


def test_a_zone_icalendar_cannot_resolve_is_kept_on_every_date_the_writer_adds():
    rid = datetime(2026, 1, 12, 9)
    assert "EXDATE;TZID=Custom Zone/Nowhere:20260112T090000\r\n" in ie.delete_this(_UNKNOWN_ZONE, rid, now=NOW)
    this = ie.edit_this(_UNKNOWN_ZONE, rid, {"SUMMARY": "Once"}, now=NOW)
    assert "RECURRENCE-ID;TZID=Custom Zone/Nowhere:20260112T090000\r\n" in this
    assert "DTEND;TZID=Custom Zone/Nowhere:20260112T100000\r\n" in this
    moved = ie.edit_all(_UNKNOWN_ZONE, {"DTSTART": datetime(2026, 1, 5, 10)}, now=NOW)
    assert "DTSTART;TZID=Custom Zone/Nowhere:20260105T100000\r\n" in moved
    assert "DTEND;TZID=Custom Zone/Nowhere:20260105T110000\r\n" in moved


def test_a_moved_start_keeps_the_end_in_its_own_zone():
    flight = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Flight//EN\r\nBEGIN:VEVENT\r\n"
              "UID:flight@example.org\r\nDTSTAMP:20260101T000000Z\r\nDTSTART;TZID=America/New_York:20261102T180000\r\n"
              "DTEND;TZID=Europe/London:20261103T060000\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\nSUMMARY:Flight\r\n"
              "END:VEVENT\r\nEND:VCALENDAR\r\n")
    ny = ZoneInfo("America/New_York")
    this = ie.edit_this(flight, datetime(2026, 11, 9, 18, tzinfo=ny), {"DTSTART": datetime(2026, 11, 9, 19, tzinfo=ny)},
                        now=NOW)
    assert "DTEND;TZID=Europe/London:20261110T070000\r\n" in this
    every = ie.edit_all(flight, {"DTSTART": datetime(2026, 11, 2, 17, tzinfo=ny)}, now=NOW)
    assert "DTEND;TZID=Europe/London:20261103T050000\r\n" in every


def test_a_new_end_replaces_a_duration_and_a_new_duration_an_end():
    text = load("auckland-weekly.ics").replace("DTEND;TZID=Pacific/Auckland:20260302T093000\n", "DURATION:PT1H\n")
    out = ie.edit_all(text, {"DTEND": datetime(2026, 3, 2, 11, tzinfo=NZ)}, now=NOW)
    master = event(out)
    assert master.get("DURATION") is None and master["DTEND"].dt == datetime(2026, 3, 2, 11, tzinfo=NZ)
    this = ie.edit_this(text, datetime(2026, 3, 9, 9, tzinfo=NZ), {"DTEND": datetime(2026, 3, 9, 9, 45, tzinfo=NZ)},
                        now=NOW)
    override = event(this, datetime(2026, 3, 9, 9, tzinfo=NZ))
    assert override.get("DURATION") is None and event(this).get("DURATION") is not None
    out = ie.edit_all(load("auckland-weekly.ics"), {"DURATION": timedelta(hours=2)}, now=NOW)
    assert event(out).get("DTEND") is None and "DURATION:PT2H" in out


def test_splitting_a_count_series_whose_start_is_not_on_the_rule_ends_it_with_until():
    text = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Example Corp//Off rule//EN\r\nBEGIN:VEVENT\r\n"
            "UID:off-rule@example.org\r\nDTSTAMP:20260101T000000Z\r\nDTSTART;TZID=Pacific/Auckland:20261103T090000\r\n"
            "RRULE:FREQ=WEEKLY;COUNT=4;BYDAY=MO\r\nSUMMARY:Weekly\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
    assert local_times(text)[:2] == ["11-03 09:00+1300", "11-09 09:00+1300"]
    for rid in (datetime(2026, 11, 9, 9, tzinfo=NZ), datetime(2026, 11, 16, 9, tzinfo=NZ)):
        old, new = ie.edit_following(text, rid, {}, now=NOW)
        assert "COUNT=0" not in old and "COUNT" not in event(old)["RRULE"] and "UNTIL=" in old
        assert occ(old, new) == occ(text)


def test_a_split_keeps_the_calendars_own_properties_and_is_checked_as_a_whole(monkeypatch):
    text = load("floating-weekly.ics").replace("VERSION:2.0\n", "VERSION:2.0\nX-WR-TIMEZONE:Europe/Berlin\n"
                                                "X-CUSTOM:keep\nMETHOD:PUBLISH\n", 1)
    rid = ie.occurrence(event(text), event(text)["DTSTART"].dt + timedelta(days=14))
    old, new = ie.edit_following(text, rid, {}, now=NOW)
    for line in ("X-WR-TIMEZONE:Europe/Berlin\r\n", "X-CUSTOM:keep\r\n"):
        assert line in old and line in new
    assert "METHOD" in old and "METHOD" not in new
    # an EXDATE left out of the new series, though taken from the old one, is caught
    real, calls = ie._map_dates, []

    def forgetting(prop, fn):  # the first call copies the EXDATE into the new series: it comes back empty
        calls.append(prop)
        return None if len(calls) == 1 else real(prop, fn)

    monkeypatch.setattr(ie, "_map_dates", forgetting)
    with_exdate = text.replace("RRULE:", f"EXDATE:{(rid + timedelta(days=7)):%Y%m%dT%H%M%S}\nRRULE:", 1)
    with pytest.raises(PropertyLossError, match="split would lose .*EXDATE"):
        ie.edit_following(with_exdate, rid, {}, now=NOW)
