"""No test leaves an Ollama server running (neither the stand-in in tests/fake_ollama nor the real one), and no
test leaves a host daemon running.

- `fake_ollama` puts the stand-in on PATH and gives it a folder of its own, where every started process
  records its pid. The fixture stops all of them at teardown, also when the test failed.
- Every ModelManager a test starts is halted at teardown (its supervisor would otherwise keep retrying after
  the test, and could start the real `ollama serve` once PATH is restored), and no test can find the real
  Ollama binary.
- At the end of the run, any Ollama process started by this run (marked by MYDATA_TEST_RUN in its
  environment, or recorded by the fixture) is stopped and fails the run, naming the test.
- At the start of a run, stand-ins left orphaned by an earlier run (and real `ollama serve` processes a test
  started, now orphaned) are stopped and reported; that does not fail the run. A process whose MYDATA_TEST_RUN
  names a pytest that is still running belongs to a run going on in another terminal, and is left alone.
- Host daemons (`mydata.service.daemon`, started by `mydata start` in test_cli and test_host_version) are
  handled the same way: one with this run's MYDATA_TEST_RUN still running at the end fails the run; one from a run
  whose pytest is gone (killed, interrupted) is stopped at the start of the next. A daemon counts only if its
  environment has MYDATA_TEST_RUN and a MYDATA_HOME that is not the real host folder, so the owner's own host
  (started by an app, never by a test) is never touched.

The conftest imports this module; it also works as a plugin on its own (`-p ollama_guard`), which the tests
of this guard use."""

from __future__ import annotations

import itertools
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

import pytest

FAKE_DIR = Path(__file__).parent / "fake_ollama"
FAKE_MARK = "tests/fake_ollama/ollama"  # in the command line of every stand-in, from any checkout
# `<python> <...>/tests/fake_ollama/ollama serve`: the stand-in's whole command line, the script as the
# interpreter's first argument (its path may hold spaces, but it is no option such as -c)
FAKE_SHAPE = re.compile(r"^\S+\s+([^-\s].*" + re.escape(FAKE_MARK) + r")\s+serve$")
DAEMON_MARK = "mydata.service.daemon"
RUN_VAR = "MYDATA_TEST_RUN"

_run: dict = {"id": None, "dir": None, "leftovers": []}
_counter = itertools.count(1)
_started_managers: list = []


# ---------------------------------------------------------------- processes

