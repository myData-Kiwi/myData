# Layout and platforms

The apps are separate programs that share one look. Each one has its own window, its own navigation and its own icon. The host runs in the background and is shown only as a menu-bar or tray icon owned by the myData app.

## Window layouts

| Width | Layout |
|---|---|
| Under 600px (phones) | One column. Top-level sections in a floating tab bar at the bottom, five at most. Detail screens push in |
| 600 to 1024px (tablets, narrow windows) | Two panes: a list and a detail. Sections move to a slim rail |
| Over 1024px (desktop) | A `sidebar-width` sidebar on `surface`, then content. A third pane for detail where the app needs it, as in myMail |

Reading and settings columns stop at `content-max`. Photo grids and calendars use the full width.

## Each app's frame

- The app name sits at the top of the sidebar in the `title` style. On a phone it is the large title at the top of the screen.
- The sidebar holds that app's own sections only. No app lists the other apps.
- The bottom of the sidebar shows the connection: "Connected to your host" with a link that opens myData. When the host cannot be reached, this becomes a `warning` line with a Retry button.
- myData is the hub: it lists the installed apps, storage, devices, backups and all settings, including appearance and the assistant switches.

## Moving between apps

- A link to another app reads "Open in myMail". It opens that app at the right item.
- A cross-app row appears only when the other app is installed. A contact's page shows "Recent mail" only if myMail is present.
- Nothing is duplicated. myContacts does not show a mail reader; it links to one.

## Without the assistant

- No screen depends on the assistant. With it off or not installed, assistant buttons are absent, not disabled.
- Search always works by keyword, date, place and album. Search by description appears only when the photo model is on.
- myAssistant, opened while the assistant is off, shows one screen: what it is, that it is off, and a link to turn it on in myData.

## What follows the platform

| Behaviour | Rule |
|---|---|
| Back | System back gesture and button on phones; no custom back gestures |
| Scrolling | Platform scroll physics and scroll bars |
| Menus | A real menu bar on macOS; context menus on right-click and long-press |
| Keyboard | Platform shortcuts: Command on macOS, Control elsewhere. Every action reachable without a pointer on desktop |
| Text | Native selection, copy, paste and spell check |
| Windows | Standard title bar controls in the platform's position |
| Dialogs for files, sharing and permissions | The system's own |

## What is ours everywhere

Colour, type, shape, icon tiles, cards, the approval card, status chips and wording. A screen from myPhotos on Windows and on an iPhone should be recognisable as the same app at a glance.

## Offline and errors

- When the host is unreachable, the app shows what it has stored on the device, marks it with the time it was last updated, and says the host cannot be reached.
- Actions that need the host are disabled with a reason next to them. They are never hidden without explanation.
- An error states what failed and offers one next step. It never shows a code alone.
