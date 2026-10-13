import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'data_colour.dart';
import 'group_frame.dart';
import 'grouped_list.dart';

/// An event's times in its own time zone, for an event set in a zone other than this device's
/// (design/components/EventRow, "Time zones").
///
/// Dart reads only the device's zone and UTC, so the app works these out (from the event's zone id and a
/// time zone database) and passes them here. Only the wall-clock fields of [start] and [end] are used.
class EventZoneTimes {
  const EventZoneTimes({required this.name, required this.start, required this.end});

  /// The zone's name in the generic form, without the word "time": "New York", or "UTC" or "UTC−5", which
  /// the caption shows without "time". [zoneCityName] makes it from a zone id; when that gives null (a zone
  /// that is not an IANA id), leave [EventItem.zone] null.
  final String name;

  /// The start, as a clock in that zone shows it.
  final DateTime start;

  /// The end, as a clock in that zone shows it.
  final DateTime end;
}

/// One event, as a day list and an [EventRow] show it. Read-only: nothing here changes the event.
class EventItem {
  const EventItem({
    this.id,
    required this.start,
    required this.end,
    this.allDay = false,
    this.zone,
    this.title = '',
    this.location = '',
    required this.calendarName,
    this.calendarColour,
    this.calendarId,
  });

  /// Optional: tells rows apart when the list changes (an occurrence key).
  final String? id;

  /// A timed event's start in this device's time zone. An all-day event's first date: only its year,
  /// month and day are used, and it never moves with the zone.
  final DateTime start;

  /// A timed event's end in this device's time zone (exclusive). An all-day event's end is the day after
  /// its last day, as the host gives it.
  final DateTime end;

  /// An all-day event: a date with no time and no time zone.
  final bool allDay;

  /// The event's times in its own zone, when that zone is not this device's; null otherwise, and always
  /// null for an all-day event. When its clock reads the same as the device's at both ends (another zone
  /// with the same offset that day), no zone caption is shown.
  final EventZoneTimes? zone;

  /// The title; empty for none ("No title").
  final String title;

  /// The location; empty for none.
  final String location;

  /// The calendar's name. Always shown: it is what the colour stands for.
  final String calendarName;

  /// The calendar's colour from the host ([parseDataColour]); null for none (`line-strong`).
  final Color? calendarColour;

  /// The calendar's id, for [DayList.hiddenCalendarIds]. Null: never hidden.
  final String? calendarId;
}

/// One source's range of days that myData reads, for [DayList] (design/components/Notice and EventRow).
class EventSourceRange {
  /// A source that reads the days from [first] to [last], both included; null for no limit at that end.
  const EventSourceRange({required this.name, this.first, this.last}) : readsNothing = false;

  /// A source that reads no days at all (not read yet, or not allowed).
  const EventSourceRange.nothing({required this.name}) : first = null, last = null, readsNothing = true;

  /// The source's name as it sits inside a sentence: "this Mac", "the iCloud account you@example.com".
  final String name;

  /// The first day read; null for no limit.
  final DateTime? first;

  /// The last day read (included); null for no limit.
  final DateTime? last;

  /// Whether the source reads no day at all.
  final bool readsNothing;

