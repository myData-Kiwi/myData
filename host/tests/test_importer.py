"""Contact import at the store (sources/importer.py) and merging (sources/contacts_merge.py): a preview writes
nothing; a commit is one batch with origins, revisions, changes and undo entries; importing again makes no
duplicate, updates only what nobody edited and reports the rest; undo reverts the batch forward and works after a
restart; the shadowing rule (one find_contact match for a person imported from a source still followed); merge and
undo merge. Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta, timezone

import pytest

import import_corpus as corpus
import test_contacts_store as con
from mydata.sources import contacts_merge as merge_
from mydata.sources import contacts_write as cw
from mydata.sources import importer
from mydata.sources._db import table_counts
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.import_files import ReadCard, ReadResult, read_card, read_contacts
from mydata.sources.importer import FILE, ICLOUD, ImportSource
from mydata.sources.mac.cards import to_vcard
from mydata.sources.mac.protocol import _contact

REGION = "US"
FILE_SOURCE = ImportSource(FILE, "", "contacts.vcf")
ACCOUNT = "acc-1"


@pytest.fixture
def store(tmp_path) -> ContactsStore:
    return ContactsStore(tmp_path / "contacts.sqlite")


@pytest.fixture
def followed(store) -> ContactsStore:
    store.apply(ACCOUNT, con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    return store


def preview(store, source, read):
    with store.db.connect() as db:
        return importer.analyse(db, source, read, region=REGION)


def commit(store, source, read, **kw):
    kw.setdefault("actor", "mycontacts")
    return importer.commit(store, source, read, region=REGION, **kw)


def owned_rows(store) -> list[sqlite3.Row]:
    with store.db.connect() as db:
        return db.execute("SELECT * FROM contacts WHERE account_id = 'local' ORDER BY seq").fetchall()


def copy_of(store, account: str) -> ReadResult:
    """What service/imports.py reads for "Import a copy" of a followed account."""
    read = ReadResult(entries_read=1)
    with store.db.connect() as db:
        rows = importer.followed_cards(db, account)
    for row in rows:
        card = read_card(row["raw_vcard"], len(read.cards))
        assert isinstance(card, ReadCard)  # a followed card is always readable
        read.cards.append(card)
    return read


def file_with(*texts: str) -> ReadResult:
    return read_contacts("".join(texts).encode())


AVA = "BEGIN:VCARD\r\nVERSION:3.0\r\nUID:ava-1@example.org\r\nFN:Ava Fictional\r\nN:Fictional;Ava;;;\r\n" \
      "EMAIL:ava@example.org\r\nTEL:+1 202 555 0100\r\nEND:VCARD\r\n"
SAM = "BEGIN:VCARD\r\nVERSION:3.0\r\nUID:sam-1@example.org\r\nFN:Sam Sample\r\nEMAIL:sam@example.org\r\nEND:VCARD\r\n"


# ---------------------------------------------------------------- preview and commit

def test_a_preview_writes_nothing(followed, tmp_path):
    before = _counts(followed)
    path = tmp_path / "contacts.sqlite"
    stamp = (path.stat().st_size, path.stat().st_mtime_ns)
    plan = preview(followed, FILE_SOURCE, read_contacts(corpus.several()))
    assert plan.counts["cards"] == 8 and plan.counts["to_import"] == 8
    assert _counts(followed) == before and (path.stat().st_size, path.stat().st_mtime_ns) == stamp


def _counts(store) -> dict[str, int]:
    with store.db.connect() as db:
        return table_counts(db)


def test_commit_writes_one_batch_as_received(store):
    read = read_contacts(corpus.read(corpus.APPLE) + corpus.read(corpus.SAMSUNG))
    done = commit(store, FILE_SOURCE, read)
    assert done.book_created and done.counts["created"] == 5 and done.counts["groups_created"] == 1
    rows = owned_rows(store)
    by_name = {r["display_name"]: r for r in rows}
    assert by_name["Ava Fictional"]["raw_vcard"] == read.cards[0].original  # 3.0 byte for byte
    zoe = by_name["Zoë Émile"]
    assert "VERSION:3.0" in zoe["raw_vcard"] and zoe["rev"] == 1
    with store.db.connect() as db:
        origins = {r["object_id"]: r for r in db.execute("SELECT * FROM origins WHERE import_id = ?",
                                                          (done.import_id,))}
        assert set(origins) == {r["id"] for r in rows}
        assert origins[zoe["id"]]["source_raw"].startswith("BEGIN:VCARD\nVERSION:2.1")  # the original kept
        assert origins[by_name["Ava Fictional"]["id"]]["source_raw"] is None
        assert {o["source_kind"] for o in origins.values()} == {"file"}
        revs = db.execute("SELECT actor, batch_id, op FROM revisions").fetchall()
        assert {tuple(r) for r in revs} == {(f"import:{done.import_id}", done.import_id, "import")}
        assert db.execute("SELECT COUNT(*) FROM changes WHERE op = 'add'").fetchone()[0] == 6
        assert db.execute("SELECT COUNT(*) FROM undo_log WHERE op = 'create'").fetchone()[0] == 5  # not the group
        imp = db.execute("SELECT * FROM imports").fetchone()
        assert imp["status"] == "committed" and imp["actor"] == "mycontacts" and imp["label"] == "contacts.vcf"
    listed = [c["display_name"] for c in store.list()]
    assert "Book club" not in listed and len(listed) == 5  # the group is kept, never listed


def test_the_same_file_again_creates_no_duplicates(store):
    read = read_contacts(corpus.several())
    commit(store, FILE_SOURCE, read)
    again = preview(store, FILE_SOURCE, read_contacts(corpus.several()))
    assert {i.status for i in again.items} == {"unchanged"} and again.counts["to_import"] == 0
    done = commit(store, FILE_SOURCE, read_contacts(corpus.several()))
    assert done.counts["created"] == 0 and len(owned_rows(store)) == 8


def test_importing_again_updates_unedited_cards_reports_conflicts_and_missing(store):
    commit(store, FILE_SOURCE, file_with(AVA, SAM))
    ava, sam = owned_rows(store)
    cw.update(store, sam["id"], {"job_title": "Inventor"}, if_match=store.get(sam["id"])["http_etag"],
              actor="mycontacts")
    changed = file_with(AVA.replace("+1 202 555 0100", "+1 202 555 0111"),
                        SAM.replace("sam@example.org", "sam.new@example.org"))
    plan = preview(store, FILE_SOURCE, changed)
    assert [(i.status, i.action, i.reason) for i in plan.items] == [("update", "update", None),
                                                                     ("conflict", "skip", "edited")]
    done = commit(store, FILE_SOURCE, changed)
    assert done.counts["updated"] == 1 and [c["display_name"] for c in done.conflicts] == ["Sam Sample"]
    assert "0111" in store.get(ava["id"])["raw_vcard"] and store.get(ava["id"])["rev"] == 2
    assert "sam@example.org" in store.get(sam["id"])["raw_vcard"]  # the user's edit is never overwritten
    only_ava = file_with(AVA.replace("+1 202 555 0100", "+1 202 555 0111"))
    plan = preview(store, FILE_SOURCE, only_ava)
    assert plan.items[0].status == "unchanged" and plan.missing == [{"contact_id": sam["id"],
                                                                     "display_name": "Sam Sample"}]
    commit(store, FILE_SOURCE, only_ava)
    assert store.get(sam["id"]) is not None  # missing from the file: reported, never deleted


def test_a_card_decoded_by_a_guess_keeps_its_bytes_as_received(store):
    latin = "BEGIN:VCARD\r\nVERSION:3.0\r\nUID:rene@example.org\r\nFN:René Sample\r\nEND:VCARD\r\n".encode("latin-1")
    read = read_contacts(latin + AVA.encode())
    commit(store, FILE_SOURCE, read, accept_losses=True)
    with store.db.connect() as db:
        raws = [r[0] for r in db.execute("SELECT source_raw FROM origins ORDER BY rowid")]
    assert raws == [latin, None]
    assert [r["display_name"] for r in owned_rows(store)] == ["René Sample", "Ava Fictional"]


ZED = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Zed Nouid\r\nN:Nouid;Zed;;;\r\nNOTE:v1\r\nEND:VCARD\r\n"
PAT = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Pat Placeholder\r\nEMAIL:pat@example.org\r\nNOTE:v1\r\nEND:VCARD\r\n"


def test_a_card_without_uid_changed_on_the_phone_updates_its_copy(store):
    commit(store, FILE_SOURCE, file_with(ZED, PAT))
    zed, pat = owned_rows(store)
    edited = file_with(ZED.replace("NOTE:v1", "NOTE:v2"), PAT.replace("NOTE:v1", "NOTE:v2"))
    plan = preview(store, FILE_SOURCE, edited)
    assert [(i.status, i.action, i.target) for i in plan.items] == [("update", "update", zed["id"]),
                                                                     ("update", "update", pat["id"])]
    assert [m.signals for m in plan.items[0].matches] == [["changed"]] and plan.missing == []
    done = commit(store, FILE_SOURCE, edited)
    assert done.counts["created"] == 0 and done.counts["updated"] == 2
    assert [r["note"] for r in owned_rows(store)] == ["v2", "v2"] and len(owned_rows(store)) == 2
    # The same file again: unchanged; and once edited on the host, a change on the phone is a conflict.
    assert {i.status for i in preview(store, FILE_SOURCE, edited).items} == {"unchanged"}
    cw.update(store, zed["id"], {"nickname": "Z"}, if_match=store.get(zed["id"])["http_etag"], actor="mycontacts")
    plan = preview(store, FILE_SOURCE, file_with(ZED.replace("NOTE:v1", "NOTE:v3")))
    assert [(i.status, i.reason) for i in plan.items] == [("conflict", "edited")]
    assert [m["display_name"] for m in plan.missing] == ["Pat Placeholder"]


def test_a_new_card_without_uid_is_not_paired_with_someone_else(store):
    commit(store, FILE_SOURCE, file_with(ZED, PAT.replace("Pat Placeholder", "Pat Two").replace("pat@", "p2@")))
    other = ZED.replace("Zed Nouid", "Yan Other").replace("Nouid;Zed", "Other;Yan")
    plan = preview(store, FILE_SOURCE, file_with(other))
    assert [(i.status, i.action) for i in plan.items] == [("new", "import")]
    assert sorted(m["display_name"] for m in plan.missing) == ["Pat Two", "Zed Nouid"]


def test_duplicates_of_owned_contacts_are_skipped_by_default_and_never_merged(store):
    cw.create(store, {"given_name": "Ava", "family_name": "Fictional",
                      "emails": [{"value": "AVA@example.org"}]}, actor="mycontacts")
    other_ava = AVA.replace("ava-1@", "ava-2@").replace("+1 202 555 0100", "+1 202 555 0177")
    plan = preview(store, FILE_SOURCE, file_with(other_ava, SAM, SAM.replace("FN:Sam Sample", "FN:Sam Two")
                                                 .replace("sam-1@", "sam-2@").replace("sam@", "s2@")))
    ava, sam, sam2 = plan.items
    assert (ava.status, ava.action, ava.choices) == ("duplicate", "skip", ("skip", "import"))
    assert [(m.source, m.strength, m.signals) for m in ava.matches] == [("mydata", "strong", ["email", "name"])]
    assert (sam.status, sam.action) == ("new", "import")
    assert (sam2.status, sam2.action) == ("new", "import")
    done = commit(store, FILE_SOURCE, file_with(other_ava, SAM), choices={0: "import"})
    assert done.counts["created"] == 2 and len(owned_rows(store)) == 3  # imported as new, not merged


def test_a_large_import_reads_each_card_once_and_compares_only_cards_that_share_a_key(store, monkeypatch):
    cards = [AVA.replace("ava-1@", f"ava-{n}@").replace("ava@", f"ava{n}@").replace("FN:Ava Fictional", f"FN:Ava {n}")
             .replace("Fictional;Ava", f"{n};Ava").replace("+1 202 555 0100", f"+1 202 555 {n % 10000:04d}")
             for n in range(2000)]
    read = file_with(*cards, AVA.replace("ava-1@", "ava-dup@"))  # shares a number with Ava 100
    calls = {"signals": 0, "fields": 0}
    real_signals, real_fields = importer._signals, importer.card_fields

    def signals(a, b):
        calls["signals"] += 1
        return real_signals(a, b)

    def fields(*args, **kw):
        calls["fields"] += 1
        return real_fields(*args, **kw)
    monkeypatch.setattr(importer, "_signals", signals)
    monkeypatch.setattr(importer, "card_fields", fields)
    done = commit(store, FILE_SOURCE, read)
    assert done.counts["created"] == 2001
    assert calls["fields"] == 0  # the columns worked out when the file was read are used again
    assert calls["signals"] < 100  # not every pair of cards (two million)


def test_phone_numbers_match_in_e164():
    assert importer.phone_key("+1 (202) 555-0100", None) == importer.phone_key("tel:+12025550100", None) \
        == "+12025550100"
    assert importer.phone_key("(202) 555-0100", "US") == "+12025550100"
    assert importer.phone_key("(202) 555-0100", None) is None  # no region: a national number is not compared
    assert importer.phone_key("12", "US") is None


def test_cards_repeated_in_the_file_can_only_be_skipped(store):
    read = file_with(AVA, AVA)
    plan = preview(store, FILE_SOURCE, read)
    assert [(i.status, i.choices) for i in plan.items] == [("new", ("import", "skip")), ("in_file", ("skip",))]
    with pytest.raises(importer.ChoiceError):
        commit(store, FILE_SOURCE, read, choices={1: "import"})
    with pytest.raises(importer.ChoiceError):
        commit(store, FILE_SOURCE, read, choices={9: "skip"})
    assert owned_rows(store) == []


def test_a_file_with_losses_needs_them_accepted(store):
    read = read_contacts(corpus.read(corpus.MALFORMED))
    plan = preview(store, FILE_SOURCE, read)
    assert [loss["code"] for loss in plan.losses] == ["skipped_no_end", "skipped_version", "skipped_empty",
                                                      "outside_text"]
    assert sum(loss["count"] for loss in plan.losses if loss["code"].startswith("skipped_")) == 6
    with pytest.raises(importer.LossesNotAccepted):
        commit(store, FILE_SOURCE, read)
    assert owned_rows(store) == []
    done = commit(store, FILE_SOURCE, read, accept_losses=True)
    assert done.counts["created"] == 1 and done.counts["skipped"] == 6


def test_a_followed_book_is_never_a_target(followed):
    book = followed.address_books()[0]["id"]
    with pytest.raises(importer.ChoiceError):
        commit(followed, FILE_SOURCE, file_with(AVA), address_book_id=book)
    with pytest.raises(cw.NotFound):
        commit(followed, FILE_SOURCE, file_with(AVA), address_book_id="no-such-book")


# ---------------------------------------------------------------- undo

def test_undo_reverts_the_batch_forward_and_keeps_what_was_edited(tmp_path, store):
    commit(store, FILE_SOURCE, file_with(AVA, SAM))
    ava, sam = owned_rows(store)
    second = commit(store, FILE_SOURCE, file_with(AVA.replace("0100", "0111"), SAM.replace("sam@", "sam.b@"),
                                                  AVA.replace("ava-1@", "ava-3@").replace("ava@", "ava3@")
                                                  .replace("+1 202 555 0100", "+1 202 555 0133")
                                                  .replace("FN:Ava Fictional", "FN:Ava Third")))
    assert second.counts["updated"] == 2 and second.counts["created"] == 1
    sam_now = store.get(sam["id"])
    cw.update(store, sam["id"], {"nickname": "Sammy"}, if_match=sam_now["http_etag"], actor="mycontacts")
    reopened = ContactsStore(tmp_path / "contacts.sqlite")  # a restart: the undo is in the database
    undone = importer.undo_import(reopened, second.import_id, actor="mydata")
    assert (undone.removed, undone.reverted, undone.gone) == (1, 1, 0)
    assert [k["display_name"] for k in undone.kept] == ["Sam Sample"]
    assert reopened.get(ava["id"])["raw_vcard"] == AVA  # its text before the second import, as a new revision
    assert reopened.get(ava["id"])["rev"] == 3
    assert "Sammy" in reopened.get(sam["id"])["raw_vcard"]  # edited since: kept
    third = [r for r in owned_rows(reopened) if r["display_name"] == "Ava Third"][0]
    assert third["deleted_at"] is not None and third["purge_after"] is not None  # Recently deleted, not purged
    with pytest.raises(cw.UndoRefused):
        importer.undo_import(reopened, second.import_id, actor="mydata")
    with reopened.db.connect() as db:
        assert db.execute("SELECT status FROM imports WHERE id = ?", (second.import_id,)).fetchone()[0] == "undone"
        assert db.execute("SELECT COUNT(*) FROM undo_log WHERE undone_at IS NOT NULL").fetchone()[0] == 2
    plan = preview(reopened, FILE_SOURCE, file_with(AVA.replace("0100", "0111")))
    assert plan.items[0].status == "update"  # the undone import's origin no longer counts


def test_undoing_an_import_restores_the_state_before_it(store, followed):
    cw.create(store, {"given_name": "Olive", "emails": [{"value": "olive@example.org"}]}, actor="mycontacts")
    with store.db.connect() as db:
        before = db.execute("SELECT id, raw_vcard, deleted_at FROM contacts ORDER BY id").fetchall()
    shown = [c["id"] for c in store.list()]
    done = commit(store, FILE_SOURCE, read_contacts(corpus.several()))
    importer.undo_import(store, done.import_id, actor="mycontacts")
    with store.db.connect() as db:
        after = db.execute("SELECT id, raw_vcard, deleted_at FROM contacts WHERE id IN "
                           f"({', '.join('?' * len(before))}) ORDER BY id", [r[0] for r in before]).fetchall()
    assert [tuple(r) for r in after] == [tuple(r) for r in before]
    assert [c["id"] for c in store.list()] == shown


def test_a_single_imported_contact_can_be_undone_like_a_create(store):
    commit(store, FILE_SOURCE, file_with(AVA))
    [row] = owned_rows(store)
    with store.db.connect() as db:
        undo_id = db.execute("SELECT id FROM undo_log WHERE object_id = ?", (row["id"],)).fetchone()[0]
    cw.undo(store, undo_id, actor="mycontacts")
    assert store.get(row["id"]) is None and store.get(row["id"], include_deleted=True)["deleted_at"]


def test_purging_an_imported_contact_removes_its_origin(store):
    commit(store, FILE_SOURCE, read_contacts(corpus.read(corpus.SAMSUNG)))
    rows = owned_rows(store)
    for r in rows:
        cw.delete(store, r["id"], actor="mycontacts")
        cw.purge_now(store, r["id"], if_match=store.get(r["id"], include_deleted=True)["http_etag"])
    with store.db.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM origins").fetchone()[0] == 0  # the 2.1 originals went too
    assert b"Zo\xc3\xab" not in (store.db.path.read_bytes())


def test_a_file_named_after_a_person_is_forgotten_once_its_contacts_are_deleted_for_good(store):
    named = ImportSource(FILE, "", "Ava Fictional.vcf")
    done = commit(store, named, file_with(AVA))
    other = commit(store, ImportSource(FILE, "", "Sam Sample.vcf"), file_with(SAM))
    ava, sam = owned_rows(store)
    cw.delete(store, ava["id"], actor="mycontacts")
    assert importer.get_import(store, done.import_id)["label"] == "Ava Fictional.vcf"  # restorable: kept
    cw.purge_now(store, ava["id"], if_match=store.get(ava["id"], include_deleted=True)["http_etag"])
    day = datetime.fromisoformat(importer.get_import(store, done.import_id)["started_at"])
    assert importer.get_import(store, done.import_id)["label"] == f"Contacts file, {day.day} {day:%b} {day.year}"
    assert importer.get_import(store, other.import_id)["label"] == "Sam Sample.vcf"
    assert b"Ava Fictional" not in store.db.path.read_bytes()


# ---------------------------------------------------------------- the shadowing rule

def test_a_person_imported_from_a_followed_account_is_found_once(followed):
    assert len(followed.find_by_name("Ava")) == 1
    before = followed.counts(ACCOUNT)["contacts"]
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account ava@example.com")
    read = copy_of(followed, ACCOUNT)
    plan = preview(followed, source, read)
    assert plan.counts["followed_matches"] == 0  # the account's own cards are this input, not matches
    sam = [i for i in plan.items if i.display_name == "Sam Sample"][1]
    assert [(m.source, m.strength, m.signals) for m in sam.matches] == [("file", "strong", ["email", "name"])]
    done = commit(followed, source, read)
    assert done.counts["created"] == len(read.cards)
    matches = followed.find_by_name("Ava")
    assert len(matches) == 1 and followed.get(matches[0]["id"])["account_id"] == "local"
    assert all(c["account_id"] == "local" for c in followed.list())
    assert all(c["account_id"] == "local" for c in followed.search("Fictional"))
    assert followed.counts(ACCOUNT)["contacts"] == 0 and before > 0
    owned_ava = followed.get(matches[0]["id"])
    assert owned_ava["changed_in_source"] is None
    # The followed copy changes on the phone: the owned contact is flagged for review, still found once.
    edited = con.card("ava-fictional.vcf").replace("NICKNAME:Avi", "NICKNAME:Avi B")
    followed.apply(ACCOUNT, con.BOOK, con.result([con.Item(href="/1/carddavhome/card/ava-fictional.vcf",
                                                           etag='"2"', data=edited)]))
    assert followed.get(owned_ava["id"])["changed_in_source"] == ACCOUNT
    assert [c["changed_in_source"] for c in followed.list() if c["id"] == owned_ava["id"]] == [ACCOUNT]
    assert len(followed.find_by_name("Ava")) == 1
    again = preview(followed, source, copy_of(followed, ACCOUNT))
    assert [i.status for i in again.items if i.display_name == "Ava Fictional"] == ["update"]
    # Undo the import: the followed copies are shown again.
    importer.undo_import(followed, done.import_id, actor="mydata")
    assert followed.counts(ACCOUNT)["contacts"] == before and len(followed.find_by_name("Ava")) == 1
    assert followed.find_by_name("Ava")[0]["id"] != owned_ava["id"]


def test_undoing_an_import_keeps_the_origins_of_the_contacts_it_keeps(followed):
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    done = commit(followed, source, copy_of(followed, ACCOUNT))
    [ava] = followed.find_by_name("Ava")
    cw.update(followed, ava["id"], {"nickname": "Avi B"}, if_match=followed.get(ava["id"])["http_etag"],
              actor="mycontacts")
    [sam, _sam2] = [c for c in followed.list() if c["display_name"] == "Sam Sample"]
    cw.delete(followed, sam["id"], if_match=sam["http_etag"], actor="mycontacts")
    undone = importer.undo_import(followed, done.import_id, actor="mydata")
    assert [k["contact_id"] for k in undone.kept] == [ava["id"]] and undone.gone == 1
    # Ava is still the copy of the followed card: it alone is found, and importing again sees it.
    assert [m["id"] for m in followed.find_by_name("Ava")] == [ava["id"]]
    again = preview(followed, source, copy_of(followed, ACCOUNT))
    by_name = {}
    for i in again.items:
        by_name.setdefault(i.display_name, []).append((i.status, i.reason, i.target))
    assert by_name["Ava Fictional"] == [("unchanged", None, ava["id"])]
    # The Sam deleted before the undo is still known (restoring it is the way back); the other went with the undo.
    assert sorted(by_name["Sam Sample"], key=str) == sorted([("unchanged", None, sam["id"]), ("new", None, None)],
                                                            key=str)


def test_a_contact_of_yours_can_be_kept_instead_of_the_followed_copy(followed):
    mine = cw.create(followed, {"given_name": "Ava", "family_name": "Fictional", "nickname": "Mine",
                                "emails": [{"value": "ava@example.com"}]}, actor="mycontacts").contact_id
    assert len(followed.find_by_name("Ava")) == 2
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    read = copy_of(followed, ACCOUNT)
    plan = preview(followed, source, read)
    ava = next(i for i in plan.items if i.display_name == "Ava Fictional")
    assert (ava.status, ava.action, ava.choices, ava.target) == ("duplicate", "link", ("link", "skip", "import"),
                                                                 mine)
    raw = followed.get(mine)["raw_vcard"]
    done = commit(followed, source, read)
    assert done.counts["linked"] == 1
    assert [m["id"] for m in followed.find_by_name("Ava")] == [mine] and followed.get(mine)["raw_vcard"] == raw
    importer.undo_import(followed, done.import_id, actor="mydata")
    assert len(followed.find_by_name("Ava")) == 2 and followed.get(mine)["raw_vcard"] == raw


def test_a_number_shared_under_another_name_is_only_a_suggestion(followed):
    ava = cw.create(followed, {"given_name": "Ava", "family_name": "Fictional",
                               "phones": [{"value": "+1 202 555 0100"}]}, actor="mycontacts").contact_id
    ben = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:ben-1@example.org\r\nFN:Ben Other\r\nTEL:+1 202 555 0100\r\n"
           "NOTE:Only Ben has this.\r\nEND:VCARD\r\n")
    plan = preview(followed, FILE_SOURCE, file_with(ben))
    [item] = plan.items
    assert (item.status, item.action) == ("new", "import")
    assert [(m.contact_id, m.strength, m.signals) for m in item.matches] == [(ava, "suggestion", ["phone"])]
    assert plan.counts["duplicates"] == 0 and plan.counts["suggestions"] == 1
    # From a followed account: never linked behind Ava by default, so Ben's card is not hidden.
    followed.apply(ACCOUNT, con.BOOK, con.result([con.Item(href="/1/carddavhome/card/ben.vcf", etag='"1"',
                                                           data=ben)]))
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    plan = preview(followed, source, copy_of(followed, ACCOUNT))
    [item] = [i for i in plan.items if i.display_name == "Ben Other"]
    assert (item.status, item.action, item.target) == ("new", "import", None)
    done = commit(followed, source, copy_of(followed, ACCOUNT))
    assert done.counts["linked"] == 0 and {m["name"] for m in followed.find_by_name("Ben")} == {"Ben Other"}


def test_two_cards_for_one_contact_of_yours_are_not_linked_by_default(followed):
    cw.create(followed, {"given_name": "Sam", "family_name": "Sample", "emails": [{"value": "sam.sample@example.com"}]},
              actor="mycontacts")
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    plan = preview(followed, source, copy_of(followed, ACCOUNT))
    sams = [i for i in plan.items if i.display_name == "Sam Sample"]
    assert len(sams) == 2 and all(i.status == "duplicate" for i in sams)
    assert [i.action for i in sams if "link" in i.choices] and {i.action for i in sams} == {"skip"}


def test_the_same_uid_from_another_source_is_never_a_silent_second_card(followed):
    same = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:same-uid@example.org\r\nFN:Kim Invented\r\nEND:VCARD\r\n")
    commit(followed, FILE_SOURCE, file_with(same))
    [kim] = [r for r in owned_rows(followed) if r["uid"] == "same-uid@example.org"]
    followed.apply(ACCOUNT, con.BOOK, con.result([con.Item(href="/1/carddavhome/card/kim.vcf", etag='"1"',
                                                           data=same.replace("Kim Invented", "Kim Renamed"))]))
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    plan = preview(followed, source, copy_of(followed, ACCOUNT))
    [item] = [i for i in plan.items if i.display_name == "Kim Renamed"]
    assert (item.status, item.action, item.target) == ("duplicate", "link", kim["id"])
    assert [(m.contact_id, m.strength, m.signals) for m in item.matches] == [(kim["id"], "strong", ["uid"])]
    # Imported anyway: a UID of its own, the card as received kept with its origin.
    done = commit(followed, source, copy_of(followed, ACCOUNT), choices={item.index: "import"})
    assert done.counts["linked"] == 0
    uids = [r["uid"] for r in owned_rows(followed)]
    assert len(uids) == len(set(uids)) and uids.count("same-uid@example.org") == 1
    [renamed] = [r for r in owned_rows(followed) if r["display_name"] == "Kim Renamed"]
    assert renamed["uid"].startswith("urn:uuid:") and "FN:Kim Renamed\r\n" in renamed["raw_vcard"]
    with followed.db.connect() as db:
        raw = db.execute("SELECT source_raw, source_uid FROM origins WHERE object_id = ?", (renamed["id"],)).fetchone()
    assert raw["source_uid"] == "same-uid@example.org" and "UID:same-uid@example.org" in raw["source_raw"]
    # Its followed copy is still shadowed (matched by the source's UID, never the stored one).
    found = [followed.get(m["id"]) for m in followed.find_by_name("Kim")]
    assert sorted((c["display_name"], c["account_id"]) for c in found) == [("Kim Invented", "local"),
                                                                           ("Kim Renamed", "local")]


# ---------------------------------------------------------------- a file import hides followed copies (H1)

MAC = con.Collection(url="mac://contacts/c1", kind="contacts", display_name="Mac")


def _mac_person(uid: str, given: str, family: str, *, emails=(), phones=()) -> str:
    """A card as the This Mac source stores it (sources/mac/cards.py: no note, its own PRODID)."""
    return to_vcard(_contact({"id": uid, "given_name": given, "family_name": family, "kind": "person",
                              "emails": [{"value": e, "label": "_$!<Home>!$_"} for e in emails],
                              "phones": [{"value": p, "label": "_$!<Mobile>!$_"} for p in phones]}))


MAC_PEOPLE = {
    "mac-ava": ("Ava", "Fictional", ["ava@example.org"], ["+1 202 555 0100"]),
    "mac-ben": ("Ben", "Sample", [], ["+1 202 555 0142"]),
    "mac-cleo": ("Cleo", "Example", ["CLEO@example.org"], []),
    # The same name as one in the export, and nothing else in common: another person.
    "mac-dev": ("Dev", "Placeholder", ["dev.other@example.net"], ["+1 202 555 0177"]),
}


def _this_mac(store, people=MAC_PEOPLE) -> None:
    store.apply("mac", MAC, con.result([con.Item(href=uid, etag='"1"', data=_mac_person(uid, g, f, emails=e, phones=p))
                                        for uid, (g, f, e, p) in people.items()], full=True))


def _contacts_export() -> bytes:
    """A Contacts on a Mac export of the same people (its own UIDs, Apple's labels and spacing), notes on."""
    def card(n, given, family, lines):
        return ("BEGIN:VCARD\r\nVERSION:3.0\r\nPRODID:-//Apple Inc.//macOS 26.0//EN\r\n"
                f"N:{family};{given};;;\r\nFN:{given} {family}\r\n{lines}NOTE:Invented note {n}.\r\n"
                f"UID:3F1C0F0E-0000-4000-8000-00000000E00{n}\r\nEND:VCARD\r\n")
    return (card(1, "Ava", "Fictional", "item1.EMAIL;type=INTERNET;type=pref:ava@example.org\r\n"
                                        "item1.X-ABLabel:_$!<Work>!$_\r\n")
            + card(2, "Ben", "Sample", "item1.TEL;type=CELL;type=VOICE;type=pref:+1 (202) 555-0142\r\n")
            + card(3, "Cleo", "Example", "EMAIL;type=INTERNET;type=HOME:cleo@example.org\r\n")
            + card(4, "Dev", "Placeholder", "EMAIL;type=INTERNET:dev@example.org\r\n")).encode()


def _found(store, name: str) -> list[tuple[str, str]]:
    return sorted((store.get(m["id"])["account_id"], m["name"]) for m in store.find_by_name(name))


def test_a_contacts_export_hides_this_macs_copies_of_the_same_people(store):
    _this_mac(store)
    assert _found(store, "Ava") == [("mac", "Ava Fictional")]
    plan = preview(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert plan.counts["followed_matches"] == 3 and plan.counts["to_import"] == 4
    by_name = {i.display_name: i for i in plan.items}
    assert [(m.source, m.strength, m.signals, m.hides) for m in by_name["Ava Fictional"].matches] == [
        ("mac", "strong", ["email", "name"], True)]
    assert [m.hides for m in by_name["Ben Sample"].matches] == [True]
    # The same name and nothing else in common: a suggestion only, never hidden.
    assert [(m.strength, m.signals, m.hides) for m in by_name["Dev Placeholder"].matches] == [
        ("suggestion", ["name"], False)]
    done = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert done.counts["created"] == 4 and done.counts["hidden"] == 3
    for name in ("Ava", "Ben", "Cleo"):
        assert [a for a, _ in _found(store, name)] == ["local"], name  # one result per person, the owned one
    assert _found(store, "Dev") == [("local", "Dev Placeholder"), ("mac", "Dev Placeholder")]
    assert store.counts("mac")["contacts"] == 1 and len(store.list()) == 5
    with store.db.connect() as db:
        shadows = db.execute("SELECT * FROM shadows").fetchall()
    assert sorted(r["source_uid"] for r in shadows) == ["mac-ava", "mac-ben", "mac-cleo"]
    assert {r["import_id"] for r in shadows} == {done.import_id} and {r["source_account"] for r in shadows} == {"mac"}


def test_a_duplicate_skipped_by_default_is_not_counted_as_hiding(store):
    _this_mac(store)
    cw.create(store, {"given_name": "Ava", "family_name": "Fictional", "emails": [{"value": "ava@example.org"}]},
              actor="mycontacts")
    plan = preview(store, FILE_SOURCE, read_contacts(_contacts_export()))
    ava = next(i for i in plan.items if i.display_name == "Ava Fictional")
    assert (ava.status, ava.action) == ("duplicate", "skip")
    assert [m.hides for m in ava.matches if m.source == "mac"] == [True]  # if the user ticks it
    assert plan.counts["followed_matches"] == 2  # Ben and Cleo, imported by default
    done = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert done.counts["hidden"] == 2 and done.counts["followed_matches"] == 2
    ticked = commit(store, FILE_SOURCE, read_contacts(_contacts_export()), choices={ava.index: "import"})
    assert ticked.counts["hidden"] == 1


def test_a_hidden_copy_that_changes_stays_hidden_and_flags_the_contact(store):
    _this_mac(store)
    commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    [ava] = store.find_by_name("Ava")
    assert store.get(ava["id"])["changed_in_source"] is None
    changed = dict(MAC_PEOPLE, **{"mac-ava": ("Ava", "Fictional", ["ava.new@example.org"], ["+1 202 555 0100"])})
    _this_mac(store, changed)  # edited on the Mac: a new email, the same UID
    assert [m["id"] for m in store.find_by_name("Ava")] == [ava["id"]]
    assert store.get(ava["id"])["changed_in_source"] == "mac"
    assert {c["id"]: c["changed_in_source"] for c in store.list()}[ava["id"]] == "mac"


def test_deleting_the_owned_contact_shows_the_hidden_copy_again(store):
    _this_mac(store)
    done = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    [ava] = store.find_by_name("Ava")
    cw.delete(store, ava["id"], if_match=store.get(ava["id"])["http_etag"], actor="mycontacts")
    assert _found(store, "Ava") == [("mac", "Ava Fictional")]
    cw.restore(store, ava["id"], actor="mycontacts")
    assert _found(store, "Ava") == [("local", "Ava Fictional")]
    # Deleted for good: its shadows go with it, and the Mac copy is back for good.
    cw.delete(store, ava["id"], if_match=store.get(ava["id"])["http_etag"], actor="mycontacts")
    cw.purge_now(store, ava["id"], if_match=store.get(ava["id"], include_deleted=True)["http_etag"])
    assert _found(store, "Ava") == [("mac", "Ava Fictional")]
    with store.db.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM shadows WHERE object_id = ?", (ava["id"],)).fetchone()[0] == 0
    # Undoing the import shows the others again.
    undone = importer.undo_import(store, done.import_id, actor="mydata")
    assert undone.unhidden == 2 and _found(store, "Ben") == [("mac", "Ben Sample")]


def test_an_account_copy_hides_its_own_cards_and_a_file_hides_every_followed_copy(followed):
    """The same person in a followed iCloud account and on this Mac: importing a copy of the account hides only
    the account's card (by UID); a file of that person hides the Mac's too (the same name and email or phone)."""
    ava_icloud = con.card("ava-fictional.vcf")
    _this_mac(followed, {"mac-ava": ("Ava", "Fictional", ["ava@example.com"], [])})
    assert sorted(a for a, _ in _found(followed, "Ava Fictional")) == [ACCOUNT, "mac"]
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    copy = commit(followed, source, copy_of(followed, ACCOUNT))
    assert copy.counts["hidden"] == 0
    assert sorted(a for a, _ in _found(followed, "Ava Fictional")) == ["local", "mac"]
    importer.undo_import(followed, copy.import_id, actor="mydata")
    done = commit(followed, FILE_SOURCE, read_contacts(ava_icloud.replace("UID:", "UID:file-").encode()))
    assert done.counts["created"] == 1 and done.counts["hidden"] == 2
    assert [a for a, _ in _found(followed, "Ava Fictional")] == ["local"]
    # A copy of the account imported after it: Ava's card is one the file already kept, never a second Ava.
    plan = preview(followed, source, copy_of(followed, ACCOUNT))
    [item] = [i for i in plan.items if i.display_name == "Ava Fictional"]
    assert (item.status, item.reason) == ("unchanged", None)
    # Stopping following the account loses nothing of Ava, but she may hold details the file's copy does not.
    with followed.db.connect() as db:
        left = importer.followed_left(db, ACCOUNT)
    assert left["linked"] == 1


def test_importing_the_file_again_hides_a_source_turned_on_since(store):
    first = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert first.counts["hidden"] == 0
    _this_mac(store)  # This Mac turned on after the import: both copies show
    assert len(store.find_by_name("Ava")) == 2
    plan = preview(store, FILE_SOURCE, read_contacts(_contacts_export()))
    ava = next(i for i in plan.items if i.display_name == "Ava Fictional")
    assert ava.status == "unchanged" and [m.hides for m in ava.matches] == [False, True]
    again = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert again.counts["created"] == 0 and again.counts["hidden"] == 3
    assert [a for a, _ in _found(store, "Ava")] == ["local"]
    undone = importer.undo_import(store, again.import_id, actor="mydata")
    assert undone.unhidden == 3 and len(store.find_by_name("Ava")) == 2


def test_merged_contacts_keep_hiding_after_their_originals_are_deleted_for_good(store):
    _this_mac(store)
    commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    [ava] = store.find_by_name("Ava")
    other = cw.create(store, {"given_name": "Ava", "family_name": "F.", "phones": [{"value": "+1 202 555 0111"}]},
                      actor="mycontacts").contact_id
    merged = merge_.merge(store, [(ava["id"], store.get(ava["id"])["http_etag"]),
                                  (other, store.get(other)["http_etag"])], names_from=ava["id"], actor="mycontacts")
    assert [m["id"] for m in store.find_by_name("Ava Fictional")] == [merged.contact_id]
    gone = store.get(ava["id"], include_deleted=True)
    cw.purge_now(store, ava["id"], if_match=gone["http_etag"])
    assert [m["id"] for m in store.find_by_name("Ava Fictional")] == [merged.contact_id]
    with store.db.connect() as db:
        assert {r[0] for r in db.execute("SELECT held_by FROM shadows WHERE source_uid = 'mac-ava'")} == {
            merged.contact_id}
    _this_mac(store, dict(MAC_PEOPLE, **{"mac-ava": ("Ava", "Fictional", ["ava@example.org"], ["+1 202 555 0199"])}))
    assert store.get(merged.contact_id)["changed_in_source"] == "mac"


@pytest.mark.parametrize("original", ["in_trash", "deleted_for_good"])
def test_importing_again_hides_a_source_turned_on_since_behind_a_merged_contact(store, original):
    commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    [ava] = store.find_by_name("Ava")
    other = cw.create(store, {"given_name": "Ava", "family_name": "F.", "phones": [{"value": "+1 202 555 0111"}]},
                      actor="mycontacts").contact_id
    merged = merge_.merge(store, [(ava["id"], store.get(ava["id"])["http_etag"]),
                                  (other, store.get(other)["http_etag"])], names_from=ava["id"], actor="mycontacts")
    if original == "deleted_for_good":
        cw.purge_now(store, ava["id"], if_match=store.get(ava["id"], include_deleted=True)["http_etag"])
    _this_mac(store)  # turned on after the import and the merge: both copies show
    assert sorted(a for a, _ in _found(store, "Ava Fictional")) == ["local", "mac"]
    plan = preview(store, FILE_SOURCE, read_contacts(_contacts_export()))
    item = next(i for i in plan.items if i.display_name == "Ava Fictional")
    assert item.status == "unchanged" and [m.hides for m in item.matches if m.source == "mac"] == [True]
    again = commit(store, FILE_SOURCE, read_contacts(_contacts_export()))
    assert again.counts["hidden"] == 3
    assert [m["id"] for m in store.find_by_name("Ava Fictional")] == [merged.contact_id]


def test_an_account_copy_analyses_afresh_a_card_whose_hiding_contact_was_deleted(followed):
    """A file import hid the iCloud card; once that contact is in Recently deleted the card shows again, and a copy
    of the account offers it as new: it was never imported from the account."""
    ava_icloud = con.card("ava-fictional.vcf")
    done = commit(followed, FILE_SOURCE, read_contacts(ava_icloud.replace("UID:", "UID:file-").encode()))
    assert done.counts["hidden"] == 1
    [ava] = [r for r in owned_rows(followed)]
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    hidden = next(i for i in preview(followed, source, copy_of(followed, ACCOUNT)).items
                  if i.display_name == "Ava Fictional")
    assert (hidden.status, hidden.reason) == ("unchanged", None)  # kept as yours (the file's copy)
    cw.delete(followed, ava["id"], if_match=followed.get(ava["id"])["http_etag"], actor="mycontacts")
    plan = preview(followed, source, copy_of(followed, ACCOUNT))
    item = next(i for i in plan.items if i.display_name == "Ava Fictional")
    assert (item.status, item.action) == ("new", "import") and plan.counts["deleted"] == 0
    # Restored: kept as yours again.
    cw.restore(followed, ava["id"], actor="mycontacts")
    item = next(i for i in preview(followed, source, copy_of(followed, ACCOUNT)).items
                if i.display_name == "Ava Fictional")
    assert item.status == "unchanged"


# ---------------------------------------------------------------- merge

def _two(store):
    a = cw.create(store, {"given_name": "Ava", "family_name": "Fictional", "emails": [{"label": "work", "value":
                  "ava@example.org"}], "phones": [{"label": "mobile", "value": "+1 202 555 0100"}],
                  "note": "First note."}, actor="mycontacts").contact_id
    b = cw.create(store, {"given_name": "Ava", "family_name": "F.", "company": "Example Widgets",
                          "emails": [{"label": "home", "value": "AVA@example.org"},
                                     {"label": "Chess club", "value": "ava.club@example.org"}],
                          "phones": [{"value": "+12025550100"}, {"label": "home", "value": "+1 202 555 0188"}],
                          "addresses": [{"label": "home", "street": "1 Example Street", "locality": "Springfield"}],
                          "note": "Second note."}, actor="mycontacts").contact_id
    return a, b


def test_merge_keeps_every_distinct_value_and_the_chosen_names(store):
    a, b = _two(store)
    raws = {i: store.get(i)["raw_vcard"] for i in (a, b)}
    merged = merge_.merge(store, [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])], names_from=a,
                          actor="mycontacts")
    m = store.get(merged.contact_id)
    assert m["display_name"] == "Ava Fictional" and m["organisation"] == "Example Widgets"
    assert sorted(e["value"].lower() for e in m["emails"]) == ["ava.club@example.org", "ava@example.org"]
    assert sorted(p["value"] for p in m["phones"]) == ["+1 202 555 0100", "+1 202 555 0188"]
    assert [x["street"] for x in m["addresses"]] == ["1 Example Street"]
    assert "Chess club" in m["raw_vcard"] and m["note"] == "First note.\n\nSecond note."
    lines = m["raw_vcard"].split("\r\n")
    kept = [line for line in raws[a].split("\r\n") if not line.startswith(("NOTE:", "REV:"))]
    assert [line for line in lines if line in kept] == kept  # the first one's lines, as they were, in order
    assert [c["id"] for c in store.list()] == [merged.contact_id] and len(store.find_by_name("Ava")) == 1
    for i in (a, b):
        gone = store.get(i, include_deleted=True)
        assert gone["deleted_at"] and gone["raw_vcard"] == raws[i]
    undone = merge_.undo(store, merged.merge_id, actor="mycontacts")
    assert set(undone.originals) == {a, b}
    assert {c["id"] for c in store.list()} == {a, b}
    assert {i: store.get(i)["raw_vcard"] for i in (a, b)} == raws
    assert store.get(merged.contact_id) is None
    with pytest.raises(cw.UndoRefused):
        merge_.undo(store, merged.merge_id, actor="mycontacts")


