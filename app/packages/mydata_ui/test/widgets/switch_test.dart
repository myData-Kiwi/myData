import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop(bool _) {}

/// The rows of a grouped list, as GroupedList will stack them: a `surface` group, `line` dividers.
Widget _group(BuildContext context, List<Widget> rows) => DecoratedBox(
      decoration: BoxDecoration(
          color: context.colors.surface, borderRadius: MyDataRadii.lg(kiwiLook), boxShadow: context.shadows.shadow1),
      child: ClipRRect(
        borderRadius: MyDataRadii.lg(kiwiLook),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: context.colors.line),
            rows[i],
          ],
        ]),
      ),
    );

void main() {
  goldenMatrix(
    'switch',
    () => Builder(
      builder: (context) => SizedBox(
        width: 512,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _group(context, const [
            SwitchRow(
                title: 'Assistant',
                description: 'Ask questions and take actions in plain language. Downloads a language model.',
                value: false,
                onChanged: _noop),
            SwitchRow(
                title: 'Group photos by face',
                description: 'Finds the same person across your photos. You name the groups.',
                value: true,
                onChanged: _noop),
            SwitchRow(
                key: ValueKey('hovered'),
                icon: MyDataIcon.sync,
                title: 'Back up every night',
                description: 'Copies your data to the backup drive at 2am.',
                value: true,
                onChanged: _noop),
            SwitchRow(
                icon: MyDataIcon.cloud,
                tone: MyDataTone.neutral,
                title: 'Search the web',
                description: 'Needs the assistant to be on.',
                value: false,
                onChanged: null),
          ]),
          const SizedBox(height: MyDataSpace.s4),
          const Row(children: [
            MyDataSwitch(value: false, onChanged: _noop, semanticLabel: 'Focused off', autofocus: true),
            SizedBox(width: MyDataSpace.s3),
            MyDataSwitch(value: true, onChanged: _noop, semanticLabel: 'On'),
            SizedBox(width: MyDataSpace.s3),
            MyDataSwitch(value: false, onChanged: null, semanticLabel: 'Disabled off'),
            SizedBox(width: MyDataSpace.s3),
            MyDataSwitch(value: true, onChanged: null, semanticLabel: 'Disabled on'),
          ]),
        ]),
      ),
    ),
    size: const Size(560, 356),
    before: (tester) async {
      // Keyboard focus on the first standalone switch, and the mouse over the third row.
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  group('MyDataSwitch', () {
    testWidgets('a tap flips it and reports the new value', (tester) async {
      bool? got;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, MyDataSwitch(value: false, onChanged: (v) => got = v, semanticLabel: 'Assistant')));
      await tester.tap(find.byType(MyDataSwitch));
      expect(got, isTrue);
    });

    testWidgets('the target is at least 44px and taps above the track still count', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, MyDataSwitch(value: true, onChanged: (_) => taps++, semanticLabel: 'Assistant')));
      final target = tester.getSize(find.byType(MyDataSwitch));
      expect(target.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(target.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(tester.getSize(find.byType(SwitchTrack)), const Size(SwitchTrack.width, SwitchTrack.height));
      // 2px inside the top edge of the target, 5px above the drawn track.
      await tester.tapAt(tester.getTopLeft(find.byType(MyDataSwitch)) + const Offset(25, 2));
      expect(taps, 1);
      // The semantics node covers the padded target, not only the track.
      expect(tester.getSemantics(find.byType(SwitchTrack)).rect.size, target);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Tab reaches it; Space and Enter flip it', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, MyDataSwitch(value: false, onChanged: got.add, semanticLabel: 'Assistant')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(got, [true, true]);
    });

    testWidgets('disabled: 45% opacity, Tab skips it, announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const Row(mainAxisSize: MainAxisSize.min, children: [
            MyDataSwitch(value: true, onChanged: null, semanticLabel: 'Assistant'),
            MyDataSwitch(value: false, onChanged: _noop, semanticLabel: 'After'),
          ])));
      final disabled = find.byType(MyDataSwitch).first;
      final enabled = find.byType(MyDataSwitch).last;
      expect(
          tester
              .widget<AnimatedOpacity>(find.descendant(of: disabled, matching: find.byType(AnimatedOpacity)))
              .opacity,
          Pressable.disabledOpacity);
      // Tab passes over the disabled switch to the next one.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(find.descendant(of: disabled, matching: find.byWidget(focused!.widget)), findsNothing);
      expect(find.descendant(of: enabled, matching: find.byWidget(focused.widget)), findsOneWidget);
      expect(
          tester.getSemantics(find.descendant(of: disabled, matching: find.byType(SwitchTrack))),
          isSemantics(
              label: 'Assistant', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: false));
      handle.dispose();
    });

    testWidgets('semantics: its label and on or off state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, MyDataSwitch(value: false, onChanged: _noop, semanticLabel: 'Group photos by face')));
      expect(
          tester.getSemantics(find.byType(SwitchTrack)),
          isSemantics(
              label: 'Group photos by face',
              hasToggledState: true,
              isToggled: false,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      handle.dispose();
    });

    testWidgets('the thumb slides over fast; with reduced motion it jumps', (tester) async {
      Widget at(bool v, {required bool reduced}) =>
          themedFrame(themeMatrix.first, MyDataSwitch(value: v, onChanged: _noop, semanticLabel: 'Assistant'),
              reduceMotion: reduced);
      double thumbX() => tester
          .getTopLeft(find.descendant(of: find.byType(AnimatedAlign), matching: find.byType(AnimatedContainer)))
          .dx;

      await tester.pumpWidget(at(false, reduced: false));
      final off = thumbX();
      await tester.pumpWidget(at(true, reduced: false));
      await tester.pump(MyDataMotion.fast ~/ 2);
      final mid = thumbX();
      expect(mid, greaterThan(off));
      expect(mid, lessThan(off + 20));
      await tester.pumpAndSettle();
      expect(thumbX(), off + 20);

      await tester.pumpWidget(at(false, reduced: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(at(true, reduced: true));
      await tester.pump();
      expect(thumbX(), off + 20);
    });
  });

  group('SwitchRow', () {
    testWidgets('the whole row is the target', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 480,
              child: SwitchRow(
                  title: 'Assistant',
                  description: 'Ask questions in plain language.',
                  value: true,
                  onChanged: got.add))));
      await tester.tap(find.text('Assistant'));
      await tester.tap(find.text('Ask questions in plain language.'));
      await tester.tap(find.byType(SwitchTrack));
      await tester.tapAt(tester.getTopLeft(find.byType(SwitchRow)) + const Offset(4, 4));
      expect(got, [false, false, false, false]);
    });

    testWidgets('GroupedList row geometry: at least row-height, padding s4 by s2, gap s3', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 480,
              child: SwitchRow(
                  icon: MyDataIcon.person,
                  title: 'Group photos by face',
                  description: 'Finds the same person across your photos.',
                  value: false,
                  onChanged: _noop))));
      final row = tester.getRect(find.byType(SwitchRow));
      final tile = tester.getRect(find.byType(IconTile));
      final track = tester.getRect(find.byType(SwitchTrack));
      final title = tester.getRect(find.text('Group photos by face'));
      expect(row.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      expect(tile.left - row.left, MyDataSpace.s4);
      expect(row.right - track.right, MyDataSpace.s4);
      expect(title.left - tile.right, MyDataSpace.s3);
      expect(track.center.dy, closeTo(row.center.dy, 0.5));
    });

    testWidgets('a long description wraps and the row grows', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 280,
              child: SwitchRow(
                  title: 'Assistant',
                  description: 'Ask questions and take actions in plain language. Downloads a language model.',
                  value: false,
                  onChanged: _noop))));
      final row = tester.getRect(find.byType(SwitchRow));
      final text = tester.getRect(find.textContaining('Downloads'));
      expect(row.top + MyDataSpace.s2, lessThanOrEqualTo(tester.getRect(find.text('Assistant')).top));
      expect(text.bottom + MyDataSpace.s2, lessThanOrEqualTo(row.bottom + 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab reaches the row; Space and Enter flip it', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 480,
              child: SwitchRow(title: 'Assistant', description: 'Plain language.', value: false, onChanged: got.add))));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(got, [true, true]);
    });

    testWidgets('semantics: one node with title, description and state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 480,
              child: SwitchRow(
                  icon: MyDataIcon.person,
                  title: 'Group photos by face',
                  description: 'You name the groups.',
                  value: true,
                  onChanged: _noop))));
      expect(
          tester.getSemantics(find.byType(SwitchRow)),
          isSemantics(
              label: 'Group photos by face\nYou name the groups.',
              hasToggledState: true,
              isToggled: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      handle.dispose();
    });

    testWidgets('disabled: the whole row at 45% opacity, Tab skips it, announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchRow(title: 'Search the web', description: 'Needs the assistant.', value: false, onChanged: null),
                SwitchRow(title: 'Assistant', description: 'Plain language.', value: false, onChanged: _noop),
              ]))));
      final disabled = find.byType(SwitchRow).first;
      final enabled = find.byType(SwitchRow).last;
      final opacity =
          tester.widget<AnimatedOpacity>(find.descendant(of: disabled, matching: find.byType(AnimatedOpacity)));
      expect(opacity.opacity, Pressable.disabledOpacity);
      // The fade covers the whole row: title, description and track.
      for (final part in [find.text('Search the web'), find.text('Needs the assistant.'), find.byType(SwitchTrack).first]) {
        expect(
            find.descendant(
                of: find.descendant(of: disabled, matching: find.byType(AnimatedOpacity)), matching: part),
            findsOneWidget);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(find.descendant(of: disabled, matching: find.byWidget(focused!.widget)), findsNothing);
      expect(find.descendant(of: enabled, matching: find.byWidget(focused.widget)), findsOneWidget);
      expect(
          tester.getSemantics(disabled),
          isSemantics(
              label: 'Search the web\nNeeds the assistant.',
              hasToggledState: true,
              isToggled: false,
              hasEnabledState: true,
              isEnabled: false));
      handle.dispose();
    });

    testWidgets('a press fills the row and does not shrink it', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 480,
              child: SwitchRow(title: 'Assistant', description: 'Plain language.', value: false, onChanged: _noop))));
      final before = tester.getSize(find.byType(SwitchRow));
      final g = await tester.startGesture(tester.getCenter(find.text('Assistant')));
      await tester.pump(MyDataMotion.fast);
      expect(find.byType(AnimatedScale), findsNothing);
      final fill = tester.widget<AnimatedContainer>(find
          .descendant(of: find.byType(SwitchRow), matching: find.byType(AnimatedContainer))
          .first);
      final colors = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;
      expect((fill.decoration! as BoxDecoration).color, colors.surfaceHover);
      expect(tester.getSize(find.byType(SwitchRow)), before);
      await g.up();
    });
  });
}
