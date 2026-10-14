"""Contact import at the store (sources/importer.py) and merging (sources/contacts_merge.py): a preview writes
nothing; a commit is one batch with origins, revisions, changes and undo entries; importing again makes no
duplicate, updates only what nobody edited and reports the rest; undo reverts the batch forward and works after a
restart; the shadowing rule (one find_contact match for a person imported from a source still followed); merge and
undo merge. Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import json
import sqlite3

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


def test_a_contact_of_yours_can_be_kept_instead_of_the_followed_copy(followed):
    mine = cw.create(followed, {"given_name": "Ava", "family_name": "Mine",
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


def test_this_mac_rows_are_never_shadowed_by_a_file(followed):
    mac = con.Collection(url="mac://contacts/c1", kind="contacts", display_name="Mac")
    followed.apply("mac", mac, con.result([con.item("ava-fictional.vcf", href="ava-mac")]))
    commit(followed, FILE_SOURCE, read_contacts(con.card("ava-fictional.vcf").encode()))
    assert len(followed.find_by_name("Ava")) == 3  # a file is no source: owned, iCloud and This Mac


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


def test_merge_keeps_every_distinct_value_and_the_first_names(store):
    a, b = _two(store)
    raws = {i: store.get(i)["raw_vcard"] for i in (a, b)}
    merged = merge_.merge(store, [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])], actor="mycontacts")
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


def test_merging_needs_no_contact_data_in_its_record(store):
    a, b = _two(store)
    merged = merge_.merge(store, [(a, store.get(a)["http_etag"]), (b, store.get(b)["http_etag"])], actor="mycontacts")
    with store.db.connect() as db:
        row = db.execute("SELECT * FROM merges WHERE id = ?", (merged.merge_id,)).fetchone()
    assert "Ava" not in json.dumps(dict(row)) and "example.org" not in json.dumps(dict(row))
