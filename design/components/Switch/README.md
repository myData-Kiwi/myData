An on or off setting that takes effect immediately.

- Off: `surface-sunken` track with a `line-strong` border and thumb. On: `accent` track with an `on-accent` thumb.
- The switch sits at the right end of a row in a grouped list, with a title in `body-strong` and a one-sentence description in `caption` on the left.
- The whole row is the target.
- If turning it on starts something large, such as a multi-gigabyte download, the description says so.
- You provide the title, the description and the state.

## In a form

A Switch inside a form that has Save and Cancel, such as "All-day" in an event, sets a value of the thing being edited. It looks the same as the settings switch; what differs is when it applies and what the row holds.

- **It applies on Save,** not at once: Cancel, or closing the form and discarding the changes, returns it to how it was. Everything else in the form may react at once (turning "All-day" on replaces the start and end times with dates), because the form shows what Save will do.
- **The row** is a FormRow: the title in `body` and `ink`, sentence case with no full stop, and the switch at the row's end. No description unless the effect is not obvious from the title. The whole row is the target.
- **Use a Switch** for a property that is on or off ("All-day"). Use a Checkbox for "do this too" or "include this" (see Checkbox).
- **States** are the settings switch's: hover fills the row with `surface-hover`; a press dims it to 85%; keyboard focus draws the `focus` ring around the track; disabled puts the title and the switch at 45% opacity, with the reason in a `caption` line under the title in full `ink-muted`, not faded ("This event comes from an invitation and cannot be changed here."; platforms.md, "Disabled controls").
- **Keyboard:** Tab reaches it; Space toggles it. Return is left to the form.
- **Screen readers:** "All-day, switch, off". Whatever the form changes as a result is announced politely once ("Start and end are now dates").
- **Motion:** the thumb slides over `fast`, as the settings switch. Fields the change hides or shows collapse or open over `base` with the `standard` curve; with reduced motion they fade over `fast` and the form jumps to its new height.
- **Phone:** the same row, `row-height` tall, `body` at 16px.
- **Used by:** myCalendar edit event, "All-day".
