"""Writes people.json: the one synthetic address book both stack-gate prototypes render (M1a).

Every name, number and address is invented (+64 21 555 01xx, +64 9 555 01xx, example.com). Each contact is
in the host's own shape (GET /contacts/{id}, ContactDetailOut), built with the host's own rules (sort letter,
caption, field groups, labels, source sentence) and checked against the host's model, so the Flutter fake
backend and the SwiftUI sample source read exactly what the host would send.

    cd host && uv run python ../prototypes/stack-gate/make_people.py

The three states both renderers draw are in "states": an owned contact with every kind of field, a followed
contact with a photo, and three contacts selected at once.
"""

import base64
import json
import math
import struct
import zlib
from pathlib import Path

from mydata.service.api import ContactDetailOut
from mydata.sources.mac import MAC_ID
from mydata.sources.owned import OWNED_ACCOUNT
from mydata.sources.views import contact_caption, contact_fields, sort_key, sort_letter, source_in_sentence

ICLOUD = "icloud-you"
ICLOUD_EMAIL = "you@example.com"
ACCOUNTS = {"mydata": OWNED_ACCOUNT, "mac": MAC_ID, "icloud": ICLOUD}
BOOKS = {"mydata": "ab-mydata", "mac": "ab-mac", "icloud": "ab-icloud"}


def P(given="", family="", *, src="mac", org="", job="", dept="", phones=(), emails=(), addresses=(),
      birthday=None, urls=(), note="", photo=False):
    return dict(given=given, family=family, src=src, org=org, job=job, dept=dept, phones=list(phones),
                emails=list(emails), addresses=list(addresses), birthday=birthday, urls=list(urls), note=note,
                photo=photo)


HOME = {"label": "home", "street": "12 Pōhutukawa Lane", "locality": "Grey Lynn", "region": "Auckland",
        "postal_code": "1021", "country": "New Zealand"}

