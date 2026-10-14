"""Approvals are bound to the mode, the conversation epoch and the handler they were held with.

A send_mail held over demo data must never run once the host is in real mode, and a call held in one
conversation epoch never runs in another: the switch fails every pending approval, and deciding checks the
binding again. Invented data only.
"""

from __future__ import annotations

import dataclasses
import threading

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
from mydata.tools import ToolResult
from mydata.tools import registry as registry_module
from mydata.tools.registry import ModeRefused, call_digest, handler_id

from service_helpers import ASSISTANT_TOKEN, SEND_TO_NISHA, TODAY, ReadyModels, Scripted, spied_registry

ARGS = {"to": "nisha.patel@example.com", "subject": "Late", "body": "I'll be late tomorrow."}


def _host(tmp_path, scripts: list | None = None):
    """A host's parts as the daemon wires them, with a scripted model and a spy on send_mail."""
    queue = list(scripts or [])
    registry, spy = spied_registry()
    assistant = Assistant(Settings(home=tmp_path), registry,
                          model_factory=lambda: Scripted(queue.pop(0) if queue else [{"content": "Hi."}]),
                          today=lambda: TODAY)
    sources = SyncService(tmp_path, Accounts(tmp_path, MemorySecretStore()))
    state = HostState(tmp_path)
    modes = ModeController(assistant, sources, state=state)
    sources.on_accounts_changed = modes.refresh
    modes.refresh()
    return assistant, sources, spy, state


def _link(sources: SyncService):
    account = sources.accounts.add("icloud", "ava.fictional@example.com", "invented-pw", verify=lambda e, p: None)
    sources.on_accounts_changed()
    return account


def test_a_send_held_in_demo_mode_fails_when_approved_in_real_mode(tmp_path):
    """The regression the plan names: hold send_mail in demo mode, switch to real, approve. The result is
    failed, and the handler never ran."""
    assistant, sources, spy, _ = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow"))
    held = next(e for e in events if e["type"] == "pending_approval")["approval"]
    assert (held["status"], held["mode"], held["conversation_epoch"]) == ("pending", "demo", 0)

    _link(sources)
    assert assistant.registry.mode == "real"
    failed = assistant.registry.approval(held["id"])
    assert failed.status == "failed" and "switched to real mode" in failed.error and failed.decided_by is None

    decided = assistant.registry.decide(held["id"], True, decided_by="app:myassistant")
    assert decided.status == "failed" and decided.decided_by is None
    assert spy.calls == []
    assert assistant.registry.approvals("pending") == []


