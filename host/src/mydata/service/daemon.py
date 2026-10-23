"""mydatad: the host service. Runs in the foreground; `mydata start` runs it in the background, or asks launchd to
when the host is installed as a login service (launchd.py). Exit code 0 means a clean stop (SIGTERM, /shutdown):
launchd then leaves it stopped; anything else is an error, and launchd starts it again.

On start: catch SIGTERM/SIGINT first (a stop during start-up is a clean stop too), read config.toml (create it
with defaults), set up structured logging, refuse to run twice, bind the API's port on the loopback address
(a taken port stops it before anything else starts), create the tokens, migrate, start getting the model ready
in the background, start the hourly snapshots of the databases (backup.py) and the daily trash expiry
(trash.py), and serve. On SIGTERM/SIGINT: finish open requests, stop Ollama if the host started it, and
remove the pid file. Under launchd, a host that cannot start waits a minute before it exits with an error.
"""

from __future__ import annotations

import signal
import threading

# Run as a program: catch a stop before the imports below (about half a second); main() takes it over.
_EARLY_STOP = threading.Event()
if __name__ == "__main__":
    for _sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(_sig, lambda *_: _EARLY_STOP.set())

import logging
import os
import socket
import sys
import traceback
from pathlib import Path

import uvicorn

from .. import __version__
from ..tools import default_registry
from .api import create_app
from .assistant import Assistant
from .config import ConfigError, Settings, load_settings, private_dir
from .logs import log, setup_logging
from .model import ModelManager
from .modes import ModeController
from .state import HostState
from .auth import AgentStore, Authenticator, ensure_app_tokens
from .backup import BackupService
from .launchd import LABEL_ENV as LAUNCHD_LABEL_ENV
from .sync import SyncService
from .trash import TrashExpiry

logger = logging.getLogger("mydata.daemon")


def _lock(fd: int) -> bool:
    try:
        if sys.platform.startswith("win"):
            import msvcrt
            msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


def acquire_pid_lock(settings: Settings, *, marker: str | None = None) -> int | None:
    """Hold an exclusive lock on the pid file for the life of the process. The kernel releases it on any
    exit, including a crash, so a held lock always means a live mydatad (or a restore: it writes `marker`
    instead of its pid, so daemon_pid finds no host to stop). Returns the fd, or None if taken."""
    private_dir(settings.home)  # also tightens a folder made before the host set 0700
    fd = os.open(settings.pid_path, os.O_RDWR | os.O_CREAT, 0o600)
    if not _lock(fd):
        os.close(fd)
        return None
    os.ftruncate(fd, 0)
    os.write(fd, (marker or str(os.getpid())).encode())
    return fd


def daemon_pid(settings: Settings) -> int | None:
    """The pid of the running mydatad, or None. A pid file nobody holds the lock on is stale and removed,
    so a leftover pid can never point the mydata command at an unrelated process. None too while a restore
    holds the lock (the file then holds no pid)."""
    if not settings.pid_path.exists():
        return None
    try:
        fd = os.open(settings.pid_path, os.O_RDWR)
    except FileNotFoundError:
        return None
    try:
        if _lock(fd):  # nobody holds it: no daemon
            settings.pid_path.unlink(missing_ok=True)
            return None
        try:
            return int(settings.pid_path.read_text().strip())
        except ValueError:
            return None
    finally:
        os.close(fd)


def build_sources(settings: Settings, secrets=None, transport=None) -> SyncService:
    """Linked accounts (passwords in the Keychain) and the service that mirrors them."""
    from ..sources.accounts import Accounts
    from ..sources.secrets import default_secret_store
    return SyncService(settings.home, Accounts(settings.home, secrets or default_secret_store()), transport=transport)


