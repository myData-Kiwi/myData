The control for choosing one theme's palette: the theme gallery's palette row (`design/themes/ARCHITECTURE.md` 4.4).

**Since phase 3** it chooses palettes, not themes. Themes are chosen on the gallery's cards (View > Theme… and myData's Appearance, `design/theming.md`), and the host-wide accent it used to pick is gone, with `themes.json` and the live sample that sat below it. The preview here still shows the six old colours: they are now the default palettes of Kiwi, Hairline, Frosted, Journal, Sticker and Paperback.

- One swatch per palette of the selected theme, in the theme's order, default first (Journal: Plum, Ink blue, Forest). Each swatch is a pill on `surface` with `shadow-1`, showing a disc of that palette's `accent` and its name. A theme with one palette, and System, show no row.
- The selected swatch has a 2px `ink` ring and a check mark in the disc. Selection is never shown by colour alone.
- It is a radio group: arrow keys move between swatches, and choosing one previews it on the whole window at once. There is no Save button; the gallery's buttons keep it.
- In the gallery it stays in view above the buttons while the cards scroll.
- You provide the theme's palettes (`ThemeLibrary.paletteSwatches`) and the current palette id; an id not among them shows the first as selected.
