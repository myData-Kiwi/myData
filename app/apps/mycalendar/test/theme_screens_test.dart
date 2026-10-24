// myCalendar's key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// month in every theme as goldens (test/screenshots/theme_month.*). Every theme file, palette and screen for
// review: the preview harness (theme_preview_test.dart).
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
  // October 2026, today (Tuesday 13) marked, Friday 16 selected with its events beside the month.
  final month = ThemeScreen('month', (t) => _app(t, day: '2026-10-16'), before: mac.settle);
  themeScreens(month, size: const Size(1280, 900));

  // Large's 52 px targets reach the Mac window's own controls: "‹ Today ›", the calendar list, the days.
  themeTargets(month, size: const Size(1280, 900));

  // The smallest window, in the largest type and the heaviest edges: the month over the day list.
  themeNarrow(month);

  // The month's grid is the same in every theme (layout stays out of themes), so its pictures differ less
  // than a list's; before the drawn looks reached it the closest two (Frosted and Paperback) scored 0.06.
  themesDistinct('month', least: 0.18, size: const Size(1280, 900));

  // Today is the theme's mark in a drawn theme (`components.today`), never System's red, which in Sticker
  // reads as its danger colour; System keeps the red capsule, as Calendar.app does.
  BoxDecoration todayMark(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.ancestor(of: find.text('13'), matching: find.byType(DecoratedBox)))
      .map((b) => b.decoration)
      .where((d) => d.isBox)
      .map((d) => d.box)
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

  // A calendar's colour as its source gives it can be near the ground (a dark grey Choir calendar on High
  // Contrast's black): a dot then carries DataColour's 3:1 edge, never the Mac's 2.2:1 hairline, and an
  // all-day chip carries the colour in a bar with that edge, never in a faint tint alone.
  macTestWidgets('every calendar mark in the Mac month reads at 3:1 in high contrast, dark', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MacLook.debugOverride = true;
    addTearDown(() => MacLook.debugOverride = null);
    await tester.pumpWidget(_app(const ThemeCase('high-contrast', Brightness.dark, drawnOnMac: true), day: '2026-10-16'));
    await mac.settle(tester);
    final c = tester.element(find.text('13')).colors;
    double ratio(Color a, Color b) => dataColourContrast(a, b);
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle && d.color != null)
        .toList();
    expect(dots, isNotEmpty);
    for (final d in dots) {
      if (ratio(d.color!, c.surface) >= 3) continue;
      final edge = (d.border! as Border).top;
      expect(ratio(edge.color, c.surface), greaterThanOrEqualTo(3), reason: '${d.color}');
      expect(edge.width, greaterThanOrEqualTo(1), reason: '${d.color}');
    }
    for (final chip in ['Rent', 'Seed swap']) {
      final box = find.ancestor(of: find.text(chip), matching: find.byType(Container)).first;
      expect(find.descendant(of: box, matching: find.byType(DataBar)), findsOneWidget, reason: chip);
    }
  });

  // A boxed month in a theme with full separators boxes every day in the theme's own line, its colour and
  // width (High Contrast's 2 px of ink, Large's 2 px of line-strong), and the line beside the day list is
  // the same; Kiwi's stays `line`.
  for (final slug in ['high-contrast', 'large', 'kiwi']) {
    macTestWidgets('a boxed Mac month is ruled in $slug\'s own line', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      MacLook.debugOverride = true;
      addTearDown(() => MacLook.debugOverride = null);
      await tester.pumpWidget(_app(ThemeCase(slug, Brightness.light, drawnOnMac: true), day: '2026-10-16'));
      await mac.settle(tester);
      final look = MyDataLook.of(tester.element(find.text('13')));
      expect(look.variants.month, MonthStyle.boxed);
      final width = look.edges.width < 1 ? 1.0 : look.edges.width;
      final cell = tester
          .widgetList<DecoratedBox>(find.ancestor(of: find.text('14'), matching: find.byType(DecoratedBox)))
          .map((b) => b.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border is Border && (d.border! as Border).top != BorderSide.none);
      expect((cell.border! as Border).top, BorderSide(color: look.edges.colour, width: width));
      final divider = tester.widget<VerticalDivider>(find.byType(VerticalDivider));
      expect((divider.color, divider.thickness), (look.edges.colour, width));
    });
  }
}

