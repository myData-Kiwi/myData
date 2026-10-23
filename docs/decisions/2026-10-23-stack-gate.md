# The M1a stack gate: Flutter or SwiftUI on the Mac

History. Where it differs from CLAUDE.md or `docs/2026-10-23-plan.md`, CLAUDE.md wins.

## What was compared (2026-10-23)

myContacts' People screen, built twice against the real host on This Mac data and opened beside Contacts.app at the same window size (1280x800):

- **Flutter:** myContacts restyled to the plan's "native frame, quiet brand" (section 5): `macos_window_utils` for a full-size content view, unified toolbar and translucent sidebar; the system font and the system's colours and accent read from NSColor; Mac density; Lucide icons; a plain list; the person page (64 pt photo or initials, round actions, label and value columns).
- **SwiftUI:** a thin app (`prototypes/people-swiftui`): NavigationSplitView, `.searchable`, SF Symbols, the same sidebar, toolbar items, person page and several-selected pane, with a hand-written API client.

Both were matched on purpose (same sidebar names without counts, toolbar items where SwiftUI puts them on macOS 26, only the quick actions a contact has data for, a push button to delete). Differences left in were what each stack draws by itself: SF Symbols against Lucide, the list's selection shape and row heights, SwiftUI's sidebar toggle, and Liquid Glass (SwiftUI only, live only). Off-screen comparison sheets were made from one synthetic address book (50 invented contacts in the host's shape, three states, light and dark, 2x); they compared layout and density only, since neither stack draws glass or vibrancy off screen.

## Decision

**Flutter on every platform, the Mac included** (the owner, after the side-by-side): Flutter's app has more to it, the SwiftUI one felt basic, and SwiftUI is Mac only. The family of separate apps stays. CLAUDE.md "Decisions in force", 2026-10-23 item 8, holds the rule; the plan's top decisions, item 9, say what changes in the plan.

## Where the pieces are

- **The Flutter side** is on main: the Mac frame in `mydata_ui` (`lib/src/mac/`, the `macos` tokens in `design/tokens.json`) and myContacts' People screen, drawn in every macOS build (the build switch `MYDATA_MAC_LOOK` was removed when it was merged). The branch `stack-gate-flutter` was merged and deleted.
- **The SwiftUI prototype** is kept on the local branch `stack-gate-swiftui` only: never pushed, never merged. It holds `prototypes/people-swiftui` (the app, `build.sh`, the off-screen `snapshot.sh`, its tests) and `prototypes/stack-gate` (`make_people.py`, `people.json`, `compare.py` for the sheets, and the README with what the sheets could and could not decide). The Flutter side's sheet renderer (`app/apps/mycontacts/test/stack_gate_test.dart`, run with `MYDATA_GATE_OUT`) and that fixture were taken off main after the decision: the test stays in main's history, the fixture on that branch.
