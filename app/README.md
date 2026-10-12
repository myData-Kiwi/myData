# myData apps

A family of separate apps built from shared code. There is no combined app.

- `apps/mydata`: the **myData** app: Setup, Status and Settings. It owns the host's lifetime and has a menu-bar icon with Open and Quit. Closing its window keeps the host running; Quit, from the icon or with Cmd+Q, stops it.
- `apps/myassistant`: the **myAssistant** chat app. It can start the host but never stops it.
- `packages/mydata_client`: the Dart API client, **generated** from `host/openapi.json` by `tool/generate_client.sh`. Never edit it by hand.
- `packages/mydata_core`: host lifecycle (find, start, wait for `/status`, watch), app tokens, error states.
- `packages/mydata_ui`: the design system: palette, bundled fonts, kiwi logo, shared widgets. Light theme only.
- `packages/mydata_assistant`: chat, streamed replies, progress lines, the approval card.

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
