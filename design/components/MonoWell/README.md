A well for a value the user reads exactly or copies: a token, an address, a path, an error from the host.

- `surface-sunken` with `radius-md` and no border, `space-3` padding across and `space-2` down. It sits on `surface` or `bg`, never on `surface-sunken`.
- The value is in the `mono` style in `ink`, selectable, and wraps at any character, so a long token stays inside the well.
- When the value is there to be copied, a tonal button sits beside the well, `space-2` away: a verb and the thing, "Copy token". After copying it reads "Copied" until the value changes, and screen readers hear "Copied".
- A name above it in the `label` style when the well is one of several values ("Token", "MCP URL").
- Not for sentences: an explanation goes in `body` or `caption` next to the well.
- You provide the value, its name and whether it can be copied.
