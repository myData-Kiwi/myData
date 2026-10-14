"""Reviewing the contacts the host owns (design/components/DuplicatePair): possible duplicates, and a followed copy
that changed since the import.

**Possible duplicates** (duplicates()): pairs of owned contacts with the same email or phone, or the same name, with
the reason and its strength, never merged here (the user merges: sources/contacts_merge.py).

**Changed since import.** An owned contact stands for the followed cards it was imported from (origins, by account
and UID) or that a file import hid behind it (shadows), its own and those of the contacts merged into it. When such
a card's text is no longer the one imported, nor the one the user last settled, the contact is flagged
(contacts_store.changed_in_source) and followed_changes() gives each changed copy beside it. The user settles it:

- save_changes(): the values chosen (the form, as an edit in myContacts) are written into the owned contact through
  the writer (If-Match; only the lines whose values differ), and the mark is cleared at the followed text the user
  saw, until that copy changes again;
- keep_mine(): the mark is cleared at that text, the contact unchanged.

Clearing the mark records the followed text's hash on the newest origin or shadow of that card (`reviewed_hash`);
the import's own hash (`source_hash`) stays. Each settlement is a `decisions` row, and POST /undo/{id} undoes it
(undo()): the marks come back, and a save's text is reverted forward, only while the contact is still at the
revision it wrote. Undone at most once, also after a restart.

Only ids, kinds and hashes are stored; nothing here logs a value.
"""

from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass

from . import owned
from ._db import new_id
from .card_values import differences
from .contacts_store import ContactsStore, http_etag
from .contacts_write import (InTrash, NotFound, PreconditionFailed, UndoRefused, WriteError, _baseline, _check_etag,
                             _clock, _record, _row, _write_text, edited_text, revert_text, stamp)
from .importer import _keys, default_region, email_key, phone_key
from .mac import MAC_ID
from .views import compare_names

SAVE, KEEP, NOT_DUPLICATE = "save_changes", "keep_mine", "not_duplicate"


class ReviewRefused(WriteError):
    pass


@dataclass(frozen=True)
class Settled:
    contact_id: str
    undo_id: str
    contact_ids: tuple[str, ...] = ()


# ---------------------------------------------------------------- changed since import

def _objects(db: sqlite3.Connection, contact_id: str) -> list[str]:
    """The owned contact and the originals merged into it: whose origins and shadows it holds."""
    return [contact_id, *(r[0] for r in db.execute("SELECT id FROM contacts WHERE merged_into = ?", (contact_id,)))]


def _links(db: sqlite3.Connection, contact_id: str) -> dict[tuple[str, str], list[dict]]:
    """{(account, UID): the newest live origin and the newest live shadow naming that followed card}, for the cards
    the owned contact stands for."""
    objects = _objects(db, contact_id)
    marks = ", ".join("?" * len(objects))
    out: dict[tuple[str, str], list[dict]] = {}
    for table, extra in (("origins", "AND source_kind != 'file'"), ("shadows", "")):
        newest: dict[tuple[str, str], sqlite3.Row] = {}
        for r in db.execute(f"SELECT rowid, source_account, source_uid, source_hash, reviewed_hash FROM {table} "
                            f"WHERE COALESCE(held_by, object_id) IN ({marks}) AND undone_at IS NULL {extra} "
                            "ORDER BY rowid", objects):
            newest[(r["source_account"], r["source_uid"])] = r
        for key, r in newest.items():
            out.setdefault(key, []).append({"table": table, "rowid": r["rowid"], "source_hash": r["source_hash"],
                                            "reviewed_hash": r["reviewed_hash"]})
    return out


def _changed(db: sqlite3.Connection, contact_id: str) -> list[tuple[sqlite3.Row, list[dict]]]:
    """(the followed card, its link rows) for each followed copy that changed since it was imported or settled."""
    out = []
    for (account, uid), links in sorted(_links(db, contact_id).items()):
        for f in db.execute("SELECT c.* FROM contacts c JOIN address_books b ON b.id = c.address_book_id "
                            "WHERE c.account_id = ? AND c.uid = ? AND c.deleted_at IS NULL AND b.mode = ? "
                            "AND b.deleted_at IS NULL AND c.account_id != ? ORDER BY c.seq",
                            (account, uid, owned.FOLLOWED, owned.OWNED_ACCOUNT)):
            if not any(f["raw_sha256"] in (link["source_hash"], link["reviewed_hash"]) for link in links):
                out.append((f, links))
    return out


def followed_changes(store: ContactsStore, contact_id: str) -> list[dict]:
    """The followed copies of an owned contact that changed since the import, each {contact_id (the followed card),
    account_id, differences (card_values.KINDS)}: empty when none did. NotFound, ReadOnly for a followed contact."""
    with store.db.connect() as db:
        row = _row(db, contact_id)
        if row["deleted_at"] is not None:
            raise NotFound("There is no such contact.")
        return [{"contact_id": f["id"], "account_id": f["account_id"],
                 "differences": differences(row["raw_vcard"], f["raw_vcard"], notes=f["account_id"] != MAC_ID)}
                for f, _links in _changed(db, contact_id)]


