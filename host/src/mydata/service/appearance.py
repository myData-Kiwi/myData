"""The host's old themes. Until 2026-10-23 the theme was stored on the host (state.json) and applied to every
app; themes are now chosen on each device, per app (design/themes/ARCHITECTURE.md 4.1), and PUT /appearance
answers 410. GET /appearance and /status's `theme` stay for one release, so each device can seed its own choice
from what the host held (4.2); then they and `state.theme` go.

The list is frozen: these are the six colours the host could hold. Each is now the default palette of a theme
in design/themes (`plum` of Journal, ARCHITECTURE.md 4.2); tests/test_appearance.py checks that it still is.
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
