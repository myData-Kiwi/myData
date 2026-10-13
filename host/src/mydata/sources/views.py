"""How the apps show mirrored contacts and calendars, worked out once on the host so every app says the same.

The words and groupings come from the component specs in design/components:
- ContactList: each contact's letter group and its caption line.
- ContactHeader and Notice: a source named inside a sentence ("this Mac", "the iCloud account
  you@example.com").
- FieldRow: a contact's values grouped by kind, in a fixed order, with labels in sentence case.
- DataColour: a calendar list grouped by source, headed "This Mac" or "iCloud account you@example.com",
  and under This Mac a caption naming the account the calendar belongs to on the Mac.

Nothing here reads or writes the mirror: these are plain functions over what the stores return.
"""

from __future__ import annotations

import functools
import re
import unicodedata
from typing import Any

from .mac import MAC_ID

# ---------------------------------------------------------------- sources


def source_heading(account_id: str, email: str | None) -> str:
    """The source as a heading (the calendar list's group): "This Mac", "iCloud account you@example.com"."""
    if account_id == MAC_ID:
        return "This Mac"
    return f"iCloud account {email}" if email else "iCloud account"


def source_in_sentence(account_id: str, email: str | None) -> str:
    """The source inside a sentence (ContactHeader, Notice): "this Mac", "the iCloud account you@example.com"."""
    if account_id == MAC_ID:
        return "this Mac"
    return f"the iCloud account {email}" if email else "an iCloud account"


# ---------------------------------------------------------------- calendars

# The words myData uses where macOS would say "Other" or "On My Mac" (DataColour, "Sources and accounts").
_CAPTION_BY_KIND = {
    "local": "Only on this Mac",
    "birthdays": "Birthdays from Contacts",
    "subscribed": "Subscribed",
}
# When macOS gives an account no name, the kind still says what it is. A CalDAV account with no name has
# nothing to say, so it has no caption.
_FALLBACK_BY_KIND = {"mobileMe": "iCloud", "exchange": "Exchange"}

_HEX = re.compile(r"^#([0-9A-Fa-f]{6})(?:[0-9A-Fa-f]{2})?$")


def account_caption(source_kind: str | None, source_name: str | None) -> str | None:
    """The caption of a This Mac calendar row: the account it belongs to on the Mac, as macOS names it
    ("iCloud", "Google", "Exchange"), or myData's words for calendars stored only on the Mac, the
    Birthdays calendar and subscriptions. None when nothing is known about the calendar's account."""
    if source_kind in _CAPTION_BY_KIND:
        return _CAPTION_BY_KIND[source_kind]
    name = (source_name or "").strip()
    if name:
        return name
    return _FALLBACK_BY_KIND.get(source_kind or "")


def data_colour(value: Any) -> str | None:
    """A calendar's colour as "#RRGGBB" (upper case), dropping any alpha (DataColour draws it opaque); None
    when there is none or it is not a hex colour."""
    if not isinstance(value, str):
        return None
    m = _HEX.match(value.strip())
    return "#" + m.group(1).upper() if m else None


# ---------------------------------------------------------------- contacts: list rows

# Scripts whose characters are not letters of an alphabet: one group per character would not help anyone
# find a name, so they go under "#".
_NO_INITIAL_SCRIPTS = ("CJK UNIFIED IDEOGRAPH", "CJK COMPATIBILITY IDEOGRAPH", "HANGUL")


def sort_letter(display_name: str) -> str:
    """The contact's letter group (ContactList): the first letter of the name as shown, without accents and
    upper case ("Émile" → "E"); "#" for a name that does not start with a letter (a digit, "+", an emoji)
    or that starts with a Chinese, Japanese kanji or Korean character."""
    text = (display_name or "").strip()
    if not text:
        return "#"
    first = text[0]
    try:
        if unicodedata.name(first).startswith(_NO_INITIAL_SCRIPTS):
            return "#"
    except ValueError:  # no name: not a letter
        return "#"
    base = unicodedata.normalize("NFD", first)[0]
    if not base.isalpha():
        return "#"
    upper = base.upper()
    return upper if len(upper) == 1 else base


# Letters with no decomposition but a plain spelling, after case folding (ß, ſ and ς are folded by casefold).
_FOLD_EXTRA = str.maketrans({"æ": "ae", "œ": "oe", "ø": "o", "đ": "d", "ð": "d", "ł": "l", "ŀ": "l", "þ": "th",
                             "ı": "i", "ħ": "h", "ŧ": "t"})

# A phone number as a name: digits and the usual phone punctuation only, with at least one digit.
_PHONE_LIKE = re.compile(r"[0-9\s+().\-‐–/]+")


def _fold(text: str) -> str:
    """Text compared ignoring case and accents: "Élodie" and "ELODIE" are the same (ContactList's
    foldForSearch in mydata_ui)."""
    decomposed = unicodedata.normalize("NFD", text.casefold())
    return "".join(c for c in decomposed if not unicodedata.combining(c)).translate(_FOLD_EXTRA)


