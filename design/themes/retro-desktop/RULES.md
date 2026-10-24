# Retro Desktop: design rules

`mydata.retro-desktop` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `beige` (renamed 2026-10-23). The classic desktop of the late 1980s and 1990s in general, drawn new.

## Personality

Grey panels with black outlines, bevelled push buttons, a pixel face for titles, pixel icons and a dotted desk behind the panes. Friendly and solid. **Original artwork only:** no real system's names, fonts, icons, chrome or wallpaper (Chicago, Geneva, Charcoal and Aqua are on Apple's trademark list; the colours here are generic).

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title | Pixelify Sans (display-only) | 32 / 1.15, 24 / 1.17, 18 / 1.22; 600 |
| Heading | Atkinson Hyperlegible Next | 16 / 1.38 / 700 |
| Body | Atkinson Hyperlegible Next | 14 / 1.43 / 400 (body-strong 700) |
| Label, caption | Atkinson Hyperlegible Next | 13 / 1.38 / 700; 12 / 1.33 / 400 |
| Mono | JetBrains Mono | 12 / 1.5 |

- Pixelify Sans only at 16 px and up (it turns "BE" into "8E" at 12 px, Research B). It has no Vietnamese or `ʼ`; Atkinson Hyperlegible Next stands behind it and lacks them too, so those letters come from the platform's font (`acceptedGaps` in `fonts_test.dart`).
- Atkinson's slashed zero and distinct letterforms suit dense grey screens.

## Shape

Square panels and windows (radius 0); 6 px on buttons and controls (`radius.sm`, `controls: match`).

## Density

28 px rows and controls in the prototype; here **32 px rows and controls and 24 px icons** on the desktop, spacing ×0.75: Pixelarticons are drawn on a 24 px grid, so at 24 px each of their pixels is one screen pixel, and at 16 px they blur. Phones: 44 / 48 / 24.

## Colour use

- A mid-tone desk (`bg`) under a dot pattern; light panels (`surface`), white wells (`surface-sunken`).
- 1 px black outlines (`edge`; a light grey in dark) on every panel and control.
- The accent is the default button and a **solid selection**: the style fixes `selection` to `accent` and `on-selection` to `on-accent`, and `toolbar` to `sidebar` (`colour-use.same-as`).
- **A double focus ring** (`borders.focus: double`): 3 px of red with a 1 px `surface` keyline on every control. No one colour is 3:1 on both the light panels and the dark selection (ARCHITECTURE.md 2.3 names this theme); the keyline carries it. It is the nearest the format has to a dotted focus rectangle.
- Status and calendar colours as everywhere; on the mid-grey panels the data colours under 3:1 get their 1 px edge.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Grey (default) | `grey` | `#2A2AA8` / `#AEB5FF` | light 12.7 / 6.8 / 6.4 / 10.5; dark 14.6 / 11.4 / 10.9 / 9.3 |
| Beige | `beige` | `#384915` / `#C5D98F` | light 12.7 / 7.3 / 5.9 / 9.8; dark 14.6 / 11.5 / 11.9 / 9.9 |
| Teal | `teal` | `#000080` / `#8FE0E0` | light 13.6 / 7.8 / 10.4 / 16.0; dark 11.5 / 8.9 / 9.4 / 10.6 |

- **Grey:** grey desk (`#C9C9C9`), light-grey panels, a deep blue.
- **Beige:** the warm platinum of an old case: every grey tinted warm at the same lightness, an olive default button.
- **Teal:** a teal desk (`#A9D9D6`; `#0F3636` in dark) under the grey panels, a navy default button.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast, its text checked over the dots as well. Secondary text and links keep a margin over 4.5:1 for that (5.0 and 5.8 on the flat ground). In dark, raised panels are a step from the surface only, so the hover keeps 1.3:1 on them when increased contrast darkens it.

## Depth and materials

- **Bevel:** a light top-left and dark bottom-right line on panels and buttons and a 2 px drop; a press collapses it and the control sinks.
- The desk is a **dot pattern** (8 px, ink at 12%), painted once behind the panes, never per row and never under a panel. Reduced transparency turns it solid; increased contrast should too (ARCHITECTURE.md 2.3), once the apps follow the system's setting.
- Solid sidebar and bars.

## Icons

Pixelarticons (MIT), one weight, 24 px, no tiles.

## Motion

`none`: menus and sheets appear at once; presses sink. Reduced motion changes nothing.

## Components

| Part | Variant |
|---|---|
| Buttons | Bevelled primary (the accent's face, a 1 px edge); outlined secondary |
| Lists | Bordered panels on the desk |
| Selection | Solid accent with its label colour |
| Avatars | Squares |
| Inputs | Outlined |
| Tabs | Boxed |
| Chat | Blocks |
| Month | Boxed grid with 1 px lines; today inverse |
| Title rule | Double, under a record's title |

## Do and don't

- Do keep outlines 1 px and bevels light at the top left.
- Do keep Pixelify for titles at 16 px and up, and pixel icons at 24 px.
- Don't copy any real system's chrome, icons, fonts or wallpaper.

## Accessibility

- Ink 11.5:1 or more on the desk in every palette and mode; secondary text 6.8:1 or more; links 5.9:1 or more.
- The double ring is 3:1 on every ground it touches, with its keyline between it and any fill.
- Targets are 32 px on the desktop, above the 24 px floor.

## Fonts and icon licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Pixelify Sans | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/pixelifysans |
| Atkinson Hyperlegible Next | SIL OFL 1.1, no Reserved Font Name, bundled | https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegiblenext |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Pixelarticons 2.4.2 | MIT | https://github.com/halfmage/pixelarticons/blob/master/LICENSE |

Pixelarticons' brand glyphs are never mapped: its `x` is a brand's logo. "clear" is drawn as its `delete` key, so it is never the same glyph as "close"; a month is `calendar-2` (a grid of days), apart from the lined `calendar-text` of an event added; a record's message is the round `comment`, apart from the chat's `message-text`. Pixelarticons has no calendar with a tick.

## Ported from the prototype

- Its colours are the Grey palette, with secondary text, links and the focus ring moved in lightness for the dots and the double ring; Beige and Teal are new.
- 24 px icons and 32 px rows and controls, not 16 and 28 and 30 (above).
- The double ring stands in for the dotted focus rectangle; striped title bars on each pane, inset (sunken) fields and "titles in the body font above 1.5× text size" are still beyond the format.
- **In the Mac window** the Mac widgets draw no bevel (the shared widgets do: buttons, the chat's cards, the branded frame), and the Mac form groups keep the theme's small radius. `themesDistinct` scores Retro Desktop and Terminal 0.13 on myCalendar's Mac month (0.18 is the bar there): both rule every day in a thin dark line and mark today in ink, and the dots are fainter than the metric's step. The pair is allowed on that screen alone, with the reason in the test.
