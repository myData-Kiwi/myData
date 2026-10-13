import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';

// ---------------------------------------------------------------------------------------------------------------
// Pure rules: the host's data as the screens show it. No widget, no state.
// ---------------------------------------------------------------------------------------------------------------

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// A day at local midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// A day in the locale's long date form, as the Notice writes it: "13 October 2025".
String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// A `YYYY-MM-DD` date from the host, at local midnight; null for anything else.
DateTime? hostDate(String? s) => s == null ? null : OpenDay.parseDate(s);

/// How a source sits inside a sentence (design/components/Notice, "Sources, not accounts"): "this Mac", or
/// "the iCloud account you@example.com". [email] is the iCloud account's address; when it is unknown, the
/// calendar list's heading for the source ("iCloud account you@example.com") gives it.
String sourceInSentence(CoverageOutSource_Enum source, {String? email, String? heading}) {
  if (source == CoverageOutSource_Enum.mac) return 'this Mac';
  if (email != null && email.isNotEmpty) return 'the iCloud account $email';
  if (heading != null && heading.startsWith('iCloud account ')) return 'the $heading';
  return 'an iCloud account';
}

/// One of the host's events as the day list and the grid show it. [calendar] gives its calendar's name and
/// colour; [zone] its times in its own zone, when known. A timed event's times are moved into this
/// device's time zone; an all-day event keeps its dates.
EventItem eventItemOf(EventOut e, CalendarOut? calendar, {EventZoneTimes? zone}) {
  final DateTime start, end;
  if (e.allDay) {
    start = hostDate(e.start.substring(0, e.start.length < 10 ? e.start.length : 10)) ?? DateTime.now();
    end = hostDate(e.end.substring(0, e.end.length < 10 ? e.end.length : 10)) ?? start.add(const Duration(days: 1));
  } else {
    start = DateTime.parse(e.start).toLocal();
    end = DateTime.parse(e.end).toLocal();
  }
  return EventItem(
    id: '${e.calendarId}|${e.eventId}|${e.recurrenceId ?? ''}|${e.start}',
    start: start,
    end: end,
    allDay: e.allDay,
    zone: e.allDay ? null : zone,
    title: e.title,
    location: e.location,
    calendarName: calendar?.name ?? MonthPageText.unknownCalendar,
    calendarColour: parseDataColour(calendar?.color),
    calendarId: e.calendarId,
  );
}

/// The zone and instants an event needs offsets for: its own zone (an IANA id [zoneCityName] can name),
/// at its start and its end. Null for an all-day event or a zone with no usable name.
(String zone, DateTime start, DateTime end)? zoneRequestOf(EventOut e) {
  final tz = e.timeZone?.trim();
  if (e.allDay || tz == null || tz.isEmpty || zoneCityName(tz) == null) return null;
  final start = DateTime.tryParse(e.start), end = DateTime.tryParse(e.end);
  if (start == null || end == null) return null;
  return (tz, start.toUtc(), end.toUtc());
}

/// The event's times as a clock in its zone shows them, from the zone's offsets at its start and end.
EventZoneTimes? zoneTimesOf(String zone, DateTime startUtc, DateTime endUtc, Duration? atStart, Duration? atEnd) {
  final name = zoneCityName(zone);
  if (name == null || atStart == null || atEnd == null) return null;
  return EventZoneTimes(name: name, start: startUtc.toUtc().add(atStart), end: endUtc.toUtc().add(atEnd));
}

/// Whether a source counts for the window rules: it has a shown calendar, or none is known yet (a source
/// not read yet has no calendars, and its notice must still show).
bool sourceCounts(String accountId, List<CalendarOut> calendars, bool Function(String id) isVisible) {
  final own = calendars.where((c) => c.accountId == accountId).toList();
  return own.isEmpty || own.any((c) => isVisible(c.id));
}

/// What one Notice says and leads to.
enum NoticeAction { none, openMyData, openSystemSettings }

@immutable
class NoticeSpec {
  const NoticeSpec(this.message, this.tone, [this.action = NoticeAction.none]);
  final String message;
  final NoticeTone tone;
  final NoticeAction action;

  @override
  bool operator ==(Object other) =>
      other is NoticeSpec && other.message == message && other.tone == tone && other.action == action;

  @override
  int get hashCode => Object.hash(message, tone, action);

  @override
  String toString() => 'NoticeSpec($message, $tone, $action)';
}

/// One source's coverage of the days on screen, with its name in a sentence and, for This Mac, whether
/// the user has been asked for access to its calendars.
@immutable
class SourceCoverage {
  const SourceCoverage({required this.coverage, required this.name, this.calendarsStatus});
  final CoverageOut coverage;

