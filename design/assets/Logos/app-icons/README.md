# App icons

One family, told apart the way Pages, Numbers and Keynote are: each app has its own colour and one large white glyph. The kiwi is myData's alone. The lime of the kiwi's wash (`#A9CC4E`) is the one detail the family shares. No corner badges, no text.

| App | Background (top to bottom) | Glyph | Dark appearance |
|---|---|---|---|
| myData | `#EAF4CB` to `#D9E8AE` (the logo's pale green) | the kiwi mark, without the logo's ground line | the same: the icon is green in every appearance |
| myContacts | `#5B7BD6` to `#3D5AA9` (Dusk) | a person, head and shoulders | `#9DB4F2` on dark grey |
| myCalendar | `#F2706B` to `#D23B3F` (Rose, brightened) | a calendar page with a deep red header, day dots and one lime marked day | a light red page on dark grey |
| myAssistant | `#A56BC2` to `#7A3E8E` (Plum) | a speech bubble with a lime spark | `#D2A6E0` on dark grey |

## Files

`make_icons.py` writes every source here and renders the apps' icon files. Edit the script, never its output.

| File | Use |
|---|---|
| `<app>.icon` | macOS 26 and later: the Icon Composer document (a gradient fill, the glyph's layers, dark variants; tinted and clear come from the same layers). Copied to `macos/Runner/AppIcon.icon`, which each Runner's Xcode project builds beside the asset catalog: actool puts both in `Assets.car`, and older systems use the classic icon. |
| `<app>.svg` | The classic macOS icon: the 824 px body on the 1024 px grid (100 px margin), continuous corners (superellipse, n = 5), the grid's soft shadow. The 128 to 1024 px files of `AppIcon.appiconset`. |
| `<app>-small.svg` | The 16 and 32 pt master: the same icon with a larger, simpler glyph (myCalendar without its dots, the kiwi without its feathers and with thicker lines). The 16, 32 and 64 px files, the web favicon and the small Windows sizes. |
| `<app>-tile.svg` | Web `Icon-192/512` and Windows `app_icon.ico`: the body filling the canvas, no shadow |
| `<app>-maskable.svg` | Web `Icon-maskable-*`: full-bleed square; the artwork inside the 80 % safe circle |

`--install` also writes `app/packages/mydata_ui/assets/app_icons/<app>.png` (256 px, macOS 26's own rendering by `ictool`): the icon an alert shows inside the app (`MyDataAppIcons`).

## Render

From the repo root (cairosvg needs Homebrew's cairo on a Mac; `ictool` is Xcode's, inside Icon Composer):

```
DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib \
  uv run --no-project --with cairosvg --with pillow \
  python design/assets/Logos/app-icons/make_icons.py --install --sheet /tmp/icons.png
```

`--sheet` writes a contact sheet: each `.icon` in macOS 26's six renditions (default, dark, tinted light and dark, clear light and dark), the classic icon at 128, 32 and 16 px with 16 and 32 enlarged on light and dark, a Dock at 64 px and a Finder list at 16 px.

## Not done

- Not yet seen in a real Dock, Finder or Spotlight on macOS 26 (the sheet is `ictool`'s rendering and a mock Dock): check it with the owner present.
- The `.icon` has one artwork for every size: Icon Composer takes no per-size masters, so on macOS 26 the 16 and 32 pt icons are the large glyph scaled down (they read, being one simple shape); the small masters serve older systems.
- Linux runners set no window icon, and there are no iOS or Android runners yet.
