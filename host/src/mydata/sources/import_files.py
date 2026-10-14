"""Reading a contacts file for an import: the bytes an app uploaded, never a path.

Accepted: a .vcf (one card or many; vCard 2.1, 3.0 or 4.0) or a .zip of .vcf files (a Google export, Takeout,
several Contacts.app exports zipped). Everything is read in memory; nothing is written to disk, so a zip
entry's name ("../../etc/passwd", "/abs/path.vcf") is only ever a label and is never opened as a path.

Caps, each refused with ImportFileError (a message for the user, no content, and a code: REFUSALS):
- MAX_INPUT bytes uploaded;
- for a zip: at most MAX_ENTRIES entries in its directory, MAX_EXPANDED bytes read out of it in all, each entry
  read through a bounded read (a header that understates an entry's size is never trusted), and no entry that
  expands more than MAX_RATIO times (a zip bomb). Nested zips, encrypted entries and entries compressed other than
  stored or deflated (bzip2 and LZMA expand a whole read before any cap applies) are not read (reported).

Each card is cut out of the text on its own, so one malformed card never stops the others: a card without
END:VCARD, one the line parser rejects, an unsupported VERSION or a vCard 2.1 that cannot be converted is
skipped with its reason, and lines of text outside any card are counted as a loss (a card whose BEGIN:VCARD is
misspelt is among them). A .vcf in a zip with no card in it at all (one in an encoding not read) is reported by
name as a loss. A card far larger than a contact (over
MAX_CARD_BYTES, MAX_CARD_LINES content lines or MAX_CARD_TEXT of text besides photos) is skipped before it is
parsed, and cards past the first MAX_CARDS are only counted, so memory stays a small multiple of the input.

vCard 2.1 (Samsung): the line reader joins quoted-printable soft breaks, then vcard_edit.upgrade_21 makes it
3.0 (values decoded in their CHARSET); the import keeps the 2.1 text as the original (origins.source_raw).
3.0 and 4.0 are kept exactly as received.

Text: UTF-8 (a byte-order mark is dropped) or UTF-16 (with a byte-order mark or, without one, with a zero byte at
every other position) is decoded whole. Any other file is decoded card by card, so one stray byte never changes
how the other cards read: UTF-8, else the character set the card names (CHARSET=, as older phones write
Shift_JIS), else a guess (Windows-1252, then Latin-1), reported as a loss, with the card's bytes kept as its
original (origins.source_raw).
"""

from __future__ import annotations

import hashlib
import io
import json
import re
import zipfile
from dataclasses import asdict, dataclass, field

from .contacts_store import card_fields
from .vcard import parse_vcard
from .vcard_edit import VCard, VCardError, text_codec, upgrade_21

MAX_INPUT = 50 * 1024 * 1024
MAX_EXPANDED = 200 * 1024 * 1024
MAX_ENTRIES = 10_000
MAX_RATIO = 200
MAX_CARDS = 50_000
# One card: its size, its content lines, and its text without binary values (photos). Parsing a card holds many
# times its text in memory, so a card past these is not read (a loss, too_large). Real cards are far smaller: a
# few KB, a photo up to a few hundred KB, a few dozen lines.
MAX_CARD_BYTES = 8 * 1024 * 1024
MAX_CARD_LINES = 5_000
MAX_CARD_TEXT = 1024 * 1024
_BINARY = {"PHOTO", "LOGO", "SOUND", "KEY"}
# Zip entries are read only when stored or deflated (Google, Takeout and macOS write these): zlib expands a bounded
# read in bounded steps, so the caps below hold while the entry is read.
_READ_COMPRESSION = (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)

