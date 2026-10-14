"""Importing contacts into an address book the host owns: preview, commit, undo, and importing again.

The input is a list of cards read by import_files (a .vcf or a .zip the app uploaded) or copied from a followed
iCloud account (its cards' raw text, as the mirror holds it). This Mac is never imported: it gives no contact
notes and only part of each card, so the copy would not be faithful (the owned-data plan, 2(c)).

**Preview (analyse) writes nothing.** For each card it decides a status and a default action:

- new: nothing like it on the host. Default: import.
- duplicate: an owned contact has the same email address or phone number (a strong signal: an exact email, lower
  case, or the same number in E.164 through phonenumbers). Default: skip, since nothing is ever merged
  automatically; the user may import it as a new contact anyway. For a copy of a followed account, when exactly
  one owned contact matches, the default is link: keep that contact and hide the followed copy (an origin row
  that writes nothing to the contact).
- in_file: a card with the same UID (or, without a UID, the same content) came earlier in the input. Skip only.
- unchanged / update / conflict / deleted: the card was imported before (an origin with the same source and
  UID, or content key when it has none). Unchanged: nothing to do. Update: the card changed and nobody edited
  the owned copy since it was imported (its rev is still imported_rev); default update. Conflict: it changed and
  so did the owned copy (or it was merged, or it is a contact the user kept instead of a followed copy):
  reported, never written. Deleted: the owned copy is in Recently deleted; default skip, may be imported again.
- skipped: the card could not be read (import_files). These are the losses.

Every item also lists its matches: owned and followed contacts with a strong signal, the same name alone (a
suggestion, never acted on), and earlier cards in the input. Group cards (iCloud's and vCard 4's) are imported as
group rows: never listed as contacts, but their members, named by UID, keep their membership.

The loss report is what the input holds that will not reach the host (cards that could not be read, zip
entries that were not read). A preview with losses is committed only with accept_losses. What changes without
being lost (a vCard 2.1 stored as 3.0, with the original kept in origins.source_raw) is reported apart.

**Commit** re-runs the analysis inside its transaction (the host may have changed since the preview), applies
the user's choices, and writes one batch: an `imports` row, and per card written a contacts row (3.0 and 4.0 as
received, 2.1 converted), an `origins` row (source kind, account, UID or content key, the hash of the text as
received, the 2.1 original), a `revisions` row (actor "import:<id>", batch_id the import's id), a `changes` row
and an `undo_log` row like an app's write (so a single contact's import can be undone as phase 3 undoes a
create). The caller takes a snapshot first (service/imports.py).

**Undo** (undo_import) reverts the whole batch, forward: a contact it created and nobody changed since goes to
Recently deleted; one it updated and nobody changed since gets its earlier text back; a link is dropped. Anything
changed since is reported and left as it is. Nothing is ever hard-deleted, and the undo is persisted (the
imports row's status), so it works after a restart, once.

**Importing again** never makes a duplicate of what an earlier import brought in (origins), updates only what
nobody edited since, and reports cards that earlier imports from the same source brought in and that the new
input no longer has; it never deletes them.

Nothing here logs contact data; the messages are the app's words and hold none.
"""

from __future__ import annotations

import json
import locale
import os
import re
import sqlite3
from dataclasses import dataclass, field

import phonenumbers

from . import owned
from ._db import new_id
from .contacts_store import _VISIBLE, ContactsStore, card_fields, http_etag
from .contacts_write import (BOOK_URL, NotFound, UndoRefused, WriteError, _baseline, _book, _clock, _set_deleted,
                             _write_text, stamp)
from .import_files import SKIP_REASONS, ReadCard, ReadResult

FILE, ICLOUD = "file", "icloud"
ACTIONS = ("import", "update", "link", "skip")
MAX_MATCHES = 5  # matches listed per card, strongest first


class ImportRefused(WriteError):
    """An import was refused; nothing was written."""


class ChoiceError(ImportRefused):
    pass


class LossesNotAccepted(ImportRefused):
    pass


