import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented calendars with the colours of design/components/MonthGrid/preview.html.
final _work = parseDataColour('#3E7BFA');
final _personal = parseDataColour('#8E4EC6');
final _family = parseDataColour('#E5484D');
final _choir = parseDataColour('#1F1F1F');
final _birthdays = parseDataColour('#8E8E93');
final _garden = parseDataColour('#F5D90A');

MonthGridEvent _ev(String title, String calendar, Color? colour, {bool allDay = false, int? hour, DateTime? day}) =>
    MonthGridEvent(
        title: title,
        calendarName: calendar,
        colour: colour,
        allDay: allDay,
        start: hour == null ? null : DateTime(day?.year ?? 2026, day?.month ?? 10, day?.day ?? 1, hour));

/// The preview's October 2026: events on the days it shows them, a 4-event Friday and a calendar with no
/// colour (Book club).
Map<DateTime, List<MonthGridEvent>> _october2026() => {
      DateTime(2026, 10, 1): [_ev('Rent', 'Personal', _personal, allDay: true)],
      DateTime(2026, 10, 5): [_ev('Team planning', 'Work', _work, hour: 9)],
      DateTime(2026, 10, 7): [_ev('Choir practice', 'Choir', _choir, hour: 19)],
      DateTime(2026, 10, 10): [_ev('Sam Sample’s birthday', 'Birthdays', _birthdays, allDay: true)],
      // Given out of order: the grid puts all-day first, then by start.
      DateTime(2026, 10, 13): [
        _ev('Choir practice', 'Choir', _choir, hour: 19, day: DateTime(2026, 10, 13)),
        _ev('Dentist', 'Family', _family, hour: 8, day: DateTime(2026, 10, 13)),
      ],
      DateTime(2026, 10, 14): [_ev('Conference in Lisbon', 'Work', _work, allDay: true)],
      DateTime(2026, 10, 15): [
        _ev('Seed swap', 'Garden club', _garden, hour: 10, day: DateTime(2026, 10, 15)),
        _ev('Conference in Lisbon', 'Work', _work, allDay: true),
      ],
      DateTime(2026, 10, 16): [
        _ev('Conference in Lisbon', 'Work', _work, allDay: true),
        _ev('Lunch with Ava', 'Personal', _personal, hour: 12, day: DateTime(2026, 10, 16)),
        _ev('School pickup', 'Family', _family, hour: 15, day: DateTime(2026, 10, 16)),
        _ev('Flight home', 'Work', _work, hour: 18, day: DateTime(2026, 10, 16)),
      ],
      DateTime(2026, 10, 19): [_ev('Book club', 'Book club', null, hour: 19)],
      DateTime(2026, 10, 21): [_ev('Choir practice', 'Choir', _choir, hour: 19)],
      DateTime(2026, 10, 22): [_ev('Ava Fictional’s birthday', 'Birthdays', _birthdays, allDay: true)],
      DateTime(2026, 10, 26): [_ev('Team planning', 'Work', _work, hour: 9)],
      DateTime(2026, 10, 31): [_ev('Costume party', 'Family', _family, hour: 18)],
      DateTime(2026, 11, 2): [_ev('Team planning', 'Work', _work, hour: 9)],
    };

/// The phone preview's October 2025: this Mac is read from 13 October 2025.
Map<DateTime, List<MonthGridEvent>> _october2025() => {
      DateTime(2025, 10, 14): [_ev('Choir practice', 'Choir', _choir, hour: 19)],
      DateTime(2025, 10, 17): [
        _ev('Dinner', 'Family', _family, hour: 19),
        _ev('Review', 'Work', _work, hour: 20),
      ],
      DateTime(2025, 10, 22): [_ev('Ava Fictional’s birthday', 'Birthdays', _birthdays, allDay: true)],
      DateTime(2025, 10, 24): [
        _ev('Lunch with Ava', 'Personal', _personal, hour: 12),
        _ev('Seed swap', 'Garden club', _garden, hour: 14),
        _ev('Planning', 'Work', _work, hour: 15),
        _ev('Retro', 'Work', _work, hour: 16),
      ],
      DateTime(2025, 10, 30): [_ev('Team planning', 'Work', _work, hour: 9)],
    };

bool _beforeOct13of2025(DateTime d) => d.isBefore(DateTime(2025, 10, 13));

const _readRange = 'myData reads events from this Mac between 13 October 2025 and 13 October 2028.';

