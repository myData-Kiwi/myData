"""Write the synthetic SQL dump of each store at its current schema version: <file>-v<N>.sql here.

Run it (from host/: .venv/bin/python tests/fixtures/schema/make_dump.py) at the commit that releases a
schema, and commit the files it writes; never edit a released dump. test_schema_migration.py loads each
dump into a file built by the released migrations up to N, migrates it with today's code and compares every
field of every row. The data is invented only: the DAV fixtures in tests/fixtures/dav, the fake This Mac
data (tests/fake_mac), a few extra cards (groups, an organisation, a soft-deleted card) and, from the schema
that has them on, owned collections (tests/owned_data.py).

A dump holds INSERT statements for the stores' own tables, never the schema, schema_version or a search
index (the migrations build those, and the insert triggers fill the index). A text value holding a carriage
return is written as hex (CAST(X'..' AS TEXT)) so git cannot change its line endings, and so is every
search_phones value: its digit forms side by side read as one long real-looking number to test_privacy."""

from __future__ import annotations

import sqlite3
import sys
import tempfile
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parents[2] / "src"), str(HERE.parents[1])]

from fake_mac import data as mac_data  # noqa: E402
from mydata.sources.dav.discovery import Collection  # noqa: E402
from mydata.sources.dav.sync import CollectionState, Item, SyncResult  # noqa: E402
from mydata.sources.mac.cards import etag, to_vcard  # noqa: E402
from mydata.sources.mac.protocol import Occurrence, _contact  # noqa: E402

import synthetic_home  # noqa: E402
import test_contacts_store as con  # noqa: E402

TABLES = {"contacts.sqlite": ("address_books", "contacts"),
          "calendar.sqlite": ("calendars", "events", "occurrences", "coverage")}

CRLF = "\r\n"
GROUP_3 = CRLF.join(["BEGIN:VCARD", "VERSION:3.0", "PRODID:-//Apple Inc.//iOS 18.0//EN", "N:Book club;;;;",
                     "FN:Book club", "X-ADDRESSBOOKSERVER-KIND:group", "UID:group-book-club@example.org",
                     "X-ADDRESSBOOKSERVER-MEMBER:urn:uuid:3F1C0F0E-0000-4000-8000-00000000A001",
                     "END:VCARD"]) + CRLF
GROUP_4 = "\n".join(["BEGIN:VCARD", "VERSION:4.0", "KIND:group", "FN:Choir (example)", "UID:urn:uuid:group-choir-1",
                     "MEMBER:urn:uuid:zoe-0001@example.org", "END:VCARD"]) + "\n"
ORG_4 = "\n".join(["BEGIN:VCARD", "VERSION:4.0", "KIND:org", "FN:Example Library", "ORG:Example Library",
                   "UID:urn:uuid:org-library-1", "TEL;TYPE=work:+1 555 0142", "END:VCARD"]) + "\n"
INDIVIDUAL_GROUPED = "\n".join(["BEGIN:VCARD", "VERSION:3.0", "FN:Kim Invented", "N:Invented;Kim;;;",
                                "item1.X-ADDRESSBOOKSERVER-KIND:individual", "UID:kim-invented@example.org",
                                "EMAIL;TYPE=INTERNET:kim@example.invalid", "END:VCARD"]) + "\n"


def populate(home: Path) -> None:
    contacts, calendar = synthetic_home.populate(home)
    extra = [Item(href=f"/1/carddavhome/card/{n}.vcf", etag=f'"x{i}"', data=text)
             for i, (n, text) in enumerate([("group-3", GROUP_3), ("group-4", GROUP_4), ("org-4", ORG_4),
                                            ("kim", INDIVIDUAL_GROUPED)])]
    contacts.apply("acc-1", con.BOOK, con.result(extra))
    contacts.apply("acc-1", con.BOOK, con.result(deleted=["/1/carddavhome/card/phone-only.vcf"]))
    contacts.apply("acc-2", con.OTHER_BOOK, con.result([con.item("zoe-example-v4.vcf", href="/2/card/zoe.vcf")]))
    for container, people in mac_data.CONTACTS.items():
        cards = [to_vcard(_contact(p)) for p in people]
        items = [Item(href=p["id"], etag=etag(c), data=c) for p, c in zip(people, cards)]
        contacts.apply("mac", Collection(f"mac://contacts/{container}", "contacts", container), SyncResult(
            changed=items, deleted=[], state=CollectionState(etags={i.href: i.etag for i in items}), full=True))
    ids = {c["id"]: calendar.upsert_calendar("mac", f"mac://calendars/{c['id']}", c["name"], c["color"])
           for c in mac_data.CALENDARS}
    by_calendar: dict[str, list] = {}
    for o in mac_data.OCCURRENCES[:-1]:
        by_calendar.setdefault(ids[o["calendar_id"]], []).append(Occurrence(**o))
    calendar.replace_occurrences("mac", (date(2025, 3, 18), date(2028, 3, 18)), by_calendar)
    with calendar.db.transaction() as db:  # one soft-deleted resource
        db.execute("UPDATE events SET deleted_at = modified_at WHERE href LIKE '%custom-tz.ics'")
        modes = "mode" in {r[1] for r in db.execute("PRAGMA table_info(calendars)")}
    if modes:
        import owned_data
        owned_data.add_owned(home)


def literal(value, hexed: bool = False) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, (int, float)):
        return repr(value)
    if "\r" in value or hexed:
        return f"CAST(X'{value.encode('utf-8').hex().upper()}' AS TEXT)"
    return "'" + value.replace("'", "''") + "'"


def dump(path: Path, tables: tuple[str, ...]) -> tuple[int, str]:
    db = sqlite3.connect(path)
    try:
        version = db.execute("SELECT MAX(version) FROM schema_version").fetchone()[0]
        lines = []
        for table in tables:
            columns = [r[1] for r in db.execute(f'PRAGMA table_info("{table}")')]
            for row in db.execute(f'SELECT {", ".join(columns)} FROM "{table}" ORDER BY rowid'):
                lines.append(f'INSERT INTO "{table}" ({", ".join(columns)}) VALUES '
                             f'({", ".join(literal(v, c == "search_phones") for c, v in zip(columns, row))});')
    finally:
        db.close()
    return version, "\n".join(lines) + "\n"


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        home = Path(tmp)
        populate(home)
        for name, tables in TABLES.items():
            version, text = dump(home / name, tables)
            out = HERE / f"{name.split('.')[0]}-v{version}.sql"
            if out.exists():
                print(f"{out.name} exists: a released dump is never rewritten")
                continue
            out.write_text(f"-- Synthetic {name} at schema version {version}, written by make_dump.py. Invented "
                           f"data only.\n" + text)
            print(f"wrote {out.name}")


if __name__ == "__main__":
    main()
