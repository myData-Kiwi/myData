# Status, direction, assets, build order, open questions and rough edges as of 14 October

Moved verbatim from CLAUDE.md on 2026-10-23, when it was cut to the current rules. This is history: where it differs from CLAUDE.md or `docs/2026-10-23-plan.md`, CLAUDE.md wins.

## Status

Early build. Done:
- the marketing site;
- two rounds of feasibility testing (see "Feasibility test result" and "Round 2 result");
- **the host** (phase 1): `mydatad` with the tool layer and permission gate, HTTP API, MCP, app and agent tokens;
- **the first two apps** (phase 2): myData (setup, status, settings) and myAssistant (chat), in Flutter, macOS first;
- **answer latency** (Part A): results on screen in about 3.5 s instead of 13;
- **the design system** (Part B): `design/` in Flutter (`mydata_ui`), six themes in light and dark, the theme stored on the host and followed by every app;
- **real contacts and calendars on the host** (phase 3): a read-only mirror from **This Mac** (macOS Contacts and EventKit, the main path on a Mac host) or from a followed iCloud account (CardDAV, CalDAV; under Advanced, for hosts that are not Macs). See "Contacts and calendars sources";
- **the myContacts and myCalendar apps** (phase 4): views of the mirror (read-only at first; myContacts now edits the host's own contacts, below), with links between the apps (`mycontacts://contact/<id>`, `mycalendar://day/<date>`, `mydata://settings/sources`). myAssistant opens a real contact or event result in them when they are installed, and myData's Status lists the apps with their counts and sources;
- **the safety net** (phase 0a of the owned-data plan): migrations with foreign keys off, snapshots (hourly and before every migration), the restore drill, restore and a raw export. See "Data safety";
- **the additive schema** (phase 0b): owned and followed collections, owned data kept by the database itself, hard deletes limited to followed data, group cards no longer shown as contacts. See "Data safety";
- **tokens, approvals and logging** (phase 0c): scopes per app token, approvals bound to mode and epoch, argument shapes only in the real-mode request log, and scans for mail libraries, `osascript` and `subprocess`. See "Tokens" and "Demo and real mode";
- **writers and export** (phase 1): a vCard line editor and an ICS writer with a property guard and the four edits of a repeating event, as library code with tests, and a clean export. See "Writing contacts and events";
- **the form components** (phase 2, spec first): specs and previews in `design/` (Dialog, Inspector, Sheet, Toast, Menu, IconButton, MultiSelect, Checkbox, FormRow, Select, TokenField, DatePicker, TimePicker, ColourPicker, the macOS menu bar), their tokens, and the widgets in `mydata_ui` with goldens. See "Client stack";
- **contacts editing** (phase 3, host and myContacts): an owned "myData" address book, create, edit (If-Match), delete to Recently deleted, restore, delete for good, persisted undo and the daily trash expiry, through the API; myContacts creates, edits and deletes the host's own contacts (Inspector, Undo toasts, several at once, Recently deleted), followed ones stay read-only. Groups and the photo picker are not built. See "Editing contacts";
- **contact import, host side** (phase 4, done): `.vcf` and `.zip` files and a copy of a followed iCloud account, with a preview, a loss report, matches (never merged automatically), import again without duplicates, undo, the shadowing of followed copies, and merge with undo, through the API; reviewed and fixed (17 findings). The import specs in `design/` (ImportFlow, DropZone, DuplicatePair) are decided (2026-10-14), and the host gaps they list are built: a file hides the followed copies of the people it brings in (H1), a no-notes loss (H2), a preview card's values (H3), refusal codes (H4), the `contacts:import` scope (H5), possible duplicates, "not the same person", the merge preview and `merged_into` (H6a to H6d), reviewing a followed copy's changes (H7) and the backups day for removing a source (H8). See "Importing contacts";
- **contact import, app side** (phase 4, done): myData's Import section (Choose with the drop zone and the file chooser, Review with the loss report, ticks and Compare, Importing, Done with "Keep following", the history and Undo import; `mydata://import/contacts`, File > Import…), and in myContacts Merge from a multi-selection with the host's merge preview, a Review section (possible duplicates, changes since import) and the contact page's "changed since import" Notice. The apps are tested against fake hosts; the host was run live on synthetic data (2026-10-14). See "Importing contacts", "The import UI".

**New direction (2026-10-13): the host owns the data.** See "Direction: the host owns the data". Today sources are still only followed (read-only); myContacts creates and edits the contacts the host owns; the safety work that must come first (snapshots, safe migrations, owned-data protection, token scopes, the lossless writers) is done. The two modes are described in "Demo and real mode". **Next:** phase 5, mail receiving (myMail, read-only), which needs the owner present for the Automation prompt; see "Build order". Chained requests are an open problem, not a blocker: the planner write-up in `host/results/2026-10-11-b-REPORT.md` is the starting point. Answer latency is in "Answer latency" below.

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

**Proposed defaults, not yet confirmed by the owner:** deleting in an app is a soft delete with Undo and "Recently deleted" for 30 days (built for contacts; an assistant's or agent's delete still needs approval); events organised by someone else are read-only until invitations exist; alerts on owned events stay hidden until something can ring them.

**Decided 2026-10-14:** real mode means "a source is on or the host owns data", and the host stays in real mode after the last owned contact is deleted for good (the empty owned address book is still owned data); a delete for good from Recently deleted is guarded by the app's Dialog alone, with no approval card (an assistant's or agent's delete still goes through the gate). The decisions on the import specs are in `design/components/ImportFlow` and `DuplicatePair` ("Decisions").

## Existing assets

- Domain: mydata.kiwi. DNS is in Cloudflare, records set to DNS only (proxy off, on purpose).
- GitHub org: `mydata-kiwi`.
- Website repo: `mydata-kiwi/mydata-kiwi.github.io`. One `index.html`, deployed by GitHub Pages from `main`. Custom domain mydata.kiwi is verified and served over HTTPS from GitHub Pages.
- Logo: hand-drawn outlined kiwi bird with a green wash. Colours: background `#E3EFBF`, wash `#A9CC4E`, ink `#2A2018`.
- **Design system: `design/` is the source of truth** for how the apps look: `tokens.json` (the Kiwi theme's values), `themes.json` (six themes: Kiwi, Graphite, Dusk, Plum, Rose, Amber), the README, `theming.md`, `motion.md`, `platforms.md` and a spec with an HTML preview per component. Light and dark mode. The Flutter implementation is `app/packages/mydata_ui` (tokens generated from the JSON; see its README for the decisions taken where `design/` disagreed with itself). The website keeps its own styling and is not changed by `design/`.
- A fuller plan document exists ("myData: architecture, technical plan, and viability check"). This file supersedes it where they differ.

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
   - ~~2 form components~~: done (specs and previews in `design/`, tokens, the widgets in `mydata_ui` with goldens, the macOS menu bar).
   - ~~3 contacts editing~~: done (see "Editing contacts"), except groups and the photo picker in myContacts.
   - ~~4 contact import~~: done (see "Importing contacts" and "The import UI"): the host side and its gaps (H1 to H8), the UI in myData and myContacts, and a live run of the host on synthetic data.
   - **Next: 5 mail receiving** (myMail, read-only). It needs the owner present: the Automation prompt (myData asking to control Mail) is answered by hand. Then remove the mail spike app (`~/Applications/myDataMailSpikeHost.app`, which holds Full Disk Access and Automation grants) and ask the owner to switch both grants off in System Settings.
   - Then 6 calendar editing and import; 7 mail sending; 8 assistant write tools (new frozen request set first); 9 CardDAV/CalDAV serving; 10 remote access; 11 API imports and IMAP (Advanced).
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
- The links between the apps, myAssistant's results opening in myContacts and myCalendar, and the Status rows' "Open" are tested with fakes only. None has been tried between built apps on a Mac, and myContacts and myCalendar have not been run against a real host (the contacts write and import APIs have, on synthetic data; see "Editing contacts" and "Importing contacts"). myCalendar's time zone channel has not been tried live.
- The phone layouts (floating tab bar, large title) are built and covered by goldens, but have not been run on a phone.
- **The calendar reader takes one zone per custom TZID.** icalendar keeps the first VTIMEZONE it reads for a TZID it does not know (Outlook's "Customized Time Zone") for the whole process, so a later resource with the same TZID and other rules is read with the first one's offsets (found 2026-10-14; the export renames such zones, the store does not yet).
- **The calendar reader gives the occurrence in the skipped hour no length.** recurring-ical-events adds an event's length on the wall clock, so on the day clocks go forward an occurrence at 02:30 ends before it starts, and `ical.occurrences` clamps it to zero length. The writer uses the exact length (RFC 5545); the reader is not fixed yet.
- **One host test is timing-sensitive:** `test_a_reader_that_fails_the_same_way_every_time_backs_off` waits 5 s for a relaunch after a 2.5 s pause; it failed once (2026-10-14) while the Flutter suites ran at the same time, and passes alone. Run the host suite on a quiet machine.
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
