import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  goldenMatrix(
    'primitives',
    () => Builder(
      builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: MyDataSpace.s3, children: [
          for (final t in MyDataTone.values) IconTile(icon: MyDataIcon.importFile, tone: t),
        ]),
        const SizedBox(height: MyDataSpace.s4),
        Text('Your data, kept at home', style: MyDataType.displayLg.copyWith(color: context.colors.ink)),
        Text('Each app works by itself and reads the data your host keeps.',
            style: MyDataType.body.copyWith(color: context.colors.inkMuted)),
        Text('192.168.1.20', style: MyDataType.mono.copyWith(color: context.colors.ink)),
        const SizedBox(height: MyDataSpace.s4),
        const Row(children: [KiwiTile(size: 72), SizedBox(width: MyDataSpace.s4), KiwiLoader()]),
      ]),
    ),
    reduceMotion: true,
  );

  testWidgets('Pressable: Enter activates it, Tab reaches it, disabled ignores everything', (tester) async {
    var taps = 0;
    await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [
      Pressable(onPressed: () => taps++, borderRadius: MyDataRadii.control(kiwiLook), child: const SizedBox(width: 80, height: 44)),
      Pressable(onPressed: null, borderRadius: MyDataRadii.control(kiwiLook), child: SizedBox(width: 80, height: 44)),
    ])));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.byType(Pressable).first);
    expect(taps, 2);
    await tester.tap(find.byType(Pressable).last, warnIfMissed: false);
    expect(taps, 2);
  });

  group('Pressable, disabled with a reason: focusable but inert (platforms.md "Disabled controls")', () {
    const reason = 'The host cannot be reached.';
    Widget box(Key key, {VoidCallback? onPressed, String? why, String? tooltip, FocusNode? node, Color? hover}) =>
        Pressable(
          key: key,
          onPressed: onPressed,
          disabledReason: why,
          tooltip: tooltip,
          focusNode: node,
          hoverFill: hover,
          semanticLabel: tooltip == null ? 'Sync now' : null,
          borderRadius: MyDataRadii.control(kiwiLook),
          child: const SizedBox(width: 80, height: 44),
        );

    bool ringShown(WidgetTester tester, Key key) => tester
        .widgetList<CustomPaint>(find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)))
        .any((p) => p.foregroundPainter.runtimeType.toString() == '_FocusRingPainter');

    testWidgets('Tab skips a disabled control with no reason and stops on one with a reason', (tester) async {
      final first = FocusNode(), plain = FocusNode(), inert = FocusNode();
      addTearDown(first.dispose);
      addTearDown(plain.dispose);
      addTearDown(inert.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [
        box(const Key('first'), onPressed: () {}, node: first),
        box(const Key('plain'), node: plain),
        box(const Key('inert'), why: reason, node: inert),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(first.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(plain.hasFocus, isFalse);
      expect(inert.hasFocus, isTrue);
      expect(ringShown(tester, const Key('inert')), isTrue, reason: 'keyboard focus shows the ring');
    });

    testWidgets('pressing, Enter and Space do nothing; it stays faded with no hover fill or click cursor',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      var calls = 0;
      // A parent shortcut that would fire if the inert control let Enter through.
      await tester.pumpWidget(themedFrame(themeMatrix.first, CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter): () => calls++},
        child: box(const Key('inert'),
            why: reason, node: node, hover: themeMatrix.first.data.extension<MyDataColors>()!.surfaceHover),
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(find.byKey(const Key('inert')), warnIfMissed: false);
      await tester.pump();
      expect(calls, 0, reason: 'Enter is taken by the control and does nothing');
      expect(node.hasFocus, isTrue);

      final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(of: find.byKey(const Key('inert')), matching: find.byType(AnimatedOpacity)));
      expect(opacity.opacity, Pressable.disabledOpacity);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('inert'))));
      await tester.pumpAndSettle();
      final fill = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byKey(const Key('inert')), matching: find.byType(AnimatedContainer)));
      expect(((fill.decoration!.box).color!).a, 0);
      expect(RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1), isNot(SystemMouseCursors.click));
    });

    testWidgets('it is announced as disabled and focusable, with the reason as its hint', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, box(const Key('inert'), why: reason)));
      expect(
          tester.getSemantics(find.byKey(const Key('inert'))),
          matchesSemantics(
            label: 'Sync now',
            hint: reason,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            isFocusable: true,
            hasFocusAction: true,
          ));
      handle.dispose();
    });

    testWidgets('keyboard focus shows the tooltip with the reason on a second line', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, box(const Key('inert'), why: reason, tooltip: 'Sync now', node: node)));
      expect(find.text('Sync now\n$reason', findRichText: true), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      final shown = find.text('Sync now\n$reason', findRichText: true);
      expect(shown, findsOneWidget);
      TextSpan? reasonSpan;
      tester.widget<RichText>(shown).text.visitChildren((span) {
        if (span is TextSpan && span.text == '\n$reason') reasonSpan = span;
        return true;
      });
      expect(reasonSpan!.style!.color, themeMatrix.first.data.extension<MyDataColors>()!.inkMuted);
    });

    testWidgets('a control that turns inert while focused keeps focus; one disabled outright loses it',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      Future<void> pump({VoidCallback? onPressed, String? why}) => tester.pumpWidget(
          themedFrame(themeMatrix.first, box(const Key('p'), onPressed: onPressed, why: why, node: node)));
      await pump(onPressed: () {});
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await pump(why: 'Saving.');
      expect(node.hasFocus, isTrue);
      await pump();
      expect(node.hasFocus, isFalse);
    });
  });
}
