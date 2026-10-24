# High Contrast: design rules

`mydata.high-contrast` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24), for accessibility; ported from the prototype `contrast` (renamed 2026-10-23: a theme is named after its design language). The most contrast there is, for people who want it always; the system's Increase contrast setting still raises every other theme by rule.

## Personality

Stark by design. Black and white, every edge drawn, every word at 7:1 or more, nothing told by colour or position alone. One colour, the accent, for the primary action, links and switches that are on.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Atkinson Hyperlegible Next | 40 and 30 / 1.15 and 1.2 / 800 |
| Title, heading | Atkinson Hyperlegible Next | 22 / 1.27 / 800; 18 / 1.33 / 700 |
| Body | Atkinson Hyperlegible Next | 16 / 1.5 / 400 (body-strong 700), 0.01 em tracking |
| Label, caption | Atkinson Hyperlegible Next | 15 / 1.4 / 700; 14 / 1.43 / 400 |
| Mono | Atkinson Hyperlegible Mono | 15 / 1.47 |

- Atkinson Hyperlegible was drawn for low-vision readers: letters that are easily confused (I, l, 1; O, 0) are told apart. Its zero is slashed.
- Body is 16 px on the desktop too; nothing is under 14 px. Tabular figures. Sentence case everywhere.

## Shape

Rounded 8 px (`xs` 4 for the checkbox, `xl` 12 for sheets); controls match `sm`. Circles for avatars.

## Density

Regular plus: 40 px controls, 48 px rows, 20 px icons on the desktop; 48 / 56 / 24 on phones.

## Colour use

- Grounds: white and black (`bg` and `surface` alike). `ink` is black or white; `ink-muted` #2B2B2B or #E0E0E0, 14 to 16:1.
- The style fixes four roles in every palette (`colour-use.same-as`): `selection` and `line-strong` and `edge` are `ink`, `on-selection` is `bg`. So selection is always inverse (black on white, white on black) and every edge is ink, whatever the palette.
- Status colours and every text pair reach 7:1, on their soft fills too. The palette's calendar colours (the ones offered for a calendar myData owns) are moved in lightness (hue kept) so each is 3:1 on the ground and needs no edge. A calendar's own colour from its source is drawn as given, so it can sit near the ground (a dark grey on black): every dot and bar under 3:1 then carries a 1 px ink edge, and in the Mac window's month an all-day chip carries its colour in such a bar, never in its faint tint alone.
- Focus is a magenta-red (#B2055B; #E865AB in dark), 6.8:1 on the ground and 3:1 against the ink of an inverse selection, apart in hue from every accent.

## Palettes

Colour is chosen inside the theme (`ARCHITECTURE.md` 1.6). Every palette keeps the grounds, ink, status, focus and calendar colours above and moves only the accent, its soft tint and the link.

| Palette | Id | Accent (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|
| Blue (default) | `blue` | `#0B3D91` / `#8CB4FF` | A deep blue; a pale blue with black text in dark | light 14.2 / 10.0 / 10.0; dark 15.9 / 10.1 / 10.1 |
| Yellow | `yellow` | `#000000` with yellow text / `#FFD60A` with black text | Signage: black and yellow. In light the primary is black with a yellow label, links a dark amber (#5C4300) | light 14.2 / 9.3 / 16.1; dark 15.9 / 14.9 / 14.9 |
| Cyan | `cyan` | `#00525C` / `#5CE1E6` | A deep teal; cyan with black text in dark | light 14.2 / 8.9 / 8.9; dark 15.9 / 13.4 / 13.4 |

Each palette gives every role the style does not fix (39 of the 43, all 43 once resolved) in both modes, and passes every pair of `ARCHITECTURE.md` 2.2 at 7:1 in both modes (the Dart validator: High Contrast is accessibility-first, so its text is checked at 7:1 at normal contrast too). It has no increase-contrast set: the derived 7:1 values change nothing, since it is there already.

## Depth and materials

None. 2 px edges in `ink` on every control and container (`borders.width: 2`, `cards`, `controls`); full separators; a rule under page titles. Solid everything: no glass, no pattern, no shadow.

## Focus

A **double ring** (`borders.focus: double`): 3 px in `focus`, with a 1 px `surface` keyline between it and the control on every control, not only on fills. It reaches the same 4 px out as every theme's ring, so nothing moves. The Mac widgets keep their own 3 px ring without the keyline.

## Icons

Material Symbols Outlined at weight 600 (`bold`), filled when selected, on outlined tiles. Icons carry a word wherever there is room.

## Motion

`calm` at 0.75x: short fades only; a press dims. Reduced motion: none.

## Components

| Part | Variant |
|---|---|
| Buttons | Filled primary; 2 px outlined secondary; plain ones (Cancel, Reject) underlined; rounded |
| Lists | Bordered |
| Selection | Inverse |
| Avatars | Circles |
| Inputs | Outlined, 2 px |
| Tabs | Boxed, the current one inverse (the Mac segmented control too) |
| Chat | Blocks |
| Month | Boxed (in the Mac window too: its grid and the line beside the day list are 2 px of ink); today inverse |
| Links | Underlined |

## Do

- Draw every boundary; never rely on a fill difference alone.
- Keep text at 7:1, captions and placeholders included.

## Don't

- Don't use translucency, shadows or tints that carry meaning.
- Don't hide labels behind icons.

## Accessibility

- Every text pair at 7:1 (WCAG 2.2 SC 1.4.6, AAA) in every palette and both modes; edges 21:1; the focus ring 3:1 against everything it touches, with its keyline between it and the control.
- One exception, on purpose: a disabled control (and, in the Mac window, another month's day) is drawn in a grey at 4.5:1, so it still reads as disabled. WCAG exempts disabled controls.
- Reduced transparency changes nothing (nothing is translucent). Increased contrast changes nothing (already 7:1).
- `test/theme/accessibility_themes_test.dart` holds these promises.

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Atkinson Hyperlegible Next | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegiblenext |
| Atkinson Hyperlegible Mono | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegiblemono |
| Material Symbols | Apache 2.0 | https://github.com/google/material-design-icons/blob/master/LICENSE |

Both fonts are Latin subsets (`tool/subset_fonts.sh`); neither has Vietnamese or the modifier apostrophe, which come from the platform's font (`fonts_test.dart`, `acceptedGaps`). Material Symbols is cut to the semantic icons as static instances per weight (`tool/subset_icons.sh`).

## Ported from the prototype

- Colours split into three palettes (the prototype had one, with a yellow accent in dark); four roles fixed by the style.
- The double ring the prototype could not express is now `borders.focus: double`.
- Unchanged: type, shape, density, borders, icons, motion and components.

## Not yet

- "Icons always with a label": no field; the apps decide.
