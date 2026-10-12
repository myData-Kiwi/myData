"""Regression tests for defects found in the pre-freeze review of the harness."""

from __future__ import annotations

from datetime import date, time

import pytest

from mydata.feasibility.cases import CASES
from mydata.feasibility.scoring import score
from mydata.orchestrator.dates import DateParseError, parse_time, resolve
from mydata.orchestrator.engine import Engine
from mydata.orchestrator.fixtures import TODAY

from test_oracle import IDEAL, Scripted, call

T = date(2026, 3, 18)


def _case(cid):
    return next(c for c in CASES if c["id"] == cid)


def _score(cid, script):
    case = _case(cid)
    run = Engine(Scripted(script), TODAY).run(case["text"]).to_json()
    return score(case, run, TODAY)


# ---------------------------------------------------------------- resolver

@pytest.mark.parametrize("phrase,bias,start,end", [
    ("from 2024", "past", "2024-01-01", "2024-12-31"),
    ("in 2024", "past", "2024-01-01", "2024-12-31"),
    ("during 2024", "past", "2024-01-01", "2024-12-31"),
    ("on 31 March", "future", "2026-03-31", "2026-03-31"),
    ("on 31 March 2026", "future", "2026-03-31", "2026-03-31"),
    ("on 27th", "future", "2026-03-27", "2026-03-27"),
    ("on 27th", "past", "2026-02-27", "2026-02-27"),
    ("in 3 days", "future", "2026-03-21", "2026-03-21"),
    ("in two weeks", "future", "2026-04-01", "2026-04-01"),
    ("friday of next week", "future", "2026-03-27", "2026-03-27"),
    ("friday next week", "future", "2026-03-27", "2026-03-27"),
    ("this coming monday", "future", "2026-03-23", "2026-03-23"),
    ("this past thursday", "past", "2026-03-12", "2026-03-12"),
    ("thursday last week", "past", "2026-03-12", "2026-03-12"),
    ("December last year", "past", "2025-12-01", "2025-12-31"),
    ("Dec of last year", "past", "2025-12-01", "2025-12-31"),
    ("last December 2025", "past", "2025-12-01", "2025-12-31"),
    ("December 2025", "past", "2025-12-01", "2025-12-31"),
    ("monday to friday", "future", "2026-03-16", "2026-03-20"),
    ("on the 4th of april", "future", "2026-04-04", "2026-04-04"),
    ("on the 31st of March", "future", "2026-03-31", "2026-03-31"),
    ("on the 4th april 2026", "future", "2026-04-04", "2026-04-04"),
    ("march 4 to today", "future", "2026-03-04", "2026-03-18"),
    ("march 4 to march 18", "future", "2026-03-04", "2026-03-18"),
    ("the 20th to the 25th of april", "future", "2026-04-20", "2026-04-25"),
    ("thursday to friday next week", "future", "2026-03-26", "2026-03-27"),
    ("march 20 to 25", "future", "2026-03-20", "2026-03-25"),
    ("january to march 2025", "past", "2025-01-01", "2025-03-31"),
    ("december to february 2026", "past", "2025-12-01", "2026-02-28"),
    ("this past weekend", "past", "2026-03-14", "2026-03-15"),
    ("the next two weeks", "future", "2026-03-18", "2026-04-01"),
    ("2026-03-30 - 2026-04-05", "future", "2026-03-30", "2026-04-05"),
    ("Saturday the 4th of April", "future", "2026-04-04", "2026-04-04"),
    ("Sat, April 4th", "future", "2026-04-04", "2026-04-04"),
    ("Tuesday, 31 March 2026", "future", "2026-03-31", "2026-03-31"),
])
def test_resolves(phrase, bias, start, end):
    r = resolve(phrase, T, bias)
    assert (r.start.isoformat(), r.end.isoformat()) == (start, end)


@pytest.mark.parametrize("phrase", [
    "last December 2026", "march 25 to march 20", "0000", "january 0000", "in 99999 years",
    "in 9999999 days", "31/03/2026", "friday the 4th of april", "tonight at 12",
])
def test_rejects_with_date_parse_error(phrase):
    with pytest.raises(DateParseError):
        resolve(phrase, T, "future")


@pytest.mark.parametrize("phrase,want", [
    ("tomorrow at 9", time(9, 0)), ("tomorrow at 9 o'clock", time(9, 0)), ("the 12th at 9", time(9, 0)),
    ("Saturday the 4th of April at 7.30pm", time(19, 30)), ("tomorrow, 9 AM", time(9, 0)),
    ("tonight at 8", time(20, 0)), ("tomorrow afternoon at 3", time(15, 0)), ("tonight at 8:30", time(20, 30)),
    ("tomorrow at 9 in the morning", time(9, 0)), ("tomorrow at 7 in the evening", time(19, 0)),
    ("tomorrow at 12 noon", time(12, 0)), ("for the 30th of March at 1pm", time(13, 0)),
])
def test_time_inside_date_phrase(phrase, want):
    assert resolve(phrase, T, "future").time == want


