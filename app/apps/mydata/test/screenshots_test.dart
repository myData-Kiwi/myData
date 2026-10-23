// Screenshots of the main screens in Kiwi and Graphite, light and dark (test/screenshots/), rendered through
// the app's own MaterialApp wiring against a fake host. Refresh with `flutter test --update-goldens`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/import/import_files.dart';
import 'package:mydata/src/import/import_text.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';

/// The case being rendered, for the `before` steps.
late ThemeCase current;

/// The app on [host], in [t]'s theme (stored on the host) and mode (stored on this device).
Widget app(FakeHost host, ThemeCase t, {Set<MyDataAppId> installed = const {}, Stream<MyDataLink>? links}) {
  current = t;
  host.theme = t.themeId;
  return MyDataApp(
    controller: host.controller(),
    store: MemoryDeviceStore({'mode': t.brightness.name, 'lastTheme': t.themeId}),
    macSystem: FakeMacSystem(),
    installedApps: FakeLaunchServices(installed).apps(),
    openApp: (_) async => true,
    links: links,
    chooser: () async => MemoryFile(_file, Uint8List.fromList(utf8.encode('BEGIN:VCARD\r\nEND:VCARD\r\n'))),
    acceptDrops: false,
    openLink: (_) async => true,
  );
}

const _file = 'contacts-2026-10-14.vcf';

/// Opens Import, then presses [label] (scrolled into view) when given.
Future<void> _import(WidgetTester tester, {List<String> press = const []}) async {
  await settle(tester);
  await tester.tap(find.text(ImportText.section).first);
  await settle(tester);
  for (final label in press) {
    final f = find.text(label).last;
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await settle(tester);
  }
}

/// A host with a followed iCloud account, This Mac, an earlier import, and [preview] for the next file.
FakeHost _importHost({ImportPreviewOut? preview, ImportCommittedOut? result}) {
  final host = FakeHost(
    status: running
      ..macAvailable = true
      ..mode = StatusOutModeEnum.real
      ..demoDate = false,
    agents: agents,
    mac: macSource(),
    // Today at 09:12, so the caption always reads "as of today at 09:12" whatever day the test runs.
    accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 128, calendars: 3), lastUpdate: _todayAt(9, 12))],
  );
  host.imports
    ..nextPreview = preview
    ..commitResult = result
    ..history = [
      ImportOut(
        id: 'imp-0',
        label: 'contacts-2026-10-01.vcf',
        source_: 'file',
        startedAt: '2026-10-01T09:00:00',
        status: 'undone',
        undoneAt: '2026-10-02T10:00:00',
        counts: {
          'created': 12,
          'skipped': 1,
          'undo': {'removed': 11, 'kept': 1},
        },
      ),
    ];
  return host;
}

/// A review with every list: new contacts, a possible duplicate, a changed card, one already in myData, a
/// card that cannot be read, and Contacts on a Mac's missing notes.
ImportPreviewOut _review() => previewOf(
      [
        for (final (i, n) in [(0, 'Ava Fictional'), (1, 'Cleo Example'), (2, 'Dev Placeholder')]) importItem(i, n),
        importItem(3, 'Ben Sample', matches: [ownMatch('Ben Sample', id: 'c-ben')]),
        importItem(4, 'Eli Sample', status: 'update', action: 'update', choices: ['update', 'skip']),
        importItem(5, 'Finn Example',
            status: 'duplicate',
            action: 'skip',
            matches: [ownMatch('Finn Example', strength: 'strong', signals: ['email', 'name'], id: 'c-finn')]),
        importItem(6, '', status: 'skipped', action: 'skip', choices: ['skip'], reason: 'no_end'),
      ],
      label: _file,
      losses: [
        ImportNoteOut(code: 'skipped_no_end', count: 1, message: ''),
        ImportNoteOut(code: 'no_notes', count: 6, message: ''),
      ],
      followedMatches: 3,
    );