# Two or three people for most letters, one for a few, none for X, as a real address book's first screens.
PEOPLE = [
    P("Aroha", "Ngata", src="mydata", org="Kōwhai Studio", job="Architect",
      phones=[("mobile", "+64 21 555 0101"), ("work", "+64 9 555 0102")],
      emails=[("home", "aroha.ngata@example.com"), ("work", "aroha@kowhai.example.com")],
      addresses=[HOME], birthday="1988-04-12", urls=[("homepage", "https://kowhai.example.com")],
      note="Met at the Kōwhai open day.\nPrefers calls after 10."),
    P("Amir", "Haddad", phones=[("mobile", "+64 21 555 0103")]),
    P("Ava", "Thompson", src="icloud", org="Harbour Health", job="Physiotherapist",
      phones=[("mobile", "+64 21 555 0104")], emails=[("home", "ava.t@example.com")], birthday="--11-14"),
    P("Ben", "Carter", org="Northwind Rail", job="Signal engineer", phones=[("mobile", "+64 21 555 0105"),
      ("work", "+64 9 555 0106")], emails=[("work", "ben.carter@example.com")],
      addresses=[{"label": "work", "street": "1 Station Road", "locality": "Newmarket", "region": "Auckland",
                  "postal_code": "1023", "country": "New Zealand"}], birthday="1979-02-03", photo=True),
    P("Bella", "Rossi", src="mydata", emails=[("home", "bella.rossi@example.com")]),
    P("Charlotte", "Wu", src="mydata", org="Fern & Co", job="Accountant",
      emails=[("work", "charlotte@fern.example.com")], phones=[("mobile", "+64 21 555 0107")]),
    P("Chen", "Li", src="icloud", phones=[("mobile", "+64 21 555 0108")]),
    P("Daniel", "Okafor", phones=[("mobile", "+64 21 555 0109")], emails=[("home", "dan.okafor@example.com")]),
    P("Diya", "Shah", src="mydata", phones=[("mobile", "+64 21 555 0110")]),
    P("Dora", "Mills", src="icloud", org="Te Atatū Library", job="Librarian"),
    P("Ella", "Martin", src="mydata", phones=[("home", "+64 9 555 0111")]),
    P("Émile", "Dubois", org="Le Petit Café", job="Chef", phones=[("work", "+64 9 555 0112")]),
    P("Farah", "Iqbal", src="icloud", org="Ponsonby Dental", phones=[("work", "+64 9 555 0113")]),
    P("Finn", "O’Brien", phones=[("mobile", "+64 21 555 0114")]),
    P("Grace", "Kim", src="mydata", job="Teacher", emails=[("home", "grace.kim@example.com")]),
    P("Gus", "Taylor", phones=[("mobile", "+64 21 555 0115")]),
    P("Hana", "Sato", src="icloud", phones=[("mobile", "+64 21 555 0116")]),
    P("Harry", "Williams", phones=[("mobile", "+64 21 555 0117")]),
    P("Hemi", "Walker", src="mydata", phones=[("mobile", "+64 21 555 0118")]),
    P("Isla", "Brown", org="Kiwi Bikes", job="Mechanic"),
    P("Ivan", "Petrov", src="icloud", emails=[("work", "ivan@example.com")]),
    P("Jack", "Nguyen", src="mydata", phones=[("mobile", "+64 21 555 0119")]),
    P("Jasmine", "Patel", phones=[("mobile", "+64 21 555 0120")]),
    P("Kiri", "Tane", src="icloud", emails=[("home", "kiri.tane@example.com")]),
    P("Kai", "Anderson", phones=[("mobile", "+64 21 555 0121")]),
    P("Leo", "Fischer", src="mydata", phones=[("mobile", "+64 21 555 0122")]),
    P("Lily", "Evans", phones=[("mobile", "+64 21 555 0123")]),
    P("Maia", "Rewi", org="Waitematā Rowing Club", job="Coach"),
    P("Mateo", "García", src="icloud", phones=[("mobile", "+64 21 555 0124")]),
    P("Maximilian Alexander", "Fitzgerald-Montgomery", src="mydata", org="Fitzgerald-Montgomery & Partners",
      job="Senior partner", emails=[("work", "max@example.com")]),
    P("Nikhil", "Mehta", phones=[("mobile", "+64 21 555 0125")]),
    P("Noah", "Smith", src="icloud", phones=[("mobile", "+64 21 555 0126")]),
    P(org="Northcote Plumbing", phones=[("work", "+64 9 555 0127")]),
    P("Olivia", "Jones", src="mydata", phones=[("mobile", "+64 21 555 0128")]),
    P("Oscar", "Reid", phones=[("mobile", "+64 21 555 0129")]),
    P("Priya", "Iyer", src="icloud", org="Example Labs", job="Researcher"),
    P("Paul", "Novak", phones=[("mobile", "+64 21 555 0130")]),
    P("Quinn", "Murphy", src="mydata", emails=[("home", "quinn@example.com")]),
    P("Rangi", "Parata", phones=[("mobile", "+64 21 555 0131")]),
    P("Rishita", "Desai", src="icloud", emails=[("home", "rishita@example.com")]),
    P("Sam", "Lee", phones=[("mobile", "+64 21 555 0132")]),
    P("Sofia", "Costa", src="mydata", phones=[("mobile", "+64 21 555 0133")]),
    P("Tama", "Hohaia", src="icloud", phones=[("mobile", "+64 21 555 0134")]),
    P("Theo", "Clarke", phones=[("mobile", "+64 21 555 0135")]),
    P("Uma", "Joshi", src="mydata", phones=[("mobile", "+64 21 555 0136")]),
    P("Victor", "Lam", phones=[("mobile", "+64 21 555 0137")]),
    P("Wiremu", "Kingi", src="icloud", phones=[("mobile", "+64 21 555 0138")]),
    P("Yara", "Haddad", src="mydata", emails=[("home", "yara@example.com")]),
    P("Zoe", "Clark", phones=[("mobile", "+64 21 555 0139")]),
    P(phones=[("mobile", "+64 21 555 0140")]),
]

