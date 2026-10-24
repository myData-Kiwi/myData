// myContacts' key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// people list with a contact open in every theme as goldens (test/screenshots/theme_people.*). Every theme
// file, palette and screen for review: the preview harness (theme_preview_test.dart).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

/// The colour on screen at [at] (logical pixels, at a device pixel ratio of 1).
Future<Color> pixel(WidgetTester tester, Offset at) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final bytes = (await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (data!, width);
  }))!;
  final (data, width) = bytes;
  final i = (at.dy.floor() * width + at.dx.floor()) * 4;
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  setUpAll(() async => mac.portrait = await portraitPng());

  final people = ThemeScreen('people', (t) => mac.app(t, lastOpened: 'c-ava'), before: mac.settle);
  themeScreens(people);

  // Large's 52 px targets reach the Mac window's own controls: the toolbar, the record's actions.
  themeTargets(people);

  // The smallest window, in the largest type and the heaviest edges.
  themeNarrow(people);

  // The pictures above differ by more than colour between every two themes.
  themesDistinct('people');

  // A bar selection (Arcade's on its cards, Swiss's on its ruled rows) keeps its 3 px bar at the row's
  // leading edge while the keyboard is on the row: the ring stands inside the bar, never over it.
  for (final slug in ['arcade', 'swiss']) {
    macTestWidgets('the selected Mac row keeps its bar under the keyboard ring in $slug', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final before = MacLook.debugOverride;
      MacLook.debugOverride = true;
      addTearDown(() => MacLook.debugOverride = before);
      await tester.pumpWidget(people.build(ThemeCase(slug, Brightness.light, drawnOnMac: true)));
      await people.before!(tester);
      final name = find.text('Ava Fictional', findRichText: true).first;
      final look = MyDataLook.of(tester.element(name));
      expect(look.variants.selection, SelectionStyle.bar);
      final mark = find.ancestor(of: name, matching: find.byType(SelectionMark)).first;
      expect(tester.widget<SelectionMark>(mark).selected, isTrue);
      final row = tester.getRect(mark);
      final bar = await pixel(tester, Offset(row.left + SelectionPaint.barWidth - 1, row.center.dy));
      expect(bar, look.colors.selection, reason: 'the bar shows at the leading edge');
    });
  }
}
