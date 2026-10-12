"""The themes every app can use. The theme is stored on the host (state.json) and applies to every app;
light or dark mode is per device and not stored here.

design/themes.json is the source of truth for ids, names, order and the default; tests/test_appearance.py
fails if this list drifts from it. The colours themselves live only in the design files and the apps.
"""

from __future__ import annotations

THEMES: tuple[tuple[str, str], ...] = (
    ("kiwi", "Kiwi"),
    ("graphite", "Graphite"),
    ("dusk", "Dusk"),
    ("plum", "Plum"),
    ("rose", "Rose"),
    ("amber", "Amber"),
)
DEFAULT_THEME = "kiwi"

THEME_IDS: tuple[str, ...] = tuple(t for t, _ in THEMES)
