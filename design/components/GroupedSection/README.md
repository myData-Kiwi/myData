A grouped list whose parts are not all rows: a picker, a short form or a note sits in the same white group as the rows, with the same dividers.

- The group is the GroupedList's: `surface`, `radius-lg`, `shadow-1`, no border. A heading in the `label` style and `ink-muted` sits above it, outside.
- It holds parts, top to bottom: GroupedList rows, ActionRows and content parts. Every part is separated from the next by a full-width `line` divider, as rows are.
- A content part has `space-5` padding, like a card. It holds one thing: a picker (such as the ThemePicker with the mode control), a short form (fields above one button), a note in `body` and `ink-muted`, or a sample. Each control in it has its name above it in the `label` style, `space-2` above the control.
- Inside a content part, things stack: each control under the last, `space-5` apart, and a sample of what they change under them, at its own width. Nothing sits beside a control, so no empty patch opens up under a short control.
- At most one filled button in the whole section. Other actions are tonal or plain.
- Never a card inside it. A theme sample is an illustration of a screen, not a card.
- The three-tile-tone rule counts every row in it.
- Use a GroupedList when every part is a row; use this when one part is not.
- You provide the heading and the parts in order.
