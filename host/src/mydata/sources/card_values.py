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
