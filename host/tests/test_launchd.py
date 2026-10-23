"""The host as a login service (service/launchd.py, `mydata service`, launchd-aware start and stop).

launchctl is replaced by a fake that records its calls: no test loads anything into the real launchd. The
daemon's exit codes, which the LaunchAgent's KeepAlive relies on, are checked against a real mydatad process.
"""

import json
import os
import plistlib
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

from mydata import cli
from mydata.service import launchd
from mydata.service.config import DEFAULT_CONFIG, Settings
from mydata.service.daemon import acquire_pid_lock, daemon_pid

from service_helpers import free_port


class FakeLaunchctl:
    """launchctl with jobs in memory: print, bootstrap, bootout, kickstart."""

    def __init__(self):
        self.calls: list[tuple[str, ...]] = []
        self.loaded: dict[str, dict] = {}  # label -> {"state", "pid", "last_exit"}
        self.fail: set[str] = set()

    def __call__(self, *args: str) -> subprocess.CompletedProcess:
        self.calls.append(args)
        verb = args[0]
        if verb in self.fail:
            return subprocess.CompletedProcess(args, 5, "", f"{verb}: Input/output error")
        if verb == "print":
            label = args[1].rsplit("/", 1)[1]
            job = self.loaded.get(label)
            if job is None:
                return subprocess.CompletedProcess(args, 113, "", "Could not find service")
            out = f"{args[1]} = {{\n\tstate = {job['state']}\n"
            if job.get("pid"):
                out += f"\tpid = {job['pid']}\n"
            out += f"\tlast exit code = {job.get('last_exit', '(never exited)')}\n}}\n"
            return subprocess.CompletedProcess(args, 0, out, "")
        if verb == "bootstrap":
            data = plistlib.loads(Path(args[2]).read_bytes())
            self.loaded[data["Label"]] = {"state": "running", "pid": 4242}
        elif verb == "bootout":
            self.loaded.pop(args[1].rsplit("/", 1)[1], None)
        elif verb == "kickstart":
            self.loaded[args[1].rsplit("/", 1)[1]]["state"] = "running"
        return subprocess.CompletedProcess(args, 0, "", "")

    def verbs(self) -> list[str]:
        return [c[0] for c in self.calls if c[0] != "print"]


@pytest.fixture
def fake(monkeypatch):
    f = FakeLaunchctl()
    monkeypatch.setattr(launchd, "_launchctl", f)
    monkeypatch.setattr(launchd, "supported", lambda: True)
    return f


@pytest.fixture
def home(tmp_path, monkeypatch):
    h = tmp_path / "home"
    h.mkdir()
    monkeypatch.setenv("MYDATA_HOME", str(h))
    return h


@pytest.fixture
def app(tmp_path):
    a = tmp_path / "Applications" / "myData Host.app"
    (a / "Contents" / "MacOS").mkdir(parents=True)
    for name in ("mydatad", "mydata"):
        (a / "Contents" / "MacOS" / name).write_text("#!/bin/sh\n")
    return a


@pytest.fixture
def answering(monkeypatch):
    """The installed host 'answers' at once (no real daemon behind the fake launchd)."""
    seen = []
    monkeypatch.setattr(cli, "_wait_until_answering", lambda settings, failed: seen.append(failed) or 0)
    return seen


def test_the_plist_restarts_only_after_an_error_and_logs_to_the_host_folder(tmp_path):
    agent = launchd.Agent("kiwi.mydata.host", tmp_path / "a.plist", Path("/Apps/myData Host.app"))
    p = launchd.plist_dict(agent, Path("/h"), home_from_env=False)
    assert p["Label"] == "kiwi.mydata.host"
    assert p["ProgramArguments"] == ["/Apps/myData Host.app/Contents/MacOS/mydatad"]
    assert p["RunAtLoad"] is True
    assert p["KeepAlive"] == {"SuccessfulExit": False}
    assert p["ThrottleInterval"] >= 10 and p["ExitTimeOut"] > 15
    assert p["StandardOutPath"] == p["StandardErrorPath"] == "/h/logs/mydatad.out"
    assert p["Umask"] == 0o077
    assert p["AssociatedBundleIdentifiers"] == ["kiwi.mydata.host"]
    assert p["EnvironmentVariables"] == {"MYDATA_DETACHED": "1", launchd.LABEL_ENV: "kiwi.mydata.host"}
    with_home = launchd.plist_dict(agent, Path("/h"), home_from_env=True)
    assert with_home["EnvironmentVariables"]["MYDATA_HOME"] == "/h"
    assert plistlib.loads(launchd.plist_bytes(agent, Path("/h"), home_from_env=True)) == with_home