def test_merge_carries_what_the_kept_card_lacks_and_reports_the_rest():
    base = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:a@example.org\r\nFN:Ava Fictional\r\nN:Fictional;Ava;;;\r\n"
            "TITLE:Librarian\r\nEND:VCARD\r\n")
    other = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:b@example.org\r\nFN:Ava F.\r\nN:F.;Ava;;;\r\nTITLE:Chess coach\r\n"
             "TITLE:Librarian\r\nX-ANNIVERSARY:2010-06-01\r\nX-PHONETIC-FIRST-NAME:Ah-va\r\nGENDER:F\r\n"
             "item1.X-GOOGLE-TALK:ava@example.org\r\nitem1.X-ABLabel:chess\r\nX-ABShowAs:COMPANY\r\nEND:VCARD\r\n")
    text, left_out = merge_.merge_cards(base, [other], region=REGION)
    for line in ("X-ANNIVERSARY:2010-06-01", "X-PHONETIC-FIRST-NAME:Ah-va", "GENDER:F",
                 "item1.X-GOOGLE-TALK:ava@example.org", "item1.X-ABLabel:chess", "TITLE:Librarian"):
        assert line + "\r\n" in text
    assert "Chess coach" not in text and "X-ABShowAs" not in text and "FN:Ava F." not in text
    assert left_out == {"TITLE": 1, "X-ABSHOWAS": 1}  # names and counts, never a value


