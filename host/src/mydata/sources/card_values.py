"""A card's values as the apps show a contact, worked out from its text alone: for cards that are not a contact on
the host (yet), such as a card in an import preview (Compare, design/components/DuplicatePair) or the contact a merge
would make. The fields are those of a contact's page (GET /contacts/{id}), without what only a stored contact has
(its id, source, etag).

Nothing here is logged or stored.
"""

from __future__ import annotations

from . import contact_form
from .vcard import card_kind, parse_vcard
from .vcard_edit import VCard, VCardError
from .views import contact_fields

_FORM_ONLY = ("middle_name", "name_prefix", "name_suffix", "company", "department")


def card_values(text: str, *, notes_included: bool = True) -> dict:
    """The card's values: names, company, job title, emails, phones, addresses, links, birthday, note, whether it
    has a photo, its kind, and `fields` (the values grouped as a contact's page shows them)."""
    card = parse_vcard(text)
    try:
        form = contact_form.read(VCard.parse(text))
    except VCardError:
        form = {}
    out = {"display_name": card.display_name, "full_name": card.full_name, "given_name": card.given_name,
           "family_name": card.family_name, "nickname": card.nickname, "organisation": card.organisation,
           "job_title": card.job_title, "emails": card.emails, "phones": card.phones, "addresses": card.addresses,
           "urls": card.urls, "birthday": card.birthday, "note": card.note if notes_included else "",
           "has_photo": card.has_photo, "kind": card_kind(text),
           **{k: form.get(k, "") for k in _FORM_ONLY}}
    out["fields"] = contact_fields(out, urls=card.urls, notes_included=notes_included)
    return out


# The kinds of value a comparison names, in the order a contact's page shows them (DuplicatePair's rows).
KINDS = ("name", "nickname", "company", "job_title", "phone", "email", "address", "birthday", "url", "note", "photo",
         "other")
# What `other` leaves out: the lines the kinds above compare, and those that say nothing about the person (the
# card's version, the app that wrote it, its revision and ids, Apple's labels and address formats).
_COMPARED = {"BEGIN", "END", "VERSION", "PRODID", "REV", "UID", "N", "FN", "NICKNAME", "ORG", "TITLE", "TEL", "EMAIL",
             "ADR", "URL", "BDAY", "NOTE", "PHOTO", "X-ABLABEL", "X-ABADR", "X-ABUID"}


def differences(a: str, b: str, *, notes: bool = True, region: str | None = None) -> list[str]:
    """The kinds of value (KINDS) in which two cards differ, after normalising: case and spacing, emails in lower
    case, phones in E.164; `other` is any other detail (an anniversary, a related name, a social profile). A value on
    one side only is a difference. `notes`: compare notes (not when one side never
    reads them: This Mac)."""
    from .importer import default_region, email_key, phone_key  # the import's own matching keys
    region = region if region is not None else default_region()

    def text(value) -> str:
        return " ".join((value or "").casefold().split())

    def keyed(card) -> dict[str, object]:
        parsed = parse_vcard(card)
        try:
            lines = VCard.parse(card)
            photo_prop = lines.first("PHOTO")
            photo_value = "".join(photo_prop.value.split()) if photo_prop is not None else ""
            other = {(p.key, text(p.decoded())) for p in lines.props() if p.key not in _COMPARED and p.value.strip()}
        except VCardError:
            photo_value, other = ("has" if parsed.has_photo else ""), set()
        return {
            "name": text(parsed.display_name),
            "nickname": text(parsed.nickname),
            "company": text(parsed.organisation),
            "job_title": text(parsed.job_title),
            "phone": {phone_key(p["value"], region) or "".join(ch for ch in p["value"] if ch.isdigit() or ch == "+")
                      for p in parsed.phones},
            "email": {email_key(e["value"]) or text(e["value"]) for e in parsed.emails},
            "address": {tuple(text(a.get(k)) for k in ("street", "locality", "region", "postal_code", "country"))
                        for a in parsed.addresses},
            "birthday": parsed.birthday or "",
            "url": {text(u["value"]) for u in parsed.urls},
            "note": text(parsed.note),
            "photo": photo_value,
            "other": other,
        }

    left, right = keyed(a), keyed(b)
    return [k for k in KINDS if (notes or k != "note") and left[k] != right[k]]
