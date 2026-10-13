"""The conversation epoch: moved on by every switch between demo and real mode, kept in state.json, reported in
GET /status, and a message to a conversation from an older epoch gets a `reset` event and a new conversation.
Invented data only."""

from __future__ import annotations

import json
import threading
from datetime import date

import pytest
from starlette.testclient import TestClient

from mydata.service.api import create_app
from mydata.service.assistant import Assistant
from mydata.service.auth import AgentStore, Authenticator
from mydata.service.config import Settings
from mydata.service.modes import ModeController
from mydata.service.state import HostState
from mydata.service.sync import SyncService
from mydata.sources.accounts import Accounts
from mydata.sources.secrets import MemorySecretStore

from service_helpers import ASSISTANT_TOKEN, TODAY, TOKEN, ReadyModels, SEND_TO_NISHA, Scripted, call, parse_sse, spied_registry

REAL_TODAY = date(2026, 10, 13)


def _link(sources: SyncService):
    """Link an account and tell the controller, as POST /accounts does."""
    account = sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)
    sources.on_accounts_changed()
    return account


def _host(tmp_path, scripts: list | None = None):
    """A host's parts as the daemon wires them, with a scripted model: (assistant, sources, modes, state)."""
    queue = scripts if scripts is not None else []
    registry, _ = spied_registry()
    assistant = Assistant(Settings(home=tmp_path), registry,
                          model_factory=lambda: Scripted(queue.pop(0) if queue else [{"content": "Hi."}]),
                          today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    state = HostState(tmp_path)
    modes = ModeController(assistant, sources, real_today=lambda: REAL_TODAY, state=state)
    sources.on_accounts_changed = modes.refresh
    modes.refresh()
    return assistant, sources, modes, state


def _types(events):
    return [e["type"] for e in events]


# ---------------------------------------------------------------- the state file


def test_epoch_moves_on_only_when_the_mode_changes(tmp_path):
    s = HostState(tmp_path)
    assert s.conversation_epoch == 0
    assert s.conversation_epoch_for("demo") == 0
    assert not s.path.exists()  # nothing to record in the first mode
    assert s.conversation_epoch_for("real") == 1
    assert s.conversation_epoch_for("real") == 1
    assert s.conversation_epoch_for("demo") == 2
    data = json.loads(s.path.read_text())
    assert (data["conversation_epoch"], data["conversation_mode"]) == (2, "demo")
    assert HostState(tmp_path).conversation_epoch == 2  # persisted


@pytest.mark.parametrize("bad", ["3", -1, True, None, 2.5])
def test_a_hand_edited_epoch_reads_as_zero(tmp_path, bad):
    (tmp_path / "state.json").write_text(json.dumps({"conversation_epoch": bad, "conversation_mode": "real"}))
    s = HostState(tmp_path)
    assert s.conversation_epoch == 0
    assert s.conversation_epoch_for("demo") == 1


def test_the_epoch_sits_beside_the_other_settings(tmp_path):
    s = HostState(tmp_path)
    s.set_theme("dusk")
    s.conversation_epoch_for("real")
    assert HostState(tmp_path).theme == "dusk" and HostState(tmp_path).conversation_epoch == 1


# ---------------------------------------------------------------- switching mode


def test_every_switch_moves_the_epoch_on_and_it_survives_a_restart(tmp_path):
    assistant, sources, modes, _ = _host(tmp_path)
    assert (modes.mode, assistant.conversation_epoch) == ("demo", 0)

    account = _link(sources)
    assert (modes.mode, assistant.conversation_epoch) == ("real", 1)
    modes.refresh()  # no switch: the same epoch
    assert assistant.conversation_epoch == 1

    # A restart in the same mode keeps the epoch: the apps' conversations were not ended by a switch.
    again, _, again_modes, _ = _host(tmp_path)
    assert (again_modes.mode, again.conversation_epoch) == ("real", 1)

    sources.remove_account(account.id)
    assert (modes.mode, assistant.conversation_epoch) == ("demo", 2)
    assert HostState(tmp_path).conversation_epoch == 2


def test_a_mode_change_while_the_host_was_stopped_moves_the_epoch_on(tmp_path):
    # The last run recorded real mode; this one starts in demo (its source was removed meanwhile).
    HostState(tmp_path).conversation_epoch_for("real")
    assistant, _, modes, _ = _host(tmp_path)
    assert (modes.mode, assistant.conversation_epoch) == ("demo", 2)


def test_status_reports_the_epoch(tmp_path):
    assistant, sources, _, state = _host(tmp_path)
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, assistant.registry, ReadyModels(), assistant, state=state, sources=sources)
    c = TestClient(app, base_url="http://127.0.0.1")
    h = {"Authorization": f"Bearer {ASSISTANT_TOKEN}"}
    first = c.get("/status", headers=h).json()
    assert (first["mode"], first["conversation_epoch"]) == ("demo", 0)
    _link(sources)
    after = c.get("/status", headers=h).json()
    assert (after["mode"], after["conversation_epoch"]) == ("real", 1)