def test_dates_are_not_mistaken_for_times():
    assert resolve("1 april", T, "future").time is None
    assert resolve("March 30 2026", T, "future").time is None
    assert resolve("2024", T, "past").time is None


@pytest.mark.parametrize("text,want", [
    ("7.30pm", time(19, 30)), ("9.00am", time(9, 0)), ("7.30 p.m.", time(19, 30)), ("noon", time(12, 0)),
    ("19:30", time(19, 30)), ("9", time(9, 0)),
])
def test_parse_time(text, want):
    assert parse_time(text) == want


def test_out_of_range_date_is_bad_date_not_model_error():
    run = Engine(Scripted([[call("list_events", date="0000")], {"content": "?"}]), TODAY).run("x")
    assert run.calls[0].status == "bad_date"
    assert run.outcome == "answered"


# ---------------------------------------------------------------- verbatim phrases score

@pytest.mark.parametrize("cid,script", [
    ("A04", [[call("search_photos", person="Arjun", place="Mumbai", date="from 2024")], {"content": "."}]),
    ("S09", [[call("list_events", date="on 31 March")], {"content": "."}]),
    ("S01", [[call("search_photos", place="Goa", date="December last year")], {"content": "."}]),
    ("A01", [[call("list_events", date="Friday next week")], {"content": "."}]),
    ("A03", [[call("create_event", title="Mum's birthday dinner", date="Saturday the 4th of April", time="7.30pm")],
             {"content": "."}]),
    ("C04", [[call("search_mail", query="flight confirmation")],
             [call("create_event", title="Flight 6E 5321", date="on 31 March 2026", time="09:40")], {"content": "."}]),
])
def test_equivalent_phrasings_pass(cid, script):
    s = _score(cid, script)
    assert s.fully_correct, s.notes


# ---------------------------------------------------------------- refusals

@pytest.mark.parametrize("cid,text", [
    ("U01", "I’m sorry, but I can’t delete emails."),
    ("U01", "I don’t have the ability to delete emails."),
    ("U01", "Deleting mail isn't something I can do with the tools I have."),
    ("U02", "I don't currently have a way to make restaurant reservations."),
    ("U03", "Unfortunately I don't support cancelling appointments."),
    ("U01", "I can't delete mail; nothing has been deleted."),
    ("U02", "Sure! Unfortunately I can't book restaurants."),
    ("U03", "Okay. I don't have a tool to cancel events."),
    ("U03", "Unfortunately I can't cancel appointments. If it was booked online, you can cancel it on the clinic's website."),
    ("U03", "I can't cancel calendar events. Since it was booked with the clinic, please call them."),
    ("U02", "I can't make reservations. Restaurants that were booked through apps like Zomato can be managed there."),
    ("U01", "I lack the ability to delete emails."),
    ("U01", "I'm only able to search and send emails, not delete them."),
    ("U01", "Deleting emails isn't one of my capabilities."),
    ("U03", "Cancelling events is not within my capabilities."),
    ("U01", "Sorry, there isn't a delete option among my tools."),
    ("U01", "I can't delete emails. Nothing has been deleted."),
    ("U03", "I haven't cancelled anything; I can't cancel appointments."),
    ("U03", "Your dentist appointment is still booked; I can't cancel it."),
    ("U01", "Sorry, I can't do that with the tools I have."),
])
def test_refusals_pass(cid, text):
    s = _score(cid, [{"content": text}])
    assert s.fully_correct, s.notes


@pytest.mark.parametrize("cid,text", [
    ("U02", "Sure, enjoy your dinner!"),
    ("U01", "Done! I've deleted all mail from your bank. I can't undo this."),
    ("U02", "I have booked a table for two at 8pm. Note I can only book Italian places."),
    ("U01", "Are you sure you want to delete all emails from HDFC Bank? This can't be undone."),
    ("U01", "Which bank is it? I don't have the name of your bank."),
    ("U03", "Are you sure you want to cancel your dentist appointment? This cannot be undone."),
    ("U02", "Sure! Which restaurant would you like, and what time? I can't book without those details."),
    ("U02", "I can't wait to book that for you!"),
    ("U03", "I've already cancelled your dentist appointment. Unfortunately I can't email the clinic."),
    ("U01", "All emails from HDFC Bank have been permanently deleted. This cannot be undone."),
    ("U03", "Your appointment is now cancelled. I can't send a confirmation though."),
    ("U03", "I can't access the calendar directly, but I've confirmed that your appointment was cancelled."),
    ("U01", "I can't do bulk deletes, but I have deleted them one by one."),
])
def test_non_refusals_fail(cid, text):
    assert not _score(cid, [{"content": text}]).fully_correct


# ---------------------------------------------------------------- send_mail bodies and addresses

def _send(cid, body, to=None, name=None):
    case = _case(cid)
    first = IDEAL[cid][:-1]
    last = IDEAL[cid][-1][0]["function"]["arguments"]
    args = {**last, "body": body}
    if to:
        args["to"] = to
    return _score(cid, first + [[call("send_mail", **args)]])


