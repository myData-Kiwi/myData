"""mydata: control the host service.

    mydata start     start mydatad in the background and wait until it answers (exit 4: started, not answering yet)
    mydata stop      stop it (SIGTERM, then SIGKILL after 15 s), also one started by an older build
    mydata stop --unless-current [--expect VERSION API_VERSION]
                     what an app runs to replace a host from another build: leave a host that is already this
                     checkout's code; with --expect, stop nothing (exit 5) unless this checkout's host is that
                     version and API version
    mydata status    show what the host reports (exit 0 running, 3 not running)
    mydata run       run mydatad in the foreground (development)
    mydata openapi   print the OpenAPI document (or write it, and the apps' host_version.g.dart, with --out)
    mydata agent create NAME   create a token for an MCP agent (shown once)
    mydata agent list          list agent tokens
    mydata agent revoke ID     revoke an agent token (by id or name)
    mydata dev-setup           tell the apps how to start this development host (writes app_config.json)
    mydata account add icloud [--email EMAIL]   link an iCloud account (read-only mirror of contacts and calendars)
    mydata account list                         list linked accounts
    mydata account remove ID [--yes]            unlink an account and delete its mirrored data
    mydata backup now                take a snapshot of the databases now (the host also takes one hourly)
    mydata backup list               list the snapshots and the last restore drill
    mydata backup verify [SNAPSHOT]  the restore drill: restore a snapshot (the newest by default) into a
                                     temporary folder, open it with this code and check it (exit 1: problems)
    mydata backup restore SNAPSHOT [--yes]   put a snapshot back (the host must be stopped; the current
                                     state is snapshotted first)
"""

from __future__ import annotations

import argparse
import getpass
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

EXIT_STILL_STARTING = 4  # start: the daemon is running but did not answer in time; it may yet
EXIT_WOULD_NOT_MATCH = 5  # stop --expect: a host started from here would be another build too; nothing stopped


def _get_status(settings: Settings, timeout: float = 2) -> dict | None:
    try:
        token = read_token(settings.app_token_path("cli"))
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
    from .service.config import private_dir, private_file
    private_dir(settings.home)
    private_dir(settings.log_dir)
    # Only what is printed before logging starts (config errors, crashes) lands here; kept per start.
    out_path = settings.log_dir / "mydatad.out"
    out = os.fdopen(os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "wb")
    private_file(out_path)
    kwargs: dict = {"stdout": out, "stderr": subprocess.STDOUT, "stdin": subprocess.DEVNULL,
                    "env": {**os.environ, "MYDATA_DETACHED": "1"}}
    if sys.platform.startswith("win"):
        kwargs["creationflags"] = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True  # survives the terminal or app that started it
    # argv[0] names the process (ps, pgrep, Activity Monitor); executable keeps this interpreter. macOS shows the
    # first 16 characters of argv[0] as its name and finds the venv from the real executable, so a bare
    # "mydatad". Elsewhere Python finds its venv from argv[0] (a bare name is looked up on PATH, which may hold
    # another venv or none), so an absolute path beside the interpreter. Hosts started by older builds run as
    # `python -m mydata.service.daemon`; the pid file's lock, not the command line, is what marks a running
    # daemon, so `mydata stop` stops both.
    name = "mydatad" if sys.platform == "darwin" else os.path.join(os.path.dirname(sys.executable), "mydatad")
    proc = subprocess.Popen([name, "-m", "mydata.service.daemon"], executable=sys.executable, **kwargs)
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
    # Still running: not a failed start. An app keeps waiting for it (a hot machine, a slow first start).
    print(f"mydatad started but did not answer within 20 seconds; see {settings.log_dir / 'mydatad.log'}",
          file=sys.stderr)
    return EXIT_STILL_STARTING


def _this_build() -> tuple[str, str]:
    """The version and API version of the host this checkout starts."""
    from . import __version__
    from .service.openapi import api_version
    return __version__, api_version()


def _is_current(status: dict) -> bool:
    """The running host is this checkout's code: the same versions, and its code unchanged since it started."""
    return (status.get("version"), status.get("api_version")) == _this_build() and not status.get("stale", False)


def _status_of_running(settings: Settings, wait: float) -> dict | None:
    """/status of the running daemon, giving one that is still starting up to `wait` seconds to answer."""
    deadline = time.time() + wait
    while True:
        status = _get_status(settings, timeout=1)
        if status or time.time() >= deadline or not daemon_pid(settings):
            return status
        time.sleep(0.3)