@dataclass(frozen=True)
class ImportSource:
    kind: str  # FILE or ICLOUD
    account: str = ""  # the followed account's id (ICLOUD)
    label: str = ""  # the file's name, or the source as a heading


@dataclass
class Match:
    display_name: str
    source: str  # mydata, icloud, mac, or file (an earlier card in the same input)
    strength: str  # same_origin, strong, suggestion
    signals: list[str]
    contact_id: str | None = None
    account_id: str | None = None
    item_index: int | None = None


@dataclass
class Item:
    index: int
    kind: str
    display_name: str
    status: str
    action: str
    choices: tuple[str, ...]
    card: ReadCard | None = None
    reason: str | None = None
    matches: list[Match] = field(default_factory=list)
    target: str | None = None  # the owned contact an update, link, conflict or deleted refers to
    origin: sqlite3.Row | None = None


@dataclass
class Plan:
    source: ImportSource
    items: list[Item]
    losses: list[dict]
    changes: list[dict]
    missing: list[dict]
    counts: dict[str, int]

    def item(self, index: int) -> Item | None:
        return next((i for i in self.items if i.index == index), None)


# ---------------------------------------------------------------- matching keys

def default_region() -> str | None:
    """The region national phone numbers are read in: the host's locale (en_NZ -> NZ), else none (then only
    numbers written with + and a country code are compared)."""
    for var in ("LC_ALL", "LC_CTYPE", "LANG"):
        m = re.match(r"[A-Za-z]{2,3}[_-]([A-Za-z]{2})\b", os.environ.get(var, ""))
        if m:
            return m.group(1).upper()
    try:
        name = locale.getlocale()[0] or ""
    except ValueError:
        name = ""
    m = re.match(r"[A-Za-z]{2,3}[_-]([A-Za-z]{2})\b", name)
    return m.group(1).upper() if m else None


def phone_key(value: str, region: str | None) -> str | None:
    """The number in E.164, or None when it cannot be read as a possible number."""
    value = value.strip()
    if value.lower().startswith("tel:"):
        value = value[4:]
    try:
        number = phonenumbers.parse(value, region)
    except phonenumbers.NumberParseException:
        return None
    if not phonenumbers.is_possible_number(number):
        return None
    return phonenumbers.format_number(number, phonenumbers.PhoneNumberFormat.E164)


def email_key(value: str) -> str | None:
    value = value.strip()
    if value.lower().startswith("mailto:"):
        value = value[7:]
    value = value.strip().lower()
    return value if "@" in value else None


def name_key(display_name: str) -> str | None:
    """A name to suggest a match on (never acted on): case and spacing ignored; none when the "name" is an email
    address, a phone number or "No name"."""
    key = " ".join(display_name.casefold().split())
    if not key or key == "no name" or "@" in key or not any(ch.isalpha() for ch in key):
        return None
    return key


@dataclass
class _Keys:
    emails: set[str]
    phones: set[str]
    name: str | None


def _keys(display_name: str, emails, phones, region: str | None) -> _Keys:
    return _Keys({k for e in emails if (k := email_key(e))}, {k for p in phones if (k := phone_key(p, region))},
                 name_key(display_name))


# ---------------------------------------------------------------- analysis

def _source_of(account_id: str) -> str:
    from .contacts_store import source_of
    return source_of(account_id)


def _existing(db: sqlite3.Connection, region: str | None) -> list[tuple[sqlite3.Row, _Keys]]:
    rows = db.execute("SELECT c.id, c.account_id, c.uid, c.display_name, c.emails, c.phones FROM contacts c "
                      "JOIN address_books b ON b.id = c.address_book_id WHERE c.deleted_at IS NULL "
                      f"AND b.deleted_at IS NULL AND {_VISIBLE}").fetchall()
    return [(r, _keys(r["display_name"], [e["value"] for e in json.loads(r["emails"])],
                      [p["value"] for p in json.loads(r["phones"])], region)) for r in rows]


