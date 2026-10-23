"""mydata: control the host service.

    mydata start     start mydatad in the background and wait until it answers (exit 4: started, not answering yet);
                     when the host is installed as a login service, launchd starts it (launchctl kickstart)
    mydata stop      stop it (SIGTERM, then SIGKILL after 15 s), also one started by an older build; it exits
                     cleanly, so launchd leaves an installed host stopped until the next login or mydata start
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
    mydata service install --app APP [--label L] [--agents-dir DIR] [--dry-run]
                               run "myData Host.app" at login: write its LaunchAgent, point the apps'
                               app_config.json at it and bootstrap it (packaging/macos/install.sh runs this)
    mydata service uninstall [--label L] [--agents-dir DIR] [--dry-run]
                               boot the LaunchAgent out, remove its plist and its app_config.json entries;
                               the host's data is never touched
    mydata service status      what launchd says about the installed host
    mydata account add icloud [--email EMAIL]   link an iCloud account (read-only mirror of contacts and calendars)
    mydata account list                         list linked accounts
    mydata account remove ID [--yes]            unlink an account and delete its mirrored data
    mydata backup now                take a snapshot of the databases now (the host also takes one hourly)
    mydata backup list               list the snapshots and the last restore drill
    mydata backup verify [SNAPSHOT]  the restore drill: restore a snapshot (the newest by default) into a
                                     temporary folder, open it with this code and check it (exit 1: problems)
    mydata backup restore SNAPSHOT [--yes]   put a snapshot back (the host must be stopped; the current
                                     state is snapshotted first)
    mydata db check-migration        try this host's migrations on copies of the databases and compare every
                                     row (the files themselves are only read; exit 1: problems)
    mydata export --out DIR [--vcard 4.0] [--raw]   write the contacts and calendars as .vcf (vCard 3.0
                                     unless --vcard 4.0) and .ics files; --raw writes the stored text as it is
                                     (DIR must be new or empty, and outside the source checkout)
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import signal
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

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


def _agent(settings: Settings):
    """The LaunchAgent recorded for this host folder (macOS), or None."""
    from .service import launchd
    return launchd.recorded_agent(settings.home) if launchd.supported() else None


def _start_error(settings: Settings, since: float | None = None) -> str | None:
    """Why the host's last start failed (the daemon writes it: the port taken, an error while building), or None.
    With `since`, only an error written after that time."""
    from .service.daemon import start_error_path
    path = start_error_path(settings)
    try:
        if since is not None and path.stat().st_mtime < since:
            return None
        return path.read_text().strip() or None
    except OSError:
        return None


def _wait_for_exit(settings: Settings, pid: int, wait: float = 30) -> bool:
    """A host that holds the folder but does not answer is starting or stopping (Stop host, then Start host at
    once: its graceful shutdown takes up to 15 s). Wait until it answers or exits; True once it has exited."""
    deadline = time.time() + wait
    while time.time() < deadline:
        if not daemon_pid(settings):
            return True
        if _get_status(settings, timeout=1):
            return False
        time.sleep(0.3)
    return not daemon_pid(settings)


def _wait_until_answering(settings: Settings, failed) -> int:
    """Wait up to 20 s for /status after a start. `failed()` returns why the start failed, or None."""
    started = time.time()
    deadline = time.time() + 20
    while time.time() < deadline:
        status = _get_status(settings, timeout=1)
        if status:
            print(_describe(status))
            return 0
        why = failed()
        if why:
            status = _get_status(settings, timeout=1)
            if status:  # another start won the race; that daemon is running
                print(_describe(status))
                return 0
            error = _start_error(settings, since=started)
            print(f"{why}{': ' + error if error else ''}; see {settings.log_dir / 'mydatad.log'} and "
                  f"{settings.log_dir / 'mydatad.out'}", file=sys.stderr)
            return 1
        error = _start_error(settings, since=started)
        if error:  # under launchd it waits a minute before exiting, holding the folder
            print(f"mydatad could not start: {error}; see {settings.log_dir / 'mydatad.log'}", file=sys.stderr)
            return 1
        time.sleep(0.3)
    # Still running: not a failed start. An app keeps waiting for it (a hot machine, a slow first start).
    print(f"mydatad started but did not answer within 20 seconds; see {settings.log_dir / 'mydatad.log'}",
          file=sys.stderr)
    return EXIT_STILL_STARTING


def _start_agent(settings: Settings, agent) -> int:
    """Ask launchd to start the installed host: kickstart the loaded agent, or bootstrap it again (RunAtLoad)
    when it was booted out."""
    from .service import launchd
    try:
        info = launchd.job(agent.label)
        # The host that held the folder has let it go, but launchd may still see it exiting: kickstart does
        # nothing to a running job, so wait until it is gone (or a new one holds the folder).
        deadline = time.time() + 5
        while (info is not None and info["state"] == "running" and not daemon_pid(settings)
               and time.time() < deadline):
            time.sleep(0.2)
            info = launchd.job(agent.label)
        if info is not None:
            launchd.kickstart(agent.label)
        elif agent.plist.exists():
            launchd.bootstrap(agent.plist)
        else:
            print(f"mydata: the host's LaunchAgent {agent.plist} is missing; install the host again "
                  f"(host/packaging/macos/install.sh) or run `mydata service uninstall`", file=sys.stderr)
            return 1
    except launchd.LaunchdError as e:
        print(f"mydata: {e}", file=sys.stderr)
        if launchd.disabled(agent.label):
            # Switched off by the owner (System Settings) or after macOS's "Background Items Added" notice: the
            # apps still need a host, so start one as before, which launchd does not watch over.
            print(f"mydata: {launchd.SWITCHED_OFF}; starting the host without it until then", file=sys.stderr)
            return _start_detached(settings)
        print(f"mydata: {launchd.MAYBE_SWITCHED_OFF}", file=sys.stderr)
        return 1
    return _wait_until_answering(settings, _launchd_failed(settings, agent.label))


def _launchd_failed(settings: Settings, label: str):
    """For _wait_until_answering: why the host launchd was asked to start has failed, or None."""
    from .service import launchd
    started = time.time()

    def failed() -> str | None:
        if time.time() - started < 3 or daemon_pid(settings):
            return None
        info = launchd.job(label)
        if info is None:
            return f"launchd no longer has the host's LaunchAgent {label}"
        if info["state"] != "running" and info["last_exit"] not in (None, "0", "(never exited)"):
            return (f"mydatad exited ({info['last_exit']}); launchd tries again after "
                    f"{launchd.THROTTLE_SECONDS} seconds")
        return None

    return failed


def cmd_start(settings: Settings) -> int:
    pid = daemon_pid(settings)
    if pid:
        status = _get_status(settings)
        if status:
            print(_describe(status))
            return 0
        error = _start_error(settings)
        if error:  # the host holding the folder could not start; under launchd it waits a minute, then exits
            print(f"mydatad (pid {pid}) could not start: {error}; see {settings.log_dir / 'mydatad.log'}",
                  file=sys.stderr)
            return 1
        if not _wait_for_exit(settings, pid):
            status = _get_status(settings)
            if status:
                print(_describe(status))
                return 0
            print(f"mydatad (pid {pid}) is running but not answering; see {settings.log_dir / 'mydatad.log'}",
                  file=sys.stderr)
            return EXIT_STILL_STARTING
    agent = _agent(settings)
    if agent is not None:
        return _start_agent(settings, agent)
    return _start_detached(settings)


def _start_detached(settings: Settings) -> int:
    """Start the host as a detached process (no login service, or the login service is switched off)."""
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
    # In "myData Host.app" the interpreter runs isolated and never writes bytecode into its signed bundle; the
    # daemon it starts does the same.
    flags = [f for f, on in (("-I", sys.flags.isolated), ("-B", sys.dont_write_bytecode)) if on]
    name = "mydatad" if sys.platform == "darwin" else os.path.join(os.path.dirname(sys.executable), "mydatad")
    proc = subprocess.Popen([name, *flags, "-m", "mydata.service.daemon"], executable=sys.executable, **kwargs)
    return _wait_until_answering(
        settings, lambda: None if proc.poll() is None else f"mydatad exited with code {proc.returncode}")


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
    # The host exits with 0 on SIGTERM, so launchd (an installed host) does not start it again.
    os.kill(pid, signal.SIGTERM)
    deadline = time.time() + 15
    while time.time() < deadline:
        if not daemon_pid(settings):
            print("mydatad stopped")
            return 0
        time.sleep(0.2)
    agent = _agent(settings)
    if agent is not None:
        # launchd would start a killed host again: unload the agent, which kills it, until mydata start.
        from .service import launchd
        try:
            if launchd.job(agent.label) is not None:
                launchd.bootout(agent.label)
                print(f"mydatad did not stop in 15 seconds: its LaunchAgent was unloaded, which stops it; "
                      f"mydata start (or the next login) loads it again", file=sys.stderr)
        except launchd.LaunchdError as e:
            print(f"mydata: {e}", file=sys.stderr)
    if daemon_pid(settings):
        os.kill(pid, getattr(signal, "SIGKILL", signal.SIGTERM))
        print("mydatad did not stop in 15 seconds and was killed", file=sys.stderr)
    return 1


def cmd_status(settings: Settings) -> int:
    status = _get_status(settings)
    if not status:
        pid = daemon_pid(settings)
        print("mydatad is not running" if not pid else f"mydatad (pid {pid}) is not answering")
        why = _start_error(settings)
        if why:
            print(f"Its last start failed: {why}")
        code = 3
    else:
        print(_describe(status))
        code = 0
    agent = _agent(settings)
    if agent is not None:
        print(f"Installed as a login service: {agent.app} (LaunchAgent {agent.label})")
    return code


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
                           f"calendars from this host (its snapshots keep copies until they expire)? Nothing "
                           f"changes in {name}. [y/N] ")
        except (EOFError, KeyboardInterrupt):
            answer = ""
        if answer.strip().lower() not in ("y", "yes"):
            print("Not removed.")
            return 1
    from .service.backup import BackupError, kept_until
    from .sources._db import MigrationError
    try:
        accounts.remove(account.id, on_remove=lambda a: _remove_account_data(settings, a))
    except (SecretStoreError, BackupError, MigrationError) as e:  # a store needed migrating, and that failed
        print(f"mydata: {e}", file=sys.stderr)
        return 1
    until = kept_until()
    print(f"Removed {name} account {account.email} (id {account.id}): its mirrored data and its Keychain "
          f"item are deleted. Copies of that data in the host's snapshots ({settings.home / 'backups'}) stay "
          f"until they expire: by {until.day} {until:%B %Y} if the host keeps running.")
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
            print(f"Took snapshot {snap.name}: {files or 'nothing'}\n  in {snap.path}")
            failed = backup.failures(snap)
            for f in failed:
                print(f"mydata: left out {f['file']}: {f['reason']}", file=sys.stderr)
            return 1 if failed else 0
        if ns.action == "list":
            snaps = backup.list_snapshots(home)
            if not snaps:
                print("No snapshots yet (mydata backup now takes one; the host takes one every hour).")
            for s in snaps:
                try:
                    m = s.manifest
                    files = m.get("files", [])
                    failed = backup.failures(s)
                    print(f"{s.name}  {m.get('reason', '?'):13}  {len(files)} file(s)  "
                          f"{_size(sum(f.get('size', 0) for f in files))}"
                          + (f"  left out: {', '.join(f['file'] for f in failed)}" if failed else ""))
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
        if out["damaged"]:
            print(f"Too damaged to copy, so kept as they were in {out['before']}/{backup.DAMAGED}: "
                  f"{', '.join(out['damaged'])}.")
        if out["untouched"]:
            print(f"Not in the snapshot, so left as they are: {', '.join(out['untouched'])}.")
        return 0
    except backup.BackupError as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 1
    except (OSError, sqlite3.Error) as e:
        print(f"mydata: {type(e).__name__}: {e}", file=sys.stderr)
        return 1


def cmd_db(settings: Settings, ns: argparse.Namespace) -> int:
    from .service import backup
    try:
        results = backup.check_migration(settings.home)
    except (OSError, sqlite3.Error) as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 1
    if not results:
        print("Nothing to check: the host folder holds no databases yet.")
        return 0
    for r in results:
        step = (f"from schema version {r['from']} to {r['to']}" if r["from"] != r["to"]
                else f"at schema version {r['to']}, nothing to migrate")
        if r["problems"]:
            print(f"{r['file']} ({step}): FAILED on a copy", file=sys.stderr)
            for problem in r["problems"]:
                print(f"  - {problem}", file=sys.stderr)
        else:
            print(f"{r['file']} ({step}): every one of its {r['rows']} rows kept, checks passed (on a copy)")
    return 1 if any(r["problems"] for r in results) else 0


def cmd_export(settings: Settings, out: str, *, raw: bool = False, vcard: str = "3.0") -> int:
    from .sources.export import ExportError, export
    try:
        summary = export(settings.home, out, style="raw" if raw else "clean", vcard_version=vcard)
    except ExportError as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 1
    except (OSError, sqlite3.Error) as e:
        print(f"mydata: {type(e).__name__}: {e}", file=sys.stderr)
        return 1
    cards = sum(c["cards"] for c in summary["contacts"])
    events = sum(c["resources"] for c in summary["calendars"])
    what = "the stored text as it is" if raw else f"vCard {vcard}"
    print(f"Exported {cards} card(s) from {len(summary['contacts'])} address book(s) and {events} event(s) from "
          f"{len(summary['calendars'])} calendar(s) to {os.path.abspath(out)} ({what})")
    for book in summary["contacts"]:
        if book.get("as_stored"):
            print(f"Address book {book['name']!r}: {book['as_stored']} card(s) could not be read, so they were "
                  f"written as stored.")
    for cal in summary["calendars"]:
        if cal.get("zones_unknown"):
            print(f"Calendar {cal['name']!r}: no zone data for {', '.join(cal['zones_unknown'])}; those events keep "
                  f"their zone name without a definition.")
    for skipped in summary["not_exported"]:
        print(f"Not exported: {skipped['source']} calendar {skipped['calendar']!r}: {skipped['why']}.")
    return 0


def cmd_dev_setup(settings: Settings) -> int:
    """The apps start the host with the command in <home>/app_config.json, and stop it with its stop command
    (to replace a host built from another version). In development that is this checkout's Python running
    `mydata start` and `mydata stop`; a packaged install will run a bundled host binary instead."""
    from .service import launchd
    from .service.config import private_dir
    agent = launchd.recorded_agent(settings.home)
    if agent is not None:
        print(f"mydata: {settings.home} is served by the installed host ({agent.app}, LaunchAgent {agent.label}), "
              f"which starts at login. Develop on another folder (MYDATA_HOME=~/mydata-dev), or uninstall it "
              f"first (host/packaging/macos/uninstall.sh).", file=sys.stderr)
        return 1
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


def _plist_home(plist: Path) -> Path | None:
    """The host folder an existing agent plist serves (its MYDATA_HOME, else the default), or None."""
    import plistlib
    from .service.config import default_home_dir
    try:
        with open(plist, "rb") as fh:
            data = plistlib.load(fh)
    except (OSError, ValueError, plistlib.InvalidFileException):
        return None
    env = data.get("EnvironmentVariables") if isinstance(data, dict) else None
    home = env.get("MYDATA_HOME") if isinstance(env, dict) else None
    return Path(home) if home else default_home_dir()


def _same_folder(a: Path, b: Path) -> bool:
    return os.path.realpath(a) == os.path.realpath(b)


def cmd_service(settings: Settings, ns: argparse.Namespace) -> int:
    from .service import launchd
    from .service.config import private_dir
    if ns.action != "status" and not launchd.supported():
        print("mydata: the login service is macOS only for now", file=sys.stderr)
        return 1
    home = settings.home
    recorded = launchd.recorded_agent(home)
    if ns.action == "status":
        if recorded is None:
            print(f"No login service is installed for {home}.")
            return 3
        info = launchd.job(recorded.label) if launchd.supported() else None
        state = ("not loaded" if info is None else
                 f"{info['state']}" + (f", pid {info['pid']}" if info["pid"] else "")
                 + (f", last exit {info['last_exit']}" if info["last_exit"] else ""))
        print(f"{recorded.app}\n  LaunchAgent {recorded.label}: {state}\n  plist {recorded.plist}")
        if launchd.supported() and launchd.disabled(recorded.label):
            print(f"  {launchd.SWITCHED_OFF}")
        why = _start_error(settings)
        if why and not _get_status(settings, timeout=1):
            print(f"  Its last start failed: {why}")
        return 0
    try:
        label = launchd.check_label(ns.label or (recorded.label if recorded else launchd.DEFAULT_LABEL))
    except launchd.LaunchdError as e:
        print(f"mydata: {e}", file=sys.stderr)
        return 2
    agents_dir = Path(ns.agents_dir).expanduser().absolute() if ns.agents_dir else launchd.default_agents_dir()
    dry = ns.dry_run
    say = (lambda line: print(f"would {line}")) if dry else (lambda line: print(line[0].upper() + line[1:]))

    if ns.action == "install":
        app = Path(ns.app).expanduser().absolute()
        agent = launchd.Agent(label=label, plist=agents_dir / f"{label}.plist", app=app)
        if recorded is not None and recorded.label != label:
            print(f"mydata: {home} already has a login service with another label ({recorded.label}); "
                  f"uninstall it first", file=sys.stderr)
            return 1
        served = _plist_home(agent.plist) if agent.plist.exists() else None
        if served is not None and not _same_folder(served, home):
            print(f"mydata: the LaunchAgent {label} ({agent.plist}) serves another host folder ({served}); "
                  f"choose another --label", file=sys.stderr)
            return 1
        if not dry and not (agent.daemon.is_file() and agent.cli.is_file()):
            print(f"mydata: {app} is not a built myData Host app (no Contents/MacOS/mydatad and mydata)",
                  file=sys.stderr)
            return 1
        home_from_env = bool(os.environ.get("MYDATA_HOME"))
        loaded = launchd.job(label)
        config = launchd.installed_config(home, agent)
        if loaded is not None:
            say(f"boot out the loaded LaunchAgent {label} (it stops the host it runs)")
            if not dry:
                launchd.bootout(label)
        pid = daemon_pid(settings)
        if pid:
            say(f"stop the host running on {home} (pid {pid}), so the installed one can start")
            if not dry and cmd_stop(settings) != 0:
                return 1
        say(f"create {settings.log_dir}")
        say(f"write {agent.plist}")
        say(f"bootstrap it into {launchd.domain()}, which starts the host now and at every login")
        say(f"write {launchd.app_config_path(home)}: the apps start the host with "
            f"{' '.join(config['host_command'])!r} and stop it with {' '.join(config['stop_command'])!r}")
        if dry:
            print(f"\n{agent.plist}:\n" + launchd.plist_bytes(agent, home, home_from_env=home_from_env).decode())
            return 0
        private_dir(home)
        private_dir(settings.log_dir)
        agents_dir.mkdir(parents=True, exist_ok=True)
        tmp = agent.plist.with_name(agent.plist.name + ".tmp")
        tmp.write_bytes(launchd.plist_bytes(agent, home, home_from_env=home_from_env))
        os.chmod(tmp, 0o644)
        os.replace(tmp, agent.plist)
        try:
            launchd.bootstrap(agent.plist)
        except launchd.LaunchdError as e:
            # app_config.json is left as it was: the apps never point at an agent that cannot load.
            print(f"mydata: {e}", file=sys.stderr)
            print(f"mydata: {launchd.SWITCHED_OFF if launchd.disabled(label) else launchd.MAYBE_SWITCHED_OFF}; "
                  f"then run the install again", file=sys.stderr)
            return 1
        launchd.write_app_config(home, config)
        return _wait_until_answering(settings, _launchd_failed(settings, label))

    # uninstall
    plist = recorded.plist if recorded is not None and not ns.agents_dir else agents_dir / f"{label}.plist"
    served = _plist_home(plist) if plist.exists() else None
    if served is not None and not _same_folder(served, home):
        print(f"mydata: the LaunchAgent {label} ({plist}) serves another host folder ({served}); nothing done",
              file=sys.stderr)
        return 1
    loaded = launchd.job(label)
    if recorded is None and served is None and loaded is None:
        print(f"No login service is installed for {home} (label {label}); nothing to do.")
        return 0
    if loaded is not None:
        say(f"boot out the LaunchAgent {label} (it stops the host it runs)")
        if not dry:
            try:
                launchd.bootout(label)
            except launchd.LaunchdError as e:
                print(f"mydata: {e}", file=sys.stderr)
                return 1
    if plist.exists():
        say(f"remove {plist}")
        if not dry:
            plist.unlink()
    if recorded is not None:
        say(f"take the installed host's commands out of {launchd.app_config_path(home)} (run `mydata dev-setup` "
            f"from a checkout to point the apps at it instead)")
        if not dry:
            launchd.write_app_config(home, launchd.uninstalled_config(launchd.read_app_config(home), recorded))
    print(f"The host's data in {home} is left as it is.")
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
    db = sub.add_parser("db", help="the host's databases")
    dbsub = db.add_subparsers(dest="action", required=True)
    dbsub.add_parser("check-migration", help="try this host's migrations on copies of the databases")
    sv = sub.add_parser("service", help="run the host at login (macOS LaunchAgent)")
    svsub = sv.add_subparsers(dest="action", required=True)
    si = svsub.add_parser("install", help="install a built myData Host.app as a login service")
    si.add_argument("--app", required=True, help="the myData Host.app to run (already in its final place)")
    su = svsub.add_parser("uninstall", help="remove the login service; the data is left as it is")
    for p in (si, su):
        p.add_argument("--label", help="the launchd label (default kiwi.mydata.host)")
        p.add_argument("--agents-dir", help="where the plist goes (default ~/Library/LaunchAgents)")
        p.add_argument("--dry-run", action="store_true", help="print what would be done, change nothing")
    svsub.add_parser("status", help="what launchd says about the installed host")
    ex = sub.add_parser("export", help="write the stored contacts and calendars as .vcf and .ics files")
    ex.add_argument("--out", required=True, help="a new or empty folder outside the source checkout")
    ex.add_argument("--vcard", choices=("3.0", "4.0"), default="3.0", help="the vCard version (default 3.0)")
    ex.add_argument("--raw", action="store_true", help="write the stored text as it is, nothing converted")
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
    if ns.cmd == "db":
        return cmd_db(settings, ns)
    if ns.cmd == "export":
        return cmd_export(settings, ns.out, raw=ns.raw, vcard=ns.vcard)
    if ns.cmd == "dev-setup":
        return cmd_dev_setup(settings)
    if ns.cmd == "service":
        from .service.launchd import LaunchdError
        try:
            return cmd_service(settings, ns)
        except LaunchdError as e:
            print(f"mydata: {e}", file=sys.stderr)
            return 1
    if ns.cmd == "stop":
        return cmd_stop(settings, unless_current=ns.unless_current, expect=ns.expect)
    return {"start": cmd_start, "status": cmd_status}[ns.cmd](settings)


if __name__ == "__main__":
    sys.exit(main())
