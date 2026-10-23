# myData

The design system for the myData family of apps: myData, myAssistant, myPhotos, myMail, myCalendar, myContacts and the apps that follow.

**A theme sets the whole look, per app and per device** (decided 2026-10-23; `theming.md`, `themes/`). The default theme is **System**: on macOS the Mac shell, with the system's window, toolbar, translucent sidebar, font, colours, accent, focus ring and density (the `macos` tokens in `tokens.json`; `platforms.md`). A drawn theme (Kiwi, Graphite, Dusk, Plum, Rose, Amber) draws everything inside the platform's window by its own rules (`themes/<slug>/RULES.md`). Ours in every theme: the kiwi, app icons, avatars, person pages, empty states, the approval card's structure, `data-*` colours and wording.

**What holds in every theme:** Principles, Voice, the colour roles and the rules marked "every theme" below, Focus and danger, Accessibility, and `theming.md`'s "Rules every theme keeps". **What is Kiwi's:** the idea below, Kiwi's colour rules, Type, Shape, depth and space, Floating bars and the icon tiles. Kiwi is also what System draws on Windows, Linux and the web until their own passes.

Tagline: Your data, kept at home.

## Kiwi: soft grounds, one colour

Until 2026-10-23 this was the look of every app; it is now the Kiwi theme's language (`themes/kiwi/RULES.md`).

A light grey room with white furniture in it.

- **The ground is soft grey**, never pure white. Content sits on white cards that lift off it with a faint shadow. There are almost no borders.
- **Everything is rounded.** Cards have large corners; buttons, chips and switches are pills.
- **One theme colour.** Kiwi green by default; the user can pick another theme, including Graphite, which has no colour at all. The colour marks the primary action, the current place and anything switched on. Its pale tint does most of the work: tonal buttons, selected rows, icon tiles.
- **Small tinted tiles carry the personality.** Each row and stat has an icon on a softly coloured rounded tile. They give a screen rhythm and colour without filling it with colour.
- **Big, confident titles.** A screen opens with a large bold title in Plus Jakarta Sans.

The kiwi stays in the logo, the app icon, empty screens and the loading slice. Inside the apps its green appears in one place: the dot beside the host's status.

## Principles

1. **Calm, not empty.** Quiet does not mean plain: each theme gives it character in its own way (Kiwi with depth, rounded shapes, tinted tiles and strong titles).
2. **The user's content is the loudest thing on screen.**
3. **One way to separate things per theme.** Kiwi uses air over lines: space and a soft lift, a divider only inside a grouped list. Other themes say theirs in their RULES.md (Plum: ink rules; Graphite: hairlines).
4. **Say what will happen.** A button states its result; anything irreversible shows exactly what it will do first.
5. **Works without AI.** Every screen is complete with the assistant off.
6. **One family.** The same controls, places and words in every app.

## Voice

Warm and plain.

- Name things by what people recognise: "your host", "this Mac", "your phone".
- Buttons are verbs that state the result: "Approve and send", "Add a device".
- Errors say what went wrong and what to do next.
- Sentence case everywhere in what we write, including labels; no exclamation marks. A theme may set `label` and `caption` in upper case (Kiwi does not), never on text that holds a name (`theming.md`).
- App names are written exactly: myData, myPhotos, myAssistant.

## Colour

| Role | Tokens |
|---|---|
| Grounds | `bg` (soft grey), `surface` (cards), `surface-raised` (menus, sheets), `surface-sunken` (tracks, wells), `surface-hover` (the hover and highlight fill) |
| Text | `ink`, `ink-muted` |
| Edges | `line` inside grouped lists, `line-strong` for input borders |
| The calm colour | `accent` with `on-accent`, and `accent-soft` for tonal fills |
| Status | `success`, `warning`, `danger`, `info`, each with a `-soft` fill for chips and tiles |
| Identity | `brand`, for the host status dot only |
| Floating bars | `glass-fill`, `glass-stroke`, `blur-glass`, `shadow-glass` |
| Artwork | `kiwi-wash`, `skin`, `cream`, `paper` |
| Data | `data-red`, `data-orange`, `data-yellow`, `data-green`, `data-blue`, `data-purple`, `data-brown`, `data-grey`: the palette for calendars myData owns (ColourPicker). Data colours, never control colours (DataColour) |

Each theme gives these roles their values (`themes/<slug>/theme.json`; 43 roles, the rest derived: `themes/ARCHITECTURE.md` 1.3).

Rules in every theme:

- Status is a tonal chip: the `-soft` fill with text in the matching status colour, always with a word.
- Links are underlined, so a theme whose accent is close to the text (Graphite) still shows them.
- `data-*` colours are data, never control colours.

Kiwi's rules:

- One filled `accent` button per screen or card. Other actions are tonal (`accent-soft` with `accent` text) or plain.
- Icon tiles use `accent-soft`, a status `-soft` fill, or `surface-sunken`. Use at most three different tile colours on one screen.
- Never put a card on a card. Never give a card a border and a shadow together.
- The focus ring uses `focus`, a warm colour, so it shows beside every theme's accent. On anything already red it is `ink` (below).

## Focus and danger