def _origins(db: sqlite3.Connection, source: ImportSource) -> dict[str, sqlite3.Row]:
    """The newest live origin per source UID for this source, with the owned row it points to (if any)."""
    rows = db.execute(
        "SELECT o.rowid AS origin_rowid, o.*, c.id AS cid, c.rev AS crev, c.deleted_at AS cdeleted, "
        "c.merged_into AS cmerged, c.display_name AS cname FROM origins o LEFT JOIN contacts c ON c.id = o.object_id "
        "WHERE o.source_kind = ? AND o.source_account = ? AND o.undone_at IS NULL ORDER BY o.rowid",
        (source.kind, source.account)).fetchall()
    out: dict[str, sqlite3.Row] = {}
    for r in rows:
        out[r["source_uid"]] = r
    return out


def _signals(a: _Keys, b: _Keys) -> list[str]:
    out = []
    if a.emails & b.emails:
        out.append("email")
    if a.phones & b.phones:
        out.append("phone")
    if a.name and a.name == b.name:
        out.append("name")
    return out


def analyse(db: sqlite3.Connection, source: ImportSource, read: ReadResult, *,
            region: str | None = None) -> Plan:
    """The preview: what an import of `read` would do now (see the module docstring). Reads only."""
    region = region if region is not None else default_region()
    existing = _existing(db, region)
    by_email: dict[str, list[int]] = {}
    by_phone: dict[str, list[int]] = {}
    by_name: dict[str, list[int]] = {}
    for n, (_row, keys) in enumerate(existing):
        for e in keys.emails:
            by_email.setdefault(e, []).append(n)
        for p in keys.phones:
            by_phone.setdefault(p, []).append(n)
        if keys.name:
            by_name.setdefault(keys.name, []).append(n)
    origins = _origins(db, source)
    seen_uid: dict[str, int] = {}
    earlier: list[tuple[int, str, _Keys]] = []  # (index, name, keys) of contact cards earlier in the input
    linked: set[str] = set()
    items: list[Item] = []
    for card in read.cards:
        keys = _keys(card.display_name, card.emails, card.phones, region)
        item = Item(index=card.index, kind=card.kind, display_name=card.display_name, status="new", action="import",
                    choices=("import", "skip"), card=card)
        items.append(item)
        if card.source_uid in seen_uid:
            item.status, item.action, item.choices = "in_file", "skip", ("skip",)
            item.matches.append(Match(card.display_name, "file", "strong",
                                      ["uid" if card.uid else "identical"], item_index=seen_uid[card.source_uid]))
            continue
        seen_uid[card.source_uid] = card.index
        origin = origins.get(card.source_uid)
        if origin is not None and origin["cid"] is not None:
            item.origin, item.target = origin, origin["cid"]
            item.matches.append(Match(origin["cname"] or "", "mydata", "same_origin", ["origin"],
                                      contact_id=origin["cid"]))
            if origin["source_hash"] == card.source_hash:
                item.status, item.action, item.choices = "unchanged", "skip", ("skip",)
            elif origin["cdeleted"] is not None and origin["cmerged"] is not None:
                item.status, item.action, item.choices, item.reason = "conflict", "skip", ("skip",), "merged"
            elif origin["cdeleted"] is not None:
                item.status, item.action, item.choices = "deleted", "skip", ("skip", "import")
            elif origin["action"] == "link":
                item.status, item.action, item.choices, item.reason = "conflict", "skip", ("skip",), "kept_yours"
            elif origin["crev"] == origin["imported_rev"]:
                item.status, item.action, item.choices = "update", "update", ("update", "skip")
            else:
                item.status, item.action, item.choices, item.reason = "conflict", "skip", ("skip",), "edited"
            continue
        if card.kind == "group":
            continue
        strong: dict[int, list[str]] = {}
        for e in keys.emails:
            for n in by_email.get(e, ()):
                strong.setdefault(n, []).append("email")
        for p in keys.phones:
            for n in by_phone.get(p, ()):
                strong.setdefault(n, []).append("phone")
        suggested = [n for n in by_name.get(keys.name, ()) if n not in strong] if keys.name else []
        owned_strong: list[str] = []
        for n in [*strong, *suggested]:
            row, other = existing[n]
            if source.kind != FILE and row["account_id"] == source.account:
                continue  # the account being copied: its cards are this input (matched as cards in it, below)
            signals = sorted(set(strong.get(n, []))) + (["name"] if keys.name and keys.name == other.name else [])
            is_strong = n in strong
            if is_strong and row["account_id"] == owned.OWNED_ACCOUNT:
                owned_strong.append(row["id"])
            item.matches.append(Match(row["display_name"], _source_of(row["account_id"]),
                                      "strong" if is_strong else "suggestion", sorted(set(signals)),
                                      contact_id=row["id"], account_id=row["account_id"]))
        for index, name, other in earlier:
            signals = _signals(keys, other)
            if signals:
                item.matches.append(Match(name, "file", "suggestion" if signals == ["name"] else "strong", signals,
                                          item_index=index))
        earlier.append((card.index, card.display_name, keys))
        rank = {"same_origin": 0, "strong": 1, "suggestion": 2}
        item.matches.sort(key=lambda m: (rank[m.strength], m.source != "mydata"))
        del item.matches[MAX_MATCHES:]
        if owned_strong:
            item.status, item.action, item.choices = "duplicate", "skip", ("skip", "import")
            if source.kind != FILE and len(set(owned_strong)) == 1:
                item.choices = ("link", "skip", "import")
                item.target = owned_strong[0]
                if item.target not in linked:
                    item.action = "link"
                    linked.add(item.target)
    for skipped in read.skipped:
        items.append(Item(index=skipped.index if skipped.index is not None else -1, kind="", display_name="",
                          status="skipped", action="skip", choices=("skip",), reason=skipped.reason))
    items.sort(key=lambda i: i.index)
    missing = _missing(db, source, {c.source_uid for c in read.cards})
    losses, changes = _report(read)
    return Plan(source, items, losses, changes, missing, _counts(items, missing, read.notes.get("too_many", 0)))


