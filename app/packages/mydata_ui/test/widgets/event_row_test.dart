import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented calendars and events, as in design/components/EventRow/preview.html. Today is Tuesday 13 October
// 2026.
final _today = DateTime(2026, 10, 13);
final _grey = parseDataColour('#8E8E93');
final _red = parseDataColour('#E5484D');
final _nearBlack = parseDataColour('#1F1F1F');
final _blue = parseDataColour('#3E7BFA');
final _yellow = parseDataColour('#F5D90A');
final _white = parseDataColour('#FFFFFF');

DateTime _d(int day, [int hour = 0, int minute = 0, int month = 10, int year = 2026]) =>
    DateTime(year, month, day, hour, minute);

final _birthday = EventItem(
  id: 'birthday',
  start: _d(13),
  end: _d(14),
  allDay: true,
  title: 'Sam Sample’s birthday',
  calendarName: 'Birthdays',
  calendarColour: _grey,
  calendarId: 'birthdays',
);
final _dentist = EventItem(
  id: 'dentist',
  start: _d(13, 9, 30),
  end: _d(13, 10, 15),
  title: 'Dentist',
  location: 'Example Dental, 4 Sample Road',
  calendarName: 'Family',
  calendarColour: _red,
  calendarId: 'family',
);
final _choir = EventItem(
  id: 'choir',
  start: _d(13, 18),
  end: _d(13, 19, 30),
  title: 'Choir practice',
  location: 'Example Hall',
  calendarName: 'Choir',
  calendarColour: _nearBlack,
  calendarId: 'choir',
);
final _conference = EventItem(
  id: 'conference',
  start: _d(14),
  end: _d(17),
  allDay: true,
  title: 'Conference in Lisbon',
  calendarName: 'Work',
  calendarColour: _blue,
  calendarId: 'work',
);
final _call = EventItem(
  id: 'call',
  start: _d(14, 15),
  end: _d(14, 16),
  zone: EventZoneTimes(name: zoneCityName('America/New_York')!, start: _d(14, 10), end: _d(14, 11)),
  title: 'Call with the New York office',
  calendarName: 'Work',
  calendarColour: _blue,
  calendarId: 'work',
);
final _train = EventItem(
  id: 'train',
  start: _d(14, 22, 40),
  end: _d(15, 7, 10),
  title: 'Night train to Porto',
  location: 'Example Central',
  calendarName: 'Family',
  calendarColour: _red,
  calendarId: 'family',
);
final _bookClub = EventItem(
  id: 'book-club',
  start: _d(15, 12),
  end: _d(15, 13),
  calendarName: 'Book club',
  calendarId: 'book-club',
);

final _all = [_choir, _dentist, _birthday, _train, _call, _conference, _bookClub];

/// This Mac reads from 13 October 2025: 7 October 2025 is outside its range.
final _mac = EventSourceRange(name: 'this Mac', first: _d(13, 0, 0, 10, 2025), last: _d(13, 0, 0, 10, 2028));

Widget _days(List<DateTime> days, {List<EventItem>? events, List<EventSourceRange>? sources, double width = 560}) =>
    SizedBox(
      width: width,
      child: DayList(
        days: days,
        today: _today,
        events: events ?? _all,
        sources: sources ?? [_mac],
        use24HourFormat: true,
      ),
    );

