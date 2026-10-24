# Large: design rules

`mydata.large` 1.0.0, CC0-1.0. New in phase 4 (2026-10-24), for accessibility; ported from the prototype `roomy` (renamed 2026-10-23). Large and simple, for low vision, unsteady hands and anyone who wants fewer, bigger things on screen. A household app has grandparents in it.

## Personality

Big, calm and easy to hit. Warm white, clear 2 px outlines, large rounded buttons with words, and room around everything. **The layout is the same as in every theme** (decision 9): the same screens, sections and order, only bigger. Folding details away, labelling every toolbar button or opening the calendar on the day list belong to a later per-device accessibility setting, not to this theme.

## Typography

| Role | Font | Size / line height / weight |
|---|---|---|
| Display | Atkinson Hyperlegible Next | 36 and 28 / 1.15 and 1.2 / 700 |
| Title, heading | Atkinson Hyperlegible Next | 24 / 1.25 / 700; 21 / 1.33 / 700 |
| Body | Atkinson Hyperlegible Next | **19** / 1.5 / 400 (body-strong 700) |
| Label, caption | Atkinson Hyperlegible Next | 17 / 1.4 / 700; 16 / 1.4 / 400 |
| Mono | JetBrains Mono | 17 / 1.45 |

No text under 16 px. The system's text size still scales it. Sentence case everywhere.

## Shape

Rounded: xs 6, sm 12 (buttons and controls), md 14, lg 18 (panels), xl 24.

## Density

Roomy: 52 px controls, 58 px rows, 24 px icons and spacing ×1.25 on the desktop; 56 / 64 / 24 on phones. Targets are twice WCAG 2.2's 24 px minimum (SC 2.5.8) and above SC 2.5.5's 44 px (AAA).

**Every target is 52 px or more, the Mac window's own included** (`accessibility.targets: control`): its toolbar items, "‹ Today ›" and segmented controls take the press over the band's full 52 px and as wide, the record's actions over 52 px squares, each of its values and each calendar in myCalendar's list over a 52 px line, and a switch over a 52 px square, while each is drawn at the Mac's size; the flat toolbar's rule is drawn over the band's foot so the items keep its height.

In the Mac window the skeleton stays the Mac's; the one thing that grows is the **sidebar's width**, in proportion to the rows' text past 16 px (`MacSidebar.width`: 208 × 19 / 16, 247 px), so "Recently Deleted" is never cut off. Every other built-in sets its rows at 16 px or less and keeps the Mac's 208.

## Colour use

- Warm white ground (#FFFDF7) and white panels; #121212 and #1E1E1E in dark.
- One calm accent for the primary button, links and the selection. The style fixes `selection` to the accent with `on-accent` on it, and `edge` to `line-strong` (`colour-use.same-as`).
- **Selection is an outline** (`selection: outline`): a 2 px ring in the accent, never a tint alone.
- 2 px `line-strong` outlines (#6B6B6B / #8A8A8A, 5.2:1 and 5.4:1 on the ground) on panels, fields and secondary buttons.
- Status and calendar colours as everywhere; data-yellow gets its edge in light mode.
- **Focus is amber** (#8A5300; #F2B544 in dark), not the house's red: a red box round the current item reads as an error, most of all to the people this theme is for. It is 4.7:1 or more on every ground it touches, 38° of hue from `danger` and 66° or more from every palette's accent, so it is never taken for the outline selection; on a selected row it stands inside the outline, so both show.
- In the Mac window, a disabled item and another month's day are a 4.5:1 grey, not the Mac's faint shade (`accessibility.faint-text: readable` in its file, as in High Contrast and E-ink).

## Palettes

| Palette | Id | Accent (light / dark) | `ink-muted` / `link` on `bg`, label on `accent` |
|---|---|---|---|
| Blue (default) | `blue` | `#1D5FBF` / `#8EB8FF` | light 9.6 / 6.0 / 6.1; dark 12.0 / 9.3 / 8.2 |
| Green | `green` | `#2B6A2E` / `#8FD392` | light 9.6 / 6.4 / 6.6; dark 12.0 / 10.6 / 9.3 |
| Purple | `purple` | `#6A3FB5` / `#D6A3FF` | light 9.6 / 6.9 / 7.0; dark 12.0 / 9.4 / 8.5 |

A palette moves the accent and its soft tint (the same lightness, the accent's hue); grounds, ink, status, focus and calendar colours stay. Every palette gives every role the style does not fix (all 43 once resolved) and passes `ARCHITECTURE.md` 2.2 in both modes and at increased contrast, where the link is derived to 7:1 (it is not fixed to the accent, so it can move).

## Depth and materials

A faint lift (`soft` at 0.25) on panels; solid ground, sidebar and bars.

## Icons

Material Symbols Rounded, regular, 24 px, filled when selected, on tinted tiles.

## Motion

`calm`: fades only; a press dims. Reduced motion: none.

## Components

| Part | Variant |
|---|---|
| Buttons | Filled rounded primary, 52 px; outlined secondary; plain ones (Cancel, Reject) underlined |
| Lists | Bordered panels, full separators |
| Selection | Outline |
| Avatars | Circles |
| Inputs | Outlined, 2 px |
| Tabs | Boxed, the current one filled (the Mac segmented control too) |
| Chat | Bubbles |
| Month | Boxed (in the Mac window too: its grid and the line beside the day list are 2 px of `line-strong`); today a filled disc |

## Do and don't

- Do give every icon a word and keep every target at 52 px or more on the desktop.
- Don't shrink text to fit: fewer rows show.
- Don't change what is on a screen or its order: that is a device setting, not a theme.

## Accessibility

- Text: ink 18.0:1 (light) and 17.2:1 (dark); secondary text 9.6 and 12.0:1.
- Each app's `theme_screens_test.dart` also draws its key screen in Large and High Contrast in the smallest Mac window, 720 by 480 (`themeNarrow`): nothing overflows. There myContacts' list narrows to 240 so the contact keeps 320, the avatar goes above a name that would break beside it, a record's label goes above its value, the search field gives up width, and myCalendar's day cells cut what does not fit.
- Each app's `theme_screens_test.dart` measures every target on its key screen in Large (`themeTargets`, myData's Settings too): none is under 52 px but a link inside a line of text.
- `accessibility_themes_test.dart` holds its promises: no role under 16 px, body 19, targets 52 / 56 and 24 px icons, 2 px outlines, an outline selection, faint Mac text at 4.5:1, and the Mac skeleton unchanged but for the sidebar's width.
- **The approval card's edge stays 1 px** `line-strong`, though every other card, field and button here is 2 px: the card's structure, its edge included, is the same in every theme (`theming.md`, "What a theme never changes"). Whether it may take a theme's border width is the owner's open question (CLAUDE.md).

## Fonts and licences

| Asset | Licence | Source (checked 2026-10-24) |
|---|---|---|
| Atkinson Hyperlegible Next | SIL OFL 1.1, no Reserved Font Name | https://github.com/google/fonts/tree/main/ofl/atkinsonhyperlegiblenext |
| JetBrains Mono | SIL OFL 1.1, bundled | https://github.com/google/fonts/tree/main/ofl/jetbrainsmono |
| Material Symbols | Apache 2.0 | https://github.com/google/material-design-icons/blob/master/LICENSE |

## Ported from the prototype

- Colours split into three palettes; three roles fixed by the style; the link derived at increased contrast.
- Research B's layout ideas (details behind "More", labelled toolbar buttons, the calendar on the day list) are left out (decision 9).
- The Mac sidebar widens with the text, so names are not cut off.