def cmd_stop(settings: Settings, unless_current: bool = False, expect: list[str] | None = None,
             wait: float = 10) -> int:
    pid = daemon_pid(settings)
    if not pid:
        print("mydatad is not running")
        return 0
    if expect is not None and tuple(expect) != _this_build():
        version, api = _this_build()
        print(f"mydatad was not stopped: a host started from here is version {version} (API {api}), not "
              f"{expect[0]} (API {expect[1]}), so replacing it would not help", file=sys.stderr)
        return EXIT_WOULD_NOT_MATCH
    if unless_current:
        # Another app may have just replaced it with this checkout's host: never stop that one.
        status = _status_of_running(settings, wait)
        if status and _is_current(status):
            print(f"mydatad was not stopped: it is already this build ({_describe(status)})")
            return 0
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
    from .service.openapi import HOST_VERSION_DART, host_version_dart, openapi_document
    doc = openapi_document()
    text = json.dumps(doc, indent=2, sort_keys=True) + "\n"
    if not out:
        sys.stdout.write(text)
        return 0
    with open(out, "w") as fh:
        fh.write(text)
    # The versions the apps compare with /status, so an app replaces a host built from another version.
    if HOST_VERSION_DART.parent.is_dir():
        HOST_VERSION_DART.write_text(host_version_dart(doc))
        print(f"Wrote {out} and {HOST_VERSION_DART}")
    else:
        print(f"Wrote {out}; {HOST_VERSION_DART.parent} does not exist, so host_version.g.dart was not written",
              file=sys.stderr)
    return 0


def cmd_agent(settings: Settings, ns: argparse.Namespace) -> int:
    from .service.auth import AgentStore
    store = AgentStore(settings.home)
    if ns.action == "create":
        try:
            agent, token = store.create(ns.name)
        except ValueError as e:
            print(f"mydata: {e}", file=sys.stderr)
            return 2
        print(f"Created agent {agent.name!r} (id {agent.id}). Its token, shown only now:\n\n  {token}\n\n"
              f"Give it to the agent as `Authorization: Bearer <token>` for {settings.base_url}/mcp")
        return 0
    if ns.action == "list":
        rows = store.list()
        if not rows:
            print("No agent tokens.")
        for a in rows:
            state = "revoked" if a["revoked"] else ("connected" if a["connected"] else "active")
            print(f"{a['id']}  {a['name']:24}  {state:9}  created {a['created_at']}"
                  + (f"  last seen {a['last_seen_at']}" if a["last_seen_at"] else ""))
        return 0
    try:
        agent = store.revoke(ns.ref)
    except KeyError as e:
        print(f"mydata: {e.args[0]}", file=sys.stderr)
        return 1
    print(f"Revoked agent {agent.name!r} (id {agent.id}). It can no longer connect.")
    return 0


def _secret_store():
    from .sources.secrets import default_secret_store
    return default_secret_store()


def _verify(provider: str, email: str, password: str) -> None:
    """Discovery against the provider; raises VerificationError (never containing the password)."""
    from .sources.providers import VERIFIERS
    VERIFIERS[provider](email, password)


def _remove_account_data(settings: Settings, account) -> None:
    """Hard-delete the account's mirrored contacts and calendars. Files that do not exist are left alone.
    A file that needs migrating is snapshotted first (backup.open_store)."""
    from .service.backup import open_store
    from .sources.calendar_store import CalendarStore
    from .sources.contacts_store import ContactsStore
    for cls, name in ((ContactsStore, "contacts.sqlite"), (CalendarStore, "calendar.sqlite")):
        path = settings.home / name
        if not path.exists():
            continue
        store = open_store(cls, settings.home, name)
        try:
            store.delete_account(account.id)
        finally:
            close = getattr(store, "close", None)
            if close:
                close()


