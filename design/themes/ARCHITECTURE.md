# The theme system

The design for the owner's request of 2026-10-23: a theme changes how the whole app looks, each app has its own theme, System is the default, and people can make, import and share themes, as in Warp. A theme is named after its design language and is a **style plus palettes**: colour is a separate choice inside a theme (1.6). The decisions are in `docs/decisions/2026-10-23-themes.md`; where this file and CLAUDE.md differ, CLAUDE.md wins. Nothing here is built yet.

In this folder:
- `theme.schema.json`: the format (JSON Schema 2020-12).
- `<slug>/theme.json` and `<slug>/RULES.md` for the built-ins: System and today's six, rebuilt as full looks and named after their design language (2026-10-23): Kiwi, Hairline (was Graphite), Frosted (was Dusk), Journal (was Plum), Sticker (was Rose) and Paperback (was Amber). These are the phase 3 targets (section 3.1 says what phase 1 reads).

Not in the repo: the 13 other prototype themes (under their new names: High Contrast, E-ink, Large, Terminal, Notebook, Brutalist, Retro Desktop, Swiss, Blueprint, Arcade, Geometric, Zen and Ledger; their prototype folders keep the old names, mapped in `docs/decisions/2026-10-23-themes.md`), the HTML previews and gallery, the example and must-fail files, the prototype validators (`check_theme.py`, the critique's scripts) and Research A and B. They stay with the design session until the owner picks which new themes to build; then a picked theme moves here with its rules.

## 0. What is wrong or missing first

- **Three earlier rules ended with this design** (rewritten 2026-10-23 in `theming.md`, `README.md`, `platforms.md` and CLAUDE.md):
  - the theme was stored on the host and applied to every app and every device (`PUT /appearance`);
  - "a theme replaces three tokens and nothing else";
  - "everything is rounded, almost no borders", now Kiwi's rule only.
- **The biggest cost is not the format but the widgets.**
  - Around 1,300 static token reads have to become context reads: `MyDataSpace.` 698, `MyDataType.` 317, `MyDataSize.` 174, `MyDataMotion.` 213, radii 126.
  - Every component variant has to be built and given goldens.
  - The 60 `MacLook.of` branches have to be split into "is this a Mac window" and "which variant".
- **Palettes multiply the checks.** Six drawn themes with three palettes each are 18 colour sets, each checked in two modes at two contrast levels. Goldens stay bounded: variants are covered once per style, and each palette once on one app scene (5).
- **Nothing proves a theme works in Flutter yet.** The prototype previews are HTML; three batches built three validators that disagreed on six rules (6a). One Dart validator and one preview harness come before any new built-in (phase 3½).
- **Choices are per device and per app, and nothing syncs.** A second Mac starts on System; export and import of a theme file (phase 5) is the way across.
- **Phones get no "Use everywhere".** On iOS and Android, separate apps cannot share a folder without App Groups (paid Apple program) or a content provider. Phones get one theme per app until native phone apps exist (decided).
- **System is only truly native on macOS today.** On Android it waits for the Android pass. On Windows, Linux and the web it is the drawn Kiwi look in the platform's font, until each platform gets its own pass. The picker says so ("System: Kiwi until this platform's own look").

---

## 1. The theme file

### 1.1 Container and envelope

| | |
|---|---|
| File | `.mydatatheme`: a zip holding `theme.json`, optionally `LICENCE.txt`, and at most two images under `images/` (one for light, one for dark). Copy as text or paste gives `theme.json` alone, without images |
| UTI / MIME | `kiwi.mydata.theme`, conforming to `public.zip-archive`; `application/vnd.mydata.theme+zip`. myData.app declares it so a double-click opens myData's import preview |
| `theme.json` | UTF-8 JSON, at most 128 KB, nesting depth at most 8, no duplicate keys |
| Envelope (required) | `format` (integer, 1), `id`, `name`, `version`, `licence`, `frame` |
| Envelope (optional) | `author`, `description`, `based-on`, `preview` |
| Colour (1.6) | `palettes` and `default-palette`, required in a `drawn` file; `colour-use`, optional |
| Ids | Built-ins are `mydata.<slug>`. Everything else is a lower-case UUID. An imported file may never use `mydata.` |
| `based-on` | A built-in id only. Every style group the file leaves out is filled from it; never its palettes, which a drawn file always gives. It is never a fetch |
| `frame` | `system` or `drawn` (section 3.4). A `system` file may give palettes with an accent and nothing else: that is "System, tinted", never applied on macOS and still open for the owner (1.6) |
| `preview` | `blurb` (80 characters) and the first `scene` to show. Pictures are always rendered live; a file never carries a screenshot |
| `licence` | One SPDX id, checked against the SPDX list compiled into the app, or `NOASSERTION` for a theme that is not shared. Export asks for one |
| YAML | The keys map one to one to YAML, so an author can write YAML and convert it. **myData reads only JSON.** YAML aliases allow exponential expansion (the "billion laughs" attack), and JSON parsing is already in the Dart SDK |

### 1.2 Groups

Every style group is optional in a `drawn` file with `based-on`; `palettes` are always required. The schema gives the exact enumerations and bounds; this table is the summary.

| Group | Fields (bounds) | Maps to today |
|---|---|---|
| `palettes[]` (1.6) | Per palette, per mode: the six seeds (`bg`, `surface`, `ink`, `ink-muted`, `accent`, `on-accent`), `overrides` for any of the other 37 roles (1.3), an optional `contrast` set used when the system asks for more contrast (checked at 7:1) and the window gradient's `gradient` stops. Opaque `#RRGGBB`, except `scrim`, `glass-fill` and `glass-stroke`, which may add alpha | The `color.tokens` in `tokens.json` (`kiwi-wash` becomes `avatar-fill`) plus 9 new roles; `themes.json`'s six accents |
| `colour-use` | `same-as`: roles the style always draws in another role's colour, in every palette (Hairline's selection bar is `ink`) | New |
| `type` | `display`, `body` and `mono` font stacks (1.5); `base` 12–19 px; `ratio` 1.067–1.333; `numerals` proportional or tabular; `secondary-italic`; per-role `size` 10–48, `line-height` 1.0–1.8, `weight` 300–900, `tracking` −0.03 to 0.12 em, `case` (`upper` only on `label` and `caption`, with tracking at least 0.04), `stack` (display, body or mono; default display for display-xl, display-lg and title, body for heading, body, body-strong, label and caption, as `tokens.json` today) | `type.groups` (display-xl … mono) |
| `shape` | `corners`: round, continuous, cut or square; `radius` xs 0–8, sm 0–14, md 0–20, lg 0–28, xl 0–36; `controls`: pill or match; `cut-size` 2–12 | `radius` tokens |
| `density` | `preset` (compact, regular, roomy), or per class (`desktop`, `phone`): `control` 24–64, `row` 24–72, `icon` 14–28, `space` ×0.75–1.5 | `size`, `spacing` |
| `borders` | `width`: hairline, 1, 2 or 3; `style`: solid, dashed or double (cards and separators only); `colour`: line, line-strong, edge or accent; `cards`; `controls`; `separators`: none, inset or full; `title-rule`: none, single or double | Implicit today ("no borders") |
| `elevation` | `style`: none, soft, hard, offset, bevel or glow; `strength` 0–1; `offset` 0–8 px; `press`: none or collapse | `shadow` tokens |
| `materials` | `window`: solid, gradient (an angle; its 2–3 stops per mode come from each palette), pattern (dots, grid, ruled, margin-rule, grain or scanlines; spacing 8–64; opacity 0.02–0.12) or image (`images/x.png` or `.jpg`, cover or tile, opacity 0.05–0.6, tint-opacity 0–0.9, blur 0–24 applied at import); `sidebar`: solid, translucent or native; `bars`: solid, translucent or blur; `blur` σ 8–30 | `blur`, `glass-*` |
| `icons` | `set`: lucide, phosphor, tabler, material-outlined, material-rounded, material-sharp, pixelarticons or iconoir; `weight`: thin, light, regular, bold or fill (mapped to the nearest the set has); `selected`: same or fill; `tiles`: tinted, outlined or none | Lucide only (`MacIcons`) |
| `motion` | `personality`: none, calm, standard, crisp or lively; `scale` 0.5–1.5 (slow capped at 500 ms); `press`: none, dim, dim-scale, sink or invert; `enter`: none, fade or fade-rise | `motion.md` |
| `components` | `button` {`primary`: filled, outline, brutal, bevel or push (**never text**); `secondary`: tonal, outline or text; `shape`: pill, rounded, square or cut}; `list`: plain, inset, cards, bordered, ruled or table; `sidebar`: source-list, column, rail or tabs; `toolbar`: native, flat or floating; `inputs`: filled, outlined or underlined; `selection`: tint, solid, inverse, bar, outline or highlighter; `avatar`: circle, rounded, square, shape or none; `tabs`: pill, underline or boxed; `chat`: bubbles, blocks or transcript; `month`: boxed, open or table; `today`: disc, ring or inverse; `data-colours`: colour or pattern | `ButtonVariant` roles stay the app's; the theme picks how each role is drawn |
| `illustration` | flat, line, pixel or ink (falls back to flat until drawn) | KiwiLoader |
| `sound` | `"none"` only (reserved) | — |

