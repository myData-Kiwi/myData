// myCalendar's key screens in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// month in every theme as goldens (test/screenshots/theme_month.*), and with
// `--dart-define=MYDATA_SHOTS=<folder> --update-goldens` every screen and palette, off-screen, for review.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

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

  // The month's grid is the same in every theme (layout stays out of themes), so its pictures differ less
  // than a list's; before the drawn looks reached it the closest two (Frosted and Paperback) scored 0.06.
  themesDistinct('month', least: 0.18, size: const Size(1280, 900));

  // Today is the theme's mark in a drawn theme (`components.today`), never System's red, which in Sticker
  // reads as its danger colour; System keeps the red capsule, as Calendar.app does.
  BoxDecoration todayMark(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.ancestor(of: find.text('13'), matching: find.byType(DecoratedBox)))
      .map((b) => b.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color != null || d.border != null);
  for (final (slug, drawn) in [('sticker', true), ('frosted', true), ('kiwi', false)]) {
    macTestWidgets('today in the Mac month: $slug${drawn ? '' : ' (System)'}', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      MacLook.debugOverride = true;
      addTearDown(() => MacLook.debugOverride = null);
      await tester.pumpWidget(_app(ThemeCase(slug, Brightness.light, drawnOnMac: drawn), day: '2026-10-16'));
      await mac.settle(tester);
      final look = MyDataLook.of(tester.element(find.text('13')));
      final mark = todayMark(tester);
      if (!drawn) {
        expect(mark.color, tester.element(find.text('13')).mac.red);
      } else if (look.variants.today == TodayStyle.disc) {
        expect(mark.color, look.colors.accent);
      } else {
        expect(mark.color, isNull);
        expect((mark.border! as Border).top.color, look.colors.accent);
      }
    });
  }
}
