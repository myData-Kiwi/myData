"""Invented address books and calendars for the fake DAV server. Every name, address and number here
is made up (example.com / example.net / example.org; phones in the reserved fictional ranges +1 NXX 555 01xx
 and +44 7700 900xxx). No real personal data."""

# A 1x1 PNG, base64: enough for a contact to "have a photo".
TINY_PNG_B64 = ("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==")


def vcard(uid: str, fn: str, *, n: str | None = None, emails=(), phones=(), org: str | None = None,
          nickname: str | None = None, bday: str | None = None, note: str | None = None,
          photo: bool = False, version: str = "3.0") -> str:
    lines = ["BEGIN:VCARD", f"VERSION:{version}", f"UID:{uid}", f"FN:{fn}"]
    lines.append(f"N:{n if n is not None else ';;;;'}")
    if nickname:
        lines.append(f"NICKNAME:{nickname}")
    if org:
        lines.append(f"ORG:{org};")
    for label, value in emails:
        lines.append(f"EMAIL;TYPE=INTERNET;TYPE={label}:{value}")
    for label, value in phones:
        lines.append(f"TEL;TYPE={label}:{value}")
    if bday:
        lines.append(f"BDAY:{bday}")
    if note:
        lines.append(f"NOTE:{note}")
    if photo:
        lines.append(f"PHOTO;ENCODING=b;TYPE=PNG:{TINY_PNG_B64}")
    lines.append("END:VCARD")
    return "\r\n".join(lines) + "\r\n"


CONTACTS = {
    "ava-fictional.vcf": vcard("fake-uid-ava", "Ava Fictional", n="Fictional;Ava;;;", nickname="Avi",
                               emails=[("HOME", "ava.fictional@example.com"), ("WORK", "ava@work.example.net")],
                               phones=[("CELL", "+1 202 555 0101")], bday="1990-04-12", photo=True,
                               note="Met at the invented book club."),
    "ben-madeup.vcf": vcard("fake-uid-ben", "Ben Madeup", n="Madeup;Ben;;;", org="Example Widgets Ltd",
                            emails=[("WORK", "ben.madeup@example.org")], phones=[("WORK", "+1 202 555 0102")]),
    "sam-example-1.vcf": vcard("fake-uid-sam-1", "Sam Example", n="Example;Sam;;;",
                               emails=[("HOME", "sam.example@example.com")]),
    "sam-example-2.vcf": vcard("fake-uid-sam-2", "Sam Example", n="Example;Sam;;;",
                               phones=[("CELL", "+44 7700 900103")]),
    "plumbing.vcf": vcard("fake-uid-plumbing", "", org="Acme Plumbing (Example)",
                          phones=[("WORK", "+1 202 555 0104")]),
    "no-name.vcf": vcard("fake-uid-noname", "", emails=[("HOME", "someone@example.net")], version="4.0"),
}


def vevent_calendar(*events: str) -> str:
    body = "".join(events)
    return ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//myData tests//fake//EN\r\n" + body
            + "END:VCALENDAR\r\n")


def vevent(uid: str, summary: str, dtstart: str, dtend: str | None = None, *, extra: str = "") -> str:
    lines = ["BEGIN:VEVENT", f"UID:{uid}", "DTSTAMP:20260301T000000Z", f"SUMMARY:{summary}", dtstart]
    if dtend:
        lines.append(dtend)
    if extra:
        lines.extend(extra.strip().splitlines())
    lines.append("END:VEVENT")
    return "\r\n".join(lines) + "\r\n"


AUCKLAND = """BEGIN:VTIMEZONE
TZID:Pacific/Auckland
BEGIN:STANDARD
DTSTART:19700405T030000
RRULE:FREQ=YEARLY;BYMONTH=4;BYDAY=1SU
TZOFFSETFROM:+1300
TZOFFSETTO:+1200
TZNAME:NZST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700927T020000
RRULE:FREQ=YEARLY;BYMONTH=9;BYDAY=-1SU
TZOFFSETFROM:+1200
TZOFFSETTO:+1300
TZNAME:NZDT
END:DAYLIGHT
END:VTIMEZONE
""".replace("\n", "\r\n")

STANDUP = ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//myData tests//fake//EN\r\n" + AUCKLAND
           + vevent("fake-uid-standup", "Team standup", "DTSTART;TZID=Pacific/Auckland:20260302T093000",
                    "DTEND;TZID=Pacific/Auckland:20260302T094500",
                    extra="RRULE:FREQ=WEEKLY;BYDAY=MO;COUNT=10\r\n"
                          "EXDATE;TZID=Pacific/Auckland:20260316T093000\r\nLOCATION:Room Kea")
           + vevent("fake-uid-standup", "Team standup (moved)", "DTSTART;TZID=Pacific/Auckland:20260324T100000",
                    "DTEND;TZID=Pacific/Auckland:20260324T101500",
                    extra="RECURRENCE-ID;TZID=Pacific/Auckland:20260323T093000")
           + "END:VCALENDAR\r\n")

CALENDARS = {
    "home": {
        "name": "Home", "color": "#34AADCFF", "components": ("VEVENT",),
        "items": {
            "dentist.ics": vevent_calendar(vevent("fake-uid-dentist", "Dentist (invented)",
                                                  "DTSTART:20260320T020000Z", "DTEND:20260320T030000Z",
                                                  extra="LOCATION:12 Example Street")),
            "ava-birthday.ics": vevent_calendar(vevent("fake-uid-ava-bday", "Ava Fictional's birthday",
                                                       "DTSTART;VALUE=DATE:20260412",
                                                       "DTEND;VALUE=DATE:20260413",
                                                       extra="RRULE:FREQ=YEARLY")),
            "lake-trip.ics": vevent_calendar(vevent("fake-uid-lake", "Lake trip", "DTSTART;VALUE=DATE:20260327",
                                                    "DTEND;VALUE=DATE:20260330")),
        },
    },
    "work": {
        "name": "Work", "color": "#CC73E1FF", "components": ("VEVENT", "VTODO"),
        "items": {"standup.ics": STANDUP},
    },
    "reminders": {
        "name": "Reminders", "color": "#FF9500FF", "components": ("VTODO",),
        "items": {"todo.ics": ("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//myData tests//fake//EN\r\n"
                               "BEGIN:VTODO\r\nUID:fake-uid-todo\r\nDTSTAMP:20260301T000000Z\r\n"
                               "SUMMARY:Buy invented milk\r\nEND:VTODO\r\nEND:VCALENDAR\r\n")},
    },
    "holidays": {  # no supported-calendar-component-set: any component allowed
        "name": "Holidays (example)", "color": None, "components": None,
        "items": {"made-up-day.ics": vevent_calendar(vevent("fake-uid-madeup-day", "Made-up Day",
                                                            "DTSTART;VALUE=DATE:20260318",
                                                            "DTEND;VALUE=DATE:20260319"))},
    },
}
