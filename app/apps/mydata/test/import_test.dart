// The Import section (design/components/ImportFlow, DropZone, DuplicatePair's Compare) against a fake host,
// with invented data only: Ava Fictional, Ben Sample, Cleo Example, Dev Placeholder, example.org, 555-01xx.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/import/import_files.dart';
import 'package:mydata/src/import/import_text.dart';
import 'package:mydata/src/shell.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// A file the fake chooser hands over.
MemoryFile vcf(String name, [String text = 'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nEND:VCARD\r\n']) =>
    MemoryFile(name, Uint8List.fromList(utf8.encode(text)));

/// The chooser of the last [pumpImport]: what "Choose file…" returns next.
class FakeChooser {
  PickedFile? next;
  int calls = 0;
  Future<PickedFile?> call() async {
    calls++;
    return next;
  }
}

late FakeChooser chooser;
late List<MyDataLink> opened;

/// The app on [host], on its Import section.
Future<HostController> pumpImport(
  WidgetTester tester,
  FakeHost host, {
  Set<MyDataAppId> installed = const {MyDataAppId.mycontacts},
  Stream<MyDataLink>? links,
  Size size = const Size(1280, 2000),
  bool openSection = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  chooser = FakeChooser();
  opened = [];
  final controller = host.controller();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MyDataApp(
    controller: controller,
    store: MemoryDeviceStore(),
    macSystem: FakeMacSystem(),
    installedApps: FakeLaunchServices(installed).apps(),
    links: links,
    chooser: chooser.call,
    acceptDrops: false,
    openLink: (l) async {
      opened.add(l);
      return true;
    },
  ));
  await settle(tester);
  if (openSection) {
    await tester.tap(find.text(ImportText.section).first);
    await settle(tester);
  }
  return controller;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// Chooses [file] with "Choose file…".
Future<void> choose(WidgetTester tester, PickedFile file) async {
  chooser.next = file;
  await tapText(tester, DropZone.defaultChooseLabel);
}

List<String> importRequests(FakeHost host) => [
      for (final r in host.requests)
        if (r.contains('/import/')) r,
    ];

/// A file with one card of each kind the review lists.
ImportPreviewOut mixedPreview() => previewOf(
      [
        importItem(0, 'Ava Fictional'),
        importItem(1, 'Ben Sample', matches: [ownMatch('Ben Sample', id: 'c-ben')]),
        importItem(2, 'Cleo Example', status: 'update', action: 'update', choices: ['update', 'skip']),
        importItem(3, 'Dev Placeholder',
            status: 'duplicate',
            action: 'skip',
            matches: [ownMatch('Dev Placeholder', strength: 'strong', signals: ['email', 'name'], id: 'c-dev')]),
        importItem(4, '', status: 'skipped', action: 'skip', choices: ['skip'], reason: 'no_end'),
        importItem(5, 'Eve Example', status: 'unchanged', action: 'skip', choices: ['skip']),
        importItem(6, 'Finn Sample', status: 'conflict', action: 'skip', choices: ['skip'], reason: 'edited'),
      ],
      losses: [
        ImportNoteOut(code: 'skipped_no_end', count: 1, message: '1 card(s) end early'),
      ],
    );

void main() {
  group('Choose', () {
    testWidgets('is the third section between Status and Settings, with the drop zone and where to get a file',
        (tester) async {
      await pumpImport(tester, FakeHost());
      expect(HomeShell.sections.map((s) => s.label), ['Status', 'Import', 'Settings']);
      expect(find.text(ImportText.chooseTitle), findsOneWidget);
      expect(find.text(ImportText.instruction), findsOneWidget);
      expect(find.text(ImportText.caption), findsOneWidget);
      expect(tester.widget<Button>(find.widgetWithText(Button, DropZone.defaultChooseLabel)).variant,
          ButtonVariant.filled);
      for (final p in ImportText.places) {
        expect(find.text(p.title), findsOneWidget);
      }
      // No steps open at first; Return or a press opens one in place.
      expect(find.text(ImportText.places.first.steps.first), findsNothing);
      await tapText(tester, 'Google');
      expect(find.text(ImportText.places[2].steps.first), findsOneWidget);
      // Nothing followed and no history: those sections are left out.
      expect(find.text(ImportText.fromAccountHeading), findsNothing);
      expect(find.text(ImportText.historyHeading), findsNothing);
    });

    testWidgets('followed accounts with their counts; This Mac with the reason and Show how', (tester) async {
      final host = FakeHost(mac: macSource(), accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 128))]);
      await pumpImport(tester, host);
      expect(find.text(ImportText.account('ava@example.org')), findsOneWidget);
      expect(find.textContaining('128 contacts, as of'), findsOneWidget);
      expect(find.text(ImportText.macNotImportable), findsOneWidget);
      expect(find.text(ImportText.importCopy), findsOneWidget, reason: 'This Mac has no Import a copy');
      await tapText(tester, ImportText.showHow);
      expect(find.text(ImportText.places.first.steps.first), findsOneWidget);
    });

    testWidgets('a link from myContacts opens Import, with Contacts on a Mac open on a Mac host', (tester) async {
      final links = StreamController<MyDataLink>();
      addTearDown(links.close);
      final host = FakeHost(status: statusWith(ModelOutStateEnum.ready, macAvailable: true), mac: macSource());
      await pumpImport(tester, host, links: links.stream, openSection: false);
      expect(find.text(ImportText.chooseTitle), findsNothing);
      links.add(const OpenMyDataImport());
      await settle(tester);
      expect(tester.widget<AppFrame>(find.byType(AppFrame)).current, 1);
      expect(find.text(ImportText.places.first.steps.first), findsOneWidget);
    });

    testWidgets('files are checked before anything is sent', (tester) async {
      final host = FakeHost();
      await pumpImport(tester, host);
      final cases = {
        vcf('family.ics'): ImportText.calendar('family.ics'),
        vcf('outlook-contacts.csv'): ImportText.csv('outlook-contacts.csv'),
        vcf('notes.txt'): ImportText.notVcard('notes.txt'),
        MemoryFile('Contacts', Uint8List(0), isDirectory: true): ImportText.folder('Contacts'),
        MemoryFile('contacts-all.vcf', Uint8List(ImportFileCheck.maxBytes + 1)):
            ImportText.tooBig('contacts-all.vcf', ImportFileCheck.maxBytes + 1),
      };
      for (final MapEntry(key: file, value: sentence) in cases.entries) {
        await choose(tester, file);
        expect(find.text(sentence), findsOneWidget, reason: file.name);
      }
      expect(ImportFileCheck.check([vcf('a.vcf'), vcf('b.vcf')]), ImportText.severalFiles);
      expect(importRequests(host), isEmpty);
    });

    testWidgets('a whole file the host refuses gets the app\'s own sentence from its code', (tester) async {
      final host = FakeHost();
      await pumpImport(tester, host);
      for (final (status, code, name) in [
        (400, 'no_vcard', 'contacts.vcf'),
        (400, 'zip_no_vcard', 'takeout-2026-10-14.zip'),
        (400, 'zip_too_big', 'takeout-2026-10-14.zip'),
        (413, 'too_big', 'contacts.vcf'),
      ]) {
        host.imports.refuse = (status, code);
        await choose(tester, vcf(name));
        expect(find.text(ImportText.refused(name, code, bytes: vcf(name).bytes.length)), findsOneWidget, reason: code);
      }
      expect(find.text(DropZone.retryLabel), findsNothing);
    });

    testWidgets('the host not answering: the error names the file, and Try again sends it again', (tester) async {
      final host = FakeHost();
      await pumpImport(tester, host);
      host.imports.down = true;
      await choose(tester, vcf('contacts-2026-10-14.vcf'));
      expect(find.text(ImportText.notRead('contacts-2026-10-14.vcf')), findsOneWidget);
      host.imports
        ..down = false
        ..nextPreview = mixedPreview();
      await tapText(tester, DropZone.retryLabel);
      expect(find.text(ImportText.reviewTitle), findsOneWidget);
      expect(
        importRequests(host).where((r) => r.startsWith('POST /import/contacts/preview')),
        hasLength(2),
      );
    });

    testWidgets('a file in which no card can be read is the zone\'s error, not a review', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = previewOf([
        for (var i = 0; i < 3; i++) importItem(i, '', status: 'skipped', action: 'skip', choices: ['skip']),
      ]);
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      expect(find.text(ImportText.noneReadable('contacts.vcf', 3)), findsOneWidget);
      expect(importRequests(host).last, 'DELETE /import/previews/pv-1');
    });

    testWidgets('reading shows the file and Cancel; a preview that arrives after Cancel is discarded',
        (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = mixedPreview()
        ..previewGate = Completer<void>();
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts-2026-10-14.vcf'));
      expect(find.text('Reading contacts-2026-10-14.vcf…'), findsOneWidget);
      await tapText(tester, DropZone.cancelLabel);
      expect(find.text(ImportText.instruction), findsOneWidget);
      host.imports.previewGate!.complete();
      await settle(tester);
      expect(find.text(ImportText.reviewTitle), findsNothing);
      expect(importRequests(host).last, 'DELETE /import/previews/pv-1');
    });

    testWidgets('with the host down the zone is disabled with the reason, and the history stays', (tester) async {
      final host = FakeHost();
      host.imports.history = [
        ImportOut(
          id: 'imp-0',
          label: 'contacts-2026-10-01.vcf',
          source_: 'file',
          startedAt: '2026-10-01T09:00:00',
          status: 'committed',
          counts: {'created': 12},
        ),
      ];
      final c = await pumpImport(tester, host);
      expect(find.text('contacts-2026-10-01.vcf'), findsOneWidget);
      c
        ..phase = HostPhase.lost
        ..notifyListeners();
      await settle(tester);
      expect(find.text(ImportText.hostDown), findsOneWidget);
      expect(tester.widget<Button>(find.widgetWithText(Button, DropZone.defaultChooseLabel)).onPressed, isNull);
      expect(find.text('contacts-2026-10-01.vcf'), findsOneWidget);
      expect(find.textContaining('As read at'), findsOneWidget);
    });
  });

  group('Review', () {
    testWidgets('names what was read, the summary follows the ticks, and losses need the tick', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = mixedPreview();
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts-2026-10-14.vcf'));
      expect(importRequests(host).single,
          startsWith('POST /import/contacts/preview?filename=contacts-2026-10-14.vcf ('));
      expect(find.text(ImportText.reviewTitle), findsOneWidget);
      expect(find.text('contacts-2026-10-14.vcf: 7 cards.'), findsOneWidget);
      expect(find.text(ImportText.summaryNew(1)), findsOneWidget);
      expect(find.text(ImportText.summaryDuplicates(1)), findsOneWidget);
      expect(find.text(ImportText.summaryUpdates(1)), findsOneWidget);
      expect(find.text(ImportText.summaryAlready(2)), findsOneWidget);
      expect(find.text(ImportText.summaryConflicts(1)), findsOneWidget);
      expect(find.text(ImportText.summarySkipped(1)), findsOneWidget);
      expect(find.text('Card 5 ends before END:VCARD; the file may be cut short.'), findsOneWidget);
      expect(find.text(ImportText.whereTheyGo), findsOneWidget);
      // Import counts the imports and updates; it waits for the tick.
      final import = find.widgetWithText(Button, ImportText.importN(3));
      expect(tester.widget<Button>(import).onPressed, isNull);
      expect(find.text(ImportText.acceptFirst), findsOneWidget);
      await tapText(tester, ImportText.acceptLabel);
      expect(tester.widget<Button>(import).onPressed, isNotNull);
      // Unticking the new contact takes it off the count and the summary.
      await tapText(tester, ImportText.showAll(1));
      await tapText(tester, 'Ava Fictional');
      expect(find.text(ImportText.summaryNew(1)), findsNothing);
      expect(find.widgetWithText(Button, ImportText.importN(2)), findsOneWidget);
      // A duplicate ticked imports it as a separate contact.
      await tapText(tester, 'Dev Placeholder');
      expect(find.widgetWithText(Button, ImportText.importN(3)), findsOneWidget);

      host.imports.commitResult = committed(created: 1, updated: 1);
      await tapText(tester, ImportText.importN(3));
      final sent = host.requests.firstWhere((r) => r.contains('/commit'));
      final body = jsonDecode(sent.substring(sent.indexOf('{'))) as Map<String, Object?>;
      expect(body['accept_losses'], true);
      expect(body['choices'], [
        {'action': 'skip', 'index': 0},
        {'action': 'import', 'index': 3},
      ]);
    });

    testWidgets('nothing ticked: Import is disabled with "Choose at least one contact to import."', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = previewOf([importItem(0, 'Ava Fictional'), importItem(1, 'Ben Sample')]);
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      await tapText(tester, ImportText.allContacts(2));
      expect(find.text(ImportText.chooseOne), findsOneWidget);
      expect(tester.widget<Button>(find.widgetWithText(Button, ImportText.importN(0))).onPressed, isNull);
    });

    testWidgets('a file with nothing to import offers "Choose another file"', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = previewOf([
        importItem(0, 'Ava Fictional', status: 'unchanged', action: 'skip', choices: ['skip']),
      ]);
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      expect(find.widgetWithText(Button, ImportText.chooseAnother), findsOneWidget);
      expect(find.text(ImportText.leftOutLine(1, 0)), findsOneWidget);
    });

    testWidgets('Compare opens the file\'s card beside the contact in myData, with what differs marked',
        (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = mixedPreview()
        ..cards[1] = ImportCardOut(
          index: 1,
          kind: 'individual',
          displayName: 'Ben Sample',
          fullName: 'Ben Sample',
          phones: [LabeledValue(label: 'Mobile', value: '555-0177')],
          fields: [],
        )
        ..contacts['c-ben'] = ContactDetailOut.fromJson({
          'id': 'c-ben',
          'account_id': 'local',
          'address_book_id': 'book-mydata',
          'created_at': '2026-10-02T09:00:00',
          'modified_at': '2026-10-02T09:00:00',
          'display_name': 'Ben Sample',
          'full_name': 'Ben Sample',
          'editable': true,
          'etag': '"1-c-ben"',
          'fields': [],
          'sort_letter': 'B',
          'source': 'mydata',
          'source_label': 'myData',
          'phones': [
            {'label': 'Mobile', 'value': '555-0142'},
          ],
        })!;
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      final compare = find.widgetWithText(Button, ImportText.compare).first;
      await tester.ensureVisible(compare);
      await tester.tap(compare);
      await settle(tester);
      expect(importRequests(host), contains('GET /import/previews/pv-1/items/1'));
      expect(host.requests, contains('GET /contacts/c-ben'));
      expect(find.byType(DuplicatePair), findsOneWidget);
      expect(find.text(ImportText.inFile), findsOneWidget);
      expect(find.text(ImportText.inMyData), findsOneWidget);
      expect(find.text(DuplicatePair.differsLabel), findsOneWidget);
      // Nothing was ticked by comparing.
      expect(host.requests.where((r) => r.contains('/commit')), isEmpty);
      await tapText(tester, ImportText.hideComparison);
      expect(find.byType(DuplicatePair), findsNothing);
    });

    testWidgets('a zip of several files: each file can be left out', (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = previewOf([
          importItem(0, 'Ava Fictional', entry: 'family.vcf'),
          importItem(1, 'Ben Sample', entry: 'work.vcf'),
        ], label: 'takeout-2026-10-14.zip')
        ..commitResult = committed(created: 1, label: 'takeout-2026-10-14.zip');
      await pumpImport(tester, host);
      await choose(tester, vcf('takeout-2026-10-14.zip'));
      expect(find.text('takeout-2026-10-14.zip: 2 vCard files, 2 cards.'), findsOneWidget);
      expect(find.text(ImportText.filesHeading(2)), findsOneWidget);
      await tapText(tester, ImportText.fileRow('work.vcf', 1));
      await tapText(tester, ImportText.importN(1));
      final sent = host.requests.firstWhere((r) => r.contains('/commit'));
      expect(sent, contains('{"action":"skip","index":1}'));
    });

    testWidgets('Cancel discards the preview and returns to Choose without asking', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = mixedPreview();
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      await tapText(tester, ImportText.cancel);
      expect(find.text(ImportText.chooseTitle), findsOneWidget);
      expect(importRequests(host).last, 'DELETE /import/previews/pv-1');
      expect(find.byType(MyDataDialog), findsNothing);
    });

    testWidgets('coming back after the host dropped the preview shows Expired', (tester) async {
      final host = FakeHost();
      host.imports.nextPreview = mixedPreview();
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      await tapText(tester, 'Status');
      host.imports.gone.add('pv-1');
      await tapText(tester, ImportText.section);
      expect(find.text(ImportText.expired), findsOneWidget);
      expect(find.widgetWithText(Button, DropZone.defaultChooseLabel), findsOneWidget);
    });

    testWidgets('first data of your own, groups and hidden followed copies are said in notices', (tester) async {
      final host = FakeHost(status: statusWith(ModelOutStateEnum.ready, macAvailable: true), mac: macSource());
      host.imports.nextPreview = previewOf(
        [
          importItem(0, 'Ava Fictional', matches: [
            ImportMatchOut(
                displayName: 'Ava Fictional', source_: 'mac', accountId: 'mac', strength: 'strong', signals: ['email', 'name'], hides: true),
          ]),
          importItem(1, 'Family', kind: 'group'),
        ],
        groups: 1,
        followedMatches: 1,
      );
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      expect(find.text(ImportText.firstData), findsOneWidget);
      expect(find.text(ImportText.groups(1)), findsOneWidget);
      expect(find.text(ImportText.shadowFile(1, 'this Mac')), findsOneWidget);
      // The group is not a row and not counted.
      expect(find.text('Family'), findsNothing);
      expect(find.widgetWithText(Button, ImportText.importN(1)), findsOneWidget);
    });
  });

  group('Importing and its failures', () {
    Future<FakeHost> toReview(WidgetTester tester) async {
      final host = FakeHost();
      host.imports.nextPreview = previewOf([importItem(0, 'Ava Fictional'), importItem(1, 'Ben Sample')]);
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      return host;
    }

    testWidgets('a slow commit shows Importing, then Done with the host\'s counts', (tester) async {
      final host = await toReview(tester);
      host.imports
        ..commitGate = Completer<void>()
        ..commitResult = committed(created: 2);
      await tester.tap(find.widgetWithText(Button, ImportText.importN(2)));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text(ImportText.importingTitle(2)), findsOneWidget);
      expect(find.text(ImportText.savingLabel), findsOneWidget);
      host.imports.commitGate!.complete();
      await settle(tester);
      expect(find.text('Imported 2 contacts into myData'), findsOneWidget);
    });

    for (final (what, refusal, line) in [
      ('no answer', null, ImportText.commitNoAnswer),
      ('no backup copy', (503, null), ImportText.commitNoBackup),
      ('a choice refused', (400, 'choice_refused'), ImportText.commitChanged),
    ]) {
      testWidgets('a failed commit ($what) returns to Review with its line', (tester) async {
        final host = await toReview(tester);
        if (refusal == null) {
          host.imports.down = true;
        } else {
          host.imports.commitRefusal = refusal;
        }
        await tapText(tester, ImportText.importN(2));
        expect(find.text(ImportText.reviewTitle), findsOneWidget);
        expect(find.text(line), findsOneWidget);
        if (refusal?.$1 == 400) {
          expect(host.requests.where((r) => r == 'GET /import/previews/pv-1'), isNotEmpty,
              reason: 'Review is read again');
        }
      });
    }

    testWidgets('the preview gone at commit shows Expired', (tester) async {
      final host = await toReview(tester);
      host.imports.commitRefusal = (404, null);
      await tapText(tester, ImportText.importN(2));
      expect(find.text(ImportText.expired), findsOneWidget);
    });
  });

  group('Done', () {
    testWidgets('says what happened; Open in myContacts opens its list; Import more goes back', (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = mixedPreview()
        ..commitResult = committed(
          created: 1,
          updated: 1,
          skipped: 1,
          conflicts: [ImportConflictOut(index: 6, displayName: 'Finn Sample')],
          missing: [ImportMissingOut(contactId: 'c-old', displayName: 'Gus Example')],
        );
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts-2026-10-14.vcf'));
      await tapText(tester, ImportText.acceptLabel);
      await tapText(tester, ImportText.importN(3));
      expect(find.text('Imported 1 contact into myData'), findsOneWidget);
      expect(find.text(ImportText.doneUpdated(1)), findsOneWidget);
      expect(find.text(ImportText.doneSkipped(1)), findsOneWidget);
      expect(find.text(ImportText.doneDuplicates(1)), findsOneWidget);
      expect(find.text(ImportText.doneConflicts(['Finn Sample'])), findsOneWidget);
      expect(find.text(ImportText.doneMissing(1)), findsOneWidget);
      expect(tester.widget<Button>(find.widgetWithText(Button, ImportText.openInMyContacts)).variant,
          ButtonVariant.filled);
      await tapText(tester, ImportText.openInMyContacts);
      expect(opened, [const OpenContactList()]);
      await tapText(tester, ImportText.importMore);
      expect(find.text(ImportText.chooseTitle), findsOneWidget);
      expect(find.text('contacts-2026-10-14.vcf'), findsOneWidget, reason: 'the history row');
    });

    testWidgets('without myContacts the filled button is Import more', (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = previewOf([importItem(0, 'Ava Fictional')])
        ..commitResult = committed(created: 1);
      await pumpImport(tester, host, installed: const {});
      await choose(tester, vcf('contacts.vcf'));
      await tapText(tester, ImportText.importN(1));
      expect(find.text(ImportText.openInMyContacts), findsNothing);
      expect(tester.widget<Button>(find.widgetWithText(Button, ImportText.importMore)).variant, ButtonVariant.filled);
    });

    testWidgets('a copy of a followed account: the shadowing notice, then Keep following or Stop following',
        (tester) async {
      final host = FakeHost(accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 2, calendars: 3))]);
      final stop = StopFollowingOut(
        accountId: 'acct-ava',
        label: 'The iCloud account ava@example.org',
        message: '',
        calendarsFollowed: 3,
        contactsFollowed: 0,
        backupsKeptUntil: '2027-10-01',
      );
      host.imports
        ..byAccount['acct-ava'] = previewOf(
          [importItem(0, 'Ava Fictional'), importItem(1, 'Ben Sample')],
          source: 'icloud',
          accountId: 'acct-ava',
          label: 'The iCloud account ava@example.org',
          stopFollowing: stop,
        )
        ..commitResult = committed(created: 2, source: 'icloud', account: 'acct-ava', stopFollowing: stop);
      await pumpImport(tester, host);
      await tapText(tester, ImportText.importCopy);
      expect(host.requests, contains('POST /import/contacts/from-source/acct-ava/preview'));
      expect(find.text('A copy of the iCloud account ava@example.org: 2 contacts.'), findsOneWidget);
      expect(find.text(ImportText.shadowAccount(2, 'ava@example.org')), findsOneWidget);
      await tapText(tester, ImportText.importN(2));
      expect(find.text(ImportText.keepFollowingTitle('ava@example.org')), findsOneWidget);
      expect(find.text(ImportText.keepFollowingCalendars(3)), findsOneWidget);
      await tapText(tester, ImportText.stopFollowing);
      expect(find.text(ImportText.stopFollowingTitle('ava@example.org')), findsOneWidget);
      expect(
        find.text(ImportText.stopFollowingBody(imported: 2, calendars: 3, keptUntil: '2027-10-01')),
        findsOneWidget,
      );
      expect(find.textContaining('kept until 1 October 2027.'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, ImportText.stopFollowing).last);
      await settle(tester);
      expect(host.requests, contains('DELETE /accounts/acct-ava'));
      expect(find.text(ImportText.keepFollowingTitle('ava@example.org')), findsNothing);
    });

    testWidgets('Keep following closes the question and changes nothing', (tester) async {
      final host = FakeHost(accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 1))]);
      final stop = StopFollowingOut(
          accountId: 'acct-ava', label: 'x', message: '', calendarsFollowed: 0, contactsFollowed: 0, backupsKeptUntil: '2027-10-01');
      host.imports
        ..byAccount['acct-ava'] = previewOf([importItem(0, 'Ava Fictional')], source: 'icloud', accountId: 'acct-ava')
        ..commitResult = committed(created: 1, source: 'icloud', account: 'acct-ava', stopFollowing: stop);
      await pumpImport(tester, host);
      await tapText(tester, ImportText.importCopy);
      await tapText(tester, ImportText.importN(1));
      await tapText(tester, ImportText.keepFollowing);
      expect(find.text(ImportText.keepFollowingTitle('ava@example.org')), findsNothing);
      expect(host.requests.where((r) => r.startsWith('DELETE /accounts')), isEmpty);
    });
  });

  group('History and Undo import', () {
    ImportOut earlier({String status = 'committed'}) => ImportOut(
          id: 'imp-0',
          label: 'contacts-2026-10-14.vcf',
          source_: 'file',
          startedAt: '2026-10-14T09:00:00',
          status: status,
          counts: {'created': 125, 'updated': 3, 'skipped': 2},
        );

    testWidgets('a row per import with its counts; Undo import asks, then the row says Undone', (tester) async {
      final host = FakeHost();
      host.imports
        ..history = [earlier()]
        ..undoResult = ImportUndoneOut(
          removed: 122,
          reverted: 3,
          unlinked: 0,
          gone: 0,
          kept: [ImportMissingOut(contactId: 'c-ava', displayName: 'Ava Fictional')],
          summary: earlier(),
        );
      await pumpImport(tester, host);
      expect(find.text('14 Oct 2026. 125 added, 3 updated, 2 could not be read.'), findsOneWidget);
      await tapText(tester, ImportText.undoImport);
      expect(find.text(ImportText.undoTitle), findsOneWidget);
      expect(find.textContaining(ImportText.undoBody), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, ImportText.undoImport).last);
      await settle(tester);
      expect(host.requests, contains('POST /imports/imp-0/undo'));
      expect(find.text(ImportText.undoneChip), findsOneWidget);
      expect(find.textContaining('Kept, because they changed since: Ava Fictional.'), findsOneWidget);
      expect(find.widgetWithText(Button, ImportText.undoImport), findsNothing);
    });

    testWidgets('already undone elsewhere: the row is read again and says Undone', (tester) async {
      final host = FakeHost();
      host.imports
        ..history = [earlier()]
        ..undoConflict = true;
      await pumpImport(tester, host);
      await tapText(tester, ImportText.undoImport);
      await tester.tap(find.widgetWithText(Button, ImportText.undoImport).last);
      await settle(tester);
      expect(find.byType(MyDataDialog), findsNothing);
      expect(find.text(ImportText.undoneChip), findsOneWidget);
    });

    testWidgets('the host not answering keeps the dialog open with its line', (tester) async {
      final host = FakeHost();
      host.imports.history = [earlier()];
      await pumpImport(tester, host);
      await tapText(tester, ImportText.undoImport);
      host.imports.down = true;
      await tester.tap(find.widgetWithText(Button, ImportText.undoImport).last);
      await settle(tester);
      expect(find.text(ImportText.undoFailed), findsOneWidget);
    });
  });

  group('Keys', () {
    testWidgets('Command or Control Return presses Import; Return alone does not', (tester) async {
      final host = FakeHost();
      host.imports
        ..nextPreview = previewOf([importItem(0, 'Ava Fictional')])
        ..commitResult = committed(created: 1);
      await pumpImport(tester, host);
      await choose(tester, vcf('contacts.vcf'));
      // Return alone on the page does not import.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(host.requests.where((r) => r.contains('/commit')), isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await settle(tester);
      expect(host.requests.where((r) => r.contains('/commit')), hasLength(1));
    });
  });
}
