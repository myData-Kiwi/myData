# Kiwi: design rules

`mydata.kiwi` 1.0.0, CC0-1.0. The brand look, written down as a whole language: today's branded frame (`design/README.md`) plus the parts it implied but never fixed. The default for every drawn surface outside System.

## Personality

A light grey room with white furniture in it. Calm and soft, never empty: big confident titles, rounded everything, one green that marks the one thing to do. The user's content is the loudest thing on screen.

## Typography

- Display: Plus Jakarta Sans 700 for `display-xl` (40/46), `display-lg` (30/36) and `title` (22/28), tracking -0.02 to -0.01 em.
- Body: Figtree. `heading` 17/24 600, `body` 15/22, `body-strong` 15/22 600, `label` and `caption` 13/18.
- Mono: JetBrains Mono 13/20 for paths, addresses and copied values.
- Proportional figures; no italic for secondary text; no upper-case labels (sentence case everywhere).

## Shape

- Continuous (squircle-like) corners: xs 6 (checkbox), sm 10 (tiles, sidebar rows), md 14 (inputs), lg 20 (cards, grouped lists), xl 28 (sheets, dialogs, floating bars).
- Controls are pills: buttons, chips, switches, segmented controls and the search field.

## Density

Today's explicit values, so phase 1 stays byte-identical: 44 px controls, 56 px rows, 20 px icons, the 4 px spacing scale at 1x, on desktop and phone.

## Colour use

