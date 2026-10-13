// Fake hosts and invented calendars for myCalendar's tests. Every name, address and event here is made up.
import 'dart:async';

import 'package:mydata_core/mydata_core.dart';
import 'package:mycalendar/src/backend.dart';
import 'package:mycalendar/src/home.dart';

/// A platform with no host: unsupported (the web build) or with no start command. It records every
/// attempt to open the myData app.
class NoHostPlatform implements HostPlatform {
  NoHostPlatform({required this.supported, this.opens = false});

  @override
  final bool supported;
  bool opens;
  final openCalls = <bool>[];

  @override
  String get unsupportedReason => 'The web version needs the desktop app.';

  @override
  Future<HostEnvironment> environment() async =>
      const HostEnvironment(home: '/tmp/mydata', baseUrl: 'http://127.0.0.1:1', hostCommand: null);

  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => null;

  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(false, '');

  @override
  Future<bool> openMyDataApp({bool setup = true}) async {
    openCalls.add(setup);
    return opens;
  }
}

/// A host already in [phaseOnConnect] with [statusOnConnect], without any network.
class FakeHost extends HostController {
  FakeHost({required this.phaseOnConnect, this.statusOnConnect, HostPlatform? platform})
    : super(app: 'mycalendar', platform: platform ?? NoHostPlatform(supported: true));

  HostPhase phaseOnConnect;
  StatusOut? statusOnConnect;

  @override
  Future<void> connect({bool startIfNeeded = true}) async {
    phase = phaseOnConnect;
    status = statusOnConnect;
    notifyListeners();
  }

  @override
  Future<bool> refresh() async {
    status = statusOnConnect;
    notifyListeners();
    return true;
  }

  /// A new status, as the next poll would bring it.
  void push(StatusOut s) {
    statusOnConnect = s;
    status = s;
    notifyListeners();
  }

  /// The host stops answering.
  void lose() {
    phase = HostPhase.lost;
    error = 'The myData host stopped while the app was open.';
    notifyListeners();
  }

  /// The host answers again.
  void comeBack() {
    phase = HostPhase.running;
    error = null;
    status = statusOnConnect;
    notifyListeners();
  }
}

/// A host status in [theme], in real mode (a source is on) unless [demo].
StatusOut hostStatus({String theme = 'kiwi', String today = '2026-10-13', bool demo = false, int epoch = 0}) =>
    StatusOut(
      agentsConnected: 0,
      assistantEnabled: false,
      conversationEpoch: epoch,
      demoDate: demo,
      memory: MemoryOut(hostBytes: 120000000),
      model: ModelOut(
        name: 'qwen3:14b',
        state: ModelOutStateEnum.disabled,
        loaded: false,
        ollamaReachable: false,
        ollamaStartedByHost: false,
      ),
      mode: demo ? StatusOutModeEnum.demo : StatusOutModeEnum.real,
      ready: true,
      theme: theme,
      today: today,
      uptimeSeconds: 12,
      version: '0.1.0',
    );

/// A local time as the host writes it: ISO 8601 with this device's offset ("2026-10-13T09:30:00+13:00").
String iso(int y, int mo, int d, [int h = 0, int mi = 0]) {
  final t = DateTime(y, mo, d, h, mi);
  final off = t.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final a = off.abs();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:00'
      '$sign${two(a.inHours)}:${two(a.inMinutes % 60)}';
}

/// The instant [local] (a time on this device) as the host writes it in a zone [offset] from UTC, so its
/// digits are not this device's clock ("...T04:30:00+05:30"). With [utcZ], "...Z".
String isoAt(DateTime local, Duration offset, {bool utcZ = false}) {
  final t = local.toUtc().add(offset);
  String two(int v) => v.toString().padLeft(2, '0');
  final clock = '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}:00';
  if (utcZ) return '${clock}Z';
  final sign = offset.isNegative ? '-' : '+';
  final a = offset.abs();
  return '$clock$sign${two(a.inHours)}:${two(a.inMinutes % 60)}';
}

String ymd(int y, int mo, int d) =>
    '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

int _ids = 0;

EventOut timed(String calendarId, String title, String start, String end, {String location = '', String? zone}) =>
    EventOut(
      allDay: false,
      calendarId: calendarId,
      start: start,
      end: end,
      eventId: 'ev${_ids++}',
      source_: calendarId.startsWith('ic') ? EventOutSource_Enum.icloud : EventOutSource_Enum.mac,
      title: title,
      location: location,
      timeZone: zone,
      uid: 'uid$_ids',
    );

EventOut allDay(String calendarId, String title, String first, String endExclusive) => EventOut(
  allDay: true,
  calendarId: calendarId,
  start: first,
  end: endExclusive,
  eventId: 'ev${_ids++}',
  source_: calendarId.startsWith('ic') ? EventOutSource_Enum.icloud : EventOutSource_Enum.mac,
  title: title,
  uid: 'uid$_ids',
);

const macId = 'mac';
const icloudId = 'acct-1';
const icloudEmail = 'sam@example.com';

