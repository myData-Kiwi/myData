import 'package:mydata_core/mydata_core.dart';

import '../format.dart';
import '../sources_section.dart';

/// Every sentence the Import section says (design/components/ImportFlow and DropZone). The app writes each
/// one itself from the host's codes and counts; the host's `message` fields are for logs and the command
/// line. Counts always with their noun, singular for one.
abstract final class ImportText {
  // ------------------------------------------------------------------------------------------------------
  // Words that count.
  // ------------------------------------------------------------------------------------------------------

  /// "1 contact", "128 contacts", "1,204 cards".
  static String count(int n, String one, [String? many]) => '${grouped(n)} ${n == 1 ? one : (many ?? '${one}s')}';

  /// 1204 as "1,204".
  static String grouped(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// "Ava Fictional", "Ava Fictional and Ben Sample", "Ava Fictional, Ben Sample and Cleo Example", then
  /// "… and 9 more" past three.
  static String names(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.single;
    if (names.length <= 3) return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }

  // ------------------------------------------------------------------------------------------------------
  // The section and its steps.
  // ------------------------------------------------------------------------------------------------------

  static const section = 'Import';
  static const chooseTitle = 'Import contacts';
  static const reviewTitle = 'Review the import';
  static String importingTitle(int n) => 'Importing ${count(n, 'contact')}';

  static const fromFile = 'From a file';
  static const instruction = 'Drop a .vcf or .zip file here';
  static const caption = 'A vCard file (.vcf) from Apple, Google or Samsung, or a .zip of them. Up to 50 MB.';
  static const hostDown = 'The host cannot be reached. Import works when it is running.';

  /// Why a file cannot be chosen, or another copy read, while an account's copy is being read.
  static const accountBeingRead = 'A copy of an account is being read. Choose a file when it is done.';
  static const copyBeingRead = 'This copy is being read.';
  static const anotherBeingRead = 'Another import is being read. Try again when it is done.';

  /// A drop that delivered no file (a promised file the app it came from did not hand over).
  static const dropEmpty = 'The file could not be taken from where it was dragged. Save it to a folder first, '
      'then drop it here or choose it.';

  /// The system's file chooser did not open.
  static const chooserFailed = 'The file chooser did not open. Try again, or drop the file here.';

  static const whereHeading = 'Where to get a file';
  static const fromAccountHeading = 'From an account myData follows';
  static const historyHeading = 'Earlier imports';

  static const importCopy = 'Import a copy';
  static const showHow = 'Show how';
  static const macNotImportable =
      'A copy from this Mac would be incomplete: myData does not read notes from it. Export a vCard from '
      'Contacts instead (Contacts on a Mac, above).';

  /// "The iCloud account ava@example.org".
  static String account(String? email) => email == null ? 'The iCloud account' : 'The iCloud account $email';

  /// "128 contacts, as of today at 09:12".
  static String accountCaption(int contacts, String? lastUpdate, {DateTime? now}) {
    final when = lastUpdate == null ? null : asOf(lastUpdate, now: now ?? DateTime.now());
    return when == null ? count(contacts, 'contact') : '${count(contacts, 'contact')}, as of $when';
  }

  /// "today at 09:12", "yesterday at 18:40", "12 Oct 2026 at 08:05".
  static String? asOf(String iso, {required DateTime now}) {
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}';
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'today at $time';
    if (day == today.subtract(const Duration(days: 1))) return 'yesterday at $time';
    return '${formatDay(t)} at $time';
  }

  static String readingAccount(int contacts) => 'Reading ${count(contacts, 'contact')}…';
  static const accountNotRead =
      'The copy was not read. The host did not answer. Check that it is running, then try again.';

  // ------------------------------------------------------------------------------------------------------
  // Where to get a file: the vendors' own menu names, quoted exactly (marked unverified in the spec).
  // ------------------------------------------------------------------------------------------------------

