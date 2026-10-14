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
- **the safety net** (phase 0a of the owned-data plan): migrations with foreign keys off, snapshots (hourly and before every migration), the restore drill, restore and a raw export. See "Data safety";
- **the additive schema** (phase 0b): owned and followed collections, owned data kept by the database itself, hard deletes limited to followed data, group cards no longer shown as contacts. See "Data safety";
- **tokens, approvals and logging** (phase 0c): scopes per app token, approvals bound to mode and epoch, argument shapes only in the real-mode request log, and scans for mail libraries, `osascript` and `subprocess`. See "Tokens" and "Demo and real mode";
- **writers and export** (phase 1): a vCard line editor and an ICS writer with a property guard and the four edits of a repeating event, as library code with tests, and a clean export. See "Writing contacts and events";
- **contacts editing** (phase 3, host and myContacts): an owned "myData" address book, create, edit (If-Match), delete to Recently deleted, restore, delete for good, persisted undo and the daily trash expiry, through the API; myContacts creates, edits and deletes the host's own contacts (Inspector, Undo toasts, several at once, Recently deleted), followed ones stay read-only. Groups and the photo picker are not built. See "Editing contacts".

**New direction (2026-10-13): the host owns the data.** See "Direction: the host owns the data". Today sources are still only followed (read-only); myContacts creates and edits the contacts the host owns; the safety work that must come first (snapshots, safe migrations, owned-data protection, token scopes, the lossless writers) is done. The two modes are described in "Demo and real mode". **Next:** phase 2 of the plan, the form components, spec first; see "Build order". Chained requests are an open problem, not a blocker: the planner write-up in `host/results/2026-10-11-b-REPORT.md` is the starting point. Answer latency is in "Answer latency" below.

## Direction: the host owns the data (decided 2026-10-13)

The full plan, with the research behind it, is `docs/2026-10-13-own-data-plan.md`; where it and this file differ, this file wins. The host becomes the owner of contacts, calendars and a full mail archive: data is **imported** once from Apple, Google, Samsung or Microsoft, then created and edited in myContacts and myCalendar, and myMail receives and sends.

