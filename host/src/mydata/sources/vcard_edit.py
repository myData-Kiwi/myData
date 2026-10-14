"""Edit a vCard as content lines, so that whatever an edit does not touch is written back exactly as it came.

vobject and icalendar re-serialise a whole card and lose things on the way (tested: vobject dropped the
second value of NICKNAME:JJ,Janie and unfolded PHOTO; icalendar's vCard support drops TYPE parameters). This
module never re-serialises a card. It splits the card into content lines, keeping each line's original text
(its folding, its case, its line endings, a vCard 2.1 quoted-printable soft break), and writes back:

- every line the edit did not touch, byte for byte;
- the lines it changed or added, folded at 75 octets, with the card's own line ending;
- REV, set to the time of the edit, when anything changed.

Apple's item groups (`item1.EMAIL` with `item1.X-ABLabel:_$!<Work>!$_`): a new labelled value takes the next
number above the highest one present, and removing a value removes its label (and its X-ABADR).

Versions:
- 3.0 (iCloud, This Mac, Google): edited as it is. New cards are 3.0, with a UID.
- 4.0: edited as it is; KIND, MEMBER and anything else this module does not know are kept.
- 2.1 (Samsung): read, with quoted-printable soft breaks joined, but never edited in place: upgrade_21()
  turns it into 3.0 for an import, and the import keeps the original text separately (`origins.source_raw`).

convert() moves a card between versions for the export, changing only the lines that differ.

Values: set() and add() take the value as plain text and escape it for the property (a list for compound
properties such as N and ADR, and for NICKNAME and CATEGORIES); Raw marks a value already in vCard syntax.
"""

from __future__ import annotations

import base64
import binascii
import quopri
import re
import uuid
from collections.abc import Sequence
from datetime import datetime, timezone

PRODID = "-//myData//vCard editor//EN"
FOLD_OCTETS = 75

# One physical line with its ending (CRLF, LF or a lone CR), or a last line without one.
_PHYSICAL = re.compile(r"[^\r\n]*(?:\r\n|\n|\r)|[^\r\n]+\Z")
_ITEM = re.compile(r"(?i)^item(\d+)$")
_NAME = re.compile(r"[A-Za-z0-9-]+")
# Control characters a parameter value may not hold (RFC 6350 3.3: tab is the only one allowed; a line break is
# written ^n, RFC 6868).
_PARAM_CTL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")

# How a value is written: each part of a compound value escaped, a comma-separated list of texts, or as given
# (URIs, dates, numbers, identifiers: escaping would change them). Every other property is text.
COMPOUND = {"N", "ADR", "ORG", "GENDER", "CLIENTPIDMAP", "X-ANDROID-CUSTOM"}
TEXT_LIST = {"NICKNAME", "CATEGORIES"}
VERBATIM = {"VERSION", "PRODID", "UID", "REV", "KIND", "X-ADDRESSBOOKSERVER-KIND", "X-ABSHOWAS", "TEL", "EMAIL",
            "URL", "PHOTO", "LOGO", "SOUND", "KEY", "MEMBER", "X-ADDRESSBOOKSERVER-MEMBER", "IMPP",
            "X-SOCIALPROFILE", "SOURCE", "FBURL", "CALURI", "CALADRURI", "GEO", "TZ", "LANG", "BDAY",
            "ANNIVERSARY", "X-ABDATE", "X-ABUID"}
# Properties of a 2.1 card whose values are text (their commas become escaped in 3.0).
_TEXT_21 = {"FN", "NOTE", "TITLE", "ROLE", "LABEL", "NICKNAME", "X-ABLABEL", "MAILER", "SORT-STRING"}
# What else an Apple item group may hold beside its value: removing the value removes these.
_GROUP_COMPANIONS = {"X-ABLABEL", "X-ABADR"}
_ENCODINGS_21 = {"QUOTED-PRINTABLE", "BASE64", "B", "8BIT", "7BIT"}


class VCardError(ValueError):
    """The text is not one vCard this module can edit, or the edit is not allowed."""


class Raw(str):
    """A value already in vCard syntax (escaped as the property needs), written as given."""


# ---------------------------------------------------------------- content-line syntax

