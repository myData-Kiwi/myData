A GroupedList row that shows one labelled value from a record, such as a phone number, and copies it.

- A GroupedList row with no icon tile: at least `row-height` tall, with `space-4` padding across and `space-2` down.
- The label is above the value, in `caption` and `ink-muted`. It is the label the source gives, in sentence case ("Mobile", "Work", "Home"), and a custom label exactly as written. A value with no label of its own, such as a birthday or a note, has no label line.
- The value is in `body` and `ink`, and can be selected. It wraps. An address keeps its lines in the order the locale writes them, and a note keeps its line breaks.
- **Links.** Only a web address is a link: a value whose scheme is `http` or `https`, or a bare address with no scheme that is a host name with a dot ("example.com/ava"), which opens with `https://` added. It is `accent` and underlined, is shown exactly as the source wrote it, and opens in the default browser, never inside the app. Any other scheme (`javascript:`, `file:`, `data:`, `mailto:`, an app's own scheme) or a value that does not parse as an address is plain text in `ink`: it can still be read, selected and copied, but nothing opens it. Contact cards can come from shared or imported vCards, so a value is never trusted to say what it opens.
- Phone numbers and email addresses are plain text: links to other apps come when those apps exist.
- At the right end, a plain icon button copies the value: `control-height` square, with a copy icon in `ink-muted`. Its accessible name says what it copies: "Copy mobile number", "Copy home address". After copying, its icon becomes a check and its tooltip reads "Copied" until something else is copied. Screen readers hear "Copied".
- Right-click or long-press on the row offers Copy as well.
- The copy button is the row's target, so the row has no hover fill. A link in the value is a second target, never in the same place.
- **On a contact's page:** one GroupedList per kind, headed in the `label` style, in this order: Phone, Email, Address, Birthday, Links, Notes. A kind with no values is left out entirely, with no empty row.
- **Notes** appear only when the source reads them and the note is not empty. This Mac never reads contact notes, so a contact from this Mac has no Notes group at all: no empty row and no "not available" line. A contact from iCloud can have one.
- A birthday is a date in the locale's long form, without a weekday ("12 May 1990"). When the year is not known, it is only the day and month ("12 May").
- You provide the label, the value and what kind of value it is. Whether a website is a link, and where it opens, follows from the value by the rule above; it is not passed in.
