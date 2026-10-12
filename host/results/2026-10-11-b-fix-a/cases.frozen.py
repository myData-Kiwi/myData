"""Second feasibility request set, "2026-10-11-b": 40 requests and what counts as correct.

Purpose: measure chained requests (and everything else) before and after the orchestrator
fixes of the 2026-10-11 round. It was written before any model output on it was seen, against
the tool definitions, tool descriptions and system prompt as they stood at the end of the
first test, and not around any planned fix.

FROZEN after the commit that adds it. No edits for any reason: not to requests, expected calls,
matchers or DATA. A request that turns out to be badly written is recorded as such in the run's
report and left as it is. A further change needs a new, separately named set.

Fixed today: Wednesday 18 March 2026 (TODAY below). Date phrases follow orchestrator/dates.py.

This set uses its own dataset, DATA, not orchestrator/fixtures.py. To run it, point the fake
tools at DATA by replacing fixtures.CONTACTS, EVENTS, MAIL and PHOTOS (the tool handlers read
those module attributes at call time); tests/test_oracle_b.py shows how.

Schema, matcher language and scoring are those of cases.py (see its docstring). TYPES and
REFUSAL_PATTERN are re-exported from there, unchanged.

Where each chain's fact lives (a reader can tell from the wording; no other source holds it):
  calendar only: BC01 BC02 BC03 BC04 BC05 BC06
  mail only:     BC07 BC08 BC09 BC10 BC11 BC15  (none of them names email as the source)
  photos only:   BC12
  user's words:  BC13 BC14

Decisions fixed with the set:
- Lookup steps in chains. A value the chain carries forward (BC05's sender, a date found in
  mail) and a date the user stated (BC01 "last month") are required. Other filters on a lookup
  are optional with matchers: any filter the user's words support is accepted, a wrong or
  invented one fails, and a lookup with no filters is accepted. Whether the lookup found the
  fact is then judged by the next step's arguments. (The first set required C02's date; this
  set accepts a query-only or date-only lookup when either finds the record.)
- Dates passed to create_event, list_events and search_photos in chains are either the user's
  own phrase or copied from a tool result, as C04 copied its flight date. No case needs the
  model to compute a calendar date. BC02 needs a computed clock time (30 minutes after 11:30)
  in a mail body; that is message text, not a tool argument.
- BC01: the photo library holds two birthdays last month with Ollie in them (his on the 21st,
  another on the 7th), so a photo search by content, person and "last month" cannot find the
  day; only the calendar can. Filters on the final search_photos from the user's words
  (person, "birthday drinks") or the event (place) are accepted.
- BC15 is a yes/no question whose conclusion exists only in the reply, so it has an answer
  check: the reply must name the clashing event (coffee with Anand) and must not say "yes" or
  "you're free".
- Single and care requests necessarily reuse the first set's one-tool shapes (six tools); their
  wording, people, places and data are new.
- BU01 to BU03: scoring.py's checks for a reply that claims or offers the impossible action
  only know the first set's verbs (delete, remove, book, cancel...). Offers or claims of making
  an album, setting an auto-reply or paying are not caught automatically and need hand review.
"""

from __future__ import annotations

from datetime import date

from .cases import REFUSAL_PATTERN, TYPES

__all__ = ["CASES", "DATA", "REFUSAL_PATTERN", "TODAY", "TYPES"]

TODAY = date(2026, 3, 18)

# ---------------------------------------------------------------- dataset