  static const places = <Place>[
    Place(
      'Contacts on a Mac',
      [
        'In Contacts, choose Contacts > Settings > vCard, and turn on “Export notes in vCards” and “Export photos '
            'in vCards”.',
        'Select all contacts (⌘A in the list).',
        'Choose File > Export > Export vCard…, and save the file.',
        'Drop it here.',
      ],
      after: 'This covers every account on this Mac: iCloud, Google, Exchange and On My Mac.',
    ),
    Place(
      'iCloud on the web',
      ['On icloud.com, open Contacts.', 'Select all contacts.', 'Choose Export vCard… from the actions menu.'],
      after: 'Use this on a computer that is not a Mac.',
    ),
    Place(
      'Google',
      ['Open contacts.google.com.', 'Choose Export, then “vCard (for iOS Contacts)”, and export.'],
      after: 'Google CSV and Outlook CSV are not read yet; choose vCard. A Google Takeout .zip works too, when it '
          'includes Contacts.',
    ),
    Place(
      'Samsung Galaxy',
      [
        'In Contacts, open the menu, then Manage contacts > Import or export contacts > Export.',
        'Send the .vcf file to this computer.',
      ],
      before: 'Best: move the contacts to your Google account on the phone (Contacts > Manage contacts > Move '
          'contacts), then export from Google. Otherwise:',
      after: 'Samsung’s file has no groups or categories.',
    ),
    Place(
      'Outlook',
      [],
      before: 'Outlook.com exports contacts only as a CSV file, which myData cannot read yet. If your Outlook '
          'account is added to this Mac (System Settings > Internet Accounts), export it from Contacts on the Mac '
          'instead.',
    ),
  ];

  // ------------------------------------------------------------------------------------------------------
  // Files checked before sending, and the host's refusals (H4).
  // ------------------------------------------------------------------------------------------------------

  static const severalFiles = 'Drop one file at a time. To bring several, put them in one .zip.';
  static String folder(String name) => '$name is a folder. Drop the file in it instead.';
  static String calendar(String name) => '$name is a calendar. myData imports contacts for now; calendars come later.';
  static String csv(String name) =>
      '$name is a CSV file, which myData cannot read yet. Export vCard instead; Where to get a file says how.';
  static String notVcard(String name) =>
      '$name is not a vCard file. Choose a .vcf file, or a .zip with .vcf files in it.';
  static String tooBig(String name, int bytes) =>
      '$name is ${(bytes / (1024 * 1024)).ceil()} MB. myData reads files up to 50 MB. Compress it into a .zip in the '
      'Finder and drop that, or export fewer contacts at a time.';
  static String notRead(String name) =>
      '$name was not read. The host did not answer. Check that it is running, then try again.';
  static String noneReadable(String name, int cards) =>
      '$name has ${count(cards, 'card')}, and none can be read. It may be damaged; export it again.';
  static String unreadable(String name) =>
      '$name could not be read on this computer. Check that the file is still there, then try again.';

  /// The sentence for a whole file the host refused, by its `code` (H4).
  static String refused(String name, String? code, {int? bytes}) => switch (code) {
        'too_big' => tooBig(name, bytes ?? 50 * 1024 * 1024 + 1),
        'zip_too_big' =>
          '$name would be over 200 MB unpacked, so myData did not open it. Export your contacts on their own '
              'instead.',
        'zip_entry_too_big' =>
          '$name holds a file that would unpack far larger than any vCard, so myData did not open it. Export '
              'your contacts on their own instead.',
        'zip_too_many' =>
          '$name has more than 10,000 files in it, so myData did not open it. Export your contacts on their own '
              'instead.',
        'zip_unreadable' => '$name cannot be imported. The zip could not be opened; it may be damaged. Make it '
            'again, or choose another file.',
        'zip_no_vcard' => '$name cannot be imported. The zip holds no vCard (.vcf) file. When you make a Google '
            'Takeout archive, include Contacts.',
        'utf16_unreadable' => '$name cannot be imported. Its text could not be read as the file says it is '
            'written. Export it again, or choose another file.',
        _ => '$name cannot be imported. No vCard was found in the file. Export it again, or choose another file.',
      };

  // ------------------------------------------------------------------------------------------------------
  // Review.
  // ------------------------------------------------------------------------------------------------------

