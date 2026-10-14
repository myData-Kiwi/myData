"""Static checks over src/mydata: nothing can go around the Swift helper's verb scan.

The host reads This Mac's contacts and calendars only through myDataReader.app, whose sources a test scans
for write calls (test_mac_reader_readonly.py). A host module that starts another program, or asks macOS to
run AppleScript, could reach Contacts, Calendar or Mail without that scan seeing it. So:

- only an allow-list of modules may start a program (subprocess), each for a stated reason and only the
  programs it names, never through a shell;
- nothing else may start one another way (os.system, os.exec*, os.spawn*, posix, pty, multiprocessing,
  asyncio's subprocesses, webbrowser, which runs osascript) or load native code that could (ctypes, cffi,
  PyObjC and Apple's frameworks through it);
- no host source mentions osascript or AppleScript.

These catch accidental use, through aliases, `from os import *` and getattr too. They are not proof against
code written to hide a call: the review of each change still has to look.
"""

import ast
from pathlib import Path

import mydata

from test_dav_no_other_http import uses

SRC = Path(mydata.__file__).parent

# Ways to start another program, or to call native code that could.
PROCESS = ("subprocess", "os.system", "os.popen", "os.exec*", "os.spawn*", "os.posix_spawn*", "os.fork*",
           "os.startfile", "posix", "nt", "_winapi", "pty", "multiprocessing", "concurrent.futures.ProcessPoolExecutor",
           "concurrent.futures.process", "asyncio.create_subprocess_exec", "asyncio.create_subprocess_shell",
           "asyncio.subprocess", "webbrowser", "ctypes", "_ctypes", "cffi", "_cffi_backend", "_posixsubprocess",
           # PyObjC: Apple's frameworks called directly, around the helper.
           "objc", "PyObjCTools", "Foundation", "AppKit", "CoreFoundation", "CoreServices", "LaunchServices",
           "Contacts", "EventKit", "ScriptingBridge", "OSAKit")
# An event loop's own ways to start a program (loop.subprocess_exec), reached through any loop object.
LOOP_PROCESS = ("subprocess_exec", "subprocess_shell")

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

# path -> the programs it may start. Checked: the first item of a literal argument list given to any call
# (subprocess.run([...]), or a wrapper such as latency's _sh([...])), and every absolute path to a program
# in the module. cli.py starts only sys.executable (the host, as `mydatad`).
PROGRAMS = {
    "cli.py": set(),
    "sources/mac/launcher.py": {"/usr/bin/codesign", "/usr/bin/open"},
    "feasibility/latency.py": {"vm_stat", "ioreg", "memory_pressure", "sysctl", "pmset", "ollama", "ps"},
    "service/model.py": {"/usr/local/bin/ollama", "/opt/homebrew/bin/ollama", "/usr/bin/ollama",
                         "/Applications/Ollama.app/Contents/Resources/ollama"},
    "service/backup.py": {"/usr/bin/fdesetup"},
}
_PROGRAM_DIRS = ("/usr/", "/bin/", "/sbin/", "/opt/", "/System/", "/Applications/", "/Library/")

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


def test_the_scanner_sees_through_aliases_star_imports_and_getattr():
    cases = {
        "import os as o\no.system('x')": "os.system",
        "import os as o\no.execv('/bin/sh', [])": "os.exec*",
        "from os import system as run": "os.system",
        "import posix\nposix.system('x')": "posix",
        "import os\ngetattr(os, 'system')('x')": "os.system",
        "getattr(__import__('os'), 'popen')('x')": "os.popen",
        "__import__('os').system('x')": "os.system",
        "from os import *\nsystem('x')": "os.system",
        "from concurrent.futures import process": "concurrent.futures.process",
        "import webbrowser\nwebbrowser.open('x')": "webbrowser",
        "import _ctypes": "_ctypes",
        "import _cffi_backend": "_cffi_backend",
        "import objc": "objc",
        "import Contacts": "Contacts",
        "from EventKit import EKEventStore": "EventKit",
        "import asyncio.subprocess": "asyncio.subprocess",
    }
    for code, want in cases.items():
        assert want in {b for _, b in uses(ast.parse(code), PROCESS)}, code
    assert _loop_process(ast.parse("loop.subprocess_exec(proto, 'x')")) == [1]
    # What the host itself does stays clear.
    assert uses(ast.parse("import os as o\no.path.join('a')\nfrom os import environ"), PROCESS) == []


def test_only_the_allow_list_starts_programs():
    problems = []
    for rel, path in _sources():
        for line, b in uses(ast.parse(path.read_text(), filename=str(path)), PROCESS):
            if not (b == "subprocess" and rel in SUBPROCESS_ALLOWED):
                problems.append(f"{rel}:{line} uses {b}")
    assert not problems, "a host module starts a program outside the allow-list:\n" + "\n".join(problems)


def _loop_process(tree: ast.AST) -> list[int]:
    return [n.lineno for n in ast.walk(tree) if isinstance(n, ast.Attribute) and n.attr in LOOP_PROCESS]


def test_no_event_loop_starts_a_program():
    problems = [f"{rel}:{line}" for rel, path in _sources() for line in _loop_process(ast.parse(path.read_text()))]
    assert not problems, "\n".join(problems)


def _programs(tree: ast.AST) -> set[str]:
    """Programs a module names: the first item of a literal argument list given to a call, and absolute paths
    in the system's program folders."""
    out = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Call) and n.args and isinstance(n.args[0], (ast.List, ast.Tuple)) and n.args[0].elts:
            first = n.args[0].elts[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str) and not first.value.startswith("-"):
                out.add(first.value)
        elif isinstance(n, ast.Constant) and isinstance(n.value, str) and n.value.startswith(_PROGRAM_DIRS):
            out.add(n.value)
    return out


def test_the_allowed_modules_start_only_their_programs_and_never_a_shell():
    assert set(PROGRAMS) == set(SUBPROCESS_ALLOWED)
    problems = []
    for rel, programs in PROGRAMS.items():
        tree = ast.parse((SRC / rel).read_text())
        problems += [f"{rel}: starts {p}" for p in sorted(_programs(tree) - programs)]
        problems += [f"{rel}: no longer names {p} (stale)" for p in sorted(programs - _programs(tree))]
        problems += [f"{rel}:{k.value.lineno}: shell=True" for n in ast.walk(tree) if isinstance(n, ast.Call)
                     for k in n.keywords if k.arg == "shell" and not (isinstance(k.value, ast.Constant)
                                                                      and k.value.value is False)]
    assert not problems, "\n".join(problems)
    assert _programs(ast.parse("subprocess.run(['/usr/bin/shortcuts', 'run', 'x'])")) == {"/usr/bin/shortcuts"}
    assert _programs(ast.parse("OPEN = '/usr/bin/open'\nrun([OPEN, '-a', 'Mail'])")) == {"/usr/bin/open"}


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
