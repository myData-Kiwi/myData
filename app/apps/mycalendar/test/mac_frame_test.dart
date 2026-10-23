// The Mac frame (MacLook) of myCalendar: its behaviour, and screenshots at the app's window size (1280 by
// 900) in light and dark, with the system accent set to Kiwi's green and to Graphite's
// (test/screenshots/mac_*.png), the bundled Figtree under the system font's names (loadMacFonts). Refresh
// with `flutter test --update-goldens test/mac_frame_test.dart` on a Mac.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycalendar/src/app.dart';
import 'package:mycalendar/src/calendars_page.dart';
import 'package:mycalendar/src/home.dart';
import 'package:mycalendar/src/mac_calendar_list.dart';
import 'package:mycalendar/src/mac_day_list.dart';
import 'package:mycalendar/src/mac_month_grid.dart';
import 'package:mycalendar/src/mac_month_view.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart' hide MacWindow;

import 'fixtures.dart';

/// myCalendar's window (macos/Runner: MacShell.install with 1280 by 900).
const _window = Size(1280, 900);

/// Pretends the system's accent (and the text on it) is [t]'s theme's (Kiwi's green, or Graphite's), as the
/// Runner's `mydata/system_colors` channel would report it, so the screenshots show the accent options the
/// plan names. The other system colours keep their defaults.
void _systemAccent(ThemeCase t) {
  Map<String, int> colours(Brightness b) {
    final c = MyDataTheme.data(t.themeId, b).extension<MyDataColors>()!;
    return {'accent': c.accent.toARGB32(), 'on-accent': c.onAccent.toARGB32()};
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MacSystemColorsScope.channel,
    (call) async => call.method == 'get' ? {'light': colours(Brightness.light), 'dark': colours(Brightness.dark)} : null,
  );
}

class Harness {
  Harness({
    FakeBackend? backend,
    List<String> hidden = const [],
    MemoryDeviceStore? store,
    this.theme = const ThemeCase('kiwi', Brightness.light),
  }) : backend = backend ?? FakeBackend(),
       store = store ??
           MemoryDeviceStore({'mode': theme.brightness.name, 'lastTheme': theme.themeId, 'hiddenCalendars': hidden}),
      host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(theme: theme.themeId));

  final ThemeCase theme;
  final FakeBackend backend;
  final MemoryDeviceStore store;
  final FakeHost host;
  final links = FakeLinks();

  Widget get app => MyCalendarApp(
    host: host,
    store: store,
    backend: backend,
    zones: const FakeZones(),
    links: links.stream,
    actions: RecordingActions().actions,
    now: () => DateTime(2026, 10, 13, 9, 41),
  );
}

/// A device store whose writes fail while [failing].
class _FailingStore extends MemoryDeviceStore {
  _FailingStore([super.initial]);
  bool failing = false;

