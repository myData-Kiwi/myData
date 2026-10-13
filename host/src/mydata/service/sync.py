"""Keeps the read-only mirror of every linked account up to date.

One background thread in mydatad syncs each account's contacts and calendars: at host start, every
15 minutes, and at once when asked ("Sync now"). Accounts are synced one at a time. A failed sync is
retried after 15 minutes, then 30, 1 hour, 2 hours and at most every 4 hours, until one succeeds.

Per account the service reports {account_id, state (idle, syncing, error), last_success, last_error,
last_attempt, next_attempt, counts}. last_error is a short message for the user and never holds the
password or anything read from the account.

Logging is structured and holds account ids, collection ids, counts and error types only: never the
password, and never a name, address, phone number or event title.

Accounts added or removed by the mydata command while the host runs are noticed within POLL seconds.
One failing collection does not stop the others: an error while discovering one kind (contacts or
calendars) or while syncing one collection is logged with its collection id and error type, and the
rest are still synced. The account then shows the error (state "error", the first failure's message)
with its counts updated; if nothing at all could be synced, the retry backs off as above, otherwise the
next attempt is at the usual interval. A rejected password (HTTP 401) stops the whole sync at once.

Removing an account deletes its mirrored data under the same lock every write to the mirror takes,
and a sync re-checks that its account still exists before each write, so a sync running at the time
cannot bring the data back.
"""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from ..sources.accounts import Account, Accounts
from ..sources.calendar_store import CalendarStore
from ..sources.contacts_store import ContactsStore
from .logs import log

logger = logging.getLogger("mydata.sync")

INTERVAL = 15 * 60.0
BACKOFF = (15 * 60.0, 30 * 60.0, 60 * 60.0, 2 * 60 * 60.0, 4 * 60 * 60.0)
POLL = 5.0  # how often the loop looks for accounts the mydata command added or removed

CONTACTS_FILE = "contacts.sqlite"
CALENDAR_FILE = "calendar.sqlite"

MSG_PASSWORD = ("Apple rejected the password. Make a new app-specific password and add the account again.")
MSG_FORBIDDEN = "Apple refused access to this account's contacts or calendars."
MSG_UNREACHABLE = "Could not reach iCloud. The host will try again."
MSG_KEYCHAIN_MISSING = "The password for this account is missing from the Keychain. Remove the account and add it again."
MSG_KEYCHAIN = "The Keychain could not be read. The host will try again."


def _iso(ts: float | None) -> str | None:
    return datetime.fromtimestamp(ts, timezone.utc).isoformat(timespec="seconds") if ts is not None else None


def user_message(exc: BaseException) -> str:
    """A short message for the user. Built only from the error's type and HTTP status: exception text
    can hold server replies, and never reaches the user or the log."""
    from ..sources.dav.client import DavError
    from ..sources.secrets import SecretStoreError

    if isinstance(exc, DavError):
        if exc.status == 401:
            return MSG_PASSWORD
        if exc.status == 403:
            return MSG_FORBIDDEN
        if exc.status is None:
            return MSG_UNREACHABLE
        return f"iCloud answered with an error (HTTP {exc.status}). The host will try again."
    if isinstance(exc, KeyError):
        return MSG_KEYCHAIN_MISSING
    if isinstance(exc, SecretStoreError):
        return MSG_KEYCHAIN
    return f"Sync failed ({type(exc).__name__}). The host will try again."


def backoff_delay(failures: int, steps: tuple[float, ...] = BACKOFF) -> float:
    """Seconds to wait after the n-th failure in a row (n >= 1): 15m, 30m, 1h, 2h, then 4h."""
    return steps[min(max(failures, 1), len(steps)) - 1]


@dataclass
class AccountSync:
    account_id: str
    state: str = "idle"  # idle | syncing | error
    last_success: float | None = None
    last_error: str | None = None
    last_attempt: float | None = None
    due: float = 0.0  # when the next sync runs (clock seconds)
    failures: int = 0
    counts: dict[str, int] = field(default_factory=dict)

    def public(self) -> dict:
        return {"account_id": self.account_id, "state": self.state, "last_success": _iso(self.last_success),
                "last_error": self.last_error, "last_attempt": _iso(self.last_attempt),
                "next_attempt": _iso(self.due), "counts": dict(self.counts)}


class _AccountGone(Exception):
    """The account was removed while it was being synced; its results are thrown away."""


