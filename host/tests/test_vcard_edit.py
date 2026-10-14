"""The content-line vCard editor (sources/vcard_edit.py): untouched lines come back byte for byte, edits read back
as written, Apple item groups, 2.1 and 4.0 cards. Synthetic corpora only (tests/fixtures/vcard)."""

from __future__ import annotations

import base64
import re
from datetime import datetime, timezone
from pathlib import Path

import pytest
import vobject
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from mydata.sources.vcard import card_kind, parse_vcard, photo
from mydata.sources.vcard_edit import (Raw, VCard, VCardError, convert, escape_text, fold, new_card, photo_bytes,
                                       split_cards, unescape_text, upgrade_21)

FIXTURES = Path(__file__).parent / "fixtures" / "vcard"
NOW = datetime(2026, 10, 13, 9, 30, tzinfo=timezone.utc)
REV30 = "REV:2026-10-13T09:30:00Z"


def fixture(name: str, newline: str = "\n") -> str:
    return (FIXTURES / name).read_text(encoding="utf-8").replace("\n", newline)


def physical(text: str) -> list[str]:
    return re.findall(r"[^\r\n]*(?:\r\n|\n|\r)", text)


def logical(text: str) -> list[str]:
    """Each content line with its folded continuations, as text with endings."""
    out: list[str] = []
    for line in physical(text):
        if out and line[:1] in (" ", "\t"):
            out[-1] += line
        else:
            out.append(line)
    return out


ALL = sorted(p.name for p in FIXTURES.glob("*.vcf"))


# ---------------------------------------------------------------- nothing changed, nothing moves

@pytest.mark.parametrize("newline", ["\n", "\r\n"])
@pytest.mark.parametrize("name", ALL)
def test_an_unedited_card_is_written_back_exactly(name, newline):
    text = fixture(name, newline)
    cards = split_cards(text)
    assert "".join(c.to_text() for c in cards) == text
    for card in cards:
        assert card.newline == newline and not card.changed


def test_the_corpus_is_what_the_tests_think_it_is():
    versions = {name: [c.version for c in split_cards(fixture(name))] for name in ALL}
    assert versions == {"apple-3.0.vcf": ["3.0"], "apple-group-3.0.vcf": ["3.0"], "google-3.0.vcf": ["3.0", "3.0"],
                        "samsung-2.1.vcf": ["2.1", "2.1"], "v4-group.vcf": ["4.0", "4.0"]}


# ---------------------------------------------------------------- golden edits

@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_changing_fn_changes_only_fn_and_rev(newline):
    text = fixture("apple-3.0.vcf", newline)
    card = VCard.parse(text)
    card.set("FN", "Ava Fictional-Example, PhD")
    out = card.to_text(now=NOW)
    expected = (text.replace(r"FN:Dr. Ava Q. Fictional\, PhD" + newline,
                             r"FN:Ava Fictional-Example\, PhD" + newline)
                .replace("REV:2026-01-01T00:00:00Z", REV30))
    assert out == expected
    assert parse_vcard(out).full_name == "Ava Fictional-Example, PhD"


def test_untouched_lines_keep_their_folding_case_and_order():
    text = fixture("apple-3.0.vcf", "\r\n")
    card = VCard.parse(text)
    card.set("NOTE", "New note, with; punctuation\nand a second line")
    card.add("EMAIL", "ava.club@example.org", [("type", ["INTERNET"])], label="Chess club")
    out = card.to_text(now=NOW)
    before, after = logical(text), logical(out)
    kept = [line for line in before if not line.startswith(("NOTE:", "REV:"))]
    assert [line for line in after if line in kept] == kept  # every other line, in order, byte for byte
    assert "PHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRgABAQAAAQABAAAAAQIDBAUGBwgJCgsMDQ4P\r\n EBESExQ" in out
    assert parse_vcard(out).note == "New note, with; punctuation\nand a second line"