def test_labels_are_checked():
    assert launchd.check_label("kiwi.mydata.host-test") == "kiwi.mydata.host-test"
    for bad in ("", "a b", "../x", "-x", "a/b"):
        with pytest.raises(launchd.LaunchdError):
            launchd.check_label(bad)


def test_app_config_round_trip_and_uninstall_keeps_other_commands(tmp_path):
    agent = launchd.Agent("kiwi.mydata.host", tmp_path / "x.plist", tmp_path / "myData Host.app")
    config = launchd.installed_config(tmp_path, agent)
    assert config["host_command"] == [str(agent.cli), "start"]
    assert config["stop_command"] == [str(agent.cli), "stop"]
    launchd.write_app_config(tmp_path, config)
    assert (tmp_path / "app_config.json").stat().st_mode & 0o777 == 0o600
    assert launchd.recorded_agent(tmp_path) == agent
    assert launchd.uninstalled_config(config, agent) == {}
    dev = {"host_command": ["/py", "-m", "mydata.cli", "start"], "launch_agent": config["launch_agent"]}
    assert launchd.uninstalled_config(dev, agent) == {"host_command": ["/py", "-m", "mydata.cli", "start"]}
    (tmp_path / "app_config.json").write_text("not json")
    assert launchd.recorded_agent(tmp_path) is None


def test_job_reads_launchctl_print(fake):
    assert launchd.job("kiwi.mydata.host") is None
    fake.loaded["kiwi.mydata.host"] = {"state": "not running", "last_exit": "0"}
    assert launchd.job("kiwi.mydata.host") == {"state": "not running", "pid": None, "last_exit": "0"}
    fake.loaded["kiwi.mydata.host"] = {"state": "running", "pid": 77}
    assert launchd.job("kiwi.mydata.host")["pid"] == 77
    assert fake.calls[-1] == ("print", f"gui/{os.getuid()}/kiwi.mydata.host")


def test_install_dry_run_changes_nothing(fake, home, app, tmp_path, capsys):
    agents = tmp_path / "agents"
    assert cli.main(["service", "install", "--app", str(app), "--label", "kiwi.mydata.host-test",
                     "--agents-dir", str(agents), "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "would write" in out and "would bootstrap" in out and "<key>KeepAlive</key>" in out
    assert fake.verbs() == []
    assert not agents.exists() and not (home / "app_config.json").exists()


def test_install_writes_the_plist_and_app_config_then_bootstraps(fake, home, app, tmp_path, answering):
    agents = tmp_path / "agents"
    assert cli.main(["service", "install", "--app", str(app), "--label", "kiwi.mydata.host-test",
                     "--agents-dir", str(agents)]) == 0
    plist = agents / "kiwi.mydata.host-test.plist"
    data = plistlib.loads(plist.read_bytes())
    assert data["EnvironmentVariables"]["MYDATA_HOME"] == str(home)
    assert data["ProgramArguments"] == [str(app / "Contents" / "MacOS" / "mydatad")]
    config = json.loads((home / "app_config.json").read_text())
    assert config["host_command"] == [str(app / "Contents" / "MacOS" / "mydata"), "start"]
    assert config["stop_command"] == [str(app / "Contents" / "MacOS" / "mydata"), "stop"]
    assert config["launch_agent"]["label"] == "kiwi.mydata.host-test"
    assert fake.verbs() == ["bootstrap"]
    assert (home / "logs").is_dir()
    # Again: idempotent; the loaded agent is booted out first so the new plist and app take effect.
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(agents)]) == 0
    assert fake.verbs() == ["bootstrap", "bootout", "bootstrap"]


