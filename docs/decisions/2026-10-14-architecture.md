# Architecture, sources, modes, assistant and client stack as of 14 October

Moved verbatim from CLAUDE.md on 2026-10-23, when it was cut to the current rules. This is history: where it differs from CLAUDE.md or `docs/2026-10-23-plan.md`, CLAUDE.md wins.

## Architecture

One host per household, clients on every device.

- **Host**: a background service that outlives any window and starts at login. It must also install alone on machines with no screen (Linux mini PC, NAS, Docker). On macOS it must be a native install, because Docker on a Mac gets no GPU acceleration.
- **Clients**: talk to the host over the local network, and over Tailscale when away. Never expose the model server's port to the internet. **For now the host listens on localhost only** (127.0.0.1); phone and remote access come later as a separate, explicit design.
- **The host owns data and tools; agents are replaceable.** Every agent reaches tools through one registry, which holds the permission gate: our orchestrator, or any MCP agent at `/mcp`. An irreversible call never runs until a user approves that exact held call in an app.
  - **A held call is bound to the mode, the conversation epoch and the handler** it was held with, all three in its digest. Switching mode or moving the epoch on fails every pending approval (status `failed`, with the reason; approving it then returns it unchanged), and approving checks the binding again, so a send held over demo data never runs in real mode. A switch waits for calls already running (an approved run from its check to its end, and an MCP agent's call, whose real-mode refusal is checked inside the registry), so a call runs wholly in one mode.
  - Approvals and the tool registry's undo log are in memory. The undo of an app's write is persisted (`undo_log` in `contacts.sqlite`, `POST /undo/{id}`; see "Editing contacts").
- **Tokens.**
  - **App tokens:** one per app (`app-tokens/<app>` in the host's folder, file mode 0600). Each app's token has scopes (`APP_SCOPES` in `service/auth.py`), and every route declares the one it needs (`dependencies=needs(...)` in `api.py`). The host refuses to start with a route that declares none, `openapi.json` lists each operation's `x-mydata-scopes`, and `tests/test_scopes.py` checks every route for every app.

    | App | Scopes |
    |---|---|
    | myData | status, admin, approve, contacts:read, contacts:write, contacts:import, calendar:read, sources:read, sources:manage, shutdown, mcp; calendar:write (reserved, no route uses it yet) |
    | myAssistant | status, assistant, approve, contacts:read, calendar:read |
    | myContacts | status, contacts:read, contacts:write, sources:read |
    | myCalendar | status, calendar:read, sources:read |
    | `mydata` command | every scope |

    Only the apps with `approve` can list, read or decide held calls; each approval records which app decided. Only `shutdown` (myData, the command) stops the host. Only `contacts:import` (myData, the command) imports contacts: myContacts' File > Import… opens myData, which keeps the one history; myContacts keeps `contacts:write` for its edits, merging and reviewing.
  - **Agent tokens:** created and revoked with `mydata agent ...` or in the myData app, with only their hash stored. They reach `/mcp` only and have no scopes.
  - **Known limit: the app tokens protect against other users, not other programs.** Any process running as the same user can read `app-tokens/*` and use the API with them, so it can read every contact and event without ever getting its own Contacts or Calendars prompt from macOS. This is true today. It must be hardened before the host sends mail (plan 2(f).4: app to host over a Unix socket with the peer's code signature checked, a Secure Enclave key per send, or Keychain access lists).
- **Apps.** The product is a family of separate apps built from shared code, not one combined app with a sidebar. Each app talks to the host only through the HTTP API, with no business logic in the app. The user opens an app and the host starts by itself.
  - Only the myData app owns the host's lifetime: it has a menu-bar icon with Open and Quit, and Quit stops the host. The host enforces this: `/shutdown` refuses other apps.
  - Other apps, such as myAssistant, can start the host but never stop it.
  - One exception, for every app: on connect, a host the app cannot use as it is (another version or API version, its code changed on disk since it started, or it refuses the app's token) is replaced, once, with `mydata stop --unless-current --expect <the app's versions>` and a start. The stop does nothing when the host the start command would start is not the app's build either, or when the running host is already current, so an app never stops a host it could not use afterwards.
  - The assistant is optional: the apps work without a model.
- **No app depends on the chat.** myPhotos talks to the host directly.
- **Phones cannot host.** iOS and Android suspend background apps and lack the memory. No third-party wake word on iOS; no iMessage or phone-call control.

### Contacts and calendars sources

Read-only mirrors in `contacts.sqlite` and `calendar.sqlite` (`host/src/mydata/sources/`). The user turns each source on or off in the myData app (Settings, Sources); turning one off deletes what it mirrored from the mirror. **Copies stay in the host's snapshots until they expire:** by the first day of the same month next year (`backup.kept_until`), while the host keeps running. The CLI, the API docs and the myData app's turn-off and remove dialogs say so.

- **Group cards** (iCloud's `X-ADDRESSBOOKSERVER-KIND:group`, vCard 4's `KIND:group`) are stored with `kind = 'group'` and never listed, counted, searched or found by `find_contact`; the export keeps them in a separate file.
- **Followed sources stay read-only.** No source ever writes back: the iCloud client sends only PROPFIND, REPORT, OPTIONS and GET, and the Mac helper has no write calls. Writing back to a provider is not planned; owned data reaches other devices through the host's own CardDAV/CalDAV server (see "Direction").
- **Nothing goes around these two paths.** Static scans of the host's sources: no HTTP client outside `DavClient.request` and a localhost allow-list; no `smtplib`, `imaplib`, `poplib` or `ssl` outside one mail module (none yet: `MAIL_ALLOWED` is empty) (`test_dav_no_other_http.py`); only an allow-list of modules, each with its reason and the programs it may start (never through a shell), may start a program, nothing may load native code (`ctypes`, `cffi`, PyObjC and Apple's frameworks) or use `posix` or `webbrowser`, and no source mentions `osascript` or AppleScript (`test_no_way_around_the_helper.py`). The scans see through import aliases, `import *` and `getattr`; they catch accidental use, not code written to hide a call.
- **Why This Mac is the default on a Mac host:** it uses the normal system permission prompt, so no password reaches myData, and it covers every account on the Mac (iCloud, Google, Exchange). Asking for an app-specific password is not acceptable as the main path, and Apple rejects sign-ins that use an address other than the Apple Account email (for example a custom domain).

- **This Mac** (Mac host only; absent, not broken, elsewhere): a Swift helper, `myDataReader.app` (`app/apps/mydata/macos/Reader`), inside `myData.app/Contents/Helpers`. macOS attributes it to myData, so the permission prompt names myData and the grant belongs to `kiwi.mydata.mydata`. No password or account detail reaches myData, and every account set up on the Mac is covered.
  - The host starts it with `open` (LaunchServices), never by running the binary, and only from a path inside a validly signed myData app with the same signing identity. It talks JSON lines over `<home>/run/reader.sock` (folder 0700, socket 0600, one connection at a time).
  - **Read-only:** all framework access is behind one Swift protocol with no write method; a host test scans the helper's sources for write calls.
  - **Permission** is asked only when the user presses Allow in the myData app, never at login.
  - **Access taken away** (denied, restricted, calendars write-only) deletes that kind's copy. "Not asked yet" keeps it, unread until the user allows again: macOS reports it whenever myData's signing identity changes, as on every ad hoc rebuild (found 2026-10-14, when a rebuild emptied the copy).
  - The user chooses which contact accounts and calendars are included (all by default).
  - **Contact notes are never read** (they need an entitlement Apple grants on request); the API says `notes_included: false`. Photos are read when allowed, otherwise the apps show initials.
  - **Events:** EventKit gives only expanded occurrences, so the Mac source keeps a rolling window, one year back and two years ahead, read in pieces of at most 4 years. An occurrence is keyed by (calendar, external id, occurrence date), so one event in two calendars is two rows.
  - **The window rule:** list_events and `/events` never answer "nothing found" for days a source does not hold. It is decided per source: an iCloud account holding every day never hides the Mac's limit.
  - Large snapshots arrive in parts of a few MB.
- **iCloud account** (Advanced): CardDAV and CalDAV with an app-specific password and the Apple Account email, which may differ from an address on the user's own domain. It holds every date.
- **Switching mode ends every conversation.** The host moves its conversation epoch on (`state.json`, `conversation_epoch` in `/status`); myAssistant then shows one line saying a new conversation has started, and a message to an older epoch's conversation gets a `reset` event.
- **The same account through both sources** (an iCloud account set up on the Mac and also followed) is mirrored twice: its contacts and calendars are listed twice, and myCalendar lets the user hide either copy. Hiding is kept on the device and followed by myCalendar only: myAssistant's answers come from the host and still include hidden calendars (and both copies). While This Mac is on, Settings says under each followed account that following it is not needed on a Mac that has it in System Settings.

### Demo and real mode

The host is in **demo mode** while no source is on and it holds no owned data, and in **real mode** as soon as a source is on or an owned address book or calendar exists (`mode` in `/status`), even an empty one (purging its last contact leaves the address book, so the host stays real; decided 2026-10-14). Turning the first source on or the last one off switches it; code that creates or purges owned data must call `ModeController.refresh()` the same way.

- **Demo mode:** the six built-in tools serve the fake data in `orchestrator/fixtures.py`, and the host's today is pinned to 18 March 2026 (`demo_date` in `/status`; myData shows a "Demo date" chip, myAssistant "Demo data"). MCP agents get the same six fake tools. myContacts and myCalendar have nothing to show and point to myData, Settings, Sources. Results in myAssistant never open in another app: their ids and days are not the user's.
- **Real mode:** only `find_contact` and `list_events` are offered, reading the mirror, with the real date and the machine's time zone. Mail, photos and creating events have no real source yet, so those tools are not offered. MCP agents get no tools. The request log records the mode and holds no mirrored data: no tool results, for each argument only its shape (name, type and length), never its value, since the model can copy a value from a result, and only the shape of the reply, which quotes the results whoever wrote it. The request text is kept. The host log keeps only the kind and length of a failed call's error, which can quote a value. Demo mode logs everything. A `result` event says `"mode": "real"`; a contact item carries its id and an event item its day, so myAssistant opens them in myContacts and myCalendar when installed.

### Assistant

The language model has exactly one job: choose a tool and extract plain arguments. Everything else is ordinary code.

- **Dates**: the model outputs the phrase ("next friday"). Code resolves it to a date.
- **Permissions**, enforced in code, never by asking the model to behave:
  - read: runs freely
  - reversible write: runs, with undo
  - irreversible (send mail, delete): blocked until the user approves
- **Ambiguity**: a lookup that returns several matches makes the code ask the user.
- **Structured output**: pass a JSON schema so the model can only emit valid calls.
- **Small tool set per request**: show the model only the handful of tools relevant to the request.
- **Untrusted input**: text from mail bodies or web pages can contain instructions. Nothing read from them may trigger an irreversible tool without approval.
- **Log every request** with the tools called and the outcome. This is future test data and, much later, fine-tuning data.
- **Web search** is an optional, visible, switchable tool (`web_search`, `fetch_page`). Prefer self-hosted SearXNG. Never put private data into a query without asking.

### Photos

No language model looks at photos. Search uses CLIP embeddings for descriptions, a face model for people, and metadata filters for place and date. These models total about 1GB. Immich's defaults (`ViT-B-32__openai` for CLIP, `buffalo_l` for faces, run through ONNX Runtime) are the reference; verify current names before copying.

### Client stack

**Flutter**, one codebase for macOS, Windows, Linux, web, iOS and Android; macOS first. The Dart API client is generated from `host/openapi.json` (OpenAPI Generator) and never hand-written. Flutter has no official Liquid Glass components. The web build compiles but only explains that it needs the desktop app, until remote access exists.

**Look:** everything comes from `design/` through `mydata_ui`. Tokens are generated from `design/tokens.json` and `themes.json` (`dart run tool/generate_tokens.dart` in `mydata_ui`; a test fails when they are stale). No app or widget may contain a literal colour, radius or font name; a test scans the source. The **theme** is stored on the host (`PUT /appearance`, reported in `/status`) and applies to every app; the **mode** (light, dark, match system) is per device. Both apps follow a change within one status poll, without a restart. Reduced motion and reduced transparency follow the system. Widget goldens and app screenshots are made in Kiwi and Graphite, light and dark.

**Rules added with the form components (phase 2; details in `design/README.md`, `design/platforms.md` and `mydata_ui`'s README):**
- **New tokens:** `surface-hover` (every row and icon button that fills on hover), the `data-*` palette (colours of calendars myData owns, never control colours), `dialog-width` (520px), `inspector-width` (440px), `radius-xs` (the checkbox's box), and checkbox and calendar tokens.
- **Focus ring:** `focus` (red) everywhere, `ink` on anything already red (a field in error, a Danger button, a destructive menu item); the colour comes from one place, never picked by a widget.
- **Disabled controls always have a reason,** a full sentence. Where it shows only on demand (tooltip, menu item) the control stays focusable but inert (`Pressable(disabledReason: ...)`).
- **Keys:** one order from the innermost outwards for Escape, ⌘Z and Return; text comes first. On macOS each app has a real menu bar (`AppMenuBar`, title case there only), the one owner of ⌘Z and ⌘S; ⌘E edits the selected record. Phones have no menu bar: every action is also on screen.
- **Phones:** one breakpoint (600px, `AppLayout.isPhone`) and 16px body text in form fields (`PhoneType`).
- **Forms:** a Dialog or Inspector makes its fields read-only while it works (`FormBusy`) and commits pending typing before it confirms or saves (`FormCommit`, `PendingInput`); Cancel with changes asks "Discard changes?". Toasts with Undo sit beside an Inspector (`ToastHost` around `InspectorLayout`).
- Dates are written in British English ("Wed 14 Oct 2026"); only the order for typing follows the region.
