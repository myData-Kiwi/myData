"""The host as a login service on macOS: a LaunchAgent that runs "myData Host.app" (packaging/macos).

`mydata service install --app <myData Host.app>` writes the agent's plist, records it in <home>/app_config.json
(with the start and stop commands the apps run, now the app's own `mydata`) and bootstraps it into the user's
GUI session; `mydata service uninstall` boots it out, removes the plist and takes those entries out again. The
host's data is never touched by either.

How the host's lifetime works with it:
- launchd starts the host at login (RunAtLoad) and again whenever it exits with an error or is killed
  (KeepAlive: SuccessfulExit false, at most every ThrottleInterval seconds).
- `mydata stop` (and the myData app's Stop host, through /shutdown) makes the host exit cleanly with code 0, so
  launchd leaves it stopped until the next login or `mydata start`.
- `mydata start` asks launchd to start it (`launchctl kickstart`), or bootstraps the agent again when it was
  booted out; without an agent it starts the host detached, as before.
- A host started by launchd while another is running on the same folder exits with 0, so launchd does not retry.

The record in app_config.json: {"launch_agent": {"label": ..., "plist": ..., "app": ...}}. Its presence is what
says the folder's host is a login service; `mydata dev-setup` refuses to replace it.
"""

from __future__ import annotations

import json
import os
import plistlib
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

LAUNCHCTL = "/bin/launchctl"
DEFAULT_LABEL = "kiwi.mydata.host"
BUNDLE_ID = "kiwi.mydata.host"
APP_NAME = "myData Host.app"
THROTTLE_SECONDS = 15
# launchd sends SIGTERM at logout and bootout, then SIGKILL after this long. The host's own shutdown takes up
# to 10 s for open requests and 5 s for a snapshot in progress.
EXIT_TIMEOUT_SECONDS = 20
# Set in the agent's environment: the daemon then knows launchd started it (see daemon.main).
LABEL_ENV = "MYDATA_LAUNCHD_LABEL"

_LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]*$")


class LaunchdError(Exception):
    pass


@dataclass(frozen=True)
class Agent:
    """The LaunchAgent recorded for a host folder."""
    label: str
    plist: Path
    app: Path

    @property
    def cli(self) -> Path:
        return self.app / "Contents" / "MacOS" / "mydata"

    @property
    def daemon(self) -> Path:
        return self.app / "Contents" / "MacOS" / "mydatad"


def check_label(label: str) -> str:
    if not _LABEL.match(label) or len(label) > 200:
        raise LaunchdError(f"{label!r} is not a launchd label (letters, digits, dots and hyphens)")
    return label


def supported() -> bool:
    return sys.platform == "darwin"


def default_agents_dir() -> Path:
    return Path.home() / "Library" / "LaunchAgents"


def domain() -> str:
    return f"gui/{os.getuid()}"


def target(label: str) -> str:
    return f"{domain()}/{check_label(label)}"


# --- app_config.json -------------------------------------------------------------------------------------------

def app_config_path(home: Path) -> Path:
    return Path(home) / "app_config.json"