def _missing(db: sqlite3.Connection, source: ImportSource, present: set[str]) -> list[dict]:
    """Contacts earlier imports from this source brought in (for a file: from a file of the same name) that the
    input no longer has, and that are still on the host. Reported only."""
    sql = ("SELECT o.source_uid, o.rowid AS rid, o.action, c.id, c.display_name, c.deleted_at, c.kind "
           "FROM origins o JOIN imports i ON i.id = o.import_id JOIN contacts c ON c.id = o.object_id "
           "WHERE o.source_kind = ? AND o.source_account = ? AND o.undone_at IS NULL")
    params: list = [source.kind, source.account]
    if source.kind == FILE:
        sql += " AND i.label = ?"
        params.append(source.label)
    latest: dict[str, sqlite3.Row] = {}
    for r in db.execute(sql + " ORDER BY o.rowid", params):
        latest[r["source_uid"]] = r
    return [{"contact_id": r["id"], "display_name": r["display_name"]} for uid, r in latest.items()
            if uid not in present and r["deleted_at"] is None and r["kind"] != "group" and r["action"] != "link"]


_LOSS_NOTES = {
    "guessed_charset": "{n} card(s) were not UTF-8 and named no character set myData reads; they were read as "
                       "Windows-1252, so some letters may be wrong. Each one's original bytes are kept.",
    "outside_text": "{n} line(s) of text outside any card were not read (a card whose BEGIN:VCARD line is written "
                    "differently would be among them).",
    "nested_zip": "{n} zip file(s) inside the zip were not read.",
    "encrypted": "{n} encrypted file(s) in the zip were not read.",
    "unsupported_compression": "{n} file(s) in the zip are compressed in a way myData does not read (only stored "
                               "and deflated); they were not read.",
}
_CHANGE_NOTES = {
    "declared_charset": "Some cards were not UTF-8; they were read in the character set each one names and are "
                        "stored as UTF-8.",
}


