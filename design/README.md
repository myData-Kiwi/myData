# myData

The design system for the myData family of apps: myData, myAssistant, myPhotos, myMail, myCalendar, myContacts and the apps that follow. Soft, airy and modern, with quiet grey grounds and one theme colour, kiwi green by default.

Tagline: Your data, kept at home.

## The idea: soft grounds, one colour

A light grey room with white furniture in it.

- **The ground is soft grey**, never pure white. Content sits on white cards that lift off it with a faint shadow. There are almost no borders.
- **Everything is rounded.** Cards have large corners; buttons, chips and switches are pills.
- **One theme colour.** Kiwi green by default; the user can pick another theme, including Graphite, which has no colour at all. The colour marks the primary action, the current place and anything switched on. Its pale tint does most of the work: tonal buttons, selected rows, icon tiles.
- **Small tinted tiles carry the personality.** Each row and stat has an icon on a softly coloured rounded tile. They give a screen rhythm and colour without filling it with colour.
- **Big, confident titles.** A screen opens with a large bold title in Plus Jakarta Sans.

The kiwi stays in the logo, the app icon, empty screens and the loading slice. Inside the apps its green appears in one place: the dot beside the host's status.

## Principles

1. **Calm, not empty.** Quiet does not mean plain. Depth, rounded shapes, tinted tiles and strong titles give it character.
2. **The user's content is the loudest thing on screen.**
3. **Air over lines.** Separate things with space and a soft lift. Use a divider only inside a grouped list.
4. **Say what will happen.** A button states its result; anything irreversible shows exactly what it will do first.
5. **Works without AI.** Every screen is complete with the assistant off.
6. **One family.** The same controls, places and words in every app.

## Voice

Warm and plain.

- Name things by what people recognise: "your host", "this Mac", "your phone".
- Buttons are verbs that state the result: "Approve and send", "Add a device".
- Errors say what went wrong and what to do next.
- Sentence case everywhere, including labels. No uppercase labels, no exclamation marks.
- App names are written exactly: myData, myPhotos, myAssistant.

## Colour

| Role | Tokens |
|---|---|
| Grounds | `bg` (soft grey), `surface` (cards), `surface-raised` (menus, sheets), `surface-sunken` (tracks, wells) |
| Text | `ink`, `ink-muted` |
| Edges | `line` inside grouped lists, `line-strong` for input borders |
| The calm colour | `accent` with `on-accent`, and `accent-soft` for tonal fills |
| Status | `success`, `warning`, `danger`, `info`, each with a `-soft` fill for chips and tiles |
| Identity | `brand`, for the host status dot only |
| Floating bars | `glass-fill`, `glass-stroke`, `blur-glass`, `shadow-glass` |
| Artwork | `kiwi-wash`, `skin`, `cream`, `paper` |

Rules:

- One filled `accent` button per screen or card. Other actions are tonal (`accent-soft` with `accent` text) or plain.
- Status is a tonal chip: the `-soft` fill with text in the matching status colour, always with a word.
- Icon tiles use `accent-soft`, a status `-soft` fill, or `surface-sunken`. Use at most three different tile colours on one screen.
- Never put a card on a card. Never give a card a border and a shadow together.
- Links are `accent` and underlined, because the Graphite theme's accent is close to the text colour.
- The focus ring uses `focus`, a warm colour, so it shows beside every theme's accent.

## Type

- **Plus Jakarta Sans** (`display`) at weight 700 for titles and large figures.
- **Figtree** (`body`) for everything else. 
- **JetBrains Mono** (`mono`) for paths, addresses and copied values.

Styles: `display-xl`, `display-lg`, `title`, `heading`, `body`, `body-strong`, `caption`, `label`, `mono`. Body is 15px on desktop and 16px on phones.

## Shape, depth and space

- Cards and grouped lists: `radius-lg` (20px), `surface`, `shadow-1`, no border.
- Buttons: `radius-control` (a pill). Chips, segmented controls and switches: `radius-pill`.
- Inputs: `radius-md` (14px) with a `line-strong` border.
- Icon tiles and photo tiles: `radius-sm` (10px).
- Sheets, dialogs and floating bars: `radius-xl` (28px).
- Cards have `space-5` padding and `space-4` between them. Screens have `space-8` padding on desktop.
- Controls are `control-height` (44px). Rows are `row-height` (56px).
- In dark mode the shadow is barely visible; cards separate from the ground by being lighter than it.

## Floating bars

A phone tab bar, a toolbar over a photo grid and the assistant's input bar float above content as glass: `glass-fill` over a `blur-glass` blur, with `glass-stroke` and `shadow-glass`. Nothing else is glass. With reduced transparency, on the web and on slow devices, the bar is `surface` with `shadow-2` and no blur.

## Icons and illustration

- Icons are 20px outlines with a 1.75px rounded stroke.
- In a list or stat, the icon sits on a 36px tile (`icon-tile`) with `radius-sm`. The icon takes the strong colour of the tile's tint: `accent` on `accent-soft`, `success` on `success-soft`.
- An icon alone always has an accessible name.
- Illustration is the kiwi, in first-run, empty screens and loading only.

The icon set has not been drawn. The previews use simple placeholder outlines.

## Accessibility

- Text contrast at least 4.5:1 in both themes; control borders, icons and focus rings at least 3:1.
- Every interactive element has a visible focus ring.
- Every target is at least 44px.
- Status is never colour alone: a chip always carries a word.
- Reduced motion replaces movement with a short fade. Reduced transparency removes glass.

## Themes

The values in `tokens.json` are the Kiwi theme, the default. A theme replaces `accent`, `on-accent` and `accent-soft` only. The six themes are in the Theming section and in `themes.json`.

## For implementers

- Build `MyDataTheme` from a theme id and a mode, reading `tokens.json` and `themes.json`. No widget reads a theme or a literal colour directly.
- Token names map one to one to the Flutter package: `accent` becomes `MyDataColors.accent`, `space-4` becomes `MyDataSpace.s4`.
- Components here are specifications with HTML previews; the Flutter widgets are the implementation.
- `tokens.json` is the source of truth for values.