  /// "contacts-2026-10-14.vcf: 140 cards." / "takeout.zip: 3 vCard files, 212 cards." / "A copy of the
  /// iCloud account ava@example.org: 128 contacts."
  static String readLine(ImportPreviewOut p, {required int vcardFiles, String? email}) {
    if (p.source_ == 'icloud') return 'A copy of ${_theAccount(email)}: ${count(p.counts.contacts, 'contact')}.';
    final files = vcardFiles > 1 ? '${count(vcardFiles, 'vCard file')}, ' : '';
    return '${p.label}: $files${count(p.counts.cards, 'card')}.';
  }

  static String summaryNew(int n) => count(n, 'new contact');
  static const summaryNewCaption = 'Imported.';
  static String summaryDuplicates(int n) => count(n, 'possible duplicate');
  static const summaryDuplicatesCaption = 'Imported as separate contacts unless you untick them below.';
  static String summaryUpdates(int n) => '${grouped(n)} changed since your last import';
  static const summaryUpdatesCaption = 'Your copies are updated unless you untick them below.';
  static String summaryAlready(int n) => '${grouped(n)} already in myData';
  static const summaryAlreadyCaption = 'Not imported again unless you tick them below.';
  static const summaryLinkedCaption = 'Kept as your contacts; the iCloud copies are hidden.';
  static String summaryConflicts(int n) => '${grouped(n)} not updated';
  static const summaryConflictsCaption =
      'You changed your copy since the last import, so the file’s version is not used.';
  static String summarySkipped(int n) => '${count(n, 'card')} cannot be read';
  static const summarySkippedCaption = 'Not imported. See below.';

  static const lossHeading = 'What this import will not bring';
  static const acceptLabel = 'Import without what is listed above';
  static const acceptFirst = 'Tick “Import without what is listed above” first, or choose another file.';

  /// One unreadable card's row: "Card 57 ends before END:VCARD; the file may be cut short."
  static String skippedCard(ImportItemOut item) {
    final card = 'Card ${grouped(item.index + 1)}${item.entry == null ? '' : ' in ${item.entry}'}';
    return switch (item.reason) {
      'no_end' => '$card ends before END:VCARD; the file may be cut short.',
      'version' => '$card is a vCard version myData does not read.',
      'empty' => '$card is empty.',
      'too_large' => '$card is far larger than a contact (over 8 MB).',
      _ => '$card could not be read as a vCard.',
    };
  }

  static String tooMany(int n) => 'The ${count(n, 'card')} after the first 50,000 are not read.';
  static String showMore(int n) => 'Show $n more';

  /// A loss that is not one card, by its `code`; null for the per-card codes.
  static String? loss(ImportNoteOut note) {
    final n = note.count;
    return switch (note.code) {
      'guessed_charset' => '${count(n, 'card')} did not say how ${n == 1 ? 'its' : 'their'} letters are written, so '
          'myData guessed (Windows-1252). Some letters may be wrong; each card’s original is kept with the import.',
      'outside_text' => '${count(n, 'line')} of text ${n == 1 ? 'is' : 'are'} outside any card. A card whose first '
          'line is misspelt (BEGIN:VCARD) would be among them.',
      'unreadable_entry' => 'In the zip, ${_entries(note.entries, n)} hold${note.entries.length == 1 && n == 1 ? 's' : ''} '
          'no card myData can read.',
      'nested_zip' => '${count(n, 'zip')} inside the zip ${n == 1 ? 'is' : 'are'} not opened.',
      'encrypted' => '${count(n, 'encrypted file')} in the zip ${n == 1 ? 'is' : 'are'} not read.',
      'unsupported_compression' =>
        '${count(n, 'file')} in the zip ${n == 1 ? 'is' : 'are'} compressed in a way myData does not read.',
      'no_notes' => 'None of the ${count(n, 'card')} has a note. Contacts on a Mac leaves notes out unless “Export '
          'notes in vCards” is on. If your contacts have notes, export again with it on.',
      'skipped_too_many' => tooMany(n),
      _ => null,
    };
  }

