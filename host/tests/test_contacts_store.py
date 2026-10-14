"""The contacts mirror: parsing iCloud (3.0) and 4.0 vCards, upserts, soft and hard deletes, search.
All fixtures are invented (tests/fixtures/dav/contacts)."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path

import pytest

from mydata.sources.contacts_store import ContactsStore, fts_query
from mydata.sources.dav.discovery import Collection
from mydata.sources.dav.sync import CollectionState, Item, SyncResult
from mydata.sources.owned import OWNED_ACCOUNT
from mydata.sources.vcard import parse_vcard
from owned_data import BOOK_URL as OWNED_BOOK_URL
from owned_data import add_owned, owned_rows

FIXTURES = Path(__file__).parent / "fixtures" / "dav" / "contacts"
BOOK = Collection(url="https://contacts.example.com/1/carddavhome/card/", kind="contacts", display_name="Card")
OTHER_BOOK = Collection(url="https://contacts.example.com/1/carddavhome/work/", kind="contacts", display_name="Work")


def card(name: str) -> str:
    return (FIXTURES / name).read_text()


def item(name: str, etag: str = '"1"', href: str | None = None) -> Item:
    return Item(href=href or f"/1/carddavhome/card/{name}", etag=etag, data=card(name))


def result(changed=(), deleted=(), full=False, etags=None, token="t1") -> SyncResult:
    changed = list(changed)
    if etags is None:
        etags = {i.href: i.etag for i in changed}
    return SyncResult(changed=changed, deleted=list(deleted), state=CollectionState(sync_token=token, etags=etags),
                      full=full)


ALL = ["ava-fictional.vcf", "zoe-example-v4.vcf", "org-only.vcf", "phone-only.vcf", "empty.vcf", "sam-sample-1.vcf",
       "sam-sample-2.vcf"]


@pytest.fixture
def store(tmp_path) -> ContactsStore:
    s = ContactsStore(tmp_path / "contacts.sqlite")
    s.apply("acc-1", BOOK, result([item(n) for n in ALL], full=True))
    return s


def by_name(store: ContactsStore, name: str) -> dict:
    [hit] = [c for c in store.list() if c["display_name"] == name]
    return store.get(hit["id"])


def by_file(store: ContactsStore, name: str) -> dict:
    [hit] = [c for c in store.list() if c["href"].endswith("/" + name)]
    return store.get(hit["id"])


# ---------------------------------------------------------------- parsing


def test_icloud_card_fields_labels_and_photo(store):
    ava = by_name(store, "Ava Fictional")
    assert ava["given_name"] == "Ava" and ava["family_name"] == "Fictional" and ava["nickname"] == "Avi"
    assert ava["organisation"] == "Example Widgets, Research"
    assert ava["emails"] == [
        {"value": "ava@example.com", "label": "work"},  # grouped item1 + X-ABLabel _$!<Work>!$_
        {"value": "ava.home@example.net", "label": "home"},  # TYPE param
        {"value": "ava.club@example.org", "label": "Chess club"},  # custom label
    ]
    assert [p["value"] for p in ava["phones"]] == ["+1 (555) 010-0100", "+44 20 7946 0000", "+1 555 0199"]
    assert [p["label"] for p in ava["phones"]] == ["mobile", "home", "Gym locker"]
    assert ava["addresses"] == [{"label": "home", "street": "1 Example Street", "locality": "Springfield",
                                 "region": "", "postal_code": "12345", "country": "Exampleland"}]
    assert ava["birthday"] == "--04-15"  # Apple's "year omitted" marker
    assert ava["note"] == "Met at the invented conference, row two.\nBrings biscuits."
    assert ava["has_photo"] is True
    assert ava["uid"] == "3F1C0F0E-0000-4000-8000-00000000A001"
    assert "PHOTO;ENCODING=b" in ava["raw_vcard"]  # the photo itself stays in the raw card


def test_vcard_4(store):
    zoe = by_name(store, "Zoë Exämple")
    assert zoe["emails"] == [{"value": "zoe@example.org", "label": "work"},
                             {"value": "zoe.home@example.net", "label": "home"}]
    assert zoe["phones"] == [{"value": "+44-20-7946-0123", "label": "mobile"}]  # tel: URI, "voice,cell"
    assert zoe["birthday"] == "1990-04-01"
    assert zoe["has_photo"] is True


def test_no_name_falls_back_to_org_then_email_then_phone_then_no_name(store):
    names = {c["display_name"] for c in store.list()}
    assert {"Example Bakery Ltd", "+1 555 0177", "No name"} <= names
    bakery = by_name(store, "Example Bakery Ltd")
    assert bakery["full_name"] == "" and bakery["organisation"] == "Example Bakery Ltd"
    assert parse_vcard("BEGIN:VCARD\nVERSION:3.0\nEMAIL:only@example.com\nEND:VCARD\n").display_name == "only@example.com"


def test_folded_lines_are_unfolded():
    text = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fic\r\n tional\r\nNOTE:one\r\n  two\r\nEND:VCARD\r\n"
    parsed = parse_vcard(text)
    assert parsed.full_name == "Ava Fictional"
    assert parsed.note == "one two"


def test_unreadable_card_still_yields_what_a_line_scan_finds():
    text = "BEGIN:VCARD\nVERSION:3.0\nFN:Broken Example\nEMAIL:broken@example.com\nBDAY;=:::\nN:x;y;;\x00\nEND:VCARD"
    parsed = parse_vcard(text)
    assert parsed.full_name == "Broken Example"
    assert parsed.emails[0]["value"] == "broken@example.com"
    garbage = parse_vcard("this is not a vcard at all")
    assert garbage.display_name == "No name"


# ---------------------------------------------------------------- storage


def test_rows_have_device_ids_timestamps_and_no_delete_marker(store):
    rows = store.list()
    assert len(rows) == len(ALL)
    for r in rows:
        assert len(r["id"]) == 36 and r["created_at"] and r["modified_at"] and r["deleted_at"] is None
        assert "raw_vcard" not in r  # the list stays light; get() returns the raw card
        assert r["account_id"] == "acc-1" and r["collection_url"] == BOOK.url


def test_exact_duplicates_are_kept_as_two_rows_and_both_found(store):
    sams = [c for c in store.list() if c["display_name"] == "Sam Sample"]
    assert len(sams) == 2 and sams[0]["id"] != sams[1]["id"]
    assert len(store.search("sam sample")) == 2
    found = store.find_by_name("Sam")
    assert len(found) == 2
    assert all(f["emails"] == ["sam.sample@example.com"] for f in found)


def test_upsert_keeps_id_and_created_at_and_updates_fields(store):
    before = by_file(store, "sam-sample-1.vcf")
    href = before["href"]
    changed = card(Path(href).name).replace("FN:Sam Sample", "FN:Samantha Sample")
    store.apply("acc-1", BOOK, result([Item(href=href, etag='"2"', data=changed)]))
    after = store.get(before["id"])
    assert after["display_name"] == "Samantha Sample" and after["etag"] == '"2"'
    assert after["created_at"] == before["created_at"]
    assert store.search("samantha")[0]["id"] == before["id"]


def test_raw_hash_and_rev_follow_the_raw_card(store):
    import hashlib
    before = by_file(store, "sam-sample-1.vcf")
    with store.db.connect() as db:
        row = lambda: db.execute("SELECT rev, raw_sha256, raw_vcard FROM contacts WHERE id = ?",  # noqa: E731
                                 (before["id"],)).fetchone()
        assert row()["rev"] == 1 and row()["raw_sha256"] == hashlib.sha256(row()["raw_vcard"].encode()).hexdigest()
        store.apply("acc-1", BOOK, result([Item(href=before["href"], etag='"2"', data=card("sam-sample-1.vcf"))]))
        assert row()["rev"] == 1  # a new ETag for the same text is not a new version
        changed = card("sam-sample-1.vcf").replace("FN:Sam Sample", "FN:Sam Changed")
        store.apply("acc-1", BOOK, result([Item(href=before["href"], etag='"3"', data=changed)]))
        assert row()["rev"] == 2 and row()["raw_sha256"] == hashlib.sha256(changed.encode()).hexdigest()


def test_same_href_in_two_books_or_accounts_are_separate(tmp_path):
    s = ContactsStore(tmp_path / "c.sqlite")
    href = "/shared/same.vcf"
    s.apply("acc-1", BOOK, result([item("sam-sample-1.vcf", href=href)]))
    s.apply("acc-1", OTHER_BOOK, result([item("sam-sample-1.vcf", href=href)]))
    s.apply("acc-2", BOOK, result([item("sam-sample-1.vcf", href=href)]))
    assert len(s.list()) == 3
    assert {b["name"] for b in s.address_books()} == {"Card", "Work"}
    assert len(s.address_books()) == 3


def test_deleted_href_gets_soft_delete_marker(store):
    sam = by_file(store, "sam-sample-1.vcf")
    store.apply("acc-1", BOOK, result(deleted=[sam["href"]]))
    assert store.get(sam["id"]) is None
    gone = store.get(sam["id"], include_deleted=True)
    assert gone["deleted_at"] is not None
    assert len(store.find_by_name("Sam")) == 1
    assert all(c["id"] != sam["id"] for c in store.search("sample"))


def test_full_resync_soft_deletes_what_is_not_listed(store):
    keep = ["ava-fictional.vcf", "org-only.vcf"]
    listing = {f"/1/carddavhome/card/{n}": '"1"' for n in keep}
    # Nothing changed for the kept two (etags equal), so changed is empty: only the listing says they exist.
    store.apply("acc-1", BOOK, result(full=True, etags=listing))
    assert sorted(c["display_name"] for c in store.list()) == ["Ava Fictional", "Example Bakery Ltd"]


def test_reappearing_href_is_undeleted_with_the_same_id(store):
    zoe = by_name(store, "Zoë Exämple")
    store.apply("acc-1", BOOK, result(deleted=[zoe["href"]]))
    store.apply("acc-1", BOOK, result([item("zoe-example-v4.vcf", etag='"9"')]))
    back = store.get(zoe["id"])
    assert back is not None and back["deleted_at"] is None and back["etag"] == '"9"'


def test_sync_state_is_saved_per_book(store):
    state = store.collection_state("acc-1", BOOK.url)
    assert state.sync_token == "t1"
    assert set(state.etags) == {f"/1/carddavhome/card/{n}" for n in ALL}
    assert store.collection_state("acc-1", OTHER_BOOK.url) == CollectionState()


def test_delete_account_hard_deletes_rows_index_and_state(tmp_path):
    path = tmp_path / "contacts.sqlite"
    s = ContactsStore(path)
    s.apply("acc-1", BOOK, result([item("ava-fictional.vcf")]))
    s.apply("acc-2", BOOK, result([item("zoe-example-v4.vcf")]))
    s.delete_account("acc-1")
    assert [c["display_name"] for c in s.list()] == ["Zoë Exämple"]
    assert s.search("ava") == [] and s.find_by_name("Ava") == []
    assert s.collection_state("acc-1", BOOK.url) == CollectionState()
    db = sqlite3.connect(path)
    assert db.execute("SELECT COUNT(*) FROM contacts WHERE account_id = 'acc-1'").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM address_books WHERE account_id = 'acc-1'").fetchone()[0] == 0
    db.execute("INSERT INTO contacts_fts(contacts_fts) VALUES ('integrity-check')")  # index matches the table
    db.close()
    assert b"ava@example.com" not in path.read_bytes()  # secure_delete + checkpoint: nothing left in the file


def test_delete_account_survives_owned_contacts(tmp_path):
    """Twin of the test above: an owned address book in the same file (even one whose cards were written
    with the removed account's id) comes through every hard delete unchanged."""
    path = tmp_path / "contacts.sqlite"
    add_owned(tmp_path)
    s = ContactsStore(path)
    s.apply("acc-1", BOOK, result([item("ava-fictional.vcf")]))
    before = owned_rows(tmp_path)
    s.delete_account("acc-1")
    s.delete_account(OWNED_ACCOUNT)  # the owned data's own account id deletes nothing
    assert s.delete_collections(OWNED_ACCOUNT, [OWNED_BOOK_URL]) == 0
    assert owned_rows(tmp_path) == before
    assert sorted(c["display_name"] for c in s.list()) == ["Olive Owned", "Pip Keepsake"]
    assert s.search("olive")[0]["display_name"] == "Olive Owned"  # its index rows were not touched
    assert s.account_ids() == []
    assert b"ava@example.com" not in path.read_bytes() and b"olive@example.org" in path.read_bytes()


def test_delete_collections_deletes_only_followed_books(tmp_path):
    add_owned(tmp_path)
    s = ContactsStore(tmp_path / "contacts.sqlite")
    s.apply("acc-1", BOOK, result([item("ava-fictional.vcf")]))
    s.apply("acc-1", OTHER_BOOK, result([item("zoe-example-v4.vcf", href="/1/work/zoe.vcf")]))
    before = owned_rows(tmp_path)
    assert s.delete_collections("acc-1", [BOOK.url, OWNED_BOOK_URL]) == 1
    assert owned_rows(tmp_path) == before
    assert {c["display_name"] for c in s.list()} == {"Zoë Exämple", "Olive Owned", "Pip Keepsake"}


def test_mark_collections_gone(store):
    store.mark_collections_gone("acc-1", [])
    assert store.list() == [] and store.address_books() == []


def test_mark_collections_gone_survives_owned_contacts(store, tmp_path):
    add_owned(tmp_path)
    before = owned_rows(tmp_path)
    store.mark_collections_gone("acc-1", [])
    store.mark_collections_gone(OWNED_ACCOUNT, [])
    assert owned_rows(tmp_path) == before
    assert [b["name"] for b in store.address_books()] == ["Kept (owned)"]


# ---------------------------------------------------------------- group cards

GROUP_3 = ("BEGIN:VCARD\r\nVERSION:3.0\r\nN:Book club;;;;\r\nFN:Book club\r\nX-ADDRESSBOOKSERVER-KIND:group\r\n"
           "UID:group-book-club@example.org\r\n"
           "X-ADDRESSBOOKSERVER-MEMBER:urn:uuid:3F1C0F0E-0000-4000-8000-00000000A001\r\nEND:VCARD\r\n")
GROUP_4 = ("BEGIN:VCARD\nVERSION:4.0\nKIND:group\nFN:Sam fans\nUID:urn:uuid:group-sam-fans\n"
           "MEMBER:urn:uuid:sam-1@example.org\nEND:VCARD\n")
ORG_4 = "BEGIN:VCARD\nVERSION:4.0\nKIND:org\nFN:Example Library\nUID:urn:uuid:org-library-1\nEND:VCARD\n"


@pytest.fixture
def with_groups(store):
    store.apply("acc-1", BOOK, result([Item(href="/1/carddavhome/card/g3.vcf", etag='"g3"', data=GROUP_3),
                                       Item(href="/1/carddavhome/card/g4.vcf", etag='"g4"', data=GROUP_4),
                                       Item(href="/1/carddavhome/card/o4.vcf", etag='"o4"', data=ORG_4)]))
    return store


def test_group_cards_are_kept_but_never_shown_counted_or_found_as_contacts(with_groups):
    store = with_groups
    with store.db.connect() as db:
        kinds = dict(db.execute("SELECT display_name, kind FROM contacts").fetchall())
        groups = [r[0] for r in db.execute("SELECT id FROM contacts WHERE kind = 'group'")]
    assert kinds["Book club"] == kinds["Sam fans"] == "group" and kinds["Example Library"] == "org"
    assert kinds["Ava Fictional"] == "individual" and len(groups) == 2
    names = [c["display_name"] for c in store.list()]
    assert "Book club" not in names and "Sam fans" not in names and "Example Library" in names
    assert len(names) == len(ALL) + 1
    assert store.counts("acc-1")["contacts"] == len(ALL) + 1
    assert store.address_books()[0]["count"] == len(ALL) + 1
    assert store.search("book club") == [] and store.search("fans") == []
    assert store.find_by_name("Book club") == []
    assert [f["name"] for f in store.find_by_name("Sam")] == ["Sam Sample", "Sam Sample"]  # not "Sam fans"
    assert all(store.get(g) is None and store.photo(g) is None for g in groups)


def test_find_contact_never_answers_with_a_group(with_groups):
    from mydata.tools.mirror import mirror_registry
    registry = mirror_registry(with_groups, None)
    assert registry.invoke("find_contact", {"name": "Book club"}, caller="test").result["matches"] == []
    found = registry.invoke("find_contact", {"name": "Example Library"}, caller="test").result["matches"]
    assert [m["name"] for m in found] == ["Example Library"]  # an organisation card is a contact


def test_a_card_that_becomes_a_group_leaves_the_list(store):
    zoe = by_name(store, "Zoë Exämple")
    regrouped = card("zoe-example-v4.vcf").replace("BEGIN:VCARD\n", "BEGIN:VCARD\nKIND:group\n", 1)
    store.apply("acc-1", BOOK, result([Item(href=zoe["href"], etag='"9"', data=regrouped)]))
    assert store.get(zoe["id"]) is None and "Zoë Exämple" not in [c["display_name"] for c in store.list()]


def test_database_file_is_private_and_versioned(tmp_path):
    path = tmp_path / "contacts.sqlite"
    ContactsStore(path)
    assert os.stat(path).st_mode & 0o777 == 0o600
    db = sqlite3.connect(path)
    assert db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0] == max(ContactsStore.MIGRATIONS)
    assert db.execute("PRAGMA journal_mode").fetchone()[0] == "wal"
    db.close()
    ContactsStore(path)  # reopening does not re-run migrations
    db = sqlite3.connect(path)
    assert db.execute("SELECT COUNT(*) FROM schema_version").fetchone()[0] == len(ContactsStore.MIGRATIONS)


