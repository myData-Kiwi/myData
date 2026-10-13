"""The apps replace a host built from another version: /status reports the host version and API version, the apps
are built against host_version.g.dart, and `mydata stop` stops a daemon started by this build or an older one."""

import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest
from starlette.testclient import TestClient

from mydata import __version__, cli
from mydata.service import version as host_code
from mydata.service.config import DEFAULT_CONFIG, Settings
from mydata.service.daemon import daemon_pid
from mydata.service.openapi import HOST_VERSION_DART, api_version, api_version_of, host_version_dart, openapi_document

from service_helpers import TOKEN, free_port, make_app

COMMITTED = Path(__file__).parent.parent / "openapi.json"


def test_committed_host_version_dart_matches_the_api():
    assert HOST_VERSION_DART.read_text() == host_version_dart(json.loads(COMMITTED.read_text())), \
        "host_version.g.dart is stale: run `uv run mydata openapi --out openapi.json`"


def test_status_reports_the_version_and_the_api_version_of_the_committed_document(tmp_path):
    app, *_ = make_app(tmp_path)
    status = TestClient(app, base_url="http://127.0.0.1").get(
        "/status", headers={"Authorization": f"Bearer {TOKEN}"}).json()
    assert status["version"] == __version__
    assert status["api_version"] == api_version_of(json.loads(COMMITTED.read_text())) == api_version()
    assert len(status["api_version"]) == 12 and int(status["api_version"], 16) >= 0
    assert status["stale"] is False


def test_stale_is_a_change_to_the_package_source_since_start(tmp_path):
    (tmp_path / "sub").mkdir()
    (tmp_path / "a.py").write_text("x = 1\n")
    (tmp_path / "sub" / "b.py").write_text("y = 1\n")
    (tmp_path / "notes.txt").write_text("not code")
    before = host_code.source_signature(tmp_path)
    assert host_code.source_signature(tmp_path) == before
    (tmp_path / "notes.txt").write_text("still not code")
    assert host_code.source_signature(tmp_path) == before
    (tmp_path / "sub" / "b.py").write_text("y = 22\n")
    assert host_code.source_signature(tmp_path) != before
    after = host_code.source_signature(tmp_path)
    (tmp_path / "c.py").write_text("")
    assert host_code.source_signature(tmp_path) != after
    assert host_code.code_changed() is False  # this test run's package has not changed since import


def test_api_version_changes_with_the_api_and_not_with_anything_else():
    doc = openapi_document()
    before = api_version_of(doc)
    assert api_version_of({**doc, "servers": [], "info": {"title": "other"}}) == before
    changed = json.loads(json.dumps(doc))
    changed["components"]["schemas"]["StatusOut"]["properties"]["extra"] = {"type": "string"}
    assert api_version_of(changed) != before


# ---------------------------------------------------------------- mydata stop/start, in process

def _status(**over) -> dict:
    return {"version": __version__, "api_version": api_version(), "stale": False,
            "model": {"name": "qwen3:14b", "state": "ready"}, **over}


@pytest.fixture
def no_kill(monkeypatch):
    """A running daemon (pid 999999) that `mydata stop` would signal; signals are recorded, never sent."""
    sent = []
    state = {"pid": 999999}
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: state["pid"])

    def kill(pid, sig):
        sent.append((pid, sig))
        state["pid"] = None  # it stops at once
    monkeypatch.setattr(cli.os, "kill", kill)
    return sent


def test_stop_expecting_another_build_stops_nothing(tmp_path, no_kill, capsys):
    """A stale app: the host this checkout starts is not the one it was built against, so stopping cannot help."""
    rc = cli.cmd_stop(Settings(home=tmp_path), unless_current=True, expect=["0.0.9", "000000000000"])
    assert rc == cli.EXIT_WOULD_NOT_MATCH == 5
    assert no_kill == []
    assert f"version {__version__} (API {api_version()})" in capsys.readouterr().err


def test_stop_unless_current_leaves_a_host_of_this_build(tmp_path, monkeypatch, no_kill, capsys):
    """Another app has just replaced it: a late stop must not kill the current host."""
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: _status())
    rc = cli.cmd_stop(Settings(home=tmp_path), unless_current=True, expect=[__version__, api_version()])
    assert rc == 0 and no_kill == []
    assert "already this build" in capsys.readouterr().out


@pytest.mark.parametrize("answer", [
    pytest.param(None, id="not answering"),
    pytest.param({"version": __version__, "model": {"name": "m", "state": "ready"}}, id="older, no api_version"),
    pytest.param(_status(api_version="000000000000"), id="another api"),
    pytest.param(_status(stale=True), id="code changed since it started"),
])
def test_stop_unless_current_stops_a_host_of_another_build_or_with_changed_code(tmp_path, monkeypatch, no_kill,
                                                                               answer):
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: answer)
    rc = cli.cmd_stop(Settings(home=tmp_path), unless_current=True, expect=[__version__, api_version()], wait=0.2)
    assert rc == 0
    assert no_kill == [(999999, cli.signal.SIGTERM)]