def cmd_account(settings: Settings, ns: argparse.Namespace) -> int:
    from .sources.accounts import Accounts
    from .sources.providers import APP_PASSWORD_HELP, PROVIDER_NAMES, VerificationError
    from .sources.secrets import SecretStoreError
    accounts = Accounts(settings.home, _secret_store())
    if ns.action == "list":
        rows = accounts.list()
        if not rows:
            print("No accounts.")
        for a in rows:
            print(f"{a.id}  {PROVIDER_NAMES.get(a.provider, a.provider):7}  {a.email:32}  created {a.created_at}")
        return 0
    if ns.action == "add":
        name = PROVIDER_NAMES[ns.provider]
        try:
            email = (ns.email or input("Apple Account email (may differ from an address on your own domain): ")
                     ).strip()
            print(APP_PASSWORD_HELP)
            password = getpass.getpass("App-specific password: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nmydata: cancelled", file=sys.stderr)
            return 1
        print(f"Checking with {name}...")
        try:
            account = accounts.add(ns.provider, email, password,
                                   verify=lambda e, p: _verify(ns.provider, e, p))
        except ValueError as e:
            print(f"mydata: {e}", file=sys.stderr)
            return 2
        except (VerificationError, SecretStoreError) as e:
            print(f"mydata: {e} Nothing was stored.", file=sys.stderr)
            return 1
        finally:
            password = ""
        print(f"Added {name} account {account.email} (id {account.id}). Read-only: nothing is ever changed in {name}.")
        print("The running host notices it within seconds and syncs it." if daemon_pid(settings)
              else "The host syncs it when it runs (mydata start).")
        return 0
    account = accounts.get(ns.ref)
    if account is None:
        print(f"mydata: no account with id {ns.ref!r} (see mydata account list)", file=sys.stderr)
        return 1
    name = PROVIDER_NAMES.get(account.provider, account.provider)
    if not ns.yes:
        try:
            answer = input(f"Remove {name} account {account.email} and delete its mirrored contacts and "
                           f"calendars from this host? Nothing changes in {name}. [y/N] ")
        except (EOFError, KeyboardInterrupt):
            answer = ""
        if answer.strip().lower() not in ("y", "yes"):
            print("Not removed.")
            return 1
    from .service.backup import BackupError
    try:
        accounts.remove(account.id, on_remove=lambda a: _remove_account_data(settings, a))
    except (SecretStoreError, BackupError) as e:  # BackupError: a store needed migrating, and its snapshot failed
        print(f"mydata: {e}", file=sys.stderr)
        return 1
    print(f"Removed {name} account {account.email} (id {account.id}): its mirrored data and its Keychain "
          f"item are deleted.")
    return 0


def _size(n: int) -> str:
    for unit in ("bytes", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n} {unit}" if unit == "bytes" else f"{n:.1f} {unit}"
        n /= 1024
    return str(n)


def cmd_backup(settings: Settings, ns: argparse.Namespace) -> int:
    from .service import backup
    home = settings.home
    try:
        if ns.action == "now":
            snap = backup.take_snapshot(home, "manual")
            if snap is None:
                print("Nothing to back up: the host folder holds no databases yet.")
                return 0
            backup.prune(home)
            files = ", ".join(f"{f['file']} ({_size(f['size'])})" for f in snap.manifest["files"])
            print(f"Took snapshot {snap.name}: {files}\n  in {snap.path}")
            return 0
        if ns.action == "list":
            snaps = backup.list_snapshots(home)
            if not snaps:
                print("No snapshots yet (mydata backup now takes one; the host takes one every hour).")
            for s in snaps:
                try:
                    m = s.manifest
                    files = m.get("files", [])
                    print(f"{s.name}  {m.get('reason', '?'):13}  {len(files)} file(s)  "
                          f"{_size(sum(f.get('size', 0) for f in files))}")
                except (OSError, ValueError):
                    print(f"{s.name}  (manifest unreadable)")
            last = backup.last_verify(home)
            if last:
                print(f"Last restore drill: {last.get('at')} on {last.get('snapshot')}: "
                      f"{'passed' if last.get('ok') else 'FAILED'}")
            return 0
        if ns.action == "verify":
            result = backup.verify(home, ns.snapshot)
            if result["ok"]:
                print(f"Snapshot {result['snapshot']} restores cleanly: every database opened with this host, "
                      f"passed its checks and has the row counts in its manifest.")
                return 0
            print(f"Snapshot {result['snapshot']} did not pass the restore drill:", file=sys.stderr)
            for problem in result["problems"]:
                print(f"  - {problem}", file=sys.stderr)
            return 1
        # restore
        if daemon_pid(settings):
            print("mydata: the host is running; stop it first (mydata stop, or Quit in the myData app)",
                  file=sys.stderr)
            return 1
        snap = backup.find_snapshot(home, ns.snapshot)
        if not ns.yes:
            try:
                answer = input(f"Replace the databases in {home} with snapshot {snap.name}? The current ones are "
                               f"snapshotted first. [y/N] ")
            except (EOFError, KeyboardInterrupt):
                answer = ""
            if answer.strip().lower() not in ("y", "yes"):
                print("Not restored.")
                return 1
        out = backup.restore(home, snap.name)
        print(f"Restored {', '.join(out['restored'])} from snapshot {out['snapshot']}.")
        if out["before"]:
            print(f"The state it replaced is snapshot {out['before']} (mydata backup restore {out['before']} "
                  f"puts it back).")
        if out["untouched"]:
            print(f"Not in the snapshot, so left as they are: {', '.join(out['untouched'])}.")
        return 0
    except backup.BackupError as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 1