def escape_text(text: str) -> str:
    r"""A text value as vCard 3.0 and 4.0 write it: \\ \, \; and \n."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return text.replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;").replace("\n", "\\n")


def unescape_text(value: str) -> str:
    r"""A text value with its escapes undone: \n or \N is a line break; \, \; \: and \\ are the character."""
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


def split_unescaped(value: str, sep: str) -> list[str]:
    """Split a raw value at each `sep` not escaped by a backslash; the parts keep their escapes."""
    parts, current, i = [], [], 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            current.append(value[i:i + 2])
            i += 2
            continue
        if ch == sep:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    parts.append("".join(current))
    return parts


def _split_quoted(text: str, sep: str) -> list[str]:
    """Split at `sep` outside double quotes (parameter syntax)."""
    parts, current, quoted = [], [], False
    for ch in text:
        if ch == '"':
            quoted = not quoted
        if ch == sep and not quoted:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    parts.append("".join(current))
    return parts


def value_colon(line: str) -> int:
    """Where the value starts: the first ':' outside a quoted parameter value; -1 if none."""
    quoted = False
    for i, ch in enumerate(line):
        if ch == '"':
            quoted = not quoted
        elif ch == ":" and not quoted:
            return i
    return -1


def fold(line: str, newline: str = "\r\n") -> str:
    """One content line folded at 75 octets (RFC 6350 3.2, RFC 5545 3.1), never inside a UTF-8 character, with
    its line ending."""
    out, current, size = [], "", 0
    for ch in line:
        n = len(ch.encode("utf-8"))
        if size + n > FOLD_OCTETS and current.strip():
            out.append(current)
            current, size = " " + ch, 1 + n
        else:
            current += ch
            size += n
    out.append(current)
    return newline.join(out) + newline


def _caret_encode(value: str) -> str:
    """A parameter value with ^, " and line breaks written as RFC 6868 says (^^, ^' and ^n)."""
    return value.replace("^", "^^").replace('"', "^'").replace("\n", "^n")


def _caret_decode(value: str) -> str:
    """RFC 6868 undone: ^n is a line break, ^' a double quote, ^^ a caret; any other ^ is itself."""
    return re.sub(r"\^([n'^])", lambda m: {"n": "\n", "'": '"', "^": "^"}[m.group(1)], value)


def _quote_param(value: str) -> str:
    value = _caret_encode(value)
    return f'"{value}"' if any(c in value for c in ':;,') else value


def check_prop(group: str, name: str, params: Sequence[tuple[str | None, list[str]]]) -> None:
    """Refuse (VCardError) what would not stay one content line as written: a name or group that is not
    letters, digits and '-', a parameter name likewise, or a parameter value with a control character other
    than a tab or a line break (which is written ^n). A double quote and ^ are written as RFC 6868 says."""
    for label, text in (("property name", name), ("group", group)):
        if (text or label == "property name") and not _NAME.fullmatch(text or ""):
            raise VCardError(f"a {label} may hold only letters, digits and '-'")
    for pname, values in params:
        if pname is None:
            if len(values) != 1 or not _NAME.fullmatch(values[0]):
                raise VCardError("a parameter without a name is one word of letters, digits and '-'")
            continue
        if not _NAME.fullmatch(pname):
            raise VCardError("a parameter name may hold only letters, digits and '-'")
        if not values:
            raise VCardError(f"parameter {pname} has no value")
        for value in values:
            if not isinstance(value, str):
                raise VCardError(f"parameter {pname} values must be text")
            if _PARAM_CTL.search(value):
                raise VCardError(f"parameter {pname} cannot hold a control character")


def _unquote(value: str) -> str:
    return value[1:-1] if len(value) >= 2 and value[0] == value[-1] == '"' else value


# ---------------------------------------------------------------- one property