  @override
  Future<void> write(Map<String, Object?> values) async {
    if (failing) throw StateError('disk full');
    await super.write(values);
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Harness> start(WidgetTester tester, {Harness? harness, Size size = _window}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = harness ?? Harness();
  await tester.pumpWidget(h.app);
  await settle(tester);
  return h;
}

Finder inGrid(String text) => find.descendant(of: find.byType(MacMonthGrid), matching: find.text(text));
Finder inDayList(String text) => find.descendant(of: find.byType(MacDayList), matching: find.text(text));
Finder segment(String label) => find.bySemanticsLabel(label);

void main() {
  setUp(() => MacLook.debugOverride = true);
  tearDown(() {
    MacLook.debugOverride = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacSystemColorsScope.channel, null);
  });

  group('the Mac frame', () {
    macTestWidgets('draws the calendar list in the sidebar, the toolbar, the month and the day', (tester) async {
      await start(tester);
      expect(find.byType(MacSidebar), findsOneWidget);
      expect(find.byType(AppFrame), findsNothing);
      expect(find.byType(MacCalendarRow), findsNWidgets(macCalendars.length));
      // This Mac alone: its accounts head the groups, as in Calendar.app.
      expect(find.text('This Mac'), findsNothing);
      for (final account in ['iCloud', 'Only on this Mac', 'Google', 'Birthdays from Contacts', 'Subscribed']) {
        expect(find.descendant(of: find.byType(MacSidebar), matching: find.text(account)), findsOneWidget,
            reason: account);
      }
      // The month's name and year, and today's events in the grid and the day list.
      expect(find.bySemanticsLabel('October 2026'), findsWidgets);
      expect(inGrid('Dentist'), findsOneWidget);
      expect(inDayList('Today, Tuesday 13 October'), findsOneWidget);
      expect(inDayList('Dentist'), findsOneWidget);
      expect(inDayList('Example Dental, 4 Sample Road · Family'), findsOneWidget);
      // Every font is the system's.
      final theme = Theme.of(tester.element(find.byType(MacMonthView)));
      expect(theme.textTheme.bodyMedium!.fontFamily, MyDataMacFont.text);
      // Only Month exists, so there is no view switch (no disabled Day, Week or Year).
      for (final view in ['Day', 'Week', 'Year']) {
        expect(find.descendant(of: find.byType(MacToolbarGroup), matching: find.text(view)), findsNothing,
            reason: view);
      }
    });

    macTestWidgets('pressing a day lists its events beside the month', (tester) async {
      await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 16 October, 4 events')));
      await settle(tester);
      expect(inDayList('Friday 16 October'), findsOneWidget);
      expect(inDayList('Conference in Lisbon'), findsOneWidget);
      expect(inDayList('Day 3 of 3 · Work'), findsOneWidget);
      expect(find.descendant(of: find.byType(MacDayList), matching: find.textContaining('New York time · Work')),
          findsOneWidget);
      // At this width the cells leave the start times to the day list, so the titles have the room.
      expect(inGrid('Lunch with Ava'), findsOneWidget);
      expect(find.descendant(of: find.byType(MacMonthGrid), matching: find.textContaining('12:30')), findsNothing);
    });

    macTestWidgets('a wider window gives the start times in the cells', (tester) async {
      await start(tester, size: const Size(1600, 900));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 16 October, 4 events')));
      await settle(tester);
      expect(find.descendant(of: find.byType(MacMonthGrid), matching: find.textContaining('12:30')), findsOneWidget);
    });

    macTestWidgets('the checkboxes in the sidebar hide a calendar on this device only', (tester) async {
      final h = await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')));
      await settle(tester);
      expect((await h.store.read())['hiddenCalendars'], ['m-family']);
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Show Family'))), isSemantics(isChecked: false));
      expect(inGrid('Dentist'), findsNothing);
      expect(inDayList('Dentist'), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Tuesday 13 October, today, 1 event in Choir$')), findsOneWidget);
      // And back.
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')));
      await settle(tester);
      expect(inDayList('Dentist'), findsOneWidget);
    });

    macTestWidgets('with two sources, each heads its own calendars, and either copy can be hidden', (tester) async {
      final h = await start(tester, harness: Harness(backend: FakeBackend(icloudOn: true)));
      expect(find.text('This Mac'), findsOneWidget);
      expect(find.text('iCloud account $icloudEmail'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Show Family')), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')).last);
      await settle(tester);
      expect((await h.store.read())['hiddenCalendars'], ['ic-family']);
      expect(inDayList('Dentist'), findsOneWidget);
    });

    macTestWidgets('a hide that cannot be stored says so, and the box goes back', (tester) async {
      final store = _FailingStore({'mode': 'light'});
      await start(tester, harness: Harness(store: store));
      store.failing = true;
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')));
      await settle(tester);
      expect(find.text(CalendarsPage.saveFailed), findsOneWidget);
      expect(tester.widget<MacCalendarRow>(find.byType(MacCalendarRow).first).shown, isTrue);
      expect(inDayList('Dentist'), findsOneWidget);
    });

    macTestWidgets('a row takes the keyboard and Space toggles it', (tester) async {
      final h = await start(tester);
      for (var i = 0; i < 20; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null && focused.findAncestorWidgetOfExactType<MacCalendarRow>()?.name == 'Work') break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect((await h.store.read())['hiddenCalendars'], ['m-work']);
    });

    macTestWidgets('Today, previous and next in the toolbar, and their keys, change the month', (tester) async {
      final h = await start(tester);
      final before = h.backend.eventCalls.length;
      await tester.tap(segment(MonthGrid.nextMonthLabel));
      await settle(tester);
      expect(find.bySemanticsLabel('November 2026'), findsWidgets);
      expect(inDayList('Friday 13 November'), findsOneWidget);
      expect(h.backend.eventCalls.length, greaterThan(before));
      await tester.tap(segment(MonthGrid.todayLabel));
      await settle(tester);
      expect(inDayList('Today, Tuesday 13 October'), findsOneWidget);
      await tester.tap(segment(MonthGrid.previousMonthLabel));
      await settle(tester);
      expect(inDayList('Sunday 13 September'), findsOneWidget);

      // ⌘→, ⌘T and ⌘←, with the grid holding the keyboard from the start.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(inDayList('Today, Tuesday 13 October'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(inDayList('Friday 13 November'), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settle(tester);
      expect(inDayList('Today, Tuesday 13 October'), findsOneWidget);
    });

    macTestWidgets('the grid takes the arrow keys and Page Down, and the day list follows', (tester) async {
      await start(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(inDayList('Wednesday 14 October'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(inDayList('Wednesday 21 October'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      expect(find.bySemanticsLabel('November 2026'), findsWidgets);
      expect(inDayList('Saturday 21 November'), findsOneWidget);
    });

    macTestWidgets('a cell too short for its events ends with how many more there are', (tester) async {
      await start(tester, size: const Size(1280, 600));
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 16 October, 4 events')));
      await settle(tester);
      expect(find.descendant(of: find.byType(MacMonthGrid), matching: find.textContaining(' more')), findsWidgets);
      // The day list still has every one.
      expect(inDayList('Night train to Porto'), findsOneWidget);
    });

    macTestWidgets('days outside This Mac’s window are on the window ground with a notice', (tester) async {
      final h = await start(tester);
      h.links.open('mycalendar://day/2025-10-07');
      await settle(tester);
      expect(find.byType(Notice), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Tuesday 7 October, events not shown$')), findsOneWidget);
      expect(inDayList('Events from this Mac are not shown for this day.'), findsOneWidget);
    });

    macTestWidgets('when the host stops, the month stays and the sidebar says so', (tester) async {
      final h = await start(tester);
      h.host.lose();
      await settle(tester);
      expect(inDayList('Dentist'), findsOneWidget);
      expect(find.descendant(of: find.byType(MacSidebar), matching: find.textContaining(AppConnection.unreachableText)),
          findsOneWidget);
      expect(find.textContaining('Last updated at'), findsOneWidget);
    });

    macTestWidgets('no source on: the empty screen, and no calendar list', (tester) async {
      await start(tester, harness: Harness(backend: FakeBackend(macOn: false)));
      expect(find.text(CalendarHome.emptyTitle), findsOneWidget);
      expect(find.byType(MacCalendarRow), findsNothing);
      expect(find.byType(MacMonthView), findsNothing);
    });

    macTestWidgets('a narrow window puts the day list under the month', (tester) async {
      await start(tester, size: const Size(720, 600));
      final grid = tester.getRect(find.byType(MacMonthGrid));
      final day = tester.getRect(find.byType(MacDayList));
      expect(day.top, greaterThanOrEqualTo(grid.bottom));
    });

    macTestWidgets('a phone-sized window keeps the branded phone layout', (tester) async {
      await start(tester, size: const Size(390, 844));
      expect(find.byType(MacSidebar), findsNothing);
      expect(find.byType(MonthGrid), findsOneWidget);
    });
  });

  group('screenshots', () {
    Widget app(ThemeCase t, {String? day, FakeBackend? backend, List<String> hidden = const []}) {
      _systemAccent(t);
      final h = Harness(theme: t, backend: backend, hidden: hidden);
      if (day != null) h.links.open('mycalendar://day/$day');
      return h.app;
    }

    // October 2026, today (Tuesday 13) marked, Friday 16 selected with its events beside the month.
    macScreenMatrix('mac_month', (t) => app(t, day: '2026-10-16'), size: _window, before: settle);

    // This Mac and a followed iCloud account in the sidebar, one copy of Personal hidden.
    macScreenMatrix('mac_two_sources', (t) => app(t, backend: FakeBackend(icloudOn: true), hidden: ['m-personal']),
        size: _window, before: settle);

    // October 2025: the first twelve days are before This Mac's window.
    macScreenMatrix('mac_outside_window', (t) => app(t, day: '2025-10-07'), size: _window, before: settle);

    // No source on.
    macScreenMatrix('mac_no_source', (t) => app(t, backend: FakeBackend(macOn: false)), size: _window, before: settle);
  });
}
