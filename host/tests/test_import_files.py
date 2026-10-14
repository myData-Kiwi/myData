"""Reading a contacts file for an import (sources/import_files.py): .vcf in 2.1, 3.0 and 4.0, zips read in memory
with their caps, malformed cards skipped one by one, and nothing ever written to disk. Invented data only."""

from __future__ import annotations

import os
import tracemalloc
import zipfile

import pytest

import import_corpus as corpus
from mydata.sources import import_files
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
    assert r.notes == {"outside_text": 1}


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


def test_a_file_over_the_cap_is_refused(monkeypatch):
    monkeypatch.setattr(import_files, "MAX_INPUT", 10_000)
    with pytest.raises(ImportFileError, match="larger than"):
        read_contacts(corpus.over_cap(10_000))


def test_text_encodings():
    card = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Zoë Example\r\nEMAIL:zoe@example.org\r\nEND:VCARD\r\n"
    assert read_contacts(b"\xef\xbb\xbf" + card.encode()).cards[0].display_name == "Zoë Example"
    assert read_contacts(card.encode("utf-16")).cards[0].display_name == "Zoë Example"
    r = read_contacts(card.encode("cp1252"))
    assert r.cards[0].display_name == "Zoë Example" and r.notes == {"windows_1252": 1}


def test_inputs_that_are_not_contacts_are_refused():
    for data in (b"", b"just some text\n", corpus.zipped({"notes.txt": b"hello"}), b"PK\x03\x04broken"):
        with pytest.raises(ImportFileError):
            read_contacts(data)
