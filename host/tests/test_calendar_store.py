"""The calendar mirror: storing CalDAV resources and expanding them into occurrences.
All fixtures are invented (tests/fixtures/dav/calendar)."""

from __future__ import annotations

import sqlite3
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from mydata.sources.calendar_store import CalendarStore
from mydata.sources.dav.discovery import Collection
from mydata.sources.dav.sync import CollectionState, Item, SyncResult
from mydata.sources.owned import OWNED_ACCOUNT
from owned_data import CALENDAR_URL as OWNED_CALENDAR_URL
from owned_data import add_owned, owned_rows

FIXTURES = Path(__file__).parent / "fixtures" / "dav" / "calendar"
HOME = Collection(url="https://cal.example.com/1/calendars/home/", kind="calendar", display_name="Home",
                  color="#A9CC4E", components=("VEVENT", "VTODO"))
WORK = Collection(url="https://cal.example.com/1/calendars/work/", kind="calendar", display_name="Work",
                  color="#4C7814", components=("VEVENT",))
LONDON = ZoneInfo("Europe/London")
NEW_YORK = ZoneInfo("America/New_York")
UTC = ZoneInfo("UTC")


def ics(name: str) -> str:
    return (FIXTURES / name).read_text()


def item(name: str, etag: str = '"1"', collection: Collection = HOME) -> Item:
    path = collection.url.split("example.com", 1)[1]
    return Item(href=f"{path}{name}", etag=etag, data=ics(name))


def result(changed=(), deleted=(), full=False, etags=None, token="s1") -> SyncResult:
    changed = list(changed)
    if etags is None:
        etags = {i.href: i.etag for i in changed}
    return SyncResult(changed=changed, deleted=list(deleted), state=CollectionState(sync_token=token, etags=etags),
                      full=full)


HOME_FILES = ["weekly-london.ics", "ny-fallback.ics", "london-gap.ics", "allday-single.ics", "allday-multi.ics",
              "overnight.ics", "floating.ics", "custom-tz.ics", "daily-until-rdate.ics", "todo-only.ics",
              "yearly-forever.ics"]


@pytest.fixture
def store(tmp_path) -> CalendarStore:
    s = CalendarStore(tmp_path / "calendar.sqlite")
    s.apply("acc-1", HOME, result([item(n) for n in HOME_FILES], full=True))
    s.apply("acc-1", WORK, result([item("outlook-tz.ics", collection=WORK)], full=True))
    return s


def between(store, start, end, tz=LONDON, **kw):
    return store.events_between(start, end, tz=tz, **kw)


def titles(events) -> list[str]:
    return [e["title"] for e in events]


def d(*args, tz=LONDON) -> datetime:
    return datetime(*args, tzinfo=tz)


# ---------------------------------------------------------------- storage


def test_calendars_listed_with_device_ids(store):
    cals = store.calendars()
    assert [(c["name"], c["color"], c["url"]) for c in cals] == [("Home", "#A9CC4E", HOME.url),
                                                                   ("Work", "#4C7814", WORK.url)]
    assert all(len(c["id"]) == 36 and c["account_id"] == "acc-1" for c in cals)


def test_vtodo_only_resource_is_not_stored(store, tmp_path):
    db = sqlite3.connect(tmp_path / "calendar.sqlite")
    hrefs = [r[0] for r in db.execute("SELECT href FROM events")]
    assert not any(h.endswith("todo-only.ics") for h in hrefs)
    assert len(hrefs) == len(HOME_FILES)  # 10 home events + 1 work event, the to-do left out
    # Its etag is still in the sync state, so it is not fetched again on every full resync.
    assert any(h.endswith("todo-only.ics") for h in store.collection_state("acc-1", HOME.url).etags)


