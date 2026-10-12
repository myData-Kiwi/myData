The control for choosing a theme, with a live sample of each theme in light and dark.

- One swatch per theme, in this order: Kiwi, Graphite, Dusk, Plum, Rose, Amber. Each swatch is a pill on `surface` with `shadow-1`, showing a disc of that theme's `accent` and the theme's name.
- The selected swatch has a 2px `ink` ring and a check mark in the disc. Selection is never shown by colour alone.
- It is a radio group: arrow keys move between swatches, and choosing one applies it at once. There is no Save button.
- In Settings, a sample below the swatches shows the chosen theme in the current mode. This preview shows light and dark side by side so both can be judged.
- Mode (Light, Dark, Match system) is a separate SegmentedControl beside it. Theme and mode are independent.
- You provide the list of themes from `themes.json` and the current theme id.
