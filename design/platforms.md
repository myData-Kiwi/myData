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

## Disabled controls

One rule for every component, so a reason is never out of reach.

- **A disabled control always has a reason,** and the reason is a full sentence with a full stop, wherever it appears: a help line, a menu item's caption or a tooltip ("The host cannot be reached.").
- **Only the control fades.** The 45% opacity applies to the control itself: its label, box, track, icon or value. The reason line keeps full `ink-muted`, which meets 4.5:1 on `surface` and `surface-raised` in both modes (about 6.6:1); faded with the control it would fall to about 2:1.
- **Where the reason is visible text next to the control** (a help line under a field, a caption under a checkbox or a form switch), the control may leave the Tab order, because the reason can be read without reaching it. Select, DatePicker, TimePicker, TokenField, Checkbox and the form Switch do this.
- **Where the reason is shown only on demand** (an IconButton's tooltip, a Menu item), the control **stays focusable**, marked disabled for assistive technology (`aria-disabled`, not `disabled`): Tab or the arrow keys reach it, focus shows the reason (the tooltip appears; the menu item's caption is read), and pressing it does nothing. Otherwise keyboard, touch and screen-reader users could never learn why.
- **For implementers:** `Pressable` in `mydata_ui` today takes every disabled control out of focus. It gets a second mode, focusable but inert, for the second case (decided 2026-10-14).

## Which handler gets a key first

Several controls give Escape, ⌘Z and Return a meaning of their own. One order decides, from the innermost outwards:

