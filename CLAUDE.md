# myData

Open-source, self-hosted personal cloud with a local assistant. All user data stays on hardware the user owns. A family of "my"-prefixed apps connects to one host that stores, syncs, indexes and runs the models; the host also serves CardDAV/CalDAV so the phones' own apps are clients.

This file is the project's working memory: the rules and state in force now. Read it before doing anything; update it when a decision changes. History is in `docs/decisions/` (see "History"), the plan in `docs/2026-10-23-plan.md`. Where they differ from this file, this file wins.

## Ground rules

- Non-commercial hobby project. No payments, donations, sponsorship links, or company entity. Do not add any of these to code, docs, or the website.
- Work happens on the owner's personal computer and personal GitHub account only.
- Not affiliated with MyData Global; the site footer says so. Keep that line.
- No trademark filing planned. "myData" is descriptive and crowded.
- Licence: AGPL-3.0-or-later (`LICENSE`).
- Owner's working style: direct, concise answers. Stress-test ideas and lead with what is wrong or missing. No flattery.
- **Done means used:** a milestone is done when the owner has used it for three days on real data, not when tests pass against fakes.

## Commits

Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

- **Subject:** `type(scope): summary`. Lower case, imperative, no full stop, 72 characters at most.
- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.
- **Scopes:** `host`, `app`, `ui`, `assistant`, `design`, `docs`. Omit the scope if none fits.
- **Breaking changes:** `!` after the type or scope, plus a `BREAKING CHANGE:` footer.
- **Body:** optional, at most 5 short lines saying why, not a list of every file. Most commits need no body.
- **One logical change per commit.**
- **Never add a `Co-Authored-By` trailer or any other mention of Claude.**
- Commits use the personal identity, set for this folder by `~/.gitconfig-mydata-kiwi`.
- **Push to GitHub at the end of every session.**
- **CI** (`.github/workflows/host-tests.yml`) runs on every push and pull request to main: the host suite on Linux (the macOS-only tests skip themselves) and `flutter analyze`. It does not run `flutter test` (goldens are rendered on macOS) or the macOS-only host tests, so run both on a Mac before pushing.
- The workspace copy `../CLAUDE.md` must stay identical to this file (`cp` after editing).

## Names

| Name | What it is | Runs on |
|---|---|---|
| myData | The host (`mydatad`): stores, syncs, indexes, runs models. Also the myData app: setup, status, settings, import; later the dashboard and file browser | Host on macOS, Windows, Linux. App everywhere |
| myAssistant | Chat (later voice) app | Everywhere |
| myContacts, myCalendar, myMail, myPhotos | First apps | Everywhere, as clients |
| myNotes, myReminders, myFiles, myDocs, myHealth, myHome and others | Later apps | Everywhere, as clients |

Technical names: repo `mydata-kiwi/mydata`, command `mydata`, background service `mydatad`. In prose, call the host "the host". The website (`mydata-kiwi/mydata-kiwi.github.io`, GitHub Pages, mydata.kiwi with Cloudflare DNS proxy off on purpose) keeps its own styling and its `CNAME`.

## Decisions in force

### The host owns the data (2026-10-13)

- Data is **imported** once from Apple, Google, Samsung or Microsoft, then created and edited in our apps and, through the host's CardDAV/CalDAV, in the phones' own apps (an iPhone with iCloud, a Samsung through DAVx5).
- **Nothing is written to iCloud, Google or the Mac.** Followed sources stay read-only. Until DAV serving, new items say "On myData only, not on your phone yet".
- **Imports come from files first** (`.vcf`, `.ics`, mbox), with a preview, a loss report, suggestions (never automatic merges) and undo. This Mac is followed only, never imported.
- **Mail: myMail,** received through Mail.app by Apple Events from a helper nested in myData.app; IMAP per provider as standby (OAuth device code for Microsoft). No Full Disk Access route, no mail server on the host. A full archive: nothing is purged; mail gone at the provider is marked deleted.
- **Pressing Send in myMail counts as approval** only once the app-to-host channel is hardened; a ~10 s undo window (a restart inside it returns the message to drafts) and an hourly limit. Sends the assistant proposes always show an approval card.
- **Proposed, not confirmed:** events organised by others are read-only until invitations exist; alerts on owned events stay hidden until something rings them.

### 2026-10-14