def test_start_that_is_still_waiting_is_not_a_failed_start(tmp_path, monkeypatch, capsys):
    """`mydata start` gives up after 20 s while the daemon is still alive: exit 4, so the app keeps waiting."""
    class Alive:
        returncode = None
        def poll(self):
            return None
    clock = {"t": 1000.0}

    class Clock:
        @staticmethod
        def time():
            clock["t"] += 1
            return clock["t"]

        @staticmethod
        def sleep(_s):
            pass
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: None)
    monkeypatch.setattr(cli.subprocess, "Popen", lambda *a, **kw: Alive())
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: None)
    monkeypatch.setattr(cli, "time", Clock)
    assert cli.cmd_start(Settings(home=tmp_path)) == cli.EXIT_STILL_STARTING == 4
    assert "did not answer within 20 seconds" in capsys.readouterr().err


def test_start_names_the_daemon_by_an_absolute_path_off_macos(tmp_path, monkeypatch):
    """Off macOS Python finds its venv from argv[0]: a bare name would be looked up on PATH."""
    seen = []

    class Exited:
        returncode = 1
        def poll(self):
            return 1
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: None)
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: None)
    monkeypatch.setattr(cli.subprocess, "Popen", lambda argv, **kw: seen.append((argv, kw)) or Exited())
    for platform, name in (("darwin", "mydatad"), ("linux", str(Path(sys.executable).parent / "mydatad"))):
        seen.clear()
        monkeypatch.setattr(cli.sys, "platform", platform)
        cli.cmd_start(Settings(home=tmp_path))
        (argv, kw), = seen
        assert argv == [name, "-m", "mydata.service.daemon"] and kw["executable"] == sys.executable


# ---------------------------------------------------------------- a real daemon

def _home(tmp_path) -> Path:
    (tmp_path / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {free_port()}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{free_port()}")
        .replace("start_ollama = true", "start_ollama = false"))
    return tmp_path


def _mydata(home, *args):
    return subprocess.run([sys.executable, "-m", "mydata.cli", *args], env={**os.environ, "MYDATA_HOME": str(home)},
                          capture_output=True, text=True, timeout=60)


def _stop_daemon(home: Path) -> None:
    """Always, also when `mydata start` failed or timed out (it leaves the daemon it spawned running): `mydata
    stop` acts only on this temp home's pid file, then SIGKILL on the daemon that still holds it."""
    try:
        _mydata(home, "stop")
    except subprocess.TimeoutExpired:
        pass
    pid = daemon_pid(Settings(home=home))  # only while a daemon holds the pid file's lock
    if pid:
        os.kill(pid, signal.SIGKILL)


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def _gone(pid: int, timeout: float = 5) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not _alive(pid):
            return True
        time.sleep(0.1)
    return False


@pytest.mark.skipif(sys.platform.startswith("win"), reason="pgrep and ps")
def test_the_daemon_is_named_mydatad_and_stop_stops_it(tmp_path):
    home = _home(tmp_path)
    pid = None
    try:
        r = _mydata(home, "start")
        assert r.returncode == 0, r.stderr
        pid = int((home / "mydatad.pid").read_text())
        found = subprocess.run(["pgrep", "-f", "mydatad"], capture_output=True, text=True).stdout.split()
        assert str(pid) in found  # other hosts may run too (the user's own); only this one matters
        if sys.platform == "darwin":
            comm = subprocess.run(["ps", "-o", "comm=", "-p", str(pid)], capture_output=True, text=True).stdout
            assert "mydatad" in comm
        # What an app runs to replace a host: neither stops this one, which is this checkout's current host.
        r = _mydata(home, "stop", "--unless-current", "--expect", __version__, api_version())
        assert r.returncode == 0 and "already this build" in r.stdout, r.stdout + r.stderr
        r = _mydata(home, "stop", "--unless-current", "--expect", "0.0.9", "000000000000")
        assert r.returncode == 5 and "would not help" in r.stderr
        assert _alive(pid)
        r = _mydata(home, "stop")
        assert r.returncode == 0 and "mydatad stopped" in r.stdout
        assert _gone(pid)
    finally:
        _stop_daemon(home)
    assert not (home / "mydatad.pid").exists()


def test_stop_stops_a_daemon_started_by_an_older_build(tmp_path):
    """Older builds ran `python -m mydata.service.daemon`, without the name; a new `mydata stop` must stop it."""
    home = _home(tmp_path)
    port = int(next(line for line in (home / "config.toml").read_text().splitlines()
                    if line.startswith("port = ")).split(" = ")[1])
    proc = subprocess.Popen([sys.executable, "-m", "mydata.service.daemon"],
                            env={**os.environ, "MYDATA_HOME": str(home), "MYDATA_DETACHED": "1"},
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL,
                            start_new_session=True)
    try:
        deadline = time.time() + 20
        while time.time() < deadline:
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{port}/status", timeout=1)
            except urllib.error.HTTPError:  # 401 without a token: it is answering
                break
            except OSError:
                time.sleep(0.2)
        assert int((home / "mydatad.pid").read_text()) == proc.pid
        r = _mydata(home, "stop")
        assert r.returncode == 0 and "mydatad stopped" in r.stdout
        assert proc.wait(timeout=10) is not None
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=10)
    assert not (home / "mydatad.pid").exists()

