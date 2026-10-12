"""The 30 feasibility requests and what counts as correct.

Written before any model output was seen. Do not edit requests or loosen
expectations after a run; add a new, separately named set instead.

Fixed today: Wednesday 18 March 2026 (see orchestrator/fixtures.py).

Matchers, applied to one argument value:
  {"eq": [...]}          normalised value equals one of these
  {"has": [[a, b], [c]]} every group has at least one option as a substring
  {"date": [start, end]} the phrase resolves (with the tool's bias) to exactly this inclusive range
  {"time": "HH:MM"}      parses to this time; for a time argument, a time inside
                         the same call's date phrase also counts
  {"re": "..."}          case-insensitive regex search
  {"email": "..."}       exact address
  {"any": true}          present, any value

In a "has" group, numbers match whole ("3:30" does not match "13:30") and an
option starting with "re:" is a regular expression.

Per expected call: "args" must all be present and match; "optional" may be
present and must then match; any other argument fails the call. Extra calls
fail the run. "optional_calls" may appear at most once each. "after" lists
tools whose results this call depends on: it must come in a later model step.
Every send_mail address must appear in an earlier find_contact result.
"""

from __future__ import annotations

TYPES = {
    "single": "Single tool, clear",
    "care": "Arguments need care",
    "chain": "Two or three steps chained",
    "ambiguous": "Ambiguous",
    "no_tool": "No tool needed",
    "no_suitable": "No suitable tool",
}

# Applied to the final answer after curly apostrophes are folded to straight ones.
REFUSAL_PATTERN = (
    r"\b(can(?:no|')?t|cannot|unable|not able|won't be able|"
    r"(?:don't|do not|doesn't|does not)(?: \w+)? (?:have|support)|"
    r"no (?:\w+ )?(?:tool|way|ability|option|function)s?|(?:isn't|is not|not) (?:possible|supported|available)|"
    r"(?:isn't|is not|not) something I(?:'m| am)? (?:can|able)|unsupported|only have (?:tools|the ability|access)|"
    r"can only|outside (?:of )?(?:my|what)|beyond (?:my|what)|"
    r"lacks? (?:the )?(?:ability|tools?|capabilit\w*|access|a way)|(?:I'm|I am) only able to|"
    r"(?:isn't|is not|not) (?:one of|within|among|part of) (?:my|the things I|what I)|"
    r"there (?:isn't|is no|aren't|are no) (?:a |an |any )?(?:\w+ )?(?:tool|option|way|function|capabilit\w*)s?)\b"
)

