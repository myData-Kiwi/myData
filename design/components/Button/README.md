A pill-shaped control that states the result of pressing it.

- **Filled:** `accent` with `on-accent` text. The one main action on a screen or card.
- **Tonal:** `accent-soft` with `accent` text. The usual choice for every other action; it keeps a screen calm.
- **Plain:** `accent` text with no fill, for low-emphasis actions such as Cancel.
- **Danger:** `danger` with `on-danger` text, for destructive actions only.
- **Plain danger:** `danger` text with no fill, for a destructive action on one item in a row (ActionRow). It always opens a confirmation dialog first, and that dialog confirms with the Danger button.
- **Icon only:** a separate component, IconButton (a round button with a tooltip and an accessible name). Use it only where a label does not fit.
- Shape is `radius-control`; height is `control-height`; label is `body-strong`. No borders on any variant.
- On press the button dims and scales to 97%.
- **Disabled:** Filled and Danger are drawn on `surface-sunken` with an `ink-muted` label (about 4.5:1), never faded (decided 2026-10-23; faded, the label fell to about 1.5:1). Tonal, Plain and Plain danger fade to 45%. The reason is shown as `design/platforms.md` "Disabled controls" says.
- **Focus:** the 2px `focus` ring, 2px outside the pill. On Danger and Plain danger it is `ink`, so it never merges with the red (design/README.md, "Focus and danger").
- The label is a verb and its object. Never "OK" or "Submit".
- You provide the label and the action.