def test_one_row_per_resource_with_overrides_in_raw_text(store, tmp_path):
    db = sqlite3.connect(tmp_path / "calendar.sqlite")
    rows = db.execute("SELECT uid, raw_ics FROM events WHERE uid = 'weekly-sync-0001@example.com'").fetchall()
    assert len(rows) == 1 and rows[0][1].count("RECURRENCE-ID") == 2


# ---------------------------------------------------------------- recurrence


def test_weekly_with_exdate_moved_and_cancelled_overrides_across_london_spring_forward(store):
    events = [e for e in between(store, d(2026, 3, 1), d(2026, 5, 1)) if e["uid"].startswith("weekly-sync")]
    assert [(e["start"], e["title"]) for e in events] == [
        ("2026-03-19T09:00:00+00:00", "Weekly sync"),
        ("2026-03-26T09:00:00+00:00", "Weekly sync"),
        # 29 March 2026: clocks go forward, and 09:00 stays 09:00 local. 2 April is an EXDATE.
        # 9 April was moved to the 10th at 14:00.
        ("2026-04-10T14:00:00+01:00", "Weekly sync (moved)"),
        # 16 April is cancelled. 23 April is the sixth and last (COUNT counts the excluded slot too).
        ("2026-04-23T09:00:00+01:00", "Weekly sync"),
    ]
    moved = events[2]
    assert moved["recurrence_id"] == "2026-04-09T09:00:00+01:00"
    assert moved["end"] == "2026-04-10T15:00:00+01:00"
    assert events[0]["recurrence_id"] == "2026-03-19T09:00:00+00:00"
    assert events[0]["time_zone"] == "Europe/London"
    assert events[0]["location"] == "Room 4, Example House"
    assert events[0]["notes"] == "Invented standing meeting."
    assert len({e["event_id"] for e in events}) == 1  # one stored resource


def test_occurrences_are_given_in_the_callers_zone(store):
    [first] = [e for e in between(store, d(2026, 3, 19), d(2026, 3, 20), tz=NEW_YORK) if e["uid"].startswith("weekly")]
    assert first["start"] == "2026-03-19T05:00:00-04:00"  # 09:00 GMT; New York already on EDT
    assert first["time_zone"] == "Europe/London"  # the event's own zone


def test_new_york_fall_back_ambiguous_time_takes_first_occurrence(store):
    [e] = [e for e in between(store, d(2026, 11, 1, tz=NEW_YORK), d(2026, 11, 2, tz=NEW_YORK), tz=NEW_YORK)
           if e["title"] == "Night check"]
    assert e["start"] == "2026-11-01T01:30:00-04:00"  # EDT, the first 01:30 (RFC 5545)
    assert e["end"] == "2026-11-01T02:30:00-05:00"  # 02:30 exists once, in EST
    assert e["time_zone"] == "America/New_York"


def test_london_spring_forward_gap_time_uses_offset_before_the_gap(store):
    [e] = [e for e in between(store, d(2026, 3, 29), d(2026, 3, 30)) if e["title"] == "Clock change test"]
    # 01:30 does not exist on 29 March in London; RFC 5545 reads it with the offset before the gap.
    assert e["start"] == "2026-03-29T02:30:00+01:00"
    assert e["end"] == "2026-03-29T03:00:00+01:00"


def test_daily_until_with_rdate(store):
    events = [e for e in between(store, d(2026, 3, 1), d(2026, 4, 1), tz=UTC) if e["title"] == "Stand-up"]
    assert [e["start"][:10] for e in events] == ["2026-03-23", "2026-03-24", "2026-03-25", "2026-03-26",
                                                  "2026-03-27", "2026-03-28"]
    assert events[0]["start"] == "2026-03-23T08:00:00+00:00" and events[0]["time_zone"] == "UTC"


def test_never_ending_series_is_found_far_ahead(store):
    events = [e for e in between(store, d(2031, 4, 1), d(2031, 5, 1)) if e["uid"].startswith("birthday")]
    assert [(e["start"], e["end"], e["all_day"]) for e in events] == [("2031-04-15", "2031-04-16", True)]
    assert events[0]["recurrence_id"] == "2031-04-15"


