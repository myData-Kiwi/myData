"""Writing owned contacts (sources/contacts_write.py, sources/contact_form.py): the owned address book, a new
card, an edit that keeps every untouched line byte for byte, If-Match, Recently deleted and its expiry with a
fake clock, undo (once, never over a later edit, across a restart), followed cards refused, and every write
atomic with its revision, change and undo rows. Invented data only (example.org, 555-01xx)."""

from __future__ import annotations

import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from mydata.sources import contact_form as cf
from mydata.sources import contacts_write as cw
from mydata.sources import owned
from mydata.sources.contacts_store import ContactsStore
from mydata.sources.vcard_edit import VCard, split_cards

import test_contacts_store as con

FIXTURES = Path(__file__).parent / "fixtures" / "vcard"
T0 = datetime(2026, 10, 14, 9, 30, tzinfo=timezone.utc)
AVA = {"given_name": "Ava", "family_name": "Fictional", "emails": [{"label": "work", "value": "ava@example.org"}],
       "phones": [{"label": "mobile", "value": "+1 555 0100"}]}


class Clock:
    def __init__(self, at: datetime = T0):
        self.at = at

    def __call__(self) -> datetime:
        return self.at


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def store(tmp_path, clock) -> ContactsStore:
    s = ContactsStore(tmp_path / "contacts.sqlite")
    s.clock = clock
    return s


def rows(store: ContactsStore, sql: str, *args) -> list[sqlite3.Row]:
    with store.db.connect() as db:
        return db.execute(sql, args).fetchall()


def etag(store: ContactsStore, contact_id: str) -> str:
    return store.get(contact_id, include_deleted=True)["http_etag"]


def imported(store: ContactsStore, text: str, href: str = "imported.vcf") -> str:
    """An owned card that did not come through the writer (as an import will write one): no revisions yet."""
    stamp = cw.stamp(T0 - timedelta(days=1))
    with store.db.transaction() as db:
        if not db.execute("SELECT 1 FROM address_books WHERE id = 'import-book'").fetchone():
            db.execute("INSERT INTO address_books (id, account_id, url, name, mode, created_at, modified_at) VALUES "
                       "('import-book', ?, 'owned://contacts/import', 'Imported', 'owned', ?, ?)",
                       (owned.OWNED_ACCOUNT, stamp, stamp))
        ContactsStore._upsert_card(db, owned.OWNED_ACCOUNT, "import-book", "owned://contacts/import", href, "", text,
                                   stamp)
        return db.execute("SELECT id FROM contacts WHERE href = ?", (href,)).fetchone()[0]


# ---------------------------------------------------------------- creating


def test_the_first_contact_creates_the_one_owned_address_book(store):
    first = cw.create(store, AVA, actor="mycontacts")
    second = cw.create(store, {"company": "Example Library"}, actor="mydata")
    assert first.book_created and not second.book_created
    books = rows(store, "SELECT * FROM address_books")
    assert [(b["name"], b["account_id"], b["mode"], b["url"]) for b in books] == [
        ("myData", "local", "owned", cw.BOOK_URL)]
    assert owned.has_owned(store.db.path, "address_books")
    ava = store.get(first.contact_id)
    assert ava["display_name"] == "Ava Fictional" and ava["source"] == "mydata" and ava["editable"]
    assert ava["emails"] == [{"value": "ava@example.org", "label": "work"}]
    assert ava["phones"] == [{"value": "+1 555 0100", "label": "mobile"}]
    assert store.get(second.contact_id)["display_name"] == "Example Library"


def test_a_new_card_is_vcard_3_with_a_uid_and_its_rows_are_written_together(store, clock):
    w = cw.create(store, AVA, actor="mycontacts")
    row = rows(store, "SELECT * FROM contacts WHERE id = ?", w.contact_id)[0]
    text = row["raw_vcard"]
    card = VCard.parse(text)
    assert card.version == "3.0" and card.first("UID").value and "\r\n" in text
    assert card.first("REV").value == "2026-10-14T09:30:00Z"
    assert row["rev"] == 1 and row["etag"] == row_etag(row) and row["href"] == card.first("UID").value + ".vcf"
    assert row["kind"] == "individual" and row["version"] == "3.0" and row["deleted_at"] is None
    revs = rows(store, "SELECT * FROM revisions WHERE object_id = ?", w.contact_id)
    assert [(r["rev"], r["op"], r["actor"], r["raw"]) for r in revs] == [(1, "create", "mycontacts", text)]
    changes = rows(store, "SELECT * FROM changes")
    assert [(c["object_id"], c["op"], c["href"]) for c in changes] == [(w.contact_id, "add", row["href"])]
    undo = rows(store, "SELECT * FROM undo_log WHERE id = ?", w.undo_id)[0]
    assert (undo["op"], undo["rev"], undo["actor"], undo["undone_at"]) == ("create", 1, "mycontacts", None)


