"""The trash expiry: once a day while the host runs (and at start), what has been in Recently deleted for 30
days is deleted for good (sources/contacts_write.expire_trash, through purge permits).

Only owned data is ever in the trash. A file that does not exist is never created for this, and a store that
cannot be opened (its migration refused) is left until the next run. The log names counts only. Copies in the
host's snapshots stay until those expire.
"""

from __future__ import annotations

import logging
import threading
from collections.abc import Callable
from datetime import datetime

from .logs import log

logger = logging.getLogger("mydata.trash")

INTERVAL = 24 * 60 * 60.0


class TrashExpiry:
    def __init__(self, sources, *, interval: float = INTERVAL, clock: Callable[[], datetime] | None = None):
        self.sources = sources  # a SyncService: its stores, opened on first use
        self.interval = interval
        self.clock = clock
        self._stopping = threading.Event()
        self._thread: threading.Thread | None = None

    def run_once(self) -> int:
        """Purge what is due; returns how many items went (0 also when there was nothing to look at)."""
        from ..sources import contacts_write
        from .sync import CONTACTS_FILE
        if self.sources._contacts is None and not (self.sources.home / CONTACTS_FILE).exists():
            return 0
        try:
            gone = contacts_write.expire_trash(self.sources.contacts, self.clock() if self.clock else None)
        except Exception as e:  # the next run tries again
            log(logger, logging.ERROR, "the trash expiry failed", error=type(e).__name__)
            return 0
        if gone:
            log(logger, logging.INFO, "deleted for good after 30 days in Recently deleted", contacts=gone)
        return gone

    def start(self) -> None:
        if self._thread is None:
            self._thread = threading.Thread(target=self._loop, name="mydata-trash", daemon=True)
            self._thread.start()

    def stop(self, timeout: float = 10) -> None:
        self._stopping.set()
        if self._thread is not None:
            self._thread.join(timeout)
            self._thread = None

    def _loop(self) -> None:
        while not self._stopping.is_set():
            self.run_once()
            self._stopping.wait(self.interval)