def test_install_never_takes_over_a_label_that_serves_another_folder(fake, home, app, tmp_path):
    agents = tmp_path / "agents"
    agents.mkdir()
    other = launchd.Agent("kiwi.mydata.host", agents / "kiwi.mydata.host.plist", app)
    (agents / "kiwi.mydata.host.plist").write_bytes(launchd.plist_bytes(other, tmp_path / "elsewhere",
                                                                        home_from_env=True))
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(agents)]) == 1
    assert fake.verbs() == []
    # Nor uninstall it.
    assert cli.main(["service", "uninstall", "--agents-dir", str(agents)]) == 1
    assert (agents / "kiwi.mydata.host.plist").exists()


def test_install_refuses_something_that_is_not_the_app(fake, home, tmp_path):
    assert cli.main(["service", "install", "--app", str(tmp_path / "nothing.app"),
                     "--agents-dir", str(tmp_path / "agents")]) == 1
    assert fake.verbs() == []


def test_uninstall_boots_out_and_removes_only_the_service(fake, home, app, tmp_path, answering):
    agents = tmp_path / "agents"
    assert cli.main(["service", "install", "--app", str(app), "--label", "kiwi.mydata.host-test",
                     "--agents-dir", str(agents)]) == 0
    (home / "contacts.sqlite").write_bytes(b"data")
    assert cli.main(["service", "uninstall", "--dry-run"]) == 0
    assert fake.verbs() == ["bootstrap"] and (agents / "kiwi.mydata.host-test.plist").exists()
    assert cli.main(["service", "uninstall"]) == 0
    assert fake.verbs() == ["bootstrap", "bootout"]
    assert not (agents / "kiwi.mydata.host-test.plist").exists()
    assert json.loads((home / "app_config.json").read_text()) == {}
    assert (home / "contacts.sqlite").read_bytes() == b"data"
    assert cli.main(["service", "uninstall"]) == 0  # again: nothing to do
    assert fake.verbs() == ["bootstrap", "bootout"]


def test_dev_setup_refuses_a_folder_served_by_the_installed_host(fake, home, app, tmp_path, answering):
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(tmp_path / "a")]) == 0
    before = (home / "app_config.json").read_text()
    assert cli.main(["dev-setup"]) == 1
    assert (home / "app_config.json").read_text() == before


def test_start_asks_launchd(fake, home, app, tmp_path, answering):
    agents = tmp_path / "agents"
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(agents)]) == 0
    fake.loaded["kiwi.mydata.host"] = {"state": "not running", "last_exit": "0"}  # after a clean stop
    assert cli.main(["start"]) == 0
    assert fake.verbs()[-1] == "kickstart"
    fake.loaded.clear()  # booted out (a stop that had to kill it): loaded again from the plist
    assert cli.main(["start"]) == 0
    assert fake.verbs()[-1] == "bootstrap"
    fake.loaded.clear()
    (agents / "kiwi.mydata.host.plist").unlink()
    assert cli.main(["start"]) == 1


def test_a_start_launchd_could_not_run_is_reported(fake, home, app, tmp_path, monkeypatch):
    agents = tmp_path / "agents"
    monkeypatch.setattr(cli, "_wait_until_answering", lambda s, f: 0)
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(agents)]) == 0
    fake.loaded["kiwi.mydata.host"] = {"state": "not running", "last_exit": "1"}
    clock = [1000.0]
    monkeypatch.setattr(cli.time, "time", lambda: clock[0])
    failed = cli._launchd_failed(Settings(home=home), "kiwi.mydata.host")
    assert failed() is None  # too early to tell
    clock[0] += 5
    assert "exited (1)" in failed()