DATA: dict[str, list[dict]] = {
    "contacts": [
        {"id": "c-kavya", "name": "Kavya Iyer", "email": "kavya.iyer@example.com", "phone": "+91 98450 10101"},
        {"id": "c-daniel", "name": "Daniel Okafor", "email": "daniel.okafor@example.com", "phone": "+44 7700 900456"},
        {"id": "c-danielle", "name": "Danielle Moreau", "email": "danielle.moreau@example.com", "phone": "+33 6 12 34 56 78"},
        {"id": "c-hannah", "name": "Hannah Schmidt", "email": "hannah.schmidt@example.com", "phone": "+49 151 2345 6789"},
        {"id": "c-marco", "name": "Marco Bianchi", "email": "marco.bianchi@example.com", "phone": "+39 347 123 4567"},
        {"id": "c-farah", "name": "Farah Siddiqui", "email": "farah.siddiqui@example.com", "phone": "+91 98450 20202"},
        {"id": "c-vikramm", "name": "Vikram Menon", "email": "vikram.menon@example.com", "phone": "+91 98450 30303"},
        {"id": "c-vikramd", "name": "Vikram Desai", "email": "vikram.desai@example.com", "phone": "+91 98450 40404"},
        {"id": "c-chrisw", "name": "Chris Walker", "email": "chris.walker@example.com", "phone": "+61 412 345 678"},
        {"id": "c-christine", "name": "Christine D'Souza", "email": "christine.dsouza@example.com", "phone": "+91 98450 50505"},
        {"id": "c-anandk", "name": "Anand Kulkarni", "email": "anand.kulkarni@example.com", "phone": "+91 98450 60606"},
        {"id": "c-anandp", "name": "Anand Pillai", "email": "anand.pillai@example.com", "phone": "+91 98450 70707"},
        {"id": "c-neha", "name": "Neha Kulkarni", "email": "neha.kulkarni@example.com", "phone": "+91 98450 80808"},
        {"id": "c-leena", "name": "Leena Joshi", "email": "leena.joshi@example.com", "phone": "+91 98450 90909"},
        {"id": "c-ollie", "name": "Ollie Grant", "email": "ollie.grant@example.com", "phone": "+44 7700 900789"},
        {"id": "c-bhat", "name": "Dr. Sunita Bhat (physio)", "email": "reception@bhatphysio.example.com", "phone": "+91 80 5555 0142"},
    ],
    "events": [
        {"id": "e-ollie-bday", "title": "Ollie's birthday drinks", "date": "2026-02-21", "start": "19:00", "end": "23:00", "location": "The Bier Library, Koramangala"},
        {"id": "e-gym", "title": "Gym", "date": "2026-03-19", "start": "07:00", "end": "08:00", "location": "Cult Fitness, HSR Layout"},
        {"id": "e-design", "title": "Design review with Daniel", "date": "2026-03-19", "start": "14:00", "end": "15:00", "location": "Video call"},
        {"id": "e-haircut", "title": "Haircut", "date": "2026-03-19", "start": "18:30", "end": "19:00", "location": "Looks Salon, Indiranagar"},
        {"id": "e-dinner", "title": "Dinner with Kavya", "date": "2026-03-20", "start": "20:00", "end": "22:00", "location": "Toit, Indiranagar"},
        {"id": "e-tennis-1", "title": "Tennis lesson", "date": "2026-03-21", "start": "07:30", "end": "08:30", "location": "Cubbon Park courts"},
        {"id": "e-1on1", "title": "1:1 meeting with Hannah (one-on-one)", "date": "2026-03-23", "start": "11:30", "end": "12:00", "location": "Room 4B"},
        {"id": "e-physio", "title": "Physio session (Dr. Bhat)", "date": "2026-03-24", "start": "08:15", "end": "09:00", "location": "Bhat Physio Clinic, Koramangala"},
        {"id": "e-car", "title": "Car service drop-off", "date": "2026-03-25", "start": "09:00", "end": "09:30", "location": "Maruti Service Centre, HSR Layout"},
        {"id": "e-ptm", "title": "Parent-teacher meeting", "date": "2026-03-26", "start": "16:45", "end": "17:15", "location": "Greenwood High School"},
        {"id": "e-housewarming", "title": "Farah's housewarming", "date": "2026-03-28", "start": "19:00", "end": "23:00", "location": "Farah's place, Jayanagar"},
        {"id": "e-tennis-2", "title": "Tennis lesson", "date": "2026-03-28", "start": "07:30", "end": "08:30", "location": "Cubbon Park courts"},
        {"id": "e-vet", "title": "Vet check-up for Biscuit", "date": "2026-03-30", "start": "17:30", "end": "18:00", "location": "PawCare Vet Clinic, 12 Outer Ring Road, Bellandur"},
        {"id": "e-coffee", "title": "Coffee with Anand Pillai", "date": "2026-04-02", "start": "10:00", "end": "11:00", "location": "Third Wave Coffee, Koramangala"},
        {"id": "e-planning", "title": "Quarterly planning workshop", "date": "2026-04-03", "start": "09:30", "end": "13:00", "location": "Office, 5th floor"},
        {"id": "e-insurance", "title": "Car insurance renewal call", "date": "2026-04-06", "start": "11:00", "end": "11:30", "location": "Phone"},
    ],
    "mail": [
        {"id": "m-kavya", "from": "Kavya Iyer <kavya.iyer@example.com>", "date": "2026-03-15",
         "subject": "Friday dinner",
         "body": "Booked us a table for Friday, I've put it in your calendar. Can't wait to catch up!"},
        {"id": "m-hannah", "from": "Hannah Schmidt <hannah.schmidt@example.com>", "date": "2026-03-16",
         "subject": "Agenda for our 1:1 on Monday",
         "body": "I'd like to cover the Q2 hiring plan and your conference talk. Add anything else you want to discuss."},
        {"id": "m-daniel", "from": "Daniel Okafor <daniel.okafor@example.com>", "date": "2026-03-17",
         "subject": "Design review deck",
         "body": "Here's the deck for Thursday's review. Please look at slides 4 to 9 before we talk."},
        {"id": "m-danielle", "from": "Danielle Moreau <danielle.moreau@example.com>", "date": "2026-03-11",
         "subject": "Spanish classes restart",
         "body": "The Spanish classes start again on Monday 6 April, 7pm to 8:30pm, same room at the HSR "
                 "community centre. Bring last term's workbook."},
        {"id": "m-tickets", "from": "TicketHive <tickets@tickethive.example.com>", "date": "2026-03-09",
         "subject": "Your tickets: Indigo Lanterns live",
         "body": "You have 2 tickets for the Indigo Lanterns concert at Phoenix Arena, Whitefield on Saturday "
                 "4 April 2026. The show starts at 7:30pm and runs about two and a half hours."},
        {"id": "m-tickethive-promo", "from": "TicketHive <news@tickethive.example.com>", "date": "2026-03-16",
         "subject": "This weekend in Bengaluru",
         "body": "Comedy nights, food festivals and more. Book now before they sell out."},
        {"id": "m-electricians", "from": "Sparks Electrical Services <bookings@sparks.example.com>", "date": "2026-03-17",
         "subject": "Electricians' visit confirmed",
         "body": "Our electrician Ramesh will visit on Monday 23 March at 10:30am to fix the kitchen wiring. "
                 "The job should take about two hours."},
        {"id": "m-train", "from": "Rail Bookings <noreply@railbookings.example.com>", "date": "2026-03-13",
         "subject": "Booking confirmed: Bengaluru to Mysuru",
         "body": "Train 16231 from Bengaluru to Mysuru on Sunday 29 March 2026 departs at 07:15. "
                 "Booking reference: RB-58213. Coach C2, seats 41 and 42."},
        {"id": "m-marco", "from": "Marco Bianchi <marco.bianchi@example.com>", "date": "2026-03-15",
         "subject": "Mysuru weekend",
         "body": "So excited for the trip! Can you send me the booking reference? I need it for the hotel form."},
        {"id": "m-leena", "from": "Leena Joshi <leena.joshi@example.com>", "date": "2026-03-14",
         "subject": "We've moved!",
         "body": "New address from this week: Flat 3B, Lakeview Apartments, 22 Hennur Road, Bengaluru 560043."},
        {"id": "m-ollie", "from": "Ollie Grant <ollie.grant@example.com>", "date": "2026-03-16",
         "subject": "Card for Leena",
         "body": "I've got a card for Leena and Sam. Do you know where they live now?"},
        {"id": "m-ollie-bday", "from": "Ollie Grant <ollie.grant@example.com>", "date": "2026-02-09",
         "subject": "Birthday drinks!",
         "body": "Doing drinks for my birthday this year. I'll send you a calendar invite with the details."},
        {"id": "m-school", "from": "Greenwood High School <office@greenwoodhigh.example.com>", "date": "2026-03-12",
         "subject": "Annual sports day",
         "body": "Sports day is on Friday 3 April 2026 from 9am to 1pm at the school grounds. Parents are welcome."},
        {"id": "m-school-2", "from": "Greenwood High School <office@greenwoodhigh.example.com>", "date": "2026-03-02",
         "subject": "Term fees reminder",
         "body": "Fees for the summer term are due by 31 March."},
        {"id": "m-vikramm", "from": "Vikram Menon <vikram.menon@example.com>", "date": "2025-10-20",
         "subject": "Kabini safari plan",
         "body": "Safari is on Saturday 8 November. The jeep picks us up from the lodge at 6am, so no late night!"},
        {"id": "m-vikramd", "from": "Vikram Desai <vikram.desai@example.com>", "date": "2026-03-16",
         "subject": "Cricket on Sunday?",
         "body": "Nets at 7am on Sunday, you in?"},
        {"id": "m-landlord", "from": "Ravi Sharma <ravi.sharma@example.com>", "date": "2026-03-17",
         "subject": "Inspection of the flat",
         "body": "As your landlord I'd like to do the annual inspection of the flat on Thursday 2 April at 10am. "
                 "It should take about an hour."},
        {"id": "m-bhat", "from": "Bhat Physio Clinic <reception@bhatphysio.example.com>", "date": "2026-03-03",
         "subject": "Your exercise plan",
         "body": "Attached are the stretches we went through. Do them twice a day."},
    ],
    "photos": [
        {"id": "p-101", "taken": "2025-11-08", "place": "Kabini, Karnataka", "people": [], "tags": ["elephants", "jeep"]},
        {"id": "p-102", "taken": "2025-11-08", "place": "Kabini, Karnataka", "people": [], "tags": ["river", "sunrise"]},
        {"id": "p-103", "taken": "2025-11-09", "place": "Kabini, Karnataka", "people": ["Vikram Menon"], "tags": ["lodge", "breakfast"]},
        {"id": "p-104", "taken": "2024-02-10", "place": "Kabini, Karnataka", "people": [], "tags": ["river", "coracle", "elephants"]},
        {"id": "p-105", "taken": "2026-01-26", "place": "Coorg, Karnataka", "people": ["Kavya Iyer"], "tags": ["coffee estate", "mist"]},
        {"id": "p-106", "taken": "2025-12-31", "place": "Bengaluru, Karnataka", "people": ["Marco Bianchi", "Kavya Iyer"], "tags": ["fireworks", "party"]},
        {"id": "p-107", "taken": "2025-12-22", "place": "Bengaluru, Karnataka", "people": ["Marco Bianchi"], "tags": ["christmas market"]},
        {"id": "p-108", "taken": "2025-08-15", "place": "Pondicherry, India", "people": ["Leena Joshi"], "tags": ["beach", "cycling"]},
        {"id": "p-109", "taken": "2026-02-14", "place": "Bengaluru, Karnataka", "people": ["Leena Joshi", "Ollie Grant"], "tags": ["wedding", "mehendi"]},
        {"id": "p-110", "taken": "2025-03-22", "place": "Hampi, Karnataka", "people": [], "tags": ["ruins", "sunrise"]},
        {"id": "p-111", "taken": "2025-03-23", "place": "Hampi, Karnataka", "people": ["Marco Bianchi"], "tags": ["boulders", "temple"]},
        {"id": "p-112", "taken": "2026-01-03", "place": "Gokarna, Karnataka", "people": [], "tags": ["beach", "sunset"]},
        {"id": "p-113", "taken": "2026-02-21", "place": "Koramangala, Bengaluru", "people": ["Ollie Grant"], "tags": ["birthday", "cake", "candles"]},
        {"id": "p-114", "taken": "2026-02-21", "place": "Koramangala, Bengaluru", "people": ["Ollie Grant", "Kavya Iyer"], "tags": ["birthday", "friends", "toast"]},
        {"id": "p-115", "taken": "2026-02-07", "place": "Indiranagar, Bengaluru", "people": ["Kavya Iyer", "Ollie Grant"], "tags": ["birthday", "balloons", "party"]},
    ],
}

