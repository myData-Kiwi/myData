# mydata_ui

The myData design system in Flutter. `design/` at the repo root is the source of truth; this package implements it.

- **Tokens** (`lib/src/generated/tokens.g.dart`) are generated from `design/tokens.json` and `design/themes.json` by `dart run tool/generate_tokens.dart`, which also copies the logo files from `design/assets/Logos`. `test/generated_tokens_test.dart` fails when either is stale. Token names map one to one: `accent` is `context.colors.accent` (`MyDataColors`), `space-4` is `MyDataSpace.s4`, `radius-lg` is `MyDataRadius.lg`, `body-strong` is `MyDataType.bodyStrong`.
- **`MyDataTheme(themeId:, mode:)`** gives `light`, `dark` and `themeMode` for `MaterialApp`. The theme id comes from the host and is the same in every app; the mode (light, dark, match system) is per device.
- **No literals.** No widget or app may contain a literal colour, radius or font name; `test/no_literals_test.dart` scans every app and package and fails if one appears outside the generated file.
- **Motion** (`MyDataMotion`, from `design/motion.md`) and **accessibility**: `MyDataAccessibilityScope` follows the system's reduced motion and reduced transparency (read from macOS over the `mydata/accessibility` channel in each app's Runner; Flutter has no reduced-transparency flag). The web build always uses solid bars.
- **Fonts:** Plus Jakarta Sans 700, Figtree 400 and 600, JetBrains Mono 400, with their licences (`assets/fonts/OFL-*.txt`, registered by `registerMyDataLicenses()`).
- **Tests:** goldens for every widget in Kiwi and Graphite, light and dark (`test/widgets/goldens`), using `package:mydata_testing`, which loads the bundled fonts in tests.

## Where design/ disagreed with itself (decided 2026-10-12)

The specs, previews and top-level docs were checked against each other; the owner decided these:

