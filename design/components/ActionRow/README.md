A GroupedList row that ends in one or two buttons, for acting on that one item: revoking a token, retrying what failed.

- The row is a GroupedList row: at least `row-height` tall, `space-4` padding across and `space-2` down, an optional `icon-tile`, a title in `body-strong` with a `caption` line in `ink-muted` under it.
- At the right end, an optional status chip, then one or two buttons, `space-2` apart and from the chip.
- The buttons are tonal or plain, never filled: the filled button belongs to the screen's main action.
- A destructive action (Revoke, Remove) is a plain button with `danger` text, never a fill. It always asks first: a dialog that names what will stop working ("Claude on my laptop will no longer reach your data.") and confirms with the Danger button.
- The row names the object, so a button may be a verb alone: "Revoke", "Retry".
- The buttons are the targets. The row itself is not pressable and has no hover fill, so there are never two targets in one place.
- When the row is too narrow, the caption wraps first; if the buttons still do not fit, they move under the text, aligned to its start.
- An item that cannot be acted on any more (a revoked token) keeps its row and chip and loses its buttons. Its chip is the inactive one, `surface-sunken` with `ink-muted`: red is for errors.
- You provide the row's icon, title, caption and chip, and the buttons.