STATES = {
    "owned": {"select": ["Aroha Ngata"]},
    "followed": {"select": ["Ben Carter"]},
    "several": {"select": ["Charlotte Wu", "Daniel Okafor", "Ella Martin"]},
}


def portrait() -> bytes:
    """A made-up head and shoulders, 256 px, as a plain PNG (no image library needed)."""
    size = 256
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            r, g, b = 0xC9, 0xD8, 0xE6  # sky
            r, g, b = (int(r - y * 0.12), int(g - y * 0.08), int(b - y * 0.04))
            if math.hypot(x - 128, y - 104) < 46:
                r, g, b = 0xC6, 0x8E, 0x6A  # face
            if math.hypot(x - 128, y - 82) < 50 and y < 86:
                r, g, b = 0x3B, 0x2A, 0x20  # hair
            if y > 160 and math.hypot((x - 128) * 0.8, y - 270) < 110:
                r, g, b = 0x2F, 0x5D, 0x8A  # jumper
            row += bytes((r, g, b))
        rows.append(bytes(row))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def lv(pairs):
    return [{"label": label, "value": value} for label, value in pairs]


def detail(i: int, p: dict) -> dict:
    full = " ".join(s for s in (p["given"], p["family"]) if s)
    emails, phones = lv(p["emails"]), lv(p["phones"])
    organisation = ", ".join(s for s in (p["org"], p["dept"]) if s)
    name = full or organisation or (emails[0]["value"] if emails else "") or (phones[0]["value"] if phones else "")
    src = p["src"]
    account = ACCOUNTS[src]
    notes = src != "mac"
    contact = {"phones": phones, "emails": emails, "addresses": p["addresses"], "birthday": p["birthday"],
               "note": p["note"]}
    stamp = f"2026-10-{1 + i % 20:02d}T09:00:00+00:00"
    out = {
        "id": f"gate-{i:02d}", "account_id": account, "address_book_id": BOOKS[src], "display_name": name,
        "full_name": full, "given_name": p["given"], "family_name": p["family"], "organisation": organisation,
        "emails": emails, "phones": phones, "addresses": p["addresses"], "birthday": p["birthday"],
        "note": p["note"] if notes else "", "has_photo": p["photo"], "source": src, "notes_included": notes,
        "etag": f'"{i + 1}-gate"', "editable": src == "mydata", "on_phone": False if src == "mydata" else None,
        "sort_letter": sort_letter(name), "caption": contact_caption(name, organisation, emails, phones),
        "created_at": stamp, "modified_at": stamp,
        "source_label": source_in_sentence(account, ICLOUD_EMAIL if src == "icloud" else None),
        "job_title": p["job"], "company": p["org"], "department": p["dept"], "urls": lv(p["urls"]),
        "fields": contact_fields(contact, urls=lv(p["urls"]), notes_included=notes),
    }
    return ContactDetailOut.model_validate(out).model_dump(mode="json", exclude={"raw_vcard"})


def main() -> None:
    contacts = [detail(i, p) for i, p in enumerate(PEOPLE)]
    contacts.sort(key=lambda c: (c["sort_letter"] == "#", sort_key(c["display_name"])))
    names = {c["display_name"] for c in contacts}
    for state in STATES.values():
        assert all(n in names for n in state["select"]), state
    photo = base64.b64encode(portrait()).decode()
    data = {
        "about": "Synthetic contacts for the M1a stack gate, in the host's ContactDetailOut shape, in the host's "
                 "order. Written by make_people.py; do not edit by hand.",
        "contacts": contacts,
        "photos": {c["id"]: photo for c in contacts if c["has_photo"]},
        "states": STATES,
    }
    out = Path(__file__).with_name("people.json")
    out.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {out} ({len(contacts)} contacts)")


if __name__ == "__main__":
    main()