def test_wrong_kind_rejected(tmp_path):
    cal = Collection(url="https://cal.example.com/home/", kind="calendar", display_name="Home")
    with pytest.raises(ValueError):
        ContactsStore(tmp_path / "c.sqlite").apply("acc-1", cal, result())


# ---------------------------------------------------------------- search


@pytest.mark.parametrize(
    "query, expected",
    [
        ("ava", "Ava Fictional"),
        ("AVA FICT", "Ava Fictional"),  # case, prefix on every word
        ("fic", "Ava Fictional"),
        ("avi", "Ava Fictional"),  # nickname
        ("widgets", "Ava Fictional"),  # organisation
        ("ava.club@example.org", "Ava Fictional"),  # whole email
        ("chess", None),  # labels are not searched
        ("5550100100", "Ava Fictional"),  # digits of a formatted number
        ("5550100", "Ava Fictional"),  # a tail of those digits
        ("0199", "Ava Fictional"),
        ("zoe", "Zoë Exämple"),  # diacritics folded both ways
        ("Zoë exa", "Zoë Exämple"),
        ("bakery", "Example Bakery Ltd"),
    ],
)
def test_search(store, query, expected):
    names = [c["display_name"] for c in store.search(query)]
    if expected is None:
        assert names == []
    else:
        assert expected in names