  static String _entries(List<String> entries, int n) {
    if (entries.isEmpty) return count(n, 'file');
    final shown = entries.take(3).toList();
    final rest = n - shown.length;
    final listed = shown.length == 1 ? shown.single : '${shown.sublist(0, shown.length - 1).join(', ')} and ${shown.last}';
    return rest > 0 ? '${shown.join(', ')} and ${count(rest, 'more file')}' : listed;
  }

  /// The caption under the checkbox: what it covers.
  static String acceptCaption({required int skipped, required bool noNotes}) {
    final parts = [
      if (skipped > 0) '${count(skipped, 'card')} ${skipped == 1 ? 'is' : 'are'} not imported.',
      if (noNotes) 'No notes are imported.',
    ];
    return parts.isEmpty ? 'What is listed above is not imported.' : parts.join(' ');
  }

  static const changesHeading = 'Changed on the way in';

  /// A change that loses nothing, by its `code`.
  static String change(ImportNoteOut note) => switch (note.code) {
        'converted_21' => '${count(note.count, 'card')} ${note.count == 1 ? 'is' : 'are'} vCard 2.1 (Samsung). '
            '${note.count == 1 ? 'It is' : 'They are'} stored as vCard 3.0 so ${note.count == 1 ? 'it' : 'they'} can '
            'be edited; nothing in ${note.count == 1 ? 'it' : 'them'} is lost, and each original is kept.',
        'declared_charset' => 'Some cards were not written in UTF-8. They are read in the character set each one names.',
        'other_files' => '${count(note.count, 'other file')} in the zip ${note.count == 1 ? 'is' : 'are'} not '
            'contacts and ${note.count == 1 ? 'is' : 'are'} not read.',
        _ => note.message,
      };

  static const whereTheyGo =
      'Into myData, the address book on this host. Imported contacts are on myData only, not on your phone yet.';
  static const firstData = 'This is the first data of your own in myData. Importing ends the demo: myData shows '
      'your contacts instead, and myAssistant starts a new conversation.';
  static String groups(int n) =>
      'This file has ${count(n, 'group')}. They are imported with the contacts, but myContacts does not show '
      'groups yet.';
  static String shadowAccount(int n, String? email) => 'All ${count(n, 'contact')} are read from ${_theAccount(email)} '
      'now. After the import, myData shows your copy and hides the followed one, so each person is found once.';

  /// "the iCloud account ava@example.org" inside a sentence.
  static String _theAccount(String? email) => email == null ? 'the iCloud account' : 'the iCloud account $email';

  /// "42 of these contacts are also read from this Mac. …" [from] is "this Mac", "the iCloud account …".
  static String shadowFile(int n, String from) =>
      '${grouped(n)} of these contacts ${n == 1 ? 'is' : 'are'} also read from $from. After the import, myData '
      'shows your copy and hides the one read from $from, so each person is found once.';

  static String filesHeading(int n) => 'Files in the zip ($n)';
  static String fileRow(String entry, int cards) => '$entry, ${count(cards, 'card')}';

  static String duplicatesHeading(int n) => 'Possible duplicates ($n)';
  static const duplicatesNote =
      'Ticked ones are imported as separate contacts. You can merge them later in myContacts.';
  static String updatesHeading(int n) => 'Changed since your last import ($n)';
  static const updateCaption = 'Changed in the file since you imported it. Ticking it updates your copy.';
  static String alreadyHeading(int n) => 'Already in myData ($n)';
  static String leftOutLine(int unchanged, int inFile) {
    final parts = [
      if (unchanged > 0) '${grouped(unchanged)} unchanged since you imported this file',
      if (inFile > 0) '${grouped(inFile)} repeated in it',
    ];
    if (parts.isEmpty) return '';
    return parts.length == 1
        ? '${parts.single[0].toUpperCase()}${parts.single.substring(1)} ${unchanged + inFile == 1 ? 'is' : 'are'} left out.'
        : '${parts[0][0].toUpperCase()}${parts[0].substring(1)}, and ${parts[1]}, are left out.';
  }

