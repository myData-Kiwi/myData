"""A contact's editable fields, read from and written to its vCard through the line editor (vcard_edit).

The apps edit a contact as a form: names, nickname, company, department, job title, phones, emails, postal
addresses, links, birthday and a note. read() gives a card's values in that shape; check() validates a form
lightly, one message per field; apply() writes a form onto a card, changing only the lines whose values
differ, so every other line of the card (photos, groups' membership by UID, custom fields, its folding)
stays byte for byte as it was. Nothing here reads or writes a database.

Fields, as the API names them:

- given_name, family_name, middle_name, name_prefix, name_suffix: the parts of N (FN is written again from
  them, or from the company when there is no name, whenever one of them changes);
- nickname (one text: commas in it stay part of it), company and department (ORG's first two parts),
  job_title (TITLE), note (NOTE; line breaks kept);
- birthday: "YYYY-MM-DD", or "--MM-DD" without a year (a 3.0 card writes that as Apple does,
  1604-MM-DD with X-APPLE-OMIT-YEAR=1604);
- phones, emails, urls: [{label, value}]; addresses: [{label, street, locality, region, postal_code,
  country}].

A label is one the sources use (mobile, iphone, home, work, main, fax, pager, other, school, and Apple's
homepage, homefax, workfax, otherfax), in any case or as the apps show it ("Home fax"), or any other text,
kept exactly as typed. Built-in labels are written as TYPE (or, on a value that already has an Apple label
line, as Apple's _$!<Label>!$_); other text goes in an Apple item group's X-ABLabel. Read back, the label is
what the mirror's parser reports (vcard.py), so a value whose label and text did not change is never
rewritten.

A list is matched to the card's lines first by equal (label, value), which stay untouched; the rest are
paired in order and changed in place, and what is left over is removed or added. A reordering alone is not
written: the card keeps its order.
"""

from __future__ import annotations

import re
from datetime import date

from .vcard import _TYPE_LABELS, _apple_label, _phone_value
from .vcard_edit import _APPLE_NO_YEAR, Prop, Raw, VCard, VCardError, split_unescaped, unescape_text

NAME_FIELDS = ("family_name", "given_name", "middle_name", "name_prefix", "name_suffix")  # N's order
TEXT_FIELDS = (*NAME_FIELDS, "nickname", "company", "department", "job_title", "birthday", "note")
LIST_FIELDS = ("phones", "emails", "urls", "addresses")
FIELDS = (*TEXT_FIELDS, *LIST_FIELDS)
ADDRESS_PARTS = ("street", "locality", "region", "postal_code", "country")

MAX_TEXT = 1000
MAX_NOTE = 20000
MAX_LABEL = 100
MAX_ITEMS = 100

# Labels written as TYPE, per kind of value: they read back as the same label (vcard._TYPE_LABELS).
_TYPES = {
    "phones": {"mobile": "CELL", "iphone": "IPHONE", "home": "HOME", "work": "WORK", "main": "MAIN", "fax": "FAX",
               "pager": "PAGER", "other": "OTHER"},
    "emails": {"home": "HOME", "work": "WORK", "other": "OTHER", "school": "SCHOOL"},
    "urls": {"home": "HOME", "work": "WORK", "other": "OTHER", "school": "SCHOOL"},
    "addresses": {"home": "HOME", "work": "WORK", "other": "OTHER", "school": "SCHOOL"},
}
# Built-in labels with no TYPE of their own: Apple's label line, which reads back as the lower-case key.
_APPLE = {"mobile": "Mobile", "iphone": "iPhone", "home": "Home", "work": "Work", "main": "Main", "fax": "Fax",
          "pager": "Pager", "other": "Other", "school": "School", "homepage": "HomePage", "homefax": "HomeFAX",
          "workfax": "WorkFAX", "otherfax": "OtherFAX"}
_KNOWN_TYPE_VALUES = set(_TYPE_LABELS)
_PROPS = {"phones": "TEL", "emails": "EMAIL", "urls": "URL", "addresses": "ADR"}

_EMAIL = re.compile(r"[^@\s,;<>\"]+@[^@\s,;<>\"]+\.[^@\s,;<>\".]+")
_PHONE = re.compile(r"[0-9+().\-/#*,;pPwWxXeEtT  ]+")
_CONTROL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")


class FormError(ValueError):
    """The form is not valid: {field: message}, never echoing the value."""

    def __init__(self, fields: dict[str, str]):
        super().__init__("; ".join(f"{k}: {v}" for k, v in fields.items()))
        self.fields = fields


# ---------------------------------------------------------------- labels