- **Spec against preview:** the selected ThemePicker swatch has a 2px `ink` ring and no shadow (preview). GroupedList: at most three tile colours per screen (spec; the preview's four is wrong).
- **Values the preview uses that are not tokens** (14px and 10px gaps, 13/22 text, a 14px tab label): the nearest token or type style.
- **Defaults accepted:**
  - "Needs approval" is a `warning` chip; after a decision the chip is the past tense of the action ("Sent", "Deleted") in `success`, "Rejected" in `surface-sunken` / `ink-muted`, and a failure is a `danger` "Failed" chip with the error.
  - Sheets use `surface-raised` (README), not `surface` (tokens.json).
  - The card header name is `body-strong`; cards are `space-4` apart; buttons are `space-2` apart.
  - Chips are 26px and not tappable; tabs are `control-height` (44px), not the preview's 40px.
  - The tab and segmented-control pill is a separate thumb that slides with `spring`; with reduced motion it jumps.
  - A press scales to 97% and dims to 85% at once and returns over `fast`. Cards enter with a fade and an 8px rise over `base`, 30ms apart, at most six; with reduced motion, a `fast` fade.
  - A switch row is a GroupedList row with an optional icon tile. An untinted tile is `surface-sunken` with an `ink-muted` icon. Rows that do something get hover and press fills and a focus ring.
  - Search fields are borderless pills on `surface-sunken` (spec). Path and address fields use the mono font.
  - The assistant's input bar is a glass FloatingBar. The solid fallback is `surface` with `shadow-2` and no stroke.
  - Loading: the kiwi mark on a round `paper` badge, turning; still with reduced motion. A placeholder until the kiwi slice is drawn.
  - Appearance has theme and mode only; transparency and motion follow the system; density and text size are not built. Cover (a preview with no spec) is not built.
- **Theme rule changed in `design/theming.md`:** a theme's light and dark accents were required to be "the same hue", which Kiwi and Amber miss by 8–10°; the rule is now "the same colour family; the dark value is lighter". The contrast rules all pass (`test/theme_test.dart`).

## Phase 2 foundation (decided 2026-10-14)

- **Focus on red:** every keyboard focus ring takes its colour from `FocusRing.colourOf`: `focus`, or `ink` when the control sets `danger` (`Pressable.danger`, `FocusRing.danger`). Danger and Plain danger buttons and a text field in error set it today; later red controls (destructive Menu items, danger IconButtons, invalid tokens) set the same flag.
- **Focusable but inert:** `Pressable(onPressed: null, disabledReason: ...)` keeps a disabled control in the Tab order (design/platforms.md "Disabled controls"), announced as disabled with the reason as its hint; with a `tooltip`, the tooltip adds the reason on a second line in `ink-muted` and appears at once on keyboard focus. Without a reason a disabled control leaves the Tab order, as before.
- **Hover is `surface-hover`** on every row and icon button that fills on hover: GroupedList rows, SwitchRow, ContactList rows, the calendar list, the assistant's result rows, FieldRow's copy button and MonthGrid's previous and next buttons. The sidebar and rail rows use it too; no spec names their hover, and `surface-sunken` barely shows on `surface`. A selected row's hover is `ink` at 16% over `accent-soft`, the step `surface-hover` is from `surface`.
- **Calendar list dots:** the edge rule is measured on `surface` and on the hover fill, now `surface-hover`. In dark mode `surface-hover` is lighter than `surface-sunken` was, so mid-dark colours (the red and purple in the screenshots) now carry the 1px `line-strong` edge at rest.

## Pickers and the menu bar (phase 2, 2026-10-14)

- **DatePicker, TimePicker, ColourPicker, AppMenuBar** follow design/components/DatePicker, TimePicker, ColourPicker and design/platforms.md "The menu bar on macOS". Their shared field, popover and list box are in `picker_field.dart`, which is not exported.
- **One day cell:** the DatePicker popover draws its days with `MonthGridDay`, which shares MonthGrid's number and marks painter, so the two cannot drift apart. MonthGrid's own goldens are unchanged.
- **English only:** dates are written British ("Wed 14 Oct 2026"), as `formatBirthday` and EventRow do; only the numeric order for typing follows the region (`DateFieldOrder`: month first in the US, year first in China, Japan, Korea and a few others). Month and weekday words are read in English.
- **Phones:** the picker sheets (Select, DatePicker, TimePicker) are the Sheet component's picker sheet, so typing not yet committed (a time, a custom label) is pending input: a drag resists and the scrim, back and Cancel ask "Discard changes?". The birthday's Month and Year are still a small select built on the shared list box.
- **Choices the specs leave open:** Down stops at the earliest date instead of stepping into an error; an empty time field steps from 9:00; the birthday popover grows a few pixels past seven cells when "September", "No year" and the month buttons need it, rather than cutting a value short; the field's hint says Option on Apple platforms and Alt elsewhere.
- **Not expressible in Flutter:** a field "announced as opening a dialog" (no has-popup flag), a radio's position ("5 of 8"), and a checked item in the macOS menu bar (`PlatformMenuItem` has no checked state, so View does not tick the current section). Close Window ⌘W needs the app to pass `onCloseWindow`.
- **Not tried on a Mac yet:** that ⌘Z and ⌘⌫ reach a focused text field before the menu bar (Flutter sends a key to the framework first and to the menu only when unhandled), and that a disabled Delete Contact leaves ⌘⌫ to the text.

## Forms and their holders (phase 2, 2026-10-14)

- **`FormBusy`:** while a Dialog works or an Inspector saves, every field reads it: text fields (and the TokenField, the pickers' typed fields and a custom label) are read-only, a Select, DatePicker or TimePicker does not open or step, and a Checkbox, CheckboxList or form Switch does not flip. Focus stays where it is.
- **`FormCommit` and `PendingInput`:** fields that hold typing until Return or blur (DatePicker, TimePicker, TokenField, a Select's custom label) register with their holder. The Dialog commits them before it checks and confirms, the Inspector before Save (⌘S, ⌘Return, the button), and both wait a frame for the holder's values; a commit that fails stops there with the field's error and focus on it. Cancel and `requestClose` ask "Discard changes?" when typing is pending, as for changes. Return in a date or time field commits first, closes an open popover without confirming, and stops on an error.
- **One owner per key:** under an `AppMenuBar`, a `ToastHost` showing Undo and an open `Inspector` hand ⌘Z and ⌘S to the menu bar (`AppMenuCommands`) instead of listening to the keyboard themselves, so one press never acts twice on Windows and Linux. On macOS, ⌘S with no declared Save item still reaches the inspector.
- **One inspector per opening:** `InspectorLayout` gives every opening its own state (a counter that goes up when an inspector appears or its key changes), and an `Inspector` that has closed starts afresh if the holder keeps it in the tree. Give each record's inspector its own key.
- **Toasts beside an inspector:** put the `ToastHost` around the `InspectorLayout`; the layout marks the content left in view (`ToastArea`), the toast centres on it, and its Undo is the last Tab stop after the inspector's Save.
- **Body at 16px on phones:** `PhoneType` and `AppLayout.isPhone` are the one size and the one breakpoint (600px). TextField (both kinds), Select's closed field, the form Switch, Checkbox, CheckboxList rows, TokenField and the pickers use them. Goldens at 560px and below are phone layouts and show 16px. The search field, ContactList and other phase 1 components are unchanged for now.
- **Form group headings** start where the fields start on a panel and on a phone; only on a page's `bg` (desktop) are they inset `space-2`, as GroupedSection's. FormGroup, InspectorGroupHeading and the event editor's "When" share `FormGroupHeading`.


## Editing contacts (phase 3, 2026-10-14)

- **ContactList takes a `MultiSelectController`** (design/components/MultiSelect) from 600px: ⌘-click, ⇧-click, ⌘A, ⇧ and Option with the arrows, Space and Escape, as the controller does; a run of adjacent selected rows in one letter group shares one ring and its divider takes the selection's fill. Runs do not join across letter groups, whose cards are apart. Phones have no select mode yet.
- **A row's Menu** (`menuFor`): right-click, Control-click, long-press, Shift-F10 and the context menu key on the row the keyboard is on; the items are the row's custom semantics actions. `onReturn` (Return edits the open row) and `onDelete` (the list's delete key, `AppMenuBar.listDeleteActivator`) belong to the app.
- **`ContactList.searchTrailing`**: an IconButton beside the search field ("New contact"), the list pane's title bar on desktop.
- **`AppFrame.phoneTitleActions`**: IconButtons at the end of a phone's large title ("New contact", "More actions"), since a phone has no menu bar.
- **`Inspector.failureAction`**: a Tonal button under the failure line, for a failure the user can act on from the inspector ("Reload" when the record changed elsewhere). The Inspector spec left "Changed elsewhere" to phase 3.

## Import and merge (phase 4, 2026-10-14)

- **DropZone** (design/components/DropZone) draws its states only; the page it is on takes the drop (the myData app wraps its Import page in `desktop_drop`'s `DropTarget`) and the chooser is the app's (`file_selector`), so this package stays free of platform plugins. The dragged file's name is not given before the drop on macOS, so dragging says "Drop to import".
- **DuplicatePair** (design/components/DuplicatePair) takes the versions as `PairVersion`s (built from the API's contacts and cards by `ContactPair` in `mydata_core`), and the after column as a `PairAfter` (the host's merge preview, never worked out here). "Differs" is the app's comparison (emails in lower case, phones as their digits, spacing) unless the host gives the differences (H7, Changes). Under 600px a SegmentedControl switches the columns; with more than five it stacks them.
- **CheckboxList** rows take a `trailing` control beside the target (the import's Compare, a second target, in the Tab order only on the row the keys are on) and a `below` widget (the comparison); `folded` hides the rows but keeps select all, for "New contacts (125)".
- **AppSection.count** shows a number after a sidebar label in `caption` and `ink-muted` (myContacts' Review), never a badge; screen readers hear "Review, 4".
- **Tile colours:** the untinted `surface-sunken` tile no longer counts toward a screen's three: ImportFlow's summary uses accent, info and warning, "every other row is neutral" (decided 2026-10-14), which the earlier count of four tones refused.

## The Mac frame (M1a stack gate, 2026-10-23)

Built for the side-by-side of myContacts' People screen with Contacts.app (docs/2026-10-23-plan.md, sections 3(b), 3(d) and 5). Only myContacts uses it so far; the other apps keep the branded frame.

- **The switch:** `MacLook` is on in a macOS build unless `--dart-define=MYDATA_MAC_LOOK=false`; `MacLook.of(context)` is true under a `MacTheme` wider than a phone. `MacTheme.data` maps the branded tokens onto the system's colours (`MyDataMacColors`, read from NSColor over `mydata/system_colors` by `MacSystemColorsScope`, accent included) and builds the text theme afresh in the system font: applying a family to the branded styles would keep mydata_ui's package and name a font that does not exist.
- **Tokens:** `design/tokens.json` "macos" (fonts, colours, type, sizes, radii), generated into `MyDataMac*`. The colours are fallbacks; on a Mac the system's own are used.
- **Widgets:** `MacSourceList` (sidebar), `MacToolbar`, `MacToolbarButton`, `MacSearchField`, `MacRecordHeader`, `MacQuickAction`, `MacFieldTable`; `ContactListStyle.plain`. Shared widgets have a Mac branch: Button becomes a push button, MultiSelectList and GroupedList plain lists, and EmptyState, StatusPanel, Notice, MultiSelectSummary and DuplicatePair take their text through `context.type`. The Inspector and its fields, Select and the dialogs are still branded.
- **Window:** the app's (`macos_window_utils`, `MacChrome`): this package has no platform plugins.
- **Icons:** Lucide (ISC), cut down by `tool/subset_lucide.sh` to `MacIcons`, in place of SF Symbols.
- **macOS 26 shapes, for the gate:** the sidebar is a floating panel (`sidebar-margin`, `sidebar` radius) with no divider beside it; toolbar items are `toolbar-item-height` circles and capsules on `toolbar-item`, a flat stand-in for Liquid Glass (Flutter cannot draw glass, flutter#170310), with no hairline under the band. The sizes are those SwiftUI's NavigationSplitView draws on macOS 26 (the SwiftUI prototype's renderer measured them).
- **Tests:** committed Mac-frame screenshots (`macMatrix`, light and dark) use the bundled Figtree under the system font's names (`loadMacFonts()`), so no rasterised SF Pro is in the repo. `loadMacFonts(systemFont: true)` reads the Mac's own SF Pro from `/System/Library/Fonts/SFNS.ttf` (never copied) for the stack gate's screenshots, which go outside the checkout (`MYDATA_GATE_OUT`, myContacts' `stack_gate_test.dart`).
- **Unverified until the app runs:** whether `.AppleSystemUIFont` resolves to SF Pro in the built app (a wrong family falls back silently to another font); check it in the live window.
