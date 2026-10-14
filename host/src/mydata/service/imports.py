"""Contact imports as the API runs them: previews held in memory, the snapshot before a commit, and which
sources may be imported (sources/importer.py does the work).

- **Previews** live in this process only, for PREVIEW_TTL seconds (at most MAX_PREVIEWS at a time; the oldest
  goes first, before a new input is read). One input is read at a time. A preview belongs to the app that made it:
  another app gets PreviewGone, as for an unknown id. The app discards one it cancels (discard), and a commit takes
  it out before it writes, so two commits of one preview never both run. A preview id that expired, was committed, or was made before the host restarted is gone
  (PreviewGone): the app reads the file again. Nothing is written for a preview.
- **Commit** takes a snapshot of the databases first ("always before an import", the owned-data plan 3.4),
  and refuses (SnapshotFailed, nothing imported) if contacts.sqlite cannot be copied. One import runs at a time.
- **Import a copy of a followed source:** an iCloud account's cards go through the same preview and commit.
  This Mac is never imported (NotImportable, with the reason). The answer says whether the account can now be
  unfollowed without losing anything (stop_following: how many of its contacts are not on myData, kept as one of
  yours, or changed since), which the app offers; nothing stops following by itself.
- **Logs** hold ids, kinds and counts only: never a card, a name, the file's name or its size per card.
"""

from __future__ import annotations

import logging
import re
import secrets
import threading
import time
import unicodedata
from collections import OrderedDict
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

from ..sources import importer
from ..sources.import_files import ReadCard, ReadResult, read_card, read_contacts
from ..sources.importer import FILE, ICLOUD, ImportSource
from ..sources.mac import MAC_ID
from .backup import BackupError, take_snapshot
from .logs import log

logger = logging.getLogger("mydata.imports")

PREVIEW_TTL = 60 * 60.0
MAX_PREVIEWS = 4

MAC_REASON = ("This Mac is never imported: it gives myData no contact notes and only part of each card, so the "
              "copy would not be faithful. In Contacts, turn on Settings, vCard, \"Export notes in vCards\" and "
              "\"Export photos in vCards\", then choose File, Export, Export vCard, and import that file.")


class PreviewGone(Exception):
    """No such preview: it expired, was committed, or the host restarted since."""


class NotImportable(Exception):
    """The source is never imported; the message says why."""


class SnapshotFailed(Exception):
    """The snapshot before the import failed: nothing was imported."""


@dataclass
class Held:
    id: str
    source: ImportSource
    read: ReadResult
    created: float
    expires: float
    expires_at: str
    actor: str
    extra: dict = field(default_factory=dict)


def file_label(filename: str) -> str:
    """The file's name as the history shows it: its last path part, without control or format characters (C0 and
    C1 controls, bidirectional overrides such as U+202E, zero-width characters), at most 200 characters."""
    name = re.split(r"[\\/]", filename or "")[-1]
    name = "".join(ch for ch in name if unicodedata.category(ch) not in ("Cc", "Cf", "Cs", "Co")).strip()[:200]
    return name or "Contacts file"