def test_over_http_the_app_sees_the_failed_approval(tmp_path):
    """The app's Approve gets the approval back, failed with the reason (not a 409), and nothing runs."""
    assistant, sources, spy, state = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow"))
    approval_id = next(e for e in events if e["type"] == "pending_approval")["approval"]["id"]
    auth = Authenticator({"myassistant": ASSISTANT_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, assistant.registry, ReadyModels(), assistant, state=state, sources=sources)
    h = {"Authorization": f"Bearer {ASSISTANT_TOKEN}"}
    with TestClient(app, base_url="http://127.0.0.1") as c:
        _link(sources)
        assert c.get("/approvals?status=pending", headers=h).json() == []
        r = c.post(f"/approvals/{approval_id}", headers=h, json={"decision": "approve"})
        assert r.status_code == 200 and r.json()["status"] == "failed" and "nothing was done" in r.json()["error"]
        assert c.get(f"/approvals/{approval_id}", headers=h).json()["status"] == "failed"
    assert spy.calls == []


def test_a_switch_back_to_demo_does_not_revive_it(tmp_path):
    assistant, sources, spy, _ = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow"))
    approval_id = next(e for e in events if e["type"] == "pending_approval")["approval"]["id"]
    account = _link(sources)
    sources.remove_account(account.id)
    assert assistant.registry.mode == "demo" and "send_mail" in assistant.registry
    assert assistant.registry.decide(approval_id, True, decided_by="app:myassistant").status == "failed"
    assert spy.calls == []


def test_approving_after_an_epoch_change_fails(tmp_path):
    """The mode changed while the host was stopped (state.json already had the next epoch): the epoch moves
    on in the same mode, and a call held before fails too."""
    assistant, _, spy, _ = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow"))
    approval_id = next(e for e in events if e["type"] == "pending_approval")["approval"]["id"]
    assistant.end_conversations(assistant.conversation_epoch + 1)
    decided = assistant.registry.decide(approval_id, True, decided_by="app:myassistant")
    assert decided.status == "failed" and "ended" in decided.error
    assert spy.calls == []


def test_a_held_call_in_the_same_mode_and_epoch_still_runs(tmp_path):
    assistant, _, spy, _ = _host(tmp_path, [list(SEND_TO_NISHA)])
    events = list(assistant.reply("Tell Nisha Patel I'll be late tomorrow"))
    approval_id = next(e for e in events if e["type"] == "pending_approval")["approval"]["id"]
    assistant.conversation_epoch = assistant.conversation_epoch  # no change: nothing fails
    assert assistant.registry.decide(approval_id, True, decided_by="app:myassistant").status == "approved"
    assert spy.calls == [ARGS]


# ---------------------------------------------------------------- the check when deciding


def test_deciding_checks_the_binding_again():
    """Even if something changed the registry without failing the pending approvals, approving one held in
    another mode, epoch or with another handler fails without running anything."""
    def held(registry):
        return registry.invoke("send_mail", ARGS, caller="test").approval.id

    registry, spy = spied_registry()
    approval_id = held(registry)
    registry.mode = "real"  # behind the gate's back
    assert registry.decide(approval_id, True, decided_by="app:mydata").status == "failed"

    registry, spy2 = spied_registry()
    approval_id = held(registry)
    registry.conversation_epoch += 1
    assert registry.decide(approval_id, True, decided_by="app:mydata").status == "failed"

    registry, spy3 = spied_registry()
    approval_id = held(registry)
    other = dataclasses.replace(registry.get("send_mail"), handler=lambda a, d, t: ToolResult({"status": "sent"}))
    registry._tools["send_mail"] = other
    a = registry.decide(approval_id, True, decided_by="app:mydata")
    assert a.status == "failed" and "nothing was done" in a.error
    assert spy.calls == spy2.calls == spy3.calls == []


def test_the_digest_covers_the_mode_the_epoch_and_the_handler():
    base = {"mode": "demo", "epoch": 0, "handler": "x.send"}
    digest = call_digest("send_mail", ARGS, **base)
    for change in ({"mode": "real"}, {"epoch": 1}, {"handler": "y.send"}):
        assert call_digest("send_mail", ARGS, **{**base, **change}) != digest
    registry, spy = spied_registry()
    a = registry.invoke("send_mail", ARGS, caller="test").approval
    assert (a.mode, a.conversation_epoch, a.handler) == ("demo", 0, "service_helpers.Spy.handler")
    assert a.handler == handler_id(registry.get("send_mail"))
    assert a.digest == call_digest("send_mail", ARGS, mode="demo", epoch=0, handler=a.handler)


def test_rejecting_a_failed_approval_leaves_it_failed():
    registry, spy = spied_registry()
    approval_id = registry.invoke("send_mail", ARGS, caller="test").approval.id
    registry.set_epoch(1)
    a = registry.decide(approval_id, False, decided_by="app:mydata")
    assert a.status == "failed" and a.decided_by is None and spy.calls == []


# ---------------------------------------------------------------- a switch during a call


def _switch_soon(registry, mode: str):
    """Start a switch to `mode` in another thread and give it time to land, as a racing refresh would."""
    tools = [registry.get(n) for n in registry.names()]
    t = threading.Thread(target=lambda: registry.replace_tools(tools, mode=mode))
    t.start()
    t.join(0.3)
    return t


def test_a_switch_during_an_approved_run_waits_for_it(monkeypatch):
    """decide() checks the binding and then runs: a switch landing between the two must wait, so the held
    call runs wholly in the mode it was held in (or not at all), never in the new one."""
    registry, _ = spied_registry()
    seen = []

    def handler(args, dates, today):
        seen.append(registry.mode)
        return ToolResult({"status": "sent"})

    registry.replace_tools([dataclasses.replace(registry.get(n), handler=handler) if n == "send_mail"
                            else registry.get(n) for n in registry.names()])
    held = registry.invoke("send_mail", ARGS, caller="test").approval
    switches = []
    real_digest = registry_module.call_digest

    def racing_digest(*a, **k):  # decide's check of the binding: a switch to real starts right after it
        out = real_digest(*a, **k)
        switches.append(_switch_soon(registry, "real"))
        return out

    monkeypatch.setattr(registry_module, "call_digest", racing_digest)
    decided = registry.decide(held.id, True, decided_by="user")
    (switch,) = switches
    switch.join(5)
    assert not switch.is_alive() and registry.mode == "real"
    assert decided.status == "approved" and seen == ["demo"]


def test_an_agent_call_cannot_run_over_real_data_after_a_switch():
    """MCP refuses agents in real mode inside the registry: the check and the run are one step, so a switch
    to real between them waits, and a call after it is refused without running."""
    registry, _ = spied_registry()
    seen = []

    def handler(args, dates, today):
        seen.append(registry.mode)
        return ToolResult({"matches": []})

    registry.replace_tools([dataclasses.replace(registry.get(n), handler=handler) if n == "find_contact"
                            else registry.get(n) for n in registry.names()])
    validate = registry.validate
    switches = []

    def racing_validate(*a, **k):
        switches.append(_switch_soon(registry, "real"))
        return validate(*a, **k)

    registry.validate = racing_validate
    inv = registry.invoke("find_contact", {"name": "Nisha"}, caller="agent:test", modes=("demo",))
    switches[0].join(5)
    assert inv.status == "ok" and seen == ["demo"] and registry.mode == "real"

    registry.validate = validate
    with pytest.raises(ModeRefused):
        registry.invoke("find_contact", {"name": "Nisha"}, caller="agent:test", modes=("demo",))
    assert seen == ["demo"]
