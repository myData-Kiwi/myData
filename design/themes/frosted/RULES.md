# Frosted

`mydata.frosted`, one of the six current themes, rebuilt as a full look. Was Dusk (renamed 2026-10-23: a theme is named after its design language, not its colour). File: `theme.json`.

## Personality

Twilight glass. A still evening sky (a static gradient, periwinkle to blush by day, navy to violet at night) seen through frosted bars, with soft round panels floating on it. Calm, slow, dark-first. Today's Dusk accent (`#3D5AA9` / `#9DB4F2`) is kept, so existing users recognise it.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display, titles, headings | Sora | 40 / 30 / 22 / 17 px, weight 600, tracking −0.02 to 0 em |
| Body, labels, captions | Manrope | 15 px / 1.5, 400; strong 700; label 13, caption 13 |
| Mono (times, numbers you copy) | JetBrains Mono | 13 px |

Proportional numerals. No upper-case labels.

## Shape and density

- Corners: **continuous** (squircle; ARCHITECTURE.md 3.2), radii 6 / 10 / 14 / 18 / 24. Buttons, chips, fields and the composer are **pills**.
- Density: regular (36 px controls), rows 48 px, icons 18 px, spacing × 1.05. Phones: 48 / 56.

## Colour use

- Grounds are blue-tinted, never neutral grey; text is navy ink (`#141A2E` / `#E8ECFA`).
- One filled accent button per screen; the second action is tonal (`accent-soft` with accent text).
- Selection is a tint (`accent-soft`) **plus a 3 px accent bar**, because the tint alone is under 3:1.
- Status and calendar colours were moved in lightness only to pass on the blue grounds (`data-*` at 3:1 on `surface`, yellow keeps its edge).

## Palettes

Colour is chosen inside the theme (decided 2026-10-23; `ARCHITECTURE.md` 1.6). "Colour use" above describes the default palette; every palette keeps the same rules, status colours, `danger` and calendar colours, and moves only the accent and the tint of the grounds and ink.

