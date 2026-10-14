# myData

Open-source, self-hosted personal cloud with a local assistant. All user data stays on hardware the user owns. A family of "my"-prefixed apps connects to one host that stores, syncs, indexes, and runs the models.

This file is the project's working memory. Read it before doing anything. Update it when a decision changes.

## Status

Early build. Done:
- the marketing site;
- two rounds of feasibility testing (see "Feasibility test result" and "Round 2 result");
- **the host** (phase 1): `mydatad` with the tool layer and permission gate, HTTP API, MCP, app and agent tokens;
- **the first two apps** (phase 2): myData (setup, status, settings) and myAssistant (chat), in Flutter, macOS first;
- **answer latency** (Part A): results on screen in about 3.5 s instead of 13;
- **the design system** (Part B): `design/` in Flutter (`mydata_ui`), six themes in light and dark, the theme stored on the host and followed by every app;
- **real contacts and calendars on the host** (phase 3): a read-only mirror from **This Mac** (macOS Contacts and EventKit, the main path on a Mac host) or from a followed iCloud account (CardDAV, CalDAV; under Advanced, for hosts that are not Macs). See "Contacts and calendars sources";
- **the myContacts and myCalendar apps** (phase 4): read-only views of the mirror, with links between the apps (`mycontacts://contact/<id>`, `mycalendar://day/<date>`, `mydata://settings/sources`). myAssistant opens a real contact or event result in them when they are installed, and myData's Status lists the apps with their counts and sources;
- **the safety net** (phase 0a of the owned-data plan): migrations with foreign keys off, snapshots (hourly and before every migration), the restore drill, restore and a raw export. See "Data safety".

**Sync is read-only for now:** the host only reads from its sources, and no app edits a contact or an event. The two modes are described in "Demo and real mode". **Next:** myMail; see "Build order". Chained requests are an open problem, not a blocker: the planner write-up in `host/results/2026-10-11-b-REPORT.md` is the starting point. Answer latency is in "Answer latency" below.

## Ground rules

- Non-commercial hobby project. No payments, donations, sponsorship links, or company entity. Do not add any of these to code, docs, or the website.
- Work happens on the owner's personal computer and personal GitHub account only.
- Not affiliated with MyData Global; the site footer says so. Keep that line.
- No trademark filing planned. "myData" is descriptive and crowded.
- Owner's working style: direct, concise answers. Stress-test ideas and lead with what is wrong or missing. No flattery.

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

## Names

| Name | What it is | Runs on |
|---|---|---|
| myData | The host (`mydatad`): stores, syncs, indexes, runs models. Also the myData app: setup, status, settings; later the dashboard and file browser | Host on macOS, Windows, Linux. App everywhere |
| myAssistant | Chat (later voice) app | Everywhere |
| myContacts, myCalendar, myMail, myPhotos | First apps | Everywhere, as clients |
| myNotes, myReminders, myFiles, myDocs, myHealth, myHome and others | Later apps | Everywhere, as clients |

Technical names: repo `mydata-kiwi/mydata`, command `mydata`, background service `mydatad`. In prose, call the host "the host".

## Existing assets

