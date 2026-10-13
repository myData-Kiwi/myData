import 'package:flutter_test/flutter_test.dart';
import 'package:mycalendar/src/calendar_model.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

CoverageOut macWindow(String a, String b, {bool complete = false}) => CoverageOut(
  accountId: macId,
  source_: CoverageOutSource_Enum.mac,
  coveredStart: a,
  coveredEnd: b,
  complete: complete,
);

CoverageOut macNothing(CoverageOutReasonEnum reason) =>
    CoverageOut(accountId: macId, source_: CoverageOutSource_Enum.mac, complete: false, reason: reason);

void main() {
  group('sources in a sentence', () {
    test('This Mac and an iCloud account, as the Notice writes them', () {
      expect(sourceInSentence(CoverageOutSource_Enum.mac), 'this Mac');
      expect(sourceInSentence(CoverageOutSource_Enum.icloud, email: 'you@example.com'),
          'the iCloud account you@example.com');
      expect(sourceInSentence(CoverageOutSource_Enum.icloud, heading: 'iCloud account you@example.com'),
          'the iCloud account you@example.com');
    });
  });

  group('notices', () {
    final first = DateTime(2025, 9, 29), last = DateTime(2025, 11, 9);

    test('a window that covers the days on screen needs none', () {
      final s = SourceCoverage(coverage: macWindow('2025-10-13', '2028-10-13', complete: true), name: 'this Mac');
      expect(s.notice(DateTime(2026, 9, 28), DateTime(2026, 11, 8)), isNull);
    });

    test('a window that covers part of them gives the range', () {
      final s = SourceCoverage(coverage: macWindow('2025-10-13', '2028-10-13'), name: 'this Mac');
      expect(
        s.notice(first, last),
        const NoticeSpec(
          'myData reads events from this Mac between 13 October 2025 and 13 October 2028.',
          NoticeTone.info,
        ),
      );
    });

    test('a month wholly outside the window says so', () {
      final s = SourceCoverage(coverage: macWindow('2025-10-13', '2028-10-13'), name: 'this Mac');
      expect(
        s.notice(DateTime(2024, 12, 30), DateTime(2025, 2, 9))!.message,
        'myData reads events from this Mac between 13 October 2025 and 13 October 2028. '
        'This month is outside that range.',
      );
    });

    test('not read yet, not allowed yet and refused', () {
      SourceCoverage mac(CoverageOutReasonEnum r, String status) =>
          SourceCoverage(coverage: macNothing(r), name: 'this Mac', calendarsStatus: status);
      expect(
        mac(CoverageOutReasonEnum.notReadYet, 'fullAccess').notice(first, last),
        const NoticeSpec(
          'myData has not read the events from this Mac yet. They appear here when it has.',
          NoticeTone.info,
        ),
      );
      expect(
        mac(CoverageOutReasonEnum.notReadYet, 'notDetermined').notice(first, last),
        const NoticeSpec(
          'myData is not allowed to read this Mac’s calendars. Allow it in myData, under Settings, Sources.',
          NoticeTone.warning,
          NoticeAction.openMyData,
        ),
      );
      expect(
        mac(CoverageOutReasonEnum.noAccess, 'denied').notice(first, last),
        const NoticeSpec(
          'myData is not allowed to read this Mac’s calendars. Turn on myData in System Settings, '
          'under Privacy & Security, Calendars.',
          NoticeTone.warning,
          NoticeAction.openSystemSettings,
        ),
      );
    });

    test('an iCloud account, read in full, never needs one', () {
      final s = SourceCoverage(
        coverage: CoverageOut(accountId: icloudId, source_: CoverageOutSource_Enum.icloud, complete: true),
        name: 'the iCloud account $icloudEmail',
      );
      expect(s.notice(first, last), isNull);
      expect(s.range.reads(DateTime(1990, 1, 1)), isTrue);
    });

    test('the range reads the window, both ends included', () {
      final r = SourceCoverage(coverage: macWindow('2025-10-13', '2028-10-13'), name: 'this Mac').range;
      expect(r.reads(DateTime(2025, 10, 12)), isFalse);
      expect(r.reads(DateTime(2025, 10, 13)), isTrue);
      expect(r.reads(DateTime(2028, 10, 13)), isTrue);
      expect(r.reads(DateTime(2028, 10, 14)), isFalse);
    });
  });

  group('which sources count', () {
    test('a source counts while it has a shown calendar, or none known yet', () {
      bool visible(String id) => id != 'm-work';
      expect(sourceCounts(macId, macCalendars, visible), isTrue);
      expect(sourceCounts(macId, [macCalendars[2]], visible), isFalse);
      expect(sourceCounts(macId, const [], visible), isTrue);
    });
  });

  group('events', () {
    test('a timed event moves into this device’s zone; an all-day event keeps its dates', () {
      final t = eventItemOf(timed('m-work', 'Team planning', iso(2026, 10, 5, 9), iso(2026, 10, 5, 10)), macCalendars[2]);
      expect(t.start, DateTime(2026, 10, 5, 9));
      expect(t.end, DateTime(2026, 10, 5, 10));
      expect(t.calendarName, 'Work');
      expect(t.calendarColour, parseDataColour('#3E7BFA'));

      final a = eventItemOf(allDay('m-work', 'Conference', '2026-10-14', '2026-10-17'), macCalendars[2]);
      expect(a.allDay, isTrue);
      expect(a.start, DateTime(2026, 10, 14));
      expect(a.end, DateTime(2026, 10, 17));
      expect(eventDays(a), [DateTime(2026, 10, 14), DateTime(2026, 10, 15), DateTime(2026, 10, 16)]);
    });

    test('a time written in another zone’s offset moves into this device’s zone, across local midnight', () {
      // 23:00 to 01:30 on this device, written as the host would for an event set in India (+05:30) and in
      // UTC: the wall-clock digits differ from this device's, so the offset must be applied.
      final localStart = DateTime(2026, 10, 16, 23), localEnd = DateTime(2026, 10, 17, 1, 30);
      for (final offset in [const Duration(hours: 5, minutes: 30), Duration.zero, const Duration(hours: -10)]) {
        final e = timed('m-work', 'Late call', isoAt(localStart, offset), isoAt(localEnd, offset));
        final t = eventItemOf(e, macCalendars[2]);
        expect(t.start, localStart, reason: e.start);
        expect(t.end, localEnd, reason: e.end);
        expect(t.start.isUtc, isFalse);
        expect(eventDays(t), [DateTime(2026, 10, 16), DateTime(2026, 10, 17)], reason: e.start);
      }
      final z = timed('m-work', 'Standup', isoAt(DateTime(2026, 3, 9, 9), Duration.zero, utcZ: true),
          isoAt(DateTime(2026, 3, 9, 9, 15), Duration.zero, utcZ: true));
      expect(z.start, endsWith('Z'));
      expect(eventItemOf(z, macCalendars[2]).start, DateTime(2026, 3, 9, 9));
    });

    test('a calendar with no colour, or unknown, still has a name', () {
      final e = eventItemOf(timed('m-book', '', iso(2026, 10, 19, 20), iso(2026, 10, 19, 21)), macCalendars[6]);
      expect(e.calendarColour, isNull);
      expect(e.calendarName, 'Book club');
      final unknown = eventItemOf(timed('gone', 'x', iso(2026, 10, 19, 20), iso(2026, 10, 19, 21)), null);
      expect(unknown.calendarName, MonthPageText.unknownCalendar);
    });

    test('an event in another zone gets that zone’s clock in its caption', () {
      final e = timed('m-work', 'Call', iso(2026, 10, 16, 15), iso(2026, 10, 16, 16), zone: 'America/New_York');
      final req = zoneRequestOf(e)!;
      expect(req.$1, 'America/New_York');
      final local = DateTime(2026, 10, 16, 15).timeZoneOffset;
      final z = zoneTimesOf(req.$1, req.$2, req.$3, local - const Duration(hours: 5), local - const Duration(hours: 5))!;
      final item = eventItemOf(e, macCalendars[2], zone: z);
      expect(eventZoneCaption(item, use24HourFormat: true), '10:00 to 11:00 New York time');
    });

    test('no zone request for all-day events or zones with no IANA name', () {
      expect(zoneRequestOf(allDay('m-work', 'x', '2026-10-14', '2026-10-15')), isNull);
      expect(zoneRequestOf(timed('m-work', 'x', iso(2026, 1, 1, 9), iso(2026, 1, 1, 10), zone: 'Pacific Standard Time')),
          isNull);
      expect(zoneRequestOf(timed('m-work', 'x', iso(2026, 1, 1, 9), iso(2026, 1, 1, 10))), isNull);
    });
  });

  group('calendar data', () {
    test('a month is read once and again after a refresh', () async {
      final backend = FakeBackend();
      final data = CalendarData(backend: backend, zones: const FakeZones());
      await data.refresh();
      expect(data.ready, isTrue);
      expect(data.anySourceOn, isTrue);
      final first = DateTime(2026, 9, 27), last = DateTime(2026, 11, 7);
      await data.ensure(first, last);
      await data.ensure(first, last);
      expect(backend.eventCalls, hasLength(1));
      expect(data.eventsFor(first, last)!.events, isNotEmpty);
      await data.refresh();
      expect(data.eventsFor(first, last), isNotNull, reason: 'kept on screen until read again');
      await data.ensure(first, last);
      expect(backend.eventCalls, hasLength(2));
      data.dispose();
    });

    test('a month that fails is asked for once, says why, and is asked again after a refresh', () async {
      final backend = FakeBackend()..eventsError = ApiException(500, 'Internal Server Error');
      final data = CalendarData(backend: backend, zones: const FakeZones());
      await data.refresh();
      final first = DateTime(2026, 9, 27), last = DateTime(2026, 11, 7);
      await data.ensure(first, last);
      await data.ensure(first, last);
      await data.ensure(first, last);
      expect(backend.eventCalls, hasLength(1));
      expect(data.eventsFor(first, last), isNull);
      expect(data.failureFor(first, last), 'The host answered with an error (500).');
      expect(data.error, isNull, reason: 'the calendars were read');

      backend.eventsError = StateError('not connected to the host');
      await data.refresh();
      expect(data.failureFor(first, last), isNull, reason: 'may be asked once more');
      await data.ensure(first, last);
      expect(backend.eventCalls, hasLength(2));
      expect(data.failureFor(first, last), 'The host could not be reached.');

      backend.eventsError = null;
      await data.refresh();
      await data.ensure(first, last);
      expect(data.failureFor(first, last), isNull);
      expect(data.eventsFor(first, last)!.events, isNotEmpty);
      data.dispose();
    });

    test('one event with a broken time is left out; the rest of the month shows', () async {
      final backend = FakeBackend(macEvents: [
        timed('m-work', 'Broken', 'not a time', 'nor this'),
        ...octoberEvents(),
      ]);
      final data = CalendarData(backend: backend, zones: const FakeZones());
      await data.refresh();
      final first = DateTime(2026, 9, 27), last = DateTime(2026, 11, 7);
      await data.ensure(first, last);
      final events = data.eventsFor(first, last)!.events;
      expect(events.map((e) => e.title), contains('Dentist'));
      expect(events.map((e) => e.title), isNot(contains('Broken')));
      expect(data.failureFor(first, last), isNull);
      data.dispose();
    });

    test('the time the data was last read is kept', () async {
      final data = CalendarData(backend: FakeBackend(), zones: const FakeZones());
      expect(data.updatedAt, isNull);
      final before = DateTime.now();
      await data.refresh();
      expect(data.updatedAt!.isBefore(before), isFalse);
      data.dispose();
    });

    test('no source on', () async {
      final data = CalendarData(backend: FakeBackend(macOn: false));
      await data.refresh();
      expect(data.anySourceOn, isFalse);
      data.dispose();
    });
  });
}
