"""A fake myDataReader helper for the host's tests: a thread that connects to the host's real Unix socket
and speaks the helper's protocol, over invented data (data.py). It never touches Contacts or EventKit.

    mac = FakeMac(contacts="notDetermined", calendars="notDetermined", answer="grant")
    SyncService(..., platform="darwin", mac_launcher=mac.launcher)

Every launch starts a FakeHelper; mac.helper is the latest. It records each command it gets. With
mac.part_size set, snapshots go in parts of that many items, as the real helper splits large ones.
"""

from __future__ import annotations

import copy
import json
import socket
import threading
import time
from datetime import date, datetime

from . import data

READABLE = {"contacts": ("authorized",), "calendars": ("fullAccess",)}
GRANTED = {"contacts": "authorized", "calendars": "fullAccess"}


class FakeMac:
    """The Mac's data and permission state, shared by every helper the host starts."""

    def __init__(self, contacts: str = "notDetermined", calendars: str = "notDetermined", answer: str = "grant"):
        self.status = {"contacts": contacts, "calendars": calendars}
        self.answer = answer  # what the user answers to the system prompt: "grant" or "deny"
        self.containers = copy.deepcopy(data.CONTAINERS)
        self.contacts = copy.deepcopy(data.CONTACTS)
        self.calendars = copy.deepcopy(data.CALENDARS)
        self.occurrences = copy.deepcopy(data.OCCURRENCES)
        self.helpers: list[FakeHelper] = []
        self.launches: list[tuple] = []
        self.part_size: int | None = None  # items per snapshot part; None sends each snapshot whole
        self.events_fail = False  # EventKit fails after listing calendars: an error instead of the snapshot
        self.launcher = FakeLauncher(self)

    @property
    def helper(self) -> "FakeHelper | None":
        return self.helpers[-1] if self.helpers else None


class FakeLauncher:
    """Stands in for MacReaderLauncher: "launching" starts a FakeHelper thread."""

    def __init__(self, mac: FakeMac, fail: bool = False):
        self.mac = mac
        self.fail = fail

    def validate(self, path):
        """The real path checks, without codesign: the tests' bundles are made up and unsigned."""
        from mydata.sources.mac.launcher import validate_helper_path

        return validate_helper_path(path, signature=None)

    def launch(self, socket_path, helper_path) -> None:
        from mydata.sources.mac.launcher import LaunchError

        self.mac.launches.append((socket_path, helper_path))
        if self.fail:
            raise LaunchError("The reader was not found. Open the myData app once, so the host can find it.")
        helper = FakeHelper(self.mac, str(socket_path))
        self.mac.helpers.append(helper)
        helper.start()


class FakeHelper(threading.Thread):
    def __init__(self, mac: FakeMac, socket_path: str):
        super().__init__(name="fake-mac-helper", daemon=True)
        self.mac = mac
        self.socket_path = socket_path
        self.commands: list[dict] = []
        self.last_read: dict | None = None
        self.connected = threading.Event()
        self.finished = threading.Event()
        self._sock: socket.socket | None = None
        self._send_lock = threading.Lock()

    # ---------------------------------------------------------------- wire

    def send(self, obj: dict) -> None:
        line = (json.dumps(obj) + "\n").encode()
        with self._send_lock:
            if self._sock is not None:
                try:
                    self._sock.sendall(line)
                except OSError:
                    pass

    def run(self) -> None:
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(self.socket_path)
        except OSError:
            self.finished.set()
            return
        self._sock = sock
        self.connected.set()
        self.send({"type": "hello", "version": 1, **self.mac.status})
        reader = sock.makefile("rb")
        try:
            for raw in reader:
                cmd = json.loads(raw)
                self.commands.append(cmd)
                if not self.handle(cmd):
                    break
        except (OSError, ValueError):
            pass
        finally:
            self.close()
            self.finished.set()

    def close(self) -> None:
        with self._send_lock:
            sock, self._sock = self._sock, None
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            sock.close()

    # ---------------------------------------------------------------- behaviour

    def handle(self, cmd: dict) -> bool:
        kind = cmd.get("cmd")
        if kind == "quit":
            return False
        if kind == "status":
            self.send({"type": "status", **self.mac.status})
        elif kind == "request_access":
            what = cmd["what"]
            if self.mac.status[what] == "notDetermined":
                self.mac.status[what] = GRANTED[what] if self.mac.answer == "grant" else "denied"
            self.send({"type": "status", **self.mac.status})
        elif kind == "read":
            self.last_read = cmd
            self.read(cmd["what"])
        return True

    def readable(self, kind: str) -> bool:
        return self.mac.status[kind] in READABLE[kind]

    def read(self, what: str) -> None:
        cmd = self.last_read or {}
        if what in ("contacts", "all") and self.readable("contacts"):
            self.send({"type": "contact_containers", "items": self.mac.containers})
            chosen = cmd.get("containers")
            for c in self.mac.containers:
                if chosen is None or c["id"] in chosen:
                    self.send_parts({"type": "contacts_snapshot", "container_id": c["id"]},
                                    self.mac.contacts.get(c["id"], []))
        if what in ("calendars", "all") and self.readable("calendars"):
            self.send({"type": "calendars", "items": self.mac.calendars})
            if self.mac.events_fail:
                self.send({"type": "error", "message": "could not read calendars (EKErrorDomain 1)"})
                return
            first = date.fromisoformat(cmd.get("window_start") or "2025-01-01")
            last = date.fromisoformat(cmd.get("window_end") or "2027-12-31")
            chosen = cmd.get("calendars")
            items = [o for o in self.mac.occurrences
                     if (chosen is None or o["calendar_id"] in chosen) and first <= _day(o["start"]) <= last]
            self.send_parts({"type": "events_snapshot", "window_start": first.isoformat(),
                             "window_end": last.isoformat()}, items)

    def send_parts(self, head: dict, items: list) -> None:
        """A snapshot, whole or (with mac.part_size) in parts; an empty one is still one part."""
        size = self.mac.part_size
        if size is None:
            self.send({**head, "items": items})
            return
        chunks = [items[i:i + size] for i in range(0, len(items), size)] or [[]]
        for n, chunk in enumerate(chunks):
            self.send({**head, "part": n, "last": n == len(chunks) - 1, "items": chunk})

    def notify(self, what: str) -> None:
        """The Mac's data changed: say so, then re-read that kind with the last choice (as the helper does)."""
        self.send({"type": "changed", "what": what})
        self.read(what)

    def wait_for(self, predicate, timeout: float = 5.0) -> bool:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if predicate(self):
                return True
            time.sleep(0.01)
        return False


def _day(value: str) -> date:
    return date.fromisoformat(value) if len(value) == 10 else datetime.fromisoformat(value).date()