def test_a_labelled_value_takes_the_next_item_number_and_reads_back_with_its_label():
    card = VCard.parse(fixture("apple-3.0.vcf"))
    assert card.next_item() == "item7"
    email = card.add("EMAIL", "ava.club@example.org", [("type", ["INTERNET"])], label="Chess club")
    assert email.group == "item7" and card.label(email) == "Chess club"
    out = card.to_text(now=NOW)
    assert "item7.EMAIL;type=INTERNET:ava.club@example.org\nitem7.X-ABLabel:Chess club\n" in out
    parsed = parse_vcard(out)
    assert {"value": "ava.club@example.org", "label": "chess club"} in [
        {"value": e["value"], "label": e["label"].lower()} for e in parsed.emails]
    # a gap in the numbers is never filled: the next is above the highest
    card2 = VCard.parse(fixture("apple-3.0.vcf").replace("item6.", "item40."))
    assert card2.next_item() == "item41"


def test_removing_a_grouped_value_removes_its_label_and_apple_country():
    text = fixture("apple-3.0.vcf")
    card = VCard.parse(text)
    [work] = [p for p in card.props("EMAIL") if p.group == "item1"]
    card.remove(work)
    card.remove(card.first("ADR"))
    out = card.to_text(now=NOW)
    for gone in ("item1.EMAIL", "item1.X-ABLabel", "item4.ADR", "item4.X-ABADR"):
        assert gone not in out
    assert "item2.X-ABLabel:custom label\n" in out
    assert [line for line in logical(out) if not line.startswith("REV:")] == [
        line for line in logical(text) if not line.startswith(("item1.", "item4.", "REV:"))]


def test_set_label_moves_an_ungrouped_value_into_a_group_and_relabels():
    card = VCard.parse(fixture("apple-3.0.vcf"))
    [home] = [p for p in card.props("EMAIL") if not p.group]
    card.set_label(home, "Old address")
    assert home.group == "item7" and card.label(home) == "Old address"
    work = card.props("EMAIL")[0]
    card.set_label(work, "Office")
    card.set_label(card.props("TEL")[0], None)
    out = card.to_text(now=NOW)
    assert "item7.EMAIL;type=INTERNET;type=HOME:ava.home@example.net\nitem7.X-ABLabel:Old address\n" in out
    assert "item1.X-ABLabel:Office\n" in out and "item2.X-ABLabel" not in out


def test_compound_and_list_values_are_escaped_per_part():
    card = VCard.parse(fixture("google-3.0.vcf").split("END:VCARD\n")[0] + "END:VCARD\n")
    card.set("N", ["Sample; Jr", "Sam, the", "", "", ""])
    card.add("ADR", ["", "", "5 Comma, Street", "Semi;colon", "", "0000", "Exampleland"], [("TYPE", ["WORK"])])
    card.set("NICKNAME", ["Sammy", "S, S"])
    card.set("ORG", ["Example Holdings", "Unit; Two"])
    out = card.to_text(now=NOW)
    v = vobject.readOne(out)
    assert (v.n.value.family, v.n.value.given) == ("Sample; Jr", "Sam, the")
    work = [a for a in v.contents["adr"] if "WORK" in a.params.get("TYPE", [])][0]
    assert (work.value.street, work.value.city) == ("5 Comma, Street", "Semi;colon")
    assert parse_vcard(out).nickname == "Sammy, S, S"
    org = VCard.parse(out).first("ORG")
    assert org.parts() == ["Example Holdings", "Unit; Two"]
    with pytest.raises(VCardError, match="compound"):
        card.set("N", "just text")
    with pytest.raises(VCardError, match="line break"):
        card.set("EMAIL", "a@example.org\nBCC:b@example.org")


def test_a_new_photo_is_folded_and_reads_back_the_same_bytes():
    data = b"\xff\xd8\xff\xe0" + bytes(range(256)) * 3
    card = VCard.parse(fixture("google-3.0.vcf").split("END:VCARD\n")[1] + "END:VCARD\n")
    prop = card.set_photo(data, "image/jpeg")
    out = card.to_text(now=NOW)
    assert all(len(line.encode()) <= 75 for line in out.split("\n"))
    assert photo(out) == (data, "image/jpeg") and photo_bytes(VCard.parse(out).first("PHOTO")) == data
    assert prop.params == [("ENCODING", ["b"]), ("TYPE", ["JPEG"])]
    # replacing keeps one photo, where the first one was
    google = VCard.parse(fixture("google-3.0.vcf").split("END:VCARD\n")[0] + "END:VCARD\n")
    index = google.items.index(google.first("PHOTO"))
    google.set_photo(data, "image/jpeg")
    assert len(google.props("PHOTO")) == 1 and google.items.index(google.first("PHOTO")) == index
    google.remove("PHOTO")
    assert "PHOTO" not in google.to_text(now=NOW)


