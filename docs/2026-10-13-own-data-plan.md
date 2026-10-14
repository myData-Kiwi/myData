> **Status (2026-10-14):** the owner's decisions are recorded in CLAUDE.md, "Direction: the host owns the data". Spikes S0 (the Automation prompt names the parent app) and S2 (account 2 is Microsoft: Outlook, Exchange or 365) are answered. Phases 0a, 0b, 0c and 1 are built. Where this plan and CLAUDE.md differ, CLAUDE.md wins.

# The plan: myData becomes the owner of contacts, calendars and mail

This plan comes from eight research reports written tonight (codebase, data model, DAV, import, mail, sync, safety and UX), revised after a hostile review. Claims the reports could not confirm are marked **unverified**. No repo files were changed. I checked the reviewer's code claims myself: `registry.py` (the `Approval` dataclass, `replace_tools`, and `decide` looking up by name), `sync.py` (`_purge_orphans`), `auth.py` (`READ_ONLY_APPS` limits only non-GET requests), the missing `.github/`, and the sibling `myEmail/` folder.

---

## 1. What changes, and the biggest risks

**What changes.** Today the host keeps read-only copies of data that lives at Apple or iCloud. From now on the host holds the master copy of contacts and calendars, and keeps a full local archive of mail.

- **Import:** data comes in from Apple, Google, Samsung and Microsoft.
- **Editing:** myContacts and myCalendar create, edit and delete.
- **Mail:** myMail receives and sends. Delivery stays with the existing providers (iCloud and account 2), because the host cannot deliver mail for those addresses.

Most of today's code assumes the opposite: that data upstream is the truth and anything local can be thrown away. So the first job is making the host safe to hold data, before any feature is built.

### Biggest risks, worst first

