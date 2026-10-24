# Terminal: design rules

`mydata.terminal` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `prompt` (renamed 2026-10-23). The look closest to the Warp feel the owner pointed at: a terminal for your own data.

## Personality

A terminal emulator or a text interface. One monospace face, square boxes, compact rows, inverse-video selection, and no decoration that is not a line or a character. Dark is phosphor on near-black; light is a printed listing on tinted paper.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | JetBrains Mono | 20 and 17 / 1.3 / 700 |
| Title, heading | JetBrains Mono | 15 / 1.33 / 700; 14 / 1.43 / 700 |
| Body | JetBrains Mono | 13 / 1.54 / 400 (body-strong 700) |
| Label | JetBrains Mono | 12 / 1.5 / 700, **upper case**, 0.04 em tracking |
| Caption, mono | JetBrains Mono | 12 / 1.5 / 400; 13 / 1.54 / 400 |

- Hierarchy by weight, not size: no step above 1.25×. Tabular figures everywhere.
- JetBrains Mono is a core font, bundled at 400 and, since this theme, 700 (`JetBrainsMono-700.ttf`, cut by `tool/subset_fonts.sh`), so the prototype's 500 label is 700: a bold upper-case label, as a text interface heads its columns.
- Upper case only on the label role, never on a name (a person, an app, a calendar): the words keep their case for screen readers.

## Shape

Square: every radius 0. Buttons, fields, tabs and boxes are rectangles.

## Density

Compact on the desktop: 28 px controls and rows, 16 px icons, spacing ×0.75 (the 24 px floor of WCAG 2.2 SC 2.5.8 holds). Phones are never compact: 44 / 48 / 20.

## Colour use

- Ground and surface are almost one colour; the sidebar (and the toolbar, which the style fixes to it) a shade apart.
- The accent fills the primary button; links are the accent, underlined.
- **Selection is inverse video:** the style fixes `selection` to `ink` and `on-selection` to `bg` (`colour-use.same-as`), so a selected row is the text colour with the ground's colour on it.
- 1 px boxes in `edge`: ink in light, the accent in dark (the phosphor's glow), around panels, fields, the result card and the approval card's contents.
- The focus ring is red, 3:1 on every ground and on the inverse selection it can sit on, and apart in hue from every palette's accent.
- Green, like the accent, is also `success`: a success state always shows its word and check.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Green (default) | `green` | `#1E6B2E` / `#5BE36B` | light 16.6 / 7.8 / 6.1 / 6.6; dark 16.0 / 8.9 / 11.6 / 11.6 |
| Amber | `amber` | `#7D4E03` / `#FFB048` | light 16.6 / 8.0 / 6.5 / 7.1; dark 15.6 / 8.4 / 10.6 / 10.6 |
| Cyan | `cyan` | `#05666F` / `#00DBED` | light 16.6 / 7.8 / 6.2 / 6.7; dark 16.0 / 8.9 / 11.4 / 11.4 |

A palette is the phosphor's colour: grounds, ink, lines and the accent all take its hue at the prototype's lightness and chroma (OKLCH), so Amber is amber on near-black and a listing on cream, Cyan the same in cyan. Status, `danger` and calendar colours stay. Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (derived 7:1 values).

## Depth and materials

None: flat solid ground, sidebar and bars, no shadows. A 1 px rule under the title. Scan lines (`pattern: scanlines`) would suit it but are not on: it is a printout, not a CRT effect.

## Icons

Lucide at 16 px, no tiles.

## Motion

`none`: nothing moves; a press inverts the control (an `ink` fill with its label in `bg`). Reduced motion changes nothing.

## Components

| Part | Variant |
|---|---|
| Buttons | A filled square primary (a block of the accent); outlined secondary |
| Lists | Plain, no separators |
| Selection | Inverse |
| Avatars | None: the name is the content |
| Inputs | Underlined, like a prompt line |
| Tabs | Boxed, the current one inverse |
| Chat | Transcript: each turn under "You" or "myAssistant" beside a rule, no bubbles |
| Month | Table: a full grid; today inverse |
| Toolbar, sidebar | A flat band with a rule; a column |
| Title rule | Single |

## Do and don't

- Do keep everything on the feel of a character grid: one face, square, aligned.
- Don't use size for hierarchy, or a second font.
- Don't add glow or blur.

## Accessibility

- Text: ink 15.6:1 or more on the ground in every palette and mode; secondary text 7.8:1 or more; links 6.1:1 or more.
- Inverse selection is the ink's contrast itself; the focus ring is 3:1 against it and against every ground.
- Compact rows stay at 28 px on the desktop, above the 24 px floor; phones keep 44 and 48.
- Reduced motion: nothing to reduce. Increased contrast: the derived 7:1 set.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| JetBrains Mono (400 and 700) | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Lucide | ISC, plus MIT for the icons it takes from Feather | https://github.com/lucide-icons/lucide/blob/main/LICENSE |

## Ported from the prototype

- Its colours are the Green palette, with `line-strong` darkened in light to 3:1 on `surface-sunken` too (a disabled button's outline); Amber and Cyan move its hue.
- `selection`, `on-selection` and `toolbar` are fixed by the style rather than given per palette.
- The label is 700, not 500 (the bundled weights).
- What the format cannot say yet, as the prototype noted: buttons in brackets (`[ New contact ]`), a prompt-style title (`~/contacts $`), a blinking block cursor in a focused field, and a `cal`-style text month (`month: table` is the nearest).
- **In the Mac window** (after the batch 2 review): switches are square, the search field and the composer are a line under the text, each chat result is boxed in the card edge, and a bare form group's heading is the upper-case 700 label, so the groups still read as groups.
