How contacts come into myData as the host's own: from a file, or as a copy of an account myData follows. Four steps on one page of the myData app (Choose, Review, Importing, Done), then the import's place in the history, where it can be undone. Phase 4; contacts only. Calendars (phase 6) use the same page and the same steps.

**Status: decided 2026-10-14** (the owner's review; "Decisions", at the end). **The host side is built** (`docs/decisions/2026-10-14-contacts-editing-and-import.md`, "Importing contacts"); the app side is not. Every count, list, choice and error below comes from the host's API as built ("What the host gives", at the end); the host gaps this spec named (H1 to H8, at the end) are all built (2026-10-14), and each use below says which it relies on.

## Where it lives

- **myData gets a third sidebar section, "Import"** (Decisions, 1), between Status and Settings (View menu: Status ⌘1, Import ⌘2, Settings ⌘3; Settings… ⌘, in the app menu is unchanged). On a phone it is the middle tab of three.
  - **Why not Settings:** Settings is one scrolling page of GroupedSections whose changes apply at once (Appearance, Assistant, Sources, Agents). An import is a task with steps, a review list that can run to hundreds of rows and a history; inside a section of that page it would push everything below it out of reach, and a link could not land on a step. In a Dialog it would break the Dialog's "one or two fields" rule.
  - **Why not Status:** Status only shows; it has no actions beyond opening apps.
  - **Sources stay in Settings.** Following an account is a setting (on or off, at once); importing is something done once. Each followed iCloud account in Settings, Sources gains a plain "Import a copy" button that opens this page with that account's copy being read, so the two meet without being merged.
  - The section is for later imports too: calendars (`.ics`, phase 6) and, if it comes, a mail archive (mbox). Until a second kind exists the page has no Contacts or Calendars switch: its first heading says "contacts".
- **myContacts does not import in place.** File > Import… (platforms.md; "Import contacts…" in the "More actions" menu on a phone, and the link in myContacts' empty state) opens myData at this page with the link `mydata://import/contacts`. myData comes forward with the Choose step showing; myContacts stays as it was.
  - **Why:** one place keeps the history and every "Undo import"; the flow is built once, for contacts now and calendars later; and the preview belongs to the app that made it (the host refuses it to any other app), so the whole flow must live in one app.
  - **The cost:** an app switch. Done offers "Open in myContacts" (when installed) to go back; myContacts shows the new contacts at its next read of the list.
  - **Scope:** import has its own scope, `contacts:import`, held by myData and the `mydata` command only, so myContacts cannot import by itself (H5, built; Decisions, 2): every import route answers myContacts with 403. myContacts keeps `contacts:write` for its own edits and for merging. An app holding `contacts:import` always holds `contacts:read` too, because the import routes answer with contact data (the host checks this).
  - A link that arrives while an import is in Review or Importing does not restart it: myData comes forward on that step.

## The page

- The page is a reading column (`content-max`) on `bg`, as Settings is, with the page title in `display-lg`. The title is the step: "Import contacts" (Choose), "Review the import", "Importing 128 contacts", "Imported 128 contacts into myData". There is no step indicator: each step has one way forward and one way back, named on its buttons.
- Each step replaces the one before in the same column, scrolled to the top.
- **The host holds a preview for an hour, for this app only, and not across a restart** (`expires_at`). Changing section and coming back within that time returns to the same Review, read again from the host (`GET /import/previews/{id}`), so a change made in myContacts meanwhile shows. After that, Review shows "Expired" (States).
- A step with a main action (Review) ends in a footer bar at the bottom of the content area: the reason line (when Import is disabled) at the start, then plain, then filled, at the end edge, `space-2` apart, `space-4` above and below, with a 1px `line` above it while the column scrolls under it (the Inspector's rule). The footer stays put while the column scrolls, so "Import 128 contacts" is never far away.

## 1. Choose

From top to bottom, as GroupedSections:

- **"From a file":** the DropZone (DropZone), with its filled "Choose file…" button, the screen's one filled button. Its caption says what it takes: "A vCard file (.vcf) from Apple, Google or Samsung, or a .zip of them. Up to 50 MB." **One file per import** (the host reads one input per preview; several files are one .zip; Decisions, 5).
- **"Where to get a file":** one GroupedList row per place people keep contacts, each a disclosure row (a chevron at the end, turning a quarter on opening; `aria-expanded`) that opens, in place, numbered steps quoting the vendor's own menu names. Several can be open at once; none is open at first, except the Apple row when the link came from myContacts on a Mac. The steps, today (menu names to be checked on current versions before building; marked "unverified" are from memory):
  - **Contacts on a Mac:** 1. In Contacts, choose Contacts > Settings > vCard, and turn on "Export notes in vCards" and "Export photos in vCards". 2. Select all contacts (⌘A in the list). 3. Choose File > Export > Export vCard…, and save the file. 4. Drop it here. A line under the steps: "This covers every account on this Mac: iCloud, Google, Exchange and On My Mac."
  - **iCloud on the web:** 1. On icloud.com, open Contacts. 2. Select all contacts. 3. Choose Export vCard… from the actions menu (unverified). "Use this on a computer that is not a Mac."
  - **Google:** 1. Open contacts.google.com. 2. Choose Export, then "vCard (for iOS Contacts)" (unverified), and export. "Google CSV and Outlook CSV are not read yet; choose vCard." A Google Takeout .zip works too, when it includes Contacts.
  - **Samsung Galaxy:** "Best: move the contacts to your Google account on the phone (Contacts > Manage contacts > Move contacts, unverified), then export from Google." Otherwise: 1. In Contacts, open the menu, then Manage contacts > Import or export contacts > Export (unverified). 2. Send the .vcf file to this computer. "Samsung's file has no groups or categories."
  - **Outlook:** "Outlook.com exports contacts only as a CSV file, which myData cannot read yet. If your Outlook account is added to this Mac (System Settings > Internet Accounts), export it from Contacts on the Mac instead." No steps.
- **"From an account myData follows":** one ActionRow per followed source that holds contacts (`GET /sources`).
  - **A followed iCloud account:** the account as Settings names it, "The iCloud account ava@example.org", a caption with its count as of the last update (`counts.contacts`, `last_update`): "128 contacts, as of today at 09:12", and a tonal "Import a copy" button. It reads the copy (`POST /import/contacts/from-source/{account}/preview`) and goes to Review, with nothing to upload.
  - **This Mac:** shown, never importable (the host refuses it, 409). No button; the caption is the reason and the way round it, in full `ink-muted`: "A copy from this Mac would be incomplete: myData does not read notes from it. Export a vCard from Contacts instead (Contacts on a Mac, above)." It ends in a plain "Show how" button that opens and scrolls to that row's steps. The app writes this sentence; it never shows the host's 409 text, which writes menu paths with commas.
  - The section is left out when no source holds contacts; This Mac's row is left out when This Mac is off.
- **"Earlier imports":** the import history (5, below). Left out until there has been one.

## 2. Review

The host has read everything and written nothing. The app shows what the preview says and sends back only the rows whose tick differs from the card's default (`choices`). From top to bottom:

- **Under the title,** one `body` line in `ink-muted` names what was read: "contacts-2026-10-14.vcf: 140 cards." (`label`, `counts.cards`). For a zip, the number of vCard files in it when there is more than one: "takeout-2026-10-14.zip: 3 vCard files, 212 cards." For an account copy: "A copy of the iCloud account ava@example.org: 128 contacts." The host does not say which app made a file or its vCard version; "vCard 2.1" appears only under "Changed on the way in", below.
- **The summary:** a GroupedList, one row per kind, each with an icon tile and a count in its title. Rows with nothing in them are left out. The counts follow the ticks below.
  - "125 new contacts" (status `new` with no match in myData), caption "Imported." (`accent-soft` tile)
  - "3 possible duplicates" (status `new` with a `suggestion` match to a contact in myData), caption "Imported as separate contacts unless you untick them below." (`info-soft`)
  - "3 changed since your last import" (status `update`), caption "Your copies are updated unless you untick them below." (`surface-sunken`)
  - "8 already in myData" (statuses `duplicate`, `unchanged`, `in_file` and `deleted`), caption "Not imported again unless you tick them below." For an account copy whose matches are kept as yours (default action `link`): "Kept as your contacts; the iCloud copies are hidden." (`surface-sunken`)
  - "1 not updated" (status `conflict`), caption "You changed your copy since the last import, so the file's version is not used." (`surface-sunken`)
  - "2 cards cannot be read" (status `skipped`, and `counts.skipped`), caption "Not imported. See below." (`warning-soft`)
  - At most three tile colours: accent, info and warning; every other row is neutral.
- **"What this import will not bring"** (the loss report, `losses`), only when it is not empty (`needs_acceptance`), as a GroupedSection whose rows each say what, how many, and why, in sentences the app writes from each note's `code` and `count` (the host's `message` says "card(s)", which the copy rules forbid):
  - unreadable cards, one row each, by position (the item's `index` plus 1) and, from a zip, the file it is in (`entry`). A skipped card has no name the host could read, so none is shown. Reasons (`reason`): `no_end` "Card 57 ends before END:VCARD; the file may be cut short."; `unreadable` "Card 112 could not be read as a vCard."; `version` "Card 9 is a vCard version myData does not read."; `empty` "Card 30 is empty."; `too_large` "Card 4 is far larger than a contact (over 8 MB)."; past the first 50,000 cards, one row: "The 1,204 cards after the first 50,000 are not read." More than five cards: the first five and "Show 12 more" (a disclosure);
  - `guessed_charset`: "2 cards did not say how their letters are written, so myData guessed (Windows-1252). Some letters may be wrong; each card's original is kept with the import.";
  - `outside_text`: "3 lines of text are outside any card. A card whose first line is misspelt (BEGIN:VCARD) would be among them.";
  - `unreadable_entry`: "In the zip, family.vcf and work.vcf hold no card myData can read." (`entries`, up to three by name, then a count);
  - `nested_zip`, `encrypted`, `unsupported_compression`: "1 zip inside the zip is not opened.", "2 encrypted files in the zip are not read.", "1 file in the zip is compressed in a way myData does not read.";
  - **Contacts on a Mac without notes** (`no_notes`, H2, built; Decisions, 4): "None of the 136 cards has a note. Contacts on a Mac leaves notes out unless “Export notes in vCards” is on. If your contacts have notes, export again with it on." It is a loss like the others, so it needs the tick: it is what is lost for good once the originals are deleted.
  - It ends in a Checkbox, unticked: "Import without what is listed above" (Decisions, 3), caption naming what it covers: "2 cards are not imported."; with `no_notes`, also "No notes are imported." Until it is ticked, the Import button is disabled and the reason sits in the footer, at its start: "Tick “Import without what is listed above” first, or choose another file." (Checkbox, "The action that uses the selection"; platforms.md, "Disabled controls".) It sends `accept_losses`; the host refuses a commit without it (400). This is the plan's explicit acceptance (3.5, step 4).
- **"Changed on the way in"** (`changes`), only when not empty: plain rows, no tick, because nothing is lost: `converted_21` "128 cards are vCard 2.1 (Samsung). They are stored as vCard 3.0 so they can be edited; nothing in them is lost, and each original is kept."; `declared_charset` "Some cards were not written in UTF-8. They are read in the character set each one names."; `other_files` "4 other files in the zip are not contacts and are not read."
- **Where they go:** one `body` line, no control: "Into myData, the address book on this host. Imported contacts are on myData only, not on your phone yet." The host keeps one owned address book and lists none (it makes "myData" with the first import), so there is nothing to choose; the commit sends no `address_book_id`. A Select comes when a second owned book can exist.
- **Notices** (Notice, `info`), each only when it applies:
  - **First data of your own** (`/status` says `mode: demo`): "This is the first data of your own in myData. Importing ends the demo: myData shows your contacts instead, and myAssistant starts a new conversation." (The commit makes the owned address book, which switches the host to real mode and moves the conversation epoch on.)
  - **Groups** (`counts.groups`): "This file has 4 groups. They are imported with the contacts, but myContacts does not show groups yet." The host gives no group names in the preview, so none are quoted.
  - **Shadowing, an account copy:** "All 128 contacts are read from the iCloud account ava@example.org now. After the import, myData shows your copy and hides the followed one, so each person is found once." (Built: matched by account and UID.)
  - **Shadowing, a file** (`counts.followed_matches`: cards with a strong match to a followed contact, the same name and the same email or phone, emails normalised and phones in E.164): "42 of these contacts are also read from this Mac. After the import, myData shows your copy and hides the one read from this Mac, so each person is found once." Built (H1; Decisions, 7). The count holds only cards imported, updated or found unchanged with the default choices; a duplicate the user ticks hides its followed copies too (its matches with `hides`), but is not counted.
  - These are not choices and not duplicates: a followed copy is never offered for merging.
- **"Files in the zip (3)",** first, only for a zip with more than one vCard file: one ticked row per file (the items' `entry`), with its card count ("family.vcf, 24 cards"), so a file can be left out; unticking sends `skip` for its cards that can take it. The counts above follow the ticks.
- **The lists,** each a Checkbox list with its own select-all row (Checkbox, "In a list"), under a heading with its count. Each row ticks with its default action; a tick and an untick map to the two actions the card's `choices` allow (below). The Import button counts what is ticked to import or update across all of them.
  - **"Possible duplicates (3)",** ticked (import; unticked: skip). A card with a `suggestion` match to a contact in myData: the same name only, or an email or phone shared under another name. Each row: the name from the file, and a caption saying what matches, from the match's `signals`: "Same name as Ben Sample in myData." / "Same email as Cleo Example in myData, under another name." The value itself is not shown (the preview does not carry it). Under the heading: "Ticked ones are imported as separate contacts. You can merge them later in myContacts." Nothing is merged here (plan 3.5, step 5).
  - **"Changed since your last import (3)",** ticked (update; unticked: skip): a card imported before from this file name or account that changed since, whose copy in myData nobody changed. Caption: "Changed in the file since you imported it. Ticking it updates your copy." A card with no UID that changed (signal `changed`, Google and Samsung exports) reads the same.
  - **"Already in myData (5)",** unticked:
    - status `duplicate`: a contact in myData with the same UID, or the same email or phone under the same name. Caption from `signals`: "Same email and name as Ava Fictional in myData." Ticking it imports the card as a separate contact (`import`). For an account copy where the host offers `link` and it is the default, unticked means "keep yours and hide the iCloud copy" and the caption ends "Your contact is kept; the iCloud copy is hidden."; where two cards would match the same contact of yours, neither is linked (default `skip`): "Two cards in this account match Ava Fictional; both iCloud copies stay visible. Tick one to import it as well."
    - status `deleted`: "Your copy is in Recently deleted. Restore it there, or tick this to import the file's version as a new contact."
    - status `unchanged` and `in_file` have no choice (their only action is skip), so they are not rows: one line under the list says "6 unchanged since you imported this file, and 2 repeated in it, are left out."
  - **"Not updated (1)",** no boxes: status `conflict`, with its `reason`: `edited` "You changed it in myData since the last import."; `merged` "It was merged with another contact since."; `kept_yours` "You kept your own contact instead when you imported it." These can only be skipped (the host never writes over a change), so the rows are text.
  - **"New contacts (125)",** ticked (import; unticked: skip), folded at first behind a plain "Show all 125" (a disclosure; the select-all row shows while folded, so they can all be unticked at once).
  - **"Not in this file any more (4)",** text rows, folded (`missing`): "Imported before from this file, and not in it now. They stay in myData; delete them in myContacts if you no longer want them." The host never deletes them.
  - **Compare:** each row in Possible duplicates and Already in myData ends in a plain "Compare" button (a disclosure, `aria-expanded`) that opens a read-only DuplicatePair under the row ("In the file" and "In myData"), with differing fields marked. "Hide comparison" closes it. On a phone, Compare opens the pair in a picker-height Sheet. "In the file" comes from `GET /import/previews/{id}/items/{index}` (H3, built).
  - The row is a list item holding two targets side by side: the checkbox (box, name and caption, which ticks on press) and the Compare button. The button is never inside the checkbox's target (a control inside a checkbox cannot be reached by a screen reader).
- **Footer:** "Cancel" (plain) and "Import 128 contacts" (filled), counting what is ticked to import and update ("Update 3 contacts" when only updates are ticked). Cancel discards the preview (`DELETE /import/previews/{id}`) and returns to Choose; nothing was written, so it never asks. With nothing ticked, Import is disabled: "Choose at least one contact to import."
- **Nothing to import:** when no card has an action other than skip by default, the summary shows that, and the footer's filled button is "Choose another file". Ticking a row turns it back into "Import 1 contact".

## 3. Importing

- One request (`POST /import/previews/{id}/commit`): the host makes a backup copy of the contacts first, then saves every card in one transaction. It takes a few seconds (about 6 s for 44,000 cards); the host reports no progress and cannot be cancelled once sent, and does not need to be: it is all or nothing, and Undo import follows.
- The title is "Importing 128 contacts". Under it an indeterminate ProgressBar labelled "Making a backup copy, then saving", and one `caption`: "Nothing is in myData until this ends. Undo import is offered then." No buttons. The step shows only when the request takes longer than 1 second, so a small file goes straight from Review to Done without a flash.
- Changing section, closing the window or switching apps does not stop it; coming back shows Done. Quitting myData stops the host: an import cut short writes nothing (one transaction) and leaves no history row.
- **Failed:** the page returns to Review, as it was, with a line in `danger` above the footer, read at once:
  - the host did not answer: "The contacts were not imported. The host stopped answering. Nothing is in myData; check that it is running, then press Import again.";
  - the backup copy failed (503): "The contacts were not imported: the host could not make its backup copy first. Nothing changed. Check that the host's disk has free space, then press Import again.";
  - a choice the host now refuses (400; the host checks again when it saves, and a contact changed in myContacts meanwhile can change a card's status): Review is read again and the line says "Some contacts changed in myData while you were reviewing. Check the review again, then press Import.";
  - the preview is gone (404): Review's "Expired" state (States).
- The host checks everything again when it saves, so Done shows the result the host returns, never the preview's counts.

## 4. Done

- The title says what happened, from the result's `counts.created`: "Imported 125 contacts into myData" ("Imported 1 contact into myData"; "Updated 3 contacts in myData" when nothing was created).
- A GroupedList says the rest, one row each, only when not empty: "3 updated" (`updated`); "6 kept as yours, the iCloud copies hidden" (`linked`); "8 already in myData were left out" (skipped by choice); "2 cards could not be read" (with "Show which", opening the loss report as it was); "3 possible duplicates were imported as separate contacts", caption "Merge them in myContacts if they are the same person."; "1 was not written: it changed in myData while you were reviewing" (`conflicts`, by name); "4 imported before are not in this file any more; they stay" (`missing`).
- **Buttons,** under the list (Decisions, 9): "Open in myContacts" (filled, only when myContacts is installed; it opens `mycontacts://contacts`, a new link to the list), "Undo import" (tonal, opens the Dialog in 5) and "Import more" (plain, back to Choose). Without myContacts the filled button is "Import more".
- **When the import was a copy of a followed account** (`stop_following` in the result), a GroupedSection follows (Decisions, 6: following goes on unless the user stops it here or in Settings), titled with a question in `heading`: "Keep following the iCloud account ava@example.org?" Its body, in `body`, from the result's numbers:
  - "myData now shows your imported copy of each contact and hides the one it follows, so each person is found once (in myContacts, in search and in the assistant's answers)."
  - "While you follow the account, a contact that changes in iCloud after today is marked in myContacts. Changes made on your iPhone reach myData only this way until myData can serve your phone itself."
  - `calendars_followed`: "Its 3 calendars are read from this account too, and are not imported yet."
  - `contacts_followed`, when not 0: "6 of its contacts are not on myData (you left them out), so they would leave myData too."; `contacts_linked`: "4 of them are hidden behind contacts of yours, which may lack some of their details."
  - Buttons: "Stop following" (tonal) and "Keep following" (plain). Keep following closes the section; the choice stays in Settings, Sources. Stop following opens Settings' own Dialog for removing an account (`DELETE /accounts/{id}`), with the import's sentences: "Stop following ava@example.org?": "myData stops reading this account. Your 128 imported contacts stay. Its 3 calendars are not imported, so they leave myData; they stay in iCloud. To follow it again you will need its app-specific password." with "Cancel" and "Stop following" (Danger). The sentence about backups ("Copies in your host's backups are kept until 1 October 2027.") comes from `stop_following.backups_kept_until` (H8, built).
  - For a file import there is no such question: the file is not an account.

## 5. Import history and Undo import

- **"Earlier imports"** on the Choose page (`GET /imports`): a GroupedList of ActionRows, newest first.
  - Title: the import's `label`: the file's name, or "Copy of the iCloud account ava@example.org" for `source` `icloud`. Once nothing a file import brought in is left on the host, the host replaces the file's name with "Contacts file, 14 Oct 2026", and the row shows that.
  - Caption: date and counts, in `ink-muted`, from `counts`: "14 Oct 2026. 125 added, 3 updated, 2 could not be read."
  - End: "Undo import" (plain danger, ActionRow's destructive style) while `status` is `committed`. An undone import keeps its row with the inactive chip "Undone" and the caption from what the undo did: "14 Oct 2026. 125 added. Undone 15 Oct 2026: 122 moved to Recently deleted, 3 changed since were kept."
  - The rows are not pressable (ActionRow). The host keeps counts only, not the loss report, so there is no "Show details".
- **Undo import** opens the Dialog "Undo this import?". The host does not say in advance what an undo will do, so the body says the rule, not counts:
  - "Contacts this import added that nobody changed since move to Recently deleted, where you can restore them for 30 days. Contacts it updated go back to how they were. Contacts changed since the import stay as they are."
  - For an account copy: "The iCloud copies it hid show again while you follow the account."
  - "This cannot be undone as a whole; each contact can be restored from Recently deleted."
  - Buttons: "Cancel" and "Undo import" (Danger). Changed contacts always stay (the host has no option to remove them; Decisions, 8).
  - **Afterwards** there is no toast: an undo of an import cannot itself be undone, and Toast is only for what can be. The dialog closes, the history row changes to "Undone" with its counts (`removed`, `reverted`, `kept`), and focus goes to that row; the change is announced politely ("Import undone. 122 contacts moved to Recently deleted; 3 changed since were kept."). When `kept` is not empty, the caption names up to three: "Kept, because they changed since: Ava Fictional, Ben Sample and Cleo Example."
  - Already undone (409, from another window or the command): the row is read again and shows "Undone".
  - Skipped cards were never imported, so nothing of them is touched. Contacts deleted since the import are already in Recently deleted and stay there (`gone`).

## States

| State | What shows |
|---|---|
| Empty (nothing followed, no history) | The DropZone and "Where to get a file" only |
| Loading (reading a file) | The DropZone's reading state: the loading slice, "Reading contacts-2026-10-14.vcf…" and "Cancel"; then Review. A large file takes a while (about 20 s for 44,000 cards) and the host reports no progress |
| Loading (an account copy) | The same in the account's row: "Reading 128 contacts…" in its caption, the button inert |
| Cancel while reading | Choose again at once. The host finishes reading anyway; when its answer comes, the app discards that preview (`DELETE`), so the file's contents are not held for the hour |
| Host not answering, before choosing | The app frame's warning line; the DropZone and the "Import a copy" buttons disabled, with the reason as the DropZone's caption: "The host cannot be reached. Import works when it is running." History shows what was last read, with the time (platforms.md, "Offline and errors") |
| Host not answering, while reading | The DropZone's error: "contacts-2026-10-14.vcf was not read. The host did not answer. Check that it is running, then try again." with "Try again" (tonal), which sends the same file |
| Host not answering, on Import or Undo | The failed line above the footer (above), or the Dialog's failed line (Dialog) |
| Expired (the preview is gone: an hour passed, the host restarted, or it was dropped for newer ones) | Review's lists are replaced by one line: "This review is no longer held by the host. It keeps one for an hour, and not across a restart. Choose the file again." with "Choose file…" (filled) in the footer; for an account copy, "Read the copy again" |
| File too big (413, over 50 MB) | "contacts-all.vcf is 63 MB. myData reads files up to 50 MB. Compress it into a .zip in the Finder and drop that, or export fewer contacts at a time." |
| A zip too big once unpacked, or with too many files | "takeout-2026-10-14.zip would be over 200 MB unpacked, so myData did not open it. Export your contacts on their own instead." / "…has more than 10,000 files in it…" |
| Not a vCard (by extension, before sending) | "notes.txt is not a vCard file. Choose a .vcf file, or a .zip with .vcf files in it." |
| A calendar file (by extension) | "family.ics is a calendar. myData imports contacts for now; calendars come later." |
| A CSV file (by extension) | "outlook-contacts.csv is a CSV file, which myData cannot read yet. Export vCard instead; Where to get a file says how." |
| A folder, or several files | "Contacts is a folder. Drop the file in it instead." / "Drop one file at a time. To bring several, put them in one .zip." |
| A .vcf or .zip the host cannot read at all (400) | The file's name, then the host's sentence, then a next step: "contacts.vcf cannot be imported. No vCard was found in the file. Export it again, or choose another file." (each case has a `code`, H4, built) |
| A zip with nothing usable (400) | "takeout-2026-10-14.zip cannot be imported. The zip holds no vCard (.vcf) file. When you make a Google Takeout archive, include Contacts." |
| No card readable | The preview arrives with every card skipped: the DropZone's error, not Review: "contacts.vcf has 40 cards, and none can be read. It may be damaged; export it again." |

Every message names the file, says what is wrong and gives one next step (platforms.md, "Offline and errors"). No message quotes a card's content beyond a name the host gives, and the host logs none of it (ids, kinds and counts only).

## Keyboard

- **Choose:** Tab reaches "Choose file…" first, then each "Where to get a file" row (Return or Space opens and closes it; its steps are text, not stops), then each "Import a copy" and "Show how", then the history's buttons. ⌘V with a file on the clipboard on this page, while no text field has focus, is the same as dropping it.
- **Review:** Tab goes: the loss report's Checkbox, each list's select-all row, the list (one stop: Up and Down move, Space ticks, ⌘A ticks all, Home and End; Checkbox), then, from the focused row, that row's Compare button, then the next list, then Cancel and Import. ⌘Return presses Import from anywhere on the page while it is enabled. Escape does nothing here: the page is not a holder, and Cancel is a button. Return on a row does not import, so a review is never sent by a stray key.
- **Importing:** nothing to focus; focus stays on the title.
- **Done:** focus moves to the title, then Tab reaches the buttons.
- **Every step change** moves focus to the new title.

## Screen readers

- Each step's title is a heading, announced politely when the step changes ("Review the import").
- The summary rows read as text with their counts. The loss report is a group named by its heading; its Checkbox reads its caption.
- Each list is a group named by its heading and count ("Possible duplicates, 3"). A row's checkbox reads its name, its caption and its state ("Ben Sample, Same name as Ben Sample in myData., checkbox, checked"); the Compare button that follows reads "Compare Ben Sample, button, collapsed".
- The disabled Import button is `aria-disabled` with its reason as its description.
- Importing is a busy progress bar with its label; "Saving to myData" is announced once, and so is the result.
- Errors from the DropZone and the failed line are read at once (assertive), because they answer the user's own action.

## Phone (under 600px)

- Import is the middle tab. The page is one column with `space-4` gutters and the large title. (Phones reach the host only once remote access exists, phase 10; the layout is specified now so the flow is built once.)
- Choose: the DropZone has no drop target on a phone; it is "Choose file…" with its caption, opening the system's file picker (Files on iOS, the system picker on Android).
- Review: the summary, loss report and lists in one column. The footer is a bar at the bottom of the screen, above the tab bar, with the filled "Import 128 contacts" full width and "Cancel" as a plain button in the large title's start. Compare opens a Sheet with the DuplicatePair stacked (DuplicatePair, phone).
- Importing and Done: the same, stacked; the buttons full width.
- The system back gesture on Review is Cancel, on Done is "Import more".

## Copy

- Counts always with their noun, singular for one: "1 contact", "128 contacts", "1 card". The app writes every sentence itself from the host's codes and counts; the host's `message` fields are for logs and the command line.
- "Import" for bringing in; "follow" and "read" for sources (never "sync"); "a copy" for an account import. Never "successfully", never an exclamation mark.
- A vendor's menu names are quoted exactly as the vendor writes them, in the vendor's case, joined with " > ": "File > Export > Export vCard…". myData's own places are written with commas, as elsewhere: "Settings, Sources".
- Owned data is described as the apps describe it: "on myData only, not on your phone yet".
- Card positions count from 1 ("Card 57"), as people count; the host's `index` counts from 0.
- Dates in captions as "14 Oct 2026"; in sentences about backups, "1 October 2027" (Dialog).
- Examples here and in the preview are synthetic: Ava Fictional, Ben Sample, Cleo Example, Dev Placeholder, example.org, 555-01xx.

## What the host gives (built)

- `POST /import/contacts/preview?filename=` (the file's bytes, at most 50 MB; 413 above; 400 with a sentence when it cannot be imported at all) and `POST /import/contacts/from-source/{account}/preview` (an iCloud account; 409 for This Mac) return the preview: `id`, `expires_at` (an hour), `source`, `label`, `counts`, `losses` and `changes` (each `code`, `count`, `entries`), `needs_acceptance`, `missing`, `stop_following`, and `items` (per card: `index`, `kind`, `display_name`, `status`, `reason`, `action`, `choices`, `converted_from`, `entry`, `matches` with `display_name`, `source`, `strength`, `signals`, `contact_id`). A skipped card has no name.
- `GET` and `DELETE /import/previews/{id}`: read again as the host is now, or discard. Only the app that made a preview can see it (another gets 404). The host holds at most four, the oldest dropped first.
- `POST /import/previews/{id}/commit` with `choices` (only those differing from the defaults), `accept_losses` and `address_book_id` (left out: the host's "myData" book, made if missing): the snapshot, then one transaction. 201 with the import (`counts` with `created`, `updated`, `linked`, `not_written`, `groups_created`; `conflicts`; `missing`; `stop_following`); 400 for losses not accepted or a refused choice; 404 when the preview is gone; 503 when the snapshot failed.
- `GET /imports` (the history: `label`, `source`, `started_at`, `status` committed or undone, `undone_at`, `counts`) and `POST /imports/{id}/undo` (no options; `removed`, `reverted`, `unlinked`, `kept` by name, `gone`, `groups_removed`; 409 when already undone).
- Every import route needs `contacts:import` (H5), held by myData and the `mydata` command only; myContacts, myCalendar, myAssistant and agent tokens get 403. Nothing imported is logged: the host logs ids, kinds and counts only.
- Built on: GroupedSection, GroupedList, ActionRow, Checkbox, Notice, ProgressBar, Dialog, Button, and the new DropZone and DuplicatePair.

## Host gaps this spec needed (all built, 2026-10-14)

Kept as the record of what the UI relies on; `docs/decisions/2026-10-14-contacts-editing-and-import.md`, "Importing contacts", says how each was built.


- **H1 (built). A file import hid no followed copy.** Shadowing is matched by account and UID and only for an account copy; a file's origins never hide anything. On the main path (a Contacts on a Mac export with This Mac on) every imported person is then listed twice and `find_contact` returns two, against the owner's "one result per person". Needed: on a file import, a followed card with a strong match (the same name and the same email or phone, emails normalised and phones in E.164; `followed_matches`) is hidden behind the imported copy, recorded as an origin of that followed card (account and UID), undone with the import, so each person is one result in myContacts and `find_contact`. Built before the import UI ships (Decisions, 7). Test it with a synthetic iCloud account also on the Mac: an account copy hides only the iCloud copies, and H1's match hides This Mac's copies of the same people too.
- **H2 (built). No signal for a Contacts on a Mac export without notes.** The biggest silent loss on the main path. Needed: a `no_notes` note when the file says it was made by Apple's Contacts (PRODID) and no card has a NOTE, in `losses`, so `needs_acceptance` is set and the tick is needed (Decisions, 4).
- **H3 (built). No card values in the preview,** so Compare cannot show "In the file". Needed: `GET /import/previews/{id}/items/{index}` returning the card's fields in the shape of a contact (`ContactDetailOut`'s fields), never logged.
- **H4 (built). A whole-file refusal (400) had no `code`,** only a sentence, so the app cannot write its own copy per case. Needed: `code` (`too_big`, `zip_too_big`, `zip_too_many`, `zip_unreadable`, `zip_no_vcard`, `no_vcard`, `utf16_unreadable`) beside the message.
- **H5 (built). A `contacts:import` scope** (Decisions, 2) on the eight import routes (the two previews, reading and discarding a preview, a preview card's values, commit, the history and undo), granted to myData and the `mydata` command only, and only with `contacts:read`. myContacts keeps `contacts:write` (its edits and `POST /contacts/merge`) and loses the import routes.
- **H6a to H6d, H7 (built):** possible duplicates, "not the same person", the merge preview, a merged original's `merged_into`, and "changed since import" (DuplicatePair, "Host gaps"). H6c comes before Merge ships; the Review section waits for H6a and H7.
- **H8 (built). When backups stop holding an account's copies** was not in the API (`backup.kept_until` exists, but only Recently deleted's items carry it). Needed for the Stop following dialog, and already for Settings' remove dialogs (CLAUDE.md).

## Decisions

The owner's choices on this spec, each the rule above.

1. **Decided 2026-10-14:** import is a third myData section, "Import" (not inside Settings, Sources, and not a broader "Your data").
2. **Decided 2026-10-14:** myContacts' File > Import… opens myData (`mydata://import/contacts`), and import moves to its own scope, `contacts:import`, for myData and the command only (H5); myContacts has no import of its own.
3. **Decided 2026-10-14:** losses are accepted with the Checkbox "Import without what is listed above", which sends `accept_losses` (not a button label that names them).
4. **Decided 2026-10-14:** build H2; a Contacts on a Mac export with no notes is a `no_notes` loss that needs the tick.
5. **Decided 2026-10-14:** one file per import, each with its own Undo; several files go in one .zip.
6. **Decided 2026-10-14:** after importing a followed account, following goes on by default ("Keep following" plain, "Stop following" tonal): stopping also removes its calendars and drops its app-specific password, and the "changed since import" mark is the only way iPhone edits reach myData until the phone can use the host.
7. **Decided 2026-10-14:** build H1 before the import UI ships: a file import hides a followed copy with the same name and the same email or phone (normalised; E.164 for phones), so each person is one result in myContacts and `find_contact`.
8. **Decided 2026-10-14:** Undo import always keeps contacts changed since the import; the dialog has no option to remove them.
9. **Decided 2026-10-14:** Done's main button is "Open in myContacts" (filled), with "Undo import" tonal.
