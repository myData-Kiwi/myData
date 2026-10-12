The card that asks the user before the assistant does something that cannot be undone.

- A `surface` card with `radius-lg` and the stronger `shadow-2`, so it stands above the conversation.
- The title is a question in the `title` style: "Send this email?". A "Needs approval" chip sits beside it.
- The stored action is shown in full inside a `surface-sunken` well with `radius-md`: every argument, exactly as it will run. Nothing is summarised.
- A `caption` line names the source of the facts, with a link.
- Actions in order: the filled "Approve and ..." button naming the action, a tonal Edit, a plain Reject.
- After a decision the chip changes to "Sent" on `success-soft` or "Rejected" on `surface-sunken`, the buttons are removed and the shadow drops to `shadow-1`.
- Approval is only ever given by the user in an app. There is no "always allow" for irreversible actions.
- The content shown is sample data.
