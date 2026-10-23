# Graphite: design rules

`mydata.graphite` 1.0.0, CC0-1.0. One of the six current themes, rebuilt as a full design language. The colours are today's Graphite accent (`design/themes.json`) on a new, quieter frame.

## Personality

A precise tool, like a well-sharpened pencil. Grey on grey, one black, nothing decorative. It should feel like it gets out of the way: dense enough for work, never cramped. The only colour on screen is data (calendar colours, status chips) and the red focus ring.

## Typography

| Role | Font | Size / line height / weight | Notes |
|---|---|---|---|
| Display, titles | Inter | 32, 26, 20 / 1.15 to 1.25 / 600 | Tracking −0.02 em on display sizes, −0.015 on title |
| Heading | Inter | 15 / 1.3 / 600 | |
| Body | Inter | 14 / 1.43 / 400 | Body-strong 550 |
| Label, caption | Inter | 12 / 1.3 / 500; 12 / 1.35 / 400 | Sentence case, never upper case |
| Mono | JetBrains Mono | 12.5 / 1.4 | Ids, versions, times in logs |

- Tabular figures everywhere (`numerals: tabular`), so counts, times and dates line up in columns.
- One family for display and body. Hierarchy comes from weight and size, never from a second face.

## Shape

- Small corners: 3 (checkbox), 5 (buttons, fields, tiles), 6, 8 (cards), 10 (sheets).
- Controls match the small radius (`controls: match`); nothing is a pill.
- Circles only for avatars.

## Density

- Desktop: 30 px controls, 40 px rows, 16 px icons, spacing ×0.85. Compact, but above the 24 px floor.
- Phone: 48 / 56 / 22 / ×1. Phones are never compact.

## Colour use

- Grounds: `bg` #F4F4F2, `surface` white, sidebar a step darker (#EDEDEA). Dark: #141414, #1C1C1C, #181818.
- The accent is near-black (#232323; #E6E6E4 dark). It is the primary button and the selection bar, nothing else.
- Because the accent is almost the ink, **links are underlined** (the preview does this by rule when `link` is within 1.6:1 of `ink`).
- The focus ring stays the repo's red (#B3261E; #F2867E dark). Red against a monochrome screen is the clearest focus signal there is.
- Status colours are Kiwi's, unchanged: they are the only saturated colours apart from calendar data.

## Depth and materials

- Flat. No shadows on cards or rows (`elevation: none`). Menus and popovers get a 1 px `line-strong` edge instead of a shadow.
- Cards have a 1 px `line` hairline (`cards: true`); separators run full width.
- Solid sidebar and toolbar; no blur, no texture.

## Icons

Tabler, light (1.5 px stroke), 16 px, bare (no tiles). The selected sidebar icon stays outlined (`selected: same`); the selection bar carries the state.

## Motion

Crisp: about 90 ms (110 ms × 0.8), no overshoot. A press dims (opacity), never scales. Views fade in; nothing slides.

## Components

| Component | Variant |
|---|---|
| Primary button | Filled black, small radius |
| Secondary button | Outlined with `line-strong` |
| List | Plain, full-width separators |
| Selection | Grey fill (`accent-soft`) plus a 3 px leading bar in `selection` (ink) |
| Sidebar | Flush column with a hairline on its right edge |
| Toolbar | Flat band, hairline below |
| Inputs | Outlined |
| Avatar | Circle, white fill with a `line-strong` ring and ink initials |
| Tabs | Underline |
| Chat | Blocks: full-width, the user's on `surface-sunken` |
| Month | Open cells with a rule between weeks; today a filled black disc |

## Do

- Let alignment and weight do the work. A 600 weight is the loudest thing on screen.
- Keep numbers in tabular figures and right-align counts.

## Don't

- Don't add a second accent colour or tint icons. Grey and black only.
- Don't rely on the grey fill alone for selection: the bar is what passes 3:1.
- Don't remove the underline from links.

## Accessibility

- Text: ink on bg 16.4:1 (light) and 15.0:1 (dark); secondary text 6.4:1 and 6.7:1 or more on every ground.
- Controls: `line-strong` 3.1:1 on bg (light), 4.3:1 (dark). The selection bar is ink, so well above 3:1.
- Increase contrast: secondary text and links go to 7:1, lines become `line-strong` (the `contrast` set in the file).
- Reduced motion: the fade becomes a cut. Reduced transparency: no change (nothing is translucent).
- Every pair in ARCHITECTURE.md 2.2 passes in both modes (the prototype validator).

## Fonts and licences

- **Inter**: SIL Open Font License 1.1, no Reserved Font Name (copyright line checked 2026-10-23 in [google/fonts `ofl/inter`](https://github.com/google/fonts/tree/main/ofl/inter)). Latin subset allowed.
- **JetBrains Mono**: OFL 1.1, no Reserved Font Name ([google/fonts `ofl/jetbrainsmono`](https://github.com/google/fonts/tree/main/ofl/jetbrainsmono)); already bundled.
- **Tabler Icons**: MIT ([licence](https://github.com/tabler/tabler-icons/blob/main/LICENSE)).
- OFL text: https://openfontlicense.org/open-font-license-official-text/

## Feasibility in Flutter

Cheap. No blur, no painter, no extra shape. Inter adds one variable family (Latin subset). The one new widget work is the leading-bar selection, which Grid and Ma reuse.

## Name

"Graphite" is also a macOS accent colour name (not on Apple's trademark list, per Research B). On a Mac, Settings should say "the Graphite theme" so it is not confused with the system accent.

## Changed by the critique (2026-10-23)

Values changed after an independent contrast audit and a distinctness check (prototype scripts, kept outside the repo with the previews). Lightness only; hue and chroma kept.

- `colours.light.line-strong`: #8A8A86 → #878783. 3:1 on bg, surface, surface-raised and sidebar (SC 1.4.11); it was under on one of them
- `contrast.dark.danger`: None → #FF958C. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.dark.info`: None → #92C0F2. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.dark.ink-muted`: #B0B0AD → #C8C8C5. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.dark.success`: None → #88D48B. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.light.danger`: #AC1D17 → #9A0001. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.light.info`: None → #024A92. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.light.ink-muted`: #4D4D4B → #41413F. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.light.success`: None → #105A18. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
- `contrast.light.warning`: None → #784000. increase contrast: 7:1 on every ground, hover, tint and unfocused selection included
