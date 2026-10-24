# Brutalist: design rules

`mydata.brutalist` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24); ported from the prototype `concrete` (renamed 2026-10-23).

## Personality

Square, heavy and honest. Black ink on off-white, 3 px outlines on every container and control, and hard offset shadows that a press pushes into. Nothing is soft and nothing hides.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, title, heading | Archivo Black (display-only) | 44 / 1.1, 32 / 1.1, 24 / 1.15, 18 / 1.25; its one weight (400, which is black) |
| Body | Space Grotesk | 15 / 1.4 / 400 (body-strong 700) |
| Label | Space Grotesk | 12 / 1.3 / 700, **upper case**, 0.06 em tracking |
| Caption | Space Grotesk | 13 / 1.35 / 500 |
| Mono | JetBrains Mono | 13 / 1.4 |

- Tabular figures. Archivo Black is never used under 16 px (display-only); it has no Vietnamese, `ẞ` or `ʼ`, so Space Grotesk stands behind it in the display stack and draws those.
- Upper case on labels only, never on a name; buttons keep their sentence-case words.

## Shape and density

- Square everywhere (radius 0), buttons included. Today in the Mac month is a square too (the theme's control corners).
- Regular density: 36 px controls, 44 px rows.

## Colour use

- Light: `#F2F0EA` ground, white surfaces, pure black ink and edges, one strong accent.
- Dark: `#121212` / `#1C1C1C`, white ink and edges.
- The style fixes `selection`, `edge`, `line`, `line-strong` and `avatar-fill` to `ink`, and `on-selection` to `surface` (`colour-use.same-as`): every line is the ink, a selection is **inverse video**, an avatar a block of ink with its initials in the ground's colour.
- The focus ring is red, so it is never taken for the black selection or the edges: 3:1 on every ground and on the inverse selection.
- Shadows are black in light; in dark they are the palette's accent (a coloured slab under each box).

## Palettes

| Palette | Id | Accent (light / dark) | `ink` / `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Blue (default) | `blue` | `#0033E6` / `#8FA8FF` | light 18.4 / 10.0 / 7.0 / 8.0; dark 18.7 / 11.2 / 8.2 / 9.2 |
| Yellow | `yellow` | `#111111` / `#FFD60A` | light 16.1 / 8.7 / 14.5 / 18.9; dark 18.7 / 11.2 / 13.3 / 14.9 |
| Green | `green` | `#007A3D` / `#3DDC84` | light 18.4 / 10.0 / 5.2 / 5.5; dark 18.7 / 11.2 / 10.5 / 11.8 |

- **Yellow is a poster:** in light the ground (and so the sidebar) is yellow `#FFE14D` with white boxes and the primary a black block, since no yellow accent reaches 3:1 on white; in dark the accent and the shadows are yellow on black.
- Blue and Green move the accent, its tint, the link and the dark shadow; grounds, ink, status and calendar colours stay.
- Every palette gives every role the style does not fix and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast (derived 7:1 values). No palette's accent is near `danger`'s red, so Approve is never drawn like Delete.

## Depth and materials

- Flat solid grounds; no glass, no texture.
- **Offset** shadows, 5 px, no blur, at full strength, on cards, lists and buttons; a press **collapses** the shadow (the control sinks into it). The primary is `brutal`: the accent, a 3 px edge and the drop.

## Icons

Phosphor Bold, 18 px; the current section's icon filled; tiles are **outlined** squares.

## Motion

`crisp` at ×0.8 (about 70 ms); a press sinks; nothing enters. Reduced motion: nothing moves.

## Components

| Part | Variant |
|---|---|
| Buttons | Primary brutal; secondary outlined; square |
| Lists | Bordered boxes with full 3 px separators |
| Selection | Inverse |
| Avatars | Squares of ink |
| Inputs | Outlined, 3 px |
| Tabs | Boxed, the current one inverse |
| Chat | Blocks: full-width boxes |
| Month | Boxed; today inverse |
| Sidebar, toolbar | A column; a flat band |
| Title rule | Single |

## Do and don't

- Do use borders and shadows together here (Kiwi's "never both" is Kiwi's).
- Do keep one accent: everything else is black, white and grey.
- Don't round anything.

## Accessibility

- Ink on the ground 16.1:1 or more; secondary text 8.7:1 or more; links 5.2:1 or more.
- Edges are the ink itself (21:1 in light), so every control's outline passes 3:1 with room to spare.
- The heavy separators cut the rows per screen; keys and target sizes are unaffected.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Archivo Black | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/archivoblack |
| Space Grotesk | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/spacegrotesk |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Phosphor Icons | MIT | https://github.com/phosphor-icons/core |

## Ported from the prototype

- Its colours are the Blue palette; Yellow and Green are new. Its focus ring is moved in lightness only, to 3:1 on the inverse selection as well.
- The mono is JetBrains Mono, bundled already, not Space Mono: one face fewer for a role the apps hardly draw.
- **In the Mac window** the panes are slabs: the contact list and record, the month and the day list are boxes on the ground (`MacPanel`, the column ground is `bg`), each with its 3 px edge and offset shadow, and no divider between columns, since the ground divides them. Toolbar items (their drop collapsing under a press, none on a disabled one) and form groups cast it too. The Mac widgets take its type, square corners (its switches too), 3 px edges, inverse selection and 3 px rules between a form's rows and a day's events. `themesDistinct` no longer needs an exception for Brutalist and High Contrast on myCalendar's month (0.26 against a bar of 0.18).
- The approval card keeps its 1 px `line-strong` edge (here the ink) and its fixed structure, as in every theme.
