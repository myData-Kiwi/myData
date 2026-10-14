# Motion

Soft and quick. Things ease into place; nothing snaps and nothing lingers.

| Name | Value | Use |
|---|---|---|
| `fast` | 120ms | Hover, press, switch and segment state |
| `base` | 240ms | Menus, popovers, tab changes, cards appearing |
| `slow` | 380ms | Sheets, dialogs and screen transitions |
| `standard` curve | cubic-bezier(0.2, 0, 0, 1) | Movement within the screen |
| `spring` | Gentle, about 350ms, a trace of overshoot | Sheets, the segmented control's thumb, the tab pill |
| `toast-duration` | 8s | How long a Toast stays before it leaves; paused on hover, touch and focus (Toast). Decided 2026-10-14 |

## Rules

- A pressed control responds within one frame: it dims slightly and scales to 97%.
- The selected pill in a segmented control and in tabs slides to its new place with `spring`; it does not jump.
- Cards entering a screen fade and rise 8px over `base`, staggered by 30ms, at most six.
- Sheets follow the finger and settle with `spring`.
- Loading is the kiwi slice, one of the places the kiwi lives.
- With reduced motion, movement becomes a fade of `fast`, the pill jumps, and the loading slice shows without spinning.
