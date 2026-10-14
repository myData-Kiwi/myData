"""Reviewing the contacts the host owns (sources/contacts_review.py): a followed copy that changed since the import is
shown beside the contact with what differs, and settled by saving the chosen values or keeping yours, each undoable
once. Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import json

import pytest

import test_contacts_store as con
import test_importer as imp
from mydata.sources import contacts_review as review
from mydata.sources import contacts_write as cw
from mydata.sources.card_values import differences
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.import_files import read_contacts
from mydata.sources.importer import ICLOUD, ImportSource
from mydata.sources.owned import raw_hash

ACCOUNT = imp.ACCOUNT
SOURCE = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
AVA_HREF = "/1/carddavhome/card/ava-fictional.vcf"


@pytest.fixture
def store(tmp_path) -> ContactsStore:
    s = ContactsStore(tmp_path / "contacts.sqlite")
    s.apply(ACCOUNT, con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    return s


def _imported_ava(store) -> str:
    imp.commit(store, SOURCE, imp.copy_of(store, ACCOUNT))
    [ava] = store.find_by_name("Ava")
    return ava["id"]


def _change_upstream(store, old: str, new: str, etag: str = '"2"') -> dict:
    edited = con.card("ava-fictional.vcf").replace(old, new)
    store.apply(ACCOUNT, con.BOOK, con.result([con.Item(href=AVA_HREF, etag=etag, data=edited)]))
    return next(c for c in _followed(store))


def _followed(store) -> list[dict]:
    with store.db.connect() as db:
        ids = [r[0] for r in db.execute("SELECT id FROM contacts WHERE account_id = ? AND href = ?",
                                        (ACCOUNT, AVA_HREF))]
    return [store.get(i) for i in ids]


def test_nothing_to_review_until_the_followed_copy_changes(store):
    ava = _imported_ava(store)
    assert review.followed_changes(store, ava) == []
    copy = _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi B")
    [change] = review.followed_changes(store, ava)
    assert change == {"contact_id": copy["id"], "account_id": ACCOUNT, "differences": ["nickname"]}
    with pytest.raises(cw.ReadOnly):
        review.followed_changes(store, copy["id"])  # only yours are reviewed


def test_keep_mine_clears_the_mark_and_undo_brings_it_back(store):
    ava = _imported_ava(store)
    copy = _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi B")
    raw = store.get(ava)["raw_vcard"]
    done = review.keep_mine(store, ava, [(copy["id"], copy["http_etag"])], actor="mycontacts")
    assert store.get(ava)["changed_in_source"] is None and store.get(ava)["raw_vcard"] == raw
    assert review.followed_changes(store, ava) == []
    # Importing a copy of the account again: the card is as you settled it, so it is not offered as an update.
    plan = imp.preview(store, SOURCE, imp.copy_of(store, ACCOUNT))
    assert [i.status for i in plan.items if i.display_name == "Ava Fictional"] == ["unchanged"]
    review.undo(store, done.undo_id, actor="mycontacts")
    assert store.get(ava)["changed_in_source"] == ACCOUNT
    with pytest.raises(cw.UndoRefused):
        review.undo(store, done.undo_id, actor="mycontacts")
    # Kept again, then it changes again upstream: marked again.
    review.keep_mine(store, ava, [(copy["id"], copy["http_etag"])], actor="mycontacts")
    _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi C", etag='"3"')
    assert store.get(ava)["changed_in_source"] == ACCOUNT


def test_save_changes_writes_the_chosen_values_and_undo_reverts_them(store):
    ava = _imported_ava(store)
    copy = _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi B")
    before = store.get(ava)
    done = review.save_changes(store, ava, {"nickname": "Avi B"}, [(copy["id"], copy["http_etag"])],
                               if_match=before["http_etag"], actor="mycontacts")
    after = store.get(ava)
    assert after["nickname"] == "Avi B" and after["rev"] == before["rev"] + 1 and after["changed_in_source"] is None
    assert differences(after["raw_vcard"], copy["raw_vcard"]) == []
    with store.db.connect() as db:
        d = db.execute("SELECT kind, object_id, data FROM decisions WHERE id = ?", (done.undo_id,)).fetchone()
    assert d["kind"] == "save_changes" and "Avi" not in d["data"]  # ids, revisions and hashes only
    review.undo(store, done.undo_id, actor="mycontacts")
    undone = store.get(ava)
    assert undone["raw_vcard"] == before["raw_vcard"] and undone["changed_in_source"] == ACCOUNT


def test_a_save_is_not_undone_once_the_contact_changed_since(store):
    ava = _imported_ava(store)
    copy = _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi B")
    done = review.save_changes(store, ava, {"nickname": "Avi B"}, [(copy["id"], copy["http_etag"])],
                               if_match=store.get(ava)["http_etag"], actor="mycontacts")
    cw.update(store, ava, {"job_title": "Inventor"}, if_match=store.get(ava)["http_etag"], actor="mycontacts")
    with pytest.raises(cw.UndoRefused):
        review.undo(store, done.undo_id, actor="mycontacts")
    assert store.get(ava)["changed_in_source"] is None


def test_stale_and_unknown_copies_are_refused_and_nothing_is_written(store):
    ava = _imported_ava(store)
    copy = _change_upstream(store, "NICKNAME:Avi", "NICKNAME:Avi B")
    before = store.get(ava)
    with pytest.raises(cw.PreconditionFailed):
        review.save_changes(store, ava, {"nickname": "Avi B"}, [(copy["id"], copy["http_etag"])],
                            if_match='"1-stale"', actor="mycontacts")
    with pytest.raises(cw.PreconditionFailed):
        review.keep_mine(store, ava, [(copy["id"], '"1-stale"')], actor="mycontacts")
    sam = next(c for c in store.list() if c["display_name"] == "Sam Sample")
    with pytest.raises(review.ReviewRefused):
        review.keep_mine(store, ava, [(sam["id"], sam["http_etag"])], actor="mycontacts")
    with pytest.raises(review.ReviewRefused):
        review.keep_mine(store, ava, [], actor="mycontacts")
    assert store.get(ava)["raw_vcard"] == before["raw_vcard"] and store.get(ava)["changed_in_source"] == ACCOUNT
    with store.db.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM decisions").fetchone()[0] == 0


def test_a_copy_this_mac_reads_is_reviewed_without_notes(tmp_path):
    store = ContactsStore(tmp_path / "contacts.sqlite")
    imp._this_mac(store)
    imp.commit(store, imp.FILE_SOURCE, read_contacts(imp._contacts_export()))
    [ava] = store.find_by_name("Ava")
    imp._this_mac(store, dict(imp.MAC_PEOPLE, **{"mac-ava": ("Ava", "Fictional", ["ava@example.org"],
                                                             ["+1 202 555 0100", "+1 202 555 0199"])}))
    [change] = review.followed_changes(store, ava["id"])
    assert change["account_id"] == "mac" and change["differences"] == ["phone"]  # the file's note is not compared
    copy = store.get(change["contact_id"])
    review.keep_mine(store, ava["id"], [(copy["id"], copy["http_etag"])], actor="mycontacts")
    assert store.get(ava["id"])["changed_in_source"] is None
    with store.db.connect() as db:
        settled = db.execute("SELECT reviewed_hash FROM shadows WHERE source_uid = 'mac-ava'").fetchone()[0]
    assert settled == raw_hash(copy["raw_vcard"])


def test_differences_normalise_before_comparing():
    a = ("BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nEMAIL:Ava@Example.org\r\nTEL:+1 (202) 555-0100\r\n"
         "END:VCARD\r\n")
    b = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:ava  fictional\r\nEMAIL:ava@example.org\r\nTEL:+12025550100\r\n" \
        "PRODID:-//Apple Inc.//macOS 26.0//EN\r\nEND:VCARD\r\n"
    assert differences(a, b, region="US") == []
    c = b.replace("END:VCARD", "BDAY:1990-03-18\r\nX-ABDATE:2001-01-01\r\nNOTE:Hi\r\nEND:VCARD")
    assert differences(a, c, region="US") == ["birthday", "note", "other"]
    assert differences(a, c, notes=False, region="US") == ["birthday", "other"]
    assert json.dumps(differences(a, c, region="US"))  # kinds only, never a value


# ---------------------------------------------------------------- possible duplicates

def _make(store, **form) -> str:
    return cw.create(store, form, actor="mycontacts").contact_id


def _pairs(store) -> list[tuple]:
    names = {}
    for p in review.duplicates(store, region="US"):
        a, b = (names.setdefault(i, store.get(i, include_deleted=True)["display_name"]) for i in (p["a"], p["b"]))
        # Two contacts of one name come in either order: their shared emails are compared in lower case.
        yield (a, b, p["strength"], tuple(p["signals"]), tuple(e.lower() for e in p["emails"]), tuple(p["phones"]))


def test_possible_duplicates_are_pairs_of_yours_strong_first(store):
    ava1 = _make(store, given_name="Ava", family_name="Fictional", emails=[{"value": "ava@example.org"}])
    _make(store, given_name="Ava", family_name="Fictional", emails=[{"value": "AVA@example.org"}],
          phones=[{"value": "+1 202 555 0100"}])
    _make(store, given_name="Ben", family_name="Sample", phones=[{"value": "(202) 555-0100"}])
    _make(store, given_name="Cleo", family_name="Example")
    cleo2 = _make(store, given_name="Cleo", family_name="Example")
    _make(store, emails=[{"value": "ava@example.org"}])  # no name: the email is its name
    gone = _make(store, given_name="Ben", family_name="Sample", phones=[{"value": "+1 202 555 0100"}])
    cw.delete(store, gone, if_match=store.get(gone)["http_etag"], actor="mycontacts")
    pairs = list(_pairs(store))
    assert pairs == [
        ("Ava Fictional", "Ava Fictional", "strong", ("email", "name"), ("ava@example.org",), ()),
        ("Ava Fictional", "ava@example.org", "strong", ("email",), ("ava@example.org",), ()),
        ("Ava Fictional", "ava@example.org", "strong", ("email",), ("ava@example.org",), ()),
        ("Ava Fictional", "Ben Sample", "suggestion", ("phone",), (), ("+1 202 555 0100",)),
        ("Cleo Example", "Cleo Example", "suggestion", ("name",), (), ()),
    ]
    # The followed account's contacts (two Sam Samples, an Ava with this host's email) are never offered.
    assert all("Sam" not in p[0] for p in pairs)
    assert store.get(ava1)["account_id"] == "local" and cleo2


def test_a_large_group_is_paired_within_a_bound(store, monkeypatch):
    monkeypatch.setattr(review, "MAX_GROUP", 3)
    for _ in range(5):
        _make(store, given_name="Dev", family_name="Placeholder")
    assert len(review.duplicates(store, region="US")) == 3  # the first three paired, not all ten pairs
    assert len(review.duplicates(store, region="US", limit=1)) == 1