  /// Whether myData reads [day] from this source.
  bool reads(DateTime day) {
    if (readsNothing) return false;
    final d = _dateKey(day);
    if (first != null && d < _dateKey(first!)) return false;
    if (last != null && d > _dateKey(last!)) return false;
    return true;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Pure functions: times, days and captions. The apps are in English only; the clock follows the device.
// ---------------------------------------------------------------------------------------------------------------

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// A day with no time, for date arithmetic that no daylight-saving change can disturb.
DateTime _date(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// A day as one sortable number.
int _dateKey(DateTime t) => _date(t).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// A time of day on the device's clock: "09:30" on a 24-hour clock, "9:30 am" on a 12-hour one (British
/// English, as the apps are written).
String formatEventTime(DateTime time, {required bool use24HourFormat}) {
  final m = time.minute.toString().padLeft(2, '0');
  if (use24HourFormat) return '${time.hour.toString().padLeft(2, '0')}:$m';
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$h:$m ${time.hour < 12 ? 'am' : 'pm'}';
}

/// A zone id's name in the generic form the zone caption uses, from the city in the id:
/// "America/New_York" is "New York", "America/Argentina/Buenos_Aires" is "Buenos Aires". "UTC", "Etc/UTC"
/// and the like are "UTC"; "Etc/GMT+5" (which is five hours behind) is "UTC−5".
///
/// Null for anything that is not an IANA "Area/City" id, so that no caption is made from it: the host passes
/// a calendar's own zone name through when it has no IANA id, such as Outlook's "Pacific Standard Time" or
/// "(UTC+01:00) Amsterdam, Berlin, Bern, Rome", and single-word ids ("EST", "Japan") are legacy aliases.
String? zoneCityName(String zoneId) {
  final id = zoneId.trim();
  if (_utcZoneIds.contains(id)) return 'UTC';
  final etc = RegExp(r'^Etc/GMT([+-])(\d{1,2})$').firstMatch(id);
  if (etc != null) {
    final hours = int.parse(etc.group(2)!);
    // The Etc zones' signs are POSIX's: Etc/GMT+5 is five hours behind UTC.
    return hours == 0 ? 'UTC' : 'UTC${etc.group(1) == '+' ? _minus : '+'}$hours';
  }
  // Area/City, maybe with a prefix ("/mozilla.org/20050126_1/America/New_York"): no spaces or brackets.
  if (!_ianaShape.hasMatch(id) || id.startsWith('Etc/')) return null;
  final city = id.split('/').last.replaceAll('_', ' ').trim();
  return city.isEmpty ? null : city;
}

const _utcZoneIds = {
  'UTC', 'UCT', 'GMT', 'GMT0', 'GMT+0', 'GMT-0', 'Greenwich', 'Universal', 'Zulu', //
  'Etc/UTC', 'Etc/UCT', 'Etc/GMT', 'Etc/GMT0', 'Etc/Greenwich', 'Etc/Universal', 'Etc/Zulu',
};

final _ianaShape = RegExp(r'^/?[A-Za-z0-9._+\-]+(/[A-Za-z0-9._+\-]+)+$');

/// The minus sign in "UTC−5".
const _minus = '\u2212';

/// A zone name the caption shows without the word "time" after it: "UTC", "UTC−5", or a name that already
/// ends in "time".
bool _zoneNameIsComplete(String name) =>
    RegExp('^UTC([+$_minus-]\\d{1,2})?\$').hasMatch(name) || name.toLowerCase().endsWith(' time');

/// The days [event] falls on in this device's time zone, in order, as dates (midnight, local).
///
/// - All-day: from its first date to the day before its end; at least one day.
/// - Timed: from the day it starts to the day it ends; an end at midnight belongs to the day before, so an
///   event that ends at 00:00 does not reach into the next day. An end at or before the start: one day.
List<DateTime> eventDays(EventItem event) {
  final first = _date(event.start);
  final DateTime last;
  if (event.allDay) {
    final end = _date(event.end).subtract(const Duration(days: 1));
    last = end.isBefore(first) ? first : end;
  } else {
    final lastInstant = event.end.isAfter(event.start)
        ? event.end.subtract(const Duration(microseconds: 1))
        : event.start;
    last = _date(lastInstant);
  }
  final count = last.difference(first).inDays + 1;
  return [for (var i = 0; i < count; i++) DateTime(first.year, first.month, first.day + i)];
}

/// Which of its days [day] is for [event]: day 1 of [count]. Null when the event is not on [day].
({int day, int count})? eventDayOf(EventItem event, DateTime day) {
  final first = _date(event.start);
  final days = eventDays(event);
  final i = _date(day).difference(first).inDays;
  if (i < 0 || i >= days.length) return null;
  return (day: i + 1, count: days.length);
}

/// "Day 2 of 3".
String dayOfLabel(int day, int count) => 'Day $day of $count';

/// What the "when" column shows for [event] on [day]: [time] in `body`, and [under] it in `caption` (null
/// for nothing). Null when the event is not on [day].
///
/// - All-day, or a day in the middle of a timed event over several days: "All day".
/// - A timed event on one day: its start over its end (just the start when it has no length).
/// - The first of several days: its start over "Starts"; the last: its end over "Ends". A last day that the
///   event fills to its very end (an end at midnight) shows "All day".
({String time, String? under})? eventWhen(EventItem event, DateTime day, {required bool use24HourFormat}) {
  final of = eventDayOf(event, day);
  if (of == null) return null;
  String t(DateTime x) => formatEventTime(x, use24HourFormat: use24HourFormat);
  return switch (_partOn(event, of)) {
    _Part.allDay => (time: EventRow.allDayLabel, under: null),
    _Part.whole => (time: t(event.start), under: event.end.isAfter(event.start) ? t(event.end) : null),
    _Part.starts => (time: t(event.start), under: EventRow.startsLabel),
    _Part.ends => (time: t(event.end), under: EventRow.endsLabel),
  };
}

/// What part of an event a day holds.
enum _Part { allDay, whole, starts, ends }

_Part _partOn(EventItem event, ({int day, int count}) of) {
  if (event.allDay) return _Part.allDay;
  if (of.count == 1) return _Part.whole;
  if (of.day == 1) return _Part.starts;
  // A last day the event fills to midnight holds all of that day.
  if (of.day == of.count && (event.end.hour != 0 || event.end.minute != 0)) return _Part.ends;
  return _Part.allDay;
}

/// The event's own times in its zone, when they differ from the device's clock: "10:00 to 11:00 New York
/// time", or "10:00 to 11:00 UTC" and "10:00 to 11:00 UTC−5" with no "time". Null for an all-day event, an
/// event with no [EventItem.zone] or with an empty zone name, or one whose zone's clock reads the same as the
/// device's at both ends.
String? eventZoneCaption(EventItem event, {required bool use24HourFormat}) {
  final z = event.zone;
  final name = z?.name.trim() ?? '';
  if (event.allDay || z == null || name.isEmpty) return null;
  bool sameClock(DateTime a, DateTime b) => _sameDay(a, b) && a.hour == b.hour && a.minute == b.minute;
  if (sameClock(z.start, event.start) && sameClock(z.end, event.end)) return null;
  String t(DateTime x) => formatEventTime(x, use24HourFormat: use24HourFormat);
  return '${t(z.start)} to ${t(z.end)} $name${_zoneNameIsComplete(name) ? '' : ' time'}';
}

/// The caption under the title, parts joined by " · ": the zone's times when the zone differs, "Day 2 of 3"
/// for an event over several days, the location if there is one, and the calendar's name, which is always
/// there.
String eventCaption(EventItem event, DateTime day, {required bool use24HourFormat}) {
  final of = eventDayOf(event, day);
  final location = event.location.trim();
  return [
    ?eventZoneCaption(event, use24HourFormat: use24HourFormat),
    if (of != null && of.count > 1) dayOfLabel(of.day, of.count),
    if (location.isNotEmpty) location,
    event.calendarName,
  ].join(EventRow.captionSeparator);
}

/// A day list's heading: the full date, "Wednesday 14 October", with the year when it is not [today]'s
/// year ("Tuesday 7 October 2025"); today's starts "Today, ".
String formatDayHeading(DateTime day, {required DateTime today}) {
  final date =
      '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}'
      '${day.year == today.year ? '' : ' ${day.year}'}';
  return _sameDay(day, today) ? '${DayList.todayPrefix}$date' : date;
}

/// The events of [events] that fall on [day], in a day list's order: all-day first (with the middle days of
/// timed events over several days), then by their start on that day, then by end; equal ones keep the order
/// given.
List<EventItem> eventsOnDay(List<EventItem> events, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final keyed = [
    for (var i = 0; i < events.length; i++)
      if (eventDayOf(events[i], day) case final of?)
        (
          e: events[i],
          i: i,
          allDay: _partOn(events[i], of) == _Part.allDay,
          start: events[i].start.isBefore(dayStart) ? dayStart : events[i].start,
        ),
  ];
  keyed.sort((a, b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    if (!a.allDay) {
      final s = a.start.compareTo(b.start);
      if (s != 0) return s;
      final e = a.e.end.compareTo(b.e.end);
      if (e != 0) return e;
    }
    return a.i.compareTo(b.i);
  });
  return [for (final k in keyed) k.e];
}

// ---------------------------------------------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------------------------------------------

/// A [GroupedList]-style row for one event on one day: when, what, where and which calendar
/// (design/components/EventRow).
///
/// - At least `row-height` tall, padded `space-4` across and `space-2` down, `space-3` between its parts,
///   with no icon tile.
/// - **When** first, in a column [whenWidth] wide (scaled with the text size) so titles line up: [eventWhen]
///   in `body`, with the end time, "Starts" or "Ends" under it in `caption` and `ink-muted`. Times follow the
///   device's 12-hour or 24-hour clock ([use24HourFormat], or `MediaQuery.alwaysUse24HourFormat`).
/// - Then the calendar's [DataBar], as tall as the text beside it, on `surface`.
/// - The title in `body-strong`, at most two lines, cut short with an ellipsis; no title shows [noTitle] in
///   `ink-muted`. Under it, in `caption` and `ink-muted`, [eventCaption]: the zone's times when the zone
///   differs, "Day 2 of 3", the location, and always the calendar's name.
/// - Not pressable and not a Tab stop: there is no event page yet. Its text can be selected with the
///   pointer; inside a [DayList] the selection runs across rows.
/// - Assistive technology reads the row as one node: the times ("09:30 to 10:15", "Starts 22:40"), the
///   title, then the caption. The bar has no accessible name; the calendar's name is in the caption.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.day, this.use24HourFormat});

  /// The event.
  final EventItem event;

  /// The day this row is shown on; the event must fall on it ([eventDays]).
  final DateTime day;

  /// The clock: null follows `MediaQuery.alwaysUse24HourFormat`.
  final bool? use24HourFormat;

  /// Preview: `.when{width:64px}`, the `space-16` step. Scaled with the text size, and widened when the
  /// longest time on the device's clock ("10:00 pm" on a 12-hour clock) would not fit on one line
  /// ([whenColumnWidth]).
  static const whenWidth = MyDataSpace.s16;

  /// The "when" column's width for a clock and a text size: [whenWidth] scaled, or the widest thing the
  /// column can show on one line, whichever is wider. The same for every row, so titles line up.
  static double whenColumnWidth({required bool use24HourFormat, required TextScaler textScaler}) {
    final key = (use24HourFormat, textScaler.scale(MyDataType.body.fontSize!));
    return _whenWidths[key] ??= () {
      var widest = 0.0;
      final painter = TextPainter(textDirection: TextDirection.ltr, textScaler: textScaler, maxLines: 1);
      for (final text in [
        allDayLabel,
        for (var hour = 0; hour < 24; hour++)
          formatEventTime(DateTime(2000, 1, 1, hour, 0), use24HourFormat: use24HourFormat),
      ]) {
        painter.text = TextSpan(text: text, style: MyDataType.body);
        painter.layout();
        if (painter.width > widest) widest = painter.width;
      }
      painter.dispose();
      // The minutes' digits vary in width: leave room for the widest pair.
      return math.max(textScaler.scale(whenWidth), (widest + textScaler.scale(_digitSlack)).ceilToDouble());
    }();
  }

  static final _whenWidths = <(bool, double), double>{};

  /// Room for minutes wider than ":00" in a proportional font.
  static const _digitSlack = MyDataSpace.s1;

  /// The title's line limit (preview: `-webkit-line-clamp:2`).
  static const titleMaxLines = 2;

  static const allDayLabel = 'All day';
  static const startsLabel = 'Starts';
  static const endsLabel = 'Ends';
  static const noTitle = 'No title';
  static const captionSeparator = ' · ';

  /// The "when" column's accessible text: "09:30 to 10:15", "Starts 22:40", "Ends 07:10", "All day".
  static String whenLabel(({String time, String? under}) when) => switch (when.under) {
    null => when.time,
    startsLabel => '$startsLabel ${when.time}',
    endsLabel => '$endsLabel ${when.time}',
    final end => '${when.time} to $end',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final use24 = use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
    final when = eventWhen(event, day, use24HourFormat: use24);
    assert(when != null, 'the event does not fall on the day this row is shown on');
    final w = when ?? (time: '', under: null);
    final title = event.title.trim();
    final caption = eventCaption(event, day, use24HourFormat: use24);
    final width = whenColumnWidth(use24HourFormat: use24, textScaler: MediaQuery.textScalerOf(context));

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
      child: Padding(
        padding: GroupedRow.padding,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: width,
                child: Semantics(
                  label: whenLabel(w),
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.time, style: MyDataType.body.copyWith(color: c.ink)),
                          if (w.under != null) Text(w.under!, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: GroupedRow.gap),
              DataBar(colour: event.calendarColour),
              const SizedBox(width: GroupedRow.gap),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? noTitle : title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: MyDataType.bodyStrong.copyWith(color: title.isEmpty ? c.inkMuted : c.ink),
                      ),
                      Text(caption, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return _Selectable(child: MergeSemantics(child: row));
  }
}

/// A day list: one group per day, headed by the full date, with that day's [EventRow]s
/// (design/components/EventRow, "In a day list").
///
/// - Each day is a GroupedList-style group headed in `label` by [formatDayHeading] ("Today, Tuesday 13
///   October"), the days [gap] apart, in the order given.
/// - A day's events: those that fall on it ([eventDays]) and whose calendar is not in [hiddenCalendarIds],
///   all-day first, then by start ([eventsOnDay]).
/// - **Days myData does not read.** [sources] are the sources with a shown calendar and the days each
///   reads. For each that does not read a day, the day ends with the line "Events from this Mac are not
///   shown for this day." ([notShownLine]) in `ink-muted`, after any events from other sources.
/// - "No events" ([noEvents], `ink-muted`) only when the day has no events and every source reads it.
/// - The Notice that gives the range sits above the list; the app puts it there ([NoticeStack]).
/// - Not scrollable: put it in the screen's scroll view. Its text can be selected across rows.
class DayList extends StatelessWidget {
  const DayList({
    super.key,
    required this.days,
    required this.today,
    required this.events,
    this.sources = const [],
    this.hiddenCalendarIds = const {},
    this.use24HourFormat,
  });

  /// The days to list, in order (one day under a month grid, or a week).
  final List<DateTime> days;

  /// Today, on this device: its heading starts "Today, ", and the year is left out within its year.
  final DateTime today;

  /// The events to place on the days; an event over several days appears on each.
  final List<EventItem> events;

  /// The sources with a shown calendar, and the days each reads. Empty: every day is read.
  final List<EventSourceRange> sources;

  /// Calendars the user has hidden on this device; their events are left out.
  final Set<String> hiddenCalendarIds;

  /// The clock: null follows `MediaQuery.alwaysUse24HourFormat`.
  final bool? use24HourFormat;

  /// Between days (preview: `.sec{margin-bottom:24px}`).
  static const gap = MyDataSpace.s6;

  static const todayPrefix = 'Today, ';
  static const noEvents = 'No events';

  /// The line for a day that [source] does not read: "Events from this Mac are not shown for this day."
  static String notShownLine(String source) => 'Events from $source are not shown for this day.';

  /// The events shown on [day], in order.
  List<EventItem> eventsOn(DateTime day) => eventsOnDay([
    for (final e in events)
      if (e.calendarId == null || !hiddenCalendarIds.contains(e.calendarId)) e,
  ], day);

  @override
  Widget build(BuildContext context) {
    final use24 = use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
    final groups = <Widget>[];
    for (final day in days) {
      final shown = eventsOn(day);
      final unread = [
        for (final s in sources)
          if (!s.reads(day)) s.name,
      ];
      final parts = <Widget>[
        for (final e in shown)
          EventRow(key: e.id == null ? null : ValueKey(e.id), event: e, day: day, use24HourFormat: use24),
        for (final name in unread) _LineRow(notShownLine(name)),
        if (shown.isEmpty && unread.isEmpty) const _LineRow(noEvents),
      ];
      groups.add(
        GroupFrame(
          heading: formatDayHeading(day, today: today),
          parts: parts,
        ),
      );
    }
    return _Selectable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < groups.length; i++) ...[if (i > 0) const SizedBox(height: gap), groups[i]],
        ],
      ),
    );
  }
}

/// A day list's row of words alone ("No events", the not-shown line): `body` in `ink-muted`.
class _LineRow extends StatelessWidget {
  const _LineRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
    child: Padding(
      padding: GroupedRow.padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(text, style: MyDataType.body.copyWith(color: context.colors.inkMuted)),
      ),
    ),
  );
}

/// Makes the text under it selectable with the pointer, unless something above already does (a [DayList]
/// around its rows), so a selection can run across rows. Not a Tab stop: rows are not targets.
class _Selectable extends StatefulWidget {
  const _Selectable({required this.child});
  final Widget child;

  @override
  State<_Selectable> createState() => _SelectableState();
}

class _SelectableState extends State<_Selectable> {
  final _focus = FocusNode(debugLabel: 'EventRow selection', skipTraversal: true);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SelectionContainer.maybeOf(context) != null) return widget.child;
    return SelectionArea(focusNode: _focus, child: widget.child);
  }
}