def build(settings: Settings, sources: SyncService | None = None, *, model_factory=None, models=None,
          real_today=None, backups: BackupService | None = None):
    """The app, the parts main() starts and stops, and the mode refresh() chose (real with a source on or
    owned data held): (app, models, sources, mode). main() passes the backup service it starts; the other
    keyword arguments are for tests: a scripted model, a stand-in for the model manager, and a fixed date
    for real mode."""
    legacy = settings.home / "token"  # phase 1 had one shared token; it is replaced by per-app tokens
    if legacy.exists():
        legacy.unlink()
        log(logger, logging.INFO, "removed the old shared token; apps now have their own", path=str(legacy))
    auth = Authenticator(ensure_app_tokens(settings.home), AgentStore(settings.home))
    registry = default_registry(today=settings.today)
    state = HostState(settings.home)
    assistant = Assistant(settings, registry, model_factory=model_factory, today=settings.today)
    models = models or ModelManager(settings, enabled=state.assistant_enabled, warm=assistant.warm)
    sources = sources or build_sources(settings)
    # demo (no account: fake tools, pinned date) or real (the mirror, the real date); re-warm on a switch.
    modes = ModeController(assistant, sources, on_change=lambda _mode: models.rewarm(), real_today=real_today,
                           state=state)
    sources.on_accounts_changed = modes.refresh
    modes.refresh()
    stop = lambda: os.kill(os.getpid(), signal.SIGTERM)  # the same clean shutdown as `mydata stop`
    app = create_app(auth, registry, models, assistant, state=state, shutdown=stop, sources=sources,
                     backups=backups or BackupService(settings.home))
    return app, models, sources, modes.mode


# Under launchd, a host that cannot start (a config error, the port taken, an exception while building) waits
# this long before it exits with an error, so KeepAlive tries again about once a minute instead of every
# ThrottleInterval (15 s), and `mydata stop` can still end the loop (it then exits with 0).
FAILURE_PAUSE_SECONDS = 60
# launchd appends the daemon's stdout and stderr to <home>/logs/mydatad.out (the plist): kept under this size.
OUT_LIMIT_BYTES = 1_000_000
OUT_KEEP_BYTES = 100_000


def start_error_path(settings: Settings):
    """Why the last start failed (one line, no user data), for `mydata start` and `mydata status`. Removed by the
    next host that takes the folder."""
    return settings.log_dir / "start-error"


class StopRequest:
    """SIGTERM or SIGINT, from the first line of main(): a stop that arrives while the host is still starting
    (migrations and the snapshot before them, the first sync) is a clean stop too, and exits with 0, so launchd
    leaves it stopped. Only flags are set here; main() checks them between the steps of starting, and a
    server that exists is told to exit (uvicorn installs its own handlers once it runs, and re-raises the
    signal to this one when it has shut down)."""

    def __init__(self):
        self.event = threading.Event()
        self.server: uvicorn.Server | None = None

    def __call__(self, signum, frame) -> None:
        self.event.set()
        if self.server is not None:
            self.server.should_exit = True

    @property
    def requested(self) -> bool:
        return self.event.is_set()


def bind_listener(host: str, port: int) -> socket.socket:
    """The API's listening socket, bound before anything else starts, so a taken port stops the host before it
    syncs, snapshots or loads a model. Not listening yet: until uvicorn serves, a connection is refused at once."""
    family, kind, proto, _, address = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)[0]
    sock = socket.socket(family, kind, proto)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # as uvicorn does: a restart within TIME_WAIT
        sock.bind(address)
    except OSError:
        sock.close()
        raise
    return sock


def _trim_output(path) -> None:
    """Keep launchd's output file (opened by launchd in append mode, never rotated) under OUT_LIMIT_BYTES: its
    last OUT_KEEP_BYTES stay."""
    try:
        if path.stat().st_size <= OUT_LIMIT_BYTES:
            return
        with open(path, "r+b") as fh:
            fh.seek(-OUT_KEEP_BYTES, os.SEEK_END)
            tail = fh.read()
            fh.seek(0)
            fh.truncate()
            fh.write(b"[older output trimmed]\n" + tail[tail.find(b"\n") + 1:])
    except OSError:
        pass


def _failed(stop: StopRequest, code: int, *, under_launchd: bool) -> int:
    """Exit code for a host that could not start. Under launchd, first wait (see FAILURE_PAUSE_SECONDS)."""
    if under_launchd and not stop.requested:
        stop.event.wait(FAILURE_PAUSE_SECONDS)
    return 0 if stop.requested else code