def losses_of(read: ReadResult) -> list[dict]:
    """The loss report of an input, before any analysis: what in it will not reach the host."""
    return _report(read)[0]


def _report(read: ReadResult) -> tuple[list[dict], list[dict]]:
    losses: list[dict] = []
    reasons: dict[str, int] = {}
    for s in read.skipped:
        reasons[s.reason] = reasons.get(s.reason, 0) + 1
    if read.notes.get("too_many"):  # cards past MAX_CARDS are counted only
        reasons["too_many"] = reasons.get("too_many", 0) + read.notes["too_many"]
    for reason, n in reasons.items():
        losses.append({"code": f"skipped_{reason}", "count": n,
                       "message": f"{n} card(s) {SKIP_REASONS[reason]}; they are not imported."})
    for code, template in _LOSS_NOTES.items():
        if read.notes.get(code):
            losses.append({"code": code, "count": read.notes[code], "message": template.format(n=read.notes[code])})
    if read.unread_entries:
        n = len(read.unread_entries)
        losses.append({"code": "unreadable_entry", "count": n, "entries": list(read.unread_entries),
                       "message": f"{n} vCard file(s) in the zip hold no card myData can read; they were not read."})
    changes: list[dict] = []
    converted = sum(1 for c in read.cards if c.converted_from == "2.1")
    if converted:
        changes.append({"code": "converted_21", "count": converted,
                        "message": f"{converted} card(s) were vCard 2.1 and are stored as vCard 3.0, their values "
                                   "decoded; nothing in them is lost, and each one's original text is kept."})
    for code, message in _CHANGE_NOTES.items():
        if read.notes.get(code):
            changes.append({"code": code, "count": read.notes[code], "message": message})
    if read.other_files:
        changes.append({"code": "other_files", "count": read.other_files,
                        "message": f"{read.other_files} other file(s) in the zip are not contacts and were not read "
                                   "here."})
    return losses, changes


def _counts(items: list[Item], missing: list[dict], uncut: int = 0) -> dict[str, int]:
    """`uncut`: cards past MAX_CARDS, counted in the input but never read (no item each)."""
    def n(pred) -> int:
        return sum(1 for i in items if pred(i))
    return {
        "cards": len(items) + uncut,
        "contacts": n(lambda i: i.status != "skipped" and i.kind != "group"),
        "groups": n(lambda i: i.kind == "group"),
        "skipped": n(lambda i: i.status == "skipped") + uncut,
        "new": n(lambda i: i.status == "new"),
        "duplicates": n(lambda i: i.status == "duplicate"),
        "in_file": n(lambda i: i.status == "in_file"),
        "unchanged": n(lambda i: i.status == "unchanged"),
        "updates": n(lambda i: i.status == "update"),
        "conflicts": n(lambda i: i.status == "conflict"),
        "deleted": n(lambda i: i.status == "deleted"),
        "suggestions": n(lambda i: any(m.strength == "suggestion" for m in i.matches)),
        "followed_matches": n(lambda i: any(m.strength == "strong" and m.source in ("icloud", "mac")
                                            for m in i.matches)),
        "missing": len(missing),
        "to_import": n(lambda i: i.action == "import"),
        "to_update": n(lambda i: i.action == "update"),
        "to_link": n(lambda i: i.action == "link"),
    }


# ---------------------------------------------------------------- commit

@dataclass
class Committed:
    import_id: str
    address_book_id: str
    book_created: bool
    counts: dict[str, int]
    conflicts: list[dict]
    missing: list[dict]


def _revision(db, object_id: str, rev: int, raw: str | None, op: str, actor: str, batch: str | None, at: str) -> None:
    db.execute("INSERT INTO revisions (object_id, rev, raw, op, actor, batch_id, at) VALUES (?, ?, ?, ?, ?, ?, ?)",
               (object_id, rev, raw, op, actor, batch, at))


