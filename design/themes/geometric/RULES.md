# Geometric: design rules

`mydata.geometric` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `primary` (renamed 2026-10-23). An original design in the early-modernist manner: no school, brand or trademark is named.

## Personality

Circle, square, triangle; red, yellow, blue. Confident and structural: square boxes with 2 px ink edges, a geometric sans, one primary colour for action, a yellow block for "this one", and people drawn as shapes.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title | Jost | 44 / 1.1, 32 / 1.12, 22 / 1.2; 600 |
| Heading | Jost | 17 / 1.35 / 600 |
| Body | Jost | 15 / 1.47 / 400 (body-strong 600) |
| Label | Jost | 12 / 1.4 / 600, **upper case**, 0.08 em tracking (field names, section letters, weekday heads) |
| Caption | Jost | 13 / 1.38 / 400 |
| Mono | JetBrains Mono | 13 / 1.5 |

- Tabular figures. Upper case is typographic only, on labels that never hold a name.
- Jost has no Vietnamese and no modifier apostrophe: those letters come from the system's font (an accepted gap, as for several bundled faces).

## Shape and density

- Square everywhere (radius 0). Shapes appear only in avatars: a circle, a square or a triangle, chosen from the name.
- Regular: 40 px controls, 52 px rows, 20 px icons on the desktop; phones 48 / 56 / 22.

## Colour use

- An off-white ground (`#F3EFE6`), white panels; black (`#121212`) and charcoal in dark.
- The style fixes `edge` and `line` to `ink` (`colour-use.same-as`): every edge and rule is a 2 px ink line.
- **The three colours keep their jobs:** the palette's primary acts (the primary button, links, today, the current tab); **yellow selects** (in light an ink block with `#F5C400` text, about 11:1, since a yellow block is 1.6:1 on white; in dark a yellow block with ink text); red, yellow and blue identify (avatars and the calendars).
- **A double focus ring** (3 px with its `surface` keyline, `borders.focus: double`): no one ring colour is 3:1 on both the dark grounds and the yellow block (ARCHITECTURE.md 2.3).

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Blue (default) | `blue` | `#1B4FD8` / `#7FA2FF` | light 16.5 / 7.7 / 5.8 / 6.7; dark 16.3 / 8.3 / 7.6 / 6.8 |
| Red | `red` | `#C8102E` / `#FF6B6B` | light 16.5 / 7.7 / 5.5 / 5.9; dark 16.3 / 8.3 / 7.2 / 6.9 |
| Green | `green` | `#007A4D` / `#4FD08F` | light 16.5 / 7.7 / 5.6 / 5.4; dark 16.3 / 8.3 / 9.6 / 8.8 |

- A palette moves the colour that acts; the yellow selection, grounds, ink, status and calendar colours stay.
- **Red is near danger:** in the Red palette the primary and Approve are drawn in ink and only a destructive act is red (ARCHITECTURE.md 2.2); its ring is blue, never the red of its links and today.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values).

## Depth and materials

None: flat off-white or black, 2 px ink edges on every container and control, a single rule under titles. No shadows, no gradients, no texture.

## Icons

Phosphor Fill at 20 px, no tiles.

## Motion

`crisp`: quick, no overshoot; a press dims and scales from the centre; a fade on entry. Reduced motion: a fast fade.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary filled, secondary outlined, plain an underlined word; square |
| Lists | Bordered, full separators |
| Selection | Solid: light an ink block with yellow text, dark a yellow block with ink text |
| Avatars | Shapes: red circle, blue square, yellow triangle, initials in white or ink by contrast |
| Inputs | Outlined, 2 px |
| Tabs | Boxed |
| Chat | Blocks |
| Month, today | Boxed 2 px grid; today a disc in the palette's colour |
| Title rule | Single |

## Do and don't

- Do keep the colours in their jobs: one acts, yellow selects, red identifies.
- Don't use yellow as text on white, or as the only marker on white.
- Don't add gradients or shadows.

## Accessibility

- Ink 16.5:1 and 16.3:1; secondary text 7.7:1 and 8.3:1; the yellow selection's text about 11:1.
- Ink edges 2 px, 16:1 or more, on every control.
- Shapes also tell people apart where colour cannot.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Jost | SIL OFL 1.1, no Reserved Font Name (Latin subset, upright) | https://github.com/google/fonts/tree/main/ofl/jost |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Phosphor Icons | MIT | https://github.com/phosphor-icons/core |

## Ported from the prototype

- Its colours are the Blue palette; Red and Green are new.
- The double focus ring is new: the prototype's red ring was 1.5:1 on the dark yellow block.
- Plain buttons are underlined words; elevation is written out as none.
- Not expressible in format 1, as the prototype said: a square primary with a round secondary, a red rule under titles, and calendar event dots drawn as shapes.
- **In the Mac window it is close to Brutalist and High Contrast** on the screens without people: myData's status (square ink boxes round each group, an inverse selected section; `themesDistinct` allows Brutalist at 0.14 and Arcade at 0.24) and myCalendar's month (one 2 px ink grid; High Contrast at 0.15). What sets it apart, the people drawn as shapes, shows where avatars do: the shared lists, the record header and the chat.
- The approval card keeps its 1 px `line-strong` edge and its fixed structure, as in every theme.