# ---------------------------------------------------------------- shared matchers

_NOON = ["12:00", "12pm", "12 pm", "12.00", "12 p.m.", "noon", "midday"]
_530PM = ["5:30", "5.30", "17:30", "17.30"]
# BC06: Monday 30 March, in any common form. Not a bare "Monday", which reads as the 23rd.
_THE_30TH = ["30 march", "march 30", "30th", "30 mar", "mar 30", "2026-03-30", "30/03", "30.03", "30-03",
             "re:(?<![\\d/])0?3/30(?!\\d)"]
# BC15: the reply must not answer the question with yes or "you're free".
_NOT_YES_FREE = (r"re:\A(?![\s\S]*(?:\byes\b|\byou(?:'re| are)\s+(?:(?!not\b)\w+\s+)?"
                 r"(?:free|available|clear)\b))")

# BC02: the body must give 12:00 (noon) as the new start, and every clock time in it must be
# 11:30 (the old start), 12:00/12pm/noon, or 12:30 as the new end: the end of a range that starts
# at 12:00 ("12:00-12:30", "from 12:00 to 12:30", "between 12:00 and 12:30") or after an end word
# ("finish at 12:30", "end time: 12:30", "run until 12:30"). A move verb shortly before
# "from 12:00 to 12:30" ("move it from 12:00 to 12:30") reads as a move to 12:30 and fails. Any
# other time (12:30 as a start, 11:00, "at 11", 1pm, 12:00 am) fails.
_PM = r"\s*(?:pm|p\.m\.)"
_AM = r"\s*(?:am|a\.m\.)"
_NEW = rf"(?:12[:.]00(?:{_PM})?(?!{_AM})|12{_PM}|noon|midday)"
_END = rf"12[:.]30(?:{_PM})?(?!{_AM})"
_TO = r"\s*(?:-|–|—|to|until|till)\s*"
_MOVED_FROM_NOON = (r"\b(?:mov|push|shift|chang|reschedul|bump|switch|postpon|delay)\w*"
                    r"(?=(?:\s+(?!(?:to|so|and|then|would|will)\b)[^\s.?!;]+){0,5}?"
                    rf"\s+(?:from|between)\s+{_NEW}(?:{_TO}|\s+and\s+){_END})")
