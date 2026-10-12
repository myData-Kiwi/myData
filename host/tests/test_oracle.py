"""A scripted model that behaves ideally must score 100%, and known-bad
behaviour must fail. This checks the engine, tools and scorer agree with the
case expectations, without any real model."""

from __future__ import annotations

import pytest

from mydata.feasibility.cases import CASES
from mydata.feasibility.scoring import score
from mydata.orchestrator.engine import Engine
from mydata.orchestrator.fixtures import TODAY


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


IDEAL = {
    "S01": [[call("search_photos", place="Goa", date="last December")], {"content": "Here are 2 photos."}],
    "S02": [[call("search_mail", sender="Tom", query="project budget")], {"content": "Found one."}],
    "S03": [[call("find_contact", name="Priya")], {"content": "+91 98200 22222"}],
    "S04": [[call("create_event", title="Team lunch", date="March 30", time="1pm")], {"content": "Added."}],
    "S05": [[call("list_events", date="tomorrow")], {"content": "Two things."}],
    "S06": [[call("search_photos", person="Rishita")], {"content": "2 photos."}],
    "S07": [[call("search_mail", query="flight booking confirmation")], {"content": "Found it."}],
    "S08": [[call("search_photos", query="beach at sunset")], {"content": "2 photos."}],
    "S09": [[call("list_events", date="March 31")], {"content": "Quarterly review."}],
    "S10": [[call("create_event", title="Call with the plumber", date="tomorrow at 9am")], {"content": "Added."}],
    "A01": [[call("list_events", date="next Friday")], {"content": "Lunch with Priya."}],
    "A02": [[call("search_mail", sender="HDFC Bank", date="the last two weeks")], {"content": "Two."}],
    "A03": [[call("create_event", title="Mum's birthday dinner", date="Saturday the 4th of April", time="7:30pm")],
            {"content": "Added."}],
    "A04": [[call("search_photos", person="Arjun", place="Mumbai", date="2024")], {"content": "2 photos."}],
    "A05": [[call("list_events", date="the week after next")], {"content": "Quarterly review, book club."}],
    "A06": [[call("search_mail", sender="Priya", query="lease", date="last Thursday")], {"content": "Found it."}],
    "C01": [[call("list_events", query="dentist")], [call("find_contact", name="Rishita")],
            [call("send_mail", to="rishita.shah@example.com", subject="Dentist",
                  body="My dentist appointment is on 26 March at 3:30 PM.")]],
    "C02": [[call("list_events", date="the 27th"), call("find_contact", name="Priya")],
            [call("send_mail", to="priya.nair@example.com", subject="Lunch on the 27th",
                  body="Lunch is at 1pm at Cafe Zoe, Lower Parel.")]],
    "C03": [[call("list_events", query="Arjun's birthday party")], [call("find_contact", name="Tom")],
            [call("send_mail", to="tom.becker@example.com", subject="Invite",
                  body="Arjun's birthday party is on Saturday 21 March at 6pm in Bandra. Come along!")]],
    "C04": [[call("search_mail", query="flight confirmation")],
            [call("create_event", title="Flight 6E 5321 to Mumbai", date="31 March 2026", time="09:40",
                  location="Bengaluru (BLR)")],
            {"content": "Added your flight."}],
    "C05": [[call("find_contact", name="Nisha Patel")],
            [call("send_mail", to="nisha.patel@example.com", subject="Running late",
                  body="I'll be late tomorrow.")]],
    "M01": [[call("find_contact", name="Patel")]],
    "M02": [[call("find_contact", name="Alex")]],
    "M03": [[call("find_contact", name="Sam")]],
    "N01": [{"content": "15% of 80 is 12."}],
    "N02": [{"content": "There are 210 minutes."}],
    "N03": [{"content": "Merci."}],
    "U01": [{"content": "I can't delete mail; I can only search it."}],
    "U02": [{"content": "I cannot book restaurants."}],
    "U03": [{"content": "I don't have a way to cancel events, only to list and add them."}],
}


@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_ideal_behaviour_scores_fully_correct(case):
    run = Engine(Scripted(IDEAL[case["id"]]), TODAY).run(case["text"]).to_json()
    s = score(case, run, TODAY)
    assert s.fully_correct, s.notes


def test_every_case_has_an_ideal_script():
    assert set(IDEAL) == {c["id"] for c in CASES}
    assert len(CASES) == 30


def _case(cid):
    return next(c for c in CASES if c["id"] == cid)


BAD = {
    "computed date instead of phrase, wrong year": ("S01", [[call("search_photos", place="Goa", date="December 2026")], {"content": "."}]),
    "this friday for next friday": ("A01", [[call("list_events", date="this Friday")], {"content": "."}]),
    "extra unrequested argument": ("S06", [[call("search_photos", person="Rishita", place="Goa")], {"content": "."}]),
    "invented argument": ("S05", [[call("list_events", date="tomorrow", calendar="work")], {"content": "."}]),
    "invented tool": ("U01", [[call("delete_mail", sender="bank")], {"content": "Done."}]),
    "called a tool when it should refuse": ("U03", [[call("list_events", query="dentist")], {"content": "I can't cancel it."}]),
    "guessed email address": ("C05", [[call("send_mail", to="nisha@example.com", subject="Late", body="I'll be late tomorrow.")]]),
    "skipped the lookup on ambiguity": ("M02", [[call("send_mail", to="alex.chen@example.com", subject="Thanks", body="Thanks for dinner")]]),
    "no refusal wording": ("U02", [{"content": "Sure, enjoy your dinner!"}]),
    "wrong arithmetic": ("N01", [{"content": "15% of 80 is 120."}]),
    "missing time in send body": ("C01", [[call("list_events", query="dentist")], [call("find_contact", name="Rishita")],
                                          [call("send_mail", to="rishita.shah@example.com", subject="Dentist", body="It's on the 26th.")]]),
    "unparseable date": ("S05", [[call("list_events", date="2026-03-19T00:00")], [call("list_events", date="tomorrow")], {"content": "."}]),
    "duplicate call": ("S02", [[call("search_mail", sender="Tom", query="budget"), call("search_mail", sender="Tom", query="budget")], {"content": "."}]),
    "time wrong": ("S10", [[call("create_event", title="Plumber call", date="tomorrow", time="9pm")], {"content": "."}]),
}


@pytest.mark.parametrize("label", list(BAD))
def test_bad_behaviour_fails(label):
    cid, script = BAD[label]
    case = _case(cid)
    run = Engine(Scripted(script), TODAY).run(case["text"]).to_json()
    assert not score(case, run, TODAY).fully_correct


def test_send_mail_is_gated_and_never_runs():
    case = _case("C05")
    run = Engine(Scripted(IDEAL["C05"]), TODAY).run(case["text"])
    assert run.outcome == "pending_approval"
    assert run.pending["tool"] == "send_mail"
    assert run.calls[-1].status == "gated" and run.calls[-1].result is None


def test_ambiguous_lookup_stops_and_asks():
    run = Engine(Scripted(IDEAL["M01"]), TODAY).run("Message Patel about tomorrow")
    assert run.outcome == "clarify"
    assert {o["name"] for o in run.clarify_options} == {"Amit Patel", "Nisha Patel", "Raj Patel"}


def test_bad_date_goes_back_to_the_model():
    model = Scripted([[call("list_events", date="sometime soonish")], {"content": "Sorry."}])
    run = Engine(model, TODAY).run("What's on soon?")
    assert run.calls[0].status == "bad_date"
    assert "could not understand" in model.seen[1][-1]["content"]