def row_etag(row) -> str:
    return f'"{row["rev"]}-{row["raw_sha256"][:16]}"'


def test_every_field_is_written_and_read_back(store):
    form = {"name_prefix": "Dr.", "given_name": "Ava", "middle_name": "Q.", "family_name": "Fictional",
            "name_suffix": "PhD", "nickname": "AJ, Avi", "company": "Example Widgets", "department": "R&D",
            "job_title": "Inventor; of things", "birthday": "--02-29", "note": "Line one\nline two, with a comma.",
            "phones": [{"label": "Mobile", "value": "+1 555 0100"}, {"label": "Home fax", "value": "+1 555 0101"}],
            "emails": [{"label": "home", "value": "ava@example.org"},
                       {"label": "Book club", "value": "ava.books@example.org"}],
            "urls": [{"label": "homepage", "value": "https://ava.example.org/"}],
            "addresses": [{"label": "work", "street": "1 Example Street\nFloor 2", "locality": "Springfield",
                           "region": "", "postal_code": "0000", "country": "Exampleland"}]}
    w = cw.create(store, form, actor="mycontacts")
    text = store.get(w.contact_id)["raw_vcard"]
    assert "BDAY;X-APPLE-OMIT-YEAR=1604:1604-02-29" in text
    back = cf.read(VCard.parse(text))
    expected = {**form, "phones": [{"label": "mobile", "value": "+1 555 0100"},
                                   {"label": "homefax", "value": "+1 555 0101"}]}
    assert back == expected
    row = store.get(w.contact_id)
    assert row["display_name"] == "Dr. Ava Q. Fictional PhD" and row["birthday"] == "--02-29"
    assert row["nickname"] == "AJ, Avi" and row["note"] == "Line one\nline two, with a comma."


def test_a_birthday_with_and_without_a_year_in_3_and_4():
    for version, with_year, without in (("3.0", "1990-03-18", "BDAY;X-APPLE-OMIT-YEAR=1604:1604-03-18"),
                                        ("4.0", "19900318", "BDAY:--0318")):
        card = VCard.parse(f"BEGIN:VCARD\r\nVERSION:{version}\r\nFN:Ava\r\nEND:VCARD\r\n")
        cf.apply(card, {"birthday": "1990-03-18"})
        assert f"BDAY:{with_year}" in card.to_text(now=T0)
        cf.apply(card, {"birthday": "--03-18"})
        text = card.to_text(now=T0)
        assert without in text and text.count("BDAY") == 1
        assert cf.read(VCard.parse(text))["birthday"] == "--03-18"


@pytest.mark.parametrize("form, errors", [
    ({}, {"given_name": "Give a name, a company, an email or a phone number."}),
    ({"given_name": "Ava", "emails": [{"label": "", "value": "not-an-address"}]},
     {"emails[0].value": "Not an email address."}),
    ({"given_name": "Ava", "phones": [{"label": "", "value": "call me"}]}, {"phones[0].value": "Not a phone number."}),
    ({"given_name": "Ava\nFictional"}, {"given_name": "Cannot hold a line break."}),
    ({"given_name": "Ava", "birthday": "2026-02-30"},
     {"birthday": "Not a date: YYYY-MM-DD, or --MM-DD without a year."}),
    ({"given_name": "Ava", "urls": [{"label": "", "value": "https://example.org/a b"}]},
     {"urls[0].value": "A link cannot hold spaces."}),
    ({"given_name": "Ava", "phones": [{"label": "x" * 101, "value": "+1 555 0100"}]},
     {"phones[0].label": "Too long (at most 100 characters)."}),
])
def test_a_form_is_checked_field_by_field_without_echoing_values(store, form, errors):
    with pytest.raises(cf.FormError) as e:
        cw.create(store, form, actor="mycontacts")
    assert e.value.fields == errors
    assert "not-an-address" not in str(e.value) and "call me" not in str(e.value)
    assert rows(store, "SELECT COUNT(*) FROM contacts")[0][0] == 0