class PartialSync(Exception):
    """Some collections (or one kind's discovery) failed and the rest were synced. `first` is the first
    failure, which decides the message the user sees."""

    def __init__(self, first: BaseException, failed: int, synced: int, changes: dict[str, int]):
        super().__init__(f"{failed} part(s) of the sync failed ({type(first).__name__})")
        self.first, self.failed, self.synced, self.changes = first, failed, synced, changes


class SyncService:
    def __init__(self, home: Path, accounts: Accounts, *, transport=None, interval: float = INTERVAL,
                 backoff: tuple[float, ...] = BACKOFF, poll: float = POLL, clock: Callable[[], float] = time.time):
        self.home = Path(home)
        self.accounts = accounts
        self._transport = transport  # an httpx transport, for tests; None = the network
        self.interval, self.backoff, self.poll, self.clock = interval, backoff, poll, clock
        # Called (with no arguments) whenever the set of accounts changes: the host switches mode.
        self.on_accounts_changed: Callable[[], None] | None = None
        self._contacts: ContactsStore | None = None
        self._calendar: CalendarStore | None = None
        self._store_lock = threading.Lock()
        self._data_lock = threading.RLock()  # every write to the mirror, and every account deletion
        self._run_lock = threading.Lock()  # one account syncs at a time
        self._status_lock = threading.Lock()
        self._status: dict[str, AccountSync] = {}
        self._known: set[str] | None = None
        self._removed: set[str] = set()
        self._wake = threading.Event()
        self._stopping = threading.Event()
        self._thread: threading.Thread | None = None

    def __repr__(self) -> str:
        return f"SyncService(home={str(self.home)!r})"

    # ---------------------------------------------------------------- stores (opened on first use)

    @property
    def contacts(self) -> ContactsStore:
        with self._store_lock:
            if self._contacts is None:
                self._contacts = ContactsStore(self.home / CONTACTS_FILE)
            return self._contacts

    @property
    def calendar(self) -> CalendarStore:
        with self._store_lock:
            if self._calendar is None:
                self._calendar = CalendarStore(self.home / CALENDAR_FILE)
            return self._calendar

    def _existing_stores(self) -> list:
        """The stores whose files exist; deleting data never creates an empty file."""
        out = []
        if self._contacts is not None or (self.home / CONTACTS_FILE).exists():
            out.append(self.contacts)
        if self._calendar is not None or (self.home / CALENDAR_FILE).exists():
            out.append(self.calendar)
        return out

    # ---------------------------------------------------------------- accounts

    def verify(self, provider: str, email: str, password: str) -> None:
        """The provider's check (discovery with these credentials); raises VerificationError."""
        from ..sources.providers import VERIFIERS
        verifier = VERIFIERS.get(provider)
        if verifier is None:
            raise ValueError(f"unknown provider {provider!r}")
        verifier(email, password, transport=self._transport)

    def add_account(self, provider: str, email: str, password: str) -> Account:
        """Verify, store (the password in the SecretStore only), and sync it as soon as possible."""
        account = self.accounts.add(provider, email, password, verify=lambda e, p: self.verify(provider, e, p))
        log(logger, logging.INFO, "account added", account_id=account.id, provider=provider)
        self._accounts_changed()
        self.request_sync(account.id)
        return account

    def remove_account(self, account_id: str) -> Account:
        """Hard-delete the account's mirrored data, then its secret and entry. KeyError if unknown."""
        account = self.accounts.remove(account_id, on_remove=self.delete_data)
        with self._status_lock:
            self._status.pop(account_id, None)
        log(logger, logging.INFO, "account removed", account_id=account_id)
        self._accounts_changed()
        return account

    def delete_data(self, account: Account) -> None:
        """Hard-delete everything mirrored from the account. A sync in progress for it stops writing."""
        with self._data_lock:
            self._removed.add(account.id)
            for store in self._existing_stores():
                store.delete_account(account.id)

    def _accounts_changed(self) -> None:
        self._known = {a.id for a in self.accounts.list()}
        self._purge_orphans()
        if self.on_accounts_changed is not None:
            try:
                self.on_accounts_changed()
            except Exception:
                logger.exception("switching mode after an account change failed")

    def _purge_orphans(self) -> None:
        """Delete data whose account no longer exists (removed by the mydata command mid-sync). The
        accounts are read under the data lock: every write checks its account exists under the same lock,
        so data written for an account added meanwhile is never mistaken for an orphan."""
        with self._data_lock:
            current = {a.id for a in self.accounts.list()}
            for store in self._existing_stores():
                for account_id in store.account_ids():
                    if account_id not in current:
                        store.delete_account(account_id)
                        log(logger, logging.INFO, "deleted data of a removed account", account_id=account_id)

    def check_accounts(self) -> None:
        """Notice accounts added or removed elsewhere (the mydata command)."""
        current = {a.id for a in self.accounts.list()}
        if current != self._known:
            self._accounts_changed()

    # ---------------------------------------------------------------- status

    def _entry(self, account_id: str) -> AccountSync:
        with self._status_lock:
            entry = self._status.get(account_id)
            if entry is None:
                entry = self._status[account_id] = AccountSync(account_id, due=self.clock())
            return entry

    def status(self) -> list[dict]:
        """Every account's sync status, in the accounts' order."""
        return [self._entry(a.id).public() for a in self.accounts.list()]

    def account_status(self, account_id: str) -> dict:
        if self.accounts.get(account_id) is None:
            raise KeyError(account_id)
        return self._entry(account_id).public()

    # ---------------------------------------------------------------- running

    def request_sync(self, account_id: str) -> dict:
        """Sync now: the account is synced next (after the one running, if any). KeyError if unknown."""
        if self.accounts.get(account_id) is None:
            raise KeyError(account_id)
        entry = self._entry(account_id)
        with self._status_lock:
            entry.due = self.clock()
        self._wake.set()
        return entry.public()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stopping.clear()
        self._thread = threading.Thread(target=self._loop, name="sync", daemon=True)
        self._thread.start()

    def stop(self, timeout: float = 10) -> None:
        self._stopping.set()
        self._wake.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=timeout)

    def _loop(self) -> None:
        while not self._stopping.is_set():
            try:
                self.check_accounts()
                self.run_due()
            except Exception:  # the loop must survive anything; the next pass tries again
                logger.exception("sync loop failed")
            self._wake.wait(self._next_wait())
            self._wake.clear()

    def _next_wait(self) -> float:
        now = self.clock()
        with self._status_lock:
            dues = [max(0.0, e.due - now) for e in self._status.values()]
        return min([self.poll, *dues])

    def run_due(self) -> int:
        """Sync every account that is due, one at a time. Returns how many ran."""
        ran = 0
        for account in self.accounts.list():
            if self._stopping.is_set():
                break
            if self._entry(account.id).due <= self.clock():
                self.sync_account(account.id)
                ran += 1
        return ran

    def sync_account(self, account_id: str) -> dict:
        """Sync one account now and return its status. Never raises for a sync failure: the error is
        recorded in the status and the next attempt is scheduled with backoff."""
        with self._run_lock:
            account = self.accounts.get(account_id)
            if account is None:
                raise KeyError(account_id)
            entry = self._entry(account_id)
            started = self.clock()
            with self._status_lock:
                entry.state, entry.last_attempt = "syncing", started
            log(logger, logging.INFO, "sync started", account_id=account_id)
            partial: PartialSync | None = None
            try:
                changes = self._sync(account)
            except PartialSync as p:
                if p.synced == 0:  # nothing worked: the same as a failed sync, with backoff
                    return self._failed(entry, p.first)
                partial, changes = p, p.changes
            except _AccountGone:
                log(logger, logging.INFO, "sync stopped: the account was removed", account_id=account_id)
                with self._status_lock:
                    self._status.pop(account_id, None)
                return AccountSync(account_id, state="idle").public()
            except Exception as e:  # noqa: BLE001 - any failure is a status with a retry
                return self._failed(entry, e)
            counts = {**self.contacts.counts(account_id), **self.calendar.counts(account_id)}
            with self._status_lock:
                entry.failures = 0
                entry.counts = counts
                entry.due = self.clock() + self.interval
                if partial is None:
                    entry.state, entry.last_error, entry.last_success = "idle", None, self.clock()
                else:  # what could be synced is; the error stays visible until a sync has no failure
                    entry.state, entry.last_error = "error", user_message(partial.first)
            if partial is None:
                log(logger, logging.INFO, "sync finished", account_id=account_id,
                    seconds=round(self.clock() - started, 2), **changes, **counts)
            else:
                log(logger, logging.WARNING, "sync finished with failures", account_id=account_id,
                    seconds=round(self.clock() - started, 2), failed=partial.failed, synced=partial.synced,
                    error=type(partial.first).__name__, status=getattr(partial.first, "status", None),
                    **changes, **counts)
            return entry.public()

    def _failed(self, entry: AccountSync, e: BaseException) -> dict:
        with self._status_lock:
            entry.failures += 1
            entry.state, entry.last_error = "error", user_message(e)
            entry.due = self.clock() + backoff_delay(entry.failures, self.backoff)
        log(logger, logging.WARNING, "sync failed", account_id=entry.account_id, error=type(e).__name__,
            status=getattr(e, "status", None), failures=entry.failures,
            retry_in_seconds=round(entry.due - self.clock()))
        return entry.public()

    def _guarded(self, account_id: str, write: Callable[[], None]) -> None:
        """Write to the mirror only while the account still exists (checked under the data lock)."""
        with self._data_lock:
            if account_id in self._removed or self.accounts.get(account_id) is None:
                raise _AccountGone()
            write()

    def _sync(self, account: Account) -> dict[str, int]:
        from ..sources.dav.client import DavClient
        from ..sources.dav.discovery import discover
        from ..sources.dav.sync import sync_collection
        from ..sources.providers import PROVIDERS

        start_urls = PROVIDERS[account.provider]
        client = DavClient(account.email, self.accounts.password(account.id), transport=self._transport)
        changed = deleted = 0
        failures: list[BaseException] = []
        synced = 0
        try:
            for kind, store in (("contacts", self.contacts), ("calendar", self.calendar)):
                try:
                    found = discover(client, start_urls[kind], kind)
                except Exception as e:  # noqa: BLE001 - this kind is skipped; its stored data is left as it is
                    _stop_on_password(e)
                    failures.append(e)
                    log(logger, logging.WARNING, "discovery failed", account_id=account.id, kind=kind,
                        error=type(e).__name__, status=getattr(e, "status", None))
                    continue
                urls = [c.url for c in found.collections]
                self._guarded(account.id, lambda: store.mark_collections_gone(account.id, urls))
                outcomes = []  # (url, result or None, error or None)
                for collection in found.collections:
                    try:
                        state = store.collection_state(account.id, collection.url)
                        result = sync_collection(client, collection, state)
                        self._guarded(account.id, lambda: store.apply(account.id, collection, result))
                    except _AccountGone:
                        raise
                    except Exception as e:  # noqa: BLE001 - one bad collection must not stop the rest
                        _stop_on_password(e)
                        failures.append(e)
                        outcomes.append((collection.url, None, e))
                        continue
                    synced += 1
                    outcomes.append((collection.url, result, None))
                    changed += len(result.changed)
                    deleted += len(result.deleted)
                # Collection ids, never URLs: an iCloud URL holds the account's identifier (DSID).
                ids = self._collection_ids(store, account.id)
                for url, result, error in outcomes:
                    if error is not None:
                        log(logger, logging.WARNING, "collection sync failed", account_id=account.id, kind=kind,
                            collection_id=ids.get(url), error=type(error).__name__,
                            status=getattr(error, "status", None))
                        continue
                    log(logger, logging.INFO, "collection synced", account_id=account.id, kind=kind,
                        collection_id=ids.get(url), changed=len(result.changed), deleted=len(result.deleted),
                        full=result.full, reason=result.reason, unresolved=result.unresolved)
                    if result.unresolved:
                        log(logger, logging.WARNING, "changed items were not returned; asked for again next sync",
                            account_id=account.id, kind=kind, collection_id=ids.get(url), count=result.unresolved)
        finally:
            client.close()
        changes = {"changed": changed, "deleted": deleted}
        if failures:
            raise PartialSync(failures[0], failed=len(failures), synced=synced, changes=changes)
        return changes

    @staticmethod
    def _collection_ids(store, account_id: str) -> dict[str, str]:
        rows = store.address_books() if isinstance(store, ContactsStore) else store.calendars()
        return {r["url"]: r["id"] for r in rows if r["account_id"] == account_id}


def _stop_on_password(exc: BaseException) -> None:
    """A rejected password fails every request: stop the whole sync rather than try each collection."""
    from ..sources.dav.client import DavError
    if isinstance(exc, DavError) and exc.status == 401:
        raise exc