CalendarOut macCal(String id, String name, String? colour, String? caption) => CalendarOut(
  id: id,
  accountId: macId,
  name: name,
  color: colour,
  accountCaption: caption,
  source_: CalendarOutSource_Enum.mac,
  sourceLabel: 'This Mac',
);

CalendarOut icloudCal(String id, String name, String? colour) => CalendarOut(
  id: id,
  accountId: icloudId,
  name: name,
  color: colour,
  source_: CalendarOutSource_Enum.icloud,
  sourceLabel: 'iCloud account $icloudEmail',
);

/// This Mac's calendars, as the host lists them.
final macCalendars = [
  macCal('m-family', 'Family', '#E5484D', 'iCloud'),
  macCal('m-personal', 'Personal', '#8E4EC6', 'iCloud'),
  macCal('m-work', 'Work', '#3E7BFA', 'Only on this Mac'),
  macCal('m-choir', 'Choir', '#1F1F1F', 'Google'),
  macCal('m-birthdays', 'Birthdays', '#8E8E93', 'Birthdays from Contacts'),
  macCal('m-garden', 'Garden club', '#F5D90A', 'Subscribed'),
  macCal('m-book', 'Book club', null, 'Only on this Mac'),
];

/// The followed iCloud account's calendars: the same Family and Personal as through the Mac.
final icloudCalendars = [
  icloudCal('ic-family', 'Family', '#E5484D'),
  icloudCal('ic-personal', 'Personal', '#8E4EC6'),
];

/// October 2026, around Tuesday 13 October, in This Mac's calendars.
List<EventOut> octoberEvents() => [
  allDay('m-personal', 'Rent', ymd(2026, 10, 1), ymd(2026, 10, 2)),
  timed('m-work', 'Team planning', iso(2026, 10, 5, 9), iso(2026, 10, 5, 10)),
  timed('m-choir', 'Choir practice', iso(2026, 10, 7, 18), iso(2026, 10, 7, 19, 30), location: 'Example Hall'),
  allDay('m-birthdays', 'Sam Sample’s birthday', ymd(2026, 10, 10), ymd(2026, 10, 11)),
  timed('m-family', 'Dentist', iso(2026, 10, 13, 9, 30), iso(2026, 10, 13, 10, 15),
      location: 'Example Dental, 4 Sample Road'),
  timed('m-choir', 'Choir practice', iso(2026, 10, 13, 18), iso(2026, 10, 13, 19, 30), location: 'Example Hall'),
  allDay('m-work', 'Conference in Lisbon', ymd(2026, 10, 14), ymd(2026, 10, 17)),
  allDay('m-garden', 'Seed swap', ymd(2026, 10, 15), ymd(2026, 10, 16)),
  timed('m-work', 'Call with the New York office', iso(2026, 10, 16, 15), iso(2026, 10, 16, 16),
      zone: 'America/New_York'),
  timed('m-personal', 'Lunch with Ava', iso(2026, 10, 16, 12, 30), iso(2026, 10, 16, 13, 30),
      location: 'Example Café'),
  timed('m-family', 'Night train to Porto', iso(2026, 10, 16, 22, 40), iso(2026, 10, 17, 7, 10),
      location: 'Example Central'),
  timed('m-book', 'Book club', iso(2026, 10, 19, 20), iso(2026, 10, 19, 21)),
  timed('m-choir', 'Choir practice', iso(2026, 10, 21, 18), iso(2026, 10, 21, 19, 30), location: 'Example Hall'),
  allDay('m-birthdays', 'Ava Fictional’s birthday', ymd(2026, 10, 22), ymd(2026, 10, 23)),
  timed('m-work', 'Team planning', iso(2026, 10, 26, 9), iso(2026, 10, 26, 10)),
  timed('m-family', 'Costume party', iso(2026, 10, 31, 19), iso(2026, 10, 31, 23)),
  timed('m-work', 'Team planning', iso(2026, 11, 2, 9), iso(2026, 11, 2, 10)),
  // October 2025, at the start of This Mac's window.
  timed('m-choir', 'Choir practice', iso(2025, 10, 14, 18), iso(2025, 10, 14, 19, 30), location: 'Example Hall'),
  timed('m-family', 'School pickup', iso(2025, 10, 17, 15), iso(2025, 10, 17, 15, 30)),
  timed('m-work', 'Quarterly review', iso(2025, 10, 17, 10), iso(2025, 10, 17, 11)),
  allDay('m-birthdays', 'Ava Fictional’s birthday', ymd(2025, 10, 22), ymd(2025, 10, 23)),
  // Events from before the window (the Mac does not read them, so the host never sends them).
];

/// The followed iCloud account's events: the same Dentist, seen through iCloud.
List<EventOut> icloudEvents() => [
  timed('ic-family', 'Dentist', iso(2026, 10, 13, 9, 30), iso(2026, 10, 13, 10, 15),
      location: 'Example Dental, 4 Sample Road'),
];