class Prop:
    """One content line: `group.NAME;params:value`.

    `value` is the unfolded value as written (escapes kept; a quoted-printable value with its soft breaks
    joined). `raw` is the line's original text with its line endings and folding, or None once the line was
    changed or when it is new; only lines with a raw text are copied as they came."""

    __slots__ = ("group", "name", "params", "value", "raw")

    def __init__(self, group: str, name: str, params: list[tuple[str | None, list[str]]], value: str,
                 raw: str | None = None):
        self.group = group
        self.name = name
        self.params = params  # (name, values) in order; name None for a vCard 2.1 bare value (TEL;CELL)
        self.value = value
        self.raw = raw

    def __repr__(self) -> str:
        return f"Prop({self.render()!r})"

    @property
    def key(self) -> str:
        return self.name.upper()

    def param(self, name: str) -> list[str]:
        """Every value of a parameter (case ignored), unquoted and with RFC 6868's carets undone; quoted lists
        stay one value."""
        name = name.upper()
        return [v for n, values in self.params if n is not None and n.upper() == name for v in values]

    @property
    def types(self) -> list[str]:
        """TYPE values, lower case, quoted lists split, vCard 2.1 bare values included."""
        out = []
        for n, values in self.params:
            if n is None:
                if values[0].upper() not in _ENCODINGS_21:
                    out.append(values[0].lower())
            elif n.upper() == "TYPE":
                out.extend(t.strip().lower() for v in values for t in v.split(",") if t.strip())
        return out

    @property
    def encoding(self) -> str:
        """QUOTED-PRINTABLE, B, BASE64 (upper case), or "" for none."""
        for n, values in self.params:
            if n is None and values[0].upper() in _ENCODINGS_21:
                return values[0].upper()
            if n is not None and n.upper() == "ENCODING" and values:
                return values[0].upper()
        return ""

    def decoded(self) -> str:
        """The value with a quoted-printable encoding undone (in its CHARSET, else UTF-8); escapes kept."""
        if self.encoding != "QUOTED-PRINTABLE":
            return self.value
        data = quopri.decodestring(self.value.encode("utf-8"))
        for charset in [*self.param("CHARSET"), "utf-8"]:
            try:
                return data.decode(charset)
            except (LookupError, UnicodeDecodeError):
                continue
        return data.decode("latin-1")

    def text(self) -> str:
        """The value as plain text (escapes undone)."""
        return unescape_text(self.decoded())

    def parts(self) -> list[str]:
        """The parts of a compound value (N, ADR, ORG) as plain text."""
        return [unescape_text(p) for p in split_unescaped(self.decoded(), ";")]

    def render(self) -> str:
        """The unfolded content line (for a changed or new line)."""
        head = f"{self.group}.{self.name}" if self.group else self.name
        for n, values in self.params:
            head += ";" + (values[0] if n is None else n + "=" + ",".join(_quote_param(v) for v in values))
        return head + ":" + self.value

    def touch(self) -> None:
        self.raw = None


def _parse_prop(unfolded: str, raw: str) -> Prop | None:
    colon = value_colon(unfolded)
    if colon < 0:
        return None
    head, value = unfolded[:colon], unfolded[colon + 1:]
    tokens = _split_quoted(head, ";")
    group, _, name = tokens[0].strip().rpartition(".")
    if not name:
        return None
    params: list[tuple[str | None, list[str]]] = []
    for token in tokens[1:]:
        if "=" in token:
            pname, pvalue = token.split("=", 1)
            params.append((pname.strip(), [_caret_decode(_unquote(v)) for v in _split_quoted(pvalue, ",")]))
        elif token:
            params.append((None, [token.strip()]))
    return Prop(group, name, params, value, raw)


def parse_line(unfolded: str) -> Prop | None:
    """One unfolded content line (vCard or iCalendar) as a Prop; None when it has no name or no value."""
    return _parse_prop(unfolded, None)


def _is_qp(first_line: str) -> bool:
    colon = value_colon(first_line)
    head = (first_line[:colon] if colon >= 0 else first_line).upper()
    return "QUOTED-PRINTABLE" in head


class _Line:
    """A logical line being joined: its pieces (unfolded) and physical lines, kept as lists so a value folded
    over many thousands of lines (a photo) is joined once, and its header (the text before the first ':' outside
    quotes) read as the pieces come, never the whole value again."""

    __slots__ = ("pieces", "raws", "head", "head_done", "quoted")

    def __init__(self) -> None:
        self.pieces: list[str] = []
        self.raws: list[str] = []
        self.head: list[str] = []
        self.head_done = False
        self.quoted = False

    def add(self, piece: str, phys: str) -> None:
        self.pieces.append(piece)
        self.raws.append(phys)
        if self.head_done:
            return
        for i, ch in enumerate(piece):
            if ch == '"':
                self.quoted = not self.quoted
            elif ch == ":" and not self.quoted:
                self.head.append(piece[:i])
                self.head_done = True
                return
        self.head.append(piece)

    def is_qp(self) -> bool:
        return "QUOTED-PRINTABLE" in "".join(self.head).upper()


def _logical_lines(text: str, *, keep_fold_space: bool = False) -> list[tuple[str, str]]:
    """(unfolded line, original text with endings) for each content line. A folded line (the next one starts
    with a space or tab) and a vCard 2.1 quoted-printable soft break (a value line ending in "=") are joined;
    a blank line is kept with the line before it. Unfolding drops the space or tab that starts a folded line
    (3.0, 4.0), or keeps it with keep_fold_space (2.1 folds as RFC 822 does: the line break alone goes)."""
    out: list[_Line] = []
    qp = qp_open = False
    for phys in _PHYSICAL.findall(text):
        content = phys.rstrip("\r\n")
        if out and qp_open:
            line = out[-1]
            line.pieces[-1] = line.pieces[-1][:-1]
            line.add(content, phys)
        elif out and content[:1] in (" ", "\t"):
            line = out[-1]
            line.add(content if keep_fold_space else content[1:], phys)
            qp = line.is_qp()  # ENCODING=QUOTED-PRINTABLE can be on a folded part of the header
        elif content.strip() == "":
            if out:
                out[-1].raws.append(phys)
            else:
                line = _Line()
                line.raws.append(phys)
                line.pieces.append("")
                out.append(line)
            qp = False
        else:
            line = _Line()
            line.add(content, phys)
            out.append(line)
            qp = line.is_qp()
        qp_open = qp and content.endswith("=")
    return [("".join(line.pieces), "".join(line.raws)) for line in out]


