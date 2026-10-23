# Sticker: design rules

`mydata.sticker` 1.0.0, CC0-1.0. One of the six current themes, rebuilt as a full design language. Was Rose (renamed 2026-10-23: a theme is named after its design language, not its colour). The accent is today's Rose (#A63A5B; #EFA3B8 dark).

## Personality

Playful and chunky, like a sticker sheet or a toy. Big rounds, ink outlines, a hard shadow under things you can press, and a little bounce. Cheerful without being childish: the type stays readable and the layout is the same as every other theme.

## Typography

| Role | Font | Size / line height / weight | Notes |
|---|---|---|---|
| Display, title, heading | Fredoka | 40, 30, 24, 18 / 1.1 to 1.3 / 600 | **Display-only**: never under 16 px |
| Body | Nunito | 15 / 1.5 / 500 | Body-strong 800 |
| Label | Nunito | 13 / 1.3 / 800 | |
| Caption | Nunito | 12.5 / 1.4 / 600 | |
| Mono | JetBrains Mono | 13 / 1.4 | |

- Fredoka's rounded terminals carry the personality; Nunito keeps body text readable at 13–15 px.
- Below 16 px the resolver drops Fredoka for Nunito, whatever a role says (ARCHITECTURE.md 1.5).

## Shape

- Round: 6 (checkbox), 12 (tiles, small wells), 16 (fields), 24 (cards), 28 (sheets).
- Buttons, chips, switches, search fields and the floating toolbar are pills.
- Avatars and calendar "today" are circles.

## Density

- Desktop: 40 px controls, 52 px rows, 20 px icons, spacing ×1.15. Fewer rows per screen than Kiwi, on purpose.
- Phone: 48 / 60 / 22 / ×1.15.

## Colour use

