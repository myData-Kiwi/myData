import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'calendar_model.dart';

/// What the Month section shows for one month, worked out once from the host's data for both of its
/// layouts: the branded [MonthPage] and the Mac frame's [MacMonthView]. Calendars hidden on this device are
/// left out of everything here.
@immutable
class MonthContent {
  const MonthContent._({
    required this.days,
    required this.fetched,
    required this.failure,
    required this.ranges,
    required this.notices,
    required this.shown,
    required this.cells,
  });

  /// Works out [month]'s six weeks. [online] false: the host cannot be reached, so no read error is given
  /// (the frame says so) and [failure] is null.
  factory MonthContent.of({
    required CalendarData data,
    required Set<String> hidden,
    required DateTime month,
    required int firstDayOfWeek,
    required bool online,
    required ValueChanged<NoticeAction> onNoticeAction,
  }) {
    final days = MonthGrid.visibleDays(month, firstDayOfWeek);
    final first = days.first, last = days.last;
    final fetched = data.eventsFor(first, last);
    final failure = fetched == null && online ? data.failureFor(first, last) : null;
    final calendars = data.calendars ?? const <CalendarOut>[];
    bool visible(String id) => !hidden.contains(id);

    // The sources with a shown calendar, and what each reads of the days on screen.
    final emails = {for (final s in data.sources ?? const <SourceOut>[]) s.id: s.email};
    final macStatus = data.sources?.where((s) => s.kind == SourceOutKindEnum.mac).firstOrNull?.calendarsStatus;
    final headings = {for (final c in calendars) c.accountId: c.sourceLabel};
    final sources = [
      for (final c in fetched?.coverage ?? const <CoverageOut>[])
        if (sourceCounts(c.accountId, calendars, visible))
          SourceCoverage(
            coverage: c,
            name: sourceInSentence(c.source_, email: emails[c.accountId], heading: headings[c.accountId]),
            calendarsStatus: c.source_ == CoverageOutSource_Enum.mac ? macStatus : null,
          ),
    ];
    final notices = [
      for (final s in sources)
        if (s.notice(first, last) case final n?)
          Notice(
            message: n.message,
            tone: n.tone,
            actionLabel: switch (n.action) {
              NoticeAction.none => null,
              NoticeAction.openMyData => MonthPageText.openMyData,
              NoticeAction.openSystemSettings => MonthPageText.openSystemSettings,
            },
            onAction: n.action == NoticeAction.none ? null : () => onNoticeAction(n.action),
          ),
    ];

    final shown = [
      for (final e in fetched?.events ?? const <EventItem>[])
        if (e.calendarId == null || visible(e.calendarId!)) e,
    ];
    final cells = <DateTime, List<MonthGridEvent>>{};
    for (final e in shown) {
      for (final d in eventDays(e)) {
        if (d.isBefore(first) || d.isAfter(last)) continue;
        final dayStart = DateTime(d.year, d.month, d.day);
        final when = eventWhen(e, d, use24HourFormat: true);
        (cells[dayStart] ??= []).add(MonthGridEvent(
          title: e.title.trim(),
          calendarName: e.calendarName,
          colour: e.calendarColour,
          allDay: when?.time == EventRow.allDayLabel,
          start: e.start.isBefore(dayStart) ? dayStart : e.start,
        ));
      }
    }
    return MonthContent._(
      days: days,
      fetched: fetched,
      failure: failure,
      ranges: [for (final s in sources) s.range],
      notices: notices,
      shown: shown,
      cells: cells,
    );
  }

  /// The six weeks on screen.
  final List<DateTime> days;

  /// The month's events as the host sent them; null until they arrive (or when they could not be read).
  final MonthEvents? fetched;

  /// Why the month could not be read, when nothing older is here; null otherwise.
  final String? failure;

  /// The days each source with a shown calendar reads.
  final List<EventSourceRange> ranges;

  /// A Notice for every such source that does not read all the days on screen.
  final List<Notice> notices;

  /// The month's events in shown calendars.
  final List<EventItem> shown;

  /// Each day's events as a MonthGrid cell takes them.
  final Map<DateTime, List<MonthGridEvent>> cells;

  /// Whether no source reads [day]: every day when the month failed; null when every day is read.
  bool Function(DateTime day)? get isNotRead => failure != null
      ? (_) => true
      : ranges.isEmpty
      ? null
      : (d) => ranges.every((r) => !r.reads(d));
}