def test_a_merge_preview_writes_nothing_and_shows_what_is_left_out(store, monkeypatch):
    a = cw.create(store, {"given_name": "Ava", "family_name": "Fictional", "job_title": "Librarian",
                          "birthday": "1990-03-18"}, actor="mycontacts").contact_id
    b = cw.create(store, {"given_name": "Ava", "family_name": "F.", "job_title": "Chess coach",
                          "emails": [{"value": "ava@example.org"}]}, actor="mycontacts").contact_id
    with store.db.transaction() as db:  # b was changed last
        db.execute("UPDATE contacts SET modified_at = '2099-01-01T00:00:00+00:00' WHERE id = ?", (b,))
    pair = [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])]
    before = _counts(store)
    preview_ = merge_.merge_preview(store, pair, names_from=a)
    assert _counts(store) == before  # written nowhere
    assert (preview_.names_from, preview_.newest) == (a, b)
    assert list(preview_.left_out) == [{"property": "TITLE", "value": "Chess coach", "contact_id": b}]
    assert "EMAIL:ava@example.org" in preview_.text and "TITLE:Librarian" in preview_.text
    # Without names_from, the names of the contact changed most recently (DuplicatePair, Decisions 2).
    other = merge_.merge_preview(store, pair)
    assert (other.names_from, other.newest) == (b, b)
    assert list(other.left_out) == [{"property": "TITLE", "value": "Librarian", "contact_id": a}]
    assert "BDAY:1990-03-18" in other.text  # a value only the other has is taken
    # The merge itself makes what the preview showed, with the same default.
    done = merge_.merge(store, pair, actor="mycontacts")
    merged = store.get(done.contact_id)["raw_vcard"]
    strip = lambda text: [line for line in text.splitlines() if not line.startswith(("REV:", "UID:"))]  # noqa: E731
    assert strip(merged) == strip(other.text) and done.left_out == (("TITLE", 1),)
    with pytest.raises(cw.PreconditionFailed):
        merge_.merge_preview(store, pair)  # they changed: they are in Recently deleted now
    photo = "PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQ\r\n"
    assert merge_.merge_cards(f"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:A\r\n{photo}END:VCARD\r\n",
                              [f"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:A\r\n{photo.replace('4AAQ', '4BBQ')}"
                               "END:VCARD\r\n"], details=(details := []))[1] == {"PHOTO": 1}
    assert details == [{"property": "PHOTO", "other": 0, "value": None}]  # a photo is named, never quoted


