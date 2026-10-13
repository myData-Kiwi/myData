A round picture of a person: their photo when the host has one, otherwise their initials.

- A circle (`radius-pill`) in two sizes: `icon-tile` (36px) in list rows, where it takes the icon tile's place, and 96px at the top of a contact's page (ContactHeader).
- **Photo:** the contact's photo from the host, cropped to fill the circle and centred, with no border or ring. It is fetched only when the contact has one. Until it arrives, and when it cannot be read, the initials show.
- **Initials:** a `kiwi-wash` fill with up to two letters in `ink`, `body-strong` at 36px and `display-lg` at 96px. They are the first letters of the given and family names, in the order the name is shown, or one letter for a single name. Names in scripts without initials (Chinese, Japanese, Korean) use their first character. An organisation's card uses the organisation's name ("Example Labs" gives "EL").
- **No letters to use** (the name shown is a phone number or an email address): a person outline icon in `ink-muted`, at `icon` size at 36px and twice that at 96px.
- Every contact gets the same `kiwi-wash` fill. There is no colour per person: a hue for each contact would be a second colour system beside the theme, and some hues would fail contrast with `ink`.
- It is not an icon tile and does not count toward the three tile tones on a screen.
- In a list row it takes the icon tile's place, beside the name. The contact list itself (its groups, search, rows, selection and keyboard) is specified in ContactList.
- Next to the name it is decoration and has no accessible name. On its own, it is named with the contact's name. It is never a target by itself: a row or header that holds it is.
- A photo appears with a `fast` fade. With reduced motion it simply appears.
- You provide the name to show, the given and family names, the size and the photo, if there is one.