def _processes() -> list[tuple[int, int, str]]:
    """(pid, ppid, command line) of every process, or [] where `ps` is missing (Windows)."""
    try:
        out = subprocess.run(["ps", "-A", "-ww", "-o", "pid=,ppid=,command="], capture_output=True, text=True,
                             timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    rows = []
    for line in out.splitlines():
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            rows.append((int(parts[0]), int(parts[1]), parts[2]))
    return rows


def _env(pid: int, key: str) -> str | None:
    """One variable of another process's environment (our own user's processes only)."""
    if sys.platform.startswith("linux"):
        try:
            items = Path(f"/proc/{pid}/environ").read_bytes().split(b"\0")
        except OSError:
            return None
        prefix = key.encode() + b"="
        return next((i[len(prefix):].decode(errors="replace") for i in items if i.startswith(prefix)), None)
    try:  # macOS: ps -E appends the environment to the command line
        out = subprocess.run(["ps", "-E", "-ww", "-o", "command=", "-p", str(pid)], capture_output=True, text=True,
                             timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    m = re.search(rf"(?:^|\s){re.escape(key)}=(\S*)", out)
    return m.group(1) if m else None


def _is_fake(command: str) -> bool:
    """The stand-in by the shape of its whole command line, not by its path appearing anywhere in it."""
    return FAKE_SHAPE.match(command.strip()) is not None


def _real_home() -> Path:
    """The owner's host folder: what home_dir() gives without MYDATA_HOME."""
    from mydata.service.config import home_dir
    saved = os.environ.pop("MYDATA_HOME", None)
    try:
        return home_dir().resolve()
    finally:
        if saved is not None:
            os.environ["MYDATA_HOME"] = saved


def _is_test_daemon(pid: int, command: str) -> bool:
    """A host daemon a test started: marked by MYDATA_TEST_RUN, on a home that is not the real one."""
    if DAEMON_MARK not in command or not _env(pid, RUN_VAR):
        return False
    home = _env(pid, "MYDATA_HOME")  # read up to the first space: it may be cut short
    real = str(_real_home())
    return bool(home) and not real.startswith(home) and not home.startswith(real)


def _run_alive(run_id: str | None) -> bool:
    """Whether the pytest that a MYDATA_TEST_RUN value names ("<pid>-<id>") is still running."""
    head = (run_id or "").split("-", 1)[0]
    if not head.isdigit():
        return False
    try:
        os.kill(int(head), 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _is_real_ollama(command: str) -> bool:
    words = command.split()
    return len(words) >= 2 and os.path.basename(words[0]) == "ollama" and words[1] == "serve"


def _command(pid: int) -> str | None:
    """The command line of a live process; None if it is gone or a zombie."""
    try:
        if os.waitpid(pid, os.WNOHANG)[0] == pid:  # our own child that already exited: reap it
            return None
    except ChildProcessError:
        pass
    try:
        out = subprocess.run(["ps", "-ww", "-o", "stat=,command=", "-p", str(pid)], capture_output=True, text=True,
                             timeout=10).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    if not out or out.startswith("Z"):
        return None
    return out.split(None, 1)[1] if " " in out else ""


def _stop(pid: int) -> None:
    """SIGTERM, a moment to exit, then SIGKILL."""
    for sig, wait in ((signal.SIGTERM, 3.0), (signal.SIGKILL, 2.0)):
        try:
            os.kill(pid, sig)
        except (ProcessLookupError, PermissionError):
            return
        deadline = time.time() + wait
        while time.time() < deadline:
            if _command(pid) is None:
                return
            time.sleep(0.05)


def _recorded() -> dict[int, str]:
    """pid -> test, for every stand-in the fixture's folders recorded in this run."""
    out: dict[int, str] = {}
    if _run["dir"] is None:
        return out
    for folder in Path(_run["dir"]).iterdir():
        test = (folder / "test.txt").read_text() if (folder / "test.txt").exists() else "?"
        for f in folder.iterdir():
            if f.name.isdigit():
                out[int(f.name)] = test
    return out


def _test_that_started(pid: int, recorded: dict[int, str]) -> str:
    if pid in recorded:
        return recorded[pid]
    folder = _env(pid, "FAKE_OLLAMA_PIDDIR")
    if folder and (Path(folder) / "test.txt").exists():
        return (Path(folder) / "test.txt").read_text()
    return _env(pid, "PYTEST_CURRENT_TEST") or "an unknown test (no test was running when it started)"


# ---------------------------------------------------------------- model managers

def _halt(mm) -> None:
    """Stop a ModelManager's threads and the Ollama it started, without unloading anything from an Ollama it
    did not start (that could be the user's own)."""
    mm._guard_halted = True
    mm._stopping.set()
    mm._cancel.set()
    for name in ("_supervisor", "_thread"):  # the supervisor first: it may start a new attempt
        t = getattr(mm, name)
        if t is not None and t.is_alive():
            t.join(timeout=15)
    child = mm._child
    if child is not None and child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=5)


def _halt_started_managers() -> None:
    while _started_managers:
        _halt(_started_managers.pop())


@pytest.fixture(autouse=True)
def _ollama_guard(monkeypatch):
    """No test can start the real Ollama, and no ModelManager outlives its test."""
    import mydata.service.model as model

    real_which = shutil.which

    class _Shutil:
        def __getattr__(self, name):
            return getattr(shutil, name)

        @staticmethod
        def which(cmd, *a, **kw):
            found = real_which(cmd, *a, **kw)
            if found and Path(cmd).name == "ollama" and Path(found).parent != FAKE_DIR:
                return None  # the real binary, never in tests
            return found

    monkeypatch.setattr(model, "shutil", _Shutil())
    monkeypatch.setattr(model, "OLLAMA_CANDIDATES", [])
    original_start, original_retry = model.ModelManager.start, model.ModelManager.retry

    def start(self):
        if self not in _started_managers:
            _started_managers.append(self)
        return original_start(self)

    def retry(self):
        if getattr(self, "_guard_halted", False):
            return
        if self not in _started_managers:
            _started_managers.append(self)
        return original_retry(self)

    monkeypatch.setattr(model.ModelManager, "start", start)
    monkeypatch.setattr(model.ModelManager, "retry", retry)
    yield
    _halt_started_managers()


# ---------------------------------------------------------------- the fixture

class FakeOllama:
    """The stand-in's folder for one test: one file per started process, named by its pid."""

    def __init__(self, folder: Path):
        self.dir = folder

    def pids(self) -> list[int]:
        files = sorted((f for f in self.dir.iterdir() if f.name.isdigit()), key=lambda f: f.stat().st_mtime)
        return [int(f.name) for f in files]

    def wait_for_pids(self, n: int = 1, timeout: float = 10) -> list[int]:
        deadline = time.time() + timeout
        while len(self.pids()) < n and time.time() < deadline:
            time.sleep(0.02)
        return self.pids()


@pytest.fixture
def fake_ollama(request, monkeypatch, _ollama_guard):
    """The stand-in `ollama` first on PATH. Teardown halts the test's ModelManagers, then stops every
    stand-in the test started, whether it passed or failed."""
    if _run["dir"] is None:  # used without the plugin's configure hook
        _run["dir"] = tempfile.mkdtemp(prefix="mydata-fake-ollama-")
    folder = Path(_run["dir"]) / str(next(_counter))
    folder.mkdir()
    (folder / "test.txt").write_text(request.node.nodeid)
    monkeypatch.setenv("PATH", f"{FAKE_DIR}{os.pathsep}{os.environ['PATH']}")
    monkeypatch.setenv("FAKE_OLLAMA_PIDDIR", str(folder))
    fake = FakeOllama(folder)
    try:
        yield fake
    finally:
        _halt_started_managers()  # first, so no supervisor starts another while they are being stopped
        for pid in fake.pids():
            command = _command(pid)
            if command is not None and _is_fake(command):
                _stop(pid)


# ---------------------------------------------------------------- the run

def pytest_configure(config):
    _run["id"] = f"{os.getpid()}-{uuid.uuid4().hex[:12]}"
    _run["dir"] = tempfile.mkdtemp(prefix="mydata-fake-ollama-")
    os.environ[RUN_VAR] = _run["id"]  # inherited by everything the run starts, however indirectly


def pytest_sessionstart(session):
    """Stop what an earlier run left behind. Only orphans of runs that are over: a run still going (another
    terminal, another agent) owns its own, and its MYDATA_TEST_RUN names its live pytest."""
    for pid, ppid, command in _processes():
        if pid == os.getpid():
            continue
        if _is_test_daemon(pid, command):  # detached by design, so never judged by its parent
            if not _run_alive(_env(pid, RUN_VAR)):
                _stop(pid)
                _run["leftovers"].append(("a host daemon", f"pid {pid} ({command[:80]}), home "
                                                           f"{_env(pid, 'MYDATA_HOME')}"))
            continue
        if ppid != 1:
            continue
        if _is_fake(command) or (_is_real_ollama(command) and (_env(pid, RUN_VAR) or _env(pid, "PYTEST_CURRENT_TEST"))):
            if _run_alive(_env(pid, RUN_VAR)):
                continue
            started_by = _env(pid, "PYTEST_CURRENT_TEST") or "an earlier test run"
            _stop(pid)
            _run["leftovers"].append(("an Ollama server", f"pid {pid} ({command[:80]}), started by {started_by}"))
    reporter = session.config.pluginmanager.get_plugin("terminalreporter")
    for what, line in _run["leftovers"]:
        message = f"stopped {what} left running by an earlier test run: {line}"
        if reporter:
            reporter.write_line(message, yellow=True)
        else:
            print(message, file=sys.stderr)


@pytest.hookimpl(trylast=True)
def pytest_sessionfinish(session, exitstatus):
    """Fail the run if any Ollama or host daemon it started is still running (also after an interrupted test)."""
    _halt_started_managers()
    recorded = _recorded()
    leaks = []
    daemons = []
    for pid, _ppid, command in _processes():
        if _is_test_daemon(pid, command):
            if _env(pid, RUN_VAR) == _run["id"]:
                home, test = _env(pid, "MYDATA_HOME"), _env(pid, "PYTEST_CURRENT_TEST")  # before it is gone
                _stop(pid)
                daemons.append(f"pid {pid}, home {home}, started by {test or 'an unknown test'}")
            continue
        if not (_is_fake(command) or _is_real_ollama(command)):
            continue
        if pid not in recorded and _env(pid, RUN_VAR) != _run["id"]:
            continue
        test = _test_that_started(pid, recorded)
        _stop(pid)
        leaks.append(f"pid {pid} ({'stand-in' if _is_fake(command) else 'the real ollama serve'}), "
                     f"started by {test}")
    if not leaks and not daemons:
        return
    if session.exitstatus == 0:
        session.exitstatus = pytest.ExitCode.TESTS_FAILED
    lines = []
    if leaks:
        lines += ["Ollama servers left running by this test run (stopped now):", *(f"  {x}" for x in leaks),
                  "Every test that starts one must stop it: use the fake_ollama fixture, and stop a started "
                  "ModelManager in a finally."]
    if daemons:
        lines += ["Host daemons left running by this test run (stopped now):", *(f"  {x}" for x in daemons),
                  "Every test that runs `mydata start` must run `mydata stop` in a finally, also when the start "
                  "failed."]
    reporter = session.config.pluginmanager.get_plugin("terminalreporter")
    if reporter:
        reporter.write_sep("!", "Processes left running", red=True)
        for line in lines:
            reporter.write_line(line, red=True)
    else:
        print("\n".join(lines), file=sys.stderr)


def pytest_unconfigure(config):
    if _run["dir"] is not None:
        shutil.rmtree(_run["dir"], ignore_errors=True)
        _run["dir"] = None
