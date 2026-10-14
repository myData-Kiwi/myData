import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// What a form's holder (a Dialog, an Inspector) and its fields do together: fields are read-only while the
// holder waits for the host (FormBusy), and typing a field holds is committed before the holder saves,
// confirms or leaves (FormCommit).

final _today = DateTime(2026, 10, 14);

/// Every kind of field, keeping its own values, as a form would.
class _Fields extends StatefulWidget {
  const _Fields({required this.values});
  final _Values values;

  @override
  State<_Fields> createState() => _FieldsState();
}

class _Values {
  final name = TextEditingController(text: 'Book club');
  bool shared = false;
  bool allDay = false;
  String calendar = 'home';
  List<String> groups = ['Family'];
  DateTime date = DateTime(2026, 10, 16);
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
}

class _FieldsState extends State<_Fields> {
  _Values get v => widget.values;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyDataTextField(label: 'Name', controller: v.name),
        MyDataCheckbox(label: 'Shared', value: v.shared, onChanged: (x) => setState(() => v.shared = x)),
        FormSwitchRow(title: 'All-day', value: v.allDay, onChanged: (x) => setState(() => v.allDay = x)),
        MyDataSelect<String>(
          label: 'Calendar',
          items: const [SelectItem(value: 'home', title: 'Home'), SelectItem(value: 'work', title: 'Work')],
          value: v.calendar,
          onChanged: (x) => setState(() => v.calendar = x),
        ),
        TokenField(label: 'Groups', values: v.groups, onChanged: (x) => setState(() => v.groups = x)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DatePicker(
              label: 'Starts', value: v.date, today: _today, onChanged: (x) => setState(() => v.date = x)),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TimePicker(
            label: 'Time',
            semanticLabel: 'Start time',
            value: v.time,
            use24HourFormat: true,
            onChanged: (x) => setState(() => v.time = x),
          ),
        ),
      ]);
}

