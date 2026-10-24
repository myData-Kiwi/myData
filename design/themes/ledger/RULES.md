# Ledger: design rules

`mydata.ledger` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `tabular` (renamed 2026-10-23).

## Personality

An account book: dense rows ruled and striped like a ledger's columns, figures that line up, small corners and grey rules, one ink colour. For people with many contacts and a big screen: it shows about twice as many rows as Kiwi. Plain and exact; no decoration.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Inter, at its display optical size | 28 / 1.15 and 22 / 1.2, 600, tracking −0.02 and −0.015 em |
| Title | Inter | 15 / 1.3 / 600, tracking −0.01 em (record names, the month) |
| Heading | Inter (the display stack) | 14 / 1.3 / 600 |
| Body | Inter | **13 / 1.35** / 400 (body-strong 600) |
| Label, caption | Inter | 12 / 1.3 / 500; 11 / 1.35 / 400 |
| Mono | JetBrains Mono | 11 / 1.35 |

- **Tabular figures everywhere**, so counts, times and day numbers line up in columns.
- 13 px is the base, not a ceiling: the system's text size scales every role. 11 px captions and mono are the floor the architecture allows (1.4); they pass contrast with room.
- Sentence case throughout.

## Shape and density

- Small round corners: 2 / 3 / 4 / 4 / 6 px; buttons are small rounded rectangles; controls match.
- **Compact on the desktop:** 28 px controls, 26 px rows, 16 px icons, spacing ×0.75. The run-time floor of 24 px (WCAG 2.2 SC 2.5.8) holds.
- **Phones are never compact:** 44 px controls, 48 px rows, 20 px icons, spacing ×1 (and the platform's floors above that).

## Colour use

- Cool or tinted greys for the ground (`#F5F6F8` / `#0D1114` in Teal), white or near-black surfaces, one ink colour per palette.
- **Three steps from the page:** a plain row on `surface`; a **zebra stripe** on `stripe`, every second row of a letter group, starting again under each letter (about 1.1:1 on `surface`, subtle on purpose); a table's **header band** (the letter) on `surface-sunken`, a near-neutral grey a step past the stripe (about 1.2:1 on `surface`, 1.1:1 on a stripe), so a striped last row never runs into the next band. `ink` and `ink-muted` pass on all three. Tables only: `stripe` is the one role no other part of the app reads, so the stripe's tint (Green's green bar) stays in the tables.
- Rules: 1 px `line` between rows and round cards, a 1 px `line-strong` under a table's header row (the letter band; 3:1 or more on the band), a single rule under titles. Controls take the control outline (`line-strong`, since `line` is under 3:1). The style fixes `edge` to `line-strong` (`colour-use.same-as`).
- Selection: a bar, the colour's tint with a 3 px leading bar in the colour. The tint is stronger than a ledger's stripes so a selected row is never read as one: about 1.27:1 on a stripe and 1.4:1 on a plain row (the validator's table notices ask 1.2), so the selection never rests on the bar alone. `selection-inactive` is the Mac's own list's (System's), which a drawn theme never paints.
- The focus ring is today's red (`#B3261E`, `#F2867E` in dark) in every palette: none of the three colours is near it, so it never reads as the selection.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Teal (default) | `teal` | `#0F6E78` / `#5CC8D2` | light 17.1 / 6.6 / 5.9 / 6.0; dark 15.5 / 7.7 / 9.6 / 8.2 |
| Green | `green` | `#3A6B1E` / `#9DD27A` | light 16.9 / 6.7 / 5.8 / 6.4; dark 15.5 / 7.7 / 10.7 / 9.1 |
| Blue | `blue` | `#2A4E9C` / `#93B2F2` | light 17.2 / 6.7 / 7.3 / 7.9; dark 15.5 / 7.7 / 9.0 / 8.1 |

- **Teal** is the prototype's colour. **Green** is green-bar listing paper: its stripes and grounds take a pale green, while its header bands and sunken panels (the approval card's message, wells) stay a near-neutral grey, so the green bar is only in the tables. **Blue** is a ledger's blue ruling ink. A palette moves the accent, its tint, the link and the tint of the grounds and stripes; status and calendar colours stay.
- Teal's light link is a step darker than its accent (`#0F6973`), so it still reads at 4.5:1 on the stronger selection tint.
- A red was left out: it would sit on `danger`'s hue, and a ledger's red is for what is owed.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values).

