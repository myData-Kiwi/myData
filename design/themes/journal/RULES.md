# Journal: design rules

`mydata.journal` 1.0.0, CC0-1.0. Was Plum (renamed 2026-10-23: a theme is named after its design language, not its colour). Today's purple theme, reinterpreted as an editorial language.

## Personality

A literary journal. Paper, ink and rules instead of boxes; a serif for names and titles; generous margins; few icons; words preferred. Quiet authority rather than softness.

## Typography

- Display: Fraunces 600 for `display-xl` (44/1.1), `display-lg` (34/1.12) and `title` (24/1.2), slight negative tracking. Fraunces is for display only: never under 22 px.
- Body: Instrument Sans. `heading` 16/1.4 600, `body` 15/1.55 (a longer line for reading), `label` 13 500, `caption` 13.
- Mono: JetBrains Mono 13.
- Secondary text is italic (`secondary-italic`), never upper case: emails, captions, the job title, the speaker's name in the chat.

## Shape

Square corners (`corners: square`; the 2 px radii are kept for a duplicate that switches to round). Buttons, fields and chips are rectangles.

## Density

Regular with wide margins: 36 px controls, 52 px rows, 18 px icons, spacing at 1.25x. Phones: 48 / 60 / 22.

## Colour use

- Paper ground and surface are the same (#FBF8F4 / #17121A): there are no cards to lift.
- Ink rules (`edge` = ink) between rows and a 4 px double rule under a record's title.
- Plum (`#7A3E8E` / `#D2A6E0`) is used as text and line, almost never as a fill: the outlined primary, links, the selection bar and the selected name.
- Status chips and calendar colours as everywhere; data-orange, -green, -blue, -grey and -yellow are under 3:1 on the paper in light mode, so their 1 px `line-strong` edge is drawn.

## Palettes

Colour is chosen inside the theme (decided 2026-10-23; `ARCHITECTURE.md` 1.6). "Colour use" above describes the default palette; every palette keeps the same rules, status colours, `danger` and calendar colours, and moves only the accent and the tint of the grounds and ink. In every palette `toolbar` is `bg`, `edge` is `ink` (`colour-use.same-as`).

| Palette | Id | Accent (light / dark) | Ground (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|---|
| Plum (default) | `plum` | `#7A3E8E` / `#D2A6E0` | `#FBF8F4` / `#17121A` | Warm paper, plum-black ink, plum accent. | light 6.8 / 6.8 / 7.2; dark 7.9 / 9.0 / 8.5 |
| Ink blue | `ink-blue` | `#20428D` / `#99BCF5` | `#FBF8F4` / `#10141C` | Warm paper, blue-black ink, a deep ink-blue accent; navy grounds at night. | light 6.7 / 8.9 / 9.4; dark 8.0 / 9.5 / 8.8 |
| Forest | `forest` | `#28603A` / `#96CAA0` | `#FBF8F4` / `#0F1611` | Warm paper, green-black ink, a deep green accent; forest grounds at night. | light 6.6 / 7.0 / 7.4; dark 8.0 / 9.8 / 8.6 |

Every palette gives, in both modes, every role the style does not fix through `colour-use.same-as`: 41 of the 43 (`toolbar` and `edge` follow their source; all 43 once resolved). It passes the contrast pairs of `ARCHITECTURE.md` 2.2 in both modes at normal contrast (prototype validator, 2026-10-23). **Increased contrast is unverified:** these palettes have no `contrast` set of their own and rely on the resolver's 7:1 derivation, which does not exist yet; the prototype only counted the pairs it would have to move (22 to 30 per palette, both modes together). Phase 1's built-in test fails on any palette whose derived set does not pass; that palette then gets its own `contrast` set. Alternative palettes were made from the default by moving the accent and the tinted roles' hue at the same lightness, then fixing each failing pair by lightness only.

## Depth and materials

None. Flat paper, solid sidebar and bars, no shadows. Dialogs (not in the preview) get a 1 px ink border on `surface-raised`.

## Icons

Phosphor Light, 18 px, ink-muted, no tiles. Use few; let the label carry the meaning.

## Motion

`calm`: soft fades only (`enter: fade`), presses dim. No movement. Reduced motion: none.

## Components

| Part | Variant |
|---|---|
| Buttons | outlined primary (2 px plum edge, plum text); text secondary |
| Lists | ruled: ink rules between rows, no container |
| Selection | a 3 px plum bar and the name underlined in plum |
| Avatars | none: the name is the content |
| Inputs | underlined |
| Tabs | underline |
| Chat | transcript, set like an interview: the speaker's name in small italic, then the paragraph |
| Month | open cells divided by rules; today a plum ring |
| Title rule | double |

## Do and don't

- Do rely on type and rules for hierarchy; leave space.
- Do keep Fraunces for names and titles only.
- Don't add cards, tiles or shadows.
- Don't use upper-case labels; use italic or the smaller size.

## Accessibility

- Light: ink on paper 16.9:1, italic secondary 6.8:1, links 6.8:1, on-accent 7.2:1. Dark: 15.4, 7.9, 9.0 and 8.5:1.
- `line-strong` is 3:1 or more on bg, surface, surface-raised and the sidebar in both modes (it was 2.90:1 on the sidebar and 2.78:1 on raised panels before the critique); fields also carry their underline in `line-strong`, so the edge passes 1.4.11.
- The selection does not rely on colour: it is a bar and an underline. Italic is never the only cue.
- Validator: PASS, 5 notices (data colours' edges in light mode).

## Font and icon licences

| Asset | Licence | Source (checked 2026-10-23) |
|---|---|---|
| Fraunces (variable: opsz, wght, SOFT, WONK) | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/blob/main/ofl/fraunces/OFL.txt |
| Instrument Sans | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/blob/main/ofl/instrumentsans/OFL.txt |
| JetBrains Mono | SIL OFL 1.1 (bundled already) | https://github.com/google/fonts/blob/main/ofl/jetbrainsmono/OFL.txt |
| Phosphor icons | MIT | https://github.com/phosphor-icons/core/blob/main/LICENSE |

## Feasibility in Flutter

Cheap: no blur, no painters. Fraunces' variable file is about 360 KB with every axis (Research B); a Latin subset with `wght` and `opsz` is smaller. Flutter sets the axes with `FontVariation`.

## What the format cannot say yet

- Italic titles (Research B's "italic titles") and Fraunces' optical size: a role has no `style` or `opsz` field. The preview shows upright Fraunces.
- "Underline the selected name" is the renderer's `bar` variant, not its own value.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept.

- `palettes[plum].overrides.dark.line-strong`: #666069 → #6D6770. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `palettes[plum].overrides.light.line-strong`: #928C91 → #8E888D. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