// Timestamps here have no offset, so they parse as local time and formatWhen's toLocal() changes nothing:
// the screenshots read the same in every time zone. The host itself sends UTC ("...Z").
List<AgentOut> get agents => [
  agentWith('Claude on my laptop', connected: true, lastSeenAt: '2026-10-12T08:05:00'),
  agentWith('Notes sync script', lastSeenAt: '2026-10-09T17:40:00'),
  agentWith('Old test agent', revoked: true),
];

StatusOut get running => statusWith(
  ModelOutStateEnum.ready,
  modelBytes: 9300000000,
  lastError: ErrorOut(
    at: '2026-10-12T07:58:00',
    logger: 'mydata.tools',
    message: 'search_mail: the mail index is not built yet',
  ),
)..uptimeSeconds = 8040;

void main() {
  screenMatrix(
    'setup_choose_theme',
    (t) => app(FakeHost(chosen: false), t),
    before: (tester) async {
      await settle(tester);
      // Graphite cases show the step after picking Graphite: the screen previews the pick at once.
      if (current.themeId == 'graphite') await tester.tap(find.text('Graphite'));
      await settle(tester);
    },
  );

  screenMatrix(
    'setup_preparing',
    (t) => app(
      FakeHost(
        status: statusWith(
          ModelOutStateEnum.pulling,
          progress: Progress(completed: 4200000000, total: 9300000000, percent: 45, status: 'pulling'),
        ),
      ),
      t,
    ),
    before: settle,
  );

  // This Mac on, myContacts and myAssistant installed, myCalendar not.
  screenMatrix(
    'status',
    (t) => app(
      FakeHost(
        status: running
          ..macAvailable = true
          ..mode = StatusOutModeEnum.real
          ..demoDate = false,
        agents: agents,
        mac: macSource(),
      ),
      t,
      installed: {MyDataAppId.mycontacts, MyDataAppId.myassistant},
    ),
    before: settle,
  );

  screenMatrix(
    'settings',
    (t) => app(FakeHost(status: running, agents: agents), t),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
    },
  );

  // The bottom of Settings: the agent tokens.
  screenMatrix(
    'settings_agents',
    (t) => app(FakeHost(status: running, agents: agents), t),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text('Old test agent'));
      await settle(tester);
    },
  );

  // First run on a Mac host, after the theme: use the contacts and calendars on this Mac?
  screenMatrix(
    'setup_this_mac',
    (t) => app(FakeHost(mac: macSource(enabled: false, decided: false)), t),
    before: settle,
  );

  // Settings, Sources on a Mac: This Mac on, contacts allowed, calendars turned off in System Settings.
  screenMatrix(
    'settings_sources',
    (t) => app(
      FakeHost(
        status: running..macAvailable = true,
        agents: agents,
        mac: macSource(calendars: 'denied'),
      ),
      t,
    ),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text(SourcesSections.heading));
      await settle(tester);
    },
  );

  // Settings, Advanced on a Mac: following an iCloud account, with one account synced and one failing.
  screenMatrix(
    'settings_sources_advanced',
    (t) => app(
      FakeHost(
        status: running..macAvailable = true,
        agents: agents,
        mac: macSource(),
        accounts: [
          icloudSource('sam@example.com'),
          icloudSource(
            'ava@example.org',
            lastError:
                'Apple did not accept this sign-in. Use the email of your Apple Account, which may '
                'differ from an address on your own domain, and an app-specific password made at '
                'account.apple.com.',
          ),
        ],
      ),
      t,
    ),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text(SourcesSections.advancedHeading));
      await settle(tester);
    },
  );

  // Opened from myContacts or myCalendar with mydata://settings/sources: Settings, scrolled to Sources.
  screenMatrix(
    'sources_link',
    (t) => app(
      FakeHost(
        status: running..macAvailable = true,
        agents: agents,
        mac: macSource(),
        accounts: [icloudSource('sam@example.com')],
      ),
      t,
      links: Stream.value(const OpenMyDataSources()),
    ),
    before: settle,
  );

  // Import, Choose: the drop zone, where to get a file, the followed account and This Mac, the history.
  screenMatrix('import_choose', (t) => app(_importHost(), t), before: (tester) => _import(tester));

  // Choose, after a file the host could not read.
  screenMatrix(
    'import_error',
    (t) => app(_importHost()..imports.refuse = (400, 'no_vcard'), t),
    before: (tester) => _import(tester, press: [DropZone.defaultChooseLabel]),
  );

  // Review: the summary, the loss report with its checkbox unticked, the notice and the lists.
  screenMatrix(
    'import_review',
    (t) => app(_importHost(preview: _review()), t),
    before: (tester) => _import(tester, press: [DropZone.defaultChooseLabel]),
  );

  // Review, the possible duplicate compared with the contact in myData.
  screenMatrix(
    'import_compare',
    (t) {
      final host = _importHost(preview: _review());
      host.imports
        ..cards[3] = ImportCardOut(
          index: 3,
          kind: 'individual',
          displayName: 'Ben Sample',
          fullName: 'Ben Sample',
          jobTitle: 'Archivist',
          phones: [LabeledValue(label: 'Mobile', value: '555-0177')],
          emails: [LabeledValue(label: 'Home', value: 'ben@example.org')],
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
          'emails': [
            {'label': 'Home', 'value': 'ben@example.org'},
          ],
        })!;
      return app(host, t);
    },
    before: (tester) async {
      await _import(tester, press: [DropZone.defaultChooseLabel]);
      final compare = find.widgetWithText(Button, ImportText.compare).first;
      await tester.ensureVisible(compare);
      await tester.pump();
      await tester.tap(compare);
      await settle(tester);
      await tester.ensureVisible(find.byType(DuplicatePair));
      await settle(tester);
    },
  );

  // Importing: the commit takes longer than a second.
  screenMatrix(
    'import_importing',
    (t) {
      final host = _importHost(
        preview: previewOf([importItem(0, 'Ava Fictional'), importItem(1, 'Ben Sample')], label: _file),
        result: committed(created: 2),
      );
      host.imports.commitGate = Completer<void>();
      return app(host, t);
    },
    before: (tester) async {
      await _import(tester, press: [DropZone.defaultChooseLabel, ImportText.importN(2)]);
      await tester.pump(const Duration(milliseconds: 1100));
    },
  );

  // Done, after a file: what happened, Open in myContacts, Undo import and Import more.
  screenMatrix(
    'import_done',
    (t) => app(
      _importHost(
        preview: _review(),
        result: committed(created: 4, updated: 1, skipped: 1, missing: [ImportMissingOut(contactId: 'c-old', displayName: 'Gus Example')]),
      ),
      t,
      installed: {MyDataAppId.mycontacts},
    ),
    before: (tester) =>
        _import(tester, press: [DropZone.defaultChooseLabel, ImportText.acceptLabel, ImportText.importN(5)]),
  );

  // Done, after a copy of the followed iCloud account: keep following it?
  screenMatrix(
    'import_done_account',
    (t) {
      final stop = StopFollowingOut(
        accountId: 'acct-ava',
        label: 'The iCloud account ava@example.org',
        message: '',
        calendarsFollowed: 3,
        contactsFollowed: 2,
        backupsKeptUntil: '2027-10-01',
      );
      final host = _importHost(
        result: committed(created: 126, source: 'icloud', account: 'acct-ava', stopFollowing: stop),
      );
      host.imports.byAccount['acct-ava'] = previewOf(
        [for (var i = 0; i < 128; i++) importItem(i, 'Contact ${i + 1}')],
        source: 'icloud',
        accountId: 'acct-ava',
        label: 'The iCloud account ava@example.org',
        stopFollowing: stop,
      );
      return app(host, t, installed: {MyDataAppId.mycontacts});
    },
    before: (tester) => _import(tester, press: [ImportText.importCopy, ImportText.importN(128)]),
  );
}

String _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute).toIso8601String();
}
