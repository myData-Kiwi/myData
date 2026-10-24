# The theme system

The design for the owner's request of 2026-10-23: a theme changes how the whole app looks, each app has its own theme, System is the default, and people can make, import and share themes, as in Warp. A theme is named after its design language and is a **style plus palettes**: colour is a separate choice inside a theme (1.6). The decisions are in `docs/decisions/2026-10-23-themes.md`; where this file and CLAUDE.md differ, CLAUDE.md wins. **Phase 1 is built** (2026-10-23, section 3.1, "As built"): the format, schema check, validator, resolver and `MyDataLook` in `mydata_ui/lib/src/theme/`, with nothing changed on screen. The rest is design.

In this folder:
- `theme.schema.json`: the format (JSON Schema 2020-12).
- `<slug>/theme.json` and `<slug>/RULES.md` for the built-ins: System and today's six, rebuilt as full looks and named after their design language (2026-10-23): Kiwi, Hairline (was Graphite), Frosted (was Dusk), Journal (was Plum), Sticker (was Rose) and Paperback (was Amber). These are the phase 3 targets (section 3.1 says what phase 1 reads).
- Phase 4's new built-ins as each is ported (5, "Phase 4 as built"): High Contrast, E-ink and Large (batch 1), Terminal, Notebook, Brutalist and Retro Desktop (batch 2), Swiss, Blueprint, Arcade, Geometric and Zen (batch 3) and Ledger (batch 4), all 2026-10-24.

