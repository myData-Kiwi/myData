A small row of colour swatches for choosing the colour of a calendar that myData owns. The colours come from a fixed palette.

- **Use it** to set an owned calendar's colour when it is created or edited.
- **Do not use it** for the app's theme (ThemePicker), or for a calendar that myData follows: that colour belongs to the source, myData never writes to a source, and the calendar list shows it without offering a change (DataColour). There is no colour wheel, hex field or "Other colour". A fixed palette keeps every calendar's colour one the design system has checked, and keeps the choice short.
- **The colours are data colours** (DataColour), not theme colours: each is one value used in both modes, drawn exactly as given, with DataColour's edge rule. They never become a control colour or a fill behind text. The picker's own marks (hover, selection, focus) use theme tokens.

- **Anatomy:**
  - the label "Colour" above, in the `label` style and `ink`, `space-2` above the swatches, as any field in a form (FormRow);
  - a row of swatches, `space-2` apart, in palette order. It wraps when the row is too narrow;
  - each swatch is a round target `control-height` wide and tall (`radius-pill`) holding a disc of the colour at `icon` size (20px), centred. The disc is DataColour's swatch shape, used only here;
  - under the row, the chosen colour's name in `caption` and `ink-muted`, `space-2` below ("Blue"). The name is there so the choice never depends on telling colours apart.
- **The palette:** Red, Orange, Yellow, Green, Blue, Purple, Brown, Grey, in that order. These are Apple Calendar's seven named colours plus grey, so a calendar from Calendar.app is likely to find its colour by name. The values are under Tokens.
- **A colour that is not in the palette:** a calendar imported with its own colour keeps it exactly, and is never moved to the nearest palette colour. The picker then shows one more swatch at the end, "Current colour", already chosen. Picking a palette colour and saving replaces it, and after that "Current colour" is gone, because there is no way to choose it again.
- **A new calendar** starts with the first palette colour that no owned calendar uses yet, or with Red when all are used.
- **States** (a swatch):
  - Rest: the disc on the ground of the part it sits in, with no mark.
  - Hover: a 1px `line-strong` edge inside the target, with no fill, appearing and going with `fast`, as MonthGrid's hover. There is no hover edge on the chosen swatch.
  - Pressed: the shared press. It dims to 85% and scales to 97% at once, and returns over `fast`.
  - **Chosen:** MonthGrid's selection, on a round target: an `accent-soft` fill and a 2px `ink` ring inside the target's edge, around the disc. The ring is the signal. In Hairline's Graphite in light mode `accent-soft` is close to `surface-sunken`, and the swatch's own colour is never used to show selection. There is no check mark on the disc: a check would need a colour that shows on every swatch, and the ring already marks the choice.
  - Focused: the 2px `focus` ring, 2px outside the target, from the keyboard. On the chosen swatch, both rings show.
  - Disabled: none. A calendar whose colour cannot be changed does not show the picker.
  - Error: none. There is always a chosen colour.