  static String conflictsHeading(int n) => 'Not updated ($n)';
  static String conflict(String? reason) => switch (reason) {
        'merged' => 'It was merged with another contact since.',
        'kept_yours' => 'You kept your own contact instead when you imported it.',
        _ => 'You changed it in myData since the last import.',
      };
  static String newHeading(int n) => 'New contacts ($n)';
  static String allContacts(int n) => 'All ${count(n, 'contact')}';
  static String showAll(int n) => 'Show all ${grouped(n)}';
  static const hideAll = 'Show fewer';
  static String missingHeading(int n) => 'Not in this file any more ($n)';
  static const missingCaption = 'Imported before from this file, and not in it now. They stay in myData; delete them '
      'in myContacts if you no longer want them.';

  static const compare = 'Compare';
  static const hideComparison = 'Hide comparison';
  static const inFile = 'In the file';
  static const inMyData = 'In myData';
  static const compareFailed = 'The comparison could not be read. The host did not answer.';

  /// Compare's "In myData" column when that contact was deleted for good since the review was read.
  static const contactGone = 'No longer in myData: it was deleted for good.';

  /// The caption of a match row, from the match's signals.
  static String matchCaption(ImportItemOut item, ImportMatchOut m, {bool linkDefault = false, bool twoLink = false}) {
    final who = m.displayName;
    if (item.status == 'deleted') {
      return 'Your copy is in Recently deleted. Restore it there, or tick this to import the file’s version as a new '
          'contact.';
    }
    if (twoLink) {
      return 'Two cards in this account match $who; both iCloud copies stay visible. Tick one to import it as well.';
    }
    final s = m.signals.toSet();
    final sameName = s.contains('name');
    final String what;
    if (s.contains('uid') || s.contains('origin') || s.contains('identical')) {
      what = 'The same card as $who in myData.';
    } else if (s.contains('email') && sameName) {
      what = 'Same email and name as $who in myData.';
    } else if (s.contains('phone') && sameName) {
      what = 'Same phone and name as $who in myData.';
    } else if (s.contains('email')) {
      what = m.strength == 'suggestion' ? 'Same email as $who in myData, under another name.' : 'Same email as $who in myData.';
    } else if (s.contains('phone')) {
      what = m.strength == 'suggestion' ? 'Same phone as $who in myData, under another name.' : 'Same phone as $who in myData.';
    } else {
      what = 'Same name as $who in myData.';
    }
    return linkDefault ? '$what Your contact is kept; the iCloud copy is hidden.' : what;
  }

  static const cancel = 'Cancel';
  static String importN(int n) => 'Import ${count(n, 'contact')}';
  static String updateN(int n) => 'Update ${count(n, 'contact')}';
  static String keepN(int n) => 'Keep ${count(n, 'contact')} as yours';
  static const chooseAnother = 'Choose another file';
  static const readCopyAgain = 'Read the copy again';
  static const chooseOne = 'Choose at least one contact to import.';
  static const nothingToImport = 'Nothing in this file needs importing.';
  static const nothingToImportAccount = 'Nothing in this copy of the account needs importing.';

  static const expired = 'This review is no longer held by the host. It keeps one for an hour, and not across a '
      'restart. Choose the file again.';
  static const expiredAccount = 'This review is no longer held by the host. It keeps one for an hour, and not '
      'across a restart. Read the copy again.';

  // ------------------------------------------------------------------------------------------------------
  // Importing and its failures.
  // ------------------------------------------------------------------------------------------------------

  static const savingLabel = 'Making a backup copy, then saving';
  static const savingCaption = 'Nothing is in myData until this ends. Undo import is offered then.';
  static const commitNoAnswer = 'The contacts were not imported. The host stopped answering. Nothing is in myData; '
      'check that it is running, then press Import again.';
  static const commitNoBackup = 'The contacts were not imported: the host could not make its backup copy first. '
      'Nothing changed. Check that the host’s disk has free space, then press Import again.';
  static const commitChanged =
      'Some contacts changed in myData while you were reviewing. Check the review again, then press Import.';

  /// The commit's 400 `losses_not_accepted`: what will not come in changed (read again), so it must be
  /// accepted again.
  static const commitLosses = 'What this import will not bring changed while you were reviewing. Check it again, '
      'tick “Import without what is listed above”, then press Import.';