def main(argv: list[str] | None = None) -> int:
    stop = StopRequest()
    if _EARLY_STOP.is_set():
        stop.event.set()
    previous = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        return _main(stop)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def _main(stop: StopRequest) -> int:
    under_launchd = bool(os.environ.get(LAUNCHD_LABEL_ENV))
    try:
        settings = load_settings()
    except ConfigError as e:
        print(f"mydatad: {e}", file=sys.stderr, flush=True)
        return _failed(stop, 2, under_launchd=under_launchd)
    # Detached (started by `mydata start` or launchd): log to the file only; stderr would duplicate every line.
    setup_logging(settings.log_dir, settings.log_level, to_stderr=os.environ.get("MYDATA_DETACHED") != "1")
    if under_launchd:
        _trim_output(settings.log_dir / "mydatad.out")

    lock_fd = acquire_pid_lock(settings)
    if lock_fd is None:
        log(logger, logging.ERROR, "already running", pid=daemon_pid(settings))
        # Started by launchd (its LaunchAgent) while another host runs on this folder: exit cleanly, so launchd
        # does not start it again every few seconds. That host is the one running.
        return 0 if under_launchd else 1

    start_error_path(settings).unlink(missing_ok=True)  # from an earlier start; this one writes its own
    parts: list = []  # what was started, stopped again in reverse order
    try:
        code = _serve(settings, stop, parts, under_launchd=under_launchd)
    finally:
        for part in reversed(parts):
            # models before waiting for a snapshot (`mydata stop` boots out or kills after 15 seconds); backups'
            # thread is a daemon one, and a snapshot cut short leaves a .partial-* that prune removes.
            part.stop(timeout=5) if isinstance(part, BackupService) else part.stop()
        settings.pid_path.unlink(missing_ok=True)
        os.close(lock_fd)
    if stop.requested:
        code = 0  # SIGTERM (`mydata stop`, /shutdown, bootout, logout): a clean stop, whenever it came
    log(logger, logging.INFO, "stopped", code=code)
    return code


def _serve(settings: Settings, stop: StopRequest, parts: list, *, under_launchd: bool) -> int:
    """Bind the port, build the host, start its parts (appended to `parts`) and serve until stopped."""
    error_file = start_error_path(settings)
    try:
        listener = bind_listener(settings.host, settings.port)
    except OSError as e:
        log(logger, logging.ERROR, "cannot listen", host=settings.host, port=settings.port, error=str(e))
        _note_start_error(error_file, f"port {settings.port} on {settings.host} is in use or cannot be used "
                                      f"({e.strerror or e})")
        return _failed(stop, 1, under_launchd=under_launchd)
    with listener:
        if stop.requested:
            return 0
        backups = BackupService(settings.home)
        try:
            app, models, sources, mode = build(settings, backups=backups)
        except Exception as e:
            # The kind only in the host log (an error's text can quote a value); the traceback goes to stderr,
            # which is mydatad.out when detached, as an uncaught error's did.
            log(logger, logging.ERROR, "could not build the host", error=type(e).__name__)
            traceback.print_exc()
            _note_start_error(error_file, f"the host could not start ({type(e).__name__}); see mydatad.log")
            return _failed(stop, 1, under_launchd=under_launchd)
        if stop.requested:  # asked to stop while migrating: start nothing
            return 0
        log(logger, logging.INFO, "starting", version=__version__, host=settings.host, port=settings.port,
            home=str(settings.home), model=settings.model, mode=mode)
        if settings.pin_today and mode == "demo":
            log(logger, logging.WARNING, f"DEMO DATE: the host treats {settings.pin_today.isoformat()} as today, "
                "because the tools serve fake demo data. Set [dev] pin_today = false in config.toml to use the "
                "real date.", pin_today=settings.pin_today.isoformat())
        models.start()
        parts.append(models)
        sources.start()  # syncs every account now, then every 15 minutes; starts This Mac's reader if it is on
        parts.append(sources)
        backups.start()  # a snapshot now if a database changed since the last one, then every hour
        parts.insert(0, backups)  # stopped last
        trash = TrashExpiry(sources)
        trash.start()  # Recently deleted: what has been there 30 days goes for good, now and then daily
        parts.append(trash)
        server = uvicorn.Server(uvicorn.Config(app, host=settings.host, port=settings.port, log_config=None,
                                               lifespan="on", timeout_graceful_shutdown=10))
        # A signal from here until uvicorn installs its own handlers sets should_exit: it starts, then stops.
        stop.server = server
        if stop.requested:
            server.should_exit = True
        # uvicorn shuts down gracefully on SIGTERM/SIGINT, then re-raises the signal to StopRequest.
        try:
            server.run(sockets=[listener])
        except SystemExit as e:
            return int(e.code or 1)
        return 0 if server.started else 1


def _note_start_error(path, why: str) -> None:
    try:
        from .config import private_file
        path.write_text(why + "\n")
        private_file(path)
    except OSError:
        pass


if __name__ == "__main__":
    sys.exit(main())
