"""Parse a vCard (3.0 as iCloud sends it, or 4.0) into the plain fields the contacts mirror stores.

The raw card is always kept beside these fields, so anything not parsed here (photos, custom fields)
is still on the host. FN, NICKNAME and NOTE are read from the card's own text rather than from vobject,
which cuts text values at the first comma: NICKNAME is a comma-separated list (RFC 2426/6350) and is
kept whole, and so is an FN, TITLE or NOTE with an unescaped comma. Parsing never raises: a card vobject cannot read comes back with only what a
line scan finds (UID, FN, N, ORG, TITLE, EMAIL, TEL, URL), so one broken card cannot stop a sync.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

import vobject

# Apple wraps its standard labels as _$!<Work>!$_ in X-ABLabel.
_APPLE_LABEL = re.compile(r"^_\$!<(.*)>!\$_$")

# TYPE values that say something about the kind of address or number, in the order we prefer them.
_TYPE_LABELS = {
    "cell": "mobile",
    "mobile": "mobile",
    "iphone": "iphone",
    "home": "home",
    "work": "work",
    "main": "main",
    "fax": "fax",
    "pager": "pager",
    "other": "other",
    "school": "school",
}


@dataclass
class ParsedContact:
    uid: str = ""
    full_name: str = ""
    given_name: str = ""
    family_name: str = ""
    nickname: str = ""
    organisation: str = ""
    job_title: str = ""
    emails: list[dict] = field(default_factory=list)
    phones: list[dict] = field(default_factory=list)
    addresses: list[dict] = field(default_factory=list)
    birthday: str | None = None
    urls: list[dict] = field(default_factory=list)
    note: str = ""
    has_photo: bool = False

    @property
    def display_name(self) -> str:
        """The name to show: FN, else given + family, else the organisation, first email, first phone, "No name"."""
        if self.full_name.strip():
            return self.full_name.strip()
        joined = " ".join(p for p in (self.given_name.strip(), self.family_name.strip()) if p)
        if joined:
            return joined
        if self.organisation.strip():
            return self.organisation.strip()
        if self.emails:
            return self.emails[0]["value"]
        if self.phones:
            return self.phones[0]["value"]
        return "No name"


def _text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, (list, tuple)):
        return ", ".join(_text(v) for v in value if _text(v))
    return str(value).strip()


def _params_types(line) -> list[str]:
    types: list[str] = []
    for raw in line.params.get("TYPE", []):
        types.extend(t.strip().lower() for t in str(raw).split(",") if t.strip())
    return types


def _label(line, group_labels: dict[str, str]) -> str:
    group = (line.group or "").lower()
    if group and group in group_labels:
        return group_labels[group]
    for t in _params_types(line):
        if t in _TYPE_LABELS:
            return _TYPE_LABELS[t]
    return ""


def _apple_label(value: str) -> str:
    m = _APPLE_LABEL.match(value.strip())
    if m:
        return m.group(1).strip().lower()
    return value.strip()


def _birthday(line) -> str | None:
    value = _text(line.value)
    if not value:
        return None
    omit_year = (line.params.get("X-APPLE-OMIT-YEAR") or [None])[0]
    m = re.fullmatch(r"(\d{4})-?(\d{2})-?(\d{2})(?:T.*)?", value)
    if m:
        year, month, day = m.groups()
        if omit_year and str(omit_year) == year:
            return f"--{month}-{day}"
        return f"{year}-{month}-{day}"
    m = re.fullmatch(r"--(\d{2})-?(\d{2})", value)
    if m:
        return f"--{m.group(1)}-{m.group(2)}"
    return value


def _phone_value(value: str) -> str:
    value = value.strip()
    if value.lower().startswith("tel:"):
        value = value[4:]
    return value


def parse_vcard(text: str) -> ParsedContact:
    try:
        card = vobject.readOne(text, ignoreUnreadable=True)
    except Exception:  # noqa: BLE001 - any parse failure falls back to a line scan
        return _scan(text)
    try:
        out = _from_vobject(card)
    except Exception:  # noqa: BLE001
        return _scan(text)
    try:
        _text_props(text, out)
    except Exception:  # noqa: BLE001 - keep what vobject gave
        pass
    return out


def _value_colon(line: str) -> int:
    """Where the value starts: the first ':' outside a quoted parameter value; -1 if none."""
    quoted = False
    for i, ch in enumerate(line):
        if ch == '"':
            quoted = not quoted
        elif ch == ":" and not quoted:
            return i
    return -1


def _properties(text: str) -> list[tuple[str, str, str]]:
    """(NAME without group, parameters, raw value) for each unfolded line, in order."""
    out = []
    for line in _unfold(text):
        colon = _value_colon(line)
        if colon < 0:
            continue
        head, value = line[:colon], line[colon + 1:]
        name, _, params = head.partition(";")
        out.append((name.split(".")[-1].strip().upper(), params, value))
    return out


def _unescape(value: str) -> str:
    r"""A vCard text value with its escapes undone: \n or \N is a line break; \, \; and \\ are the
    character itself."""
    out, i = [], 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append("\n" if nxt in "nN" else nxt)
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _split_list(value: str) -> list[str]:
    """Split a raw text-list value at unescaped commas, then undo the escapes in each item."""
    items, current, i = [], [], 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            current.append(value[i:i + 2])
            i += 2
            continue
        if ch == ",":
            items.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    items.append("".join(current))
    return [v for v in (_unescape(item).strip() for item in items) if v]


def _text_props(text: str, out: ParsedContact) -> None:
    """Set full_name, job_title, nickname and note from the card's text (see the module docstring). A
    quoted-printable value (vCard 2.1) is left to vobject, which decodes it."""
    full_name: str | None = None
    job_title: str | None = None
    nicknames: list[str] = []
    note: str | None = None
    for name, params, value in _properties(text):
        if "QUOTED-PRINTABLE" in params.upper():
            continue
        if name == "FN" and full_name is None and value.strip():
            full_name = _unescape(value).strip()
        elif name == "TITLE" and job_title is None and value.strip():
            job_title = _unescape(value).strip()
        elif name == "NICKNAME":
            nicknames.extend(n for n in _split_list(value) if n not in nicknames)
        elif name == "NOTE" and note is None and value.strip():
            note = _unescape(value).strip()
    if full_name is not None:
        out.full_name = full_name
    if job_title is not None:
        out.job_title = job_title
    if nicknames:
        out.nickname = ", ".join(nicknames)
    if note is not None:
        out.note = note


def _from_vobject(card) -> ParsedContact:
    out = ParsedContact()
    children = list(card.getChildren())
    group_labels = {
        (c.group or "").lower(): _apple_label(_text(c.value))
        for c in children
        if c.name == "X-ABLABEL" and c.group
    }
    for line in children:
        name = line.name
        if name == "UID":
            out.uid = _text(line.value)
        elif name == "FN":
            out.full_name = _text(line.value)
        elif name == "N":
            n = line.value
            out.given_name = _text(getattr(n, "given", ""))
            out.family_name = _text(getattr(n, "family", ""))
        elif name == "NICKNAME":
            out.nickname = out.nickname or _text(line.value)
        elif name == "ORG":
            out.organisation = out.organisation or _text(line.value)
        elif name == "TITLE":
            out.job_title = out.job_title or _text(line.value)
        elif name == "EMAIL":
            value = _text(line.value)
            if value:
                out.emails.append({"value": value, "label": _label(line, group_labels)})
        elif name == "TEL":
            value = _phone_value(_text(line.value))
            if value:
                out.phones.append({"value": value, "label": _label(line, group_labels)})
        elif name == "ADR":
            a = line.value
            address = {
                "label": _label(line, group_labels),
                "street": _text(getattr(a, "street", "")),
                "locality": _text(getattr(a, "city", "")),
                "region": _text(getattr(a, "region", "")),
                "postal_code": _text(getattr(a, "code", "")),
                "country": _text(getattr(a, "country", "")),
            }
            if any(v for k, v in address.items() if k != "label"):
                out.addresses.append(address)
        elif name == "BDAY":
            out.birthday = out.birthday or _birthday(line)
        elif name == "URL":
            value = _text(line.value)
            if value:
                out.urls.append({"value": value, "label": _label(line, group_labels)})
        elif name == "NOTE":
            out.note = out.note or _text(line.value)
        elif name == "PHOTO":
            out.has_photo = True
    return out


def _unfold(text: str) -> list[str]:
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def _scan(text: str) -> ParsedContact:
    """Last-resort reader for a card vobject rejects: one property per unfolded line, no grouping."""
    out = ParsedContact()
    for line in _unfold(text):
        if ":" not in line:
            continue
        head, value = line.split(":", 1)
        prop = head.split(";", 1)[0].split(".")[-1].upper()
        value = value.replace("\\,", ",").replace("\\;", ";").replace("\\n", "\n").strip()
        if prop == "UID":
            out.uid = value
        elif prop == "FN":
            out.full_name = value
        elif prop == "N":
            parts = value.split(";")
            out.family_name = parts[0].strip() if parts else ""
            out.given_name = parts[1].strip() if len(parts) > 1 else ""
        elif prop == "ORG":
            out.organisation = out.organisation or value.split(";")[0].strip()
        elif prop == "TITLE":
            out.job_title = out.job_title or value
        elif prop == "URL" and value:
            out.urls.append({"value": value, "label": ""})
        elif prop == "EMAIL" and value:
            out.emails.append({"value": value, "label": ""})
        elif prop == "TEL" and value:
            out.phones.append({"value": _phone_value(value), "label": ""})
        elif prop == "PHOTO":
            out.has_photo = True
    _text_props(text, out)
    return out


def card_kind(text: str) -> str:
    """What the card describes: "group" (KIND:group in 4.0, or Apple's X-ADDRESSBOOKSERVER-KIND:group, the
    way iCloud sends a group in 3.0), "org" (KIND:org), else "individual" (also for KIND:location and
    values this host does not know: shown as a contact, as before kinds were read)."""
    kinds = {_unescape(value).strip().lower() for name, _params, value in _properties(text)
             if name in ("KIND", "X-ADDRESSBOOKSERVER-KIND")}
    if "group" in kinds:
        return "group"
    if kinds & {"org", "organization"}:
        return "org"
    return "individual"


def card_version(text: str) -> str:
    """The card's VERSION as received ("3.0", "4.0", "2.1"); "" when it has none."""
    return next((value.strip() for name, _params, value in _properties(text) if name == "VERSION"), "")