def test_empty_rows_of_a_form_are_left_out(store):
    w = cw.create(store, {**AVA, "emails": [{"label": "home", "value": "  "}, {"label": "", "value": "a@example.org"}],
                          "addresses": [{"label": "home"}]}, actor="mycontacts")
    assert cf.read(VCard.parse(store.get(w.contact_id)["raw_vcard"]))["emails"] == [
        {"label": "", "value": "a@example.org"}]


# ---------------------------------------------------------------- editing


def test_an_edit_keeps_every_untouched_line_byte_for_byte(store, clock):
    """The full form, as the app sends it back, with one phone changed: only that line and REV change."""
    original = (FIXTURES / "apple-3.0.vcf").read_text()
    contact_id = imported(store, original)
    form = cf.read(VCard.parse(original))
    form["phones"][1]["value"] = "+44 20 7946 0999"
    clock.at = T0 + timedelta(hours=1)
    w = cw.update(store, contact_id, form, if_match=etag(store, contact_id), actor="mycontacts")
    text = store.get(contact_id)["raw_vcard"]
    assert text == original.replace("TEL;type=HOME;type=VOICE:+44 20 7946 0000",
                                    "TEL;type=HOME;type=VOICE:+44 20 7946 0999").replace(
        "REV:2026-01-01T00:00:00Z", "REV:2026-10-14T10:30:00Z")
    assert w.undo_id is not None


def test_a_label_change_touches_only_the_label(store):
    original = (FIXTURES / "apple-3.0.vcf").read_text()
    contact_id = imported(store, original)
    form = cf.read(VCard.parse(original))
    form["phones"][0]["label"] = "Gym"  # item2's custom label
    form["emails"][0]["label"] = "home"  # item1: an Apple label line, so Apple's form
    cw.update(store, contact_id, {"phones": form["phones"], "emails": form["emails"]},
              if_match=etag(store, contact_id), actor="mycontacts")
    text = store.get(contact_id)["raw_vcard"]
    assert "item2.X-ABLabel:Gym\n" in text and "item1.X-ABLabel:_$!<Home>!$_\n" in text
    changed = set(text.splitlines()) ^ set(original.splitlines())
    assert {line.split(":")[0] for line in changed} == {"item2.X-ABLabel", "item1.X-ABLabel", "REV"}
    assert [p["label"] for p in store.get(contact_id)["phones"]][0] == "Gym"


def test_reading_and_writing_back_an_unchanged_form_changes_nothing():
    for path in [*FIXTURES.glob("*.vcf"), *(Path(__file__).parent / "fixtures" / "dav" / "contacts").glob("*.vcf")]:
        for card in split_cards(path.read_text()):
            if card.version == "2.1":
                continue
            cf.apply(card, cf.check(cf.read(card), creating=False))
            assert not card.changed, path.name


def test_an_edit_that_changes_nothing_writes_nothing(store):
    w = cw.create(store, AVA, actor="mycontacts")
    before = etag(store, w.contact_id)
    again = cw.update(store, w.contact_id, {"given_name": "Ava", "phones": AVA["phones"]}, if_match=before,
                      actor="mycontacts")
    assert again.undo_id is None and etag(store, w.contact_id) == before
    assert rows(store, "SELECT COUNT(*) FROM revisions")[0][0] == 1


def test_a_list_edit_keeps_the_values_it_does_not_change(store):
    w = cw.create(store, {**AVA, "phones": [{"label": "mobile", "value": "+1 555 0100"},
                                            {"label": "work", "value": "+1 555 0102"}]}, actor="mycontacts")
    before = store.get(w.contact_id)["raw_vcard"]
    cw.update(store, w.contact_id, {"phones": [{"label": "work", "value": "+1 555 0102"}]},
              if_match=etag(store, w.contact_id), actor="mycontacts")
    after = store.get(w.contact_id)["raw_vcard"]
    # the same second: REV is unchanged, so the only difference is the line removed
    assert set(before.splitlines()) - set(after.splitlines()) == {"TEL;TYPE=CELL:+1 555 0100"}
    assert set(after.splitlines()) <= set(before.splitlines()) and "TEL;TYPE=WORK:+1 555 0102\r\n" in after