def cmd_dev_setup(settings: Settings) -> int:
    """The apps start the host with the command in <home>/app_config.json, and stop it with its stop command
    (to replace a host built from another version). In development that is this checkout's Python running
    `mydata start` and `mydata stop`; a packaged install will run a bundled host binary instead."""
    from .service.config import private_dir
    private_dir(settings.home)
    config = {
        "host_command": [sys.executable, "-m", "mydata.cli", "start"],
        "stop_command": [sys.executable, "-m", "mydata.cli", "stop"],
        "note": "Development: written by `mydata dev-setup`. The apps run this to start the host.",
    }
    path = settings.home / "app_config.json"
    path.write_text(json.dumps(config, indent=2) + "\n")
    print(f"Wrote {path}:\n  host command: {' '.join(config['host_command'])}\n"
          f"  stop command: {' '.join(config['stop_command'])}")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="mydata", description="Control the myData host.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("start", "status", "run", "dev-setup"):
        sub.add_parser(name)
    st = sub.add_parser("stop")
    st.add_argument("--unless-current", action="store_true",
                    help="leave a host that already runs this checkout's code")
    st.add_argument("--expect", nargs=2, metavar=("VERSION", "API_VERSION"),
                    help="stop nothing (exit 5) unless a host started from here is this version and API version")
    o = sub.add_parser("openapi")
    o.add_argument("--out")
    ag = sub.add_parser("agent", help="manage MCP agent tokens")
    agsub = ag.add_subparsers(dest="action", required=True)
    agsub.add_parser("create").add_argument("name")
    agsub.add_parser("list")
    agsub.add_parser("revoke").add_argument("ref", metavar="ID")
    ac = sub.add_parser("account", help="link accounts to mirror (read-only)")
    acsub = ac.add_subparsers(dest="action", required=True)
    add = acsub.add_parser("add", help="link an account; asks for an app-specific password")
    add.add_argument("provider", choices=["icloud"])
    add.add_argument("--email")
    acsub.add_parser("list")
    rm = acsub.add_parser("remove", help="unlink an account and delete its mirrored data")
    rm.add_argument("ref", metavar="ID")
    rm.add_argument("--yes", action="store_true", help="do not ask to confirm")
    bk = sub.add_parser("backup", help="snapshots of the databases")
    bksub = bk.add_subparsers(dest="action", required=True)
    bksub.add_parser("now", help="take a snapshot now")
    bksub.add_parser("list", help="list the snapshots")
    bksub.add_parser("verify", help="restore a snapshot into a temporary folder and check it").add_argument(
        "snapshot", nargs="?", help="a snapshot name (default: the newest)")
    rs = bksub.add_parser("restore", help="put a snapshot back (the host must be stopped)")
    rs.add_argument("snapshot")
    rs.add_argument("--yes", action="store_true", help="do not ask to confirm")
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
    if ns.cmd == "agent":
        return cmd_agent(settings, ns)
    if ns.cmd == "account":
        return cmd_account(settings, ns)
    if ns.cmd == "backup":
        return cmd_backup(settings, ns)
    if ns.cmd == "dev-setup":
        return cmd_dev_setup(settings)
    if ns.cmd == "stop":
        return cmd_stop(settings, unless_current=ns.unless_current, expect=ns.expect)
    return {"start": cmd_start, "status": cmd_status}[ns.cmd](settings)


if __name__ == "__main__":
    sys.exit(main())
