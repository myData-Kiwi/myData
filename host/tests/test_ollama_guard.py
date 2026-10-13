"""The guard in tests/ollama_guard.py: a failing test still stops its stand-in Ollama, a leaked one fails the
run and names the test, and leftovers from an earlier run are stopped at the start without failing it; a run
still going elsewhere keeps its own. Test host daemons are held to the same rules.
Each case runs pytest in a subprocess on a small generated test file, with only the guard as a plugin."""

import os
import subprocess
import sys
import textwrap
import time
from pathlib import Path

import pytest

TESTS = Path(__file__).parent


def _gone(pid: int, timeout: float = 5) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        out = subprocess.run(["ps", "-o", "stat=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
        if not out or out.startswith("Z"):
            return True
        time.sleep(0.05)
    return False


def _pytest(tmp_path, body: str) -> tuple[subprocess.CompletedProcess, Path]:
    (tmp_path / "pytest.ini").write_text("[pytest]\n")
    test = tmp_path / "test_generated.py"
    test.write_text(textwrap.dedent(body))
    pidfile = tmp_path / "started.pid"
    env = {**os.environ, "PYTHONPATH": os.pathsep.join([str(TESTS), os.environ.get("PYTHONPATH", "")]),
           "STARTED_PIDFILE": str(pidfile)}
    r = subprocess.run([sys.executable, "-m", "pytest", "-q", "-p", "ollama_guard", "-p", "no:cacheprovider",
                        "--rootdir", str(tmp_path), "-c", str(tmp_path / "pytest.ini"), str(test)],
                       cwd=tmp_path, env=env, capture_output=True, text=True, timeout=120)
    return r, pidfile


pytestmark = pytest.mark.skipif(sys.platform.startswith("win"), reason="the guard reads the process list with ps")


def test_a_failing_test_still_stops_the_fake_it_started(tmp_path):
    r, pidfile = _pytest(tmp_path, """
        import os, shutil, subprocess
        from pathlib import Path
        from mydata.service.config import Settings
        from mydata.service.model import ModelManager
        from service_helpers import free_port

        def test_fails_after_starting_the_fake(tmp_path, fake_ollama):
            # One through a ModelManager the test never stops, one started directly.
            mm = ModelManager(Settings(home=tmp_path, ollama_url=f"http://127.0.0.1:{free_port()}", model="tiny:1b"))
            mm.start()
            fake_ollama.wait_for_pids(1)
            subprocess.Popen([shutil.which("ollama"), "serve"], env={**os.environ, "OLLAMA_HOST": "127.0.0.1:0"},
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            pids = fake_ollama.wait_for_pids(2)
            Path(os.environ["STARTED_PIDFILE"]).write_text(" ".join(map(str, pids)))
            assert False, "deliberate failure"

        def test_the_next_test_finds_them_stopped():
            for pid in map(int, Path(os.environ["STARTED_PIDFILE"]).read_text().split()):
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    continue
                assert os.waitpid(pid, os.WNOHANG)[0] == pid, f"fake {pid} is still running"  # only a zombie
        """)
    pids = [int(p) for p in pidfile.read_text().split()]
    assert len(pids) == 2
    assert r.returncode == 1 and "1 failed, 1 passed" in r.stdout, r.stdout + r.stderr
    assert "left running by this test run" not in r.stdout
    assert all(_gone(pid) for pid in pids)


def test_a_leaked_fake_fails_the_run_and_names_the_test(tmp_path):
    r, pidfile = _pytest(tmp_path, """
        import os, shutil, subprocess, time
        from pathlib import Path

        def test_leaks_a_fake(tmp_path, fake_ollama):
            # Started outside the fixture's folder, so the fixture does not stop it: a leak.
            subprocess.Popen([shutil.which("ollama"), "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             env={**os.environ, "OLLAMA_HOST": "127.0.0.1:0", "FAKE_OLLAMA_PIDDIR": str(tmp_path)})
            deadline = time.time() + 10
            while not [f for f in tmp_path.iterdir() if f.name.isdigit()] and time.time() < deadline:
                time.sleep(0.02)
            [f] = [f for f in tmp_path.iterdir() if f.name.isdigit()]
            Path(os.environ["STARTED_PIDFILE"]).write_text(f.name)
        """)
    pid = int(pidfile.read_text())
    assert "1 passed" in r.stdout and r.returncode != 0, r.stdout + r.stderr
    assert "Ollama servers left running by this test run" in r.stdout
    assert f"pid {pid} (stand-in), started by test_generated.py::test_leaks_a_fake" in r.stdout
    assert _gone(pid)


def _spawn(tmp_path, name: str, argv: list[str], env: dict) -> int:
    """A detached process whose parent shell has exited (an orphan), as a killed run leaves behind."""
    pidfile = tmp_path / f"{name}.pid"
    quoted = " ".join(f"'{a}'" for a in argv)
    subprocess.run(["sh", "-c", f'{quoted} >/dev/null 2>&1 & echo $! > "{pidfile}"'], check=True, env=env)
    return int(pidfile.read_text())


def _dead_run() -> str:
    """A MYDATA_TEST_RUN value naming a pytest that is no longer running."""
    p = subprocess.Popen([sys.executable, "-c", "pass"])
    p.wait()
    return f"{p.pid}-0123456789ab"


def _fake_stand_in(tmp_path) -> Path:
    """A script at .../tests/fake_ollama/ollama, so its command line has the stand-in's shape."""
    marker = tmp_path / "tests" / "fake_ollama" / "ollama"
    marker.parent.mkdir(parents=True)
    marker.write_text("import time\ntime.sleep(60)\n")
    return marker


def _kill(*pids: int) -> None:
    for pid in pids:
        subprocess.run(["kill", "-9", str(pid)], capture_output=True)


def test_leftovers_from_an_earlier_run_are_stopped_at_the_start(tmp_path):
    marker = _fake_stand_in(tmp_path)
    env = {k: v for k, v in os.environ.items() if k != "MYDATA_TEST_RUN"}  # from before the guard marked runs
    orphan = _spawn(tmp_path, "orphan", [sys.executable, str(marker), "serve"], env)
    from_dead_run = _spawn(tmp_path, "dead", [sys.executable, str(marker), "serve"],
                           {**os.environ, "MYDATA_TEST_RUN": _dead_run()})
    try:
        r, _ = _pytest(tmp_path, """
            def test_nothing():
                pass
            """)
        assert r.returncode == 0, r.stdout + r.stderr
        assert f"stopped an Ollama server left running by an earlier test run: pid {orphan}" in r.stdout
        assert f"stopped an Ollama server left running by an earlier test run: pid {from_dead_run}" in r.stdout
        assert _gone(orphan) and _gone(from_dead_run)
    finally:
        _kill(orphan, from_dead_run)


def test_a_run_still_going_keeps_its_own(tmp_path):
    """Another terminal or agent runs the suite at the same time: its processes name its live pytest."""
    marker = _fake_stand_in(tmp_path)
    live = os.environ["MYDATA_TEST_RUN"]  # this pytest's run, which is running
    stand_in = _spawn(tmp_path, "stand_in", [sys.executable, str(marker), "serve"], {**os.environ})
    daemon = _spawn(tmp_path, "daemon", [sys.executable, "-c", "import time; time.sleep(60)", "-m",
                                         "mydata.service.daemon"],
                    {**os.environ, "MYDATA_TEST_RUN": live, "MYDATA_HOME": str(tmp_path / "home")})
    try:
        r, _ = _pytest(tmp_path, """
            def test_nothing():
                pass
            """)
        assert r.returncode == 0, r.stdout + r.stderr
        assert str(stand_in) not in r.stdout and str(daemon) not in r.stdout
        assert not _gone(stand_in, timeout=0.5) and not _gone(daemon, timeout=0.5)
    finally:
        _kill(stand_in, daemon)


def test_a_host_daemon_left_by_a_run_that_is_over_is_stopped_at_the_start(tmp_path):
    daemon = _spawn(tmp_path, "daemon", [sys.executable, "-c", "import time; time.sleep(60)", "-m",
                                         "mydata.service.daemon"],
                    {**os.environ, "MYDATA_TEST_RUN": _dead_run(), "MYDATA_HOME": str(tmp_path / "home")})
    try:
        r, _ = _pytest(tmp_path, """
            def test_nothing():
                pass
            """)
        assert r.returncode == 0, r.stdout + r.stderr
        assert f"stopped a host daemon left running by an earlier test run: pid {daemon}" in r.stdout
        assert _gone(daemon)
    finally:
        _kill(daemon)


def test_a_leaked_host_daemon_fails_the_run_and_names_the_test(tmp_path):
    r, pidfile = _pytest(tmp_path, """
        import os, subprocess, sys
        from pathlib import Path

        def test_leaks_a_daemon(tmp_path):
            # Like `mydata start` with no `mydata stop` after: detached, on a temp home.
            p = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)", "-m", "mydata.service.daemon"],
                                 env={**os.environ, "MYDATA_HOME": str(tmp_path)}, start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            Path(os.environ["STARTED_PIDFILE"]).write_text(str(p.pid))
        """)
    pid = int(pidfile.read_text())
    try:
        assert "1 passed" in r.stdout and r.returncode != 0, r.stdout + r.stderr
        assert "Host daemons left running by this test run" in r.stdout
        assert f"pid {pid}, home " in r.stdout and "test_generated.py::test_leaks_a_daemon" in r.stdout
        assert _gone(pid)
    finally:
        _kill(pid)