def _change(db, book_id: str, object_id: str, href: str, op: str, at: str) -> None:
    db.execute("INSERT INTO changes (collection_id, object_id, href, op, at) VALUES (?, ?, ?, ?, ?)",
               (book_id, object_id, href, op, at))


def _undo_entry(db, object_id: str, op: str, actor: str, rev: int, prior_rev: int | None, at: str) -> None:
    db.execute("INSERT INTO undo_log (id, object_id, op, actor, rev, prior_rev, at) VALUES (?, ?, ?, ?, ?, ?, ?)",
               (new_id(), object_id, op, actor, rev, prior_rev, at))


def _origin(db, object_id: str, import_id: str, source: ImportSource, card: ReadCard, rev: int, action: str,
            prior_rev: int | None) -> None:
    db.execute("INSERT INTO origins (object_id, import_id, source_kind, source_uid, source_hash, source_raw, "
               "imported_rev, source_account, action, prior_rev) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
               (object_id, import_id, source.kind, card.source_uid, card.source_hash, _original(card), rev,
                source.account, action, prior_rev))


def _original(card: ReadCard) -> str | bytes | None:
    """What origins.source_raw keeps: a card's bytes as received when its text was decoded by a guess (a blob),
    a vCard 2.1's text (stored as 3.0), else nothing (the stored text is the card as received)."""
    if card.raw is not None:
        return card.raw
    return card.original if card.converted_from else None


def _target_book(db: sqlite3.Connection, address_book_id: str | None, at: str) -> tuple[str, str, bool]:
    if address_book_id is None:
        book_id, created = _book(db, at)
        return book_id, BOOK_URL, created
    row = db.execute("SELECT id, url, mode, deleted_at FROM address_books WHERE id = ?", (address_book_id,)).fetchone()
    if row is None or row["deleted_at"] is not None:
        raise NotFound("There is no such address book.")
    if row["mode"] != owned.OWNED:
        raise ChoiceError("That address book is followed from a source; import into one of your own.")
    return row["id"], row["url"], False


