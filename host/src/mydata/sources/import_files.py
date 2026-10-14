"""Reading a contacts file for an import: the bytes an app uploaded, never a path.

Accepted: a .vcf (one card or many; vCard 2.1, 3.0 or 4.0) or a .zip of .vcf files (a Google export, Takeout,
several Contacts.app exports zipped). Everything is read in memory; nothing is written to disk, so a zip
entry's name ("../../etc/passwd", "/abs/path.vcf") is only ever a label and is never opened as a path.

Caps, each refused with ImportFileError (a message for the user, no content):
- MAX_INPUT bytes uploaded;
- for a zip: at most MAX_ENTRIES entries in its directory, MAX_EXPANDED bytes read out of it in all, each entry
  read through a bounded read (a header that understates an entry's size is never trusted), and no entry that
  expands more than MAX_RATIO times (a zip bomb). Nested zips, encrypted entries and entries compressed other than
  stored or deflated (bzip2 and LZMA expand a whole read before any cap applies) are not read (reported).

Each card is cut out of the text on its own, so one malformed card never stops the others: a card without
END:VCARD, one the line parser rejects, an unsupported VERSION or a vCard 2.1 that cannot be converted is
skipped with its reason, and text outside any card is reported once. A card far larger than a contact (over
MAX_CARD_BYTES, MAX_CARD_LINES content lines or MAX_CARD_TEXT of text besides photos) is skipped before it is
parsed, and cards past the first MAX_CARDS are only counted, so memory stays a small multiple of the input.

vCard 2.1 (Samsung): the line reader joins quoted-printable soft breaks, then vcard_edit.upgrade_21 makes it
3.0 (values decoded in their CHARSET); the import keeps the 2.1 text as the original (origins.source_raw).
3.0 and 4.0 are kept exactly as received.

Text: UTF-8 (a byte-order mark is dropped), UTF-16 with a byte-order mark, else Windows-1252 (reported).
"""

from __future__ import annotations

import hashlib
import io
import re
import zipfile
from dataclasses import dataclass, field

from .vcard import card_kind, parse_vcard
from .vcard_edit import VCard, VCardError, upgrade_21

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


class ImportFileError(Exception):
    """The file cannot be imported at all. The message is for the user and holds no content."""


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


@dataclass
class Skipped:
    reason: str  # a SKIP_REASONS code
    index: int | None = None  # the card's position (None for text outside any card)
    entry: str | None = None


@dataclass
class ReadResult:
    cards: list[ReadCard] = field(default_factory=list)
    skipped: list[Skipped] = field(default_factory=list)
    # Notes about the file that lose nothing ("windows_1252", "outside_text") and ones that do ("nested_zip",
    # "encrypted"): {code: count}
    notes: dict[str, int] = field(default_factory=dict)
    entries_read: int = 0  # .vcf files read (1 for a plain .vcf)
    other_files: int = 0  # files in a zip that are not vCards (calendars, photos): not read

    def note(self, code: str, n: int = 1) -> None:
        self.notes[code] = self.notes.get(code, 0) + n


def is_zip(data: bytes) -> bool:
    return data[:4] in (b"PK\x03\x04", b"PK\x05\x06")


def read_contacts(data: bytes) -> ReadResult:
    """Every card in a .vcf or a .zip of them (see the module docstring)."""
    if len(data) > MAX_INPUT:
        raise ImportFileError(f"The file is larger than {MAX_INPUT // (1024 * 1024)} MB.")
    result = ReadResult()
    if is_zip(data):
        for name, payload in _zip_vcards(data, result):
            _read_text(_decode(payload, result), result, entry=name)
            result.entries_read += 1
        if result.entries_read == 0:
            raise ImportFileError("The zip holds no vCard (.vcf) file.")
    else:
        _read_text(_decode(data, result), result, entry=None)
        result.entries_read = 1
    if not result.cards and not result.skipped:
        raise ImportFileError("No vCard was found in the file.")
    return result


def _zip_vcards(data: bytes, result: ReadResult):
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
        infos = archive.infolist()
    except (zipfile.BadZipFile, zipfile.LargeZipFile, ValueError, OSError):
        raise ImportFileError("The zip file cannot be read.") from None
    if len(infos) > MAX_ENTRIES:
        raise ImportFileError(f"The zip holds more than {MAX_ENTRIES} files.")
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
            raise ImportFileError("A file in the zip cannot be read.") from None
        except Exception:  # noqa: BLE001 - zlib errors and the like: the archive is damaged
            raise ImportFileError("A file in the zip cannot be read.") from None
        if len(payload) > cap:
            if cap == budget:
                raise ImportFileError(f"The zip expands to more than {MAX_EXPANDED // (1024 * 1024)} MB.")
            raise ImportFileError("A file in the zip expands far more than a vCard does; it was not read.")
        budget -= len(payload)
        yield name, payload


def _decode(data: bytes, result: ReadResult) -> str:
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        try:
            return data.decode("utf-16")
        except UnicodeDecodeError:
            raise ImportFileError("The file's text cannot be read (UTF-16).") from None
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        pass
    try:
        text = data.decode("cp1252")
    except UnicodeDecodeError:
        raise ImportFileError("The file is not text in an encoding myData reads (UTF-8, UTF-16 or "
                              "Windows-1252).") from None
    result.note("windows_1252")
    return text


_PHYSICAL = re.compile(r"[^\r\n]*(?:\r\n|\n|\r)|[^\r\n]+\Z")


def _chunks(text: str):
    """(kind, text) for each part of the text: ("card", one card from BEGIN:VCARD to its END:VCARD),
    ("open", a card with no END:VCARD), ("outside", non-blank text outside any card). Cards are cut out by
    offset, so a very long card is never held twice as a list of its lines."""
    start: int | None = None  # where the current card begins
    depth = 0
    outside = False
    for match in _PHYSICAL.finditer(text):
        phys = match.group(0)
        # Only the start of a line decides (BEGIN:/END:); a long value line is never copied whole to read it.
        line = (phys if len(phys) <= 256 else phys[:256]).strip().lstrip("\ufeff").upper()
        if start is None:
            if line == "BEGIN:VCARD":
                start, depth = match.start(), 0
            elif line:
                outside = True
            continue
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
        yield "outside", ""


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
    """One card's text as a ReadCard, or why it is skipped."""
    if len(original) > MAX_CARD_BYTES:
        return Skipped("too_large", index, entry)
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
    uid = parsed.uid.strip()
    return ReadCard(index=index, text=text, original=original, converted_from=converted, kind=card_kind(text),
                    version=VCard.parse(text).version, uid=uid, source_uid=uid or content_key(original),
                    source_hash=raw_hash(original), display_name=parsed.display_name,
                    emails=[e["value"] for e in parsed.emails], phones=[p["value"] for p in parsed.phones],
                    entry=entry)


def _trimmed(chunk: str) -> str:
    """A card's own text: from BEGIN:VCARD to its line ending after END:VCARD."""
    start = chunk.upper().find("BEGIN:VCARD")
    return chunk[start:] if start > 0 else chunk


def _read_text(text: str, result: ReadResult, *, entry: str | None) -> None:
    for kind, chunk in _chunks(text):
        if kind == "outside":
            result.note("outside_text")
            continue
        index = len(result.cards) + len(result.skipped)
        if index >= MAX_CARDS:
            result.note("too_many")  # counted, never cut out or kept: the input may hold millions
            continue
        if kind == "open":
            result.skipped.append(Skipped("no_end", index, entry))
            continue
        read = read_card(_trimmed(chunk), index, entry)
        (result.skipped if isinstance(read, Skipped) else result.cards).append(read)
