"""Grounding check unit tests. Examples are invented here, not taken from either request set."""

from mydata.orchestrator.grounding import Sources, check

EVENT = {"events": [{"title": "Piano lesson", "date": "2026-05-12", "start": "16:45", "end": "17:30",
                     "location": "Riverside Music School"}]}
CONTACT = {"matches": [{"name": "Jo Park", "email": "jo.park@example.com"}]}


def run(tool, args, request, results=(), required=(), skip=()):
    return check(tool, args, list(required), set(skip), Sources(request, list(results)))


def test_invented_optional_arguments_are_dropped():
    kept, dropped, failing = run("create_event",
                                 {"title": "Piano practice", "date": "Friday", "location": "Music room",
                                  "duration_minutes": 45},
                                 "Add piano practice on Friday", required=["title", "date"], skip={"date"})
    assert kept == {"title": "Piano practice", "date": "Friday"}
    assert set(dropped) == {"location", "duration_minutes"}
    assert not failing


def test_values_copied_from_results_are_kept():
    kept, dropped, _ = run("create_event",
                           {"title": "Piano lesson", "date": "2026-05-12", "time": "4:45pm",
                            "location": "Riverside Music School", "duration_minutes": 45},
                           "Copy my piano lesson", [EVENT], required=["title", "date"], skip={"date"})
    # Title, time and place are copied from the event, and 45 minutes is the time between its grounded
    # start and end (16:45-17:30), so everything is kept.
    assert set(kept) == {"title", "date", "time", "location", "duration_minutes"}
    assert not dropped


def test_mail_body_facts_must_come_from_sources():
    ok_body = "The lesson is on 12 May at 4:45 pm at Riverside Music School."
    bad_body = "The lesson is on 12 May at 3:15 pm."
    req = ["to", "subject", "body"]
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Lesson", "body": ok_body},
                        "Tell Jo when my piano lesson is", [EVENT, CONTACT], required=req)
    assert not failing
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Lesson", "body": bad_body},
                        "Tell Jo when my piano lesson is", [EVENT, CONTACT], required=req)
    assert "body" in failing and "3:15" in failing["body"]


def test_time_without_am_pm_matches_either_reading():
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "x", "body": "It starts at 4:45."},
                        "Tell Jo", [EVENT, CONTACT], required=["to", "subject", "body"])
    assert not failing


def test_guessed_address_fails():
    _, _, failing = run("send_mail", {"to": "jo@example.com", "subject": "Hi", "body": "Hello"},
                        "Email Jo hello", [CONTACT], required=["to", "subject", "body"])
    assert "to" in failing


def test_display_name_address_passes():
    _, _, failing = run("send_mail", {"to": "Jo Park <jo.park@example.com>", "subject": "Hi", "body": "Hello"},
                        "Email Jo hello", [CONTACT], required=["to", "subject", "body"])
    assert not failing


def test_query_words_must_come_from_the_request():
    kept, dropped, _ = run("search_mail", {"query": "invoice", "sender": "landlord"},
                           "Find the invoice Sam sent", required=[])
    assert kept == {"query": "invoice"} and "sender" in dropped


def test_inflections_match():
    kept, dropped, _ = run("search_photos", {"query": "kittens"}, "Show me pictures of my kitten", required=[])
    assert kept == {"query": "kittens"} and not dropped


def test_numbers_and_codes_in_body():
    res = [{"messages": [{"body": "Your order ZX-4410 ships on 3 June."}]}, CONTACT]
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Order", "body": "Order ZX-4410, 3 June."},
                        "Send Jo my order number", res, required=["to", "subject", "body"])
    assert not failing
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Order", "body": "Order ZX-4411."},
                        "Send Jo my order number", res, required=["to", "subject", "body"])
    assert "body" in failing


def test_required_word_argument_not_grounded_fails():
    _, _, failing = run("find_contact", {"name": "Morgan"}, "Email Jo", required=["name"])
    assert "name" in failing


class _Scripted:
    name = "scripted"

    def __init__(self, replies):
        self.replies, self.seen = list(replies), []

    def chat(self, messages, tools):
        self.seen.append(list(messages))
        r = self.replies.pop(0) if self.replies else {"content": "Done."}
        return {"content": "", "tool_calls": r} if isinstance(r, list) else {"content": r["content"], "tool_calls": []}


def _call(tool, **args):
    return {"function": {"name": tool, "arguments": args}}


def test_engine_drops_invented_optional_argument():
    from mydata.orchestrator.engine import Engine
    from mydata.orchestrator.fixtures import TODAY

    run = Engine(_Scripted([[_call("create_event", title="Gym", date="tomorrow", time="7am", location="Downtown gym")],
                            {"content": "Added."}]), TODAY, route=False, ground=True).run("Add gym tomorrow at 7am")
    c = run.calls[0]
    assert c.status == "ok" and "location" not in c.args and "location" in c.dropped_args
    assert c.args["time"] == "7am"


def test_engine_rejects_ungrounded_required_argument_and_tells_the_model():
    from mydata.orchestrator.engine import Engine
    from mydata.orchestrator.fixtures import TODAY

    model = _Scripted([[_call("send_mail", to="someone@example.com", subject="Hi", body="Hello")],
                       {"content": "Sorry."}])
    run = Engine(model, TODAY, route=False, ground=True).run("Email Sam hello")
    assert run.calls[0].status == "invalid_args" and "ungrounded" in run.calls[0].error
    assert "Use only what the user said" in model.seen[1][-1]["content"]



def test_numeric_range_is_grounded_by_its_numbers():
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Notes on slides 4-9",
                                      "body": "I went through slides 4-9."},
                        "Tell Jo I've gone through slides 4 to 9", [CONTACT], required=["to", "subject", "body"])
    assert not failing


def test_range_with_an_ungrounded_end_still_fails():
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "Slides 4-12", "body": "Done."},
                        "Tell Jo I've gone through slides 4 to 9", [CONTACT], required=["to", "subject", "body"])
    assert "subject" in failing


def test_codes_with_letters_must_appear_whole():
    res = [{"messages": [{"body": "Order ZX-4410"}]}, CONTACT]
    _, _, failing = run("send_mail", {"to": "jo.park@example.com", "subject": "x", "body": "Order ZX-9"},
                        "Send Jo my order number", res, required=["to", "subject", "body"])
    assert "body" in failing


def test_duration_from_two_grounded_times_is_kept():
    kept, dropped, _ = run("create_event", {"title": "Team retro", "date": "the 2nd of April", "time": "3pm",
                                            "duration_minutes": 90},
                           "Add a team retro on the 2nd of April from 3pm to 4:30pm", required=["title", "date"],
                           skip={"date"})
    assert kept["duration_minutes"] == 90 and not dropped


def test_duration_not_between_grounded_times_is_dropped():
    _, dropped, _ = run("create_event", {"title": "Team retro", "date": "the 2nd of April", "duration_minutes": 60},
                        "Add a team retro on the 2nd of April from 3pm to 4:30pm", required=["title", "date"],
                        skip={"date"})
    assert "duration_minutes" in dropped
