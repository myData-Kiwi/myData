# The M1a stack gate: shared fixture and comparison sheets

The same files are on both prototype branches (`stack-gate-flutter`, `stack-gate-swiftui`), so the two People
screens are rendered from the same data, in the same states, at the same scale.

- `make_people.py` writes `people.json`: 50 invented contacts (two or three per letter, a company-only card,
  a number-only card, a long name, an accented name; owned, This Mac and iCloud), each in the host's own
  shape (ContactDetailOut, built with the host's rules and checked against its model), in the host's order,
  with one synthetic photo. `states` names the three states both renderers draw: an owned contact with every
  kind of field, a followed contact with a photo, three contacts selected.
- **Flutter:** `MYDATA_GATE_OUT=DIR flutter test test/stack_gate_test.dart` in `app/apps/mycontacts`
  writes `flutter-<state>-<mode>.png` (2560x1600: 1280x800 points at 2x) in the Mac's system font.
- **SwiftUI:** `./snapshot.sh DIR` in `prototypes/people-swiftui` writes `swiftui-<state>-<mode>.png` at the
  same size, without showing a window.
- `compare.py FLUTTER_DIR SWIFTUI_DIR OUT_DIR` (Pillow: `uv run --no-project --with pillow python ...`)
  writes `compare-light.png` and `compare-dark.png`: Flutter left, SwiftUI right, one row per state, both
  scaled the same way, with the same stand-in window buttons.

## What the sheets can and cannot decide

They compare layout and density only. Neither stack can draw Liquid Glass or vibrancy off screen, so both use
the same flat stand-ins (the sidebar panel in `sidebar-background`, toolbar capsules in `toolbar-item`). Both
windows are drawn active, with the list holding the keyboard (the selection in the accent). The SwiftUI image
is a composite of what AppKit draws off screen and the contact page drawn by ImageRenderer
(`Sources/PeopleSnapshot/Snapshot.swift` lists every stand-in). The decision comes from the owner opening
both signed apps beside Contacts.app at the same window size (both open at 1280x800).

## Agreed for the gate (both prototypes)

- Sidebar: Contacts, Recently Deleted, Review; no counts; no host-status line while connected.
- Toolbar: the title "Contacts" and + over the list; Edit at the start of the contact column; the search
  field at its end (where SwiftUI's `.searchable` puts it on macOS 26; check Contacts.app live).
- List: no source badges, no count line.
- Contact page: the plan's person page (section 5): a 64 pt photo or initials on the left, the name (22 pt
  bold) and "job · company" beside it, round actions message, call, mail and map under the name (only those
  the contact has data for; labels in the secondary colour), label and value in two columns, groups 16 pt
  apart without separators, the source line at the bottom. Initials on the `kiwi-wash` fill.
- Several selected: "3 contacts selected", the names, "1 is from this Mac; change it in Contacts.", a push
  button "Delete 2 contacts".
- Compared: the People screen only. Recently Deleted and Review exist in both but differ (Merge is Flutter's).

Differences left on purpose, because each is what the stack draws by itself: SF Symbols (SwiftUI) against
Lucide (Flutter; SF Symbols in Flutter are unverified, plan 3(d)), the list's selection shape and row and
section heights, SwiftUI's sidebar toggle button, and glass (live only).