def test_a_merge_changed_since_is_not_undone(store):
    a, b = _two(store)
    merged = merge_.merge(store, [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])],
                          names_from=b, actor="mycontacts")
    m = store.get(merged.contact_id)
    assert m["display_name"] == "Ava F."
    cw.update(store, m["id"], {"job_title": "Inventor"}, if_match=m["http_etag"], actor="mycontacts")
    with pytest.raises(cw.UndoRefused):
        merge_.undo(store, merged.merge_id, actor="mycontacts")


def test_merge_refuses_what_it_cannot_do(followed):
    a, b = _two(followed)
    etag = followed.get(a)["http_etag"]
    with pytest.raises(merge_.MergeRefused):
        merge_.merge(followed, [(a, etag)], actor="mycontacts")
    with pytest.raises(merge_.MergeRefused):
        merge_.merge(followed, [(a, etag), (a, etag)], actor="mycontacts")
    with pytest.raises(cw.PreconditionFailed):
        merge_.merge(followed, [(a, etag), (b, '"1-stale"')], actor="mycontacts")
    other = followed.list()[0]
    other = next(c for c in followed.list() if c["account_id"] == ACCOUNT)
    with pytest.raises(cw.ReadOnly):
        merge_.merge(followed, [(a, etag), (other["id"], other["http_etag"])], actor="mycontacts")
    assert followed.get(a)["deleted_at"] is None