  // ------------------------------------------------------------------------------------------------------
  // Done.
  // ------------------------------------------------------------------------------------------------------

  static String doneTitle({required int created, required int updated, required int linked}) {
    if (created > 0 || (updated == 0 && linked == 0)) return 'Imported ${count(created, 'contact')} into myData';
    if (updated > 0) return 'Updated ${count(updated, 'contact')} in myData';
    return 'Kept ${count(linked, 'contact')} as yours in myData';
  }

  static String doneUpdated(int n) => '${grouped(n)} updated';
  static String doneLinked(int n) => '${grouped(n)} kept as yours, the iCloud copies hidden';
  static String doneLeftOut(int n) => '${grouped(n)} already in myData ${n == 1 ? 'was' : 'were'} left out';
  static String doneSkipped(int n) => '${count(n, 'card')} could not be read';
  static const showWhich = 'Show which';
  static String doneDuplicates(int n) =>
      '${count(n, 'possible duplicate')} ${n == 1 ? 'was' : 'were'} imported as separate contacts';
  static const doneDuplicatesCaption = 'Merge them in myContacts if they are the same person.';
  static String doneConflicts(List<String> names) =>
      '${grouped(names.length)} ${names.length == 1 ? 'was' : 'were'} not written: ${names.length == 1 ? 'it' : 'they'} '
      'changed in myData while you were reviewing';
  static String doneMissing(int n) =>
      '${grouped(n)} imported before ${n == 1 ? 'is' : 'are'} not in this file any more; ${n == 1 ? 'it stays' : 'they stay'}';

  static const openInMyContacts = 'Open in myContacts';
  static const undoImport = 'Undo import';
  static const importMore = 'Import more';
  static const openFailed = 'myData could not open myContacts. Open it yourself.';

  static String keepFollowingTitle(String? email) => 'Keep following ${_theAccount(email)}?';
  static const keepFollowingShadow = 'myData now shows your imported copy of each contact and hides the one it '
      'follows, so each person is found once (in myContacts, in search and in the assistant’s answers).';
  static const keepFollowingChanges = 'While you follow the account, a contact that changes in iCloud after today is '
      'marked in myContacts. Changes made on your iPhone reach myData only this way until myData can serve your '
      'phone itself.';
  static String keepFollowingCalendars(int n) =>
      'Its ${count(n, 'calendar')} ${n == 1 ? 'is' : 'are'} read from this account too, and ${n == 1 ? 'is' : 'are'} '
      'not imported yet.';
  static String keepFollowingLeft(int n) => '${grouped(n)} of its contacts ${n == 1 ? 'is' : 'are'} not on myData '
      '(you left ${n == 1 ? 'it' : 'them'} out), so ${n == 1 ? 'it' : 'they'} would leave myData too.';
  static String keepFollowingLinked(int n) => '${grouped(n)} of them ${n == 1 ? 'is' : 'are'} hidden behind contacts '
      'of yours, which may lack some of their details.';
  static const stopFollowing = 'Stop following';
  static const keepFollowing = 'Keep following';
  static String stopFollowingTitle(String? email) => 'Stop following ${email ?? 'the iCloud account'}?';
  static String stopFollowingBody({required int imported, required int calendars, required String? keptUntil}) {
    final cal = calendars == 0
        ? ''
        : ' Its ${count(calendars, 'calendar')} ${calendars == 1 ? 'is' : 'are'} not imported, so '
            '${calendars == 1 ? 'it leaves' : 'they leave'} myData; ${calendars == 1 ? 'it stays' : 'they stay'} in '
            'iCloud.';
    return 'myData stops reading this account. Your ${count(imported, 'imported contact')} stay.$cal To follow it '
        'again you will need its app-specific password.${keptUntil == null ? '' : ' ${backupsKept(keptUntil)}'}';
  }

  /// "Copies in your host's backups are kept until 1 October 2027." (H8), as Settings' dialogs say it.
  static String backupsKept(String isoDay) => RemoveAccountText.backupsKept(isoDay);

