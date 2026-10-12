import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}
void _noopBool(bool _) {}

final _kiwi = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;

Widget _frame(Widget child, {double width = 480, bool reduceMotion = false}) => themedFrame(
  themeMatrix.first,
  SizedBox(width: width, child: child),
  reduceMotion: reduceMotion,
);

/// The fill a row paints under its content (selected) and the hover fill Pressable animates.
Color? _rowFill(WidgetTester tester, Finder row) =>
    (tester.widget<DecoratedBox>(find.descendant(of: row, matching: find.byType(DecoratedBox)).first).decoration
            as BoxDecoration)
        .color;

Color? _hoverFill(WidgetTester tester, Finder row) =>
    (tester
                .widget<AnimatedContainer>(find.descendant(of: row, matching: find.byType(AnimatedContainer)).first)
                .decoration!
            as BoxDecoration)
        .color;

void main() {
  goldenMatrix(
    'grouped_list',
    () => SizedBox(
      width: 824,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GroupedList(
              heading: 'Sync',
              rows: const [
                GroupedRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Mail',
                  subtitle: '2 accounts',
                  trailing: GroupedTrailing.badge('Up to date', tone: MyDataTone.success),
                  onPressed: _noop,
                ),
                GroupedRow(
                  icon: Icons.calendar_today_outlined,
                  tone: MyDataTone.info,
                  title: 'Calendar',
                  subtitle: '3 calendars',
                  trailing: GroupedTrailing.badge('Up to date', tone: MyDataTone.success),
                  onPressed: _noop,
                  selected: true,
                ),
                GroupedRow(
                  icon: Icons.photo_outlined,
                  tone: MyDataTone.warning,
                  title: 'Photos',
                  subtitle: 'Indexing, example 64%',
                  trailing: GroupedTrailing.badge('In progress', tone: MyDataTone.warning),
                  onPressed: _noop,
                ),
                GroupedRow(
                  icon: Icons.smartphone_outlined,
                  title: 'Example phone',
                  subtitle: 'Seen 5 minutes ago',
                  trailing: GroupedTrailing.badge('Connected', tone: MyDataTone.info),
                ),
              ],
            ),
          ),
          const SizedBox(width: MyDataSpace.s6),
          Expanded(
            child: GroupedList(
              heading: 'Settings',
              rows: const [
                GroupedRow(
                  key: ValueKey('hovered'),
                  icon: Icons.storage_outlined,
                  title: 'Storage',
                  subtitle: 'Hovered',
                  trailing: GroupedTrailing.chevron(),
                  onPressed: _noop,
                ),
                GroupedRow(
                  icon: Icons.backup_outlined,
                  title: 'Back up',
                  subtitle: 'Focused',
                  trailing: GroupedTrailing.valueChevron('Every night'),
                  onPressed: _noop,
                  autofocus: true,
                ),
                GroupedRow.toggle(
                  icon: Icons.face_outlined,
                  title: 'Group photos by face',
                  subtitle: 'You name the groups.',
                  value: true,
                  onChanged: _noopBool,
                ),
                GroupedRow.toggle(
                  icon: Icons.public_outlined,
                  tone: MyDataTone.info,
                  title: 'Search the web',
                  subtitle: 'Needs the assistant to be on.',
                  value: false,
                  onChanged: null,
                ),
                GroupedRow(title: 'Version', trailing: GroupedTrailing.value('0.1.0')),
                GroupedRow(
                  title: 'Remove this Mac',
                  subtitle: 'Disabled',
                  trailing: GroupedTrailing.chevron(),
                  onPressed: _noop,
                  enabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    size: const Size(872, 416),
    before: (tester) async {
      // Keyboard focus on the second settings row, and the mouse over the first.
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  group('GroupedList', () {
    testWidgets('a tap on a row calls onPressed; a static row does nothing', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: [
              GroupedRow(title: 'Storage', trailing: const GroupedTrailing.chevron(), onPressed: () => taps++),
              const GroupedRow(title: 'Version', trailing: GroupedTrailing.value('0.1.0')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Storage'));
      await tester.tapAt(tester.getTopLeft(find.byType(GroupedRow).first) + const Offset(4, 4));
      await tester.tap(find.text('Version'));
      expect(taps, 2);
      expect(find.descendant(of: find.byType(GroupedRow).last, matching: find.byType(Pressable)), findsNothing);
    });

    testWidgets('Tab skips static and disabled rows; Enter and Space activate', (tester) async {
      final got = <String>[];
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: [
              const GroupedRow(title: 'Version', trailing: GroupedTrailing.value('0.1.0')),
              GroupedRow(
                title: 'Remove',
                trailing: const GroupedTrailing.chevron(),
                onPressed: () => got.add('x'),
                enabled: false,
              ),
              GroupedRow(
                title: 'Storage',
                trailing: const GroupedTrailing.chevron(),
                onPressed: () => got.add('storage'),
              ),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.descendant(of: find.byType(GroupedRow).last, matching: find.byWidget(focused.widget)),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, ['storage', 'storage']);
    });

    testWidgets('a switch row: the whole row flips it, by tap or by key', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: [
              GroupedRow.toggle(
                icon: Icons.face_outlined,
                title: 'Group photos by face',
                subtitle: 'You name the groups.',
                value: false,
                onChanged: got.add,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Group photos by face'));
      await tester.tap(find.byType(SwitchTrack));
      await tester.tap(find.byType(IconTile));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, [true, true, true, true]);
    });

    testWidgets('a switch row with onChanged null is disabled: 45%, skipped, announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: const [
              GroupedRow.toggle(
                title: 'Search the web',
                subtitle: 'Needs the assistant.',
                value: false,
                onChanged: null,
              ),
            ],
          ),
        ),
      );
      final row = find.byType(GroupedRow);
      expect(
        tester.widget<AnimatedOpacity>(find.descendant(of: row, matching: find.byType(AnimatedOpacity))).opacity,
        Pressable.disabledOpacity,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.descendant(of: row, matching: find.byWidget(FocusManager.instance.primaryFocus!.context!.widget)),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.text('Search the web')),
        isSemantics(
          label: 'Search the web\nNeeds the assistant.',
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: one node per row with title, subtitle and value; heading is a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _frame(
          GroupedList(
            heading: 'Sync',
            rows: const [
              GroupedRow(
                icon: Icons.mail_outline_rounded,
                title: 'Mail',
                subtitle: '2 accounts',
                trailing: GroupedTrailing.badge('Up to date', tone: MyDataTone.success),
                onPressed: _noop,
                selected: true,
              ),
              GroupedRow(title: 'Backup', trailing: GroupedTrailing.valueChevron('Every night'), onPressed: _noop),
              GroupedRow(title: 'Example phone', subtitle: 'Seen 5 minutes ago'),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Mail')),
        isSemantics(
          label: 'Mail\n2 accounts\nUp to date',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Backup')),
        isSemantics(label: 'Backup\nEvery night', isButton: true, isFocusable: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('Example phone')),
        isSemantics(label: 'Example phone\nSeen 5 minutes ago', isButton: false, hasTapAction: false),
      );
      expect(tester.getSemantics(find.text('Sync')), isSemantics(label: 'Sync', isHeader: true));
      handle.dispose();
    });

    testWidgets('geometry: rows at least row-height, s4 by s2 padding, s3 gaps, full-width line dividers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _frame(
          GroupedList(
            heading: 'Sync',
            rows: const [
              GroupedRow(
                icon: Icons.mail_outline_rounded,
                title: 'Mail',
                subtitle: '2 accounts',
                trailing: GroupedTrailing.valueChevron('2'),
                onPressed: _noop,
              ),
              GroupedRow(title: 'Version'),
              GroupedRow.toggle(title: 'Calendar', value: true, onChanged: _noopBool),
            ],
          ),
        ),
      );
      final rows = find.byType(GroupedRow);
      final first = tester.getRect(rows.first);
      for (var i = 0; i < 3; i++) {
        final r = tester.getRect(rows.at(i));
        expect(r.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
        expect(r.width, 480);
      }
      final tile = tester.getRect(find.byType(IconTile));
      expect(tile.left - first.left, MyDataSpace.s4);
      expect(tester.getRect(find.text('Mail')).left - tile.right, MyDataSpace.s3);
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right_rounded));
      expect(first.right - chevron.right, MyDataSpace.s4);
      expect(chevron.left - tester.getRect(find.text('2')).right, GroupedRow.trailingGap);
      // Dividers: between rows only, 1px of `line`, the full width of the group.
      expect(tester.getRect(rows.at(1)).top - first.bottom, GroupedList.dividerWidth);
      final dividers = find.byWidgetPredicate((w) => w is Container && w.color == _kiwi.line);
      expect(dividers, findsNWidgets(2));
      expect(tester.getSize(dividers.first), const Size(480, GroupedList.dividerWidth));
      // The heading: `space-2` in and `space-2` above the group.
      final heading = tester.getRect(find.text('Sync'));
      expect(heading.left - first.left, MyDataSpace.s2);
      expect(first.top - heading.bottom, MyDataSpace.s2);
      // The group: surface, radius-lg, shadow-1, no border.
      final group = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(GroupedList), matching: find.byType(DecoratedBox)).first,
      );
      final d = group.decoration as BoxDecoration;
      expect(d.color, _kiwi.surface);
      expect(d.borderRadius, MyDataRadii.lg);
      expect(d.border, isNull);
      expect(d.boxShadow, isNotEmpty);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    });

    testWidgets('selected: accent-soft fill in the group corners', (tester) async {
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: const [
              GroupedRow(title: 'Mail', onPressed: _noop, selected: true),
              GroupedRow(title: 'Calendar', onPressed: _noop),
              GroupedRow(title: 'Notes', selected: true),
            ],
          ),
        ),
      );
      final rows = find.byType(GroupedRow);
      expect(_rowFill(tester, rows.at(0)), _kiwi.accentSoft);
      expect(_rowFill(tester, rows.at(1)), isNull);
      expect(_rowFill(tester, rows.at(2)), _kiwi.accentSoft);
      final top = tester.widget<DecoratedBox>(
        find.descendant(of: rows.at(0), matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (top.decoration as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MyDataRadius.lg)),
      );
      final bottom = tester.widget<DecoratedBox>(
        find.descendant(of: rows.at(2), matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (bottom.decoration as BoxDecoration).borderRadius,
        const BorderRadius.vertical(bottom: Radius.circular(MyDataRadius.lg)),
      );
    });

    testWidgets('hover and press fill the row with surface-sunken; it dims and does not shrink', (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
          _frame(
            GroupedList(
              rows: const [GroupedRow(title: 'Storage', trailing: GroupedTrailing.chevron(), onPressed: _noop)],
            ),
            reduceMotion: reduced,
          ),
        );
        final row = find.byType(GroupedRow);
        final before = tester.getSize(row);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(row));
        await tester.pump(MyDataMotion.fast);
        expect(_hoverFill(tester, row), _kiwi.surfaceSunken);
        await mouse.down(tester.getCenter(row));
        await tester.pump();
        expect(find.byType(AnimatedScale), findsNothing);
        expect(
          tester.widget<AnimatedOpacity>(find.descendant(of: row, matching: find.byType(AnimatedOpacity))).opacity,
          MyDataMotion.pressOpacity,
        );
        expect(tester.getSize(row), before);
        await mouse.up();
        await mouse.removePointer();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a selected row hovers and presses with ink over its accent-soft, not accent-soft again', (
      tester,
    ) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: const [
              GroupedRow(title: 'Calendar', trailing: GroupedTrailing.chevron(), onPressed: _noop, selected: true),
            ],
          ),
        ),
      );
      final row = find.byType(GroupedRow);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(row));
      addTearDown(mouse.removePointer);
      await tester.pump(MyDataMotion.fast);
      final hover = _hoverFill(tester, row)!;
      expect(hover, _kiwi.ink.withValues(alpha: GroupedRow.selectedHoverInk));
      expect(_rowFill(tester, row), _kiwi.accentSoft);
      // What the eye sees: the hover fill over accent-soft differs from accent-soft.
      expect(Color.alphaBlend(hover, _kiwi.accentSoft), isNot(_kiwi.accentSoft));
      await mouse.down(tester.getCenter(row));
      await tester.pump();
      expect(_hoverFill(tester, row), hover);
      await mouse.up();
      await tester.pumpAndSettle();
    });

    testWidgets('sizes to its content: works inside IntrinsicHeight and IntrinsicWidth', (tester) async {
      const rows = [
        GroupedRow(
          icon: Icons.mail_outline_rounded,
          title: 'Mail',
          subtitle: '2 accounts',
          trailing: GroupedTrailing.badge('Up to date', tone: MyDataTone.success),
        ),
        GroupedRow(title: 'Back up', trailing: GroupedTrailing.valueChevron('Every night'), onPressed: _noop),
        GroupedRow.toggle(title: 'Faces', subtitle: 'You name the groups.', value: true, onChanged: _noopBool),
      ];
      await tester.pumpWidget(
        _frame(
          IntrinsicHeight(
            child: GroupedList(heading: 'Sync', rows: rows),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final r in tester.widgetList(find.byType(GroupedRow))) {
        expect(tester.getSize(find.byWidget(r)).height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      }
      // Shrink-wrapped (as a dialog sized to its content): as wide as its widest row, nothing cut short.
      await tester.pumpWidget(
        themedFrame(
          themeMatrix.first,
          Center(
            child: IntrinsicWidth(
              child: GroupedList(heading: 'Sync', rows: rows),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final width = tester.getSize(find.byType(GroupedList)).width;
      expect(width, lessThan(480));
      final every = tester.getRect(find.text('Every night'));
      expect(tester.getRect(find.text('Back up')).right + GroupedRow.gap, lessThanOrEqualTo(every.left + 0.5));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('Every night'));
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('a value takes the width it needs; only when both cannot fit is it held to half', (tester) async {
      const long = 'A long value that says a good deal more than usual';
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: const [
              GroupedRow(title: 'Note', trailing: GroupedTrailing.value(long)),
              GroupedRow(
                title: 'A long title that also needs most of the row to itself',
                trailing: GroupedTrailing.value(long),
              ),
            ],
          ),
        ),
      );
      final rows = find.byType(GroupedRow);
      final inner = 480 - 2 * MyDataSpace.s4 - GroupedRow.gap;
      final values = find.text(long);
      // Short title: the value takes more than half and is not cut short.
      expect(tester.getSize(values.first).width, greaterThan(inner * GroupedRow.maxTrailingFraction));
      expect(tester.renderObject<RenderParagraph>(values.first).didExceedMaxLines, isFalse);
      expect(tester.getRect(values.first).right, tester.getRect(rows.first).right - MyDataSpace.s4);
      // Long title: the value keeps half and is cut short with an ellipsis; the title keeps the rest.
      expect(tester.getSize(values.last).width, closeTo(inner * GroupedRow.maxTrailingFraction, 0.5));
      expect(tester.renderObject<RenderParagraph>(values.last).didExceedMaxLines, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('right to left: the tile and title at the right, the trailing part at the left', (tester) async {
      await tester.pumpWidget(
        themedFrame(
          themeMatrix.first,
          Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 480,
              child: GroupedList(
                rows: const [
                  GroupedRow(icon: Icons.mail_outline_rounded, title: 'Mail', trailing: GroupedTrailing.value('2')),
                ],
              ),
            ),
          ),
        ),
      );
      final row = tester.getRect(find.byType(GroupedRow));
      expect(row.right - tester.getRect(find.byType(IconTile)).right, MyDataSpace.s4);
      expect(tester.getRect(find.text('2')).left - row.left, MyDataSpace.s4);
    });

    testWidgets('trailing parts: the MyDataBadge, the switch track, a value', (tester) async {
      await tester.pumpWidget(
        _frame(
          GroupedList(
            rows: const [
              GroupedRow(
                title: 'Mail',
                trailing: GroupedTrailing.badge('Up to date', tone: MyDataTone.success),
              ),
              GroupedRow.toggle(title: 'Faces', value: true, onChanged: _noopBool),
              GroupedRow(title: 'Version', trailing: GroupedTrailing.value('0.1.0')),
            ],
          ),
        ),
      );
      expect(tester.widget<MyDataBadge>(find.byType(MyDataBadge)).tone, MyDataTone.success);
      expect(tester.widget<SwitchTrack>(find.byType(SwitchTrack)).value, isTrue);
      expect(tester.widget<Text>(find.text('0.1.0')).style!.color, _kiwi.inkMuted);
    });

    test('at most three tile tones in one list', () {
      expect(
        () => GroupedList(
          rows: const [
            GroupedRow(icon: Icons.mail_outline_rounded, title: 'A'),
            GroupedRow(icon: Icons.mail_outline_rounded, tone: MyDataTone.info, title: 'B'),
            GroupedRow(icon: Icons.mail_outline_rounded, tone: MyDataTone.warning, title: 'C'),
            GroupedRow(icon: Icons.mail_outline_rounded, tone: MyDataTone.success, title: 'D'),
          ],
        ),
        throwsAssertionError,
      );
      // Rows without a tile do not count.
      expect(
        () => GroupedList(
          rows: const [
            GroupedRow(icon: Icons.mail_outline_rounded, title: 'A'),
            GroupedRow(icon: Icons.mail_outline_rounded, tone: MyDataTone.info, title: 'B'),
            GroupedRow(icon: Icons.mail_outline_rounded, tone: MyDataTone.warning, title: 'C'),
            GroupedRow(tone: MyDataTone.success, title: 'D'),
          ],
        ),
        returnsNormally,
      );
    });

    test('a chevron row needs onPressed', () {
      expect(() => GroupedRow(title: 'A', trailing: const GroupedTrailing.chevron()), throwsAssertionError);
    });
  });
}