Future<void> _desktop(WidgetTester tester, {Size size = const Size(1000, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

EditableText _editable(WidgetTester tester, Finder of) =>
    tester.widget<EditableText>(find.descendant(of: of, matching: find.byType(EditableText)));

/// Tries every field while the holder waits, and checks nothing changed.
Future<void> _tryEveryField(WidgetTester tester, _Values v) async {
  for (final f in [find.byType(MyDataTextField), find.byType(TokenField), find.byType(DatePicker), find.byType(TimePicker)]) {
    expect(_editable(tester, f).readOnly, isTrue, reason: '${f.describeMatch(Plurality.one)} is read-only');
  }
  await tester.tap(find.text('Shared'));
  await tester.tap(find.text('All-day'));
  await tester.tap(find.text('Home'));
  await tester.pump();
  expect(find.text('Work'), findsNothing, reason: 'the Select does not open');
  // Arrow keys in a date or time field do not step it.
  await tester.tap(find.byType(DatePicker));
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.tap(find.byType(TimePicker));
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  // Backspace in the token field does not take a token.
  await tester.tap(find.byType(TokenField));
  await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
  await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
  await tester.pump();
  expect(v.shared, isFalse);
  expect(v.allDay, isFalse);
  expect(v.calendar, 'home');
  expect(v.groups, ['Family']);
  expect(v.date, DateTime(2026, 10, 16));
  expect(v.time, const TimeOfDay(hour: 9, minute: 0));
  expect(v.name.text, 'Book club');
}

void main() {
  group('FormBusy: fields are read-only while the holder waits for the host', () {
    testWidgets('in a Dialog that is working', (tester) async {
      await _desktop(tester);
      final v = _Values();
      final answer = Completer<String?>();
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => Button(
            label: 'Open',
            onPressed: () => showMyDataDialog(
              context: context,
              builder: (_) => MyDataDialog(
                title: 'New calendar',
                fields: [_Fields(values: v)],
                confirmLabel: 'Create calendar',
                workingLabel: 'Creating…',
                onConfirm: () => answer.future,
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create calendar'));
      await tester.pump();
      expect(find.text('Creating…'), findsOneWidget);
      await _tryEveryField(tester, v);
      answer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('in an Inspector that is saving', (tester) async {
      await _desktop(tester);
      final v = _Values();
      final answer = Completer<String?>();
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 400,
          height: 850,
          child: Inspector(
            title: 'Edit event',
            form: _Fields(values: v),
            changed: true,
            discardMessage: 'Your changes to Book club are not saved.',
            savingAnnouncement: 'Saving Book club',
            onSave: () => answer.future,
            onClosed: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Inspector.saveLabel));
      await tester.pump();
      expect(find.text(Inspector.savingLabel), findsOneWidget);
      await _tryEveryField(tester, v);
      answer.complete(null);
      await tester.pumpAndSettle();
    });
  });

  group('Return in a date or time field inside a Dialog', () {
    Future<List<DateTime>> openDateDialog(WidgetTester tester, {required List<bool> answers}) async {
      final confirmed = <DateTime>[];
      var date = DateTime(2026, 10, 16);
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => Button(
            label: 'Open',
            onPressed: () async => answers.add(await showMyDataDialog(
              context: context,
              builder: (_) => StatefulBuilder(
                builder: (context, setState) => MyDataDialog(
                  title: 'Ends',
                  fields: [
                    DatePicker(
                        label: 'Ends on',
                        value: date,
                        today: _today,
                        order: DateFieldOrder.dayMonthYear,
                        onChanged: (d) => setState(() => date = d)),
                  ],
                  confirmLabel: 'Done',
                  cancelLabel: 'Cancel',
                  onConfirm: () async {
                    confirmed.add(date);
                    return null;
                  },
                  workingLabel: 'Saving…',
                ),
              ),
            )),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return confirmed;
    }

    testWidgets('typed text is committed first: the dialog confirms with the typed date', (tester) async {
      await _desktop(tester);
      final answers = <bool>[];
      final confirmed = await openDateDialog(tester, answers: answers);
      await tester.enterText(find.byType(EditableText), '20/11/2026');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(confirmed, [DateTime(2026, 11, 20)]);
      expect(answers, [true]);
    });

    testWidgets('typed text that is not a date stops the confirm with its error', (tester) async {
      await _desktop(tester);
      final answers = <bool>[];
      final confirmed = await openDateDialog(tester, answers: answers);
      await tester.enterText(find.byType(EditableText), '31/9/2026');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(confirmed, isEmpty);
      expect(find.textContaining('That is not a date'), findsOneWidget);
      expect(find.text('Ends'), findsOneWidget, reason: 'the dialog stays');
    });

    testWidgets('with the calendar open, Return closes it and does not confirm', (tester) async {
      await _desktop(tester);
      final answers = <bool>[];
      final confirmed = await openDateDialog(tester, answers: answers);
      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();
      expect(find.text(DatePicker.nextMonthLabel), findsNothing, reason: 'tooltips only');
      expect(find.byKey(const ValueKey('date-picker-day-20261016')), findsOneWidget, reason: 'the calendar is open');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('date-picker-day-20261016')), findsNothing);
      expect(confirmed, isEmpty);
      expect(find.text('Ends'), findsOneWidget);
      // The next Return confirms.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(confirmed, [DateTime(2026, 10, 16)]);
    });

    testWidgets('a TimePicker: the typed time is committed, then the dialog confirms', (tester) async {
      await _desktop(tester);
      final confirmed = <TimeOfDay>[];
      var time = const TimeOfDay(hour: 9, minute: 0);
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => Button(
            label: 'Open',
            onPressed: () => showMyDataDialog(
              context: context,
              builder: (_) => StatefulBuilder(
                builder: (context, setState) => MyDataDialog(
                  title: 'Remind me',
                  fields: [
                    TimePicker(
                        label: 'At',
                        semanticLabel: 'Time',
                        value: time,
                        use24HourFormat: true,
                        onChanged: (t) => setState(() => time = t)),
                  ],
                  confirmLabel: 'Done',
                  onConfirm: () async {
                    confirmed.add(time);
                    return null;
                  },
                  workingLabel: 'Saving…',
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '10:30');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(confirmed, [const TimeOfDay(hour: 10, minute: 30)]);
    });

    testWidgets('pressing the confirming button commits a token still being typed', (tester) async {
      await _desktop(tester);
      final confirmed = <List<String>>[];
      var groups = <String>['Family'];
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => Button(
            label: 'Open',
            onPressed: () => showMyDataDialog(
              context: context,
              builder: (_) => StatefulBuilder(
                builder: (context, setState) => MyDataDialog(
                  title: 'Add to group',
                  fields: [TokenField(label: 'Groups', values: groups, onChanged: (g) => setState(() => groups = g))],
                  confirmLabel: 'Add',
                  onConfirm: () async {
                    confirmed.add(groups);
                    return null;
                  },
                  workingLabel: 'Adding…',
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Book club');
      // A pointer press: focus stays in the field, so only the commit can make the token.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(confirmed, [
        ['Family', 'Book club'],
      ]);
    });
  });

  group('the Inspector commits typing before it saves or leaves', () {
    Widget holder({required List<TimeOfDay> saved, required List<bool> closes, TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0)}) {
      var time = initial;
      var groups = <String>[];
      return SizedBox(
        width: 400,
        height: 600,
        child: StatefulBuilder(
          builder: (context, setState) => Inspector(
            title: 'Edit event',
            form: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TimePicker(
                  label: 'Starts',
                  semanticLabel: 'Start time',
                  value: time,
                  use24HourFormat: true,
                  onChanged: (t) => setState(() => time = t)),
              const SizedBox(height: MyDataSpace.s4),
              TokenField(label: 'Groups', values: groups, onChanged: (g) => setState(() => groups = g)),
            ]),
            changed: time != initial || groups.isNotEmpty,
            discardMessage: 'Your changes to Book club are not saved.',
            savingAnnouncement: 'Saving Book club',
            onSave: () async {
              saved.add(time);
              return null;
            },
            onClosed: closes.add,
          ),
        ),
      );
    }

    testWidgets('⌘S in the middle of typing a time saves the typed time', (tester) async {
      await _desktop(tester);
      final saved = <TimeOfDay>[], closes = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, holder(saved: saved, closes: closes)));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(TimePicker), matching: find.byType(EditableText)), '10:30');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(saved, [const TimeOfDay(hour: 10, minute: 30)]);
      expect(closes, [true]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('⌘Return with a token still being typed saves it', (tester) async {
      await _desktop(tester);
      final saved = <TimeOfDay>[], closes = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, holder(saved: saved, closes: closes)));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(TokenField), matching: find.byType(EditableText)), 'Book club');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(saved, hasLength(1), reason: 'the new token is a change, so it saves');
      expect(closes, [true]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('typing that is wrong stops the save, with the error and focus on the field', (tester) async {
      await _desktop(tester);
      final saved = <TimeOfDay>[], closes = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, holder(saved: saved, closes: closes)));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(TimePicker), matching: find.byType(EditableText)), '25:99');
      await tester.tap(find.text(Inspector.saveLabel));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(closes, isEmpty);
      expect(find.text(TimePicker.notATimeError), findsOneWidget);
      expect(_editable(tester, find.byType(TimePicker)).focusNode.hasFocus, isTrue);
    });

    testWidgets('Cancel with typed text asks "Discard changes?" first', (tester) async {
      await _desktop(tester);
      final saved = <TimeOfDay>[], closes = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, holder(saved: saved, closes: closes)));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(TimePicker), matching: find.byType(EditableText)), '10:30');
      await tester.tap(find.text(Inspector.cancelLabel));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      expect(closes, isEmpty);
    });
  });

  group('picker sheets on a phone keep typing', () {
    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Widget timeField(List<TimeOfDay> changes) => StatefulBuilder(
          builder: (context, setState) => TimePicker(
            label: 'Starts',
            semanticLabel: 'Start time',
            value: changes.isEmpty ? const TimeOfDay(hour: 9, minute: 0) : changes.last,
            use24HourFormat: true,
            onChanged: (t) => setState(() => changes.add(t)),
          ),
        );

    testWidgets('the time sheet is the Sheet component: typed text makes the scrim ask', (tester) async {
      await phone(tester);
      final changes = <TimeOfDay>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, timeField(changes)));
      await tester.tap(find.byType(TimePicker));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byType(Sheet), matching: find.byType(EditableText)), '21:30');
      await tester.pump();
      await tester.tapAt(const Offset(195, 10));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget, reason: 'typing is never lost silently');
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TimePicker.doneLabel));
      await tester.pumpAndSettle();
      expect(changes, [const TimeOfDay(hour: 21, minute: 30)]);
      expect(find.byType(Sheet), findsNothing);
    });

    testWidgets('a drag down with typed text resists at space-8 and asks', (tester) async {
      await phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, timeField([])));
      await tester.tap(find.byType(TimePicker));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(Sheet), matching: find.byType(EditableText)), '21:30');
      await tester.pump();
      final title = find.descendant(of: find.byType(Sheet), matching: find.text('Start time'));
      final top = tester.getTopLeft(title).dy;
      final drag = await tester.startGesture(tester.getCenter(title));
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(0, 30));
      }
      await tester.pump();
      expect(tester.getTopLeft(title).dy - top, lessThanOrEqualTo(Sheet.resistance + 0.5));
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
    });

    testWidgets('a Select custom label typed in its sheet is pending too', (tester) async {
      await phone(tester);
      String? custom;
      await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        MyDataSelect<String>(
          label: 'Label for phone 1',
          items: const [SelectItem(value: 'Mobile', title: 'Mobile')],
          value: 'Mobile',
          onChanged: (_) {},
          onCustomLabel: (t) => custom = t,
        ),
      ));
      await tester.tap(find.text('Mobile'));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsOneWidget);
      await tester.tap(find.text('Custom label…'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(Sheet), matching: find.byType(EditableText)), 'Boat');
      await tester.pump();
      await tester.tap(find.text(Sheet.cancelLabel));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Sheet.doneLabel));
      await tester.pumpAndSettle();
      expect(custom, 'Boat');
    });
  });
}
