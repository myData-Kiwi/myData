"""Small host settings the user changes from the apps (state.json), as opposed to config.toml,
which the user edits by hand. Currently: whether the assistant is switched on, and the theme every app uses."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import threading
from pathlib import Path

from .appearance import DEFAULT_THEME, THEME_IDS


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
        self._update(assistant_enabled=bool(enabled))

    @property
    def theme(self) -> str:
        """The theme every app uses. An unknown value (a hand-edited file) reads as the default."""
        theme = self._read().get("theme", DEFAULT_THEME)
        return theme if theme in THEME_IDS else DEFAULT_THEME

    def set_theme(self, theme: str) -> None:
        if theme not in THEME_IDS:
            raise ValueError(f"unknown theme {theme!r}; valid themes: {', '.join(THEME_IDS)}")
        self._update(theme=theme)

    def _update(self, **changes) -> None:
        """Merge changes into state.json atomically (temp file, then rename), readable only by the user."""
        with self._lock:
            data = {**self._read(), **changes}
            self.path.parent.mkdir(parents=True, exist_ok=True)
            fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".state.")
            if not sys.platform.startswith("win"):
                os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as fh:
                json.dump(data, fh, indent=2)
            os.replace(tmp, self.path)
