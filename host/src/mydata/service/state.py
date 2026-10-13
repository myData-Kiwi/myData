"""Small host settings the user changes from the apps (state.json), as opposed to config.toml,
which the user edits by hand: whether the assistant is switched on, the theme every app uses, the
"This Mac" source's settings and status, each source's last sync status (so it survives a restart), and the
conversation epoch (bumped on every switch between demo and real mode; see modes.py).

Several parts of the host each hold a HostState for the same file; they share one lock per file, so a
read-modify-write by one never loses another's change.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import threading
from pathlib import Path

from .appearance import DEFAULT_THEME, THEME_IDS

_LOCKS: dict[str, threading.RLock] = {}
_LOCKS_GUARD = threading.Lock()


def _lock_for(path: Path) -> threading.RLock:
    key = str(Path(path).absolute())
    with _LOCKS_GUARD:
        lock = _LOCKS.get(key)
        if lock is None:
            lock = _LOCKS[key] = threading.RLock()
        return lock


def _epoch(value) -> int:
    """A stored epoch; anything that is not a non-negative integer (a hand-edited file) reads as 0."""
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else 0


class HostState:
    def __init__(self, home: Path):
        self.path = Path(home) / "state.json"
        self._lock = _lock_for(self.path)

    def _read(self) -> dict:
        try:
            data = json.loads(self.path.read_text())
        except (FileNotFoundError, ValueError):
            return {}
        return data if isinstance(data, dict) else {}

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

    @property
    def theme_chosen(self) -> bool:
        """Whether someone has chosen a theme yet. First run offers the choice until they have."""
        return "theme" in self._read()

    def set_theme(self, theme: str) -> None:
        if theme not in THEME_IDS:
            raise ValueError(f"unknown theme {theme!r}; valid themes: {', '.join(THEME_IDS)}")
        self._update(theme=theme)

    # ---------------------------------------------------------------- conversation epoch

    @property
    def conversation_epoch(self) -> int:
        """How many times conversations have been ended by a switch between demo and real mode (0 at first)."""
        return _epoch(self._read().get("conversation_epoch"))

    def conversation_epoch_for(self, mode: str) -> int:
        """The conversation epoch for `mode`: the recorded one while the mode is the one it was recorded for,
        one more (recorded with the new mode) when the mode differs, i.e. on a switch. A file with no record
        counts as demo mode, epoch 0."""
        with self._lock:
            data = self._read()
            epoch = _epoch(data.get("conversation_epoch"))
            if data.get("conversation_mode", "demo") == mode:
                return epoch
            self._write({**data, "conversation_epoch": epoch + 1, "conversation_mode": mode})
            return epoch + 1

    # ---------------------------------------------------------------- sections (dicts under one key)

    def section(self, name: str) -> dict:
        """A copy of one top-level object in the file ({} when missing or not an object)."""
        value = self._read().get(name)
        return dict(value) if isinstance(value, dict) else {}

    def update_section(self, name: str, **changes) -> dict:
        """Merge changes into one top-level object, atomically. Returns the merged object."""
        with self._lock:
            merged = {**self.section(name), **changes}
            self._update(**{name: merged})
            return merged

    def replace_section(self, name: str, value: dict | None) -> None:
        """Replace (or with None remove) one top-level object."""
        with self._lock:
            data = self._read()
            if value is None:
                data.pop(name, None)
            else:
                data[name] = value
            self._write(data)

    def _update(self, **changes) -> None:
        """Merge changes into state.json atomically (temp file, then rename), readable only by the user."""
        with self._lock:
            self._write({**self._read(), **changes})

    def _write(self, data: dict) -> None:
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".state.")
        try:
            if not sys.platform.startswith("win"):
                os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as fh:
                json.dump(data, fh, indent=2)
                fh.flush()
                os.fsync(fh.fileno())
            os.replace(tmp, self.path)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
