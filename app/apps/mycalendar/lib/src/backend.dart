import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';

/// What myCalendar reads from the host. Read-only: there is no call here that changes a calendar or an
/// event. Tests pass a fake.
abstract class CalendarBackend {
  /// Every calendar, grouped by source: This Mac first, then each iCloud account (GET /calendars).
  Future<List<CalendarOut>> calendars();

  /// Every source and its state (GET /sources): which are on, and This Mac's permission.
  Future<List<SourceOut>> sources();

  /// The events on the days from [first] to [last], both included, and per source which of those days it
  /// reads (GET /events).
  Future<EventsOut> events(DateTime first, DateTime last);
}

/// The host's API, through the app's current connection.
class HostCalendarBackend implements CalendarBackend {
  HostCalendarBackend(this._connection);
  final HostConnection? Function() _connection;

  HostConnection get _conn {
    final c = _connection();
    if (c == null) throw StateError('not connected to the host');
    return c;
  }

  @override
  Future<List<CalendarOut>> calendars() async => (await _conn.sources.calendars()) ?? const [];

  @override
  Future<List<SourceOut>> sources() async => (await _conn.sources.sources())?.sources ?? const [];

  /// The generated client sends a date parameter as an ISO date-time in UTC, so the days go in as UTC
  /// midnights ("2026-10-13T00:00:00.000Z"), which the host reads as the date 2026-10-13. A local midnight
  /// would move to the day before east of UTC.
  @override
  Future<EventsOut> events(DateTime first, DateTime last) async {
    final out = await _conn.sources.events(
      DateTime.utc(first.year, first.month, first.day),
      DateTime.utc(last.year, last.month, last.day),
    );
    if (out == null) throw StateError('the host sent no events');
    return out;
  }
}

/// UTC offsets of named time zones at given instants, for an event set in a zone other than this
/// device's (design/components/EventRow, "Time zones"). Dart knows only the device's zone and UTC.
abstract class ZoneOffsets {
  /// For each (zone id, instant), the zone's offset from UTC at that instant; null for a zone the system
  /// does not know. Never throws: anything that fails is null.
  Future<List<Duration?>> offsets(List<(String, DateTime)> requests);
}

/// The macOS runner's time zone database, over the `mycalendar/zones` channel (MainFlutterWindow.swift).
/// Elsewhere, and in tests without the runner, every offset is null and no zone caption is shown.
class ChannelZoneOffsets implements ZoneOffsets {
  const ChannelZoneOffsets([this.channel = defaultChannel]);
  final MethodChannel channel;

  static const defaultChannel = MethodChannel('mycalendar/zones');

  /// The runner's limit on one call.
  static const maxPerCall = 4096;

  @override
  Future<List<Duration?>> offsets(List<(String, DateTime)> requests) async {
    final out = <Duration?>[];
    for (var i = 0; i < requests.length; i += maxPerCall) {
      final part = requests.sublist(i, i + maxPerCall > requests.length ? requests.length : i + maxPerCall);
      List<Object?>? answer;
      try {
        answer = await channel.invokeListMethod<Object?>('offsets', [
          for (final (zone, at) in part) [zone, at.millisecondsSinceEpoch],
        ]);
      } on Object {
        answer = null;
      }
      for (var j = 0; j < part.length; j++) {
        final v = answer != null && j < answer.length ? answer[j] : null;
        out.add(v is int ? Duration(seconds: v) : null);
      }
    }
    return out;
  }
}