def test_launchd_started_host_exits_cleanly_when_another_runs(tmp_path, monkeypatch):
    """KeepAlive would otherwise start it again every few seconds while another host holds the folder."""
    from mydata.service import daemon
    monkeypatch.setenv("MYDATA_HOME", str(tmp_path))
    (tmp_path / "config.toml").write_text(DEFAULT_CONFIG.replace("port = 47821", f"port = {free_port()}"))
    fd = acquire_pid_lock(Settings(home=tmp_path))
    try:
        monkeypatch.setenv(launchd.LABEL_ENV, "kiwi.mydata.host-test")
        assert daemon.main() == 0
        monkeypatch.delenv(launchd.LABEL_ENV)
        assert daemon.main() == 1
    finally:
        os.close(fd)


def test_the_daemon_exits_with_0_on_sigterm(tmp_path):
    """`mydata stop` and /shutdown send SIGTERM; exit code 0 is what keeps launchd from restarting the host."""
    port = free_port()
    (tmp_path / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {port}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{free_port()}")
        .replace("start_ollama = true", "start_ollama = false"))
    env = {**os.environ, "MYDATA_HOME": str(tmp_path), "MYDATA_DETACHED": "1"}
    proc = subprocess.Popen([sys.executable, "-m", "mydata.service.daemon"], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        deadline = time.time() + 30
        while not daemon_pid(Settings(home=tmp_path)) and time.time() < deadline:
            time.sleep(0.1)
        time.sleep(1)  # serving
        proc.send_signal(signal.SIGTERM)
        assert proc.wait(timeout=30) == 0
    finally:
        if proc.poll() is None:
            proc.kill()


def test_a_stop_that_has_to_kill_an_installed_host_unloads_its_agent(fake, home, app, tmp_path, answering,
                                                                     monkeypatch):
    """launchd would start a killed host again (KeepAlive), so a host that ignores SIGTERM is booted out."""
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(tmp_path / "a")]) == 0
    running = {"pid": 4242}
    signals = []

    def kill(pid, sig):
        signals.append(sig)

    def bootout_kills(*args):
        r = fake(*args)
        if args[0] == "bootout":
            running["pid"] = None
        return r

    monkeypatch.setattr(launchd, "_launchctl", bootout_kills)
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: running["pid"])
    monkeypatch.setattr(cli.os, "kill", kill)
    clock = [1000.0]
    monkeypatch.setattr(cli.time, "time", lambda: clock[0])
    monkeypatch.setattr(cli.time, "sleep", lambda s: clock.__setitem__(0, clock[0] + s))
    assert cli.main(["stop"]) == 1
    assert signals == [signal.SIGTERM]  # never SIGKILL: the bootout stopped it
    assert fake.verbs() == ["bootstrap", "bootout"]


def test_a_clean_stop_leaves_the_agent_loaded(fake, home, app, tmp_path, answering, monkeypatch):
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(tmp_path / "a")]) == 0
    running = {"pid": 4242}
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: running["pid"])
    monkeypatch.setattr(cli.os, "kill", lambda pid, sig: running.update(pid=None))
    assert cli.main(["stop"]) == 0
    assert fake.verbs() == ["bootstrap"]
    assert "kiwi.mydata.host" in fake.loaded


def test_bootout_waits_until_launchd_has_let_the_job_go(fake, monkeypatch):
    """launchctl bootout returns while the job is torn down; bootstrapping the label before then fails (EIO)."""
    fake.loaded["kiwi.mydata.host"] = {"state": "running", "pid": 4242}
    lingering = {"prints": 3}
    real = fake.__call__

    def slow(*args):
        if args[0] == "bootout":
            fake.calls.append(args)
            return subprocess.CompletedProcess(args, 0, "", "")
        if args[0] == "print" and fake.loaded:
            lingering["prints"] -= 1
            if lingering["prints"] == 0:
                fake.loaded.clear()
        return real(*args)

    monkeypatch.setattr(launchd, "_launchctl", slow)
    monkeypatch.setattr(launchd.time, "sleep", lambda s: None)
    launchd.bootout("kiwi.mydata.host")
    assert launchd.job("kiwi.mydata.host") is None
    fake.loaded["kiwi.mydata.host"] = {"state": "running", "pid": 4242}
    lingering["prints"] = 10**6
    with pytest.raises(launchd.LaunchdError, match="still has"):
        launchd.bootout("kiwi.mydata.host", wait=0)


