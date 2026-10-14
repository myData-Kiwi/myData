"""The "This Mac" source: the main path on a Mac host. Contacts and calendars are read from macOS itself,
by the myDataReader helper inside the myData app, with the system's own permission prompt. No password
or account detail reaches myData, and every account set up on the Mac is covered.

Lifecycle
- Only on macOS (`available`). Elsewhere the source does not exist: it is not listed at all.
- While enabled, the host listens on <home>/run/reader.sock and starts the helper through LaunchServices
  (launcher.py). If the helper goes away or does not connect, it is started again after 5 s, 30 s,
  2 min, then every 10 min. The count goes back to the start only once a snapshot has been stored (or
  after a connection that lasted STABLE_AFTER), so a helper that fails the same way on every read is
  not restarted every few seconds. A message over the line limit goes straight to the longest pause,
  since the same data would fail the same way; "Sync now" tries at once.
- Turning the source off stops the helper and deletes everything it mirrored (both stores). Stopping
  the host stops the helper.

Permission
- The helper reports the status of each kind without prompting. It asks the system only when the host
  sends request_access, which happens only when the user presses Allow in the myData app
  (POST /sources/mac/request-access). Never at login.
- When access to a kind is taken away (denied, restricted, or calendars write-only), what was mirrored
  of that kind is deleted: access taken away in System Settings takes the copy away too. "Not asked yet"
  keeps the copy, unread until the user allows access again: macOS reports it when myData's signing
  identity changes (every ad hoc rebuild), which is not the user taking anything away.

Reading
- On connect, the host asks for every readable kind (with the window it expects), again when a kind is
  allowed, when the choice changes, and on "Sync now". The helper remembers what was asked and re-reads
  by itself: when the Mac's data changes, every 15 minutes (safety net), and when the day changes (the
  calendar window moves). The host does not repeat those reads; it records the window each events
  snapshot reports.
- The user chooses which contact containers (accounts) and calendars are included; by default all.
  Narrowing the choice deletes the rows no longer included.
- Calendars: a rolling window, one year back and two years ahead. Contacts: every chosen container.
  Contact notes are never read (notes_included is false).
- A large snapshot arrives in parts (protocol.py); the rows are replaced only when the last part is in.
- Writes go into the existing stores under the sync service's data lock, and only while the source is
  enabled, so a snapshot arriving while it is turned off cannot bring data back.

Status (enabled, the choice, the last statuses, the containers and calendars seen, last_update,
last_error) is kept in state.json under "mac", and survives a restart.
"""

from __future__ import annotations

import logging
import sys
import threading
import time
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Callable

from ...service.logs import log
from ...service.state import HostState
from ..calendar_store import CalendarStore
from ..contacts_store import ContactsStore
from ..dav.discovery import Collection
from ..dav.sync import CollectionState, Item, SyncResult
from . import MAC_ID, protocol
from .cards import etag, to_vcard
from .launcher import LaunchError, MacReaderLauncher, validate_helper_path
from .socket import MAX_LINE, ReaderSocket, ReaderSocketError

logger = logging.getLogger("mydata.mac")

STATE_KEY = "mac"
CONTACTS_URL = "mac://contacts/"
CALENDARS_URL = "mac://calendars/"

WINDOW_BACK_YEARS = 1
WINDOW_AHEAD_YEARS = 2
RELAUNCH = (5.0, 30.0, 120.0, 600.0)
STABLE_AFTER = 600.0  # a connection this long resets the relaunch pauses, even with nothing read
CONNECT_TIMEOUT = 20.0
ACCESS_TIMEOUT = 180.0  # the user may take a while to answer the system prompt

UNKNOWN = protocol.UNKNOWN  # a status the helper has not reported yet, or one this host does not know

MSG_NOT_STARTED = "The reader on this Mac did not start. The host will try again."
MSG_GONE = "The reader on this Mac stopped. The host is starting it again."
MSG_TOO_LONG = ("The reader sent more than the host takes in one piece. The host tries again in 10 minutes, "
                "or when you choose Sync now.")