def commit(store: ContactsStore, source: ImportSource, read: ReadResult, *, choices: dict[int, str] | None = None,
           address_book_id: str | None = None, accept_losses: bool = False, actor: str,
           region: str | None = None) -> Committed:
    """Write the import as one batch (see the module docstring). Raises LossesNotAccepted, ChoiceError or
    NotFound and writes nothing when refused."""
    choices = dict(choices or {})
    at = _clock(store)()
    when = stamp(at)
    import_id = new_id()
    by = f"import:{import_id}"
    with store.db.transaction() as db:
        plan = analyse(db, source, read, region=region)
        if plan.losses and not accept_losses:
            raise LossesNotAccepted("Some of the file cannot be imported (see the loss report). Accept that to "
                                    "import the rest.")
        actions: dict[int, str] = {}
        for item in plan.items:
            actions[item.index] = item.action
        for index, action in choices.items():
            item = plan.item(index)
            if item is None:
                raise ChoiceError(f"There is no card {index} in this preview.")
            if action not in item.choices:
                raise ChoiceError(f"Card {index} can only be: {', '.join(item.choices)}.")
            actions[index] = action
        targets = [plan.item(i).target for i, a in actions.items() if a == "link"]
        if len(targets) != len(set(targets)):
            raise ChoiceError("Two cards cannot both be kept as the same contact of yours.")
        book_id, book_url, created = _target_book(db, address_book_id, when)
        db.execute("INSERT INTO imports (id, source, label, started_at, counts, status, actor, source_account, "
                   "address_book_id) VALUES (?, ?, ?, ?, '{}', 'committing', ?, ?, ?)",
                   (import_id, source.kind, source.label, when, actor, source.account, book_id))
        done = {"created": 0, "groups_created": 0, "updated": 0, "linked": 0, "not_written": 0}
        conflicts: list[dict] = []
        for item in plan.items:
            action = actions[item.index]
            card = item.card
            if item.status == "conflict":
                conflicts.append({"index": item.index, "contact_id": item.target, "display_name": item.display_name,
                                  "reason": item.reason})
            if action == "skip" or card is None:
                done["not_written"] += 1
                continue
            if action == "import":
                row_id = new_id()
                href = f"{row_id}.vcf"
                fields = card_fields(None, card.text)
                fields["etag"] = http_etag(1, fields["raw_sha256"])
                columns = ["id", "account_id", "address_book_id", "collection_url", "href", *fields, "rev",
                           "created_at", "modified_at"]
                db.execute(f"INSERT INTO contacts ({', '.join(columns)}) VALUES ({', '.join('?' * len(columns))})",
                           [row_id, owned.OWNED_ACCOUNT, book_id, book_url, href, *fields.values(), 1, when, when])
                _revision(db, row_id, 1, card.text, "import", by, import_id, when)
                _change(db, book_id, row_id, href, "add", when)
                if card.kind != "group":
                    _undo_entry(db, row_id, "create", actor, 1, None, when)
                _origin(db, row_id, import_id, source, card, 1, "create", None)
                done["groups_created" if card.kind == "group" else "created"] += 1
            elif action == "update":
                row = db.execute("SELECT * FROM contacts WHERE id = ?", (item.target,)).fetchone()
                _baseline(db, row)
                rev = _write_text(db, row, card.text, when)
                _revision(db, row["id"], rev, card.text, "import", by, import_id, when)
                _change(db, row["address_book_id"], row["id"], row["href"], "modify", when)
                if row["kind"] != "group":
                    _undo_entry(db, row["id"], "update", actor, rev, row["rev"], when)
                _origin(db, row["id"], import_id, source, card, rev, "update", row["rev"])
                done["updated"] += 1
            elif action == "link":
                row = db.execute("SELECT id, rev FROM contacts WHERE id = ?", (item.target,)).fetchone()
                _origin(db, row["id"], import_id, source, card, row["rev"], "link", row["rev"])
                done["linked"] += 1
        counts = {**plan.counts, **done}
        db.execute("UPDATE imports SET counts = ?, status = 'committed', finished_at = ? WHERE id = ?",
                   (json.dumps(counts), when, import_id))
    return Committed(import_id, book_id, created, counts, conflicts, plan.missing)


# ---------------------------------------------------------------- undo and history

@dataclass
class Undone:
    import_id: str
    removed: int  # contacts
    groups_removed: int
    reverted: int
    unlinked: int
    kept: list[dict]  # changed since the import: left as they are
    gone: int  # already in Recently deleted or deleted for good