Every drawn theme: its own `focus` colour (Rose's is blue), with the `ink` rule below and a two-tone ring where it sits on a fill (`themes/ARCHITECTURE.md` 2.3). Under System on macOS the focus ring is the system's (`focus-ring` in `tokens.json` "macos", read from the system) on every control, red ones included; the values below are Kiwi's.

`focus` and `danger` have the same values (#B3261E light, #F2867E dark). The red ring shows beside every theme's accent and on every ground (5.2 to 6.5:1 in light mode, 5.4 to 8.0:1 in dark, on `bg`, the surfaces and the soft fills), but next to anything red it cannot be told apart from the red. So:

- **The focus ring is `focus` (red) everywhere, except on something already red, where it is `ink`.** It keeps its shape: 2px, 2px outside the element (or inside it, where the component draws it inside), with the ground showing in the gap. Only its colour changes.
- **"Already red"** is anything drawn in `danger` or `danger-soft`:
  - a field in error, with its 2px `danger` border (TextField, FormRow, Select, DatePicker, TimePicker, TokenField);
  - a Danger button (the destructive button in a Dialog, and any other);
  - a destructive Menu item (red label, `danger-soft` fill);
  - a danger-tone IconButton (red icon, `danger-soft` hover);
  - an invalid token in a TokenField (`danger-soft` pill).
- **Why `ink`:** it reaches 3:1 on every ground, differs from `danger` in lightness as well as hue (2.7:1 in light mode, 2.1:1 in dark), and needs no new token. A Plain danger button (red text, no fill) is red too, and takes the `ink` ring by the same rule.
- **For implementers:** the focus ring takes its colour from one place, with a flag the component sets when it is in its red state; no widget picks `ink` or `focus` by itself.
- Decided 2026-10-14: keep the red `focus` ring, and draw it in `ink` on red elements (the alternatives were a new `focus` hue, or a second inner `ink` line).

## Type (Kiwi)

Each theme sets its own fonts from the catalogue (`themes/ARCHITECTURE.md` 1.5).

- **Plus Jakarta Sans** (`display`) at weight 700 for titles and large figures.
- **Figtree** (`body`) for everything else. 
- **JetBrains Mono** (`mono`) for paths, addresses and copied values.

Styles: `display-xl`, `display-lg`, `title`, `heading`, `body`, `body-strong`, `caption`, `label`, `mono`. Body is 15px on desktop and 16px on phones.

On macOS the apps use the system font at the Mac's sizes instead (`macos` type tokens: `body` 13 pt, `callout`, `caption`, `title`, a record's `name` at 22 pt); Plus Jakarta Sans and Figtree are Kiwi's.

## Shape, depth and space (Kiwi)

Other themes set their own corners, radii, density, borders and elevation (`themes/<slug>/RULES.md`), above the platform floors.

- Cards and grouped lists: `radius-lg` (20px), `surface`, `shadow-1`, no border.
- Buttons: `radius-control` (a pill). Chips, segmented controls and switches: `radius-pill`.
- Inputs: `radius-md` (14px) with a `line-strong` border.
- Icon tiles and photo tiles: `radius-sm` (10px). The checkbox's box: `radius-xs` (6px).
- Sheets, dialogs and floating bars: `radius-xl` (28px).
- Cards have `space-5` padding and `space-4` between them. Screens have `space-8` padding on desktop.
- Controls are `control-height` (44px). Rows are `row-height` (56px).
- A Dialog is `dialog-width` (520px) wide and an Inspector `inspector-width` (440px), each narrower when the window is.
- In dark mode the shadow is barely visible; cards separate from the ground by being lighter than it.

## Floating bars (Kiwi)

A phone tab bar, a toolbar over a photo grid and the assistant's input bar float above content as glass: `glass-fill` over a `blur-glass` blur, with `glass-stroke` and `shadow-glass`. Nothing else is glass. With reduced transparency, on the web and on slow devices, the bar is `surface` with `shadow-2` and no blur.

## Icons and illustration

- Icons are 20px outlines with a 1.75px rounded stroke.
- In a list or stat, the icon sits on a 36px tile (`icon-tile`) with `radius-sm`. The icon takes the strong colour of the tile's tint: `accent` on `accent-soft`, `success` on `success-soft`.
- An icon alone always has an accessible name.
- Illustration is the kiwi, in first-run, empty screens and loading only.

Those are Kiwi's sizes. Under System on macOS the icons are Lucide (`MacIcons` in `mydata_ui`, one set for every app) at 16px; the branded frame still uses Material outline icons. A theme picks its own set and weight (from phase 3, through semantic icon ids). Android moves to Material Symbols in its own pass.

## Accessibility

- Text contrast at least 4.5:1 in both themes; control borders, icons and focus rings at least 3:1.
- Every interactive element has a visible focus ring.
- Every target is at least 44px on phones and in the branded frame; on macOS the system's sizes (28 pt controls, 20 pt at least).
- Status is never colour alone: a chip always carries a word.
- Reduced motion replaces movement with a short fade. Reduced transparency removes glass.

## Themes

System is the default; the built-ins are in `themes/` and `theming.md`. Until phase 3 the code reads today's values: `tokens.json` is Kiwi, and `themes.json` gives the other five their `accent`, `on-accent` and `accent-soft`. From phase 3 the theme files are the source and `themes.json` goes.

## For implementers

- Today `MyDataTheme` is built from a theme id and a mode, reading `tokens.json` and `themes.json`. From phase 1 it is built from a resolved look (`MyDataLook`, `themes/ARCHITECTURE.md` 3.1), read by widgets through `context`. No widget reads a theme file or a literal colour directly, and no app passes style overrides to a widget.
- Token names map one to one to the Flutter package: `accent` becomes `MyDataColors.accent`, `space-4` becomes `MyDataSpace.s4` (phase 1's codemod makes it `context.space(4)`).
- Components here are specifications with HTML previews; the Flutter widgets are the implementation.
- `tokens.json` is the source of truth for values a theme does not set, and until phase 3 for Kiwi's; from phase 3 a theme's values come from its `themes/<slug>/theme.json`.
