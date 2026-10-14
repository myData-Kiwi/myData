"""The request log (logs/assistant.jsonl) in real mode keeps each argument's shape, never its value.

The model can copy a value from a tool result (an email address from a contact) into a later call, and a
grounding error quotes the value it rejected, so neither may reach the log in real mode. Demo mode logs
everything, as before: its data is invented. Invented data only.
"""

from __future__ import annotations

import json
from zoneinfo import ZoneInfo

from mydata.service.assistant import Assistant, arg_shapes, value_shape
from mydata.service.config import Settings
from mydata.service.modes import REAL_SYSTEM_PROMPT
from mydata.tools.mirror import mirror_tools

from service_helpers import TODAY, Scripted, call, spied_registry

AVA_EMAIL = "ava.fictional@example.com"


class _Contacts:
    def find_by_name(self, name):
        return [{"id": "c1", "name": "Ava Fictional", "emails": [AVA_EMAIL], "phones": ["+1 202 555 0101"]}]


class _Calendar:
    def events_between(self, start, end, calendar_ids=None, tz=None):
        return []


def _assistant(tmp_path, scripts, *, real: bool):
    registry, _ = spied_registry()
    settings = Settings(home=tmp_path)
    assistant = Assistant(settings, registry, model_factory=lambda: Scripted(scripts.pop(0)), today=lambda: TODAY)
    if real:
        assistant.apply_mode("real", mirror_tools(_Contacts(), _Calendar(), tz=lambda: ZoneInfo("UTC")),
                             lambda: TODAY, REAL_SYSTEM_PROMPT)
    return assistant, settings


def _entries(settings):
    return [json.loads(line) for line in (settings.log_dir / "assistant.jsonl").read_text().splitlines()]


def test_real_mode_logs_the_shape_of_each_argument_not_its_value(tmp_path):
    scripts = [[[call("find_contact", name="Ava")],
                [call("find_contact", name=AVA_EMAIL)],  # copied from the first result
                {"content": "Found her."}]]
    assistant, settings = _assistant(tmp_path, scripts, real=True)
    list(assistant.reply("Find Ava"))
    (entry,) = _entries(settings)
    assert entry["mode"] == "real" and entry["request"] == "Find Ava"  # the request text is kept
    first, second = entry["calls"]
    assert first["tool"] == second["tool"] == "find_contact" and first["status"] == "ok"
    assert first["args"] == {"name": {"type": "string", "length": 3}}
    assert second["args"] == {"name": {"type": "string", "length": len(AVA_EMAIL)}}
    logged = json.dumps(entry)
    assert AVA_EMAIL not in logged and "555 0101" not in logged and "Ava Fictional" not in logged


def test_a_rejected_value_stays_out_of_the_real_mode_log(tmp_path):
    """Grounding rejects a name found nowhere; its error quotes the name. In real mode the log keeps only
    the error's length."""
    scripts = [[[call("find_contact", name="Zephyrine Inventedname")], {"content": "Sorry."}]]
    assistant, settings = _assistant(tmp_path, scripts, real=True)
    list(assistant.reply("Who is my dentist?"))
    (entry,) = _entries(settings)
    (c,) = entry["calls"]
    assert c["status"] == "invalid_args" and c["error"]["type"] == "string" and c["error"]["length"] > 0
    assert c["args"] == {"name": {"type": "string", "length": len("Zephyrine Inventedname")}}
    assert "Zephyrine" not in json.dumps(entry)


def test_a_model_reply_quoting_the_result_stays_out_of_the_real_mode_log(tmp_path):
    """The follow-up sentence answers from the result, so it quotes it: only its shape is logged."""
    reply = f"Ava Fictional, email {AVA_EMAIL}, phone +1 202 555 0101."
    scripts = [[[call("find_contact", name="Ava")], {"content": reply}]]
    assistant, settings = _assistant(tmp_path, scripts, real=True)
    list(assistant.reply("Which one is Ava Fictional, and why?"))
    (entry,) = _entries(settings)
    assert entry["reply_by"] == "model" and entry["final_text"] == {"type": "string", "length": len(reply)}
    logged = json.dumps(entry)
    assert AVA_EMAIL not in logged and "555 0101" not in logged and "Ava Fictional, email" not in logged


def test_a_later_reply_quoting_an_earlier_result_stays_out_of_the_real_mode_log(tmp_path):
    """A reply with no tool call of its own can still quote a result from earlier in the conversation."""
    scripts = [[[call("find_contact", name="Ava")], {"content": "Found her."}],
               [{"content": f"Her email is {AVA_EMAIL}."}]]
    assistant, settings = _assistant(tmp_path, scripts, real=True)
    cid = next(e for e in list(assistant.reply("Find Ava")) if e["type"] == "conversation")["conversation_id"]
    list(assistant.reply("What was her email?", cid))
    first, second = _entries(settings)
    assert second["conversation_id"] == first["conversation_id"] and second["calls"] == []
    assert AVA_EMAIL not in json.dumps(second)


def test_demo_mode_logs_the_values_as_before(tmp_path):
    scripts = [[[call("find_contact", name="Zephyrine Inventedname")], {"content": "Sorry."}],
               [[call("find_contact", name="Nisha")], {"content": "Found."}]]
    assistant, settings = _assistant(tmp_path, scripts, real=False)
    list(assistant.reply("Who is my dentist?"))
    list(assistant.reply("Find Nisha"))
    rejected, found = _entries(settings)
    assert rejected["mode"] == "demo" and "Zephyrine" in rejected["calls"][0]["error"]
    assert found["calls"][0]["args"] == {"name": "Nisha"} and "Nisha" in found["final_text"]
    assert "nisha" in json.dumps(found["calls"][0]["result"]).lower()


def test_value_shapes():
    assert value_shape("abc") == {"type": "string", "length": 3}
    assert value_shape("") == {"type": "string", "length": 0}
    assert value_shape(["a", "b"]) == {"type": "array", "length": 2}
    assert value_shape({"k": 1}) == {"type": "object", "length": 1}
    assert value_shape(30) == {"type": "integer"} and value_shape(2.5) == {"type": "number"}
    assert value_shape(True) == {"type": "boolean"} and value_shape(None) == {"type": "null"}
    assert arg_shapes({"to": "x@example.org", "n": 2}) == {"to": {"type": "string", "length": 13},
                                                           "n": {"type": "integer"}}
    assert arg_shapes("not a dict") == {"_args": {"type": "string", "length": 10}}