def test_non_recurring_event_has_no_recurrence_id(store):
    [e] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21)) if e["title"] == "Floating lunch"]
    assert e["recurrence_id"] is None


# ---------------------------------------------------------------- all-day, multi-day, zones


def test_all_day_single_end_is_exclusive(store):
    [e] = [e for e in between(store, d(2026, 3, 21), d(2026, 3, 22)) if e["title"] == "Invented holiday"]
    assert (e["start"], e["end"], e["all_day"], e["time_zone"]) == ("2026-03-21", "2026-03-22", True, None)
    # The day after: not included, because the end date is exclusive.
    assert "Invented holiday" not in titles(between(store, d(2026, 3, 22), d(2026, 3, 23)))
    assert "Invented holiday" not in titles(between(store, d(2026, 3, 20), d(2026, 3, 21)))


def test_all_day_multi_day_overlaps_each_day_it_covers(store):
    for day in (23, 24, 25):
        hits = [e for e in between(store, d(2026, 3, day, 12), d(2026, 3, day, 13)) if e["title"] == "Trip to Exampleton"]
        assert [(e["start"], e["end"]) for e in hits] == [("2026-03-23", "2026-03-26")]
    assert "Trip to Exampleton" not in titles(between(store, d(2026, 3, 26), d(2026, 3, 27)))


def test_all_day_is_judged_in_the_callers_zone(store):
    # Midnight-to-midnight in New York is 04:00 to 04:00 UTC: 21 March in New York only touches the holiday
    # from 00:00 New York time, never the 20th.
    ny = between(store, d(2026, 3, 20, tz=NEW_YORK), d(2026, 3, 21, tz=NEW_YORK), tz=NEW_YORK)
    assert "Invented holiday" not in titles(ny)


def test_timed_event_spanning_midnight_and_several_days(store):
    name = "Invented hackathon"
    assert name in titles(between(store, d(2026, 3, 21), d(2026, 3, 22)))  # fully inside it
    assert name in titles(between(store, d(2026, 3, 22, 1), d(2026, 3, 22, 3)))  # range starts mid-event
    assert name in titles(between(store, d(2026, 3, 20, 21), d(2026, 3, 20, 23)))  # range ends mid-event
    assert name not in titles(between(store, d(2026, 3, 22, 2), d(2026, 3, 22, 4)))  # starts at its end
    assert name not in titles(between(store, d(2026, 3, 20, 20), d(2026, 3, 20, 22)))  # ends at its start
    [e] = [e for e in between(store, d(2026, 3, 21), d(2026, 3, 22)) if e["title"] == name]
    assert (e["start"], e["end"]) == ("2026-03-20T22:00:00+00:00", "2026-03-22T02:00:00+00:00")


def test_range_boundaries_are_half_open(store):
    lunch = "Floating lunch"  # 12:00-13:00 local
    assert lunch in titles(between(store, d(2026, 3, 20, 12), d(2026, 3, 20, 12, 1)))
    assert lunch in titles(between(store, d(2026, 3, 20, 12, 59), d(2026, 3, 20, 14)))
    assert lunch not in titles(between(store, d(2026, 3, 20, 13), d(2026, 3, 20, 14)))
    assert lunch not in titles(between(store, d(2026, 3, 20, 11), d(2026, 3, 20, 12)))
    assert between(store, d(2026, 3, 20, 13), d(2026, 3, 20, 12)) == []  # end before start


def test_floating_time_is_read_in_the_callers_zone(store):
    [london] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21)) if e["title"] == "Floating lunch"]
    assert london["start"] == "2026-03-20T12:00:00+00:00" and london["time_zone"] is None
    ny_day = between(store, d(2026, 3, 20, tz=NEW_YORK), d(2026, 3, 21, tz=NEW_YORK), tz=NEW_YORK)
    [ny] = [e for e in ny_day if e["title"] == "Floating lunch"]
    assert ny["start"] == "2026-03-20T12:00:00-04:00"


