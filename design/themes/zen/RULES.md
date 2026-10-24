# Zen: design rules

`mydata.zen` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `ma` (renamed 2026-10-23).

## Personality

Japanese-inspired minimalism: *ma* (間), the meaningful space between things. Lots of room, hairlines instead of boxes, a mincho serif for titles with open letter spacing, washi-white paper, and one quiet colour used sparingly. Referenced respectfully: no pseudo-Japanese ornament, no imitation brush script, no red sun.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Shippori Mincho (display-only, its 600 alone) | 34 / 1.3 and 27 / 1.3, tracking +0.04 to +0.05 em |
| Title, heading | Shippori Mincho | 22 / 1.4, tracking +0.06 em; 16 / 1.5 |
| Body | Manrope | 15 / **1.75** / 400 (body-strong 500), tracking +0.01 em |
| Label, caption | Manrope | 12.5 / 1.5 / 500; 12.5 / 1.6 / 400 |
| Mono | JetBrains Mono | 12.5 / 1.5 |

- The generous line height is part of the look.
- Shippori Mincho's Latin has no Extended-A: in a name such as Dvořák or Łukasz those letters come from Literata, the serif behind it in the display stack, at the same size.
- Sentence case throughout.

## Shape and density

- Almost square: 2 px everywhere, 4 on sheets. Nothing is a pill.
- Airy: 36 px controls, 52 px rows, 18 px icons, spacing ×1.35 on the desktop; phones 48 / 60 / 22 / ×1.25.

## Colour use

- Light: washi `#FAF8F3` for ground and surface alike (flat), ink `#1F1F1F`, a warm grey for secondary text.
- Dark: a sumi ground `#161614`, ink `#ECE8DF`, the colour lightened.
- The colour only on the primary's outline, links, the selection tint and its edge, and the today disc.
- The style fixes `selection` to the accent, with `on-accent` on it (`colour-use.same-as`).
- The focus ring is the repo's red, the only warm colour on screen; in Ochre it is blue, since red sits too near the ochre selection.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Indigo (default) | `indigo` | `#2F4B7C` / `#9DB3DD` | light 15.5 / 6.4 / 8.2 / 8.7; dark 14.8 / 7.2 / 9.3 / 8.0 |
| Moss | `moss` | `#25603F` / `#8FCCA4` | light 15.5 / 6.4 / 7.0 / 7.4; dark 14.8 / 7.2 / 10.6 / 9.1 |
| Ochre | `ochre` | `#6E5214` / `#D8B86E` | light 15.5 / 6.4 / 6.9 / 7.3; dark 14.8 / 7.2 / 10.5 / 9.0 |

- **Indigo** (*ai*) is the prototype; **Moss** (*koke*) a deep green; **Ochre** (*kuchiba*) the brown-gold of fallen leaves. A palette moves the accent, its tint and the link; paper, ink, hairlines, status and calendar colours stay.
- Vermilion was considered and left out: it sits on `danger`'s hue.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values).

## Depth and materials

- None. Hairlines (`width: hairline`) between rows and under the toolbar; no cards, no shadows, solid grounds.
- A washi fibre texture was considered and left out: a custom theme can add it with `pattern: grain`.

## Icons

Phosphor Light, 18 px, bare, few.

## Motion

`calm` at ×1.2 (about 290 ms), fades only, nothing slides. Reduced motion makes the fades instant.

## Components

| Part | Variant |
|---|---|
| Primary button | Outlined in the colour (2 px), small radius; never text alone |
| Secondary, plain | Text |
| List | Plain, full-width hairlines |
| Selection | Tint, with its 2 px edge in the colour (the tint is under 3:1) |
| Sidebar, toolbar | A column; a flat band with a hairline under it |
| Inputs | Underlined |
| Avatar | None: the name is the content |
| Tabs | Underline |
| Chat | Transcript |
| Month, today | Open: hairlines between weeks; today a disc in the colour |

## Do and don't

- Do leave space; when in doubt, remove a line rather than add one.
- Do keep the colour rare enough that it always means "this one".
- Don't add ornament, waves, blossom or faux calligraphy.
- Don't tighten the line height to fit more rows: choose a denser theme.
- Don't fill the primary button: outline is the look, and the approval card's outlined Approve is the invariant's own.

## Accessibility

- Ink 15.5:1 on washi, 14.8:1 on sumi; secondary text 6.4:1 and 7.2:1.
- The primary's 2 px outline and the selection's edge are the colour, well above 3:1. The hairlines between rows are decorative; `line-strong` is 3:1 or more where a control needs an edge, and an underlined field keeps a 3:1 line.
- Increased contrast: the derived 7:1 values (the prototype's own set is no longer needed).

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Shippori Mincho | SIL OFL 1.1, no Reserved Font Name (SemiBold, Latin subset) | https://github.com/google/fonts/tree/main/ofl/shipporimincho |
| Literata | SIL OFL 1.1, bundled (behind it, for Latin Extended-A) | https://github.com/google/fonts/tree/main/ofl/literata |
| Manrope | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/manrope |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Phosphor Icons | MIT | https://github.com/phosphor-icons/core |

## Ported from the prototype

- **Manrope, not Zen Kaku Gothic New, for the text.** Cut to Latin, the latter keeps none of the Japanese it was chosen for (about 2.3 MB a weight with it) and has no Latin Extended-A, so names in lists and records would fall back mid-word; Manrope is bundled already and draws them all.
- Shippori Mincho is bundled at its one display weight, 600 (42 KB), Latin only; Japanese names fall back to the system's font, as the prototype said.
- Its colours are the Indigo palette; Moss and Ochre are new. Indigo's selection tint is a pale indigo (`#E3E7EF`, `#29303F` in dark), not the prototype's neutral grey, so the tint carries the colour, as Moss's and Ochre's do.
- The toolbar is a flat band with a hairline, as its rules always said ("hairlines under the toolbar"), not the native band, under which a scrolled chat ran up to the title's subtitle with nothing between them.
- The approval card keeps its 1 px `line-strong` edge and its fixed structure, as in every theme.