def label_key(label: str | None) -> str:
    """A label as the parser reports it: a built-in one lower case without spaces ("Home fax" -> "homefax",
    "cell" -> "mobile"), any other text exactly as typed (trimmed)."""
    text = (label or "").strip()
    key = text.lower().replace(" ", "")
    if key == "cell":
        return "mobile"
    return key if key in _APPLE else text


def _label_of(card: VCard, prop: Prop) -> str:
    """The label the mirror's parser gives this line: its item group's X-ABLabel, else its first built-in
    TYPE (vcard._label)."""
    group_label = card.label(prop)
    if group_label is not None:
        return label_key(_apple_label(group_label))
    for t in prop.types:
        if t in _TYPE_LABELS:
            return _TYPE_LABELS[t]
    return ""


def _without_label_types(prop: Prop) -> list[tuple[str | None, list[str]]]:
    """The line's parameters without the TYPE values that name a label (pref, voice, internet stay)."""
    out = []
    for name, values in prop.params:
        if name is not None and name.upper() == "TYPE":
            kept = [v for v in values
                    if not {t.strip().lower() for t in v.split(",")} & _KNOWN_TYPE_VALUES]
            if kept:
                out.append((name, kept))
        elif name is None and values[0].lower() in _KNOWN_TYPE_VALUES:
            continue
        else:
            out.append((name, values))
    return out


def _set_label(card: VCard, prop: Prop, kind: str, label: str) -> None:
    key = label_key(label)
    has_line = prop.group and card.label(prop) is not None
    if not key:
        card.set_label(prop, None)
        params = _without_label_types(prop)
        if params != prop.params:
            card.update(prop, params=params)
        return
    if has_line or key not in _TYPES[kind]:
        # an Apple label line: Apple's own form for a built-in label, the text as typed otherwise
        card.set_label(prop, f"_$!<{_APPLE[key]}>!$_" if key in _APPLE else key)
        return
    params = [*_without_label_types(prop), ("TYPE", [_TYPES[kind][key]])]
    if params != prop.params:
        card.update(prop, params=params)


# ---------------------------------------------------------------- reading

def _parts(prop: Prop | None, size: int) -> list[str]:
    parts = prop.parts() if prop is not None else []
    return (parts + [""] * size)[:size] if len(parts) < size else parts


def _birthday(prop: Prop | None) -> str | None:
    if prop is None:
        return None
    value = prop.text().strip()
    omit = prop.param("X-APPLE-OMIT-YEAR")
    if m := re.fullmatch(r"(\d{4})-?(\d{2})-?(\d{2})(?:T.*)?", value):
        year, month, day = m.groups()
        if omit and omit[0] == year:
            return f"--{month}-{day}"
        return f"{year}-{month}-{day}"
    if m := re.fullmatch(r"--(\d{2})-?(\d{2})", value):
        return f"--{m.group(1)}-{m.group(2)}"
    return value or None


def _nickname(card: VCard) -> str:
    names: list[str] = []
    for prop in card.props("NICKNAME"):
        for item in split_unescaped(prop.decoded(), ","):
            text = unescape_text(item).strip()
            if text and text not in names:
                names.append(text)
    return ", ".join(names)


def _value_of(kind: str, prop: Prop) -> str | tuple:
    if kind == "phones":
        return _phone_value(prop.text())
    if kind == "addresses":
        parts = _parts(prop, 7)
        return tuple(p.strip() for p in parts[2:7])
    return prop.text().strip()  # a link's escapes undone too: Google writes https\://


def _items(card: VCard, kind: str) -> list[tuple[Prop, tuple[str, str | tuple]]]:
    out = []
    for prop in card.props(_PROPS[kind]):
        value = _value_of(kind, prop)
        if (any(value) if isinstance(value, tuple) else value):
            out.append((prop, (_label_of(card, prop), value)))
    return out


def read(card: VCard) -> dict:
    """The card's editable values, as the API names them (see the module docstring)."""
    n = _parts(card.first("N"), 5)
    org = _parts(card.first("ORG"), 1)
    out: dict = {field: n[i].strip() for i, field in enumerate(NAME_FIELDS)}
    title, note = card.first("TITLE"), card.first("NOTE")
    out.update(nickname=_nickname(card), company=org[0].strip(),
               department=", ".join(p.strip() for p in org[1:] if p.strip()),
               job_title=title.text().strip() if title else "", birthday=_birthday(card.first("BDAY")),
               note=note.text().strip() if note else "")
    for kind in ("phones", "emails", "urls"):
        out[kind] = [{"label": label, "value": value} for _p, (label, value) in _items(card, kind)]
    out["addresses"] = [{"label": label, **dict(zip(ADDRESS_PARTS, value))}
                        for _p, (label, value) in _items(card, "addresses")]
    return out


