"""Structured logging: one JSON object per line, to logs/mydatad.log and stderr.

Fields: ts, level, logger, msg, plus anything passed as `extra={"fields": {...}}`.
The token is never logged.
"""

from __future__ import annotations

import json
import logging
import logging.handlers
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


def setup_logging(log_dir: Path, level: str = "INFO", to_stderr: bool = True) -> None:
    log_dir.mkdir(parents=True, exist_ok=True)
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    fmt = JsonFormatter()
    file_handler = logging.handlers.RotatingFileHandler(log_dir / "mydatad.log", maxBytes=5_000_000, backupCount=3,
                                                        encoding="utf-8")
    file_handler.setFormatter(fmt)
    root.addHandler(file_handler)
    if to_stderr:
        err = logging.StreamHandler(sys.stderr)
        err.setFormatter(fmt)
        root.addHandler(err)
    # uvicorn's own loggers go through ours instead of its default text format.
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        lg = logging.getLogger(name)
        lg.handlers.clear()
        lg.propagate = True


def log(logger: logging.Logger, level: int, msg: str, **fields) -> None:
    logger.log(level, msg, extra={"fields": fields})
