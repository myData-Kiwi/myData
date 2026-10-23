import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop(bool _) {}

// Invented calendars with the colours the preview uses (design/components/DataColour/preview.html).
final _red = parseDataColour('#E5484D');
final _purple = parseDataColour('#8E4EC6');
final _blue = parseDataColour('#3E7BFA');
final _grey = parseDataColour('#8E8E93');
final _yellow = parseDataColour('#F5D90A');
final _nearBlack = parseDataColour('#1F1F1F');
final _white = parseDataColour('#FFFFFF');
final _teal = parseDataColour('#12A594');

MyDataColors _colors(String theme, Brightness b) => MyDataTheme.data(theme, b).extension<MyDataColors>()!;

BoxDecoration _decorationOf(WidgetTester tester, Finder widget) {
  final box = find.descendant(of: widget, matching: find.byType(Container)).evaluate().isNotEmpty
      ? tester.widget<Container>(find.descendant(of: widget, matching: find.byType(Container)).first).decoration
      : tester.widget<DecoratedBox>(find.descendant(of: widget, matching: find.byType(DecoratedBox)).first).decoration;
  return box! as BoxDecoration;
}

/// The two calendar lists of the preview, one GroupedList per source, plus a subscribed calendar.
Widget _calendarLists({bool hoverKey = false}) => SizedBox(
    width: 440,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GroupedList(heading: 'This Mac', rows: [
        CalendarListRow(colour: _red, name: 'Family', caption: 'iCloud', shown: true, onChanged: _noop),
        CalendarListRow(colour: _purple, name: 'Personal', caption: 'iCloud', shown: false, onChanged: _noop),
        CalendarListRow(
            colour: _blue, name: 'Work', caption: CalendarListRow.onlyOnThisMac, shown: true, onChanged: _noop),
        CalendarListRow(
            key: const ValueKey('hovered'),
            colour: _grey,
            name: 'Birthdays',
            caption: CalendarListRow.birthdaysFromContacts,
            shown: true,
            onChanged: _noop),
        CalendarListRow(
            colour: _teal,
            name: 'Holidays (example)',
            caption: CalendarListRow.subscribed,
            shown: false,
            onChanged: _noop),
        const CalendarListRow(
            colour: null, name: 'Book club', caption: CalendarListRow.onlyOnThisMac, shown: true, onChanged: _noop)
      ]),
      const SizedBox(height: MyDataSpace.s4),
      GroupedList(heading: 'iCloud account you@example.com', rows: [
        CalendarListRow(
            key: const ValueKey('focused'),
            colour: _yellow,
            name: 'Garden club',
            shown: true,
            onChanged: _noop,
            autofocus: true),
        CalendarListRow(colour: _nearBlack, name: 'Choir', shown: true, onChanged: _noop),
        CalendarListRow(colour: _white, name: 'Allotment', shown: false, onChanged: null)
      ])
    ]));

