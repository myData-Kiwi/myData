A rounded white group of rows, each with an icon tile, a title, a secondary line and something at the right end.

- The group is `surface` with `radius-lg` and `shadow-1`, with no border. Rows are separated by a `line` divider.
- A small heading in the `label` style and `ink-muted` sits above the group, outside it.
- Each row is at least `row-height` tall: an `icon-tile` on the left, a title in `body-strong` with a `caption` line under it, and at the right end a status chip, a switch, a value or a chevron.
- **Selected:** the row fill becomes `accent-soft`.
- **Hover** (only on a row that does something when pressed): the row fills with `surface-hover` over `fast`. Hover is never selection.
- Tile colours come from `accent-soft`, the status `-soft` fills or `surface-sunken`. Use at most three on one screen, and give the same kind of thing the same colour everywhere.
- This is the main way to show settings, devices, accounts and any short list of records.
- You provide the heading and the rows. The rows shown are examples.