| Palette | Id | Accent (light / dark) | Ground (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|---|
| Dusk (default) | `dusk` | `#3D5AA9` / `#9DB4F2` | `#E9EDF8` / `#0E1326` | A periwinkle-to-blush sky (navy to violet at night), periwinkle accent. | light 6.5 / 5.5 / 6.5; dark 8.9 / 9.0 / 8.3 |
| Aurora | `aurora` | `#00736F` / `#75D1C5` | `#E2F1F1` / `#00191D` | A teal-to-lilac sky (deep teal to violet at night), teal accent. | light 6.3 / 5.1 / 5.7; dark 8.9 / 10.1 / 8.9 |
| Sand | `sand` | `#8C541F` / `#E2B487` | `#F3ECE4` / `#1E1107` | A sand-to-lavender sky (umber to plum at night), warm brown accent. | light 6.5 / 5.3 / 6.2; dark 8.9 / 9.8 / 8.8 |

Every palette gives all 43 roles in both modes (this style fixes none through `colour-use.same-as`) and passes the contrast pairs of `ARCHITECTURE.md` 2.2 in both modes at normal contrast (prototype validator, 2026-10-23). **Increased contrast is derived:** these palettes have no `contrast` set of their own, and the resolver moves the 34 to 35 pairs per palette (both modes together) that fall short of 7:1, by lightness only. Every palette passes at 7:1 (phase 1's Dart validator, `app/packages/mydata_ui/test/theme/builtin_themes_test.dart`, 2026-10-23); one that ever stops passing gets its own `contrast` set. Alternative palettes were made from the default by moving the accent and the tinted roles' hue at the same lightness, then fixing each failing pair by lightness only.

**The focus ring is blue in Sand** (`#2457C5` / `#8CB4FF`, as in Sticker): its tan selection is 31° and 40° of hue from the red ring at about 1:1, so the ring would be lost on a selected row (`ARCHITECTURE.md` 2.2, "Kept apart"). It is 5.1:1 or more on every ground it touches. Dusk and Aurora keep the red ring, 117° and 160° from their accents.

## Depth and materials

The gradient, the translucent sidebar and the glass come with phase 6 (materials); until then the ground, sidebar and bars are solid `bg`, `sidebar` and `toolbar`.

- Window: a **static linear gradient** at 160°, three stops per mode. Painted once behind everything, never animated.
- Sidebar: **translucent** sidebar colour at about 62% with a blur of 24; on macOS this is the window's own sidebar material tinted (free to Flutter).
- Toolbar and the assistant's composer: **floating glass** (`glass-fill` at 80% light and 83% dark over a 24 blur, a 1 px `glass-stroke`; 72% let secondary text fall to 3.3:1 over dark content), in one shared `BackdropGroup`.
- Content (lists, cards, the record) always sits on a solid `surface`; text never sits on glass alone.
- Elevation: wide soft shadows (strength 0.8) under panels; hairline borders only.

## Icons

Phosphor Regular (MIT), 18 px; the current sidebar section's icon is filled. Tinted icon tiles on `accent-soft`.

## Motion

Calm: about 260 ms (`base` × 1.2) on an ease-in-out curve, no overshoot. Press dims; screens fade in. Reduced motion: a fast fade.

## Component styles

| Component | Variant |
|---|---|
| Buttons | Primary filled pill; secondary tonal pill |
| Lists | Inset groups (rounded panel, inset separators) |
| Sidebar / toolbar | Column on frosted glass / floating glass capsule |
| Fields | Filled, with a 1 px `line-strong` underline |
| Avatars | Circles on `avatar-fill` |
| Tabs | Pill segmented control |
| Chat | Bubbles: the user's in the accent, myAssistant's on `surface` |
| Month / today | Open cells with hairlines / an accent ring |

## Do and don't

- Do keep the gradient faint: text pairs are checked against every stop (`ink-muted` 6.0:1 at the worst light stop, 7.4:1 at the worst dark stop).
- Do turn every glass surface solid with reduced transparency, on the web and when frame raster time goes over budget.
- Don't blur rows, cards or anything inside a list. Don't animate the sky.
- Don't put text directly on the gradient except titles that pass against every stop.

## Accessibility (checked by the prototype validator, both modes)

- `ink` on `bg` 14.7:1 light, 15.6:1 dark; `ink-muted` on `surface` 7.0 / 7.6; white on the accent 6.5:1; accent as text 6.0 / 7.7; the red focus ring 5.6 / 7.4 on `bg` (Dusk); `line-strong` 3.3 / 3.1.
- Every text pair also passes over the glass composited on each gradient stop.
- Reduce transparency: the sidebar, toolbar and composer become `surface`; the gradient stays (it is not transparency) and still passes.

## Fonts and licences

Sora, Manrope and JetBrains Mono: SIL Open Font License 1.1, no Reserved Font Name (`google/fonts` `ofl/sora`, `ofl/manrope`, `ofl/jetbrainsmono`, `OFL.txt`, checked 2026-10-23). Latin subsets allowed. JetBrains Mono is already bundled. Phosphor icons: MIT.

## Feasibility

Glass is the cost. Bounded as the architecture says: blur only on the sidebar (outside macOS), the toolbar and the composer, through one `BackdropGroup`; solid on the web. On macOS the sidebar costs nothing. The gradient is free once painted.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept.

- `palettes[dusk].overrides.dark.glass-fill`: #1B2140B8 → #1B2140D3. secondary text on a glass bar stays 4.5:1 over any content scrolled beneath (it fell to 3.1:1 over ink)
- `palettes[dusk].overrides.dark.line-strong`: #696E86 → #70758D. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `palettes[dusk].overrides.light.glass-fill`: #F3F5FBB8 → #F3F5FBCB. secondary text on a glass bar stays 4.5:1 over any content scrolled beneath (it fell to 3.1:1 over ink)
- `palettes[dusk].overrides.light.line-strong`: #84868F → #81838C. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `type.roles.heading.stack`: None → display. the heading is set in the display font, as the Typography table says; the schema now has role.stack, and heading defaults to body as in design/tokens.json