**A theme never touches these:**
- wording and sentence case;
- the sections and their order, the order of actions, the keyboard map, the macOS menu bar;
- the window's controls and the system's file, share and permission dialogs;
- `brand`, `skin`, `cream`, `paper` and the logo;
- what a status colour means;
- the **approval card's structure**: it takes the theme's colours and fonts only, with a solid surface, a 1px `line-strong` edge, a filled or outline Approve, and never an image or pattern behind it.

### 1.3 Colour roles, and how missing ones are derived

The resolver works on one palette at a time, in this order:

1. the palette's seeds and overrides;
2. the style's `colour-use.same-as`, for every key whose source has a value;
3. the derivations below, for the roles still missing (a `same-as` key is never derived);
4. `same-as` again, so a key whose source was derived in step 3 takes its value.

At increased contrast the palette's `contrast` set is merged over that result, or the resolver derives the 7:1 values (2.2), and then `same-as` is applied once more, so a role the style fixes follows its source (Journal's `toolbar` follows a darker `bg`). The checks run on the result of the last step. It derives in OKLCH. Each derived value is then moved in lightness only, until its pair in 2.2 passes. Hue and chroma are kept.

| Role | Derived from (when absent) |
|---|---|
| `surface-raised` | `surface` (light); `surface` +0.04 L (dark) |
| `surface-sunken` | `bg` mixed 6% towards `ink` |
| `surface-hover` | `surface` mixed towards `ink` until 1.3:1 against `bg`, `surface` and `surface-raised` (today's rule) |
| `sidebar`, `toolbar` (new) | `bg` / `surface` |
| `line` | `surface` mixed 10% towards `ink` |
| `line-strong` | Mixed towards `ink` until 3:1 against `bg` and `surface` |
| `edge` (new) | `ink` |
| `accent-soft` | `surface` mixed 12% (light) or 22% (dark) towards `accent` |
| `link` (new) | `accent`, adjusted to 4.5:1 against `bg` and `surface` (Geometric's yellow accent sets it explicitly) |
| `selection`, `on-selection`, `selection-inactive` (new) | `accent`, `on-accent`, `surface-sunken` |
| `focus`, `focus-on-danger` (new as a role) | Today's red `focus` adjusted to 3:1; `ink` |
| status and their `-soft` fills, `on-danger` | Today's values, lightness moved to pass on this theme's `surface` |
| `data-*` | Today's values; each must stay within ±30° of its reference hue (a red calendar stays reddish) and at least ΔE<sub>OK</sub> 0.08 from the others. Below 3:1 against `surface`, the 1px `line-strong` edge is drawn, as today |
| `scrim`, `glass-fill`, `glass-stroke`, `shadow`, `avatar-fill` | Today's values, or `ink` and `bg` at today's alphas |

The resolver fills new roles added in later formats from the seeds, so old files keep working. This avoids VS Code's stale-theme problem (Research A).

### 1.4 Density in numbers

| Preset | Desktop control / row / icon / space | Phone control / row / icon / space |
|---|---|---|
| compact | 28 / 28 / 16 / ×0.75 | 44 / 48 / 20 / ×1 (phones are never compact) |
| regular | 36 / 44 / 18 / ×1 | 48 / 56 / 22 / ×1 |
| roomy | 48 / 56 / 22 / ×1.25 | 56 / 64 / 24 / ×1.25 |
| Kiwi today | 44 / 56 / 20 / ×1 (explicit values, so phase 1 is identical) | 44 / 56 / 20 / ×1 |
| System on a Mac | Not from the file: the `macos` tokens (28 control, 24 row, 32 sidebar row) | — |

**Floors, applied at run time whatever the file says:** 24 for a desktop target (WCAG 2.2 SC 2.5.8, with its spacing rule), 44 on iOS, 48 on Android, and 44 for a coarse pointer on any platform. Text field text is at least 16 on phones (`PhoneType`), body at least 12 on desktop, and caption at least 11.

### 1.5 The font and icon catalogue

**Fonts:**
- **Ids:** `figtree`, `plus-jakarta-sans`, `jetbrains-mono`, `inter`, `inter-tight`, `sora`, `manrope`, `fraunces`, `instrument-sans`, `instrument-serif`, `fredoka`*, `nunito`, `literata`, `hanken-grotesk`, `newsreader`, `kalam`*, `archivo-black`*, `space-grotesk`, `space-mono`, `pixelify-sans`*, `atkinson-hyperlegible-next`, `atkinson-hyperlegible-mono`, `azeret-mono`, `chakra-petch`, `outfit`, `jost`, `shippori-mincho`, `zen-kaku-gothic-new`.
- **Generics:** `system`, `system-mono`, `sans`, `serif`, `mono`.
- **Display-only fonts** (marked *) are allowed only in `display` and in roles of 16 px or more. Research B saw Pixelify Sans turn "BE" into "8E" at 12 px.
- **Licences:** all are OFL fonts from Google Fonts' `ofl/` folder with **no Reserved Font Name**, so Latin subsets are allowed. Plex, Andika and Lexend have reserved names and are left out of the catalogue.
- **Never bundled:** SF Pro, New York and Segoe. `system` reaches them only through the OS: `.AppleSystemUIFont` on macOS, `Segoe UI Variable` on Windows (to verify), the fontconfig default on Linux (to verify), Roboto on Android.

**Icons:**
- Each set is a subset icon font cut by a tool extended from `subset_lucide.sh`.
- Every set maps the same semantic ids (`MyDataIcon.contact`, `.calendar`, `.add`, about 90 in all). A test fails if a set misses an id.
- Licences: Lucide ISC; Phosphor, Tabler, Pixelarticons and Iconoir MIT; Material Symbols Apache 2.0. Remix Icon is excluded because of its own licence (January 2026).
- Material Symbols' weight and fill are variable axes, which Flutter's `Icon` sets with `weight` and `fill`. Phosphor ships one font per weight.

### 1.6 Palettes: colour is a separate choice (decided 2026-10-23)

The owner, on the twenty prototypes, said the names made them look like colour changes only (his words are in the decision record). So a theme is named after its design language (Journal, not Plum), and colour is chosen inside it.

- **A theme is a style plus palettes.** The style is every group of 1.2 except colour: type, shape, density, borders, elevation, materials, icons, motion, components and `colour-use`. A palette is the colours, named by colour. The user picks a theme and one of its palettes, per app and per device ("Journal, Ink blue").
- **Fields:**

  | Field | What |
  |---|---|
  | `palettes` | 1 to 8 per theme; built-ins have 2 to 4. Their order is the picker's |
  | `palettes[].id` | Lower kebab case, unique within the theme (`ink-blue`). Device settings store it, so a shipped id never changes |
  | `palettes[].name` | A colour name in sentence case, at most 24 characters ("Ink blue") |
  | `palettes[].light`, `.dark` | The six seeds |
  | `palettes[].overrides` | Any other role per mode; what is left out is derived (1.3) |
  | `palettes[].contrast` | Optional values per mode for increased contrast, checked at 7:1; else derived (2.2) |
  | `palettes[].gradient` | The window gradient's 2–3 stops per mode, when the style's window is a gradient (the style keeps the angle). Left out: `bg` mixed 8% towards `accent`, `bg`, and `bg` mixed 5% towards `ink` |
  | `default-palette` | The palette used when none is chosen, or when the chosen one is gone |
  | `colour-use.same-as` | Roles the style always draws in another role's colour: Hairline's `selection`, `edge` → `ink` and `avatar-fill` → `surface`; Journal's and Paperback's `toolbar` → `bg` and `edge` → `ink`; Kiwi's `sidebar` and `toolbar` → `bg`. A palette may not give these roles, in its overrides or in its `contrast` set; a value may not itself be a key. Applied as 1.3 says: after the palette's values, again after derivation, and again at increased contrast |

- **A palette changes colour roles only** (the 43 roles, the contrast set, the gradient's stops). Fonts, shapes, density, borders, the elevation style, icons, motion and variants are the style's: a palette that needs another shape is another theme.
- **Every palette is checked on its own** (section 2): both modes, normal and increased contrast. A built-in palette that fails breaks the build. In an imported theme, a failing default palette fails the theme (2.4); a failing other palette is left out of the picker, with its reasons as a notice, and the editor offers Fix.
- **Built-in palettes give every role** in both modes (37 overrides beside the seeds), so the built-ins never depend on the resolver's derivation, which phase 1 rebuilds in Dart and may round differently. Custom palettes may give only the seeds.
- **Across a theme's palettes** (a rule for built-ins, seen in the previews): status colours, `danger` and the `data-*` colours stay close to the default palette's, so they mean the same in every palette; a palette moves the accent and the tint of the grounds. Accents of one theme's palettes are at least ΔE<sub>OK</sub> 0.08 apart (a notice).
- **Today's colour themes became palettes:** Graphite is Hairline's default, Dusk Frosted's, Plum Journal's, Rose Sticker's and Amber Paperback's; Kiwi keeps its green. Each built-in's palettes are listed in `theming.md` and described in its `RULES.md`.
- **System has no palettes.** Its colour is the platform's: the macOS accent; Android's wallpaper colours from phase 7; elsewhere, until each platform's pass, Kiwi's default palette. The picker shows no palette row for System.
- **"System, tinted"** (a `system`-frame theme whose palettes give an accent only) **is never applied on macOS:** there the system accent is drawn and such a file's palettes are ignored, since the owner decided System has no alternative colours on macOS. Whether it exists at all is **open for the owner** (phase 5): off macOS, System is Kiwi until each platform's pass, so it would be little more than Kiwi in another palette. If it stays, a tinted palette must give `accent` in both modes (the schema requires it) and is checked as a palette on the grounds System draws on that platform: the accent replaces Kiwi's default palette's `accent`, `link`, `selection` and `accent-soft` are derived again from it (1.3), and the result passes 2.2 like any palette, text at 4.5:1 (`on-accent` on `accent` and `link` included).
- **Custom themes may add palettes** (phase 5). A duplicate copies every palette of its source; the editor adds, renames, removes and reorders palettes and picks the default, up to 8. A palette cannot be added to a built-in in place: duplicate the theme.

---

## 2. Validation: every theme, built-in or imported

One validator in Dart (`mydata_ui/lib/src/theme/validate.dart`) is used by import, the editor, the loader and the tests. `check_theme.py`, kept with the design session, was its prototype. A built-in that fails breaks the build; an imported one is never applied.

### 2.1 Order

1. **The file:**
   - at most 8 MB;
   - zip entries: stored or deflate only, at most 6, at most 16 MB expanded, at most 100 times compression per entry;
   - no absolute paths, `..`, links or nested zips;
   - only `theme.json`, `LICENCE.txt` and `images/<name>.png|jpg` are read. Other entries are never extracted and are listed in a notice.

   The rules and their tests come from the host's contact-import zip reader (`import_files.py`).
2. **Parse:** strict JSON, at most 128 KB, depth at most 8, duplicate keys refused.
3. **`format`:** a newer major version is refused with "Made for a newer myData. Update myData to use it."
4. **Schema** (`theme.schema.json`): types, enumerations and bounds. Unknown keys are dropped with a notice.
5. **Text:**
   - Unicode control (Cc) and format (Cf) characters are stripped, bidi overrides included, then the text is normalised to NFC and length-capped.
   - A name equal to a built-in's, ignoring case, gets " (imported)".
   - An id starting `mydata.` is refused.
6. **References:**
   - `based-on` must be a built-in;
   - font stacks skip unknown ids with a notice and must end in a known font;
   - an icon set or weight the app does not have maps to the nearest one, with a notice;
   - a licence id must be on the SPDX list.
7. **Images** (when present):
   - PNG or JPEG only, checked by magic bytes, not by name;
   - at most 4 MB each, at most 4096 px on a side, at most 16.7 Mpx;
   - decoded once, then re-encoded to PNG at most 2560 px on the long side, which strips EXIF data such as GPS position;
   - the `blur` is applied at this point, once.
8. **Resolve and check, per palette:** the resolver derives each palette's missing roles in both modes, at normal contrast and at increased contrast, then the checks in 2.2 to 2.5 run on each palette. Palette ids must be unique, `default-palette` must name one, and `colour-use.same-as` keys may be neither seeds nor given by a palette (in `overrides` or in a `contrast` set). `same-as` is applied in the order 1.3 gives, at both contrast levels, before any pair is checked.

### 2.2 Contrast pairs (WCAG 2.x relative luminance; alpha composited over its ground first)

| Need | Pairs, in each palette and each mode |
|---|---|
| 4.5:1 text (SC 1.4.3) | `ink` on bg, surface, surface-raised, surface-sunken, surface-hover, accent-soft, selection-inactive, sidebar, toolbar and each status `-soft`; `ink-muted` on bg, surface, surface-raised, surface-sunken and sidebar; `link` on bg, surface and surface-raised; `on-accent` on accent; `on-selection` on selection; `on-danger` on danger; each status colour on surface and on its `-soft` |
| 3:1 non-text (SC 1.4.11) | `line-strong` (and `edge` when borders use it) on bg and surface; `accent` on bg and surface wherever it alone marks a state (a switch that is on, a selection bar); the selection marker (fill, bar or outline) on surface; `focus` on bg, surface, surface-raised and accent-soft, and `focus-on-danger` on danger-soft; each `data-*` on surface, or the edge rule |
| 7:1 | At increased contrast, every text pair of the list above (status words, links, accent drawn as text and labels on fills included). The resolver **derives** these values (lightness only, as for missing roles; a status `-soft` that leaves no room becomes `surface-sunken`); a palette's `contrast` set is an override and must itself pass. Always, in themes marked accessibility-first (High Contrast, E-ink) |
| Grounds that are not flat | **Gradient:** text pairs against every stop. **Pattern:** against the ground with the pattern colour composited at its opacity. A pattern is the window ground: it shows on `bg` and a sidebar that is not a panel, never under `surface` or `surface-raised`, which are opaque. **Image:** against the 1st and 99th luminance percentiles of the image, after tint and opacity, sampled at 64×64. **Glass and translucent bars:** `ink` and `ink-muted` composited over `bg`, `surface`, `ink`, `accent` and `selection` beneath (blur averages text into its ground, but a filled row or button scrolled under a bar is a large block of its colour). At 72% `glass-fill`, Kiwi and Frosted fell to 3.1–3.8:1; they now use 80–84% |
| Kept apart | `accent` and `danger` closer than 25° in hue gives a notice (danger always carries a word); then the approval card's Approve and every filled primary button are drawn in `ink`, not `accent`, so Approve never looks like Delete (Swiss). `danger` stays within 25° of today's red hue: a theme moves its accent, never danger's meaning. `focus` must differ from `selection` by 3:1 or by hue |
| Avatar initials | A new role, `on-avatar` (derived: whichever of `ink` and `surface` is higher on `avatar-fill`), 4.5:1 on `avatar-fill`. The three prototype validators disagreed (one assumed ink initials and failed Brutalist and Swiss, whose avatars are ink-filled) |
| Highlighter selection | The marker is the 3 px `accent` bar (3:1 on surface); the yellow highlight is a text ground (`on-selection` on `selection` 4.5:1) and needs no 3:1 |

### 2.3 Rules beyond colour

- **Focus visible (SC 2.4.7), not obscured (SC 2.4.11), 3:1 against what it touches (SC 1.4.11):** a ring 2–4 px wide (3 px double in High Contrast), offset 0–3. It follows the shape (`OutlinedBorder`, never a clip) and is never covered by a sticky bar. The colour rule stays in `FocusRing`, and System uses the system's ring.
- **Two-tone ring where it touches a fill.** When the ring sits on or inside a filled shape (a solid or inverse selected row, a MonthGrid cell, which today draws the ring inside the selection ring), `FocusRing` adds a 1 px inner keyline in `surface`, so the ring is 3:1 against both sides whatever the fill (WCAG technique C40). The validator then checks `focus` against the grounds only, and checks the fill only where no keyline is drawn. Retro Desktop (both modes) and Geometric (dark) cannot pass with one colour: no lightness of their focus colour is 3:1 against both the dark grounds and the yellow or blue fill.
- **Sizes:** the floors in 1.4, also enforced at run time.
- **Text:** body line height at least 1.25, display at least 1.1. Display-only fonts only at 16 px or more. `upper` only on `label` and `caption`, and never on text that holds a name (a person, an app, a calendar, a file): widgets mark such text and it keeps its own case (decided 2026-10-23; a trial turned "myAssistant" into "MYASSISTANT").
- **Not colour alone (SC 1.4.1):**
  - a `tint` selection also draws a 2 px `selection` edge or bar, unless the tint reaches 3:1 against `surface`;
  - status always has a word;
  - `data-colours: pattern` always shows the calendar's name.
- **System settings win:**
  - reduce motion turns every personality into a `fast` fade (or nothing for `none`);
  - reduce transparency turns glass, translucent bars, patterns and images solid;
  - increase contrast applies the palette's `contrast` set, or the rule `ink-muted`→`ink`, `line`→`line-strong`, borders on every control, materials solid;
  - text size scales every theme.

  These come from `MyDataAccessibilityScope`, which gets an increase-contrast flag:
  - on macOS, from `NSWorkspace.accessibilityDisplayShouldIncreaseContrast` over the existing accessibility channel;
  - elsewhere, from Flutter's `MediaQueryData.highContrast`, which is only updated on iOS 13+ and Android API 34+.
- **No code:** the schema has no field that takes a URL, path, CSS or expression. The only path-like values are the two image slots, which match `^images/[a-z0-9-]+\.(png|jpg)$`. Name, author and description are shown as plain text, never as Markdown or links. Nothing is ever fetched.

### 2.4 Failure

| Where | What happens |
|---|---|
| Built-in theme | The test fails. It never ships |
| Import | A failing palette other than the default: left out of the picker, its reasons listed as a notice. Steps 1–7 failing: refused, with every reason as a sentence ("The dark background and secondary text are 3.8:1; they need 4.5:1."). Contrast failing: the preview shows the reasons and offers **Open a fixed copy in the editor**, which proposes the nearest passing values, never applied unseen. Notices (dropped keys, substituted fonts) are listed but do not block |
| Editor | Each failing pair is a badge on its field, with **Fix**, which moves the edited colour's lightness to the nearest pass. **Fix all** is offered too. Save is disabled while anything fails, with the reason ("2 checks fail. Fix them to save."), as the disabled-control rule says |
| Load at start (library file damaged or edited by hand) | The app uses `based-on`, else System. myData's Appearance shows a Notice naming the theme and the reasons |

### 2.5 Tests that prove "a theme can never break usability"

- Every built-in, every palette, in both modes and at increased contrast, passes 2.2 and 2.3.
- **Theme fuzz:** 500 seeded random files (one to three palettes each) that pass the schema go through the validator. Each one it accepts is pumped on four preview scenes at 1280, 800 and 390 px wide, and must show:
  - no overflow errors;
  - `textContrastGuideline`;
  - `MinimumTapTargetGuideline(size: 24×24)` on desktop, 44 or 48 on phones;
  - a focus ring present and unclipped on a tabbed control (checked from the painter's bounds).
- Must-fail files (the prototype's `bad-*` examples, rewritten as test fixtures in phase 1) are refused with the expected reasons.

---

## 3. Runtime design in Flutter

### 3.1 From build-time constants to a run-time spec

Today `tool/generate_tokens.dart` writes `tokens.g.dart`: static `MyDataColors.light`, `MyDataSpace.s4`, `MyDataType.body` and so on, plus `MyDataThemeSpec`, which carries three colours. In the new design:

- **Source of truth:**
  - `design/themes/<slug>/theme.json`, one file per built-in, in the format above, with its `RULES.md`;
  - `design/tokens.json` keeps the non-themed tokens (the `macos` set, `toast-duration`, widths such as `dialog-width`) and the role list with usages;
  - `themes.json` goes in phase 3. **Phase 1 still reads today's values:** the files here are the full looks, and Frosted's, Sticker's and Paperback's `accent-soft` and Kiwi's link and glass were moved by the contrast audit, so building phase 1 from them would change goldens. Phase 1 generates one built-in style, Kiwi, from `tokens.json`, with today's six colour themes from `themes.json` as its palettes (`kiwi`, `graphite`, `dusk`, `plum`, `rose`, `amber`): that is exactly what the apps draw today. Phase 3 switches the generator to these files: Kiwi keeps its own palettes and the other five move to the themes they now belong to (4.2).
- **Generator:**
  - copies the built-ins into `mydata_ui/assets/themes/`;
  - generates `builtin_kiwi.g.dart`, Kiwi's default palette resolved in light and dark as constants. It is used for the first frame, for tests and when everything else fails, so the app never draws unthemed;
  - `generated_tokens_test.dart` still fails when that file is stale.
- **Model:** `ThemeFile` (the parsed, validated file) goes through `resolve(file, paletteId, brightness, platform, a11y)` and gives a `MyDataLook`, made of one `ThemeExtension` per group:

  ```dart
  class MyDataLook {               // one per brightness, immutable, resolved
    final String themeId; final String? paletteId; // null for System
    final LookFrame frame;          // system | drawn
    final MyDataColors colors;     // existing extension, now built at run time from one palette (43 roles)
    final MyDataTypeScale type;    // TextStyles per role, families resolved, numerals
    final MyDataShape shape;       // radii + corner style → border(ShapeRole) → OutlinedBorder
    final MyDataDensity density;   // control, row, icon, space(n) after platform floors
    final MyDataEdges edges;       // widths, style, colour per place, title rule
    final MyDataElevation elevation; // BoxShadow lists, or a bevel painter
    final MyDataMaterials materials; // ground painter, bar fill, blurAllowed
    final MyDataIconTheme icons;   // font family for set+weight, size, tile style
    final MyDataMotionSpec motion; // durations, curves, press, enter (a11y applied)
    final MyDataVariants variants; // the enums from `components`
  }
  ```

  `lerp` interpolates colours, sizes and shadows and switches enums at t = 0.5, so a theme change can cross-fade (or snap with reduced motion).
- **Access:**
  - `context.colors` and `context.type(role)` keep working;
  - new: `context.space(4)`, `context.density`, `context.shape`, `context.edges`, `context.elevation`, `context.icons`, `context.motion`, `context.variants`, and `context.look` for all of them;
  - `MyDataTheme.data(look)` builds the Material `ThemeData` from the look, as `theme.dart` does today from the constants.
- **The static classes go:**
  - a codemod rewrites `MyDataSpace.sN` → `context.space(N)`, `MyDataType.x` → `context.type(MyDataTypeRole.x)`, `MyDataRadii.x` → `context.shape.radius(x)`, `MyDataSize.*` → `context.density.*`, `MyDataMotion.*` → `context.motion.*`;
  - the `const` qualifiers that block it are removed;
  - `no_literals_test.dart` then also refuses the static classes outside `mydata_ui/lib/src/theme/`.
- **The no-literals rule stays:** literal colours, radii, font names and sizes exist only in theme JSON and the generated fallback.

### 3.2 How a widget gets its variant

- Each component reads its variant from `context.variants` and switches on it inside its own file. No widget accepts style overrides from an app.
- The app keeps choosing roles:
  - Button: `ButtonVariant.filled` (primary), `tonal` (secondary), `plain`, `danger`;
  - ContactList: section letters, multi-select.
- The theme decides how each role is drawn:
  - `brutal` = square, 3 px `edge` border, offset shadow that collapses on press;
  - `push` = the Mac push button.
- **Shape:** every rounded thing asks `context.shape.border(role)` for an `OutlinedBorder`:
  - `RoundedRectangleBorder` for round;
  - `RoundedSuperellipseBorder` for continuous (the iOS and macOS corner; `ContinuousRectangleBorder` is a different curve, and its radius is commonly reported to read about half the same token; measure both in a golden before choosing). Check its look on the web build, where Flutter still draws with Skia;
  - `BeveledRectangleBorder` for cut;
  - `StadiumBorder` for pill;
  - square for square.

  `FocusRing.painter` draws the same border, inflated. That is what keeps cut corners from clipping the ring (Research B, Arcade).
- **Variants and where they are used:**

  | Variant | Used by |
  |---|---|
  | list | ContactList, GroupedList, MultiSelectList, EventRow lists, the sidebar list |
  | selection | every selectable row, MonthGrid, the sidebar |
  | inputs | TextField, Select, pickers, TokenField |
  | avatar | Avatar, ContactHeader |
  | tabs | Tabs, SegmentedControl |
  | chat | myAssistant's message list (in `mydata_assistant`) |
  | month, today | MonthGrid, myCalendar's Mac month view |
  | sidebar, toolbar | the frames (3.4) |
- **Mixed variants:** when a combination needs both (`list: table` with `selection: inverse`), the widget composes them. Combinations are covered pairwise in goldens (5.2).

### 3.3 What changes in existing widgets and apps

- **`theme.dart`:**
  - `MyDataTheme(themeId:, mode:)` becomes `MyDataTheme(look: (light, dark), mode:)`;
  - `MyDataThemes.byId` becomes `ThemeLibrary.resolve(id)`.
- **`AppearanceController`** (mydata_core) becomes `ThemeController(appId:)`:
  - it reads its theme and palette from device settings (section 4) instead of the host;
  - it loads the file from the built-ins or the library and resolves the chosen palette in both modes;
  - it loads the theme's fonts (3.6) before switching;
  - it follows the device file on the existing 2 s poll.
- **`MacLook.of(context)`** is split in two:
  - `MacWindow.of(context)`: macOS, wider than a phone. This is the skeleton, and it is true for every theme;
  - `context.look.frame == LookFrame.system`: the System look.

  The 35 app sites and 25 package sites are audited one by one. Layout branches (three columns, toolbar band) take the first. Visual branches (for example `contacts_view.dart:462` choosing tonal or plainDanger) become variants.
- **Mac widgets** (`MacSourceList`, `MacToolbar`, `MacRecordHeader`, `MacForm`) become the System implementations of `sidebar: source-list`, `toolbar: native` and so on:
  - they read `context.colors` roles instead of `context.mac`;
  - `MacTheme.data` already maps the branded roles onto NSColor, so System looks the same;
  - with a drawn theme the same widgets take that theme's colours, fonts and shapes.
- **Branded widgets** (AppFrame, PageScaffold, Card, GroupedList, and others) gain their variant switches and lose their constants.
- **Each app:**
  - replaces `AppearanceController.forHost` with `ThemeController(appId:)`;
  - adds View > Theme… and its preview scene (4.4);
  - otherwise only the `MacLook` audit and the codemod touch app code.

### 3.4 Frames: System is special

| | System (`frame: system`) | Drawn theme |
|---|---|---|
| macOS | Today's Mac shell, unchanged: NSColor read live, the system accent, `.AppleSystemUIFont`, Mac density, the system focus ring, the native sidebar material, Lucide | The **same native window**: `macos_window_utils`, traffic lights, unified title bar, the Mac menu bar, the Mac skeleton (sidebar, list and record columns, toolbar band). Inside it, everything comes from the theme. `sidebar: source-list` with `materials.sidebar: native` keeps the window's sidebar material under a tint, and `solid` turns it off (a new call in `MacShell.swift`). `toolbar`: native is a transparent band, flat a solid band with a rule, floating a detached capsule. NSAppearance follows the theme's brightness, so traffic lights and menus match |
| Android | Material 3, with wallpaper colours through `dynamic_color` (Apache-2.0; check that it is maintained before depending on it). Until the Android pass: Kiwi in Roboto | The branded skeleton (AppFrame) with the theme |
| Windows, Linux, web | Until each platform's own pass: Kiwi in the platform font (Windows `Segoe UI Variable`; Linux and the web unverified, the web falls back to bundled Figtree). Labelled as such in the picker | The branded skeleton with the theme |
| "System, tinted" (open, 1.6) | Not on macOS: its palettes are ignored and the system accent is drawn. Elsewhere, System with `accent` replaced and checked as a palette, text at 4.5:1 (1.6) | — |

- Duplicating System gives a drawn theme seeded from the Mac shell's current colours and sizes. Its variants are `button.primary: push`, `list: plain`, `sidebar: source-list`, `toolbar: native`. It is a frozen copy and does not follow the system. The editor says so.

### 3.5 Performance

| Effect | Rule | Cost |
|---|---|---|
| Theme switch | One `Theme` change, which rebuilds the tree once. Budget: under 50 ms on an M-series Mac, measured in a profile-mode test | One rebuild |
| Gradient, pattern | Painted once behind the content in a `RepaintBoundary`, never per row. Rules and grids line up with text through a fixed strut (`forceStrutHeight`) | Nil |
| Glass (`bars: blur`) | Toolbar, sidebar (outside macOS) and floating bars only, through one `BackdropGroup` per window with `BackdropFilter.grouped`. Never on rows or cards. Solid on the web, with reduced transparency, and when frame raster time goes over budget for 2 s | Bounded |
| macOS sidebar material | The window's own NSVisualEffectView | Free to Flutter |
| Background image | Decoded once at window size (`ResizeImage`), at most 2560 px on the long side (about 16 MB of texture), one per mode, pre-blurred at import. Content always sits on a surface | Memory |
| Glow | Primary button and selection marker only, never on text | Small |
| Fonts | The core three (Figtree, Plus Jakarta Sans, JetBrains Mono) are in the pubspec as today. Every other catalogue font is a plain asset (Latin subset), loaded with `FontLoader` when a theme that needs it is chosen or previewed, and cached for the session. Estimated 3–4 MB per app, still to be measured; a test fails above 6 MB | Bundle size; a few ms per family |
| Web font fallback | Flutter web fetches missing glyphs from `fonts.gstatic.com` by default (`fontFallbackBaseUrl`). Before the web build shows data, point it at the host | Privacy, not speed |
| Gallery | Previews are live widget trees under `Theme(data:)`, built lazily, at most 6 at once, with no blur (a solid stand-in) and fonts preloaded on focus or hover | Bounded |

### 3.6 Fonts and icons at run time

- `FontCatalogue` maps an id to its asset, its weights or variable range, its licence, and whether it is display-only.
- `ThemeController` awaits `FontCatalogue.ensure(families)` before swapping themes, so text never reflows in a fallback font.
- `registerMyDataLicenses()` registers every bundled font's and icon set's licence.
- Icons go through `MyDataIcon` semantic ids, resolved as `IconData(codePoint, fontFamily: <set-weight>)` from `context.icons`.
- Glyphs drawn as characters (`›`, `$`) for decoration are excluded from semantics.

---

## 4. Storage and UX

### 4.1 Where choices live (per device, per app)

`<home>/device/settings.json` already exists:
- it is written by `FileDeviceStore` with a temporary file and a rename;
- it is shared by every app on the device (none is sandboxed);
- it holds `mode` and `lastTheme` today.

New keys:

```json
{
  "mode": "system",
  "themes": {
    "everywhere": { "theme": "mydata.system" },
    "apps": { "mycontacts": { "theme": "mydata.journal", "palette": "ink-blue" } }
  },
  "lastTheme": "kiwi"
}
```

- **A choice is a theme and a palette:** `{ "theme": <id>, "palette": <palette id> }`. Without `palette`, the theme's `default-palette`. A palette the theme no longer has (a custom theme edited or replaced) falls back to its default, with a one-time Notice in myData's Appearance.
- **A theme without palettes (System) takes no `palette`:** `ThemeController` never writes one for it, and a `palette` found on such a choice (a hand-edited file, an older writer) is ignored and stripped at the next write, with no Notice and no default looked up.
- **Changing theme resets the palette** to the new theme's `default-palette`, in the gallery and in every write: palette ids belong to one theme (Journal's `plum` means nothing to Hairline), so a palette id is never carried from one theme to another.
- **Resolution:** an app's choice is `apps[appId]`, else `everywhere`, else `{ "theme": "mydata.system" }`.
- **Use in this app** sets `apps[appId]` to the theme and palette shown; changing only the palette is the same write.
- **Use everywhere** sets `everywhere` to the theme **and palette** shown and clears `apps`, so every app, including ones installed later, follows both.
- **Mode stays per device** (owner decision 2): one for all apps. The library key leaves room for a per-app mode later; it is not offered now.
- **Library:** `<home>/device/themes/<id>/theme.json` plus its re-encoded images, and `<home>/device/themes/.drafts/` for the editor's unsaved drafts. A development host with `MYDATA_HOME` has its own library.
- **Writes are rare and user-made.** A read-modify-write race between two apps is possible, as for `mode` today. Add a compare-mtime-and-retry to `FileDeviceStore` in phase 2.
- **A theme deleted while in use** makes those apps fall back to its `based-on`, else System, with a one-time Notice in myData's Appearance.

### 4.2 Migrating from the host's theme

- **First start of the new version** (no `themes` key in the file):
  - **on macOS**, every app is set to `mydata.system`, because the Mac shell already ignores the host's theme. Nothing on screen changes;
  - **elsewhere**, `everywhere` is seeded with the host's `/appearance` theme (else `lastTheme`) as Kiwi in that palette (`plum` → `{ "theme": "mydata.kiwi", "palette": "plum" }`), which is what phase 1 draws;
  - in both cases, nothing on screen changes.
- **Phase 3** moves a choice of Kiwi in one of the five old colours to the theme that colour now belongs to (`graphite` → Hairline, `dusk` → Frosted, `plum` → Journal, `rose` → Sticker, `amber` → Paperback, in that palette). That changes the look, which is the point of phase 3, so myData's Appearance says so once ("Plum is now a palette of Journal.").
- **The host:**
  - `GET /appearance` and `/status`'s `theme` are kept for one release, marked deprecated;
  - `PUT /appearance` returns 410 with "Themes are chosen on each device now.";
  - then the route and `state.theme` go, with an API version bump, a regenerated `openapi.json`, and the scope tests updated.

### 4.3 Where the picker lives

| Place | What |
|---|---|
| Every app, macOS | View > Theme… (⌥⌘T, to check against Apple's apps) opens the gallery sheet. It is not a submenu of themes, because `PlatformMenuItem` has no checked state (`mydata_ui` README) |
| Every app, phone | More actions > Theme… |
| myData, Settings > Appearance | **Mode** (Light, Dark, Match system); **Everywhere** (the theme and palette, "Journal, Ink blue", Change…); **Apps**: one row per installed app, showing "Same as everywhere" or its own theme and palette, with Change… and Reset; **Library**: built-ins and custom themes, each with Duplicate, Edit (custom only), Export…, Delete (custom only, a Dialog saying which apps use it); Import… and Paste theme |
| myData, File | Import Theme…, Export Theme… |
| Finder | A double-click on a `.mydatatheme` opens myData's import preview |
| First launch | Not offered. System is the default, and the owner's first-run screen stays short |

### 4.4 The gallery

- **Layout:** a sheet with a grid of live cards. Each card renders **that app's own preview scene**:
  - `ThemePreviewScene` is supplied by each app: its main screen at small scale, on synthetic data (Ava Fictional, `ava@example.org`, events on a fixed demo week);
  - light and dark sit side by side on each card;
  - the card shows the name, author and licence, its palettes as a row of swatches, and a "Contrast checked" or "Fails 2 checks" chip with a word;
  - a card draws the theme in its default palette, or in the palette in use for the current theme.
- **Live preview:**
  - arrow keys move the selection, and **the whole window previews** the theme as you move (as in Warp and Zed);
  - **Palette:** below the grid, the selected theme's palettes as a radio group of swatches, each with its name as text (never colour alone). Tab reaches it after the grid; its arrow keys move between palettes and preview each on the whole window. A theme with one palette, and System, show no row;
  - Return or **Use in myContacts** keeps the theme and palette;
  - **Use everywhere** applies both to every app;
  - Escape or Cancel puts the previous theme and palette back;
  - with reduced motion the preview switches without a fade.
- **myData's version** adds an app switcher above the grid, so a theme can be judged on myCalendar's month or myAssistant's chat before it is applied there.
- **Groups:** System, Built-in, Yours, Imported. Each card has Duplicate and Export in its Menu.

### 4.5 The editor (myData only, desktop)

- **Entry:** Duplicate (from any theme) or Edit (custom themes). Built-ins are never edited in place.
- **Left pane:** groups as Inspector sections, in this order: About (name, author, licence, description), Palettes (a list: add, duplicate, rename, remove, reorder, make default; each palette shows its seeds first, "More colours" opens the 43 roles, light and dark columns, "Make dark from light" derives the dark set), Type, Shape, Density, Surfaces (borders, elevation, materials), Icons, Motion, Components, Checks.
- **Right pane: the live preview.**
  - It shows real preview scenes with an app switcher.
  - Toggles: light or dark, phone width, reduced motion, reduced transparency, increase contrast, larger text.
  - Every change shows at once.
- **Checks:** a badge on each field and the full list in Checks, per palette, each with Fix (2.4). Save is disabled with its reason while anything fails.
- **Keys and drafts:** ⌘Z undoes field by field (the menu bar owns ⌘Z, as for the Inspector), and ⌘S saves. Cancel with changes asks "Discard changes?". Drafts survive a quit (`.drafts/`).
- **Saving** bumps `version` (patch). Apps that use the theme pick it up on their next poll.

### 4.6 Import, export, sharing

- **Import** (File > Import Theme…, drop on Appearance, double-click, or Paste theme):
  - validation (2.1);
  - a preview sheet with the live cards, name, author, licence and description as plain text, and the notices and failures;
  - **Add to library**, **Add and use in this app**, or Cancel;
  - an id already in the library offers "Replace version 1.1.0 with 1.2.0" or "Keep both" (a new id).
  - Nothing applies by itself, and nothing is fetched.
- **Export:**
  - writes `.mydatatheme` (theme.json, the images, and `LICENCE.txt` when the licence needs the text);
  - asks for a licence when it is `NOASSERTION`, suggesting CC0-1.0, CC-BY-4.0 or MIT;
  - an export of a duplicate of a built-in keeps `based-on`, and the built-in's licence applies (hence CC0 in section 6).
- **Copy as text / Paste theme:** the same JSON without images (Slack and Raycast show this is the low-friction route).
- **No online gallery.** A later catalogue could be a GitHub repo with CI running the same validator, installed by downloading the file.

---

## 5. Build plan (each phase usable on its own)

Phases 0 to 3 are the themes foundation and come before the phones (M1b). Phase 5 (custom themes) and later wait; phase 4 waits for the owner's pick.

| Phase | Builds | Usable result | Tests |
|---|---|---|---|
| 0. Decide (done 2026-10-23) | The decision record; this folder; `theming.md`, the `README.md` rules (they became Kiwi's), `platforms.md` and CLAUDE.md rewritten | — | — |
| 1. Run-time spec, no visible change | Format (style and palettes), schema and validator in Dart; built-ins from today's values (Kiwi from `tokens.json` with `themes.json`'s six colours as its palettes; 3.1); the resolver, `MyDataLook` and its extensions; generator changes; the codemod across packages and apps; the `MacLook` split | The apps look exactly as before | Every existing golden **byte-identical**; validator unit tests (examples, `bad-*`; a `same-as` key in a `contrast` set refused; a `same-as` role following its source after derivation and at increased contrast); schema test; contrast of the six; `no_literals` extended to the static classes |
| 2. Per app, per device | `ThemeController`, the `themes` keys, migration, deprecating the host route, the gallery sheet with live preview, View > Theme…, myData's Appearance (apps, Use everywhere, library list), System as default | Each app picks System or Kiwi in one of six palettes (what exists until phase 3); Use everywhere carries the palette | Store and migration tests (macOS → System; elsewhere → host theme); a System choice with a stray `palette` resolves with no Notice and loses it on the next write; Use everywhere and Use in this app never write `palette` for System; changing theme resets the palette to the new default; two apps following one file; a fake-host test that the 410 route is never called; gallery keys (arrows preview, Escape reverts) |
| 3. Design rules | Shape and corner styles with the shape-following focus ring; density presets and floors; borders; elevation; the type catalogue with on-demand fonts; icon sets with semantic ids; motion personalities; the component variants (button, list, selection, inputs, avatar, tabs, sidebar, toolbar, chat, month, today); drawn themes inside the Mac window; the new disabled style. The six rebuilt as full looks from the files in this folder, each with its palettes; the old colours moved to their themes (4.2); `themes.json` retired; the component specs' "Kiwi and Graphite" (today's accent-only Graphite) rewritten as "Kiwi and Hairline" | Kiwi, Hairline, Frosted, Journal, Sticker and Paperback each look distinct, each in 3 palettes | Variant goldens, **one per variant value** in both modes (about 120 images); pairwise golden sets for risky pairs (cut with focus, table with inverse, brutal with collapse press); each palette once on one app scene in both modes (36 images); font budget test; icon-mapping completeness; theme fuzz (2.5) starts here |
| 3½. One harness | One validator (the Dart one) and one preview harness; every prototype the owner picked re-rendered from them in the real app | Like-for-like previews | Each passes in both modes and at increased contrast |
| 4. New built-ins | **Only the ones the owner picks from the gallery** (not picked yet). In batches; proposed order: High Contrast, E-ink, Large, then Terminal, Notebook, Brutalist, Retro Desktop, Swiss, Blueprint, Arcade, Geometric, Zen, Ledger. Each with 2 to 4 palettes; status and `data-*` colours tuned per palette. A theme that does not earn its place in the real app is cut | Up to 20 themes | Every theme: contrast at both levels; 4 app scenes × 2 modes screen goldens (160 images for 20 themes); a review by eye on a Mac before each batch is merged |
| 5. Editor and sharing | Duplicate and edit, with checks and Fix; `.mydatatheme` export and import without images; copy and paste; the UTI and double-click | Make and share themes | Import refusal tests mirroring the host's zip tests; round trip (export → import → the same resolved look); editor: Save disabled with a reason, Fix reaches a pass, drafts survive |
| 6. Materials | Gradients, patterns, glass with `BackdropGroup`, background images in the zip with re-encoding and percentile contrast | Frosted's glass, Notebook's rules, image grounds | Raster-time budget in a profile run with blur on; image caps (size, pixels, magic bytes, EXIF gone); reduced transparency turns everything solid |
| 7. Other platforms' System | Android: Material 3 and dynamic colour. Windows and Linux: each with its platform pass | System means native there | Per-platform screen goldens |

Goldens in total come to about 300 to 400 images, not the 1,600 of every widget in every look. Widget goldens stay at System and Kiwi; variants are covered once each; themes are covered on app screens.

---

## 6a. Found in the critique (2026-10-23), still open

- **One validator, one preview harness.** Three batches built three validators and three preview generators, and they disagreed on six rules (heading's font stack, patterns under surfaces, the highlighter's marker, avatar initials, status colours at increased contrast, the ring on a filled row). Before phase 4, keep one validator (the Dart one, with `critique/contrast.py`'s pairs) and one preview harness, and re-render all twenty from it; today's previews are not like for like, which flatters some themes.
- **Disabled controls at 45% opacity** put a filled button's label at 1.4–1.6:1 in every theme. **Decided 2026-10-23:** a disabled filled button uses `surface-sunken` with an `ink-muted` label (about 4.5:1) in every theme, Kiwi included, from phase 3; other controls keep 45%.
- **Name spoofing.** "A name equal to a built-in's gets (imported)" misses look-alikes ("Кiwi" with a Cyrillic К). Compare the UTS #39 confusable skeleton, not the case-folded string.
- **Numbers in JSON.** Refuse `NaN`, `Infinity` and numbers whose exponent overflows a double; Python's `json` accepts `NaN` by default, so the prototype validators would pass a file the Dart parser refuses.
- **Image decode.** Decode imported images in an isolate with a time limit, and check the header's width and height against the caps before decoding (a 4 MB PNG can declare 30,000 × 30,000).
- **Use everywhere clears every per-app choice.** It has an Undo toast in the gallery and myData's Appearance, since it cannot be told apart from a slip (phase 2).
- **Windows contrast themes and forced colours** are not seen by Flutter (`MediaQueryData.highContrast` is iOS and Android only), so System on Windows cannot follow them yet. Unverified whether a platform channel can read `SPI_GETHIGHCONTRAST`.
- **CJK and other scripts.** Fonts ship as Latin subsets, so Zen's Japanese fonts draw only Latin; Japanese, Devanagari and other names fall back to the OS fonts (and, on the web, to `fonts.gstatic.com` until `fontFallbackBaseUrl` points at the host). Shippori Mincho with Japanese is about 8.6 MB per weight.
- **Editor scope for format 1.** 43 roles × 2 modes plus 12 variant groups is too much for a first editor. Ship seeds, the variant pickers and type, shape and density presets; derive everything else; keep "More colours" behind a disclosure; leave materials and images for phase 6.
- **Previews use synthetic data only:** Ofcom's drama range (+44 7700 900xxx) or NANP 555-0100 to 0199, `example.org`/`.com`/`.net`. The batch-3 preview had "+64 21 555 0100", a normal New Zealand mobile number; it is fixed.

## 6. Decided (2026-10-23)

The owner accepted every recommendation (`docs/decisions/2026-10-23-themes.md`):

1. Built-in theme files are **CC0-1.0**, so a shared duplicate carries no AGPL obligation.
2. Fonts are **bundled as Latin subsets in every app**, with a test that fails above the cap (6 MB per app).
3. **No images in theme files until phase 6**; decide then, after using Frosted and Notebook.
4. **Build new themes in batches** and cut any that does not earn its place in the real app. Which new themes: the owner's pick, still open.
5. **The new disabled style** for filled buttons (6a), in every theme.
6. **Kiwi's visible changes** from the contrast audit (link colour, glass at 80–84%) land in phase 3.
7. **Accent near red:** Approve and filled primary buttons are drawn in `ink` (2.2, "Kept apart").
8. **Upper case** only on label and caption roles that never hold a name (2.3).
9. **Layout stays out of themes.** Folding details or opening the calendar on the day list is a later device accessibility setting.
10. **Mode per device,** not per app; **phones one theme per app,** no Use everywhere, until native phone apps.
11. **View > Theme… on ⌥⌘T,** unless Apple's own apps use it (still to check on a Mac).
12. **Themes are named after their design language,** not a colour (later the same day): Kiwi stays (the house style); Graphite → Hairline, Dusk → Frosted, Plum → Journal, Rose → Sticker, Amber → Paperback; for the prototypes, Contrast → High Contrast, Still → E-ink, Roomy → Large, Prompt → Terminal, Notebook stays, Concrete → Brutalist, Beige → Retro Desktop, Grid → Swiss, Cyanotype → Blueprint, Neon → Arcade, Primary → Geometric, Ma → Zen, Tabular → Ledger.
13. **Colour is a separate choice inside a theme** (1.6): a theme is a style plus 2 to 4 palettes named by colour; the user picks theme and palette per app and per device; System's colour is the system accent, with no alternatives on macOS.

## Sources

- Repo, read 2026-10-23:
  - `design/README.md`, `theming.md`, `platforms.md`, `motion.md`, `tokens.json`, `themes.json`;
  - `app/packages/mydata_ui/README.md`, `lib/src/theme.dart`, `lib/src/mac/mac_theme.dart`;
  - `mydata_core/lib/src/appearance.dart`, `file_device_store.dart`, `platform_io.dart`;
  - `host/src/mydata/service/api.py` (`/appearance`);
  - the apps' `Release.entitlements` (sandbox off).
  - Usage counts come from `grep` over `app/packages/*/lib` and `app/apps/*/lib`.
- Research A and Research B (with the design session, not in the repo), with their sources: Warp, VS Code, Obsidian, Firefox, Raycast, the Windows theme CVEs, Google Fonts licences, the icon licences, and Apple's trademark list.
- WCAG 2.2: https://www.w3.org/TR/WCAG22/ (1.4.1, 1.4.3, 1.4.6, 1.4.11, 2.4.7, 2.4.11, 2.5.8); technique C40, two-colour focus indicator: https://www.w3.org/WAI/WCAG22/Techniques/css/C40
- Impeller is the default renderer on iOS, Android API 29+, and macOS, Windows and Linux from Flutter 3.47; the web still uses Skia: https://docs.flutter.dev/perf/impeller (fetched 2026-10-23)
- `RoundedSuperellipseBorder` (iOS-style continuous corners): https://api.flutter.dev/flutter/painting/RoundedSuperellipseBorder-class.html; its rendering on the web is not documented
- JSON Schema 2020-12: https://json-schema.org/draft/2020-12
- SPDX licence list: https://spdx.org/licenses/
- Flutter (fetched this session unless marked):
  - `MediaQueryData.highContrast`, "only updated on iOS devices running iOS 13+ and Android devices running API 34+": https://api.flutter.dev/flutter/widgets/MediaQueryData/highContrast.html
  - `MinimumTapTargetGuideline({required Size size, required String link})`: https://api.flutter.dev/flutter/flutter_test/MinimumTapTargetGuideline-class.html
  - Web `fontFallbackBaseUrl`, default `https://fonts.gstatic.com/s/`: https://docs.flutter.dev/platform-integration/web/initialization
  - `FontLoader`: https://api.flutter.dev/flutter/services/FontLoader-class.html
  - Not re-fetched: `BackdropGroup`, https://api.flutter.dev/flutter/widgets/BackdropGroup-class.html (cited by Research B); `ThemeExtension`, https://api.flutter.dev/flutter/material/ThemeExtension-class.html; `BeveledRectangleBorder` and `ContinuousRectangleBorder` in `package:flutter/painting`; `Icon.weight` and `Icon.fill`, https://api.flutter.dev/flutter/widgets/Icon-class.html
- `NSWorkspace.accessibilityDisplayShouldIncreaseContrast`: https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldincreasecontrast (not re-fetched)
- The "billion laughs" YAML/XML expansion attack: https://en.wikipedia.org/wiki/Billion_laughs_attack
- `dynamic_color`: https://pub.dev/packages/dynamic_color (its maintenance status is unverified, per Research A)

**Not verified:** the system font family names on Windows and Linux; ⌥⌘T against Apple's apps; the font bundle size; whether `FontLoader` can reload a family; App Groups on a free Apple account.
