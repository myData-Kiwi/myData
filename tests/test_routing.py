"""Tests for orchestrator.routing.select_tools, on requests invented for this file."""

import pytest

from mydata.orchestrator.routing import ALL_TOOLS, select_tools
from mydata.orchestrator.tools import TOOLS

MAIL, SEND, PHOTOS, CONTACT, EVENTS, CREATE = (
    "search_mail", "send_mail", "search_photos", "find_contact", "list_events", "create_event",
)

# (request, must include, must exclude)
CASES = [
    # single source, read only
    ("Did the landlord reply to my message about the boiler?", {MAIL}, {SEND, CREATE, EVENTS, PHOTOS}),
    ("Find the receipt for the headphones I bought in May", {MAIL}, {EVENTS, PHOTOS, SEND}),
    ("Anything new in my inbox from Priya?", {MAIL}, {EVENTS, PHOTOS, SEND}),
    ("What did Marco say in his email last week?", {MAIL}, {EVENTS, PHOTOS, SEND}),
    ("Am I free on Thursday afternoon?", {EVENTS}, {MAIL, PHOTOS, SEND, CREATE}),
    ("What's on my calendar next Monday?", {EVENTS}, {MAIL, PHOTOS, SEND, CREATE}),
    ("When is my next meeting with the design team?", {EVENTS}, {MAIL, PHOTOS, SEND}),
    ("Do I have any appointments booked for the 14th?", {EVENTS}, {MAIL, PHOTOS, SEND, CREATE}),
    ("Show me pictures of the dog from last summer", {PHOTOS}, {MAIL, EVENTS, SEND, CREATE}),
    ("Find photos with Grandma in Lisbon", {PHOTOS}, {MAIL, EVENTS, SEND, CREATE}),
    ("What's Hannah's phone number?", {CONTACT}, {MAIL, EVENTS, PHOTOS, SEND, CREATE}),
    ("Look up Dev's email address", {CONTACT}, {MAIL, EVENTS, PHOTOS, SEND, CREATE}),
    # multi-step: lookup + send
    ("Email Jo the time of my physio appointment", {EVENTS, CONTACT, SEND}, {MAIL}),
    ("Tell Sam where my meeting on Friday is", {EVENTS, CONTACT, SEND}, {MAIL}),
    ("Let Aunt Mira know when my flight lands", {CONTACT, SEND, MAIL, EVENTS}, set()),
    ("Send Kofi the photos from the barbecue", {PHOTOS, CONTACT, SEND}, {MAIL, CREATE}),
    ("Forward the hotel confirmation to Lena", {MAIL, CONTACT, SEND}, {CREATE}),
    ("Ask Ben if he is free for lunch on Saturday", {CONTACT, SEND, EVENTS}, set()),
    ("Send Ravi an email saying I'm running late", {CONTACT, SEND}, {CREATE}),
    # multi-step: lookup + create
    ("Add the dinner Tara emailed me about to my calendar", {MAIL, CREATE}, {SEND}),
    ("Put the concert from the ticket confirmation on my calendar", {MAIL, CREATE}, {SEND}),
    ("Add Noor's birthday party to my calendar", {MAIL, EVENTS, CREATE}, {SEND}),
    ("Schedule a meeting with Owen next Tuesday at 10", {CREATE, EVENTS}, {SEND, MAIL}),
    ("Remind me to call the vet on Monday", {CREATE}, {SEND}),
    # mail and calendar both mentioned
    ("Is the appointment in the email from the clinic already on my calendar?", {MAIL, EVENTS}, {SEND, CREATE}),
    ("Check my schedule and reply to Pia's message about coffee", {MAIL, EVENTS, SEND, CONTACT}, set()),
    # no cue words: everything
    ("When does my train leave tomorrow?", set(ALL_TOOLS), set()),
    ("What did I do last weekend?", set(ALL_TOOLS), set()),
    ("What's 15% of 80?", set(ALL_TOOLS), set()),
    # inflections, punctuation, case
    ("MESSAGES from Carla?", {MAIL}, {SEND, EVENTS}),
    ("Any classes scheduled this week?", {EVENTS}, {MAIL, CREATE}),
    ("Text Omar. Tell him the pics are ready", {PHOTOS, SEND, CONTACT}, {MAIL}),
    ("Can you e-mail Zoe my plans for Sunday", {SEND, CONTACT, EVENTS}, {MAIL}),
]


@pytest.mark.parametrize("request_text,must,must_not", CASES, ids=[c[0][:40] for c in CASES])
def test_select_tools(request_text, must, must_not):
    got = select_tools(request_text)
    assert must <= set(got), f"missing {must - set(got)} in {got}"
    assert not (must_not & set(got)), f"should not show {must_not & set(got)}: {got}"


@pytest.mark.parametrize("request_text", [c[0] for c in CASES])
def test_invariants(request_text):
    got = select_tools(request_text)
    assert got, "never empty"
    assert got == [t for t in TOOLS if t in got], "canonical order"
    if SEND in got:
        assert CONTACT in got, "sending implies find_contact"
    assert select_tools(request_text) == got, "deterministic"


def test_empty_request_gets_everything():
    assert select_tools("") == list(TOOLS)


def test_engine_shows_only_the_selected_tools():
    from mydata.orchestrator.engine import Engine
    from mydata.orchestrator.fixtures import TODAY

    class Recorder:
        name = "recorder"

        def __init__(self):
            self.tools = None

        def chat(self, messages, tools):
            self.tools = [t["function"]["name"] for t in tools]
            return {"content": "ok", "tool_calls": []}

    m = Recorder()
    Engine(m, TODAY, route=True).run("Show me pictures of the lake")
    assert m.tools == select_tools("Show me pictures of the lake") == ["search_photos"]
    m = Recorder()
    Engine(m, TODAY).run("Show me pictures of the lake")  # routing is off by default
    assert len(m.tools) == 6
