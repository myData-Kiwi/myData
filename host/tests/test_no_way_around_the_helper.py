"""Static checks over src/mydata: nothing can go around the Swift helper's verb scan.

The host reads This Mac's contacts and calendars only through myDataReader.app, whose sources a test scans
for write calls (test_mac_reader_readonly.py). A host module that starts another program, or asks macOS to
run AppleScript, could reach Contacts, Calendar or Mail without that scan seeing it. So:

- only an allow-list of modules may start a program (subprocess), each for a stated reason;
- nothing else may start one another way (os.system, os.exec*, os.spawn*, pty, multiprocessing,
  asyncio's subprocesses) or load native code that could (ctypes, cffi);
- no host source mentions osascript or AppleScript.
"""

import ast
from pathlib import Path

import mydata

from test_dav_no_other_http import uses

SRC = Path(mydata.__file__).parent

# Ways to start another program, or to call native code that could.
PROCESS = ("subprocess", "os.system", "os.popen", "os.exec*", "os.spawn*", "os.posix_spawn*", "os.fork*",
           "pty", "multiprocessing", "concurrent.futures.ProcessPoolExecutor", "asyncio.create_subprocess_exec",
           "asyncio.create_subprocess_shell", "ctypes", "cffi", "_posixsubprocess")

# path (relative to src/mydata) -> what it may use, and why. Only subprocess, never the others.
SUBPROCESS_ALLOWED = {
    "cli.py": "starts the host (mydatad) detached: `python -m mydata.service.daemon`",
    "sources/mac/launcher.py": "checks the reader's signature with /usr/bin/codesign and starts it with "
                               "/usr/bin/open (LaunchServices), never by running its binary",
    "feasibility/latency.py": "reads memory, power and thermal state (vm_stat, pmset, sysctl, ollama ps) for "
                              "the measurement report",
    "service/model.py": "starts `ollama serve` when Ollama is installed but not running",
    "service/backup.py": "asks /usr/bin/fdesetup whether FileVault is on",
}

APPLESCRIPT = ("osascript", "applescript", "nsapplescript", "appleevent")


def _sources():
    for path in sorted(SRC.rglob("*.py")):
        yield path.relative_to(SRC).as_posix(), path


def test_the_scanner_catches_every_way_to_start_a_program():
    code = """
import subprocess
from subprocess import run
import os
os.system("x")
os.execvpe("x", [], {})
os.posix_spawnp("x", [], {})
os.popen("x")
from os import spawnl
import pty
import multiprocessing.pool
import asyncio
asyncio.create_subprocess_exec("x")
import ctypes.util
from concurrent.futures import ProcessPoolExecutor
"""
    hits = {b for _, b in uses(ast.parse(code), PROCESS)}
    assert hits == {"subprocess", "os.system", "os.exec*", "os.posix_spawn*", "os.popen", "os.spawn*", "pty",
                    "multiprocessing", "asyncio.create_subprocess_exec", "ctypes",
                    "concurrent.futures.ProcessPoolExecutor"}
    assert uses(ast.parse("import os\nos.path.join('a')\nos.environ.get('x')\n"), PROCESS) == []


def test_only_the_allow_list_starts_programs():
    problems = []
    for rel, path in _sources():
        for line, b in uses(ast.parse(path.read_text(), filename=str(path)), PROCESS):
            if not (b == "subprocess" and rel in SUBPROCESS_ALLOWED):
                problems.append(f"{rel}:{line} uses {b}")
    assert not problems, "a host module starts a program outside the allow-list:\n" + "\n".join(problems)


def test_the_allow_list_is_not_stale():
    """Every module on it exists and still needs subprocess: the list stays the true set."""
    for rel in SUBPROCESS_ALLOWED:
        path = SRC / rel
        assert path.is_file(), rel
        assert uses(ast.parse(path.read_text()), ("subprocess",)), f"{rel} no longer uses subprocess"


def test_no_host_source_mentions_osascript_or_applescript():
    problems = []
    for path in sorted(SRC.rglob("*")):
        if path.is_file() and "__pycache__" not in path.parts:
            text = path.read_text(errors="replace").lower()
            problems += [f"{path.relative_to(SRC)}: {w}" for w in APPLESCRIPT if w in text]
    assert not problems, "\n".join(problems)