def read_app_config(home: Path) -> dict:
    """The decoded app_config.json, or {} when it is missing or unreadable."""
    try:
        value = json.loads(app_config_path(home).read_text())
    except (OSError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def write_app_config(home: Path, config: dict) -> None:
    path = app_config_path(home)
    tmp = path.with_name(path.name + ".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(json.dumps(config, indent=2) + "\n")
    os.replace(tmp, path)


def recorded_agent(home: Path) -> Agent | None:
    """The LaunchAgent install recorded in the folder's app_config.json, or None."""
    entry = read_app_config(home).get("launch_agent")
    if not isinstance(entry, dict):
        return None
    try:
        return Agent(label=check_label(str(entry["label"])), plist=Path(entry["plist"]), app=Path(entry["app"]))
    except (KeyError, TypeError, LaunchdError):
        return None


def installed_config(home: Path, agent: Agent) -> dict:
    """app_config.json for an installed host: the apps start and stop it with the app's own `mydata`."""
    return {
        "host_command": [str(agent.cli), "start"],
        "stop_command": [str(agent.cli), "stop"],
        "launch_agent": {"label": agent.label, "plist": str(agent.plist), "app": str(agent.app)},
        "note": "Installed: written by `mydata service install`. The host starts at login (launchd); the apps "
                "run these commands to start it and to replace one from another build.",
    }


def uninstalled_config(config: dict, agent: Agent) -> dict:
    """app_config.json without the agent: its record goes, and so do commands that run the removed app."""
    out = {k: v for k, v in config.items() if k not in ("launch_agent", "note")}
    for key in ("host_command", "stop_command"):
        cmd = out.get(key)
        if isinstance(cmd, list) and cmd and str(cmd[0]).startswith(str(agent.app) + "/"):
            del out[key]
    return out


# --- The plist ----------------------------------------------------------------------------------------------

def plist_dict(agent: Agent, home: Path, *, home_from_env: bool) -> dict:
    """The LaunchAgent. MYDATA_HOME is set only when the host folder is not the default one."""
    log = str(Path(home) / "logs" / "mydatad.out")
    env = {"MYDATA_DETACHED": "1", LABEL_ENV: agent.label}
    if home_from_env:
        env["MYDATA_HOME"] = str(home)
    return {
        "Label": agent.label,
        "ProgramArguments": [str(agent.daemon)],
        "AssociatedBundleIdentifiers": [BUNDLE_ID],
        "RunAtLoad": True,
        # Restarted after a crash or an error exit; not after `mydata stop` or Stop host, which exit with 0.
        "KeepAlive": {"SuccessfulExit": False},
        "ThrottleInterval": THROTTLE_SECONDS,
        "ExitTimeOut": EXIT_TIMEOUT_SECONDS,
        "LimitLoadToSessionType": "Aqua",
        "ProcessType": "Standard",
        "EnvironmentVariables": env,
        # Only what is printed before the host's own log starts (config errors, crashes) lands here.
        "StandardOutPath": log,
        "StandardErrorPath": log,
        "Umask": 0o077,
    }


def plist_bytes(agent: Agent, home: Path, *, home_from_env: bool) -> bytes:
    return plistlib.dumps(plist_dict(agent, home, home_from_env=home_from_env), sort_keys=True)


# --- launchctl --------------------------------------------------------------------------------------------------

def _launchctl(*args: str) -> subprocess.CompletedProcess:
    """Run /bin/launchctl. (Replaced in the host's tests.)"""
    return subprocess.run([LAUNCHCTL, *args], capture_output=True, text=True, timeout=60, check=False)


def job(label: str) -> dict | None:
    """What launchd says about the job in this user's GUI session ({"state", "pid", "last_exit"}), or None when
    it is not loaded."""
    r = _launchctl("print", target(label))
    if r.returncode != 0:
        return None
    info: dict = {"state": None, "pid": None, "last_exit": None}
    for line in r.stdout.splitlines():
        key, sep, value = line.strip().partition(" = ")
        if not sep:
            continue
        if key == "state" and info["state"] is None:
            info["state"] = value
        elif key == "pid" and info["pid"] is None and value.isdigit():
            info["pid"] = int(value)
        elif key == "last exit code" and info["last_exit"] is None:
            info["last_exit"] = value
    return info


def _check(r: subprocess.CompletedProcess, what: str) -> None:
    if r.returncode != 0:
        detail = (r.stderr or r.stdout).strip()
        raise LaunchdError(f"{what} failed (launchctl exit {r.returncode}){': ' + detail if detail else ''}")


def bootstrap(plist: Path) -> None:
    _check(_launchctl("bootstrap", domain(), str(plist)), f"launchctl bootstrap {plist}")


def bootout(label: str, wait: float = EXIT_TIMEOUT_SECONDS + 10) -> None:
    """Unload the job; launchd stops a running host first (SIGTERM, then SIGKILL after ExitTimeOut).

    launchctl returns while the job is still being torn down, and a bootstrap of the same label until it is gone
    fails ("Bootstrap failed: 5: Input/output error"), so this waits until launchd no longer lists it."""
    _check(_launchctl("bootout", target(label)), f"launchctl bootout {target(label)}")
    deadline = time.monotonic() + wait
    while job(label) is not None:
        if time.monotonic() >= deadline:
            raise LaunchdError(f"launchd still has {target(label)} {wait:.0f} seconds after bootout")
        time.sleep(0.2)


# What `mydata start` and `mydata service install` say when launchd will not load the agent. On macOS 13 and
# later the agent is listed under Login Items, where it can be switched off (also right after the "Background
# Items Added" notice); launchctl bootstrap then fails with "5: Input/output error" (tried on macOS 26.7 with
# `launchctl disable`). Whether the Settings switch always shows in `launchctl print-disabled` is unverified.
SWITCHED_OFF = ("myData Host is switched off: switch it on in System Settings > General > Login Items & Extensions "
                "(Allow in the Background)")
MAYBE_SWITCHED_OFF = ("launchd did not load myData Host; if it is switched off in System Settings > General > "
                      "Login Items & Extensions (Allow in the Background), switch it on")


def disabled(label: str) -> bool:
    """launchd has the label switched off for this user (`launchctl print-disabled`)."""
    r = _launchctl("print-disabled", domain())
    if r.returncode != 0:
        return False
    for line in r.stdout.splitlines():
        key, sep, value = line.strip().partition(" => ")
        if sep and key.strip('"') == label:
            return value.strip() in ("disabled", "true")
    return False


def kickstart(label: str) -> None:
    """Start the job if it is not running (never restarts a running one: no -k)."""
    _check(_launchctl("kickstart", target(label)), f"launchctl kickstart {target(label)}")