| # | Risk | Why it is real today |
|---|---|---|
| 1 | **Silent data loss on the host** | - `SyncService._purge_orphans()` (`service/sync.py:299`) hard-deletes every `account_id` that is not in `accounts.json` and is not `"mac"`. It runs on every account change, so any owned id would be wiped. It is a deny-list, so every new store or path is a new chance to get it wrong.<br>- Turning a source off, revoking access, narrowing the selection and `replace_occurrences` all hard-delete.<br>- **Confirmed with a scratch test:** the migration runner (`sources/_db.py`) runs migrations with `foreign_keys=ON` inside `BEGIN IMMEDIATE`. A table rebuild therefore cascades: 0 cards remained after rebuilding `address_books`. Turning foreign keys off inside the transaction does nothing.<br>- **A development build migrates the real data.** Stores migrate inside `Database.__init__`. A branch with an unreleased migration, run as the normal host, rewrites the real `contacts.sqlite`. An older checkout then refuses to start ("schema version … is newer"). The owner is also the developer, and there is no CI.<br>- **There is no backup of any kind.** |
| 2 | **Sending mail by mistake, or because a mail told it to** | - **A demo-mode `send_mail` approval would send real mail.** `replace_tools()` deliberately keeps pending approvals across a mode switch. `decide()` looks the tool up by name (`registry.py:305`), and `Approval` records no mode, epoch or handler. This is safe today only because real mode has no `send_mail`.<br>- One Automation grant to Mail covers send, delete and move. There is no read-only grant. Moving a message to Trash uses the same `delete`/`move` verbs that delete mailboxes.<br>- Approvals and the undo log live in memory. There is no "sending" or "unknown" state, so a crash at the wrong moment and a retry would send twice.<br>- Grounding counts mail bodies as trusted text, so an address found only in a mail grounds `send_mail.to`. |
| 3 | **The host lends its macOS privacy grants to any local process. This is true today.** | - Any process running as the user can read `app-tokens/*` (0600, same user). With a token it reads every contact and event through the localhost API, without ever getting its own Contacts or Calendars prompt.<br>- `GET /approvals` is open to the read-only tokens.<br>- Once writes exist, such a process can delete everything. If "Send in myMail counts as approval", the myMail token alone could create a send and approve it in two requests. myData would then be a confused deputy for its Mail Automation grant. |
| 4 | **Lossy import that becomes permanent** | - This Mac provides only expanded occurrences, 1 year back to 2 years ahead, with no RRULE, EXDATE, alarms or attendees. A weekly meeting would become about 156 one-off events that stop in 2028.<br>- Contacts come without notes (they need an entitlement), related names, other dates, social or IM fields, and so on.<br>- As a mirror that is fine. As the start of an owned database it is corruption, and it becomes permanent the day the owner deletes the originals.<br>- **On the Mail.app route, "the provider deleted it" looks the same as "Mail stopped showing it"** (local windows, `.partial.emlx`, ids that change when Mail rebuilds its index). A purge rule would then destroy archived mail. |
| 5 | **Drifting away from the phone, and alerts that never ring** | - The host listens on localhost only, and phone access is build step 9. Anything created in myCalendar or myContacts never reaches the phone. Anything created on the phone never reaches the host unless that account is still followed.<br>- **Alerts on owned events ring nowhere, not even on the Mac.** Nothing delivers them.<br>- **Importing an account while still following it** creates two rows for every person. `find_contact` would then answer "several matches" for nearly everyone. |
| 6 | **Provider policy and scope** | - Gmail over IMAP needs the restricted scope `https://mail.google.com/`, which requires CASA for a shared client ([Google](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)).<br>- iCloud has no OAuth for third parties, so an app-specific password is the only option off the Mac. **That includes the future Linux or NAS host.**<br>- Apple announced on 2 Oct 2026 that Full Disk Access will need "very explicit user action", because "AI agents become increasingly capable and autonomous" ([MacRumors](https://macrumors.com/2026/10/02/apple-announces-macos-full-disk-access-changes)). Automation is not mentioned, but myData is exactly that kind of agent (unverified whether Automation is affected).<br>- **Microsoft:** since June 2024 every app must be registered in a directory ([MS Learn](https://learn.microsoft.com/en-us/entra/identity-platform/reference-breaking-changes)), so a shipped public client id means a maintainer-owned multi-tenant registration. Whether an individual can pass publisher verification is unverified.<br>- **Scope:** about 30 new UI components, recurring-event editing (XL), myMail (XXL) and a DAV server (3–5 weekends, unverified estimate). |

---

## 2. Decisions only you can make

### (0) Which phone do you use every day? Decide this first

Most of what follows depends on the answer.

- **iPhone on iCloud.** A4 (the host serves DAV) reaches the phone as an "Other" account. A3 (push to iCloud) is possible as a fallback.
- **Samsung or another Android phone.** A3 is worthless. DAVx5 is the A4 client. Samsung Calendar has no `.ics` export (unverified), so on the phone, moving the data to Google first becomes the main Samsung import path. A future "This Phone" Android client would be the lossless route.
- **Both.** A4 is the only option that serves both.

Every recommendation below assumes an **iPhone on iCloud** until you answer.

### (a) After import: how myData relates to iCloud, Google and the phone

| Option | Phone keeps working? | Cost and risk | Verdict |
|---|---|---|---|
| **A1. Import once, then myData is the only copy** | **No.** Changes never reach the phone, and alerts ring nowhere. | Smallest. Easy to lose events in daily life. | Not on its own |
| **A2. Own the data, and keep following the providers read-only beside it** | Partly. Provider data stays live; anything new made in myData is not on the phone. | Data lives in two places. Needs the shadowing rule below. | **Interim state** |
| **A3. Own the data, and push to one account (iCloud through a new This Mac *writer* helper)** | Yes, through iCloud (iPhone only). | - Reverses the read-only guarantee; a new Writer protocol needs its own tests.<br>- `CNSaveRequest` is "last change wins" ([Apple](https://developer.apple.com/documentation/contacts/cnsaverequest)); EventKit has no precondition check either.<br>- A delete pushed to iCloud has no real undo. iCloud's restore replaces the whole set ([Apple 102508](https://support.apple.com/102508)).<br>- Upload failures inside Apple's daemons are invisible to myData. | Fallback only |
| **A4. Own the data, and the host serves CardDAV/CalDAV** | Yes, once the phone can reach the host: iOS adds an "Other" account, Android uses DAVx5. | - About 2–3k lines of our own code (unverified).<br>- Needs TLS. macOS clients probably refuse plain http ([Nextcloud](https://docs.nextcloud.com/server/latest/user_manual/en/groupware/sync_osx.html), [Radicale](https://radicale.org/v3.html); unverified on macOS 26).<br>- Needs a remote-access route for the phone (its own decision record). | **End state** |
| A5. Two-way sync with every account | Yes | The source of every vdirsyncer and DAVx5 conflict story. Needs an iCloud app password and Google sensitive scopes. | No |

**Recommendation: A2 now, A4 as the target.** It fits your words ("import initially, then manage our own database") and keeps the read-only guarantees. By default A4 comes after mail sending (see section 4); if phone sync matters more to you than sending mail, you can move it earlier.

**The rule for A2 together with import (decided before the import phase):**

- When you import from account X, the app offers to stop following X.
- If you keep following it, **owned records shadow the followed records** they were imported from, linked through `origins` by UID plus source (never by followed `id`, which changes when This Mac is turned off and on).
  - The shadowed followed copy is hidden from lists and from `find_contact`.
  - When the followed copy changes after the import, it is flagged: "changed on your iPhone since import, review".
  - A test asserts that `find_contact` returns **one** match for a person who was imported and is still followed.
- Build A3 only if living with the gap until A4 proves unacceptable. If you do, it only creates and edits, holds every delete for approval, uses a mass-delete guard, and writes to one chosen container and calendar.
- **Until A4 exists, the apps say plainly that new items are "On myData only, not on your phone yet".**

### (b) How mail is sent and received

| Option | Receive | Send | Password? | Verdict |
|---|---|---|---|---|
| **B1. Mail.app through Apple Events** (Mac host only) | **Measured tonight:** about 2 ms per call; bulk headers for a mailbox of a few thousand messages in about 1.3 s; full source median 16 ms. Sees every account set up in Mail. **But** account 2 may be only Mail's recent local window (three mailboxes hold exactly 50 messages), about a third of the iCloud messages are `.partial.emlx`, and Mail's ids change when it rebuilds its index. | - Plain text only: `html content` "Does nothing at all (deprecated)" (local `mail.sdef`).<br>- Our own Message-ID and custom headers cannot be set.<br>- Known bug where a scripted body arrives quoted with `>` ([Apple forum 738842](https://developer.apple.com/forums/thread/738842)).<br>- A `sender` that matches no account falls back to the first account.<br>- **No sending has been tested on macOS 26.** | None, one Automation prompt. **Still unconfirmed:** whether the prompt named myData or the spike helper. | **Main receive path once spike S2 passes and the prompt names myData. Main send path only if S1 passes.** |
| **B2. IMAP/SMTP per provider** | Full server history | Full control: our own Message-ID, HTML, a copy saved to Sent | - **Microsoft:** OAuth device code with a public client id in the source ([MS Learn](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)), no secret, but a maintainer-owned directory registration (see risk 6).<br>- **Gmail:** your own Cloud project (see (e)), or an app password (secondary sources only, [Nylas](https://cli.nylas.com/guides/gmail-app-password-setup.md)).<br>- **iCloud:** app-specific password only. | **Keep one route working from the day receiving ships**, whichever matches account 2, in case a macOS privacy change cuts off B1. It is also the send fallback and the only route on a non-Mac host. |
| **B3. History import (mbox)** | Takeout mbox, Mail.app "Export Mailbox" | — | None | Yes, for the archive |
| **B4. A mail server on the host for your own domain** | Needs port 25 reachable around the clock on a fanless laptop that sleeps | Residential IPs are on the Spamhaus PBL ([Spamhaus](https://www.spamhaus.org/faq/section/Spamhaus-PBL)); you rarely control PTR records; Gmail requires SPF/DKIM, PTR and TLS ([Google](https://support.google.com/a/answer/81126)) | — | **Not realistic from a home connection.** The only workable shape is Cloudflare Email Routing to a Worker for receiving (free; Cloudflare sees every message) plus a third-party relay for sending (Cloudflare's own is paid, which breaks the non-commercial rule). Possibly later as an optional source, never as a server on the host. |

**Recommendation:**

- **B1 for receiving**, after S2. B1 for sending only if S1 passes.
- **B2 for whichever provider account 2 turns out to be**, ready soon after receiving ships. Microsoft goes first **only if S2 shows account 2 is Outlook or Exchange**.
- **B3 for history.**

"Our own database of mail" then means a complete local archive with an outbox, while the providers still deliver it.

**Related decisions:**

1. **Writing back to the provider.** Should mark read, flag and move to Trash be written back, as reversible writes with undo? I recommend **yes**; otherwise the phone shows mail as unread forever. On B1, Trash is a typed `trashMessage(account, messageId)` command, never the generic `delete` (see 3.7). Permanent delete stays an action that needs approval.
2. **Pressing Send in myMail counts as approving that exact held call.** I recommend **yes, but only once the send channel is hardened** (see 2(f).4). A token alone must not be able to approve a send. Limits:
   - only for sends myMail itself created from a draft;
   - an undo-send window of about 10 s, held on the host. **A restart inside the window returns the message to draft, never sends it.** On B1, once the message has been handed to Mail's Outbox there is no undo, and a host crash after that point still sends;
   - a cap on sends per hour.

   Sends started by the assistant or an agent always get an approval card.
3. **When a message disappears:**
   - **On B1, absence never means deletion.** A message is marked deleted only when it is seen in Trash. If more than 5% of a mailbox vanishes at once, sync pauses and asks you.
   - **On IMAP routes,** a deletion the provider confirms is soft-deleted on the host.
   - Default: **full archive, nothing purged.** Optionally, purge after 30 days, on IMAP routes only.
4. **Name: myMail or myEmail.** `../myEmail/` already exists (a README only). Pick one before `APPS` gains the token name, because token file names are persistent state.

### (c) Which import sources come first

| Order | Source | Faithful to the original? | Needs |
|---|---|---|---|
| 1 | **Files:** `.vcf` and `.ics` from Contacts.app (File → Export vCard, with "Export notes" and "Export photos" on, [Apple](https://support.apple.com/guide/contacts/adrbk1512/mac)) and Calendar.app (File → Export, once per calendar, [Apple](https://support.apple.com/guide/calendar/icl1023/mac)) | Yes. Covers every account on the Mac, notes included. | Nothing. A few minutes of exporting by you. |
| 2 | **Files from Google:** calendar.google.com Export (a zip of `.ics`) and contacts.google.com Export (vCard), or Takeout | Calendar yes; contacts mostly | Nothing |
| 3 | **Samsung contacts `.vcf`** | vCard 2.1, no groups ([Samsung community](https://eu.community.samsung.com/t5/other-galaxy-s-series/contacts-export-as-vcf/td-p/12042579), unverified on a current Galaxy). vobject fails on quoted-printable soft breaks (tested), so we need a pre-pass. Better: move the contacts to Google on the phone first. | A phone and a cable, or email |
| 4 | **iCloud CardDAV/CalDAV** (already built, Advanced) | Yes: `raw_vcard` and `raw_ics` are already stored | App-specific password (Advanced only) |
| Later | Google People and Calendar APIs, Microsoft Graph (device code) | Calendar yes; contacts are JSON with a lossy mapping | OAuth (see (e)) |

**This Mac stays followed only and is never imported.** The partial "quick import" is dropped: once the originals are deleted, it is exactly the permanent loss described in risk 4. The app points you to Contacts.app → Export vCard with "Export notes" on instead.

**Recommendation:** start with file import (1–3) as the main path. It is faithful, needs no credentials and works for every provider. Never import Birthdays, subscribed calendars or calendars shared by others; those stay followed.

### (d) Whether, when and how the host serves CardDAV/CalDAV

| Option | Verdict |
|---|---|
| Embed Radicale (GPL-3.0, file store) | No. It settles the licence question for us, means a second store, and Apple's clients are not on its tested list. Use it as a **spike and test reference** only. |
| Embed Xandikos (GPL-3.0+, Beta) | No, for the same reasons. Use it as a second test reference. |
| **Our own minimal server** on a separate loopback port with per-device passwords | **Yes.** |
| Never | Then owned data never reaches the phone or the Mac's own Contacts and Calendar. |

**When:**

- **Run the spike now** (S3). One evening, by you, in a throwaway macOS user, with Radicale on 127.0.0.1. It answers four questions:
  - Do Contacts and Calendar sign in over plain http?
  - Does a single trusted self-signed localhost certificate work?
  - Is it still one address book per account?
  - Does dragging contacts between accounts carry the notes over?

  Whether the iOS Simulator can add CalDAV or CardDAV accounts is unverified. The fallback is an "Other" account on your real phone, which needs no second Apple Account.
- **Build it after mail sending** (the default order in section 4), or earlier if you choose phone sync over sending mail.
- **Remote access for the phone is a separate decision record and phase,** not bundled with DAV. Tailscale Serve is the candidate: the personal plan is free, but it is a third-party account and publishes machine names in Certificate Transparency logs.

### (e) Google, given the verification rules

| Option | Contacts and calendar | Gmail | Verdict |
|---|---|---|---|
| **File export and Takeout** | Yes | mbox history | **Main path** |
| **Google account set up on the Mac** | Followed through This Mac | Read (and maybe sent) through Mail.app | **Main live path** |
| Bring your own Cloud project (desktop client) | People and Calendar APIs | IMAP with the restricted scope, under the personal-use exception ("used by only a few users, all of whom are known personally to you") | Advanced |
| A shared, verified myData client | Sensitive scopes: verification without CASA, per secondary sources ([Nylas](https://developer.nylas.com/docs/provider-guides/google/google-verification-security-assessment-guide/); unverified). Needs a privacy policy on mydata.kiwi and a demo video. | Restricted scope: **annual CASA**. Not realistic for a hobby project. | Maybe later for contacts and calendar only; never for Gmail |

Confirmed facts ([restricted-scope page](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification), [OAuth2](https://developers.google.com/identity/protocols/oauth2)):

- Testing status gives "a refresh token expiring in 7 days".
- Each account gets at most 100 refresh tokens per client.
- For a desktop client, "the client secret is obviously not treated as a secret".

**Unverified:** that an unverified project set to In production, using the restricted scope under the personal-use exception, avoids the 7-day expiry. The exception page says nothing about publishing status. Test it on a throwaway Google account (S5) before relying on it.

**Recommendation:** files plus the Mac route now, your own project under Advanced, and no shared client.

### (f) Smaller decisions that block code

1. **Delete.**
   - A user deleting one item in an app gets a soft delete with an Undo toast and "Recently deleted" (30 days).
   - An assistant or agent delete waits for approval.
   - Emptying the trash, "Forget" and bulk deletes wait for approval.

   Recommended as above. This changes CLAUDE.md's "delete is irreversible" to "delete is reversible for 30 days".
2. **Events with attendees organised by someone else** are read-only until invitation handling exists. Recommended.
3. **Alerts on owned events.** Either hide the alert field (keeping imported VALARMs in `raw`, labelled "Alerts don't ring yet") until DAV lets macOS and iOS Calendar deliver them, or have the myData menu-bar app post local notifications from the host's alarm index. **I recommend hiding them for now.** An alert that silently never rings is worse than no alert.
4. **Hardening the send channel (a prerequisite of sending, not an option).** Choose one after a spike; all are unverified with ad-hoc signing:
   - app↔host over a Unix socket, with the peer's code signature checked through its audit token;
   - a Secure Enclave key with `.userPresence` held by myMail, so the host checks a signature for each send;
   - Keychain access lists per app.

   Also, in phase 0: restrict `GET /approvals` to the apps that approve, replace `READ_ONLY_APPS` with scopes per app (`contacts:write`, `calendar:write`, `mail:read`, `mail:send-own`, `approve`, `admin`), and state in the docs that the read bypass in risk 3 exists today.
5. **Backups versus "no readable remains".**
   - Host snapshots keep deleted data until they expire, and so does Time Machine. "Forget" must state the date the last copy expires.
   - On APFS and SSDs, neither SQLite's `secure_delete` nor deleting a file guarantees physical erasure. FileVault is the real protection, so Status warns when it is off.
   - Do you use Time Machine with an external disk or a NAS? If so, it becomes the off-machine copy (see 3.4).
6. **Modes.** "Real mode" should follow "the host owns data or a source is on", not "a source is on". Recommended.

---

## 3. Recommended architecture

### 3.1 What stays

- `DavClient` stays read-only (PROPFIND, REPORT, OPTIONS, GET) and becomes the iCloud, Fastmail and Nextcloud **import and follow** engine.
- The Reader's protocol stays read-only. Adding the rule and attendee reads is a reviewed change to `test_the_one_protocol_declares_only_reads`.
- **This Mac and iCloud become *followed* sources.** Turning one off **removes what it followed, as today, and never touches owned rows.** The dialog offers "Import a copy first", which goes through the import pipeline with its loss report. No stale followed orphans are kept.
- These stay as they are:
  - MCP agents get no tools in real mode;
  - the gate, and the rule that no HTTP route runs a tool directly;
  - the request log never holds mirrored data;
  - the host listens on loopback only.

### 3.2 Data model: additive, with no table rebuilds

**Keep the existing `contacts` and `events` tables and their ids.** `contacts.raw_vcard` and `events.raw_ics` already hold one raw object per row. Renaming them to `cards`/`objects` would rewrite every query in `contacts_store.py` and `calendar_store.py`, the FTS triggers, DAV sync, `MacSource` and the mirror tools, and it is exactly the kind of table rebuild that triggers the cascade bug. The raw text is the record; every parsed column can be rebuilt from it (the sabre/dav and Nextcloud pattern, [sabre SQL](https://github.com/sabre-io/dav/blob/master/examples/sql/sqlite.calendars.sql)).

**Changes, all with `ALTER TABLE … ADD COLUMN` or new tables:**

- **Collections** (`address_books`, `calendars`): `mode` (`'owned' | 'followed'`, default `'followed'`), `slug`, `group_style`, and `default_tz` on calendars.
- **Rows** (`contacts`, `events`): `rev`, `etag` (sha256 of `raw`), `deleted_at`, `purge_after`, `kind` (`individual`, `group` or `org`), and `version` (3.0 or 4.0, kept as received). Owned rows use a fixed `account_id` value such as `'local'`, because the column is `NOT NULL`.
- **Fixes a live bug:** iCloud group cards (`X-ADDRESSBOOKSERVER-KIND:group`) show up as contacts today (tested). They become `kind='group'` and are kept out of lists and `find_contact`.
- **Owned calendar rows** hold one raw ICS per (calendar, UID): the master plus its overrides ([RFC 4791 §4.1](https://www.rfc-editor.org/rfc/rfc4791#section-4.1)), with `recurring`, `scheduled` and a UTC `range_start`/`range_end` index. That the current `events` row shape fits this without a rebuild is to be confirmed while writing migration 0b.
- **Partial unique index** on `(collection, uid)` where the row is not deleted. `CREATE INDEX` needs no rebuild.
- **Timestamps:** move to milliseconds, **normalising existing rows in the same migration**, so seconds and milliseconds are never mixed in one column.

**Protection in the database, not only in code:**

- `BEFORE DELETE ON address_books/calendars WHEN OLD.mode='owned'` → `RAISE(ABORT)`.
- `BEFORE DELETE ON contacts/events`, when the row's collection is owned → abort, unless a purge-permit row exists in the same transaction. Only trash expiry and "Forget" write one. SQLite fires these triggers for foreign-key cascades as well.

**New tables:**

- `revisions(object_id, rev, raw, op, actor, approval_id, batch_id, at)`, where `actor` is the app name, `agent:<id>` or `import:<id>`. When the photo did not change, `raw` is stored without PHOTO, so inline photos are not copied on every edit.
- `changes(token AUTOINCREMENT, collection_id, object_id, href, op, at)`: the change feed for our apps and, later, for sync-collection.
- `imports(id, source, label, started, finished, counts, status)`.
- `origins(object_id, import_id, source_kind, source_uid, source_hash, source_raw, imported_rev)`, keyed by UID plus source, **never by a followed row's `id`**. Merge records and group membership follow the same rule.
- `meta`, including `tzdata_version`, so indexes are rebuilt when the zone data changes.

**Deferred until a query needs them** (all can be rebuilt from `raw`): `card_values`, `group_members`, `card_categories`, `components`, `alarms`, `attendees`. `occurrences` and `coverage` stay **only** for the followed This Mac source. **Expansion stays at query time** with recurring-ical-events, as today.

**Rules for writing the text back:**

- **vCard:** never rewrite the whole card with vobject. Tested: it lost `NICKNAME:JJ,Janie`'s second value and wrote unfolded PHOTO lines. icalendar's vCard support drops TYPE parameters.
  - Write a small content-line editor that copies untouched lines byte for byte, adds `itemN` numbers above the highest one present, and bumps REV.
  - New cards are written as vCard 3.0.
- **ICS:** edit with icalendar 7.3 (`sorted=False`), then **re-parse and compare the property and parameter counts of each component. Refuse the write if anything disappeared.** Known drop bug: [#1870](https://github.com/collective/icalendar/issues/1870).
  - Store TZIDs only; generate VTIMEZONE when exporting or serving (the generated ones are limited to 1970–2038).
  - UNTIL is written in UTC for zoned times.
- **Recurring-event edits:**
  - **This event:** add an override.
  - **Delete this event:** add an EXDATE of DTSTART's type.
  - **All events:** edit the master, shifting EXDATEs and overrides if only the time changed.
  - **This and following:** split the series (UNTIL, or recount COUNT; a new UID; `X-MYDATA-SPLIT-FROM`). Never write `RANGE=THISANDFUTURE`.

### 3.3 Write path, gate, undo, trash

```
App (scoped token) ──PUT/PATCH/DELETE + If-Match──▶ store.write(actor=app)
Assistant / agent ──tool call──▶ Registry gate ──(class)──▶ store.write(actor, approval_id)
                                      │
store.write: one transaction = row change + revision + change-feed row (+ pending op for mail)
```

| Action | User in an app | Assistant or agent |
|---|---|---|
| Create or update a contact, or an event without attendees | Runs; Undo toast | Reversible: runs, with undo. **Needs approval if an argument is grounded only by untrusted text** (mail, event notes, web). |
| Delete a contact or event | Soft delete, Undo, Recently deleted | Approval |
| Anything touching an event with attendees | Read-only (until invitations exist) | Refused |
| Import a batch | Preview, then commit; "Undo import" | Not offered |
| Mark read, flag, move to Trash | Reversible, written back to the provider | Not offered at first |
| Send, reply, forward | Send = approval of own drafts, through the hardened channel; undo window | Approval card; about 5 per hour |
| Empty trash, Forget, expunge, bulk delete | Confirmation dialog, through the gate | Approval |

- **Approvals are bound to mode and epoch, starting in phase 0.**
  - `Approval` records `mode`, `conversation_epoch` and a handler identity, and all three go into its digest.
  - `apply_mode` and every change of epoch **fail all pending approvals**.
  - A regression test holds a call in demo mode, switches to real, and approves: the result must be `failed` with zero handler calls.
- **Undo** writes a new forward revision, using `If-Match` on the current revision, so it never overwrites a later edit. It is persisted from phase 0, with an `/undo/{id}` route.
- **Persisted approvals** arrive with the outbox (mail sending), when the first real irreversible tool exists. Then they:
  - bind to the record's `rev`, and a stale `rev` refuses the approval;
  - expire after 24 h;
  - fall back to "needs approval again" after a restart, never to sent;
  - hand the call to a job queue rather than running it inside the HTTP request.
- **Approval cards** show the exact payload: a before/after comparison for updates; for mail, the full body and attachments with sizes. Each recipient is labelled "from your contacts", "from your request" or "**appeared only in an email**".
- **Trash:** purge after 30 days, revisions after 90. The purge writes a purge permit, uses `secure_delete` (with the limits stated in 2(f).5), and keeps a tombstone until the `changes` row has been pruned.

### 3.4 Backups, migrations, development safety, export

- **Snapshots (phase 0):** `Connection.backup()` of each `*.sqlite` into `<home>/backups/<ts>/`, with `integrity_check` and a manifest (sha256, schema version).
  - Hourly, and always before a migration, an import, a bulk delete or a restore.
  - Keep 24 hourly, 30 daily and 12 monthly.
  - **The snapshot before a migration is taken in the store factory** (`SyncService.contacts` and `.calendar`), *before* `Database()` is constructed. There is no hook there today, so one is added.
- **Off the machine:**
  - If you use Time Machine, exclude the live `*.sqlite*` files (`tmutil addexclusion`) and let it copy `backups/`, so Time Machine never takes a torn copy of a database in WAL mode.
  - restic becomes **optional and later**. Like Litestream, it is a Go binary to bundle. If it is added, its password goes in the Keychain through `secrets.py`.
  - Status warns when FileVault is off.
- **Restore drill:** `mydata backup verify` restores into a temporary folder, runs the migrations, the integrity and FTS checks, and the count comparison. Status shows "last verified restore". It runs **in the local test suite** on synthetic data. There is no CI; adding CI would be its own step.
- **Litestream** is deferred. It conflicts with `Database.checkpoint()` TRUNCATE ([tips](https://litestream.io/tips/)).
- **Migration runner:**
  - a dedicated connection with `foreign_keys=OFF` *before* BEGIN;
  - after the migration: `foreign_key_check`, `integrity_check`, FTS rebuild, and the declared row counts must still match;
  - a snapshot first;
  - one synthetic **SQL dump** fixture per released schema (git ignores `*.sqlite`);
  - `mydata db check-migration` runs the migration on a copy of the real databases, locally;
  - **no planned migration depends on the runner fix**: they are all additive.
- **Development safety:**
  - Development builds run with a separate `MYDATA_HOME` (already supported).
  - The host refuses to migrate the default home unless the build is a tagged release, or a fresh snapshot was taken in the same process.
- **Export at any time:**
  - `.vcf` (3.0 by default, 4.0 as an option);
  - `.ics` per calendar;
  - mail as `.eml` or Maildir plus **mboxrd**. Not `mailbox.mbox` alone, which writes mboxo and loses data on the round trip ([docs](https://docs.python.org/3/library/mailbox.html)).
  - Export into the checkout is refused.
  - A raw export (the stored `raw` text) ships in phase 0, before the writers exist.

### 3.5 Import pipeline

1. The app uploads **bytes**, not a path.
2. The host parses with caps:
   - size and decompressed-size caps;
   - zips read in memory, never extracted to disk;
   - a pass that joins vCard 2.1 quoted-printable soft breaks, then converts 2.1 to 3.0, keeping the original in `origins.source_raw`.
3. The host returns a **preview without writing anything**:
   - counts;
   - duplicates, **including matches against followed collections** (these trigger the shadowing rule in 2(a));
   - what would be lost ("notes not in this source", "repeating events become single events");
   - calendars that look derived (Birthdays, holidays).
4. You pick the target book or calendar, then commit as one `batch_id`. A preview with a loss report needs your explicit acceptance before it can be committed.
5. **Matching:**
   - **Events:** UID + RECURRENCE-ID; the higher SEQUENCE wins and the other copy is kept as provenance.
   - **Contacts:** an exact normalised email or E.164 phone number (needs the `phonenumbers` package) is a strong signal; a name alone is only a suggestion. **Never merge automatically.** A merge keeps both originals so it can be undone.
6. **Re-import:**
   - an item is updated only if `rev == imported_rev`, meaning nobody has edited it since;
   - an item missing from the new file is reported, never deleted.
7. Nothing imported is ever logged.

### 3.6 Sync and serve (phase 10 below)

- A separate ASGI app on its own loopback port (for example 47822), off by default.
- Authentication with **per-device passwords** created only by the myData app: random, 128 bits or more, shown once, stored as a hash, each with a read-only flag and a last-seen time.
- **First, read-only:** discovery, PROPFIND, GET, and the multiget, calendar-query and sync-collection reports. `current-user-privilege-set` supports the read-only flag.
- **Then writes:** PROPPATCH (name and colour), PUT with If-Match / If-None-Match, DELETE as a soft delete, and a mass-delete guard (more than 10 items or more than 5% from one device: hold it and ask).
- **Not in v1:** scheduling (iTIP/iMIP) and free-busy.
- **This Mac must exclude the myData DAV account,** or the host reads its own data back in and serves it out again.

### 3.7 Mail

- **Store:** `mail.sqlite` plus immutable blobs at `mail/blobs/<sha[0:2]>/<sha>.eml`: one file per message, even when it is in several mailboxes.
  - Each blob is encrypted with its own key, stored in `mail.sqlite`, so "Forget" works by deleting the key. Snapshots keep the key until they expire, and "Forget" states that date.
- **Tables:** `accounts`, `mailboxes` (role, uidvalidity, cursor), `messages` (blob hash, Message-ID, thread_id, `seen_last_at`), `message_locations` (mailbox, remote id, flags), `addresses`, `attachments`, `threads` (the provider's own thread id when there is one, otherwise JWZ), `fts_messages` (body capped at about 64 KB), `outbox`, `pending_ops`.
- **Size:** at the measured average of about 85 KB per message, a few hundred MB for a mailbox of a few thousand messages.
- **Mail helper:** a separate nested helper, attributed to myData (to be confirmed once the spike's prompt question is answered).
  - It accepts **fixed commands with typed parameters passed as Apple Event descriptors**, never text pasted into AppleScript. The spike's `NSAppleScript(source:)` would let an email inject script.
  - **Trash** is `trashMessage(account, messageId)`: a `move` into that account's Trash mailbox, with a Swift assertion that the object is a message. **`delete` is never exposed.** A fixture test checks that the command refuses a mailbox reference.
  - A scan test bans every verb except the allowed ones, and the read and send surfaces are separate.
  - **Never launches Mail on its own.** Before each poll, it checks that Mail is running (`NSRunningApplication`). "Start Mail when myData starts" is a setting, off by default.
  - **Never prompts in the background.** Before each poll it calls `AEDeterminePermissionToAutomateTarget(…, askUserIfNeeded: false)`, and it asks only when you press Allow.
  - Messages are keyed by (account, Message-ID, mailbox) plus a hash, because Mail's ids change when it rebuilds its index.
  - **Absence is not deletion** (see (b).3). A mass-change guard pauses sync when more than 5% of a mailbox vanishes.
  - Polling: the inbox id list every 60 s, a full check every 15 min.
  - The purpose string changes when sending ships. Whether changing it re-prompts is unverified.
  - **Mac only.** On a Linux or NAS host, iCloud mail means an app-specific password; the docs say so plainly, as they do for CardDAV.
- **Parsing:** in a worker process with a timeout and size cap, using `email` with `policy.default` and `errors='replace'`. A test must confirm that 3.11.15 has the header-injection fix (CVE-2024-6923).
- **HTML mail:**
  - The host sanitises with `nh3` ([docs](https://nh3.readthedocs.io/en/latest/)): `url(` stripped from styles, remote images replaced by placeholders, `cid:` inlined.
  - **CSS inlining never fetches anything.** css-inline defaults `load_remote_stylesheets` to `True` ([PyPI](https://pypi.org/pypi/css-inline/json)). Pin it to `False`, and test a fixture containing `<link href="http://…">` against a socket that refuses connections.
  - The app renders with `flutter_widget_from_html_core`, with a plain-text toggle, remote content blocked by default and a banner to load it.
- **Outbox:** draft → held → approved → sending → sent | failed | **unknown**.
  - **"Unknown" is never retried automatically.**
  - On SMTP routes the Message-ID is made when the call is held. On the Mail route, the host matches recipients, subject and time in Sent and asks you.
  - The digest covers the from account, every recipient, subject, body, in-reply-to, and **the sha256 of each attachment**.
  - Attachments are handles to files you picked in an app and the host copied in; **a path supplied by the model is never accepted.**
- **Untrusted text:**
  - a turn that read mail is *tainted*, and any write proposed in it needs approval;
  - addresses that appear only in mail never pass grounding silently;
  - hidden HTML elements are stripped before anything reaches the model;
  - logs hold counts, statuses and digests only.

### 3.8 What changes in the API, tools, apps and tests

- **API (`service/api.py`):**
  - `POST/PATCH/DELETE /contacts`, `/calendars` and `/events/{id}?recurrence_id&scope=this|following|all` with If-Match and 412;
  - `/changes?since=`, `/trash`, `/undo/{id}`, `/import` (preview, commit, undo), `/export`, `/backups`, `/mail/*`;
  - `Literal["mac","icloud"]` grows a value; the generated Dart enums throw on unknown values, so the host and apps move together under `api_version`;
  - regenerate `openapi.json` and the client every time.
- **Auth:** scopes per app replace `READ_ONLY_APPS`. The mail app's token is added to `APPS` after the name is decided. `GET /approvals` is limited to the apps that approve.
- **Tools:** real `create_event`, `add_contact`, `search_mail` and `send_mail` **only after a new frozen request set and a measurement**, as CLAUDE.md requires. Until then, writes come only from the apps. The prompt prefix test changes.
- **Logs:** real-mode logs keep the shape of each argument (field names and lengths), never the values. Today `calls[].args` would hold mail bodies.
- **Tests:**
  - add `smtplib`, `imaplib`, `poplib` and `ssl` to `BANNED` in `test_dav_no_other_http.py`, with one allowed mail module;
  - a scan that rejects `osascript` anywhere in host sources, and an allow-list of the modules that may import `subprocess` (today `cli.py`, `sources/mac/launcher.py`, `feasibility/latency.py`, `service/model.py`), so nothing can go around the Swift helper's verb scan;
  - a reviewed list of native-extension dependencies, with a reason for each, since the import scan cannot see their network use;
  - the demo→real approval regression;
  - a "survives" twin for every mirror-delete test, plus trigger tests showing that deleting an owned row without a permit aborts;
  - `find_contact` returns one match for a person who was imported and is still followed;
  - Hypothesis round trips (fixtures only at example.org / .invalid / 555-01xx; `.hypothesis/` in `.gitignore`);
  - byte-identical golden tests for untouched lines;
  - the property-loss guard;
  - the four recurrence algorithms across a time change (the 02:30 Auckland gap behaviour must be pinned);
  - the cascade regression;
  - restart and crash outbox tests, including a restart inside the undo-send window that returns the message to draft;
  - a test that agent tokens cannot reach any write route.
- **Apps:** the read-only wording changes in the same phase as the feature it describes: ContactHeader's "Change it in Contacts", EventRow, the CalendarsPage intro, empty states, and the Sources turn-off copy. Sources becomes three groups: "Your data on this host", "Imported" and "Following". Turning a source off removes followed data and offers "Import a copy first".

---

## 4. Phases in build order

**Spec first** marks phases whose `design/` specs and previews you review before any widget is built.

**Default order:** safety → contacts editing and import → mail receiving → calendar editing → mail sending → DAV → remote access. If phone sync matters more to you than sending mail, phases 10 and 11 can move ahead of phase 9. That is your choice, and it will not be made silently.

### Phase 0a: Safety net (about 1 weekend)

| Built | Verified by |
|---|---|
| Migration runner fix (foreign keys off before BEGIN, then the checks) | A cascade regression test: rebuilding a parent table keeps its children (the scratch script is the model) |
| Development safety: a separate `MYDATA_HOME` for development, a refusal to migrate the default home without a release tag or a fresh snapshot, the snapshot hook in the store factory | Tests on a temporary home |
| Snapshots, restore drill, Status lines (last snapshot, last verified restore, FileVault off), raw export | `mydata backup verify` in the local test suite; **you run one real restore drill** |

**You:** decide on Time Machine (2(f).5).

### Phase 0b: Additive schema (about 1 weekend)

| Built | Verified by |
|---|---|
| `ADD COLUMN` migrations (`mode`, `rev`, `etag`, `kind`, `version`, `deleted_at`, `purge_after`), timestamps normalised to milliseconds, `revisions`, `changes`, `imports`, `origins`, `meta`, owned-row triggers | Migrating a synthetic dump compares every field; `mydata db check-migration` on a copy of your real files |
| `_purge_orphans` and the other hard-delete paths rewritten as an allow-list (followed collections of accounts known to be removed only) | A "survives" twin of every existing hard-delete test; trigger-abort tests |
| Group-card fix | Updated store tests |

### Phase 0c: Tokens, undo, mode (about 1 weekend)

| Built | Verified by |
|---|---|
| Approvals bound to mode and epoch, failed on a mode or epoch change | The demo→real regression test |
| Token scopes; `GET /approvals` restricted; docs on the read bypass | Updated `test_app_views`, `test_privacy` |
| Persisted undo and the `/undo` route | Restart tests: nothing is undone twice |
| Real-mode argument redaction, the network ban list and `osascript` scan, the mode rule | Updated `test_modes`, `test_privacy` |

### Phase 1: Writers and export (about 1 weekend)

- **Built:** the line-preserving vCard editor, the ICS writer with the property guard, and `.vcf`/`.ics` export.
- **Verified by:** round-trip and Hypothesis tests on synthetic corpora: Apple 3.0, Google, Samsung 2.1, 4.0 KIND/MEMBER, and Outlook/Windows TZIDs. Export, then re-import, then compare.
- **You:** nothing.

### Decision record and CLAUDE.md update (small, before phase 3)

The new direction (owned data, reversible delete, followed sources) changes ground rules in CLAUDE.md. **You approve it** before any write feature ships.

### Spikes to run alongside phases 0–1 (you present; nothing in the repo)

- **S0, prompt attribution:** which name the Automation prompt showed (also visible under Privacy & Security → Automation).
- **S1, mail send:** to your own address only. Check:
  - the `>` bug with a body that starts with a blank line, and non-ASCII text;
  - two attachments;
  - `sender` set to each account;
  - `reply` threading;
  - the copy in Sent;
  - what happens offline;
  - that parameters go in as descriptors.
- **S2, account 2:** what type it is, Mail's counts against the web interface, and whether reading a partial message downloads the rest. **It gates B1 as the main receive path and decides which B2 route comes first.**
- **S3, DAV:** Radicale in a throwaway macOS user, answering the four questions in (d). Use the iOS Simulator if it can add DAV accounts (unverified), otherwise an "Other" account on your real phone.
- **S4, calendar export:** a synthetic calendar in a throwaway user with one deleted and one moved occurrence. Export it from Calendar.app and check it round-trips through `ical.py`.
- **S5, Google token lifetime:** on a throwaway Google account, check whether an unverified In-production project using the restricted scope keeps its refresh token past 7 days.
- **S6, send-channel hardening:** try the options in 2(f).4 with ad-hoc signing.

### Phase 2 (spec first): Batch A foundation components (about 1–2 weekends)

- **Built:** Dialog, Inspector/Sheet, Menu, Select, Text area, Checkbox, Toast with Undo, Icon button, multi-select, a form variant of Switch, and `PlatformMenuBar` (Edit ▸ Undo, ⌘N, ⌘⌫).
- **Verified by:** goldens in Kiwi and Graphite, light and dark; the no-literals scan.
- **You:** review the specs and previews.

### Phase 3 (spec first, Batch B): Editing contacts (about 1.5–2 weekends)

- **Built:** contacts CRUD on the host, myContacts edit mode, groups, photo picker, Recently deleted, and the contacts wording changes.
- **Verified by:**
  - host API tests (If-Match/412, undo, trash);
  - an edit that keeps every untouched line byte-identical;
  - app goldens;
  - a live run against a host holding **only synthetic data**.
- **You:** review the specs, then try it.

### Phase 4 (spec first, Batch E): Contact import (about 1 weekend)

- **Built:**
  - contact file import with preview, loss report, commit and undo;
  - iCloud CardDAV into owned collections;
  - the shadowing rule and the "stop following X?" offer;
  - duplicate suggestions and merge with undo.
- **Verified by:** importing twice creates no duplicates; undoing a batch restores the exact state before it; the one-match `find_contact` test; zip bomb and path traversal tests.
- **You:** export from Contacts.app (with notes) and Google, and from the Samsung phone if you use one. **Keep the originals until DAV has been running for a while.**

### Phase 5 (spec first, Batch D): Receiving mail, read-only (about 3–4 weekends in all)

Before it starts, S0 and S2 must have passed, and the name must be decided.

- **5a, helper and store, no UI:** the Mail reader helper (no launching, no background prompts, typed commands), `mail.sqlite`, encrypted blobs, FTS, the absence rule and mass-change guard. Verified by the verb scan, synthetic fixtures and a live count comparison with Mail. **You:** grant the Automation prompt.
- **5b, the app:** mailbox list, message list, thread view (spec needed for the three-pane layout), plain-text reading, search.
- **5c, HTML:** the sanitiser, CSS inlining with remote loading off, the renderer. Verified by hostile-HTML fixtures and a remote image or stylesheet that must not load.
- **5d, mbox import.**
- **5e, the IMAP route for account 2's provider,** as the standby path (Microsoft device code if S2 says Outlook or Exchange).

### Phase 6 (spec first, Batch C): Editing calendars and calendar import (about 2.5–3.5 weekends; recurrence is the risk)

- **Built:**
  - events CRUD including this / following / all;
  - date, time, zone and repeat fields; the alert field hidden on owned events (2(f).3);
  - the calendar colour picker;
  - the event inspector;
  - events with attendees read-only;
  - calendar file import and iCloud CalDAV into owned calendars, with the shadowing rule;
  - the calendar wording changes.
- **Verified by:**
  - the four algorithms across a time change, COUNT, UNTIL, RDATE and all-day events;
  - our expansion compared with the original source's occurrences over a window.
- **You:** review the specs; export your calendars from Calendar.app and Google.
- **Optional:** extend the Reader to read `recurrenceRules`, alarms and attendees, to improve the *followed* This Mac view. It is still never imported.

### Phase 7: Sending mail and writing back to the provider (about 2–3 weekends)

- **Prerequisite:** the send channel hardened (S6 decides how).
- **Built:**
  - persisted, `rev`-bound approvals and the job queue;
  - the outbox state machine;
  - Send counted as approval, with the undo window (a restart returns to draft) and the rate limit;
  - mark read, flag and `trashMessage` written back;
  - the SMTP fallback if S1 failed.
- **Verified by:**
  - a crash during `sending` leads to `unknown` and no second send;
  - an attachment hash changed after approval is refused;
  - a token alone cannot complete a send;
  - live sends only to your own address.
- **You:** turn on "Allow myMail to send through Mail" in Settings.

### Phase 8: Assistant write tools

- **Built:** the taint-tracking split of grounding; real write tools.
- **Verified by:** a **new frozen request set** measured before shipping, plus the prompt prefix test.

### Phase 9: Serve CardDAV/CalDAV (about 3–5 weekends, unverified)

- **9a:** the DAV listener, per-device passwords, discovery and read-only serving, This Mac excluding the myData account, TLS as S3 decides.
- **9b:** writes, the mass-delete guard; then the alert field is enabled on owned events.
- **Verified by:**
  - caldav-server-tester (run in development, not shipped);
  - vdirsyncer or pimsync;
  - Calendar and Contacts in a throwaway user;
  - the iOS Simulator or a real phone;
  - DAVx5 in an Android emulator at 10.0.2.2.

### Phase 10: Remote access for the phone (its own decision record)

- Tailscale Serve or another route, as you decide. Whether Tailscale Serve keeps the Host header is unverified.
- **You:** add the account on the phone and make it the default.

### Phase 11 (Advanced): API imports and IMAP

- **Built:** Google with your own project (after S5), Microsoft Graph and IMAP (device code), generic DAV and IMAP accounts.
- **You:** set up your own Google Cloud project if you want it. For Microsoft, the maintainer needs a directory registration (an Azure or M365 Developer Program sign-up, which may need a card or phone number; unverified).

---

## 5. Unverified items and open questions

**Unverified:**

- **Automation prompt:** whether it named myData or the spike helper (S0), and whether a second nested helper is attributed to myData without a new prompt.
- **macOS 26 and DAV:** whether Contacts and Calendar accept plain http or a single trusted localhost certificate, and whether Contacts still allows one address book per account (S3). Whether the iOS Simulator can add DAV accounts.
- **Mail.app sending on 26.7.1:** the `>` bug, attachment timing, sender fallback, what `send` returns, copies in Sent (S1).
- **Account 2:** its type, and whether Mail holds only a recent window of it (S2).
- **Apple's Full Disk Access tightening:** whether it extends to Automation.
- **EventKit:** that it exposes no EXDATE or RDATE, and that attendees are read-only.
- **Calendar.app `.ics` export:** that it keeps RRULE, EXDATE and overrides (S4).
- **Exports:** that Samsung exports vCard 2.1 without groups and has no calendar `.ics` export; that Google's vCards carry stable UIDs.
- **Google:** that `contacts.readonly` and `calendar.readonly` are sensitive, not restricted (secondary sources); whether an unverified In-production project with the restricted scope avoids the 7-day expiry (S5); that Gmail app passwords still work (secondary sources).
- **Microsoft:** whether an individual can pass publisher verification; what the Azure sign-up requires.
- **Send-channel hardening** with ad-hoc signing (S6).
- **The existing `events` row shape** holding a master plus overrides per UID without a rebuild.
- **Litestream:** whether a TRUNCATE checkpoint stalls behind its read lock.
- **Tailscale Serve:** whether it keeps the Host header.
- **Estimates:** every size estimate is unverified against your pace.

**Open questions for you:**

1. **Your daily phone:** iPhone on iCloud, a Samsung or other Android, or both? (Decision 0.)
2. Is "On myData only, not on your phone yet" acceptable until DAV, or do you want the A3 push-to-iCloud bridge (iPhone only)?
3. Default order: mail sending before DAV, or DAV first?
4. Should Tailscale (a free third-party account) be the remote-access route?
5. Mail retention: full archive by default (recommended), or purge after 30 days on IMAP routes?
6. Should Send in myMail count as the approval, once the channel is hardened?
7. myMail or myEmail?
8. Do you use Time Machine, and to which disk?
9. Licence. It is still open, and it decides whether GPL code (Radicale or Xandikos) could ever be embedded. The plan avoids needing to.

---

### Critic points not taken

- **Item 11, banning `subprocess` in `BANNED`:** not taken as written. Four host modules already use it (`cli.py`, `sources/mac/launcher.py`, `feasibility/latency.py`, `service/model.py`), so the plan scans for `osascript` and allow-lists the modules that may use `subprocess` instead.
- **Item 17, "Time Machine is the off-machine copy":** taken only if you use Time Machine with a separate disk. It is not assumed, so it became decision 2(f).5.
- **Item 17, per-blob keys as the fix for "no readable remains":** taken, but not as a full fix. Keys stay in snapshots until those expire, and SQLite `secure_delete` has the same APFS/SSD limits, so "Forget" still has to state an expiry date and relies on FileVault.