class ContactImports:
    def __init__(self, sources, *, ttl: float | None = None, max_previews: int = MAX_PREVIEWS,
                 clock=time.monotonic, snapshot=None):
        self.sources = sources
        self.ttl = PREVIEW_TTL if ttl is None else ttl
        self.max_previews, self.clock = max_previews, clock
        self._snapshot = snapshot or (lambda: take_snapshot(sources.home, "pre-import",
                                                            require=["contacts.sqlite"]))
        self._previews: OrderedDict[str, Held] = OrderedDict()
        self._lock = threading.Lock()
        self._write_lock = threading.Lock()
        # One input is read at a time: reading a large file holds several times its size in memory.
        self._read_lock = threading.Lock()

    # ---------------------------------------------------------------- previews

    def preview_file(self, data: bytes, filename: str, actor: str) -> dict:
        """Read an uploaded .vcf or .zip (ImportFileError when it cannot be imported at all) and hold it."""
        with self._read_lock:
            self._make_room()
            read = read_contacts(data)
            return self._hold(ImportSource(FILE, "", file_label(filename)), read, actor)

    def preview_source(self, account_id: str, actor: str) -> dict:
        """Copy a followed iCloud account's cards into a preview. NotImportable for This Mac; KeyError for an
        account that is not linked."""
        if account_id == MAC_ID:
            raise NotImportable(MAC_REASON)
        account = self.sources.accounts.get(account_id)
        if account is None:
            raise KeyError(account_id)
        from ..sources.views import source_heading
        store = self.sources.contacts
        with self._read_lock:
            self._make_room()
            read = ReadResult()
            with store.db.connect() as db:
                rows = importer.followed_cards(db, account_id)
            for row in rows:
                card = read_card(row["raw_vcard"], len(read.cards) + len(read.skipped))
                (read.cards if isinstance(card, ReadCard) else read.skipped).append(card)
            read.entries_read = 1
            return self._hold(ImportSource(ICLOUD, account_id, source_heading(account_id, account.email)), read,
                              actor)

    def _make_room(self) -> None:
        """Drop expired previews, and the oldest while as many are held as allowed, before a new input is read, so
        the new one's memory never comes on top of them all."""
        with self._lock:
            self._expire(self.clock())
            while len(self._previews) >= self.max_previews:
                self._previews.popitem(last=False)

    def _hold(self, source: ImportSource, read: ReadResult, actor: str) -> dict:
        now = self.clock()
        held = Held(id=secrets.token_urlsafe(18), source=source, read=read, created=now, expires=now + self.ttl,
                    expires_at=(datetime.now(timezone.utc) + timedelta(seconds=self.ttl)).isoformat(
                        timespec="seconds"), actor=actor)
        with self._lock:
            self._expire(now)
            while len(self._previews) >= self.max_previews:
                self._previews.popitem(last=False)
            self._previews[held.id] = held
        out = self.describe(held)
        log(logger, logging.INFO, "contacts import previewed", preview_id=held.id, source=source.kind,
            actor=actor, **{k: v for k, v in out["counts"].items() if isinstance(v, int)})
        return out

    def _expire(self, now: float) -> None:
        for key in [k for k, h in self._previews.items() if h.expires <= now]:
            del self._previews[key]

    def _held(self, preview_id: str, actor: str, *, take: bool = False) -> Held:
        """The preview, held for the app that made it (another app gets PreviewGone, as for an unknown id); with
        take, it is also taken out, so no second commit or read finds it."""
        with self._lock:
            self._expire(self.clock())
            held = self._previews.get(preview_id)
            if held is not None and held.actor != actor:
                held = None
            if held is not None and take:
                del self._previews[preview_id]
        if held is None:
            raise PreviewGone("This preview is no longer held (it expired, was imported already, or the host "
                              "restarted). Choose the file again.")
        return held

    def _give_back(self, held: Held) -> None:
        """A commit that wrote nothing (refused) leaves its preview held, unless it expired meanwhile."""
        with self._lock:
            if held.expires > self.clock():
                self._previews[held.id] = held

    def get(self, preview_id: str, actor: str) -> dict:
        """The preview again, as the host is now (an edit since may have changed a card's status)."""
        return self.describe(self._held(preview_id, actor))

    def discard(self, preview_id: str, actor: str) -> None:
        """Drop a preview the app cancelled, with the file's contents it holds."""
        self._held(preview_id, actor, take=True)
        log(logger, logging.INFO, "contacts import preview discarded", preview_id=preview_id, actor=actor)

    def describe(self, held: Held) -> dict:
        store = self.sources.contacts
        with store.db.connect() as db:
            plan = importer.analyse(db, held.source, held.read)
        return {"id": held.id, "expires_at": held.expires_at, "source": held.source.kind, "label": held.source.label,
                "account_id": held.source.account or None, "counts": plan.counts, "losses": plan.losses,
                "changes": plan.changes, "needs_acceptance": bool(plan.losses), "missing": plan.missing,
                "items": [_item(i) for i in plan.items], "stop_following": self._stop_following(held.source)}

    def _stop_following(self, source: ImportSource) -> dict | None:
        if source.kind != ICLOUD:
            return None
        with self.sources.contacts.db.connect() as db:
            left = importer.followed_left(db, source.account)
        try:
            calendars = self.sources.calendar.counts(source.account).get("calendars", 0)
        except Exception:  # noqa: BLE001 - the calendar file failing must not stop a contacts import
            calendars = 0
        if not any(left.values()):
            message = (f"You can stop following {source.label}: its contacts are on myData now, and stopping removes "
                       "only the followed copy, never yours.")
        else:
            parts = []
            if left["followed"]:
                parts.append(f"{left['followed']} of its contact(s) are not on myData")
            if left["linked"]:
                parts.append(f"{left['linked']} are kept as a contact of yours whose details may differ")
            if left["changed"]:
                parts.append(f"{left['changed']} changed in {source.label} since they were imported")
            message = (f"Keep following {source.label} for now: " + "; ".join(parts) + ". Stopping following it "
                       "would take those details off myData; import or review them first.")
        if calendars:
            message += (f" It would also stop following its {calendars} calendar(s), which are not imported yet; "
                        "keep following it for them.")
        return {"account_id": source.account, "label": source.label, "contacts_followed": left["followed"],
                "contacts_linked": left["linked"], "contacts_changed": left["changed"],
                "calendars_followed": calendars, "message": message}

    # ---------------------------------------------------------------- commit, undo, history

    def commit(self, preview_id: str, *, address_book_id: str | None, choices: dict[int, str], accept_losses: bool,
               actor: str) -> dict:
        with self._write_lock:
            # Taken out first, so a second commit of the same preview finds nothing; given back if this one is
            # refused before anything is written.
            held = self._held(preview_id, actor, take=True)
            try:
                if importer.losses_of(held.read) and not accept_losses:
                    raise importer.LossesNotAccepted("Some of the file cannot be imported (see the loss report). "
                                                     "Accept that to import the rest.")
                store = self.sources.contacts
                try:
                    snap = self._snapshot()
                except BackupError as e:
                    log(logger, logging.ERROR, "the snapshot before an import failed; nothing was imported",
                        preview_id=preview_id)
                    raise SnapshotFailed(f"The snapshot before the import failed ({e}). Nothing was "
                                         "imported.") from None
                done = importer.commit(store, held.source, held.read, choices=choices,
                                       address_book_id=address_book_id, accept_losses=accept_losses, actor=actor)
            except BaseException:
                self._give_back(held)
                raise
        log(logger, logging.INFO, "contacts imported", import_id=done.import_id, preview_id=preview_id,
            source=held.source.kind, actor=actor, snapshot=getattr(snap, "name", None),
            **{k: v for k, v in done.counts.items() if isinstance(v, int)})
        if done.book_created:
            self.sources.owned_data_changed()
        out = importer.get_import(store, done.import_id)
        out.update(conflicts=done.conflicts, missing=done.missing,
                   stop_following=self._stop_following(held.source))
        return out

    def undo(self, import_id: str, actor: str) -> dict:
        with self._write_lock:
            undone = importer.undo_import(self.sources.contacts, import_id, actor=actor)
        log(logger, logging.INFO, "contacts import undone", import_id=import_id, actor=actor, removed=undone.removed,
            reverted=undone.reverted, unlinked=undone.unlinked, unhidden=undone.unhidden, kept=len(undone.kept),
            gone=undone.gone)
        return {"summary": importer.get_import(self.sources.contacts, import_id), "removed": undone.removed,
                "groups_removed": undone.groups_removed, "reverted": undone.reverted, "unlinked": undone.unlinked,
                "unhidden": undone.unhidden, "kept": undone.kept, "gone": undone.gone}

    def history(self) -> list[dict]:
        return importer.history(self.sources.contacts)


def _item(i: importer.Item) -> dict:
    card = i.card
    return {"index": i.index, "kind": i.kind or None, "display_name": i.display_name, "status": i.status,
            "reason": i.reason, "action": i.action, "choices": list(i.choices),
            "converted_from": card.converted_from if card else None, "entry": card.entry if card else None,
            "matches": [{"contact_id": m.contact_id, "item_index": m.item_index, "display_name": m.display_name,
                         "source": m.source, "account_id": m.account_id, "strength": m.strength,
                         "signals": m.signals, "hides": m.hides} for m in i.matches]}