_TIMEISH = (rf"(?<![\d:.])\d{{1,2}}(?:[:.]\d\d)?(?:{_AM}|{_PM})(?![a-z])"
            r"|(?<![\d:.])\d{1,2}[:.]\d\d(?!\d)"
            r"|\b(?:at|to|until|till|from)\s+\d{1,2}(?![\d:.])"
            rf"|{_MOVED_FROM_NOON}")
_ALLOWED = (rf"\bbetween\s+{_NEW}(?:{_TO}|\s+and\s+){_END}"
            rf"|{_NEW}{_TO}{_END}"
            r"|\b(?:end(?:s|ing)?(?:\s+time)?|finish(?:es|ing)?(?:\s+time)?|wrap(?:s|ping)?\s+up)"
            rf"\s*(?:(?:is|of|would\s+be|will\s+be|becomes)\s*)?:?\s*(?:at\s+|by\s+|around\s+)?{_END}"
            rf"|\b(?:run(?:s|ning)?|go(?:es|ing)?|last(?:s|ing)?)\s+(?:until|till|to|through)\s+{_END}"
            rf"|11[:.]30(?!{_PM})(?:{_AM})?|12[:.]00(?:{_PM})?(?!{_AM})|12{_PM}|\b(?:at|to)\s+12(?![\d:.])")
