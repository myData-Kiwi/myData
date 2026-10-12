"""mydatad: the host service. Runs in the foreground; `mydata start` runs it in the background.

On start: read config.toml (create it with defaults), create the token on first start, set up
structured logging, refuse to run twice, start getting the model ready in the background, and
serve the API on the loopback address from the config. On SIGTERM/SIGINT: finish open requests,
stop Ollama if the host started it, and remove the pid file.
"""

from __future__ import annotations

import logging
import os
import signal
import sys

import uvicorn

from .. import __version__
from ..tools import default_registry
from .api import create_app
from .assistant import Assistant
from .config import ConfigError, Settings, load_settings
from .logs import log, setup_logging
from .model import ModelManager
from .state import HostState
from .auth import AgentStore, Authenticator, ensure_app_tokens

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


def acquire_pid_lock(settings: Settings) -> int | None:
    """Hold an exclusive lock on the pid file for the life of the process. The kernel releases it on any
    exit, including a crash, so a held lock always means a live mydatad. Returns the fd, or None if taken."""
    settings.home.mkdir(parents=True, exist_ok=True)
    fd = os.open(settings.pid_path, os.O_RDWR | os.O_CREAT, 0o600)
    if not _lock(fd):
        os.close(fd)
        return None
    os.ftruncate(fd, 0)
    os.write(fd, str(os.getpid()).encode())
    return fd


def daemon_pid(settings: Settings) -> int | None:
    """The pid of the running mydatad, or None. A pid file nobody holds the lock on is stale and removed,
    so a leftover pid can never point the mydata command at an unrelated process."""
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


def build(settings: Settings):
    legacy = settings.home / "token"  # phase 1 had one shared token; it is replaced by per-app tokens
    if legacy.exists():
        legacy.unlink()
        log(logger, logging.INFO, "removed the old shared token; apps now have their own", path=str(legacy))
    auth = Authenticator(ensure_app_tokens(settings.home), AgentStore(settings.home))
    registry = default_registry(today=settings.today)
    state = HostState(settings.home)
    models = ModelManager(settings, enabled=state.assistant_enabled)
    assistant = Assistant(settings, registry, today=settings.today)
    stop = lambda: os.kill(os.getpid(), signal.SIGTERM)  # the same clean shutdown as `mydata stop`
    return create_app(auth, registry, models, assistant, state=state, shutdown=stop), models


def main(argv: list[str] | None = None) -> int:
    try:
        settings = load_settings()
    except ConfigError as e:
        print(f"mydatad: {e}", file=sys.stderr)
        return 2
    # Detached (started by `mydata start`): log to the file only; stderr would duplicate every line.
    setup_logging(settings.log_dir, settings.log_level, to_stderr=os.environ.get("MYDATA_DETACHED") != "1")

    lock_fd = acquire_pid_lock(settings)
    if lock_fd is None:
        log(logger, logging.ERROR, "already running", pid=daemon_pid(settings))
        return 1

    app, models = build(settings)
    log(logger, logging.INFO, "starting", version=__version__, host=settings.host, port=settings.port,
        home=str(settings.home), model=settings.model)
    if settings.pin_today:
        log(logger, logging.WARNING, f"DEMO DATE: the host treats {settings.pin_today.isoformat()} as today, because the "
            "tools serve fake demo data. Set [dev] pin_today = false in config.toml to use the real date.",
            pin_today=settings.pin_today.isoformat())
    models.start()
    # uvicorn shuts down gracefully on SIGTERM/SIGINT, then re-raises the signal to the handler that was
    # installed before it. With the default handler that kills the process before the cleanup below runs,
    # so install a harmless one: shutdown still happens, and Ollama and the pid file are cleaned up.
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: None)
    server = uvicorn.Server(uvicorn.Config(app, host=settings.host, port=settings.port, log_config=None,
                                           lifespan="on", timeout_graceful_shutdown=10))
    code = 0
    try:
        server.run()
        if not server.started:  # e.g. the port is taken
            code = 1
    except SystemExit as e:
        code = int(e.code or 1)
    finally:
        models.stop()
        settings.pid_path.unlink(missing_ok=True)
        os.close(lock_fd)
        log(logger, logging.INFO, "stopped", code=code)
    return code


if __name__ == "__main__":
    sys.exit(main())