def test_new_cards_are_3_0_with_a_uid_and_a_rev():
    card = new_card("Kai Invented", given="Kai", family="Invented")
    card.add("TEL", "+1 202 555 0108", [("type", ["CELL"])])
    out = card.to_text(now=NOW)
    lines = out.split("\r\n")
    assert lines[:3] == ["BEGIN:VCARD", "VERSION:3.0", "PRODID:-//myData//vCard editor//EN"]
    assert lines[-2:] == ["END:VCARD", ""] and REV30 in lines
    uid = VCard.parse(out).first("UID").value
    assert re.fullmatch(r"[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}", uid)
    parsed = parse_vcard(out)
    assert (parsed.full_name, parsed.given_name, parsed.family_name, parsed.uid) == (
        "Kai Invented", "Kai", "Invented", uid)
    assert new_card("A").first("UID").value != new_card("A").first("UID").value
    assert new_card("A", uid="fixed-uid@example.org").first("UID").value == "fixed-uid@example.org"


def test_rev_is_added_when_missing_and_not_touched_without_a_change():
    text = fixture("google-3.0.vcf").split("END:VCARD\n")[1] + "END:VCARD\n"
    card = VCard.parse(text)
    assert card.to_text(now=NOW) == text  # read-only use never bumps REV
    card.set("TITLE", "Invented")
    out = card.to_text(now=NOW)
    assert out.endswith(f"TITLE:Invented\n{REV30}\nEND:VCARD\n")
    card2 = VCard.parse(text)
    card2.set("TEL", "+1 202 555 0103")  # the same value: no change
    assert not card2.changed and card2.to_text(now=NOW) == text


def test_lines_the_editor_cannot_read_are_kept():
    text = ("BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Odd Card\r\nTHIS LINE HAS NO COLON\r\n"
            "X-EMBEDDED;X-NOTE=\"a:b;c\":value with : colon\r\nEND:VCARD\r\n")
    card = VCard.parse(text)
    assert card.first("X-EMBEDDED").param("X-NOTE") == ["a:b;c"]
    card.set("FN", "Odd Card Two")
    out = card.to_text(now=NOW)
    assert "THIS LINE HAS NO COLON\r\n" in out and 'X-EMBEDDED;X-NOTE="a:b;c":value with : colon\r\n' in out


def test_a_byte_order_mark_is_kept_and_not_read_as_text():
    text = "\ufeff" + fixture("apple-group-3.0.vcf", "\r\n")
    card = VCard.parse(text)
    assert card.to_text() == text and card.first("FN").text() == "Book club"
    card.set("FN", "Book group")
    assert card.to_text(now=NOW).startswith("\ufeffBEGIN:VCARD\r\n")


@pytest.mark.parametrize("text, message", [
    ("FN:loose\r\n", "outside a vCard"),
    ("BEGIN:VCARD\r\nVERSION:3.0\r\nFN:A\r\n", "without END:VCARD"),
    ("", "no vCard"),
    (fixture("google-3.0.vcf"), "expected one vCard, found 2"),
])
def test_what_is_not_one_card_is_refused(text, message):
    with pytest.raises(VCardError, match=message):
        VCard.parse(text)


# ---------------------------------------------------------------- vCard 2.1 (Samsung)

def test_2_1_quoted_printable_soft_breaks_are_joined_and_decoded():
    zoe, pat = split_cards(fixture("samsung-2.1.vcf", "\r\n"))
    assert zoe.first("FN").text() == "Zoë Émile"
    assert zoe.first("N").parts()[:2] == ["Émile", "Zoë"]
    assert zoe.first("NOTE").text() == ("Line one\r\nLine two is a fairly long line of notes that will need a soft "
                                        "break in the quoted printable text, with a comma")
    assert zoe.first("X-ANDROID-CUSTOM").decoded().startswith("vnd.android.cursor.item/nickname;Zoëy;1;")
    assert zoe.first("TEL").types == ["cell", "pref"]
    assert photo_bytes(zoe.first("PHOTO"))[:3] == b"\xff\xd8\xff"
    assert pat.first("ORG").parts() == ["Example Holdings", "Invented, Unit"]


