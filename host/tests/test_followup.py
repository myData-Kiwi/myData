"""Results first, sentences only when needed: the engine's follow-up policies (followup.py)."""

from mydata.orchestrator.engine import Engine, request_prefix
from mydata.orchestrator.followup import ANSWER_INSTRUCTION, sentence_needed
from mydata.orchestrator.fixtures import TODAY
from mydata.tools import default_registry


def call(_tool, **args):
    return {"function": {"name": _tool, "arguments": args}}


class Model:
    """Scripted replies; records how each call was made. Streams, so the engine can stop it early."""

    name = "scripted"
    streams = True

    def __init__(self, replies):
        self.replies, self.calls = list(replies), []

    def chat(self, messages, tools, on_delta=None, max_text=None, stop_on_text=False):
        self.calls.append({"messages": list(messages), "tools": tools, "max_text": max_text, "stop_on_text": stop_on_text})
        r = self.replies.pop(0) if self.replies else {"content": "Done."}
        if isinstance(r, list):
            return {"content": "", "tool_calls": r}
        text = r["content"]
        if stop_on_text and text.strip():
            return {"content": "", "tool_calls": [], "aborted": True}
        if max_text is not None:
            text = " ".join(text.split()[:max_text])
        if on_delta:
            for w in text.split():
                on_delta(w + " ")
        return {"content": text, "tool_calls": []}


def run(mode, replies, request="What's on my calendar tomorrow?", events=None):
    m = Model(replies)
    sink = events if events is not None else []
    r = Engine(m, TODAY, followup=mode).run(request, on_event=sink.append).to_json()
    return r, m, sink


def test_field_show_ends_without_a_second_call():
    r, m, events = run("field", [[call("list_events", date="tomorrow", then="show")]])
    assert len(m.calls) == 1 and r["reply_by"] == "code" and r["outcome"] == "answered"
    assert r["final_text"] == "2 events on Thursday 19 March"
    result = next(e for e in events if e["type"] == "result")
    assert result["kind"] == "events" and [i["title"] for i in result["items"]] == ["Personal training", "Call with mum"]
    assert r["calls"][0]["args"] == {"date": "tomorrow"} and r["calls"][0]["then"] == "show"  # never reaches the tool
    assert r["seconds_to_result"] is not None


def test_field_answer_asks_for_one_capped_sentence():
    r, m, _ = run("field", [[call("list_events", date="tomorrow", then="answer")],
                            {"content": "Yes, you are free at 3pm tomorrow."}], request="Am I free at 3 tomorrow?")
    assert len(m.calls) == 2 and m.calls[1]["max_text"] == 40
    assert m.calls[1]["messages"][-1] == {"role": "system", "content": ANSWER_INSTRUCTION}
    assert r["reply_by"] == "model" and r["final_text"].startswith("Yes")


def test_field_continue_and_missing_then_keep_the_old_loop():
    r, m, _ = run("field", [[call("find_contact", name="Rishita", then="continue")],
                            [call("send_mail", to="rishita.shah@example.com", subject="Hi", body="Hello")]],
                  request="Email Rishita hello")
    assert r["outcome"] == "pending_approval" and m.calls[1]["max_text"] is None
    r, m, _ = run("field", [[call("list_events", date="tomorrow")], {"content": "Two things."}])
    assert len(m.calls) == 2 and r["reply_by"] == "model"


def test_field_definitions_carry_then_except_on_irreversible_tools():
    _, tools = request_prefix(default_registry(), followup="field")
    with_then = {t["function"]["name"] for t in tools if "then" in t["function"]["parameters"]["properties"]}
    assert "send_mail" not in with_then and {"list_events", "search_mail", "find_contact"} <= with_then
    _, plain = request_prefix(default_registry())
    assert not any("then" in t["function"]["parameters"]["properties"] for t in plain)


def test_rule_probe_stops_at_text_and_code_writes_the_reply():
    r, m, _ = run("rule", [[call("list_events", date="tomorrow")], {"content": "You have two events."}])
    assert m.calls[1]["stop_on_text"] and r["reply_by"] == "code"
    assert r["final_text"] == "2 events on Thursday 19 March"
    assert r["messages"][-1] == {"role": "assistant", "content": r["final_text"]}


def test_rule_probe_lets_a_chain_continue():
    r, m, _ = run("rule", [[call("list_events", query="dentist")], [call("find_contact", name="Rishita")],
                           [call("send_mail", to="rishita.shah@example.com", subject="x", body="It's at 3:30.")]],
                  request="Email Rishita the time of my dentist appointment")
    assert r["outcome"] == "pending_approval" and m.calls[1]["stop_on_text"]


def test_rule_answer_for_a_question_the_list_does_not_answer():
    r, m, _ = run("rule", [[call("list_events", date="Friday")], {"content": "No, you have yoga at 7."}],
                  request="Am I free on Friday morning?")
    assert m.calls[1]["max_text"] == 40 and r["reply_by"] == "model"


def test_full_mode_is_unchanged():
    r, m, events = run("full", [[call("list_events", date="tomorrow")], {"content": "Two things."}])
    assert len(m.calls) == 2 and m.calls[1]["max_text"] is None and r["reply_by"] == "model"
    assert any(e["type"] == "result" for e in events)  # the result is still shown at once


def test_sentence_rule():
    for q in ["Am I free at 3 on Friday?", "Is there a clash with my dentist appointment?",
              "Will I make it to the party after yoga?", "Why is my flight not in the calendar?"]:
        assert sentence_needed(q), q
    for q in ["What's on my calendar tomorrow?", "Show me pictures of Rishita", "Find emails from Tom",
              "When is my vet appointment?", "Do I have anything on March 31?"]:
        assert not sentence_needed(q), q
