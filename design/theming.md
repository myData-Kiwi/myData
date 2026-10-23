# Theming

The default theme is Kiwi, in whichever mode the device uses. People can change it. Settings live in the myData app under Settings, Appearance, are stored on the host, and apply to every app.

**On macOS the accent is the system's** (the Mac shell; `platforms.md`), and the host's theme does not change it. The six themes become accent options (Settings, Appearance, Accent: System, Kiwi, Graphite, Dusk, Plum, Rose, Amber; System the default on the Mac) in M1a's look pass; until then they colour the branded frame on the other platforms. Density on the Mac is the platform's, not a setting.

## What the user can set

| Setting | Options | Default | Where it applies |
|---|---|---|---|
| Theme | Kiwi, Graphite, Dusk, Plum, Rose, Amber | Kiwi | All apps, all devices |
| Mode | Light, Dark, Match system | Match system | Per device |
| Transparency | Glass bars, Solid bars | Glass; solid when the system reduces transparency | Per device |
| Density | Comfortable, Compact | Comfortable; Compact is desktop only | Per device |
| Text size | Small, Default, Large, Larger | Default, scaled by the system setting | Per device |
| Motion | Full, Reduced | Full; reduced when the system asks | Per device |

## Themes

A theme replaces three tokens and nothing else: `accent`, `on-accent` and `accent-soft`. The grounds are neutral grey with no tint, so every theme sits on the same grounds. Text, lines, status colours, `brand`, type, shape and layout are the same in every theme.

| Theme | Character | accent (light / dark) | on-accent (light / dark) | accent-soft (light / dark) |
|---|---|---|---|---|
| Kiwi | The brand greens. The default | `#4C7814` / `#A9CC4E` | `#FFFFFF` / `#1A2408` | `#EBF3DA` / `#28331A` |
| Graphite | The neutral theme: greys only, no colour | `#232323` / `#E6E6E4` | `#FFFFFF` / `#161616` | `#E7E7E4` / `#2C2C2C` |
| Dusk | A calm blue | `#3D5AA9` / `#9DB4F2` | `#FFFFFF` / `#0E1A3A` | `#E5EAF8` / `#232C47` |
| Plum | Purple | `#7A3E8E` / `#D2A6E0` | `#FFFFFF` / `#2A0F33` | `#F1E4F5` / `#3B2145` |
| Rose | A deep pink | `#A63A5B` / `#EFA3B8` | `#FFFFFF` / `#33101C` | `#F8E3E9` / `#40222B` |
| Amber | A warm orange-brown | `#8A5100` / `#F0B45A` | `#FFFFFF` / `#2E1B00` | `#FBEBCF` / `#3D2C0C` |

`themes.json` holds the same values in a form code can read. `tokens.json` holds the Kiwi values and everything a theme does not change.

Things to design for:

- **Graphite's accent is almost the same colour as the text.** A link cannot stand out by colour alone, so links are underlined in every theme.
- **Kiwi's accent is green and so is `success`.** A success state is never shown by a green fill alone; it always has a word or a check mark. Avoid placing an accent icon tile directly beside a success icon tile.
- **Amber's accent is the same hue as `warning`.** Warnings always carry a word.

Rules for adding a theme:

- `on-accent` on `accent` at least 4.5:1 in both modes.
- `accent` as text on `bg`, `surface` and `accent-soft` at least 4.5:1 in both modes.
- `ink` on `accent-soft` at least 4.5:1 in both modes.
- The light and dark values are the same colour family; the dark value is lighter.

All six themes pass the contrast rules above by calculation in both modes. They have not been checked by eye on real devices.

## Choosing a theme

- First run offers the choice on one screen, with Kiwi selected.
- Afterwards it lives in myData under Settings, Appearance, as the ThemePicker component.
- Choosing a theme applies at once, with no Save button.

## What does not change

- The logo keeps its own colours in every theme.
- `brand` stays kiwi green in every theme.
- Status colours keep their meaning in every theme.
- Layout, type, shape and wording are the same in every theme.

## Custom themes

A later version may let the user pick any colour. When it does, the app derives the three tokens from the chosen hue and refuses a colour it cannot bring to the rules above, showing the nearest one that passes.