- **Edge rule:** a disc with less than 3:1 contrast against what it sits on (`surface`, or `accent-soft` when chosen) gets DataColour's 1px `line-strong` edge. Yellow on white, or a dark colour in dark mode, keeps its shape.
- **Keyboard:** the swatches are a radio group with one tab stop, on the chosen swatch. The arrow keys move to the next or previous swatch and choose it, wrapping at the ends, as ThemePicker does. Right and Down go forward, and Left and Up go back, whatever the wrapping on screen. In a form the choice applies on Save, with the rest of the form.
- **Screen readers:** a radio group named "Colour". Each swatch is a radio button named by its colour ("Blue", "Current colour"), with its state and position ("Blue, selected, 5 of 8"). The colour's name below the row is not read separately, because the chosen radio button already says it.
- **Motion:** the fill, ring and hover edge change over `fast`. Nothing moves, so reduced motion changes nothing beyond the shared press, which then does not scale.
- **Light and dark, Kiwi and Hairline:** the palette is the same in both modes. The marks are tokens, and the ring carries the choice in every theme. In Kiwi the Green swatch's chosen fill is `accent-soft`, a pale green behind a green disc. The ring still says it is chosen.
- **Desktop and phone:** on desktop the swatches sit in one row (eight 44px targets and their gaps need 408px; nine, with "Current colour", 460px, which fits the Dialog's body at `dialog-width`). Under 600px they sit in a grid of four columns, `space-2` apart, so the eight make two even rows of four (200px) rather than wrapping where the width happens to end (seven and one on a 358px phone); "Current colour", when present, starts a third row. There is no tooltip on a phone; the name under the row and the accessible name carry the colour's name. On desktop each swatch has the colour's name as its tooltip.
- **Sizes:** the target is `control-height` and the disc `icon` size. In the Compact density on desktop the target is `control-height-compact` and the disc is unchanged.
- **Copy:** the label is "Colour", the spelling DataColour uses. Colour names are one word in sentence case with no full stop: Red, Orange, Yellow, Green, Blue, Purple, Brown, Grey. The extra swatch is "Current colour". Never a hex value.
- **Tokens:** eight data colours in `tokens.json`'s colour list, named `data-*`. Each is **one value, used in both modes**: the host stores the chosen colour as one hex value, and DataColour draws a data colour exactly as given. The token therefore carries the same value under `light` and `dark`. A theme never replaces them.

  | Colour | Token | Value | On `surface`, light | On `surface`, dark | On `surface-raised`, dark | On `accent-soft`, light (six themes) | On `accent-soft`, dark (six themes) |
  |---|---|---|---|---|---|---|---|
  | Red | `data-red` | #D34730 | 4.5 | 3.9 | 3.5 | 3.6 to 3.9 | 2.99 to 3.2 |
  | Orange | `data-orange` | #EA700F | 3.1 | 5.7 | 5.1 | 2.5 to 2.7 | 4.3 to 4.6 |
  | Yellow | `data-yellow` | #E7BD1B | 1.8 | 9.7 | 8.8 | 1.4 to 1.6 | 7.4 to 7.9 |
  | Green | `data-green` | #36A462 | 3.2 | 5.5 | 5.0 | 2.6 to 2.8 | 4.2 to 4.5 |
  | Blue | `data-blue` | #159CE2 | 3.05 | 5.7 | 5.2 | 2.5 to 2.7 | 4.4 to 4.6 |
  | Purple | `data-purple` | #8B51E1 | 4.8 | 3.6 | 3.3 | 3.9 to 4.2 | 2.8 to 2.9 |
  | Brown | `data-brown` | #8A6859 | 5.0 | 3.5 | 3.1 | 4.0 to 4.4 | 2.7 to 2.8 |
  | Grey | `data-grey` | #939393 | 3.1 | 5.7 | 5.1 | 2.5 to 2.7 | 4.3 to 4.6 |

  - **Readable as a dot or bar:** seven of the eight reach 3:1 on `surface` and `surface-raised` in both modes, so they need no edge on a form, a Dialog or a list. Yellow cannot, and still look yellow: it gets DataColour's 1px `line-strong` edge on every light ground. On the softer grounds the edge rule (under 3:1) applies to: Orange, Yellow, Green, Blue and Grey on light `accent-soft`, `bg` and `surface-sunken` (2.5 to 2.9:1); Purple and Brown on dark `accent-soft` (2.7 to 2.9:1), and Red on Kiwi's dark `accent-soft` (2.99:1). One value cannot reach 3:1 on both a pale tint and a near-black tint without making every colour the same lightness, which would make them harder to tell apart.
  - **Telling them apart:** the smallest colour difference between any two (CIEDE2000) is 17 (Red and Orange) with typical vision, and, simulated at full strength (Machado 2009), 10.9 for protanopia (Red and Brown), 10.5 for deuteranopia (Red and Orange) and 9.0 for tritanopia (Green and Blue). Their lightness (CIELAB L*) is 50, 61, 78, 60, 61, 48, 47 and 61 in palette order: one value for both modes keeps all but Yellow between about 47 and 62, so Green and Blue, and Purple and Brown, are neighbours of about the same lightness and differ in hue only. The colour's name under the row, in the tooltip and in the accessible name carries the choice whatever the user sees.
  - **Not a status:** Red is not `danger` (difference 10 from light `danger`, 18 from dark), and Green is not `success` or `brand` (at least 11.6).
  - **Names:** each value reads plainly as its name: a warm red, an orange, a golden yellow, a mid green, a sky blue, a violet purple, a greyish brown and a neutral grey.
- **The host stores** the chosen colour as a hex value on the owned calendar, as it already stores a source's colour, so a CalDAV client sees it later. Nothing names the palette in the data.

- **Used by:**
  - myCalendar new calendar: the colour, under the name (phase 6).
  - myCalendar edit calendar, for a calendar myData owns: the colour, under the name (phase 6).
  - myData import, calendars: the colour of a new calendar created to import into, already set to the colour in the file when the file has one (phase 6).
- **Decided 2026-10-14:** eight colours (Apple Calendar's seven named colours plus Grey), so the row fits a Dialog in one line and a phone in two rows of four; the values are those under Tokens.
- You provide the palette, the chosen colour, and for an imported calendar its current colour when it is not one of the palette's.
