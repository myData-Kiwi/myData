"""Ollama caches the rendered prompt prefix. The system message and tool definitions must be byte-identical
in the warm-up request and in every assistant request, whatever came before in the conversation."""

import json

from mydata.orchestrator.engine import request_prefix
from mydata.service.assistant import Assistant
from mydata.service.config import Settings

from service_helpers import TODAY, Scripted, call, spied_registry


class Recorder(Scripted):
    """Records exactly what would be sent to Ollama: the messages and the tools of every call."""

    sent: list = []

    def chat(self, messages, tools):
        Recorder.sent.append((json.dumps(messages[0], sort_keys=False), json.dumps(tools, sort_keys=False)))
        return super().chat(messages, tools)

    def warm(self, system, tools):
        Recorder.sent.append((json.dumps(system, sort_keys=False), json.dumps(tools, sort_keys=False)))


def test_prefix_is_byte_identical_across_warmup_and_requests(tmp_path):
    Recorder.sent = []
    registry, _ = spied_registry()
    scripts = [[[call("list_events", date="tomorrow")], {"content": "Two things."}],
               [[call("find_contact", name="Patel")]],
               [{"content": "15% of 80 is 12."}]]
    a = Assistant(Settings(home=tmp_path), registry, model_factory=lambda: Recorder(scripts.pop(0) if scripts else []),
                  today=lambda: TODAY)
    a.warm()
    list(a.reply("What's on tomorrow?", "c1"))
    list(a.reply("Message Patel about it", "c1"))  # a later turn, with history before the new message
    list(a.reply("What's 15% of 80?", "c2"))
    assert len(Recorder.sent) >= 5
    assert len(set(Recorder.sent)) == 1, "system prompt or tool definitions changed between requests"


def test_prefix_does_not_depend_on_the_date_or_the_request():
    registry, _ = spied_registry()
    assert request_prefix(registry) == request_prefix(registry)
    system, tools = request_prefix(registry)
    text = json.dumps([system, tools])
    assert "2026" not in text  # nothing dated in the cached part: the demo date or today must not leak in