- Light: a blush ground (#FFF4F6), white surfaces, plum-black ink (#2A1520), pastel pink fills (`accent-soft` #F8E1E8, avatars #F9D3DE).
- Dark: aubergine grounds (#1C1216, #2A1C22), pale pink ink, outlines in pale rose (#E2C4CF).
- Danger moved to an orange-red (#B4380E light, #FF9A8A dark) so it stays at least 25° of hue from the pink accent; danger still always carries its word.
- Focus ring is blue (#2457C5; #8CB4FF dark), because the repo's red ring would sit too close to the pink accent and selection.

## Palettes

Colour is chosen inside the theme (decided 2026-10-23; `ARCHITECTURE.md` 1.6). "Colour use" above describes the default palette; every palette keeps the same rules, status colours, `danger` and calendar colours, and moves only the accent and the tint of the grounds and ink.

| Palette | Id | Accent (light / dark) | Ground (light / dark) | Character | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|---|---|
| Rose (default) | `rose` | `#A63A5B` / `#EFA3B8` | `#FFF4F6` / `#1C1216` | Blush ground, pink fills, rose accent. | light 7.1 / 6.0 / 6.2; dark 8.8 / 10.1 / 8.6 |
| Mint | `mint` | `#057558` / `#7FD9B8` | `#F0FAF6` / `#0D1814` | Mint ground, pale green fills, deep mint accent. | light 6.8 / 5.3 / 5.7; dark 9.1 / 10.8 / 9.2 |
| Mustard | `mustard` | `#866700` / `#EFCA55` | `#FAF7EE` / `#19150C` | Butter ground, pale yellow fills; the accent is a dark gold in light mode (a bright yellow fails 3:1 on white and white text on it) and true mustard in dark. | light 6.9 / 5.2 / 5.3; dark 9.0 / 11.5 / 10.1 |

Every palette gives all 43 roles in both modes (this style fixes none through `colour-use.same-as`) and passes the contrast pairs of `ARCHITECTURE.md` 2.2 in both modes, with its own increase-contrast set, checked at 7:1 (prototype validator, 2026-10-23). Alternative palettes were made from the default by moving the accent and the tinted roles' hue at the same lightness, then fixing each failing pair by lightness only.

## Depth and materials

- 2 px outlines in `edge` (ink) on cards, buttons, fields and containers (`borders.width: 2`, `colour: edge`).
- A hard "sticker" shadow: 0 4 px 0 in ink, no blur (`elevation: hard`, offset 4). Pressing collapses it and the control sinks into where the shadow was (`press: collapse`, motion `press: sink`).
- **Outline and shadow together is deliberate here**; Kiwi's "never a border and a shadow" rule does not apply.
- Lists carry the outline on the container only (`list: bordered`), with inset separators inside, so long lists don't turn into a wall of boxes.
- Solid grounds; no blur, no texture. The floating toolbar is a solid capsule.

## Icons

Phosphor Bold, 20 px, on tinted tiles (`accent-soft` behind the accent-text colour). The current sidebar section's icon switches to Phosphor Fill.

## Motion

Lively: about 240 ms with a small overshoot (cubic-bezier .34, 1.56, .64, 1) on presses, toasts and sheets; views fade and rise. Reduced motion turns all of it into a short fade.

## Components

| Component | Variant |
|---|---|
| Primary button | "Brutal" in the pill shape: accent fill, 2 px ink outline, sticker shadow |
| Secondary button | 2 px ink outline with the sticker shadow |
| List | Bordered container, inset separators |
| Selection | Pastel tint plus a 2 px `selection` outline (the tint alone is only 1.24:1 on white) |
| Sidebar | Source list: inset rounded rows |
| Toolbar | Floating capsule with outline and shadow |
| Inputs | Outlined |
| Avatar | Circle, pastel fill |
| Tabs | Pill (segmented) |
| Chat | Bubbles; the user's in pastel pink with an ink outline |
| Month | Boxed day cells with outlines; today a filled accent disc |

## Do

- Keep outlines on containers and controls; keep rows inside a container unboxed.
- Use the pastel fills only under ink text.

## Don't

- Don't use the pink accent as large-area fill (backgrounds, banners).
- Don't let Fredoka into body text or anything under 16 px.
- Don't let the bounce run with reduced motion on.

## Accessibility

- Text: ink on bg 15.9:1 (light), 15.6:1 (dark); secondary text 7.1:1 and 7.9:1 or more on every ground.
- White on the accent 6.2:1 (light); dark ink on the dark accent 8.6:1.
- Edges: `edge` 17.1:1 on white, 10.1:1 on the dark surface; `line-strong` 4.3:1 and 5.2:1.
- Selection: the pastel tint fails 3:1, so the 2 px `selection` outline is always drawn (ARCHITECTURE.md 2.3).
- Increase contrast: secondary text 7:1, the accent darkened to give white text 7:1.
- Every pair in ARCHITECTURE.md 2.2 passes in both modes.

## Fonts and licences

- **Fredoka**: SIL OFL 1.1, no Reserved Font Name ([google/fonts `ofl/fredoka`](https://github.com/google/fonts/tree/main/ofl/fredoka), checked 2026-10-23).
- **Nunito**: OFL 1.1, no Reserved Font Name ([`ofl/nunito`](https://github.com/google/fonts/tree/main/ofl/nunito)).
- **JetBrains Mono**: OFL 1.1, already bundled.
- **Phosphor Icons**: MIT ([phosphor-icons/core](https://github.com/phosphor-icons/core)). Bold and Fill are separate fonts, so two subsets.

## Feasibility in Flutter

Cheap at run time: hard shadows are `BoxShadow` with blur 0, outlines are `BorderSide`. The spring is a `SpringDescription`. Two font families plus two Phosphor weights add to the bundle. The `brutal` variant must take the button shape from `button.shape` (pill here); the architecture's description of `brutal` says square, so the variant and the shape need to stay separate fields, as the schema already has them.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept.

- `palettes[rose].contrast.dark.danger`: None → #FF9E8D. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.dark.info`: None → #8EBDEF. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.dark.ink-muted`: None → #E2C6D1. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.dark.success`: None → #83CF86. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.accent`: #9C3153 → #962C4E. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.danger`: #A62A00 → #961700. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.info`: None → #024A92. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.ink-muted`: #644351 → #593846. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.link`: #962B4D → #8B2044. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.success`: None → #105A18. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `palettes[rose].contrast.light.warning`: None → #784000. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `type.roles.heading.stack`: None → display. the heading is set in the display font, as the Typography table says; the schema now has role.stack, and heading defaults to body as in design/tokens.json
