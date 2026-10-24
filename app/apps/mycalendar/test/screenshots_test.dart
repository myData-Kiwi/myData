// Whole-app screenshots in Kiwi and Graphite, light and dark: test/screenshots/<name>.<theme>-<mode>.png.
// Refresh with `flutter test --update-goldens test/screenshots_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycalendar/src/app.dart';
import 'package:mycalendar/src/backend.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';

/// The app as it starts on a device in [t]'s mode, with the host reporting [t]'s theme.
Widget app(ThemeCase t, CalendarBackend backend,
        {Stream<MyDataLink>? links, HostPhase phase = HostPhase.running, List<String> hidden = const [],
        FakeHost? host}) =>
    MyCalendarApp(
      host: host ?? FakeHost(phaseOnConnect: phase, statusOnConnect: hostStatus(theme: t.themeId)),
      store: MemoryDeviceStore({...t.deviceSettings, 'hiddenCalendars': hidden}),
      backend: backend,
      zones: const FakeZones(),
      links: links,
      actions: RecordingActions().actions,
      now: () => DateTime(2026, 10, 13, 9, 41),
    );

/// Lets the appearance, the hidden calendars and the host's data arrive, and the theme's cross-fade
/// finish. Frame by frame: the loading kiwi never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// myCalendar opens at 1280 by 900 (macos/Runner/Base.lproj/MainMenu.xib): six weeks fit at the cell height
/// the MonthGrid spec asks for.
const _window = Size(1280, 900);

void main() {
  // October 2026 with today (Tuesday 13) marked and Friday 16 selected, its events beside the grid.
  screenMatrix(
    'month',
    (t) {
      final links = FakeLinks();
      links.open('mycalendar://day/2026-10-16');
      return app(t, FakeBackend(), links: links.stream);
    },
    size: _window, before: settle,
  );

  // October 2025: the first twelve days are before This Mac's window, so they are not shown, a notice says
  // so, and the selected day (7 October) says its events from this Mac are not shown.
  screenMatrix(
    'month_outside_window',
    (t) {
      final links = FakeLinks();
      links.open('mycalendar://day/2025-10-07');
      return app(t, FakeBackend(), links: links.stream);
    },
    size: _window, before: settle,
  );

  // This Mac and a followed iCloud account: both copies of Family and Personal are listed, one hidden.
  screenMatrix(
    'calendars_list',
    (t) => app(t, FakeBackend(icloudOn: true), hidden: ['m-personal']),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Calendars').first);
      await settle(tester);
    },
  );

  // No source is on: the empty screen leads to myData's Settings, Sources.
  screenMatrix('no_source', (t) => app(t, FakeBackend(macOn: false)), size: _window, before: settle);

  // The host stopped after October was read: the month stays, and the frame says the host cannot be reached,
  // with the time it was last read.
  late FakeHost lostHost;
  screenMatrix(
    'month_unreachable',
    (t) {
      lostHost = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(theme: t.themeId));
      return app(t, FakeBackend(), host: lostHost);
    },
    before: (tester) async {
      await settle(tester);
      lostHost.lose();
      await settle(tester);
    },
  );

  // The host could not read the month: its days are marked not shown, and the day list's place says why,
  // with Retry.
  screenMatrix(
    'month_failed',
    (t) => app(t, FakeBackend()..eventsError = ApiException(500, 'Internal Server Error')),
    size: _window, before: settle,
  );
}
