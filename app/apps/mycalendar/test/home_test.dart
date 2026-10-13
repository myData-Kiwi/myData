import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycalendar/src/app.dart';
import 'package:mycalendar/src/calendar_model.dart';
import 'package:mycalendar/src/calendars_page.dart';
import 'package:mycalendar/src/home.dart';
import 'package:mycalendar/src/month_page.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

class Harness {
  Harness({
    FakeBackend? backend,
    List<String> hidden = const [],
    HostPhase phase = HostPhase.running,
    MemoryDeviceStore? store,
  }) : backend = backend ?? FakeBackend(),
       store = store ?? MemoryDeviceStore({'mode': 'light', 'hiddenCalendars': hidden}),
       host = FakeHost(phaseOnConnect: phase, statusOnConnect: hostStatus());

  final FakeBackend backend;
  final MemoryDeviceStore store;
  final FakeHost host;
  final links = FakeLinks();
  final actions = RecordingActions();

  Widget get app => MyCalendarApp(
    host: host,
    store: store,
    backend: backend,
    zones: const FakeZones(),
    links: links.stream,
    actions: actions.actions,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Harness> start(WidgetTester tester, {Harness? harness, Size size = const Size(1280, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = harness ?? Harness();
  await tester.pumpWidget(h.app);
  await settle(tester);
  return h;
}

/// A device store whose writes fail while [failing].
class FailingStore extends MemoryDeviceStore {
  FailingStore([super.initial]);
  bool failing = false;

  @override
  Future<void> write(Map<String, Object?> values) async {
    if (failing) throw StateError('disk full');
    await super.write(values);
  }
}

Finder dayList() => find.byType(DayList);
Finder inDayList(String text) => find.descendant(of: dayList(), matching: find.text(text));

void main() {
  testWidgets('shows the month the host is in, today selected, with its events', (tester) async {
    await start(tester);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Today, Tuesday 13 October'), findsOneWidget);
    expect(inDayList('Dentist'), findsOneWidget);
    expect(inDayList('Choir practice'), findsOneWidget);
    expect(find.text('Example Dental, 4 Sample Road · Family'), findsOneWidget);
    // This Mac reads every day of October 2026: no notice.
    expect(find.byType(Notice), findsNothing);
  });

  testWidgets('pressing a day lists its events, with the calendar named in each caption', (tester) async {
    await start(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Friday 16 October, 4 events')));
    await settle(tester);
    expect(find.text('Friday 16 October'), findsOneWidget);
    expect(inDayList('Conference in Lisbon'), findsOneWidget);
    expect(find.text('Day 3 of 3 · Work'), findsOneWidget);
    expect(find.textContaining('New York time · Work'), findsOneWidget);
    expect(inDayList('Night train to Porto'), findsOneWidget);
  });

  testWidgets('a hidden calendar is left out of the grid and the day list', (tester) async {
    await start(tester, harness: Harness(hidden: ['m-family']));
    expect(inDayList('Dentist'), findsNothing);
    expect(inDayList('Choir practice'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tuesday 13 October, today, 1 event in Choir$')), findsOneWidget);
  });

  testWidgets('the next and previous months are read from the host', (tester) async {
    final h = await start(tester);
    final before = h.backend.eventCalls.length;
    await tester.tap(find.bySemanticsLabel('Next month'));
    await settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    // The selection moved into November, keeping its day.
    expect(find.text('Friday 13 November'), findsOneWidget);
    expect(h.backend.eventCalls.length, greaterThan(before));
    await tester.tap(find.text(MonthGrid.todayLabel));
    await settle(tester);
    expect(find.text('Today, Tuesday 13 October'), findsOneWidget);
  });

  testWidgets('a mycalendar://day link selects that day', (tester) async {
    final h = await start(tester);
    h.links.open('mycalendar://day/2026-12-24');
    await settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('Thursday 24 December'), findsOneWidget);
    expect(inDayList(DayList.noEvents), findsOneWidget);
  });

  testWidgets('a link opens the Month section from Calendars', (tester) async {
    final h = await start(tester);
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    expect(find.byType(CalendarListRow), findsWidgets);
    h.links.open('mycalendar://day/2026-10-16');
    await settle(tester);
    expect(find.text('Friday 16 October'), findsOneWidget);
  });

  testWidgets('days outside This Mac’s window are not shown, and a notice gives the range', (tester) async {
    final h = await start(tester);
    h.links.open('mycalendar://day/2025-10-07');
    await settle(tester);
    expect(find.text('myData reads events from this Mac between 13 October 2025 and 13 October 2028.'),
        findsOneWidget);
    expect(find.text(DayList.notShownLine('this Mac')), findsOneWidget);
    expect(inDayList(DayList.noEvents), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Tuesday 7 October, events not shown$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tuesday 14 October, 1 event in Choir$')), findsOneWidget);
  });

  testWidgets('a month wholly outside the window says so', (tester) async {
    final h = await start(tester);
    h.links.open('mycalendar://day/2024-03-05');
    await settle(tester);
    expect(find.textContaining('This month is outside that range.'), findsOneWidget);
  });

  testWidgets('an iCloud account that reads every day keeps those days shown', (tester) async {
    final h = await start(tester, harness: Harness(backend: FakeBackend(icloudOn: true)));
    h.links.open('mycalendar://day/2025-10-07');
    await settle(tester);
    // This Mac's notice stays: the iCloud account never hides its limit.
    expect(find.textContaining('myData reads events from this Mac'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tuesday 7 October, no events$')), findsOneWidget);
    expect(find.text(DayList.notShownLine('this Mac')), findsOneWidget);
  });

  testWidgets('hiding every Mac calendar drops This Mac’s notice', (tester) async {
    final hidden = [for (final c in macCalendars) c.id];
    final h = await start(tester, harness: Harness(backend: FakeBackend(icloudOn: true), hidden: hidden));
    h.links.open('mycalendar://day/2025-10-07');
    await settle(tester);
    expect(find.byType(Notice), findsNothing);
    expect(inDayList(DayList.noEvents), findsOneWidget);
  });

  testWidgets('This Mac not asked yet: a warning that opens myData', (tester) async {
    final h = await start(tester,
        harness: Harness(
            backend: FakeBackend(mac: const MacNothing(CoverageOutReasonEnum.notReadYet), macStatus: 'notDetermined')));
    expect(find.text(MonthPageText.notAllowedYet('this Mac')), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, MonthPageText.openMyData));
    await settle(tester);
    expect(h.actions.calls, ['sources']);
    expect(find.text(DayList.notShownLine('this Mac')), findsOneWidget);
  });

  testWidgets('This Mac refused: a warning that opens System Settings', (tester) async {
    final h = await start(tester,
        harness: Harness(backend: FakeBackend(mac: const MacNothing(CoverageOutReasonEnum.noAccess), macStatus: 'denied')));
    expect(find.text(MonthPageText.refused('this Mac')), findsOneWidget);
    h.actions.succeed = false;
    await tester.tap(find.widgetWithText(Button, MonthPageText.openSystemSettings));
    await settle(tester);
    expect(h.actions.calls, ['privacy']);
    expect(find.text(CalendarHome.openSettingsFailed), findsOneWidget);
  });

  testWidgets('This Mac allowed but not read yet: an info notice with no button', (tester) async {
    await start(tester, harness: Harness(backend: FakeBackend(mac: const MacNothing(CoverageOutReasonEnum.notReadYet))));
    expect(find.text(MonthPageText.notReadYet('this Mac')), findsOneWidget);
    expect(find.widgetWithText(Button, MonthPageText.openMyData), findsNothing);
  });

  testWidgets('no source on: the empty screen opens myData at Settings, Sources', (tester) async {
    final h = await start(tester, harness: Harness(backend: FakeBackend(macOn: false)));
    expect(find.text(CalendarHome.emptyTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, CalendarHome.openMyData));
    await settle(tester);
    expect(h.actions.calls, ['sources']);
  });

  testWidgets('the calendar list shows both copies and hides one on this device only', (tester) async {
    final h = await start(tester, harness: Harness(backend: FakeBackend(icloudOn: true)));
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    expect(find.text('This Mac'), findsOneWidget);
    expect(find.text('iCloud account $icloudEmail'), findsOneWidget);
    expect(find.text('Family'), findsNWidgets(2));
    expect(find.text('Birthdays from Contacts'), findsOneWidget);
    expect(find.text('Subscribed'), findsOneWidget);
    expect(find.text('Only on this Mac'), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')).last);
    await settle(tester);
    expect((await h.store.read())['hiddenCalendars'], ['ic-family']);

    // Back on the month, the Mac's Dentist is still there; the iCloud copy is not.
    await tester.tap(find.text(MonthPage.title).first);
    await settle(tester);
    expect(inDayList('Dentist'), findsOneWidget);
  });

  testWidgets('the calendar list says it is myCalendar on this device that hides', (tester) async {
    await start(tester);
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    expect(find.text(CalendarsPage.intro), findsOneWidget);
    expect(CalendarsPage.intro, contains('myCalendar shows on this device'));
  });

  testWidgets('a hide that cannot be stored says so, and the switch goes back', (tester) async {
    final store = FailingStore({'mode': 'light'});
    await start(tester, harness: Harness(store: store));
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    store.failing = true;
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Family')).first);
    await settle(tester);
    expect(find.text(CalendarsPage.saveFailed), findsOneWidget);
    final shown = tester.widget<CalendarListRow>(find.byType(CalendarListRow).first);
    expect(shown.shown, isTrue);
    // The next change is stored.
    store.failing = false;
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Show Personal')).first);
    await settle(tester);
    expect((await store.read())['hiddenCalendars'], ['m-personal']);
  });

  testWidgets('the calendar list is keyboard reachable', (tester) async {
    final h = await start(tester);
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    final row = find.byType(CalendarListRow).first;
    Focus.of(tester.element(find.descendant(of: row, matching: find.text('Family')))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await settle(tester);
    expect((await h.store.read())['hiddenCalendars'], ['m-family']);
  });

  testWidgets('the web build explains it needs the desktop app, without the frame', (tester) async {
    await start(tester,
        harness: Harness(phase: HostPhase.unsupported));
    expect(find.text('myCalendar needs the desktop app'), findsOneWidget);
    expect(find.byType(AppFrame), findsNothing);
  });

  testWidgets('a host that stopped offers Retry in the frame and the panel', (tester) async {
    await start(tester, harness: Harness(phase: HostPhase.lost));
    expect(find.text('The myData host stopped'), findsOneWidget);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
  });

  testWidgets('a host from another build that is still there offers Retry, and does not say "did not start"',
      (tester) async {
    await start(tester, harness: Harness(phase: HostPhase.incompatible));
    expect(find.text('The myData host is from another build'), findsOneWidget);
    expect(find.textContaining('did not start'), findsNothing);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
  });

  testWidgets('when the host stops, the month and the calendars stay, with the time they were read', (tester) async {
    final h = await start(tester);
    expect(inDayList('Dentist'), findsOneWidget);
    final calls = h.backend.eventCalls.length;
    h.host.lose();
    await settle(tester);
    expect(find.text('The myData host stopped'), findsNothing);
    expect(find.text('October 2026'), findsOneWidget);
    expect(inDayList('Dentist'), findsOneWidget);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
    expect(find.textContaining('Last updated at'), findsOneWidget);

    // Nothing is asked of a host that is not there: the next month is simply not filled in.
    await tester.tap(find.bySemanticsLabel('Next month'));
    await settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(h.backend.eventCalls.length, calls);
    expect(find.text(MonthPage.failedTitle), findsNothing);
    await tester.tap(find.text(CalendarsPage.title).first);
    await settle(tester);
    expect(find.byType(CalendarListRow), findsNWidgets(macCalendars.length));

    // Back again: everything is read again.
    final calendarCalls = h.backend.calendarCalls;
    h.host.comeBack();
    await settle(tester);
    expect(h.backend.calendarCalls, greaterThan(calendarCalls));
    expect(find.textContaining('Last updated at'), findsNothing);
  });

  testWidgets('a month the host cannot read says so with Retry, and is not asked for on every frame', (tester) async {
    final backend = FakeBackend()..eventsError = ApiException(500, 'Internal Server Error');
    final h = await start(tester, harness: Harness(backend: backend));
    expect(find.text(MonthPage.failedTitle), findsOneWidget);
    expect(find.text('The host answered with an error (500). Try again in a moment.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tuesday 13 October, today, events not shown$')), findsOneWidget);
    // This month and the two either side, once each.
    expect(h.backend.eventCalls, hasLength(3));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(h.backend.eventCalls, hasLength(3));

    h.backend.eventsError = null;
    await tester.tap(find.widgetWithText(Button, AppConnection.retryText));
    await settle(tester);
    expect(find.text(MonthPage.failedTitle), findsNothing);
    expect(inDayList('Dentist'), findsOneWidget);
  });

  testWidgets('under 600px a month that cannot be read says so under the grid', (tester) async {
    final backend = FakeBackend()..eventsError = ApiException(500, 'Internal Server Error');
    await start(tester, harness: Harness(backend: backend), size: const Size(390, 1400));
    expect(tester.takeException(), isNull);
    final grid = tester.getRect(find.byType(MonthGrid));
    expect(tester.getRect(find.text(MonthPage.failedTitle)).top, greaterThan(grid.bottom));
  });

  testWidgets('calendars that cannot be read: an error with Retry, which reads them again', (tester) async {
    final backend = FakeBackend()..calendarsError = ApiException(503, 'Service Unavailable');
    final h = await start(tester, harness: Harness(backend: backend));
    expect(find.text('myCalendar could not read your calendars'), findsOneWidget);
    expect(h.backend.eventCalls, isEmpty);
    h.backend.calendarsError = null;
    await tester.tap(find.widgetWithText(Button, AppConnection.retryText).last);
    await settle(tester);
    expect(inDayList('Dentist'), findsOneWidget);
  });

  testWidgets('a link that arrives before the host is ready opens its day once the calendars are read, after an '
      'error', (tester) async {
    final backend = FakeBackend()..calendarsError = ApiException(503, 'Service Unavailable');
    final h = await start(tester, harness: Harness(backend: backend, phase: HostPhase.starting));
    h.links.open('mycalendar://day/2026-10-16');
    await settle(tester);
    h.host.comeBack();
    await settle(tester);
    expect(find.text('myCalendar could not read your calendars'), findsOneWidget);
    h.backend.calendarsError = null;
    await tester.tap(find.widgetWithText(Button, AppConnection.retryText).last);
    await settle(tester);
    expect(find.text('Friday 16 October'), findsOneWidget);
    expect(inDayList('Night train to Porto'), findsOneWidget);
  });

  testWidgets('a source turned on or off reads everything again', (tester) async {
    final h = await start(tester);
    expect(inDayList('Dentist'), findsOneWidget);
    h.backend.macOn = false;
    h.host.push(hostStatus(demo: true, epoch: 1));
    await settle(tester);
    expect(find.text(CalendarHome.emptyTitle), findsOneWidget);
  });

  testWidgets('under 600px the day list is under the grid, with dots in the cells', (tester) async {
    await start(tester, size: const Size(390, 1400));
    final grid = tester.getRect(find.byType(MonthGrid));
    final list = tester.getRect(dayList());
    expect(list.top, greaterThan(grid.bottom));
    expect(find.byType(DataDot), findsWidgets);
  });

  testWidgets('the grid takes the arrow keys and follows them with the day list', (tester) async {
    await start(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Tuesday 13 October')));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text('Wednesday 14 October'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(find.text('Wednesday 21 October'), findsOneWidget);
  });
}
