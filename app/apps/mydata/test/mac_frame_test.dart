// The Mac frame (MacLook) of myData: first launch, Status, Import and Settings, their behaviour, and
// screenshots at the window's 1280x800 in light and dark, with the system accent set to Kiwi's and to
// Graphite's (test/screenshots/mac_*.png), the bundled Figtree under the system font's names (loadMacFonts).
// Refresh with `flutter test --update-goldens test/mac_frame_test.dart` on a Mac.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/import/import_files.dart';
import 'package:mydata/src/import/import_text.dart';
import 'package:mydata/src/mac_status.dart';
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata/src/setup_screen.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// Light and dark, with the system's accent set to Kiwi's and to Graphite's (the plan's accent options).
const macAccents = [
  ThemeCase('kiwi', Brightness.light),
  ThemeCase('kiwi', Brightness.dark),
  ThemeCase('graphite', Brightness.light),
  ThemeCase('graphite', Brightness.dark),
];

/// The Runner's answer on `mydata/system_colors`: the system defaults with [themeId]'s accent as the
/// accent the person picked in System Settings.
Map<String, Object?> palette(String themeId) {
  final t = MyDataThemes.byId(themeId);
  Map<String, int> side(Color accent, Color onAccent) => {
    'accent': accent.toARGB32(),
    'on-accent': onAccent.toARGB32(),
    'focus-ring': accent.withValues(alpha: 0.5).toARGB32(),
  };
  return {'light': side(t.accentLight, t.onAccentLight), 'dark': side(t.accentDark, t.onAccentDark)};
}

void useAccent(String themeId) => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(MacSystemColorsScope.channel, (call) async => call.method == 'get' ? palette(themeId) : null);

Widget app(
  FakeHost host,
  ThemeCase t, {
  Set<MyDataAppId> installed = const {MyDataAppId.mycontacts, MyDataAppId.myassistant},
  Stream<MyDataLink>? links,
}) {
  useAccent(t.themeId);
  return MyDataApp(
    controller: host.controller(),
    store: MemoryDeviceStore({'mode': t.brightness.name, 'lastTheme': host.theme}),
    macSystem: FakeMacSystem(),
    installedApps: FakeLaunchServices(installed).apps(),
    openApp: (_) async => true,
    links: links,
    chooser: () async => MemoryFile('contacts.vcf', Uint8List.fromList(utf8.encode('BEGIN:VCARD\r\nEND:VCARD\r\n'))),
    acceptDrops: false,
    openLink: (_) async => true,
  );
}

List<AgentOut> get agents => [
  agentWith('Claude on my laptop', connected: true, lastSeenAt: '2026-10-12T08:05:00'),
  agentWith('Notes sync script', lastSeenAt: '2026-10-09T17:40:00'),
  agentWith('Old test agent', revoked: true),
];

/// A host in real mode reading This Mac, its model ready, with an error it reported this morning.
StatusOut get real => statusWith(
  ModelOutStateEnum.ready,
  modelBytes: 9300000000,
  macAvailable: true,
  lastError: ErrorOut(at: '2026-10-12T07:58:00', logger: 'mydata.tools', message: 'search_mail: the mail index is not built yet'),
)
  ..mode = StatusOutModeEnum.real
  ..demoDate = false
  ..uptimeSeconds = 8040;

FakeHost realHost({List<SourceOut>? accounts, SourceOut? mac}) => FakeHost(
  status: real,
  agents: agents,
  mac: mac ?? macSource(counts: SyncCounts(contacts: 412, calendars: 6)),
  accounts: accounts,
);

/// Opens Settings at [tab].
Future<void> openSettings(WidgetTester tester, SettingsTab tab) async {
  await settle(tester);
  await tester.tap(find.text('Settings').first);
  await settle(tester);
  await tester.tap(find.text(tab.label));
  await settle(tester);
}

