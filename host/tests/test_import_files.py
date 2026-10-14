"""Reading a contacts file for an import (sources/import_files.py): .vcf in 2.1, 3.0 and 4.0, zips read in memory
with their caps, malformed cards skipped one by one, and nothing ever written to disk. Invented data only."""

from __future__ import annotations

import base64
import os
import tracemalloc
import zipfile

import pytest

import import_corpus as corpus
from mydata.sources import import_files, importer
from mydata.sources.contacts_store import card_fields
from mydata.sources.import_files import ImportFileError, content_key, read_contacts


def test_an_apple_export_is_read_as_received():
    r = read_contacts(corpus.read(corpus.APPLE))
    assert [(c.kind, c.display_name, c.version, c.converted_from) for c in r.cards] == [
        ("individual", "Ava Fictional", "3.0", None), ("org", "Example Library", "3.0", None),
        ("individual", "Sam Sample", "3.0", None), ("group", "Book club", "3.0", None)]
    ava = r.cards[0]
    assert ava.text == ava.original and ava.text.startswith("BEGIN:VCARD\r\n") and ava.text.endswith("END:VCARD\r\n")
    assert "PHOTO;ENCODING=b;TYPE=JPEG:" in ava.text and "item2.X-ABLabel:Gym locker" in ava.text
    assert ava.source_uid == ava.uid == "3F1C0F0E-0000-4000-8000-0000000AE001"
    assert r.skipped == [] and r.notes == {}
    assert "".join(c.original for c in r.cards) == corpus.read(corpus.APPLE).decode()  # every byte accounted for


def test_samsung_21_is_converted_and_its_original_kept():
    r = read_contacts(corpus.read(corpus.SAMSUNG))
    zoe, pat = r.cards
    assert zoe.converted_from == "2.1" and zoe.version == "3.0" and "VERSION:2.1" in zoe.original
    assert "QUOTED-PRINTABLE" not in zoe.text and "Zoë" in zoe.text and zoe.display_name == "Zoë Émile"
    assert "Line two is a fairly long line" in zoe.text  # the soft break was joined
    assert zoe.uid == "" and zoe.source_uid.startswith("sha256:")  # no UID: keyed by its content
    assert pat.display_name == "Pat Placeholder" and pat.phones == ["+1-202-555-0106"]


def test_a_card_without_uid_has_the_same_key_when_exported_again():
    text = corpus.read(corpus.GOOGLE).decode().split("END:VCARD")[0] + "END:VCARD\r\n"
    again = text.replace("\r\n", "\n").replace("FN:Sam Sample", "FN:Sam Sample\nREV:2026-10-14T00:00:00Z")
    assert content_key(text) == content_key(again)
    assert content_key(text) != content_key(text.replace("sam@example.org", "sam2@example.org"))


def test_v4_group_cards_are_recognised():
    r = read_contacts(corpus.read(corpus.V4_GROUP))
    assert [(c.kind, c.version) for c in r.cards] == [("group", "4.0"), ("individual", "4.0")]
    assert "MEMBER:urn:uuid:00000000-0000-4000-8000-00000000c001" in r.cards[0].text


def test_malformed_cards_are_skipped_one_by_one_with_their_reasons():
    r = read_contacts(corpus.read(corpus.MALFORMED))
    assert [c.display_name for c in r.cards] == ["Robin Readable"]
    assert [(s.reason, s.index) for s in r.skipped] == [("no_end", 1), ("version", 2), ("empty", 3), ("no_end", 4),
                                                        ("empty", 5), ("no_end", 6)]
    assert r.notes == {"outside_text": 2}  # the first line, and the END:VCARD left over from the nested card


def test_a_card_naming_a_codec_that_is_no_character_set_is_skipped_alone():
    r = read_contacts(corpus.read(corpus.ODD_CHARSETS))
    # In a 2.1 card such a CHARSET is ignored (the value is read as UTF-8: "\\ud800" stays six characters); in a
    # 3.0 card the parser decodes it to a lone surrogate, which is no text: that card alone is unreadable.
    assert [c.display_name for c in r.cards] == ["Punycode Name", "Ava\\ud800", "Pat Placeholder"]
    assert [(s.reason, s.index) for s in r.skipped] == [("unreadable", 2)]
    for card in r.cards:
        card.text.encode("utf-8")


def test_a_value_line_that_starts_like_begin_or_end_never_cuts_a_card():
    folded = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nNOTE:Book club\r\n BEGIN:at nine\r\nEND:VCARD\r\n"
    soft = ("BEGIN:VCARD\r\nVERSION:2.1\r\nN:Sample;Sam\r\nNOTE;ENCODING=QUOTED-PRINTABLE:Book club=\r\n"
            "Begin: at nine=\r\nEnd: at ten\r\nEND:VCARD\r\n")
    r = read_contacts((folded + soft).encode())
    assert r.skipped == [] and [c.display_name for c in r.cards] == ["Ava Fictional", "Sam Sample"]
    assert r.cards[0].text == folded and "NOTE:Book clubBegin: at nineEnd: at ten\r\n" in r.cards[1].text