def test_merged_copies_of_a_followed_account_keep_shadowing_it(followed):
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    commit(followed, source, copy_of(followed, ACCOUNT))
    sams = [c for c in followed.list() if c["display_name"] == "Sam Sample"]
    assert len(sams) == 2 and all(c["account_id"] == "local" for c in sams)
    merged = merge_.merge(followed, [(c["id"], c["http_etag"]) for c in sams], actor="mycontacts")
    assert [c["id"] for c in followed.find_by_name("Sam")] == [merged.contact_id]
    edited = con.card("sam-sample-1.vcf").replace("FN:Sam Sample", "FN:Sam Sample\nNICKNAME:Sammy")
    followed.apply(ACCOUNT, con.BOOK, con.result([con.Item(href="/1/carddavhome/card/sam-sample-1.vcf", etag='"2"',
                                                           data=edited)]))
    assert followed.get(merged.contact_id)["changed_in_source"] == ACCOUNT
    merge_.undo(followed, merged.merge_id, actor="mycontacts")
    assert sorted(c["id"] for c in followed.find_by_name("Sam")) == sorted(c["id"] for c in sams)


@pytest.mark.parametrize("how", ["expire", "purge_now"])
def test_a_merged_contact_keeps_shadowing_after_its_originals_are_deleted_for_good(followed, how):
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    commit(followed, source, copy_of(followed, ACCOUNT))
    sams = [c for c in followed.list() if c["display_name"] == "Sam Sample"]
    merged = merge_.merge(followed, [(c["id"], c["http_etag"]) for c in sams], actor="mycontacts")
    if how == "expire":
        later = datetime.now(timezone.utc) + timedelta(days=31)
        assert cw.expire_trash(followed, now=later) == 2
    else:
        for c in sams:
            cw.purge_now(followed, c["id"], if_match=followed.get(c["id"], include_deleted=True)["http_etag"])
    assert all(followed.get(c["id"], include_deleted=True) is None for c in sams)
    assert [c["id"] for c in followed.find_by_name("Sam")] == [merged.contact_id]
    with followed.db.connect() as db:
        held = db.execute("SELECT held_by, source_raw FROM origins WHERE object_id IN (?, ?)",
                          [c["id"] for c in sams]).fetchall()
    assert [tuple(r) for r in held] == [(merged.contact_id, None)] * 2
    # Importing again knows both cards: unchanged, or a conflict (merged) once one changed; never a new copy.
    edited = con.card("sam-sample-1.vcf").replace("FN:Sam Sample", "FN:Sam Sample\nNICKNAME:Sammy")
    followed.apply(ACCOUNT, con.BOOK, con.result([con.Item(href="/1/carddavhome/card/sam-sample-1.vcf", etag='"2"',
                                                           data=edited)]))
    assert followed.get(merged.contact_id)["changed_in_source"] == ACCOUNT
    again = preview(followed, source, copy_of(followed, ACCOUNT))
    assert sorted((i.status, i.reason) for i in again.items if i.display_name == "Sam Sample") == [
        ("conflict", "merged"), ("unchanged", None)]
    # Once the merged card goes for good too, the origins go with it.
    cw.delete(followed, merged.contact_id, if_match=followed.get(merged.contact_id)["http_etag"], actor="mycontacts")
    cw.purge_now(followed, merged.contact_id,
                 if_match=followed.get(merged.contact_id, include_deleted=True)["http_etag"])
    with followed.db.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM origins WHERE held_by IS NOT NULL").fetchone()[0] == 0
    assert len(followed.find_by_name("Sam")) == 2  # the followed copies are shown again