/// Dots and bars in every colour case, on each ground the spec names, and as EventRow and a month cell use
/// them.
Widget _swatches() => Builder(builder: (context) {
      final c = context.colors;
      final colours = <Color?>[_red, _yellow, _nearBlack, _white, parseDataColour('#3E7BFA80'), null];
      Widget ground(DataGround g, String label) => Container(
          padding: const EdgeInsets.all(MyDataSpace.s3),
          decoration: BoxDecoration(color: g.of(c), borderRadius: MyDataRadii.md(kiwiLook)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: MyDataType.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: MyDataSpace.s2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final col in colours) ...[DataDot(colour: col, ground: g), const SizedBox(width: MyDataSpace.s3)]
            ]),
            const SizedBox(height: MyDataSpace.s2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final col in colours) ...[
                DataBar(colour: col, ground: g, height: MyDataSpace.s5),
                const SizedBox(width: MyDataSpace.s3)
              ]
            ])
          ]));
      Widget event(String when, String? end, Color? col, String title, String caption) => IntrinsicHeight(
          child: Padding(
              padding: GroupedRow.padding(kiwiLook),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                    width: MyDataSpace.s16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(when, style: MyDataType.body.copyWith(color: c.ink)),
                      if (end != null) Text(end, style: MyDataType.caption.copyWith(color: c.inkMuted))
                    ])),
                const SizedBox(width: MyDataSpace.s3),
                DataBar(colour: col),
                const SizedBox(width: MyDataSpace.s3),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
                  Text(caption, style: MyDataType.caption.copyWith(color: c.inkMuted))
                ]))
              ])));
      return SizedBox(
          width: 512,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: ground(DataGround.surface, 'Surface')),
              const SizedBox(width: MyDataSpace.s2),
              Expanded(child: ground(DataGround.accentSoft, 'Selected')),
              const SizedBox(width: MyDataSpace.s2),
              Expanded(child: ground(DataGround.surfaceSunken, 'Sunken'))
            ]),
            const SizedBox(height: MyDataSpace.s4),
            DecoratedBox(
                decoration:
                    BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(kiwiLook), boxShadow: context.shadows.shadow1),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  event('All day', null, _yellow, 'Seed swap', 'Garden club'),
                  Container(height: 1, color: c.line),
                  event('18:00', '19:30', _nearBlack, 'Choir practice', 'Example Hall · Choir'),
                  Container(height: 1, color: c.line),
                  event('20:00', '21:00', null, 'Book club', 'Book club')
                ]))
          ]));
    });