- Neutral grey grounds (`bg` #F6F6F5 / #111111) and white or near-black cards.
- One filled accent button per screen or card; other actions are tonal (`accent-soft` with accent text) or plain.
- Selection is the `accent-soft` tint; because the tint is only 1.14:1 (light) and 1.31:1 (dark) against `surface`, a 3 px accent bar is drawn at the row's leading edge.
- Status is a tonal chip with a word. Links are accent and underlined.
- Calendar colours are today's `data-*`; data-yellow (1.8:1 on white) gets its 1 px `line-strong` edge.

## Palettes

Colour is chosen inside the theme (decided 2026-10-23; `ARCHITECTURE.md` 1.6). "Colour use" above describes the default palette; every palette keeps the same rules, status colours, `danger` and calendar colours, and moves only the accent and the tint of the grounds and ink. In every palette `sidebar` is `bg`, `toolbar` is `bg` (`colour-use.same-as`).

| Palette | Id | Accent (light / dark) | Ground (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|---|
| Kiwi (default) | `kiwi` | `#4C7814` / `#A9CC4E` | `#F6F6F5` / `#111111` | The brand green on neutral greys. | light 6.2 / 5.0 / 5.2; dark 7.9 / 10.3 / 8.8 |
| Sky | `sky` | `#1666AA` / `#78BFF9` | `#F6F6F5` / `#111111` | A clear blue on the same greys. | light 6.2 / 5.5 / 6.0; dark 7.9 / 9.5 / 8.4 |
| Violet | `violet` | `#6849AB` / `#BCA9F7` | `#F6F6F5` / `#111111` | A soft violet on the same greys. | light 6.2 / 6.2 / 6.7; dark 7.9 / 9.1 / 8.3 |

Every palette gives, in both modes, every role the style does not fix through `colour-use.same-as`: 41 of the 43 (`sidebar` and `toolbar` follow their source; all 43 once resolved). It passes the contrast pairs of `ARCHITECTURE.md` 2.2 in both modes at normal contrast (prototype validator, 2026-10-23). **Increased contrast is derived:** these palettes have no `contrast` set of their own, and the resolver moves the 29 to 30 pairs per palette (both modes together) that fall short of 7:1, by lightness only. Every palette passes at 7:1 (phase 1's Dart validator, `app/packages/mydata_ui/test/theme/builtin_themes_test.dart`, 2026-10-23); one that ever stops passing gets its own `contrast` set. Alternative palettes were made from the default by moving the accent and the tinted roles' hue at the same lightness, then fixing each failing pair by lightness only.

## Depth and materials

- Soft lift (`shadow-1` 0 4 20, strength 0.5) on cards and grouped lists; no borders on cards. In dark mode cards separate by lightness.
- Solid window ground and sidebar. Toolbar and floating bars are glass: `glass-fill` at 82% (light) and 84% (dark) over a 24 px blur (72% let secondary text drop to 3.1:1 over dark content; critique, 2026-10-23), one shared `BackdropGroup` per window, solid with reduced transparency and on the web.

## Icons

Lucide (regular, about 1.75 stroke) at 20 px, on 34 px tinted tiles (`accent-soft` behind an accent glyph) in rows and stats. At most three tile tints on one screen.

## Motion

`standard` personality at 1x: presses dim and scale slightly (`dim-scale`), new content fades and rises 4 px (`fade-rise`). Reduced motion: a fast fade.

## Components

| Part | Variant |
|---|---|
| Buttons | filled pill primary, tonal secondary |
| Lists | inset grouped cards with inset separators |
| Sidebar | flush column with a hairline rule |
| Toolbar | flat band, glass |
| Inputs | outlined, `line-strong` edge |
| Selection | tint plus leading bar |
| Avatars | circles on `avatar-fill` |
| Tabs | pill segments on a sunken track |
| Chat | bubbles (user `accent-soft`, assistant on `surface`) |
| Month | boxed cells with a gap; today a filled disc |

## Do and don't

- Do keep cards borderless and let the soft lift separate them.
- Do keep one filled accent button per card.
- Don't put a card on a card, or a border and a shadow on the same card.
- Don't place an accent tile beside a success tile: the green accent and `success` are close.

## Accessibility

- Text in both modes: ink on bg 16.1:1, ink-muted on surface 6.7:1 (light) and 7.3:1 (dark), on-accent on accent 5.2:1 and 8.8:1, links 5.2:1 and 9.5:1.
- `line-strong` 3.8:1 and 4.2:1; the red focus ring 6.5:1 and 7.0:1, drawn in `ink` on anything already red.
- Every pair in ARCHITECTURE.md 2.2 passes (validator: PASS, 3 notices: the tint bar and data-yellow's edge).

## Font and icon licences

| Asset | Licence | Source (checked 2026-10-23) |
|---|---|---|
| Plus Jakarta Sans | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/blob/main/ofl/plusjakartasans/OFL.txt |
| Figtree | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/blob/main/ofl/figtree/OFL.txt |
| JetBrains Mono | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/blob/main/ofl/jetbrainsmono/OFL.txt |
| Lucide | ISC, plus MIT for the icons derived from Feather (both notices kept) | https://github.com/lucide-icons/lucide/blob/main/LICENSE |

All are already bundled in `mydata_ui`, so Kiwi adds no bundle size.

## Feasibility in Flutter

Cheap. The only costly effect is the glass toolbar, bounded to the bars. Continuous corners are `RoundedSuperellipseBorder`, measured against `ContinuousRectangleBorder` in a golden first (ARCHITECTURE.md 3.2); the prototype preview approximated them with CSS `corner-shape: squircle`, so the curve differs slightly.

## What the format cannot say yet

- Research B's "avatars tinted from `data-*`" needs a per-avatar colour rule; `avatar-fill` is one colour.
- The optional paper grain is a `grain` pattern, which the preview does not draw; Kiwi ships solid.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept. **They apply from phase 3** (decided 2026-10-23): phase 1 must leave every golden byte-identical, so until then Kiwi draws today's values.

- `palettes[kiwi].overrides.dark.glass-fill`: #1A1A1AB8 → #1A1A1AD5. secondary text on a glass bar stays 4.5:1 over any content scrolled beneath (it fell to 3.1:1 over ink)
- `palettes[kiwi].overrides.light.glass-fill`: #FFFFFFB8 → #FFFFFFD0. secondary text on a glass bar stays 4.5:1 over any content scrolled beneath (it fell to 3.1:1 over ink)
- `palettes[kiwi].overrides.light.link`: #4C7814 → #4B7611. link text 4.5:1 on every ground it is drawn on