def _newline(text: str) -> str:
    m = re.search(r"\r\n|\n|\r", text)
    return m.group(0) if m else "\r\n"


# ---------------------------------------------------------------- one card

_KEEP = object()


class VCard:
    """One card: its content lines between BEGIN:VCARD and END:VCARD. Lines this module cannot read (no colon,
    a nested card) are kept as text and copied."""

    def __init__(self, text: str, lead: str, begin: str, items: list, end: str, tail: str):
        self._source = text
        self._lead, self._begin, self._end, self._tail = lead, begin, end, tail
        self.items: list[Prop | str] = items
        self.newline = _newline(begin or text)
        self.changed = False

    # -- reading

    @classmethod
    def parse(cls, text: str) -> VCard:
        cards = _cards(text)
        if len(cards) != 1:
            raise VCardError(f"expected one vCard, found {len(cards)}")
        return cards[0]

    def props(self, name: str | None = None) -> list[Prop]:
        key = name.upper() if name else None
        return [p for p in self.items if isinstance(p, Prop) and (key is None or p.key == key)]

    def first(self, name: str) -> Prop | None:
        found = self.props(name)
        return found[0] if found else None

    @property
    def version(self) -> str:
        p = self.first("VERSION")
        return p.value.strip() if p else ""

    def group_members(self, group: str) -> list[Prop]:
        g = group.lower()
        return [p for p in self.props() if p.group and p.group.lower() == g]

    def label(self, prop: Prop) -> str | None:
        """The X-ABLabel of the property's item group, as text (Apple's own labels keep their _$!<...>!$_)."""
        if not prop.group:
            return None
        return next((p.text() for p in self.group_members(prop.group) if p.key == "X-ABLABEL"), None)

    def next_item(self) -> str:
        """The next free Apple item group: one above the highest itemN present."""
        numbers = [int(m.group(1)) for p in self.props() if p.group and (m := _ITEM.match(p.group))]
        return f"item{max(numbers, default=0) + 1}"

    # -- editing

    def _mark(self) -> None:
        self.changed = True

    def _index(self, prop: Prop) -> int:
        for i, item in enumerate(self.items):
            if item is prop:
                return i
        raise VCardError("that property is not in this card")

    def _insert(self, prop: Prop, after: Prop | None = None) -> None:
        if after is not None:
            self.items.insert(self._index(after) + 1, prop)
        else:
            self.items.append(prop)
        self._mark()

    def add(self, name: str, value, params: Sequence[tuple[str | None, list[str]]] = (), *,
            label: str | None = None, group: str = "") -> Prop:
        """Add a property at the end of the card. With a label it goes in a new Apple item group, followed by
        that group's X-ABLabel."""
        if label is not None and not group:
            group = self.next_item()
        params = [(n, list(v)) for n, v in params]
        check_prop(group, name, params)
        prop = Prop(group, name, params, encode(name, value))
        self._insert(prop)
        if label is not None:
            self._insert(Prop(group, "X-ABLabel", [], escape_text(label)), after=prop)
        return prop

    def update(self, prop: Prop, value=_KEEP, params: Sequence[tuple[str | None, list[str]]] | None = None, *,
               name: str | None = None) -> Prop:
        """Change a property in place (its position and group are kept): its value, its parameters, its name.
        A new value given without parameters drops the old value's ENCODING and CHARSET (and a 2.1 bare
        QUOTED-PRINTABLE or BASE64): the new value is written as plain text."""
        self._index(prop)
        new_value = prop.value if value is _KEEP else encode(name or prop.name, value)
        if params is not None:
            new_params = [(n, list(v)) for n, v in params]
        elif value is not _KEEP:
            # The new value is plain 3.0/4.0 text: an encoding or charset kept from the old one would misread it
            # (a quoted-printable value ending in "=" would swallow the next line; a link would be read as base64).
            new_params = [(n, v) for n, v in prop.params
                          if not (n is None and v[0].upper() in _ENCODINGS_21)
                          and not (n is not None and n.upper() in ("ENCODING", "CHARSET"))]
        else:
            new_params = prop.params
        new_name = name or prop.name
        if params is not None or name is not None:
            check_prop("", new_name, new_params)
        if any(n is not None and n.upper() == "ENCODING" and any(x.upper() == "QUOTED-PRINTABLE" for x in v)
               or n is None and v[0].upper() == "QUOTED-PRINTABLE" for n, v in new_params) and new_value != prop.value:
            raise VCardError("a value is never written quoted-printable")
        if (new_value, new_params, new_name) != (prop.value, prop.params, prop.name):
            prop.value, prop.params, prop.name = new_value, new_params, new_name
            prop.touch()
            self._mark()
        return prop

    def set(self, name: str, value, params: Sequence[tuple[str | None, list[str]]] | None = None) -> Prop:
        """The card's one `name` property becomes this value: the first one is changed in place (keeping its
        parameters unless new ones are given), any others are removed; added if there is none."""
        existing = self.props(name)
        if not existing:
            return self.add(name, value, params or ())
        for other in existing[1:]:
            self.remove(other)
        return self.update(existing[0], value, params)

    def remove(self, prop_or_name: Prop | str) -> None:
        """Remove a property (or every property of that name), and the label of an item group left with no
        value."""
        props = self.props(prop_or_name) if isinstance(prop_or_name, str) else [prop_or_name]
        for prop in props:
            del self.items[self._index(prop)]
            self._mark()
            if prop.group:
                rest = self.group_members(prop.group)
                if rest and all(p.key in _GROUP_COMPANIONS for p in rest):
                    for p in rest:
                        del self.items[self._index(p)]

    def set_label(self, prop: Prop, label: str | None) -> None:
        """Give a property an Apple label (moving it into a new item group if it has none), or remove it."""
        self._index(prop)
        current = next((p for p in self.group_members(prop.group) if p.key == "X-ABLABEL"), None) \
            if prop.group else None
        if label is None:
            if current is not None:
                del self.items[self._index(current)]
                self._mark()
            return
        if current is not None:
            self.update(current, label)
            return
        if not prop.group:
            prop.group = self.next_item()
            prop.touch()
        self._insert(Prop(prop.group, "X-ABLabel", [], escape_text(label)), after=prop)

    def set_photo(self, data: bytes, media_type: str) -> Prop:
        """The card's photo, embedded: `PHOTO;ENCODING=b;TYPE=JPEG` in 3.0, a data: URI in 4.0."""
        subtype = media_type.split("/", 1)[-1]
        encoded = base64.b64encode(data).decode("ascii")
        if self.version == "4.0":
            return self.set("PHOTO", Raw(f"data:{media_type};base64,{encoded}"), [])
        return self.set("PHOTO", Raw(encoded), [("ENCODING", ["b"]), ("TYPE", [subtype.upper()])])

    # -- writing

    def to_text(self, *, now: datetime | None = None, bump_rev: bool = True) -> str:
        """The card as text. Unchanged, it is exactly the text it was read from. Changed, every untouched line
        is copied as it came, and REV is set to `now` (default: the current time) unless bump_rev is False."""
        if not self.changed:
            return self._source
        if self.version == "2.1":
            raise VCardError("a vCard 2.1 is never edited in place: convert it with upgrade_21() first")
        if bump_rev:
            stamp = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
            rev = stamp.strftime("%Y%m%dT%H%M%SZ" if self.version == "4.0" else "%Y-%m-%dT%H:%M:%SZ")
            self.set("REV", Raw(rev), [])
        body = "".join(item if isinstance(item, str) else
                       item.raw if item.raw is not None else fold(item.render(), self.newline)
                       for item in self.items)
        return self._lead + self._begin + body + self._end + self._tail