Not in the repo: the prototype themes as drawn before their port (all 13 are ported, 2026-10-24: High Contrast, E-ink, Large, Terminal, Notebook, Brutalist, Retro Desktop, Swiss, Blueprint, Arcade, Geometric, Zen and Ledger; their prototype folders keep the old names, mapped in `docs/decisions/2026-10-23-themes.md`), the HTML previews and gallery, the example and must-fail files, the prototype validators (`check_theme.py`, the critique's scripts) and Research A and B. The owner picked all of them (2026-10-23): each moves here with its rules and 2 to 4 palettes as it is built, ported to the palette format and the Dart validator rather than copied.

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
- **Nothing proves a theme works in Flutter yet.** The prototype previews are HTML; three batches built three validators that disagreed on six rules (6a). One Dart validator and one preview harness come before any new built-in (phase 3½). Both exist since 2026-10-24 (5, "Phase 3½, the preview harness as built").
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
| `frame` | `system` or `drawn` (section 3.4). A `system` file may give palettes with an accent and nothing else: that is "System, tinted", never on macOS (decided 2026-10-23) and possible elsewhere later (1.6) |
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
| `borders` | `width`: hairline, 1, 2 or 3; `style`: solid, dashed or double (cards and separators only); `colour`: line, line-strong, edge or accent; `cards`; `controls`; `separators`: none, inset or full; `title-rule`: none, single or double; `focus`: single (2 px at 2 px) or double (3 px at 1 px over a `surface` keyline on every control; phase 4, High Contrast) | Implicit today ("no borders") |
| `elevation` | `style`: none, soft, hard, offset, bevel or glow; `strength` 0–1; `offset` 0–8 px; `press`: none or collapse | `shadow` tokens |
| `materials` | `window`: solid, gradient (an angle; its 2–3 stops per mode come from each palette), pattern (dots, grid, ruled, margin-rule, grain or scanlines; spacing 8–64; opacity 0.02–0.12) or image (`images/x.png` or `.jpg`, cover or tile, opacity 0.05–0.6, tint-opacity 0–0.9, blur 0–24 applied at import); `sidebar`: solid, translucent or native; `bars`: solid, translucent or blur; `blur` σ 8–30 | `blur`, `glass-*` |
| `icons` | `set`: lucide, phosphor, tabler, material-outlined, material-rounded, material-sharp, pixelarticons or iconoir; `weight`: thin, light, regular, bold or fill (mapped to the nearest the set has); `selected`: same or fill; `tiles`: tinted, outlined or none | Lucide, Tabler and Phosphor bundled (`MyDataIcon`, phase 3), Material Symbols Outlined and Rounded and Pixelarticons (phase 4); the others drawn in Lucide, with a notice |
| `motion` | `personality`: none, calm, standard, crisp or lively; `scale` 0.5–1.5 (slow capped at 500 ms); `press`: none, dim, dim-scale, sink or invert; `enter`: none, fade or fade-rise | `motion.md` |
| `components` | `button` {`primary`: filled, outline, brutal, bevel or push (**never text**); `secondary`: tonal, outline or text; `plain`: text or underline (added 2026-10-24 for the accessibility themes); `shape`: pill, rounded, square or cut}; `list`: plain, inset, cards, bordered, ruled or table; `sidebar`: source-list, column, rail or tabs; `toolbar`: native, flat or floating; `inputs`: filled, outlined or underlined; `selection`: tint, solid, inverse, bar, outline or highlighter; `avatar`: circle, rounded, square, shape or none; `tabs`: pill, underline or boxed; `chat`: bubbles, blocks or transcript; `month`: boxed, open or table; `today`: disc, ring or inverse; `data-colours`: colour or pattern | `ButtonVariant` roles stay the app's; the theme picks how each role is drawn |
| `illustration` | flat, line, pixel or ink (falls back to flat until drawn) | KiwiLoader |
| `accessibility` | What the style promises beyond the rules every theme keeps: `text-contrast` 4.5:1 or 7:1 (every text pair checked at 7:1 at normal contrast too: accessibility-first); `faint-text` system or readable (a disabled item and another month's day in the Mac window at 4.5:1); `targets` platform or control (every target at least the control height, the Mac window's own widgets included: Large). Left out, nothing more; a file based on another keeps its promises (added 2026-10-24: they were keyed on the built-ins' ids) | New |
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
| `stripe` (new, 2026-10-24) | Halfway from `surface` to `surface-sunken`, so a table's header band (on `surface-sunken`) stays the stronger. Only a `table` list reads it (its zebra stripes); a built-in gives it only where its lists are tables |
| `surface-hover` | `surface` mixed towards `ink` until 1.3:1 against `bg`, `surface` and `surface-raised` (today's rule) |
| `sidebar`, `toolbar` (new) | `bg` / `surface` |
| `line` | `surface` mixed 10% towards `ink` |
| `line-strong` | Mixed towards `ink` until 3:1 against `bg` and `surface` |
| `edge` (new) | `ink` |
| `accent-soft` | `surface` mixed 12% (light) or 22% (dark) towards `accent` |
| `link` (new) | `accent`, adjusted to 4.5:1 against `bg` and `surface` (Geometric's yellow accent sets it explicitly) |
| `selection`, `on-selection`, `selection-inactive` (new) | `accent`, `on-accent`, `surface-sunken` |
| `focus`, `focus-on-danger` (new as a role) | Today's red `focus` adjusted to 3:1 on every ground a ring touches; where it would be lost on the selection (2.2, "Kept apart"), today's blue `info` instead (Sticker's and Paperback's ring); `ink` when neither works. `focus-on-danger`: `ink` |
| status and their `-soft` fills, `on-danger` | Today's values, lightness moved to pass on this theme's `surface` |
| `data-*` | Today's values; each must stay within ±30° of its reference hue (a red calendar stays reddish) and at least ΔE<sub>OK</sub> 0.08 from the others. Below 3:1 against `surface`, the 1px `line-strong` edge is drawn, as today |
| `scrim`, `glass-stroke`, `shadow`, `avatar-fill` | Today's values |
| `glass-fill` | The palette's `surface` at today's opacity (72%), made more opaque until `ink` and `ink-muted` read at 4.5:1 over everything that scrolls beneath (2.2) |

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
- **Ids:** `figtree`, `plus-jakarta-sans`, `jetbrains-mono`, `inter`, `inter-tight`, `sora`, `manrope`, `fraunces`, `instrument-sans`, `instrument-serif`, `fredoka`*, `nunito`, `literata`, `hanken-grotesk`, `newsreader`, `kalam`*, `archivo-black`*, `space-grotesk`, `space-mono`, `pixelify-sans`*, `atkinson-hyperlegible-next`, `atkinson-hyperlegible-mono`, `azeret-mono`, `chakra-petch`*, `outfit`, `jost`, `shippori-mincho`*, `zen-kaku-gothic-new`. Chakra Petch and Shippori Mincho are bundled at their one display weight (600), so they are display-only too (batch 3).
- **Generics:** `system`, `system-mono`, `sans`, `serif`, `mono`.
- **Display-only fonts** (marked *) are allowed only in `display` and in roles of 16 px or more. Research B saw Pixelify Sans turn "BE" into "8E" at 12 px.
- **Licences:** all are OFL fonts from Google Fonts' `ofl/` folder with **no Reserved Font Name**, so Latin subsets are allowed. Plex, Andika and Lexend have reserved names and are left out of the catalogue.
- **Never bundled:** SF Pro, New York and Segoe. `system` reaches them only through the OS: `.AppleSystemUIFont` on macOS, `Segoe UI Variable` on Windows (to verify), the fontconfig default on Linux (to verify), Roboto on Android.

**Icons:**
- Each set is a subset icon font, one per weight, cut by `tool/subset_icons.sh` from `tool/icons.json`. **As built (phase 3):** Lucide (one weight), Tabler (thin, light, regular; no bold, so a bold Tabler theme draws regular) and Phosphor (light, regular, bold, fill). **Phase 4:** Material Symbols Outlined and Rounded (light 300, regular 400, bold 600, and fill at 400), static instances at optical size 20 cut from the variable fonts at a pinned commit (names from the fonts' own `.codepoints`, one `material` column in `tool/icons.json`), about 10 KB each. **Batch 2:** Pixelarticons 2.4.2 (one weight, the font its package ships, names from its CSS; drawn on a 24 px grid, so Retro Desktop sets icons at 24). **Batch 3:** Material Symbols Sharp, cut as Outlined and Rounded are (Swiss). Iconoir comes with the first theme that draws it.
- Every set maps the same semantic ids (`MyDataIcon.contact`, `.calendar`, `.add`): 53 today, the ones the apps draw; new ids are added as screens need them (the estimate was about 90). A test fails if a set misses an id.
- Licences: Lucide ISC; Phosphor, Tabler, Pixelarticons and Iconoir MIT; Material Symbols Apache 2.0. Remix Icon is excluded because of its own licence (January 2026).
- Material Symbols' weight and fill are variable axes, which Flutter's `Icon` sets with `weight` and `fill`. Phosphor ships one font per weight.

### 1.6 Palettes: colour is a separate choice (decided 2026-10-23)

The owner, on the twenty prototypes, said the names made them look like colour changes only (his words are in the decision record). So a theme is named after its design language (Journal, not Plum), and colour is chosen inside it.

- **A theme is a style plus palettes.** The style is every group of 1.2 except colour: type, shape, density, borders, elevation, materials, icons, motion, components and `colour-use`. A palette is the colours, named by colour. The user picks a theme and one of its palettes, per app and per device ("Journal, Ink blue").
- **Fields:**

  | Field | What |
  |---|---|
  | `palettes` | 1 to 8 per theme; a built-in drawn theme has 2 to 4 (the schema fails it otherwise). Their order is the picker's |
  | `palettes[].id` | Lower kebab case, unique within the theme (`ink-blue`). Device settings store it, so a shipped id never changes or disappears. One planned exception: Kiwi's `graphite`, `dusk`, `plum`, `rose` and `amber` (today's colours, Kiwi's palettes in phases 1 and 2) leave Kiwi's picker in phase 3 but stay in the library as **hidden aliases**, never shown or written, read only by the 4.2 migration |
  | `palettes[].name` | A colour name in sentence case, at most 24 characters ("Ink blue") |
  | `palettes[].light`, `.dark` | The six seeds |
  | `palettes[].overrides` | Any other role per mode; what is left out is derived (1.3) |
  | `palettes[].contrast` | Optional values per mode for increased contrast, checked at 7:1; else derived (2.2) |
  | `palettes[].gradient` | The window gradient's 2–3 stops per mode, when the style's window is a gradient (the style keeps the angle). Left out: `bg` mixed 8% towards `accent`, `bg`, and `bg` mixed 5% towards `ink`. Given on a style whose window is not a gradient: ignored, with a notice |
  | `default-palette` | The palette used when none is chosen, or when the chosen one is gone. Only with `palettes` (the schema refuses it alone, System included) |
  | `colour-use.same-as` | Roles the style always draws in another role's colour: Hairline's `selection`, `edge` → `ink` and `avatar-fill` → `surface`; Journal's and Paperback's `toolbar` → `bg` and `edge` → `ink`; Kiwi's `sidebar` and `toolbar` → `bg`. A palette may not give these roles, in its overrides or in its `contrast` set; a value may not itself be a key. Applied as 1.3 says: after the palette's values, again after derivation, and again at increased contrast |

- **A palette changes colour roles only** (the 44 roles, the contrast set, the gradient's stops). Fonts, shapes, density, borders, the elevation style, icons, motion and variants are the style's: a palette that needs another shape is another theme.
- **Every palette is checked on its own** (section 2): both modes, normal and increased contrast. A built-in palette that fails breaks the build. Status (phase 1, 2026-10-23): the Dart validator checks all 18 in both modes at both levels, and all pass: the six with their own `contrast` set (Hairline, Sticker) and the other 12 (Kiwi, Frosted, Journal, Paperback) with the derived 7:1 values (`mydata_ui/test/theme/builtin_themes_test.dart`). Increased contrast turns glass solid (2.3), so the glass pairs are checked at normal contrast only. In an imported theme, a failing default palette fails the theme (2.4); a failing other palette is left out of the picker, with its reasons as a notice, and the editor offers Fix.
- **Built-in palettes give every role the style does not fix through `colour-use.same-as`** in both modes (34 to 37 overrides beside the seeds, and `stripe` where the style's lists are tables; all 44 roles once resolved), so the built-ins never depend on the resolver's derivation, which phase 1 rebuilds in Dart and may round differently. Custom palettes may give only the seeds.
- **Across a theme's palettes** (a rule for built-ins, seen in the previews): status colours, `danger` and the `data-*` colours stay close to the default palette's, so they mean the same in every palette; a palette moves the accent and the tint of the grounds. Accents of one theme's palettes are at least ΔE<sub>OK</sub> 0.08 apart (a notice).
- **Today's colour themes became palettes:** Graphite is Hairline's default, Dusk Frosted's, Plum Journal's, Rose Sticker's and Amber Paperback's; Kiwi keeps its green. Each built-in's palettes are listed in `theming.md` and described in its `RULES.md`.
- **System has no palettes.** Its colour is the platform's: the macOS accent; Android's wallpaper colours from phase 7; elsewhere, until each platform's pass, Kiwi's default palette. The picker shows no palette row for System.
- **"System, tinted"** (a `system`-frame theme whose palettes give an accent only) **is never applied on macOS:** there the system accent is drawn and such a file's palettes are ignored, since the owner decided System has no alternative colours on macOS. **The owner decided (2026-10-23): it never exists on macOS,** where System always follows the Mac accent; other platforms may allow a tint later (phase 5 or that platform's pass). Off macOS, System is Kiwi until each platform's pass, so a tint would be little more than Kiwi in another palette. If one is allowed, a tinted palette must give `accent` in both modes (the schema requires it) and is checked as a palette on the grounds System draws on that platform: the accent replaces Kiwi's default palette's `accent`, `link`, `selection` and `accent-soft` are derived again from it (1.3), with what follows them (`on-selection`, `focus`, and `glass-fill`, which must read over the accent), and the result passes 2.2 like any palette, text at 4.5:1 (`on-accent` on `accent` and `link` included). The validator checks it so (`systemPalette` in `resolve.dart`); a tint that fails is left out like any palette.
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
| 4.5:1 text (SC 1.4.3) | `ink` on bg, surface, surface-raised, surface-sunken, stripe, surface-hover, accent-soft, selection-inactive, sidebar, toolbar and each status `-soft`; `ink-muted` on bg, surface, surface-raised, surface-sunken, stripe and sidebar; `link` on bg, surface and surface-raised; `on-accent` on accent; `on-selection` on selection; `on-danger` on danger; each status colour on surface and on its `-soft` |
| 3:1 non-text (SC 1.4.11) | `line-strong` (and `edge` when borders use it) on bg and surface; `accent` on bg and surface wherever it alone marks a state (a switch that is on, a selection bar); the selection marker (fill, bar or outline) on surface; `focus` on bg, surface, surface-raised and accent-soft, and `focus-on-danger` on danger-soft; each `data-*` on surface, or the edge rule |
| 7:1 | At increased contrast, every text pair of the list above (status words, links, accent drawn as text and labels on fills included). The resolver **derives** these values (lightness only, as for missing roles; a status `-soft` that leaves no room becomes `surface-sunken`); a palette's `contrast` set is an override and must itself pass. Always, in a theme whose file says `accessibility.text-contrast: 7:1` (accessibility-first: High Contrast, E-ink) |
| Grounds that are not flat | **Gradient:** text pairs against every stop. **Pattern:** against the ground with the pattern colour composited at its opacity. A pattern is the window ground: it shows on `bg` and a sidebar that is not a panel, never under `surface` or `surface-raised`, which are opaque. **Image:** against the 1st and 99th luminance percentiles of the image, after tint and opacity, sampled at 64×64. **Glass and translucent bars:** `ink` and `ink-muted` composited over `bg`, `surface`, `ink`, `accent` and `selection` beneath (blur averages text into its ground, but a filled row or button scrolled under a bar is a large block of its colour). At 72% `glass-fill`, Kiwi and Frosted fell to 3.1–3.8:1; they now use 80–84% |
| Kept apart | `accent` and `danger` closer than 25° in hue gives a notice (danger always carries a word); then the approval card's Approve and every filled primary button are drawn in `ink`, not `accent`, so Approve never looks like Delete (Swiss), and so is every icon that would take the accent (an accent icon tile, a record's quick actions, a result's icon: a red phone or cloud reads as an error). `danger` stays within 25° of today's red hue: a theme moves its accent, never danger's meaning. A danger without colour (OKLCH chroma under 0.04: E-ink's, in ink) has no hue to move and passes with a notice ("told by its word alone"; phase 4). `focus` must differ from the selection marker (`selection`; `ink` for an inverse selection) by 3:1, or by colourfulness (a marker of OKLCH chroma under 0.04 and a ring at least 0.08 more chromatic: a red ring on Hairline's ink bar), or by hue (both chromas at least 0.04 and at least 60° of OKLCH hue apart). 60°, not 25°: a red ring on an amber or brown selection, 28° to 50° away at about 1:1, is lost on a selected row, so Paperback's Amber and Sepia and Frosted's Sand use a blue ring |
| Avatar initials | A new role, `on-avatar` (derived: whichever of `ink` and `surface` is higher on `avatar-fill`), 4.5:1 on `avatar-fill`. The three prototype validators disagreed (one assumed ink initials and failed Brutalist and Swiss, whose avatars are ink-filled) |
| Highlighter selection | The marker is the 3 px `accent` bar (3:1 on surface); the yellow highlight is a text ground (`on-selection` on `selection` 4.5:1) and needs no 3:1 |
| Tables | Where `components.list` is `table` (Ledger), three steps the eye must tell apart: the header band (`surface-sunken`) at least 1.08:1 on a stripe (`stripe`), and a selected row's fill (`accent-soft` for a tint or bar, `selection`, or `ink` when inverse) at least 1.2:1 on a stripe and on `surface`, so a selected striped row is never read as a stripe with a bar. Notices in the validator (a palette of seeds alone may fall short); every built-in table is held to them by `builtin_themes_test.dart` at both contrast levels (2026-10-24, the Ledger review) |

### 2.3 Rules beyond colour

- **Focus visible (SC 2.4.7), not obscured (SC 2.4.11), 3:1 against what it touches (SC 1.4.11):** a ring 2–4 px wide (3 px double in High Contrast), offset 0–3. It follows the shape (`OutlinedBorder`, never a clip) and is never covered by a sticky bar. The colour rule stays in `FocusRing`, and System uses the system's ring.
- **Two-tone ring where it touches a fill.** When the ring sits on or inside a filled shape (a solid or inverse selected row, a MonthGrid cell, which today draws the ring inside the selection ring), `FocusRing` adds a 1 px inner keyline in `surface`, so the ring is 3:1 against both sides whatever the fill (WCAG technique C40). The validator then checks `focus` against the grounds only, and checks the fill only where no keyline is drawn. Retro Desktop (both modes) and Geometric (dark) cannot pass with one colour: no lightness of their focus colour is 3:1 against both the dark grounds and the yellow or blue fill.
- **Sizes:** the floors in 1.4, also enforced at run time.
- **Text:** body line height at least 1.25, display at least 1.1. Display-only fonts only at 16 px or more. `upper` only on `label` and `caption`, and never on text that holds a name (a person, an app, a calendar, a file): widgets mark such text and it keeps its own case (decided 2026-10-23; a trial turned "myAssistant" into "MYASSISTANT"). As built: a widget's own labels in these roles (a control's or field's name, a heading, a tab, a status word, a weekday) go through `RoleLabel`, and a widget whose label may be a name takes `holdsName` (`GroupedControl`, `FormRow`; `headingHoldsName` on group headings); sentences (help, errors, descriptions) and the user's data, a field's own label from a card included, never change case.
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
  - `themes.json` went in phase 3 (as built below, "the six full looks"). **Phase 1 still read today's values:** the files here are the full looks, and Frosted's, Sticker's and Paperback's `accent-soft` and Kiwi's link and glass were moved by the contrast audit, so building phase 1 from them would change goldens. Phase 1 generates one built-in style, Kiwi, from `tokens.json`, with today's six colour themes from `themes.json` as its palettes (`kiwi`, `graphite`, `dusk`, `plum`, `rose`, `amber`): that is exactly what the apps draw today. Phase 3 switches the generator to these files: Kiwi keeps its own palettes and the other five move to the themes they now belong to (4.2), their old ids kept on Kiwi as hidden aliases (1.6).
- **Generator:**
  - copies the built-ins into `mydata_ui/assets/themes/`;
  - generates `builtin_kiwi.g.dart`, Kiwi's default palette resolved in light and dark as constants. It is used for the first frame, for tests and when everything else fails, so the app never draws unthemed;
  - `generated_tokens_test.dart` still fails when that file is stale.
- **Model:** `ThemeFile` (the parsed, validated file) goes through `resolve(file, paletteId, brightness, platform, a11y)` and gives a `MyDataLook`, made of one `ThemeExtension` per group:

  ```dart
  class MyDataLook {               // one per brightness, immutable, resolved
    final String themeId; final String? paletteId; // null for System
    final LookFrame frame;          // system | drawn
    final MyDataColors colors;     // existing extension, now built at run time from one palette (44 roles)
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

**As built (phase 1, 2026-10-23).** Every golden and app screenshot came out byte-identical. Where the code differs from the design above:
- **`context.typeScale.body`**, not `context.type(MyDataTypeRole.body)`, for a role's style: `context.type(role)` already means "the role's style, or its Mac counterpart in the System look" and keeps that meaning. The look's field is `typeScale` too, since a `ThemeExtension` is keyed by its `type`.
- **A widget's own measures that depend on the look** (`Card.gap`, `GroupedRow.padding`, `MyDataDialog.widthFor`) became static methods taking it: `Card.gap(context.look)`, and `kiwiLook` in tests. Render objects, painters, layout delegates and routes are given the look (or the value) when they are built.
- **`context.lookNow`** reads the look without depending on it, for `initState` and fields first read there (animation controllers). Such a controller keeps its durations until it is built again; a theme change while it lives does not reach it (phase 2 looks at this when themes change at run time).
- **The density class** is the platform's (iOS and Android take the phone set), decided when the look is resolved, so reading it makes no dependency on the window's size. The floors of 1.4 are phase 3's.
- **Unknown keys** are left out with a notice at every depth (2.1), also where the schema says `additionalProperties: false`.
- **Not changed:** `MyDataSize`'s layout widths (`content-max`, `dialog-width`, `inspector-width`, `sidebar-width`), `MyDataMotion.toastDuration` and `reduced`, and the Mac frame's own tokens (`MyDataMac*`, the System look's), which no theme changes. `no_literals_test.dart` refuses the themeable static reads outside `mydata_ui/lib/src/theme/`.
- **Kiwi as drawn today** has six palettes, which the schema refuses for a built-in (2 to 4); the validator allows it for that file alone until phase 3. It reported today's look's known gaps, which phase 3 fixes (decision 6): glass at 72% was too thin for `ink-muted` over dark or coloured content, and the red ring is lost on a Rose or Amber selection. **Fixed in phase 3 (2026-10-23):** the glass is 82% and 84% (`tokens.json`), and Kiwi's link is `#4B7611` in light, as `kiwi/theme.json` gives it; every link (Open myData, a source, a web address) is drawn in `link`, no longer `accent`. The red ring on a rose or amber selection goes with the move of those colours to Sticker and Paperback (4.2).

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
- **`MacLook.of(context)`** is split in two (done in phase 1):
  - `MacWindow.of(context)`: the Mac shell's window, wider than a phone. This is the skeleton, and it is true for every theme;
  - `context.isSystemLook`: the System look in that window (`MacWindow.of` and `context.look.frame == LookFrame.system`).

  The 60 sites were audited one by one. Layout branches (three columns, toolbar band, the app's Mac pages and the Mac widgets, which phase 3 makes take a drawn theme's colours) take the first. Visual branches in shared widgets (the push button, plain lists, the alert sheet and its scrim, the Mac menu, toast, picker, inspector footer, empty and status panels, the hairline edge of a data colour, the assistant's Mac cards and chat, and `contacts_view.dart` choosing tonal or plainDanger) take the second, and become variants in phase 3. The two agree until a drawn theme is drawn in the Mac window.
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
| "System, tinted" (not on macOS, 1.6) | Not on macOS: its palettes are ignored and the system accent is drawn. Elsewhere, System with `accent` replaced and checked as a palette, text at 4.5:1 (1.6) | — |

- Duplicating System gives a drawn theme seeded from the Mac shell's current colours and sizes. Its variants are `button.primary: push`, `list: plain`, `sidebar: source-list`, `toolbar: native`. It is a frozen copy and does not follow the system. The editor says so.

### 3.5 Performance

| Effect | Rule | Cost |
|---|---|---|
| Theme switch | One `Theme` change, which rebuilds the tree once: every app passes `MyDataTheme.switchDuration` (zero) as `themeAnimationDuration`, so type never lerps through in-between sizes and fonts, and `MyDataLook.lerp` snaps type past t = 0 wherever a theme does animate. Budget: under 50 ms on an M-series Mac, measured in a profile-mode test (not yet) | One rebuild |
| Gradient, pattern | Painted once behind the content in a `RepaintBoundary`, never per row. Rules and grids line up with text through a fixed strut (`forceStrutHeight`) | Nil |
| Glass (`bars: blur`) | Toolbar, sidebar (outside macOS) and floating bars only, through one `BackdropGroup` per window with `BackdropFilter.grouped`. Never on rows or cards. Solid on the web, with reduced transparency, and when frame raster time goes over budget for 2 s | Bounded |
| macOS sidebar material | The window's own NSVisualEffectView | Free to Flutter |
| Background image | Decoded once at window size (`ResizeImage`), at most 2560 px on the long side (about 16 MB of texture), one per mode, pre-blurred at import. Content always sits on a surface | Memory |
| Glow | Primary button and selection marker only, never on text | Small |
| Fonts | The core three (Figtree, Plus Jakarta Sans, JetBrains Mono) are in the pubspec as today. Every other catalogue font is a plain asset (Latin subset), loaded with `FontLoader` when a theme that needs it is chosen or previewed, and cached for the session. Measured 2026-10-23 (`tool/measure_fonts.sh`, the built asset bundle): 4.11 MB in myData, 3.87 MB in the other three, of which 2.30 MB are ours (core fonts, the six built-ins' fonts, icon sets) and the rest Flutter's Material Icons (1.57 MB) and, in myData, Cupertino Icons (0.25 MB), both tree-shaken to a few KB in a release build. A test counts every font an app carries, the framework's included, and fails above 6 MB | Bundle size; a few ms per family |
| Web font fallback | Flutter web fetches missing glyphs from `fonts.gstatic.com` by default (`fontFallbackBaseUrl`). Before the web build shows data, point it at the host | Privacy, not speed |
| Gallery | Previews are live widget trees under `Theme(data:)`, built lazily, at most 6 at once, with no blur (a solid stand-in) and fonts preloaded on focus or hover | Bounded |

### 3.6 Fonts and icons at run time

- `FontCatalogue` maps an id to its asset, its weights or variable range, its licence, and whether it is display-only.
- `ThemeController` awaits `FontCatalogue.ensure(families)` before swapping themes, so text never reflows in a fallback font. **As built:** `ThemeFonts.ensure`; a stored theme is drawn once its fonts are, a preview overtaken while loading is never drawn, and a font that cannot be read is reported and the theme drawn in its fallback fonts (`mydata_core/test/theme_fonts_test.dart`, with a gated asset bundle). Every app reaches it since phase 3 offers the designed six.
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
- **Writes are rare and user-made.** A read-modify-write race between two apps is possible, as for `mode` today. **As built (phase 2):** `FileDeviceStore.update` compares the file's text (not its modification time, which two writes in one millisecond share) just before the rename and reads again and retries when another app wrote; updates in one process run one at a time. Between processes a write landing between the check and the rename can still be lost.
- **A theme deleted while in use** makes those apps fall back to its `based-on`, else System, with a one-time Notice in myData's Appearance.

### 4.2 Migrating from the host's theme

- **First start of the new version** (no `themes` key in the file):
  - **on macOS**, every app is set to `mydata.system`, because the Mac shell already ignores the host's theme. Nothing on screen changes;
  - **elsewhere**, `everywhere` is seeded with the colour someone chose on the host, as Kiwi in that palette (`plum` → `{ "theme": "mydata.kiwi", "palette": "plum" }`), which is what phase 1 draws. The device's `lastTheme` is read first and the host's deprecated `/status` `theme` only without it: the old controller wrote the host's theme to `lastTheme` at every poll, so it is the same theme without waiting for the host. The host's default colour, `kiwi`, which a host where nobody chose reports too, seeds System instead: System draws Kiwi in Kiwi until each platform's own pass, so nothing changes on screen, and the device then follows that pass;
  - in both cases, nothing on screen changes.
- **Phase 3** moves a choice of Kiwi in one of the five old colours to the theme that colour now belongs to (`graphite` → Hairline, `dusk` → Frosted, `plum` → Journal, `rose` → Sticker, `amber` → Paperback, in that palette). That changes the look, which is the point of phase 3, so myData's Appearance says so once ("Plum is now a palette of Journal."), and each app whose look moved says it once in its own window (5, "the six full looks as built"). The five ids stay on Kiwi as hidden aliases (1.6), so a choice the first-start migration did not move (a settings file restored from a backup, an app that wrote an old choice) is moved when it is read, never resolved through the generic fallback to Kiwi's default. **Confirmed by the owner (2026-10-23),** with the one-time notice; **built 2026-10-24** (5, "the six full looks as built"). A Mac is affected too where someone chose Kiwi in an old colour in phase 2's gallery; macOS's first start itself puts every app on System (above).
- **The host:**
  - `GET /appearance` and `/status`'s `theme` are kept for one release, marked deprecated;
  - `PUT /appearance` returns 410 with "Themes are chosen on each device now.";
  - then the route and `state.theme` go, with an API version bump, a regenerated `openapi.json`, and the scope tests updated.

### 4.3 Where the picker lives

| Place | What |
|---|---|
| Every app, macOS | View > Theme… ⌃⌘T (⌥⌘T is Show or Hide Toolbar in Apple's apps; checked in phase 2) opens the gallery sheet; Windows and Linux have no key (Ctrl+T is myCalendar's Go to Today). It is not a submenu of themes, because `PlatformMenuItem` has no checked state (`mydata_ui` README) |
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
- **Left pane:** groups as Inspector sections, in this order: About (name, author, licence, description), Palettes (a list: add, duplicate, rename, remove, reorder, make default; each palette shows its seeds first, "More colours" opens the 44 roles, light and dark columns, "Make dark from light" derives the dark set), Type, Shape, Density, Surfaces (borders, elevation, materials), Icons, Motion, Components, Checks.
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

Phases 0 to 3 are the themes foundation and come before the phones (M1b). Phase 4 builds the 13 new built-ins (the owner picked all twenty, 2026-10-23); phase 5 (custom themes) and later wait.

| Phase | Builds | Usable result | Tests |
|---|---|---|---|
| 0. Decide (done 2026-10-23) | The decision record; this folder; `theming.md`, the `README.md` rules (they became Kiwi's), `platforms.md` and CLAUDE.md rewritten | — | — |
| 1. Run-time spec, no visible change | Format (style and palettes), schema and validator in Dart; built-ins from today's values (Kiwi from `tokens.json` with `themes.json`'s six colours as its palettes; 3.1); the resolver, `MyDataLook` and its extensions; generator changes; the codemod across packages and apps; the `MacLook` split | The apps look exactly as before | Every existing golden **byte-identical**; every built-in palette of `design/themes/` resolved at increased contrast (its own set, else the derived 7:1 values) passes 2.2, failing the test otherwise, even though phase 1 does not draw them yet; validator unit tests (examples, `bad-*`; a `same-as` key in a `contrast` set refused; a `same-as` role following its source after derivation and at increased contrast); schema test; contrast of the six; `no_literals` extended to the static classes |
| 2. Per app, per device | `ThemeController`, the `themes` keys, migration, deprecating the host route, the gallery sheet with live preview, View > Theme…, myData's Appearance (apps, Use everywhere, library list), System as default | Each app picks System or Kiwi in one of six palettes (what exists until phase 3); Use everywhere carries the palette | Store and migration tests (macOS → System; elsewhere → host theme); a System choice with a stray `palette` resolves with no Notice and loses it on the next write; Use everywhere and Use in this app never write `palette` for System; changing theme resets the palette to the new default; two apps following one file; a fake-host test that the 410 route is never called; gallery keys (arrows preview, Escape reverts) |
| 3. Design rules | Shape and corner styles with the shape-following focus ring; density presets and floors; borders; elevation; the type catalogue with on-demand fonts; icon sets with semantic ids; motion personalities; the component variants (button, list, selection, inputs, avatar, tabs, sidebar, toolbar, chat, month, today); drawn themes inside the Mac window; the new disabled style. The six rebuilt as full looks from the files in this folder, each with its palettes; the old colours moved to their themes (4.2); `themes.json` retired; the component specs' "Kiwi and Graphite" (today's accent-only Graphite) rewritten as "Kiwi and Hairline" | Kiwi, Hairline, Frosted, Journal, Sticker and Paperback each look distinct, each in 3 palettes | Variant goldens, **one per variant value** in both modes (about 120 images); pairwise golden sets for risky pairs (cut with focus, table with inverse, brutal with collapse press); each palette once on one app scene in both modes (36 images); a stored `{mydata.kiwi, plum}` read after phase 3 resolves to Journal in Plum with the one-time Notice, never to Kiwi in Kiwi; font budget test; icon-mapping completeness; theme fuzz (2.5) starts here |
| 3½. One harness (done 2026-10-24) | One validator (the Dart one) and one preview harness; every prototype the owner picked re-rendered from them in the real app (each once ported, phase 4) | Like-for-like previews | Each passes in both modes and at increased contrast |
| 4. New built-ins (done 2026-10-24, in four batches: High Contrast, E-ink, Large; Terminal, Notebook, Brutalist, Retro Desktop; Swiss, Blueprint, Arcade, Geometric, Zen; Ledger) | **All 13** (the owner's pick, 2026-10-23), each ported, not copied: split into a style and palettes, layout left out (Large keeps no reflow, Ledger only a list or table variant). In batches; proposed order: High Contrast, E-ink, Large, then Terminal, Notebook, Brutalist, Retro Desktop, Swiss, Blueprint, Arcade, Geometric, Zen, Ledger. Each with 2 to 4 palettes; status and `data-*` colours tuned per palette. A theme that does not earn its place in the real app is cut | Up to 20 themes | Every theme: contrast at both levels; 4 app scenes × 2 modes screen goldens (160 images for 20 themes); a review by eye on a Mac before each batch is merged |
| 5. Editor and sharing | Duplicate and edit, with checks and Fix; `.mydatatheme` export and import without images; copy and paste; the UTI and double-click | Make and share themes | Import refusal tests mirroring the host's zip tests; round trip (export → import → the same resolved look); editor: Save disabled with a reason, Fix reaches a pass, drafts survive |
| 6. Materials | Gradients, patterns, glass with `BackdropGroup`, background images in the zip with re-encoding and percentile contrast | Frosted's glass, Notebook's rules, image grounds | Raster-time budget in a profile run with blur on; image caps (size, pixels, magic bytes, EXIF gone); reduced transparency turns everything solid |
| 7. Other platforms' System | Android: Material 3 and dynamic colour. Windows and Linux: each with its platform pass | System means native there | Per-platform screen goldens |

**Phase 2 as built (2026-10-23).**

- **Store:** `ThemeController` (mydata_core) per app reads `themes` and `mode` from `<home>/device/settings.json`, follows other apps' writes through `FileDeviceStore.changes` (the folder's file system events) and a 2 s read, and writes through `DeviceStore.update`. A choice for a theme without palettes is written without `palette`; one found with a stray `palette` resolves as System and loses it at the next write.
- **Every writer of the file goes through `update`** (the themes, the mode, myCalendar's hidden calendars, myContacts' last contact opened), so none puts back what it read before another app's change. A file that exists but cannot be read or is not a JSON object is never taken for "nothing stored": `read` throws `DeviceStoreUnreadable`, `update` reads again briefly and then refuses, writing nothing, and the apps keep drawing what they read last. No file, or an empty one, is no settings yet.
- **What this build does not know is kept:** the apps are built and installed one by one and share the file, so a write keeps other keys under `themes`, `apps` entries it cannot read (except Use everywhere, which clears every app's own), and a choice's other fields while its theme stays the same.
- **Migration:** as 4.2: elsewhere the device's `lastTheme` first, else the host's deprecated `/status` `theme` once the host answers; the default colour `kiwi` and a host theme this build does not know migrate to System. The apps never call `/appearance`.
- **Host:** `PUT /appearance` answers 410 with no body; `GET /appearance` and `/status`'s `theme` are marked deprecated (API version `3ce02a66c0de`). **The installed host must be rebuilt and installed again** (`build_host_app.sh`, then `install.sh`), or every app built from this checkout settles on "incompatible".
- **Gallery:** System, then Built-in (Kiwi in six palettes); live cards drawn by `MacShell.themeDataFor`, so a card looks as the app would draw it on this platform. The window's preview ends when the gallery is popped (Escape, Cancel), never from `dispose`, which cannot rebuild the app. Return on the cards uses the selection; on a palette swatch Return chooses that swatch (it is already the selection) and does not close the gallery. Phones get no Use everywhere.
  - **One gallery at a time:** on a Mac the menu bar is not behind the gallery's barrier, so View > Theme… is disabled while one is open and a second open does nothing (`ThemeGallery.showing`).
  - **While a choice is being stored,** the cards, the palette row, the app switcher, Escape and the buttons wait, so the window is never put back under a choice still landing; a choice that cannot be stored shows a Notice above the buttons and the gallery stays open.
  - **Use everywhere's Undo is its inverse:** it puts back the everywhere choice and each app's own where that app still has none, keeping choices made since in any app; when everywhere was changed again since, it puts nothing back and says so. The preview goes on (the gallery stays open), and Cancel becomes Done. The Undo lives in the gallery's toast, so it goes when the gallery closes.
  - **The Everywhere row's Change…** in myData's Appearance opens the gallery on the everywhere choice, with Use everywhere as its default action and no "Use in"; phones show that row without Change….
- **On a Mac, a drawn theme** keeps the Mac window and skeleton (`MacWindow.of` stays true) and draws its palette in the Mac widgets (`MacTheme.colorsFor`); the Mac widgets keep the Mac's type and sizes until phase 3. The Mac text theme is marked `inherit` so the app's theme animation can lerp between System and a drawn theme.
- **First launch** no longer has a theme step, on any platform (4.3).
- **View > Theme…** has no key (6, item 11). Windows and Linux, which have no menu bar, reach the gallery from myData's Settings > Appearance.
- **myCalendar and myAssistant now draw `AppMenuBar`,** as myData and myContacts already did, to carry Theme…. It replaces the runner's `MainMenu.xib`, so the template's items that did nothing for a Flutter window go (Preferences… ⌘,, Paste and Match Style, Find, Spelling and Grammar), Close Window ⌘W is there but disabled as in every app (`onCloseWindow`), and ⌘Z runs a toast's Undo as in the other apps. Their own items (myCalendar's New Event, Month ⌘1, Go to Today ⌘T) come with their full adoption.
- **myData's Appearance** lists all four apps (a choice can be made before an app is installed), and a stored choice this build cannot draw shows a Notice saying what it draws instead, for as long as it is stored (not once).

**Phase 3, design rules as built (2026-10-23).** The rules every theme's style sets reach the widgets; the component variants, the six as full looks and the move of the old colours (4.2) are below. Kiwi draws as before except where decided: its link and glass (3.1), the disabled filled button, and the two-tone ring on a selected day.

- **Shape:** `MyDataShape.outline`, `decorate`, `clip` and `ringPath` (`look.dart`). Every rounded decoration in the branded widgets, `mydata_assistant` and the apps goes through `context.radius.decorate(...)` (a box for round and square corners, so Kiwi is byte-identical; a `ShapeDecoration` for continuous and cut), clips through `context.radius.clip`, and Material's dialog, sheet, menu, snack bar and tooltip shapes through `outline`. A cut is `cut-size`, never more than the radius it replaces (a row keeps a small cut, a square corner stays square). Continuous is `RoundedSuperellipseBorder`; it has not been measured against the system's corners on screen, nor seen on the web build. Not yet shape-aware: the Mac widgets (`lib/src/mac/`, the System look's, which a drawn theme reaches with the variants), the floating bar's outside shadow and the month grid's cells' own fills.
- **Focus ring:** drawn as a stroke of the shape grown outward (`FocusRing.painter`, `InsetRingPainter`), never a clip, so a cut ring is cut again with an even gap (a chamfer grows by `gap × (2 − √2)`). `onFill` (`focusOnFill` on `Pressable`) fills the 2 px gap between control and ring with a `surface` keyline (a 1 px keyline left a line of the ground between them); the month grid uses it on a selected day, where the ring touches the `ink` ring, selected grouped and contact rows use it, and so does a filled button over a hard, offset or bevel drop, whose drop fills the ring's band (Sticker's ring on its ink shadow was about 2.65:1). Width and offset stay 2 and 2, except where the theme's ring is double (`borders.focus: double`, phase 4): 3 px at 1 px, with the `surface` keyline on every control, in the same 4 px (`FocusRing.widthFor`, `keylineFor`); the widgets that draw their own ring (fields, selects, checkboxes, menus, pickers, the contact list, the month) take the width too, and the validator then checks the ring against the grounds only, not against a solid or inverse fill. The Mac widgets keep their 3 px ring without a keyline.
- **Borders:** `MyDataEdges` carries the palette's colour (`line`, `line-strong`, `edge`, `accent`; recoloured when a look's colours are replaced, as the Mac shell does). Cards and groups take `CardEdge` (drawn over the rows, so a hover fill never covers it); separators `EdgeRule` (none; inset from where the row above starts its text, after its icon tile, avatar or checkbox (`LeadingTile`, `GroupFrame.textStart`); full; dashed and double too; inside a double-outlined card a rule stops at the inner line); dashes are one path per edge, kept while its size stays and fitted to each contour; buttons with a fill and text fields take the control edge, never in `line`, which is under 3:1 (`line-strong` stands in, `MyDataEdges.controlColour`); `PageScaffold` draws the title rule. Increased contrast outlines every control. Kiwi keeps full-width separators, in the generated file and in `kiwi/theme.json` alike (GroupedList's spec; a test holds the two files' borders equal), so the full look changes no separator. The contact list keeps its 1 px separator slot, so a theme's wider or double separator is drawn 1 px there.
- **Elevation:** hard drops straight down, offset and bevel down and right, all solid in `shadow` at the strength; bevel adds a light top-left and dark bottom-right line on cards and buttons (`BevelPainter`), stroked along the shape (a pill's ends, a chamfer) and mitred at 45° through the corners, swapped while pressed, none on a disabled button; the light line is made more opaque until it is 1.5:1 on its fill where it can be; glow lights the primary button only (the selection marker comes with the selection variants). With `press: collapse` a pressed button's shadow drops (`PressedScope`, from `Pressable`), and a `sink` press drops it with or without collapse (else it would sink with the button to twice its offset). Soft and none put nothing under controls, as Kiwi has nothing there today.
- **Density floors:** `MyDataDensity.of` raises controls and rows to 24 on a desktop, 44 on iOS and 48 on Android (`minTarget`), and a finger on a desktop raises them to 44 until a mouse or pen is used again (`MyDataAccessibilityScope` follows every press, taking it when the press ends so nothing resizes under the finger). `MyDataLook.of` applies the raise, so `look.density` and `lookNow.density` in layout sums agree with `context.density` in builds (an open Select scrolled to the wrong row when they did not); the fallback look holds the platform floor too. One golden (`style.floor-android`) shows Android's 48. **Kiwi on Android now draws 48 px controls.** The test harness holds the floor at 24 (`MyDataDensity.debugFloor`), because Flutter renders tests as Android: the shared goldens show each theme's own sizes, and the floors have their own tests. Every style golden meets `MinimumTapTargetGuideline` at 24.
- **Motion:** the five personalities with `scale` (slow capped at 500 ms); press none, dim, dim-scale, sink (into the shadow's place, or 2 px) and invert (a button or icon button swaps roles while pressed, an `ink` fill with its label in `bg`; any other control is colour-inverted, the filter put in only while pressed); each personality's spring reaches the segmented thumb, the tab pill, the floating bar's pill and a sheet's rise (`context.motion.springCurve`; `standard` under reduced motion); entrance none, fade and fade-rise (`CardGrid`). Reduced motion turns `context.motion` into its `reduced` form: everything at most `fast`, no scale, sink, rise or sheet travel, and none stays nothing. A sheet's spring share is clamped, so a lively or none theme cannot break it. The personalities' numbers are first values, not tuned by eye on a Mac.
- **Disabled filled buttons:** Filled and Danger on `surface-sunken` with an `ink-muted` label, unfaded (6a, decided), and a 1 px `line-strong` outline (or the theme's control outline), since `surface-sunken` is about 1.05:1 on `bg`; the validator notes `line-strong` under 3:1 on `surface-sunken`. The other variants fade. System keeps the Mac's own look.
- **Switch:** the thumb takes the track's corner style (an octagon in a cut track, a square in a square one). Open: whether the switch scales with density (it stays 44 by 26, so in compact it stands taller than the 28 px buttons), and hairline borders, 0.5 px, which blur at 1x on Windows and Linux.
- **Goldens:** `test/theme/style_variants_test.dart`, one per value of each rule in light and dark on one specimen (corners, controls, border width, style, colour, cards, controls, separators, title rule, elevation style and press, density preset, motion press, bevel on cut corners), 88 images; the two-tone ring per corner style, with the plain ring beside it focused in a second image (16); a focused Sticker button over its drop (2); Android's floor (1). None yet shows a whole theme against its `RULES.md`: per-theme specimens come with the component variants.

**Phase 3, component variants as built (2026-10-24).** Every `components` value the schema defines is drawn by the shared widgets in `mydata_ui` (and myAssistant's chat in `mydata_assistant`), read as typed values (`context.variants`, `lib/src/theme/variants.dart`). The six as full looks and the move of the old colours (4.2) are below.

- **Buttons** (`ButtonPaint`): the app picks the role, the theme how it is drawn. Primary: filled, outline (2 px), brutal (3 px `edge` outline over the theme's drop or a 4 px `edge` drop, which a press always collapses), bevel (a 1 px `edge` ring and the bevel's lines), push (a faint edge and a 1 px soft drop). Danger is built as the primary, in `danger`. Secondary: tonal, outline (the control outline, `ink` text) or text (the accent, underlined). Shape: pill, rounded (`radius-sm`), square or cut, whatever the theme's other corners are; the focus ring follows it (`Pressable.shape`). **Near red:** when the accent is within 25° of `danger` (both chromatic), the primary is `ink` with its label in `bg` (`MyDataLook.accentNearDanger`), and every label that would be in the accent (plain, tonal, a text secondary) is `ink` too, so only a destructive action is red; never in System. No designed palette is near red today (Sticker's Rose is more than 25° from its orange-red `danger`).
- **The approval card** keeps its structure in every theme, System included: a solid `surface`, a 1 px `line-strong` edge (drawn over the content, so nothing moves) and an Approve that is filled, or outlined where the primary is an outline, never brutal, bevelled or a push button (`Button.approval`): its paint is fixed, with no drop and no bevel from the theme's elevation and at most a 1 px `line-strong` outline where the theme outlines controls (Sticker drew it over its hard 4 px drop with a 2 px edge before the review). **Open for the owner:** the card also takes the theme's corners, its elevation's `shadow-2` (a hard drop in Sticker) and Edit's secondary style, where 1.2 says "colours and fonts only" (`design/components/ApprovalCard`).
- **Selection** (`SelectionMark`, `SelectionPaint`): tint, solid, inverse, bar, outline or highlighter on grouped rows, the contact list, the frame's sidebar and rail, the Mac source list in a drawn theme, the gallery's preview scenes and the month's selected day (`DaySelection`). Text on a solid or inverse fill takes its colour from the mark (`inkAs`); a highlighter swipes behind the name (`SelectionHighlight`). **A tint under 3:1 on `surface` is never colour alone:** it adds a `selection` bar, or a 2 px outline where the theme outlines its controls (2.3). Kiwi's tint is under 3:1, so **Kiwi's selected rows and current section now have a leading bar** (its `RULES.md`: "tint plus leading bar"); the contact list keeps its `ink` ring instead. The bar is flush with the item's leading edge and clipped to its outline (the curved start of a sidebar pill), never inset beside the icon, where it read as a stray glyph. System in the Mac shell keeps the system's selection.
- **Lists** (`GroupFrame`, `ContactList`, `MultiSelectList`, the day list): inset (Kiwi), plain, cards (`GroupFrame.cardGap` apart; the contact list counts the gap in its row heights), bordered (always outlined, `GroupFrame.listOutline`), ruled (rules above, between and below, in the border colour) and table (an outlined `radius-sm` box, the heading as a header band on `surface-sunken`, full rules, zebra stripes on `stripe`; the contact list heads each letter's table with the letter as its band and starts the stripes again in each group).
- **Fields** (`InputBox`): outlined (Kiwi), filled (`surface-sunken` with a line along the bottom) and underlined (the line alone; the text lines up with its label, and the focus ring stands `space-2` further out at the sides so it clears the text, `InputBox.focusClearance`). Every field, select, picker, token field and the date picker's month box.
- **Avatars:** circle (always round, whatever the controls' radius: Hairline's and Paperback's were squares before), rounded tile, square, shape (a red circle, blue square or yellow triangle chosen from the name, its initials in `ink` or `surface` by contrast) and none, where the row or header leaves out its place too (`Avatar.shown`). Initials are drawn in `on-avatar`.
- **Tabs and the segmented control** (`TabMark`): pill (Kiwi), underline (a 2 px accent line; the segmented control has no track, only a rule) and boxed (one outlined group with `radius-sm` at its ends and straight dividers, each run of a wrapped row its own group; the current one in `selection` with `on-selection`).
- **The month:** boxed (Kiwi, as drawn today: the month in a card, days ruled by `line`), open (days on the ground, rules between weeks only) and table (every day ruled in the control outline's colour, `radius-sm`, no lift; where the theme's lists are tables too, Ledger, the weekdays are a header band on `surface-sunken` over the first week's rule, in the branded month and the Mac month alike: `MonthGrid.bandedHeadings`, 2026-10-24). Today: disc (Kiwi), ring, or inverse (the whole cell in `ink`; a disc in the date picker). A day's swatches take their 3:1 edge against the day's own fill (`ink`, `selection` or `accent-soft`), read above the cell's text colours. **Not built:** Kiwi's `RULES.md` says "boxed cells with a gap", the component spec says one ruled card; the code keeps the spec (the owner may decide).
- **Data colours:** colour (Kiwi) or pattern (`DataPattern`: the colour's family, red, orange, yellow, green, blue, purple, brown or grey, each its own mark of four fills, none, light, mid or dark grey, plain or with a column of dots, with the `line-strong` edge; the first build's hatch did not show at a 4 px bar). The name always shows: beside the swatch in lists, and in a month cell as the calendar's initial before each title, with the calendar in the accessible name.
- **Chat** (myAssistant): bubbles (Kiwi), blocks (full width, the user's on `surface-sunken`, `surface` in dark, in a 1 px `line-strong` outline) and transcript (each turn under "You" or "myAssistant", which keeps its case, beside a rule). Every style, the Mac's included, reads each turn as "You:" or "myAssistant:" and its text.
- **Sidebar and toolbar.** The branded frame: column (Kiwi), source list (smaller rows with `radius-sm` on `sidebar`), rail (at every width from 600 px) and tabs (the sections as tabs beside the app name; under 600 px every style is the phone's tab bar). A drawn theme in the Mac window keeps its skeleton: its source list rows take the theme's selection and type, and the toolbar band is native (as the Mac draws it), flat (`toolbar` with a rule) or floating (a `FloatingBarSurface` capsule in the theme's bar material, starting after the window's buttons when there is no sidebar). **Open for the owner:** `rail` and `tabs` change the frame's layout (a rail at every width from 600 px; the sections as tabs on top), against decision 9 ("layout stays out of themes"); no built-in uses either. Drop them from the schema, or let them change only how the rows are drawn. The tabbed frame reads each section's spoken name ("Review, 4"). **Icon tiles** (`icons.tiles`): tinted (Kiwi), outlined or the icon alone.
- **Materials, as phase 3 allows:** the window ground is solid, the palette's gradient at the theme's angle, or a pattern (dots, grid, ruled, margin rule, grain, scan lines), painted once in a `RepaintBoundary` behind the branded frame and, for a gradient or a pattern, behind a drawn theme's content column in the Mac window (`WindowGround`, `MacContentGround`; never under the sidebar, and a solid window keeps the Mac's content background); grain is one cached 128 px tile repeated, so a resize costs the same and the grain stays put; the frame's sidebar may be translucent over it; floating bars are blur (Kiwi), translucent (the glass without blur) or solid (with the theme's card outline). Reduced transparency makes patterns, translucent sidebars and glass solid; images wait for phase 6. **Not yet:** a tint over the window's own sidebar material beyond the `sidebar` colour at glass opacity, and the apps' own solid bands in the Mac window (myCalendar's month toolbar), none seen on a real Mac.
- **Goldens:** `test/theme/component_variants_test.dart`, one per value of every `components` key and of `icons.tiles`, in light and dark (140 images, Kiwi with that one value changed), with an accent near red, the approval card under an outline and a brutal primary, the selection on the month, the frame's sidebar over a translucent pattern, the Mac toolbar styles, and three risky pairs (inverse in a table, a highlighter in a ruled list, a pressed brutal button with cut corners); myAssistant's three chat styles (`mydata_assistant/test/chat_variants_test.dart`, 6). Every golden meets the 24 px target guideline. After the review (2026-10-24): Approve in the designed Sticker and under a bevel elevation, the buttons in Sticker, the approval card near red, boxed tabs wrapped, the window grain, Frosted and Paperback in the Mac window (with the window's buttons beside a floating toolbar), and a light-only pass at 360 by 740 of the buttons, the approval card, lists, tabs, the month and avatars for every value (34, at a 44 px target). **Whole themes:** `test/theme/theme_scenes_test.dart` draws one app scene per designed theme in light and dark (12). Seen against each `RULES.md`, for the six full looks: Sticker's secondary has no sticker shadow (its rules give it one); Hairline's sidebar has no hairline on its right edge and its avatars no `line-strong` ring; Journal's selected name is not underlined (the format cannot say it yet); Kiwi's month is one ruled card, not cells with a gap.

**Phase 3, the six full looks as built (2026-10-24).** Kiwi, Hairline, Frosted, Journal, Sticker and Paperback are drawn from their files here, each in its three palettes, and the gallery offers System and all six.

- **Generator:** `builtin_themes.g.dart` holds the schema and every `design/themes/<slug>/theme.json` byte for byte, by id, in the gallery's order (`builtInOrder` in `tool/themes_codegen.dart`; a folder it does not list is refused), so every built-in is read without waiting for an asset; `assets/themes/` is gone. `tokens.g.dart` comes from `tokens.json` and Kiwi's file: the colour roles `tokens.json` has no token for are Kiwi's default palette, and a `tokens.json` colour that is not Kiwi's stops the generator, so `MyDataColors.light` and `dark` (the first frame, the fallback) are Kiwi's. `themes.json`, `MyDataThemeSpec`, `MyDataThemes` and `MyDataColors.withTheme` are gone; `ThemePicker` is the gallery's palette row (`PaletteSwatch`), and `ThemeSample` went with the host-wide picker. `generated_tokens_test.dart` still fails when either file is stale.
- **The library** (`ThemeLibrary`): System and the six, each based on its `based-on`, else Kiwi; `defaults` are Kiwi's default palette. `MyDataTheme.data(name)` takes a built-in's slug or id, or an old colour (`plum` is Journal in Plum), for tests and the Mac shell's base.
- **Kiwi** takes what its file says: continuous corners (`RoundedSuperellipseBorder`; most decorations become a `ShapeDecoration`, so widget tests read them through `.box` in mydata_testing). Its file's line heights are the exact ratios (28/22 is 1.2727, not 1.27), so its type is unchanged. **System in the Mac shell keeps round corners** (`MyDataLook.asSystem`): its style is Kiwi's, and the Mac frame stays as it was approved until the Mac's own pass; every Mac System golden is byte-identical, except Appearance and the gallery, which list seven themes. A tracking of 0 now sets no letter spacing (an explicit 0 lost the font's kerning, a pixel off where none was set).
- **The old colours** (4.2): `ThemeLibrary.movedColours` maps `graphite`, `dusk`, `plum`, `rose` and `amber` to Hairline, Frosted, Journal, Sticker and Paperback in that palette. `normalise` draws a stored Kiwi in one of them as its theme at once (never Kiwi's default), `knows` counts it as known, and `fromColour` gives the new theme. `ThemeController` rewrites such a choice, everywhere or for an app, whenever it reads the file (`ThemeSettings.movedOver`; an older build that writes one again is moved again), lists the colour under `themes.moved`, and seeds a device from the host's old colour the same way. myData's Appearance shows "Plum is now a palette of Journal." for each listed colour on its next visit and then takes it off the list (`acknowledgeMoved`), so it is said once there; that is the record. **After the review (2026-10-24):** each app whose look moved also says it once in its own window, where the change is seen ("Plum is now a palette of Journal, so myContacts looks different.", with OK; `ThemeMovedNotice` in mydata_core, round each app's content), and records it under `themes.told` (`{"plum": ["mycontacts"]}`, `acknowledgeMovedHere`; Appearance's acknowledgement counts for myData). A colour once told is never listed as moved again, so an older build that writes Kiwi in Plum again is moved quietly.
- **Gallery:** with seven cards the palette row stays in view above the buttons while the cards scroll.
- **Fixed on the way** (found by Hairline's phone density and Sticker's type in the apps): a checkbox whose box is taller than its label's line moves the label down instead of a negative padding; a card grid re-measures a card whose content grows (a tight stretch made each card a relayout boundary); a floating Mac toolbar makes room for a theme's two-line title.
- **Goldens:** every widget golden and app screenshot is Kiwi and Hairline (was Kiwi and Graphite); Flutter tests run as Android, so Hairline's are its phone density (48 px controls). The Mac frame's accent screenshots keep their Kiwi and Graphite accents (System). `theme_scenes_test.dart` draws its scene in all 18 palettes, light and dark (36). Each app's `theme_screens_test.dart` draws a key screen (myData's status, myContacts' people, myCalendar's month, myAssistant's approval) in each of the six in the Mac window, light and dark (48), and until phase 3½ rendered every theme, palette and screen with `--dart-define=MYDATA_SHOTS`; the preview harness replaced that (below).
- **Fixed after the review (2026-10-24): the Mac widgets draw the theme.** Inside the Mac window a drawn theme no longer leaves the Mac widgets in the Mac's type and sizes. `MacLookMetrics` (`context.macLook`, `lib/src/mac/mac_metrics.dart`) gives them System's `macos` tokens unchanged, or the drawn theme's: `body`, `body-strong`, `label`, `caption`, `heading` and `title` for the Mac roles (a record's name and a pane's title in `title`, so Journal's names are in Fraunces), secondary text italic where the theme says so, its desktop rows and controls (Hairline's 40 and 30 px), its icon size, its small radius for a selected row and its controls' corners (a capsule where controls are pills, else the small radius, square in Journal) in its corner style, and its control outline round toolbar items. The source list, toolbar buttons and search field, the toolbar group, segmented controls, forms (with the theme's card outline round a group), the record header, quick actions and field table, the plain contact list and the apps' Mac pages read it; the window's skeleton (column widths, the toolbar band, sidebar margins) stays the Mac's. The plain contact list marks its selection as the theme does (`SelectionMark`: Kiwi's tint and bar, Hairline's and Journal's bar), rules its rows where the theme's lists are ruled or plain with separators, and rings the keyboard's row inside it; a drawn theme's focus ring in the Mac window is its own (2 px, following its corners, two-tone on a fill), not the system's. The sidebar panel takes the theme's large radius and card outline. A drawn `Button` in the Mac window is no larger than the theme's `label`, so it never outweighs a form row's title. A record's web address is in `link` and underlined (Hairline's link is almost its ink). The Mac month draws today as the theme does (`components.today`: a disc in the accent, a ring, or an `ink` disc; the system red is System's alone), the selected day's outline in the theme's small radius, and its rules per `components.month` (open: between the weeks only, in the border colour). **Test:** `themesDistinct` (mydata_testing) checks that each app's theme screenshots of every two drawn themes differ by more than colour: edges counted in 16 px blocks, so one theme's palettes score 0.00 to 0.02 against each other; at least 0.3 for myData's status, myContacts' people and myAssistant's approval (Kiwi and Hairline scored 0.22 on people before), 0.18 for myCalendar's month, whose grid is the same in every theme (0.06 before). Also fixed: Send in myAssistant's composer is drawn as the theme draws its primary (an outlined square in Journal); one-off raised surfaces (the kiwi tile, the loader, the host chip, a form's page card, a duplicate pair, a boxed month) draw the theme's card outline with their shadow, so Sticker's hard shadow never shows alone; System off the Mac keeps round corners (`MyDataLook.resolve`), with a golden of it (`scene.system.*`). **Still not done:** Journal's double rule under a record's title, the Mac menus and alerts (`mac_overlays.dart`) and the Mac switch, which keep the Mac's look in every theme; Hairline's widget goldens show phone density, not the desktop's 30 px controls. Not seen on a real Mac.

**Phase 3½, the preview harness as built (2026-10-24).** One validator and one way to see a theme: any theme file, in any of its palettes, drawn by the real apps on the same four screens, in the same window, with the same synthetic data. Nothing opens a window: every picture is made by `flutter test`.

- **Command:** `app/tool/preview_themes.sh [all | <slug> | <path/theme.json>]... [--palette <id>] [--contrast] [--all-screens] [--out <folder>]` (default `$TMPDIR/mydata-theme-preview`; it refuses a folder inside the checkout). About a minute for System and the six.
- **Steps**, each a `flutter test` with `--dart-define`s (`MYDATA_PREVIEW`, `_THEMES`, `_PALETTE`, `_CONTRAST`, `_ALL_SCREENS`); the code is mydata_testing's `lib/src/theme_preview.dart`:
  1. **Check** (mydata_ui's `test/theme/theme_preview_test.dart`): each file through `validateThemeText`, every palette in both modes at normal and increased contrast, into `<slug>/check.txt` (verdict, reasons, notices). A file in `design/themes`, or whose id is `mydata.<slug>` (a theme being ported), is checked as a built-in; anything else as an import would be. A refused theme fails this step and is not drawn; the others still are, and the command exits 1.
  2. **Screens** (each app's `test/theme_preview_test.dart`, `themePreview`): myContacts' people with Ava's page open, myCalendar's October 2026 with Friday 16 selected, myAssistant's chat ending in an approval card, and myData's Settings, Sources, inside the Mac window at 1280 × 900, light then dark, into `<slug>/<app>-<screen>.<palette>-<mode>.png`. The file is registered over the built-in with its id (`ThemeLibrary.addForTesting` now wins over a built-in), so an edited `design/themes` file is drawn before it is generated. System is drawn with the Mac's own blue accent and, in a preview run only, the Mac's own system font read from `/System/Library/Fonts` (committed screenshots keep Figtree). `--contrast` also draws every case at increased contrast (`ThemeLibrary.debugIncreasedContrast`), since the apps do not follow the system's setting yet (2.3); `--all-screens` adds each app's other screens (the ones `MYDATA_SHOTS` drew) in each theme's default palette.
  3. **Sheets:** `<out>/<slug>.png`, a row per palette and mode, a column per app.
- **Retired:** `themeScreens`' `MYDATA_SHOTS` mode; `theme_screens_test.dart` keeps its 12 goldens per app and `themesDistinct`. The validator is exported from mydata_ui (`validateThemeText`, `ThemeCheck`).
- **Kept working:** without `MYDATA_PREVIEW` each app's preview test draws Kiwi's file once into a temporary folder, and mydata_ui's tests check the loader, the refusals and the sheet.
- **Re-rendered 2026-10-24:** System and the six, all 18 palettes: every theme passes, every picture was drawn, and the sheets were looked at. Seen there, already listed above: a drawn theme draws its focus ring around the selected contact at launch, in its `focus` colour (red in Kiwi and Hairline), where the Mac draws only its accent fill. The 13 prototypes run through the check step are all refused, as expected: they have no `palettes` or `default-palette` (their colours are at the top level, and three have a top-level `contrast`), so each needs the port of phase 4 before it can be drawn.
- **Not done:** the branded frame (Windows, Linux, the web) is not drawn, only the Mac window; nor phone widths. The theme fuzz (2.5) still pumps the gallery's scenes, not these screens.

**Phase 4, batch 1 as built (2026-10-24): High Contrast, E-ink and Large.** Each ported from its prototype (`contrast`, `still`, `roomy`) into `design/themes/<slug>/` with its `RULES.md`, three palettes each, drawn through the harness in every palette, light and dark, at both contrast levels, and looked at. Each is in every app's gallery and myData's Appearance (the library lists `design/themes` in `builtInOrder`).

- **High Contrast** (Blue, Yellow, Cyan): text at 7:1 in every palette (accessibility-first: `accessibility.text-contrast` in its file, which the validator reads; it first knew it by id), 2 px ink edges, inverse selection, boxed tabs, Atkinson Hyperlegible Next and Mono, Material Symbols Outlined bold, and the new **double focus ring** (above, 3.2's rule and 1.2).
- **E-ink** (White, Cream, Grey): ink on paper only. The style fixes 17 roles to ink, paper or their greys (`colour-use.same-as`), so no palette brings a colour in; danger in ink passes the new colourless-danger rule (2.2); calendars as patterns, now also in myCalendar's Mac month and calendar list (`MacColourCheckbox` in ink, the mark and initial on each event); motion none, and the loader stays still (`KiwiLoader`). Rows and controls a size up (44 / 56, ×1.1) and chat in bubbles with an open month, so it is neither High Contrast in a serif nor Journal in black (`themesDistinct` caught both).
- **Large** (Blue, Green, Purple): 19 px body, nothing under 16 px, 52 / 58 px targets on the desktop and 56 / 64 on phones, 2 px outlines, an outline selection, Material Symbols Rounded. **The layout is unchanged** (decision 9); the one thing that grows is the Mac window's sidebar, in proportion to its rows' text past 16 px (`MacSidebar.width`, 247 px for Large; every other built-in keeps 208), and the gallery's scene sidebar likewise, so a section's name is never cut off.
- **Fixed on the way, for every theme:** faint text in the Mac window (a disabled item, another month's day) was `ink` at a quarter opacity, about 2:1; at increased contrast and in the accessibility themes it is now the grey that reads at 4.5:1 (`MacTheme.colorsFor(strongText:)`, `accessibilityThemes`); a drawn theme with boxed tabs marks the current Mac segment in `selection` (it was a faint tint); a theme whose lists are ruled rules its Mac form groups instead of boxing them (Journal's status and Settings changed: ink rules, as its rules say); the gallery's scenes clip what does not fit instead of overflowing (Large's month cells and status), set a name that cannot fit beside the avatar under it rather than breaking it mid-word, and draw no calendar colour in a pattern theme; the theme fuzz's copies hold null anywhere.
- **Fonts and icons added:** Atkinson Hyperlegible Next (with its italic) and Mono, OFL with no Reserved Font Name, Latin subsets (neither has Vietnamese nor the modifier apostrophe: `acceptedGaps`); Material Symbols Outlined and Rounded, Apache 2.0. Every app now carries 4.21 MB of fonts (myData 4.46 MB) of the 6 MB budget.
- **Tests:** `accessibility_themes_test.dart` holds each one's own promises: High Contrast's 7:1 text in every palette and mode, 2 px ink edges, double ring, inverse selection, nothing under 14 px; E-ink's 7:1, every role but the calendar colours a grey at both contrast levels, every duration zero, ruled pages; Large's 16 px floor and 19 px body, 52 / 56 px targets and 24 px icons, outline selection, 4.5:1 faint Mac text, and the skeleton unchanged but for the sidebar's width. The drawn built-ins in the tests and screen goldens now follow the library (`drawnBuiltIns`, `drawnThemes`), so each new theme gets its type, component, scene, icon and app-screen goldens and `themesDistinct` by being added.
- **Not done:** the Mac switch is drawn at the Mac's size in Large (since the review it takes the press over 52 px, as every Mac target there does, `accessibility.targets`); the brand dot of the frame's "Connected to your host" stays green in E-ink (`brand` never changes with a theme); a disabled control and another month's day are 4.5:1, not 7:1, in High Contrast and E-ink, so they still read as disabled; the Mac widgets' own 3 px ring has no keyline in High Contrast. None of the three has been seen on a real Mac.

**Batch 1, review fixes (2026-10-24).** A review of the three in the harness found these, now fixed: Large's Mac controls were 24 to 36 px where its rules promise 52 (`accessibility.targets: control`; `themeTargets` measures every target on each app's key screen and myData's Settings); an outline selection in a bordered list was covered by the list's outline (the ring is drawn over it, in every theme with a bordered list); Large's focus ring was danger's red (amber now); calendars in the Mac month were the source's colours with a 2.2:1 hairline or a faint tint alone (DataColour's 3:1 rule there too, in every drawn theme); E-ink's sidebar panel edge was half a point of ink, a 2.6:1 grey at 1x; E-ink's composer had no edge; plain buttons were bare words beside outlined controls (`button.plain: underline`); the boxed Mac month and its divider ignored the theme's line in High Contrast and Large; the accessibility promises were keyed on ids (`accessibility` in the file now); and the Mac windows overflowed at their smallest size, 720 by 480, in every theme (`themeNarrow` draws Large and High Contrast there). Left for the owner: E-ink's rows and controls a size up, bubbles and an open month were chosen partly so `themesDistinct` would pass against High Contrast and Journal; the harness draws the prototype's 40 / 48 density, transcript and table from a copy of the file for a side-by-side, and if those read better on e-paper the metric should count type family and colour use rather than steer the variants. The approval card keeps its 1 px `line-strong` edge in the 2 px themes, as its fixed structure says (`theming.md`); both themes' rules record it.

**Phase 4, batch 2 as built (2026-10-24): Terminal, Notebook, Brutalist and Retro Desktop.** Each ported from its prototype (`prompt`, `notebook`, `concrete`, `beige`) into `design/themes/<slug>/` with its `RULES.md`, three palettes each, drawn through the harness in every palette, light and dark (and at increased contrast), and looked at; each is in every app's gallery and myData's Appearance.

- **Terminal** (Green, Amber, Cyan): JetBrains Mono everywhere, square, compact, inverse-video selection (`selection` and `on-selection` fixed to `ink` and `bg`), nothing that moves. A palette is the phosphor's hue: grounds, ink, lines and accent take it at the prototype's lightness and chroma. JetBrains Mono gains a bold (`JetBrainsMono-700.ttf`, a static instance cut by `tool/subset_fonts.sh`'s new `CORE` list), so the label is 700, not 500.
- **Notebook** (Blue, Green, Violet inks): Kalam titles (display-only, its bold alone: **a static font loaded on demand**, `CatalogueFont.staticWeight`), Newsreader text with its italic (pinned at optical size 16), a highlighter selection, ruled paper. **Changed from the prototype:** the margin rule is gone (the apps' columns start at their own edge, so three rules in it crossed names and the chat), and lists are plain with no separators (`list: plain`, `separators: none`), because a list's own rules beside the paper's doubled every line; a Mac form group in such a theme is bare (`MacFormSection`, Terminal's too). Text on the 28 px pitch everywhere (a forced strut) stays phase 6's.
- **Brutalist** (Blue, Yellow, Green): Archivo Black titles (static, with Space Grotesk behind it for the Vietnamese, `ẞ` and `ʼ` it lacks), Space Grotesk text, JetBrains Mono rather than Space Mono, 3 px ink edges, offset shadows in the accent in dark, brutal primary, inverse selection; the style fixes six roles to `ink`. Yellow is a poster: a yellow ground with a black primary in light (no yellow accent is 3:1 on white), yellow on black in dark.
- **Retro Desktop** (Grey, Beige, Teal): Pixelify Sans titles, Atkinson Hyperlegible Next text, **Pixelarticons** at 24 px (32 px rows and controls rather than the prototype's 28 and 30, so the icons' pixels land on screen pixels), bevelled buttons, a dotted desk, a solid selection and a **double focus ring**, since no one ring colour is 3:1 on both the light panels and the dark selection (2.3).
- **Fixed on the way, for every theme:** today in myCalendar's Mac month takes the theme's shape (`MacMonthGrid.todayRadius`): a disc or a ring is round (Hairline's, Paperback's and Large's discs, Notebook's ring in pen) unless the theme's corners are square (Terminal, Brutalist, Journal), and an inverse mark takes the control corners (High Contrast's 8 px); System keeps the system's capsule. (The first cut gave every theme its control corners, which turned Hairline's, Paperback's and Large's discs and Notebook's ring into rounded squares against their rules; the review caught it.) A Mac form group is bare where the theme's lists are plain with no separators.
- **Tests:** `themesDistinct` takes `alike`, pairs allowed under the bar on one screen with the reason said in the test: Notebook and Paperback on myData's status (0.26; the ruled paper is fainter than the metric's edge step) and, since the review, Terminal and Retro Desktop on myAssistant's approval (0.29; both box each result and the approval card in a thin dark line). High Contrast and Brutalist (0.15) and Terminal and Retro Desktop (0.13) on myCalendar's Mac month were allowed until the review's panels set them apart (0.26 and 0.25 now, over the month's 0.18). Each exception is the score it was measured at and has a floor: the pair fails when it drifts more than 0.02 under it, and when it clears the bar (a stale exception goes); a key may name the pair in either order and one that names no pair fails (`distinctProblems`, tested in mydata_testing). Every other pair of the thirteen drawn themes clears the bar on all four screens. The type golden of Notebook is taller (40 px handwriting on a 28 px pitch). `themeNarrow` draws all four at the smallest window (720 by 480) on each app's key screen too, beside Large and High Contrast (`narrowThemes`); a record's labels go above their values wherever a value would otherwise break inside a word (Terminal's and Retro Desktop's records did).
- **Fonts:** Kalam, Newsreader, Archivo Black, Space Grotesk, Pixelify Sans (OFL, no Reserved Font Name, Latin subsets) and JetBrains Mono Bold; Pixelarticons (MIT). Every app now carries 5.00 MB of fonts (myData 5.24 MB) of the 6 MB budget, counted untrimmed.
- **After the review (2026-10-24):** in Brutalist and Retro Desktop (bordered lists with a slab's depth) the Mac panes are panels on the window's ground (`MacPanel`: the contact list and record, the month and the day list; the column ground is `bg` or the dotted desk, the skeleton the Mac's), and toolbar items and form groups cast the theme's drop; the bevel lines stay on the shared widgets and the panels. The source list draws no elevation. Retro Desktop's Mac form groups keep the theme's small radius (its panels are square elsewhere); increased contrast changes colours only, so Notebook's ruled paper and Retro Desktop's dots stay (2.3 wants them solid; the apps do not follow the system's setting yet); Notebook's rules stay put while a list scrolls. None of the four has been seen on a real Mac.

**Batch 2, review fixes (2026-10-24).** A review of the four in the harness found these, now fixed: today in the Mac month had become a rounded square in Hairline, Paperback, Large and Notebook (a disc or ring is round again unless the corners are square; a test pins the shape per `components.today`); Brutalist read as a square High Contrast in the Mac window (its panes are slabs now, toolbar items and form groups cast its offset shadow, form rows and day lists are ruled in its 3 px, switches are square) and Retro Desktop's list and record sat on the dotted desk (both draw their panes as panels, `MacPanel`; Brutalist Yellow's ground now shows between them); Terminal's, Notebook's, Journal's and Paperback's search field and composer were boxes although their fields are underlined; Terminal's results had no card edge (a result is boxed where lists are plain but cards outlined, Hairline too); a bare form group's heading looked like its rows (Terminal's in its upper-case label, Notebook's in its handwriting); Notebook's record labels sat off their values' baseline (every theme's are on it now); quick actions had a grey ground in themes with no icon tiles; a disabled toolbar item kept Brutalist's full ink edge; Pixelarticons drew clear and close as one glyph and the month like an event added (a test refuses two meanings on one glyph); the tests drew JetBrains Mono's bold as its regular, so Terminal's goldens showed no bold; `themesDistinct`'s exceptions had no floor and an order-bound key; and nothing drew the four at the smallest window. Left as they are: Pixelarticons has no calendar with a tick; Brutalist's day list and form rules are 3 px but the Mac contact list has no rules between rows, as in every theme; Sticker's hard shadow does not reach the Mac panes (`MacPanel` takes the slab styles, offset and bevel, only).

**Phase 4, batch 3 as built (2026-10-24): Swiss, Blueprint, Arcade, Geometric and Zen.** Each ported from its prototype (`grid`, `cyanotype`, `neon`, `primary`, `ma`) into `design/themes/<slug>/` with its `RULES.md`, three palettes each, drawn through the harness in every palette, light and dark, and looked at; each is in every app's gallery and myData's Appearance.

- **Swiss** (Red, Blue, Green): Inter at its display optical size for the 800-weight titles (not Inter Tight: one family, not two), ink rules everywhere (`borders.colour: edge`), square, a bar selection, Material Symbols Sharp. **Danger stays today's red** (the prototype had moved it to a magenta), so in Red the accent is near danger and the primary and Approve are drawn in ink, as 2.2 says.
- **Blueprint** (Blue, Sepia, Green): the drawn grid, dashed card and list edges (controls solid), an outline selection, upper-case callouts, white chalk on a coloured board in dark. Its dark status fills are drawn from the board (the prototype's greys read blue), and its danger fill a step off the board, so increased contrast keeps danger red. JetBrains Mono, not Azeret Mono. **In the Mac window its panes are sheets on the grid** (`MacPanel` now also takes a bordered list on a patterned window, with no shadow unless the depth is a slab's), so no name sits on the grid.
- **Arcade** (Magenta, Cyan, Lime): Chakra Petch titles (its 600 alone, display-only) over Outfit, cut corners, a grid floor, the bright edge colour fixed to `line-strong`, a glow on the primary. **The Mac contact list draws each row as a card** where the theme's lists are cards (the row heights count the card gap); today in the Mac month stays a round ring and a calendar's colour bar a plain bar in a cut theme (cut at the theme's size they came out as a lozenge and a diamond).
- **Geometric** (Blue, Red, Green): Jost, 2 px ink edges, square, the yellow selection block (ink with yellow text in light, yellow with ink in dark), people as shapes, Phosphor Fill, and the **double focus ring** 2.3 foresaw (no one ring colour is 3:1 on both the dark grounds and the yellow block). Red is near danger, so its primary and Approve are ink.
- **Zen** (Indigo, Moss, Ochre): Shippori Mincho titles (600 alone, display-only, Literata behind it for the Latin Extended-A it lacks), **Manrope, not Zen Kaku Gothic New, for text** (cut to Latin the latter keeps none of its Japanese and lacks Latin Extended-A, so names would fall back mid-word in lists), hairlines, ×1.35 spacing, a 1.75 line height, no avatars, and a flat band with its hairline rather than the native toolbar.
- **Tests:** `themesDistinct` takes nine more exceptions, each with its score and reason in the test: Brutalist and Swiss (0.22), Blueprint and Swiss (0.27), Arcade and Brutalist (0.24), Brutalist and Geometric (0.14) and Arcade and Geometric (0.21) on myData's status; Swiss and Terminal (0.13), Blueprint and Retro Desktop (0.13), Arcade and Kiwi (0.17) and Geometric and High Contrast (0.15) on myCalendar's Mac month. The Mac month is one grid in every theme and myData's status the same boxed groups, so the boxed and ruled themes meet there; each pair clears the bar on the other screens. `themeNarrow` draws all five at the smallest window (no overflow). Zen's type golden is taller (its line heights).
- **Fonts and icons:** Chakra Petch (SemiBold), Outfit, Jost and Shippori Mincho (SemiBold), OFL with no Reserved Font Name, Latin subsets (Outfit and Jost lack Vietnamese, Jost the modifier apostrophe: `acceptedGaps`); Material Symbols Sharp (Apache 2.0). Every app now carries 5.32 MB of fonts (myData 5.57 MB) of the 6 MB budget, counted untrimmed: about 0.43 MB is left for Ledger, which can take Inter (bundled) for Inter Tight.
- **Not done:** the Mac month draws the same grid in every theme, so Arcade's separate cut cells and Blueprint's mono day numbers are not drawn; Geometric's people as shapes do not reach the Mac contact list (it has no avatars in any theme) or a record with a photo; a Latin Extended-A name in a Zen title mixes Literata's letters into Shippori Mincho's; Blueprint's three dark palettes all have a white accent (the validator notes it; the board tells them apart). None of the five has been seen on a real Mac.

**Batch 3, review fixes (2026-10-24).** A review of the five in the harness found these, now fixed: Geometric's today was a square in the Mac month (a disc is round in every theme now; a ring is square where the corners are, as Journal's); a bar selection lost its bar under the keyboard ring in every Mac contact list (the ring stands inside the bar; Swiss, Arcade, Kiwi, Hairline and Journal showed it); the shared list ringed an outlined tint in `ink` (Zen's and Sticker's are in `selection`, as their sidebars), and Zen's Indigo tint was a neutral grey; an accent icon (a tile, a record's quick actions, a result's icon) was red where the accent is near danger (ink now, as the primary: Swiss and Geometric in Red); Arcade's square avatars were not cut and its shared list cards had no edge; the record's quick actions left one alone on a second line at the smallest window (they close up, or the name goes under the avatar, where they then fit; Large's three 52 px targets still wrap), and its source badge was left alone under the name (it follows the name's last line); the Mac form groups were a neutral shade of `ink` in themes that edge their cards (they are their `surface-raised` panels now, and Arcade's daylight hover is lavender); Blueprint's bordered lists had a solid box (dashed now, controls solid); the Mac column dividers and the sidebar panel were the faint `line` in themes whose borders are their `edge` (Swiss's ink; `MacPanel.divider`); and Phosphor Fill's carets and check read as a play button and a ticked box (they stay Phosphor Bold strokes). Corrected in the rules rather than built: Arcade's tabs are sentence case and its month is ruled in the faint `line`; Blueprint's record values are in the body face, not mono, and its grid shows only in the 8 px gutters on myContacts' people; Geometric's current tab is the yellow selection. `themesDistinct`'s exceptions moved with the white panels and ink dividers: Arcade and Brutalist 0.24, Arcade and Geometric 0.21, Brutalist and Swiss 0.22, Blueprint and Swiss 0.27 (new) on myData's status, Swiss and Terminal 0.13 on the month: nine for batch 3 in all (the first count said seven, for eight). Left as they are: myAssistant's composer in Blueprint is a `FloatingBarSurface` with `field: true` and takes the dashed card edge, though its rules keep a field's edge solid (seen in the approval goldens, from before this review).

**Phase 4, batch 4 as built (2026-10-24): Ledger.** Ported from its prototype (`tabular`) into `design/themes/ledger/` with its `RULES.md`, three palettes (Teal, Green, Blue), drawn through the harness in every palette, light and dark, and looked at; it is in every app's gallery and myData's Appearance. With it all twenty built-ins are in.

- **Ledger:** Inter with tabular figures (its display optical size for the titles, not Inter Tight, as in Swiss), a 13 px body, compact on the desktop (28 px controls, 26 px rows, 16 px icons, ×0.75), regular on phones; table lists, a bar selection, boxed tabs, the transcript chat, a table month with today an ink block, grey rules (`edge` fixed to `line-strong`), Tabler Light. Green is green-bar paper: its stripes and grounds take a pale green. **Layout stays out:** the prototype's columns (email, phone, source) and narrow inspector are not drawn; the contact list stays one column of names, drawn as a table.
- **The table in the Mac window:** where a theme's lists are tables, the Mac contact list is a table across the pane: each letter a header band on `surface-sunken` with a `line-strong` rule under it, the letter lined up with the names, and every second row of a letter group on `stripe` (zebra stripes, started again under each letter). The branded frame's table (`GroupFrame`, the shared `ContactList`) was built in phase 3; no built-in used it before Ledger.
- **Tests:** `themesDistinct` takes one more exception: Ledger and Terminal on myCalendar's Mac month (0.15; the same ruled table month with today an ink block, other type), clearing the bar on the other three screens. `themeNarrow` draws Ledger at the smallest window (no overflow). The Mac table has its own test (`mac_frame_test.dart`).
- **Fonts and icons:** none added (Inter, JetBrains Mono and Tabler are bundled), so the font budget is unchanged: 5.32 MB per app (myData 5.57 MB) of 6 MB.
- **Not done:** today in the Mac month is an ink block on the day's number, not the whole cell the prototype drew (the branded month inverts the whole cell); phone numbers stay in the body face, not mono (the format cannot set a face per value); the name Ledger is also a hardware-wallet company's (the prototype had been renamed Tabular for that; the owner chose Ledger, a common word). Not seen on a real Mac.

**Font budget before batch 2 (measured 2026-10-24).** `fonts_test.dart` counts every font an app carries untrimmed (4.21 MB per app, myData 4.46, of 6 MB), Material Icons' 1.57 MB included, as debug and profile builds carry them. A release build tree-shakes every icon font to the glyphs it draws: myCalendar's release app carries 2.64 MB of fonts, its Material Icons 1.2 KB. The budget stays counted the conservative way until the owner says otherwise. Batch 2's prototypes name 13 families not bundled yet: Kalam and Newsreader (Notebook), Archivo Black, Space Grotesk and Space Mono (Brutalist), Pixelify Sans (Retro Desktop), Inter Tight (Swiss, Ledger), Azeret Mono (Blueprint), Chakra Petch and Outfit (Arcade), Jost (Geometric), Shippori Mincho and Zen Kaku Gothic New (Zen); and two icon sets, Pixelarticons and Material Symbols Sharp. Before porting: measure each Latin subset (`tool/subset_fonts.sh`), prefer upright-only subsets and the fonts already bundled (Inter for Inter Tight, JetBrains Mono for Space and Azeret Mono, Instrument Sans for Space Grotesk as Blueprint's display), and cut a family that does not earn its place. **After batch 2:** 5.00 MB per app (myData 5.24); Space Grotesk is bundled now (Brutalist), so Blueprint may take it; Newsreader with its italic (0.49 MB) was the heaviest addition. Batch 3 has about 0.76 MB left: Chakra Petch, Outfit, Jost, Shippori Mincho and Zen Kaku Gothic New, and Material Symbols Sharp.

Goldens in total come to about 300 to 400 images, not the 1,600 of every widget in every look. Widget goldens stay at System and Kiwi; variants are covered once each; themes are covered on app screens.

---

## 6a. Found in the critique (2026-10-23), still open

- **One validator, one preview harness.** Both exist (2026-10-24: the validator since phase 1, `mydata_ui/lib/src/theme/validate.dart`, the batch-3 and critique pairs together; the harness since phase 3½, `app/tool/preview_themes.sh`, section 5). What stays open: the 13 prototypes are drawn from it only once each is ported (phase 4). Three batches built three validators and three preview generators, and they disagreed on six rules (heading's font stack, patterns under surfaces, the highlighter's marker, avatar initials, status colours at increased contrast, the ring on a filled row). Keep it to one validator (the Dart one, with `critique/contrast.py`'s pairs) and one preview harness, and judge each prototype from the harness once ported; the prototype previews are not like for like, which flatters some themes.
- **Disabled controls at 45% opacity** put a filled button's label at 1.4–1.6:1 in every theme. **Decided 2026-10-23:** a disabled filled button uses `surface-sunken` with an `ink-muted` label (about 4.5:1) in every theme, Kiwi included, from phase 3; other controls keep 45%.
- **Name spoofing.** "A name equal to a built-in's gets (imported)" misses look-alikes ("Кiwi" with a Cyrillic К). Compare the UTS #39 confusable skeleton, not the case-folded string.
- **Numbers in JSON.** Refuse `NaN`, `Infinity` and numbers whose exponent overflows a double; Python's `json` accepts `NaN` by default, so the prototype validators would pass a file the Dart parser refuses. Done in phase 1 (`strict_json.dart`).
- **Image decode.** Decode imported images in an isolate with a time limit, and check the header's width and height against the caps before decoding (a 4 MB PNG can declare 30,000 × 30,000).
- **Use everywhere clears every per-app choice.** It has an Undo toast in the gallery and myData's Appearance, since it cannot be told apart from a slip (phase 2).
- **Windows contrast themes and forced colours** are not seen by Flutter (`MediaQueryData.highContrast` is iOS and Android only), so System on Windows cannot follow them yet. Unverified whether a platform channel can read `SPI_GETHIGHCONTRAST`.
- **Latin gaps in the bundled fonts** (`fonts_test.dart`, `acceptedGaps`): Figtree, Instrument Sans and Sora have no Vietnamese, and they, Plus Jakarta Sans and Manrope no modifier apostrophe (ʼ), so those letters come from the platform's font mid-word ("Nguyễn" in Kiwi's body, Journal's body and Frosted's titles). Fredoka lacks much of Latin Extended-A (ő ș ț ě İ) and takes it from Nunito, the next font of Sticker's stack, which is narrower and squarer. Only Inter and JetBrains Mono have the key symbols (⌘ ⌥ ⌃ ⇧; ⌫ in Inter alone), so every other drawn theme draws a shortcut hint's symbols in the platform's font: fine on macOS, unverified on Windows and Linux. A test fails when a role cannot draw a name in its stack outside these.
- **CJK and other scripts.** Fonts ship as Latin subsets, so Zen's Japanese fonts draw only Latin; Japanese, Devanagari and other names fall back to the OS fonts (and, on the web, to `fonts.gstatic.com` until `fontFallbackBaseUrl` points at the host). Shippori Mincho with Japanese is about 8.6 MB per weight.
- **Editor scope for format 1.** 44 roles × 2 modes plus 12 variant groups is too much for a first editor. Ship seeds, the variant pickers and type, shape and density presets; derive everything else; keep "More colours" behind a disclosure; leave materials and images for phase 6.
- **Previews use synthetic data only:** Ofcom's drama range (+44 7700 900xxx) or NANP 555-0100 to 0199, `example.org`/`.com`/`.net`. The batch-3 preview had "+64 21 555 0100", a normal New Zealand mobile number; it is fixed.

## 6. Decided (2026-10-23)

The owner accepted every recommendation (`docs/decisions/2026-10-23-themes.md`):

1. Built-in theme files are **CC0-1.0**, so a shared duplicate carries no AGPL obligation.
2. Fonts are **bundled as Latin subsets in every app**, with a test that fails above the cap (6 MB per app).
3. **No images in theme files until phase 6**; decide then, after using Frosted and Notebook.
4. **Build new themes in batches** and cut any that does not earn its place in the real app. Which new themes: all twenty (the owner, 2026-10-23).
5. **The new disabled style** for filled buttons (6a), in every theme.
6. **Kiwi's visible changes** from the contrast audit (link colour, glass at 80–84%) land in phase 3.
7. **Accent near red:** Approve and filled primary buttons are drawn in `ink` (2.2, "Kept apart").
8. **Upper case** only on label and caption roles that never hold a name (2.3).
9. **Layout stays out of themes.** Folding details or opening the calendar on the day list is a later device accessibility setting.
10. **Mode per device,** not per app; **phones one theme per app,** no Use everywhere, until native phone apps.
11. **View > Theme… on ⌥⌘T,** unless Apple's own apps use it. They do (Show or Hide Toolbar), so Theme… shipped with no key (phase 2); the owner then picked **⌃⌘T**, on macOS only (14 below).
12. **Themes are named after their design language,** not a colour (later the same day): Kiwi stays (the house style); Graphite → Hairline, Dusk → Frosted, Plum → Journal, Rose → Sticker, Amber → Paperback; for the prototypes, Contrast → High Contrast, Still → E-ink, Roomy → Large, Prompt → Terminal, Notebook stays, Concrete → Brutalist, Beige → Retro Desktop, Grid → Swiss, Cyanotype → Blueprint, Neon → Arcade, Primary → Geometric, Ma → Zen, Tabular → Ledger.
13. **Colour is a separate choice inside a theme** (1.6): a theme is a style plus 2 to 4 palettes named by colour; the user picks theme and palette per app and per device; System's colour is the system accent, with no alternatives on macOS.
14. **The "open for the owner" items, decided (later the same day):** all twenty themes ship as built-ins, each with 2 to 4 palettes; a choice of Kiwi in an old colour moves to that colour's theme with a one-time notice (4.2); no "System, tinted" on macOS (1.6); View > Theme… is ⌃⌘T on macOS, and Windows and Linux (where Ctrl+T is myCalendar's Go to Today) reach the gallery from myData's Appearance.

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

**Not verified:** the system font family names on Windows and Linux; the font bundle size; whether `FontLoader` can reload a family; App Groups on a free Apple account.