def test_a_2_1_card_is_never_edited_in_place():
    card = split_cards(fixture("samsung-2.1.vcf"))[1]
    card.set("FN", "Pat Placeholder-Two")
    with pytest.raises(VCardError, match="upgrade_21"):
        card.to_text(now=NOW)


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_upgrading_2_1_to_3_0_keeps_every_value(newline):
    zoe_21, pat_21 = (c.to_text() for c in split_cards(fixture("samsung-2.1.vcf", newline)))
    zoe = upgrade_21(zoe_21)
    assert VCard.parse(zoe).version == "3.0" and "QUOTED-PRINTABLE" not in zoe and "CHARSET" not in zoe
    v = vobject.readOne(zoe)
    assert v.fn.value == "Zoë Émile" and (v.n.value.family, v.n.value.given) == ("Émile", "Zoë")
    assert v.adr.value.street == "12 Invented Lane, Unit 4" and v.adr.value.city == "Ōtautahi"
    parsed = parse_vcard(zoe)
    assert parsed.note == ("Line one\nLine two is a fairly long line of notes that will need a soft break in the "
                           "quoted printable text, with a comma")
    assert [(p["value"], p["label"]) for p in parsed.phones] == [("+12025550104", "mobile"), ("+12025550105", "home")]
    assert parsed.emails == [{"value": "zoe@example.org", "label": "home"}] and parsed.birthday == "1991-07-02"
    assert photo(zoe)[1] == "image/jpeg"
    assert photo(zoe)[0] == photo_bytes(split_cards(zoe_21)[0].first("PHOTO"))
    # lines 2.1 and 3.0 write the same way are copied as they came
    assert "BDAY:1991-07-02" + newline in zoe
    assert all(len(line.encode()) <= 75 for line in zoe.split(newline))
    pat = upgrade_21(pat_21)
    assert "ORG:Example Holdings;Invented\\, Unit" + newline in pat and "TEL;TYPE=WORK,VOICE:+1-202-555-0106" in pat
    with pytest.raises(VCardError, match="not a vCard 2.1"):
        upgrade_21(zoe)


def test_upgrading_adds_fn_and_n_when_missing():
    out = upgrade_21("BEGIN:VCARD\r\nVERSION:2.1\r\nN:Invented;Kai;;;\r\nEND:VCARD\r\n")
    assert parse_vcard(out).full_name == "Kai Invented"
    out = upgrade_21("BEGIN:VCARD\r\nVERSION:2.1\r\nFN:Kai\r\nEND:VCARD\r\n")
    assert "N:;;;;\r\n" in out


# ---------------------------------------------------------------- vCard 4.0 and conversion

def test_a_4_0_group_keeps_kind_and_members_when_edited():
    text = split_cards(fixture("v4-group.vcf", "\r\n"))[0].to_text()
    card = VCard.parse(text)
    card.set("FN", "Weekend walkers")
    out = card.to_text(now=NOW)
    assert out == text.replace("FN:Weekend hikers", "FN:Weekend walkers").replace(
        "REV:20260301T120000Z", "REV:20261013T093000Z")
    assert card_kind(out) == "group"


def test_converting_4_0_to_3_0_and_back_keeps_kind_members_photo_and_birthday():
    group_40, riley_40 = (c.to_text() for c in split_cards(fixture("v4-group.vcf", "\r\n")))
    group_30 = convert(group_40, "3.0")
    assert card_kind(group_30) == "group" and group_30.count("X-ADDRESSBOOKSERVER-MEMBER:urn:uuid:") == 2
    assert "N:Weekend hikers;;;;\r\n" in group_30  # 3.0 needs N
    riley_30 = convert(riley_40, "3.0")
    v = vobject.readOne(riley_30)
    assert v.version.value == "3.0" and "KIND" not in riley_30
    assert photo(riley_30) == photo(riley_40)
    assert "BDAY;X-APPLE-OMIT-YEAR=1604:1604-04-15\r\n" in riley_30 and parse_vcard(riley_30).birthday == "--04-15"
    assert "EMAIL;TYPE=work;TYPE=pref:riley@example.org" in riley_30 and "TEL;TYPE=\"voice,cell\":+1-202-555-0107" in riley_30
    assert "GENDER:N\r\n" in riley_30  # unknown to 3.0, kept
    back = convert(riley_30, "4.0")
    assert "BDAY:--0415\r\n" in back and "EMAIL;TYPE=work;PREF=1:riley@example.org" in back
    assert photo(back) == photo(riley_40)
    assert card_kind(convert(group_30, "4.0")) == "group" and "MEMBER:urn:uuid:" in convert(group_30, "4.0")
    assert convert(riley_40, "4.0") == riley_40  # already that version: unchanged