def test_naive_range_is_read_in_tz(store):
    hits = store.events_between(datetime(2026, 3, 20, 12), datetime(2026, 3, 20, 13), tz=NEW_YORK)
    assert "Floating lunch" in titles(hits)


def test_windows_zone_name_and_custom_vtimezone(store):
    [outlook] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21), tz=UTC) if e["uid"].startswith("outlook")]
    assert outlook["start"] == "2026-03-20T11:00:00+00:00"  # 12:00 W. Europe (CET, +01:00)
    assert outlook["time_zone"]  # a zone name is reported
    [custom] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21), tz=UTC) if e["uid"].startswith("custom")]
    assert custom["start"] == "2026-03-20T04:30:00+00:00"  # 10:00 at +05:30


def test_results_sorted_and_shaped(store):
    events = between(store, d(2026, 3, 19), d(2026, 3, 27))
    keys = {"event_id", "calendar_id", "uid", "recurrence_id", "title", "location", "notes", "start", "end",
            "all_day", "time_zone", "source"}
    assert all(set(e) == keys for e in events)
    assert {e["source"] for e in events} == {"icloud"}
    starts = [datetime.fromisoformat(e["start"]).replace(tzinfo=None) if e["all_day"]
              else datetime.fromisoformat(e["start"]).astimezone(LONDON).replace(tzinfo=None) for e in events]
    assert starts == sorted(starts)


def test_calendar_ids_filter(store):
    work_id = next(c["id"] for c in store.calendars() if c["name"] == "Work")
    home_id = next(c["id"] for c in store.calendars() if c["name"] == "Home")
    only_work = between(store, d(2026, 3, 20), d(2026, 3, 21), calendar_ids=[work_id])
    assert titles(only_work) == ["Call with Example GmbH"]
    assert all(e["calendar_id"] == work_id for e in only_work)
    only_home = between(store, d(2026, 3, 20), d(2026, 3, 21), calendar_ids=[home_id])
    assert "Call with Example GmbH" not in titles(only_home) and "Floating lunch" in titles(only_home)
    assert between(store, d(2026, 3, 20), d(2026, 3, 21), calendar_ids=[]) == []
    assert between(store, d(2026, 3, 20), d(2026, 3, 21), calendar_ids=["no-such-id"]) == []


# ---------------------------------------------------------------- sync bookkeeping


def test_deleted_href_soft_deleted_and_full_resync(store, tmp_path):
    lunch = item("floating.ics")
    store.apply("acc-1", HOME, result(deleted=[lunch.href]))
    assert "Floating lunch" not in titles(between(store, d(2026, 3, 20), d(2026, 3, 21)))
    db = sqlite3.connect(tmp_path / "calendar.sqlite")
    assert db.execute("SELECT deleted_at IS NOT NULL FROM events WHERE href = ?", (lunch.href,)).fetchone() == (1,)

    keep = item("allday-single.ics")
    store.apply("acc-1", HOME, result(full=True, etags={keep.href: keep.etag}))
    left = titles(between(store, d(2026, 3, 1), d(2026, 12, 1)))
    assert sorted(set(left)) == ["Call with Example GmbH", "Invented holiday"]  # Work calendar untouched


def test_changed_resource_updates_in_place_and_turning_into_a_todo_removes_it(store):
    lunch = item("floating.ics")
    [before] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21)) if e["uid"].startswith("lunch")]
    moved = Item(href=lunch.href, etag='"2"', data=lunch.data.replace("T120000", "T150000").replace("T130000", "T160000"))
    store.apply("acc-1", HOME, result([moved]))
    [after] = [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21)) if e["uid"].startswith("lunch")]
    assert after["event_id"] == before["event_id"] and after["start"] == "2026-03-20T15:00:00+00:00"

    todo = Item(href=lunch.href, etag='"3"', data=ics("todo-only.ics"))
    store.apply("acc-1", HOME, result([todo]))
    assert not [e for e in between(store, d(2026, 3, 20), d(2026, 3, 21)) if e["event_id"] == before["event_id"]]