/// Holds the month and selection, as a screen does, and records the callbacks.
class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    this.firstDayOfWeek = DateTime.monday,
    this.events = const {},
    this.isNotRead,
    this.notice,
    this.autofocus = false,
    this.width = MyDataSize.contentMax,
    this.log,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final int? firstDayOfWeek;
  final Map<DateTime, List<MonthGridEvent>> events;
  final bool Function(DateTime)? isNotRead;
  final Widget? notice;
  final bool autofocus;
  final double width;
  final List<String>? log;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime month = widget.month;
  late DateTime selected = widget.selected;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: MonthGrid(
          month: month,
          today: widget.today,
          selected: selected,
          firstDayOfWeek: widget.firstDayOfWeek,
          events: widget.events,
          isNotRead: widget.isNotRead,
          notice: widget.notice,
          autofocus: widget.autofocus,
          onSelected: (d) {
            widget.log?.add('select ${_ymd(d)}');
            setState(() => selected = d);
          },
          onMonthChanged: (m) {
            widget.log?.add('month ${_ymd(m)}');
            setState(() => month = m);
          },
        ),
      );
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget _desktop({DateTime? selected, DateTime? today, int firstDay = DateTime.monday, bool autofocus = false}) =>
    _Host(
        month: DateTime(2026, 10),
        today: today ?? DateTime(2026, 10, 13),
        selected: selected ?? DateTime(2026, 10, 16),
        firstDayOfWeek: firstDay,
        events: _october2026(),
        autofocus: autofocus);

Widget _notRead() => _Host(
    month: DateTime(2025, 10),
    // Today and not read: a source that has not read this day yet.
    today: DateTime(2025, 10, 8),
    selected: DateTime(2025, 10, 9),
    events: _october2025(),
    isNotRead: _beforeOct13of2025,
    notice: const Notice(message: _readRange));

Widget _phone() => _Host(
    month: DateTime(2025, 10),
    today: DateTime(2026, 10, 13),
    selected: DateTime(2025, 10, 24),
    events: _october2025(),
    isNotRead: _beforeOct13of2025,
    notice: const Notice(message: _readRange),
    // A 390px phone less its 16px gutters (design/platforms.md), as the preview's 358px.
    width: 358);

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(1000, 900), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, _scaled(textScale, child)));
  await tester.pumpAndSettle();
}

/// [child] at the system text size [textScale] (theming.md: "scaled by the system setting").
Widget _scaled(double textScale, Widget child) => textScale == 1
    ? child
    : Builder(
        builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child));

/// "Larger" text: the scale the review probed with.
const _largeText = 1.6;

Future<void> _hover(WidgetTester tester, String label) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: tester.getCenter(find.bySemanticsLabel(label)));
  addTearDown(mouse.removePointer);
}

void _keyboardFocus(WidgetTester tester) {
  tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
}

