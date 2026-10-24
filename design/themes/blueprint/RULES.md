# Blueprint: design rules

`mydata.blueprint` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `cyanotype` (renamed 2026-10-23).

## Personality

A technical drawing. Lines on drafting paper by day; white lines on a coloured board at night (Prussian blue in the default palette). A faint 16 px grid under everything, dashed outlines, small upper-case callouts, values in a mono face. Precise and quiet.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title, heading | Space Grotesk | 36 / 1.15, 28 / 1.2, 20 / 1.25, 16 / 1.3; 600 |
| Body | Instrument Sans | 14 / 1.45 / 400 (body-strong 600) |
| Label | Instrument Sans | 11 / 1.3 / 500, **upper case**, 0.08 em tracking (drawing callouts) |
| Caption | Instrument Sans | 12 / 1.35 / 400 |
| Mono | JetBrains Mono | 12 / 1.4: phone numbers, addresses, times you would copy or compare |

- Tabular figures throughout.
- Upper case on labels only, never on text that holds a name: a contact's field labels from the card, an account or a calendar keep their own case.

## Shape and density

- Corners 2 px (4 px on sheets); buttons are square-cornered rectangles.
- Regular: 34 px controls, 40 px rows, 18 px icons on the desktop; phones 48 / 56 / 22.

## Colour use

- Light: a tinted paper ground, white sheets, a dark ink and one strong drawing colour (cobalt `#1554A8` in Blue) for the primary, links and the selection outline; edges in a mid tone of it.
- Dark: the board is the colour, sheets a step lighter, and the **accent is white chalk** with the board's colour as text on it.
- The style fixes `edge` to `line-strong` (`colour-use.same-as`): every outline is the mid tone, never the ink.
- The focus ring is a drafting red (`#C0262D`, `#FF9C8F` in dark), never the drawing colour; in Sepia's light mode it is blue, since red is lost on the brown selection (37° apart).
- Status fills in dark are drawn from the board (the prototype's greys read blue on every board).

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Blue (default) | `blue` | `#1554A8` / `#FFFFFF` | light 14.4 / 6.9 / 6.9 / 7.3; dark 12.7 / 8.4 / 14.3 / 14.3 |
| Sepia | `sepia` | `#804701` / `#FFFFFF` | light 14.6 / 7.0 / 7.0 / 7.4; dark 12.8 / 8.5 / 14.5 / 14.5 |
| Green | `green` | `#056843` / `#FFFFFF` | light 14.2 / 6.7 / 6.4 / 6.8; dark 12.4 / 8.5 / 13.9 / 13.9 |

- **Blue** is the cyanotype; **Sepia** a brown print (a Van Dyke) on cream, white lines on a walnut board in dark; **Green** the engineer's green drafting paper, white lines on a bottle-green board in dark.
- A palette moves the hue of the paper, the board, the ink, the lines and the drawing colour together; status, danger and calendar colours keep their meaning. In dark the three accents are all white chalk (the validator notes they are hard to tell apart): the board tells the palettes apart.
- Calendar colours are lifted in dark until each is 3:1 on the sheet (hue kept).
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values; danger stays red there because its dark fill is drawn from the board).

## Depth and materials

- Window: a **drawn grid** (`pattern: grid`, 16 px, the accent at 7%), painted once behind the content; reduced transparency turns it plain.
- **In the Mac window the panes are sheets on the grid** (`MacPanel`): the contact list and record, the month and the day list are white (or board-coloured) panels with a dashed edge, so names never sit on the grid; form groups are boxes. Section headings and footnotes between groups do sit on the grid; they are checked against it composited.
- No shadows (`elevation: none`). Separation comes from lines.
- Borders: **1 px dashed** in `edge` on cards, lists, panels and separators. **Inputs, buttons, the month's days and the focus ring stay solid**: a dashed line can never be a control's only edge.
- A single rule under a record's title.

## Icons

Tabler at its thinnest stroke, 18 px, on outlined tiles.

## Motion

`crisp` at ×0.9 (about 80 ms); a press dims; a short fade on enter. Reduced motion: a fast fade.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary filled, secondary outline, plain text; square |
| Lists | Bordered: a dashed box with dashed full separators |
| Selection | Outline: a 2 px accent outline, never a fill |
| Sidebar, toolbar | A column; a flat band |
| Inputs | Outlined, solid |
| Avatars | Circles |
| Tabs | Boxed, the current one filled |
| Chat | Blocks |
| Month, today | Table (every day ruled); today an accent ring |
| Title rule | Single |

## Do and don't

- Do keep the grid faint and behind solid sheets.
- Do use mono for anything you would copy or compare.
- Don't use the dashed style for anything interactive.
- Don't add colour beyond the palette's one hue and the calendar colours.

## Accessibility

- Ink on the paper 14.2:1 or more, on the board 12.4:1 or more; secondary text 6.7:1 or more.
- The outline selection is the accent at 3:1 or more on the sheet, so selection never relies on a tint.
- The grid is composited under every text pair that can sit on the ground.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Space Grotesk | SIL OFL 1.1, no Reserved Font Name, bundled | https://github.com/google/fonts/tree/main/ofl/spacegrotesk |
| Instrument Sans | SIL OFL 1.1, no Reserved Font Name, bundled | https://github.com/google/fonts/tree/main/ofl/instrumentsans |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Tabler Icons | MIT | https://github.com/tabler/tabler-icons |

## Ported from the prototype

- **Named Blueprint** again, as the owner's list has it (the prototype was renamed Cyanotype to stay clear of a UI toolkit of that name; "blueprint" is the common word for the drawing, and the theme names no product).
- Its colours are the Blue palette, with the dark status fills drawn from the board; Sepia and Green are new.
- The mono is JetBrains Mono, bundled already, not Azeret Mono: one face fewer for the values the apps set in mono.
- Density for phones is given (48 / 56 / 22); plain buttons are text.
- The panes as sheets on the grid in the Mac window are new (the prototype drew no Mac window); without them the contact list's names sat on the grid.
- Research B's dimension-line ticks for time ranges cannot be said in format 1; the month is a table.
- The approval card keeps its 1 px `line-strong` edge and its fixed structure, as in every theme.