def test_a_soft_break_followed_by_spaces_is_still_a_soft_break():
    card = ("BEGIN:VCARD\r\nVERSION:2.1\r\nN:Placeholder;Pat\r\nNOTE;ENCODING=QUOTED-PRINTABLE:one= \t\r\ntwo\r\n"
            "END:VCARD\r\n")
    [pat] = read_contacts(card.encode()).cards
    assert "NOTE:onetwo\r\n" in pat.text


def test_text_outside_any_card_is_counted_as_a_loss():
    misspelt = "BEGIN: VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nEMAIL:ava@example.org\r\nEND:VCARD\r\n"
    r = read_contacts(("PRODID:-//Example//EN\r\n\r\n" + misspelt + corpus.read(corpus.GOOGLE).decode()).encode())
    assert len(r.cards) == 2 and r.notes == {"outside_text": 4}  # the misspelt card's lines, not VERSION or PRODID
    losses, changes = importer._report(r)
    assert [(x["code"], x["count"]) for x in losses] == [("outside_text", 4)] and changes == []


def test_a_zip_entry_with_no_card_is_a_loss_by_name():
    utf16_no_bom = corpus.read(corpus.GOOGLE).decode().encode("utf-16-le")
    data = corpus.zipped({"a.vcf": corpus.read(corpus.APPLE), "b.vcf": utf16_no_bom,
                          "c.vcf": corpus.read(corpus.GOOGLE).decode().encode("utf-16-be"),
                          "notes.vcf": b"just some text\r\n", "bad.vcf": b"\xff\xfe\x00\xd8"})
    r = read_contacts(data)
    assert [c.entry for c in r.cards].count("b.vcf") == 2 and [c.entry for c in r.cards].count("c.vcf") == 2
    assert r.unread_entries == ["notes.vcf", "bad.vcf"] and r.notes == {}
    losses, _changes = importer._report(r)
    assert [(x["code"], x["count"], x.get("entries")) for x in losses] == [
        ("unreadable_entry", 2, ["notes.vcf", "bad.vcf"])]


def test_a_zip_of_several_exports_is_read_in_memory():
    r = read_contacts(corpus.several())
    assert r.entries_read == 3 and r.other_files == 1
    assert {c.entry for c in r.cards} == {"Apple.vcf", "Google.vcf", "Samsung.VCF"}
    assert len(r.cards) == 4 + 2 + 2