/// How This Mac reads events in a [FakeBackend].
sealed class MacReads {
  const MacReads();
}

/// The days from [first] to [last].
class MacWindow extends MacReads {
  const MacWindow(this.first, this.last);
  final String first, last;
}

/// No days at all, for [reason].
class MacNothing extends MacReads {
  const MacNothing(this.reason);
  final CoverageOutReasonEnum reason;
}

/// The host, as myCalendar reads it: calendars, sources and events, with each source's coverage worked
/// out for the days asked for, as the host does.
class FakeBackend implements CalendarBackend {
  FakeBackend({
    this.mac = const MacWindow('2025-10-13', '2028-10-13'),
    this.macOn = true,
    this.icloudOn = false,
    this.macStatus = 'fullAccess',
    List<EventOut>? macEvents,
    List<EventOut>? icloudEvents_,
  }) : macEvents = macEvents ?? octoberEvents(),
       icloudEventList = icloudEvents_ ?? icloudEvents();

  MacReads mac;
  bool macOn;
  bool icloudOn;
  String macStatus;
  List<EventOut> macEvents;
  List<EventOut> icloudEventList;

  /// The days asked for, in order.
  final eventCalls = <(DateTime, DateTime)>[];
  int calendarCalls = 0;

  /// While set, GET /events answers with this error (as the generated client throws it).
  Object? eventsError;

  /// While set, GET /calendars answers with this error.
  Object? calendarsError;

  @override
  Future<List<CalendarOut>> calendars() async {
    calendarCalls++;
    if (calendarsError case final e?) throw e;
    return _calendars();
  }

  List<CalendarOut> _calendars() => [
    if (macOn && mac is MacWindow) ...macCalendars,
    if (icloudOn) ...icloudCalendars,
  ];

  @override
  Future<List<SourceOut>> sources() async => [
    SourceOut(
      id: macId,
      kind: SourceOutKindEnum.mac,
      enabled: macOn,
      notesIncluded: false,
      calendarsStatus: macStatus,
    ),
    if (icloudOn)
      SourceOut(
        id: icloudId,
        kind: SourceOutKindEnum.icloud,
        enabled: true,
        notesIncluded: true,
        email: icloudEmail,
      ),
  ];

  @override
  Future<EventsOut> events(DateTime first, DateTime last) async {
    eventCalls.add((first, last));
    if (eventsError case final e?) throw e;
    final from = DateTime(first.year, first.month, first.day);
    final to = DateTime(last.year, last.month, last.day + 1);
    bool overlaps(EventOut e) {
      final s = DateTime.tryParse(e.start), en = DateTime.tryParse(e.end);
      // A row the host could not have written well is sent anyway, as a broken host might.
      if (s == null || en == null) return true;
      return s.isBefore(to) && en.isAfter(from);
    }

    final coverage = <CoverageOut>[];
    final events = <EventOut>[];
    if (macOn) {
      switch (mac) {
        case MacWindow(first: final a, last: final b):
          final wa = DateTime.parse(a), wb = DateTime.parse(b);
          coverage.add(CoverageOut(
            accountId: macId,
            source_: CoverageOutSource_Enum.mac,
            coveredStart: a,
            coveredEnd: b,
            complete: !wa.isAfter(from) && !wb.isBefore(DateTime(last.year, last.month, last.day)),
          ));
          events.addAll(macEvents.where(overlaps));
        case MacNothing(:final reason):
          coverage.add(CoverageOut(
            accountId: macId,
            source_: CoverageOutSource_Enum.mac,
            complete: false,
            reason: reason,
          ));
      }
    }
    if (icloudOn) {
      coverage.add(CoverageOut(accountId: icloudId, source_: CoverageOutSource_Enum.icloud, complete: true));
      events.addAll(icloudEventList.where(overlaps));
    }
    return EventsOut(events: events, coverage: coverage);
  }
}

/// Zones whose clock is [behind] this device's clock, whatever this device's zone is, so the captions are
/// the same on every machine: "10:00 to 11:00 New York time" for a 15:00 to 16:00 event.
class FakeZones implements ZoneOffsets {
  const FakeZones({this.behind = const Duration(hours: 5)});
  final Duration behind;

  @override
  Future<List<Duration?>> offsets(List<(String, DateTime)> requests) async => [
    for (final (_, at) in requests) at.toLocal().timeZoneOffset - behind,
  ];
}

/// Records where the app's buttons tried to lead.
class RecordingActions {
  final calls = <String>[];
  bool succeed = true;

  CalendarActions get actions => CalendarActions(
    openSources: () async {
      calls.add('sources');
      return succeed;
    },
    openCalendarPrivacy: () async {
      calls.add('privacy');
      return succeed;
    },
  );
}

/// Links as macOS would hand them over.
class FakeLinks {
  final controller = StreamController<MyDataLink>();
  Stream<MyDataLink> get stream => controller.stream;
  void open(String link) => controller.add(MyDataLink.parse(link)!);
}
