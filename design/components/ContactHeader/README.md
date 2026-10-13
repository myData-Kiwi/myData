The top of a contact's page: the avatar, the name, what the person does, and where the card comes from.

- It has no card. It sits on `bg` at the top of the contact pane, with the contact's fields `space-6` below it (FieldRow).
- **Over 600px:** a 96px Avatar, with the text beside it, `space-5` away and centred on it. **Under 600px:** the avatar is above the text, `space-4` apart, and everything is centred.
- The name, as the host gives it to show, in `display-lg`. It is the screen's title, so no other title sits above it. A long name wraps and is never cut short.
- Under the name, in `body` and `ink-muted`, the job title and the organisation joined by a comma ("Head of research, Example Labs"). The organisation shows alone when there is no job title. The line is left out when the card has neither, or when the name shown already is the organisation.
- A `caption` line in `ink-muted`, `space-1` lower, says where the card comes from and where to change it, because the apps only read contacts: "From this Mac. Change it in Contacts." or, for a followed iCloud account, "From the iCloud account you@example.com. Change it in your iCloud account."
- All the text can be selected. There are no buttons. Links to other apps ("Open in myMail") come later, and only when that app is installed.
- You provide the name, the job title and organisation, the source line and the Avatar.