  /// "this Mac", "the iCloud account you@example.com".
  final String name;

  /// This Mac's calendars permission from GET /sources ("notDetermined", "denied", "fullAccess", ...).
  final String? calendarsStatus;

  /// The days this source reads, for the grid and the day list.
  EventSourceRange get range {
    if (coverage.reason != null) return EventSourceRange.nothing(name: name);
    return EventSourceRange(name: name, first: hostDate(coverage.coveredStart), last: hostDate(coverage.coveredEnd));
  }

  /// The notice for the days [first] to [last], or null when this source reads all of them.
  /// (design/components/Notice: the window limit, and a source with no days read at all.)
  NoticeSpec? notice(DateTime first, DateTime last) {
    switch (coverage.reason) {
      case CoverageOutReasonEnum.noAccess:
        return NoticeSpec(MonthPageText.refused(name), NoticeTone.warning, NoticeAction.openSystemSettings);
      case CoverageOutReasonEnum.notReadYet:
        // Not asked yet is "not allowed yet"; asked and allowed is "not read yet".
        if (calendarsStatus == 'notDetermined') {
          return NoticeSpec(MonthPageText.notAllowedYet(name), NoticeTone.warning, NoticeAction.openMyData);
        }
        return NoticeSpec(MonthPageText.notReadYet(name), NoticeTone.info);
      case null:
        break;
    }
    if (coverage.complete) return null;
    final from = hostDate(coverage.coveredStart), to = hostDate(coverage.coveredEnd);
    if (from == null && to == null) return null;
    final r = range;
    if (r.reads(first) && r.reads(last)) return null;
    var anyRead = false;
    for (var d = dateOnly(first); !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      if (r.reads(d)) {
        anyRead = true;
        break;
      }
    }
    return NoticeSpec(
      MonthPageText.window(name, from, to, outside: anyRead ? null : MonthPageText.thisMonthOutside),
      NoticeTone.info,
    );
  }
}

/// The words the month screen writes (design/components/Notice and EventRow).
abstract final class MonthPageText {
  static const unknownCalendar = 'Calendar';
  static const thisMonthOutside = 'This month is outside that range.';
  static const openMyData = 'Open myData';
  static const openSystemSettings = 'Open System Settings';

  /// "myData reads events from this Mac between 13 October 2025 and 13 October 2028." With [outside], that
  /// sentence follows. An open end says "from" or "until" instead. [from] and [to] are not both null.
  static String window(String source, DateTime? from, DateTime? to, {String? outside}) {
    final String range;
    if (from != null && to != null) {
      range = 'between ${longDate(from)} and ${longDate(to)}';
    } else if (from != null) {
      range = 'from ${longDate(from)} on';
    } else {
      range = 'until ${longDate(to!)}';
    }
    final first = 'myData reads events from $source $range.';
    return outside == null ? first : '$first $outside';
  }

  static String _possessive(String source) => source == 'this Mac' ? 'this Mac’s' : '$source’s';

  static String notReadYet(String source) =>
      'myData has not read the events from $source yet. They appear here when it has.';

  static String notAllowedYet(String source) =>
      'myData is not allowed to read ${_possessive(source)} calendars. Allow it in myData, under Settings, Sources.';

  static String refused(String source) =>
      'myData is not allowed to read ${_possessive(source)} calendars. Turn on myData in System Settings, '
      'under Privacy & Security, Calendars.';
}

// ---------------------------------------------------------------------------------------------------------------
// State: what the host has sent, per month.
// ---------------------------------------------------------------------------------------------------------------

/// One month's six weeks of events as the host sent them, and which of those days each source reads.
@immutable
class MonthEvents {
  const MonthEvents({required this.first, required this.last, required this.events, required this.coverage});

  /// The first and last day fetched (the grid's six weeks).
  final DateTime first, last;

  /// Every event on those days, in every calendar (hidden ones are left out when shown).
  final List<EventItem> events;

  /// Per source holding calendars, which of those days it reads.
  final List<CoverageOut> coverage;
}

