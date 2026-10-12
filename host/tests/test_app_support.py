"""Host features the apps rely on: stopping the host (myData only), the assistant switch, dev-setup."""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest
from starlette.testclient import TestClient

from mydata.service.api import create_app
from mydata.service.assistant import Assistant
from mydata.service.auth import AgentStore, Authenticator
from mydata.service.config import DEFAULT_CONFIG, Settings
from mydata.service.model import ModelManager
from mydata.service.state import HostState

from service_helpers import ASSISTANT_TOKEN, CLI_TOKEN, TOKEN, ReadyModels, free_port, spied_registry

FAKE = Path(__file__).parent / "fake_ollama"


def _app(tmp_path, models=None):
    registry, _ = spied_registry()
    stopped = []
    auth = Authenticator({"mydata": TOKEN, "myassistant": ASSISTANT_TOKEN, "cli": CLI_TOKEN}, AgentStore(tmp_path))
    app = create_app(auth, registry, models or ReadyModels(), Assistant(Settings(home=tmp_path), registry),
                     state=HostState(tmp_path), shutdown=lambda: stopped.append(True))
    return TestClient(app, base_url="http://127.0.0.1"), stopped, auth


def _h(t):
    return {"Authorization": f"Bearer {t}"}


def test_only_the_mydata_app_and_cli_can_stop_the_host(tmp_path):
    c, stopped, auth = _app(tmp_path)
    _, agent = auth.agents.create("x")
    assert c.post("/shutdown", headers=_h(ASSISTANT_TOKEN)).status_code == 403
    assert c.post("/shutdown", headers=_h(agent)).status_code == 403
    assert stopped == []
    assert c.post("/shutdown", headers=_h(TOKEN)).status_code == 202
    time.sleep(0.4)
    assert stopped == [True]
    assert c.post("/shutdown", headers=_h(CLI_TOKEN)).status_code == 202


def test_assistant_switch_persists_and_blocks_chat_when_off(tmp_path):
    c, _, _ = _app(tmp_path)
    r = c.put("/assistant/settings", json={"enabled": False}, headers=_h(TOKEN))
    assert r.status_code == 200 and r.json()["assistant_enabled"] is False
    assert HostState(tmp_path).assistant_enabled is False
    r = c.post("/assistant/messages", json={"text": "hi"}, headers=_h(ASSISTANT_TOKEN))
    assert r.status_code == 503 and "switched off" in r.json()["detail"]
    assert c.put("/assistant/settings", json={"enabled": True}, headers=_h(TOKEN)).json()["assistant_enabled"]


def test_status_reports_memory_and_last_error(tmp_path):
    import logging

    from mydata.service.logs import LAST_ERROR
    LAST_ERROR.handle(logging.makeLogRecord({"msg": "boom", "levelno": logging.ERROR, "levelname": "ERROR",
                                             "name": "mydata.test"}))
    c, _, _ = _app(tmp_path)
    st = c.get("/status", headers=_h(TOKEN)).json()
    assert st["memory"]["host_bytes"] > 10_000_000 and st["memory"]["model_bytes"] == 9_000_000_000
    assert st["last_error"]["message"] == "boom"


def test_switching_off_cancels_a_download_and_downloads_nothing(tmp_path, monkeypatch):
    monkeypatch.setenv("PATH", f"{FAKE}{os.pathsep}{os.environ['PATH']}")
    monkeypatch.setenv("FAKE_OLLAMA_PIDFILE", str(tmp_path / "fake.pid"))
    mm = ModelManager(Settings(home=tmp_path, ollama_url=f"http://127.0.0.1:{free_port()}", model="tiny:1b"))
    mm.start()
    deadline = time.time() + 20
    while mm.status().state != "pulling" and time.time() < deadline:
        time.sleep(0.02)
    mm.set_enabled(False)
    assert mm.status().state == "disabled" and not mm.status().loaded
    time.sleep(1)
    assert mm.status().state == "disabled"  # the cancelled pull did not finish into "ready"
    mm.retry()
    assert mm.status().state == "disabled"  # retry does nothing while off
    mm.stop()


def test_disabled_from_the_start_never_contacts_ollama(tmp_path):
    mm = ModelManager(Settings(home=tmp_path, ollama_url="http://127.0.0.1:1"), enabled=False)
    mm.start()
    time.sleep(0.3)
    s = mm.status()
    assert s.state == "disabled" and not s.ollama_reachable
    mm.stop()


def test_dev_setup_writes_the_host_command(tmp_path):
    (tmp_path / "config.toml").write_text(DEFAULT_CONFIG)
    r = subprocess.run([sys.executable, "-m", "mydata.cli", "dev-setup"], env={**os.environ, "MYDATA_HOME": str(tmp_path)},
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0
    cmd = json.loads((tmp_path / "app_config.json").read_text())["host_command"]
    assert cmd[0] == sys.executable and cmd[-1] == "start"
