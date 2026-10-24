// A finger on a desktop's touch screen raises every target to the coarse floor (44). Every size a widget
// counts with, not only what it draws, must see the raised density, or lists scroll to the wrong row and
// bars overflow (design/themes/ARCHITECTURE.md 1.4).
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

/// Kiwi with compact controls and rows (28), so the coarse floor changes them.
ThemeFile _compact() {
  final json = jsonDecode(kiwiThemeJson) as Map<String, dynamic>;
  json['density'] = {
    'desktop': {'control': 28, 'row': 28, 'icon': 16, 'space': 1},
    'phone': {'control': 44, 'row': 44, 'icon': 16, 'space': 1},
  };
  return ThemeFile.fromJson(json, base: json);
}

final _items = [
  for (final name in ['Home', 'Work', 'Book club', 'Family', 'Football', 'School', 'Garden', 'Holidays', 'Car', 'Dentist'])
    SelectItem<String>(value: name, title: name),
];

void main() {
  setUp(() => MyDataDensity.debugFloor = null);
  tearDown(() => MyDataDensity.debugFloor = MyDataDensity.desktopFloor);

  Future<void> pump(WidgetTester tester, Widget Function(BuildContext) child) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final look = ThemeLibrary.look(_compact(), brightness: Brightness.light, platform: TargetPlatform.linux);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MyDataTheme.fromLook(look),
      builder: (context, nav) => MyDataAccessibilityScope(child: nav!),
      home: Builder(builder: (context) => Material(color: context.colors.bg, child: child(context))),
    ));
  }

  testWidgets('look.density, lookNow.density and context.density agree under a finger', (tester) async {
    late BuildContext ctx;
    await pump(tester, (context) {
      ctx = context;
      return const SizedBox.expand();
    });
    expect(ctx.look.density.controlHeight, 28);
    await tester.tapAt(const Offset(300, 600), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(ctx.density.controlHeight, 44);
    expect(ctx.look.density.controlHeight, 44);
    expect(ctx.lookNow.density.rowHeight, 44);
    // Made once per look, not on every read.
    expect(identical(ctx.look, ctx.look), isTrue);
    await tester.tapAt(const Offset(300, 600), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(ctx.look.density.controlHeight, 28);
  });

  testWidgets('the size changes only once the finger is lifted', (tester) async {
    late BuildContext ctx;
    await pump(tester, (context) {
      ctx = context;
      return const SizedBox.expand();
    });
    final finger = await tester.startGesture(const Offset(300, 600), kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(ctx.density.controlHeight, 28);
    await finger.up();
    await tester.pump();
    expect(ctx.density.controlHeight, 44);
  });

  testWidgets('after a tap, a floating bar and a segmented control hold their 44 px items', (tester) async {
    await pump(
      tester,
      (context) => Column(children: [
        SegmentedControl<int>(segments: const [(0, 'Day'), (1, 'Week'), (2, 'Month')], selected: 1, onChanged: (_) {}),
        SizedBox(
          width: 400,
          height: 200,
          child: FloatingBarHost(
            bar: FloatingBar(current: 0, items: [
              for (final label in ['Library', 'Albums', 'People']) FloatingBarItem(label: label, onPressed: () {}),
            ]),
            child: const SizedBox.expand(),
          ),
        ),
      ]),
    );
    await tester.tapAt(const Offset(500, 650), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final bar = tester.getSize(find.byType(FloatingBar));
    final item = tester.getSize(find.ancestor(of: find.text('Albums'), matching: find.byType(Pressable)).first);
    expect(item.height, greaterThanOrEqualTo(44));
    expect(bar.height, greaterThanOrEqualTo(item.height));
    for (final label in ['Day', 'Week', 'Month']) {
      final segment = tester.getSize(find.ancestor(of: find.text(label), matching: find.byType(Pressable)).first);
      expect(segment.width, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('after a tap, an open Select scrolls its chosen row into view at the drawn height', (tester) async {
    await pump(
      tester,
      (context) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 280,
          child: MyDataSelect<String>(label: 'Calendar', items: _items, value: 'Dentist', onChanged: (_) {}),
        ),
      ),
    );
    await tester.tap(find.byType(MyDataSelect<String>), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The chosen row, last of ten, is in the list's viewport and drawn at the coarse height.
    final row = find.text('Dentist').last;
    final list = find.ancestor(of: row, matching: find.byType(Scrollable)).first;
    final rowRect = tester.getRect(find
        .ancestor(of: row, matching: find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('_ListRow')))
        .first);
    final listRect = tester.getRect(list);
    expect(rowRect.height, greaterThanOrEqualTo(44));
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top - 0.5));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom + 0.5));
  });
}
