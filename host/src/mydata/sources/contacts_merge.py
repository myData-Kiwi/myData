"""Merging owned contacts the user chose as one person, and undoing a merge.

Nothing is merged automatically: an import only suggests duplicates (sources/importer.py), and the user picks
the contacts to merge. Only owned contacts are merged; a followed one is refused (ReadOnly).

A merge creates one new card and moves the originals to Recently deleted:

- the new card starts as a copy of the contact whose names are kept (the one changed most recently unless the
  user chose another: DuplicatePair, Decisions 2), lines it holds copied byte for byte;
- every email address, phone number, postal address, link, instant-message handle, social profile, related
  name and Apple date the others hold and it does not (compared as values: an email in any case, a phone number
  in E.164, an address part by part) is added, with its label in a new Apple item group;
- any other property it has no value of (a company, job title, birthday, nickname, photo, categories, X- lines
  such as a phonetic name or an anniversary) is added with all the other's values; notes that differ are kept
  one after the other;
- what it cannot take is left out and reported by name and count (`left_out`, never a value): a different value
  of a property it has its own of (a second job title or birthday, another photo), and KIND or X-ABShowAs, which
  say what the card is. The originals keep it all until they are deleted for good;
- a card in another vCard version is converted to the kept one's first (vcard_edit.convert, which changes only
  the lines that differ).

The originals are only soft-deleted (`deleted_at`, `purge_after`, and `merged_into` naming the new card), so
their text stays exactly as it was: undo restores them as they were. Each original's origins (where it was
imported from) keep shadowing their followed copies through `merged_into` (contacts_store._SHADOWED), also for a
card merged twice (the links are moved to the newest card, and back on undo), and once the original is deleted for
good (trash expiry or Delete for good) the merged card holds them (`origins.held_by`, contacts_write).

The merge is recorded in `merges` (ids and revisions only, no contact data); POST /undo/{id} with its id undoes
it: only while the new card and every original are still at the revisions the merge wrote, so nothing changed
since is ever lost. Undo moves the new card to Recently deleted and brings the originals back. A merge is undone
at most once, also across a restart.

Membership of groups is by UID: the new card keeps the kept contact's UID, so its groups still hold it; the
others' memberships stay on their originals.
"""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass

from . import owned
from ._db import new_id
from .contacts_store import ContactsStore, card_fields, http_etag
from .contacts_write import (InTrash, NotFound, UndoRefused, WriteError, _baseline, _check_etag, _clock, _record,
                             _row, _set_deleted, stamp)
from .importer import email_key, phone_key, default_region
from .vcard_edit import Raw, VCard, VCardError, convert

MAX_MERGE = 20
_UNION = ("EMAIL", "TEL", "ADR", "URL", "IMPP", "X-SOCIALPROFILE", "X-ABRELATEDNAMES", "X-ABDATE")
_COMPANIONS = ("X-ABLABEL", "X-ABADR")
_NEVER_COPIED = ("BEGIN", "END", "VERSION", "N", "FN", "UID", "REV", "PRODID")  # the kept card's own
_IDENTITY = ("KIND", "X-ADDRESSBOOKSERVER-KIND", "X-ABSHOWAS")  # what the card is: never changed by a merge


class MergeRefused(WriteError):
    pass


@dataclass(frozen=True)
class Merged:
    contact_id: str  # the merged card
    merge_id: str
    originals: tuple[str, ...]
    left_out: tuple[tuple[str, int], ...] = ()  # (property name, values) the merged card does not hold


def _value_key(prop, region: str | None) -> str:
    if prop.key == "EMAIL":
        return email_key(prop.text()) or prop.text().strip().casefold()
    if prop.key == "TEL":
        return phone_key(prop.text(), region) or "".join(ch for ch in prop.text() if ch.isdigit() or ch == "+")
    if prop.key == "ADR":
        return "|".join(" ".join(p.casefold().split()) for p in prop.parts())
    return " ".join(prop.text().casefold().split())


def _copy(card: VCard, other: VCard, prop) -> None:
    """Add `prop` from `other` to `card`, with its label (and Apple's address format) in a new item group."""
    companions = [p for p in other.group_members(prop.group) if p.key in _COMPANIONS] if prop.group else []
    group = card.next_item() if companions else ""
    card.add(prop.name, Raw(prop.value), prop.params, group=group)
    for c in companions:
        card.add(c.name, Raw(c.value), c.params, group=group)


def merged_text(base: str, others: list[str], *, region: str | None = None) -> str | None:
    """The merged card's text (see the module docstring), or None when nothing was added to `base`."""
    return merge_cards(base, others, region=region)[0]


