Two versions of a contact side by side, with the fields that differ marked, so the user can tell whether they are the same person and what merging them gives. One component, three uses: comparing during an import, merging two contacts, and reviewing a contact that changed in a followed account after it was imported.

**Status: decided 2026-10-14** (phase 4; the owner's review, "Decisions", at the end). The host has built merge (`POST /contacts/merge`, undone with `POST /undo/{id}`) and the "changed since import" flag on a contact (`changed_in_source`). Since then it has built the list of possible duplicates, "not the same person", the merge preview, a card's values in an import preview and a way to read and settle a followed change (host gaps at the end, numbered as in ImportFlow's H1 to H8, all built 2026-10-14); each use below says which it relies on. **Built first:** Merge from a multi-selection in myContacts, once the merge preview (H6c) exists, and the flag's Notice without its Review button. The Review section comes after H6a and H7.

## Uses

| Mode | Where | Columns | Actions | Host |
|---|---|---|---|---|
| **Compare** (read-only) | myData, Import, Review: under a duplicate row, after "Compare" (ImportFlow) | "In the file", "In myData" | None. The row's checkbox decides | H3 (the file's values), built |
| **Merge** | myContacts: Edit > Merge Contacts… for two to twenty selected contacts (first, with H6c); later the Review section's "Possible duplicates" | The contacts, then "After merging" | "Merge" (filled); "Not the same person" (plain) only in Review | Built: Merge, the list (H6a), "Not the same person" (H6b), "After merging" (H6c) |
| **Changes** | myContacts, the Review section, "Changed since import", and the contact page's Notice | "In myData", "In iCloud now", then "After" | "Save changes" (filled), "Keep mine" (plain) | H7, built |

Only contacts myData owns are merged or changed. A followed contact is never one side of a merge (the host refuses it): a followed copy of an imported contact is hidden by the shadowing rule (plan 2(a)), not offered as a duplicate.

## Anatomy

- **One card** (`surface`, `radius-lg`, `shadow-1`), never a card per contact: never a card on a card. Inside, a grid with a label column (`label` style, `ink-muted`, 84px) and one column per version, `space-4` apart, `space-5` padding across.
- **Header row:** for each version, a 36px Avatar, the name in `body-strong` and a short `caption` in `ink-muted` saying how it came and when: "Added 2 Oct 2026", "Imported 14 Oct 2026", "Changed in iCloud 20 Oct 2026". The longer story is the line under the pane's title, so the columns stay narrow: "They share an email address." A 1px `line` under the header row. The "After merging" column's caption says what happens to the two: "A new contact. These two go to Recently deleted."
- **Field rows,** grouped by kind in the contact page's order (Name, Company, Job title, Phone, Email, Address, Birthday, Links, Notes, Photo), one row per kind, each value on its own line in its column, with its label ("mobile", "work") in `caption` before it, as FieldRow writes them. A side with no value shows "None" in `ink-muted`.
- **Differences are marked by a word and a band.** A row whose values differ (after normalising: case of emails, E.164 phones, spacing) has a `surface-sunken` band across the whole row, `radius-sm`, and its label gains a second line, "Differs", in `caption` and `ink`. A value present on one side only counts as a difference. The band is never the only sign: "Differs" is read and seen in every theme. Matching values are not marked.
- **Same values are shown once in Compare and Changes only when the user asks:** by default those two modes show only the rows that differ, with a plain "Show all fields" (and "Show differences only") under the grid, because what the user decides on is the difference. Merge shows every field, because the result is a whole contact.
- **Merge's one choice: whose details to keep.** Above the grid, a Select labelled "Keep the name and details of", listing the contacts by name, each item with a caption ("Added 2 Oct 2026"). It is the host's `names_from`: the merged contact starts as a copy of that one. The default is the contact changed most recently (Decisions, 2).
- **"After merging" column** (from 900px of content width; under it, a separate group titled "After merging", with the same rows), in `ink`, following the host's rules for a merge:
  - **Lists** (phones, emails, addresses, links) are joined: every value from every contact, once each after normalising, the kept one's first. Nothing on a list is dropped.
  - **Single values** (name, company, job title, birthday, photo) come from the kept contact. A value only another contact has is taken. A different value another contact has is **left out**: the cell shows the kept value, and under it, in `caption` and `ink-muted`, "Left out: 18 March 1990", so nothing goes without being seen. Choosing the other contact in the Select swaps them.
  - **Notes** are kept, one after the other: "Both notes, one after the other."
  - What is left out stays in the originals in Recently deleted, until they are deleted for good (30 days); the line under the grid says so: "What is left out stays with the originals in Recently deleted for 30 days."
  - **The column is the host's word for it (H6c, a merge preview),** never worked out by the app (no business logic in the app). Merge does not ship without it, so the user sees exactly what is kept and left out before pressing Merge (Decisions, 3). It is read again when the Select changes. While it is being read, the column shows the Loading state.
- **Actions** under the card, at the end edge, `space-2` apart: the plain one, then the filled one. In Merge: "Not the same person" (Review only), "Merge". In Changes: "Keep mine", "Save changes".

## What the actions do

- **Merge** (myContacts; `POST /contacts/merge` with each contact's id and the etag the user saw, in order, and `names_from`): one transaction on the host. It makes **a new contact** and moves the originals to Recently deleted, where restoring one on its own takes it out of the merge. The new contact has a new id, so links to the originals (`mycontacts://contact/<id>`) open them in Recently deleted (following them to the merged contact uses their `merged_into`, H6d). After it, the merged contact is selected and a Toast says "Contacts merged" with Undo; when the host reports something left out (`left_out`, property names and counts only), the toast says it too, in words: "Contacts merged. 1 birthday and 1 job title were left out." Undo (`POST /undo/{undo_id}`) puts the originals back exactly as they were and moves the merged contact to Recently deleted. Edit, Undo names it "Undo Merge Contacts". As with every undo, a merged contact edited since cannot be unmerged: "Not undone. Ava Fictional was changed after that." (Toast). In the Review list the pair leaves the list and selection moves to the next pair.
- **Not the same person** (H6b): the host records that these two are different people, so the pair is never suggested again, even after another import, until the user undoes it (Decisions, 5). Toast "Marked as different people" with Undo. Nothing on either contact changes.
- **Save changes** (Changes, H7): writes the "After" column into myData's copy as a new revision, as an edit in myContacts would (If-Match; Undo toast "Changes saved"), and clears the "changed since import" mark until the followed copy changes again. A value the user kept from myData's side stays.
- **Keep mine** (H7): clears the mark without changing the contact. Toast "Kept your version" with Undo, which brings the mark back.
- Three or more contacts are merged in one go from a multi-selection (the host takes up to twenty); in the Review list, a third is offered as a new pair once the first two are one.

## Merge from a multi-selection (built first, with H6c)

- In myContacts' Contacts, with two to twenty owned contacts selected (MultiSelect), Edit > Merge Contacts… (and the selection's Menu, and "More actions" on a phone) opens the Merge pane in the detail pane's place: the title "Merge 2 contacts?", the Select, the grid of the contacts with "After merging", and "Merge" with "Cancel" (plain) instead of "Not the same person".
- Disabled, with its reason: one contact selected ("Select two or more contacts to merge."), a followed contact among them ("Ava Fictional is read from this Mac. Only contacts on myData can be merged."), more than twenty ("Merge at most 20 contacts at a time.").
- A contact changed since it was shown (412): the pane reads them again and says "Ben Sample changed while you were looking. This is the new version." Nothing is merged on old data.

## The Review section in myContacts (after H6a and H7)

- A third sidebar section, **"Review"**, after Contacts and Recently deleted (View: Contacts ⌘1, Recently Deleted ⌘2, Review ⌘3), so the keys already built do not move. On a phone, a third tab.
- It is a list and a detail pane, as Contacts is. The list has two groups, each left out when empty:
  - **"Possible duplicates (3)":** one row per pair, titled with both names ("Ava Fictional and Ava M. Fictional"), and a caption with the reason: "Same email: ava@example.org", "Same phone: 555-0142", "Same name". Strong reasons (email, phone) come first, then names alone.
  - **"Changed since import (1)":** one row per contact whose followed copy changed after the import, titled with the name, caption "Changed in the iCloud account ava@example.org" (the host gives the account, `changed_in_source_label`, not the day). Only while the account is still followed (ImportFlow, Done).
- The detail pane is the DuplicatePair for the selected row, in Merge or Changes mode, under a title in `display-lg` that names the question: "Same person?" (Merge) or "Changed in iCloud" (Changes).
- **Empty:** the pane and list are replaced by a centred title "Nothing to review" and one sentence in `ink-muted`: "When two contacts look like the same person, or a contact changes in an account myData follows, it shows here." There is no button, so it is not an EmptyState (which always has one) and has no kiwi.
- **The count** shows in the section's title ("Review, 4") and in the sidebar as a count after the label, in `caption` and `ink-muted`; a number alone, never a red badge.
- H6a and H7 are built; until the section itself is, Merge lives in Edit, and the changed contacts are found by their Notice.

## The contact page flag ("changed since import")

- On a contact page (myContacts), between the ContactHeader and the fields, a Notice (`info`), shown when the contact's `changed_in_source` is set: "This contact changed in the iCloud account ava@example.org after you imported it." (`changed_in_source_label`). Once the Review section exists (H7 is built), it ends in a plain button "Review", which opens the Review section on that contact (Changes mode); until then it has no button and adds: "Its changes are not shown here yet; you can see them in Contacts on your Mac or iPhone." On a phone, the same Notice under the header.
- In the contact list, the row's caption is unchanged and there is no mark; the Notice is on the page only, so the list stays calm (Decisions, 4).
- The Notice goes when the user saves the changes or keeps theirs (H7), or stops following the account.

## States

- **Loading** (a pair being read): the card at its final height with the header row's names and grey bars where values will be, for at most a moment; no spinner.
- **Merging, saving:** as Dialog's working state: focus stays on the pressed button, whose label becomes "Merging…" or "Saving…" at its old width; the Select is read-only, the buttons inert.
- **Failed:** a line in `danger` above the buttons: "The contacts were not merged. The host did not answer. Check that it is running, then try again." Focus goes to the button that was pressed.
- **Changed elsewhere** (a side changed after the pair was shown; the host refuses with 412): the pair is read again and shown with a line in `body` and `ink` above the buttons: "Ben Sample changed while you were looking. This is the new version." The user decides again; nothing is merged on old data.
- **The other side is gone** (deleted, or merged elsewhere; 404): the row leaves the list and the pane says "This pair is no longer a duplicate: Ben Sample was deleted." with no actions.
- Controls have their own states (Select, Button).

## Keyboard

- In Compare, the card is text; the only stops are "Show all fields" and the row's "Hide comparison".
- In Merge, Tab goes to the Select, then the plain button, then the filled one; in Changes, through each Select in the "After" column, then the buttons. ⌘Return presses the filled one while focus is in the pane and no Select is open. "Not the same person", "Cancel" and "Keep mine" have no key; Escape in the multi-selection Merge pane is Cancel (platforms.md, "Which handler gets a key first": an open Select takes it first).
- In the Review list: Up and Down move between rows (ContactList), Return moves focus to the pane's Select.
- ⌘Z undoes the last merge, marking or save, as Edit, Undo (platforms.md, "Which handler gets a key first").

## Screen readers

- The grid is a table: the header row's cells are column headers ("Ava Fictional, added 2 Oct 2026"), each row's label a row header. A differing row reads its label, "Differs", then each value with its column ("Phone, Differs. Ava Fictional: mobile 555-0142. Ava M. Fictional: mobile 555-0142, work 555-0177. After merging: mobile 555-0142, work 555-0177"). A left-out value reads after the kept one: "Birthday, Differs. … After merging: 18 March. Left out: 18 March 1990."
- The pane's title is a heading and is announced when a pair is selected.
- Toasts are polite (Toast); a failure line is assertive.

## Phone (under 600px)

- The versions are stacked, not side by side: a SegmentedControl at the top switches between them ("Ava Fictional", "Ava M. Fictional"), and a third segment shows "After merging". Rows that differ keep their band and "Differs" in every segment. The Select sits above the segments. In Compare (import, in a Sheet) there are two segments.
- The buttons are a bar at the bottom: the filled one full width, the plain one under it.
- The Review section's list is its own screen; a row pushes its pair.

## Light and dark, Kiwi and Graphite

Only tokens. The band is `surface-sunken` inside a `surface` card: a darker strip in light mode and a darker strip in dark mode (`surface-sunken` is near black), with the word carrying the meaning in every theme. Only the filled button takes the theme's colour.

## Copy

- Column headers are the contacts' names; their captions say where and since when, with dates as "14 Oct 2026".
- The question is "Same person?", the answers "Merge" and "Not the same person". Never "duplicate" in a button; "Possible duplicates" is the list's name.
- What the host leaves out is named by kind in words, never by vCard property: BDAY "birthday", TITLE "job title", PHOTO "photo", ORG "company", NICKNAME "nickname", anything else "other detail".
- Toasts: "Contacts merged", "Contacts merged. 1 birthday was left out.", "Marked as different people", "Changes saved", "Kept your version".
- Examples are synthetic: Ava Fictional, Ava M. Fictional, Ben Sample, example.org, 555-01xx.

## For implementers

- Built: `POST /contacts/merge` (`contacts:write`; 2 to 20 owned contacts with their etags, in order; `names_from`; 201 with the merged `contact`, `merged` ids, `undo_id` and `left_out`; 409 for a followed contact, 412 for a stale etag, 404 for one gone). `POST /undo/{undo_id}` undoes it once, while nothing changed since. `changed_in_source` and `changed_in_source_label` on a contact.
- Matching (plan 3.5, step 5): exact normalised email or E.164 phone, under the same name, is strong; a name alone, or a number shared under another name, is a suggestion; nothing is merged without the user's press.
- Built on: GroupedSection's card, Avatar, FieldRow's labels, Select, Button, SegmentedControl, Toast, Notice, MultiSelect.
- You provide the versions, their captions, the mode, and what each action does.

## Host gaps

Numbered with ImportFlow's list (H1 to H8); H1, H2, H4, H5 and H8 concern the import only. All are built (2026-10-14); the import routes need `contacts:import` (myData and the command only), while merging, "not the same person" and settling a followed change need `contacts:write` (myContacts too).

- **H3 (built).** An import preview's card values (`GET /import/previews/{id}/items/{index}`), for Compare (ImportFlow).
- **H6a (built).** `GET /contacts/duplicates`: pairs of owned contacts with their reason and strength, for the Review list.
- **H6b (built).** `POST /contacts/not-duplicates` (both ids), kept on the host, honoured by later imports and the list, undoable.
- **H6c (built).** A merge preview (`POST /contacts/merge/preview`): the merged contact and `left_out` with the values' kinds, written nowhere, for the "After merging" column.
- **H6d (built).** A merged original's `merged_into` on `GET /contacts/{id}`, so a link to it can open the merged contact.
- **H7 (built).** For "changed since import": the followed copy's values beside the owned one (`GET /contacts/{id}/followed-changes`), and a way to settle it (`POST /contacts/{id}/followed-changes/save` with the chosen values, If-Match, clearing the mark; or `.../keep`, clearing it alone; both undoable).

## Decisions

The owner's choices on this spec, each the rule above.

1. **Decided 2026-10-14:** Merge from a multi-selection is built now; the "Review" section, third and last in myContacts (⌘3), holding possible duplicates and changes since import, is built after H6a and H7.
2. **Decided 2026-10-14:** a merge keeps the name and details of the contact changed most recently by default (`names_from`).
3. **Decided 2026-10-14:** build H6c before Merge ships, so "After merging" shows what is kept and left out before the press.
4. **Decided 2026-10-14:** no mark in the contact list for a contact changed since import; the Notice on its page (and later the Review section) is enough.
5. **Decided 2026-10-14:** "Not the same person" is permanent until undone: kept on the host and honoured by later imports.
