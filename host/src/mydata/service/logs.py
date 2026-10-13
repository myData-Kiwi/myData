"""Structured logging: one JSON object per line, to logs/mydatad.log and stderr.

Fields: ts, level, logger, msg, plus anything passed as `extra={"fields": {...}}`.
The token is never logged, and neither is an account password. Logs live only in the host folder
(never inside the source checkout: setup_logging refuses it). Access log lines leave out query strings,
which can hold search words (GET /contacts?query=...); HTTP client libraries log nothing below WARNING.
"""

from __future__ import annotations

import json
import logging
import logging.handlers
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        out = {
            "ts": datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="milliseconds"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            out.update(fields)
        if record.exc_info:
            out["exc"] = self.formatException(record.exc_info)
        return json.dumps(out, ensure_ascii=False, default=str)


class LastError(logging.Handler):
    """Keeps the most recent ERROR record, for the Status screen."""

    def __init__(self):
        super().__init__(logging.ERROR)
        self.last: dict | None = None

    def emit(self, record: logging.LogRecord) -> None:
        self.last = {"at": datetime.fromtimestamp(record.created, timezone.utc).isoformat(timespec="seconds"),
                     "message": record.getMessage(), "logger": record.name}


LAST_ERROR = LastError()


class NoQueryString(logging.Filter):
    """uvicorn's access line is (client, method, path with query, http version, status): drop the query."""

    def filter(self, record: logging.LogRecord) -> bool:
        args = record.args
        if isinstance(args, tuple) and len(args) >= 3 and isinstance(args[2], str) and "?" in args[2]:
            record.args = (*args[:2], args[2].split("?", 1)[0], *args[3:])
        return True


_NO_QUERY = NoQueryString()


def open_private(path: Path, mode: str = "a", encoding: str | None = "utf-8"):
    """Open a log file for appending, creating it readable only by this user (0600). An existing file
    with looser permissions is tightened. Once an account is linked, logs can hold real requests."""
    from .config import private_file
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    private_file(path)
    if "b" in mode:
        return os.fdopen(fd, "ab")
    return os.fdopen(fd, "a", encoding=encoding)


class PrivateRotatingFileHandler(logging.handlers.RotatingFileHandler):
    """RotatingFileHandler whose files (the current one and each new one after a rollover) are 0600."""

    def _open(self):
        return open_private(Path(self.baseFilename), encoding=self.encoding)


def setup_logging(log_dir: Path, level: str = "INFO", to_stderr: bool = True) -> None:
    from .config import ensure_outside_checkout
    from .config import private_dir
    ensure_outside_checkout(log_dir, "the log folder")
    private_dir(log_dir)
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    fmt = JsonFormatter()
    file_handler = PrivateRotatingFileHandler(log_dir / "mydatad.log", maxBytes=5_000_000, backupCount=3,
                                              encoding="utf-8")
    file_handler.setFormatter(fmt)
    root.addHandler(file_handler)
    root.addHandler(LAST_ERROR)
    if to_stderr:
        err = logging.StreamHandler(sys.stderr)
        err.setFormatter(fmt)
        root.addHandler(err)
    # uvicorn's own loggers go through ours instead of its default text format.
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        lg = logging.getLogger(name)
        lg.handlers.clear()
        lg.propagate = True
    access = logging.getLogger("uvicorn.access")
    if _NO_QUERY not in access.filters:
        access.addFilter(_NO_QUERY)
    # httpx logs every request's URL at INFO; the DAV client logs what it needs itself, without them.
    for name in ("httpx", "httpcore"):
        logging.getLogger(name).setLevel(logging.WARNING)


def log(logger: logging.Logger, level: int, msg: str, **fields) -> None:
    logger.log(level, msg, extra={"fields": fields})
