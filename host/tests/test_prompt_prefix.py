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


# ---------------------------------------------------------------- demo and real mode

import hashlib  # noqa: E402
from datetime import date  # noqa: E402

from mydata.orchestrator.engine import SYSTEM_PROMPT  # noqa: E402
from mydata.service.modes import REAL_SYSTEM_PROMPT, ModeController  # noqa: E402
from mydata.service.sync import SyncService  # noqa: E402
from mydata.sources.accounts import Accounts  # noqa: E402
from mydata.sources.secrets import MemorySecretStore  # noqa: E402
from mydata.tools import default_registry  # noqa: E402

# sha256 of json.dumps(request_prefix(default_registry(), followup=mode)), captured before real mode existed.
# Demo mode's prefix must stay byte for byte what it was ("full" and "rule" render the same prefix).
DEMO_PREFIX_SHA256 = {
    "full": "e90610d9c2e6526694c36da31f9d149b5ce631c46b84b03fc14dd435cd0e95b3",
    "rule": "e90610d9c2e6526694c36da31f9d149b5ce631c46b84b03fc14dd435cd0e95b3",
    "field": "d5327230eb59b3cc10762136ea9cbef1ad97f28a47c202bd50160351110eae75",
}


def _sha(prefix) -> str:
    return hashlib.sha256(json.dumps(prefix).encode()).hexdigest()


def test_demo_prefix_is_unchanged_from_before_real_mode():
    for mode, digest in DEMO_PREFIX_SHA256.items():
        assert _sha(request_prefix(default_registry(), followup=mode)) == digest, mode


def _run_mode(tmp_path, real: bool) -> list:
    """Warm up, then three replies (one a later turn of the same conversation); returns every prefix sent."""
    Recorder.sent = []
    registry, _ = spied_registry()
    scripts = [[[call("list_events", date="tomorrow")], {"content": "Two things."}],
               [[call("find_contact", name="Patel")]],
               [{"content": "15% of 80 is 12."}]]
    a = Assistant(Settings(home=tmp_path), registry, model_factory=lambda: Recorder(scripts.pop(0) if scripts else []),
                  today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    modes = ModeController(a, sources, real_today=lambda: date(2026, 10, 13))
    if real:
        sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)
    assert modes.refresh() == ("real" if real else "demo")
    a.warm()
    list(a.reply("What's on tomorrow?", "c1"))
    list(a.reply("Message Patel about it", "c1"))
    list(a.reply("What's 15% of 80?", "c2"))
    assert len(Recorder.sent) >= 5
    return list(Recorder.sent)


def test_prefix_is_byte_identical_within_demo_mode_and_equal_to_the_old_one(tmp_path):
    sent = _run_mode(tmp_path, real=False)
    assert len(set(sent)) == 1
    system, tools = (json.loads(x) for x in sent[0])
    assert system == {"role": "system", "content": SYSTEM_PROMPT}
    assert _sha([system, tools]) == DEMO_PREFIX_SHA256["rule"]


def test_prefix_is_byte_identical_within_real_mode(tmp_path):
    sent = _run_mode(tmp_path, real=True)
    assert len(set(sent)) == 1, "system prompt or tool definitions changed between requests in real mode"
    system, tools = (json.loads(x) for x in sent[0])
    assert system == {"role": "system", "content": REAL_SYSTEM_PROMPT}
    assert [t["function"]["name"] for t in tools] == ["find_contact", "list_events"]
    assert "2026" not in sent[0][0] + sent[0][1]  # the real date never enters the cached part either
