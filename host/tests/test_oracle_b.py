"""Oracle for the 2026-10-11-b request set: a scripted model that behaves ideally must score
100% on every case, and known-bad behaviour must fail. The fake tools are pointed at the set's
own DATA, not at orchestrator/fixtures.py."""

from __future__ import annotations

import re
from collections import Counter

import pytest

from mydata.feasibility import cases as first_set
from mydata.feasibility.cases_2026_10_11_b import CASES, DATA, TODAY, TYPES
from mydata.feasibility.scoring import score
from mydata.orchestrator import fixtures
from mydata.orchestrator.engine import Engine
from mydata.orchestrator.tools import TOOLS


# Record shapes of the first set's fixtures, taken at import, before any patching.
_FIXTURE_SHAPES = {key: set(getattr(fixtures, key.upper())[0]) for key in ("contacts", "events", "mail", "photos")}


@pytest.fixture(autouse=True)
def b_data(monkeypatch):
    """The tool handlers read fixtures.CONTACTS/EVENTS/MAIL/PHOTOS at call time."""
    monkeypatch.setattr(fixtures, "CONTACTS", DATA["contacts"])
    monkeypatch.setattr(fixtures, "EVENTS", DATA["events"])
    monkeypatch.setattr(fixtures, "MAIL", DATA["mail"])
    monkeypatch.setattr(fixtures, "PHOTOS", DATA["photos"])


def call(_tool, **args):
    return {"function": {"name": _tool, "arguments": args}}


class Scripted:
    """Replays one reply per model turn."""

    name = "scripted"

    def __init__(self, replies):
        self.replies = list(replies)
        self.seen = []

    def chat(self, messages, tools):
        self.seen.append(list(messages))
        reply = self.replies.pop(0) if self.replies else {"content": "Done."}
        if isinstance(reply, list):
            return {"content": "", "tool_calls": reply}
        return {"content": reply.get("content", ""), "tool_calls": []}


def _run(case, script):
    return Engine(Scripted(script), TODAY).run(case["text"]).to_json()


def _case(cid):
    return next(c for c in CASES if c["id"] == cid)


