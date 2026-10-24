import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

final _today = DateTime(2026, 10, 14);

/// Holds the date the way a form does.
class _Host extends StatefulWidget {
  const _Host({
    this.initial,
    this.earliest,
    this.order = DateFieldOrder.dayMonthYear,
    this.onChanged,
    this.onError,
    this.disabledReason,
    this.semanticLabel,
  });
  final DateTime? initial;
  final DateTime? earliest;
  final DateFieldOrder order;
  final ValueChanged<DateTime>? onChanged;
  final ValueChanged<String?>? onError;
  final String? disabledReason;
  final String? semanticLabel;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime? value = widget.initial;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        DatePicker(
          label: 'Ends',
          semanticLabel: widget.semanticLabel,
          value: value,
          today: _today,
          earliest: widget.earliest,
          order: widget.order,
          firstDayOfWeek: DateTime.monday,
          disabledReason: widget.disabledReason,
          onErrorChanged: widget.onError,
          onChanged: (d) {
            widget.onChanged?.call(d);
            setState(() => value = d);
          },
        ),
        const SizedBox(height: MyDataSpace.s4),
        // Somewhere else for focus to go.
        Button(label: 'Save', onPressed: () {}),
      ]);
}

class _BirthdayHost extends StatefulWidget {
  const _BirthdayHost({this.initial, this.onChanged});
  final Birthday? initial;
  final ValueChanged<Birthday>? onChanged;

  @override
  State<_BirthdayHost> createState() => _BirthdayHostState();
}

class _BirthdayHostState extends State<_BirthdayHost> {
  late Birthday? value = widget.initial;

  @override
  Widget build(BuildContext context) => DatePicker.birthday(
        value: value,
        today: _today,
        order: DateFieldOrder.dayMonthYear,
        firstDayOfWeek: DateTime.monday,
        onChanged: (b) {
          widget.onChanged?.call(b);
          setState(() => value = b);
        },
      );
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(800, 700)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
}

Future<void> _optionDown(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester) => _key(tester, LogicalKeyboardKey.tab);

/// Goldens draw text fields as on a Mac (no touch selection handles), whatever the test platform.
Widget _mac(Widget child) =>
    Builder(builder: (context) => Theme(data: Theme.of(context).copyWith(platform: TargetPlatform.macOS), child: child));

Finder _day(int y, int m, int d) => find.byKey(ValueKey('date-picker-day-${y * 10000 + m * 100 + d}'));

String _errorText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .firstWhere((s) => s.startsWith('That is') || s.contains('or later.'), orElse: () => '');

