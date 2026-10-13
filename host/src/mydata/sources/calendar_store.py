"""The calendar mirror: <home>/calendar.sqlite.

Read-only copies of the user's calendars. Each CalDAV resource is one row, keyed by (account, calendar
URL, href): the raw iCalendar text holds the master VEVENT and its RECURRENCE-ID overrides together, and
is expanded into occurrences when queried. Only VEVENT is mirrored; a resource with no VEVENT (a
VTODO-only one) is not stored. Upstream deletions get the soft-delete marker; removing an account
hard-deletes its rows. Sync state (sync token, ctag, etags) is stored per calendar in the same file.

Each row keeps a UTC window (widened by a day, open-ended for never-ending series) so a range query
only parses the resources that can overlap it.

The "This Mac" source (account_id "mac") is stored differently: EventKit gives expanded occurrences
only, so each occurrence is one row of `occurrences`, keyed by (account, calendar, external id,
occurrence date). The calendar is part of the key: the same event in two calendars is two rows. A
snapshot replaces the source's occurrences; an occurrence that is gone is deleted outright (they are
expansions of a rolling window, not records the user made). `coverage` holds each such source's window:
the days it holds. A CalDAV account holds everything, so it has no coverage row.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable, Mapping, Sequence
from datetime import date, datetime, time, timedelta, timezone, tzinfo
from pathlib import Path

from ._db import Database, new_id, now
from ._mirror import load_state, retire_collections, soft_delete_missing, upsert_collection
from .dav.discovery import Collection
from .dav.sync import CollectionState, SyncResult
from .ical import _format, bound, local_timezone, occurrences, summarise
from .mac import MAC_ID

log = logging.getLogger(__name__)

_MIGRATIONS = {
    1: [
        """CREATE TABLE calendars (
            seq INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            account_id TEXT NOT NULL,
            url TEXT NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            color TEXT,
            sync_token TEXT,
            ctag TEXT,
            etags TEXT NOT NULL DEFAULT '{}',
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            deleted_at TEXT,
            UNIQUE (account_id, url)
        )""",
        """CREATE TABLE events (
            seq INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            account_id TEXT NOT NULL,
            calendar_id TEXT NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
            collection_url TEXT NOT NULL,
            href TEXT NOT NULL,
            etag TEXT NOT NULL DEFAULT '',
            uid TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL DEFAULT '',
            raw_ics TEXT NOT NULL,
            range_start TEXT,
            range_end TEXT,
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            deleted_at TEXT,
            UNIQUE (account_id, collection_url, href)
        )""",
        "CREATE INDEX events_calendar ON events (calendar_id, deleted_at)",
        "CREATE INDEX events_account ON events (account_id)",
        "CREATE INDEX events_range ON events (deleted_at, range_start, range_end)",
    ],
    2: [
        """CREATE TABLE occurrences (
            seq INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            account_id TEXT NOT NULL,
            calendar_id TEXT NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
            external_id TEXT NOT NULL,
            occurrence_date TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            location TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            start TEXT NOT NULL,
            end TEXT NOT NULL,
            all_day INTEGER NOT NULL DEFAULT 0,
            time_zone TEXT,
            detached INTEGER NOT NULL DEFAULT 0,
            recurring INTEGER NOT NULL DEFAULT 0,
            range_start TEXT NOT NULL,
            range_end TEXT NOT NULL,
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL,
            deleted_at TEXT,
            UNIQUE (account_id, calendar_id, external_id, occurrence_date)
        )""",
        "CREATE INDEX occurrences_range ON occurrences (range_start, range_end)",
        "CREATE INDEX occurrences_calendar ON occurrences (calendar_id)",
        """CREATE TABLE coverage (
            account_id TEXT PRIMARY KEY,
            covered_start TEXT NOT NULL,
            covered_end TEXT NOT NULL,
            modified_at TEXT NOT NULL
        )""",
    ],
}

_OCC_FIELDS = ("title", "location", "notes", "start", "end", "all_day", "time_zone", "detached", "recurring",
               "range_start", "range_end")
_OUT_KEYS = ("event_id", "calendar_id", "uid", "recurrence_id", "title", "location", "notes", "start", "end",
             "all_day", "time_zone", "source")


def source_of(account_id: str) -> str:
    """Which kind of source an account id is: "mac" for This Mac, "icloud" for a CalDAV account."""
    return "mac" if account_id == MAC_ID else "icloud"


def _occ_bounds(start: str, end: str, all_day: bool) -> tuple[str, str]:
    """UTC bounds for the range index. All-day days have no fixed instant: widened by a day each side."""
    if all_day:
        first = datetime.combine(date.fromisoformat(start), time.min) - timedelta(days=1)
        last = datetime.combine(date.fromisoformat(end), time.min) + timedelta(days=1)
        return _format(first), _format(last)
    utc = lambda v: datetime.fromisoformat(v).astimezone(timezone.utc).replace(tzinfo=None)  # noqa: E731
    return _format(utc(start)), _format(utc(end))


class CalendarStore:
    def __init__(self, path: Path):
        self.db = Database(path, _MIGRATIONS)

    # ------------------------------------------------------------------ sync

    def apply(self, account_id: str, collection: Collection, result: SyncResult) -> None:
        """Store one sync result for one calendar, in one transaction.

        Changed resources are upserted by (account, calendar URL, href). A changed resource that no longer
        holds a VEVENT, or cannot be read as iCalendar, counts as removed (soft-deleted if it was stored).
        Deleted hrefs get the soft-delete marker. For a full result, anything not present upstream is
        soft-deleted too, where present means a changed href or an href in result.state.etags (the full
        listing). The new sync state is saved.
        """
        if collection.kind != "calendar":
            raise ValueError("CalendarStore only stores calendars")
        stamp = now()
        with self.db.transaction() as db:
            calendar_id = upsert_collection(db, "calendars", account_id, collection, result.state, stamp)
            for item in result.changed:
                self._upsert_resource(db, account_id, calendar_id, collection.url, item.href, item.etag, item.data,
                                      stamp)
            for href in result.deleted:
                _soft_delete(db, account_id, collection.url, href, stamp)
            if result.full:
                present = {i.href for i in result.changed} | set(result.state.etags)
                soft_delete_missing(db, "events", account_id, collection.url, present, stamp)

    @staticmethod
    def _upsert_resource(db, account_id, calendar_id, collection_url, href, etag, data, stamp) -> None:
        try:
            parsed = summarise(data)
        except Exception as exc:  # noqa: BLE001 - one unreadable resource must not stop the calendar's sync
            log.warning("calendar resource could not be read; skipped", extra={"fields": {"error": type(exc).__name__}})
            parsed = None
        if parsed is None or not parsed.has_event:
            _soft_delete(db, account_id, collection_url, href, stamp)
            return
        fields = {
            "etag": etag or "",
            "uid": parsed.uid,
            "title": parsed.title,
            "raw_ics": data,
            "range_start": parsed.range_start,
            "range_end": parsed.range_end,
        }
        existing = db.execute(
            "SELECT id, etag, raw_ics, deleted_at FROM events WHERE account_id = ? AND collection_url = ? AND href = ?",
            (account_id, collection_url, href),
        ).fetchone()
        if existing is None:
            columns = ["id", "account_id", "calendar_id", "collection_url", "href", *fields, "created_at", "modified_at"]
            values = [new_id(), account_id, calendar_id, collection_url, href, *fields.values(), stamp, stamp]
            db.execute(f"INSERT INTO events ({', '.join(columns)}) VALUES ({', '.join('?' * len(columns))})", values)
            return
        if existing["etag"] == fields["etag"] and existing["raw_ics"] == data and existing["deleted_at"] is None:
            return
        assignments = ", ".join(f"{k} = ?" for k in fields)
        db.execute(
            f"UPDATE events SET {assignments}, calendar_id = ?, modified_at = ?, deleted_at = NULL WHERE id = ?",
            [*fields.values(), calendar_id, stamp, existing["id"]],
        )

    def collection_state(self, account_id: str, collection_url: str) -> CollectionState:
        """The saved sync state for a calendar (empty when it has never been synced)."""
        with self.db.connect() as db:
            return load_state(db, "calendars", account_id, collection_url)

    def mark_collections_gone(self, account_id: str, present_urls: Iterable[str]) -> None:
        """Soft-delete this account's calendars that discovery no longer finds, and their events."""
        with self.db.transaction() as db:
            retire_collections(db, "calendars", "events", "calendar_id", account_id, set(present_urls), now())

    def delete_account(self, account_id: str) -> None:
        """Hard-delete everything mirrored from one account (events, calendars, sync state)."""
        with self.db.transaction() as db:
            db.execute("DELETE FROM occurrences WHERE account_id = ?", (account_id,))
            db.execute("DELETE FROM coverage WHERE account_id = ?", (account_id,))
            db.execute("DELETE FROM events WHERE account_id = ?", (account_id,))
            db.execute("DELETE FROM calendars WHERE account_id = ?", (account_id,))
        self.db.checkpoint()

    def account_ids(self) -> list[str]:
        """Every account with rows in this file (to find data left by an account that no longer exists)."""
        with self.db.connect() as db:
            rows = db.execute("SELECT account_id FROM calendars UNION SELECT account_id FROM events "
                              "UNION SELECT account_id FROM occurrences UNION SELECT account_id FROM coverage"
                              ).fetchall()
        return sorted(r[0] for r in rows)

    def counts(self, account_id: str) -> dict[str, int]:
        """How many calendars and events the account has (not soft-deleted). For a CalDAV account events are
        resources, not occurrences; for This Mac, which only holds occurrences, they are occurrences."""
        with self.db.connect() as db:
            cals = db.execute("SELECT COUNT(*) FROM calendars WHERE account_id = ? AND deleted_at IS NULL",
                              (account_id,)).fetchone()[0]
            events = db.execute("SELECT COUNT(*) FROM events WHERE account_id = ? AND deleted_at IS NULL",
                                (account_id,)).fetchone()[0]
            events += db.execute("SELECT COUNT(*) FROM occurrences WHERE account_id = ? AND deleted_at IS NULL",
                                 (account_id,)).fetchone()[0]
        return {"calendars": cals, "events": events}

    # ------------------------------------------------------------------ occurrence sources (This Mac)

    def upsert_calendar(self, account_id: str, url: str, name: str, color: str | None) -> str:
        """Create or refresh a calendar that has no sync state of its own; returns its id."""
        with self.db.transaction() as db:
            return upsert_collection(db, "calendars", account_id, Collection(url, "calendar", name, color),
                                     CollectionState(), now())

    def calendar_ids(self, account_id: str) -> dict[str, str]:
        """{calendar URL: id} for the account's calendars (not soft-deleted)."""
        with self.db.connect() as db:
            rows = db.execute("SELECT id, url FROM calendars WHERE account_id = ? AND deleted_at IS NULL",
                              (account_id,)).fetchall()
        return {r["url"]: r["id"] for r in rows}

    def delete_calendars(self, account_id: str, urls: Iterable[str]) -> int:
        """Hard-delete these calendars of the account and everything in them. Returns how many went."""
        urls = list(urls)
        if not urls:
            return 0
        with self.db.transaction() as db:
            ids = [r["id"] for r in db.execute(
                f"SELECT id FROM calendars WHERE account_id = ? AND url IN ({', '.join('?' * len(urls))})",
                [account_id, *urls]).fetchall()]
            if ids:
                marks = ", ".join("?" * len(ids))
                db.execute(f"DELETE FROM occurrences WHERE calendar_id IN ({marks})", ids)
                db.execute(f"DELETE FROM events WHERE calendar_id IN ({marks})", ids)
                db.execute(f"DELETE FROM calendars WHERE id IN ({marks})", ids)
        if ids:
            self.db.checkpoint()
        return len(ids)

    def replace_occurrences(self, account_id: str, window: tuple[date, date],
                            by_calendar: Mapping[str, Sequence]) -> dict[str, int]:
        """Make the account's occurrences exactly `by_calendar` ({calendar id: [Occurrence]}), and record
        `window` (first and last day, both included) as the days it holds. Unchanged rows keep their id;
        rows not in the snapshot are deleted. Returns {"added", "changed", "removed"}."""
        stamp = now()
        counts = {"added": 0, "changed": 0, "removed": 0}
        with self.db.transaction() as db:
            existing = {(r["calendar_id"], r["external_id"], r["occurrence_date"]): r for r in db.execute(
                "SELECT * FROM occurrences WHERE account_id = ?", (account_id,)).fetchall()}
            seen: set[tuple] = set()
            for calendar_id, items in by_calendar.items():
                for o in items:
                    key = (calendar_id, o.external_id, o.occurrence_date)
                    if key in seen:
                        continue  # the helper sent one occurrence twice: the first wins
                    seen.add(key)
                    range_start, range_end = _occ_bounds(o.start, o.end, o.all_day)
                    values = {"title": o.title, "location": o.location, "notes": o.notes, "start": o.start,
                              "end": o.end, "all_day": int(o.all_day), "time_zone": o.time_zone,
                              "detached": int(o.detached), "recurring": int(o.recurring),
                              "range_start": range_start, "range_end": range_end}
                    row = existing.get(key)
                    if row is None:
                        columns = ["id", "account_id", "calendar_id", "external_id", "occurrence_date", *values,
                                   "created_at", "modified_at"]
                        db.execute(f"INSERT INTO occurrences ({', '.join(columns)}) "
                                   f"VALUES ({', '.join('?' * len(columns))})",
                                   [new_id(), account_id, *key, *values.values(), stamp, stamp])
                        counts["added"] += 1
                    elif any(row[k] != v for k, v in values.items()):
                        db.execute(f"UPDATE occurrences SET {', '.join(f'{k} = ?' for k in values)}, "
                                   "modified_at = ? WHERE id = ?", [*values.values(), stamp, row["id"]])
                        counts["changed"] += 1
            gone = [(row["id"],) for key, row in existing.items() if key not in seen]
            db.executemany("DELETE FROM occurrences WHERE id = ?", gone)
            counts["removed"] = len(gone)
            db.execute("INSERT INTO coverage (account_id, covered_start, covered_end, modified_at) VALUES (?, ?, ?, ?) "
                       "ON CONFLICT(account_id) DO UPDATE SET covered_start = excluded.covered_start, "
                       "covered_end = excluded.covered_end, modified_at = excluded.modified_at",
                       (account_id, window[0].isoformat(), window[1].isoformat(), stamp))
        return counts

    def clear_occurrences(self, account_id: str) -> None:
        """Delete the account's occurrences and its window (its access was taken away)."""
        with self.db.transaction() as db:
            db.execute("DELETE FROM occurrences WHERE account_id = ?", (account_id,))
            db.execute("DELETE FROM coverage WHERE account_id = ?", (account_id,))
        self.db.checkpoint()

    def coverage(self, start: date, end: date) -> list[dict]:
        """Per source holding calendars, whether it holds every day from start to end (both included).

        A CalDAV account holds everything (covered_start and covered_end None, complete). A source with a
        window (This Mac) is complete only when the window contains the whole range. This Mac never counts
        as holding everything: until its first events snapshot is stored it has calendars but no window, and
        it is then left out here (SyncService.coverage adds a "not_read_yet" or "no_access" entry for it)."""
        with self.db.connect() as db:
            windows = db.execute("SELECT account_id, covered_start, covered_end FROM coverage "
                                 "ORDER BY account_id").fetchall()
            bounded = {r["account_id"] for r in windows}
            unbounded = [r[0] for r in db.execute(
                "SELECT DISTINCT account_id FROM calendars WHERE deleted_at IS NULL ORDER BY account_id").fetchall()
                if r[0] not in bounded and r[0] != MAC_ID]
        out = [{"source": source_of(a), "account_id": a, "covered_start": None, "covered_end": None,
                "complete": True} for a in unbounded]
        for r in windows:
            first, last = date.fromisoformat(r["covered_start"]), date.fromisoformat(r["covered_end"])
            out.append({"source": source_of(r["account_id"]), "account_id": r["account_id"],
                        "covered_start": r["covered_start"], "covered_end": r["covered_end"],
                        "complete": first <= start and end <= last})
        return out

    # ------------------------------------------------------------------ reading

    def calendars(self) -> list[dict]:
        with self.db.connect() as db:
            rows = db.execute(
                "SELECT id, account_id, url, name, color FROM calendars WHERE deleted_at IS NULL "
                "ORDER BY name COLLATE NOCASE, url"
            ).fetchall()
        return [dict(r) for r in rows]

    def events_between(self, start: datetime, end: datetime, calendar_ids: list[str] | None = None,
                       tz: tzinfo | None = None) -> list[dict]:
        """Occurrences overlapping [start, end), sorted by start.

        Recurring series are expanded (EXDATE removes, RECURRENCE-ID overrides replace, cancelled
        occurrences are left out). `tz` is the zone for output and for floating and all-day times; it
        defaults to the machine's zone. Naive start/end are read in `tz`. An all-day event's end is the
        exclusive next day. calendar_ids=None means every calendar; [] means none.
        """
        tz = tz or local_timezone()
        if start.tzinfo is None:
            start = start.replace(tzinfo=tz)
        if end.tzinfo is None:
            end = end.replace(tzinfo=tz)
        if end <= start or calendar_ids == []:
            return []
        sql = (
            "SELECT id, account_id, calendar_id, uid, raw_ics FROM events WHERE deleted_at IS NULL "
            "AND (range_start IS NULL OR range_start < ?) AND (range_end IS NULL OR range_end > ?) "
            "AND calendar_id IN (SELECT id FROM calendars WHERE deleted_at IS NULL)"
        )
        params: list = [bound(end), bound(start)]
        if calendar_ids is not None:
            sql += f" AND calendar_id IN ({', '.join('?' * len(calendar_ids))})"
            params.extend(calendar_ids)
        with self.db.connect() as db:
            rows = db.execute(sql, params).fetchall()

        out = []
        for row in rows:
            try:
                found = occurrences(row["raw_ics"], start, end, tz)
            except Exception:  # noqa: BLE001 - one unreadable resource must not hide the rest
                log.warning("calendar resource could not be expanded; skipped")
                continue
            for occ in found:
                occ["event_id"] = row["id"]
                occ["calendar_id"] = row["calendar_id"]
                occ["source"] = source_of(row["account_id"])
                if not occ["uid"]:
                    occ["uid"] = row["uid"]
                out.append(occ)
        out.extend(self._stored_occurrences(start, end, calendar_ids, tz))
        out.sort(key=lambda o: (o["_sort"], not o["all_day"], o["title"], o["event_id"]))
        return [{k: o[k] for k in _OUT_KEYS} for o in out]

    def _stored_occurrences(self, start: datetime, end: datetime, calendar_ids: list[str] | None,
                            tz: tzinfo) -> list[dict]:
        """Occurrence rows (This Mac) overlapping [start, end), in the shape of an expanded occurrence."""
        start_utc, end_utc = start.astimezone(timezone.utc), end.astimezone(timezone.utc)
        sql = ("SELECT * FROM occurrences WHERE deleted_at IS NULL AND range_start < ? AND range_end > ? "
               "AND calendar_id IN (SELECT id FROM calendars WHERE deleted_at IS NULL)")
        params: list = [bound(end), bound(start)]
        if calendar_ids is not None:
            sql += f" AND calendar_id IN ({', '.join('?' * len(calendar_ids))})"
            params.extend(calendar_ids)
        with self.db.connect() as db:
            rows = db.execute(sql, params).fetchall()
        out = []
        for r in rows:
            all_day = bool(r["all_day"])
            if all_day:
                a_start = datetime.combine(date.fromisoformat(r["start"]), time.min, tzinfo=tz).astimezone(timezone.utc)
                a_end = datetime.combine(date.fromisoformat(r["end"]), time.min, tzinfo=tz).astimezone(timezone.utc)
                start_s, end_s = r["start"], r["end"]
            else:
                a_start = datetime.fromisoformat(r["start"]).astimezone(timezone.utc)
                a_end = datetime.fromisoformat(r["end"]).astimezone(timezone.utc)
                start_s, end_s = a_start.astimezone(tz).isoformat(), a_end.astimezone(tz).isoformat()
            if a_end == a_start:
                overlaps = start_utc <= a_start < end_utc
            else:
                overlaps = a_start < end_utc and a_end > start_utc
            if not overlaps:
                continue
            out.append({"event_id": r["id"], "calendar_id": r["calendar_id"], "uid": r["external_id"],
                        "recurrence_id": r["occurrence_date"] if (r["recurring"] or r["detached"]) else None,
                        "title": r["title"], "location": r["location"], "notes": r["notes"], "start": start_s,
                        "end": end_s, "all_day": all_day, "time_zone": None if all_day else r["time_zone"],
                        "source": source_of(r["account_id"]), "_sort": a_start})
        return out


def _soft_delete(db, account_id: str, collection_url: str, href: str, stamp: str) -> None:
    db.execute(
        "UPDATE events SET deleted_at = ?, modified_at = ? "
        "WHERE account_id = ? AND collection_url = ? AND href = ? AND deleted_at IS NULL",
        (stamp, stamp, account_id, collection_url, href),
    )
