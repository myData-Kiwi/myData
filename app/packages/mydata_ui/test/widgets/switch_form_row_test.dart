import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop(bool _) {}

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

Widget _panel(Widget child) => Builder(
      builder: (context) => Container(
        width: 440,
        color: context.colors.surface,
        padding: const EdgeInsets.all(MyDataSpace.s4),
        child: child,
      ),
    );

void main() {
  goldenMatrix(
    'switch_form_row',
    () => _panel(const Column(mainAxisSize: MainAxisSize.min, children: [
      FormSwitchRow(title: 'All-day', value: false, onChanged: _noop, autofocus: true),
      SizedBox(height: MyDataSpace.s4),
      FormSwitchRow(key: ValueKey('hovered'), title: 'All-day', value: true, onChanged: _noop),
      SizedBox(height: MyDataSpace.s4),
      FormSwitchRow(
          title: 'All-day',
          value: false,
          onChanged: null,
          disabledReason: 'This event comes from an invitation and cannot be changed here.'),
    ])),
    size: const Size(488, 300),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  testWidgets('the whole row is the target; the title is body in ink, the switch at the end', (tester) async {
    final got = <bool>[];
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(FormSwitchRow(title: 'All-day', value: false, onChanged: got.add))));
    await tester.tap(find.text('All-day'));
    await tester.tap(find.byType(SwitchTrack));
    await tester.tapAt(tester.getCenter(find.byType(FormSwitchRow)));
    expect(got, [true, true, true]);
    final title = tester.widget<Text>(find.text('All-day'));
    expect(title.style!.fontWeight, MyDataType.body.fontWeight);
    expect(title.style!.color, _kiwi.ink);
    final row = tester.getRect(find.byType(FormSwitchRow));
    expect(row.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
    expect(tester.getRect(find.byType(SwitchTrack)).right, row.right);
    expect(tester.getRect(find.text('All-day')).left, row.left);
  });

  testWidgets('Space toggles it; Return is left to the form', (tester) async {
    final got = <bool>[];
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(FormSwitchRow(title: 'All-day', value: false, onChanged: got.add))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(got, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(got, [true]);
  });

  testWidgets('keyboard focus rings the track, not the row', (tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(const FormSwitchRow(title: 'All-day', value: false, onChanged: _noop))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = tester.widget<FocusRing>(find.byType(FocusRing));
    expect(ring.visible, isTrue);
    expect(find.descendant(of: find.byType(FocusRing), matching: find.byType(SwitchTrack)), findsOneWidget);
    expect(find.descendant(of: find.byType(FocusRing), matching: find.text('All-day')), findsNothing);
  });

  testWidgets('disabled: title and switch at 45%, the reason not faded, not focusable', (tester) async {
    final handle = tester.ensureSemantics();
    const reason = 'This event comes from an invitation and cannot be changed here.';
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        _panel(const Column(mainAxisSize: MainAxisSize.min, children: [
          FormSwitchRow(title: 'All-day', value: true, onChanged: null, disabledReason: reason),
          FormSwitchRow(title: 'After', value: false, onChanged: _noop),
        ]))));
    expect(find.ancestor(of: find.text(reason), matching: find.byType(Opacity)), findsNothing);
    expect(tester.widget<Opacity>(find.ancestor(of: find.text('All-day'), matching: find.byType(Opacity)).first).opacity,
        Pressable.disabledOpacity);
    expect(
        tester.widget<Opacity>(find.ancestor(of: find.byType(SwitchTrack).first, matching: find.byType(Opacity)).first)
            .opacity,
        Pressable.disabledOpacity);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(find.descendant(of: find.byType(FormSwitchRow).last, matching: find.byWidget(focused.widget)),
        findsOneWidget);
    expect(
        tester.getSemantics(find.byType(FormSwitchRow).first),
        isSemantics(
            label: 'All-day\n$reason', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: false));
    handle.dispose();
  });

  testWidgets('semantics: "All-day, switch, off"; what the form changes is announced once', (tester) async {
    final handle = tester.ensureSemantics();
    var value = false;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        StatefulBuilder(
          builder: (context, setState) => _panel(FormSwitchRow(
            title: 'All-day',
            value: value,
            onChanged: (v) => setState(() => value = v),
            announce: (v) => v ? 'Start and end are now dates' : 'Start and end are now times',
          )),
        )));
    expect(
        tester.getSemantics(find.byType(FormSwitchRow)),
        isSemantics(
            label: 'All-day',
            hasToggledState: true,
            isToggled: false,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true));
    await tester.tap(find.byType(FormSwitchRow));
    await tester.pump();
    expect(tester.takeAnnouncements().map((a) => a.message), ['Start and end are now dates']);
    handle.dispose();
  });

  testWidgets('hover fills the row with surface-hover; under 600px the row is row-height', (tester) async {
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(const FormSwitchRow(title: 'All-day', value: false, onChanged: _noop))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(FormSwitchRow)));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    final fill = tester.widget<TweenAnimationBuilder<Color?>>(find.byType(TweenAnimationBuilder<Color?>));
    expect((fill.tween as ColorTween).end, _kiwi.surfaceHover);

    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(const FormSwitchRow(title: 'All-day', value: false, onChanged: _noop))));
    expect(tester.getSize(find.byType(FormSwitchRow)).height, MyDataSize.rowHeight);
  });

  testWidgets('the title is body at 16px on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _panel(const FormSwitchRow(title: 'All-day', value: false, onChanged: _noop))));
    expect(tester.widget<Text>(find.text('All-day')).style!.fontSize, PhoneType.bodySize);
  });

  testWidgets('while its form waits for the host it does not flip', (tester) async {
    var flips = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        FormBusy(busy: true, child: _panel(FormSwitchRow(title: 'All-day', value: false, onChanged: (_) => flips++)))));
    await tester.tap(find.text('All-day'));
    await tester.pump();
    expect(flips, 0);
  });
}