# ---------------------------------------------------------------- a message to an ended conversation


def test_a_message_to_a_conversation_from_an_older_epoch_starts_a_new_one(tmp_path):
    scripts = [[[call("find_contact", name="Nisha")], {"content": "Nisha Patel."}],
               [{"content": "Hello."}], [{"content": "Hello again."}]]
    assistant, sources, _, _ = _host(tmp_path, scripts)
    events = list(assistant.reply("Find Nisha"))
    old = events[0]["conversation_id"]
    assert _types(events)[0] == "conversation" and old.startswith("e0.")
    assert assistant.history(old)

    _link(sources)
    events = list(assistant.reply("Hello", old))
    assert _types(events)[:2] == ["reset", "conversation"]
    assert events[0] == {"type": "reset", "mode": "real", "epoch": 1}
    new = events[1]["conversation_id"]
    assert new != old and new.startswith("e1.")
    assert assistant.history(old) == []  # the demo results never reach real mode
    assert [m["content"] for m in assistant.history(new) if m["role"] == "user"] == ["Hello"]

    # The new conversation goes on without another reset.
    events = list(assistant.reply("Hello again", new))
    assert _types(events)[0] == "conversation" and events[0]["conversation_id"] == new
    assert "reset" not in _types(events)


def test_an_id_from_before_a_restart_is_known_by_its_stamp(tmp_path):
    # The host's previous run was in real mode, epoch 1; this run starts in demo mode, epoch 2.
    HostState(tmp_path).conversation_epoch_for("real")
    assistant, _, _, _ = _host(tmp_path)
    assert assistant.conversation_epoch == 2
    events = list(assistant.reply("Hello", "e1.AAAAAAAAAAAAAAAA"))
    assert events[0] == {"type": "reset", "mode": "demo", "epoch": 2}
    assert events[1]["conversation_id"].startswith("e2.")
    # An id with the current stamp, or one the host never made, carries on as before.
    assert _types(list(assistant.reply("Hello", "e2.BBBBBBBBBBBBBBBB")))[0] == "conversation"
    assert _types(list(assistant.reply("Hello", "made-by-a-client")))[0] == "conversation"


def test_a_switch_while_the_message_waits_its_turn_resets_it(tmp_path):
    assistant, _, _, _ = _host(tmp_path)
    list(assistant.reply("Hi", "c1"))
    assistant._busy.acquire()  # another message is being answered
    events: list[dict] = []
    t = threading.Thread(target=lambda: events.extend(assistant.reply("Hello", "c1")))
    t.start()
    # While it waits, a switch ends every conversation (as apply_mode does, under the same lock).
    assistant._end_conversations(1, "real")
    assistant._busy.release()
    t.join(10)
    assert _types(events)[:3] == ["conversation", "reset", "conversation"]
    assert events[0]["conversation_id"] == "c1"
    assert events[1] == {"type": "reset", "mode": "demo", "epoch": 1}
    new = events[2]["conversation_id"]
    assert new.startswith("e1.") and assistant.history(new) and assistant.history("c1") == []


def test_the_reset_event_reaches_the_app_over_sse(tmp_path):
    assistant, sources, _, state = _host(tmp_path)
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, assistant.registry, ReadyModels(), assistant, state=state, sources=sources)
    c = TestClient(app, base_url="http://127.0.0.1")
    h = {"Authorization": f"Bearer {ASSISTANT_TOKEN}"}
    first = parse_sse(c.post("/assistant/messages", headers=h, json={"text": "Hi"}).text)
    cid = first[0][1]["conversation_id"]
    _link(sources)
    second = parse_sse(c.post("/assistant/messages", headers=h, json={"text": "Hi", "conversation_id": cid}).text)
    assert second[0] == ("reset", {"mode": "real", "epoch": 1})
    assert second[1][0] == "conversation" and second[1][1]["conversation_id"] != cid
    assert second[-1] == ("done", {})


def test_a_decision_does_not_reopen_an_ended_conversation(tmp_path):
    assistant, sources, _, _ = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow", "c1"))
    approval = next(e for e in events if e["type"] == "pending_approval")["approval"]
    _link(sources)
    decided = assistant.registry.decide(approval["id"], False, decided_by="app:myassistant")
    assistant.note_decision(decided)
    assert assistant.history("c1") == []