def test_the_names_change_n_and_fn_and_nothing_else(store):
    w = cw.create(store, AVA, actor="mycontacts")
    cw.update(store, w.contact_id, {"family_name": "Example"}, if_match=etag(store, w.contact_id), actor="mycontacts")
    row = store.get(w.contact_id)
    assert row["display_name"] == "Ava Example" and "N:Example;Ava;;;\r\n" in row["raw_vcard"]
    assert row["emails"] == [{"value": "ava@example.org", "label": "work"}]


def test_if_match_must_be_the_current_etag(store):
    w = cw.create(store, AVA, actor="mycontacts")
    stale = etag(store, w.contact_id)
    cw.update(store, w.contact_id, {"nickname": "Avi"}, if_match=stale, actor="mycontacts")
    current = etag(store, w.contact_id)
    assert current != stale
    with pytest.raises(cw.PreconditionFailed) as e:
        cw.update(store, w.contact_id, {"nickname": "Lost update"}, if_match=stale, actor="mydata")
    assert e.value.etag == current
    with pytest.raises(cw.PreconditionFailed):
        cw.delete(store, w.contact_id, if_match=stale, actor="mydata")
    assert store.get(w.contact_id)["nickname"] == "Avi" and etag(store, w.contact_id) == current
    assert rows(store, "SELECT COUNT(*) FROM revisions")[0][0] == 2


def test_followed_cards_are_never_written(store):
    store.apply("acc-1", con.BOOK, con.result([con.item(n) for n in con.ALL], full=True))
    store.apply("mac", con.OTHER_BOOK, con.result([con.item("zoe-example-v4.vcf")], full=True))
    before = rows(store, "SELECT * FROM contacts ORDER BY id")
    for row in before:
        if row["kind"] == "group":
            continue
        tag = row_etag(row)
        with pytest.raises(cw.ReadOnly):
            cw.update(store, row["id"], {"given_name": "Changed"}, if_match=tag, actor="mycontacts")
        with pytest.raises(cw.ReadOnly):
            cw.delete(store, row["id"], actor="mycontacts")
        with pytest.raises(cw.ReadOnly):
            cw.restore(store, row["id"], actor="mycontacts")
    assert rows(store, "SELECT * FROM contacts ORDER BY id") == before
    assert rows(store, "SELECT COUNT(*) FROM revisions")[0][0] == 0
    assert not store.get(before[0]["id"], include_deleted=True)["editable"]


def test_group_cards_are_not_written_and_membership_by_uid_survives_an_edit(store):
    group = (FIXTURES / "apple-group-3.0.vcf").read_text()
    group_id = imported(store, group, "group.vcf")
    member_id = imported(store, (FIXTURES / "apple-3.0.vcf").read_text(), "member.vcf")
    with pytest.raises(cw.NotFound):
        cw.update(store, group_id, {"given_name": "x"}, if_match="x", actor="mycontacts")
    uid = store.get(member_id)["uid"]
    cw.update(store, member_id, {"family_name": "Renamed"}, if_match=etag(store, member_id), actor="mycontacts")
    assert store.get(member_id)["uid"] == uid
    assert rows(store, "SELECT raw_vcard FROM contacts WHERE id = ?", group_id)[0][0] == group


# ---------------------------------------------------------------- Recently deleted