- Real mode means "a source is on or the host owns data"; the host stays real after the last owned contact is deleted for good.
- A delete for good from Recently deleted needs only the app's Dialog; an assistant's or agent's delete still goes through the gate.
- The import specs' decisions are in `design/components/ImportFlow` and `DuplicatePair` ("Decisions").

### 2026-10-23 (on `docs/2026-10-23-plan.md`)

1. **Keep the family of separate apps,** not the plan's merge into one app. The host still serves CardDAV/CalDAV. Per-app scopes, links and runners stay; each app gets the look pass; the plan's one-app items become per-app work.
2. **iPhone:** the phones' own apps through DAV plus the host's light web page. Native iPhone apps once the owner pays Apple's $99 a year himself (after M2, or when he says).
3. **Remote access: Tailscale** (free Personal plan, Serve on `ts.net`, **never Funnel**), through a separate remote listener.
4. **Licence: AGPL-3.0.**
5. **Push** at the end of every session.
6. **Backups:** Time Machine to an external disk or NAS, live `*.sqlite*` files excluded; the M1b off-machine backup gate stands.
7. The mail spike app is deleted; the owner switches off its two stale grants.
8. **Flutter is the stack on every platform, the Mac included** (the owner, after the M1a side-by-side of the People screen: Flutter's app has more to it, the SwiftUI one felt basic, and SwiftUI is Mac only). The family of separate apps stays. **Native frame, quiet brand:** on macOS the system's window, unified toolbar and translucent sidebar, the system font at 13 pt, the system accent and focus ring, Mac density; ours are the kiwi, the app icons, avatars, person pages, empty states and wording. Other platforms keep building and keep today's look until their own pass (Material 3 on Android). The SwiftUI prototype stays on the local branch `stack-gate-swiftui`, never pushed (`docs/decisions/2026-10-23-stack-gate.md`).

### 2026-10-23 (themes; `docs/decisions/2026-10-23-themes.md`)

- **A theme changes the whole look** (type, shape, density, borders, depth, icons, motion, each component's variant, and colour through its palettes), never wording, layout, keys, the menu bar, the window's controls, status meanings or the approval card's structure. Design: `design/themes/ARCHITECTURE.md`; rules: `design/theming.md`.
- **Themes are named after their design language, and colour is a separate choice inside a theme** (the owner, later the same day, on the prototype gallery: the names made the themes look like colour changes only). A theme is a style plus 2 to 4 palettes named by colour; each palette is the colour seeds in light and dark (plus optional roles, an increase-contrast set and gradient stops) and passes the contrast rules on its own. The user picks theme and palette. System's colour is the system accent: **no "System, tinted" on macOS** (decided 2026-10-23); other platforms may allow a tint later. Custom themes may add palettes. Design: `design/themes/ARCHITECTURE.md` 1.6.
- **Each app has its own theme and palette, plus "Use everywhere"** (carries the palette; clears each app's choice, with Undo). **Per device, never synced** (`<home>/device/settings.json`); the host's `/appearance` is retired in phase 2. **Mode stays per device.** Phones: one theme per app, no Use everywhere, until native phone apps.
- **System is the default** (the Mac shell on macOS; Kiwi in the platform's font elsewhere until each platform's pass).
- **Built-ins: all twenty ship** (the owner, 2026-10-23), each built properly with 2 to 4 palettes. System and today's six as full looks, renamed: Kiwi (the house style), Hairline (was Graphite), Frosted (Dusk), Journal (Plum), Sticker (Rose), Paperback (Amber). Palettes, default first: Kiwi: Kiwi, Sky, Violet; Hairline: Graphite, Slate, Cobalt; Frosted: Dusk, Aurora, Sand; Journal: Plum, Ink blue, Forest; Sticker: Rose, Mint, Mustard; Paperback: Amber, Sepia, Linen. Plus the 13 prototypes (outside the repo under their old folder names): High Contrast, E-ink, Large, Terminal, Notebook, Brutalist, Retro Desktop, Swiss, Blueprint, Arcade, Geometric, Zen, Ledger. They predate palettes and the Dart validator, so they are ported, not copied; layout stays out (Large keeps no reflow, Ledger only a list or table variant).
- **Kiwi in an old colour moves** to that colour's theme, in that palette (Graphite to Hairline, Dusk to Frosted, Plum to Journal, Rose to Sticker, Amber to Paperback), with a one-time notice in myData's Appearance (the record) and once in each moved app's own window; the five ids stay as hidden aliases (built 2026-10-24: `ThemeSettings.movedOver`, `themes.moved` and `themes.told` in the device settings, `ThemeMovedNotice`).
- The design's 11 choices, as recommended: theme files CC0-1.0; fonts bundled as Latin subsets per app, capped; no background images until phase 6; new built-ins in batches, cut what does not earn its place; a new disabled style for filled buttons; Kiwi's contrast changes in phase 3; Approve and primary in `ink` when the accent is near red; upper case only on label and caption roles that never hold a name; layout stays out of themes; mode per device, phones one theme per app. **View > Theme… is ⌃⌘T** (⌥⌘T is Show or Hide Toolbar in Apple's apps), on macOS only: Windows and Linux reach the gallery from myData's Appearance.
- **Order:** the themes foundation (phases 0 to 3) before the phones (M1b). Custom themes (create, import, share) are phase 5, not now.

## Architecture

One host per household, clients on every device. Phones cannot host.

- **Host:** a background service that outlives any window; must also install alone on machines with no screen. On macOS a native install (Docker on a Mac gets no GPU): `myData Host.app`, started at login by a LaunchAgent and independent of every app (see "Host lifecycle"). A development checkout still runs it with `uv run mydata start`.
- **Listening:** loopback only (`service/config.py` refuses any other `server.host`). Phones come through a **second, remote listener** (M1b), the only thing Tailscale Serve proxies to, accepting only per-device credentials. Never expose the model server's port.
- **The host owns data and tools; agents are replaceable.** Every agent reaches tools through one registry (`tools/registry.py`) holding the permission gate. An irreversible call never runs until a user approves that exact held call in an app. A held call is bound to the mode, the conversation epoch and the handler (all three in its digest); switching mode or moving the epoch on fails pending approvals (approving one then returns it unchanged), approving checks the binding again, and a switch waits for running calls (`tests/test_approval_binding.py`). Approvals and the registry's undo log are in memory; the undo of an app's write is persisted (`undo_log`, `POST /undo/{id}`).
- **Apps** talk to the host only through the HTTP API, with no business logic. Opening any app starts the host if it is not running. **Quitting an app never stops the host,** myData included; only myData's menu-bar Stop host and the `mydata` command stop it (`/shutdown` refuses other apps), and myData's Start host starts it again. On connect, a host the app cannot use (another version, code changed on disk, token refused) is replaced once with `mydata stop --unless-current --expect <versions>`. The assistant is optional; no app depends on the chat.
- **Develop on a separate host folder.** Never run a branch against the default folder (`~/Library/Application Support/myData`, port 47821): a new migration would migrate the owner's data. Use `MYDATA_HOME=~/mydata-dev uv run mydata dev-setup` (it refuses a folder an installed host serves), another `[server] port`, and `flutter run --dart-define=MYDATA_HOME=$HOME/mydata-dev`. Tests always use temporary folders.

### Host lifecycle (macOS)

- **Build:** `host/packaging/macos/build_host_app.sh` makes `host/build/macos/myData Host.app` (`kiwi.mydata.host`, git-ignored): uv's managed CPython 3.11 (python-build-standalone) in `Contents/Resources/python` with the host and its locked dependencies (`uv.lock`, wheels only, hashes checked; nothing fetched at run time, every module compiled, run with `-I -B`), launchers `Contents/MacOS/mydatad` (the daemon, argv[0] `mydatad`) and `mydata` (the command), `LSUIElement` and no window. Every Mach-O is signed inside out with the identity in the myData app's `Signing.local.xcconfig`, then the bundle; `codesign --verify --deep --strict` must pass. Development signing only (no hardened runtime, no notarisation).
- **Install:** `host/packaging/macos/install.sh` copies it to `~/Applications` and runs its `mydata service install`: the LaunchAgent `~/Library/LaunchAgents/kiwi.mydata.host.plist` (RunAtLoad; KeepAlive with `SuccessfulExit` false and a 15 s ThrottleInterval; output to `<home>/logs/mydatad.out`; MYDATA_HOME only when not the default), `<home>/app_config.json` pointed at the installed `mydata start` and `mydata stop` (with a `launch_agent` record), then `launchctl bootstrap gui/$UID` (app_config.json is written only once launchd has loaded the agent). **Rebuild and reinstall the myData app before or with the first `install.sh`:** a myData built before 2026-10-23 still stops the host when it quits, and an installed host then stays stopped until the next login or an app starts it. Opened from Finder or Spotlight, `myData Host.app` only asks launchd to start the agent (`mydata start`), or refuses when its folder has none; it never runs a host launchd does not supervise. `uninstall.sh` boots it out and removes the plist, those entries and the app; **the data is never touched.** Both are idempotent and take `--dry-run`; trials use a temporary `MYDATA_HOME`, a free port, `--agents-dir` in a temporary folder and the label `kiwi.mydata.host-test`, booted out at the end.
- **Exit codes are the contract with launchd:** a clean stop (SIGTERM from `mydata stop`, `/shutdown`, logout) exits 0, so launchd leaves it stopped until `mydata start` or the next login; an error exit or a crash is restarted. The daemon catches SIGTERM before its imports, so a stop while it is still starting (migrations, the first snapshot) is a clean stop too. A launchd-started host that finds another running on its folder exits 0. It binds its port before anything else starts (no sync, snapshot or model on a taken port); under launchd a host that cannot start (config error, port taken, an error while building) waits 60 s before its error exit, so KeepAlive retries about once a minute, and writes why to `<home>/logs/start-error`, which `mydata start`, `mydata status` and `mydata service status` show. launchd's `mydatad.out` is trimmed to its last 100 KB past 1 MB. A host that ignores SIGTERM for 15 s is booted out (which stops it) instead of killed, so launchd does not start it again; the apps give `mydata stop` 75 s for that.
- **`mydata start`** asks launchd (`launchctl kickstart`, or `bootstrap` again after a bootout) when the folder records an agent, else starts the host detached as before. A host that holds the folder without answering (Stop host, then Start host at once) is given 30 s to exit, then started again. When the agent is switched off (System Settings > General > Login Items & Extensions, or `launchctl disable`; bootstrap then fails with "5: Input/output error", tried on macOS 26.7), it says so and starts the host detached, which launchd does not supervise. `mydata status` and `mydata service status` say what launchd knows. The apps' replace-on-connect flow is unchanged: they run the installed `mydata stop --unless-current --expect …` and `mydata start`, so an app from a newer checkout settles on "incompatible" until the host is rebuilt and installed again.

### Tokens

- **App tokens:** one per app (`app-tokens/<app>`, mode 0600) with scopes (`APP_SCOPES` in `service/auth.py`). Every route declares its scope (`dependencies=needs(...)` in `service/api.py`); the host refuses to start with a route that declares none; `openapi.json` lists `x-mydata-scopes`; `tests/test_scopes.py` checks every route for every app.

  | App | Scopes |
  |---|---|
  | myData | status, admin, approve, contacts:read, contacts:write, contacts:import, calendar:read, sources:read, sources:manage, shutdown, mcp; calendar:write (reserved) |
  | myAssistant | status, assistant, approve, contacts:read, calendar:read |
  | myContacts | status, contacts:read, contacts:write, sources:read |
  | myCalendar | status, calendar:read, sources:read |
  | `mydata` command | every scope |

  Only apps with `approve` list, read or decide held calls, and each approval records which app decided. Only `shutdown` stops the host. Only `contacts:import` imports: myContacts' File > Import… opens myData, which keeps the one history.
- **Agent tokens:** hashed, `/mcp` only, no scopes.
- **Device credentials** (`dav`, `web`; M1b): bound to a person, accepted only on the remote listener, with rate limits and lockout. App tokens, admin, MCP, approve, import and shutdown never reach that listener.
- **Known limit:** any process running as the same user can read `app-tokens/*`. Harden the app-to-host channel (peer signature over a Unix socket, a Secure Enclave key per send, or Keychain access lists) **before the host sends mail**.

### Data

- One SQLite file per service; binary files on disk. Every record has a device-generated ID, timestamps and a soft-delete marker. Search: FTS5 and sqlite-vec. Index the data; never train on it. Standards over invention: IMAP, CardDAV, CalDAV. Litestream is deferred (it conflicts with the host's `wal_checkpoint(TRUNCATE)`).
- **Owned data is written only through the API** with If-Match (428 without, 412 when stale), each write one transaction with a revision, a change and an undo entry (`sources/contacts_write.py`). Followed cards are refused (409). Deletes are soft (30 days in Recently deleted, purged daily by `service/trash.py`). An undo writes forward, only while the card is at the revision it wrote, once, across restarts.
- **Logs:** writes, imports and the host log hold ids, kinds and counts only: never a card, a name, a file name or a value (a failed call's error: its kind and length only). In real mode the request log keeps the mode, the request text and each argument's shape (name, type, length) and the reply's shape, never values or tool results (`tests/test_request_log.py`, `tests/test_host_log_real_mode.py`); in demo mode it keeps everything.

### Data safety (enforced)

- **Migrations** (`sources/_db.py`): foreign keys off before `BEGIN`; no table may lose rows unless declared `may_shrink`; `foreign_key_check` and `integrity_check` must pass, else rollback. Migrations are additive; dropping a trigger rolls back.
- **Snapshots** (`service/backup.py`): hourly and before every migration, file by file. Stores open through `open_store`, which refuses to migrate a file it cannot snapshot. Kept: 24 hourly, 30 daily, 12 monthly; 90 days for those before a restore or by hand and for the newest 3 before each migration. A failed migration is rolled back and not retried for 15 minutes.
- **Owned rows are kept by the database** (`sources/owned.py`): triggers abort deleting owned rows unless a purge permit names them; only `purge()` writes one, in the same transaction, for three callers: the trash expiry, a delete for good (`purge_now`, at the etag the user saw) and the future Forget. The mirror's hard deletes touch only the followed collections of the account concerned; leftovers are purged only for accounts in `accounts-removed.json`.
- **A new schema version ships with a synthetic dump** (`host/tests/fixtures/schema`, `make_dump.py`); tests migrate every released dump. `mydata db check-migration` runs a migration on copies of real files first.
- `mydata backup verify` (the restore drill), `mydata backup restore` (host stopped), `mydata export` (read back and compared before writing).
- **Off-machine backup gate (M1b):** a verified external copy, "last off-machine backup" in `/status` and a tried restore runbook, before iCloud Contacts goes off and before passwords are ever stored.

### Writers (frozen until real data hits a bug)

- **vCards** (`sources/vcard_edit.py`): a content-line editor, never vobject. Untouched lines are written back byte for byte. A 2.1 card is never edited in place.
- **Events** (`sources/ical_edit.py`): unchanged properties are put back as written; a write that loses a property, value or parameter is refused (`PropertyLossError`). Splits use `X-MYDATA-SPLIT-FROM`, never `RANGE=THISANDFUTURE`.

### Contacts editing and import

Built; the full rules, routes and live runs are in `docs/decisions/2026-10-14-contacts-editing-and-import.md`.

- Only owned cards are written; the first creates the owned address book "myData" (account `local`), switching the host to real mode.
- Import is an app action, never a tool. Previews are in memory and write nothing; a commit takes a snapshot first, in one transaction; losses need `accept_losses`; nothing is merged automatically.
- A file hides the followed copies of the people it brings in (`shadows`): one result per person.

### Sources (followed, read-only)

- **Never write back.** The iCloud client sends only PROPFIND, REPORT, OPTIONS and GET; the Mac helper has no write method (`tests/test_mac_reader_readonly.py`).
- **Nothing goes around them:** no HTTP client outside `DavClient.request`, no mail libraries outside `MAIL_ALLOWED` (`tests/test_dav_no_other_http.py`); only allow-listed modules start programs, never through a shell; no native code, `osascript` or AppleScript (`tests/test_no_way_around_the_helper.py`).
- **This Mac:** `myDataReader.app` inside myData.app, started with `open` only from a validly signed myData with the same identity, over `<home>/run/reader.sock` (0600). Permission is asked only on Allow. Access taken away deletes that copy; "not asked yet" keeps it. Contact notes are never read. It is the default on a Mac host because it uses the system prompt, so no password reaches myData; an app-specific password (iCloud, under Advanced, with the Apple Account email) is never the main path. **From M1b it must exclude the myData account.**
- **The window rule:** `/events` never answers "nothing found" for days a source does not hold.
- Group cards are never listed, counted or found. Turning a source off deletes its mirror; snapshots keep copies until they expire, and the UI says so.

### Demo and real mode

Demo while no source is on and no owned data exists; otherwise real (`mode` in `/status`). Code that creates or purges owned data calls `ModeController.refresh()`. **Switching mode moves the conversation epoch on and ends every conversation.** Demo: six fake tools over `orchestrator/fixtures.py`, today pinned to 18 March 2026 (to become "Try with sample data" in M1a). Real: only `find_contact` and `list_events`; MCP agents get no tools (later, a per-agent permission granted in myData, off by default, with a warning that data may leave the machine).

### Assistant

The model has one job: choose a tool and extract plain arguments. Everything else is code.

- **Dates** are resolved by code from the model's phrase. **Permissions** are code: reads run, reversible writes run with undo, irreversible acts wait for approval. **Ambiguity** makes code ask the user. **Structured output** with a JSON schema; grounding drops invented arguments (`orchestrator/grounding.py`).
- **Untrusted input:** text from mail, invites or web pages may carry instructions; nothing read from them triggers an irreversible tool without approval. Before extraction ships, add the plan's rules: a session that has read such text loses outbound tools unless each call is approved; extraction jobs have no tools; every extracted fact links to its source.
- **Web search** (`web_search`, `fetch_page`) is optional, visible and switchable; prefer self-hosted SearXNG; never put private data into a query without asking.
- Log every request with its tools and outcome. The prompt prefix stays byte-identical (`tests/test_prompt_prefix.py`).
- **Measure on a new frozen request set,** written before looking at output; never edit one (`feasibility/cases.py`, `cases_2026_10_11_b.py`); a request passes only if all reps pass.
- Working model: `qwen3:14b`, thinking off (24 GB Air; a 27B model crashed it). No language model looks at photos.

### Client stack

- **Flutter on every platform** (decided 2026-10-23, item 8), macOS first; the iPhone gets plain HTML from the host until native iPhone apps. The Dart client is generated from `host/openapi.json`, never hand-written. Native pieces (widgets, App Intents, the share sheet) are budgeted per feature.
- **Look today:** everything from `design/` through `mydata_ui`; tokens and the built-in themes generated (`generated_tokens_test.dart` fails when stale); widgets read the look through their context (`context.space(4)`, `context.typeScale.body`, `context.radius.lg`, `context.density.controlHeight`, `context.motion.fast`; `context.lookNow` in `initState`); **no literal colour, radius or font name, and no static read of a themeable token** in any app or widget (`no_literals_test.dart`). Layout asks `MacWindow.of(context)`, how a shared widget is drawn asks `context.isSystemLook`. Each app's theme and palette are chosen per device (`ThemeController` in mydata_core, `themes` in `device/settings.json`; System by default, or one of the drawn built-ins in one of its palettes); light or dark per device. Every writer of `device/settings.json` goes through `DeviceStore.update`, which keeps other apps' keys and never writes over a file it cannot read.
- **Native frame, quiet brand (M1a's look pass):** the platform owns the frame (window, toolbar, sidebar, controls, font, icons, accent, focus ring); myData owns the content. On macOS every app draws the Mac shell in `mydata_ui` (`MacShell`; the adoption steps and API are in its README; all four apps have adopted it); other platforms keep the branded look until their pass. This is the **System** theme; drawn themes keep the Mac window and skeleton and draw inside it. No spec before a component's first use.
- **Themes** (phases in `design/themes/ARCHITECTURE.md` section 5): 1, **done 2026-10-23**: the format, validator and resolver in Dart (`mydata_ui/lib/src/theme/`), the run-time look (`MyDataLook`), the codemod from static token classes to context reads and the `MacLook` split, with every golden byte-identical, built from today's `tokens.json` and `themes.json` (Kiwi, with today's six colours as its palettes); all 18 designed palettes pass at both contrast levels, and today's look shows the audit's known gaps (thin glass, the red ring on Rose and Amber), fixed in phase 3 ("As built" in ARCHITECTURE.md 3.1); 2, **done 2026-10-23**: per app and per device, a theme and a palette per choice (`ThemeController`, migration from the host's theme, the gallery on View > Theme… in every app, myData's Settings > Appearance, Use everywhere with Undo; the host's `PUT /appearance` answers 410, GET kept one release; no theme step at first launch; "Phase 2 as built" in ARCHITECTURE.md 5); 3, **done 2026-10-24**: type, fonts and icons, and the design rules (shape and the shape-following, two-tone focus ring, borders, elevation, density floors at run time, motion, the disabled filled button, Kiwi's link and glass) are built ("Phase 3, design rules as built" in ARCHITECTURE.md 5), and so is every component variant (2026-10-24, "Phase 3, component variants as built"; Kiwi's selected rows gained a leading bar and the approval card its `line-strong` edge, as the rules say); and so are the six as full looks, generated from `design/themes/<slug>/theme.json` (2026-10-24; `themes.json` gone; Kiwi takes its continuous corners, System in the Mac shell keeps round ones; widget goldens are Kiwi and Hairline; each app draws a key screen in all six in the Mac window, `theme_screens_test.dart`), with the move of the old colours ("Phase 3, the six full looks as built"); 3½, **done 2026-10-24**: one validator and one preview harness, `app/tool/preview_themes.sh` (any theme file or slug: validated, then the same four screens of the real apps in each palette, light and dark, off-screen, into PNGs and one sheet per theme, outside the checkout; "Phase 3½" in ARCHITECTURE.md 5); 4, the thirteen new built-ins, in batches, each judged from the harness once ported: **batch 1 done 2026-10-24**, High Contrast, E-ink and Large (with a double focus ring, a colourless danger, Atkinson Hyperlegible and Material Symbols; "Phase 4, batch 1 as built" in ARCHITECTURE.md 5), the other ten next; 5, custom themes; 6, materials.
- **Mac frame tests** run as macOS (`macTestWidgets`, `macScreenMatrix` in mydata_testing), so keys are ⌘ and menus say ⌘E. Dates and times come from `MyDataDates` in every app ("14 Oct 2026", the device's 12- or 24-hour clock).
- Disabled controls always give a reason. On macOS the menu bar (`AppMenuBar`) owns ⌘Z and ⌘S; phones have every action on screen. Forms go read-only while working (`FormBusy`) and commit pending typing first (`FormCommit`). Dates in British English ("Wed 14 Oct 2026"). The focus ring, key order, phone breakpoint and form rules are in `design/README.md`, `design/platforms.md` and `mydata_ui`'s README.

### Repo layout

```
host/        Python: mydatad, the mydata command, tools, API, MCP, orchestrator, feasibility harness
  openapi.json, results/
app/         Dart workspace
  packages/  mydata_client (generated), mydata_core (host lifecycle, tokens, links), mydata_ui,
             mydata_testing, mydata_assistant
  apps/      mydata, myassistant, mycontacts, mycalendar (each later app is a new app/apps/<name>)
design/      design system specs, tokens, previews; themes/ (format, built-in themes and their rules)
docs/        2026-10-23-plan.md and decisions/ (history)
```

The links between the apps are in `mydata_core` (`AppLinks`, `IncomingLinks`, `InstalledApps`); the runner side is `macos_snippets/LinksAppDelegate.swift`.

## Status (2026-10-23)

Built and tested against fakes and synthetic hosts, **never used live by the owner**: the host with the gate, scopes, safety net, writers and export; followed contacts and calendars (This Mac, iCloud); the four apps on the design system; contacts editing, import, merge and review. Nothing reaches the phones (loopback only). M1a in progress: the stack gate is done (Flutter on every platform); the host builds as a signed `myData Host.app` with a LaunchAgent, **installed for the owner as a login service since 2026-10-23** and reinstalled after phase 2, and the four apps and the host app sign with the Apple Development certificate. Themes: designed and decided (phase 0; renamed after their design language and split into style and palettes the same day); phases 1 and 2 built 2026-10-23 (the run-time look; each app's theme and palette per device, with the gallery) and phase 3 on 2026-10-24 (the six as full looks in their palettes, the old colours moved); none seen on a real Mac yet; phase 4's first three new built-ins (High Contrast, E-ink, Large) on 2026-10-24, the other ten to come. The old phase build order is replaced by the milestones below.

## Milestones (plan section 6, adjusted for 2026-10-23)

- **M0, housekeeping. Next.** Owner: the Apple Development certificate; switching off the spike app's grants. Mine: `Signing.local.xcconfig`; `mydata db check-migration` on copies of the owner's files (schemas 5 to 7). Done: push, licence, this file cut, CI. Accept: two rebuilds without a second Contacts prompt.
- **M1a, the Mac (2 to 3 weeks).** The host as a signed `.app` with a LaunchAgent (built and installed for the owner 2026-10-23); the stack gate (**done 2026-10-23: Flutter chosen**); the look pass in **each** of the four apps (Mac density, system font and accent, icons, a real app icon); first launch in myData (Allow, or Try with sample data); History, Restore and Cleanup in myContacts; Proof of privacy v0 in myData.
- **Themes foundation (phases 1 to 3), after M1a's look pass and before M1b.** Phases 0 to 3 are done (phase 3 on 2026-10-24); the owner's look on a real Mac is still to come.
- **M1b, contacts on both phones (3 weeks).** The backup gate first; the remote listener and Tailscale Serve; day 1 records stock Radicale against iPhone, Mac Contacts and DAVx5, then our CardDAV against the recordings; Settings, Devices; This Mac excludes the myData account; the switch-over tool; `mydata check security`.
- **M1c, calendar and tasks on both phones (2 weeks).** CalDAV for an owned calendar and plain VTODO; `.ics` import; provider calendars stay followed.
- **M2:** the host's web page (Today, Search/Ask, Settings) with Web Push; Android APKs; ⌘K and Ask in myAssistant; notifications.
- **M3:** the `items` index; person pages in myContacts; a model bake-off on a new frozen set. Then decide on a Mac mini.
- **M4** mail archive, read-only (myMail). **M5** brief and tasks. **M6** extraction from mail (no tools). **M7** photos through Immich. **M8** sending and the assistant acting (channel hardened first).
- **Native iPhone apps** when the owner pays for the Apple Developer Program.

## Open questions

- Where Today, ⌘K and person pages live (proposed: Today in myData, ⌘K and Ask in myAssistant, person pages in myContacts).
- Where to keep conversation history (in memory now).
- Themes: a key for View > Theme… on Windows and Linux (Ctrl+T is myCalendar's Go to Today); whether a tinted System exists off macOS (phase 5 or that platform's pass); whether the sidebar's `rail` and `tabs` values stay, since they change layout (decision 9); whether the approval card may take a theme's corners, shadow and Edit style, or only its colours and fonts (ARCHITECTURE.md 5, "component variants as built"); whether System in the Mac shell keeps round corners or takes Kiwi's continuous ones (System keeps round corners on every platform for now). The Mac widgets take a drawn theme's type, density, corners and selection since the phase 3 review (2026-10-24, "the six full looks as built"); the owner's look on a real Mac decides whether that stays.
- Releasing on macOS needs the paid program: Developer ID, hardened runtime, notarisation, and the entitlements in `Reader.entitlements`. Development signing goes through the myData app's git-ignored `Runner/Configs/Signing.local.xcconfig`, which the other three apps include and `build_host_app.sh` reads.
- Chained requests (26% in round 2) need a planner; start from `host/results/2026-10-11-b-REPORT.md`.

## Known rough edges

- **Signing:** the apps and the host app now sign with the Apple Development certificate; M0's check (two rebuilds without a second Contacts prompt) is still the owner's to make. A checkout without `Signing.local.xcconfig` builds ad hoc, and every rebuild is then a new app to macOS.
- **Never run live:** the apps against a live host or each other, the links between apps, the phone layouts, Windows and Linux builds.
- **The calendar reader** takes one zone per custom TZID and gives the occurrence in the skipped hour no length.
- `test_a_reader_that_fails_the_same_way_every_time_backs_off` is timing-sensitive: run the host suite on a quiet machine.
- **App icons** (`design/assets/Logos/app-icons`: an Icon Composer `.icon` per app for macOS 26, the classic icon for older systems) have only been seen in `ictool`'s renderings, never in a real Dock, Finder or Spotlight. `KiwiLoader` is a placeholder.
- A host-only code change shows as `stale`; the next app to connect restarts the host, ending conversations.
- This Mac is unverified across a reboot, over hours, with Google or Exchange accounts and with signed builds.
- Real-mode tool descriptions were measured on the demo set; new ones need a new frozen set.

## History

Moved verbatim from this file on 2026-10-23:

- `docs/decisions/2026-10-11-feasibility.md`: hardware and model findings; the feasibility test and its result.
- `docs/decisions/2026-10-12-round-2.md`: round 2 (chained requests).
- `docs/decisions/2026-10-12-answer-latency.md`: Part A and its open items.
- `docs/decisions/2026-10-14-architecture.md`: architecture, tokens, sources, modes, assistant, photos, client stack and repo layout in full.
- `docs/decisions/2026-10-14-data-safety-and-writers.md`: data layer, data safety and the writers in full.
- `docs/decisions/2026-10-14-contacts-editing-and-import.md`: contacts editing, import and the import UI.
- `docs/decisions/2026-10-14-status-and-build-order.md`: phase status, the 2026-10-13 direction in full, assets, the old build order, open questions and rough edges.
- `docs/decisions/2026-10-23-stack-gate.md`: the M1a side-by-side of Flutter and SwiftUI, and where each side's pieces are.
- `docs/decisions/2026-10-23-themes.md`: the owner's request for whole-look themes, the decisions, what a theme can change and the build phases.
- `docs/2026-10-13-own-data-plan.md` (superseded) and `docs/2026-10-23-plan.md` (current).
