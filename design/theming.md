# Theming

A theme changes how the whole app looks: colours, type, shape, density, borders, depth, icons, motion and how each component is drawn. Each app has its own theme, chosen on each device. System is the default. Decided 2026-10-23 (`docs/decisions/2026-10-23-themes.md`); the full design is `themes/ARCHITECTURE.md`, the format `themes/theme.schema.json`.

**Not built yet.** Until phase 2 the apps still read one theme from the host (`/appearance`), which changes only `accent`, `on-accent` and `accent-soft` (`themes.json`), and on macOS the Mac shell ignores it. Phase 1 changes nothing on screen.

## Choosing a theme

| Setting | Options | Default | Where it applies |
|---|---|---|---|
| Theme, per app | Any built-in (later, any custom theme) | System | That app, on this device |
| Use everywhere | Sets one theme for every app, including apps installed later, and clears each app's own choice (with Undo) | System | Every app on this device |
| Mode | Light, Dark, Match system | Match system | Every app on this device |
| Transparency, motion, text size, increase contrast | Follow the system | The system's | Every app on this device |

- An app uses its own choice, else the "everywhere" theme, else System. Choices live in `<home>/device/settings.json` and are **never synced**: a second Mac starts on System.
- **In every app:** View > Theme… (⌥⌘T, unless Apple's own apps use it) opens the gallery: live cards of that app's main screen in light and dark; arrow keys preview the theme on the whole window, Return or "Use in myContacts" keeps it, "Use everywhere" applies it to every app, Escape puts the previous one back. On a phone: More actions > Theme….
- **In myData:** Settings > Appearance has Mode, Everywhere, one row per installed app ("Same as everywhere" or its own theme, Change… and Reset) and, later, the library.
- **Phones** get one theme per app and no Use everywhere until native phone apps exist (separate apps cannot share a folder without App Groups).
- First launch does not ask: System is the default.

## The built-in themes

| Theme | Character | Rules |
|---|---|---|
| System | Looks like the rest of your computer: the Mac shell on macOS. On Windows, Linux and the web, Kiwi in the platform's font until that platform's own pass; Android waits for its Material 3 pass. The picker says so | `themes/system/` |
| Kiwi | Soft grey grounds, white cards, continuous corners, pills, tinted tiles, one kiwi green | `themes/kiwi/` |
| Graphite | Precise, grey and quiet: hairlines, small corners, a black bar on the selected row | `themes/graphite/` |
| Dusk | An evening sky behind frosted glass, slow motion | `themes/dusk/` |
| Plum | Set like a literary journal: serif titles, ink rules instead of boxes | `themes/plum/` |
| Rose | Chunky, round and cheerful: 2 px outlines, sticker shadows | `themes/rose/` |
| Amber | Warm paper under a reading lamp: a book serif, italic secondary text | `themes/amber/` |

Each folder holds the theme file and its `RULES.md` (its design language, do and don't, accessibility, font and icon licences). The six drawn themes are the phase 3 targets; until then they differ only in their accent. New built-ins are the owner's pick from the prototype gallery; none is added until then. "System, tinted" (System with another accent) is a custom theme, phase 5.

## What a theme can change

Colours (43 roles in light and dark, six required, the rest derived), increase-contrast overrides, type (fonts from a catalogue of OFL fonts, sizes, weights, case on labels and captions, figures, italic secondary text), shape (round, continuous, cut or square corners; radii; pill or matching controls), density (above the platform floors), borders, elevation, materials (window ground, sidebar, bars; images not before phase 6), icon set and weight, motion, and the variant of each component (buttons, lists, selection, sidebar, toolbar, inputs, avatar, tabs, chat, month, today). Bounds are in the schema; `themes/ARCHITECTURE.md` section 1 has the table.

## What a theme never changes

- Wording, sentence case in wording, the sections and their order, the order of actions, keys and the macOS menu bar.
- Layout. Folding details away or opening on another view is a later device accessibility setting, not a theme field.
- The window's own controls and the system's dialogs. A drawn theme on a Mac keeps the native window, traffic lights, menu bar and the skeleton (sidebar, list, record, toolbar band), and draws everything inside it.
- `brand`, the logo and the kiwi artwork colours.
- What a status colour means: `danger` stays within 25° of today's red.
- The approval card's structure: the theme's colours and fonts only, on a solid surface with a 1 px `line-strong` edge, never an image or pattern behind it.
- Mode, which stays per device.

## Rules every theme keeps

The validator checks these for built-ins, imports and the editor alike; a built-in that fails breaks the build, an imported one is never applied (`themes/ARCHITECTURE.md` section 2).

- **Contrast,** in both modes: text 4.5:1 on every ground it is drawn on (`ink`, `ink-muted`, `link`, `on-accent` on `accent`, status words on their fills); control edges, the selection marker and the focus ring 3:1; 7:1 for every text pair when the system asks for more contrast (derived when the file does not give it). Gradients, patterns and glass are checked against what shows through.
- **Never colour alone:** status always carries a word; a tint selection that is under 3:1 also draws a bar or outline; links are underlined.
- **Focus:** a visible ring, 3:1 against what it touches, following the shape (never clipped), drawn in `ink` on anything already red, and two-tone where it sits on a filled shape. System uses the system's ring.
- **Accent near red:** when `accent` and `danger` are within 25° of hue, Approve and filled primary buttons are drawn in `ink`, so Approve never looks like Delete.
- **Upper case** only on `label` and `caption` roles, with tracking, and never on text that holds a name (a person, an app such as myAssistant, a calendar, a file).
- **Disabled filled buttons** (from phase 3): `surface-sunken` with an `ink-muted` label, about 4.5:1; other controls fade to 45%, and the reason always shows in full `ink-muted` (`platforms.md`, "Disabled controls").
- **Sizes:** targets at least 24 px on desktop, 44 on iOS and coarse pointers, 48 on Android; body at least 12 px on desktop, 16 px in phone text fields; display-only fonts at 16 px or more.
- **System settings win:** reduced motion turns motion into a short fade or nothing; reduced transparency turns glass, patterns and images solid; increase contrast applies the contrast set; text size scales every theme.
- **Data only:** a theme file holds no URLs, code or CSS, and nothing is ever fetched. Built-in theme files are CC0-1.0. Fonts are bundled as Latin subsets in every app, capped at 6 MB per app.

## Custom themes (phase 5)

Duplicate any theme and edit it in myData (a live preview beside the settings, each failing check with Fix, Save disabled with its reason while anything fails), import a `.mydatatheme` file or pasted JSON, export and share. Duplicating System gives a frozen drawn copy, and the editor says it no longer follows the system. Nothing applies by itself, and there is no online gallery.