def test_delete_goes_to_the_trash_for_30_days_and_restore_brings_it_back(store, clock):
    w = cw.create(store, AVA, actor="mycontacts")
    d = cw.delete(store, w.contact_id, actor="mycontacts")
    row = store.get(w.contact_id, include_deleted=True)
    assert row["deleted_at"] == "2026-10-14T09:30:00+00:00" and row["purge_after"] == "2026-11-13T09:30:00+00:00"
    assert store.get(w.contact_id) is None and store.list() == [] and store.find_by_name("Ava") == []
    assert [r["id"] for r in cw.trash(store)] == [w.contact_id]
    with pytest.raises(cw.InTrash):
        cw.update(store, w.contact_id, {"given_name": "x"}, if_match=row["http_etag"], actor="mycontacts")
    r = cw.restore(store, w.contact_id, actor="mydata")
    assert d.undo_id and r.undo_id and store.get(w.contact_id)["purge_after"] is None
    assert cw.trash(store) == [] and [c["id"] for c in store.find_by_name("Ava")] == [w.contact_id]
    assert [c["op"] for c in rows(store, "SELECT op FROM changes ORDER BY token")] == ["add", "delete", "add"]
    assert [r["op"] for r in rows(store, "SELECT op FROM revisions ORDER BY rev")] == ["create", "delete", "restore"]
    with pytest.raises(cw.NotFound):
        cw.restore(store, w.contact_id, actor="mydata")


def test_the_trash_expires_after_30_days_through_purge_permits(store, clock):
    keep = cw.create(store, {"given_name": "Kept"}, actor="mycontacts")
    gone = cw.create(store, AVA, actor="mycontacts")
    cw.delete(store, gone.contact_id, actor="mycontacts")
    assert cw.expire_trash(store, T0 + timedelta(days=30) - timedelta(seconds=1)) == 0
    assert cw.expire_trash(store, T0 + timedelta(days=30)) == 1
    assert store.get(gone.contact_id, include_deleted=True) is None and cw.trash(store) == []
    assert store.get(keep.contact_id) is not None
    assert rows(store, "SELECT COUNT(*) FROM revisions WHERE object_id = ?", gone.contact_id)[0][0] == 0
    assert rows(store, "SELECT COUNT(*) FROM purge_permits")[0][0] == 0
    assert rows(store, "SELECT COUNT(*) FROM address_books WHERE mode = 'owned'")[0][0] == 1
    data = store.db.path.read_bytes()
    assert b"ava@example.org" not in data and b"555 0100" not in data
    with pytest.raises(cw.UndoRefused, match="deleted for good"):
        cw.undo(store, gone.undo_id, actor="mycontacts")


def test_the_triggers_still_refuse_deleting_an_owned_contact_without_a_permit(store):
    w = cw.create(store, AVA, actor="mycontacts")
    cw.delete(store, w.contact_id, actor="mycontacts")
    with store.db.connect() as db, pytest.raises(sqlite3.IntegrityError, match="owned data is never"):
        db.execute("DELETE FROM contacts WHERE id = ?", (w.contact_id,))
    with store.db.connect() as db, pytest.raises(sqlite3.IntegrityError, match="owned data is never"):
        db.execute("DELETE FROM address_books WHERE mode = 'owned'")
    assert store.get(w.contact_id, include_deleted=True) is not None


# ---------------------------------------------------------------- undo


def test_undo_reverts_each_kind_of_action_as_a_new_revision(store, clock):
    created = cw.create(store, AVA, actor="mycontacts")
    first_text = store.get(created.contact_id)["raw_vcard"]
    clock.at = T0 + timedelta(minutes=1)
    edited = cw.update(store, created.contact_id, {"nickname": "Avi"}, if_match=etag(store, created.contact_id),
                       actor="mycontacts")
    cw.undo(store, edited.undo_id, actor="mycontacts")
    row = store.get(created.contact_id)
    assert row["raw_vcard"] == first_text and row["rev"] == 3 and row["nickname"] == ""
    deleted = cw.delete(store, created.contact_id, actor="mycontacts")
    cw.undo(store, deleted.undo_id, actor="mycontacts")
    assert store.get(created.contact_id)["deleted_at"] is None
    restored_from = cw.delete(store, created.contact_id, actor="mycontacts")
    restored = cw.restore(store, created.contact_id, actor="mycontacts")
    cw.undo(store, restored.undo_id, actor="mydata")
    assert store.get(created.contact_id) is None and restored_from.undo_id
    cw.restore(store, created.contact_id, actor="mycontacts")
    newest = cw.create(store, {"company": "Example Library"}, actor="mycontacts")
    cw.undo(store, newest.undo_id, actor="mycontacts")
    assert store.get(newest.contact_id) is None and [r["id"] for r in cw.trash(store)] == [newest.contact_id]
    ops = [(r["rev"], r["op"]) for r in rows(store, "SELECT rev, op FROM revisions WHERE object_id = ? ORDER BY rev",
                                             created.contact_id)]
    assert ops == [(1, "create"), (2, "update"), (3, "undo"), (4, "delete"), (5, "undo"), (6, "delete"),
                   (7, "restore"), (8, "undo"), (9, "restore")]


