"""Synthetic inputs for the contact import tests, built from the committed fixtures (tests/fixtures/vcard and
tests/fixtures/import): zips of several exports, a zip bomb, a zip whose entry names try to leave any folder, and a
file over the size cap. Built in memory when a test asks; nothing here is real data (example.org, 555-01xx)."""

from __future__ import annotations

import io
import zipfile
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"
VCARD = FIXTURES / "vcard"
IMPORT = FIXTURES / "import"

APPLE = IMPORT / "apple-export.vcf"
MALFORMED = IMPORT / "malformed.vcf"
GOOGLE = VCARD / "google-3.0.vcf"
SAMSUNG = VCARD / "samsung-2.1.vcf"
V4_GROUP = VCARD / "v4-group.vcf"


def read(path: Path) -> bytes:
    return path.read_bytes()


def zipped(files: dict[str, bytes], *, compression: int = zipfile.ZIP_DEFLATED) -> bytes:
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", compression=compression) as z:
        for name, data in files.items():
            z.writestr(name, data)
    return out.getvalue()


def several() -> bytes:
    """A Takeout-like zip: three exports in folders, and a calendar file that is not read here."""
    return zipped({"Takeout/Contacts/Apple.vcf": read(APPLE), "Takeout/Contacts/Google.vcf": read(GOOGLE),
                   "Takeout/Contacts/Samsung.VCF": read(SAMSUNG),
                   "Takeout/Calendar/Invented.ics": b"BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"})


def bomb(size: int = 300 * 1024 * 1024) -> bytes:
    """One .vcf entry of `size` bytes of the same character: a few hundred KB compressed. Written in pieces, so
    the test never holds the expanded bytes."""
    out = io.BytesIO()
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as z:
        with z.open("contacts.vcf", "w", force_zip64=True) as fh:
            chunk = b"A" * (1024 * 1024)
            for _ in range(size // len(chunk)):
                fh.write(chunk)
    return out.getvalue()


def traversal() -> bytes:
    """Entry names that would leave any folder they were extracted into: harmless, since nothing is extracted."""
    return zipped({"../../../../tmp/evil.vcf": read(GOOGLE), "/abs/path/escape.vcf": read(APPLE),
                   "..\\..\\windows\\style.vcf": read(V4_GROUP)})


def over_cap(cap: int) -> bytes:
    card = b"BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nEND:VCARD\r\n"
    return card * (cap // len(card) + 1)
