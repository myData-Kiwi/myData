# mydata_core

myData shared app logic: finding, starting and watching the host, app tokens, error states, links between the apps, and settings that belong to this device. See `../../README.md`.

## Device settings

`device/settings.json` in the myData folder (`DeviceStore`), shared by every myData app on this device. A change in one app reaches the others without a restart: through the folder's file system events (`FileDeviceStore.changes`) and, where those are not promised, a read every 2 s. Writers merge into the file and keep the other keys (`DeviceStore.update`). Each write goes to its own temporary file, renamed over the real one, so apps writing at once never break the file. `update` checks just before the rename that the file still holds the text it read, and reads again and retries when another app wrote meanwhile; updates in one process run one at a time. Between apps the check and the rename are not one step, so a write landing between them can still be lost (rare for settings people change by hand).

| Key | Owner | What |
|---|---|---|
| `mode` | `ThemeController` | light, dark or system, for every app on this device |
| `themes` | `ThemeController` | `{"everywhere": {"theme", "palette"}, "apps": {"<app>": {"theme", "palette"}}}`: each app's theme and palette on this device, else everywhere's, else System (design/themes/ARCHITECTURE.md 4.1). Written by the galleries and myData's Appearance; never synced |
| `lastTheme` | (read once) | the host's theme as the old `AppearanceController` last saw it; read only by the first-start migration (macOS: every app on System; elsewhere: Kiwi in that colour everywhere), never written now |
| `lastContact` | myContacts | the contact last opened |
| `hiddenCalendars` | `CalendarVisibility` | ids of calendars hidden on this device (sorted list). myCalendar follows it; myAssistant's answers come from the host and do not |

## Links between the apps (macOS)

| Link | App | Dart |
|---|---|---|
| `mycontacts://contact/<id>` (id: `[A-Za-z0-9-]{1,64}`) | myContacts | `OpenContact(id)` |
| `mycalendar://day/<YYYY-MM-DD>` (a real date) | myCalendar | `OpenDay(date)` |
| `mydata://settings/sources` | myData | `OpenMyDataSources()` |

Nothing else is a link: no query, fragment, port, trailing slash or percent escape (`MyDataLink.parse`).

- **Sending:** `appLinks.open(uri)` validates, then runs `/usr/bin/open -b kiwi.mydata.<app> <canonical link>`, so only that app receives it (it is started if needed). `appLinks.isInstalled(app)` asks LaunchServices (`NSWorkspace.urlForApplication(withBundleIdentifier:)` through `osascript -l JavaScript`, about 50 to 100 ms, no Apple Events, no Spotlight, nothing launched; an app in the Trash counts as not installed). `openMyDataSources()` brings myData forward at Settings, Sources. `appLinks.openApp(app)` opens an app with no link (`open -b <bundle id>`), also one that takes none (myAssistant). Off macOS every answer is false.
- **Installed apps:** `InstalledApps(apps: [...])` asks `isInstalled` for each once at `start()` and again whenever this app comes back to the front (its lifecycle resumes), never on every build. Until it has answered, and off macOS, nothing counts as installed. myAssistant uses it for opening results, the myData app for its Status rows. App tests set `appLinks = AppLinks(macOS: false)` in `flutter_test_config.dart`, so no test asks LaunchServices.
- **Receiving:** `IncomingLinks(app: ...)` on the `mydata/links` channel. Call `start()` once at launch and listen to `links`; links for other apps and invalid links are dropped. The runner part is `macos_snippets/LinksAppDelegate.swift`: copy it into the app's runner, follow the steps in its header (register the lifecycle delegate in `AppDelegate.init`, attach the channel in `MainFlutterWindow.awakeFromNib`, add the app's own scheme to `CFBundleURLTypes`). It holds links that arrive before Dart is ready (the link that started the app) and shows the window, which the myData app hides rather than closing.