# ---------------------------------------------------------------- checking

def _text_ok(errors: dict, key: str, value, *, limit: int = MAX_TEXT, lines: bool = False) -> None:
    if value is None:
        return
    if not isinstance(value, str):
        errors[key] = "Must be text."
    elif len(value) > limit:
        errors[key] = f"Too long (at most {limit} characters)."
    elif _CONTROL.search(value) or (not lines and ("\n" in value or "\r" in value)):
        errors[key] = "Cannot hold a line break." if not lines else "Cannot hold control characters."


def _birthday_ok(value: str) -> bool:
    if m := re.fullmatch(r"(\d{4})-(\d{2})-(\d{2})", value):
        y, mo, d = map(int, m.groups())
    elif m := re.fullmatch(r"--(\d{2})-(\d{2})", value):
        y, (mo, d) = 2000, map(int, m.groups())  # a leap year, so 29 February is a birthday too
    else:
        return False
    try:
        date(y if y > 0 else 2000, mo, d)
    except ValueError:
        return False
    return True


def check(form: dict, *, creating: bool) -> dict:
    """The form with its values trimmed (None for a text left empty, [] for a list), or FormError with one
    message per field ("emails[1].value": "Not an email address."). Only the fields given are checked; a
    new contact needs a name, a company, a nickname, an email or a phone."""
    errors: dict[str, str] = {}
    out: dict = {}
    for field in TEXT_FIELDS:
        if field not in form:
            continue
        value = form[field]
        _text_ok(errors, field, value, limit=MAX_NOTE if field == "note" else MAX_TEXT, lines=field == "note")
        if field in errors:
            continue
        value = (value or "").strip()
        if field == "birthday" and value and not _birthday_ok(value):
            errors[field] = "Not a date: YYYY-MM-DD, or --MM-DD without a year."
        out[field] = value
    for kind in LIST_FIELDS:
        if kind not in form:
            continue
        items = form[kind] or []
        if not isinstance(items, list):
            errors[kind] = "Must be a list."
            continue
        if len(items) > MAX_ITEMS:
            errors[kind] = f"Too many (at most {MAX_ITEMS})."
            continue
        cleaned = []
        for i, item in enumerate(items):
            key = f"{kind}[{i}]"
            if not isinstance(item, dict):
                errors[key] = "Must be an object."
                continue
            _text_ok(errors, f"{key}.label", item.get("label"), limit=MAX_LABEL)
            label = (item.get("label") or "").strip()
            if kind == "addresses":
                parts = {}
                for part in ADDRESS_PARTS:
                    _text_ok(errors, f"{key}.{part}", item.get(part), lines=part == "street")
                    parts[part] = (item.get(part) or "").strip() if isinstance(item.get(part), str) else ""
                if any(parts.values()):
                    cleaned.append({"label": label, **parts})
                continue
            _text_ok(errors, f"{key}.value", item.get("value"))
            if f"{key}.value" in errors:
                continue
            value = (item.get("value") or "").strip()
            if not value:
                continue  # an empty row in the form: nothing to keep
            if kind == "emails" and not _EMAIL.fullmatch(value):
                errors[f"{key}.value"] = "Not an email address."
            elif kind == "phones" and (not _PHONE.fullmatch(value) or len(re.sub(r"\D", "", value)) < 2):
                errors[f"{key}.value"] = "Not a phone number."
            elif kind == "urls" and re.search(r"\s", value):
                errors[f"{key}.value"] = "A link cannot hold spaces."
            cleaned.append({"label": label, "value": value})
        out[kind] = cleaned
    if creating and not errors and not any(out.get(f) for f in (*NAME_FIELDS, "nickname", "company", "phones",
                                                               "emails")):
        errors["given_name"] = "Give a name, a company, an email or a phone number."
    if errors:
        raise FormError(errors)
    return out


# ---------------------------------------------------------------- writing

def _shown_name(values: dict) -> str:
    name = " ".join(values.get(f, "") for f in ("name_prefix", "given_name", "middle_name", "family_name",
                                                 "name_suffix") if values.get(f))
    if name:
        return name
    for field in ("company", "nickname"):
        if values.get(field):
            return values[field]
    for kind in ("emails", "phones"):
        if values.get(kind):
            return values[kind][0]["value"]
    return ""


def _set_text(card: VCard, name: str, value: str) -> None:
    if value:
        card.set(name, value)
    else:
        card.remove(name)


