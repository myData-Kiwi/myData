# Notebook: design rules

`mydata.notebook` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `notebook` (Research B, look 9).

## Personality

An exercise book on the desk: cream paper with faint ruled lines, pen ink, handwritten titles and a yellow highlighter. Dark mode is a blackboard with chalk. Calm and personal, good for a calendar and notes.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title, heading | Kalam (display-only, handwriting) | 40 / 1.4, 32 / 1.75, 26 / 1.077, 20 / 1.4; 700 |
| Body | Newsreader | 16 / 1.75 = **28 px**, the rule pitch; 400 (body-strong 600) |
| Label, caption | Newsreader | 14 / 1.43; 600 and 400; secondary text in italic (`secondary-italic`) |
| Mono | JetBrains Mono | 13 / 1.54 |

- Handwriting never appears in body text, fields, buttons or anything under 16 px (Kalam is display-only; the validator and `MyDataTypeScale` hold it to 16 px and up).
- Kalam is bundled as its bold alone, a static font; Newsreader with its italic, pinned at optical size 16 (it is set at 14 to 16 px only).

## Shape

Nearly square: 2 (checkbox), 3 (buttons, fields), 4 (cards), 6 (sheets). Research B's slightly rotated "taped on" chips are not in the format and not here.

## Density

Rows of 56 px (two rules), 36 px controls and 18 px icons on the desktop; phones 48 / 56 / 22.

## Colour use

- Light: paper `#FAF7F0`, a sticky-note surface `#FFFDF8`, ink a deep shade of the pen's colour, and a **highlighter yellow** `selection` (`#F8E37C`) under the ink.
- Dark (blackboard): `#1F2622` ground, chalk ink `#ECEFE6`, the pen's colour in chalk, a dull yellow-chalk smudge (`#574F1F`) for the highlighter.
- The style fixes `on-selection` to `ink` (the highlighter never changes the text's colour) and `toolbar` to `bg` (`colour-use.same-as`).
- Red is `danger`'s and, as the house's focus ring, keyboard focus (a teacher's red pen); the pen colours keep well clear of it.
- The hover fill is a warm paper shade, not grey.

## Palettes

The pen's colour. A palette moves the accent, the link, the accent's tint, the paper's rules (`line` and the window's ruled lines, which are drawn in the accent) and, faintly, the ink, its edges and `line-strong`; the paper, the blackboard, the highlighter, status and calendar colours stay.

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Blue (default) | `blue` | `#2A4BA8` / `#A4BEF2` | light 13.4 / 6.6 / 7.4 / 7.9; dark 13.3 / 8.2 / 8.3 / 9.0 |
| Green | `green` | `#03662C` / `#99CDA3` | light 13.0 / 6.5 / 6.7 / 7.1; dark 13.3 / 8.2 / 8.5 / 9.1 |
| Violet | `violet` | `#762F8A` / `#E0A3F3` | light 13.6 / 6.7 / 7.7 / 8.3; dark 13.3 / 8.2 / 7.9 / 8.8 |

Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (derived 7:1 values; the highlighter is 7:1 under the ink in both modes already).

## Depth and materials

- **Window ground: ruled paper** (`pattern: ruled`, 28 px apart, the accent at 12%). Under every column but the sidebar, never under a surface; a decoration, never a boundary (the lines are under 3:1 on purpose).
- No cards: rows stand on the paper. Lists are plain with **no separators of their own** (`list: plain`, `separators: none`): the paper's rules separate them, and a list's own rules drawn beside them doubled every line. A Mac form group is bare for the same reason: no box, no fill, no rule (`MacFormSection`). Dialogs get a faint paper shadow (`soft`, 0.3).
- The sidebar is a solid, slightly darker paper (`#F0E9DA`), like a notebook's cover flap.
- Reduced transparency turns the ruled ground solid. Increased contrast should too (ARCHITECTURE.md 2.3), once the apps follow the system's setting; today it changes the colours only.

## Icons

Phosphor regular, 18 px, bare; the current section's icon filled.

## Motion

`calm`: 240 ms, no overshoot. A press dims; views fade. Reduced motion: a short fade.

## Components

| Part | Variant |
|---|---|
| Buttons | A filled primary in the pen's colour, small radius; secondary as underlined words in the pen's colour |
| Lists | Plain, on the paper's rules |
| Selection | **Highlighter**: a yellow swipe behind the name, with a 3 px bar in the pen's colour at the leading edge (the swipe alone is under 3:1 on paper) |
| Sidebar, toolbar | A column; native (transparent over the paper) |
| Inputs | Underlined |
| Avatar | None: the name is the content |
| Tabs | Underline |
| Chat | Transcript: each turn under "You" or "myAssistant" beside a rule |
| Month | Open: a rule between weeks; today circled in pen (`ring`) |
| Title rule | Single |

## Do and don't

- Don't put handwriting in body text, fields or buttons.
- Don't raise the rules above the schema's 12%: they are paper, not grid lines.
- Don't use the highlighter for anything but the selection.

## Accessibility

- Text: ink on paper 13.0:1 or more in light, 13.3:1 on the blackboard; secondary text 6.5:1 or more; links 6.7:1 or more.
- Highlighter: ink on it 10.8:1 or more (light) and 7.1:1 (dark); its pen bar 7.0:1 or more on the surface.
- The ruled lines are under 3:1 on purpose and never the only boundary of anything.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Kalam (Bold) | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/kalam |
| Newsreader (and Italic) | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/newsreader |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Phosphor Icons | MIT | https://github.com/phosphor-icons/core |

## Ported from the prototype

- Its colours are the Blue palette, without its own increased-contrast set (the derived one passes); Green and Violet move the pen's colour. Its dark highlighter is a shade darker (`#5C5424` to `#574F1F`) so the ink keeps 7:1 on it.
- **The margin rule is gone.** The prototype inset every column 52 px so text cleared it; layout stays out of themes (decision 9), and three rules in from each column's edge it crossed names in the contact list and the chat. The paper is ruled without one.
- Lists are plain without separators, not ruled (above).
- **Not yet:** text set on the 28 px pitch everywhere. The contact list's rows sit between the rules (56 px rows on a 28 px pitch), but other text crosses a rule where its rows are not whole multiples of 28 (the chat, the record); that needs a forced strut and is phase 6's ("Notebook's rules", ARCHITECTURE.md 5). The rules also stay put while a list scrolls.
- `themesDistinct` scores Notebook and Paperback 0.26 on myData's status (0.3 is the bar): both are serif paper themes on the same rows, and what sets Notebook apart there (rules fainter than the metric's edge step, handwritten titles, bare groups, the highlighter) mostly falls in the same blocks. The pair is allowed on that screen alone, with the reason in the test; they pass elsewhere.
