import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

const _reason = 'The host cannot be reached.';

/// The colour of the focus ring drawn inside [of], or null when none is drawn.
Color? _ringColour(WidgetTester tester, Finder of) {
  final painters = tester
      .widgetList<CustomPaint>(find.descendant(of: of, matching: find.byType(CustomPaint)))
      .map((p) => p.foregroundPainter)
      .where((p) => p.runtimeType.toString() == '_FocusRingPainter');
  return painters.isEmpty ? null : (painters.single as dynamic).color as Color;
}

Color? _iconColour(WidgetTester tester, Finder button) =>
    tester.widget<Icon>(find.descendant(of: button, matching: find.byType(Icon))).color;

Finder _pressable(Finder button) => find.descendant(of: button, matching: find.byType(Pressable));

FocusNode? _focused;

/// Columns: rest, hovered, toggled, done, disabled; rows: the three tones. Then a focused button with its
/// tooltip and shortcut.
Widget _states() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final tone in IconButtonTone.values)
        Row(children: [
          MyDataIconButton(icon: MyDataIcon.add, label: 'New event', tone: tone, onPressed: _noop),
          MyDataIconButton(icon: MyDataIcon.copy, label: 'Copy', tone: tone, onPressed: _noop),
          if (tone != IconButtonTone.danger)
            MyDataIconButton(
                icon: MyDataIcon.report, label: 'Flag', tone: tone, toggled: true, onPressed: _noop)
          else
            const SizedBox(width: MyDataSize.controlHeight),
          MyDataIconButton(
              icon: MyDataIcon.copy, label: 'Copy', doneLabel: 'Copied', done: true, tone: tone, onPressed: _noop),
          MyDataIconButton(
              icon: MyDataIcon.remove, label: 'Remove mobile number', tone: tone, onPressed: null,
              disabledReason: _reason),
          MyDataIconButton(
              icon: MyDataIcon.add, label: 'New event', tone: tone, compact: true, onPressed: _noop),
        ]),
      const SizedBox(height: MyDataSpace.s4),
      Row(children: [
        const SizedBox(width: MyDataSpace.s6),
        MyDataIconButton(
          icon: MyDataIcon.add,
          label: 'New event',
          shortcut: MyDataShortcut.primary(LogicalKeyboardKey.keyN),
          focusNode: _focused = FocusNode(),
          onPressed: _noop,
        ),
        const SizedBox(width: 120),
        const MyDataIconButton(
            key: Key('hovered'), icon: MyDataIcon.copy, label: 'Copy work email', tone: IconButtonTone.quiet,
            onPressed: _noop),
      ]),
    ]);