def merge_cards(base: str, others: list[str], *, region: str | None = None,
                details: list[dict] | None = None) -> tuple[str | None, dict[str, int]]:
    """(the merged card's text, or None when nothing was added to `base`; what the others hold that it does not
    take: {property name: how many values}, names only, never a value). See the module docstring. `details`, when
    given, gets each value left out: {property, value (None for a photo or other binary value), other (its index in
    `others`)}, for a merge preview the user reads; never logged."""
    region = region if region is not None else default_region()
    card = VCard.parse(base)
    version = card.version
    left_out: dict[str, int] = {}
    for index, text in enumerate(others):
        if VCard.parse(text).version != version and version in ("3.0", "4.0"):
            text = convert(text, version)
        other = VCard.parse(text)
        for name in _UNION:
            have = {_value_key(p, region) for p in card.props(name)}
            for prop in other.props(name):
                key = _value_key(prop, region)
                if key and key not in have:
                    _copy(card, other, prop)
                    have.add(key)
        note = other.first("NOTE")
        if note is not None and note.text().strip():
            mine = card.first("NOTE")
            if mine is None or not mine.text().strip():
                _copy(card, other, note)
            elif note.text().strip() not in mine.text():
                card.update(mine, mine.text().rstrip() + "\n\n" + note.text().strip())
        # Everything else: what the kept card has no value of is added (all its values); a value it already has
        # is the same; a different value where it has its own (a second job title, another birthday or photo) is
        # left out and counted, as are the properties that say what the card is (KIND, X-ABShowAs).
        names = dict.fromkeys(p.key for p in other.props()
                              if p.key not in (*_UNION, "NOTE", *_COMPANIONS, *_NEVER_COPIED))
        for name in names:
            values = [p for p in other.props(name) if p.decoded().strip()]
            mine = card.props(name)
            have = {_value_key(p, region) for p in mine}
            if name in _IDENTITY:
                lost = [p for p in values if _value_key(p, region) not in have]
            elif not mine:
                for prop in values:
                    _copy(card, other, prop)
                continue
            else:
                lost = [p for p in values if _value_key(p, region) not in have]
            if lost:
                left_out[name] = left_out.get(name, 0) + len(lost)
                if details is not None:
                    details.extend({"property": name, "other": index,
                                    "value": None if name in _BINARY or _is_binary(p) else p.decoded()} for p in lost)
    return (card.to_text() if card.changed else None), left_out


_BINARY = ("PHOTO", "LOGO", "SOUND", "KEY")


def _is_binary(prop) -> bool:
    return any(v.lower() in ("b", "base64") for v in prop.param("ENCODING")) or prop.value.startswith("data:")


@dataclass(frozen=True)
class Preview:
    """What a merge would make, written nowhere (merge_preview)."""
    text: str  # the merged card
    names_from: str  # the contact whose names and lines it starts from
    newest: str  # the contact changed most recently: names_from when none is given (DuplicatePair, Decisions 2)
    left_out: tuple[dict, ...]  # {property, value (None for a photo), contact_id}: what it does not hold


def newest(rows: list[sqlite3.Row]) -> sqlite3.Row:
    """The contact changed most recently (the latest modified_at, then the highest revision; the first named on a
    tie): whose names a merge keeps unless the user chose another (DuplicatePair, Decisions 2)."""
    return max(rows, key=lambda r: (r["modified_at"], r["rev"]))


def _plan(db: sqlite3.Connection, contacts: list[tuple[str, str]], names_from: str | None,
          details: list[dict] | None = None) -> tuple[list[sqlite3.Row], sqlite3.Row, list[sqlite3.Row], str,
                                                       dict[str, int]]:
    """Check a merge and work out its card: (the rows in order, the base, the others, the merged text, left_out)."""
    ids = [c for c, _ in contacts]
    if len(ids) < 2:
        raise MergeRefused("Choose at least two contacts to merge.")
    if len(ids) > MAX_MERGE:
        raise MergeRefused(f"Merge at most {MAX_MERGE} contacts at a time.")
    if len(set(ids)) != len(ids):
        raise MergeRefused("A contact is named twice.")
    if names_from is not None and names_from not in ids:
        raise MergeRefused("The contact whose names are kept must be one of those merged.")
    rows = []
    for contact_id, etag in contacts:
        row = _row(db, contact_id)
        _check_etag(row, etag)
        if row["deleted_at"] is not None:
            raise InTrash("A contact to merge is in Recently deleted. Restore it first.")
        rows.append(row)
    first = names_from or newest(rows)["id"]
    base = next(r for r in rows if r["id"] == first)
    others = [r for r in rows if r["id"] != first]
    try:
        text, left_out = merge_cards(base["raw_vcard"], [r["raw_vcard"] for r in others], details=details)
    except VCardError as e:
        raise WriteError("These contacts' cards cannot be merged here.") from e
    return rows, base, others, text or base["raw_vcard"], left_out


def merge_preview(store: ContactsStore, contacts: list[tuple[str, str]], *, names_from: str | None = None) -> Preview:
    """What merge() would make of these contacts now, written nowhere: the merged card and every value it leaves out
    (with the value, for the user to read before pressing Merge; never logged). The same refusals as merge()."""
    details: list[dict] = []
    with store.db.connect() as db:
        rows, base, others, text, _ = _plan(db, contacts, names_from, details)
    return Preview(text, base["id"], newest(rows)["id"], tuple({"property": d["property"], "value": d["value"],
                                                           "contact_id": others[d["other"]]["id"]} for d in details))