## Depth and materials

Flat. No shadows, no glass, no texture. Structure comes from the 1 px rules, the header bands and the stripes.

## Icons

Tabler Light (1.5 px strokes) at 16 px, bare, no tiles; the current section's icon stays as drawn (`selected: same`).

## Motion

Crisp at ×0.7 (about 60 ms); a press dims; nothing slides or fades in. Reduced motion: nothing moves.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary filled, small rounded; secondary 1 px outline; plain a word in the colour |
| Lists | **Table**: each letter group a header band on `surface-sunken` with its `line-strong` rule, full `line` rules, zebra stripes on the lighter `stripe`; a selected row's tint covers its stripe; boxed in the outline with small corners where the list is a group (the branded frame), across the pane in the Mac window |
| Selection | Bar: the pale tint and a 3 px leading bar |
| Sidebar, toolbar | A solid column; a flat band with its rule |
| Inputs | Outlined |
| Avatars | Small rounded tiles |
| Tabs | Boxed segments, the current one filled in the colour |
| Chat | Transcript: each turn under its speaker, beside a rule |
| Month, today | Table: every day ruled in the control outline's grey; today inverse, an ink block |
| Title rule | Single |

## Do and don't

- Do let the user's text size setting scale everything.
- Do keep every target at 24 px or more on the desktop, with spacing.
- Don't use this density on phones or with a finger on a desktop (the run-time floors raise it to 44).
- Don't stripe anything but tables: forms, cards and the month stay plain.
- Don't add columns: the contact list stays one column of names, as in every theme (layout stays out of themes, decision 9).

## Accessibility

- Ink 16.9 to 17.2:1 on the light grounds and 15.5:1 on the dark; secondary text 6.5:1 or more on the grounds and stripes, 5.9:1 on the header bands and 5.1:1 on a selected row.
- `line-strong` (the control outline, the header rule and `edge`) 3.4:1 or more on `bg` and 3.7:1 or more on `surface`; the selection bar 3:1 or more on both surfaces.
- Increased contrast: the derived 7:1 values for every text pair, links and status words included.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Inter | SIL OFL 1.1, no Reserved Font Name, bundled | https://github.com/google/fonts/tree/main/ofl/inter |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Tabler Icons | MIT, bundled | https://github.com/tabler/tabler-icons/blob/main/LICENSE |

No font or icon set is added: Ledger costs nothing of the font budget.

## Ported from the prototype

- **Named Ledger** (the owner, 2026-10-23). The prototype had been renamed Tabular because Ledger is also a hardware-wallet company's name; "ledger" is the common word for an account book, as Blueprint is for the drawing.
- **Inter, not Inter Tight, for the titles,** as in Swiss: Inter's optical size axis gives display sizes its tight display cut, so no second family is bundled.
- **No columns.** The prototype drew contacts as a table with name, email, phone and source columns and a narrow inspector beside it; that is layout, which stays out of themes. Ledger keeps the table's look (header bands, rules, stripes, density) on the one column every theme has.
- **Today is an ink block on the day's number** in the Mac month, not the whole cell as the prototype drew it: the Mac month draws today's mark the same way in every inverse theme. The branded month grid (off the Mac) inverts the whole cell.
- Phone numbers stay in the body face with tabular figures, not mono: the format cannot set a face per value.
- Its colours are the Teal palette (the hover fill a step darker so it reads 1.3:1 on the ground); Green and Blue are new.
- The approval card keeps its 1 px `line-strong` edge and its fixed structure, as in every theme.
