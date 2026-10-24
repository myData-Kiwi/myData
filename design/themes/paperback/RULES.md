# Paperback

`mydata.paperback`, one of the six current themes, rebuilt as a full look. Was Amber (renamed 2026-10-23: a theme is named after its design language, not its colour). File: `theme.json`.

## Personality

A reading lamp. Warm paper with a faint grain, a book serif set for long reading, italic secondary text, calm pages and soft warm shadows. Dark mode is lamplight on walnut. Made for reading notes, mail and long contact pages. Today's Amber accent (`#8A5100` / `#F0B45A`) is kept.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, titles, headings | Literata | 40 / 30 / 23 / 19 px, weight 600 |
| Body | Literata | **16 px / 1.55**, 400; strong 600 |
| Labels, captions | Literata | 14 / 13 px |
| Mono | JetBrains Mono | 14 px |

- **Secondary text is italic** (emails under names, captions, notes, placeholders): `secondary-italic: true`.
- Notes and mail bodies are set at a reading measure of about 66 characters (a layout rule in those screens, not a theme value).
- Research B suggested Hanken Grotesk for buttons and labels. **Format 1 cannot say that**: a theme has one body family for every body role. Literata at 14 px semibold reads well on buttons, so the theme stays in one family. A per-role family is a schema question for later.

## Shape and density

- Corners: round, radii 4 / 8 / 10 / 12 / 16. Buttons are rounded rectangles (`radius-sm`), not pills; controls match.
- Density: regular, rows 48 px (more air for the serif), spacing × 1.1.

## Colour use

- Grounds: paper `#F4ECDD`, cream surfaces `#FBF6EC`; walnut `#1A1510` and `#231C15` in dark.
- Ink is warm brown-black (`#2B2118`), never pure black.
- **The accent is the warning hue.** `warning` was moved to an ochre (`#755600` light, `#E2C766` dark) so the two differ, and a warning always carries a word.
- Selection: `accent-soft` tint plus the 3 px accent bar.

## Palettes

Colour is chosen inside the theme (decided 2026-10-23; `ARCHITECTURE.md` 1.6). "Colour use" above describes the default palette; every palette keeps the same rules, status colours, `danger` and calendar colours, and moves only the accent and the tint of the grounds and ink. In every palette `toolbar` is `bg`, `edge` is `ink` (`colour-use.same-as`).

| Palette | Id | Accent (light / dark) | Ground (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|---|
| Amber (default) | `amber` | `#8A5100` / `#F0B45A` | `#F4ECDD` / `#1A1510` | Cream paper, walnut at night, amber accent. | light 6.1 / 5.5 / 6.4; dark 7.6 / 9.8 / 8.9 |
| Sepia | `sepia` | `#5D4432` / `#CDAD95` | `#F2ECE3` / `#181512` | Greyer, browner paper and a muted brown accent, like an old print. | light 6.1 / 7.6 / 9.0; dark 7.6 / 8.7 / 8.0 |
| Linen | `linen` | `#2B616D` / `#8DC6D0` | `#E6EEF2` / `#121719` | Cool grey-blue paper, slate-teal accent. | light 6.0 / 5.9 / 6.9; dark 7.6 / 9.6 / 8.7 |

Every palette gives, in both modes, every role the style does not fix through `colour-use.same-as`: 41 of the 43 (`toolbar` and `edge` follow their source; all 43 once resolved). It passes the contrast pairs of `ARCHITECTURE.md` 2.2 in both modes at normal contrast (prototype validator, 2026-10-23). **Increased contrast is derived:** these palettes have no `contrast` set of their own, and the resolver moves the 24 to 33 pairs per palette (both modes together) that fall short of 7:1, by lightness only. Every palette passes at 7:1 (phase 1's Dart validator, `app/packages/mydata_ui/test/theme/builtin_themes_test.dart`, 2026-10-23); one that ever stops passing gets its own `contrast` set. Alternative palettes were made from the default by moving the accent and the tinted roles' hue at the same lightness, then fixing each failing pair by lightness only.

**The focus ring is blue in Amber and Sepia** (`#2457C5` / `#8CB4FF`, as in Sticker): their amber and brown selection is 28° to 50° of hue from the red ring at about 1:1, so the ring would be lost on a selected row (`ARCHITECTURE.md` 2.2, "Kept apart"). It is 5.1:1 or more on every ground it touches. Linen keeps the red ring, 174° from its teal.

## Depth and materials

The grain is drawn since phase 3 (2026-10-24), behind the branded frame and, in the Mac window, behind the content column; reduced transparency turns it into solid `bg`. Background images wait for phase 6.

- Window: a **grain pattern** (`kind: grain`, opacity 0.04, ink). Painted once from one cached 128 px tile repeated behind the content; never per row.
- Sidebar and bars: solid. No glass anywhere.
- Elevation: soft and warm (`shadow` is a brown, strength 0.6). No borders on cards.

## Icons

Lucide light (1.5 px stroke), 18 px, on tinted tiles.

## Motion

Calm: about 250 ms ease-in-out; press dims; pages fade. Reduced motion: a fast fade.

## Component styles

| Component | Variant |
|---|---|
| Buttons | Primary filled, rounded; secondary tonal |
| Lists | Inset groups |
| Sidebar / toolbar | Solid column / flat band with a rule |
| Fields | **Underlined** (1.5 px `line-strong`), like a ruled form |
| Avatars | Circles |
| Tabs | Underline |
| Chat | **Transcript**: "You" and "myAssistant" labels over each turn, a left rule, no bubbles |
| Month / today | Open cells / a filled accent disc |

## Do and don't

- Do give reading text room: never under 16 px body, never tighter than 1.5.
- Do keep the grain under ±3% luminance; contrast is checked against the ground with the grain composited.
- Don't add borders to cards, or a second accent colour.
- Don't use the accent for warnings.

## Accessibility (checked by the prototype validator, both modes)

- `ink` on `bg` 13.4:1 / 14.1:1; `ink-muted` on `surface` 6.7 / 7.1; white on the accent 6.4:1 and dark on the dark accent 8.9:1; accent as text 6.0 / 9.1; the blue focus ring 5.5 / 8.7 on `bg`; `line-strong` 3.4 / 3.1.
- Italic secondary text keeps `ink-muted` at 6.7:1 or better, so the italic never relies on lightness to read.
- Underlined fields keep a 3:1 underline (`line-strong`).

## Fonts and licences

Literata (variable, opsz and wght, italics) and JetBrains Mono: SIL OFL 1.1, no Reserved Font Name (`google/fonts` `ofl/literata`, `ofl/jetbrainsmono`, checked 2026-10-23). Literata is the largest font in this batch (Research B: 955 KB with all axes); a Latin subset with the wght axis only and the italic is needed. Lucide: ISC.

## Feasibility

Cheap. The grain tile is drawn once. The only cost is Literata's size.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept.

- `palettes[amber].overrides.dark.line-strong`: #71695E → #776E63. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `palettes[amber].overrides.light.line-strong`: #8B857E → #87817B. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `type.roles.heading.stack`: None → display. the heading is set in the display font, as the Typography table says; the schema now has role.stack, and heading defaults to body as in design/tokens.json
