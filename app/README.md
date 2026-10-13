# myData apps

A family of separate apps built from shared code. There is no combined app.

- `apps/mydata`: the **myData** app: Setup, Status and Settings. It owns the host's lifetime and has a menu-bar icon with Open and Quit. Closing its window keeps the host running; Quit, from the icon or with Cmd+Q, stops it.
- `apps/myassistant`: the **myAssistant** chat app. It can start the host but never stops it.
- `packages/mydata_client`: the Dart API client, **generated** from `host/openapi.json` by `tool/generate_client.sh`. Never edit it by hand.
- `packages/mydata_core`: host lifecycle (find, start, wait for `/status`, watch), app tokens, error states.
- `packages/mydata_ui`: the design system, generated from `design/` at the repo root (the source of truth): tokens, `MyDataTheme` (themes chosen on the host, light and dark per device), motion, accessibility, bundled fonts, the kiwi logo and the shared widgets. See its README for the owner's decisions where `design/` disagreed with itself.
- `packages/mydata_assistant`: chat, streamed replies, progress lines, the approval card.
- `packages/mydata_testing`: test helpers, a dev dependency only: loads the bundled fonts in tests (each package's and app's `test/flutter_test_config.dart`), and `goldenMatrix` / `screenMatrix` for one image per theme and mode (Kiwi and Graphite, light and dark).

**Design tokens.** `packages/mydata_ui/lib/src/generated/tokens.g.dart` is generated from `design/tokens.json` and `design/themes.json` by `dart run tool/generate_tokens.dart` (run in `packages/mydata_ui`), which also copies the logos from `design/assets/Logos`; never edit it by hand. `test/generated_tokens_test.dart` fails when it is stale. `test/no_literals_test.dart` fails when any app or package contains a literal colour, radius or font name outside that file: use `context.colors`, `MyDataSpace`, `MyDataRadius` and `MyDataType`.

**Goldens and screenshots.** Widget goldens are in `packages/mydata_ui/test/widgets/goldens`; whole-screen screenshots of each app are in `apps/<app>/test/screenshots` (`<screen>.<theme>-<mode>.png`). Both are checked by `flutter test`; after an intended visual change, run `flutter test --update-goldens` in that package or app and look at every changed image before keeping it.

```sh
(cd ../host && uv sync && uv run mydata dev-setup)   # once: tells the apps how to start this development host
flutter pub get
cd apps/mydata && flutter run -d macos              # or apps/myassistant
flutter analyze && (cd packages/mydata_assistant && flutter test)    # and in each app and package
tool/integration_test.sh                             # both apps on macOS, each with a fresh host; myAssistant needs Ollama and qwen3:14b
tool/generate_client.sh                              # after changing the host API (regenerate host/openapi.json first)
```

**Starting the host.** The apps start it with the command in `app_config.json` in the host's folder; `mydata dev-setup` writes it. The place where a packaged app will start a bundled host binary instead is marked in `packages/mydata_core/lib/src/platform_io.dart`.

**Platforms.** macOS is the target. The web build compiles and, when opened in a browser, explains that it needs the desktop app: a browser can neither start the host nor read its token files. Windows and Linux code paths compile, but Flutter only builds those apps on those systems, so they have not been built here. macOS builds are not sandboxed: the apps read the host's folder and start the host process.