/// Rows on their own, in the states the spec names that the preview's days do not show.
Widget _states() => SizedBox(
  width: 400,
  child: DayList(
    days: [_d(16)],
    today: _today,
    use24HourFormat: false,
    events: [
      // 12-hour clock, a long title cut at two lines, a long caption that wraps.
      EventItem(
        start: _d(16, 12, 45),
        end: _d(16, 13, 30),
        title: 'Planning lunch for the example street party with the neighbours from numbers 2 to 14',
        location: 'Example Café, 12 Sample Street, Exampleton',
        calendarName: 'Family',
        calendarColour: _red,
      ),
      // A pale colour on surface: the edge.
      EventItem(
        start: _d(16, 9),
        end: _d(16, 9, 30),
        title: 'Garden club',
        calendarName: 'Garden',
        calendarColour: _yellow,
      ),
      // White: the edge in light mode.
      EventItem(
        start: _d(16, 10),
        end: _d(16, 11),
        title: 'Allotment',
        calendarName: 'Allotment',
        calendarColour: _white,
      ),
      // A timed event filling its last day to midnight: "All day" on that day.
      EventItem(start: _d(15, 20), end: _d(17), title: 'Hackathon', calendarName: 'Work', calendarColour: _blue),
      // No colour: line-strong.
      EventItem(start: _d(16, 17), end: _d(16, 17), title: 'Reminder to water plants', calendarName: 'Book club'),
    ],
  ),
);

Future<void> _pump(WidgetTester tester, Widget child, {bool use24 = true, double textScale = 1}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(alwaysUse24HourFormat: use24, textScaler: TextScaler.linear(textScale)),
      child: themedFrame(themeMatrix.first, child),
    ),
  );
}

List<String> _texts(WidgetTester tester, Finder within) =>
    tester.widgetList<Text>(find.descendant(of: within, matching: find.byType(Text))).map((t) => t.data ?? '').toList();