# --- Starting and stopping around launchd's KeepAlive (review of the packaging) ---------------------------------

def _test_config(home: Path, port: int) -> None:
    (home / "config.toml").write_text(
        DEFAULT_CONFIG.replace("port = 47821", f"port = {port}")
        .replace("http://127.0.0.1:11434", f"http://127.0.0.1:{free_port()}")
        .replace("start_ollama = true", "start_ollama = false"))


def _daemon(home: Path, **env) -> subprocess.Popen:
    return subprocess.Popen([sys.executable, "-m", "mydata.service.daemon"],
                            env={**os.environ, "MYDATA_HOME": str(home), "MYDATA_DETACHED": "1", **env},
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _wait_for(predicate, timeout: float = 30) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if predicate():
            return True
        time.sleep(0.01)
    return False


@pytest.mark.parametrize("when", ["early", "locked"])
def test_a_sigterm_while_the_host_is_starting_is_a_clean_stop(tmp_path, when):
    """`mydata stop` signals as soon as the folder is locked, before the host serves; a death by signal would make
    launchd start it again (KeepAlive), undoing the stop."""
    _test_config(tmp_path, free_port())
    proc = _daemon(tmp_path)
    try:
        if when == "early":  # during the imports
            time.sleep(0.1)
        else:
            assert _wait_for(lambda: daemon_pid(Settings(home=tmp_path)))
        proc.send_signal(signal.SIGTERM)
        assert proc.wait(timeout=30) == 0
    finally:
        if proc.poll() is None:
            proc.kill()


def test_a_taken_port_stops_the_host_before_anything_starts(tmp_path, monkeypatch, capsys):
    from mydata.service import daemon
    port = free_port()
    _test_config(tmp_path, port)
    monkeypatch.setenv("MYDATA_HOME", str(tmp_path))
    monkeypatch.delenv(launchd.LABEL_ENV, raising=False)
    built = []
    monkeypatch.setattr(daemon, "build", lambda *a, **k: built.append(1))
    import socket
    with socket.socket() as taken:
        taken.bind(("127.0.0.1", port))
        taken.listen()
        assert daemon.main() == 1
    assert built == []  # no migration, sync, snapshot, model or trash expiry
    settings = Settings(home=tmp_path)
    assert f"port {port}" in daemon.start_error_path(settings).read_text()
    assert cli._start_error(settings) and cli.cmd_status(settings) == 3
    assert "Its last start failed: port" in capsys.readouterr().out
    assert daemon_pid(settings) is None


def test_under_launchd_a_host_that_cannot_start_waits_and_mydata_stop_ends_the_loop(tmp_path):
    """KeepAlive restarts an error exit every 15 s; the host waits a minute first, and a SIGTERM during the wait
    (mydata stop, bootout, logout) makes it exit with 0, so launchd leaves it stopped."""
    import socket
    port = free_port()
    _test_config(tmp_path, port)
    settings = Settings(home=tmp_path)
    with socket.socket() as taken:
        taken.bind(("127.0.0.1", port))
        taken.listen()
        proc = _daemon(tmp_path, **{launchd.LABEL_ENV: "kiwi.mydata.host-test"})
        try:
            from mydata.service.daemon import start_error_path
            assert _wait_for(lambda: start_error_path(settings).exists())
            time.sleep(0.5)
            assert proc.poll() is None  # waiting, not restarting
            assert daemon_pid(settings) == proc.pid
            assert cli.cmd_start(settings) == 1  # says why at once instead of waiting for it
            proc.send_signal(signal.SIGTERM)
            assert proc.wait(timeout=10) == 0
        finally:
            if proc.poll() is None:
                proc.kill()


def test_a_config_error_under_launchd_waits_before_exiting(tmp_path, monkeypatch):
    from mydata.service import daemon
    (tmp_path / "config.toml").write_text("[server]\nport = 0\n")
    monkeypatch.setenv("MYDATA_HOME", str(tmp_path))
    monkeypatch.setenv(launchd.LABEL_ENV, "kiwi.mydata.host-test")
    monkeypatch.setattr(daemon, "FAILURE_PAUSE_SECONDS", 0.2)
    t = time.monotonic()
    assert daemon.main() == 2
    assert time.monotonic() - t >= 0.2
    monkeypatch.delenv(launchd.LABEL_ENV)
    monkeypatch.setattr(daemon, "FAILURE_PAUSE_SECONDS", 60)
    assert daemon.main() == 2  # not under launchd: at once


def test_launchd_output_is_trimmed(tmp_path, monkeypatch):
    from mydata.service import daemon
    monkeypatch.setattr(daemon, "OUT_LIMIT_BYTES", 1000)
    monkeypatch.setattr(daemon, "OUT_KEEP_BYTES", 100)
    out = tmp_path / "mydatad.out"
    out.write_bytes(b"".join(b"line %04d\n" % i for i in range(200)))
    daemon._trim_output(out)
    text = out.read_bytes()
    assert text.startswith(b"[older output trimmed]\n") and text.endswith(b"line 0199\n") and len(text) < 150
    small = text
    daemon._trim_output(out)
    assert out.read_bytes() == small


def test_start_waits_for_a_host_that_is_still_stopping(home, monkeypatch, capsys):
    """Stop host, then Start host at once: the old host still holds the folder for up to 15 s."""
    pids = iter([4242, 4242, 4242, None])
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: next(pids, None))
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: None)
    monkeypatch.setattr(cli.time, "sleep", lambda s: None)
    started = []
    monkeypatch.setattr(cli, "_start_detached", lambda settings: started.append(1) or 0)
    assert cli.cmd_start(Settings(home=home)) == 0
    assert started == [1]


