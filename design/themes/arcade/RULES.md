# Arcade: design rules

`mydata.arcade` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `neon` (renamed 2026-10-23).

## Personality

A midnight heads-up display. A near-black ground with a faint grid floor, thin bright edges, **cut corners** on everything, and one neon accent that glows. Daylight mode is "daylight neon": white panels, a deep neon ink for the accent. Dark-first.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title, heading | Chakra Petch (display-only, its 600 alone) | 40 / 1.1, 30 / 1.15, 22 / 1.2, 17 / 1.3; tracking +0.01 to +0.02 em |
| Body | Outfit | 15 / 1.45 / 400 (body-strong 600) |
| Label | Outfit | 12 / 1.3 / 600, **upper case**, 0.1 em tracking |
| Caption | Outfit | 13 / 1.35 / 400 |
| Mono | JetBrains Mono | 13 / 1.4 |

- Tabular figures. Chakra Petch is never used under 16 px (display-only); Outfit stands behind it in the display stack. Outfit has no Vietnamese, so those letters come from the system's font in text (an accepted gap, as for several bundled faces).
- Upper case on labels only, never on a name.

## Shape and density

- Corners are **cut** (a chamfer): 10 px on panels and buttons, smaller on rows (the radius caps the cut), drawn as a shape, so the focus ring and the glow follow the chamfer.
- Regular: 36 px controls, 44 px rows, 18 px icons on the desktop; phones 48 / 56 / 22.

## Colour use

- Dark: `#0A0A14` ground, `#12122A` panels, lavender ink `#EDEBFF`, the neon accent with near-black text on it, a second neon for the edges, a ring of a third so focus never looks like an edge or a selection.
- Light: `#F7F6FF` / white, ink `#14112B`, the accent deepened until white text reads on it, edges in a muted violet.
- The style fixes `edge` to `line-strong` (the bright edge colour) and `selection` to the accent, with `on-accent` on it (`colour-use.same-as`).
- The accent only on the primary, the user's bubbles, the selection bar, links and today; never large fills of it.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Magenta (default) | `magenta` | `#A3007F` / `#FF5FDC` | light 17.1 / 7.8 / 6.8 / 7.3; dark 16.8 / 8.3 / 7.4 / 7.5 |
| Cyan | `cyan` | `#007C89` / `#3FF5FF` | light 17.1 / 7.8 / 5.5 / 4.9; dark 16.8 / 8.3 / 14.7 / 13.5 |
| Lime | `lime` | `#3B7300` / `#B8FF3C` | light 17.1 / 7.8 / 5.5 / 5.8; dark 16.8 / 8.3 / 16.3 / 14.2 |

- **Magenta** is the prototype: magenta accent, cyan edges, a yellow ring (teal by day). **Cyan** has violet edges and a magenta ring by day, yellow at night. **Lime** has violet edges and a magenta ring by day, pink at night (yellow is too near lime to tell from the selection).
- Grounds, ink, status and calendar colours stay; `info` is a blue, never the cyan of an edge. No accent is near `danger`'s red.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values).

## Depth and materials

- Window: a **grid floor** (32 px, the accent at 8%), painted once; reduced transparency turns it plain.
- **In the Mac window each contact is a card on the floor:** the plain contact list draws every row as a cut-corner card with its bright edge and the card gap under it (the theme's lists are cards), as the prototype's list did. The record, the month and the day list stand on the floor itself; their text is checked against the grid composited.
- Elevation: **glow**, on the primary button only (the approval card's Approve keeps a soft glow and nothing else of the theme's depth). Never on text, never on cards.
- Borders: 1 px solid in the edge colour on cards, controls and month cells; inset separators. No blur anywhere.

## Icons

Phosphor Regular, the current section filled, on outlined tiles (cut, like everything else).

## Motion

`crisp` at ×0.9 (about 80 ms); a press dims; panels fade and rise a few pixels. Reduced motion: a fast fade, no rise.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary filled with cut corners and its glow; secondary outline; plain text |
| Lists | Cards: each row a cut-corner panel |
| Selection | Bar: a 3 px accent bar with a faint tint |
| Sidebar, toolbar | A column; a flat band |
| Inputs | Outlined in the edge colour |
| Avatars | Cut-corner squares |
| Tabs | Underline in the accent, upper-case labels |
| Chat | Cut-corner bubbles |
| Month, today | Boxed cells; today an accent ring |

## Do and don't

- Do draw cut corners as a shape, never a clip: the ring and the glow follow the chamfer.
- Do keep the glow to the primary.
- Don't glow or blur text. Don't fill large areas with the accent.
- Don't use the edge colour for anything that means "information".

## Accessibility

- Ink 17.1:1 by day, 16.8:1 at night; secondary text 7.8:1 and 8.3:1.
- The edges are 3:1 or more on every ground, so every control's outline carries its shape alone.
- The ring is 3:1 on every ground and differs from the accent selection by hue in every palette.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Chakra Petch | SIL OFL 1.1, no Reserved Font Name (SemiBold, Latin subset) | https://github.com/google/fonts/tree/main/ofl/chakrapetch |
| Outfit | SIL OFL 1.1, no Reserved Font Name (Latin subset) | https://github.com/google/fonts/tree/main/ofl/outfit |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Phosphor Icons | MIT | https://github.com/phosphor-icons/core |

## Ported from the prototype

- Its colours are the Magenta palette; Cyan and Lime are new.
- Chakra Petch is bundled at its one weight, 600, the only weight the theme sets it in (45 KB).
- A mono role, tabular figures, phone density and plain text buttons are given.
- The contact list's rows as cards in the Mac window are new for the Mac list (the shared lists drew cards already). Today in the Mac month stays a round ring, and a calendar's colour bar a plain bar: cut at the theme's size, the small capsule came out as a lozenge and the 4 px bar as a diamond.
- The prototype's month of separate cut cells is not the Mac month's (one boxed grid in every theme), so `themesDistinct` lets Arcade and Kiwi through on the month at 0.17, and Arcade and Brutalist on myData's status at 0.26 (both box each group in the same place).
- Research B wanted Phosphor Duotone; format 1 has no duotone weight.
- The approval card keeps its 1 px `line-strong` edge (here the bright edge) and its fixed structure.