def phone_search_forms(value: str) -> list[str]:
    """Extra search tokens for a phone number: its digits, and their tails of 7 or more digits, so
    "5550100" finds "+1 (555) 010-0". The number as written is indexed too, split at punctuation."""
    digits = re.sub(r"\D", "", value)
    if len(digits) < 4:
        return []
    forms = [digits]
    forms.extend(digits[i:] for i in range(1, len(digits) - 6))
    return forms


# ---------------------------------------------------------------- photos

# A photo larger than this is not served (the app shows initials instead).
MAX_PHOTO_BYTES = 2 * 1024 * 1024


def image_type(data: bytes) -> str | None:
    """image/jpeg or image/png from the first bytes; None for anything else."""
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return None


def photo(text: str) -> tuple[bytes, str] | None:
    """The card's embedded photo as (bytes, media type), JPEG or PNG only; None when there is none, it is
    a link (never fetched), or it cannot be read. vCard 3.0 (PHOTO;ENCODING=b) and 4.0 (a data: URI)."""
    import base64
    import binascii

    for name, params, value in _properties(text):
        if name != "PHOTO":
            continue
        value = value.strip()
        encoded = None
        if value.lower().startswith("data:"):
            meta, _, rest = value[5:].partition(",")
            if ";base64" in meta.lower():
                encoded = rest
        elif re.search(r"(?i)(?:^|;)\s*ENCODING\s*=\s*\"?(?:b|base64)\"?\s*(?:;|$)", params):
            encoded = value
        if not encoded:
            continue
        try:
            data = base64.b64decode(re.sub(r"\s+", "", encoded), validate=True)
        except (binascii.Error, ValueError):
            continue
        kind = image_type(data)
        if kind is not None and len(data) <= MAX_PHOTO_BYTES:
            return data, kind
    return None