def test_unreadable_resource_does_not_break_the_sync(store):
    bad = Item(href="/1/calendars/home/bad.ics", etag='"1"', data="BEGIN:VCALENDAR\nthis is not ical")
    store.apply("acc-1", HOME, result([bad]))
    assert "Floating lunch" in titles(between(store, d(2026, 3, 20), d(2026, 3, 21)))


def test_sync_state_saved(store):
    state = store.collection_state("acc-1", WORK.url)
    assert state.sync_token == "s1" and len(state.etags) == 1
    assert store.collection_state("acc-2", WORK.url) == CollectionState()


def test_delete_account_hard_deletes(tmp_path):
    path = tmp_path / "calendar.sqlite"
    s = CalendarStore(path)
    s.apply("acc-1", HOME, result([item("floating.ics")]))
    s.apply("acc-2", WORK, result([item("outlook-tz.ics", collection=WORK)]))
    s.delete_account("acc-1")
    assert [c["name"] for c in s.calendars()] == ["Work"]
    assert titles(between(s, d(2026, 3, 20), d(2026, 3, 21))) == ["Call with Example GmbH"]
    db = sqlite3.connect(path)
    assert db.execute("SELECT COUNT(*) FROM events WHERE account_id = 'acc-1'").fetchone()[0] == 0
    db.close()
    assert b"Floating lunch" not in path.read_bytes()


def test_delete_account_survives_owned_events(tmp_path):
    """Twin of test_delete_account_hard_deletes: an owned calendar in the same file comes through every hard
    delete unchanged, This Mac's occurrence paths included."""
    from datetime import date

    from mydata.sources.mac.protocol import Occurrence

    path = tmp_path / "calendar.sqlite"
    ids = add_owned(tmp_path)
    s = CalendarStore(path)
    s.apply("acc-1", HOME, result([item("floating.ics")]))
    mac = s.upsert_calendar("mac", "mac://calendars/cal-1", "Mac home", None)
    occ = Occurrence("cal-1", "ext-1", "2026-03-20", "2026-03-20", "2026-03-21", True, None, "Mac day (invented)",
                     "", "", False, False)
    before = owned_rows(tmp_path)
    # Occurrences go only into the source's own followed calendars: one aimed at the owned calendar is left out.
    assert s.replace_occurrences("mac", (date(2026, 1, 1), date(2026, 12, 31)),
                                 {mac: [occ], ids["calendars"][0]: [occ]})["added"] == 1
    assert s.replace_occurrences("mac", (date(2026, 1, 1), date(2026, 12, 31)), {})["removed"] == 1
    s.clear_occurrences("mac")
    s.clear_occurrences(OWNED_ACCOUNT)
    assert s.delete_calendars(OWNED_ACCOUNT, [OWNED_CALENDAR_URL]) == 0
    assert s.delete_calendars("mac", ["mac://calendars/cal-1"]) == 1
    s.delete_account("acc-1")
    s.delete_account(OWNED_ACCOUNT)
    assert owned_rows(tmp_path) == before
    assert titles(between(s, d(2026, 3, 20), d(2026, 3, 21))) == ["Owned picnic (invented)"]
    # Not a source's (account_ids leaves it out), but it holds every day of its own events.
    assert s.coverage(date(2026, 3, 20), date(2026, 3, 21)) == [
        {"source": "icloud", "account_id": OWNED_ACCOUNT, "covered_start": None, "covered_end": None,
         "complete": True}]
    assert s.account_ids() == [] and b"Floating lunch" not in path.read_bytes()