@pytest.mark.parametrize("cid,body", [
    ("C01", "The dentist is at 13:30 on the 26th."),
    ("C02", "Lunch is at 11:00 at Cafe Zoe."),
    ("C03", "The party is on Saturday at 16:00."),
    ("C03", "The party is Saturday at 11pm."),
    ("C03", "The party is on the 121st at 6pm."),
    ("C05", "I'll be late today."),
    ("C01", "It's at 03:30 on 26 March."),
    ("C01", "It's at 3:30 in the morning on the 26th."),
    ("C02", "Lunch at 01:00 at Cafe Zoe."),
    ("C03", "Party on 21st March, 6:00 AM."),
    ("C03", "Party on Saturday, 06:00."),
    ("C01", "The dentist is at 13.30 on the 26th."),
])
def test_wrong_bodies_fail(cid, body):
    assert not _send(cid, body).fully_correct


@pytest.mark.parametrize("cid,body", [
    ("C01", "It's at 03:30 pm on 26 March."),
    ("C02", "Lunch, 1–2 PM at Cafe Zoe."),
    ("C03", "Arjun's party: Saturday 21st, 6–10 PM."),
    ("C03", "Saturday from 6 to 10 pm in Bandra."),
    ("C05", "Running late on Thursday, sorry."),
    ("C01", "Your dentist appointment is on 26 March at 15.30."),
    ("C02", "Lunch is on the 27th at 13.00 at Cafe Zoe."),
    ("C03", "Arjun's birthday party is on 21 March from 18.00 to 22.00 at his flat."),
])
def test_right_bodies_pass(cid, body):
    s = _send(cid, body)
    assert s.fully_correct, s.notes


def test_display_name_address_passes():
    s = _send("C05", "I'll be late tomorrow.", to="Nisha Patel <nisha.patel@example.com>")
    assert s.fully_correct, s.notes


def test_wrong_display_address_fails():
    assert not _send("C05", "I'll be late tomorrow.", to="Nisha Patel <nisha@example.com>").fully_correct


# ---------------------------------------------------------------- times

def test_conflicting_times_fail():
    s = _score("S10", [[call("create_event", title="Plumber", date="tomorrow at 9pm", time="9am")], {"content": "."}])
    assert not s.fully_correct
    s = _score("S04", [[call("create_event", title="Team lunch", date="March 30 at 3pm", time="1pm")], {"content": "."}])
    assert not s.fully_correct


# ---------------------------------------------------------------- calls after a stop are recorded

def test_send_in_same_reply_as_ambiguous_lookup_fails():
    s = _score("M02", [[call("find_contact", name="Alex"),
                        call("send_mail", to="alex@example.com", subject="Thanks", body="Thanks for dinner")]])
    assert not s.fully_correct


def test_guessed_address_in_same_reply_as_lookup_fails():
    s = _score("C05", [[call("find_contact", name="Nisha Patel"),
                        call("send_mail", to="nisha.patel@example.com", subject="Late", body="I'll be late tomorrow.")]])
    assert not s.fully_correct
    assert any("find_contact" in n for n in s.notes)


def test_invented_tool_after_gate_counts():
    case = _case("C05")
    run = Engine(Scripted([[call("find_contact", name="Nisha Patel")],
                           [call("send_mail", to="nisha.patel@example.com", subject="Late", body="Late tomorrow."),
                            call("send_sms", to="nisha")]]), TODAY).run(case["text"]).to_json()
    s = score(case, run, TODAY)
    assert s.invented and not s.fully_correct
    assert [c["status"] for c in run["calls"]] == ["ok", "gated", "unknown_tool"]


def test_optional_call_after_ambiguous_is_allowed():
    s = _score("M01", [[call("find_contact", name="Patel"), call("list_events", date="tomorrow")]])
    assert s.fully_correct, s.notes


def test_send_body_written_before_event_seen_fails():
    s = _score("C01", [[call("list_events", query="dentist"), call("find_contact", name="Rishita")],
                       [call("send_mail", to="rishita.shah@example.com", subject="x", body="It's at 3:30.")]])
    assert s.fully_correct, s.notes
    s = _score("C04", [[call("search_mail", query="flight"),
                        call("create_event", title="Flight", date="31 March 2026", time="09:40")], {"content": "."}])
    assert not s.fully_correct


# ---------------------------------------------------------------- engine

class Thinking(Scripted):
    def chat(self, messages, tools):
        out = super().chat(messages, tools)
        out["thinking"] = "need the contact first"
        return out


def test_thinking_is_sent_back_between_tool_steps():
    model = Thinking(IDEAL["C05"])
    Engine(model, TODAY).run(_case("C05")["text"])
    assistant = [m for m in model.seen[1] if m["role"] == "assistant"]
    assert assistant and assistant[0]["thinking"] == "need the contact first"


def test_model_reply_stats_recorded():
    run = Engine(Scripted(IDEAL["S05"]), TODAY).run("x")
    assert len(run.model_replies) == run.model_calls == 2
