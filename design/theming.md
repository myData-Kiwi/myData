# Theming

A theme changes how the whole app looks: type, shape, density, borders, depth, icons, motion, how each component is drawn, and colour. A theme is named after its design language (Journal, not Plum) and is a **style plus palettes**: colour is a separate choice inside the theme, from 2 to 4 palettes named by colour (Journal in Plum, Ink blue or Forest). Each app has its own theme and palette, chosen on each device. System is the default. Decided 2026-10-23 (`docs/decisions/2026-10-23-themes.md`); the full design is `themes/ARCHITECTURE.md`, the format `themes/theme.schema.json`.

**Phases 1 to 3 are built (2026-10-24):** each theme's type, fonts and icons, its design rules (shape, borders, depth, density floors, motion, the shape-following focus ring and the disabled filled button) and every component variant (buttons, selection, lists, fields, avatars, tabs, the month and today, data colours, chat, sidebar, toolbar, icon tiles, and the window ground and bars as phase 3 allows) are drawn by the widgets, and the six built-ins are full looks generated from `themes/<slug>/theme.json`, each in its three palettes (`themes.json` is gone). A device that had Kiwi in an old colour moves to that colour's theme in that palette (Kiwi in Plum becomes Journal in Plum), and myData's Appearance says so once. Phase 4's first two batches are built (2026-10-24): High Contrast, E-ink and Large, the accessibility themes, then Terminal, Notebook, Brutalist and Retro Desktop, each in three palettes; the other six new built-ins and phases 5 to 7 are not built. Widgets read the look through their context (`MyDataLook`); each app has its own theme and palette on each device (`ThemeController`), chosen in its gallery (View > Theme…) or in myData's Settings > Appearance; the host's `/appearance` is retired. On a Mac a drawn theme keeps the Mac window and its skeleton and draws inside it: the shared widgets in the theme's full look, and the Mac widgets (source list, toolbar items, record, forms, the plain list, month view) in its type, density, corners, selection and colours (`context.macLook`); a device moved from Kiwi in an old colour hears so once in each app's window too. Component specs in `components/` say "Kiwi and Hairline" for the two looks every widget golden is made in.

## Choosing a theme

| Setting | Options | Default | Where it applies |
|---|---|---|---|
| Theme and palette, per app | Any built-in and one of its palettes (later, any custom theme) | System (whose colour is the system accent) | That app, on this device |
| Use everywhere | Sets one theme and palette for every app, including apps installed later, and clears each app's own choice (with Undo) | System | Every app on this device |
| Mode | Light, Dark, Match system | Match system | Every app on this device |
| Transparency, motion, text size, increase contrast | Follow the system | The system's | Every app on this device |