def test_the_macs_window_never_hides_an_owned_event(tmp_path):
    """The window rule is per source: an owned calendar holds every day, so an owned event outside This Mac's
    window is still listed, and never reported as outside what the host holds."""
    from datetime import date

    from mydata.tools.dates import Resolved
    from mydata.tools.mirror import mirror_tools

    add_owned(tmp_path)  # an owned event on 20 March 2026
    s = CalendarStore(tmp_path / "calendar.sqlite")
    mac = s.upsert_calendar("mac", "mac://calendars/cal-1", "Mac home", None)
    s.replace_occurrences("mac", (date(2026, 6, 1), date(2027, 6, 1)), {mac: []})
    tool = next(t for t in mirror_tools(None, s, tz=lambda: LONDON, coverage=s.coverage) if t.name == "list_events")
    out = tool.handler({}, {"date": Resolved(date(2026, 3, 20), date(2026, 3, 20))}, date(2026, 3, 18)).data
    assert [e["title"] for e in out["events"]] == ["Owned picnic (invented)"]
    assert out["outside_window"] is True and out["complete_sources"] == ["icloud"]


def test_mark_collections_gone(store):
    store.mark_collections_gone("acc-1", [WORK.url])
    assert [c["name"] for c in store.calendars()] == ["Work"]
    assert titles(between(store, d(2026, 3, 20), d(2026, 3, 21))) == ["Call with Example GmbH"]


def test_mark_collections_gone_survives_owned_events(store, tmp_path):
    add_owned(tmp_path)
    before = owned_rows(tmp_path)
    store.mark_collections_gone("acc-1", [])
    store.mark_collections_gone(OWNED_ACCOUNT, [])
    assert owned_rows(tmp_path) == before
    assert [c["name"] for c in store.calendars()] == ["Kept (owned)"]


def test_raw_hash_and_rev_follow_the_raw_resource(store):
    import hashlib
    with store.db.connect() as db:
        row = lambda: db.execute("SELECT rev, raw_sha256, raw_ics, href FROM events "  # noqa: E731
                                 "WHERE href LIKE '%floating.ics'").fetchone()
        assert row()["rev"] == 1 and row()["raw_sha256"] == hashlib.sha256(row()["raw_ics"].encode()).hexdigest()
        changed = ics("floating.ics").replace("Floating lunch", "Floating supper")
        store.apply("acc-1", HOME, result([Item(href=row()["href"], etag='"2"', data=changed)]))
        assert row()["rev"] == 2 and row()["raw_sha256"] == hashlib.sha256(changed.encode()).hexdigest()


def test_wrong_kind_rejected(tmp_path):
    book = Collection(url="https://contacts.example.com/card/", kind="contacts", display_name="Card")
    with pytest.raises(ValueError):
        CalendarStore(tmp_path / "c.sqlite").apply("acc-1", book, result())


def test_default_zone_is_the_machines(store, monkeypatch):
    monkeypatch.setenv("TZ", "America/New_York")
    [e] = [e for e in store.events_between(d(2026, 3, 20, tz=NEW_YORK), d(2026, 3, 21, tz=NEW_YORK))
           if e["title"] == "Floating lunch"]
    assert e["start"] == "2026-03-20T12:00:00-04:00"


def test_stored_windows_let_range_queries_skip_resources(store, tmp_path):
    db = sqlite3.connect(tmp_path / "calendar.sqlite")
    rows = dict(db.execute("SELECT uid, range_start || ' ' || IFNULL(range_end, 'open') FROM events").fetchall())
    assert rows["standup-0010@example.com"] == "2026-03-22T08:00:00 2026-03-29T08:15:00"  # RDATE is the last
    assert rows["birthday-0012@example.com"].endswith(" open")  # never ends
    assert rows["weekly-sync-0001@example.com"].endswith(" open")  # COUNT: expanded at query time
    assert rows["allday-0004@example.com"] == "2026-03-20T00:00:00 2026-03-23T00:00:00"