void main() {
  group('goldens', () {
    goldenMatrix(
      'date_picker_field_states',
      () => _mac(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: MyDataSpace.s6, runSpacing: MyDataSpace.s4, children: [
          DatePicker(label: 'Starts', value: DateTime(2026, 10, 14), today: _today, onChanged: (_) {}),
          DatePicker(label: 'Ends', value: DateTime(2026, 10, 16), today: _today, onChanged: (_) {}),
          DatePicker(
              key: const ValueKey('typed'),
              label: 'Ends',
              value: DateTime(2026, 10, 16),
              today: _today,
              onChanged: (_) {}),
          DatePicker(
              label: 'Starts',
              value: DateTime(2026, 10, 14),
              today: _today,
              disabledReason: 'Events organised by someone else cannot be moved yet.',
              onChanged: (_) {}),
          DatePicker.birthday(value: const Birthday(month: 5, day: 12), today: _today, onChanged: (_) {}),
          DatePicker.birthday(value: const Birthday(year: 1990, month: 5, day: 12), today: _today, onChanged: (_) {}),
        ]),
      ])),
      size: const Size(720, 420),
      before: (tester) async {
        // The third field holds text that is not a date, committed by leaving it ("Error"); then keyboard
        // focus goes back to the second field ("Focused").
        await tester.enterText(
            find.descendant(of: find.byKey(const ValueKey('typed')), matching: find.byType(EditableText)), '9/31/2026');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      },
    );

    goldenMatrix(
      'date_picker_error_focus',
      // The form's error for an end that the start has moved past: the date shown is before the one named.
      () => _mac(DatePicker(
          label: 'Ends',
          value: DateTime(2026, 10, 12),
          today: _today,
          error: 'Ends before it starts. Choose 14 Oct 2026 or later.',
          onChanged: (_) {})),
      size: const Size(600, 180),
      before: (tester) async => tester.sendKeyEvent(LogicalKeyboardKey.tab),
    );

    // The popover open from the keyboard: today (14), the selected day (16) with the focus ring, days before
    // the earliest date (13 October) unavailable, and the pointer over 22 October. In Graphite dark the hover
    // edge sits beside the selection, to be checked on a real screen (DatePicker README).
    goldenMatrix(
      'date_picker_popover',
      () => _mac(_Host(initial: DateTime(2026, 10, 16), earliest: DateTime(2026, 10, 13))),
      size: const Size(600, 512),
      before: (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(_day(2026, 10, 22)));
        addTearDown(mouse.removePointer);
      },
    );

    goldenMatrix(
      'date_picker_birthday_popover',
      () => _mac(const _BirthdayHost(initial: Birthday(month: 2, day: 29))),
      size: const Size(600, 512),
      before: (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      },
    );
  });

  group('reading and writing dates', () {
    ({int? year, int month, int day})? parse(String s,
            {DateFieldOrder order = DateFieldOrder.dayMonthYear, int? defaultYear, bool yearOptional = false}) =>
        parseTypedDate(s, order: order, today: _today, defaultYear: defaultYear, yearOptional: yearOptional);

    test('the medium form, the full form and the numeric example', () {
      expect(formatPickerDate(DateTime(2026, 10, 14)), 'Wed 14 Oct 2026');
      expect(formatPickerDateNoWeekday(DateTime(2026, 10, 14)), '14 Oct 2026');
      expect(spokenPickerDate(DateTime(2026, 10, 14)), 'Wednesday 14 October 2026');
      expect(spokenPickerDate(DateTime(2028, 5, 12), noYear: true), '12 May');
      expect(numericPickerDate(DateTime(2026, 10, 14), DateFieldOrder.dayMonthYear), '14/10/2026');
      expect(numericPickerDate(DateTime(2026, 10, 14), DateFieldOrder.monthDayYear), '10/14/2026');
      expect(numericPickerDate(DateTime(2026, 10, 14), DateFieldOrder.yearMonthDay), '2026/10/14');
    });

    test('the locale decides the numeric order', () {
      expect(DateFieldOrder.of(const Locale('en', 'GB')), DateFieldOrder.dayMonthYear);
      expect(DateFieldOrder.of(const Locale('en', 'NZ')), DateFieldOrder.dayMonthYear);
      expect(DateFieldOrder.of(const Locale('en', 'US')), DateFieldOrder.monthDayYear);
      expect(DateFieldOrder.of(const Locale('ja', 'JP')), DateFieldOrder.yearMonthDay);
      expect(DateFieldOrder.of(const Locale('en')), DateFieldOrder.dayMonthYear);
    });

    test('numbers in the locale order, with any separator', () {
      expect(parse('14/10/2026'), (year: 2026, month: 10, day: 14));
      expect(parse('14.10.2026'), (year: 2026, month: 10, day: 14));
      expect(parse('14-10-2026'), (year: 2026, month: 10, day: 14));
      expect(parse('14 10 2026'), (year: 2026, month: 10, day: 14));
      expect(parse('10/14/2026', order: DateFieldOrder.monthDayYear), (year: 2026, month: 10, day: 14));
      expect(parse('2026-10-14', order: DateFieldOrder.yearMonthDay), (year: 2026, month: 10, day: 14));
      // In the UK, 10/14 is not a date.
      expect(parse('10/14/2026'), isNull);
    });

    test('month words, short forms, weekdays and ordinals', () {
      expect(parse('14 Oct 2026'), (year: 2026, month: 10, day: 14));
      expect(parse('14 october', defaultYear: 2027), (year: 2027, month: 10, day: 14));
      expect(parse('Oct 14 2026'), (year: 2026, month: 10, day: 14));
      expect(parse('3 nov'), (year: 2026, month: 11, day: 3));
      expect(parse('Wed 14 Oct 2026'), (year: 2026, month: 10, day: 14));
      expect(parse('Wednesday, 14th October'), (year: 2026, month: 10, day: 14));
      expect(parse('14 sept 2026'), (year: 2026, month: 9, day: 14));
    });

    test('a two-digit year is in the century nearest to today', () {
      expect(parse('14/10/26'), (year: 2026, month: 10, day: 14));
      expect(parse('1/1/80'), (year: 1980, month: 1, day: 1));
      expect(parse('1/1/70'), (year: 2070, month: 1, day: 1));
    });

    test('no year takes the earlier date’s year, or none for a birthday', () {
      expect(parse('20/10', defaultYear: 2030), (year: 2030, month: 10, day: 20));
      expect(parse('20/10'), (year: 2026, month: 10, day: 20));
      expect(parse('12 May', yearOptional: true), (year: null, month: 5, day: 12));
      expect(parse('29 Feb', yearOptional: true), (year: null, month: 2, day: 29));
      expect(parse('29 Feb 2027'), isNull);
    });

    test('text that is not a date', () {
      for (final s in ['', 'tomorrow', '31/2/2026', '14/13/2026', '14', '14 Oct Nov', '1/2/3/4', '14/10/202']) {
        expect(parse(s), isNull, reason: s);
      }
    });

    test('a birthday reads and writes the host’s form, with or without a year', () {
      expect(Birthday.parse('1990-05-12'), const Birthday(year: 1990, month: 5, day: 12));
      expect(Birthday.parse('--05-12'), const Birthday(month: 5, day: 12));
      expect(Birthday.parse('--0229'), const Birthday(month: 2, day: 29));
      expect(Birthday.parse('1990-02-30'), isNull);
      expect(const Birthday(month: 5, day: 12).toHostString(), '--05-12');
      expect(const Birthday(year: 1990, month: 5, day: 12).toHostString(), '1990-05-12');
      expect(const Birthday(year: 1990, month: 5, day: 12).format(), '12 May 1990');
      expect(const Birthday(month: 5, day: 12).format(), '12 May');
    });
  });

  group('the field', () {
    testWidgets('shows the medium date and is named, with its hint', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), semanticLabel: 'End date'));
      expect(find.text('Wed 14 Oct 2026'), findsOneWidget);
      expect(find.text('Ends'), findsOneWidget);
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, contains('End date'));
      expect(node.hint, contains('press Up or Down arrow to change it by a day'));
      handle.dispose();
    });

    testWidgets('Tab reaches the field without opening; Up and Down step a day and announce it', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility,
          (m) async {
        announced.add((m as Map)['data']['message'] as String);
        return null;
      });
      addTearDown(() =>
          tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      expect(find.text('October 2026'), findsNothing);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(changes, [DateTime(2026, 10, 15), DateTime(2026, 10, 16), DateTime(2026, 10, 15)]);
      expect(find.text('Thu 15 Oct 2026'), findsOneWidget);
      expect(announced, contains('Thursday 15 October 2026'));
    });

    testWidgets('Down stops at the earliest date', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), earliest: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(changes, isEmpty);
    });

    testWidgets('typing commits on Return and rewrites the text in the medium form', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await tester.enterText(find.byType(TextField), '20/10');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(changes, [DateTime(2026, 10, 20)]);
      expect(find.text('Tue 20 Oct 2026'), findsOneWidget);
    });

    testWidgets('leaving the field commits the typing', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await tester.enterText(find.byType(TextField), '3 nov');
      await _tab(tester);
      expect(changes, [DateTime(2026, 11, 3)]);
      expect(find.text('Tue 3 Nov 2026'), findsOneWidget);
    });

    testWidgets('text that is not a date is an error with an example in the locale order', (tester) async {
      final errors = <String?>[];
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 16), onError: errors.add, onChanged: changes.add));
      await tester.enterText(find.byType(TextField), 'next friday');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_errorText(tester), 'That is not a date. Type it like 16/10/2026.');
      expect(errors, ['That is not a date. Type it like 16/10/2026.']);
      expect(changes, isEmpty, reason: 'the form keeps its last good date');
      // The US order in the example.
      await _pump(tester, _Host(initial: DateTime(2026, 10, 16), order: DateFieldOrder.monthDayYear));
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_errorText(tester), 'That is not a date. Type it like 10/16/2026.');
    });

    testWidgets('a date before the earliest says why and gives the first date allowed', (tester) async {
      await _pump(tester, _Host(initial: DateTime(2026, 10, 16), earliest: DateTime(2026, 10, 14)));
      await tester.enterText(find.byType(TextField), '12/10/2026');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_errorText(tester), 'Ends before it starts. Choose 14 Oct 2026 or later.');
    });

    testWidgets('the error goes once a good date is committed', (tester) async {
      final errors = <String?>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 16), onError: errors.add));
      await tester.enterText(find.byType(TextField), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '17/10/2026');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(errors, [isNotNull, isNull]);
      expect(_errorText(tester), '');
    });

    testWidgets('Escape puts back the date from before the typing', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await tester.enterText(find.byType(TextField), '20/10');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('Wed 14 Oct 2026'), findsOneWidget);
      await _tab(tester);
      expect(changes, isEmpty);
    });

    testWidgets('disabled: faded, not focusable, the reason as its help', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), disabledReason: 'The host cannot be reached.'));
      expect(find.text('The host cannot be reached.'), findsOneWidget);
      await _tab(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isFalse);
      expect(tester.getSemantics(find.byType(EditableText)), isSemantics(isEnabled: false));
      // The reason is not faded with the field.
      final reason = find.text('The host cannot be reached.');
      expect(find.ancestor(of: reason, matching: find.byType(Opacity)), findsNothing);
      handle.dispose();
    });
  });

  group('the popover', () {
    testWidgets('Option-Down opens it with focus on the field’s date; focus does not pick', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      await _optionDown(tester);
      expect(find.text('October 2026'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(changes, isEmpty);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, [DateTime(2026, 10, 22)]);
      expect(find.text('October 2026'), findsNothing, reason: 'a pick closes the popover');
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasPrimaryFocus, isTrue);
    });

    testWidgets('Page Up and Down move a month, with Shift a year; Home and End to the week’s ends', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.pageDown);
      expect(find.text('November 2026'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.pageDown, shift: true);
      expect(find.text('November 2027'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.pageUp, shift: true);
      await _key(tester, LogicalKeyboardKey.pageUp);
      expect(find.text('October 2026'), findsOneWidget);
      // Wednesday 14 October: End goes to Sunday 18 (weeks start on Monday).
      await _key(tester, LogicalKeyboardKey.end);
      await _key(tester, LogicalKeyboardKey.space);
      expect(changes, [DateTime(2026, 10, 18)]);
    });

    testWidgets('the previous and next buttons show the month before and after', (tester) async {
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('Escape closes it with no change and returns focus to the field', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('October 2026'), findsNothing);
      expect(changes, isEmpty);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab stays inside the popover until it closes', (tester) async {
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
      await _tab(tester);
      await _optionDown(tester);
      for (var i = 0; i < 5; i++) {
        await _tab(tester);
        expect(find.text('October 2026'), findsOneWidget);
        final focused = FocusManager.instance.primaryFocus!;
        expect(focused.debugLabel == 'DatePicker calendar' || focused.context!.widget is! TextField, isTrue);
      }
    });

    testWidgets('clicking the field opens it with the caret in the text; typing moves it', (tester) async {
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasPrimaryFocus, isTrue);
      await tester.enterText(find.byType(TextField), '3/12/2026');
      await tester.pumpAndSettle();
      expect(find.text('December 2026'), findsOneWidget);
    });

    testWidgets('pressing a day picks it and closes', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(_day(2026, 10, 27));
      await tester.pumpAndSettle();
      expect(changes, [DateTime(2026, 10, 27)]);
      expect(find.text('October 2026'), findsNothing);
    });

    testWidgets('a click outside closes it and commits the typing', (tester) async {
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '21/10/2026');
      await tester.tapAt(const Offset(780, 680));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsNothing);
      expect(changes, [DateTime(2026, 10, 21)]);
    });

    testWidgets('days before the earliest are reached but cannot be picked', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <DateTime>[];
      await _pump(tester, _Host(initial: DateTime(2026, 10, 14), earliest: DateTime(2026, 10, 14), onChanged: changes.add));
      await _tab(tester);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, isEmpty);
      expect(find.text('October 2026'), findsOneWidget);
      expect(tester.getSemantics(_day(2026, 10, 13)).label, 'Tuesday 13 October 2026, unavailable');
      await tester.tap(_day(2026, 10, 13));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      handle.dispose();
    });

    testWidgets('days are named by their full date, with today and selected', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Host(initial: DateTime(2026, 10, 16)));
      await _tab(tester);
      await _optionDown(tester);
      expect(tester.getSemantics(_day(2026, 10, 14)).label, 'Wednesday 14 October 2026, today');
      expect(tester.getSemantics(_day(2026, 10, 16)).label, 'Friday 16 October 2026, selected');
      expect(find.bySemanticsLabel('Ends, choose a date'), findsOneWidget);
      handle.dispose();
    });
  });

  group('birthday', () {
    testWidgets('no year: the field shows the day and month, and typing keeps no year', (tester) async {
      final changes = <Birthday>[];
      await _pump(tester, _BirthdayHost(initial: const Birthday(year: 1990, month: 5, day: 12), onChanged: changes.add));
      expect(find.text('12 May 1990'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '3 June');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(changes, [const Birthday(month: 6, day: 3)]);
      expect(find.text('3 June'), findsOneWidget);
    });

    testWidgets('the popover has Month and Year lists; No year lays out a leap year', (tester) async {
      final changes = <Birthday>[];
      await _pump(tester, _BirthdayHost(initial: const Birthday(month: 2, day: 10), onChanged: changes.add));
      await _tab(tester);
      await _optionDown(tester);
      expect(find.text('February'), findsOneWidget);
      expect(find.text('No year'), findsOneWidget);
      // 2028 is the next leap year: 29 February is there.
      expect(_day(2028, 2, 29), findsOneWidget);
      await tester.tap(_day(2028, 2, 29));
      await tester.pumpAndSettle();
      expect(changes, [const Birthday(month: 2, day: 29)]);
    });

    testWidgets('choosing a year from the Year list', (tester) async {
      final changes = <Birthday>[];
      await _pump(tester, _BirthdayHost(initial: const Birthday(month: 5, day: 12), onChanged: changes.add));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      await tester.tap(_day(2025, 5, 12));
      await tester.pumpAndSettle();
      expect(changes, [const Birthday(year: 2025, month: 5, day: 12)]);
    });
  });

  testWidgets('phone: tapping the field opens the calendar in a sheet; a day picks and closes', (tester) async {
    final changes = <DateTime>[];
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add), size: const Size(390, 800));
    expect(find.byType(TextField), findsNothing, reason: 'not typed on a phone');
    await tester.tap(find.text('Wed 14 Oct 2026'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(tester.widget<Sheet>(find.byType(Sheet)).kind, SheetKind.picker);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(_day(2026, 10, 20));
    await tester.pumpAndSettle();
    expect(changes, [DateTime(2026, 10, 20)]);
    expect(find.text('October 2026'), findsNothing);
  });

  testWidgets('phone, with a keyboard: focus starts on the day; Return picks and closes; Escape is Cancel',
      (tester) async {
    final changes = <DateTime>[];
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14), onChanged: changes.add), size: const Size(390, 800));
    await tester.tap(find.text('Wed 14 Oct 2026'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [DateTime(2026, 10, 15)]);
    expect(find.byType(Sheet), findsNothing);
    await tester.tap(find.text('Thu 15 Oct 2026'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Sheet), findsNothing);
    expect(changes, [DateTime(2026, 10, 15)]);
  });

  testWidgets('the month buttons are IconButtons: the tooltip shows at once on keyboard focus', (tester) async {
    await _pump(tester, _Host(initial: DateTime(2026, 10, 14)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _optionDown(tester);
    final buttons = tester.widgetList<MyDataIconButton>(find.byType(MyDataIconButton)).map((b) => b.label);
    expect(buttons, [DatePicker.previousMonthLabel, DatePicker.nextMonthLabel]);
  });
}
