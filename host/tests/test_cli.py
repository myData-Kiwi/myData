"""mydata start / status / stop against a real mydatad process, with Ollama pointed at a dead port."""

import json
import os
import subprocess
import sys
import time
import urllib.request

from mydata.service.config import DEFAULT_CONFIG

from service_helpers import free_port


def _mydata(home, *args, timeout=60):
    return subprocess.run([sys.executable, "-m", "mydata.cli", *args], env={**os.environ, "MYDATA_HOME": str(home)},
                          capture_output=True, text=True, timeout=timeout)


def test_start_status_stop(tmp_path):
    port, dead = free_port(), free_port()
    (tmp_path / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {port}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{dead}")
        .replace("start_ollama = true", "start_ollama = false"))
    try:
        r = _mydata(tmp_path, "start")
        assert r.returncode == 0, r.stderr
        assert "running" in r.stdout
        pid = int((tmp_path / "mydatad.pid").read_text())
        assert _mydata(tmp_path, "start").returncode == 0  # second start: already running, no second process
        assert int((tmp_path / "mydatad.pid").read_text()) == pid

        token = (tmp_path / "app-tokens" / "cli").read_text()
        for _ in range(50):
            req = urllib.request.Request(f"http://127.0.0.1:{port}/status", headers={"Authorization": f"Bearer {token}"})
            status = json.loads(urllib.request.urlopen(req, timeout=2).read())
            if status["model"]["state"] == "error":
                break
            time.sleep(0.1)
        assert status["ready"] is False and "not running" in status["model"]["error"]
        assert _mydata(tmp_path, "status").returncode == 0

        log_lines = (tmp_path / "logs" / "mydatad.log").read_text().splitlines()
        assert all(json.loads(line)["ts"] for line in log_lines)  # structured
        assert token not in "\n".join(log_lines)
    finally:
        r = _mydata(tmp_path, "stop")
    assert r.returncode == 0 and "stopped" in r.stdout
    assert not (tmp_path / "mydatad.pid").exists()
    assert _mydata(tmp_path, "status").returncode == 3


def test_stale_pid_of_another_process_is_never_touched(tmp_path):
    port = free_port()
    (tmp_path / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {port}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{free_port()}")
        .replace("start_ollama = true", "start_ollama = false"))
    other = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    try:
        (tmp_path / "mydatad.pid").write_text(str(other.pid))
        assert _mydata(tmp_path, "stop").stdout.strip() == "mydatad is not running"
        assert other.poll() is None  # untouched
        assert _mydata(tmp_path, "status").returncode == 3
        r = _mydata(tmp_path, "start")
        assert r.returncode == 0 and "running" in r.stdout
        assert int((tmp_path / "mydatad.pid").read_text()) != other.pid
        assert _mydata(tmp_path, "stop").returncode == 0
        assert other.poll() is None
    finally:
        other.kill()


def test_detached_daemon_logs_each_line_once(tmp_path):
    port = free_port()
    (tmp_path / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {port}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{free_port()}")
        .replace("start_ollama = true", "start_ollama = false"))
    try:
        assert _mydata(tmp_path, "start").returncode == 0
    finally:
        _mydata(tmp_path, "stop")
    assert (tmp_path / "logs" / "mydatad.log").read_text().count('"msg": "starting"') == 1
    assert '"msg"' not in (tmp_path / "logs" / "mydatad.out").read_text()
