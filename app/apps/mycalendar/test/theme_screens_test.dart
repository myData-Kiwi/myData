// myCalendar's key screens in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// month in every theme as goldens (test/screenshots/theme_month.*), and with
// `--dart-define=MYDATA_SHOTS=<folder> --update-goldens` every screen and palette, off-screen, for review.
import 'package:flutter/widgets.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

Widget _app(ThemeCase t, {String? day, FakeBackend? backend, List<String> hidden = const []}) {
  final h = mac.Harness(theme: t, backend: backend, hidden: hidden);
  if (day != null) h.links.open('mycalendar://day/$day');
  return h.app;
}

void main() {
  themeScreens(
    'mycalendar',
    [
      // October 2026, today (Tuesday 13) marked, Friday 16 selected with its events beside the month.
      ThemeScreen('month', (t) => _app(t, day: '2026-10-16'), before: mac.settle),
      // This Mac and a followed iCloud account in the sidebar, one copy of Personal hidden.
      ThemeScreen('two_sources', (t) => _app(t, backend: FakeBackend(icloudOn: true), hidden: ['m-personal']),
          before: mac.settle),
      // October 2025: the first twelve days are before This Mac's window.
      ThemeScreen('outside_window', (t) => _app(t, day: '2025-10-07'), before: mac.settle),
      // No source on.
      ThemeScreen('no_source', (t) => _app(t, backend: FakeBackend(macOn: false)), before: mac.settle),
    ],
    size: const Size(1280, 900),
  );
}
