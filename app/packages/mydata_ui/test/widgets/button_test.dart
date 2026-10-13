import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

/// Focused by keyboard in the golden.
FocusNode? _focusedNode;

/// Rows: the five variants; with a leading icon; disabled; keyboard focus ring and pressed.
Widget _allStates() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const ButtonRow(children: [
        Button(label: 'Approve and send', variant: ButtonVariant.filled, onPressed: _noop),
        Button(label: 'Edit', onPressed: _noop),
        Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: _noop),
        Button(label: 'Delete 12 photos', variant: ButtonVariant.danger, onPressed: _noop),
        Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop),
      ]),
      const SizedBox(height: MyDataSpace.s4),
      const ButtonRow(children: [
        Button(label: 'Add a device', variant: ButtonVariant.filled, icon: Icons.add_rounded, onPressed: _noop),
        Button(label: 'Open in myData', icon: Icons.open_in_new_rounded, onPressed: _noop),
        Button(label: 'Retry', variant: ButtonVariant.plain, icon: Icons.refresh_rounded, onPressed: _noop),
        Button(label: 'Delete', variant: ButtonVariant.danger, icon: Icons.delete_outline_rounded, onPressed: _noop),
        Button(label: 'Remove', variant: ButtonVariant.plainDanger, icon: Icons.link_off_rounded, onPressed: _noop),
      ]),
      const SizedBox(height: MyDataSpace.s4),
      const ButtonRow(children: [
        Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: null),
        Button(label: 'Edit', onPressed: null),
        Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: null),
        Button(label: 'Delete 12 photos', variant: ButtonVariant.danger, onPressed: null),
        Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: null),
      ]),
      const SizedBox(height: MyDataSpace.s4),
      ButtonRow(children: [
        Button(
            label: 'Approve and send',
            variant: ButtonVariant.filled,
            focusNode: _focusedNode = FocusNode(),
            onPressed: _noop),
        const Button(label: 'Edit', key: Key('pressed'), onPressed: _noop),
      ]),
    ]);