def test_converting_apple_3_0_to_4_0_puts_version_first_and_maps_apple_fields():
    apple = fixture("apple-3.0.vcf", "\r\n")
    out = convert(apple, "4.0")
    lines = out.split("\r\n")
    assert lines[:2] == ["BEGIN:VCARD", "VERSION:4.0"]
    assert "BDAY:--0318" in lines and "item1.EMAIL;type=INTERNET;PREF=1:ava@example.com" in lines
    assert photo(out) == photo(apple)
    # lines both versions write the same way are untouched
    assert "NOTE:Met at the invented conference\\, row two.\\nBrings biscuits\\; always.\r\n" in out
    group = convert(fixture("apple-group-3.0.vcf"), "4.0")
    assert "KIND:group\n" in group and group.count("MEMBER:urn:uuid:") == 2 and card_kind(group) == "group"
    assert convert(fixture("samsung-2.1.vcf").split("END:VCARD\n")[1] + "END:VCARD\n", "4.0").startswith(
        "BEGIN:VCARD\nVERSION:4.0\n")
    with pytest.raises(VCardError):
        convert(apple, "2.1")


# ---------------------------------------------------------------- property tests

_SAFE_TEXT = st.text(st.characters(blacklist_categories=("Cs", "Cc"), blacklist_characters="  \x85")
                     | st.sampled_from(["\n", ",", ";", "\\", ":", '"', " "]), max_size=120)
_NAMES = st.sampled_from(["FN", "NOTE", "TITLE", "EMAIL", "TEL", "X-CUSTOM", "NICKNAME", "URL", "X-ABLabel"])
_GROUPS = st.sampled_from(["", "item1", "item2", "ITEM7", "g"])
_PARAM = st.tuples(st.sampled_from(["type", "TYPE", "X-P", "VALUE"]),
                   st.lists(st.text("abcXYZ09-,:; ", min_size=1, max_size=8), min_size=1, max_size=3))


@st.composite
def content_line(draw):
    name = draw(_NAMES)
    group = draw(_GROUPS)
    params = draw(st.lists(_PARAM, max_size=3))
    value = escape_text(draw(_SAFE_TEXT)) if name not in ("EMAIL", "TEL", "URL") else draw(
        st.text("abcdefghij@.+-0123456789 :/", max_size=40))
    head = f"{group}.{name}" if group else name
    for n, values in params:
        head += ";" + n + "=" + ",".join(f'"{v}"' if any(c in v for c in ':;,') else v for v in values)
    return head + ":" + value


@st.composite
def card_text(draw):
    """A card made of random content lines, folded at random places (or not), with one kind of line ending."""
    newline = draw(st.sampled_from(["\r\n", "\n"]))
    lines = ["BEGIN:VCARD", "VERSION:3.0", *draw(st.lists(content_line(), max_size=12)), "END:VCARD"]
    out = []
    for line in lines:
        width = draw(st.sampled_from([0, 10, 40, 75]))
        if width and len(line) > width and not line.startswith(("BEGIN", "END")):
            parts = [line[:width]] + [" " + line[i:i + width] for i in range(width, len(line), width)]
        else:
            parts = [line]
        out.append(newline.join(parts))
    return newline.join(out) + newline


@settings(max_examples=300, suppress_health_check=[HealthCheck.too_slow])
@given(card_text())
def test_any_card_reads_and_writes_back_unchanged(text):
    card = VCard.parse(text)
    assert card.to_text() == text