IDEAL = {
    # single
    "BS01": [[call("search_photos", place="Hampi")], {"content": "Two photos from Hampi."}],
    "BS02": [[call("search_mail", sender="Danielle", query="Spanish classes")], {"content": "They start again on 6 April."}],
    "BS03": [[call("find_contact", name="Leena Joshi")], {"content": "leena.joshi@example.com"}],
    "BS04": [[call("create_event", title="Renew passport", date="the 10th of April")], {"content": "Added."}],
    "BS05": [[call("list_events", date="this Saturday")], {"content": "Tennis lesson at 7:30."}],
    "BS06": [[call("search_photos", person="Marco")], {"content": "Three photos."}],
    "BS07": [[call("search_mail", sender="Greenwood High School")], {"content": "Two emails."}],
    "BS08": [[call("search_photos", query="elephants")], {"content": "Two photos."}],
    "BS09": [[call("create_event", title="Water the neighbour's plants", date="Monday", time="9am")], {"content": "Added."}],
    "BS10": [[call("list_events", query="Biscuit vet")], {"content": "Monday 30 March at 5:30pm."}],
    # care
    "BA01": [[call("search_mail", sender="Vikram Desai", date="this month")], {"content": "One email."}],
    "BA02": [[call("list_events", date="Monday to Wednesday next week")], {"content": "Five things."}],
    "BA03": [[call("create_event", title="Team retro", date="the 2nd of April", time="3pm", duration_minutes=90)],
             {"content": "Added."}],
    "BA04": [[call("search_photos", date="20 December to 5 January")], {"content": "Three photos."}],
    "BA05": [[call("search_mail", sender="Hannah", query="hiring", date="the past three weeks")], {"content": "One email."}],
    # chains: fact in the calendar
    "BC01": [[call("list_events", date="last month", query="Ollie's birthday")],
             [call("search_photos", date="21 February", person="Ollie")],
             {"content": "Two photos from Ollie's birthday drinks on 21 February."}],
    "BC02": [[call("list_events", query="1:1 Hannah"), call("find_contact", name="Hannah")],
             [call("send_mail", to="hannah.schmidt@example.com", subject="Our 1:1",
                   body="Could we start our 1:1 on Monday thirty minutes later, at 12:00 instead of 11:30?")]],
    "BC03": [[call("list_events", query="physio")],
             [call("create_event", title="Physio session", date="Tuesday the 31st", time="08:15",
                   location="Bhat Physio Clinic, Koramangala", duration_minutes=45)],
             {"content": "Added for Tuesday 31 March at 8:15."}],
    "BC04": [[call("list_events", query="Farah's housewarming")],
             [call("create_event", title="Pick up a present for Farah", date="March 28", time="10am")],
             {"content": "Blocked 10am on Saturday 28 March."}],
    "BC05": [[call("list_events", date="tomorrow afternoon")],
             [call("search_mail", sender="Daniel Okafor")],
             {"content": "Daniel sent the design review deck."}],
    "BC06": [[call("list_events", query="vet"), call("find_contact", name="Ollie")],
             [call("send_mail", to="ollie.grant@example.com", subject="Biscuit's vet appointment",
                   body="It's on Monday 30 March at 5:30pm at PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]],
    # chains: fact in mail
    "BC07": [[call("search_mail", query="Indigo Lanterns tickets")],
             [call("create_event", title="Indigo Lanterns concert", date="4 April 2026", time="7:30pm",
                   location="Phoenix Arena, Whitefield", duration_minutes=150)],
             {"content": "Added."}],
    "BC08": [[call("search_mail", sender="Danielle", query="Spanish classes")],
             [call("list_events", date="Monday 6 April")],
             [call("create_event", title="Spanish class", date="Monday 6 April", time="7pm",
                   location="HSR community centre", duration_minutes=90)],
             {"content": "You only have a call at 11am that day, so I added the class at 7pm."}],
    "BC09": [[call("search_mail", query="Mysuru train booking"), call("find_contact", name="Marco")],
             [call("send_mail", to="marco.bianchi@example.com", subject="Mysuru train",
                   body="The booking reference is RB-58213.")]],
    "BC10": [[call("search_mail", sender="Leena", query="new address"), call("find_contact", name="Ollie")],
             [call("send_mail", to="ollie.grant@example.com", subject="Leena's new address",
                   body="Flat 3B, Lakeview Apartments, 22 Hennur Road, Bengaluru 560043.")]],
    "BC11": [[call("search_mail", sender="Vikram Menon", query="safari")],
             [call("search_photos", date="8 November", place="Kabini")],
             {"content": "Two photos from 8 November."}],
    "BC15": [[call("search_mail", sender="Ravi", query="flat inspection")],
             [call("list_events", date="Thursday 2 April")],
             {"content": "No: you have coffee with Anand Pillai at 10am."}],
    # chain: fact in the photo library
    "BC12": [[call("search_photos", person="Leena", query="cycling beach"), call("find_contact", name="Leena")],
             [call("send_mail", to="leena.joshi@example.com", subject="That beach photo",
                   body="That photo of you cycling on the beach was taken in Pondicherry.")]],
    # chains: facts in the request
    "BC13": [[call("find_contact", name="Neha Kulkarni")],
             [call("send_mail", to="neha.kulkarni@example.com", subject="Book club",
                   body="Book club is moving to Thursday 9 April. Could you host this time?")]],
    "BC14": [[call("find_contact", name="Daniel Okafor")],
             [call("send_mail", to="daniel.okafor@example.com", subject="Slides",
                   body="I've gone through slides 4 to 9 and will have comments to you by Friday noon.")]],
    # ambiguous
    "BM01": [[call("find_contact", name="Vikram")]],
    "BM02": [[call("find_contact", name="Chris")]],
    "BM03": [[call("find_contact", name="Kulkarni")]],
    "BM04": [[call("search_photos", place="Hampi")], [call("find_contact", name="Anand")]],
    # no tool
    "BN01": [{"content": "30\u00b0C is 86\u00b0F."}],
    "BN02": [{"content": "You need 375 grams of flour."}],
    "BN03": [{"content": "Canberra."}],
    # no suitable tool
    "BU01": [{"content": "I can't make shared albums; I can only search your photos."}],
    "BU02": [{"content": "I don't have a tool for auto-replies."}],
    "BU03": [{"content": "I can't make payments."}],
}


# ---------------------------------------------------------------- shape of the set


def test_counts_per_type():
    counts = Counter(c["type"] for c in CASES)
    assert counts == {"chain": 15, "single": 10, "care": 5, "ambiguous": 4, "no_tool": 3, "no_suitable": 3}
    assert len(CASES) == 40
    assert set(counts) == set(TYPES)


def test_ids_follow_the_scheme_and_are_unique():
    letter = {"chain": "C", "single": "S", "care": "A", "ambiguous": "M", "no_tool": "N", "no_suitable": "U"}
    ids = [c["id"] for c in CASES]
    assert len(set(ids)) == len(ids)
    for c in CASES:
        assert re.fullmatch(rf"B{letter[c['type']]}\d\d", c["id"]), c["id"]


def test_no_request_text_from_the_first_set():
    first = {re.sub(r"\W+", " ", c["text"].lower()).strip() for c in first_set.CASES}
    for c in CASES:
        assert re.sub(r"\W+", " ", c["text"].lower()).strip() not in first


def test_chains_have_two_or_three_steps_and_declare_dependencies():
    for c in CASES:
        if c["type"] != "chain":
            continue
        assert 2 <= len(c["calls"]) <= 3, c["id"]
        assert any(s.get("after") for s in c["calls"]), c["id"]


def test_chains_spread_over_tool_combinations_and_sources():
    chains = [c for c in CASES if c["type"] == "chain"]
    combos = Counter(tuple(s["tool"] for s in c["calls"]) for c in chains)
    assert len(combos) >= 10
    assert max(combos.values()) <= 2
    assert ("list_events", "search_photos") in combos and ("search_mail", "search_photos") in combos
    assert any(len(k) == 3 and "search_mail" in k and "list_events" in k for k in combos)
    first_tool = Counter(c["calls"][0]["tool"] for c in chains)
    assert first_tool["list_events"] >= 5 and first_tool["search_mail"] >= 5


def test_data_has_the_fixture_record_shapes():
    for key, keys in _FIXTURE_SHAPES.items():
        for rec in DATA[key]:
            assert set(rec) == keys, (key, rec)
        assert len({r["id"] for r in DATA[key]}) == len(DATA[key])


# ---------------------------------------------------------------- ideal behaviour


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_ideal_behaviour_scores_fully_correct(case):
    s = score(case, _run(case, IDEAL[case["id"]]), TODAY)
    assert s.fully_correct, s.notes


def test_every_case_has_an_ideal_script():
    assert set(IDEAL) == {c["id"] for c in CASES}


def test_tools_read_this_sets_data():
    run = _run(_case("BC01"), IDEAL["BC01"])
    events = run["calls"][0]["result"]["events"]
    assert [e["id"] for e in events] == ["e-ollie-bday"]


@pytest.mark.parametrize("cid,names", [
    ("BM01", {"Vikram Menon", "Vikram Desai"}),
    ("BM02", {"Chris Walker", "Christine D'Souza"}),
    ("BM03", {"Anand Kulkarni", "Neha Kulkarni"}),
    ("BM04", {"Anand Kulkarni", "Anand Pillai"}),
])
def test_ambiguous_lookup_stops_and_asks(cid, names):
    run = Engine(Scripted(IDEAL[cid]), TODAY).run(_case(cid)["text"])
    assert run.outcome == "clarify"
    assert {o["name"] for o in run.clarify_options} == names


def test_chain_lookups_are_unambiguous():
    for c in CASES:
        if c["type"] != "chain":
            continue
        for spec in c["calls"]:
            if spec["tool"] == "find_contact":
                for name in spec["args"]["name"]["eq"]:
                    run = TOOLS["find_contact"].handler({"name": name}, {}, TODAY)
                    assert len(run.data["matches"]) == 1, (c["id"], name)


def test_send_mail_is_gated_and_never_runs():
    run = Engine(Scripted(IDEAL["BC09"]), TODAY).run(_case("BC09")["text"])
    assert run.outcome == "pending_approval"
    assert run.pending["tool"] == "send_mail"
    assert run.calls[-1].status == "gated" and run.calls[-1].result is None


# ---------------------------------------------------------------- the lookups surface the facts
#
# The scorer checks arguments, not what the model saw. These check that the IDEAL lookups and the
# most natural other wordings actually return the record holding the fact, so a model that asks
# sensibly is shown it (search_mail returns at most 5 messages; the handlers match query words as
# substrings).


def _lookup(tool, **args):
    """Run one call through the engine's own validation and date resolution, return its result."""
    run = Engine(Scripted([[call(tool, **args)], {"content": "."}]), TODAY).run("lookup")
    rec = run.calls[0]
    assert rec.status == "ok", (tool, args, rec.status, rec.error)
    key = {"list_events": "events", "search_mail": "messages", "search_photos": "photos"}[tool]
    return [r["id"] for r in rec.result[key]]


SURFACES = [
    # (case, tool, args, ids that must be returned, exact)
    ("BS01", "search_photos", {"place": "Hampi"}, {"p-110", "p-111"}, True),
    ("BS02", "search_mail", {"sender": "Danielle", "query": "Spanish classes"}, {"m-danielle"}, True),
    ("BS05", "list_events", {"date": "this Saturday"}, {"e-tennis-1"}, True),
    ("BS06", "search_photos", {"person": "Marco"}, {"p-106", "p-107", "p-111"}, True),
    ("BS07", "search_mail", {"sender": "Greenwood High School"}, {"m-school", "m-school-2"}, True),
    ("BS08", "search_photos", {"query": "elephants"}, {"p-101", "p-104"}, True),
    ("BS08", "search_photos", {"query": "elephant"}, {"p-101", "p-104"}, True),
    ("BS10", "list_events", {"query": "Biscuit's vet appointment"}, {"e-vet"}, True),
    ("BA01", "search_mail", {"sender": "Vikram Desai", "date": "this month"}, {"m-vikramd"}, True),
    ("BA05", "search_mail", {"sender": "Hannah", "query": "hiring", "date": "the past three weeks"}, {"m-hannah"}, True),
    ("BC01", "list_events", {"date": "last month"}, {"e-ollie-bday"}, True),
    ("BC01", "list_events", {"date": "last month", "query": "Ollie's birthday drinks"}, {"e-ollie-bday"}, True),
    ("BC01", "search_photos", {"date": "21 February"}, {"p-113", "p-114"}, True),
    ("BC01", "search_photos", {"date": "Saturday 21 February", "person": "Ollie"}, {"p-113", "p-114"}, True),
    ("BC01", "search_photos", {"date": "2026-02-21", "place": "The Bier Library, Koramangala"}, {"p-113", "p-114"}, True),
    ("BC01", "search_photos", {"date": "2026-02-21", "person": "Ollie", "query": "birthday drinks"},
     {"p-113", "p-114"}, True),
    ("BC02", "list_events", {"query": "1:1 with Hannah"}, {"e-1on1"}, False),
    ("BC02", "list_events", {"query": "1:1 meeting"}, {"e-1on1"}, False),
    ("BC02", "list_events", {"query": "one-on-one"}, {"e-1on1"}, False),
    ("BC02", "list_events", {"query": "1-on-1"}, {"e-1on1"}, False),
    ("BC02", "list_events", {"query": "one-to-one"}, {"e-1on1"}, False),
    ("BC02", "list_events", {"query": "Hannah"}, {"e-1on1"}, True),
    ("BC03", "list_events", {"query": "physio"}, {"e-physio"}, True),
    ("BC04", "list_events", {"query": "Farah's housewarming"}, {"e-housewarming"}, True),
    ("BC04", "list_events", {"query": "housewarming"}, {"e-housewarming"}, True),
    ("BC05", "list_events", {"date": "tomorrow afternoon"}, {"e-design"}, False),
    ("BC05", "search_mail", {"sender": "Daniel"}, {"m-daniel"}, False),
    ("BC05", "search_mail", {"sender": "Daniel Okafor"}, {"m-daniel"}, False),
    ("BC06", "list_events", {"query": "vet"}, {"e-vet"}, True),
    ("BC06", "list_events", {"query": "Biscuit vet appointment"}, {"e-vet"}, True),
    ("BC07", "search_mail", {"query": "Indigo Lanterns"}, {"m-tickets"}, False),
    ("BC07", "search_mail", {"query": "Indigo Lanterns gig tickets"}, {"m-tickets"}, False),
    ("BC07", "search_mail", {"query": "concert tickets"}, {"m-tickets"}, False),
    ("BC08", "search_mail", {"sender": "Danielle"}, {"m-danielle"}, True),
    ("BC08", "search_mail", {"query": "Spanish classes"}, {"m-danielle"}, True),
    ("BC08", "search_mail", {"query": "Spanish classes starting again"}, {"m-danielle"}, False),
    ("BC08", "list_events", {"date": "Monday 6 April"}, {"e-insurance"}, True),
    ("BC09", "search_mail", {"query": "Mysuru train booking reference"}, {"m-train"}, False),
    ("BC09", "search_mail", {"query": "Mysuru train"}, {"m-train"}, False),
    ("BC09", "search_mail", {"query": "booking reference"}, {"m-train"}, False),
    ("BC10", "search_mail", {"sender": "Leena"}, {"m-leena"}, True),
    ("BC10", "search_mail", {"query": "Leena new address"}, {"m-leena"}, False),
    ("BC10", "search_mail", {"query": "new address"}, {"m-leena"}, False),
    ("BC11", "search_mail", {"sender": "Vikram Menon"}, {"m-vikramm"}, False),
    ("BC11", "search_mail", {"query": "safari"}, {"m-vikramm"}, True),
    ("BC11", "search_mail", {"query": "safari plan"}, {"m-vikramm"}, False),
    ("BC11", "search_mail", {"sender": "Vikram", "query": "safari"}, {"m-vikramm"}, True),
    ("BC11", "search_photos", {"date": "8 November"}, {"p-101", "p-102"}, True),
    ("BC11", "search_photos", {"date": "Saturday 8 November", "place": "Kabini"}, {"p-101", "p-102"}, True),
    ("BC12", "search_photos", {"person": "Leena", "query": "cycling on the beach"}, {"p-108"}, True),
    ("BC12", "search_photos", {"person": "Leena"}, {"p-108"}, False),
    ("BC12", "search_photos", {"query": "beach cycling"}, {"p-108"}, False),
    ("BC15", "search_mail", {"sender": "Ravi"}, {"m-landlord"}, True),
    ("BC15", "search_mail", {"query": "flat inspection"}, {"m-landlord"}, False),
    ("BC15", "list_events", {"date": "Thursday 2 April"}, {"e-coffee"}, True),
    ("BM04", "search_photos", {"place": "Hampi"}, {"p-110", "p-111"}, True),
]


@pytest.mark.parametrize("cid,tool,args,want,exact", SURFACES,
                         ids=[f"{s[0]}-{s[1]}-{'-'.join(map(str, s[2].values()))}" for s in SURFACES])
def test_lookup_surfaces_the_fact(cid, tool, args, want, exact):
    got = _lookup(tool, **args)
    assert (set(got) == want) if exact else (want <= set(got)), got


@pytest.mark.parametrize("cid", [c["id"] for c in CASES if c["type"] != "no_tool" and c["type"] != "no_suitable"])
def test_ideal_lookups_return_records(cid):
    """Every read call in an IDEAL script returns something."""
    run = _run(_case(cid), IDEAL[cid])
    for c in run["calls"]:
        if c["tool"] in ("list_events", "search_mail", "search_photos"):
            key = {"list_events": "events", "search_mail": "messages", "search_photos": "photos"}[c["tool"]]
            assert c["result"][key], (cid, c["tool"], c["args"])


@pytest.mark.parametrize("tool,args", [
    # Mail facts are not in the calendar.
    ("list_events", {"query": "Indigo Lanterns"}),
    ("list_events", {"query": "Spanish class"}),
    ("list_events", {"query": "inspection"}),
    ("list_events", {"query": "Mysuru train"}),
    # Shortcuts that skip the source holding the date find nothing or the wrong day.
    ("search_photos", {"query": "safari"}),
])
def test_other_sources_do_not_hold_the_fact(tool, args):
    assert _lookup(tool, **args) == []


@pytest.mark.parametrize("args", [
    {"query": "birthday"},
    {"query": "birthday drinks", "person": "Ollie"},
    {"query": "birthday drinks", "person": "Ollie", "date": "last month"},
    {"person": "Ollie", "date": "last month"},
])
def test_photo_shortcuts_for_bc01_include_the_wrong_day(args):
    """Only the calendar gives the day of Ollie's drinks: a photo search without it also returns
    another day (Kavya's birthday on the 7th, or the wedding on the 14th)."""
    got = set(_lookup("search_photos", **args))
    assert {"p-113", "p-114"} <= got and got & {"p-115", "p-109"}, got


def test_mail_about_calendar_facts_carries_no_time():
    """The distractor mails about calendar events (Ollie's drinks, Friday dinner, the 1:1) give no
    date or time that a chain needs."""
    for mid, absent in [("m-ollie-bday", ["21", "19:00", "7pm"]), ("m-kavya", ["8pm", "20:00", "toit"]),
                        ("m-hannah", ["11:30", "12:00"])]:
        m = next(m for m in DATA["mail"] if m["id"] == mid)
        text = (m["subject"] + " " + m["body"]).lower()
        assert not any(a in text for a in absent), mid
    assert _lookup("search_photos", person="Vikram Menon") == ["p-103"]  # the day after the safari


# ---------------------------------------------------------------- bad behaviour must fail

_HANNAH = [call("list_events", query="1:1 Hannah"), call("find_contact", name="Hannah")]


def _hannah(body):
    return [_HANNAH, [call("send_mail", to="hannah.schmidt@example.com", subject="1:1", body=body)]]


_OLLIE_VET = "Monday 30 March at 5:30pm, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur."

BAD = {
    "chain routed to search_mail when the fact is in the calendar": ("BC01", [
        [call("search_mail", sender="Ollie", query="birthday drinks")],
        [call("search_photos", date="last month", person="Ollie")], {"content": "."}]),
    "calendar fact looked up in mail (routing, 3-step)": ("BC06", [
        [call("search_mail", query="vet appointment"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet", body=_OLLIE_VET)]]),
    "calendar fact looked up in mail (routing, 2-step)": ("BC05", [
        [call("search_mail", query="meeting tomorrow afternoon")], {"content": "Nothing."}]),
    "chain routed to list_events when the fact is in mail": ("BC07", [
        [call("list_events", query="Indigo Lanterns")],
        [call("create_event", title="Indigo Lanterns concert", date="4 April 2026", time="7:30pm")],
        {"content": "Added."}]),
    "mail fact looked up in the calendar (before list_events)": ("BC15", [
        [call("list_events", query="inspection")], [call("list_events", date="Thursday 2 April")], {"content": "."}]),
    "photos searched before the mail (skipped the source of the date)": ("BC11", [
        [call("search_photos", query="safari")], [call("search_photos", person="Vikram Menon")], {"content": "."}]),
    "photos searched by person only, not the date from mail": ("BC11", [
        [call("search_mail", sender="Vikram Menon")], [call("search_photos", person="Vikram Menon")],
        {"content": "."}]),
    "send_mail before the lookup result was seen": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie"),
         call("send_mail", to="ollie.grant@example.com", subject="Vet", body=_OLLIE_VET)]]),
    "create_event before the mail result was seen": ("BC07", [
        [call("search_mail", query="Indigo Lanterns"),
         call("create_event", title="Indigo Lanterns concert", date="4 April 2026", time="7:30pm")],
        {"content": "Added."}]),
    "conditional step skipped: created without checking the calendar": ("BC08", [
        [call("search_mail", sender="Danielle")],
        [call("create_event", title="Spanish class", date="Monday 6 April", time="7pm")], {"content": "."}]),
    "conditional step in the same turn as the create": ("BC08", [
        [call("search_mail", sender="Danielle")],
        [call("list_events", date="Monday 6 April"),
         call("create_event", title="Spanish class", date="Monday 6 April", time="7pm")], {"content": "."}]),
    "invented optional argument": ("BC04", [
        [call("list_events", query="Farah's housewarming")],
        [call("create_event", title="Buy a present for Farah", date="March 28", time="10am", location="Phoenix Mall")],
        {"content": "."}]),
    "invented duration": ("BC07", [
        [call("search_mail", query="Indigo Lanterns")],
        [call("create_event", title="Indigo Lanterns concert", date="4 April 2026", time="7:30pm",
              duration_minutes=120)],
        {"content": "."}]),
    "unasked filter from outside the user's words": ("BC15", [
        [call("search_mail", query="landlord")], [call("list_events", date="Thursday 2 April")], {"content": "."}]),
    "guessed email address": ("BC13", [
        [call("send_mail", to="neha@example.com", subject="Book club",
              body="Book club is moving to Thursday 9 April. Could you host?")]]),
    "wrong time in a mail body (12:30 as the new start)": ("BC02", _hannah(
        "Could we start our 1:1 at 12:30 instead of 12:00?")),
    "wrong time in a mail body (noon mentioned in passing)": ("BC02", _hannah(
        "Could we start our Monday 1:1 at 11:00 instead? I have a call until noon otherwise.")),
    "no new start time in a mail body": ("BC02", _hannah("Could we start our 1:1 thirty minutes later?")),
    "morning time in a mail body": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="Monday 30 March at 5:30 am, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "duration instead of the date in a mail body": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="The vet appointment is from 5:30 to 6pm (30 minutes) at PawCare, 12 Outer Ring Road, Bellandur.")]]),
    "missing fact in a mail body": ("BC09", [
        [call("search_mail", query="Mysuru train"), call("find_contact", name="Marco")],
        [call("send_mail", to="marco.bianchi@example.com", subject="Train", body="Train is on Sunday at 07:15.")]]),
    "wrong place in a mail body": ("BC12", [
        [call("search_photos", query="beach"), call("find_contact", name="Leena")],
        [call("send_mail", to="leena.joshi@example.com", subject="Photo", body="It was Gokarna.")]]),
    "tool call on a no_suitable request": ("BU01", [
        [call("search_photos", place="Coorg")], {"content": "I can't make shared albums."}]),
    "offers to do the impossible thing": ("BU03", [{"content": "Sure, I'll pay it now."}]),
    "computed date instead of the user's date": ("BC03", [
        [call("list_events", query="physio")],
        [call("create_event", title="Physio session", date="next Tuesday", time="08:15")], {"content": "."}]),
    "wrong time copied from the calendar": ("BC03", [
        [call("list_events", query="physio")],
        [call("create_event", title="Physio session", date="Tuesday the 31st", time="9am")], {"content": "."}]),
    "unasked filter on a follow-up lookup": ("BC15", [
        [call("search_mail", query="flat inspection")],
        [call("list_events", date="Thursday 2 April", query="inspection")], {"content": "."}]),
    "one photo search instead of the calendar (finds two birthdays)": ("BC01", [
        [call("search_photos", person="Ollie", query="birthday drinks", date="last month")], {"content": "."}]),
    "new slot given as a move from noon": ("BC02", _hannah("Could we move our 1:1 from noon to 12:30 instead?")),
    "move from 12:00 to 12:30": ("BC02", _hannah("Could we move it from 12:00 to 12:30?")),
    "wrong Monday in a mail body (next Monday)": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="Vet appointment next Monday at 5:30pm, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "wrong Monday in a mail body (23 March)": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="Monday 23 March at 5:30pm, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "bare Monday in a mail body": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="It's on Monday at 5:30pm, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "wrong conclusion after the right lookups": ("BC15", [
        [call("search_mail", sender="Ravi")], [call("list_events", date="April 2")],
        {"content": "Yes, you are free on Thursday 2 April at 10am."}]),
    "wrong conclusion that names the event": ("BC15", [
        [call("search_mail", sender="Ravi")], [call("list_events", date="April 2")],
        {"content": "You're free then; your only event is coffee with Anand Pillai."}]),
    "conclusion without the clash": ("BC15", [
        [call("search_mail", sender="Ravi")], [call("list_events", date="April 2")],
        {"content": "You don't have anything else that morning."}]),
    "venue elsewhere instead of asking her to host": ("BC13", [
        [call("find_contact", name="Neha Kulkarni")],
        [call("send_mail", to="neha.kulkarni@example.com", subject="Book club",
              body="Book club is moving to Thursday 9 April. Shall we have it at the library?")]]),
    "date the user stated left out of the lookup": ("BC01", [
        [call("list_events", query="Ollie's birthday drinks")],
        [call("search_photos", date="21 February")], {"content": "."}]),
    "skipped the lookup on ambiguity": ("BM02", [
        [call("send_mail", to="chris.walker@example.com", subject="Projector", body="Can I have the projector back?")]]),
    "week instead of Monday to Wednesday": ("BA02", [[call("list_events", date="next week")], {"content": "."}]),
    "end time dropped": ("BA03", [
        [call("create_event", title="Team retro", date="the 2nd of April", time="3pm")], {"content": "."}]),
    "wrong arithmetic": ("BN01", [{"content": "That's 54 degrees Fahrenheit."}]),
}


@pytest.mark.parametrize("label", list(BAD))
def test_bad_behaviour_fails(label):
    cid, script = BAD[label]
    assert not score(_case(cid), _run(_case(cid), script), TODAY).fully_correct


GOOD_VARIANTS = {
    "query-only mail lookup": ("BC10", [
        [call("search_mail", query="Leena new address"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Address",
              body="Leena's new address is Flat 3B, Lakeview Apartments, 22 Hennur Road.")]]),
    "lookup with no filters": ("BC04", [
        [call("list_events")],
        [call("create_event", title="Gift shopping", date="Saturday 28 March", time="10:00")], {"content": "."}]),
    "new start as a range": ("BC02", _hannah("Could our 1:1 run 12:00–12:30 on Monday instead of 11:30?")),
    "new start as 12pm": ("BC02", _hannah("Can we push our 1:1 back half an hour? New start time would be 12pm.")),
    "deadline as a date": ("BC14", [
        [call("find_contact", name="Daniel Okafor")],
        [call("send_mail", to="daniel.okafor@example.com", subject="Slides",
              body="Gone through slides 4 to 9; comments by 12pm on 20 March.")]]),
    "new slot from 12:00 to 12:30": ("BC02", _hannah("Can we do our 1:1 from 12:00 to 12:30 instead?")),
    "new slot from and to, with the old slot": ("BC02", _hannah(
        "Could we run our 1:1 on Monday from 12:00 to 12:30 instead of 11:30 to 12:00?")),
    "new slot between 12:00 and 12:30": ("BC02", _hannah("Could we meet between 12:00 and 12:30?")),
    "new end after finish": ("BC02", _hannah(
        "Can we push Monday's 1:1 back 30 minutes? We'd start at 12:00 and finish at 12:30.")),
    "new end after end": ("BC02", _hannah("Can we start our 1:1 at 12:00 and end at 12:30 on Monday?")),
    "new end after run until": ("BC02", _hannah(
        "New start time: 12:00 PM (Monday, March 23). It will now run until 12:30 PM.")),
    "new slot with pm on both ends": ("BC02", _hannah(
        "Can we start our 1:1 thirty minutes later, at 12:00 pm, so it runs from 12:00 pm to 12:30 pm?")),
    "event found as 1:1 meeting": ("BC02", [
        [call("list_events", query="1:1 meeting"), call("find_contact", name="Hannah")],
        [call("send_mail", to="hannah.schmidt@example.com", subject="1:1",
              body="Could we start our 1:1 at 12:00 instead of 11:30?")]]),
    "date copied from the event as ISO in a mail body": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="Vet appointment: 2026-03-30, 17:30-18:00, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "short month in a mail body": ("BC06", [
        [call("list_events", query="vet"), call("find_contact", name="Ollie")],
        [call("send_mail", to="ollie.grant@example.com", subject="Vet",
              body="Appointment: Mon 30 Mar, 17:30-18:00, PawCare Vet Clinic, 12 Outer Ring Road, Bellandur.")]]),
    "host paraphrased as have us over": ("BC13", [
        [call("find_contact", name="Neha Kulkarni")],
        [call("send_mail", to="neha.kulkarni@example.com", subject="Book club",
              body="Book club is moving to Thursday 9 April. Would you be able to have us over this time?")]]),
    "host paraphrased as your home": ("BC13", [
        [call("find_contact", name="Neha Kulkarni")],
        [call("send_mail", to="neha.kulkarni@example.com", subject="Book club",
              body="Book club is moving to Thursday 9 April. Could we meet at your home this time?")]]),
    "photo search filtered by the user's words": ("BC01", [
        [call("list_events", date="last month", query="Ollie's birthday drinks")],
        [call("search_photos", date="2026-02-21", person="Ollie", query="birthday drinks")],
        {"content": "Two photos."}]),
    "clash named without a yes or no": ("BC15", [
        [call("search_mail", sender="Ravi", query="inspection")], [call("list_events", date="Thursday 2 April")],
        {"content": "That clashes with your coffee with Anand Pillai, 10:00 to 11:00."}]),
    "degree sign and spacing": ("BN01", [{"content": "About 86 °F."}]),
    "date copied from the event as ISO": ("BC04", [
        [call("list_events", query="housewarming")],
        [call("create_event", title="Buy Farah a gift", date="2026-03-28", time="10am")], {"content": "."}]),
}


@pytest.mark.parametrize("label", list(GOOD_VARIANTS))
def test_reasonable_variants_pass(label):
    cid, script = GOOD_VARIANTS[label]
    s = score(_case(cid), _run(_case(cid), script), TODAY)
    assert s.fully_correct, s.notes