def encode(name: str, value) -> str:
    """A value in the property's syntax (see the module docstring). Raises VCardError for a line break in a
    value that cannot hold one."""
    key = name.upper()
    if isinstance(value, Raw):
        text = str(value)
    elif isinstance(value, (list, tuple)):
        if key in TEXT_LIST:
            text = ",".join(escape_text(v) for v in value)
        else:
            text = ";".join(",".join(escape_text(x) for x in part) if isinstance(part, (list, tuple))
                            else escape_text(part) for part in value)
    elif not isinstance(value, str):
        raise TypeError(f"{name} value must be text or a list, not {type(value).__name__}")
    elif key in COMPOUND:
        raise VCardError(f"{name} is a compound value: give its parts as a list")
    elif key in VERBATIM:
        text = value
    else:
        text = escape_text(value)
    if "\r" in text or "\n" in text:
        raise VCardError(f"{name} cannot hold a line break")
    return text


def _cards(text: str) -> list[VCard]:
    lines = _logical_lines(text)
    offsets = [0]
    for _u, r in lines:
        offsets.append(offsets[-1] + len(r))
    cards: list[VCard] = []
    i, lead = 0, ""
    while i < len(lines):
        unfolded, raw = lines[i]
        if unfolded.strip().lstrip("\ufeff").upper() != "BEGIN:VCARD":  # a byte-order mark is not text
            if unfolded.strip():
                raise VCardError("text outside a vCard")
            lead += raw
            i += 1
            continue
        begin, items, depth, j = raw, [], 0, i + 1
        end = None
        while j < len(lines):
            u, r = lines[j]
            upper = u.strip().upper()
            if upper.startswith("BEGIN:"):
                depth += 1
            elif upper.startswith("END:"):
                if depth == 0:
                    if upper != "END:VCARD":
                        raise VCardError(f"unexpected {u.strip()}")
                    end = r
                    break
                depth -= 1
            prop = _parse_prop(u, r) if depth == 0 and not upper.startswith("END:") else None
            items.append(prop if prop is not None else r)
            j += 1
        if end is None:
            raise VCardError("a vCard without END:VCARD")
        start, stop = offsets[i] - len(lead), offsets[j + 1]
        cards.append(VCard(text[start:stop], lead, begin, items, end, ""))
        lead = ""
        i = j + 1
    if lead and cards:
        cards[-1]._tail = lead
        cards[-1]._source += lead
    if not cards:
        raise VCardError("no vCard found")
    return cards


