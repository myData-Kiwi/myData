"""Small host settings the user changes from the apps (state.json), as opposed to config.toml,
which the user edits by hand. Currently: whether the assistant is switched on."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import threading
from pathlib import Path


class HostState:
    def __init__(self, home: Path):
        self.path = home / "state.json"
        self._lock = threading.Lock()

    def _read(self) -> dict:
        try:
            return json.loads(self.path.read_text())
        except (FileNotFoundError, ValueError):
            return {}

    @property
    def assistant_enabled(self) -> bool:
        return bool(self._read().get("assistant_enabled", True))

    def set_assistant_enabled(self, enabled: bool) -> None:
        with self._lock:
            data = {**self._read(), "assistant_enabled": bool(enabled)}
            self.path.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".state.")
            if not sys.platform.startswith("win"):
                os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as fh:
                json.dump(data, fh, indent=2)
            os.replace(tmp, self.path)