def test_restoring_one_merged_original_takes_it_out_of_the_merge(followed):
    source = ImportSource(ICLOUD, ACCOUNT, "iCloud account")
    commit(followed, source, copy_of(followed, ACCOUNT))
    sams = [c for c in followed.list() if c["display_name"] == "Sam Sample"]
    merged = merge_.merge(followed, [(c["id"], c["http_etag"]) for c in sams], actor="mycontacts")
    first = followed.get(sams[0]["id"], include_deleted=True)
    cw.restore(followed, first["id"], if_match=first["http_etag"], actor="mycontacts")
    with followed.db.connect() as db:
        assert db.execute("SELECT merged_into FROM contacts WHERE id = ?", (first["id"],)).fetchone()[0] is None
    with pytest.raises(cw.UndoRefused):
        merge_.undo(followed, merged.merge_id, actor="mycontacts")
    # Deleted again, it no longer hides its followed copy through the merged card.
    cw.delete(followed, first["id"], if_match=followed.get(first["id"])["http_etag"], actor="mycontacts")
    assert sorted(followed.get(c["id"])["account_id"] for c in followed.find_by_name("Sam")) == [ACCOUNT, "local"]


def test_merging_needs_no_contact_data_in_its_record(store):
    a, b = _two(store)
    merged = merge_.merge(store, [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])], actor="mycontacts")
    with store.db.connect() as db:
        row = db.execute("SELECT * FROM merges WHERE id = ?", (merged.merge_id,)).fetchone()
    assert "Ava" not in json.dumps(dict(row)) and "example.org" not in json.dumps(dict(row))