def split_cards(text: str) -> list[VCard]:
    """Every card of a .vcf file, in order. Each card's text is its own lines, as they came."""
    return _cards(text)


def new_card(full_name: str, *, given: str = "", family: str = "", uid: str | None = None) -> VCard:
    """A new vCard 3.0 with N, FN and a UID (a random UUID unless given). REV is set when it is written."""
    lines = ["BEGIN:VCARD", "VERSION:3.0", f"PRODID:{PRODID}",
             "N:" + encode("N", [family, given, "", "", ""]), "FN:" + encode("FN", full_name),
             "UID:" + encode("UID", uid or str(uuid.uuid4()).upper()), "END:VCARD"]
    card = VCard.parse("".join(fold(line) for line in lines))
    card.changed = True
    return card


# ---------------------------------------------------------------- versions

def _from_21(key: str, text: str) -> str:
    r"""A vCard 2.1 value (decoded) in 3.0 syntax. 2.1 escapes only \; and uses ; between parts."""
    if key in _TEXT_21:
        return escape_text(text.replace("\\;", ";"))
    return ";".join(escape_text(part.replace("\\;", ";")) for part in split_unescaped(text, ";"))


def upgrade_21(text: str) -> str:
    """A vCard 2.1 as 3.0, for an import (which keeps the 2.1 text as the original): quoted-printable values
    decoded (in their CHARSET) and escaped as 3.0 text, bare parameters (TEL;CELL;PREF) written as TYPE,
    ENCODING=BASE64 as ENCODING=b, CHARSET dropped (3.0 is UTF-8), FN and N added when missing (3.0 needs
    both). Lines that need none of this are copied as they came; REV is not changed."""
    card = VCard.parse(text)
    if card.version != "2.1":
        raise VCardError(f"not a vCard 2.1 (VERSION {card.version or 'missing'})")
    depth = 0
    for item in card.items:
        if isinstance(item, Prop):
            if item.raw is not None and len(_PHYSICAL.findall(item.raw.rstrip("\r\n \t"))) > 1:
                # a folded 2.1 line: unfolded keeping the space that starts each folded part, and written again
                again = _parse_prop(_logical_lines(item.raw, keep_fold_space=True)[0][0], None)
                if again is not None:
                    item.value, item.params = again.value, again.params
                item.touch()
            continue
        head = item.strip().upper()
        if head.startswith("BEGIN:"):
            depth += 1
        elif head.startswith("END:"):
            depth -= 1
        elif depth == 0 and head:
            raise VCardError("the vCard 2.1 has a line that is not a property")
    for prop in card.props():
        if prop.key == "VERSION":
            card.update(prop, Raw("3.0"))
            continue
        encoding = prop.encoding
        types: list[str] = []
        params: list[tuple[str | None, list[str]]] = []
        for n, values in prop.params:
            if n is None:
                if values[0].upper() not in _ENCODINGS_21:
                    types.append(values[0])
            elif n.upper() not in ("ENCODING", "CHARSET"):
                params.append((n, values))
        if types:
            params.insert(0, ("TYPE", types))
        value = prop.value
        if encoding == "QUOTED-PRINTABLE":
            value = _from_21(prop.key, prop.decoded())
        elif encoding in ("BASE64", "B"):
            value = re.sub(r"\s+", "", value)
            params.insert(0, ("ENCODING", ["b"]))
        elif prop.key in _TEXT_21 or prop.key in COMPOUND:
            value = _from_21(prop.key, value)
        card.update(prop, Raw(value), params)
    if card.first("FN") is None:
        n = card.first("N")
        parts = n.parts() if n else []
        name = " ".join(p for p in (parts[1:2] + parts[:1]) if p.strip()) if parts else ""
        if not name and card.first("ORG"):
            name = card.first("ORG").parts()[0]
        card.add("FN", name)
    if card.first("N") is None:
        card.add("N", ["", "", "", "", ""])
    return card.to_text(bump_rev=False)


