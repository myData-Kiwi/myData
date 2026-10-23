import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

enum _View { day, week, month }

const _views = [(_View.day, 'Day'), (_View.week, 'Week'), (_View.month, 'Month')];

/// A segmented control that keeps its own selection, as a screen would.
class _Harness extends StatefulWidget {
  const _Harness({this.onChanged});
  final ValueChanged<_View>? onChanged;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  _View value = _View.week;

  @override
  Widget build(BuildContext context) => SegmentedControl<_View>(
    segments: _views,
    selected: value,
    semanticLabel: 'View',
    onChanged: (v) {
      setState(() => value = v);
      widget.onChanged?.call(v);
    },
  );
}

Rect _thumbRect(WidgetTester tester) => tester.getRect(
  find.descendant(of: find.byType(SegmentedControl<_View>), matching: find.byType(AnimatedPositionedDirectional)).first,
);

/// A segment's whole target: the outermost gesture detector inside the control around [label].
Finder _target(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.descendant(of: find.byType(SegmentedControl<_View>), matching: find.byType(GestureDetector)),
    )
    .last;

void main() {
  goldenMatrix(
    'segmented_control',
    () => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SegmentedControl<_View>(segments: _views, selected: _View.week, onChanged: _ignore),
            SizedBox(width: MyDataSpace.s5),
            SegmentedControl<String>(
              segments: [('all', 'All'), ('photos', 'Photos'), ('videos', 'Videos')],
              selected: 'all',
              onChanged: _ignore,
            ),
          ],
        ),
        SizedBox(height: MyDataSpace.s4),
        Row(
          children: [
            SegmentedControl<bool>(segments: [(true, 'On'), (false, 'Off')], selected: false, onChanged: _ignore),
            SizedBox(width: MyDataSpace.s5),
            SegmentedControl<int>(
              segments: [(1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri')],
              selected: 5,
              onChanged: _ignore,
            ),
          ],
        ),
        SizedBox(height: MyDataSpace.s4),
        Row(
          children: [
            // Disabled.
            SegmentedControl<_View>(segments: _views, selected: _View.day, onChanged: null),
            SizedBox(width: MyDataSpace.s5),
            // Focused with the keyboard (focus is moved in `before`).
            SegmentedControl<_View>(segments: _views, selected: _View.month, onChanged: _ignore),
          ],
        ),
        SizedBox(height: MyDataSpace.s4),
        // Too narrow for its labels: padding shrinks, then the widest labels ellipsize.
        SizedBox(
          width: 360,
          child: SegmentedControl<int>(
            segments: [(1, 'Monday'), (2, 'Tuesday'), (3, 'Wednesday'), (4, 'Thursday'), (5, 'Fri')],
            selected: 3,
            onChanged: _ignore,
          ),
        ),
      ],
    ),
    size: const Size(520, 272),
    before: (tester) async {
      // Tab through the enabled controls to the last one: one stop per control (the selected segment).
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
    },
  );

  testWidgets('tapping a segment calls onChanged with its value; tapping the selected one does not', (tester) async {
    final calls = <_View>[];
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SegmentedControl<_View>(segments: _views, selected: _View.week, onChanged: calls.add),
      ),
    );
    await tester.tap(find.text('Month'));
    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(calls, [_View.month]);
  });

  testWidgets('disabled: no callbacks, no focus, 45% opacity', (tester) async {
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        const SegmentedControl<_View>(segments: _views, selected: _View.week, onChanged: null),
      ),
    );
    await tester.tap(find.text('Day'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel?.startsWith('SegmentedControl') ?? false, isFalse);
    final opacities = tester
        .widgetList<Opacity>(find.descendant(of: find.byType(SegmentedControl<_View>), matching: find.byType(Opacity)))
        .map((o) => o.opacity);
    expect(opacities, everyElement(Pressable.disabledOpacity));
  });

  testWidgets('keyboard: Tab reaches the selected segment only; arrows, Home and End move the selection', (
    tester,
  ) async {
    final calls = <_View>[];
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        Column(
          children: [
            _Harness(onChanged: calls.add),
            const Focus(child: SizedBox(width: 10, height: 10)),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'SegmentedControl segment 1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(calls, [_View.month]);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'SegmentedControl segment 2');

    // Right wraps from the last to the first; End on the last changes nothing.
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.home,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(calls, [_View.month, _View.day, _View.month, _View.day, _View.month, _View.day]);

    // Tab leaves the group in one step, to the next focusable thing.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel?.startsWith('SegmentedControl') ?? false, isFalse);
  });

  testWidgets('keyboard: arrows follow reading direction in right-to-left text', (tester) async {
    final calls = <_View>[];
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        Directionality(
          textDirection: TextDirection.rtl,
          child: _Harness(onChanged: calls.add),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(calls, [_View.month]);
  });

  testWidgets('Enter and Space select the focused segment', (tester) async {
    final calls = <_View>[];
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SegmentedControl<_View>(segments: _views, selected: _View.week, onChanged: calls.add),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    // The parent did not update the selection, so focus moves without the selection.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    // Moving onto the selected segment (Week) does not call onChanged.
    expect(calls, [_View.day, _View.day, _View.month, _View.month]);
  });

  testWidgets('semantics: a radio group of radios, the selected one checked', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness()));
    expect(
      tester.getSemantics(find.text('Week')),
      isSemantics(
        label: 'Week',
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Day')),
      isSemantics(label: 'Day', isInMutuallyExclusiveGroup: true, hasCheckedState: true, isChecked: false),
    );
    final group = tester.getSemantics(find.byType(SegmentedControl<_View>));
    expect(group.role, SemanticsRole.radioGroup);
    expect(group.label, 'View');

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Day')), isSemantics(isChecked: true));
    expect(tester.getSemantics(find.text('Week')), isSemantics(isChecked: false));
    handle.dispose();
  });

  testWidgets('every segment is at least 44px tall; the control is control-height', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness()));
    expect(tester.getSize(find.byType(SegmentedControl<_View>)).height, MyDataSize.controlHeight);
    for (final label in ['Day', 'Week', 'Month']) {
      final target = tester.getRect(_target(label));
      expect(target.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(target.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
      // A tap on the track's padding above the thumb still selects the segment.
      await tester.tapAt(target.topCenter + const Offset(0, 1));
      await tester.pump();
      expect(tester.getSemantics(find.text(label)), isSemantics(isChecked: true));
    }
    expect(_thumbRect(tester).height, MyDataSize.controlHeightCompact);
    handle.dispose();
  });

  testWidgets('the thumb slides with spring to the new segment', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness()));
    final start = _thumbRect(tester);
    final target = tester.getRect(_target('Month'));
    await tester.tap(find.text('Month'));
    await tester.pump();
    await tester.pump(MyDataMotion.springDuration ~/ 4);
    final mid = _thumbRect(tester);
    expect(mid.left, greaterThan(start.left));
    expect(mid.left, lessThan(target.left));
    await tester.pumpAndSettle();
    expect(_thumbRect(tester).left, target.left);
    expect(_thumbRect(tester).width, target.width);
  });

  testWidgets('reduced motion: the thumb jumps', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness(), reduceMotion: true));
    final target = tester.getRect(_target('Day'));
    await tester.tap(find.text('Day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(_thumbRect(tester).left, target.left);
  });

  testWidgets('selected label is ink in body-strong, the others ink-muted in body', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness()));
    await tester.pumpAndSettle();
    final colors = MyDataTheme.data(themeMatrix.first.themeId, themeMatrix.first.brightness).extension<MyDataColors>()!;
    TextStyle styleOf(String label) => tester
        .widget<DefaultTextStyle>(find.ancestor(of: find.text(label), matching: find.byType(DefaultTextStyle)).first)
        .style;
    expect(styleOf('Week').color, colors.ink);
    expect(styleOf('Week').fontWeight, MyDataType.bodyStrong.fontWeight);
    expect(styleOf('Day').color, colors.inkMuted);
    expect(styleOf('Day').fontWeight, MyDataType.body.fontWeight);
  });

  testWidgets('narrow parent: five segments at text scale 1.3 fit in 300px without overflow', (tester) async {
    const days = [(1, 'Monday'), (2, 'Tuesday'), (3, 'Wednesday'), (4, 'Thursday'), (5, 'Friday')];
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: const SizedBox(
              width: 300,
              child: SegmentedControl<int>(segments: days, selected: 3, onChanged: _ignore),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final control = tester.getRect(find.byType(SegmentedControl<int>));
    expect(control.width, lessThanOrEqualTo(300));
    final track = find.descendant(of: find.byType(SegmentedControl<int>), matching: find.byType(Row));
    expect(tester.getRect(track).right, lessThanOrEqualTo(control.right));
    // Every segment keeps a 44px target and the thumb covers the selected one exactly.
    final targets = <Rect>[
      for (final d in days)
        tester.getRect(
          find
              .ancestor(
                of: find.text(d.$2),
                matching: find.descendant(
                  of: find.byType(SegmentedControl<int>),
                  matching: find.byType(GestureDetector),
                ),
              )
              .last,
        ),
    ];
    for (final t in targets) {
      expect(t.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(t.right, lessThanOrEqualTo(control.right));
    }
    final thumb = tester.getRect(
      find
          .descendant(of: find.byType(SegmentedControl<int>), matching: find.byType(AnimatedPositionedDirectional))
          .first,
    );
    expect(thumb.left, targets[2].left);
    expect(thumb.width, targets[2].width);
    // Long labels are cut with an ellipsis rather than overflowing.
    expect(tester.widget<Text>(find.text('Wednesday')).overflow, TextOverflow.ellipsis);
  });

  testWidgets('slightly narrow parent: side padding shrinks, labels stay whole', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _Harness()));
    final natural = tester.getSize(find.byType(SegmentedControl<_View>)).width;
    await tester.pumpWidget(
      themedFrame(themeMatrix.first, SizedBox(width: natural - 2 * MyDataSpace.s4, child: const _Harness())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SegmentedControl<_View>)).width, lessThanOrEqualTo(natural - 2 * MyDataSpace.s4));
    for (final label in ['Day', 'Week', 'Month']) {
      final text = tester.getRect(find.text(label));
      final target = tester.getRect(_target(label));
      expect(text.left - target.left, greaterThanOrEqualTo(SegmentedControl.minSidePadding(kiwiLook)));
      expect(target.right - text.right, greaterThanOrEqualTo(SegmentedControl.minSidePadding(kiwiLook)));
    }
  });

  testWidgets('asserts two to five segments and a selected value among them', (tester) async {
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        const SegmentedControl<int>(segments: [(1, 'One')], selected: 1, onChanged: _ignore),
      ),
    );
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        const SegmentedControl<int>(
          segments: [(1, 'A'), (2, 'B'), (3, 'C'), (4, 'D'), (5, 'E'), (6, 'F')],
          selected: 1,
          onChanged: _ignore,
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        const SegmentedControl<int>(segments: [(1, 'A'), (2, 'B')], selected: 3, onChanged: _ignore),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}

void _ignore(Object? _) {}