void main() {
  goldenMatrix('button', _allStates, size: const Size(840, 272), before: (tester) async {
    // A Tab press puts focus highlighting in keyboard mode; then focus the fourth row's filled button and
    // hold a press on its tonal one.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    _focusedNode!.requestFocus();
    await tester.pumpAndSettle();
    // A mouse press keeps keyboard highlighting on (a touch would switch it off). Tap-down lands after
    // the press timeout.
    final press = await tester.startGesture(tester.getCenter(find.byKey(const Key('pressed'))),
        kind: PointerDeviceKind.mouse);
    addTearDown(press.up);
    await tester.pump(kPressTimeout);
  });

  testWidgets('tap, Enter and Space call onPressed; disabled ignores taps and focus', (tester) async {
    var sent = 0;
    var cancelled = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      const Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: null),
      Button(label: 'Approve and send', variant: ButtonVariant.filled, onPressed: () => sent++),
      Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: () => cancelled++),
    ])));

    await tester.tap(find.text('Approve and send'));
    expect(sent, 1);
    await tester.tap(find.text('Add a device'), warnIfMissed: false);
    expect(sent, 1);

    // Tab skips the disabled button and lands on "Approve and send".
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cancelled, 1);
    expect(sent, 2);
  });

  testWidgets('semantics: a button named by its label, enabled or not', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      Button(label: 'Open in myData', icon: Icons.open_in_new_rounded, onPressed: () {}),
      const Button(label: 'Add a device', onPressed: null),
    ])));
    expect(
      tester.getSemantics(find.byType(Button).first),
      matchesSemantics(
        label: 'Open in myData',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(Button).last),
      matchesSemantics(label: 'Add a device', isButton: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('every variant is control-height tall and at least 44px wide; label is body-strong', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      for (final v in ButtonVariant.values) Button(label: 'Go', variant: v, onPressed: () {}),
      Button(label: 'Go', icon: Icons.add_rounded, onPressed: () {}),
    ])));
    for (final e in find.byType(Button).evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.height, MyDataSize.controlHeight);
      expect(size.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
    }
    final text = tester.widget<Text>(find.text('Go').first);
    expect(text.style!.fontSize, MyDataType.bodyStrong.fontSize);
    expect(text.style!.fontWeight, MyDataType.bodyStrong.fontWeight);
    expect(text.style!.height, MyDataType.bodyStrong.height);
  });

  testWidgets('colours follow the variant; the plain button has no fill', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      for (final v in ButtonVariant.values) Button(label: v.name, variant: v, onPressed: () {}),
    ])));
    final c = tester.element(find.byType(ButtonRow)).colors;
    Color? fillOf(String label) => ((tester.widget<Container>(
                find.ancestor(of: find.text(label), matching: find.byType(Container)).first))
            .decoration as BoxDecoration)
        .color;
    Color? labelOf(String label) => tester.widget<Text>(find.text(label)).style!.color;
    expect(fillOf('filled'), c.accent);
    expect(labelOf('filled'), c.onAccent);
    expect(fillOf('tonal'), c.accentSoft);
    expect(labelOf('tonal'), c.accent);
    expect(fillOf('plain'), isNull);
    expect(labelOf('plain'), c.accent);
    expect(fillOf('danger'), c.danger);
    expect(labelOf('danger'), c.onDanger);
    expect(fillOf('plainDanger'), isNull);
    expect(labelOf('plainDanger'), c.danger);
  });

  testWidgets('plain danger presses, focuses and disables exactly as plain', (tester) async {
    var revoked = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: () => revoked++),
      const Button(label: 'Remove', variant: ButtonVariant.plainDanger, onPressed: null),
    ])));
    await tester.tap(find.text('Revoke'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(revoked, 2);
    await tester.tap(find.text('Remove'), warnIfMissed: false);
    final disabled = tester.widget<AnimatedOpacity>(
        find.descendant(of: find.byType(Button).last, matching: find.byType(AnimatedOpacity)));
    expect(disabled.opacity, Pressable.disabledOpacity);
    expect(tester.getSize(find.byType(Button).first).height, MyDataSize.controlHeight);
  });

  testWidgets('press scales to 97% at once; with reduced motion it only dims', (tester) async {
    Future<void> pressAndCheck({required bool reduceMotion}) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, Button(label: 'Edit', onPressed: () {}),
          reduceMotion: reduceMotion));
      await tester.pumpAndSettle();
      final g = await tester.startGesture(tester.getCenter(find.byType(Button)));
      await tester.pump();
      final scales = tester.widgetList<AnimatedScale>(
          find.descendant(of: find.byType(Button), matching: find.byType(AnimatedScale)));
      if (reduceMotion) {
        expect(scales, isEmpty);
      } else {
        expect(scales.single.scale, MyDataMotion.pressScale);
      }
      final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(of: find.byType(Button), matching: find.byType(AnimatedOpacity)));
      expect(opacity.opacity, MyDataMotion.pressOpacity);
      await g.up();
      await tester.pumpAndSettle();
    }

    await pressAndCheck(reduceMotion: false);
    await pressAndCheck(reduceMotion: true);
  });

  Future<(Rect, Rect)> pumpRow(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(themeMatrix.first, ButtonRow(children: [
      Button(label: 'Approve and send', variant: ButtonVariant.filled, onPressed: () {}),
      Button(label: 'Edit', onPressed: () {}),
    ])));
    return (tester.getRect(find.byType(Button).first), tester.getRect(find.byType(Button).last));
  }

  testWidgets('ButtonRow puts buttons space-2 apart on one line when they fit', (tester) async {
    // 600 wide less themedFrame's 24px padding each side leaves 552px: room for both buttons.
    final (first, second) = await pumpRow(tester, 600);
    expect(second.top, first.top);
    expect(second.left - first.right, MyDataSpace.s2);
  });

  testWidgets('ButtonRow wraps to a new line space-2 below when they do not fit', (tester) async {
    // 260 wide leaves 212px: less than both buttons plus the gap, so "Edit" wraps.
    final (first, second) = await pumpRow(tester, 260);
    expect(second.top, greaterThan(first.top));
    expect(second.top - first.bottom, MyDataSpace.s2);
  });
}