_UNSET: Any = object()


class MacUnavailable(Exception):
    """This host is not a Mac: the source does not exist here."""


class MacNotEnabled(Exception):
    """The action needs This Mac to be turned on."""


def add_years(day: date, years: int) -> date:
    try:
        return day.replace(year=day.year + years)
    except ValueError:  # 29 February in a year without one
        return day.replace(year=day.year + years, day=28)


def window_for(today: date) -> tuple[date, date]:
    """The days of events mirrored: one year back and two years ahead, both ends included."""
    return add_years(today, -WINDOW_BACK_YEARS), add_years(today, WINDOW_AHEAD_YEARS)


def _iso_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class MacSource:
    def __init__(self, home: Path, *, contacts: Callable[[], Any], calendar: Callable[[], Any], state: HostState,
                 existing_stores: Callable[[], list] | None = None,
                 launcher: MacReaderLauncher | None = None, platform: str = sys.platform,
                 today: Callable[[], date] = date.today, data_lock: threading.RLock | None = None,
                 on_enabled_changed: Callable[[], None] | None = None, relaunch: tuple[float, ...] = RELAUNCH, connect_timeout: float = CONNECT_TIMEOUT,
                 access_timeout: float = ACCESS_TIMEOUT, tick: float = 1.0, max_line: int = MAX_LINE,
                 clock: Callable[[], float] = time.monotonic):
        self.home = Path(home)
        self._contacts, self._calendar = contacts, calendar
        # The stores whose files exist (deleting never creates an empty file); both when not given.
        self._existing_stores = existing_stores or (lambda: [contacts(), calendar()])
        self.state = state
        self.launcher = launcher or MacReaderLauncher()
        self.platform = platform
        self.today = today
        self._data_lock = data_lock or threading.RLock()
        self.on_enabled_changed = on_enabled_changed
        self.relaunch = relaunch
        self.connect_timeout, self.access_timeout, self.tick = connect_timeout, access_timeout, tick
        self.max_line = max_line
        self.clock = clock

        self._lock = threading.RLock()
        self._launch_lock = threading.Lock()
        self._socket: ReaderSocket | None = None
        self._ready = threading.Event()  # the helper said hello on the current connection
        self._status_cond = threading.Condition()
        self._status_seq = 0
        self._failures = 0
        self._next_launch = 0.0
        self._pending = False  # launched, and not connected yet
        self._connected_at: float | None = None  # when the current helper said hello
        self._parts: dict[tuple, dict] = {}  # snapshots arriving in parts, until their last part
        self._wake = threading.Event()
        self._stopping = threading.Event()
        self._thread: threading.Thread | None = None

    def __repr__(self) -> str:
        return f"MacSource(home={str(self.home)!r})"

    # ---------------------------------------------------------------- settings

    @property
    def available(self) -> bool:
        return self.platform == "darwin"

    def _settings(self) -> dict:
        return self.state.section(STATE_KEY)

    def _save(self, **changes) -> dict:
        return self.state.update_section(STATE_KEY, **changes)

    @property
    def enabled(self) -> bool:
        return self.available and bool(self._settings().get("enabled", False))

    def _selection(self, key: str) -> list[str] | None:
        value = self._settings().get(key)
        return [str(v) for v in value] if isinstance(value, list) else None

    def _known(self, key: str) -> list[dict]:
        value = self._settings().get(key)
        return [v for v in value if isinstance(v, dict) and isinstance(v.get("id"), str)] if isinstance(value, list) \
            else []

    def _included(self, selection_key: str) -> set[str] | None:
        """The ids included: None means all (no choice made)."""
        chosen = self._selection(selection_key)
        return None if chosen is None else set(chosen)

    @staticmethod
    def _is_in(item_id: str, included: set[str] | None) -> bool:
        return included is None or item_id in included

    def _status(self, kind: str) -> str:
        value = self._settings().get(f"{kind}_status")
        return value if isinstance(value, str) else UNKNOWN

    def _readable(self, kind: str) -> bool:
        status = self._status(kind)
        return status in (protocol.CONTACTS_READABLE if kind == "contacts" else protocol.CALENDARS_READABLE)

    @property
    def reader_path(self) -> Path | None:
        value = self._settings().get("reader_path")
        return Path(value) if isinstance(value, str) and value else None

    def set_reader_path(self, path: str) -> Path:
        """Where the myData app's helper is (reported by the app). Raises ValueError when it is not the reader."""
        if not self.available:
            raise MacUnavailable()
        validate = getattr(self.launcher, "validate", None) or validate_helper_path
        checked = validate(path)
        self._save(reader_path=str(checked))
        if self.enabled and not self.connected:
            self._launch_soon()
        return checked

    # ---------------------------------------------------------------- what the API shows

    @property
    def connected(self) -> bool:
        return self._ready.is_set() and self._socket is not None and self._socket.connected

    def window(self) -> dict | None:
        value = self._settings().get("window")
        return dict(value) if isinstance(value, dict) else None

    def public(self) -> dict:
        s = self._settings()
        containers, calendars = self._included("contact_containers"), self._included("calendars")
        return {
            "id": MAC_ID, "kind": "mac", "available": self.available, "enabled": self.enabled,
            "decided": isinstance(s.get("enabled"), bool),
            "contacts_status": self._status("contacts"), "calendars_status": self._status("calendars"),
            "contact_containers": [{"id": c["id"], "name": c.get("name", ""), "kind": c.get("kind", ""),
                                    "included": self._is_in(c["id"], containers)}
                                   for c in self._known("known_containers")],
            "calendars": [{"id": c["id"], "name": c.get("name", ""), "source_name": c.get("source_name", ""),
                           "color": c.get("color"), "included": self._is_in(c["id"], calendars)}
                          for c in self._known("known_calendars")],
            "all_contact_containers": containers is None, "all_calendars": calendars is None,
            "notes_included": False, "window": self.window(), "reader_running": self.connected,
            "last_update": s.get("last_update"), "last_error": s.get("last_error"),
        }

    def calendar_accounts(self) -> dict[str, dict]:
        """{calendar id: {"source_name", "source_kind"}} for the calendars the helper last listed: the account
        each belongs to on the Mac, as macOS names and classifies it."""
        return {c["id"]: {"source_name": c.get("source_name", "") or "", "source_kind": c.get("source_kind", "")}
                for c in self._known("known_calendars")}

    def coverage_note(self) -> dict | None:
        """This Mac as a coverage entry with no range, for when the calendar store holds no window for it:
        why ("no_access" or "not_read_yet"). None when it is off. The sync service adds it only when the
        store has no coverage row for This Mac; it is never "complete"."""
        if not self.enabled:
            return None
        status = self._status("calendars")
        reason = "no_access" if status in ("denied", "restricted", "writeOnly") else "not_read_yet"
        return {"source": "mac", "account_id": MAC_ID, "covered_start": None, "covered_end": None,
                "complete": False, "reason": reason}

    # ---------------------------------------------------------------- lifecycle

    def start(self) -> None:
        """At host start: remove what a source turned off left behind, then run if enabled."""
        if not self.available:
            return
        if not self.enabled:
            self._delete_all()
            return
        self._launch_soon()
        self._ensure_thread()

    def stop(self) -> None:
        """At host stop: stop the helper (the data stays)."""
        self._stopping.set()
        self._wake.set()
        thread, self._thread = self._thread, None
        if thread is not None and thread is not threading.current_thread():
            thread.join(timeout=5)
        self._close()

    def _ensure_thread(self) -> None:
        with self._lock:
            if self._thread is not None and self._thread.is_alive():
                return
            self._stopping.clear()
            self._thread = threading.Thread(target=self._loop, name="mac-source", daemon=True)
            self._thread.start()

    def _open(self) -> ReaderSocket:
        with self._lock:
            if self._socket is None:
                sock = ReaderSocket(self.home, on_line=self._on_line, on_connect=self._on_connect,
                                    on_disconnect=self._on_disconnect, max_line=self.max_line)
                sock.start()
                self._socket = sock
            return self._socket

    def _close(self) -> None:
        with self._lock:
            sock, self._socket = self._socket, None
            self._ready.clear()
        if sock is not None:
            sock.send(protocol.encode(protocol.cmd_quit()))
            sock.close()

    def _open_and_launch(self) -> None:
        """Listen, then start the helper. Only the source's own thread starts the helper (one at a time);
        everyone else asks it to, with _launch_soon."""
        try:
            self._open()
        except ReaderSocketError as e:
            self._schedule_retry(str(e))
            return
        except OSError as e:
            self._schedule_retry(f"Could not open the reader's socket ({type(e).__name__}).")
            return
        self._launch()

    def _launch(self) -> None:
        """Start the helper now, unless one is connected or starting. Failures are retried by the loop."""
        with self._launch_lock:
            sock = self._socket
            if sock is None or sock.connected or not self.enabled:
                return
            if self._pending and self.clock() < self._next_launch:
                return  # one is starting already
            with self._lock:
                self._pending = True
                self._next_launch = self.clock() + self.connect_timeout
            try:
                self.launcher.launch(sock.path, self.reader_path)
            except LaunchError as e:
                with self._lock:
                    self._pending = False
                self._schedule_retry(str(e))
                log(logger, logging.WARNING, "the reader could not be started")
                return
            log(logger, logging.INFO, "reader started")

    def _delay(self) -> float:
        return self.relaunch[min(max(self._failures, 1), len(self.relaunch)) - 1]

    def _schedule_retry(self, message: str | None, *, longest: bool = False) -> None:
        with self._lock:
            self._failures = max(self._failures + 1, len(self.relaunch) if longest else 0)
            self._next_launch = self.clock() + self._delay()
        if message:
            self._error(message)

    def _loop(self) -> None:
        while not self._stopping.is_set():
            try:
                self._maintain()
            except Exception:  # noqa: BLE001 - the loop must survive anything
                logger.exception("This Mac source loop failed")
            self._wake.wait(self.tick)
            self._wake.clear()

    def _maintain(self) -> None:
        if not self.enabled:
            return
        if self._socket is None:
            if self.clock() >= self._next_launch:
                self._open_and_launch()
            return
        if not self._socket.connected:
            if self.clock() < self._next_launch:
                return
            if self._pending:  # started, but it never connected: try again after a pause
                with self._lock:
                    self._pending = False
                self._schedule_retry(MSG_NOT_STARTED)
                return
            self._launch()

    # ---------------------------------------------------------------- user actions

    def configure(self, *, enabled: bool | None = None, contact_containers: Any = _UNSET,
                  calendars: Any = _UNSET) -> dict:
        """Turn the source on or off and choose what is included (None = everything). Unset arguments
        keep their value. Turning it off stops the helper and deletes everything it mirrored."""
        if not self.available:
            raise MacUnavailable()
        was = self.enabled
        changes: dict = {}
        if contact_containers is not _UNSET:
            changes["contact_containers"] = None if contact_containers is None else sorted(set(contact_containers))
        if calendars is not _UNSET:
            changes["calendars"] = None if calendars is None else sorted(set(calendars))
        if enabled is not None:
            changes["enabled"] = bool(enabled)
        if enabled is False:
            with self._data_lock:  # in-flight snapshots check `enabled` under this lock
                self._save(**changes)
            self._close()
            self._delete_all()
            self._save(contacts_status=None, calendars_status=None, known_containers=[], known_calendars=[],
                       window=None, last_update=None, last_error=None)
            log(logger, logging.INFO, "This Mac turned off; its mirrored data was deleted")
        else:
            self._save(**changes)
            if self.enabled:
                self._prune()
                if not was:
                    log(logger, logging.INFO, "This Mac turned on")
                    self._launch_soon()
                    self._ensure_thread()
                elif self.connected:
                    kinds = [k for k, key in (("contacts", "contact_containers"), ("calendars", "calendars"))
                             if key in changes]
                    if kinds:
                        self.request_read("all" if len(kinds) == 2 else kinds[0])
        if was != self.enabled and self.on_enabled_changed is not None:
            try:
                self.on_enabled_changed()
            except Exception:  # noqa: BLE001
                logger.exception("after turning This Mac on or off")
        return self.public()

    def request_access(self, what: str) -> dict:
        """Ask the helper to show the system's permission prompt for contacts or calendars; wait for the
        answer (up to access_timeout) and return the source as it is then."""
        if not self.available:
            raise MacUnavailable()
        if what not in protocol.ACCESS_KINDS:
            raise ValueError("what must be contacts or calendars")
        if not self.enabled:
            raise MacNotEnabled()
        self._ensure_thread()
        if not self.connected:
            self._launch_soon()
            if not self._ready.wait(self.connect_timeout):
                raise TimeoutError(MSG_NOT_STARTED)
        with self._status_cond:
            seq = self._status_seq
        if not self._send(protocol.cmd_request_access(what)):
            raise TimeoutError(MSG_NOT_STARTED)
        log(logger, logging.INFO, "asked the reader to request access", what=what)
        with self._status_cond:
            self._status_cond.wait_for(lambda: self._status_seq > seq, timeout=self.access_timeout)
        return self.public()

    def sync_now(self) -> dict:
        if not self.available:
            raise MacUnavailable()
        if not self.enabled:
            raise MacNotEnabled()
        self._ensure_thread()
        if self.connected:
            self.request_read("all")
        else:
            self._launch_soon()
        return self.public()

    def _launch_soon(self) -> None:
        """Have the source's thread start the helper at its next tick (now), unless one is connected or
        already starting."""
        with self._lock:
            if not (self._pending and self.clock() < self._next_launch):
                self._next_launch, self._pending = 0.0, False
        self._wake.set()

    def request_read(self, what: str) -> bool:
        """Ask the helper for the readable part of `what` with the current choice and window."""
        kinds = {"contacts", "calendars"} if what == "all" else {what}
        kinds = {k for k in kinds if self._readable(k)}
        if not kinds:
            return False
        ask = "all" if len(kinds) == 2 else next(iter(kinds))
        return self._send(protocol.cmd_read(ask, self._selection("contact_containers"),
                                            self._selection("calendars"), window_for(self.today())))

    def _send(self, cmd: dict) -> bool:
        sock = self._socket
        return sock.send(protocol.encode(cmd)) if sock is not None else False

    # ---------------------------------------------------------------- from the helper

    def _on_connect(self, _conn) -> None:
        self._ready.clear()

    def _on_disconnect(self, why: str) -> None:
        was_ready = self._ready.is_set()
        self._ready.clear()
        with self._lock:
            self._pending = False
            self._parts.clear()
            since, self._connected_at = self._connected_at, None
            if since is not None and self.clock() - since >= STABLE_AFTER:
                self._failures = 0  # it ran a long while: start again with the short pause
        if self.enabled and not self._stopping.is_set():
            if why == "too_long":
                self._schedule_retry(MSG_TOO_LONG, longest=True)
            else:
                self._schedule_retry(MSG_GONE if was_ready else None)
            log(logger, logging.WARNING, "reader disconnected", reason=why)

    def _on_line(self, line: bytes) -> None:
        try:
            message = protocol.parse(line)
        except protocol.ProtocolError as e:
            log(logger, logging.WARNING, "ignored a message from the reader", problem=str(e))
            return
        if message is None:
            return
        handler = {
            protocol.Hello: self._on_hello, protocol.Status: self._on_status,
            protocol.ContactContainers: self._on_containers, protocol.Calendars: self._on_calendars,
            protocol.ContactsSnapshot: self._on_contacts, protocol.EventsSnapshot: self._on_events,
            protocol.Changed: self._on_changed, protocol.HelperError: self._on_error,
        }[type(message)]
        handler(message)

    def _on_hello(self, m: protocol.Hello) -> None:
        if m.version != protocol.VERSION:
            log(logger, logging.WARNING, "the reader speaks another protocol version", version=m.version)
        with self._lock:
            self._pending = False  # the pauses are reset only once a snapshot is stored (_stored)
            self._connected_at = self.clock()
        self._apply_status(m.contacts, m.calendars)
        self._ready.set()
        log(logger, logging.INFO, "reader connected", contacts=m.contacts, calendars=m.calendars)
        self.request_read("all")

    def _on_status(self, m: protocol.Status) -> None:
        before = {k: self._readable(k) for k in ("contacts", "calendars")}
        self._apply_status(m.contacts, m.calendars)
        log(logger, logging.INFO, "reader status", contacts=m.contacts, calendars=m.calendars)
        now = [k for k in ("contacts", "calendars") if self._readable(k) and not before[k]]
        if now and self._ready.is_set():
            self.request_read("all" if len(now) == 2 else now[0])

    def _apply_status(self, contacts: str, calendars: str) -> None:
        with self._data_lock:
            if not self.enabled:
                return
            self._save(contacts_status=contacts, calendars_status=calendars)
            if contacts in protocol.CONTACTS_NO_ACCESS:
                self._delete_contacts()
            if calendars in protocol.CALENDARS_NO_ACCESS:
                self._delete_calendars()
        with self._status_cond:
            self._status_seq += 1
            self._status_cond.notify_all()

    def _on_containers(self, m: protocol.ContactContainers) -> None:
        with self._data_lock:
            if not self.enabled:
                return
            self._save(known_containers=[{"id": c.id, "name": c.name, "kind": c.kind} for c in m.items])
            self._prune_contacts()

    def _on_calendars(self, m: protocol.Calendars) -> None:
        with self._data_lock:
            if not self.enabled:
                return
            self._save(known_calendars=[{"id": c.id, "name": c.name, "source_name": c.source_name,
                                         "source_kind": c.source_kind, "color": c.color} for c in m.items])
            included = self._included("calendars")
            store = self._calendar()
            for c in m.items:
                if self._is_in(c.id, included):
                    store.upsert_calendar(MAC_ID, CALENDARS_URL + c.id, c.name, c.color)
            self._prune_calendars()

    def _assemble(self, key: tuple, m, first: dict) -> dict | None:
        """Collect a snapshot that comes in parts. Returns {"items", "skipped", **first} once its last part is
        in, else None. A part out of order (or of another window) drops what was collected for that key."""
        with self._lock:
            buf = {"next": 0, "items": [], "skipped": 0, **first} if m.part == 0 else self._parts.pop(key, None)
            if buf is None or buf["next"] != m.part or any(buf[k] != v for k, v in first.items()):
                log(logger, logging.WARNING, "dropped a snapshot that arrived out of order", part=m.part)
                return None
            buf["items"].extend(m.items)
            buf["skipped"] += m.skipped
            buf["next"] += 1
            if m.last:
                return buf
            self._parts[key] = buf
            return None

    def _stored(self) -> None:
        """A snapshot was stored: the helper works, so the next restart waits only the short pause."""
        with self._lock:
            self._failures = 0
        self._updated()

    def _on_contacts(self, m: protocol.ContactsSnapshot) -> None:
        whole = self._assemble(("contacts", m.container_id), m, {})
        if whole is None:
            return
        with self._data_lock:
            if not self.enabled or not self._is_in(m.container_id, self._included("contact_containers")):
                return
            name = next((c.get("name", "") for c in self._known("known_containers") if c["id"] == m.container_id), "")
            collection = Collection(CONTACTS_URL + m.container_id, "contacts", name)
            items, etags = [], {}
            for contact in whole["items"]:
                card = to_vcard(contact)
                tag = etag(card)
                items.append(Item(href=contact.id, etag=tag, data=card))
                etags[contact.id] = tag
            self._contacts().apply(MAC_ID, collection, SyncResult(changed=items, deleted=[],
                                                                  state=CollectionState(etags=etags), full=True))
            self._stored()
        log(logger, logging.INFO, "contacts read from this Mac", count=len(whole["items"]), skipped=whole["skipped"],
            parts=whole["next"])

    def _on_events(self, m: protocol.EventsSnapshot) -> None:
        whole = self._assemble(("events",), m, {"window": (m.window_start, m.window_end)})
        if whole is None:
            return
        with self._data_lock:
            if not self.enabled:
                return
            included = self._included("calendars")
            known = {c["id"]: c for c in self._known("known_calendars")}
            store = self._calendar()
            ids = store.calendar_ids(MAC_ID)
            by_calendar: dict[str, list] = {}
            for o in whole["items"]:
                if not self._is_in(o.calendar_id, included):
                    continue
                url = CALENDARS_URL + o.calendar_id
                if url not in ids:
                    c = known.get(o.calendar_id, {})
                    ids[url] = store.upsert_calendar(MAC_ID, url, c.get("name", ""), c.get("color"))
                by_calendar.setdefault(ids[url], []).append(o)
            counts = store.replace_occurrences(MAC_ID, (m.window_start, m.window_end), by_calendar)
            self._save(window={"start": m.window_start.isoformat(), "end": m.window_end.isoformat()})
            self._stored()
        log(logger, logging.INFO, "events read from this Mac", skipped=whole["skipped"], parts=whole["next"], **counts)

    def _on_changed(self, m: protocol.Changed) -> None:
        log(logger, logging.INFO, "the Mac's data changed", what=m.what)

    def _on_error(self, m: protocol.HelperError) -> None:
        log(logger, logging.WARNING, "the reader reported an error")
        self._error(f"The reader on this Mac reported a problem: {m.message}" if m.message
                    else "The reader on this Mac reported a problem.")

    def _updated(self) -> None:
        self._save(last_update=_iso_now(), last_error=None)

    def _error(self, message: str) -> None:
        if self.enabled:
            self._save(last_error=message)

    # ---------------------------------------------------------------- deleting

    def _prune(self) -> None:
        with self._data_lock:
            self._prune_contacts()
            self._prune_calendars()

    def _prune_contacts(self) -> None:
        """Delete address books not included, or no longer on the Mac (when the Mac's list is known)."""
        included = self._included("contact_containers")
        known = {c["id"] for c in self._known("known_containers")}
        store = self._existing(ContactsStore)
        if store is None:
            return
        gone = []
        for url in store.address_book_ids(MAC_ID):
            cid = url[len(CONTACTS_URL):]
            if not self._is_in(cid, included) or (known and cid not in known):
                gone.append(url)
        if gone:
            store.delete_collections(MAC_ID, gone)

    def _prune_calendars(self) -> None:
        included = self._included("calendars")
        known = {c["id"] for c in self._known("known_calendars")}
        store = self._existing(CalendarStore)
        if store is None:
            return
        gone = []
        for url in store.calendar_ids(MAC_ID):
            cid = url[len(CALENDARS_URL):]
            if not self._is_in(cid, included) or (known and cid not in known):
                gone.append(url)
        if gone:
            store.delete_calendars(MAC_ID, gone)

    def _existing(self, kind: type):
        return next((s for s in self._existing_stores() if isinstance(s, kind)), None)

    def _delete_kind(self, kind: type) -> None:
        """Hard-delete This Mac's rows from the stores of this kind that exist (none is created)."""
        with self._data_lock:
            for store in self._existing_stores():
                if isinstance(store, kind) and MAC_ID in store.account_ids():
                    store.delete_account(MAC_ID)

    def _delete_contacts(self) -> None:
        self._delete_kind(ContactsStore)

    def _delete_calendars(self) -> None:
        self._delete_kind(CalendarStore)
        if self.window() is not None:
            self._save(window=None)

    def _delete_all(self) -> None:
        """Hard-delete everything This Mac mirrored, in both stores (files that do not exist stay absent)."""
        self._delete_kind(object)