def test_start_does_not_start_a_second_host_beside_one_that_is_starting(home, monkeypatch):
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: 4242)
    answers = iter([None, None, {"version": "x"}])
    monkeypatch.setattr(cli, "_get_status", lambda settings, timeout=2: next(answers, {"version": "x"}))
    monkeypatch.setattr(cli, "_describe", lambda status: "running")
    monkeypatch.setattr(cli.time, "sleep", lambda s: None)
    monkeypatch.setattr(cli, "_start_detached", lambda settings: pytest.fail("started a second host"))
    assert cli.cmd_start(Settings(home=home)) == 0


class _Disabled(FakeLaunchctl):
    """A label switched off (System Settings, Login Items, or `launchctl disable`): bootstrap fails with EIO."""

    def __init__(self, label):
        super().__init__()
        self.label = label

    def __call__(self, *args):
        if args[0] == "print-disabled":
            self.calls.append(args)
            return subprocess.CompletedProcess(args, 0, f'\tdisabled services = {{\n\t\t"{self.label}" => disabled\n'
                                                        '\t\t"com.example.other" => enabled\n\t}\n', "")
        if args[0] == "bootstrap":
            self.calls.append(args)
            return subprocess.CompletedProcess(args, 5, "", "Bootstrap failed: 5: Input/output error")
        return super().__call__(*args)


def test_a_switched_off_agent_is_named_and_the_host_still_starts(fake, home, app, tmp_path, answering, monkeypatch,
                                                                 capsys):
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(tmp_path / "a")]) == 0
    off = _Disabled("kiwi.mydata.host")
    monkeypatch.setattr(launchd, "_launchctl", off)  # not loaded at login: switched off
    assert launchd.disabled("kiwi.mydata.host") and not launchd.disabled("com.example.other")
    started = []
    monkeypatch.setattr(cli, "_start_detached", lambda settings: started.append(1) or 0)
    assert cli.main(["start"]) == 0
    assert started == [1]
    assert "Login Items" in capsys.readouterr().err
    # Not switched off but bootstrap fails all the same: the hint, and no host started around launchd.
    off.label = "something.else"
    assert cli.main(["start"]) == 1
    assert started == [1] and "if it is switched off" in capsys.readouterr().err


