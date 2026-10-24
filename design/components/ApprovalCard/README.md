The card that asks the user before the assistant does something that cannot be undone.

- A solid `surface` card with `radius-lg`, a 1 px `line-strong` edge (drawn over the content, so nothing moves) and the stronger `shadow-2`, so it stands above the conversation, in every theme.
- The title is a question in the `title` style: "Send this email?". A "Needs approval" chip sits beside it.
- The stored action is shown in full inside a `surface-sunken` well with `radius-md`: every argument, exactly as it will run. Nothing is summarised.
- A `caption` line names the source of the facts, with a link.
- Actions in order: the filled "Approve and ..." button naming the action, a tonal Edit, a plain Reject.
- Approve is the same in every theme: filled in the accent (in `ink`, label in `bg`, when the accent is within 25° of `danger`), or outlined where the theme's primary is an outline; never brutal, bevelled or a push button, with no drop and no bevel from the theme's elevation and at most a 1 px `line-strong` outline. Near red, Edit and Reject are in `ink` too, so only a destructive action is red.
- What follows the theme today: its colours and fonts, and also its corners (the card's `radius-lg`, Approve's `button.shape`), its elevation's `shadow-2` (a hard drop in Sticker) and Edit's secondary style (tonal, outline or underlined text). The decision record says "colours and fonts only": **open for the owner** whether corners, the card's shadow and Edit's style may follow the theme, or are pinned.
- After a decision the chip changes to "Sent" on `success-soft` or "Rejected" on `surface-sunken`, the buttons are removed and the shadow drops to `shadow-1`.
- Approval is only ever given by the user in an app. There is no "always allow" for irreversible actions.
- The content shown is sample data.