def _settle(db: sqlite3.Connection, contact_id: str, seen: list[tuple[str, str]]) -> list[dict]:
    """Clear the mark of each followed copy the user saw (id, etag) at that text: [{table, rowid, prior, now}]. A copy
    that is not a changed copy of this contact is refused; one that changed again since it was seen fails (412)."""
    if not seen:
        raise ReviewRefused("Name the followed copies whose changes were reviewed.")
    changed = {f["id"]: (f, links) for f, links in _changed(db, contact_id)}
    done = []
    for followed_id, etag in seen:
        if followed_id not in changed:
            raise ReviewRefused("That copy has no changes to review for this contact (settled already, or not one of "
                                "its copies).")
        f, links = changed[followed_id]
        current = http_etag(f["rev"], f["raw_sha256"])
        if etag.strip() != current:
            raise PreconditionFailed("That copy changed again since it was shown. Look at it again first.", current)
        for link in links:
            db.execute(f"UPDATE {link['table']} SET reviewed_hash = ? WHERE rowid = ?", (f["raw_sha256"],
                                                                                         link["rowid"]))
            done.append({"table": link["table"], "rowid": link["rowid"], "prior": link["reviewed_hash"],
                         "now": f["raw_sha256"]})
    return done


def _decide(db, kind: str, object_id: str, data: dict, actor: str, when: str, other_id: str | None = None) -> str:
    decision_id = new_id()
    db.execute("INSERT INTO decisions (id, kind, object_id, other_id, data, actor, at) VALUES (?, ?, ?, ?, ?, ?, ?)",
               (decision_id, kind, object_id, other_id, json.dumps(data), actor, when))
    return decision_id


def keep_mine(store: ContactsStore, contact_id: str, seen: list[tuple[str, str]], *, actor: str) -> Settled:
    """Clear the "changed since import" mark of the copies seen, leaving the contact as it is."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        if row["deleted_at"] is not None:
            raise InTrash("This contact is in Recently deleted. Restore it first.")
        links = _settle(db, contact_id, seen)
        decision = _decide(db, KEEP, contact_id, {"links": links}, actor, when)
    return Settled(contact_id, decision, (contact_id,))


def save_changes(store: ContactsStore, contact_id: str, form: dict, seen: list[tuple[str, str]], *, if_match: str,
                 actor: str) -> Settled:
    """Write the values the user chose into the owned contact (from its etag `if_match`; only the lines that differ),
    and clear the mark of the copies seen, in one transaction. FormError for a bad form."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        row = _row(db, contact_id)
        _check_etag(row, if_match)
        if row["deleted_at"] is not None:
            raise InTrash("This contact is in Recently deleted. Restore it first.")
        text = edited_text(row, form, at)
        rev = None
        if text is not None:
            _baseline(db, row)
            rev = _write_text(db, row, text, when)
            _record(db, contact_id, row["address_book_id"], row["href"], rev, text, "review", "modify", actor, when,
                    undo_op=None)
        links = _settle(db, contact_id, seen)
        decision = _decide(db, SAVE, contact_id, {"rev": rev, "prior_rev": row["rev"], "links": links}, actor, when)
    return Settled(contact_id, decision, (contact_id,))


# ---------------------------------------------------------------- possible duplicates

MAX_GROUP = 20  # contacts sharing one email, number or name that are paired with each other


def _head(db: sqlite3.Connection, contact_id: str) -> str:
    """The live contact a contact now is: itself, or the contact it was merged into (followed through merges)."""
    seen = {contact_id}
    current = contact_id
    while True:
        row = db.execute("SELECT deleted_at, merged_into FROM contacts WHERE id = ?", (current,)).fetchone()
        if row is None or row["deleted_at"] is None or row["merged_into"] is None or row["merged_into"] in seen:
            return current
        current = row["merged_into"]
        seen.add(current)


def different_people(db: sqlite3.Connection) -> set[frozenset[str]]:
    """Pairs of contacts the user said are not the same person (not undone), as the live contacts they are now: a
    contact merged since stands for its originals."""
    out = set()
    for r in db.execute("SELECT object_id, other_id FROM decisions WHERE kind = ? AND undone_at IS NULL",
                        (NOT_DUPLICATE,)):
        pair = frozenset((_head(db, r["object_id"]), _head(db, r["other_id"])))
        if len(pair) == 2:
            out.add(pair)
    return out