def test_install_leaves_app_config_alone_when_launchd_will_not_load_the_agent(fake, home, app, tmp_path,
                                                                             monkeypatch, capsys):
    before = '{"host_command": ["/py", "-m", "mydata.cli", "start"]}\n'
    (home / "app_config.json").write_text(before)
    monkeypatch.setattr(launchd, "_launchctl", _Disabled("kiwi.mydata.host-test"))
    assert cli.main(["service", "install", "--app", str(app), "--label", "kiwi.mydata.host-test",
                     "--agents-dir", str(tmp_path / "a")]) == 1
    assert (home / "app_config.json").read_text() == before
    assert "Login Items" in capsys.readouterr().err


def test_a_stop_that_boots_out_fits_in_the_apps_wait(fake, home, app, tmp_path, answering, monkeypatch):
    """The apps give `mydata stop` 75 s: 10 s for a starting host, 15 s after SIGTERM, then the bootout."""
    assert cli.main(["service", "install", "--app", str(app), "--agents-dir", str(tmp_path / "a")]) == 0
    waits = []
    monkeypatch.setattr(launchd, "bootout", lambda label, wait=None: waits.append(wait))
    monkeypatch.setattr(cli, "daemon_pid", lambda settings: 4242)
    monkeypatch.setattr(cli.os, "kill", lambda pid, sig: None)
    clock = [1000.0]
    monkeypatch.setattr(cli.time, "time", lambda: clock[0])
    monkeypatch.setattr(cli.time, "sleep", lambda s: clock.__setitem__(0, clock[0] + s))
    assert cli.main(["stop"]) == 1
    assert waits and 10 + 15 + waits[0] + 10 < 75


def test_the_host_app_opened_from_finder_asks_launchd_or_refuses(tmp_path, monkeypatch, capsys):
    """Opened from Finder or Spotlight, the bundle's mydatad has neither launchd's label nor `mydata start`'s
    marker; it never runs a host launchd does not watch over."""
    from mydata.service import daemon
    prefix = tmp_path / "myData Host.app" / "Contents" / "Resources" / "python"
    prefix.mkdir(parents=True)
    monkeypatch.setattr(daemon.sys, "prefix", str(prefix))
    monkeypatch.setenv("MYDATA_HOME", str(tmp_path / "home"))
    monkeypatch.delenv(launchd.LABEL_ENV, raising=False)
    monkeypatch.delenv("MYDATA_DETACHED", raising=False)
    monkeypatch.setattr(daemon, "main", lambda: pytest.fail("ran a host outside launchd"))
    monkeypatch.setattr(launchd, "supported", lambda: True)
    assert daemon.run_program() == 1
    assert "no login service" in capsys.readouterr().err
    monkeypatch.setattr(launchd, "recorded_agent", lambda home: object())
    monkeypatch.setattr(cli, "cmd_start", lambda settings: 0)
    assert daemon.run_program() == 0
    # Started by launchd or by `mydata start`: the host itself.
    monkeypatch.setattr(daemon, "main", lambda: 7)
    monkeypatch.setenv("MYDATA_DETACHED", "1")
    assert daemon.run_program() == 7
    monkeypatch.delenv("MYDATA_DETACHED")
    monkeypatch.setenv(launchd.LABEL_ENV, "kiwi.mydata.host")
    assert daemon.run_program() == 7
    # A checkout's Python is not the app.
    monkeypatch.delenv(launchd.LABEL_ENV)
    monkeypatch.setattr(daemon.sys, "prefix", str(tmp_path / "venv"))
    assert daemon.run_program() == 7