def _birthday_value(card: VCard, value: str) -> tuple[Raw, list[tuple[str | None, list[str]]]]:
    four = card.version == "4.0"
    if value.startswith("--"):
        month, day = value[2:4], value[5:7]
        if four:
            return Raw(f"--{month}{day}"), []
        return Raw(f"{_APPLE_NO_YEAR}-{month}-{day}"), [("X-APPLE-OMIT-YEAR", [_APPLE_NO_YEAR])]
    return Raw(value.replace("-", "") if four else value), []


def _write_value(card: VCard, kind: str, prop: Prop | None, value, label: str) -> None:
    name = _PROPS[kind]
    if kind == "addresses":
        old = _parts(prop, 7) if prop is not None else [""] * 7
        written = [old[0], old[1], *value]
        if prop is None:
            prop = card.add(name, written)
        elif _value_of(kind, prop) != tuple(value):
            card.update(prop, written)
    elif prop is None:
        prop = card.add(name, value)  # TEL, EMAIL and URL are written as given (vcard_edit.VERBATIM)
    elif _value_of(kind, prop) != value:
        card.update(prop, value)
    if prop is not None and _label_of(card, prop) != label_key(label):
        _set_label(card, prop, kind, label)


def _sync_list(card: VCard, kind: str, wanted: list[dict]) -> None:
    def key(item: dict) -> tuple[str, str | tuple]:
        if kind == "addresses":
            return label_key(item.get("label")), tuple(item.get(p, "") for p in ADDRESS_PARTS)
        return label_key(item.get("label")), item["value"]

    left = _items(card, kind)
    todo = []
    for item in wanted:
        k = key(item)
        hit = next((entry for entry in left if entry[1] == k), None)
        if hit is not None:
            left.remove(hit)  # the same label and value: the line stays as it is
        else:
            todo.append((item, k))
    for (prop, _old), (item, (label, value)) in zip(left, todo):
        _write_value(card, kind, prop, value, item.get("label") or "")
    for prop, _old in left[len(todo):]:
        card.remove(prop)
    for item, (label, value) in todo[len(left):]:
        _write_value(card, kind, None, value, item.get("label") or "")


def apply(card: VCard, form: dict) -> None:
    """Write a checked form (check()) onto the card: only the fields given, and of those only the lines whose
    values differ. The caller writes the card with to_text(), which sets REV when anything changed."""
    if card.version == "2.1":
        raise VCardError("a vCard 2.1 is never edited in place")
    current = read(card)
    names_changed = any(f in form and form[f] != current[f] for f in (*NAME_FIELDS, "company"))
    if any(f in form and form[f] != current[f] for f in NAME_FIELDS):
        n = _parts(card.first("N"), 5)
        for i, field in enumerate(NAME_FIELDS):
            if field in form and form[field] != current[field]:
                n[i] = form[field]
        card.set("N", n)
    if "nickname" in form and form["nickname"] != current["nickname"]:
        if form["nickname"]:
            card.set("NICKNAME", [form["nickname"]])
        else:
            card.remove("NICKNAME")
    if any(f in form and form[f] != current[f] for f in ("company", "department")):
        company = form.get("company", current["company"])
        department = form.get("department", current["department"])
        if company or department:
            old = _parts(card.first("ORG"), 1)
            # an unchanged department keeps the card's own units, however many it has
            units = old[1:] if department == current["department"] else [department] if department else []
            card.set("ORG", [company, *units])
        else:
            card.remove("ORG")
    if "job_title" in form and form["job_title"] != current["job_title"]:
        _set_text(card, "TITLE", form["job_title"])
    if "note" in form and form["note"] != current["note"]:
        _set_text(card, "NOTE", form["note"])
    if "birthday" in form and (form["birthday"] or None) != current["birthday"]:
        if form["birthday"]:
            value, extra = _birthday_value(card, form["birthday"])
            old = card.first("BDAY")
            params = [p for p in (old.params if old else []) if p[0] is None or p[0].upper() != "X-APPLE-OMIT-YEAR"]
            card.set("BDAY", value, [*params, *extra])
        else:
            card.remove("BDAY")
    for kind in LIST_FIELDS:
        if kind in form:
            _sync_list(card, kind, form[kind])
    # FN follows the name; a card written anyway gains the FN vCard 3.0 requires, one left alone does not
    if names_changed or (card.changed and card.first("FN") is None):
        shown = _shown_name({**current, **form})
        fn = card.first("FN")
        if fn is None or fn.text().strip() != shown:
            card.set("FN", shown)