def test_search_never_passes_fts_syntax_through(store):
    for hostile in ['"', 'ava"', "ava OR zoe", "NEAR(ava zoe)", "ava*", "{full_name}: ava", "-ava", "ava AND",
                    "'); DROP TABLE contacts; --", "*", "^ava", ""]:
        store.search(hostile)  # must not raise
    assert [c["display_name"] for c in store.search("ava OR zoe")] == []  # OR is a word here, not an operator
    assert store.search("") == [] and store.search("   ") == []
    assert len(store.list()) == len(ALL)


def test_fts_query_quotes_every_word():
    assert fts_query('ava "x" OR') == '"ava"* AND "x"* AND "OR"*'
    assert fts_query("ava", ["given_name"]) == '{given_name} : ("ava"*)'
    assert fts_query("  -- ") is None


def test_find_by_name_matches_names_only(store):
    [ava] = store.find_by_name("ava")
    assert ava["name"] == "Ava Fictional"
    assert ava["emails"] == ["ava@example.com", "ava.home@example.net", "ava.club@example.org"]
    assert ava["phones"][0] == "+1 (555) 010-0100"
    assert set(ava) == {"id", "name", "emails", "phones"}
    assert store.find_by_name("Ava's") == [ava]
    assert store.find_by_name("Ava Fictional") == [ava]
    assert store.find_by_name("example.com") == []  # emails are not names
    assert store.find_by_name("widgets") == []  # nor organisations
    assert [c["name"] for c in store.find_by_name("zoe")] == ["Zoë Exämple"]


def test_list_paging(store):
    first = store.list(limit=3)
    rest = store.list(limit=100, offset=3)
    assert len(first) == 3 and len(rest) == len(ALL) - 3
    assert not {c["id"] for c in first} & {c["id"] for c in rest}
    assert store.address_books()[0]["count"] == len(ALL)