_APPLE_NO_YEAR = "1604"  # the year Apple writes, with X-APPLE-OMIT-YEAR, for a birthday without one


def _to_30(card: VCard) -> None:
    for prop in card.props():
        key = prop.key
        if key == "VERSION":
            card.update(prop, Raw("3.0"))
        elif key == "KIND":
            kind = prop.text().strip().lower()
            if kind == "group":
                card.update(prop, Raw("group"), [], name="X-ADDRESSBOOKSERVER-KIND")
            elif kind in ("org", "organization"):
                card.update(prop, Raw("COMPANY"), [], name="X-ABShowAs")
            elif kind == "individual":
                card.remove(prop)
                continue
        elif key == "MEMBER":
            card.update(prop, name="X-ADDRESSBOOKSERVER-MEMBER")
        elif key in _BINARY and prop.value.lower().startswith("data:"):
            meta, _, data = prop.value[5:].partition(",")
            if ";base64" in meta.lower():
                subtype = meta.split(";", 1)[0].split("/", 1)[-1].upper() or "JPEG"
                card.update(prop, Raw(data), [("ENCODING", ["b"]), ("TYPE", [subtype])])
            else:
                card.update(prop, params=[*_without(prop.params, "VALUE"), ("VALUE", ["uri"])])
        elif key in _BINARY and _URI.match(prop.value.strip()) and not prop.encoding and (
                prop.param("MEDIATYPE") or not any(v.lower() == "uri" for v in prop.param("VALUE"))):
            # 3.0 reads these as binary unless told otherwise; 4.0's MEDIATYPE is 3.0's TYPE
            params = _without(_without(prop.params, "VALUE"), "MEDIATYPE")
            media = prop.param("MEDIATYPE")
            if media and not prop.types:
                params.append(("TYPE", [media[0].split("/", 1)[-1].upper()]))
            card.update(prop, params=[*params, ("VALUE", ["uri"])])
        elif key in ("BDAY", "ANNIVERSARY"):
            v = prop.value.strip()
            if m := re.fullmatch(r"--(\d{2})-?(\d{2})", v):
                card.update(prop, Raw(f"{_APPLE_NO_YEAR}-{m.group(1)}-{m.group(2)}"),
                            [*_without(prop.params, "VALUE"), ("X-APPLE-OMIT-YEAR", [_APPLE_NO_YEAR])])
            elif m := re.fullmatch(r"(\d{4})(\d{2})(\d{2})", v):
                card.update(prop, Raw(f"{m.group(1)}-{m.group(2)}-{m.group(3)}"), _without(prop.params, "VALUE"))
        if key == "TEL" and any(v.lower() == "uri" for v in prop.param("VALUE")):
            v = prop.value
            card.update(prop, Raw(v[4:] if v.lower().startswith("tel:") else v), _without(prop.params, "VALUE"))
        if prop.param("PREF"):
            pref = prop.param("PREF")[0].strip() == "1"
            params = _without(prop.params, "PREF")
            if pref and "pref" not in prop.types:
                params.append(("TYPE", ["pref"]))
            card.update(prop, params=params)
    if card.first("N") is None:
        fn = card.first("FN")
        group = card.first("X-ADDRESSBOOKSERVER-KIND")
        family = fn.text() if fn is not None and group is not None else ""
        card.add("N", [family, "", "", "", ""])