- **Escape:** first, close whatever is open (a Menu, a Select's list, a date or time popover, a suggestion list); then a field's own revert or clear (DatePicker and TimePicker put back the value from before the typing, a custom label returns the previous one, TokenField clears its token selection, a search field clears its search); only then the holder's Cancel (Inspector, Dialog, Sheet). One press does one of these.
- **⌘Z (Ctrl+Z elsewhere):** first, the typing in the focused text field (see "Text comes first" below); then a field's own undo, where it has one (TokenField brings back the last removed token); then the record undo, Edit, Undo, which is also the Toast's Undo.
- **Return:** first, whatever is open (it picks the highlighted item or day); then the focused button; then the holder's rule (a Dialog confirms; an Inspector does not save on Return in a single-line field).
- **Scope:** the holder's keys apply only while focus is inside it. Escape in the list beside an open Inspector keeps the list's meaning. ⌘S is the exception: like the menu bar's Save, it saves an open Inspector wherever focus is in the window.

## The menu bar on macOS

On a Mac, each app has a real menu bar. macOS draws it, so it follows macOS and has no preview here; this section says what is in it. It is built once per app (Flutter's `PlatformMenuBar`), and the same shortcuts work without it on Windows and Linux.

- **Menus,** in this order: the app's menu, File, Edit, View, Window. There is no Help menu until there is help to show.
- **Words:** each item uses the same words and shortcut as the same action in a Menu or a button, in this menu bar's case, so an action has one name everywhere. An item that opens a dialog or a file chooser before it acts ends with an ellipsis, whether the dialog asks for values or only for confirmation: "Import…", "Delete 3 Contacts…". The Menu spec uses the same rule. An item that cannot act now is disabled, never hidden, so the menus keep their shape.
- **Case:** macOS writes menu items in title case ("Bring All to Front"), and adds its own items to our menus (Edit gets "Start Dictation…" and "Emoji & Symbols"). Ours are written in title case too, so a menu never mixes the two. This is the one place in the apps that is not in sentence case. Windows and Linux have no such menu bar, and every other label, Menu items included, stays in sentence case ("New contact").

| Menu | Items, with shortcuts | Notes |
|---|---|---|
| The app's menu ("myContacts") | About myContacts; Hide myContacts ⌘H; Hide Others ⌥⌘H; Show All; Quit myContacts ⌘Q | macOS's own items. Quit closes the app; the host keeps running (a login service). myData alone adds Settings… ⌘, here; its menu-bar icon has Stop host and Start host |
| File | New Contact ⌘N (myContacts) or New Event ⌘N and New Calendar… ⌥⌘N (myCalendar); Import… ; Save ⌘S; Close Window ⌘W | Import… opens myData at its Import section with the link `mydata://import/contacts` (phase 4; ImportFlow, "Where it lives"). In myData itself, File has Import… too, which goes to that section. Save is enabled while an Inspector is open (its ⌘S). New while an Inspector has changes asks "Discard changes?" first, as the Inspector does |
| Edit | Undo *action* ⌘Z; Redo *action* ⇧⌘Z; Cut ⌘X; Copy ⌘C; Paste ⌘V; Select All ⌘A; Edit Contact or Edit Event ⌘E; Delete Contact or Delete Event ⌘⌫; myCalendar also Edit Calendar… and Delete Calendar…, for the calendar selected in Calendars | See below. Edit Contact and Edit Event open the Inspector for the selected record; Return on a selected row in the list does the same |
| View | One item per sidebar section, in sidebar order, ⌘1, ⌘2…, the current one checked (myCalendar: Month ⌘1, Calendars ⌘2); myCalendar also Go to Today ⌘T; Enter Full Screen ⌃⌘F | Enter Full Screen is macOS's own |
| Window | Minimize ⌘M; Zoom; Bring All to Front | macOS's own |

- **Undo and Redo name the action** by its verb and object, in this menu bar's case: "Undo Delete Contact", "Redo Edit Event", "Undo Import". The name comes from the action, not from its Toast, which says what happened ("Contact deleted"). With nothing to undo, the item is "Undo", disabled. The names come from the host's undo log, so Undo works for what was done in this app on this host, after the Toast has gone. **Redo needs host work:** the plan names only `/undo/{id}`; a redo would be a new forward revision of its own. Until the host has it, Redo stays disabled.
- **Text comes first.** While a text field has focus, ⌘Z and ⇧⌘Z undo and redo the typing in that field, Cut, Copy, Paste and Select All act on its text, and ⌘⌫ deletes to the start of the line, as everywhere on macOS. The Undo item then shows "Undo Typing", and Delete Contact is disabled. A record is never deleted by a key meant for text.
- **Delete** acts on the selected record or records (MultiSelect). One record is deleted at once, with a Toast and Undo; several first ask in a Dialog, so the item then ends with an ellipsis. With nothing selected, or a record from a followed source, it is disabled. A repeating event's Delete Event… asks which events (phase 6).
- **myMail** adds New Message ⌘N under File once it can send (phase 7); its other items come with its own specs (phase 5).
- **Windows and Linux** have no menu bar of this kind. The same shortcuts work with Control in place of Command: Ctrl+N, Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z for Redo, Ctrl+S, Ctrl+1. Delete is the Delete key alone while the list has focus, as in Explorer and Outlook: Ctrl+Delete deletes the next word in text there, and text comes first anyway. Menus show it as "Delete". Every action is also on screen, as on a phone (below).
- **Phones have no menu bar.** Each action lives in the screen: New is an IconButton in the large title ("New contact", "New event"); Save and Cancel are in the Inspector's sheet; Undo is the Toast's Undo, and afterwards "Undo" and the action ("Undo delete contact") at the top of the "More actions" menu in the screen's header, for as long as the host's undo log holds that action from this app; Delete is in the record's Menu (long-press) and its "More actions" menu; Import is in myData ("Import contacts…" in myContacts' "More actions" opens it); View sections are the floating tab bar.
- **Nothing only in a context menu.** Every context-menu action is also in this menu bar or on screen (a "More actions" IconButton), and has a key where the table gives one (Menu, "Never only in a context menu").
- **Screen readers:** VoiceOver reads the menu bar as macOS's own, with each item's shortcut. Nothing extra is needed.
- **⌘E edits the selected record** in every app (Edit Contact, Edit Event), so the family has one key for one action. **Unverified:** Apple's own apps may differ (Contacts is thought to use ⌘L for Edit Card; Calendar's key is not known). Check both on a Mac before building, and record what they use here; the decision stands either way.
- **Decided 2026-10-14:** title case in the macOS menu bar only; ⌘E for Edit Contact and Edit Event; disabled controls whose reason shows only on demand stay focusable (Pressable's focusable-but-inert mode).
- **Used by:** myContacts (phase 3), myCalendar (phase 6), myData (Import…, Settings…; phase 4) and myMail (phases 5 and 7).
- **Decided 2026-10-14 with phase 4 (ImportFlow, DuplicatePair):** myData's View menu becomes Status ⌘1, Import ⌘2, Settings ⌘3; myContacts' becomes Contacts ⌘1, Recently Deleted ⌘2, Review ⌘3 once the Review section exists (after host gaps H6a and H7). myContacts' Edit menu gains Merge Contacts… for two to twenty selected contacts the host owns (DuplicatePair, "Merge from a multi-selection"; it ships with the merge preview, H6c), disabled with its reason otherwise.
