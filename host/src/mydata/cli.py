"""mydata: control the host service.

    mydata start     start mydatad in the background and wait until it answers
    mydata stop      stop it (SIGTERM, then SIGKILL after 15 s)
    mydata status    show what the host reports (exit 0 running, 3 not running)
    mydata run       run mydatad in the foreground (development)
    mydata openapi   print the OpenAPI document (or write it with --out)
"""

from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request

from .service.config import ConfigError, Settings, load_settings
from .service.daemon import daemon_pid
from .service.security import TokenError, read_token


def _get_status(settings: Settings, timeout: float = 2) -> dict | None:
    try:
        token = read_token(settings.token_path)
    except TokenError:
        return None
    req = urllib.request.Request(settings.base_url + "/status", headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, OSError, ValueError):
        return None


def _describe(status: dict) -> str:
    m = status["model"]
    line = f"myData host {status['version']} running; model {m['name']}: {m['state']}"
    if m.get("progress") and m["state"] == "pulling":
        line += f" ({m['progress']['percent']}%)"
    if m.get("error"):
        line += f" - {m['error']}"
    return line


def cmd_start(settings: Settings) -> int:
    pid = daemon_pid(settings)
    if pid:
        status = _get_status(settings)
        print(_describe(status) if status else f"mydatad is already running (pid {pid})")
        return 0
    settings.log_dir.mkdir(parents=True, exist_ok=True)
    # Only what is printed before logging starts (config errors, crashes) lands here; kept per start.
    out = open(settings.log_dir / "mydatad.out", "wb")
    kwargs: dict = {"stdout": out, "stderr": subprocess.STDOUT, "stdin": subprocess.DEVNULL,
                    "env": {**os.environ, "MYDATA_DETACHED": "1"}}
    if sys.platform.startswith("win"):
        kwargs["creationflags"] = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True  # survives the terminal or app that started it
    proc = subprocess.Popen([sys.executable, "-m", "mydata.service.daemon"], **kwargs)
    deadline = time.time() + 20
    while time.time() < deadline:
        if proc.poll() is not None:
            status = _get_status(settings, timeout=1)
            if status:  # another start won the race; that daemon is running
                print(_describe(status))
                return 0
            print(f"mydatad exited with code {proc.returncode}; see {settings.log_dir / 'mydatad.log'} "
                  f"and {settings.log_dir / 'mydatad.out'}", file=sys.stderr)
            return 1
        status = _get_status(settings, timeout=1)
        if status:
            print(_describe(status))
            return 0
        time.sleep(0.3)
    print(f"mydatad did not answer within 20 seconds; see {settings.log_dir / 'mydatad.log'}", file=sys.stderr)
    return 1


def cmd_stop(settings: Settings) -> int:
    pid = daemon_pid(settings)
    if not pid:
        print("mydatad is not running")
        return 0
    os.kill(pid, signal.SIGTERM)
    deadline = time.time() + 15
    while time.time() < deadline:
        if not daemon_pid(settings):
            print("mydatad stopped")
            return 0
        time.sleep(0.2)
    os.kill(pid, getattr(signal, "SIGKILL", signal.SIGTERM))
    print("mydatad did not stop in 15 seconds and was killed", file=sys.stderr)
    return 1


def cmd_status(settings: Settings) -> int:
    status = _get_status(settings)
    if not status:
        pid = daemon_pid(settings)
        print("mydatad is not running" if not pid else f"mydatad (pid {pid}) is not answering")
        return 3
    print(_describe(status))
    return 0


def cmd_openapi(out: str | None) -> int:
    from .service.openapi import openapi_document
    text = json.dumps(openapi_document(), indent=2, sort_keys=True) + "\n"
    if out:
        with open(out, "w") as fh:
            fh.write(text)
    else:
        sys.stdout.write(text)
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="mydata", description="Control the myData host.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("start", "stop", "status", "run"):
        sub.add_parser(name)
    o = sub.add_parser("openapi")
    o.add_argument("--out")
    ns = ap.parse_args(argv)
    if ns.cmd == "openapi":
        return cmd_openapi(ns.out)
    if ns.cmd == "run":
        from .service.daemon import main as run
        return run()
    try:
        settings = load_settings()
    except ConfigError as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 2
    return {"start": cmd_start, "stop": cmd_stop, "status": cmd_status}[ns.cmd](settings)


if __name__ == "__main__":
    sys.exit(main())
