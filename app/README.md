# myData apps

A family of separate apps built from shared code. There is no combined app.

- `apps/mydata`: the **myData** app: Setup, Status and Settings. It has a menu-bar icon with Open, Stop host (Start host once it is stopped) and Quit. Closing its window keeps the app running; Quit, from the icon or with Cmd+Q, quits the app only: the host is a login service that outlives every app. Only myData's Stop host (and the `mydata` command) stops it. Status lists myContacts, myCalendar and myAssistant (installed or not, the counts of contacts and calendars and their sources, Open). It opens `mydata://settings/sources` links at Settings, Sources (after setup, if a link arrives during it).
- `apps/myassistant`: the **myAssistant** chat app. It can start the host but never stops it. In real mode a contact or event in a result opens in myContacts or myCalendar when that app is installed; otherwise the row is not interactive.
- `apps/mycontacts`: the **myContacts** app: the contacts the host mirrors from its sources, read-only. It can start the host but never stops it, opens `mycontacts://contact/<id>` links, and remembers the contact last opened on this device.
- `apps/mycalendar`: the **myCalendar** app: a month of the calendars the host mirrors, the selected day's events, and which calendars this device shows, read-only. It can start the host but never stops it, opens `mycalendar://day/<YYYY-MM-DD>` links, and shows This Mac's window limit (and why a source reads nothing) above the grid. Times in an event's own zone come from macOS's time zone database over the `mycalendar/zones` channel in its runner.
- `packages/mydata_client`: the Dart API client, **generated** from `host/openapi.json` by `tool/generate_client.sh`. Never edit it by hand.
- `packages/mydata_core`: host lifecycle (find, start, wait for `/status`, watch), app tokens, error states.
- `packages/mydata_ui`: the design system, generated from `design/` at the repo root (the source of truth): tokens, `MyDataTheme` (themes chosen on the host, light and dark per device), motion, accessibility, bundled fonts, the kiwi logo and the shared widgets. See its README for the owner's decisions where `design/` disagreed with itself.
- `packages/mydata_assistant`: chat, streamed replies, progress lines, the approval card.
- `packages/mydata_testing`: test helpers, a dev dependency only: loads the bundled fonts in tests (each package's and app's `test/flutter_test_config.dart`), and `goldenMatrix` / `screenMatrix` for one image per theme and mode (Kiwi and Graphite, light and dark).

**Design tokens.** `packages/mydata_ui/lib/src/generated/tokens.g.dart` is generated from `design/tokens.json` and `design/themes.json` by `dart run tool/generate_tokens.dart` (run in `packages/mydata_ui`), which also copies the logos from `design/assets/Logos`; never edit it by hand. `test/generated_tokens_test.dart` fails when it is stale. `test/no_literals_test.dart` fails when any app or package contains a literal colour, radius or font name outside that file: use `context.colors`, `MyDataSpace`, `MyDataRadius` and `MyDataType`.

**Passwords are never printed.** `packages/mydata_ui/test/no_password_logging_test.dart` scans every app's and package's `lib/` (not the generated client) and fails on an `AccountIn` interpolated, turned into a string or logged (its generated `toString()` includes the password), and on anything named `*password*` passed to `print`, `debugPrint`, `log` or a logger. `apps/mydata/test/password_not_printed_test.dart` submits the iCloud form and checks that the password appears in nothing printed.

**Goldens and screenshots.** Widget goldens are in `packages/mydata_ui/test/widgets/goldens`; whole-screen screenshots of each app are in `apps/<app>/test/screenshots` (`<screen>.<theme>-<mode>.png`). Both are checked by `flutter test`; after an intended visual change, run `flutter test --update-goldens` in that package or app and look at every changed image before keeping it.

```sh
(cd ../host && uv sync && uv run mydata dev-setup)   # once: tells the apps how to start this development host
flutter pub get
cd apps/mydata && flutter run -d macos              # or apps/myassistant
flutter analyze && (cd packages/mydata_assistant && flutter test)    # and in each app and package
tool/integration_test.sh                             # both apps on macOS, each with a fresh host; myAssistant needs Ollama and qwen3:14b
tool/generate_client.sh                              # after changing the host API (regenerate host/openapi.json first)
```

**Starting the host.** The apps start it with the command in `app_config.json` in the host's folder. An installed host (`host/packaging/macos/install.sh`) writes its own `mydata start` and `mydata stop` there (start asks launchd); `mydata dev-setup` writes a development checkout's instead, and refuses a folder an installed host serves.

**Platforms.** macOS is the target. The web build compiles and, when opened in a browser, explains that it needs the desktop app: a browser can neither start the host nor read its token files. Windows and Linux code paths compile, but Flutter only builds those apps on those systems, so they have not been built here. macOS builds are not sandboxed: the apps read the host's folder and start the host process.
