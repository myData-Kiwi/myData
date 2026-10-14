A single-line input with a label above and optional help below.

- Label in the `label` style, sentence case, in `ink`, `space-2` above the field. Help or error in `caption`, `space-2` below it.
- `surface` fill, 1px `line-strong` border, `radius-md`, `control-height`, `space-4` padding across. Every field that looks like a TextField (Select, DatePicker, TimePicker, TokenField) uses the same measurements, so fields side by side in a form line up.
- Search fields are pills (`radius-pill`) on `surface-sunken` with no border.
- **Error:** a 2px `danger` border and help text in `danger` that says what is wrong and what a correct value looks like.
- **Focused in error:** the focus ring is `ink`, not the red `focus`: the 2px `danger` border, a 2px gap and a 2px `ink` ring. A red ring there would read as a thicker error border rather than focus (design/README.md, "Focus and danger"). Every field that looks like a TextField does the same.
- You provide the label, the value and any error text.

## Multi-line (text area)

A TextField that takes several lines, for text people write in sentences: a contact's notes, an event's description.

- **Use it** for free text that can run to a few paragraphs. **Do not use it** for a single value, even a long one (a TextField scrolls sideways), for an address (its parts are separate fields, ordered as the locale writes them), or for a mail body. **Mail compose needs its own editor** (phase 7): quoting, signatures, pasted formatting, attachments dropped into the text and bodies long enough to need their own scrolling pane are beyond a form field. That editor is a separate spec.
- **Anatomy:** as the single-line field (label above, help or error below, `surface`, 1px `line-strong`, `radius-md`), with `space-4` padding across and `space-3` down, text in `body` and `ink` that wraps.
- **Height:** it starts three lines tall and grows a line at a time as the text grows, up to twelve lines; past that it scrolls inside, with the platform's scroll bar, keeping the typing point in view. A form around it never scrolls sideways. It never shrinks below three lines, so an empty notes field still reads as a place to write.
- **Keys:** Return inserts a new line. Tab moves focus on (it never inserts a tab). ⌘Return (Control+Return elsewhere) is left to the Inspector or Dialog that holds the form, which saves with it.
- **Counter:** only when the field has a limit. None of today's uses does (vCard notes and event descriptions have none), so no counter is built now. If one ever does, the count sits at the end of the help line in `caption` and `ink-muted` ("120 of 500"); going over is allowed, so pasted text is never cut silently, and turns the field to its error state with "Notes can be 500 characters at most. This is 520."
- **States** are the single-line field's: focused (the `focus` ring around the whole box, `ink` while in error), disabled (45% opacity, with the reason as help), error (2px `danger` border, the error in place of the help).
- **Screen readers:** a multi-line text field with its label, and its help or error as its hint.
- **Motion:** the height follows the text at once, with no animation, so the typing point never moves under the user's eye.
- **Phone:** `body` at 16px, full width; it grows the same way, and the page scrolls to keep the typing point above the keyboard.
- **Copy:** the label is the thing, not an instruction ("Notes", "Description"). A placeholder is optional and says what goes there in the user's terms ("Add notes"), never an example of private data.
- **Used by:** myContacts edit contact, Notes (only for contacts myData owns or iCloud gives notes for: this Mac never reads them); myCalendar edit event, Notes.
- You provide the label, the text, any help or error text, and the limit if one exists.