def test_nothing_is_undone_twice(store):
    w = cw.create(store, AVA, actor="mycontacts")
    e = cw.update(store, w.contact_id, {"nickname": "Avi"}, if_match=etag(store, w.contact_id), actor="mycontacts")
    cw.undo(store, e.undo_id, actor="mycontacts")
    with pytest.raises(cw.UndoRefused, match="already undone"):
        cw.undo(store, e.undo_id, actor="mycontacts")
    with pytest.raises(cw.NotFound):
        cw.undo(store, "no-such-undo", actor="mycontacts")
    entry = rows(store, "SELECT * FROM undo_log WHERE id = ?", e.undo_id)[0]
    assert entry["undone_by"] == "mycontacts" and entry["undone_rev"] == 3


def test_undo_never_overwrites_a_later_edit(store):
    w = cw.create(store, AVA, actor="mycontacts")
    first = cw.update(store, w.contact_id, {"nickname": "Avi"}, if_match=etag(store, w.contact_id), actor="mycontacts")
    cw.update(store, w.contact_id, {"job_title": "Inventor"}, if_match=etag(store, w.contact_id), actor="mydata")
    before = store.get(w.contact_id)
    with pytest.raises(cw.UndoRefused, match="changed since"):
        cw.undo(store, first.undo_id, actor="mycontacts")
    with pytest.raises(cw.UndoRefused, match="changed since"):
        cw.undo(store, w.undo_id, actor="mycontacts")  # the create: deleting it now would lose the edits
    assert store.get(w.contact_id) == before


def test_undo_works_across_a_restart(tmp_path, clock):
    path = tmp_path / "contacts.sqlite"
    first = ContactsStore(path)
    first.clock = clock
    w = cw.create(first, AVA, actor="mycontacts")
    e = cw.update(first, w.contact_id, {"nickname": "Avi"}, if_match=etag(first, w.contact_id), actor="mycontacts")
    del first
    again = ContactsStore(path)  # a new host process opening the same file
    cw.undo(again, e.undo_id, actor="mycontacts")
    assert again.get(w.contact_id)["nickname"] == ""
    third = ContactsStore(path)
    with pytest.raises(cw.UndoRefused, match="already undone"):
        cw.undo(third, e.undo_id, actor="mycontacts")


def test_undo_of_an_edit_to_a_card_written_before_revisions_finds_its_text(store):
    original = (FIXTURES / "google-3.0.vcf").read_text().split("END:VCARD\n")[0] + "END:VCARD\n"
    contact_id = imported(store, original)
    e = cw.update(store, contact_id, {"nickname": ""}, if_match=etag(store, contact_id), actor="mycontacts")
    cw.undo(store, e.undo_id, actor="mycontacts")
    assert store.get(contact_id)["raw_vcard"] == original
    assert [r["op"] for r in rows(store, "SELECT op FROM revisions WHERE object_id = ? ORDER BY rev", contact_id)] == [
        "baseline", "update", "undo"]


# ---------------------------------------------------------------- atomic