# Why a card was not read (the loss report's codes); the messages are the app's words.
SKIP_REASONS = {
    "unreadable": "could not be read as a vCard",
    "no_end": "has no END:VCARD (the file may be cut short)",
    "version": "is a vCard version myData does not read",
    "empty": "holds nothing at all (not even a UID)",
    "too_large": "is far larger than a contact card (over {mb} MB, {lines} lines, or {text} KB of text)".format(
        mb=MAX_CARD_BYTES // (1024 * 1024), lines=MAX_CARD_LINES, text=MAX_CARD_TEXT // 1024),
    "too_many": "came after the first {n} cards".format(n=MAX_CARDS),
}


# Why a whole file is refused (ImportFileError.code), so an app can write its own sentence for each.
REFUSALS = ("too_big", "zip_too_big", "zip_entry_too_big", "zip_too_many", "zip_unreadable", "zip_no_vcard",
            "no_vcard", "utf16_unreadable")


class ImportFileError(Exception):
    """The file cannot be imported at all. The message is for the user and holds no content; `code` (REFUSALS)
    says which case it is."""

    def __init__(self, message: str, code: str):
        if code not in REFUSALS:
            raise ValueError(code)
        super().__init__(message)
        self.code = code


@dataclass
class ReadCard:
    """One card as read from the input."""

    index: int
    text: str  # what would be stored: 3.0 and 4.0 as received, 2.1 upgraded to 3.0
    original: str  # as received
    converted_from: str | None
    kind: str  # individual, org or group
    version: str
    uid: str
    source_uid: str  # the card's UID, else "sha256:" and a hash of its content (REV and PRODID left out)
    source_hash: str  # sha256 of the original text
    display_name: str
    emails: list[str] = field(default_factory=list)
    phones: list[str] = field(default_factory=list)
    entry: str | None = None  # the zip entry it came from (its name, as a label only)
    prodid: str = ""  # the app that wrote the card, as its PRODID says (Apple's Contacts on a Mac: _MAC_CONTACTS)
    has_note: bool = False
    raw: bytes | None = None  # the card's bytes as received, when its text was decoded by a guess (_decode_card)
    # What is worked out from the card once and used again by every analysis and the commit: its columns
    # ("fields", contacts_store.card_fields) and its matching keys per region (importer).
    cache: dict = field(default_factory=dict, repr=False, compare=False)


@dataclass
class Skipped:
    reason: str  # a SKIP_REASONS code
    index: int | None = None  # the card's position (None for text outside any card)
    entry: str | None = None


@dataclass
class ReadResult:
    cards: list[ReadCard] = field(default_factory=list)
    skipped: list[Skipped] = field(default_factory=list)
    # Notes about the file that lose nothing ("declared_charset": cards decoded in the character set they name)
    # and ones that do ("guessed_charset": cards decoded by a guess, "outside_text": lines outside any card,
    # "nested_zip", "encrypted", "too_many", "no_notes": cards Contacts on a Mac wrote without notes): {code: count}
    notes: dict[str, int] = field(default_factory=dict)
    unread_entries: list[str] = field(default_factory=list)  # .vcf files in a zip with no card that could be read
    entries_read: int = 0  # .vcf files read (1 for a plain .vcf)
    other_files: int = 0  # files in a zip that are not vCards (calendars, photos): not read

    def note(self, code: str, n: int = 1) -> None:
        self.notes[code] = self.notes.get(code, 0) + n


def is_zip(data: bytes) -> bool:
    return data[:4] in (b"PK\x03\x04", b"PK\x05\x06")


def read_contacts(data: bytes) -> ReadResult:
    """Every card in a .vcf or a .zip of them (see the module docstring)."""
    if len(data) > MAX_INPUT:
        raise ImportFileError(f"The file is larger than {MAX_INPUT // (1024 * 1024)} MB.", "too_big")
    result = ReadResult()
    if is_zip(data):
        for name, payload in _zip_vcards(data, result):
            try:
                found, outside = _read_payload(payload, result, entry=name)
            except ImportFileError:
                result.unread_entries.append(name)
                continue
            if found:
                result.entries_read += 1
                if outside:
                    result.note("outside_text", outside)
            elif payload.strip():
                result.unread_entries.append(name)  # no card at all: the whole file is a loss, not stray text
        if result.entries_read == 0 and not result.unread_entries:
            raise ImportFileError("The zip holds no vCard (.vcf) file.", "zip_no_vcard")
    else:
        _found, outside = _read_payload(data, result, entry=None)
        if outside:
            result.note("outside_text", outside)
        result.entries_read = 1
    if not result.cards and not result.skipped:
        raise ImportFileError("No vCard was found in the file.", "no_vcard")
    _note_missing_notes(result)
    return result


# Contacts on a Mac writes "-//Apple Inc.//macOS 26.0//EN" (earlier "Mac OS X 10.15.7", "OS X 10.11").
_MAC_CONTACTS = re.compile(r"-//Apple Inc\.//(macOS|Mac OS X|OS X)\b", re.IGNORECASE)


def _note_missing_notes(result: ReadResult) -> None:
    """Contacts on a Mac leaves notes out of an export unless "Export notes in vCards" is on, and says nothing: a
    file whose cards it wrote, none with a NOTE, is a loss ("no_notes": how many of its people and organisations),
    since the notes are gone for good once the originals are deleted. Only for a file: a followed account's copy
    holds what the account holds."""
    written = [c for c in result.cards if c.kind != "group" and _MAC_CONTACTS.match(c.prodid.strip())]
    if written and not any(c.has_note for c in written):
        result.note("no_notes", len(written))


def _zip_vcards(data: bytes, result: ReadResult):
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
        infos = archive.infolist()
    except (zipfile.BadZipFile, zipfile.LargeZipFile, ValueError, OSError):
        raise ImportFileError("The zip file cannot be read.", "zip_unreadable") from None
    if len(infos) > MAX_ENTRIES:
        raise ImportFileError(f"The zip holds more than {MAX_ENTRIES} files.", "zip_too_many")
    budget = MAX_EXPANDED
    for info in infos:
        if info.is_dir():
            continue
        name = info.filename.replace("\\", "/").rsplit("/", 1)[-1]
        lower = name.lower()
        if lower.endswith(".zip"):
            result.note("nested_zip")
            continue
        if not lower.endswith((".vcf", ".vcard")):
            result.other_files += 1
            continue
        if info.flag_bits & 0x1:
            result.note("encrypted")
            continue
        if info.compress_type not in _READ_COMPRESSION:
            # bzip2 and LZMA are expanded a whole read at a time, before any cap could stop them (a few KB can
            # expand to gigabytes); exports never use them.
            result.note("unsupported_compression")
            continue
        cap = min(budget, max(info.compress_size, 1) * MAX_RATIO)
        try:
            with archive.open(info) as fh:
                payload = fh.read(cap + 1)
        except (zipfile.BadZipFile, NotImplementedError, RuntimeError, ValueError, OSError, EOFError):
            raise ImportFileError("A file in the zip cannot be read.", "zip_unreadable") from None
        except Exception:  # noqa: BLE001 - zlib errors and the like: the archive is damaged
            raise ImportFileError("A file in the zip cannot be read.", "zip_unreadable") from None
        if len(payload) > cap:
            if cap == budget:
                raise ImportFileError(f"The zip expands to more than {MAX_EXPANDED // (1024 * 1024)} MB.",
                                      "zip_too_big")
            raise ImportFileError("A file in the zip expands far more than a vCard does; it was not read.",
                                  "zip_entry_too_big")
        budget -= len(payload)
        yield name, payload


def _utf16_without_bom(data: bytes) -> str | None:
    """"utf-16-le" or "utf-16-be" when text has no byte-order mark but a zero byte at every other position (ASCII
    text in UTF-16, as Windows tools write it), else None."""
    sample = data[:4096]
    if len(sample) < 4 or len(sample) % 2:
        return None
    half = len(sample) // 2
    odd, even = sample[1::2].count(0), sample[0::2].count(0)
    if odd >= half * 0.6 and even <= half * 0.05:
        return "utf-16-le"
    if even >= half * 0.6 and odd <= half * 0.05:
        return "utf-16-be"
    return None


def _read_payload(data: bytes, result: ReadResult, *, entry: str | None) -> tuple[int, int]:
    """Read one file's cards (see _read_text). UTF-16 (ImportFileError when it is not valid) and UTF-8 are
    decoded whole; any other text card by card (_decode_card), so one card in another encoding never changes
    how the others read."""
    utf16 = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else _utf16_without_bom(data)
    if utf16:
        try:
            text = data.decode(utf16)
        except UnicodeDecodeError:
            raise ImportFileError("The file's text cannot be read (UTF-16).", "utf16_unreadable") from None
        return _read_text(text, result, entry=entry)
    try:
        return _read_text(data.decode("utf-8-sig"), result, entry=entry)
    except UnicodeDecodeError:
        pass
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    # Latin-1 maps each byte to one character, so the cards are cut where they are in the bytes (the lines that
    # open and close them are ASCII), and each card's own bytes come back exactly with .encode("latin-1").
    return _read_text(data.decode("latin-1"), result, entry=entry, by_card=True)


_CHARSET = re.compile(rb"""CHARSET="?([A-Za-z0-9_.:-]+)""", re.IGNORECASE)


def _decode_card(raw: bytes) -> tuple[str, str]:
    """(text, how) for one card's bytes: "utf-8"; "declared", in the character set the card names (CHARSET=, as
    vCard 2.1 from older phones writes Shift_JIS or ISO-8859-x text); else "guessed": Windows-1252, or Latin-1
    for the bytes Windows-1252 leaves undefined."""
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        pass
    for name in dict.fromkeys(m.group(1).decode("ascii") for m in _CHARSET.finditer(raw)):
        codec = text_codec(name)
        if codec is None or b"BEGIN:VCARD\r\n".decode(codec, "replace") != "BEGIN:VCARD\r\n":
            continue  # only a character set that reads ASCII as ASCII can decode a whole card (not UTF-16)
        try:
            return raw.decode(codec), "declared"
        except UnicodeError:
            continue
    try:
        return raw.decode("cp1252"), "guessed"
    except UnicodeDecodeError:
        return raw.decode("latin-1"), "guessed"


_PHYSICAL = re.compile(r"[^\r\n]*(?:\r\n|\n|\r)|[^\r\n]+\Z")


def _chunks(text: str):
    """(kind, text) for each part of the text: ("card", one card from BEGIN:VCARD to its END:VCARD),
    ("open", a card with no END:VCARD), and last ("outside", n): n lines outside any card that are not blank or
    a PRODID or VERSION line (lost: "BEGIN: VCARD" misspelt makes its card such lines). Cards are cut out by
    offset, so a very long card is never held twice as a list of its lines."""
    start: int | None = None  # where the current card begins
    depth = 0
    outside = 0
    qp = qp_open = False  # the line is quoted-printable; it ends in a soft break ("="), so the next continues it
    for match in _PHYSICAL.finditer(text):
        phys = match.group(0)
        # Only the start of a line decides (BEGIN:/END:); a long value line is never copied whole to read it.
        line = (phys if len(phys) <= 256 else phys[:256]).strip().lstrip("\ufeff").upper()
        if start is None:
            if line == "BEGIN:VCARD":
                start, depth, qp = match.start(), 0, False
            elif line and not line.startswith(("PRODID:", "VERSION:")):
                outside += 1
            continue
        content = phys.rstrip("\r\n")
        if qp_open or content[:1] in (" ", "\t"):
            # A folded line or a quoted-printable continuation is part of a value ("BEGIN: at nine" in a note), never
            # a line that opens or closes a card; as vcard_edit._logical_lines joins them.
            if not qp_open:
                qp = qp or "QUOTED-PRINTABLE" in line  # the parameter may be on a folded part of the name
            qp_open = qp and content.rstrip(" \t").endswith("=")
            continue
        colon = line.find(":")
        qp = "QUOTED-PRINTABLE" in (line[:colon] if colon >= 0 else line)
        qp_open = qp and content.rstrip(" \t").endswith("=")
        if line == "BEGIN:VCARD" and depth == 0:  # a new card before this one ended
            yield "open", text[start:match.start()]
            start = match.start()
            continue
        if line.startswith("BEGIN:"):
            depth += 1
        elif line.startswith("END:"):
            if depth == 0:
                if line == "END:VCARD":
                    yield "card", text[start:match.end()]
                    start = None
                continue
            depth -= 1
    if start is not None:
        yield "open", text[start:]
    if outside:
        yield "outside", outside


_IGNORED_IN_HASH = ("REV", "PRODID")
_NOT_CONTENT = {"VERSION", "PRODID", "REV"}


def content_key(text: str) -> str:
    """"sha256:" and a hash of a card's content lines (unfolded, line endings and REV and PRODID left out): the
    key of a card that has no UID, the same for the same card exported again."""
    unfolded = re.sub(r"\r\n[ \t]|\n[ \t]|\r[ \t]", "", text)
    lines = []
    for line in re.split(r"\r\n|\n|\r", unfolded):
        line = line.rstrip()
        name = line.split(":", 1)[0].split(";", 1)[0].rsplit(".", 1)[-1].upper()
        if line and name not in _IGNORED_IN_HASH:
            lines.append(line)
    return "sha256:" + hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def raw_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _has_content(card: VCard) -> bool:
    """Anything beyond VERSION, PRODID and REV. A card with only a UID is kept: a blank contact on a phone is one."""
    return any(p.key not in _NOT_CONTENT and p.value.strip() for p in card.props())


def read_card(original: str, index: int, entry: str | None = None) -> ReadCard | Skipped:
    """One card's text as a ReadCard, or why it is skipped. Never raises: whatever a card holds (an unknown
    character set, text that is not valid Unicode once decoded), it is skipped as unreadable on its own."""
    if len(original) > MAX_CARD_BYTES:
        return Skipped("too_large", index, entry)
    try:
        return _read_card(original, index, entry)
    except Exception:  # noqa: BLE001 - one card never stops the others; its text is never quoted
        return Skipped("unreadable", index, entry)


def _read_card(original: str, index: int, entry: str | None) -> ReadCard | Skipped:
    try:
        card = VCard.parse(original)
    except VCardError:
        return Skipped("unreadable", index, entry)
    props = card.props()
    if len(props) > MAX_CARD_LINES or sum(len(p.value) for p in props if p.key not in _BINARY) > MAX_CARD_TEXT:
        return Skipped("too_large", index, entry)
    version = card.version
    if version not in ("2.1", "3.0", "4.0", ""):
        return Skipped("version", index, entry)
    if not _has_content(card):
        return Skipped("empty", index, entry)
    text, converted = original, None
    if version == "2.1":
        try:
            text, converted = upgrade_21(original), "2.1"
            VCard.parse(text)
        except VCardError:
            return Skipped("unreadable", index, entry)
    parsed = parse_vcard(text)
    if not _is_unicode(original, text, json.dumps(asdict(parsed), ensure_ascii=False)):
        return Skipped("unreadable", index, entry)  # a lone surrogate, from a codec such as unicode_escape
    uid = parsed.uid.strip()
    fields = card_fields(None, text, parsed)
    prodid = card.first("PRODID")
    return ReadCard(index=index, text=text, original=original, converted_from=converted, kind=fields["kind"],
                    version=VCard.parse(text).version, uid=uid, source_uid=uid or content_key(original),
                    source_hash=raw_hash(original), display_name=parsed.display_name,
                    emails=[e["value"] for e in parsed.emails], phones=[p["value"] for p in parsed.phones],
                    entry=entry, prodid=prodid.text() if prodid is not None else "",
                    has_note=bool(parsed.note.strip()), cache={"fields": fields})


def _is_unicode(*texts: str) -> bool:
    """Whether every text can be stored as UTF-8 (no lone surrogate)."""
    try:
        for text in texts:
            text.encode("utf-8")
    except UnicodeEncodeError:
        return False
    return True


def _trimmed(chunk: str) -> str:
    """A card's own text: from BEGIN:VCARD to its line ending after END:VCARD."""
    start = chunk.upper().find("BEGIN:VCARD")
    return chunk[start:] if start > 0 else chunk


def _read_text(text: str, result: ReadResult, *, entry: str | None, by_card: bool = False) -> tuple[int, int]:
    """Read the cards of one text into `result`: (cards found, read or skipped; lines outside any card). With
    by_card, `text` is bytes as Latin-1 and each card is decoded on its own (_decode_card)."""
    found = outside = 0
    for kind, chunk in _chunks(text):
        if kind == "outside":
            outside = chunk
            continue
        found += 1
        index = len(result.cards) + len(result.skipped)
        if index >= MAX_CARDS:
            result.note("too_many")  # counted, never cut out or kept: the input may hold millions
            continue
        if kind == "open":
            result.skipped.append(Skipped("no_end", index, entry))
            continue
        chunk, raw, how = _trimmed(chunk), None, "utf-8"
        if by_card:
            raw = chunk.encode("latin-1")
            chunk, how = _decode_card(raw)
        read = read_card(chunk, index, entry)
        if isinstance(read, ReadCard) and how != "utf-8":
            result.note(f"{how}_charset")
            if how == "guessed":
                read.raw = raw  # kept as the original (origins.source_raw): the guess may be wrong
        (result.skipped if isinstance(read, Skipped) else result.cards).append(read)
    return found, outside