- Domain: mydata.kiwi. DNS is in Cloudflare, records set to DNS only (proxy off, on purpose).
- GitHub org: `mydata-kiwi`.
- Website repo: `mydata-kiwi/mydata-kiwi.github.io`. One `index.html`, deployed by GitHub Pages from `main`. Custom domain mydata.kiwi is verified and served over HTTPS from GitHub Pages.
- Logo: hand-drawn outlined kiwi bird with a green wash. Colours: background `#E3EFBF`, wash `#A9CC4E`, ink `#2A2018`.
- **Design system: `design/` is the source of truth** for how the apps look: `tokens.json` (the Kiwi theme's values), `themes.json` (six themes: Kiwi, Graphite, Dusk, Plum, Rose, Amber), the README, `theming.md`, `motion.md`, `platforms.md` and a spec with an HTML preview per component. Light and dark mode. The Flutter implementation is `app/packages/mydata_ui` (tokens generated from the JSON; see its README for the decisions taken where `design/` disagreed with itself). The website keeps its own styling and is not changed by `design/`.
- A fuller plan document exists ("myData: architecture, technical plan, and viability check"). This file supersedes it where they differ.

## Architecture

One host per household, clients on every device.

- **Host**: a background service that outlives any window and starts at login. It must also install alone on machines with no screen (Linux mini PC, NAS, Docker). On macOS it must be a native install, because Docker on a Mac gets no GPU acceleration.
- **Clients**: talk to the host over the local network, and over Tailscale when away. Never expose the model server's port to the internet. **For now the host listens on localhost only** (127.0.0.1); phone and remote access come later as a separate, explicit design.
- **The host owns data and tools; agents are replaceable.** Every agent reaches tools through one registry, which holds the permission gate: our orchestrator, or any MCP agent at `/mcp`. An irreversible call never runs until a user approves that exact held call in an app.
- **Tokens.**
  - **App tokens:** one per app (`app-tokens/<app>` in the host's folder, readable only by the user). The myData app, myAssistant and the `mydata` command can do everything, including approving, and each approval records which app decided. myContacts and myCalendar only read: their tokens get GET, nothing else (`READ_ONLY_APPS`).
  - **Agent tokens:** created and revoked with `mydata agent ...` or in the myData app, with only their hash stored. They reach `/mcp` only.
- **Apps.** The product is a family of separate apps built from shared code, not one combined app with a sidebar. Each app talks to the host only through the HTTP API, with no business logic in the app. The user opens an app and the host starts by itself.
  - Only the myData app owns the host's lifetime: it has a menu-bar icon with Open and Quit, and Quit stops the host. The host enforces this: `/shutdown` refuses other apps.
  - Other apps, such as myAssistant, can start the host but never stop it.
  - One exception, for every app: on connect, a host the app cannot use as it is (another version or API version, its code changed on disk since it started, or it refuses the app's token) is replaced, once, with `mydata stop --unless-current --expect <the app's versions>` and a start. The stop does nothing when the host the start command would start is not the app's build either, or when the running host is already current, so an app never stops a host it could not use afterwards.
  - The assistant is optional: the apps work without a model.
- **No app depends on the chat.** myPhotos talks to the host directly.
- **Phones cannot host.** iOS and Android suspend background apps and lack the memory. No third-party wake word on iOS; no iMessage or phone-call control.

### Data layer

- One SQLite file per service; binary files on disk.
- Every record has a device-generated ID, created and modified timestamps, and a soft-delete marker.
- The host is the source of truth.
- Backups: the host's own snapshots of every SQLite file (see "Data safety"). Litestream is deferred (it conflicts with the host's `wal_checkpoint(TRUNCATE)`); restic for files is optional and later.
- Search: SQLite FTS5 for text, sqlite-vec for embeddings. Index the data; do not train on it.
- PostgreSQL with pgvector only if multi-user support is ever needed.
- Standards over invention: IMAP for mail, CardDAV for contacts, CalDAV for calendar.

### Data safety

- **Migrations** run on their own connection with foreign keys off, set before `BEGIN`; then no table may have lost rows (unless the migration declares it, `may_shrink`), and `foreign_key_check` and `integrity_check` must pass, or the migration is rolled back (`sources/_db.py`). With foreign keys on, rebuilding a parent table deleted every child row through `ON DELETE CASCADE`.
- **Snapshots** (`service/backup.py`): `backups/<UTC time>/` in the host folder, hourly while the host runs and always before a migration. **The host never migrates a file without a snapshot:** stores are opened through `open_store`, which refuses (and reports it in `/status`'s `last_error`) when that file cannot be copied. Files are copied one by one, so one damaged database never stops the others being backed up. Kept: 24 hourly, 30 daily, 12 monthly, plus 90 days for those taken before a restore or by hand, and for the newest 3 taken before each migration (file and version). A failed migration is rolled back and not retried for 15 minutes; a retry on an unchanged file reuses its snapshot.
- **Restore drill:** `mydata backup verify` restores a snapshot into a temporary folder, migrates and checks it, and records the result, which `/status` reports with the last snapshot and FileVault. It runs in the test suite on synthetic data; there is no CI. `mydata backup restore` needs the host stopped; a live database too damaged to copy is kept byte for byte in the pre-restore snapshot's `damaged/` folder. `mydata export --out DIR` writes the stored vCards and ICS outside the checkout.
- **Develop on a separate host folder.** A branch with a new migration, run against the default folder, migrates the real data (after a snapshot), and an older checkout then refuses the newer file. Run a development host with its own `MYDATA_HOME` (outside the checkout) and port: `MYDATA_HOME=~/mydata-dev uv run mydata dev-setup` creates `~/mydata-dev/config.toml` (and lets the apps start that host); set its `[server] port` to something other than 47821 before `MYDATA_HOME=~/mydata-dev uv run mydata run`. Point the apps at it with `flutter run --dart-define=MYDATA_HOME=$HOME/mydata-dev`. Tests always use temporary folders.

### Contacts and calendars sources

Read-only mirrors in `contacts.sqlite` and `calendar.sqlite` (`host/src/mydata/sources/`). The user turns each source on or off in the myData app (Settings, Sources); turning one off deletes what it mirrored from the mirror. **Copies stay in the host's snapshots until they expire:** by the first day of the same month next year (`backup.kept_until`), while the host keeps running. The CLI and the API docs say so; the myData app's turn-off and remove dialogs do not yet.

- **Read-only for now.** No source ever writes back: the iCloud client sends only PROPFIND, REPORT, OPTIONS and GET, and the Mac helper has no write calls. Writing back (and the host as a CardDAV/CalDAV server) is a later decision.
- **Why This Mac is the default on a Mac host:** it uses the normal system permission prompt, so no password reaches myData, and it covers every account on the Mac (iCloud, Google, Exchange). Asking for an app-specific password is not acceptable as the main path, and Apple rejects sign-ins that use an address other than the Apple Account email (for example a custom domain).

- **This Mac** (Mac host only; absent, not broken, elsewhere): a Swift helper, `myDataReader.app` (`app/apps/mydata/macos/Reader`), inside `myData.app/Contents/Helpers`. macOS attributes it to myData, so the permission prompt names myData and the grant belongs to `kiwi.mydata.mydata`. No password or account detail reaches myData, and every account set up on the Mac is covered.
  - The host starts it with `open` (LaunchServices), never by running the binary, and only from a path inside a validly signed myData app with the same signing identity. It talks JSON lines over `<home>/run/reader.sock` (folder 0700, socket 0600, one connection at a time).
  - **Read-only:** all framework access is behind one Swift protocol with no write method; a host test scans the helper's sources for write calls.
  - **Permission** is asked only when the user presses Allow in the myData app, never at login.
  - The user chooses which contact accounts and calendars are included (all by default).
  - **Contact notes are never read** (they need an entitlement Apple grants on request); the API says `notes_included: false`. Photos are read when allowed, otherwise the apps show initials.
  - **Events:** EventKit gives only expanded occurrences, so the Mac source keeps a rolling window, one year back and two years ahead, read in pieces of at most 4 years. An occurrence is keyed by (calendar, external id, occurrence date), so one event in two calendars is two rows.
  - **The window rule:** list_events and `/events` never answer "nothing found" for days a source does not hold. It is decided per source: an iCloud account holding every day never hides the Mac's limit.
  - Large snapshots arrive in parts of a few MB.
- **iCloud account** (Advanced): CardDAV and CalDAV with an app-specific password and the Apple Account email, which may differ from an address on the user's own domain. It holds every date.
- **Switching mode ends every conversation.** The host moves its conversation epoch on (`state.json`, `conversation_epoch` in `/status`); myAssistant then shows one line saying a new conversation has started, and a message to an older epoch's conversation gets a `reset` event.
- **The same account through both sources** (an iCloud account set up on the Mac and also followed) is mirrored twice: its contacts and calendars are listed twice, and myCalendar lets the user hide either copy. Hiding is kept on the device and followed by myCalendar only: myAssistant's answers come from the host and still include hidden calendars (and both copies). While This Mac is on, Settings says under each followed account that following it is not needed on a Mac that has it in System Settings.

### Demo and real mode

The host is in **demo mode** while no source is on, and in **real mode** as soon as one is (`mode` in `/status`). Turning the first source on or the last one off switches it.

- **Demo mode:** the six built-in tools serve the fake data in `orchestrator/fixtures.py`, and the host's today is pinned to 18 March 2026 (`demo_date` in `/status`; myData shows a "Demo date" chip, myAssistant "Demo data"). MCP agents get the same six fake tools. myContacts and myCalendar have nothing to show and point to myData, Settings, Sources. Results in myAssistant never open in another app: their ids and days are not the user's.
- **Real mode:** only `find_contact` and `list_events` are offered, reading the mirror, with the real date and the machine's time zone. Mail, photos and creating events have no real source yet, so those tools are not offered. MCP agents get no tools. The request log records the mode and holds no mirrored data. A `result` event says `"mode": "real"`; a contact item carries its id and an event item its day, so myAssistant opens them in myContacts and myCalendar when installed.

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

### Repo layout

```
host/                 Python: mydatad, mydata command, tool layer, API, MCP, orchestrator, feasibility harness
  openapi.json        generated from the app; the Dart client is generated from it
  results/            feasibility runs and reports
app/                  Dart workspace
  packages/mydata_client     generated API client
  packages/mydata_core       host lifecycle (find, start, wait, watch), app tokens, error states
  packages/mydata_ui         design system: tokens generated from design/, MyDataTheme, fonts, logo, widgets
  packages/mydata_testing    test helpers: bundled fonts in tests, golden and screenshot matrices
  packages/mydata_assistant  chat, streamed replies, progress lines, approval card, results that open in their apps
  apps/mydata                the myData app
  apps/myassistant           the myAssistant app
  apps/mycontacts            the myContacts app (read-only)
  apps/mycalendar            the myCalendar app (read-only)
CLAUDE.md, README.md
```

Each later app (myMail, myPhotos, ...) is a new `app/apps/<name>` on the same packages. `mydata_core` also holds the links between the apps (`AppLinks`, `IncomingLinks`, `InstalledApps`; the runner side is `macos_snippets/LinksAppDelegate.swift`).

## Hardware and model findings

Measured on a 24GB Apple-silicon MacBook Air:

- A 27B model crashed the machine (about 17GB of weights plus context plus macOS exceeds 24GB).
- `qwen3:14b` fits: 10GB, 100% GPU.
- With thinking on, answers took 30 to 120 seconds. Run with `--think=false`; the shipped configuration must work without thinking.
- Default context was 4,096 tokens. Too small for multi-turn or web content; raise `num_ctx` to 8,000 to 16,000 when needed and watch memory.
- Realistic ceiling on 24GB is about 20B. `gpt-oss:20b` is the candidate above 14B.
- A 16GB machine tops out around 8B. A phone handles 3 to 4B, as an offline fallback only.

### First manual test (10 requests, tools described in text, thinking off, one shared chat)

- Right tool chosen: 9 of 10, including both chained requests.
- Fully correct, judged strictly: 3 of 10.
- Failures: 4 date errors (wrong day, wrong year), 3 rule failures (skipped a confirmation, guessed at an ambiguous name, offered to delete with no delete tool).

Conclusion: tool choice is promising; dates and rules must move into code. That finding is why the architecture above assigns them to code.

## First task: the feasibility test

Build this before anything else. Its harness becomes the first version of the orchestrator, so write it as real code, not a throwaway script.

**Setup**

- Python, calling Ollama's chat API with real tool definitions (not tools described in the prompt).
- Six fake tools that only record their arguments: `search_mail`, `send_mail`, `search_photos`, `find_contact`, `list_events`, `create_event`.
- Date arguments are natural phrases. A resolver in code converts them, given a fixed "today".
- A permission gate in code blocks `send_mail` pending approval.
- `find_contact` returns canned results, including a case with several matches.
- Thinking off. One fresh context per request.

**Requests: 30, written before looking at any model output**

| Type | Count | Example | Correct behaviour |
|---|---|---|---|
| Single tool, clear | 10 | "Show photos from Goa last December" | `search_photos` with place and the date phrase |
| Arguments need care | 6 | "What's on my calendar next Friday?" | `list_events` with the right phrase |
| Two or three steps chained | 5 | "Email Rishita the time of my dentist appointment" | `list_events`, `find_contact`, then `send_mail` (gated) |
| Ambiguous | 3 | "Message Patel about tomorrow" | `find_contact` returns several; code asks |
| No tool needed | 3 | "What's 15% of 80?" | Answer directly, no calls |
| No suitable tool | 3 | "Delete all mail from my bank" | Say it cannot; call nothing |

**Method**

- Run each request 3 times per model.
- Models: `qwen3:14b` and `gpt-oss:20b`. Optionally `qwen3:8b` to see whether a faster model matches.
- Record per run: right tool, arguments correct (strict), any invented tool or argument, seconds to first tool call.
- Print a results table per model and per request type.

**Reading the result**

- 90% or more fully correct: the local-only design works. Start building.
- 70 to 90%: look at which type fails; consider a planner step or the larger model.
- Under 70%: local-only on this hardware is not viable as planned. Options are a 48GB or larger host, or a hybrid that sends hard requests to a hosted model.

Do not count "close enough" arguments as passes, and do not rewrite requests after seeing what the model is good at.

## Feasibility test result (2026-10-11)

Full detail: `myData/results/2026-10-11-full/report.md` and `REVIEW.md`. 30 requests × 3 reps, strict scoring, fixed today Wed 18 March 2026, Ollama 0.40.1, 24GB MacBook Air.

| Model | Fully correct (after hand review of refusals) |
|---|---|
| `qwen3:14b`, think off | 78/90 (87%) |
| `qwen3:8b`, think off | 67/90 (74%) |
| `gpt-oss:20b`, think low (it cannot be turned off) | 63/90 (70%) |

- Dates in code works. `qwen3:14b` got every date case right on every rep.
- Chained requests are the weak spot (`qwen3:14b` 53%). Models search mail for calendar facts, and gpt-oss writes made-up times into emails. The permission gate held every send.
- gpt-oss:20b and qwen3:8b invent optional arguments (location, duration) on every create_event. qwen3:14b does not.
- gpt-oss:20b is worse than qwen3:14b, so "use the larger model" is not the fix on 24GB. `qwen3:14b` is the working model.
- Thinking off gives a median of 2.5 to 3.9 s to the first tool call.
- Round 2 (below) tried the code fixes for chains on a new set. Never edit the 2026-10-11 set.

## Round 2 result (2026-10-11/12)

Full report: `myData/results/2026-10-11-b-REPORT.md`. New frozen set `cases_2026_10_11_b.py`: 40 requests, 15 of them chained, its own dataset, committed before any orchestrator change. Model `qwen3:14b`, thinking off, 3 reps. Each row adds one fix.

| Row | Overall runs (requests passing all reps) | Chains runs (requests) | Median s to first tool call |
|---|---|---|---|
| baseline | 65% (26/40) | 20% (3/15) | 3.8 |
| +a tool descriptions | 70% (28/40 hand-reviewed) | 28% (4/15) | 3.9 |
| +b per-request tool filtering | 70% (28/40) | 26% (4/15) | 4.5 |
| +c grounding check | 67% (27/40) | 26% (4/15) | 4.6 |

- Chains stay far under 80%. The model treats a chain as one step: it skips the lookup and acts on a guess, passes a description ("the day of Farah's housewarming") as an argument, or reads the wrong source.
- No planner was built, as agreed for this round. The report lists what one would need to fix. Measure any planner on a new frozen set; 2026-10-11-b has now been seen.
- **Kept: (a) tool descriptions and (c) grounding.**
  - (a) gave +5 runs at no cost.
  - (c) did not raise the score. It blocked 6 sends with an invented address and dropped invented event fields before the user saw them. Its one cost was a duration worked out from two times (BA03), which it dropped; fixed in Part A (see "Answer latency").
- **Not kept: (b) per-request tool filtering.** It is off by default (`Engine.route=False`); the module stays so the measurement can be reproduced. It gained nothing, added 0.6 s, and by design hides tools that a chain needs when the wording does not name the source.
- The kept combination (a + c, without b) was not itself measured.
- Scoring: raw and hand-reviewed scores are both reported, and requests count as passing only if all reps pass. The hand-review rule for refusals is automated in `scoring.py`.
- Kept configuration (a + c, routing off), measured as a whole: 68% of runs strict after hand review (27/40 requests); chains 26% on both the strict and outcome scores (4/15). Median 12.4 s to the final answer, worst 39.5 s.
- Thinking on, chains only: strict 40% (4/15 requests), outcome 48% (6/15). Median 181 s to the final answer, worst 693 s. It fixes some lookup-skipping but often asks the user for facts it could look up; too slow to ship.
- An "outcome correct" score (ignores rejected calls the model then corrected) is now reported next to strict. Defect found: grounding read "4-9" as one token and rejected "Slides 4-9" (BC14); fixed in Part A.

## Answer latency (Part A, 2026-10-12)

Full report: `host/results/2026-10-12-a-REPORT.md`. Measured on battery, with BTLEServer using one core throughout.

- **Results are shown by code.** A read tool's result goes to the app at once as a `result` event (`{kind, header, items}`), with a one-line header written by code. Single-tool requests: result on screen median 13.4 → 3.5 s, worst 35.7 → 5.9 s; end of reply 13.4 → 7.0 s, worst 35.7 → 8.2 s.
- **A model sentence is written only when the list does not answer the question.** It is streamed, capped at about 40 tokens, and decided by a code rule (`[model] followup = "rule"`, `orchestrator/followup.py`). Tool choice is unchanged: 27/40 requests before and after.
- **Rejected: a `then` field on the tool-choice call.** It changed which tools the model chose (BS10, BM04, BU01).
- **Open defect: the rule misses sentences.** It caught 4 of the 12 needed in a blind probe set (open item 1 below).
- **Keep warm.** The model is loaded while the assistant is on, and a warm-up request caches the prompt prefix. The prefix must stay byte-identical across requests (`tests/test_prompt_prefix.py`).
- **Grounding fixes.** "4-9" is grounded by "4 to 9", and a duration between two grounded times is allowed.
- **Speed.** The M4 Air peaks at about 11 tok/s generating and about 100 tok/s reading a cold prompt. On this fanless machine, heat costs about 15% within minutes, and swap bursts caused by other apps cost about 20% more. Background CPU load does not matter. The earlier 8.5 tok/s and 25 s cold read were a hot machine after 25 to 50 minutes of continuous requests.

**Open items for the next assistant round** (agreed; not built):

1. **Follow-up sentence: flip the default.** Write the short sentence unless the request is plainly a show/list request, instead of only when a question is recognised. A missed answer is worse than an extra sentence. Measure on a new blind set of about 40 requests, written before the rule changes.
2. **Keep the input usable while the second model call runs.** Cancel that call if the user sends something new.
3. **Temperature for the tool-choice call.** Measure 0 and 0.2 against today's 0.6 on a new frozen set, reporting requests that pass on all reps.
4. **Repeat the speed check plugged in, on a quiet machine,** to separate battery from heat.

## Build order after the test passes

1. ~~Host skeleton~~: done (phase 1): service, config, logging, tool layer and gate, API, MCP, tokens.
2. ~~myData and myAssistant apps~~: done (phase 2), macOS first, against the fake tools.
3. ~~Answer latency~~: done (Part A, 2026-10-12): results shown by code, the model kept warm. Open items are listed under "Answer latency".
4. ~~Design system~~: done (Part B): `design/` implemented in `mydata_ui`, the theme stored on the host, both apps restyled.
5. ~~myContacts and myCalendar~~: done. The host side, with This Mac (Contacts, EventKit) as the main source on a Mac and iCloud (CardDAV, CalDAV) under Advanced, replacing the fake contact and calendar tools in real mode; then the two read-only apps in `app/apps`, the links between the apps, myAssistant's results opening in them, and the apps on myData's Status. myCalendar shows the window limit that `/events` reports.
6. **Next:** myMail (IMAP sync, FTS5 search), replacing the fake mail tools.
7. myAssistant against the real tools; revisit chained requests (planner) and the sentences the follow-up rule misses (see "Answer latency").
   - **Real-mode tool descriptions:** in real mode `find_contact` and `list_events` still use the descriptions measured on the demo set, which mention mail. New descriptions need a new frozen request set and a measurement before they replace them.
   - **Outside agents and real data:** MCP agents are blocked from real data (in real mode they get no tools). Later: a per-agent permission, granted in the myData app, off by default, with a warning that the data may leave this machine.
8. myPhotos (import, CLIP index, faces). The largest piece; expect 6 to 8 weekends.
9. Phone clients and remote access (the host is localhost-only until then).
10. Packaging: installers, a bundled host binary (the place to start it is marked in `mydata_core`), Windows and Linux builds on those systems.

## Open questions

- Licence: MIT or AGPL.
- Whether to reuse existing servers (for example Radicale for CardDAV and CalDAV) or write them.
- Where to keep the conversation history (in memory now; lost when the host restarts).
- Whether myAssistant should ask the myData app to open its Setup when myData is already running. Today `--setup` only works on a cold start of myData.
- **Releasing on macOS** (not needed for development). It needs the paid Apple Developer Program, for:
  - a Developer ID Application certificate for the myData app and its helper;
  - the hardened runtime;
  - notarization;
  - the two entitlements on `myDataReader.app`: `com.apple.security.personal-information.addressbook` and `com.apple.security.personal-information.calendars`. `Reader.entitlements` has them, and `build_reader.sh` applies them when `ENABLE_HARDENED_RUNTIME=YES`.

  Development builds are signed ad hoc, or with a free Apple Development certificate through the git-ignored `Runner/Configs/Signing.local.xcconfig`. With a Developer ID, the host's check of the helper could also pin the team id; today it only requires the same identity as the myData app around it.
- Website: may move to a static-site generator. If so, it must build to static files for GitHub Pages and keep the `CNAME` file. Not a priority.

## Known rough edges

- The website's header animation (kiwi walks in, pecks the "M" to lower case, jumps) and the pull-to-refresh kiwi-slice loader were never visually verified end to end. Expect to tune timing and positions.
- The app icon file and the newer logo (pale green background with wash and ground line) do not match yet.
- The myData and myAssistant apps still use Flutter's default app icons; `design/assets/Logos/mydata-kiwi-app-icon.svg` exists but is not applied. Inside the apps the kiwi appears only on empty and loading screens and in the menu-bar icon, as `design/` says.
- Design-system gaps found while restyling:
  - The loading "kiwi slice" has not been drawn. `KiwiLoader` (the kiwi mark on a turning badge) is a placeholder.
  - The icon set has not been drawn. The apps use Material outline icons.
- myAssistant's "Open myData" (assistant off) can only bring myData forward, or open Setup on a cold start. myData now takes one link, `mydata://settings/sources`, but there is none for its Assistant setting yet.
- The links between the apps, myAssistant's results opening in myContacts and myCalendar, and the Status rows' "Open" are tested with fakes only. None has been tried between built apps on a Mac, and myContacts and myCalendar have not been run against a real host. myCalendar's time zone channel has not been tried live.
- The phone layouts (floating tab bar, large title) are built and covered by goldens, but have not been run on a phone.
- Windows and Linux builds of the apps have not been made: Flutter builds them only on those systems. Their code paths compile (`flutter analyze`).
- **The owner's Mac still builds ad hoc** (checked 2026-10-13): no Apple Development certificate is in the keychain, Xcode has no account, and there is no `Signing.local.xcconfig`. An ad hoc build's designated requirement is its code hash, so every rebuild is a new app to macOS and the Contacts and Calendars permission is asked again. The fix is the certificate (steps in `Signing.local.xcconfig.example`); a self-signed certificate does not work without trusting it, which needs an admin prompt.
- The host runs as `mydatad` (argv[0]; `pgrep mydatad`, `ps`). On macOS the kernel name in `top` and Activity Monitor is still the Python binary. The Linux form (an absolute path beside the interpreter) has not been run on Linux.
- An app replaces a host from another build only when it connects (the poll reports it and restarts nothing). A host-only code change shows up as `stale` in `/status`, so the next app to connect restarts the host, which ends in-memory conversations.
- This Mac has not been verified:
  - across a reboot;
  - with the helper running for hours (it was watched for 5 minutes);
  - with Google or Exchange accounts (the test Mac had only iCloud, On My Mac, a subscribed calendar and Birthdays);
  - on macOS versions other than 26.7;
  - with signed and notarized builds;
  - starting the host at login through Apple's login-item mechanism (a plain login agent was used).