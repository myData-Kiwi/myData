// The other apps on the Status screen, the note under a followed iCloud account while This Mac is on, and
// the mydata://settings/sources link. Against a fake host and a fake LaunchServices, with invented data.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/apps_section.dart';
import 'package:mydata/src/shell.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// The app against [host], with [launch] standing in for LaunchServices; returns the apps it opened.
Future<List<MyDataAppId>> pumpApp(
  WidgetTester tester,
  FakeHost host, {
  FakeLaunchServices? launch,
  bool opens = true,
  Stream<MyDataLink>? links,
  Size size = const Size(1280, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = host.controller();
  addTearDown(controller.dispose);
  final opened = <MyDataAppId>[];
  await tester.pumpWidget(
    MyDataApp(
      controller: controller,
      store: MemoryDeviceStore(),
      macSystem: FakeMacSystem(),
      installedApps: (launch ?? FakeLaunchServices()).apps(),
      openApp: (app) async {
        opened.add(app);
        return opens;
      },
      links: links,
    ),
  );
  await settle(tester);
  return opened;
}

/// The caption of the app row for [app].
String captionOf(WidgetTester tester, MyDataAppId app) =>
    tester.widget<ActionRow>(find.byKey(ValueKey('app-${app.name}'))).subtitle!;

Finder openButtonOf(MyDataAppId app) =>
    find.descendant(of: find.byKey(ValueKey('app-${app.name}')), matching: find.widgetWithText(Button, 'Open'));

Finder notInstalledOf(MyDataAppId app) =>
    find.descendant(of: find.byKey(ValueKey('app-${app.name}')), matching: find.text(AppsSection.notInstalled));

void main() {
  group('AppsText', () {
    test('counts in words', () {
      expect(AppsText.counted(0, 'contact', 'contacts'), 'No contacts');
      expect(AppsText.counted(1, 'calendar', 'calendars'), '1 calendar');
      expect(AppsText.counted(214, 'contact', 'contacts'), '214 contacts');
    });

    test('names the sources as everywhere else', () {
      expect(AppsText.sourceNames([macSource()]), 'this Mac');
      expect(
        AppsText.sourceNames([macSource(), icloudSource('sam@example.com'), icloudSource('ava@example.org')]),
        'this Mac, the iCloud account sam@example.com and the iCloud account ava@example.org',
      );
    });
  });

  group('the apps on Status', () {
    testWidgets('a row per app: installed with Open, or not installed', (tester) async {
      final launch = FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.myassistant});
      await pumpApp(tester, FakeHost(mac: macSource()), launch: launch);
      expect(find.text(AppsSection.heading), findsOneWidget);
      for (final app in AppsSection.listed) {
        expect(find.text(app.displayName), findsOneWidget);
      }
      expect(openButtonOf(MyDataAppId.mycontacts), findsOneWidget);
      expect(openButtonOf(MyDataAppId.myassistant), findsOneWidget);
      expect(openButtonOf(MyDataAppId.mycalendar), findsNothing);
      expect(notInstalledOf(MyDataAppId.mycalendar), findsOneWidget);
      expect(notInstalledOf(MyDataAppId.mycontacts), findsNothing);
      // The Open buttons are tonal: the screen's filled button is not theirs.
      expect(
        tester.widgetList<Button>(find.widgetWithText(Button, 'Open')).every((b) => b.variant == ButtonVariant.tonal),
        isTrue,
      );
      expect(captionOf(tester, MyDataAppId.myassistant), AppsText.assistant);
    });

    testWidgets('the data apps count what the sources hold, and name them', (tester) async {
      await pumpApp(
        tester,
        FakeHost(
          mac: macSource(counts: SyncCounts(contacts: 214, calendars: 3)),
          accounts: [icloudSource('sam@example.com', counts: SyncCounts(contacts: 1, calendars: 4))],
        ),
      );
      expect(
        captionOf(tester, MyDataAppId.mycontacts),
        '215 contacts from this Mac and the iCloud account sam@example.com',
      );
      expect(
        captionOf(tester, MyDataAppId.mycalendar),
        '7 calendars from this Mac and the iCloud account sam@example.com',
      );
    });

    testWidgets('with no source on, the data apps say where to turn one on', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource(enabled: false)));
      expect(captionOf(tester, MyDataAppId.mycontacts), AppsText.noSource);
      expect(captionOf(tester, MyDataAppId.mycalendar), AppsText.noSource);
    });

    testWidgets('the counts follow the status poll', (tester) async {
      final host = FakeHost(mac: macSource(counts: SyncCounts(contacts: 1, calendars: 1)));
      final controller = host.controller();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(1280, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MyDataApp(
          controller: controller,
          store: MemoryDeviceStore(),
          macSystem: FakeMacSystem(),
          installedApps: FakeLaunchServices().apps(),
        ),
      );
      await settle(tester);
      expect(captionOf(tester, MyDataAppId.mycontacts), '1 contact from this Mac');
      host.mac = macSource(counts: SyncCounts(contacts: 40, calendars: 2));
      await controller.refresh();
      await settle(tester);
      expect(captionOf(tester, MyDataAppId.mycontacts), '40 contacts from this Mac');
      expect(captionOf(tester, MyDataAppId.mycalendar), '2 calendars from this Mac');
    });

    testWidgets('Open opens that app', (tester) async {
      final launch = FakeLaunchServices({...AppsSection.listed});
      final opened = await pumpApp(tester, FakeHost(), launch: launch);
      await tester.tap(openButtonOf(MyDataAppId.mycalendar));
      await tester.tap(openButtonOf(MyDataAppId.myassistant));
      await settle(tester);
      expect(opened, [MyDataAppId.mycalendar, MyDataAppId.myassistant]);
    });

    testWidgets('an app that would not open: one line says so, and the apps are looked up again', (tester) async {
      final launch = FakeLaunchServices({MyDataAppId.mycontacts});
      await pumpApp(tester, FakeHost(), launch: launch, opens: false);
      expect(launch.lookups, 3);
      launch.present.clear(); // removed meanwhile
      await tester.tap(openButtonOf(MyDataAppId.mycontacts));
      await settle(tester);
      expect(find.text(HomeShell.openFailed(MyDataAppId.mycontacts)), findsOneWidget);
      expect(launch.lookups, 6);
      expect(notInstalledOf(MyDataAppId.mycontacts), findsOneWidget);
    });

    testWidgets('installed apps are looked up once, and again when myData comes back to the front', (tester) async {
      final launch = FakeLaunchServices();
      await pumpApp(tester, FakeHost(), launch: launch);
      expect(launch.lookups, 3);
      expect(openButtonOf(MyDataAppId.mycontacts), findsNothing);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.tap(find.text('Status'));
      await settle(tester);
      expect(launch.lookups, 3, reason: 'not on every visit to the screen');

      launch.present.add(MyDataAppId.mycontacts);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(launch.lookups, 6);
      expect(openButtonOf(MyDataAppId.mycontacts), findsOneWidget);
    });
  });

  group('a followed iCloud account while This Mac is on', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text('Settings'));
      await settle(tester);
    }

    String captionOfAccount(WidgetTester tester, String id) =>
        tester.widget<ActionRow>(find.byKey(ValueKey('account-$id'))).subtitle!;

    testWidgets('says, under the account, that it is not needed and its calendars appear twice', (tester) async {
      await pumpApp(
        tester,
        FakeHost(
          status: statusWith(ModelOutStateEnum.ready, macAvailable: true),
          mac: macSource(),
          accounts: [icloudSource('sam@example.com')],
        ),
      );
      await openSettings(tester);
      final caption = captionOfAccount(tester, 'acct-sam');
      expect(caption, startsWith('Last synced '));
      expect(caption, endsWith('\n${IcloudSection.notNeededOnMac}'));
      expect(
        IcloudSection.notNeededOnMac,
        'Following this iCloud account is not needed on a Mac that has it in System Settings. Its calendars '
        'appear twice; hide one copy in myCalendar.',
      );
      // Plain words, not an error: no danger colour anywhere near it.
      final row = tester.widget<ActionRow>(find.byKey(const ValueKey('account-acct-sam')));
      expect(row.badge, isNull);
    });

    testWidgets('not while This Mac is off', (tester) async {
      await pumpApp(
        tester,
        FakeHost(
          status: statusWith(ModelOutStateEnum.ready, macAvailable: true),
          mac: macSource(enabled: false),
          accounts: [icloudSource('sam@example.com')],
        ),
      );
      await openSettings(tester);
      expect(captionOfAccount(tester, 'acct-sam'), isNot(contains(IcloudSection.notNeededOnMac)));
    });

    testWidgets('not on a host that is not a Mac', (tester) async {
      await pumpApp(tester, FakeHost(accounts: [icloudSource('sam@example.com')]));
      await openSettings(tester);
      expect(captionOfAccount(tester, 'acct-sam'), isNot(contains(IcloudSection.notNeededOnMac)));
    });
  });

  group('mydata://settings/sources', () {
    bool settingsShown(WidgetTester tester) => tester.widget<AppFrame>(find.byType(AppFrame)).current == 2;

    testWidgets('opens Settings, scrolled to Sources', (tester) async {
      final links = StreamController<MyDataLink>();
      addTearDown(links.close);
      await pumpApp(
        tester,
        FakeHost(status: statusWith(ModelOutStateEnum.ready, macAvailable: true), mac: macSource()),
        links: links.stream,
        size: const Size(1280, 800),
      );
      expect(settingsShown(tester), isFalse);

      links.add(const OpenMyDataSources());
      await settle(tester);
      expect(settingsShown(tester), isTrue);
      final heading = tester.getRect(find.text(SourcesSections.heading));
      expect(heading.top, inInclusiveRange(0, 100), reason: 'Sources is brought to the top');

      // Again from Status: it comes back to Sources.
      await tester.tap(find.text('Status'));
      await settle(tester);
      links.add(const OpenMyDataSources());
      await settle(tester);
      expect(settingsShown(tester), isTrue);
    });

    testWidgets('other apps\' links are not for myData', (tester) async {
      await pumpApp(tester, FakeHost(), links: Stream.value(OpenDay(DateTime(2026, 3, 20))));
      expect(settingsShown(tester), isFalse);
    });

    testWidgets('a link during setup waits until setup is done', (tester) async {
      final host = FakeHost(status: statusWith(ModelOutStateEnum.loading));
      await pumpApp(tester, host, links: Stream.value(const OpenMyDataSources()));
      expect(find.text('Preparing the assistant'), findsOneWidget); // still in setup
      expect(find.byType(AppFrame), findsNothing);
      await tester.tap(find.widgetWithText(Button, 'Skip for now'));
      await settle(tester);
      expect(settingsShown(tester), isTrue);
    });
  });
}