@settings(max_examples=200, suppress_health_check=[HealthCheck.too_slow])
@given(card_text(), _SAFE_TEXT, st.data())
def test_an_edit_leaves_every_other_line_as_it_was(text, new, data):
    card = VCard.parse(text)
    before = [(p.key, p.raw) for p in card.props()]
    editable = [i for i, (key, _raw) in enumerate(before) if key not in ("VERSION", "REV")]
    if editable:
        target = data.draw(st.sampled_from(editable))
        prop = card.props()[target]
        card.update(prop, new if prop.key not in ("EMAIL", "TEL", "URL") else "x@example.org")
    else:
        target = None
        card.add("NOTE", new)
    out = card.to_text(now=NOW)
    after = VCard.parse(out).props()
    # positions are kept: every other line is at its index, byte for byte (REV may change, or be added at the end)
    for i, (key, raw) in enumerate(before):
        if i != target and key != "REV":
            assert after[i].raw == raw
    assert out.startswith("BEGIN:VCARD") and out.endswith("END:VCARD" + card.newline)


@settings(max_examples=300)
@given(_SAFE_TEXT.filter(lambda t: t.strip()), _SAFE_TEXT.filter(lambda t: t.strip()))
def test_text_values_read_back_exactly(fn, note):
    card = VCard.parse(fixture("apple-3.0.vcf", "\r\n"))
    card.set("FN", fn)
    card.set("NOTE", note)
    out = card.to_text(now=NOW)
    again = VCard.parse(out)
    assert again.first("FN").text() == fn and again.first("NOTE").text() == note
    parsed = parse_vcard(out)  # the store's own reader, written separately
    assert parsed.full_name == fn.strip() and parsed.note == note.strip()
    written = [line for line in logical(out) if line.startswith(("FN:", "NOTE:"))]
    assert all(len(part.encode()) <= 75 for line in written for part in line.split("\r\n"))


@settings(max_examples=200)
@given(st.lists(_SAFE_TEXT, min_size=5, max_size=5))
def test_compound_values_read_back_exactly(parts):
    card = VCard.parse(fixture("apple-3.0.vcf"))
    card.set("N", parts)
    out = card.to_text(now=NOW)
    assert VCard.parse(out).first("N").parts() == [p.replace("\r\n", "\n").replace("\r", "\n") for p in parts]


@given(_SAFE_TEXT)
def test_escape_and_unescape_are_inverse(text):
    assert unescape_text(escape_text(text)) == text.replace("\r\n", "\n").replace("\r", "\n")


@given(st.text(max_size=300))
def test_fold_never_splits_a_character_or_exceeds_75_octets(text):
    text = re.sub(r"[\r\n]", "", text)
    folded = fold("X-TEST:" + text)
    assert folded.endswith("\r\n")
    lines = folded[:-2].split("\r\n")
    assert all(len(line.encode()) <= 75 for line in lines)
    assert lines[0] + "".join(line[1:] for line in lines[1:]) == "X-TEST:" + text


def test_raw_values_are_written_as_given():
    card = VCard.parse(fixture("apple-group-3.0.vcf"))
    card.add("X-ADDRESSBOOKSERVER-MEMBER", Raw("urn:uuid:3F1C0F0E-0000-4000-8000-00000000B003"))
    assert "X-ADDRESSBOOKSERVER-MEMBER:urn:uuid:3F1C0F0E-0000-4000-8000-00000000B003\n" in card.to_text(now=NOW)
    assert base64.b64decode(Raw("AAAA")) == b"\x00\x00\x00"


# ---------------------------------------------------------------- what an edit may write

@pytest.mark.parametrize("params, message", [
    ([("TYPE", ["cell\r\nEMAIL:evil@example.invalid"])], "control character"),
    ([("TYPE", ["cell\x00"])], "control character"),
    ([("TY PE", ["cell"])], "parameter name"),
    ([("TYPE:X", ["cell"])], "parameter name"),
    ([(None, ["CELL;X"])], "without a name"),
])
def test_a_parameter_that_would_break_the_line_is_refused(params, message):
    card = VCard.parse(fixture("apple-3.0.vcf"))
    with pytest.raises(VCardError, match=message):
        card.add("TEL", "555-0102", params)
    with pytest.raises(VCardError, match=message):
        card.update(card.first("FN"), "Someone", params)
    assert not card.changed