void main() {
  setUp(() => MacLook.debugOverride = true);
  tearDown(() {
    MacLook.debugOverride = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      MacSystemColorsScope.channel,
      null,
    );
  });

  Future<void> window(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('first launch', () {
    macTestWidgets('asks one question, with no theme step: the accent is the system\'s', (tester) async {
      await window(tester);
      final host = FakeHost(chosen: false, mac: macSource(enabled: false, decided: false));
      await tester.pumpWidget(app(host, macAccents.first));
      await settle(tester);
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text(ThisMacStep.macTitle), findsOneWidget);
      expect(find.text(ThisMacStep.sampleLabel), findsOneWidget);
      expect(find.text(ThisMacStep.allowLabel), findsOneWidget);
      expect(host.requests.where((r) => r.startsWith('PUT /appearance')), isEmpty);
    });

    macTestWidgets('Allow turns This Mac on and asks for contacts, then calendars, and opens Status', (tester) async {
      await window(tester);
      final host = FakeHost(chosen: false, mac: macSource(enabled: false, decided: false));
      await tester.pumpWidget(app(host, macAccents.first));
      await settle(tester);
      // Allow is the default button: it has focus from the start (replacing the theme step's focused control
      // must not make the menu bar's text-focus check throw), and Return presses it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(host.requests.where((r) => r.startsWith('PUT /sources/mac ')).single, contains('"enabled":true'));
      expect(host.requests.where((r) => r.startsWith('POST /sources/mac/request-access')), hasLength(2));
      expect(find.text(MacStatusView.title), findsOneWidget);
    });

    macTestWidgets('Try with sample data leaves This Mac off, records it, and opens Status', (tester) async {
      await window(tester);
      final host = FakeHost(mac: macSource(enabled: false, decided: false));
      await tester.pumpWidget(app(host, macAccents.first));
      await settle(tester);
      await tester.tap(find.text(ThisMacStep.sampleLabel));
      await settle(tester);
      expect(host.requests.where((r) => r.startsWith('PUT /sources/mac ')).single, contains('"enabled":false'));
      expect(find.text(MacStatusView.title), findsOneWidget);
      expect(find.text(MacStatusView.useYourData), findsOneWidget, reason: 'demo mode offers the way out');
    });
  });

  group('Status', () {
    macTestWidgets('a calm overview: the developer facts are folded under Details', (tester) async {
      await window(tester);
      await tester.pumpWidget(app(realHost(), macAccents.first));
      await settle(tester);
      expect(find.text(MacStatusView.title), findsOneWidget);
      expect(find.textContaining('Reading your contacts and calendars from this Mac'), findsOneWidget);
      expect(find.text('Host memory'), findsNothing);
      expect(find.text('Claude on my laptop'), findsOneWidget, reason: 'a connected agent is listed');
      expect(find.text('Notes sync script'), findsNothing, reason: 'an agent not connected is not');
      await tester.tap(find.text(MacStatusView.details));
      await settle(tester);
      expect(find.text('Host memory'), findsOneWidget);
      expect(find.text('2 h 14 min'), findsOneWidget);
    });

    macTestWidgets('an error the host reported shows one line, whose button opens the details', (tester) async {
      await window(tester);
      await tester.pumpWidget(app(realHost(), macAccents.first));
      await settle(tester);
      expect(find.text(MacStatusView.errorTitle), findsOneWidget);
      await tester.tap(find.text(MacStatusView.showDetails));
      await settle(tester);
      expect(find.text('search_mail: the mail index is not built yet'), findsOneWidget);
    });

    macTestWidgets('sample data offers Settings, Sources', (tester) async {
      await window(tester);
      await tester.pumpWidget(app(FakeHost(mac: macSource(enabled: false)), macAccents.first));
      await settle(tester);
      await tester.tap(find.text(MacStatusView.useYourData));
      await settle(tester);
      expect(find.text(ThisMacText.title), findsOneWidget);
    });
  });

  group('Settings', () {
    macTestWidgets('tabs in the toolbar; mydata://settings/sources opens Sources', (tester) async {
      await window(tester);
      final links = StreamController<MyDataLink>();
      addTearDown(links.close);
      await tester.pumpWidget(app(realHost(), macAccents.first, links: links.stream));
      await openSettings(tester, SettingsTab.agents);
      expect(find.text('Notes sync script'), findsOneWidget);
      links.add(const OpenMyDataSources());
      await settle(tester);
      expect(find.text(ThisMacText.title), findsOneWidget);
      expect(find.text('Notes sync script'), findsNothing);
    });

    macTestWidgets('turning This Mac off asks first, with the system\'s switch', (tester) async {
      await window(tester);
      await tester.pumpWidget(app(realHost(), macAccents.first));
      await openSettings(tester, SettingsTab.sources);
      await tester.tap(find.bySemanticsLabel(ThisMacText.title).first);
      await settle(tester);
      expect(find.text('Turn off This Mac?'), findsOneWidget);
    });

    macTestWidgets('the assistant switch turns it off', (tester) async {
      await window(tester);
      final host = realHost();
      await tester.pumpWidget(app(host, macAccents.first));
      await openSettings(tester, SettingsTab.assistant);
      await tester.tap(find.byType(MacSwitch));
      await settle(tester);
      expect(host.requests, contains('PUT /assistant/settings {"enabled":false}'));
    });

    macTestWidgets('a theme swatch sets the theme on the host, for the other platforms', (tester) async {
      await window(tester);
      final host = realHost();
      await tester.pumpWidget(app(host, macAccents.first));
      await openSettings(tester, SettingsTab.appearance);
      await tester.tap(find.bySemanticsLabel('Plum'));
      await settle(tester);
      expect(host.theme, 'plum');
    });

    macTestWidgets('on a Mac host, following iCloud is folded under Advanced', (tester) async {
      await window(tester);
      await tester.pumpWidget(app(realHost(), macAccents.first));
      await openSettings(tester, SettingsTab.sources);
      expect(find.text('Apple Account email'), findsNothing);
      await tester.ensureVisible(find.text('Follow an iCloud account'));
      await tester.tap(find.text('Follow an iCloud account'));
      await settle(tester);
      expect(find.text('Apple Account email'), findsOneWidget);
    });
  });

  group('screenshots', () {
    macScreenMatrix(
      'mac_setup_welcome',
      (t) => app(FakeHost(chosen: false, mac: macSource(enabled: false, decided: false)), t),
      themes: macAccents,
      before: settle,
    );

    macScreenMatrix(
      'mac_setup_preparing',
      (t) => app(
        FakeHost(
          status: statusWith(
            ModelOutStateEnum.pulling,
            progress: Progress(completed: 4200000000, total: 9300000000, percent: 45, status: 'pulling'),
          ),
        ),
        t,
      ),
      themes: macAccents,
      before: settle,
    );

    macScreenMatrix('mac_status', (t) => app(realHost(), t), themes: macAccents, before: settle);

    macScreenMatrix(
      'mac_status_details',
      (t) => app(FakeHost(status: statusWith(ModelOutStateEnum.ready, modelBytes: 9300000000), agents: agents), t),
      themes: macAccents,
      before: (tester) async {
        await settle(tester);
        await tester.tap(find.text(MacStatusView.details));
        await settle(tester);
      },
    );

    macScreenMatrix(
      'mac_settings_sources',
      (t) => app(realHost(mac: macSource(calendars: 'denied', counts: SyncCounts(contacts: 412))), t),
      themes: macAccents,
      before: (tester) => openSettings(tester, SettingsTab.sources),
    );

    macScreenMatrix(
      'mac_settings_sources_advanced',
      (t) => app(
        realHost(
          accounts: [
            icloudSource('sam@example.com'),
            icloudSource(
              'ava@example.org',
              lastError: 'Apple did not accept this sign-in. Use the email of your Apple Account and an '
                  'app-specific password made at account.apple.com.',
            ),
          ],
        ),
        t,
      ),
      themes: macAccents,
      before: (tester) async {
        await openSettings(tester, SettingsTab.sources);
        await tester.ensureVisible(find.text('Follow an iCloud account'));
        await tester.tap(find.text('Follow an iCloud account'));
        await settle(tester);
        await tester.ensureVisible(find.text('ava@example.org'));
        await settle(tester);
      },
    );

    macScreenMatrix(
      'mac_settings_appearance',
      (t) => app(realHost(), t),
      themes: macAccents,
      before: (tester) => openSettings(tester, SettingsTab.appearance),
    );

    macScreenMatrix(
      'mac_settings_assistant',
      (t) => app(realHost(), t),
      themes: macAccents,
      before: (tester) => openSettings(tester, SettingsTab.assistant),
    );

    macScreenMatrix(
      'mac_settings_agents',
      (t) => app(realHost(), t),
      themes: macAccents,
      before: (tester) => openSettings(tester, SettingsTab.agents),
    );

    macScreenMatrix(
      'mac_settings_about',
      (t) => app(realHost(), t),
      themes: macAccents,
      before: (tester) => openSettings(tester, SettingsTab.about),
    );

    macScreenMatrix(
      'mac_import',
      (t) {
        final host = realHost(accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 128))]);
        host.imports.history = [
          ImportOut(
            id: 'imp-0',
            label: 'contacts-2026-10-01.vcf',
            source_: 'file',
            startedAt: '2026-10-01T09:00:00',
            status: 'done',
            counts: {'created': 12, 'skipped': 1},
          ),
        ];
        return app(host, t);
      },
      themes: macAccents,
      before: (tester) async {
        await settle(tester);
        await tester.tap(find.text(ImportText.section).first);
        await settle(tester);
      },
    );

    late HostController stopping;
    macScreenMatrix(
      'mac_host_stopped',
      (t) {
        final host = realHost();
        stopping = host.controller();
        useAccent(t.themeId);
        final widget = MyDataApp(
          controller: stopping,
          store: MemoryDeviceStore({'mode': t.brightness.name}),
          macSystem: FakeMacSystem(),
          installedApps: FakeLaunchServices(const {}).apps(),
          acceptDrops: false,
        );
        host.down = true;
        return widget;
      },
      themes: macAccents,
      before: (tester) async {
        await settle(tester);
        await stopping.refresh();
        await stopping.refresh();
        await settle(tester);
      },
    );
  });
}