/// Sets keyboard highlighting and puts the mouse over [hovered].
Future<void> _hoverAndFocus(WidgetTester tester, Finder hovered, FocusNode focused) async {
  tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(hovered));
  addTearDown(mouse.removePointer);
  await tester.pump();
  focused.requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  // Keyboard focus (with its tooltip at once) on the plus, the mouse over the quiet copy button (its hover
  // fill and tooltip).
  goldenMatrix('icon_button', _states, size: const Size(360, 280),
      before: (tester) => _hoverAndFocus(tester, find.byKey(const Key('hovered')), _focused!));

  // The danger tone's ring is `ink` (design/README.md "Focus and danger"), with its `danger-soft` hover.
  FocusNode? dangerNode;
  goldenMatrix(
      'icon_button_focus_danger',
      () => Row(children: [
            MyDataIconButton(
              icon: MyDataIcon.remove,
              label: 'Remove mobile number',
              tone: IconButtonTone.danger,
              focusNode: dangerNode = FocusNode(),
              onPressed: _noop,
            ),
            const SizedBox(width: 160),
            const MyDataIconButton(
              key: Key('hovered'),
              icon: MyDataIcon.remove,
              label: 'Remove home number',
              tone: IconButtonTone.danger,
              onPressed: _noop,
            ),
          ]),
      size: const Size(420, 120),
      before: (tester) => _hoverAndFocus(tester, find.byKey(const Key('hovered')), dangerNode!));

  testWidgets('a control-height circle with an icon-size glyph; compact is control-height-compact', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      MyDataIconButton(key: Key('a'), icon: MyDataIcon.add, label: 'New event', onPressed: _noop),
      MyDataIconButton(key: Key('b'), icon: MyDataIcon.add, label: 'New event', compact: true, onPressed: _noop),
    ])));
    expect(tester.getSize(find.byKey(const Key('a'))), const Size.square(MyDataSize.controlHeight));
    expect(tester.getSize(find.byKey(const Key('b'))), const Size.square(MyDataSize.controlHeightCompact));
    expect(tester.widget<Icon>(find.descendant(of: find.byKey(const Key('a')), matching: find.byType(Icon))).size,
        MyDataSize.icon);
  });

  testWidgets('tones colour the icon; toggled turns it accent on accent-soft with the filled glyph', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      MyDataIconButton(key: Key('n'), icon: MyDataIcon.add, label: 'A', onPressed: _noop),
      MyDataIconButton(key: Key('q'), icon: MyDataIcon.add, label: 'B', tone: IconButtonTone.quiet, onPressed: _noop),
      MyDataIconButton(key: Key('d'), icon: MyDataIcon.add, label: 'C', tone: IconButtonTone.danger, onPressed: _noop),
      MyDataIconButton(
          key: Key('t'), icon: MyDataIcon.report, label: 'Flag', toggled: true, onPressed: _noop),
    ])));
    final c = tester.element(find.byKey(const Key('n'))).colors;
    expect(_iconColour(tester, find.byKey(const Key('n'))), c.ink);
    expect(_iconColour(tester, find.byKey(const Key('q'))), c.inkMuted);
    expect(_iconColour(tester, find.byKey(const Key('d'))), c.danger);
    expect(_iconColour(tester, find.byKey(const Key('t'))), c.accent);
    expect(tester.widget<Icon>(find.descendant(of: find.byKey(const Key('t')), matching: find.byType(Icon))).icon,
        iconOf(MyDataIcon.report, selected: true));
  });

  testWidgets('Tab, Return and Space press it; the danger tone takes the ink ring', (tester) async {
    var pressed = 0;
    final normal = FocusNode(), danger = FocusNode();
    addTearDown(normal.dispose);
    addTearDown(danger.dispose);
    await tester.pumpWidget(themedFrame(themeMatrix.first, Row(children: [
      MyDataIconButton(key: const Key('n'), icon: MyDataIcon.add, label: 'New event', focusNode: normal, onPressed: () => pressed++),
      MyDataIconButton(
          key: const Key('d'), icon: MyDataIcon.remove, label: 'Remove', tone: IconButtonTone.danger, focusNode: danger,
          onPressed: () => pressed++),
    ])));
    final c = tester.element(find.byKey(const Key('n'))).colors;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(normal.hasFocus, isTrue);
    expect(_ringColour(tester, find.byKey(const Key('n'))), c.focus);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pressed, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(danger.hasFocus, isTrue);
    expect(_ringColour(tester, find.byKey(const Key('d'))), c.ink);
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
  });

  testWidgets('keyboard focus shows the tooltip at once, with the shortcut', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(themedFrame(themeMatrix.first, MyDataIconButton(
      icon: MyDataIcon.add,
      label: 'New event',
      shortcut: MyDataShortcut.primary(LogicalKeyboardKey.keyN, platform: TargetPlatform.linux),
      focusNode: node,
      onPressed: _noop,
    )));
    expect(find.text('New event Ctrl+N', findRichText: true), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('New event Ctrl+N', findRichText: true), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('New event Ctrl+N', findRichText: true), findsNothing, reason: 'Escape hides it');
    expect(node.hasFocus, isTrue);
    node.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('New event Ctrl+N', findRichText: true), findsNothing);
  });

  testWidgets('disabled with its reason: focusable, inert, the reason in the tooltip and the hint', (tester) async {
    final handle = tester.ensureSemantics();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(themedFrame(themeMatrix.first, MyDataIconButton(
      icon: MyDataIcon.sync,
      label: 'Sync now',
      focusNode: node,
      onPressed: null,
      disabledReason: _reason,
    )));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(node.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Sync now\n$_reason', findRichText: true), findsOneWidget);
    expect(
      tester.getSemantics(_pressable(find.byType(MyDataIconButton))),
      matchesSemantics(
        label: 'Sync now',
        hint: _reason,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        isFocusable: true,
        isFocused: true,
        hasFocusAction: true,
      ),
    );
    node.unfocus();
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('semantics: named by its label; a toggle keeps one name and says on or off', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      MyDataIconButton(key: Key('a'), icon: MyDataIcon.chevronLeft, label: 'Previous month', onPressed: _noop),
      MyDataIconButton(key: Key('f'), icon: MyDataIcon.report, label: 'Flag', toggled: false, onPressed: _noop),
      MyDataIconButton(key: Key('g'), icon: MyDataIcon.report, label: 'Flag', toggled: true, onPressed: _noop),
    ])));
    expect(
      tester.getSemantics(_pressable(find.byKey(const Key('a')))),
      matchesSemantics(
          label: 'Previous month', isButton: true, hasEnabledState: true, isEnabled: true, isFocusable: true,
          hasTapAction: true, hasFocusAction: true),
    );
    for (final (key, on) in [('f', false), ('g', true)]) {
      expect(
        tester.getSemantics(_pressable(find.byKey(Key(key)))),
        matchesSemantics(
            label: 'Flag', isButton: true, hasToggledState: true, isToggled: on, hasEnabledState: true, isEnabled: true,
            isFocusable: true, hasTapAction: true, hasFocusAction: true),
      );
    }
    handle.dispose();
  });

  testWidgets('done shows a check in its tone and the result word', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const MyDataIconButton(
      icon: MyDataIcon.copy,
      label: 'Copy work email',
      doneLabel: 'Copied',
      done: true,
      tone: IconButtonTone.quiet,
      onPressed: _noop,
    )));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, iconOf(MyDataIcon.check));
    expect(icon.color, tester.element(find.byType(Icon)).colors.inkMuted);
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.richMessage!.toPlainText(), 'Copied');
  });

  test('shortcuts are written and spoken the platform way', () {
    final mac = MyDataShortcut.primary(LogicalKeyboardKey.backspace, platform: TargetPlatform.macOS);
    expect(MyDataShortcut.shown(mac, platform: TargetPlatform.macOS), '⌘⌫');
    expect(MyDataShortcut.spoken(mac, platform: TargetPlatform.macOS), 'Command Delete');
    final newCal = MyDataShortcut.primary(LogicalKeyboardKey.keyN, alt: true, platform: TargetPlatform.macOS);
    expect(MyDataShortcut.shown(newCal, platform: TargetPlatform.macOS), '⌥⌘N');
    final win = MyDataShortcut.primary(LogicalKeyboardKey.keyN, platform: TargetPlatform.windows);
    expect(MyDataShortcut.shown(win, platform: TargetPlatform.windows), 'Ctrl+N');
    expect(MyDataShortcut.spoken(win, platform: TargetPlatform.windows), 'Control N');
    expect(MyDataShortcut.shown(const SingleActivator(LogicalKeyboardKey.delete), platform: TargetPlatform.linux), 'Delete');
  });
}
