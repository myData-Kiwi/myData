"""The calendar mirror: <home>/calendar.sqlite.

Read-only copies of the user's calendars. Each CalDAV resource is one row, keyed by (account, calendar
URL, href): the raw iCalendar text holds the master VEVENT and its RECURRENCE-ID overrides together, and
is expanded into occurrences when queried. Only VEVENT is mirrored; a resource with no VEVENT (a
VTODO-only one) is not stored. Upstream deletions get the soft-delete marker; removing an account
hard-deletes its rows. Sync state (sync token, ctag, etags) is stored per calendar in the same file.

Each row keeps a UTC window (widened by a day, open-ended for never-ending series) so a range query
only parses the resources that can overlap it.
"""

from __future__ import annotations

import logging
from collections.abc import Iterable
from datetime import datetime, tzinfo
from pathlib import Path

from ._db import Database, new_id, now
from ._mirror import load_state, retire_collections, soft_delete_missing, upsert_collection
from .dav.discovery import Collection
from .dav.sync import CollectionState, SyncResult
from .ical import bound, local_timezone, occurrences, summarise

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
}


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
            db.execute("DELETE FROM events WHERE account_id = ?", (account_id,))
            db.execute("DELETE FROM calendars WHERE account_id = ?", (account_id,))
        self.db.checkpoint()

    def account_ids(self) -> list[str]:
        """Every account with rows in this file (to find data left by an account that no longer exists)."""
        with self.db.connect() as db:
            rows = db.execute("SELECT account_id FROM calendars UNION SELECT account_id FROM events").fetchall()
        return sorted(r[0] for r in rows)

    def counts(self, account_id: str) -> dict[str, int]:
        """How many calendars and events (resources, not occurrences; not soft-deleted) the account has."""
        with self.db.connect() as db:
            cals = db.execute("SELECT COUNT(*) FROM calendars WHERE account_id = ? AND deleted_at IS NULL",
                              (account_id,)).fetchone()[0]
            events = db.execute("SELECT COUNT(*) FROM events WHERE account_id = ? AND deleted_at IS NULL",
                                (account_id,)).fetchone()[0]
        return {"calendars": cals, "events": events}

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
            "SELECT id, calendar_id, uid, raw_ics FROM events WHERE deleted_at IS NULL "
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
                if not occ["uid"]:
                    occ["uid"] = row["uid"]
                out.append(occ)
        out.sort(key=lambda o: (o["_sort"], not o["all_day"], o["title"], o["event_id"]))
        keys = ("event_id", "calendar_id", "uid", "recurrence_id", "title", "location", "notes", "start", "end",
                "all_day", "time_zone")
        return [{k: o[k] for k in keys} for o in out]


def _soft_delete(db, account_id: str, collection_url: str, href: str, stamp: str) -> None:
    db.execute(
        "UPDATE events SET deleted_at = ?, modified_at = ? "
        "WHERE account_id = ? AND collection_url = ? AND href = ? AND deleted_at IS NULL",
        (stamp, stamp, account_id, collection_url, href),
    )