def merge(store: ContactsStore, contacts: list[tuple[str, str]], *, names_from: str | None = None,
          actor: str) -> Merged:
    """Merge owned contacts, each given as (id, the etag the user saw). PreconditionFailed when one changed
    since; MergeRefused for fewer than two, a repeat, or names_from not among them. Without names_from the names
    are the newest contact's (newest())."""
    ids = [c for c, _ in contacts]
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        rows, base, others, text, left_out = _plan(db, contacts, names_from)
        merged_id = new_id()
        href = f"{merged_id}.vcf"
        book = base["address_book_id"]
        fields = card_fields(None, text)
        fields["etag"] = http_etag(1, fields["raw_sha256"])
        columns = ["id", "account_id", "address_book_id", "collection_url", "href", *fields, "rev", "created_at",
                   "modified_at"]
        db.execute(f"INSERT INTO contacts ({', '.join(columns)}) VALUES ({', '.join('?' * len(columns))})",
                   [merged_id, owned.OWNED_ACCOUNT, book, base["collection_url"], href, *fields.values(), 1, when,
                    when])
        _record(db, merged_id, book, href, 1, text, "merge", "add", actor, when, undo_op=None)
        originals, links = [], {}
        for row in rows:
            _baseline(db, row)
            rev = _set_deleted(db, row, True, at)
            db.execute("UPDATE contacts SET merged_into = ? WHERE id = ?", (merged_id, row["id"]))
            _record(db, row["id"], row["address_book_id"], row["href"], rev, None, "merge", "delete", actor, when,
                    undo_op=None)
            originals.append({"id": row["id"], "rev": rev})
            for (child,) in db.execute("SELECT id FROM contacts WHERE merged_into = ?", (row["id"],)).fetchall():
                links[child] = row["id"]
                db.execute("UPDATE contacts SET merged_into = ? WHERE id = ?", (merged_id, child))
        merge_id = new_id()
        db.execute("INSERT INTO merges (id, merged_id, merged_rev, originals, links, actor, at) "
                   "VALUES (?, ?, 1, ?, ?, ?, ?)", (merge_id, merged_id, json.dumps(originals), json.dumps(links),
                                                    actor, when))
    return Merged(merged_id, merge_id, tuple(ids), tuple(sorted(left_out.items())))


def is_merge(store: ContactsStore, undo_id: str) -> bool:
    with store.db.connect() as db:
        return db.execute("SELECT 1 FROM merges WHERE id = ?", (undo_id,)).fetchone() is not None


def undo(store: ContactsStore, merge_id: str, *, actor: str) -> Merged:
    """Undo a merge (see the module docstring): UndoRefused when it was undone already or anything changed since."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        m = db.execute("SELECT * FROM merges WHERE id = ?", (merge_id,)).fetchone()
        if m is None:
            raise NotFound("There is nothing to undo with that id.")
        if m["undone_at"] is not None:
            raise UndoRefused("This was already undone.")
        merged = _get(db, m["merged_id"])
        if merged is None:
            raise UndoRefused("The merged contact was deleted for good, so this cannot be undone.")
        if merged["rev"] != m["merged_rev"] or merged["deleted_at"] is not None:
            raise UndoRefused("The merged contact changed since, so this cannot be undone.")
        originals = json.loads(m["originals"])
        rows = []
        for o in originals:
            row = _get(db, o["id"])
            if row is None:
                raise UndoRefused("A merged contact was deleted for good, so this cannot be undone.")
            if row["rev"] != o["rev"] or row["deleted_at"] is None:
                raise UndoRefused("A merged contact changed since, so this cannot be undone.")
            rows.append(row)
        rev = _set_deleted(db, merged, True, at)
        _record(db, merged["id"], merged["address_book_id"], merged["href"], rev, None, "undo", "delete", actor, when,
                undo_op=None)
        for row in rows:
            rev = _set_deleted(db, row, False, at)
            db.execute("UPDATE contacts SET merged_into = NULL WHERE id = ?", (row["id"],))
            _record(db, row["id"], row["address_book_id"], row["href"], rev, None, "undo", "add", actor, when,
                    undo_op=None)
        for child, prior in json.loads(m["links"]).items():
            db.execute("UPDATE contacts SET merged_into = ? WHERE id = ? AND merged_into = ?",
                       (prior, child, merged["id"]))
        db.execute("UPDATE merges SET undone_at = ?, undone_by = ? WHERE id = ?", (when, actor, merge_id))
    return Merged(merged["id"], merge_id, tuple(o["id"] for o in originals))


def _get(db: sqlite3.Connection, contact_id: str) -> sqlite3.Row | None:
    try:
        return _row(db, contact_id)
    except NotFound:
        return None
