# E-ink: design rules

`mydata.e-ink` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24), for accessibility; ported from the prototype `still` (renamed 2026-10-23). The second accessibility-first theme, after High Contrast.

## Personality

E-paper: ink on paper and nothing else, a reading serif, ruled pages and **nothing that moves**. For e-paper screens, and for anyone who finds motion or colour tiring (migraine, attention, vestibular conditions). Quiet, readable, completely predictable.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Literata | 34 and 28 / 1.2 and 1.25 / 700 |
| Title, heading | Literata | 22 / 1.3 / 700; 18 / 1.35 / 700 (heading in the display stack) |
| Body | Literata | 16 / 1.55 / 400 (body-strong 700) |
| Label, caption | Literata | 14 / 1.35 / 600; 13 / 1.4 / 400 |
| Mono | JetBrains Mono | 14 / 1.45 |

Literata was drawn for long reading on screens; one family keeps the page calm. Body starts at 16 px. Sentence case everywhere.

## Shape

Small, plain corners: 2 (checkbox), 4 (buttons, fields, cards), 6 (sheets). Circles for avatars only.

## Density

An e-reader's page: 44 px controls, 56 px rows, 20 px icons and spacing ×1.1 on the desktop; 48 / 60 / 22 on phones. A size up from High Contrast and Journal, which also keeps the three apart on screen (`themesDistinct`).

## Colour use

- **Two colours per mode: ink and paper.** Greys only where text on them stays at 7:1 or more (hover, sunken, the selection's tint).
- The style fixes most roles to those two (`colour-use.same-as`): `selection`, `line`, `line-strong`, `edge`, `link`, every status colour and `focus-on-danger` are `ink`; `on-selection` and `on-danger` are `bg`; each status `-soft` is `surface-sunken`; `avatar-fill` is `accent-soft`, the grey of a selection's tint. The accent is `ink`, with `bg` on it. So no palette can bring a colour in.
- **Status has no colour.** It is told by its word and icon, as everywhere. `danger` in ink passes the validator's rule as a danger with no colour (a notice: "told by its word alone"), where a coloured danger must stay within 25° of red.
- **Calendars are patterns** (`data-colours: pattern`): four fills (none, light, mid, dark grey), plain or dotted, chosen by the colour's family, always with the calendar's name beside it in lists and its initial before each title in a month cell. In the Mac window the month and the calendar list draw these too, and the calendar list's boxes are ink.
- **Focus is a grey** chosen per palette and mode: the one non-text grey, 3:1 or more against every ground it touches and against the ink of an inverse selection (a black ring round a black row would vanish). On a filled row it is two-tone, with its `surface` keyline.

## Palettes

Every palette is a paper and an ink; nothing else changes.

| Palette | Id | Paper / ink (light; dark) | Character | `ink` / `ink-muted` on `bg`; focus on `bg` / on ink |
|---|---|---|---|---|
| White (default) | `white` | `#FFFFFF` / `#000000`; `#000000` / `#FFFFFF` | Pure black and white | light 21.0 / 12.6, ring 5.4 / 3.9; dark 21.0 / 13.1, ring 5.9 / 3.5 |
| Cream | `cream` | `#F6F0E0` / `#1C1A16`; `#1B1915` / `#F3EDDE` | A warm paper, as an e-reader's sepia | light 15.3 / 10.0, ring 4.6 / 3.3; dark 15.0 / 10.5, ring 4.6 / 3.3 |
| Grey | `grey` | `#E4E4E0` / `#0F0F0F`; `#232323` / `#ECECEC` | The grey of an e-paper screen | light 15.0 / 10.7, ring 4.6 / 3.3; dark 13.3 / 10.4, ring 4.3 / 3.1 |

The palettes' accents are all ink, so the validator notes they are hard to tell apart: on purpose, since a palette here changes the paper. Each palette gives every role the style does not fix (all 43 once resolved) and passes every pair of `ARCHITECTURE.md` 2.2 at 7:1 in both modes (E-ink is accessibility-first: `accessibility.text-contrast: 7:1` in its file). No increase-contrast set: the derived values change nothing that matters.

## Depth and materials

None. No shadows, blur, texture or translucency. Pages are ruled, not boxed (`cards: false`, `list: ruled`): rules between rows, and in the Mac window the Settings groups are ruled too. A rule under page titles. The Mac window's sidebar panel keeps its floating shape, edged in a full point of ink (the Mac's half-point hairline read as a 2.6:1 grey on a 1x screen).

## Icons

Phosphor Regular, bare (no tiles), never coloured. The current section's icon switches to Fill.

## Motion

**None** (`personality: none`, `enter: none`): no transitions, fades, rises or springs, whatever the system says. A press inverts the control for its duration. The loader stays still.

## Components

| Component | Variant |
|---|---|
| Primary button | Filled ink |
| Secondary button | 1 px ink outline |
| Plain button (Cancel, Reject) | Underlined, so it reads as an action beside the outlined ones |
| List | Ruled: full-width rules between rows, no box |
| Selection | Inverse (the row in ink, its text in paper) |
| Sidebar, toolbar | A column and a flat band, each with a rule |
| Inputs | Outlined, 1 px ink; the assistant's composer too, which would otherwise sit on the page as bare text |
| Avatar | A grey circle (`accent-soft`), initials in ink |
| Tabs | Underline, 2 px ink |
| Chat | Bubbles, outlined |
| Month | Open: rules between the weeks; today inverse |

## Do

- Keep every state readable without colour: inverse for selection, words for status, patterns and names for calendars.
- Keep the page still: an update replaces, it never animates.

## Don't

- Don't add colour, even for errors. Danger is a word, an icon and the destructive button's label.
- Don't use greys for text or lines under 7:1 (the focus ring is the one exception).

## Accessibility

- 7:1 for all text (WCAG 2.2 SC 1.4.6) in every palette and both modes; lines and edges are ink.
- No colour anywhere: every role but the calendar colours (drawn as patterns) is a grey, at both contrast levels (`accessibility_themes_test.dart`).
- No motion: every duration is zero (`accessibility_themes_test.dart`).
- Patterns pass "not colour alone" (SC 1.4.1) by construction.
- Two exceptions to 7:1, as in High Contrast: a disabled control, and another month's day in the Mac window, are a 4.5:1 grey.

## Fonts and licences

- **Literata**: SIL OFL 1.1, no Reserved Font Name (https://github.com/google/fonts/tree/main/ofl/literata); bundled since phase 3.
- **JetBrains Mono**: OFL 1.1, bundled.
- **Phosphor Icons**: MIT (https://github.com/phosphor-icons/core), bundled.

## Ported from the prototype

- Colours split into three palettes; most roles fixed to ink and paper by the style; the data colours given (the prototype left them out), never drawn.
- Rows, controls and spacing a size up (44 / 56, ×1.1), so it is not High Contrast in a serif or Journal in black.
- Chat in bubbles and the month open, for the same reason (the prototype had transcript and table). Open for the owner: a transcript and a table may suit an e-reader better; the harness draws both from a copy of this file.
- Danger in ink is now allowed by the validator, with a notice.