  static const stoppingWork = 'Stopping…';
  static String stopFailed(String? email) => 'myData did not stop following ${email ?? 'the iCloud account'}. The '
      'host did not answer. Check that it is running, then try again.';

  // ------------------------------------------------------------------------------------------------------
  // History and Undo import.
  // ------------------------------------------------------------------------------------------------------

  /// The history row's title: the file's name, or "Copy of the iCloud account …". Once the account is not
  /// followed any more, its address comes from the host's label ("iCloud account ava@example.org").
  static String historyTitle(ImportOut i, {String? email}) =>
      i.source_ == 'icloud' ? 'Copy of ${_theAccount(email ?? accountEmail(i.label))}' : i.label;

  /// The address in the host's heading for an account ("iCloud account ava@example.org"); null without one.
  static String? accountEmail(String label) {
    const prefix = 'iCloud account ';
    if (!label.startsWith(prefix)) return null;
    final email = label.substring(prefix.length).trim();
    return email.isEmpty ? null : email;
  }

  /// "14 Oct 2026. 125 added, 3 updated, 2 could not be read." and, once undone, "Undone 15 Oct 2026: 122
  /// moved to Recently deleted, 3 changed since were kept."
  static String historyCaption(ImportOut i, {List<String> kept = const []}) {
    final c = i.counts;
    int n(Object? v) => v is num ? v.toInt() : 0;
    final day = DateTime.tryParse(i.startedAt);
    final parts = [
      '${grouped(n(c['created']))} added',
      if (n(c['updated']) > 0) '${grouped(n(c['updated']))} updated',
      if (n(c['linked']) > 0) '${grouped(n(c['linked']))} kept as yours',
      if (n(c['skipped']) > 0) '${grouped(n(c['skipped']))} could not be read',
    ];
    final head = '${day == null ? i.startedAt : formatDay(day.toLocal())}. ${parts.join(', ')}.';
    if (i.status != 'undone') return head;
    final u = c['undo'];
    final undo = u is Map ? u : const {};
    final when = i.undoneAt == null ? null : DateTime.tryParse(i.undoneAt!);
    final did = [
      if (n(undo['removed']) > 0) '${grouped(n(undo['removed']))} moved to Recently deleted',
      if (n(undo['reverted']) > 0) '${grouped(n(undo['reverted']))} put back as they were',
      if (n(undo['kept']) > 0) '${grouped(n(undo['kept']))} changed since ${n(undo['kept']) == 1 ? 'was' : 'were'} kept',
    ];
    final undone = 'Undone${when == null ? '' : ' ${formatDay(when.toLocal())}'}${did.isEmpty ? '' : ': ${did.join(', ')}'}.';
    final keptLine = kept.isEmpty ? '' : ' Kept, because they changed since: ${names(kept)}.';
    return '$head $undone$keptLine';
  }

  static const undoneChip = 'Undone';
  static const undoTitle = 'Undo this import?';
  static const undoBody = 'Contacts this import added that nobody changed since move to Recently deleted, where you '
      'can restore them for 30 days. Contacts it updated go back to how they were. Contacts changed since the import '
      'stay as they are.';
  static const undoAccount = 'The iCloud copies it hid show again while you follow the account.';
  static const undoCannot = 'This cannot be undone as a whole; each contact can be restored from Recently deleted.';
  static const undoing = 'Undoing…';
  static const undoFailed =
      'The import was not undone. The host did not answer. Check that it is running, then try again.';

  /// Heard politely after an undo: "Import undone. 122 contacts moved to Recently deleted; 3 changed since were
  /// kept."
  static String undone(ImportUndoneOut u) {
    final kept = u.kept.length;
    return 'Import undone. ${count(u.removed, 'contact')} moved to Recently deleted'
        '${kept == 0 ? '' : '; ${grouped(kept)} changed since ${kept == 1 ? 'was' : 'were'} kept'}.';
  }

  static String historyAsOf(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'As read at ${two(t.hour)}:${two(t.minute)}.';
  }
}

/// One place people keep contacts, for "Where to get a file".
class Place {
  const Place(this.title, this.steps, {this.before, this.after});
  final String title;
  final List<String> steps;
  final String? before;
  final String? after;
}