@functools.lru_cache(maxsize=65536)
def sort_key(display_name: str) -> str:
    """How the contact list is ordered: the name as shown, ignoring case and accents, so "Émile" sorts with
    the E's and "élodie" before "Ezra" (ContactList: contacts in the locale's order). Letters with no
    decomposition fold as foldForSearch does (ø as o, æ as ae)."""
    return _fold((display_name or "").strip())


def compare_names(a: str, b: str) -> int:
    """An SQLite collation over sort_key; equal keys fall back to the names as written, so the order is
    stable."""
    ka, kb = sort_key(a), sort_key(b)
    if ka != kb:
        return -1 if ka < kb else 1
    return (a > b) - (a < b)


def _digits(text: str) -> str:
    return re.sub(r"[^0-9]", "", text)


def contact_caption(display_name: str, organisation: str, emails: list[dict], phones: list[dict]) -> str | None:
    """The line under a contact's name in the list (ContactList): the organisation, or else the first email
    or phone that is not already the name. None when there is nothing else to say.

    A value is already the name when it is the same ignoring case and accents; when the name is a phone
    number, a phone with the same digits is the name too ("+44 7700 900456" and "+447700900456"). The same
    rule as contactCaption in mydata_ui."""
    name = (display_name or "").strip()
    shown = _fold(name)
    shown_digits = _digits(name) if _PHONE_LIKE.fullmatch(name) and _digits(name) else None
    for value in (organisation, *(e.get("value", "") for e in emails)):
        value = (value or "").strip()
        if value and _fold(value) != shown:
            return value
    for p in phones:
        value = (p.get("value", "") or "").strip()
        if not value or _fold(value) == shown or (shown_digits is not None and _digits(value) == shown_digits):
            continue
        return value
    return None


# ---------------------------------------------------------------- contacts: a contact's page

# Labels the sources use for their built-in kinds, stored lower case (vcard.py, the Mac reader). Shown in
# sentence case; a label the user typed is shown exactly as written.
_LABELS = {
    "mobile": "Mobile", "cell": "Mobile", "iphone": "iPhone", "home": "Home", "work": "Work", "other": "Other",
    "main": "Main", "fax": "Fax", "homefax": "Home fax", "workfax": "Work fax", "otherfax": "Other fax",
    "pager": "Pager", "school": "School", "homepage": "Home page", "applewatch": "Apple Watch",
}

FIELD_KINDS = (  # FieldRow: the order of the groups on a contact's page, and their headings
    ("phone", "Phone"), ("email", "Email"), ("address", "Address"), ("birthday", "Birthday"), ("url", "Links"),
    ("note", "Notes"),
)


def display_label(label: str | None) -> str:
    """A value's label as the contact's page shows it: built-in labels in sentence case ("Mobile",
    "Home fax"), a label the user typed exactly as written, "" when there is none."""
    text = (label or "").strip()
    return _LABELS.get(text.lower(), text)


def address_lines(a: dict) -> str:
    """A postal address as plain lines: street (its own lines kept), then locality, region and postal code,
    then country. The apps may lay it out for their locale from the parts instead."""
    place = " ".join(p for p in (a.get("locality", ""), a.get("region", ""), a.get("postal_code", "")) if p)
    return "\n".join(p for p in (a.get("street", ""), place, a.get("country", "")) if p)


def contact_fields(contact: dict, *, urls: list[dict], notes_included: bool) -> list[dict]:
    """A contact's values grouped by kind, in FieldRow's order (Phone, Email, Address, Birthday, Links,
    Notes). A kind with no values is left out. Notes appear only when the source reads them and the note
    is not empty: never for This Mac.

    Each group: {kind, title, items}; each item: {label, value, address}. A birthday's value is
    "YYYY-MM-DD", or "--MM-DD" when the year is not known, for the app to write in the locale's long form.
    An address item also has its parts (`address`), for a layout in the locale's order."""
    items: dict[str, list[dict]] = {
        "phone": [{"label": display_label(p.get("label")), "value": p["value"]} for p in contact.get("phones", [])],
        "email": [{"label": display_label(e.get("label")), "value": e["value"]} for e in contact.get("emails", [])],
        "address": [{"label": display_label(a.get("label")), "value": address_lines(a), "address": a}
                    for a in contact.get("addresses", []) if address_lines(a)],
        "birthday": [{"label": "", "value": contact["birthday"]}] if contact.get("birthday") else [],
        "url": [{"label": display_label(u.get("label")), "value": u["value"]} for u in urls if u.get("value")],
        "note": [{"label": "", "value": contact.get("note", "").strip()}]
        if notes_included and (contact.get("note") or "").strip() else [],
    }
    return [{"kind": kind, "title": title, "items": items[kind]} for kind, title in FIELD_KINDS if items[kind]]