def undo_import(store: ContactsStore, import_id: str, *, actor: str) -> Undone:
    """Revert the whole batch (see the module docstring). NotFound for an unknown id; UndoRefused when it was
    already undone."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        imp = db.execute("SELECT * FROM imports WHERE id = ?", (import_id,)).fetchone()
        if imp is None:
            raise NotFound("There is no such import.")
        if imp["status"] != "committed":
            raise UndoRefused("This import was already undone.")
        rows = db.execute("SELECT o.rowid AS rid, o.* FROM origins o WHERE o.import_id = ? AND o.undone_at IS NULL "
                          "ORDER BY o.rowid", (import_id,)).fetchall()
        removed = groups_removed = reverted = unlinked = gone = 0
        kept: list[dict] = []
        for o in rows:
            row = db.execute("SELECT * FROM contacts WHERE id = ?", (o["object_id"],)).fetchone()
            if o["action"] == "link":
                unlinked += 1
            elif row is None or row["deleted_at"] is not None:
                gone += 1
            elif row["rev"] != o["imported_rev"]:
                kept.append({"contact_id": row["id"], "display_name": row["display_name"]})
            elif o["action"] == "create":
                rev = _set_deleted(db, row, True, at)
                _revision(db, row["id"], rev, None, "undo", f"undo-import:{actor}", import_id, when)
                _change(db, row["address_book_id"], row["id"], row["href"], "delete", when)
                _close_undo(db, row["id"], "create", o["imported_rev"], actor, when, rev)
                if row["kind"] == "group":
                    groups_removed += 1
                else:
                    removed += 1
            else:  # update
                prior = db.execute("SELECT raw FROM revisions WHERE object_id = ? AND rev <= ? AND raw IS NOT NULL "
                                   "ORDER BY rev DESC LIMIT 1", (row["id"], o["prior_rev"])).fetchone()
                if prior is None:
                    kept.append({"contact_id": row["id"], "display_name": row["display_name"]})
                else:
                    rev = _write_text(db, row, prior["raw"], when)
                    # The text is again what the import before this one wrote, and nobody changed it since (else
                    # this import would have been a conflict): that import's origin stands at the new revision.
                    db.execute("UPDATE origins SET imported_rev = ? WHERE rowid = (SELECT MAX(rowid) FROM origins "
                               "WHERE object_id = ? AND rowid < ? AND undone_at IS NULL AND action != 'link')",
                               (rev, row["id"], o["rid"]))
                    _revision(db, row["id"], rev, prior["raw"], "undo", f"undo-import:{actor}", import_id, when)
                    _change(db, row["address_book_id"], row["id"], row["href"], "modify", when)
                    _close_undo(db, row["id"], "update", o["imported_rev"], actor, when, rev)
                    reverted += 1
            db.execute("UPDATE origins SET undone_at = ? WHERE rowid = ?", (when, o["rid"]))
        counts = json.loads(imp["counts"] or "{}")
        counts["undo"] = {"removed": removed, "groups_removed": groups_removed, "reverted": reverted, "unlinked": unlinked, "kept": len(kept),
                          "gone": gone}
        db.execute("UPDATE imports SET status = 'undone', undone_at = ?, undone_by = ?, counts = ? WHERE id = ?",
                   (when, actor, json.dumps(counts), import_id))
    return Undone(import_id, removed, groups_removed, reverted, unlinked, kept, gone)


def _close_undo(db, object_id: str, op: str, rev: int, actor: str, when: str, undone_rev: int) -> None:
    """The contact's own undo entry for what the import did is used up by undoing the import."""
    db.execute("UPDATE undo_log SET undone_at = ?, undone_by = ?, undone_rev = ? WHERE object_id = ? AND op = ? "
               "AND rev = ? AND undone_at IS NULL", (when, actor, undone_rev, object_id, op, rev))


def history(store: ContactsStore, limit: int = 100) -> list[dict]:
    """Imports, the newest first: id, source, label, started_at, finished_at, status, counts, address book."""
    with store.db.connect() as db:
        rows = db.execute("SELECT * FROM imports WHERE status != 'committing' ORDER BY started_at DESC, rowid DESC "
                          "LIMIT ?", (limit,)).fetchall()
    return [import_row(r) for r in rows]


def get_import(store: ContactsStore, import_id: str) -> dict | None:
    with store.db.connect() as db:
        row = db.execute("SELECT * FROM imports WHERE id = ?", (import_id,)).fetchone()
    return import_row(row) if row is not None else None


def import_row(r: sqlite3.Row) -> dict:
    return {"id": r["id"], "source": r["source"], "label": r["label"], "source_account": r["source_account"] or None,
            "started_at": r["started_at"], "finished_at": r["finished_at"], "status": r["status"],
            "counts": json.loads(r["counts"] or "{}"), "address_book_id": r["address_book_id"],
            "undone_at": r["undone_at"]}


def followed_cards(db: sqlite3.Connection, account_id: str) -> list[sqlite3.Row]:
    """A followed account's live cards (groups included), for "Import a copy"."""
    return db.execute("SELECT c.id, c.raw_vcard FROM contacts c JOIN address_books b ON b.id = c.address_book_id "
                      "WHERE c.account_id = ? AND b.mode = ? AND c.deleted_at IS NULL AND b.deleted_at IS NULL "
                      "ORDER BY c.seq", (account_id, owned.FOLLOWED)).fetchall()