/// What myCalendar knows from the host: the calendars, the sources, and each month's events, fetched when a
/// month is first shown and kept until [refresh]. Read-only: nothing here changes a calendar or an event.
///
/// A month whose events could not be read is not asked for again until the next [refresh] (the app's
/// periodic one, or Retry), so a failing host is not asked once per frame; [failureFor] says why it failed.
/// What was read stays here while the host cannot be reached, with [updatedAt].
class CalendarData extends ChangeNotifier {
  CalendarData({required this.backend, this.zones = const ChannelZoneOffsets(), DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final CalendarBackend backend;
  final ZoneOffsets zones;
  final DateTime Function() _now;

  List<CalendarOut>? calendars;
  List<SourceOut>? sources;

  /// Why the last read of the calendars and sources failed, for people; null when it worked.
  String? error;

  /// When the calendars or a month's events were last read from the host; null before either.
  DateTime? updatedAt;

  final _months = <String, MonthEvents>{};

  /// Months whose last read failed, with why, for people. Not asked for again until [refresh].
  final _failed = <String, String>{};
  final _loading = <String, Future<void>>{};
  final _stale = <String>{};
  int _generation = 0;
  bool _disposed = false;

  static String _key(DateTime first, DateTime last) =>
      '${first.year}-${first.month}-${first.day}/${last.year}-${last.month}-${last.day}';

  /// Whether the calendars and sources have arrived.
  bool get ready => calendars != null && sources != null;

  /// Whether any source is on. Null until the sources have arrived.
  bool? get anySourceOn => sources?.any((s) => s.enabled);

  /// The events fetched for the days [first] to [last], or null when they have not arrived yet.
  MonthEvents? eventsFor(DateTime first, DateTime last) => _months[_key(first, last)];

  /// Why the days [first] to [last] could not be read, or null when they were not asked for, are being
  /// read, or were read.
  String? failureFor(DateTime first, DateTime last) => _failed[_key(first, last)];

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Read the calendars and the sources again, and mark every month as stale, so the next [ensure] of each
  /// reads it again (the month on screen keeps its events until then).
  Future<void> refresh() async {
    final generation = ++_generation;
    // Every month that failed may be asked for once more.
    _failed.clear();
    try {
      final results = await Future.wait([backend.calendars(), backend.sources()]);
      if (_disposed || generation != _generation) return;
      calendars = results[0] as List<CalendarOut>;
      sources = results[1] as List<SourceOut>;
      error = null;
      updatedAt = _now();
      _stale.addAll(_months.keys);
    } on Object catch (e) {
      if (_disposed || generation != _generation) return;
      error = _describe(e);
    }
    _notify();
  }

  /// Forget every month: the sources changed, so what the host holds changed.
  void clearMonths() {
    _months.clear();
    _stale.clear();
    _failed.clear();
    _notify();
  }

  /// Fetch the days [first] to [last] unless they are here and fresh.
  Future<void> ensure(DateTime first, DateTime last) {
    final key = _key(first, last);
    if (_months.containsKey(key) && !_stale.contains(key)) return Future.value();
    if (_failed.containsKey(key)) return Future.value();
    // The block body matters: an arrow would return the removed future, and whenComplete would wait on
    // itself.
    return _loading[key] ??= _fetch(key, first, last).whenComplete(() {
      _loading.remove(key);
    });
  }

  Future<void> _fetch(String key, DateTime first, DateTime last) async {
    try {
      final out = await backend.events(first, last);
      final byId = {for (final c in calendars ?? const <CalendarOut>[]) c.id: c};
      final zoneTimes = await _zoneTimes(out.events);
      final items = <EventItem>[];
      for (final e in out.events) {
        try {
          items.add(eventItemOf(e, byId[e.calendarId], zone: zoneTimes[e]));
        } on Object {
          // One event the app cannot read (a malformed time) is left out; the month's others still show.
        }
      }
      if (_disposed) return;
      _months[key] = MonthEvents(first: first, last: last, events: items, coverage: out.coverage);
      _stale.remove(key);
      _failed.remove(key);
      updatedAt = _now();
    } on Object catch (e) {
      if (_disposed) return;
      _failed[key] = _describe(e);
    }
    _notify();
  }

  Future<Map<EventOut, EventZoneTimes>> _zoneTimes(List<EventOut> events) async {
    final wanted = <(EventOut, String, DateTime, DateTime)>[
      for (final e in events)
        if (zoneRequestOf(e) case (final zone, final start, final end)) (e, zone, start, end),
    ];
    if (wanted.isEmpty) return const {};
    final offsets = await zones.offsets([
      for (final w in wanted) ...[(w.$2, w.$3), (w.$2, w.$4)],
    ]);
    final out = Map<EventOut, EventZoneTimes>.identity();
    for (var i = 0; i < wanted.length; i++) {
      final (e, zone, start, end) = wanted[i];
      final z = zoneTimesOf(zone, start, end, offsets[2 * i], offsets[2 * i + 1]);
      if (z != null) out[e] = z;
    }
    return out;
  }

  static String _describe(Object e) => switch (e) {
    ApiException(:final code) when code > 0 => 'The host answered with an error ($code).',
    _ => 'The host could not be reached.',
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