@pytest.mark.parametrize("failing", ["changes", "undo_log"])
def test_a_write_and_its_revision_change_and_undo_rows_commit_together(store, monkeypatch, failing):
    w = cw.create(store, AVA, actor="mycontacts")
    before = {t: rows(store, f"SELECT * FROM {t}") for t in ("contacts", "revisions", "changes", "undo_log")}
    real_execute = sqlite3.Connection.execute

    class Failing(sqlite3.Connection):
        def execute(self, sql, *args):
            if sql.startswith(f"INSERT INTO {failing}"):
                raise sqlite3.OperationalError("disk I/O error (invented)")
            return real_execute(self, sql, *args)

    real_connect = sqlite3.connect
    monkeypatch.setattr(sqlite3, "connect", lambda *a, **k: real_connect(*a, **k, factory=Failing))
    with pytest.raises(sqlite3.OperationalError, match="invented"):
        cw.update(store, w.contact_id, {"nickname": "Avi"}, if_match=etag(store, w.contact_id), actor="mycontacts")
    with pytest.raises(sqlite3.OperationalError, match="invented"):
        cw.delete(store, w.contact_id, actor="mycontacts")
    with pytest.raises(sqlite3.OperationalError, match="invented"):
        cw.create(store, {"given_name": "Pip"}, actor="mycontacts")
    monkeypatch.setattr(sqlite3, "connect", real_connect)
    assert {t: rows(store, f"SELECT * FROM {t}") for t in before} == before


def _written_around(store: ContactsStore, contact_id: str, text: str) -> None:
    """An owned card's text changed by a writer other than contacts_write (an import writing again through the
    store): the store moves rev on, but records no revision."""
    with store.db.connect() as db:
        row = db.execute("SELECT * FROM contacts WHERE id = ?", (contact_id,)).fetchone()
    with store.db.transaction() as db:
        ContactsStore._upsert_card(db, row["account_id"], row["address_book_id"], row["collection_url"], row["href"],
                                   "", text, cw.stamp(T0))


def test_undo_never_goes_back_past_a_change_written_around_the_writer(store):
    w = cw.create(store, AVA, actor="mycontacts")
    first = store.get(w.contact_id)["raw_vcard"]
    with_note = first.replace("END:VCARD", "NOTE:from the import\r\nEND:VCARD")
    _written_around(store, w.contact_id, with_note)
    assert store.get(w.contact_id)["rev"] == 2
    e = cw.update(store, w.contact_id, {"job_title": "Inventor"}, if_match=etag(store, w.contact_id),
                  actor="mycontacts")
    cw.undo(store, e.undo_id, actor="mycontacts")
    after = store.get(w.contact_id)
    assert after["raw_vcard"] == with_note and after["note"] == "from the import" and "TITLE" not in after["raw_vcard"]
    assert [(r["rev"], r["op"]) for r in rows(store, "SELECT rev, op FROM revisions WHERE object_id = ? ORDER BY rev",
                                              w.contact_id)] == [(1, "create"), (2, "baseline"), (3, "update"),
                                                                 (4, "undo")]


def test_undo_is_refused_when_the_text_it_would_go_back_to_was_not_recorded(store):
    """A revision missing between the text found and the edit (written around the writer, recorded by nothing):
    the undo refuses rather than going back too far."""
    w = cw.create(store, AVA, actor="mycontacts")
    e = cw.update(store, w.contact_id, {"job_title": "Inventor"}, if_match=etag(store, w.contact_id),
                  actor="mycontacts")
    with store.db.transaction() as db:  # as if rev 1 -> 2 had happened around the writer, unrecorded
        db.execute("UPDATE revisions SET rev = 3 WHERE object_id = ? AND rev = 2", (w.contact_id,))
        db.execute("UPDATE undo_log SET rev = 3, prior_rev = 2 WHERE id = ?", (e.undo_id,))
        db.execute("UPDATE contacts SET rev = 3 WHERE id = ?", (w.contact_id,))
    before = store.get(w.contact_id)["raw_vcard"]
    with pytest.raises(cw.UndoRefused, match="not kept"):
        cw.undo(store, e.undo_id, actor="mycontacts")
    assert store.get(w.contact_id)["raw_vcard"] == before


def test_a_deleted_and_restored_card_needs_no_new_baseline(store):
    w = cw.create(store, AVA, actor="mycontacts")
    cw.delete(store, w.contact_id, actor="mycontacts")
    cw.restore(store, w.contact_id, actor="mycontacts")
    e = cw.update(store, w.contact_id, {"nickname": "Avi"}, if_match=etag(store, w.contact_id), actor="mycontacts")
    cw.undo(store, e.undo_id, actor="mycontacts")
    assert store.get(w.contact_id)["nickname"] == ""
    assert "baseline" not in [r["op"] for r in rows(store, "SELECT op FROM revisions WHERE object_id = ?",
                                                     w.contact_id)]