void main() {
  group('times', () {
    test('the 24-hour clock pads the hour', () {
      expect(formatEventTime(_d(13, 9, 5), use24HourFormat: true), '09:05');
      expect(formatEventTime(_d(13, 0, 0), use24HourFormat: true), '00:00');
      expect(formatEventTime(_d(13, 23, 59), use24HourFormat: true), '23:59');
    });

    test('the 12-hour clock writes am and pm, with 12 at noon and midnight', () {
      expect(formatEventTime(_d(13, 9, 30), use24HourFormat: false), '9:30 am');
      expect(formatEventTime(_d(13, 0, 15), use24HourFormat: false), '12:15 am');
      expect(formatEventTime(_d(13, 12, 0), use24HourFormat: false), '12:00 pm');
      expect(formatEventTime(_d(13, 22, 40), use24HourFormat: false), '10:40 pm');
    });

    test('a zone id gives its city, UTC, or an offset', () {
      expect(zoneCityName('America/New_York'), 'New York');
      expect(zoneCityName('America/Argentina/Buenos_Aires'), 'Buenos Aires');
      expect(zoneCityName('Europe/Lisbon'), 'Lisbon');
      expect(zoneCityName('UTC'), 'UTC');
      expect(zoneCityName('Etc/UTC'), 'UTC');
      expect(zoneCityName('Etc/GMT+5'), 'UTC−5');
      expect(zoneCityName('Etc/GMT-10'), 'UTC+10');
      expect(zoneCityName('Etc/GMT+0'), 'UTC');
      expect(zoneCityName('Etc/Greenwich'), 'UTC');
      expect(zoneCityName('/mozilla.org/20050126_1/America/New_York'), 'New York');
      expect(zoneCityName('America/Port-au-Prince'), 'Port-au-Prince');
    });

    test('a zone name that is not an IANA id gives no name, so no caption', () {
      // The host passes a calendar's own TZID through when it has no IANA key (Outlook, Exchange).
      expect(zoneCityName('Pacific Standard Time'), isNull);
      expect(zoneCityName('W. Europe Standard Time'), isNull);
      expect(zoneCityName('(UTC+01:00) Amsterdam, Berlin, Bern, Rome'), isNull);
      expect(zoneCityName('GMT +0100 (Standard) / GMT +0200 (Daylight)'), isNull);
      expect(zoneCityName('UTC-08'), isNull);
      expect(zoneCityName('EST'), isNull);
      expect(zoneCityName('Floating'), isNull);
      expect(zoneCityName('Etc/Unknown'), isNull);
      expect(zoneCityName(''), isNull);
    });

    test('the zone caption says "time" after a city only', () {
      EventItem at(String name) => EventItem(
        start: _d(14, 15),
        end: _d(14, 16),
        zone: EventZoneTimes(name: name, start: _d(14, 10), end: _d(14, 11)),
        calendarName: 'Work',
      );
      expect(eventZoneCaption(at('UTC'), use24HourFormat: true), '10:00 to 11:00 UTC');
      expect(eventZoneCaption(at(zoneCityName('Etc/GMT+5')!), use24HourFormat: true), '10:00 to 11:00 UTC−5');
      expect(eventZoneCaption(at('UTC+10'), use24HourFormat: true), '10:00 to 11:00 UTC+10');
      expect(eventZoneCaption(at('Lisbon'), use24HourFormat: true), '10:00 to 11:00 Lisbon time');
      // A name passed in as written is not given a second "time".
      expect(
        eventZoneCaption(at('Pacific Standard Time'), use24HourFormat: true),
        '10:00 to 11:00 Pacific Standard Time',
      );
      expect(eventZoneCaption(at('  '), use24HourFormat: true), isNull);
    });

    test('the zone caption shows the event’s own times only when its clock differs', () {
      expect(eventZoneCaption(_call, use24HourFormat: true), '10:00 to 11:00 New York time');
      expect(eventZoneCaption(_call, use24HourFormat: false), '10:00 am to 11:00 am New York time');
      final sameClock = EventItem(
        start: _d(14, 15),
        end: _d(14, 16),
        zone: EventZoneTimes(name: 'Paris', start: _d(14, 15), end: _d(14, 16)),
        calendarName: 'Work',
      );
      expect(eventZoneCaption(sameClock, use24HourFormat: true), isNull);
      expect(eventZoneCaption(_dentist, use24HourFormat: true), isNull);
      // An all-day event is a date with no zone, and never gains one.
      final allDay = EventItem(
        start: _d(14),
        end: _d(15),
        allDay: true,
        zone: EventZoneTimes(name: 'New York', start: _d(13, 18), end: _d(14, 18)),
        calendarName: 'Work',
      );
      expect(eventZoneCaption(allDay, use24HourFormat: true), isNull);
    });
  });

  group('days', () {
    test('a timed event on one day', () {
      expect(eventDays(_dentist), [_d(13)]);
      expect(eventDayOf(_dentist, _d(13, 23)), (day: 1, count: 1));
      expect(eventDayOf(_dentist, _d(14)), isNull);
    });

    test('an overnight event falls on both days', () {
      expect(eventDays(_train), [_d(14), _d(15)]);
      expect(eventDayOf(_train, _d(15)), (day: 2, count: 2));
    });

    test('an end at midnight does not reach into the next day', () {
      final late = EventItem(start: _d(13, 22), end: _d(14), calendarName: 'Family');
      expect(eventDays(late), [_d(13)]);
      expect(eventWhen(late, _d(13), use24HourFormat: true), (time: '22:00', under: '00:00'));
    });

    test('an all-day event covers its dates, the end being the day after', () {
      expect(eventDays(_birthday), [_d(13)]);
      expect(eventDays(_conference), [_d(14), _d(15), _d(16)]);
      final bad = EventItem(start: _d(14), end: _d(14), allDay: true, calendarName: 'Work');
      expect(eventDays(bad), [_d(14)]);
    });

    test('a month and a year boundary', () {
      final newYear = EventItem(
        start: _d(31, 0, 0, 12, 2026),
        end: _d(2, 0, 0, 1, 2027),
        allDay: true,
        calendarName: 'Family',
      );
      expect(eventDays(newYear), [_d(31, 0, 0, 12, 2026), _d(1, 0, 0, 1, 2027)]);
    });

    test('when: start over end, Starts, Ends and All day', () {
      String? s(EventItem e, DateTime day) {
        final w = eventWhen(e, day, use24HourFormat: true);
        return w == null ? null : '${w.time}/${w.under}';
      }

      expect(s(_dentist, _d(13)), '09:30/10:15');
      expect(s(_birthday, _d(13)), 'All day/null');
      expect(s(_train, _d(14)), '22:40/Starts');
      expect(s(_train, _d(15)), '07:10/Ends');
      for (final day in [14, 15, 16]) {
        expect(s(_conference, _d(day)), 'All day/null');
      }
      final threeNights = EventItem(start: _d(14, 20), end: _d(16, 9), calendarName: 'Work');
      expect(s(threeNights, _d(15)), 'All day/null');
      final toMidnight = EventItem(start: _d(14, 20), end: _d(16), calendarName: 'Work');
      expect(s(toMidnight, _d(15)), 'All day/null');
      final zeroLength = EventItem(start: _d(13, 17), end: _d(13, 17), calendarName: 'Work');
      expect(s(zeroLength, _d(13)), '17:00/null');
      expect(s(_dentist, _d(14)), isNull);
    });

    test('the when column’s accessible text', () {
      expect(EventRow.whenLabel((time: '09:30', under: '10:15')), '09:30 to 10:15');
      expect(EventRow.whenLabel((time: '22:40', under: 'Starts')), 'Starts 22:40');
      expect(EventRow.whenLabel((time: '07:10', under: 'Ends')), 'Ends 07:10');
      expect(EventRow.whenLabel((time: 'All day', under: null)), 'All day');
    });

    test('the caption: zone times, day of, location, then always the calendar', () {
      expect(eventCaption(_dentist, _d(13), use24HourFormat: true), 'Example Dental, 4 Sample Road · Family');
      expect(eventCaption(_choir, _d(13), use24HourFormat: true), 'Example Hall · Choir');
      expect(eventCaption(_birthday, _d(13), use24HourFormat: true), 'Birthdays');
      expect(eventCaption(_conference, _d(15), use24HourFormat: true), 'Day 2 of 3 · Work');
      expect(eventCaption(_call, _d(14), use24HourFormat: true), '10:00 to 11:00 New York time · Work');
      expect(eventCaption(_train, _d(14), use24HourFormat: true), 'Day 1 of 2 · Example Central · Family');
      final spaces = EventItem(start: _d(13, 9), end: _d(13, 10), location: '  ', calendarName: 'Family');
      expect(eventCaption(spaces, _d(13), use24HourFormat: true), 'Family');
      expect(dayOfLabel(2, 3), 'Day 2 of 3');
    });

    test('day headings: today, this year, another year', () {
      expect(formatDayHeading(_d(13), today: _today), 'Today, Tuesday 13 October');
      expect(formatDayHeading(_d(14), today: _today), 'Wednesday 14 October');
      expect(formatDayHeading(_d(7, 0, 0, 10, 2025), today: _today), 'Tuesday 7 October 2025');
      expect(formatDayHeading(_d(13, 0, 0, 10, 2027), today: _today), 'Wednesday 13 October 2027');
    });

    test('a day’s order: all day first, then by start, then by end; ties keep their order', () {
      expect(eventsOnDay(_all, _d(13)), [_birthday, _dentist, _choir]);
      expect(eventsOnDay([_train, _call, _conference], _d(14)), [_conference, _call, _train]);
      // The end of an overnight event counts from the start of the day: it comes before 12:00.
      expect(eventsOnDay([_bookClub, _conference, _train], _d(15)), [_conference, _train, _bookClub]);
      final a = EventItem(id: 'a', start: _d(13, 9), end: _d(13, 10), calendarName: 'Work');
      final b = EventItem(id: 'b', start: _d(13, 9), end: _d(13, 9, 30), calendarName: 'Work');
      final c = EventItem(id: 'c', start: _d(13, 9), end: _d(13, 10), calendarName: 'Family');
      expect(eventsOnDay([a, b, c], _d(13)).map((e) => e.id), ['b', 'a', 'c']);
    });

    test('a source’s range', () {
      expect(_mac.reads(_d(13, 0, 0, 10, 2025)), isTrue);
      expect(_mac.reads(_d(12, 23, 59, 10, 2025)), isFalse);
      expect(_mac.reads(_d(13, 23, 0, 10, 2028)), isTrue);
      expect(_mac.reads(_d(14, 0, 0, 10, 2028)), isFalse);
      expect(const EventSourceRange(name: 'the iCloud account you@example.com').reads(_d(1, 0, 0, 1, 1990)), isTrue);
      expect(const EventSourceRange.nothing(name: 'this Mac').reads(_today), isFalse);
    });
  });

  group('EventRow', () {
    testWidgets('shows the when column, the bar, the title and the caption', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
      );
      expect(_texts(tester, find.byType(EventRow)), [
        '09:30',
        '10:15',
        'Dentist',
        'Example Dental, 4 Sample Road · Family',
      ]);
      final bar = tester.widget<DataBar>(find.byType(DataBar));
      expect(bar.colour, _red);
      expect(bar.ground, DataGround.surface);
    });

    testWidgets('it is at least row-height tall, and the bar is as tall as the text beside it', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
      );
      expect(tester.getSize(find.byType(EventRow)).height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      final barBox = tester.getRect(find.byType(DataBar));
      final title = tester.getRect(find.text('Dentist'));
      final caption = tester.getRect(find.text('Example Dental, 4 Sample Road · Family'));
      expect(barBox.top, title.top);
      expect(barBox.bottom, caption.bottom);
      expect(barBox.width, DataBar.width(kiwiLook));
    });

    testWidgets('the when column has a fixed width, so titles line up', (tester) async {
      await _pump(tester, _days([_d(13), _d(14)]));
      final lefts = {
        for (final t in [
          'Sam Sample’s birthday',
          'Dentist',
          'Choir practice',
          'Conference in Lisbon',
          'Night train to Porto',
        ])
          tester.getTopLeft(find.text(t)).dx,
      };
      expect(lefts, hasLength(1));
      expect(
        tester.getTopLeft(find.text('Dentist')).dx - tester.getTopLeft(find.text('09:30')).dx,
        EventRow.whenWidth(kiwiLook) + GroupedRow.gap(kiwiLook) + DataBar.width(kiwiLook) + GroupedRow.gap(kiwiLook),
      );
    });

    testWidgets('the when column grows with the text size', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
        textScale: 1.5,
      );
      expect(
        tester.getTopLeft(find.text('Dentist')).dx - tester.getTopLeft(find.text('09:30')).dx,
        EventRow.whenWidth(kiwiLook) * 1.5 + GroupedRow.gap(kiwiLook) + DataBar.width(kiwiLook) + GroupedRow.gap(kiwiLook),
      );
    });

    testWidgets('no title shows "No title" in ink-muted; a title is ink, two lines at most', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _bookClub, day: _d(15), use24HourFormat: true),
        ),
      );
      final c = MyDataColors.light;
      final none = tester.widget<Text>(find.text(EventRow.noTitle));
      expect(none.style!.color, c.inkMuted);
      expect(none.style!.fontWeight, MyDataType.bodyStrong.fontWeight);
      expect(find.text('Book club'), findsOneWidget);
      expect(tester.widget<DataBar>(find.byType(DataBar)).colour, isNull);

      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
      );
      final title = tester.widget<Text>(find.text('Dentist'));
      expect(title.style!.color, c.ink);
      expect(title.maxLines, EventRow.titleMaxLines);
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a long title is cut at two lines', (tester) async {
      final long = EventItem(
        start: _d(13, 9),
        end: _d(13, 10),
        title: List.filled(30, 'Example').join(' '),
        calendarName: 'Family',
      );
      await _pump(
        tester,
        SizedBox(
          width: 360,
          child: EventRow(event: long, day: _d(13), use24HourFormat: true),
        ),
      );
      final lineHeight = MyDataType.bodyStrong.fontSize! * MyDataType.bodyStrong.height!;
      expect(tester.getSize(find.text(long.title)).height, closeTo(lineHeight * 2, 0.5));
    });

    testWidgets('the clock follows the device unless given', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13)),
        ),
        use24: false,
      );
      expect(find.text('9:30 am'), findsOneWidget);
      expect(find.text('10:15 am'), findsOneWidget);
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13)),
        ),
        use24: true,
      );
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('on a 12-hour clock the column widens so every time stays on one line', (tester) async {
      final late = EventItem(start: _d(13, 22), end: _d(13, 23), title: 'Late call', calendarName: 'Work');
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: late, day: _d(13), use24HourFormat: false),
        ),
      );
      final lineHeight = MyDataType.body.fontSize! * MyDataType.body.height!;
      expect(tester.getSize(find.text('10:00 pm')).height, closeTo(lineHeight, 0.01));
      final width = EventRow.whenColumnWidth(kiwiLook, use24HourFormat: false, textScaler: TextScaler.noScaling);
      expect(width, greaterThan(EventRow.whenWidth(kiwiLook)));
      expect(EventRow.whenColumnWidth(kiwiLook, use24HourFormat: true, textScaler: TextScaler.noScaling), EventRow.whenWidth(kiwiLook));
      expect(
        tester.getTopLeft(find.text('Late call')).dx - tester.getTopLeft(find.text('10:00 pm')).dx,
        width + GroupedRow.gap(kiwiLook) + DataBar.width(kiwiLook) + GroupedRow.gap(kiwiLook),
      );
    });

    testWidgets('it is read as one node, the times first', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _train, day: _d(14), use24HourFormat: true),
        ),
      );
      final node = tester.getSemantics(find.text('Night train to Porto'));
      expect(node.label, 'Starts 22:40\nNight train to Porto\nDay 1 of 2 · Example Central · Family');
      expect(node.flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('it is not pressable and not a Tab stop', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
      );
      expect(find.descendant(of: find.byType(EventRow), matching: find.byType(Pressable)), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      final inRow =
          focused?.context != null &&
          find
              .descendant(of: find.byType(EventRow), matching: find.byWidget(focused!.context!.widget))
              .evaluate()
              .isNotEmpty;
      expect(inRow, isFalse);
    });

    testWidgets('its text can be selected with the pointer', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: EventRow(event: _dentist, day: _d(13), use24HourFormat: true),
        ),
      );
      expect(find.descendant(of: find.byType(EventRow), matching: find.byType(SelectionArea)), findsOneWidget);
      // Drag across the title, then copy what is selected.
      final title = tester.getRect(find.text('Dentist'));
      final gesture = await tester.startGesture(title.centerLeft + const Offset(1, 0), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(title.centerRight + const Offset(4, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      Actions.invoke(tester.element(find.text('Dentist')), CopySelectionTextIntent.copy);
      await tester.pump();
      expect(clipboard, 'Dentist');
    });
  });

  group('DayList', () {
    testWidgets('one group per day, headed by the date; today starts "Today, "', (tester) async {
      await _pump(tester, _days([_d(13), _d(14), _d(7, 0, 0, 10, 2025)]));
      expect(find.text('Today, Tuesday 13 October'), findsOneWidget);
      expect(find.text('Wednesday 14 October'), findsOneWidget);
      expect(find.text('Tuesday 7 October 2025'), findsOneWidget);
      final heading = tester.widget<Text>(find.text('Wednesday 14 October'));
      expect(heading.style!.fontSize, MyDataType.label.fontSize);
      expect(
        tester.getTopLeft(find.text('Wednesday 14 October')).dy,
        greaterThan(tester.getTopLeft(find.text('Today, Tuesday 13 October')).dy),
      );
    });

    testWidgets('all day first, then by start; an event over several days on each of its days', (tester) async {
      await _pump(tester, _days([_d(13), _d(14), _d(15), _d(16)]));
      List<double> ys(List<String> titles) => [for (final t in titles) tester.getTopLeft(find.text(t).first).dy];
      final today = ys(['Sam Sample’s birthday', 'Dentist', 'Choir practice']);
      expect(today, orderedEquals([...today]..sort()));
      expect(find.text('Conference in Lisbon'), findsNWidgets(3));
      expect(find.text('Night train to Porto'), findsNWidgets(2));
      expect(find.text('Day 3 of 3 · Work'), findsOneWidget);
      expect(find.text('Starts'), findsOneWidget);
      expect(find.text('Ends'), findsOneWidget);
      expect(find.text('10:00 to 11:00 New York time · Work'), findsOneWidget);
    });

    testWidgets('events in hidden calendars are left out', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 560,
          child: DayList(
            days: [_d(13)],
            today: _today,
            events: _all,
            hiddenCalendarIds: const {'family'},
            use24HourFormat: true,
          ),
        ),
      );
      expect(find.text('Dentist'), findsNothing);
      expect(find.text('Choir practice'), findsOneWidget);
    });

    testWidgets('"No events" only when every source reads the day', (tester) async {
      await _pump(tester, _days([_d(17)]));
      expect(find.text(DayList.noEvents), findsOneWidget);
      expect(tester.widget<Text>(find.text(DayList.noEvents)).style!.color, MyDataColors.light.inkMuted);

      await _pump(tester, _days([_d(7, 0, 0, 10, 2025)]));
      expect(find.text(DayList.noEvents), findsNothing);
      expect(find.text('Events from this Mac are not shown for this day.'), findsOneWidget);

      await _pump(tester, _days([_d(17)], sources: [const EventSourceRange.nothing(name: 'this Mac')]));
      expect(find.text(DayList.noEvents), findsNothing);
      expect(find.text(DayList.notShownLine('this Mac')), findsOneWidget);
    });

    testWidgets('a day with events from another source lists them, then the not-shown line', (tester) async {
      final fromICloud = EventItem(
        id: 'icloud',
        start: _d(7, 19, 0, 10, 2025),
        end: _d(7, 20, 0, 10, 2025),
        title: 'Garden club',
        calendarName: 'Garden',
        calendarColour: _yellow,
      );
      await _pump(
        tester,
        _days(
          [_d(7, 0, 0, 10, 2025)],
          events: [fromICloud],
          sources: [
            _mac,
            const EventSourceRange(name: 'the iCloud account you@example.com'),
          ],
        ),
      );
      expect(find.text('Garden club'), findsOneWidget);
      expect(find.text(DayList.noEvents), findsNothing);
      expect(
        tester.getTopLeft(find.text(DayList.notShownLine('this Mac'))).dy,
        greaterThan(tester.getTopLeft(find.text('Garden club')).dy),
      );
      // The iCloud account reads every day: it never adds a line.
      expect(find.textContaining('iCloud account'), findsNothing);
    });

    testWidgets('one selection area for the whole list, so a selection can run across rows', (tester) async {
      await _pump(tester, _days([_d(13), _d(14)]));
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });

  goldenMatrix('event_row_days', () => _days([_d(13), _d(14)]), size: const Size(608, 470));
  goldenMatrix(
    'event_row_days_more',
    () => _days(
      [_d(15), _d(17), _d(7, 0, 0, 10, 2025), _d(8, 0, 0, 10, 2025)],
      events: [
        ..._all,
        EventItem(
          start: _d(8, 19, 0, 10, 2025),
          end: _d(8, 20, 0, 10, 2025),
          title: 'Garden club',
          calendarName: 'Garden',
          calendarColour: _yellow,
        ),
      ],
      sources: [
        _mac,
        const EventSourceRange(name: 'the iCloud account you@example.com'),
      ],
    ),
    size: const Size(608, 680),
  );
  goldenMatrix('event_row_states', _states, size: const Size(448, 400));
}