void main() {
  group('dates', () {
    test('six weeks from the week holding the 1st, on the first day given', () {
      final mon = MonthGrid.visibleDays(DateTime(2026, 10), DateTime.monday);
      expect(mon, hasLength(42));
      expect(mon.first, DateTime(2026, 9, 28));
      expect(mon.last, DateTime(2026, 11, 8));
      final sun = MonthGrid.visibleDays(DateTime(2026, 10, 20), DateTime.sunday);
      expect(sun.first, DateTime(2026, 9, 27));
      expect(sun.first.weekday, DateTime.sunday);
      // February 2026 starts on a Sunday: with Sunday first, the grid starts on the 1st and ends in March.
      final feb = MonthGrid.visibleDays(DateTime(2026, 2), DateTime.sunday);
      expect(feb.first, DateTime(2026, 2, 1));
      expect(feb.last, DateTime(2026, 3, 14));
      // Saturday first.
      expect(MonthGrid.visibleDays(DateTime(2026, 10), DateTime.saturday).first, DateTime(2026, 9, 26));
    });

    test('the locale decides the first day of the week', () {
      expect(MonthGrid.firstDayOfWeekFor(const Locale('en', 'US')), DateTime.sunday);
      expect(MonthGrid.firstDayOfWeekFor(const Locale('en', 'GB')), DateTime.monday);
      expect(MonthGrid.firstDayOfWeekFor(const Locale('en', 'NZ')), DateTime.monday);
      expect(MonthGrid.firstDayOfWeekFor(const Locale('ar', 'EG')), DateTime.saturday);
      expect(MonthGrid.firstDayOfWeekFor(const Locale('dv', 'MV')), DateTime.friday);
      expect(MonthGrid.firstDayOfWeekFor(const Locale('de')), DateTime.monday);
    });

    test('names', () {
      expect(MonthGrid.monthTitle(DateTime(2026, 10, 16)), 'October 2026');
      expect(MonthGrid.weekdayShortName(DateTime.monday), 'Mon');
      expect(MonthGrid.weekdayName(DateTime.sunday), 'Sunday');
    });
  });

  group('accessible names', () {
    test('as the spec words them', () {
      final friday = MonthGrid.sortEvents(_october2026()[DateTime(2026, 10, 16)]!);
      expect(MonthGrid.dayLabel(DateTime(2026, 10, 16), events: friday),
          'Friday 16 October, 4 events in Work, Personal and Family');
      final tuesday = MonthGrid.sortEvents(_october2026()[DateTime(2026, 10, 13)]!);
      expect(MonthGrid.dayLabel(DateTime(2026, 10, 13), today: true, events: tuesday),
          'Tuesday 13 October, today, 2 events in Family and Choir');
      expect(MonthGrid.dayLabel(DateTime(2026, 10, 1), events: _october2026()[DateTime(2026, 10, 1)]!),
          'Thursday 1 October, 1 event in Personal');
      expect(MonthGrid.dayLabel(DateTime(2026, 9, 28)), 'Monday 28 September, no events');
      expect(MonthGrid.dayLabel(DateTime(2025, 10, 1), notRead: true, events: friday),
          'Wednesday 1 October, events not shown');
      expect(MonthGrid.dayLabel(DateTime(2025, 10, 8), today: true, notRead: true),
          'Wednesday 8 October, today, events not shown');
    });

    test('lists join as English does', () {
      expect(MonthGrid.joinList(['Work']), 'Work');
      expect(MonthGrid.joinList(['Work', 'Family']), 'Work and Family');
      expect(MonthGrid.joinList(['Work', 'Personal', 'Family']), 'Work, Personal and Family');
    });

    test('all-day first, then by start time, stable between equals', () {
      final sorted = MonthGrid.sortEvents([
        _ev('Late', 'A', null, hour: 18),
        _ev('Holiday', 'B', null, allDay: true),
        _ev('No start', 'C', null),
        _ev('Early', 'D', null, hour: 7),
        _ev('Also all day', 'E', null, allDay: true),
      ]);
      expect(sorted.map((e) => e.title), ['Holiday', 'Also all day', 'No start', 'Early', 'Late']);
    });

    testWidgets('Previous month and Next month are IconButtons, named and tooltipped', (tester) async {
      await _pump(tester, _desktop());
      expect(tester.widgetList<MyDataIconButton>(find.byType(MyDataIconButton)).map((b) => b.label),
          [MonthGrid.previousMonthLabel, MonthGrid.nextMonthLabel]);
    });

    testWidgets('every cell is named and the selected one is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _desktop());
      expect(find.bySemanticsLabel('October 2026'), findsWidgets);
      expect(find.bySemanticsLabel('Tuesday 13 October, today, 2 events in Family and Choir'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday 19 October, 1 event in Book club'), findsOneWidget);
      expect(find.bySemanticsLabel('Sunday 8 November, no events'), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
      expect(find.bySemanticsLabel('Next month'), findsOneWidget);
      final selected = tester.getSemantics(find.bySemanticsLabel('Friday 16 October, 4 events in Work, Personal and Family'));
      expect(selected, isSemantics(isSelected: true, hasTapAction: true));
      final other = tester.getSemantics(find.bySemanticsLabel('Thursday 15 October, 2 events in Work and Garden club'));
      expect(other, isSemantics(isSelected: false, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('days myData does not read are named "events not shown" and show no events', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _notRead());
      expect(find.bySemanticsLabel('Wednesday 8 October, today, events not shown'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday 29 September, events not shown'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday 13 October, no events'), findsOneWidget);
      expect(find.text(_readRange), findsOneWidget);
      handle.dispose();
    });
  });

  group('cells', () {
    testWidgets('three lines at most: two titles and "+n" when a day has more than three', (tester) async {
      await _pump(tester, _desktop());
      expect(find.text('Lunch with Ava'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('School pickup'), findsNothing);
      expect(find.text('Flight home'), findsNothing);
      // All-day first: the conference line comes before the seed swap on the 15th.
      final conference = tester.getTopLeft(find.text('Conference in Lisbon').at(1));
      final seeds = tester.getTopLeft(find.text('Seed swap'));
      expect(conference.dy, lessThan(seeds.dy));
      // Today's events in time order.
      expect(tester.getTopLeft(find.text('Dentist')).dy, lessThan(tester.getTopLeft(find.text('Choir practice').at(1)).dy));
    });

    testWidgets('a desktop cell is at least twice row-height tall; six weeks whatever the month', (tester) async {
      await _pump(tester, _desktop());
      final cell = tester.getSize(find.bySemanticsLabel('Saturday 17 October, no events'));
      expect(cell.height, greaterThanOrEqualTo(2 * MyDataSize.rowHeight));
      final height = tester.getSize(find.byType(MonthGrid)).height;
      // February 2026 fits in four weeks; the grid still shows six and keeps its height.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
      expect(tester.getSize(find.byType(MonthGrid)).height, height);
    });

    testWidgets('under 600px: row-height cells with dots, two dots and "+n" past three', (tester) async {
      await _pump(tester, _phone(), size: const Size(406, 760));
      expect(tester.getSize(find.bySemanticsLabel('Saturday 18 October, no events')).height, MyDataSize.rowHeight);
      expect(find.text('Lunch with Ava'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
      final friday = find.bySemanticsLabel('Friday 24 October, 4 events in Personal, Garden club and Work');
      expect(find.descendant(of: friday, matching: find.byType(DataDot)), findsNWidgets(2));
      final dinner = find.bySemanticsLabel('Friday 17 October, 2 events in Family and Work');
      expect(find.descendant(of: dinner, matching: find.byType(DataDot)), findsNWidgets(2));
      // Not read: no dots even where the source would have events.
      expect(find.descendant(of: find.bySemanticsLabel('Monday 6 October, events not shown'), matching: find.byType(DataDot)),
          findsNothing);
    });

    testWidgets('a day not read shows none of the events it was given', (tester) async {
      await _pump(
          tester,
          _Host(
              month: DateTime(2025, 10),
              today: DateTime(2025, 10, 20),
              selected: DateTime(2025, 10, 20),
              events: {
                DateTime(2025, 10, 6): [_ev('Hidden', 'Work', _work, hour: 9)]
              },
              isNotRead: _beforeOct13of2025));
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('the selected day\'s bars are measured on accent-soft; others on surface', (tester) async {
      await _pump(tester, _desktop());
      final selectedBars = tester.widgetList<DataBar>(find.descendant(
          of: find.bySemanticsLabel('Friday 16 October, 4 events in Work, Personal and Family'),
          matching: find.byType(DataBar)));
      expect(selectedBars.map((b) => b.ground).toSet(), {DataGround.accentSoft});
      final other = tester.widget<DataBar>(
          find.descendant(of: find.bySemanticsLabel('Monday 5 October, 1 event in Work'), matching: find.byType(DataBar)));
      expect(other.ground, DataGround.surface);
    });
  });

  group('first day of the week', () {
    testWidgets('given', (tester) async {
      await _pump(tester, _desktop(firstDay: DateTime.sunday));
      expect(tester.getTopLeft(find.text('Sun')).dx, lessThan(tester.getTopLeft(find.text('Mon')).dx));
    });

    testWidgets('null takes the device locale\'s', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await _pump(
          tester,
          _Host(
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 10, 13),
              firstDayOfWeek: null));
      expect(tester.getTopLeft(find.text('Mon')).dx, lessThan(tester.getTopLeft(find.text('Sun')).dx));

      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      await _pump(
          tester,
          _Host(
              key: const ValueKey('us'),
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 10, 13),
              firstDayOfWeek: null));
      expect(tester.getTopLeft(find.text('Sun')).dx, lessThan(tester.getTopLeft(find.text('Mon')).dx));
    });
  });

  group('selection', () {
    testWidgets('pressing a cell selects it without changing the month, also outside the month', (tester) async {
      final log = <String>[];
      await _pump(
          tester,
          _Host(
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 10, 16),
              events: _october2026(),
              log: log));
      await tester.tap(find.bySemanticsLabel('Wednesday 21 October, 1 event in Choir'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Monday 2 November, 1 event in Work'));
      await tester.pumpAndSettle();
      expect(log, ['select 2026-10-21', 'select 2026-11-02']);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('the arrow keys, Page Up and Down, Home and End move the selection', (tester) async {
      final log = <String>[];
      await _pump(
          tester,
          _Host(
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 10, 16),
              autofocus: true,
              log: log));
      Future<void> key(LogicalKeyboardKey k) async {
        await tester.sendKeyEvent(k);
        await tester.pumpAndSettle();
      }

      await key(LogicalKeyboardKey.arrowRight);
      await key(LogicalKeyboardKey.arrowDown);
      await key(LogicalKeyboardKey.arrowLeft);
      await key(LogicalKeyboardKey.arrowUp);
      await key(LogicalKeyboardKey.home);
      await key(LogicalKeyboardKey.end);
      await key(LogicalKeyboardKey.pageDown);
      await key(LogicalKeyboardKey.pageUp);
      expect(log, [
        'select 2026-10-17',
        'select 2026-10-24',
        'select 2026-10-23',
        'select 2026-10-16',
        'select 2026-10-12', // Monday
        'select 2026-10-18', // Sunday
        'select 2026-11-18', 'month 2026-11-01',
        'select 2026-10-18', 'month 2026-10-01',
      ]);
    });

    testWidgets('leaving the six weeks shown changes the month; staying inside them does not', (tester) async {
      final log = <String>[];
      await _pump(
          tester,
          _Host(
              month: DateTime(2026, 10),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 10, 29),
              autofocus: true,
              log: log));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // 5 November: still shown
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // 12 November: past the six weeks
      await tester.pumpAndSettle();
      expect(log, ['select 2026-11-05', 'select 2026-11-12', 'month 2026-11-01']);
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('left and right follow the text direction', (tester) async {
      final log = <String>[];
      await _pump(
          tester,
          Directionality(
              textDirection: TextDirection.rtl,
              child: _Host(
                  month: DateTime(2026, 10),
                  today: DateTime(2026, 10, 13),
                  selected: DateTime(2026, 10, 16),
                  autofocus: true,
                  log: log)));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(log, ['select 2026-10-17']);
    });

    testWidgets('Today, Previous month and Next month', (tester) async {
      final log = <String>[];
      await _pump(
          tester,
          _Host(
              month: DateTime(2026, 1),
              today: DateTime(2026, 10, 13),
              selected: DateTime(2026, 1, 31),
              log: log));
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(log, [
        'select 2026-02-28', 'month 2026-02-01', // the 31st does not exist in February
        'select 2026-01-28', 'month 2026-01-01',
        'select 2026-10-13', 'month 2026-10-01',
      ]);
      expect(find.text('October 2026'), findsOneWidget);
    });

    // February 2026 with Monday first runs from Monday 26 January to Sunday 8 March.
    testWidgets('Page Up from a day of the month before shows the month the selection lands in', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await _pump(tester, _Host(month: DateTime(2026, 2), today: DateTime(2026, 10, 13), selected: DateTime(2026, 2, 10), log: log));
      await tester.tap(find.bySemanticsLabel('Monday 26 January, no events'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(log, ['select 2026-01-26', 'select 2025-12-26', 'month 2025-12-01']);
      expect(find.text('December 2025'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Friday 26 December, no events')),
          isSemantics(isSelected: true, isFocused: true));
      // And forwards from a day of the month after.
      await tester.tap(find.bySemanticsLabel('Friday 2 January, no events'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(log.skip(3), ['select 2026-01-02', 'select 2026-02-02', 'month 2026-02-01']);
      expect(find.text('February 2026'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Next and Previous month from a day of the month after keep the selection in the month shown',
        (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await _pump(tester, _Host(month: DateTime(2026, 2), today: DateTime(2026, 10, 13), selected: DateTime(2026, 3, 8), log: log));
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Sunday 8 March, no events')), isSemantics(isSelected: true));
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(log, [
        'select 2026-03-08', 'month 2026-03-01', // not 8 April, which March's grid does not show
        'select 2026-02-08', 'month 2026-02-01',
        'select 2026-01-08', 'month 2026-01-01',
      ]);
      expect(tester.getSemantics(find.bySemanticsLabel('Thursday 8 January, no events')), isSemantics(isSelected: true));
      handle.dispose();
    });

    testWidgets('a screen reader follows the selection: the selected cell is focused while the grid is',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _desktop());
      const friday = 'Friday 16 October, 4 events in Work, Personal and Family';
      const saturday = 'Saturday 17 October, no events';
      // Not focused yet: the selected cell can take focus but does not have it.
      expect(tester.getSemantics(find.bySemanticsLabel(friday)),
          isSemantics(isSelected: true, isFocusable: true, isFocused: false, hasTapAction: true));
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(tester.getSemantics(find.bySemanticsLabel(friday)),
          isSemantics(isSelected: true, isFocusable: true, isFocused: true, hasTapAction: true));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel(saturday)),
          isSemantics(isSelected: true, isFocusable: true, isFocused: true, hasTapAction: true));
      expect(tester.getSemantics(find.bySemanticsLabel(friday)),
          isSemantics(isSelected: false, isFocusable: false, isFocused: false, hasTapAction: true));
      // The month is not a second focused node.
      expect(tester.getSemantics(find.bySemanticsLabel('October 2026').last), isSemantics(isFocused: false));
      // Tabbing on takes the focus away from the cell.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getSemantics(find.bySemanticsLabel(saturday)), isSemantics(isSelected: true, isFocusable: true, isFocused: false, hasTapAction: true));
      handle.dispose();
    });

    testWidgets('the grid is one tab stop after the header buttons', (tester) async {
      await _pump(tester, _desktop());
      bool gridFocused() => FocusManager.instance.primaryFocus?.debugLabel == 'MonthGrid';
      // Today, Previous month, Next month, then the grid.
      for (var i = 0; i < 4; i++) {
        expect(gridFocused(), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(gridFocused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(gridFocused(), isFalse);
    });
  });

  group('text size', () {
    testWidgets('today\'s disc, the number box and the bars grow with the text', (tester) async {
      await _pump(tester, _desktop(), textScale: _largeText);
      final today = find.bySemanticsLabel('Tuesday 13 October, today, 2 events in Family and Choir');
      final digits = find.descendant(of: today, matching: find.text('13'));
      final disc = find.ancestor(of: digits, matching: find.byType(Container)).first;
      final discRect = tester.getRect(disc);
      expect(discRect.width, closeTo(MonthGrid.todayDiameter * _largeText, 0.01));
      expect(discRect.height, discRect.width);
      final digitsRect = tester.getRect(digits);
      expect(discRect.top, lessThanOrEqualTo(digitsRect.top));
      expect(discRect.bottom, greaterThanOrEqualTo(digitsRect.bottom));
      // A bar is as tall as the caption line it marks.
      final title = find.text('Dentist');
      final bar = find.descendant(of: today, matching: find.byType(DataBar)).first;
      expect(tester.getSize(bar).height, closeTo(tester.getSize(title).height, 0.5)); // the text box rounds up
      expect(tester.getSize(bar).height, closeTo(MonthGrid.captionLineHeight(const TextScaler.linear(_largeText)), 0.01));
      // The cell grows to hold them: the 16th's two lines and "+2" are inside it.
      final friday = find.bySemanticsLabel('Friday 16 October, 4 events in Work, Personal and Family');
      final more = find.descendant(of: friday, matching: find.text('+2'));
      expect(tester.getRect(friday).bottom, greaterThanOrEqualTo(tester.getRect(more).bottom));
      expect(tester.takeException(), isNull);
    });

    test('the default size is unchanged: a 28px box and an 18px bar', () {
      expect(MonthGrid.numberBoxSize(TextScaler.noScaling), MonthGrid.todayDiameter);
      expect(MonthGrid.captionLineHeight(TextScaler.noScaling), MyDataType.caption.fontSize! * MyDataType.caption.height!);
    });

    testWidgets('on a phone "+n" stays whole and the title never breaks a word', (tester) async {
      await _pump(tester, _phone(), size: const Size(406, 1000), textScale: _largeText);
      final friday = find.bySemanticsLabel('Friday 24 October, 4 events in Personal, Garden club and Work');
      final more = find.descendant(of: friday, matching: find.text('+2'));
      final cell = tester.getRect(friday);
      final moreRect = tester.getRect(more);
      expect(cell.contains(moreRect.topLeft) && cell.contains(moreRect.bottomRight - const Offset(0.01, 0.01)), isTrue);
      final paragraph = tester.renderObject<RenderParagraph>(more);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01));
      // "October 2025" does not fit beside the buttons as one word: it takes its own line above them.
      final titleRect = tester.getRect(find.text('October 2025'));
      final todayRect = tester.getRect(find.text('Today'));
      expect(titleRect.bottom, lessThanOrEqualTo(todayRect.top));
      final titleLine = const TextScaler.linear(_largeText).scale(MyDataType.title.fontSize!) * MyDataType.title.height!;
      expect(titleRect.height, closeTo(titleLine, 0.5)); // one line, so no word broken
      expect(tester.takeException(), isNull);
    });

    testWidgets('at the default size a long title wraps between words beside the buttons', (tester) async {
      await _pump(
          tester,
          _Host(month: DateTime(2026, 9), today: DateTime(2026, 10, 13), selected: DateTime(2026, 9, 30), width: 358),
          size: const Size(406, 600));
      final titleRect = tester.getRect(find.text('September 2026'));
      final todayRect = tester.getRect(find.text('Today'));
      expect(titleRect.right, lessThanOrEqualTo(todayRect.left));
      expect(titleRect.height, greaterThan(MyDataType.title.fontSize! * MyDataType.title.height! * 1.5));
    });
  });

  group('motion', () {
    for (final reduced in [false, true]) {
      testWidgets('changing the month fades the days in place${reduced ? ' (reduced motion)' : ''}', (tester) async {
        tester.view.physicalSize = const Size(1000, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(themedFrame(themeMatrix.first, _desktop(), reduceMotion: reduced));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next month'));
        await tester.pump();
        await tester.pump(MyDataMotion.fast ~/ 2);
        final fades = find.descendant(of: find.byType(AnimatedSwitcher), matching: find.byType(FadeTransition));
        expect(fades, findsNWidgets(2));
        expect(find.descendant(of: find.byType(AnimatedSwitcher), matching: find.byType(SlideTransition)), findsNothing);
        await tester.pump(MyDataMotion.fast);
        await tester.pumpAndSettle();
        expect(fades, findsOneWidget);
        expect(find.text('November 2026'), findsOneWidget);
      });
    }
  });

  group('goldens', () {
    // The desktop preview: today the 13th, the 16th selected with four events, the mouse over the 14th.
    goldenMatrix('month_grid', _desktop, size: const Size(928, 840), before: (tester) async {
      await _hover(tester, 'Wednesday 14 October, 1 event in Work');
    });

    // Selected and today, with keyboard focus: the accent disc, the ink ring and the focus ring inside it.
    goldenMatrix(
        'month_grid_focus', () => _desktop(selected: DateTime(2026, 10, 13), autofocus: true),
        size: const Size(928, 840), before: (tester) async {
      _keyboardFocus(tester);
    });

    // A week that starts on Sunday; selected outside the month (an ink number) in the bottom-start corner,
    // the ring following the group's corner; the mouse over the selected day (the ring only, no hover edge).
    goldenMatrix('month_grid_outside', () => _desktop(selected: DateTime(2026, 11, 1), firstDay: DateTime.sunday),
        size: const Size(928, 840), before: (tester) async {
      await _hover(tester, 'Sunday 1 November, no events');
    });

    // A long month name on a phone wraps rather than being cut short.
    goldenMatrix(
        'month_grid_phone_long_month',
        () => _Host(
            month: DateTime(2026, 9),
            today: DateTime(2026, 10, 13),
            selected: DateTime(2026, 9, 30),
            events: {
              DateTime(2026, 9, 30): [_ev('Rent', 'Personal', _personal, allDay: true)]
            },
            width: 358),
        size: const Size(406, 520));

    // Days not read, with the Notice: today not read, selected and not read, the mouse over a day not read.
    goldenMatrix('month_grid_not_read', _notRead, size: const Size(928, 920), before: (tester) async {
      await _hover(tester, 'Tuesday 7 October, events not shown');
    });

    // Under 600px: dots, the Notice, days not read, a selected day with two dots and "+2".
    goldenMatrix('month_grid_phone', _phone, size: const Size(406, 680));

    // The largest text size: today's number inside a larger disc, bars as tall as their text, cells grown.
    goldenMatrix('month_grid_large_text', () => _scaled(_largeText, _desktop()), size: const Size(928, 1160));

    // The largest text size on a phone: the title on its own line, "+2" whole under its two dots.
    goldenMatrix('month_grid_phone_large_text', () => _scaled(_largeText, _phone()), size: const Size(406, 980));
  });
}