_STARTS_AT_NOON = (rf"re:\A(?=[\s\S]*(?:(?<![\d:.]){_NEW}|\bnoon\b|\bmidday\b|\b(?:at|to)\s+12(?![\d:.])))"
                   rf"(?:{_ALLOWED}|(?!{_TIMEISH})[\s\S])*\Z")

# A number standing alone: rejects "2.441" and "1,441", accepts "Rs.441" and "₹441".
def _number(n: str) -> str:
    return rf"(?<!\d)(?<!\d[.,]){n}(?!\d)"


# ---------------------------------------------------------------- cases

CASES: list[dict] = [
    # ---------------------------------------------------------- single tool, clear (10)
    {
        "id": "BS01", "type": "single", "text": "Find the photos I took in Hampi",
        "calls": [{"tool": "search_photos", "args": {"place": {"eq": ["hampi", "hampi karnataka", "hampi india"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS02", "type": "single", "text": "Has Danielle sent me anything about her Spanish classes?",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"eq": ["danielle", "danielle moreau"]},
            "query": {"has": [["spanish"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS03", "type": "single", "text": "What's Leena Joshi's email address?",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["leena joshi", "leena"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS04", "type": "single",
        "text": "I need to renew my passport. Put it in the calendar for the 10th of April",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["passport"]]},
            "date": {"date": ["2026-04-10", "2026-04-10"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS05", "type": "single", "text": "What have I got on this Saturday?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-21", "2026-03-21"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS06", "type": "single", "text": "Which of my photos have Marco in them?",
        "calls": [{"tool": "search_photos", "args": {"person": {"eq": ["marco", "marco bianchi"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS07", "type": "single", "text": "Look through my email for anything from Greenwood High School",
        "calls": [{"tool": "search_mail", "args": {"sender": {"has": [["greenwood"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS08", "type": "single", "text": "Have I got any pictures of elephants?",
        "calls": [{"tool": "search_photos", "args": {"query": {"has": [["elephant"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "BS09", "type": "single",
        "text": "Add 'water the neighbour's plants' to my calendar for Monday at 9am",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["plant"]]},
            "date": {"date": ["2026-03-23", "2026-03-23"]},
            "time": {"time": "09:00"}}}],
        "outcome": "answered",
    },
    {
        "id": "BS10", "type": "single", "text": "When is Biscuit's vet appointment?",
        "calls": [{"tool": "list_events", "args": {"query": {"has": [["vet", "biscuit"]]}}}],
        "outcome": "answered",
    },
    # ---------------------------------------------------------- arguments need care (5)
    {
        "id": "BA01", "type": "care", "text": "Show me emails from Vikram Desai this month",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"eq": ["vikram desai"]},
            "date": {"date": ["2026-03-01", "2026-03-31"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BA02", "type": "care", "text": "What's on my calendar from Monday to Wednesday next week?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-23", "2026-03-25"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BA03", "type": "care", "text": "Add a team retro on the 2nd of April from 3pm to 4:30pm",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["retro"]]},
            "date": {"date": ["2026-04-02", "2026-04-02"]},
            "time": {"time": "15:00"},
            "duration_minutes": {"eq": ["90"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BA04", "type": "care", "text": "Show me the photos taken from 20 December to 5 January",
        "calls": [{"tool": "search_photos", "args": {"date": {"date": ["2025-12-20", "2026-01-05"]}}}],
        "outcome": "answered",
    },
    {
        "id": "BA05", "type": "care", "text": "Did Hannah email me anything about hiring in the past three weeks?",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"eq": ["hannah", "hannah schmidt"]},
            "query": {"has": [["hiring", "hire"]]},
            "date": {"date": ["2026-02-25", "2026-03-18"]}}}],
        "outcome": "answered",
    },
    # ---------------------------------------------------------- chained (15)
    # Fact in the calendar.
    {
        "id": "BC01", "type": "chain", "text": "Show me the photos from the day of Ollie's birthday drinks last month",
        "calls": [
            {"tool": "list_events", "args": {"date": {"date": ["2026-02-01", "2026-02-28"]}},
             "optional": {"query": {"has": [["ollie", "birthday", "drinks"]]}}},
            {"tool": "search_photos", "after": ["list_events"], "args": {
                "date": {"date": ["2026-02-21", "2026-02-21"]}},
             "optional": {"person": {"eq": ["ollie", "ollie grant"]},
                          "query": {"has": [["birthday", "drinks", "party"]]},
                          "place": {"has": [["koramangala", "bengaluru", "bier library"]]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC02", "type": "chain",
        "text": "Email Hannah to say I'd like to start our 1:1 thirty minutes later than planned, and give her the new start time",
        "calls": [
            {"tool": "list_events", "args": {},
             "optional": {"query": {"has": [["1:1", "hannah", "one-on-one", "one on one", "1-1", "1on1", "1-on-1",
                                                "1 on 1", "one-to-one", "one to one"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["hannah", "hannah schmidt"]}}},
            {"tool": "send_mail", "after": ["list_events", "find_contact"], "args": {
                "to": {"email": "hannah.schmidt@example.com"},
                "subject": {"any": True},
                "body": {"has": [[_STARTS_AT_NOON]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "BC03", "type": "chain",
        "text": "Put another physio session in my calendar for Tuesday the 31st, at the same time as my next one",
        "calls": [
            {"tool": "list_events", "args": {}, "optional": {"query": {"has": [["physio", "bhat"]]}}},
            {"tool": "create_event", "after": ["list_events"], "args": {
                "title": {"has": [["physio"]]},
                "date": {"date": ["2026-03-31", "2026-03-31"]},
                "time": {"time": "08:15"}},
             "optional": {"location": {"has": [["bhat", "koramangala"]]}, "duration_minutes": {"eq": ["45"]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC04", "type": "chain",
        "text": "Block out 10am on the day of Farah's housewarming so I can pick up a present",
        "calls": [
            {"tool": "list_events", "args": {}, "optional": {"query": {"has": [["farah", "housewarming"]]}}},
            {"tool": "create_event", "after": ["list_events"], "args": {
                "title": {"has": [["present", "gift", "shop", "buy", "pick up", "pickup"]]},
                "date": {"date": ["2026-03-28", "2026-03-28"]},
                "time": {"time": "10:00"}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC05", "type": "chain", "text": "Pull up any emails from the person I'm meeting tomorrow afternoon",
        "calls": [
            {"tool": "list_events", "args": {"date": {"date": ["2026-03-19", "2026-03-19"]}}},
            {"tool": "search_mail", "after": ["list_events"], "args": {
                "sender": {"eq": ["daniel", "daniel okafor"]}},
             "optional": {"query": {"has": [["design", "review", "deck"]]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC06", "type": "chain",
        "text": "Ollie is taking Biscuit to the vet for me. Email him the clinic's address and when the appointment is",
        "calls": [
            {"tool": "list_events", "args": {}, "optional": {"query": {"has": [["vet", "biscuit"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["ollie", "ollie grant"]}}},
            {"tool": "send_mail", "after": ["list_events", "find_contact"], "args": {
                "to": {"email": "ollie.grant@example.com"},
                "subject": {"any": True},
                "body": {"has": [["outer ring", "bellandur"], _530PM, _THE_30TH]}}},
        ],
        "outcome": "pending_approval",
    },
    # Fact in mail.
    {
        "id": "BC07", "type": "chain", "text": "Add the Indigo Lanterns gig I bought tickets for to my calendar",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"query": {"has": [["indigo", "lantern", "concert", "ticket", "gig"]]}}},
            {"tool": "create_event", "after": ["search_mail"], "args": {
                "title": {"has": [["indigo", "lantern", "concert", "gig"]]},
                "date": {"date": ["2026-04-04", "2026-04-04"]},
                "time": {"time": "19:30"}},
             "optional": {"location": {"has": [["phoenix", "whitefield"]]}, "duration_minutes": {"eq": ["150"]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC08", "type": "chain",
        "text": "Danielle says Spanish classes are starting again. If I'm free that evening, put the first class in my calendar",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"sender": {"eq": ["danielle", "danielle moreau"]},
                          "query": {"has": [["spanish", "class"]]}}},
            {"tool": "list_events", "after": ["search_mail"], "args": {
                "date": {"date": ["2026-04-06", "2026-04-06"]}}},
            {"tool": "create_event", "after": ["search_mail", "list_events"], "args": {
                "title": {"has": [["spanish"]]},
                "date": {"date": ["2026-04-06", "2026-04-06"]},
                "time": {"time": "19:00"}},
             "optional": {"location": {"has": [["community centre", "community center", "hsr"]]},
                          "duration_minutes": {"eq": ["90"]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC09", "type": "chain", "text": "Marco needs the booking reference for our Mysuru train. Email it to him",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"query": {"has": [["mysuru", "train", "booking", "reference"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["marco", "marco bianchi"]}}},
            {"tool": "send_mail", "after": ["search_mail", "find_contact"], "args": {
                "to": {"email": "marco.bianchi@example.com"},
                "subject": {"any": True},
                "body": {"has": [["58213"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "BC10", "type": "chain",
        "text": "Leena has moved. Send Ollie her new address, he's posting her a card",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"sender": {"eq": ["leena", "leena joshi"]},
                          "query": {"has": [["address", "move", "leena"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["ollie", "ollie grant"]}}},
            {"tool": "send_mail", "after": ["search_mail", "find_contact"], "args": {
                "to": {"email": "ollie.grant@example.com"},
                "subject": {"any": True},
                "body": {"has": [["lakeview", "hennur"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "BC11", "type": "chain",
        "text": "Vikram Menon sent round the plan for his safari. Show me my photos from that day",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"sender": {"eq": ["vikram menon", "vikram"]},
                          "query": {"has": [["safari", "plan"]]}}},
            {"tool": "search_photos", "after": ["search_mail"], "args": {
                "date": {"date": ["2025-11-08", "2025-11-08"]}},
             "optional": {"place": {"eq": ["kabini", "kabini karnataka"]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "BC15", "type": "chain",
        "text": "Am I free when Ravi wants to come round for the flat inspection?",
        "calls": [
            {"tool": "search_mail", "args": {},
             "optional": {"sender": {"eq": ["ravi", "ravi sharma"]},
                          "query": {"has": [["inspection", "flat"]]}}},
            {"tool": "list_events", "after": ["search_mail"], "args": {
                "date": {"date": ["2026-04-02", "2026-04-02"]}}},
        ],
        "outcome": "answered",
        # The conclusion is only in the reply: it must name the clash and must not say yes or free.
        "answer": {"has": [["coffee", "anand"], [_NOT_YES_FREE]]},
    },
    # Fact in the photo library.
    {
        "id": "BC12", "type": "chain",
        "text": "Leena can't remember where we took that photo of her cycling on the beach. Email her the name of the place",
        "calls": [
            {"tool": "search_photos", "args": {},
             "optional": {"person": {"eq": ["leena", "leena joshi"]},
                          "query": {"has": [["beach", "cycl"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["leena", "leena joshi"]}}},
            {"tool": "send_mail", "after": ["search_photos", "find_contact"], "args": {
                "to": {"email": "leena.joshi@example.com"},
                "subject": {"any": True},
                "body": {"has": [["pondicherry", "puducherry", "pondy"]]}}},
        ],
        "outcome": "pending_approval",
    },
    # Facts in the user's words.
    {
        "id": "BC13", "type": "chain",
        "text": "Email Neha Kulkarni that book club is moving to Thursday the 9th of April, and ask if she could host this time",
        "calls": [
            {"tool": "find_contact", "args": {"name": {"eq": ["neha kulkarni", "neha"]}}},
            {"tool": "send_mail", "after": ["find_contact"], "args": {
                "to": {"email": "neha.kulkarni@example.com"},
                "subject": {"any": True},
                "body": {"has": [["9th", "9 april", "april 9", "ninth"],
                                 ["host", "at yours", "your place", "your house", "your home", "your flat", "your apartment",
                                  "have it at your", "hold it at your",
                                  r"re:\bhave (?:us|everyone|the group|book club) (?:over|round)\b"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "BC14", "type": "chain",
        "text": "Send Daniel Okafor an email saying I've gone through slides 4 to 9 and will have comments to him by Friday noon",
        "calls": [
            {"tool": "find_contact", "args": {"name": {"eq": ["daniel okafor"]}}},
            {"tool": "send_mail", "after": ["find_contact"], "args": {
                "to": {"email": "daniel.okafor@example.com"},
                "subject": {"any": True},
                "body": {"has": [["4"], ["9"], ["friday", "20 march", "march 20", "20th"], _NOON]}}},
        ],
        "outcome": "pending_approval",
    },
    # ---------------------------------------------------------- ambiguous (4)
    {
        "id": "BM01", "type": "ambiguous", "text": "Email Vikram that I left my charger at his place",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["vikram"]}}}],
        "outcome": "clarify",
    },
    {
        "id": "BM02", "type": "ambiguous", "text": "Drop Chris an email asking for the projector back",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["chris"]}}}],
        "outcome": "clarify",
    },
    {
        "id": "BM03", "type": "ambiguous", "text": "Email Kulkarni to say the invoice has been paid",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["kulkarni"]}}}],
        "outcome": "clarify",
    },
    {
        "id": "BM04", "type": "ambiguous",
        "text": "Check my photos to see when I was in Hampi, and email Anand the month",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["anand"]}}}],
        "optional_calls": [{"tool": "search_photos", "args": {},
                            "optional": {"place": {"eq": ["hampi", "hampi karnataka", "hampi india"]}}}],
        "outcome": "clarify",
    },
    # ---------------------------------------------------------- no tool needed (3)
    {
        "id": "BN01", "type": "no_tool", "text": "It's 30 degrees Celsius here. What's that in Fahrenheit?",
        "calls": [], "outcome": "answered", "answer": {"re": _number("86")},
    },
    {
        "id": "BN02", "type": "no_tool",
        "text": "A recipe uses 250 grams of flour for 4 people. How much flour do I need for 6?",
        "calls": [], "outcome": "answered", "answer": {"re": _number("375")},
    },
    {
        "id": "BN03", "type": "no_tool", "text": "What's the capital of Australia?",
        "calls": [], "outcome": "answered", "answer": {"has": [["canberra"]]},
    },
    # ---------------------------------------------------------- no suitable tool (3)
    {
        "id": "BU01", "type": "no_suitable", "text": "Make a shared album of my Coorg photos and invite Kavya to it",
        "calls": [], "outcome": "answered", "refuse": True,
    },
    {
        "id": "BU02", "type": "no_suitable", "text": "Turn on an out-of-office auto-reply until Monday",
        "calls": [], "outcome": "answered", "refuse": True,
    },
    {
        "id": "BU03", "type": "no_suitable", "text": "Pay my electricity bill",
        "calls": [], "outcome": "answered", "refuse": True,
    },
]