void main() {
  goldenMatrix('data_colour_calendar_list', _calendarLists, size: const Size(488, 760), before: (tester) async {
    // Keyboard focus on "Garden club" (autofocus), and the mouse over "Birthdays": its grey passes 3:1 on
    // `surface` but not on the hover fill in Kiwi light, so it shows the edge measured on both grounds.
    tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
    addTearDown(mouse.removePointer);
    await tester.pump();
  });

  goldenMatrix('data_colour_swatches', _swatches, size: const Size(560, 420));

  group('parseDataColour', () {
    test('reads #RRGGBB in either case', () {
      expect(parseDataColour('#E5484D'), const Color(0xFFE5484D));
      expect(parseDataColour('#e5484d'), const Color(0xFFE5484D));
      expect(parseDataColour('  #A9CC4E '), const Color(0xFFA9CC4E));
    });

    test('reads #RRGGBBAA and ignores the alpha: the colour is opaque', () {
      expect(parseDataColour('#34AADCFF'), const Color(0xFF34AADC));
      expect(parseDataColour('#3E7BFA80'), const Color(0xFF3E7BFA));
      expect(parseDataColour('#3E7BFA00'), const Color(0xFF3E7BFA));
    });

    test('anything else is no colour', () {
      for (final v in [null, '', '#', 'E5484D', '#FFF', '#E5484', '#E5484DF', '#GGGGGG', 'red', 'rgb(1,2,3)']) {
        expect(parseDataColour(v), isNull, reason: '$v');
      }
    });
  });

  group('the 3:1 edge rule', () {
    test('contrast is the WCAG ratio and ignores alpha', () {
      expect(dataColourContrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
      expect(dataColourContrast(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21, 0.01));
      expect(dataColourContrast(const Color(0xFF777777), const Color(0xFF777777)), 1);
      expect(dataColourContrast(const Color(0x00000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    });

    test('yellow on white and near black on a dark surface get the edge; strong colours do not', () {
      final light = _colors('kiwi', Brightness.light);
      final dark = _colors('kiwi', Brightness.dark);
      expect(dataColourNeedsEdge(_yellow!, light.surface), isTrue);
      expect(dataColourNeedsEdge(_yellow!, dark.surface), isFalse);
      expect(dataColourNeedsEdge(_nearBlack!, light.surface), isFalse);
      expect(dataColourNeedsEdge(_nearBlack!, dark.surface), isTrue);
      expect(dataColourNeedsEdge(_blue!, light.surface), isFalse);
      // Exactly 3:1 is enough; just under is not.
      expect(DataGround.minContrast, 3.0);
    });

    test('each ground is its token', () {
      final c = _colors('graphite', Brightness.dark);
      expect(DataGround.surface.of(c), c.surface);
      expect(DataGround.accentSoft.of(c), c.accentSoft);
      expect(DataGround.surfaceSunken.of(c), c.surfaceSunken);
      expect(DataGround.surfaceHover.of(c), c.surfaceHover);
    });
  });

  group('DataDot', () {
    testWidgets('an 8px circle drawn exactly as given; the slot is an icon-tile square', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Row(mainAxisSize: MainAxisSize.min, children: [
            DataDot(key: const ValueKey('bare'), colour: _red),
            DataDot.slot(key: const ValueKey('slot'), colour: _red)
          ])));
      expect(tester.getSize(find.byKey(const ValueKey('bare'))), const Size.square(8));
      expect(tester.getSize(find.byKey(const ValueKey('slot'))), const Size.square(MyDataSize.iconTile));
      final dot = find.descendant(of: find.byKey(const ValueKey('slot')), matching: find.byType(Container));
      expect(tester.getSize(dot), Size.square(DataDot.diameter(kiwiLook)));
      expect(tester.getCenter(dot), tester.getCenter(find.byKey(const ValueKey('slot'))));
      final d = _decorationOf(tester, find.byKey(const ValueKey('bare')));
      expect(d.color, _red);
      expect(d.shape, BoxShape.circle);
      expect(d.border, isNull);
    });

    for (final theme in themeMatrix) {
      testWidgets('edge follows the ground in the current mode (${theme.label})', (tester) async {
        final c = theme.data.extension<MyDataColors>()!;
        await tester.pumpWidget(themedFrame(
            theme,
            Column(mainAxisSize: MainAxisSize.min, children: [
              DataDot(key: const ValueKey('yellow'), colour: _yellow),
              DataDot(key: const ValueKey('black'), colour: _nearBlack),
              DataDot(key: const ValueKey('selected'), colour: _yellow, ground: DataGround.accentSoft),
              DataDot(key: const ValueKey('sunken'), colour: _nearBlack, ground: DataGround.surfaceSunken)
            ])));
        for (final (key, colour, ground) in [
          ('yellow', _yellow!, c.surface),
          ('black', _nearBlack!, c.surface),
          ('selected', _yellow!, c.accentSoft),
          ('sunken', _nearBlack!, c.surfaceSunken)
        ]) {
          final d = _decorationOf(tester, find.byKey(ValueKey(key)));
          final needs = dataColourContrast(colour, ground) < 3;
          expect(d.border != null, needs, reason: key);
          if (needs) {
            final side = (d.border! as Border).top;
            expect(side.color, c.lineStrong);
            expect(side.width, 1);
            expect(side.strokeAlign, BorderSide.strokeAlignInside);
          }
          // Never lightened, darkened or tinted.
          expect(d.color, colour);
        }
      });
    }

    testWidgets('no colour is line-strong; alpha in a Color is dropped', (tester) async {
      final c = _colors('kiwi', Brightness.light);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            const DataDot(key: ValueKey('none'), colour: null),
            DataDot(key: const ValueKey('alpha'), colour: _blue!.withValues(alpha: 0.3))
          ])));
      expect(_decorationOf(tester, find.byKey(const ValueKey('none'))).color, c.lineStrong);
      expect(_decorationOf(tester, find.byKey(const ValueKey('none'))).border, isNull);
      expect(_decorationOf(tester, find.byKey(const ValueKey('alpha'))).color, _blue);
    });

    testWidgets('has no accessible name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, DataDot.slot(colour: _red)));
      expect(tester.getSemantics(find.byType(DataDot)).label, isEmpty);
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });
  });

  group('DataBar', () {
    testWidgets('space-1 wide, radius-pill, as tall as the text it marks', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
              width: 300,
              child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DataBar(colour: _red),
                const SizedBox(width: MyDataSpace.s3),
                const Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Choir practice', key: ValueKey('title'), style: MyDataType.bodyStrong),
                  Text('Example Hall · Choir', key: ValueKey('caption'), style: MyDataType.caption)
                ]))
              ])))));
      final bar = tester.getRect(find.byType(DataBar));
      expect(bar.width, MyDataSpace.s1);
      expect(bar.top, tester.getRect(find.byKey(const ValueKey('title'))).top);
      expect(bar.bottom, tester.getRect(find.byKey(const ValueKey('caption'))).bottom);
      final d = _decorationOf(tester, find.byType(DataBar));
      expect(d.borderRadius, MyDataRadii.pill(kiwiLook));
      expect(d.color, _red);
    });

    testWidgets('a fixed height, or one body line with no bound; never makes a row taller', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            DataBar(key: const ValueKey('fixed'), colour: _red, height: 12),
            DataBar(key: const ValueKey('free'), colour: _red)
          ])));
      expect(tester.getSize(find.byKey(const ValueKey('fixed'))), const Size(4, 12));
      expect(tester.getSize(find.byKey(const ValueKey('free'))).height, closeTo(22, 0.01));
      final bar = tester.renderObject<RenderBox>(find.byKey(const ValueKey('free')));
      expect(bar.getMaxIntrinsicHeight(double.infinity), 0);
      expect(bar.getMaxIntrinsicWidth(double.infinity), MyDataSpace.s1);
    });

    testWidgets('the edge rule: a near-black bar on a dark surface, a yellow bar on a light one', (tester) async {
      for (final (theme, colour) in [(themeMatrix[0], _yellow), (themeMatrix[1], _nearBlack)]) {
        final c = theme.data.extension<MyDataColors>()!;
        await tester.pumpWidget(themedFrame(theme, DataBar(colour: colour, height: 20)));
        // The theme animates from the previous case's; let it arrive.
        await tester.pumpAndSettle();
        final d = _decorationOf(tester, find.byType(DataBar));
        expect((d.border! as Border).top.color, c.lineStrong, reason: theme.label);
        expect(d.color, colour);
      }
      await tester.pumpWidget(themedFrame(themeMatrix[0], const DataBar(colour: null, height: 20)));
      await tester.pumpAndSettle();
      expect(_decorationOf(tester, find.byType(DataBar)).color, _colors('kiwi', Brightness.light).lineStrong);
    });

    testWidgets('a loose height bound never stretches it: a non-stretch row stays one line tall', (tester) async {
      // A month cell: a day label over a row of bar and title, in a bounded cell; and a row under a tall bound.
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 100,
                height: 120,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('18', style: MyDataType.caption),
                  Row(key: const ValueKey('cell'), children: [
                    DataBar(key: const ValueKey('cellBar'), colour: _red),
                    const Flexible(child: Text('Seed swap', key: ValueKey('cellText'), style: MyDataType.body))
                  ])
                ])),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
                child: Row(key: const ValueKey('tall'), mainAxisSize: MainAxisSize.min, children: [
                  DataBar(key: const ValueKey('tallBar'), colour: _red),
                  const Text('Seed swap', key: ValueKey('tallText'), style: MyDataType.body)
                ]))
          ])));
      for (final k in ['cell', 'tall']) {
        final text = tester.getSize(find.byKey(ValueKey('${k}Text'))).height;
        // One body line: the row is the text's height (the bar's 22 is the text's to within rounding), not the
        // cell's 98 or the bound's 300.
        expect(tester.getSize(find.byKey(ValueKey(k))).height, closeTo(text, 0.01), reason: k);
        expect(tester.getSize(find.byKey(ValueKey('${k}Bar'))), Size(MyDataSpace.s1, DataBar.fallbackHeight(kiwiLook)),
            reason: k);
      }
      // A bound smaller than one line clamps it.
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 10),
                  child: DataBar(key: const ValueKey('small'), colour: _red)))));
      expect(tester.getSize(find.byKey(const ValueKey('small'))).height, 10);
    });

    testWidgets('alsoOn: the edge is drawn when any ground the bar can show on fails 3:1', (tester) async {
      final c = _colors('kiwi', Brightness.light);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            DataBar(key: const ValueKey('one'), colour: _grey, height: 20),
            DataBar(key: const ValueKey('both'), colour: _grey, height: 20, alsoOn: const [DataGround.surfaceSunken])
          ])));
      expect(dataColourNeedsEdge(_grey!, c.surface), isFalse);
      expect(dataColourNeedsEdge(_grey!, c.surfaceSunken), isTrue);
      expect(_decorationOf(tester, find.byKey(const ValueKey('one'))).border, isNull);
      expect(_decorationOf(tester, find.byKey(const ValueKey('both'))).border, isNotNull);
    });

    testWidgets('has no accessible name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, DataBar(colour: _red, height: 20)));
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });
  });

  group('CalendarListRow', () {
    Widget list(List<GroupedRow> rows, {String heading = 'This Mac'}) =>
        SizedBox(width: 440, child: GroupedList(heading: heading, rows: rows));

    testWidgets('dot in an icon-tile slot, name in body-strong, caption in caption, the switch at the end',
        (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          list([
            CalendarListRow(colour: _red, name: 'Family', caption: 'iCloud', shown: true, onChanged: _noop),
            const GroupedRow(icon: Icons.event_outlined, title: 'With a tile')
          ])));
      final c = _colors('kiwi', Brightness.light);
      final row = tester.getRect(find.byType(CalendarListRow));
      final slot = tester.getRect(find.byType(DataDot));
      expect(row.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      expect(slot.left - row.left, MyDataSpace.s4);
      expect(slot.size, const Size.square(MyDataSize.iconTile));
      expect(row.right - tester.getRect(find.byType(SwitchTrack)).right, MyDataSpace.s4);
      // Names line up with rows that have tiles.
      expect(tester.getRect(find.text('Family')).left, tester.getRect(find.text('With a tile')).left);
      expect(tester.widget<Text>(find.text('Family')).style, MyDataType.bodyStrong.copyWith(color: c.ink));
      expect(tester.widget<Text>(find.text('iCloud')).style, MyDataType.caption.copyWith(color: c.inkMuted));
      expect(find.text('This Mac'), findsOneWidget);
    });

    testWidgets('the whole row flips it; Tab reaches it; Space and Enter flip it', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          list([CalendarListRow(colour: _red, name: 'Family', caption: 'iCloud', shown: true, onChanged: got.add)])));
      await tester.tap(find.text('Family'));
      await tester.tap(find.byType(DataDot));
      await tester.tap(find.byType(SwitchTrack));
      expect(got, [false, false, false]);
      got.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(got, [false, false]);
    });

    testWidgets('a hidden calendar keeps its row and its dot', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          list([
            CalendarListRow(colour: _purple, name: 'Personal', caption: 'iCloud', shown: false, onChanged: _noop)
          ])));
      expect(find.text('Personal'), findsOneWidget);
      expect(_decorationOf(tester, find.byType(DataDot)).color, _purple);
      expect(tester.widget<SwitchTrack>(find.byType(SwitchTrack)).value, isFalse);
      final opacity = tester.widget<AnimatedOpacity>(
          find.descendant(of: find.byType(CalendarListRow), matching: find.byType(AnimatedOpacity)));
      expect(opacity.opacity, 1);
    });

    testWidgets('semantics: "Show" and the name, then the caption, as a switch', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          list([
            CalendarListRow(colour: _red, name: 'Family', caption: 'iCloud', shown: true, onChanged: _noop),
            CalendarListRow(colour: _yellow, name: 'Garden club', shown: false, onChanged: _noop)
          ])));
      expect(
          tester.getSemantics(find.byType(CalendarListRow).first),
          isSemantics(
              label: 'Show Family\niCloud',
              hasToggledState: true,
              isToggled: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      expect(
          tester.getSemantics(find.byType(CalendarListRow).last),
          isSemantics(
              label: 'Show Garden club',
              hasToggledState: true,
              isToggled: false,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      handle.dispose();
    });

    testWidgets('disabled: 45% opacity, Tab skips it, announced as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          list([
            CalendarListRow(colour: _red, name: 'Family', shown: true, onChanged: null),
            CalendarListRow(colour: _blue, name: 'Work', shown: true, onChanged: _noop)
          ])));
      final disabled = find.byType(CalendarListRow).first;
      final enabled = find.byType(CalendarListRow).last;
      expect(
          tester.widget<AnimatedOpacity>(find.descendant(of: disabled, matching: find.byType(AnimatedOpacity))).opacity,
          Pressable.disabledOpacity);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(find.descendant(of: disabled, matching: find.byWidget(focused.widget)), findsNothing);
      expect(find.descendant(of: enabled, matching: find.byWidget(focused.widget)), findsOneWidget);
      expect(
          tester.getSemantics(disabled),
          isSemantics(
              label: 'Show Family', hasToggledState: true, isToggled: true, hasEnabledState: true, isEnabled: false));
      handle.dispose();
    });

    testWidgets('a press fills the row and does not shrink it', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, list([CalendarListRow(colour: _red, name: 'Family', shown: true, onChanged: _noop)])));
      final before = tester.getSize(find.byType(CalendarListRow));
      final g = await tester.startGesture(tester.getCenter(find.text('Family')));
      await tester.pump(MyDataMotion.fast);
      expect(find.byType(AnimatedScale), findsNothing);
      final fill = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byType(CalendarListRow), matching: find.byType(AnimatedContainer)).first);
      expect((fill.decoration! as BoxDecoration).color, _colors('kiwi', Brightness.light).surfaceHover);
      expect(tester.getSize(find.byType(CalendarListRow)), before);
      await g.up();
    });

    for (final theme in themeMatrix) {
      testWidgets('the dot\'s edge is measured on surface and on the hover fill (${theme.label})', (tester) async {
        final c = theme.data.extension<MyDataColors>()!;
        final colours = {'Birthdays': _grey!, 'Holidays (example)': _teal!, 'Family': _red!, 'Garden club': _yellow!};
        await tester.pumpWidget(themedFrame(
            theme,
            list([
              for (final e in colours.entries)
                CalendarListRow(colour: e.value, name: e.key, shown: true, onChanged: _noop)
            ])));
        // Hover each row in turn: the edge does not change under the pointer, and it is there whenever the
        // colour fails 3:1 on either ground.
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        for (final e in colours.entries) {
          final row = find.ancestor(of: find.text(e.key), matching: find.byType(CalendarListRow));
          final needs = dataColourNeedsEdge(e.value, c.surface) || dataColourNeedsEdge(e.value, c.surfaceHover);
          final dot = find.descendant(of: row, matching: find.byType(DataDot));
          expect(_decorationOf(tester, dot).border != null, needs, reason: '${e.key}, resting');
          await mouse.moveTo(tester.getCenter(row));
          await tester.pumpAndSettle();
          expect(_decorationOf(tester, dot).border != null, needs, reason: '${e.key}, hovered');
        }
        if (theme.label == 'kiwi-light') {
          // The review's cases: pass on white, fail on the hover fill.
          for (final col in [_grey!, _teal!]) {
            expect(dataColourNeedsEdge(col, c.surface), isFalse);
            expect(dataColourNeedsEdge(col, c.surfaceHover), isTrue);
          }
        }
      });
    }

    test('the three captions in myData\'s own words, and the accessors', () {
      expect(CalendarListRow.onlyOnThisMac, 'Only on this Mac');
      expect(CalendarListRow.birthdaysFromContacts, 'Birthdays from Contacts');
      expect(CalendarListRow.subscribed, 'Subscribed');
      expect(CalendarListRow.showLabel('Choir'), 'Show Choir');
      final row = CalendarListRow(colour: _red, name: 'Family', caption: 'iCloud', shown: false, onChanged: _noop);
      expect((row.name, row.caption, row.shown, row.colour), ('Family', 'iCloud', false, _red));
    });
  });
}