- An app uses its own choice, else the "everywhere" choice, else System. A choice is a theme and a palette; without a palette, or when the theme no longer has it, the theme's default palette. Choices live in `<home>/device/settings.json` and are **never synced**: a second Mac starts on System.
- **In every app:** View > Theme… ⌃⌘T (⌥⌘T is Show or Hide Toolbar in Apple's apps; macOS only) opens the gallery: live cards of that app's main screen in light and dark; arrow keys preview the theme on the whole window, the selected theme's palettes sit below the grid as named swatches (Tab, then arrows, preview each), Return or "Use in myContacts" keeps the theme and palette, "Use everywhere" applies both to every app, Escape puts the previous ones back. On a phone: More actions > Theme….
- **In myData:** Settings > Appearance has Mode, Everywhere, one row per app (all four, installed or not, since a choice can be made before an app is installed; "Same as everywhere" or its own theme and palette, such as "Journal, Ink blue", Change… and Reset) and, later, the library.
- **Phones** get one theme per app and no Use everywhere until native phone apps exist (separate apps cannot share a folder without App Groups).
- First launch does not ask: System is the default.

## The built-in themes

| Theme | Character | Palettes (default first) | Rules |
|---|---|---|---|
| System | Looks like the rest of your computer: the Mac shell on macOS. On Windows, Linux and the web, Kiwi in the platform's font until that platform's own pass; Android waits for its Material 3 pass. The picker says so | None: the system accent | `themes/system/` |
| Kiwi | The house style: soft grey grounds, white cards, continuous corners, pills, tinted tiles, one accent | Kiwi, Sky, Violet | `themes/kiwi/` |
| Hairline (was Graphite) | Precise and quiet: hairlines, small corners, an ink bar on the selected row | Graphite, Slate, Cobalt | `themes/hairline/` |
| Frosted (was Dusk) | A sky behind frosted glass, slow motion | Dusk, Aurora, Sand | `themes/frosted/` |
| Journal (was Plum) | Set like a literary journal: serif titles, ink rules instead of boxes | Plum, Ink blue, Forest | `themes/journal/` |
| Sticker (was Rose) | Chunky, round and cheerful: 2 px outlines, sticker shadows | Rose, Mint, Mustard | `themes/sticker/` |
| Paperback (was Amber) | Paper under a reading lamp: a book serif, italic secondary text | Amber, Sepia, Linen | `themes/paperback/` |
| High Contrast | The most contrast there is: black and white, every word at 7:1, 2 px edges, inverse selection, a double focus ring | Blue, Yellow, Cyan | `themes/high-contrast/` |
| E-ink | E-paper: ink on paper only, a reading serif, ruled pages, calendars as patterns, nothing that moves | White, Cream, Grey | `themes/e-ink/` |
| Large | Large and simple: 19 px text, 52 px targets, 2 px outlines, the same layout | Blue, Green, Purple | `themes/large/` |
| Terminal | A terminal for your own data: one monospace face, square boxes, compact rows, inverse-video selection, nothing that moves | Green, Amber, Cyan | `themes/terminal/` |
| Notebook | Paper and ink: ruled paper, handwritten titles, a reading serif, a highlighter for the selection; a blackboard in dark | Blue, Green, Violet | `themes/notebook/` |
| Brutalist | Square, heavy and honest: black ink, 3 px outlines, hard offset shadows that a press pushes into | Blue, Yellow, Green | `themes/brutalist/` |
| Retro Desktop | The classic desktop, drawn new: grey panels, black outlines, bevelled buttons, pixel titles and icons on a dotted desk | Grey, Beige, Teal | `themes/retro-desktop/` |
| Swiss | A Swiss poster: big tight grotesk titles set flush left, black rules, square corners, one colour | Red, Blue, Green | `themes/swiss/` |
| Blueprint | A technical drawing: a faint drawn grid, dashed outlines, upper-case callouts, outline selection; white lines on a coloured board in dark | Blue, Sepia, Green | `themes/blueprint/` |
| Arcade | A midnight heads-up display: cut corners, a faint grid floor, thin bright edges, a glow on the accent only | Magenta, Cyan, Lime | `themes/arcade/` |

Each folder holds the theme file and its `RULES.md` (its design language, its palettes, do and don't, accessibility, font and icon licences). The six drawn themes are the phase 3 targets; until then the apps draw Kiwi, and the old colours are Kiwi's palettes. All twenty prototypes ship as built-ins (the owner, 2026-10-23): the 13 new ones are added in phase 4, each ported to palettes and the validator; High Contrast, E-ink, Large, Terminal, Notebook, Brutalist and Retro Desktop are in (2026-10-24). "System, tinted" (System with another accent) never exists on macOS; other platforms may allow a tint later (phase 5).

## Palettes

- **A palette is colour only:** the six seeds (`bg`, `surface`, `ink`, `ink-muted`, `accent`, `on-accent`) in light and dark, any other of the 43 roles, an increase-contrast set and, for a gradient window, the gradient's stops. Built-in palettes give every role their style does not fix through `colour-use.same-as` (all 43 once resolved); what a custom palette leaves out is derived.
- **The style stays:** fonts, shapes, density, borders, depth, materials, icons, motion and variants never change with the palette. A theme can also fix a role for every palette (`colour-use.same-as`: Hairline's selection bar is always `ink`).
- **Every palette must pass the contrast rules on its own**, in both modes and at increased contrast. All 18 built-in palettes pass at both levels (phase 1's validator): Hairline's and Sticker's with their own sets, the others with the derived 7:1 values.
- **Across a theme's palettes** the accent and the tint of the grounds move; status, `danger` and calendar colours keep their meaning.
- **System has no palettes:** its colour is the system accent (no alternatives on macOS).
- **Custom themes** (phase 5) may add palettes, up to 8.

## What a theme can change

Colours, through its palettes (43 roles in light and dark, six required, the rest derived; increase-contrast overrides), type (fonts from a catalogue of OFL fonts, sizes, weights, case on labels and captions, figures, italic secondary text), shape (round, continuous, cut or square corners; radii; pill or matching controls), density (above the platform floors), borders, elevation, materials (window ground, sidebar, bars; images not before phase 6), icon set and weight, motion, and the variant of each component (buttons, lists, selection, sidebar, toolbar, inputs, avatar, tabs, chat, month, today), and what it promises beyond the rules every theme keeps (`accessibility`: text at 7:1, readable faint text), which its file says, not its id. Bounds are in the schema; `themes/ARCHITECTURE.md` section 1 has the table.

## What a theme never changes

- Wording, sentence case in wording, the sections and their order, the order of actions, keys and the macOS menu bar.
- Layout. Folding details away or opening on another view is a later device accessibility setting, not a theme field.
- The window's own controls and the system's dialogs. A drawn theme on a Mac keeps the native window, traffic lights, menu bar and the skeleton (sidebar, list, record, toolbar band), and draws everything inside it.
- `brand`, the logo and the kiwi artwork colours.
- What a status colour means: `danger` stays within 25° of today's red (a theme without colour, E-ink, draws it in ink, told by its word).
- The approval card's structure: the theme's colours and fonts only, on a solid surface with a 1 px `line-strong` edge, never an image or pattern behind it.
- Mode, which stays per device.

## Rules every theme keeps

The validator checks these for built-ins, imports and the editor alike; a built-in that fails breaks the build, an imported one is never applied (`themes/ARCHITECTURE.md` section 2). To see a theme file in the real apps before it ships, run `app/tool/preview_themes.sh <slug or path>`: it validates the file, then draws myContacts, myCalendar, myAssistant and myData's Settings in each palette, light and dark, off-screen, onto one sheet (`themes/ARCHITECTURE.md` 5, phase 3½).

- **Contrast,** in both modes: text 4.5:1 on every ground it is drawn on (`ink`, `ink-muted`, `link`, `on-accent` on `accent`, status words on their fills); control edges, the selection marker and the focus ring 3:1; 7:1 for every text pair when the system asks for more contrast (derived when the file does not give it). Gradients, patterns and glass are checked against what shows through.
- **Never colour alone:** status always carries a word; a tint selection that is under 3:1 also draws a bar or outline; links are underlined.
- **Focus:** a visible ring, 3:1 against what it touches, following the shape (never clipped), drawn in `ink` on anything already red, and two-tone where it sits on a filled shape; a theme may make it double (3 px with a keyline on every control, High Contrast). System uses the system's ring.
- **Accent near red:** when `accent` and `danger` are within 25° of hue, Approve and filled primary buttons are drawn in `ink`, so Approve never looks like Delete.
- **Upper case** only on `label` and `caption` roles, with tracking, and never on text that holds a name (a person, an app such as myAssistant, a calendar, a file).
- **Disabled filled buttons** (from phase 3): `surface-sunken` with an `ink-muted` label, about 4.5:1; other controls fade to 45%, and the reason always shows in full `ink-muted` (`platforms.md`, "Disabled controls").
- **Sizes:** targets at least 24 px on desktop, 44 on iOS and coarse pointers, 48 on Android; body at least 12 px on desktop, 16 px in phone text fields; display-only fonts at 16 px or more.
- **System settings win:** reduced motion turns motion into a short fade or nothing; reduced transparency turns glass, patterns and images solid; increase contrast applies the contrast set; text size scales every theme.
- **Data only:** a theme file holds no URLs, code or CSS, and nothing is ever fetched. Built-in theme files are CC0-1.0. Fonts are bundled as Latin subsets in every app, capped at 6 MB per app.

## Custom themes (phase 5)

Duplicate any theme and edit it in myData (a live preview beside the settings, each failing check with Fix, Save disabled with its reason while anything fails), import a `.mydatatheme` file or pasted JSON, export and share. Duplicating System gives a frozen drawn copy, and the editor says it no longer follows the system. Nothing applies by itself, and there is no online gallery.