def test_a_zip_with_names_that_leave_the_folder_is_read_and_nothing_is_written(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    before = set(os.listdir(tmp_path))
    r = read_contacts(corpus.traversal())
    assert {c.entry for c in r.cards} == {"evil.vcf", "escape.vcf", "style.vcf"}
    assert set(os.listdir(tmp_path)) == before and not os.path.exists("/tmp/evil.vcf")


def test_a_zip_bomb_is_refused_without_expanding_it():
    data = corpus.bomb()
    assert len(data) < 2 * 1024 * 1024
    with pytest.raises(ImportFileError, match="expands"):
        read_contacts(data)


@pytest.mark.parametrize("compression", [zipfile.ZIP_BZIP2, zipfile.ZIP_LZMA])
def test_bzip2_and_lzma_entries_are_never_expanded(compression):
    # bzip2 and LZMA expand a whole read at once, before the size cap could stop them: such entries are not read.
    data = corpus.bomb(64 * 1024 * 1024, compression=compression, beside={"plain.vcf": corpus.read(corpus.GOOGLE)})
    assert len(data) < 64 * 1024
    tracemalloc.start()
    try:
        r = read_contacts(data)
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()
    assert r.notes == {"unsupported_compression": 1} and len(r.cards) == 2
    assert peak < 8 * 1024 * 1024


def test_a_zip_expanding_past_the_total_cap_is_refused(monkeypatch):
    monkeypatch.setattr(import_files, "MAX_EXPANDED", 2000)
    monkeypatch.setattr(import_files, "MAX_RATIO", 10_000)
    with pytest.raises(ImportFileError, match="expands to more than"):
        read_contacts(corpus.several())


def test_a_zip_with_too_many_entries_is_refused(monkeypatch):
    monkeypatch.setattr(import_files, "MAX_ENTRIES", 2)
    with pytest.raises(ImportFileError, match="more than 2 files"):
        read_contacts(corpus.several())


def test_nested_and_encrypted_entries_are_reported_not_read():
    data = corpus.zipped({"inner.zip": corpus.zipped({"a.vcf": corpus.read(corpus.GOOGLE)}),
                          "plain.vcf": corpus.read(corpus.GOOGLE)})
    r = read_contacts(data)
    assert r.notes == {"nested_zip": 1} and len(r.cards) == 2
    raw = bytearray(corpus.zipped({"secret.vcf": corpus.read(corpus.GOOGLE), "plain.vcf": corpus.read(corpus.GOOGLE)},
                                  compression=zipfile.ZIP_STORED))
    # Mark the first entry encrypted (flag bit 0) in its local header and in the central directory.
    raw[6] |= 1
    central = raw.find(b"PK\x01\x02")
    raw[central + 8] |= 1
    r = read_contacts(bytes(raw))
    assert r.notes == {"encrypted": 1} and len(r.cards) == 2


def test_cards_far_larger_than_a_contact_are_skipped_without_parsing_them():
    head = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\n"
    huge_note = head + "NOTE:" + "x" * (20 * 1024 * 1024) + "\r\nEND:VCARD\r\n"
    many_lines = head + "EMAIL:ava@example.org\r\n" * (import_files.MAX_CARD_LINES + 1) + "END:VCARD\r\n"
    long_text = head + "NOTE:" + "x" * (import_files.MAX_CARD_TEXT + 1) + "\r\nEND:VCARD\r\n"
    data = (huge_note + many_lines + long_text + corpus.read(corpus.GOOGLE).decode()).encode()
    tracemalloc.start()
    try:
        r = read_contacts(data)
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()
    assert [(s.reason, s.index) for s in r.skipped] == [("too_large", 0), ("too_large", 1), ("too_large", 2)]
    assert len(r.cards) == 2
    assert peak < 4 * len(data)  # parsing it held well over a hundred times its size


def test_a_large_photo_is_read_without_parsing_it_in_full():
    photo = base64.b64encode(os.urandom(3 * 1024 * 1024)).decode()
    folded = "\r\n ".join(photo[i:i + 74] for i in range(0, len(photo), 74))
    card = ("BEGIN:VCARD\r\nVERSION:3.0\r\nUID:ava-1@example.org\r\nFN:Ava Fictional\r\nEMAIL:ava@example.org\r\n"
            f"PHOTO;ENCODING=b;TYPE=JPEG:{folded}\r\nNOTE:Met at the library\\, Tuesdays.\r\nEND:VCARD\r\n")
    tracemalloc.start()
    try:
        [read] = read_contacts(card.encode()).cards
        fields = card_fields(None, read.text)
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()
    assert read.text == card and read.emails == ["ava@example.org"] and read.uid == "ava-1@example.org"
    assert fields["has_photo"] == 1 and fields["note"] == "Met at the library, Tuesdays."
    assert fields["raw_vcard"] == card
    assert peak < 12 * len(card)


def test_cards_past_the_limit_are_counted_not_kept(monkeypatch):
    monkeypatch.setattr(import_files, "MAX_CARDS", 3)
    r = read_contacts(b"BEGIN:VCARD\n" * 100_000)
    assert len(r.skipped) == 3 and r.notes == {"too_many": 100_000 - 3}


def test_a_file_over_the_cap_is_refused(monkeypatch):
    monkeypatch.setattr(import_files, "MAX_INPUT", 10_000)
    with pytest.raises(ImportFileError, match="larger than"):
        read_contacts(corpus.over_cap(10_000))


def test_text_encodings():
    card = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Zoë Example\r\nEMAIL:zoe@example.org\r\nEND:VCARD\r\n"
    assert read_contacts(b"\xef\xbb\xbf" + card.encode()).cards[0].display_name == "Zoë Example"
    assert read_contacts(card.encode("utf-16")).cards[0].display_name == "Zoë Example"
    r = read_contacts(card.encode("cp1252"))
    assert r.cards[0].display_name == "Zoë Example" and r.notes == {"guessed_charset": 1}
    assert r.cards[0].raw == card.encode("cp1252")  # the bytes kept: the guess may be wrong


def test_each_card_is_decoded_on_its_own():
    utf8 = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Zoë Fictional\r\nEND:VCARD\r\n".encode()
    latin = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:René Sample\r\nEND:VCARD\r\n".encode("latin-1")
    sjis = "BEGIN:VCARD\r\nVERSION:2.1\r\nN;CHARSET=SHIFT_JIS:架空;花子\r\nFN;CHARSET=SHIFT_JIS:架空\r\nEND:VCARD\r\n"
    undefined = b"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Pat \x81 Placeholder\r\nEND:VCARD\r\n"  # not in cp1252
    r = read_contacts(utf8 + latin + sjis.encode("shift_jis") + undefined)
    assert [c.display_name for c in r.cards] == ["Zoë Fictional", "René Sample", "架空", "Pat \x81 Placeholder"]
    assert "FN:架空\r\n" in r.cards[2].text and "CHARSET" not in r.cards[2].text
    assert r.notes == {"guessed_charset": 2, "declared_charset": 1}
    assert [c.raw is not None for c in r.cards] == [False, True, False, True]
    losses, changes = importer._report(r)
    assert [x["code"] for x in losses] == ["guessed_charset"] and [x["code"] for x in changes] == ["converted_21",
                                                                                                   "declared_charset"]


def test_inputs_that_are_not_contacts_are_refused():
    for data in (b"", b"just some text\n", corpus.zipped({"notes.txt": b"hello"}), b"PK\x03\x04broken"):
        with pytest.raises(ImportFileError):
            read_contacts(data)
