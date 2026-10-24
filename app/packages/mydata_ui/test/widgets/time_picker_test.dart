import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _t = TimeOfDay.new;

/// Goldens draw text fields as on a Mac (no touch selection handles), whatever the test platform.
Widget _mac(Widget child) =>
    Builder(builder: (context) => Theme(data: Theme.of(context).copyWith(platform: TargetPlatform.macOS), child: child));

class _Host extends StatefulWidget {
  const _Host({this.initial, this.use24 = true, this.start, this.onChanged, this.onDay, this.onError});
  final TimeOfDay? initial;
  final bool use24;
  final TimeOfDay? start;
  final ValueChanged<TimeOfDay>? onChanged;
  final ValueChanged<int>? onDay;
  final ValueChanged<String?>? onError;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late TimeOfDay? value = widget.initial;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TimePicker(
          label: widget.start == null ? 'Starts' : 'Ends',
          semanticLabel: widget.start == null ? 'Start time' : 'End time',
          value: value,
          use24HourFormat: widget.use24,
          start: widget.start,
          onEndDayFromList: widget.onDay,
          onErrorChanged: widget.onError,
          onChanged: (t) {
            widget.onChanged?.call(t);
            setState(() => value = t);
          },
        ),
        const SizedBox(height: MyDataSpace.s4),
        Button(label: 'Save', onPressed: () {}),
      ]);
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(800, 700)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _optionDown(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  group('goldens', () {
    goldenMatrix(
      'time_picker_field_states',
      () => _mac(Wrap(spacing: MyDataSpace.s6, runSpacing: MyDataSpace.s4, children: [
        TimePicker(label: 'Starts', semanticLabel: 'Start time', value: _t(hour: 9, minute: 30), use24HourFormat: true, onChanged: (_) {}),
        TimePicker(label: 'Starts', semanticLabel: 'Start time', value: _t(hour: 21, minute: 30), use24HourFormat: false, onChanged: (_) {}),
        TimePicker(
            label: 'Ends',
            semanticLabel: 'End time',
            value: _t(hour: 9, minute: 0),
            use24HourFormat: true,
            error: TimePicker.notATimeError,
            onChanged: (_) {}),
        TimePicker(
            label: 'Starts',
            semanticLabel: 'Start time',
            value: _t(hour: 14, minute: 0),
            use24HourFormat: true,
            disabledReason: 'Events organised by someone else cannot be moved yet.',
            onChanged: (_) {}),
      ])),
      size: const Size(640, 300),
      // Keyboard focus on the first field.
      before: (tester) async => tester.sendKeyEvent(LogicalKeyboardKey.tab),
    );

    // The end field's list, opened from the keyboard after a 14:00 start, with lengths; the end (15:00) is
    // checked and the highlight moved down one row with the keys.
    goldenMatrix(
      'time_picker_end_list',
      () => _mac(const _Host(initial: TimeOfDay(hour: 15, minute: 0), start: TimeOfDay(hour: 14, minute: 0))),
      size: const Size(600, 480),
      before: (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      },
    );

    Widget when({required bool allDay, required bool zoneDiffers}) => SizedBox(
          width: MyDataSize.inspectorWidth - 2 * MyDataSpace.s5,
          child: EventWhenGroup(
            allDay: allDay,
            // The form Switch row (title at the start, the switch at the end), drawn from its track.
            allDaySwitch: Builder(
                builder: (context) => Row(children: [
                      Expanded(child: Text('All-day', style: MyDataType.body.copyWith(color: context.colors.ink))),
                      SwitchTrack(value: allDay),
                    ])),
            startDate: DatePicker(
                label: 'Starts',
                semanticLabel: 'Start date',
                showLabel: false,
                value: DateTime(2026, 10, 16),
                today: DateTime(2026, 10, 14),
                onChanged: (_) {}),
            startTime: TimePicker(
                label: 'Starts',
                semanticLabel: 'Start time',
                showLabel: false,
                value: const TimeOfDay(hour: 10, minute: 0),
                use24HourFormat: true,
                onChanged: (_) {}),
            endDate: DatePicker(
                label: 'Ends',
                semanticLabel: 'End date',
                showLabel: false,
                value: DateTime(2026, 10, 16),
                today: DateTime(2026, 10, 14),
                onChanged: (_) {}),
            endTime: TimePicker(
                label: 'Ends',
                semanticLabel: 'End time',
                showLabel: false,
                value: const TimeOfDay(hour: 11, minute: 0),
                start: const TimeOfDay(hour: 10, minute: 0),
                use24HourFormat: true,
                onChanged: (_) {}),
            zoneDiffers: zoneDiffers,
            zoneCaption: zoneDiffers ? '15:00 to 16:00 London time' : null,
            onSetTimeZone: () {},
          ),
        );

    goldenMatrix(
      'event_when_group',
      () => _mac(Wrap(spacing: MyDataSpace.s8, runSpacing: MyDataSpace.s6, children: [
        when(allDay: false, zoneDiffers: false),
        when(allDay: false, zoneDiffers: true),
        when(allDay: true, zoneDiffers: false),
      ])),
      size: const Size(1340, 330),
    );
  });

  group('reading times', () {
    TimeOfDay? p(String s, {bool use24 = true, TimeOfDay? after}) =>
        parseTypedTime(s, use24HourFormat: use24, after: after);

    test('the spec table, on a 24-hour and a 12-hour clock', () {
      final table = <String, (TimeOfDay, TimeOfDay)>{
        '9:30': (_t(hour: 9, minute: 30), _t(hour: 9, minute: 30)),
        '9.30': (_t(hour: 9, minute: 30), _t(hour: 9, minute: 30)),
        '09:30': (_t(hour: 9, minute: 30), _t(hour: 9, minute: 30)),
        '930': (_t(hour: 9, minute: 30), _t(hour: 9, minute: 30)),
        '21:30': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '21.30': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '2130': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '9.30pm': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '9:30 PM': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '9:30p': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '930pm': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '9.30 p.m.': (_t(hour: 21, minute: 30), _t(hour: 21, minute: 30)),
        '9': (_t(hour: 9, minute: 0), _t(hour: 9, minute: 0)),
        '9am': (_t(hour: 9, minute: 0), _t(hour: 9, minute: 0)),
        '9 a.m.': (_t(hour: 9, minute: 0), _t(hour: 9, minute: 0)),
        '9pm': (_t(hour: 21, minute: 0), _t(hour: 21, minute: 0)),
        '12am': (_t(hour: 0, minute: 0), _t(hour: 0, minute: 0)),
        '0:00': (_t(hour: 0, minute: 0), _t(hour: 0, minute: 0)),
        '00:00': (_t(hour: 0, minute: 0), _t(hour: 0, minute: 0)),
        '12pm': (_t(hour: 12, minute: 0), _t(hour: 12, minute: 0)),
        '12:00': (_t(hour: 12, minute: 0), _t(hour: 12, minute: 0)),
      };
      for (final e in table.entries) {
        expect(p(e.key), e.value.$1, reason: '${e.key} on a 24-hour clock');
        expect(p(e.key, use24: false), e.value.$2, reason: '${e.key} on a 12-hour clock');
      }
    });

    test('a bare hour in an end field is the first such time after the start (12-hour clock)', () {
      final two = _t(hour: 14, minute: 0);
      expect(p('5', use24: false, after: two), _t(hour: 17, minute: 0));
      expect(p('3:30', use24: false, after: two), _t(hour: 15, minute: 30));
      expect(p('5', use24: true, after: two), _t(hour: 5, minute: 0), reason: 'read as written on a 24-hour clock');
      expect(p('5', use24: false), _t(hour: 5, minute: 0), reason: 'a start field reads it as written');
    });

    test('text that is not a time', () {
      for (final s in ['', '13pm', '0am', '24:00', '9:60', '9:5', '12345', 'noon', '9:30 xm']) {
        expect(p(s), isNull, reason: s);
      }
    });

    test('steps go to the next or previous quarter hour, round midnight', () {
      expect(stepQuarterHour(_t(hour: 9, minute: 37), up: true), _t(hour: 9, minute: 45));
      expect(stepQuarterHour(_t(hour: 9, minute: 37), up: false), _t(hour: 9, minute: 30));
      expect(stepQuarterHour(_t(hour: 9, minute: 30), up: false), _t(hour: 9, minute: 15));
      expect(stepQuarterHour(_t(hour: 23, minute: 45), up: true), _t(hour: 0, minute: 0));
      expect(stepQuarterHour(_t(hour: 0, minute: 0), up: false), _t(hour: 23, minute: 45));
    });

    test('lengths, the list’s rows and the times’ forms', () {
      expect(formatShortDuration(30), '30 min');
      expect(formatShortDuration(60), '1 hr');
      expect(formatShortDuration(105), '1 hr 45 min');
      expect(spokenDuration(60), '1 hour');
      expect(spokenDuration(105), '1 hour 45 minutes');
      expect(TimePicker.rows().length, 96);
      final end = TimePicker.rows(start: _t(hour: 14, minute: 0));
      expect(end.length, 96);
      expect(end.first.time, _t(hour: 14, minute: 15));
      expect(end.last.time, _t(hour: 14, minute: 0));
      expect(formatPickerTime(_t(hour: 9, minute: 30), use24HourFormat: true), '09:30');
      expect(formatPickerTime(_t(hour: 9, minute: 30), use24HourFormat: false), '9:30 am');
      expect(formatPickerTime(_t(hour: 0, minute: 0), use24HourFormat: false), '12:00 am');
    });
  });

  group('the field', () {
    testWidgets('is named Start time, with its hint', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const _Host(initial: TimeOfDay(hour: 9, minute: 30)));
      expect(find.text('09:30'), findsOneWidget);
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, contains('Start time'));
      expect(node.hint, contains('change it by 15 minutes'));
      handle.dispose();
    });

    testWidgets('Up and Down step a quarter hour and announce it', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (m) async {
        announced.add((m as Map)['data']['message'] as String);
        return null;
      });
      addTearDown(() =>
          tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 37), onChanged: changes.add));
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(changes, [_t(hour: 9, minute: 45), _t(hour: 9, minute: 30), _t(hour: 9, minute: 15)]);
      expect(find.text('09:15'), findsOneWidget);
      expect(announced, contains('09:15'));
    });

    testWidgets('typing commits on Return and is rewritten in the locale’s form', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), use24: false, onChanged: changes.add));
      await _type(tester, '930pm');
      expect(changes, [_t(hour: 21, minute: 30)]);
      expect(find.text('9:30 pm'), findsOneWidget);
    });

    testWidgets('text that is not a time is an error; the form keeps its last good time', (tester) async {
      final errors = <String?>[];
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), onChanged: changes.add, onError: errors.add));
      await _type(tester, '13pm');
      expect(find.text(TimePicker.notATimeError), findsOneWidget);
      expect(errors, [TimePicker.notATimeError]);
      expect(changes, isEmpty);
      await _type(tester, '14:15');
      expect(find.text(TimePicker.notATimeError), findsNothing);
      expect(errors.last, isNull);
    });

    testWidgets('Escape puts back the time from before the typing', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), onChanged: changes.add));
      await tester.enterText(find.byType(TextField), '11');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.text('09:00'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(changes, isEmpty);
    });
  });

  group('the list', () {
    testWidgets('Option-Down opens it on the field’s time; the keys move, Return picks and closes', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 30), onChanged: changes.add));
      await _key(tester, LogicalKeyboardKey.tab);
      await _optionDown(tester);
      expect(find.byKey(const ValueKey('picker-row-38')), findsOneWidget); // 09:30
      expect(findIcon(MyDataIcon.check), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, [_t(hour: 9, minute: 45)]);
      expect(find.byKey(const ValueKey('picker-row-38')), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasPrimaryFocus, isTrue);
    });

    testWidgets('screen readers follow the highlighted row: it is the focused one, with its position',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 30)));
      await _key(tester, LogicalKeyboardKey.tab);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      final row = tester.getSemantics(find.byKey(const ValueKey('picker-row-39')));
      expect(row.flagsCollection.isFocused, Tristate.isTrue);
      expect(row.hint, '40 of 96');
      expect(tester.getSemantics(find.byKey(const ValueKey('picker-row-38'))).flagsCollection.isFocused,
          Tristate.isFalse);
      await _key(tester, LogicalKeyboardKey.escape);
      handle.dispose();
    });

    testWidgets('Up stops at the first row; Escape closes with no change', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 0, minute: 0), onChanged: changes.add));
      await _key(tester, LogicalKeyboardKey.tab);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, isEmpty, reason: 'still on 00:00, the current time');
      await _key(tester, LogicalKeyboardKey.tab);
      await _optionDown(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.escape);
      expect(changes, isEmpty);
      expect(find.byKey(const ValueKey('picker-row-0')), findsNothing);
    });

    testWidgets('typing moves the highlight to a time that starts with it', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), onChanged: changes.add));
      await _key(tester, LogicalKeyboardKey.tab);
      await _optionDown(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7, character: '7');
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, [_t(hour: 17, minute: 0)]);
    });

    testWidgets('an end field lists lengths, and a row past midnight moves the end date', (tester) async {
      final handle = tester.ensureSemantics();
      final days = <int>[];
      final changes = <TimeOfDay>[];
      await _pump(tester,
          _Host(initial: _t(hour: 23, minute: 30), start: _t(hour: 22, minute: 0), onChanged: changes.add, onDay: days.add));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('1 hr 30 min'), findsOneWidget);
      expect(tester.getSemantics(find.byKey(const ValueKey('picker-row-3'))).label, '23:00, 1 hour');
      // 23:00 is row 3 (22:15, 22:30, 22:45, 23:00); 00:15 is row 8, past midnight.
      await tester.tap(find.text('00:15'));
      await tester.pumpAndSettle();
      expect(changes, [_t(hour: 0, minute: 15)]);
      expect(days, [1]);
      handle.dispose();
    });

    testWidgets('a click outside closes it and commits the typing', (tester) async {
      final changes = <TimeOfDay>[];
      await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), onChanged: changes.add));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10.15');
      await tester.tapAt(const Offset(780, 680));
      await tester.pumpAndSettle();
      expect(changes, [_t(hour: 10, minute: 15)]);
      expect(find.text('10:15'), findsOneWidget);
    });
  });

  testWidgets('phone: a sheet with Cancel, Done, the field and the quarter hours', (tester) async {
    final changes = <TimeOfDay>[];
    await _pump(tester, _Host(initial: _t(hour: 9, minute: 0), onChanged: changes.add), size: const Size(390, 800));
    await tester.tap(find.text('09:00'));
    await tester.pumpAndSettle();
    expect(find.byType(Sheet), findsOneWidget, reason: 'the Sheet component, as a picker');
    expect(tester.widget<Sheet>(find.byType(Sheet)).kind, SheetKind.picker);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1830');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(changes, [_t(hour: 18, minute: 30)]);
    expect(find.text('Done'), findsNothing);
  });

  group('When group', () {
    Widget group({required bool allDay, required bool zoneDiffers}) => EventWhenGroup(
          allDay: allDay,
          allDaySwitch: const Text('All-day'),
          startDate: const Text('start date'),
          startTime: const Text('start time'),
          endDate: const Text('end date'),
          endTime: const Text('end time'),
          zoneDiffers: zoneDiffers,
          timeZoneField: const Text('zone field'),
          zoneCaption: '15:00 to 16:00 London time',
          onSetTimeZone: () {},
        );

    testWidgets('all-day hides the times and the zone; the dates stay', (tester) async {
      await _pump(tester, group(allDay: true, zoneDiffers: true));
      await tester.pumpAndSettle();
      expect(find.text('start date'), findsOneWidget);
      expect(find.text('start time'), findsNothing);
      expect(find.text('end time'), findsNothing);
      expect(find.text('zone field'), findsNothing);
    });

    testWidgets('the zone shows only when it is not this device’s', (tester) async {
      await _pump(tester, group(allDay: false, zoneDiffers: false));
      expect(find.text('zone field'), findsNothing);
      expect(find.text(EventWhenGroup.setTimeZoneLabel), findsOneWidget);
      await _pump(tester, group(allDay: false, zoneDiffers: true));
      await tester.pumpAndSettle();
      expect(find.text('zone field'), findsOneWidget);
      expect(find.text('15:00 to 16:00 London time'), findsOneWidget);
      expect(find.text(EventWhenGroup.setTimeZoneLabel), findsNothing);
    });

    testWidgets('it is a group named When', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, group(allDay: false, zoneDiffers: false));
      expect(find.bySemanticsLabel('When'), findsOneWidget);
      handle.dispose();
    });
  });
}
