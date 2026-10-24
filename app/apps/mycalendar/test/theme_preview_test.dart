// myCalendar in the theme preview harness (mydata_testing's themePreview; app/tool/preview_themes.sh): the
// month with a day selected, in any theme file and palette, light and dark, off-screen; with
// `--all-screens`, two sources, a month outside This Mac's window and no source too.
import 'package:flutter/material.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

Widget _app(ThemeCase t, {String? day, FakeBackend? backend, List<String> hidden = const []}) {
  final h = mac.Harness(theme: t, backend: backend, hidden: hidden);
  if (day != null) h.links.open('mycalendar://day/$day');
  return h.app;
}

void main() {
  themePreview('mycalendar', [
    // October 2026, today (Tuesday 13) marked, Friday 16 selected with its events beside the month.
    ThemeScreen('month', (t) => _app(t, day: '2026-10-16'), before: mac.settle),
    // This Mac and a followed iCloud account in the sidebar, one copy of Personal hidden.
    ThemeScreen('two_sources', (t) => _app(t, backend: FakeBackend(icloudOn: true), hidden: ['m-personal']),
        before: mac.settle),
    // October 2025: the first twelve days are before This Mac's window.
    ThemeScreen('outside_window', (t) => _app(t, day: '2025-10-07'), before: mac.settle),
    // No source on.
    ThemeScreen('no_source', (t) => _app(t, backend: FakeBackend(macOn: false)), before: mac.settle),
  ]);
}