def _to_40(card: VCard) -> None:
    version = card.first("VERSION")
    for prop in card.props():
        key = prop.key
        if key == "VERSION":
            card.update(prop, Raw("4.0"))
        elif key == "X-ADDRESSBOOKSERVER-KIND":
            card.update(prop, name="KIND")
        elif key == "X-ADDRESSBOOKSERVER-MEMBER":
            card.update(prop, name="MEMBER")
        elif key == "X-ABSHOWAS" and prop.text().strip().upper() == "COMPANY" and card.first("KIND") is None:
            card.add("KIND", Raw("org"))
        elif key in ("PHOTO", "LOGO") and prop.encoding in ("B", "BASE64"):
            data = re.sub(r"\s+", "", prop.value)
            subtype = next((t for t in prop.types), None) or _image_type(data)
            card.update(prop, Raw(f"data:image/{subtype};base64,{data}"),
                        [p for p in prop.params if p[0] is not None and p[0].upper() not in ("ENCODING", "TYPE")])
        elif key in ("BDAY", "ANNIVERSARY", "X-ABDATE"):
            omit = prop.param("X-APPLE-OMIT-YEAR")
            m = re.fullmatch(r"(\d{4})-?(\d{2})-?(\d{2})", prop.value.strip())
            if omit and m and m.group(1) == omit[0]:
                card.update(prop, Raw(f"--{m.group(2)}{m.group(3)}"), _without(prop.params, "X-APPLE-OMIT-YEAR"))
            elif key != "X-ABDATE" and (basic := _basic(prop.value.strip())) is not None:
                card.update(prop, Raw(basic))
        elif key == "REV" and (basic := _basic(prop.value.strip())) is not None:
            card.update(prop, Raw(basic))
        if "pref" in prop.types:
            params = []
            for n, values in prop.params:
                if n is not None and n.upper() == "TYPE":
                    values = [v for v in values if v.lower() != "pref"]
                    if not values:
                        continue
                params.append((n, values))
            params.append(("PREF", ["1"]))
            card.update(prop, params=params)
    if version is not None and card.items[0] is not version:  # 4.0 wants VERSION right after BEGIN
        card.items.remove(version)
        card.items.insert(0, version)
        version.touch()


# Properties 3.0 reads as binary (ENCODING=b) unless VALUE=uri says otherwise.
_BINARY = ("PHOTO", "LOGO", "SOUND", "KEY")
_URI = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*:")
# A date or date-time in ISO 8601's extended format (3.0 writes it; 4.0 allows only the basic one).
_EXTENDED = re.compile(r"(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?(?:[.,]\d+)?"
                       r"(Z|[+-]\d{2}(?::?\d{2})?)?)?")
_MAGIC = ((b"\x89PNG", "png"), (b"\xff\xd8\xff", "jpeg"), (b"GIF8", "gif"))


def _basic(value: str) -> str | None:
    """A date or date-time in ISO 8601's basic format (19850412, 20260101T000000Z); None when it is not one in
    the extended format (already basic, or something else: left as it is)."""
    m = _EXTENDED.fullmatch(value)
    if not m:
        return None
    day = m.group(1) + m.group(2) + m.group(3)
    if m.group(4) is None:
        return day
    return f"{day}T{m.group(4)}{m.group(5)}{m.group(6) or '00'}{(m.group(7) or '').replace(':', '')}"


def _image_type(data: str) -> str:
    """The image type of base64 data, from its first bytes (JPEG when unknown)."""
    try:
        head = base64.b64decode(data[:16] + "=" * (-len(data[:16]) % 4))
    except (binascii.Error, ValueError):
        return "jpeg"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    return next((name for magic, name in _MAGIC if head.startswith(magic)), "jpeg")


def _without(params: list[tuple[str | None, list[str]]], name: str) -> list[tuple[str | None, list[str]]]:
    return [(n, v) for n, v in params if n is None or n.upper() != name.upper()]


def convert(text: str, version: str) -> str:
    """One card in another vCard version ("3.0" or "4.0"), changing only the lines that differ between them
    (VERSION; KIND and MEMBER against Apple's X-ADDRESSBOOKSERVER-KIND and -MEMBER; an embedded PHOTO; a link
    in PHOTO, LOGO, SOUND or KEY, which 3.0 marks VALUE=uri; PREF against TYPE=pref; a birthday without a year;
    dates and REV, which 4.0 writes in the basic format; a tel: URI). Everything else is copied as it came, and a card
    already in that version is returned unchanged. REV is not changed: the card's content is the same."""
    if version not in ("3.0", "4.0"):
        raise VCardError(f"cannot write vCard {version}")
    card = VCard.parse(text)
    current = card.version
    if current == version:
        return text
    if current == "2.1":
        text = upgrade_21(text)
        if version == "3.0":
            return text
        card, current = VCard.parse(text), "3.0"
    if (current, version) == ("3.0", "4.0"):
        _to_40(card)
    elif (current, version) == ("4.0", "3.0"):
        _to_30(card)
    else:
        raise VCardError(f"cannot convert a vCard {current or 'without VERSION'} to {version}")
    return card.to_text(bump_rev=False)


def photo_bytes(prop: Prop) -> bytes | None:
    """The bytes of an embedded PHOTO (3.0 ENCODING=b or a 4.0 data: URI); None for a link or bad data."""
    value = prop.value.strip()
    if value.lower().startswith("data:"):
        meta, _, value = value[5:].partition(",")
        if ";base64" not in meta.lower():
            return None
    elif prop.encoding not in ("B", "BASE64"):
        return None
    try:
        return base64.b64decode(re.sub(r"\s+", "", value), validate=True)
    except (binascii.Error, ValueError):
        return None
