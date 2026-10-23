# System

`mydata.system`, the default for every app on every device. File: `theme.json` (frame `system`, nothing else). **It has no palettes:** its colour is the platform's accent, with no alternatives on macOS, so the picker shows no palette row for it (decided 2026-10-23). "System, tinted" (a custom `system`-frame theme whose palettes give an accent only) is never applied on macOS, and whether it exists at all is open for the owner (phase 5; `ARCHITECTURE.md` 1.6).

## Personality

Looks like the rest of your computer. myData disappears into the platform: the user's content and the kiwi are the only brand left. Nothing in this theme is ours to choose; every rule below says where the value comes from.

## Where each part comes from

| Part | macOS (today's Mac shell, M1a) | Android (its own pass) | Windows, Linux, web (until their own pass) |
|---|---|---|---|
| Frame | Native window, transparent title bar, unified toolbar, traffic lights, floating sidebar on the window's own sidebar material | Material 3 | Kiwi's branded frame, labelled "System: Kiwi until this platform's own look" in the picker |
| Colour | NSColor read live in both appearances (`mydata/system_colors` channel); `design/tokens.json` `macos` values are fallbacks only | Wallpaper colours through `dynamic_color` (Android 12+), else Material baseline | Kiwi's colours with the platform's accent where one can be read |
| Accent | The system accent (`controlAccentColor`), with no alternatives: a "System, tinted" file's accent is ignored on macOS | Dynamic colour | Kiwi green |
| Type | `.AppleSystemUIFont` (SF Pro through CoreText), never bundled. Body 13/16, title 15/20 bold, pane title 22/28 bold, caption 11/14 | Roboto (the device font) | The platform font: Segoe UI Variable on Windows (to verify), the fontconfig default on Linux (to verify), bundled Figtree on the web |
| Density | Mac: 28 pt controls, 24 pt list rows, 32 pt sidebar rows, 16 px icons | 48 dp targets | Kiwi's |
| Focus | The system ring (`keyboardFocusIndicatorColor`, follows the accent), on every control, red ones included | Material | Kiwi's red ring and its `ink` rule |
| Icons | Lucide (ISC), `MacIcons`, in place of SF Symbols (Apple's frameworks only) | Material Symbols (Apache 2.0) | Lucide |
| Motion | The platform's curves; reduced motion respected | Material motion | Kiwi's |

## Component styles on macOS (what the preview shows)

- **Buttons:** push buttons (24 pt capsules); the default button in the accent. Toolbar items are borderless icons with the flat Liquid Glass stand-in.
- **Lists:** one plain source list with section letters, no separators, no cards; the selection is the accent with white text while the list has focus, `selection-inactive` grey otherwise.
- **Sidebar:** the floating source list on the window's material; the selected row is the neutral `sidebar-selection` fill under an accent icon.
- **Fields:** the capsule search field on `quaternary-label`.
- **Record page:** large avatar, name in the pane title, values in an inset group (forms and settings only use inset groups).
- **Calendar:** open month with hairlines, today as a red disc (systemRed), as Calendar.app marks it.
- **Chat:** accent bubbles for the user, a neutral surface for myAssistant.
- **Approval card:** the fixed structure every theme uses: solid surface, 1 px `line-strong` edge, filled Approve, Reject as a bordered button.

## Do and don't

- Do read every colour from the system and follow changes live (accent, appearance, increase contrast).
- Do keep the Mac skeleton (sidebar, list, record, toolbar band) identical across all themes; drawn themes paint inside it.
- Don't bundle or rasterise SF Pro, New York or SF Symbols.
- Don't put the brand green anywhere but the host status dot.
- Duplicating System gives a **frozen drawn copy** of the current values (push buttons, plain list, source list, native toolbar). The editor must say it no longer follows the system.

## Accessibility

- **The platform's defaults do not all meet WCAG 2.2 AA.** Measured on the `macos` fallback values in `design/tokens.json`:
  - `secondaryLabelColor` in light mode (black at 50%) is **4.0:1 on the content background and 3.8:1 on the window background**, under 4.5:1;
  - white text on the default blue accent `#007AFF` is **4.0:1** (a selected row, the default button);
  - white on systemRed `#FF3B30` (today's date) is 3.5:1; it is a large bold numeral, but at 11–13 px it is not large text.
  - Dark mode passes (secondary label 5.9:1).

  System cannot fix these without stopping being System. What it does: it follows macOS **Increase contrast** (`accessibilityDisplayShouldIncreaseContrast`, which darkens these colours), and the picker's card says "Contrast: the system's" instead of "Contrast checked". Anyone who needs 4.5:1 guaranteed is pointed at a drawn theme, or at Contrast.
- Reduce motion and reduce transparency come from the system (the sidebar turns `sidebar-background`).
- Targets: the Mac's own sizes (28 pt controls, 20 pt at least), which meet the 24 px of SC 2.5.8 only with spacing; that is the platform's rule, documented in `platforms.md`.

## Fonts and licences

None bundled. SF Pro is reached through the OS only. Lucide icons: ISC (`lucide-static` 0.460.0 header). The preview uses `-apple-system` in Chrome, which is SF Pro on a Mac and a stand-in elsewhere.

## Feasibility

Built: the Mac shell is today's code. Android, Windows and Linux System looks are each a platform pass (Research B: Material 3 Expressive is not in Flutter; `fluent_ui` BSD-3-Clause; `libadwaita`/`yaru` MPL-2.0, markings still to check).