def duplicates(store: ContactsStore, *, limit: int = 500, region: str | None = None) -> list[dict]:
    """Pairs of contacts the host owns that may be one person (design/components/DuplicatePair, "Review"), strong
    ones first: the same email or phone (an email in lower case, a phone in E.164) under the same name, or where one
    has no name, is strong; the same name alone, or an email or phone shared under another name, is a suggestion.
    Followed contacts are never offered (a followed copy of an owned contact is hidden instead). Pairs the user
    marked as different people are left out. Each: {a, b (contact ids, in name order), strength, signals (email,
    phone, name), emails, phones (the shared values, as the first contact writes them)}. Nothing is merged."""
    region = region if region is not None else default_region()
    with store.db.connect() as db:
        db.create_collation("MYDATA_NAME", compare_names)
        rows = db.execute("SELECT c.id, c.display_name, c.emails, c.phones FROM contacts c JOIN address_books b "
                          "ON b.id = c.address_book_id WHERE b.mode = ? AND b.deleted_at IS NULL AND "
                          "c.deleted_at IS NULL AND c.kind != 'group' ORDER BY c.display_name COLLATE MYDATA_NAME, "
                          "c.id", (owned.OWNED,)).fetchall()
        apart = different_people(db)
    contacts = []
    for r in rows:
        emails = [e["value"] for e in json.loads(r["emails"])]
        phones = [p["value"] for p in json.loads(r["phones"])]
        contacts.append((r["id"], emails, phones, _keys(r["display_name"], emails, phones, region)))
    groups: dict[tuple[str, str], list[int]] = {}
    for n, (_id, _e, _p, keys) in enumerate(contacts):
        for kind, values in (("email", keys.emails), ("phone", keys.phones), ("name", {keys.name} - {None})):
            for value in values:
                groups.setdefault((kind, value), []).append(n)
    pairs: set[tuple[int, int]] = set()
    for members in groups.values():
        members = members[:MAX_GROUP]
        pairs.update((a, b) for i, a in enumerate(members) for b in members[i + 1:])
    out = []
    for a, b in sorted(pairs):
        (a_id, a_emails, a_phones, ka), (b_id, _be, _bp, kb) = contacts[a], contacts[b]
        if frozenset((a_id, b_id)) in apart:
            continue
        signals = [s for s, shared in (("email", ka.emails & kb.emails), ("phone", ka.phones & kb.phones),
                                       ("name", ka.name is not None and ka.name == kb.name)) if shared]
        agree = ka.name is None or kb.name is None or ka.name == kb.name
        strong = agree and ("email" in signals or "phone" in signals)
        out.append({"a": a_id, "b": b_id, "strength": "strong" if strong else "suggestion", "signals": signals,
                    "emails": [e for e in a_emails if (k := email_key(e)) and k in kb.emails],
                    "phones": [p for p in a_phones if (k := phone_key(p, region)) and k in kb.phones],
                    "order": (not strong, a, b)})
    out.sort(key=lambda p: p.pop("order"))
    return out[:max(1, min(int(limit), 5000))]


# ---------------------------------------------------------------- undo

def is_decision(store: ContactsStore, undo_id: str) -> bool:
    with store.db.connect() as db:
        return db.execute("SELECT 1 FROM decisions WHERE id = ?", (undo_id,)).fetchone() is not None


def undo(store: ContactsStore, decision_id: str, *, actor: str) -> Settled:
    """Undo a decision (see the module docstring). UndoRefused when it was undone already, or when a save's
    contact changed since."""
    at = _clock(store)()
    when = stamp(at)
    with store.db.transaction() as db:
        d = db.execute("SELECT * FROM decisions WHERE id = ?", (decision_id,)).fetchone()
        if d is None:
            raise NotFound("There is nothing to undo with that id.")
        if d["undone_at"] is not None:
            raise UndoRefused("This was already undone.")
        data = json.loads(d["data"])
        if d["kind"] == SAVE and data.get("rev") is not None:
            try:
                row = _row(db, d["object_id"])
            except NotFound:
                raise UndoRefused("This contact was deleted for good, so this cannot be undone.") from None
            if row["rev"] != data["rev"]:
                raise UndoRefused("This contact changed since, so this cannot be undone.")
            rev, raw = revert_text(db, row, data["prior_rev"], when)
            _record(db, row["id"], row["address_book_id"], row["href"], rev, raw, "undo", "modify", actor, when,
                    undo_op=None)
        for link in data.get("links", []):  # the mark comes back, unless the copy was settled again since
            db.execute(f"UPDATE {_table(link['table'])} SET reviewed_hash = ? WHERE rowid = ? AND reviewed_hash IS ?",
                       (link["prior"], link["rowid"], link["now"]))
        db.execute("UPDATE decisions SET undone_at = ?, undone_by = ? WHERE id = ?", (when, actor, decision_id))
    ids = tuple(i for i in (d["object_id"], d["other_id"]) if i)
    return Settled(d["object_id"], decision_id, ids)


def _table(name: str) -> str:
    if name not in ("origins", "shadows"):
        raise ValueError(name)
    return name
