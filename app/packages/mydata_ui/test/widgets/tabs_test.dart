import 'dart:ui' show SemanticsAction, SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _settings = ['General', 'Storage and backup', 'Devices', 'Appearance', 'Assistant'];

/// Holds the current tab the way a screen does.
class _Host extends StatefulWidget {
  const _Host({this.initial = 0, this.tabs = _settings, this.onChanged});
  final int initial;
  final List<String> tabs;
  final ValueChanged<int>? onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int current = widget.initial;

  @override
  Widget build(BuildContext context) => MyDataTabs(
        tabs: widget.tabs,
        current: current,
        semanticLabel: 'Settings',
        onChanged: (i) {
          widget.onChanged?.call(i);
          setState(() => current = i);
        },
      );
}

/// The pill: the only box filled with `accent-soft`.
Finder _pill(BuildContext context) => find.byWidgetPredicate((w) =>
    w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == context.colors.accentSoft);

Finder _tab(String name) => find.ancestor(of: find.text(name), matching: find.byType(Pressable));

void main() {
  goldenMatrix(
    'tabs',
    () => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // As in the preview, with the keyboard focus ring on the current tab.
      MyDataTabs(tabs: _settings, current: 2, onChanged: (_) {}, semanticLabel: 'Settings'),
      const SizedBox(height: MyDataSpace.s6),
      // Disabled.
      const MyDataTabs(tabs: ['Photos', 'Albums', 'People', 'Places'], current: 0, onChanged: null),
      const SizedBox(height: MyDataSpace.s6),
      // Too narrow for one run: the row wraps.
      SizedBox(
        width: 360,
        child: MyDataTabs(tabs: _settings, current: 1, onChanged: (_) {}),
      ),
    ]),
    size: const Size(640, 296),
    before: (tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    },
  );

  testWidgets('Tapping a tab reports it; tapping the current tab does not', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: picked.add)));
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    expect(picked, [2]);
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    expect(picked, [2]);
  });

  testWidgets('The current tab is accent body-strong; the others are ink-muted body', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 2)));
    await tester.pumpAndSettle();
    final colors = tester.element(find.byType(MyDataTabs)).colors;
    TextStyle styleOf(String name) =>
        tester.widget<DefaultTextStyle>(find.ancestor(of: find.text(name), matching: find.byType(DefaultTextStyle)).first).style;
    expect(styleOf('Devices').color, colors.accent);
    expect(styleOf('Devices').fontWeight, MyDataType.bodyStrong.fontWeight);
    expect(styleOf('General').color, colors.inkMuted);
    expect(styleOf('General').fontWeight, MyDataType.body.fontWeight);
  });

  testWidgets('Tab reaches the current tab only; arrows, Home and End move and pick', (tester) async {
    final picked = <int>[];
    var after = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Column(children: [
          _Host(initial: 2, onChanged: picked.add),
          Pressable(onPressed: () => after++, borderRadius: MyDataRadii.control, child: const SizedBox(width: 80, height: 44)),
        ])));
    FocusNode focusOf(String name) => Focus.of(tester.element(find.text(name)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusOf('Devices').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(picked, [3]);
    expect(focusOf('Appearance').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // wraps to the first
    await tester.pumpAndSettle();
    expect(picked, [3, 4, 0]);
    expect(focusOf('General').hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft); // wraps to the last
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(picked, [3, 4, 0, 4, 0, 4]);

    // Tab leaves the row instead of visiting the other tabs.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(after, 1);
  });

  testWidgets('Arrow keys follow reading order right to left', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Directionality(textDirection: TextDirection.rtl, child: _Host(initial: 1, onChanged: picked.add))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(picked, [2]);
    // The first tab is on the right.
    expect(tester.getCenter(_tab('General')).dx, greaterThan(tester.getCenter(_tab('Devices')).dx));
  });

  testWidgets('Semantics: a tab bar of tabs, the current one selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 2)));
    final devices = tester.getSemantics(find.text('Devices'));
    expect(devices.getSemanticsData().role, SemanticsRole.tab);
    expect(devices, matchesSemantics(label: 'Devices', isSelected: true, hasSelectedState: true,
        hasEnabledState: true, isEnabled: true, isFocusable: true, hasTapAction: true, hasFocusAction: true));
    final general = tester.getSemantics(find.text('General'));
    expect(general.getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    expect(general.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final bar = tester.getSemantics(find.byType(MyDataTabs));
    expect(bar.getSemanticsData().role, SemanticsRole.tabBar);
    expect(bar.label, 'Settings');
    handle.dispose();
  });

  testWidgets('Every tab is control-height tall and at least 44px wide', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(tabs: ['A', 'Storage and backup'])));
    for (final name in ['A', 'Storage and backup']) {
      final size = tester.getSize(_tab(name));
      expect(size.height, MyDataSize.controlHeight);
      expect(size.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
    }
  });

  testWidgets('Tabs keep their width when the current tab changes', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    final before = [for (final n in _settings) tester.getRect(_tab(n))];
    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    expect([for (final n in _settings) tester.getRect(_tab(n))], before);
  });

  testWidgets('The pill slides with spring and settles on the new tab', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
    final context = tester.element(find.byType(MyDataTabs));
    expect(tester.getRect(_pill(context)), tester.getRect(_tab('General')));
    await tester.tap(find.text('Assistant'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getRect(_pill(context));
    expect(mid.left, greaterThan(tester.getRect(_tab('General')).left));
    expect(mid.left, lessThan(tester.getRect(_tab('Assistant')).left));
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill(context)), tester.getRect(_tab('Assistant')));
  });

  testWidgets('With reduced motion the pill jumps', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(), reduceMotion: true));
    final context = tester.element(find.byType(MyDataTabs));
    await tester.tap(find.text('Assistant'));
    await tester.pump();
    expect(tester.getRect(_pill(context)), tester.getRect(_tab('Assistant')));
  });

  testWidgets('A narrow row wraps and stays inside its width', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const SizedBox(width: 300, child: _Host())));
    final row = tester.getRect(find.byType(MyDataTabs));
    for (final n in _settings) {
      final r = tester.getRect(_tab(n));
      expect(r.right, lessThanOrEqualTo(row.right));
    }
    expect(tester.getRect(_tab('Assistant')).top, greaterThan(tester.getRect(_tab('General')).top));
  });

  testWidgets('Disabled: no picks, no focus, dimmed pill', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first, const MyDataTabs(tabs: ['Photos', 'Albums'], current: 0, onChanged: null)));
    await tester.tap(find.text('Albums'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Photos'))).hasFocus, isFalse);
    final context = tester.element(find.byType(MyDataTabs));
    // The pill and the label are dimmed together, by the current tab's own opacity.
    final fade = find.ancestor(of: _pill(context), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, Pressable.disabledOpacity);
    expect(find.descendant(of: fade, matching: find.text('Photos')), findsOneWidget);
  });

  testWidgets('Pressing the current tab scales and dims pill and label together', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 2)));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MyDataTabs));
    final rest = tester.getRect(_tab('Devices'));
    expect(tester.getRect(_pill(context)), rest);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Devices')));
    await tester.pump();
    // One scale and one fade hold both the pill and the label.
    final scale = find.ancestor(of: _pill(context), matching: find.byType(ScaleTransition)).first;
    final fade = find.ancestor(of: _pill(context), matching: find.byType(FadeTransition)).first;
    expect(find.descendant(of: scale, matching: find.text('Devices')), findsOneWidget);
    expect(find.descendant(of: fade, matching: find.text('Devices')), findsOneWidget);
    expect(tester.widget<ScaleTransition>(scale).scale.value, MyDataMotion.pressScale);
    expect(tester.widget<FadeTransition>(fade).opacity.value, MyDataMotion.pressOpacity);
    final pressed = tester.getRect(_pill(context));
    expect(pressed.width, moreOrLessEquals(rest.width * MyDataMotion.pressScale));
    expect(pressed.center, rest.center);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(_pill(context)), rest);
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });

  testWidgets('With reduced motion a press on the current tab dims pill and label without scaling', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: 2), reduceMotion: true));
    final context = tester.element(find.byType(MyDataTabs));
    final rest = tester.getRect(_tab('Devices'));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Devices')));
    await tester.pump();
    expect(find.ancestor(of: _pill(context), matching: find.byType(ScaleTransition)), findsNothing);
    expect(tester.getRect(_pill(context)), rest);
    final fade = find.ancestor(of: _pill(context), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, MyDataMotion.pressOpacity);
    expect(find.descendant(of: fade, matching: find.text('Devices')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