CASES: list[dict] = [
    # ---------------------------------------------------------- single tool, clear (10)
    {
        "id": "S01", "type": "single", "text": "Show photos from Goa last December",
        "calls": [{"tool": "search_photos", "args": {
            "place": {"eq": ["goa", "goa india"]},
            "date": {"date": ["2025-12-01", "2025-12-31"]}}}],
        "outcome": "answered",
    },
    {
        "id": "S02", "type": "single", "text": "Find emails from Tom about the project budget",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"eq": ["tom"]},
            "query": {"has": [["budget"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "S03", "type": "single", "text": "What's Priya's phone number?",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["priya"]}}}],
        "outcome": "answered",
    },
    {
        "id": "S04", "type": "single", "text": "Add a team lunch on March 30 at 1pm",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["lunch"]]},
            "date": {"date": ["2026-03-30", "2026-03-30"]},
            "time": {"time": "13:00"}}}],
        "outcome": "answered",
    },
    {
        "id": "S05", "type": "single", "text": "What's on my calendar tomorrow?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-19", "2026-03-19"]}}}],
        "outcome": "answered",
    },
    {
        "id": "S06", "type": "single", "text": "Show me pictures of Rishita",
        "calls": [{"tool": "search_photos", "args": {"person": {"eq": ["rishita"]}}}],
        "outcome": "answered",
    },
    {
        "id": "S07", "type": "single", "text": "Search my mail for the flight booking confirmation",
        "calls": [{"tool": "search_mail", "args": {"query": {"has": [["flight"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "S08", "type": "single", "text": "Find photos of the beach at sunset",
        "calls": [{"tool": "search_photos", "args": {"query": {"has": [["beach"], ["sunset"]]}}}],
        "outcome": "answered",
    },
    {
        "id": "S09", "type": "single", "text": "Do I have anything on March 31?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-31", "2026-03-31"]}}}],
        "outcome": "answered",
    },
    {
        "id": "S10", "type": "single", "text": "Schedule a call with the plumber tomorrow at 9am",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["plumber"]]},
            "date": {"date": ["2026-03-19", "2026-03-19"]},
            "time": {"time": "09:00"}}}],
        "outcome": "answered",
    },
    # ---------------------------------------------------------- arguments need care (6)
    {
        "id": "A01", "type": "care", "text": "What's on my calendar next Friday?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-27", "2026-03-27"]}}}],
        "outcome": "answered",
    },
    {
        "id": "A02", "type": "care", "text": "Show me emails from HDFC Bank in the last two weeks",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"has": [["hdfc"]]},
            "date": {"date": ["2026-03-04", "2026-03-18"]}}}],
        "outcome": "answered",
    },
    {
        "id": "A03", "type": "care",
        "text": "Put mum's birthday dinner on the calendar for Saturday the 4th of April at 7:30pm",
        "calls": [{"tool": "create_event", "args": {
            "title": {"has": [["birthday"]]},
            "date": {"date": ["2026-04-04", "2026-04-04"]},
            "time": {"time": "19:30"}}}],
        "outcome": "answered",
    },
    {
        "id": "A04", "type": "care", "text": "Photos of Arjun in Mumbai from 2024",
        "calls": [{"tool": "search_photos", "args": {
            "person": {"eq": ["arjun"]},
            "place": {"eq": ["mumbai", "mumbai india"]},
            "date": {"date": ["2024-01-01", "2024-12-31"]}}}],
        "outcome": "answered",
    },
    {
        "id": "A05", "type": "care", "text": "What do I have on the week after next?",
        "calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-30", "2026-04-05"]}}}],
        "outcome": "answered",
    },
    {
        "id": "A06", "type": "care", "text": "Find the email Priya sent me last Thursday about the lease",
        "calls": [{"tool": "search_mail", "args": {
            "sender": {"eq": ["priya"]},
            "query": {"has": [["lease"]]},
            "date": {"date": ["2026-03-12", "2026-03-12"]}}}],
        "outcome": "answered",
    },
    # ---------------------------------------------------------- chained (5)
    {
        "id": "C01", "type": "chain", "text": "Email Rishita the time of my dentist appointment",
        "calls": [
            {"tool": "list_events", "args": {"query": {"has": [["dentist"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["rishita"]}}},
            {"tool": "send_mail", "after": ["list_events", "find_contact"], "args": {
                "to": {"email": "rishita.shah@example.com"},
                "subject": {"any": True},
                "body": {"has": [["3:30", "15:30", "3.30", "15.30"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "C02", "type": "chain", "text": "Send Priya the details of my lunch with her on the 27th",
        "calls": [
            {"tool": "list_events", "args": {"date": {"date": ["2026-03-27", "2026-03-27"]}},
             "optional": {"query": {"has": [["lunch", "priya"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["priya"]}}},
            {"tool": "send_mail", "after": ["list_events", "find_contact"], "args": {
                "to": {"email": "priya.nair@example.com"},
                "subject": {"any": True},
                "body": {"has": [["1pm", "1 pm", "13:00", "13.00", "1:00", "1.00", "1 p.m.",
                                  r"re:(?<![\d:.])1\s*(?:-|\u2013|\u2014|to|until|till)\s*2(?::00)?\s*(?:pm|p\.m\.)"],
                                 ["zoe"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "C03", "type": "chain",
        "text": "Find out when Arjun's birthday party is and email Tom an invite to it",
        "calls": [
            {"tool": "list_events", "args": {"query": {"has": [["arjun", "birthday", "party"]]}}},
            {"tool": "find_contact", "args": {"name": {"eq": ["tom"]}}},
            {"tool": "send_mail", "after": ["list_events", "find_contact"], "args": {
                "to": {"email": "tom.becker@example.com"},
                "subject": {"any": True},
                "body": {"has": [["21", "saturday"],
                                 ["6pm", "6 pm", "18:00", "18.00", "6:00", "6.00", "6 p.m.",
                                  r"re:(?<![\d:.])6\s*(?:-|\u2013|\u2014|to|until|till)\s*10(?::00)?\s*(?:pm|p\.m\.)"]]}}},
        ],
        "outcome": "pending_approval",
    },
    {
        "id": "C04", "type": "chain", "text": "Find my flight confirmation email and add the flight to my calendar",
        "calls": [
            {"tool": "search_mail", "args": {"query": {"has": [["flight"]]}}},
            {"tool": "create_event", "after": ["search_mail"], "args": {
                "title": {"has": [["flight", "6e", "mumbai", "bom"]]},
                "date": {"date": ["2026-03-31", "2026-03-31"]},
                "time": {"time": "09:40"}},
             "optional": {"location": {"any": True}, "duration_minutes": {"eq": ["105"]}}},
        ],
        "outcome": "answered",
    },
    {
        "id": "C05", "type": "chain",
        "text": "Look up Nisha Patel's email and send her a note saying I'll be late tomorrow",
        "calls": [
            {"tool": "find_contact", "args": {"name": {"eq": ["nisha patel", "nisha"]}}},
            {"tool": "send_mail", "after": ["find_contact"], "args": {
                "to": {"email": "nisha.patel@example.com"},
                "subject": {"any": True},
                "body": {"has": [["late"], ["tomorrow", "tmrw", "thursday", "19 march", "march 19", "19th"]]}}},
        ],
        "outcome": "pending_approval",
    },
    # ---------------------------------------------------------- ambiguous (3)
    {
        "id": "M01", "type": "ambiguous", "text": "Message Patel about tomorrow",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["patel"]}}}],
        "optional_calls": [{"tool": "list_events", "args": {"date": {"date": ["2026-03-19", "2026-03-19"]}}}],
        "outcome": "clarify",
    },
    {
        "id": "M02", "type": "ambiguous", "text": "Email Alex to say thanks for dinner",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["alex"]}}}],
        "outcome": "clarify",
    },
    {
        "id": "M03", "type": "ambiguous", "text": "Send Sam an email saying the meeting has moved to 4pm",
        "calls": [{"tool": "find_contact", "args": {"name": {"eq": ["sam"]}}}],
        "outcome": "clarify",
    },
    # ---------------------------------------------------------- no tool needed (3)
    {
        "id": "N01", "type": "no_tool", "text": "What's 15% of 80?",
        "calls": [], "outcome": "answered", "answer": {"re": r"(?<![\d.])12(?![\d])"},
    },
    {
        "id": "N02", "type": "no_tool", "text": "How many minutes are there in three and a half hours?",
        "calls": [], "outcome": "answered", "answer": {"re": r"(?<![\d.])210(?![\d])"},
    },
    {
        "id": "N03", "type": "no_tool", "text": "How do you say 'thank you' in French?",
        "calls": [], "outcome": "answered", "answer": {"has": [["merci"]]},
    },
    # ---------------------------------------------------------- no suitable tool (3)
    {
        "id": "U01", "type": "no_suitable", "text": "Delete all mail from my bank",
        "calls": [], "outcome": "answered", "refuse": True,
    },
    {
        "id": "U02", "type": "no_suitable", "text": "Book me a table for two at an Italian restaurant tonight",
        "calls": [], "outcome": "answered", "refuse": True,
    },
    {
        "id": "U03", "type": "no_suitable", "text": "Cancel my dentist appointment",
        "calls": [], "outcome": "answered", "refuse": True,
    },
]