**The owner's decisions:**
- **Phones: both an iPhone (iCloud) and an Android (Samsung).** The end state is the host **serving CardDAV/CalDAV** (our own minimal server on its own loopback port, per-device passwords; Radicale and Xandikos only as test references), reached by the iPhone as an "Other" account and by Android through DAVx5, once remote access exists.
- **Until then, nothing is written to iCloud, Google or the Mac.** New items are labelled "On myData only, not on your phone yet". Followed sources stay read-only; an imported account can still be followed, and the imported (owned) copy then shadows the followed one (one result per person in `find_contact`).
- **Imports come from files first** (`.vcf`, `.ics`, mbox: Contacts.app and Calendar.app exports, Google export or Takeout, Samsung `.vcf`), with a preview, a loss report, de-duplication suggestions (never automatic merges) and undo. This Mac stays followed only: its occurrences and note-less cards are not a faithful copy, so it is never imported.
- **Mail: myMail** (not myEmail). Received on a Mac through Mail.app by Apple Events, from a helper nested in myData.app (the spike showed the Automation prompt names the parent app, and Mail reaches every account, including the Microsoft one that Mail's own store does not hold). Mail's store with Full Disk Access is not used: no prompt, the whole disk, and Apple announced on 2 Oct 2026 that it will tighten it. The standby route is IMAP per provider; for the Microsoft account, OAuth with a device code. A mail server on the host for an own domain is not realistic from a home connection.
- **Full mail archive:** nothing is purged; mail gone at the provider is only marked deleted.
- **Pressing Send in myMail counts as approval**, but only once the app-to-host channel is hardened so a token alone cannot send; a ~10 s undo window (a restart inside it returns the message to drafts) and an hourly limit. Sends the assistant proposes always show an approval card.
- **Order:** contacts editing and import, mail receiving, calendar editing and import, mail sending, then CardDAV/CalDAV serving and remote access.
- **Backups:** Time Machine (external disk or NAS) holds the off-machine copy of the host's snapshots; the live `*.sqlite*` files are to be excluded from it.

**Proposed defaults, not yet confirmed by the owner:** deleting in an app is a soft delete with Undo and "Recently deleted" for 30 days (an assistant's or agent's delete still needs approval); events organised by someone else are read-only until invitations exist; alerts on owned events stay hidden until something can ring them; real mode means "a source is on or the host owns data" (built).

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
  - **A held call is bound to the mode, the conversation epoch and the handler** it was held with, all three in its digest. Switching mode or moving the epoch on fails every pending approval (status `failed`, with the reason; approving it then returns it unchanged), and approving checks the binding again, so a send held over demo data never runs in real mode. A switch waits for calls already running (an approved run from its check to its end, and an MCP agent's call, whose real-mode refusal is checked inside the registry), so a call runs wholly in one mode.
  - Approvals and the tool registry's undo log are in memory. The undo of an app's write is persisted (`undo_log` in `contacts.sqlite`, `POST /undo/{id}`; see "Editing contacts").
- **Tokens.**
  - **App tokens:** one per app (`app-tokens/<app>` in the host's folder, file mode 0600). Each app's token has scopes (`APP_SCOPES` in `service/auth.py`), and every route declares the one it needs (`dependencies=needs(...)` in `api.py`). The host refuses to start with a route that declares none, `openapi.json` lists each operation's `x-mydata-scopes`, and `tests/test_scopes.py` checks every route for every app.

    | App | Scopes |
    |---|---|
    | myData | status, admin, approve, contacts:read, contacts:write, calendar:read, sources:read, sources:manage, shutdown, mcp; calendar:write (reserved, no route uses it yet) |
    | myAssistant | status, assistant, approve, contacts:read, calendar:read |
    | myContacts | status, contacts:read, contacts:write, sources:read |
    | myCalendar | status, calendar:read, sources:read |
    | `mydata` command | every scope |

    Only the apps with `approve` can list, read or decide held calls; each approval records which app decided. Only `shutdown` (myData, the command) stops the host.
  - **Agent tokens:** created and revoked with `mydata agent ...` or in the myData app, with only their hash stored. They reach `/mcp` only and have no scopes.
  - **Known limit: the app tokens protect against other users, not other programs.** Any process running as the same user can read `app-tokens/*` and use the API with them, so it can read every contact and event without ever getting its own Contacts or Calendars prompt from macOS. This is true today. It must be hardened before the host sends mail (plan 2(f).4: app to host over a Unix socket with the peer's code signature checked, a Secure Enclave key per send, or Keychain access lists).
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
- **Owned data is kept by the database itself** (`sources/owned.py`). Every address book and calendar is `followed` (a copy of a source) or `owned` (the host holds the only copy; the contacts writer makes one, see "Editing contacts"). Triggers abort deleting an owned collection or a row in one, foreign-key cascades and `INSERT OR REPLACE` included, unless a purge permit names it; only `purge()` writes one, in the same transaction, and only three callers may use it: the trash expiry, a delete for good from Recently deleted (`purge_now`, at the etag the user saw there, logged with the app that asked) and the future Forget. The mirror's hard deletes only touch the followed collections of the account concerned, and leftovers are purged only for accounts recorded in `accounts-removed.json`. Migrations are additive (`ADD COLUMN`, new tables, triggers); the runner rolls back one that drops a trigger.
- **A new schema version ships with a synthetic dump** (`host/tests/fixtures/schema`, `make_dump.py`); the tests migrate every released dump and compare every field. Before a new migration reaches the real files, `mydata db check-migration` runs it on copies of them.
- **Restore drill:** `mydata backup verify` restores a snapshot into a temporary folder, migrates and checks it, and records the result, which `/status` reports with the last snapshot and FileVault. It runs in the test suite on synthetic data; there is no CI. `mydata backup restore` needs the host stopped; a live database too damaged to copy is kept byte for byte in the pre-restore snapshot's `damaged/` folder. `mydata export --out DIR` writes every card in vCard 3.0 (`--vcard 4.0` for 4.0) and one `.ics` per calendar with a generated VTIMEZONE for each zone used, outside the checkout; every calendar file is read back and compared before anything is written. `--raw` writes the stored text as it is.
- **Develop on a separate host folder.** A branch with a new migration, run against the default folder, migrates the real data (after a snapshot), and an older checkout then refuses the newer file. Run a development host with its own `MYDATA_HOME` (outside the checkout) and port: `MYDATA_HOME=~/mydata-dev uv run mydata dev-setup` creates `~/mydata-dev/config.toml` (and lets the apps start that host); set its `[server] port` to something other than 47821 before `MYDATA_HOME=~/mydata-dev uv run mydata run`. Point the apps at it with `flutter run --dart-define=MYDATA_HOME=$HOME/mydata-dev`. Tests always use temporary folders.

### Writing contacts and events

The vCard editor is used by the contact routes (phase 3, below); the ICS writer is library code until phase 6 (calendars).

- **vCards** (`sources/vcard_edit.py`): a content-line editor, never vobject. Lines an edit does not touch are written back byte for byte (folding, case, line endings); changed lines are folded at 75 octets; REV is set when anything changed. Names, groups and parameters given to an edit are checked (letters, digits and `-`; no control characters), and quotes, carets and line breaks in a parameter value are written as RFC 6868 says. A new value drops the old one's ENCODING and CHARSET. A new labelled value takes the next Apple `itemN` above the highest present, and removing it removes its X-ABLabel and X-ABADR. New cards are 3.0 with a UID. A 2.1 card (Samsung) is read, quoted-printable soft breaks joined, but never edited in place: `upgrade_21()` turns it into 3.0 for an import, which keeps the original. 4.0 is edited as it is (KIND, MEMBER kept); `convert()` moves a card between 3.0 and 4.0 changing only the lines that differ.
- **Events** (`sources/ical_edit.py`): edits go through icalendar with `sorted=False`, then every property the edit did not change is put back as the input wrote it (icalendar re-escapes what it re-serialises: REQUEST-STATUS, INTEGER values, Outlook TZIDs). The written text is read back and compared, per component, with the input's own lines (counted without icalendar) and with the edited object: a property, value (EXDATE, RDATE, CATEGORIES) or parameter that went down, or an unchanged property that reads differently, refuses the write (`PropertyLossError`); a split is also checked as the two resources together. The writer reads a series as the store's reader does (an UNTIL of another kind, a date EXDATE on a timed series). A change of time of day moves exceptions and UNTIL on the series' own clock, so a UTC value keeps its occurrence across a clock change; a new start in UTC or without a zone stays in the event's zone (only a named zone moves it). The writer stores TZIDs only, as the event's DTSTART writes them (an Outlook name stays); the export adds the VTIMEZONEs. Repeating events: this event (an override), delete this event (an EXDATE like DTSTART), all events (exceptions move with a change of time of day; a change that leaves exceptions off the series is refused unless they are dropped), this and following (a split: COUNT recounted or UNTIL, in UTC for zoned times; a new UID with `X-MYDATA-SPLIT-FROM`; never `RANGE=THISANDFUTURE`). Lengths are exact (RFC 5545), so an occurrence at 02:30 on the day clocks go forward in Auckland is 02:30 NZST (14:30 UTC) and ends 30 minutes later.
- **Tests** use synthetic corpora (`tests/fixtures/vcard`, `tests/fixtures/ics`: Apple, Google, Samsung 2.1, 4.0 groups, Outlook zones) and Hypothesis round trips (a dev dependency).

### Editing contacts

Phase 3: the host (`sources/contacts_write.py`, `sources/contact_form.py`, routes in `service/api.py`) and myContacts (`app/apps/mycontacts`).

- **Only owned cards are written.** The first one creates the owned address book "myData" (account `local`, one per host for now), which switches the host to real mode and ends conversations as turning a source on does. A followed card is refused (409).
- **Routes** (`contacts:write`: myData, myContacts, the command): `POST /contacts`, `PATCH /contacts/{id}` and `DELETE /contacts/{id}` (If-Match with the etag required: 428 without, 412 with the current etag when stale), `GET /trash?kind=contact` (`contacts:read`; each item has `backups_kept_until` and its contact's etag), `POST /trash/{id}/restore` (If-Match optional), `DELETE /trash/{id}` (delete for good now, with its revisions; If-Match with the item's etag required; 404 unless it is in Recently deleted), `POST /undo/{id}`. The body is the form's fields (names, nickname, company, department, job title, phones, emails, urls, addresses, birthday with or without a year, note); a field left out is kept, null clears it (the generated client sends every field, so it sends the whole form). Errors come per field (400, `fields`), never echoing values; an edit checks only the values that differ from the card, so a value the card already holds (an imported `BDAY:March 18`) never blocks it. Contacts carry `etag`, `editable` and `on_phone` (false for owned: "On myData only, not on your phone yet").
- **Writes:** one transaction each, with a `revisions` row (actor = the app), a `changes` row and an `undo_log` row. An edit changes only the lines whose values differ; the rest of the card stays byte for byte. `rev` and the etag move on with every write, a delete or restore included.
- **Undo** writes a new revision forward and only when the card is still at the revision the action wrote; each action is undone at most once, across restarts. A card whose text changed without a revision (another owned-row writer, such as a later import) gets one before the next write, so an undo never goes back past that change; an undo whose earlier text is not fully recorded is refused. Undoing a create moves the card to Recently deleted.
- **Recently deleted:** a delete is soft (`purge_after` = 30 days). The host purges what is due daily (`service/trash.py`) through purge permits, with the card's revisions. Snapshots keep copies until they expire.
- **myContacts:** "New contact" (beside the search field, ⌘N; in a phone's large title) and Edit (beside the header, ⌘E, Return on the open row, the row's Menu) open the Inspector in the contact pane's place (the editor sheet on a phone): Name (first, last, company, job title), Phone, Email, Address, Birthday (year optional), Links, Notes. Fields not in the form (middle name, prefix, suffix, nickname, department) are sent back as loaded. Save sends the whole form with If-Match; a 412 keeps the changes and offers Reload (the host's version, dropping them), never overwriting. Field errors show on their fields in the app's words. One delete goes at once with an Undo toast; several (⌘-click, ⇧-click, ⌘A; the count in the pane) ask first in a Dialog; followed contacts are counted out with the reason. Undo is the toast's, ⌘Z and Edit, Undo named from the action ("Undo Delete Contact"), or "More actions" on a phone; Redo stays disabled. Recently deleted is the app's second section: restore (with Undo), or delete for good after a Dialog naming until when the host's backups keep a copy. Owned contacts say "On myData only, not on your phone yet."; followed ones keep "Change it in Contacts" and have no Edit or Delete.
- **Not done:** a delete for good from an app runs after the app's Dialog, not through the approval gate as the plan's 3.3 table says ("Empty trash, Forget, expunge, bulk delete: confirmation dialog, through the gate"); the owner decides; revisions keep the whole card (the plan's "raw without PHOTO when the photo did not change" is not built); revisions are not pruned after 90 days; no unique index on (address book, UID); groups are not edited (membership is by UID, which no edit changes); the shadowing of followed duplicates by imported copies is phase 4. In myContacts: no groups or photo picker, no select mode on a phone, no "Empty Recently deleted"; the undo names live for the app's session (the host has no route that lists its undo log); owned contacts changed by another app show only when the list is read again (a source changes, or this app writes); not yet run against a live host.

### Contacts and calendars sources

Read-only mirrors in `contacts.sqlite` and `calendar.sqlite` (`host/src/mydata/sources/`). The user turns each source on or off in the myData app (Settings, Sources); turning one off deletes what it mirrored from the mirror. **Copies stay in the host's snapshots until they expire:** by the first day of the same month next year (`backup.kept_until`), while the host keeps running. The CLI and the API docs say so; the myData app's turn-off and remove dialogs do not yet.

- **Group cards** (iCloud's `X-ADDRESSBOOKSERVER-KIND:group`, vCard 4's `KIND:group`) are stored with `kind = 'group'` and never listed, counted, searched or found by `find_contact`; the export keeps them in a separate file.
- **Followed sources stay read-only.** No source ever writes back: the iCloud client sends only PROPFIND, REPORT, OPTIONS and GET, and the Mac helper has no write calls. Writing back to a provider is not planned; owned data reaches other devices through the host's own CardDAV/CalDAV server (see "Direction").
- **Nothing goes around these two paths.** Static scans of the host's sources: no HTTP client outside `DavClient.request` and a localhost allow-list; no `smtplib`, `imaplib`, `poplib` or `ssl` outside one mail module (none yet: `MAIL_ALLOWED` is empty) (`test_dav_no_other_http.py`); only an allow-list of modules, each with its reason and the programs it may start (never through a shell), may start a program, nothing may load native code (`ctypes`, `cffi`, PyObjC and Apple's frameworks) or use `posix` or `webbrowser`, and no source mentions `osascript` or AppleScript (`test_no_way_around_the_helper.py`). The scans see through import aliases, `import *` and `getattr`; they catch accidental use, not code written to hide a call.
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

The host is in **demo mode** while no source is on and it holds no owned data, and in **real mode** as soon as a source is on or an owned address book or calendar exists (`mode` in `/status`), even an empty one (purging its last contact leaves the address book, so the host stays real; whether it should go back to demo is the owner's call). Turning the first source on or the last one off switches it; code that creates or purges owned data must call `ModeController.refresh()` the same way.

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
  apps/mycontacts            the myContacts app (edits the host's own contacts; followed ones read-only)
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
6. **The host owns the data** (`docs/2026-10-13-own-data-plan.md`, section 4):
   - ~~0a safety net~~: done (snapshots, restore drill, safe migrations, export).
   - ~~0b additive schema~~: done (owned and followed collections, revisions, changes, origins, triggers that keep owned rows, group cards fixed).
   - ~~0c tokens and approvals~~: done (scopes per app, approvals bound to mode and epoch, real-mode logs keep shapes only, wider scans).
   - ~~1 writers and export~~: done (the lossless vCard and ICS writers, `.vcf`/`.ics` export).
   - **Next: 2**, the form components (dialog, inspector, menu, select, text area, checkbox, toast with undo, icon button, multi-select): specs and previews in `design/` for the owner first.
   - 3 contacts editing: done (see "Editing contacts"), except groups and the photo picker in myContacts. 4 contact import; 5 mail receiving (myMail, read-only); 6 calendar editing and import; 7 mail sending; 8 assistant write tools (new frozen request set first); 9 CardDAV/CalDAV serving; 10 remote access; 11 API imports and IMAP (Advanced).
7. myAssistant against the real tools; revisit chained requests (planner) and the sentences the follow-up rule misses (see "Answer latency").
   - **Real-mode tool descriptions:** in real mode `find_contact` and `list_events` still use the descriptions measured on the demo set, which mention mail. New descriptions need a new frozen request set and a measurement before they replace them.
   - **Outside agents and real data:** MCP agents are blocked from real data (in real mode they get no tools). Later: a per-agent permission, granted in the myData app, off by default, with a warning that the data may leave this machine.
8. myPhotos (import, CLIP index, faces). The largest piece; expect 6 to 8 weekends.
9. Phone clients (remote access itself is phase 10 of item 6).
10. Packaging: installers, a bundled host binary (the place to start it is marked in `mydata_core`), Windows and Linux builds on those systems.

## Open questions

- Licence: MIT or AGPL.
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
- **The calendar reader takes one zone per custom TZID.** icalendar keeps the first VTIMEZONE it reads for a TZID it does not know (Outlook's "Customized Time Zone") for the whole process, so a later resource with the same TZID and other rules is read with the first one's offsets (found 2026-10-14; the export renames such zones, the store does not yet).
- **The calendar reader gives the occurrence in the skipped hour no length.** recurring-ical-events adds an event's length on the wall clock, so on the day clocks go forward an occurrence at 02:30 ends before it starts, and `ical.occurrences` clamps it to zero length. The writer uses the exact length (RFC 5545); the reader is not fixed yet.
- Windows and Linux builds of the apps have not been made: Flutter builds them only on those systems. Their code paths compile (`flutter analyze`).
- **myContacts' keys on Windows and Linux** (Ctrl+N, Ctrl+E, Ctrl+S, Ctrl+Z) reach the menu bar's handler only while focus is inside the window's content; right after launch, with nothing focused, they do nothing until something is clicked. macOS's menu bar owns its keys and is not affected. ⌘E for Edit Contact is still unverified against Apple's Contacts.
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