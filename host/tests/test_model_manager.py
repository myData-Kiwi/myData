"""The host starts Ollama itself when it is installed but not running, pulls a missing model with
progress, loads it, and stops the Ollama it started on shutdown. Uses a stand-in `ollama` on PATH."""

import os
import time
from pathlib import Path

from mydata.service.config import Settings
from mydata.service.model import ModelManager

from service_helpers import free_port

FAKE = Path(__file__).parent / "fake_ollama"


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def test_starts_ollama_pulls_loads_and_stops_it(tmp_path, monkeypatch):
    monkeypatch.setenv("PATH", f"{FAKE}{os.pathsep}{os.environ['PATH']}")
    pidfile = tmp_path / "fake.pid"
    monkeypatch.setenv("FAKE_OLLAMA_PIDFILE", str(pidfile))
    settings = Settings(home=tmp_path, ollama_url=f"http://127.0.0.1:{free_port()}", model="tiny:1b")
    mm = ModelManager(settings)
    mm.start()
    seen, progress = [], []
    deadline = time.time() + 30
    while time.time() < deadline:
        s = mm.status()
        if not seen or seen[-1] != s.state:
            seen.append(s.state)
        if s.progress:
            progress.append(s.progress["percent"])
        if s.state in ("ready", "error", "ollama_missing"):
            break
        time.sleep(0.05)
    assert s.state == "ready", (seen, s.error)
    assert s.ollama_started_by_host and s.loaded
    assert "pulling" in seen and "loading" in seen
    assert max(progress) >= 50
    pid = int(pidfile.read_text())
    assert _alive(pid)
    mm.stop()
    time.sleep(0.3)
    assert not _alive(pid)


def test_ollama_not_installed_is_a_clear_state(tmp_path, monkeypatch):
    monkeypatch.setenv("PATH", str(tmp_path))
    monkeypatch.setattr("mydata.service.model.OLLAMA_CANDIDATES", [])
    mm = ModelManager(Settings(home=tmp_path, ollama_url=f"http://127.0.0.1:{free_port()}"))
    mm.start()
    deadline = time.time() + 10
    while mm.status().state not in ("ollama_missing", "error") and time.time() < deadline:
        time.sleep(0.05)
    s = mm.status()
    assert s.state == "ollama_missing" and "ollama.com" in s.error
