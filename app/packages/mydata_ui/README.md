# mydata_ui

The myData design system in Flutter. `design/` at the repo root is the source of truth; this package implements it.

- **Tokens** (`lib/src/generated/tokens.g.dart`) are generated from `design/tokens.json` and `design/themes.json` by `dart run tool/generate_tokens.dart`, which also copies the logo files from `design/assets/Logos`. `test/generated_tokens_test.dart` fails when either is stale. Token names map one to one: `accent` is `context.colors.accent` (`MyDataColors`), `space-4` is `MyDataSpace.s4`, `radius-lg` is `MyDataRadius.lg`, `body-strong` is `MyDataType.bodyStrong`.
- **`MyDataTheme(themeId:, mode:)`** gives `light`, `dark` and `themeMode` for `MaterialApp`. The theme id comes from the host and is the same in every app; the mode (light, dark, match system) is per device.
- **No literals.** No widget or app may contain a literal colour, radius or font name; `test/no_literals_test.dart` scans every app and package and fails if one appears outside the generated file.
- **Motion** (`MyDataMotion`, from `design/motion.md`) and **accessibility**: `MyDataAccessibilityScope` follows the system's reduced motion and reduced transparency (read from macOS over the `mydata/accessibility` channel in each app's Runner; Flutter has no reduced-transparency flag). The web build always uses solid bars.
- **Fonts:** Plus Jakarta Sans 700, Figtree 400 and 600, JetBrains Mono 400, with their licences (`assets/fonts/OFL-*.txt`, registered by `registerMyDataLicenses()`).
- **Tests:** goldens for every widget in Kiwi and Graphite, light and dark (`test/widgets/goldens`), using `package:mydata_testing`, which loads the bundled fonts in tests.

## Where design/ disagreed with itself (decided 2026-10-12)

The specs, previews and top-level docs were checked against each other; the owner decided these:

- **Spec against preview:** the selected ThemePicker swatch has a 2px `ink` ring and no shadow (preview). GroupedList: at most three tile colours per screen (spec; the preview's four is wrong).
- **Values the preview uses that are not tokens** (14px and 10px gaps, 13/22 text, a 14px tab label): the nearest token or type style.
- **Defaults accepted:**
  - "Needs approval" is a `warning` chip; after a decision the chip is the past tense of the action ("Sent", "Deleted") in `success`, "Rejected" in `surface-sunken` / `ink-muted`, and a failure is a `danger` "Failed" chip with the error.
  - Sheets use `surface-raised` (README), not `surface` (tokens.json).
  - The card header name is `body-strong`; cards are `space-4` apart; buttons are `space-2` apart.
  - Chips are 26px and not tappable; tabs are `control-height` (44px), not the preview's 40px.
  - The tab and segmented-control pill is a separate thumb that slides with `spring`; with reduced motion it jumps.
  - A press scales to 97% and dims to 85% at once and returns over `fast`. Cards enter with a fade and an 8px rise over `base`, 30ms apart, at most six; with reduced motion, a `fast` fade.
  - A switch row is a GroupedList row with an optional icon tile. An untinted tile is `surface-sunken` with an `ink-muted` icon. Rows that do something get hover and press fills and a focus ring.
  - Search fields are borderless pills on `surface-sunken` (spec). Path and address fields use the mono font.
  - The assistant's input bar is a glass FloatingBar. The solid fallback is `surface` with `shadow-2` and no stroke.
  - Loading: the kiwi mark on a round `paper` badge, turning; still with reduced motion. A placeholder until the kiwi slice is drawn.
  - Appearance has theme and mode only; transparency and motion follow the system; density and text size are not built. Cover (a preview with no spec) is not built.
- **Flagged, not changed:** `theming.md` says each theme's light and dark accents are the same hue with the dark one no more saturated; by calculation this fails for Kiwi and Amber (8–10° hue shift). The contrast rules all pass (`test/theme_test.dart`).
