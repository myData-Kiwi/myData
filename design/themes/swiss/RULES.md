# Swiss: design rules

`mydata.swiss` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `grid` (renamed 2026-10-23).

## Personality

A Swiss poster (the International Typographic Style): black and white and one colour, big tight grotesk titles set flush left, strict columns and black rules. Confident and orderly; information first, decoration never.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Inter, at its display optical size | 48 / 1.1 and 36 / 1.1, 800, tracking −0.03 em |
| Title | Inter | 28 / 1.15 / 800, tracking −0.02 em (record names, the month) |
| Heading | Inter | 17 / 1.3 / 700 |
| Body | Inter | 15 / 1.47 / 400 (body-strong 700) |
| Label, caption | Inter | 12.5 / 1.3 / 700; 12 / 1.35 / 500 |
| Mono | JetBrains Mono | 12.5 / 1.4 |

- Tabular figures everywhere: day numbers, counts and times line up.
- The large step between title and body (ratio 1.333) is the look.
- Sentence case throughout: no upper-case labels (they turned "myAssistant" into "MYASSISTANT" in the prototype's first render).

## Shape and density

- Square everywhere (radius 0), buttons, fields, avatars and today's mark included.
- Regular on an 8 px grid: 36 px controls, 48 px rows, 20 px icons on the desktop; phones 48 / 56 / 22.

## Colour use

- White grounds, ink `#111111` (`#F2F2F2` on `#0E0E0E` in dark), grey `line`, and **every structural rule in ink** (`borders.colour: edge`): under the toolbar, between list rows, round the month's days, the title rule.
- One colour per palette: the selection bar and its pale tint, the current section, links, the underline of the current tab, switches that are on.
- The style fixes `edge` and `avatar-fill` to `ink` (`colour-use.same-as`): avatars are ink squares with their initials in white (inverted in dark), so the colour stays rare.
- **Red is near danger.** `danger` keeps today's red (a theme moves its accent, never danger's meaning), so in the Red palette the accent sits within 25° of it: the filled primary and Approve are drawn in **ink**, and only a destructive act is red (`ARCHITECTURE.md` 2.2, "Kept apart"). That is also the poster's own rule: black type, one red.
- The focus ring is blue in Red and Green (`#0B50D0`, `#7FA8FF` in dark) and red in Blue, so it never looks like the selection bar.

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Red (default) | `red` | `#D21F17` / `#FF6A5E` | light 18.9 / 7.5 / 6.0 / 5.3; dark 17.2 / 8.1 / 7.6 / 7.2 |
| Blue | `blue` | `#1D3FBB` / `#8EA6FF` | light 18.9 / 7.5 / 8.5 / 8.5; dark 17.2 / 8.1 / 9.3 / 7.6 |
| Green | `green` | `#00704A` / `#4FCB91` | light 18.9 / 7.5 / 6.1 / 6.1; dark 17.2 / 8.1 / 10.6 / 8.5 |

- Blue (an ultramarine) and Green move the accent, its tint, the link and the focus ring; grounds, ink, rules, status and calendar colours stay. In Blue and Green the primary and Approve are the accent, since neither is near red.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (the derived 7:1 values).

## Depth and materials

Flat. No shadows (`elevation: none`), solid grounds everywhere, no glass, no texture. Structure comes from the 1 px ink rules alone.

## Icons

Material Symbols Sharp, regular (400), 20 px, never on tiles; the current section's icon filled.

## Motion

Crisp at ×0.9 (about 80 ms), nothing fades in (`enter: none`); a press inverts the control. Reduced motion: a fast fade.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary filled (ink in Red), secondary 1 px ink outline, plain an underlined word; square |
| Lists | Ruled: ink rules above, between and below |
| Selection | Bar: the colour's pale tint and a 3 px leading bar |
| Sidebar, toolbar | A column; a flat band with an ink rule |
| Inputs | Underlined |
| Avatars | Ink squares |
| Tabs | Underline in the colour |
| Chat | Transcript: each turn under its speaker, beside a rule |
| Month, today | Table: every day ruled in ink; today inverse, an ink block |
| Title rule | Single |

## Do and don't

- Do align everything to the left edge of its column; use size and weight for hierarchy, the colour for the one thing that matters.
- Don't put the colour on large areas, or anywhere it could be read as an error.
- Don't round anything.

## Accessibility

- Ink 18.9:1 on white, 17.2:1 on the dark ground; secondary text 7.5:1 and 8.1:1.
- Every rule and outline is the ink, so controls' edges pass 3:1 with room to spare; the selection bar is 3:1 or more on both surfaces in every palette.
- Increased contrast: the derived 7:1 values for every text pair, links and status words included.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Inter | SIL OFL 1.1, no Reserved Font Name, bundled | https://github.com/google/fonts/tree/main/ofl/inter |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Material Symbols Sharp | Apache 2.0 | https://github.com/google/material-design-icons/blob/master/LICENSE |

## Ported from the prototype

- **Inter, not Inter Tight, for the titles.** Inter's optical size axis reaches 32, and its display cut is the tight grotesk the prototype wanted, so one family is bundled, not two (Inter Tight's Latin subset would add about 0.3 MB).
- **Danger is red again.** The prototype moved it to a crimson magenta so it would not match the red accent; the decided rule keeps danger's hue and draws the primary in ink instead (above).
- Its colours are the Red palette (lightness moved where a pair needed it); Blue and Green are new.
- Square corners are explicit (`radius` all 0), and plain buttons are underlined words, as in the other ruled themes.
- Research B's 6 px bar *above* the page title, and the selection bar's side, cannot be said in format 1; the title rule is a single rule under the title.
- The approval card keeps its 1 px `line-strong` edge and its fixed structure, as in every theme.