@pytest.mark.parametrize("name, group", [("TEL\r\nEMAIL", ""), ("X:Y", ""), ("TEL", "item1.x"), ("TEL", "a b")])
def test_a_name_or_group_that_would_break_the_line_is_refused(name, group):
    card = VCard.parse(fixture("apple-3.0.vcf"))
    with pytest.raises(VCardError):
        card.add(name, "555-0102", group=group)
    if name != "TEL":
        with pytest.raises(VCardError):
            card.update(card.first("FN"), name=name)


def test_quotes_carets_and_line_breaks_in_a_parameter_are_written_as_rfc_6868_says():
    card = VCard.parse(fixture("apple-3.0.vcf", "\r\n"))
    prop = card.add("TEL", "555-0101", [("X-NOTE", ['a":b', "x^y", "two\nlines"])])
    out = card.to_text(now=NOW)
    assert "TEL;X-NOTE=\"a^':b\",x^^y,two^nlines:555-0101\r\n" in out
    again = VCard.parse(out)
    tel = again.props("TEL")[-1]
    assert tel.value == "555-0101" and tel.param("X-NOTE") == ['a":b', "x^y", "two\nlines"]
    assert [p.raw for p in again.props() if p.key not in ("TEL", "REV")] == \
        [p.raw for p in VCard.parse(fixture("apple-3.0.vcf", "\r\n")).props() if p.key not in ("TEL", "REV")]
    assert prop.param("X-NOTE")[0] == 'a":b'


_ANY_PARAM_TEXT = st.text(st.characters(blacklist_categories=("Cs",)), min_size=1, max_size=20)


@settings(max_examples=300, suppress_health_check=[HealthCheck.too_slow])
@given(st.text(min_size=1, max_size=12), st.lists(_ANY_PARAM_TEXT, min_size=1, max_size=3))
def test_any_parameter_is_refused_or_reads_back_and_nothing_else_moves(pname, values):
    text = split_cards(fixture("google-3.0.vcf", "\r\n"))[0].to_text()
    card = VCard.parse(text)
    before = [(p.key, p.raw) for p in card.props() if p.key != "REV"]
    try:
        card.add("X-PROBE", "probe", [(pname, values)])
    except VCardError:
        assert card.to_text() == text
        return
    out = card.to_text(now=NOW)
    again = VCard.parse(out)
    probe = again.props("X-PROBE")
    assert len(probe) == 1 and probe[0].value == "probe" and probe[0].param(pname) == values
    assert [(p.key, p.raw) for p in again.props() if p.key not in ("REV", "X-PROBE")] == before


def test_a_new_value_drops_a_quoted_printable_encoding_so_the_next_line_survives():
    text = ("BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Kai Invented\r\nN:Invented;Kai;;;\r\n"
            "NOTE;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:caf=C3=A9\r\nTEL;TYPE=CELL:555-0101\r\nEND:VCARD\r\n")
    assert VCard.parse(text).first("NOTE").text() == "café"
    for value in ("total =", "a=3D b"):
        card = VCard.parse(text)
        card.set("NOTE", value)
        out = card.to_text(now=NOW)
        again = VCard.parse(out)
        assert again.first("NOTE").text() == value and "QUOTED-PRINTABLE" not in out and "CHARSET" not in out
        assert again.first("TEL").raw == "TEL;TYPE=CELL:555-0101\r\n"
        assert parse_vcard(out).note == value
    card = VCard.parse(text)
    with pytest.raises(VCardError, match="quoted-printable"):
        card.set("NOTE", "x", [("ENCODING", ["QUOTED-PRINTABLE"])])


def test_a_link_replacing_an_embedded_photo_drops_its_encoding():
    card = VCard.parse(fixture("apple-3.0.vcf"))
    assert card.first("PHOTO").encoding == "B"
    card.set("PHOTO", Raw("https://example.org/p.jpg"))
    photo_prop = VCard.parse(card.to_text(now=NOW)).first("PHOTO")
    assert photo_prop.encoding == "" and photo_prop.value == "https://example.org/p.jpg"
