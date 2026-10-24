import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'calendar_model.dart';
import 'calendars_page.dart';
import 'mac_calendar_list.dart';
import 'mac_month_view.dart';
import 'month_content.dart';
import 'month_page.dart';

/// Where the app's buttons lead outside it. Tests pass fakes that record the calls.
class CalendarActions {
  const CalendarActions({this.openSources = openMyDataSources, this.openCalendarPrivacy = _openPrivacy});

  /// The myData app at Settings, Sources (`mydata://settings/sources`).
  final Future<bool> Function() openSources;

  /// System Settings at Privacy & Security, Calendars.
  final Future<bool> Function() openCalendarPrivacy;

  static Future<bool> _openPrivacy() => macSystem.open(PrivacyPane.calendars);
}

/// The app's one window, in the app's frame: a panel for every state of the host, an empty screen while no
/// source is on, and otherwise the Month and Calendars sections. The web build, which cannot reach a host,
/// shows only its panel, without the frame.
///
/// While the host cannot be reached, what was already read stays on screen (design/platforms.md, "Offline
/// and errors"): the frame's warning line says the host cannot be reached, with the time the calendars were
/// last read, and nothing is asked of the host until it is back.
class CalendarHome extends StatefulWidget {
  const CalendarHome({
    super.key,
    required this.host,
    required this.visibility,
    this.backend,
    this.zones = const ChannelZoneOffsets(),
    this.links,
    this.actions = const CalendarActions(),
    this.refreshInterval = const Duration(seconds: 30),
    this.now,
  });

  final HostController host;

  /// Which calendars this device hides.
  final CalendarVisibility visibility;

  /// The host's calendars and events; null uses the host's API through [host]'s connection.
  final CalendarBackend? backend;
  final ZoneOffsets zones;

  /// Links other apps opened this one with (`mycalendar://day/<date>`).
  final Stream<MyDataLink>? links;

  final CalendarActions actions;

  /// How often the calendars and the month on screen are read again while the app is open.
  final Duration refreshInterval;

  /// The clock for "Last updated at"; null is the device's. Screenshots pass a fixed one.
  final DateTime Function()? now;

  static const appName = 'myCalendar';
  static const sections = [
    AppSection(icon: MyDataIcon.calendarMonth, label: MonthPage.title),
    AppSection(icon: MyDataIcon.layers, label: CalendarsPage.title),
  ];

  static const emptyTitle = 'No calendars yet';
  static const emptySentence =
      'Turn on This Mac or an iCloud account in myData, under Settings, Sources, and your calendars appear here.';
  static const openMyData = 'Open myData';

  static const openMyDataFailed = 'myCalendar could not open myData from here. Open the myData app yourself.';
  static const openSettingsFailed =
      'myCalendar could not open System Settings. Open it yourself, then Privacy & Security, Calendars.';

  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome> {
  late final CalendarData _data = CalendarData(
    backend: widget.backend ?? HostCalendarBackend(() => widget.host.connection),
    zones: widget.zones,
    now: widget.now,
  );
  final _gridFocus = FocusNode(debugLabel: 'Month grid');

  int _section = 0;
  DateTime? _month;
  DateTime? _selected;

  /// A day a link asked for before the host answered; shown once it does.
  DateTime? _pendingDay;

  Timer? _refresh;
  StreamSubscription<MyDataLink>? _linkSub;

  /// What the host's mode and epoch were at the last read: a change means a source was turned on or off.
  (StatusOutModeEnum, int)? _hostState;
  bool _wasRunning = false;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.addListener(_followHost);
    _data.addListener(_onData);
    widget.visibility.addListener(_onData);
    _linkSub = widget.links?.listen(_onLink);
    _host.connect();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _linkSub?.cancel();
    _host.removeListener(_followHost);
    _data.removeListener(_onData);
    widget.visibility.removeListener(_onData);
    _data.dispose();
    _gridFocus.dispose();
    _host.dispose();
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  /// Today on the host (the device, while the host is localhost-only).
  DateTime get _today => hostDate(_host.status?.today) ?? dateOnly(DateTime.now());

  void _followHost() {
    final running = _host.phase == HostPhase.running && _host.status != null;
    if (!running) {
      _wasRunning = false;
      _refresh?.cancel();
      return;
    }
    final status = _host.status!;
    final state = (status.mode, status.conversationEpoch);
    final changed = _hostState != null && _hostState != state;
    _hostState = state;
    if (_selected == null) {
      final day = _pendingDay ?? _today;
      _pendingDay = null;
      _selected = day;
      _month = monthOf(day);
    }
    if (changed) _data.clearMonths();
    if (!_wasRunning || changed) {
      _wasRunning = true;
      _data.refresh();
      _refresh?.cancel();
      _refresh = Timer.periodic(widget.refreshInterval, (_) => _data.refresh());
    }
  }

  void _onLink(MyDataLink link) {
    if (link is! OpenDay) return;
    setState(() {
      _section = 0;
      if (_selected == null) {
        _pendingDay = link.date;
      } else {
        _selected = link.date;
        _month = monthOf(link.date);
      }
    });
  }

  Future<void> _openMyData() async {
    final opened = await _host.platform.openMyDataApp(setup: false).catchError((Object _) => false);
    if (!mounted || opened) return;
    _say(CalendarHome.openMyDataFailed);
  }

  Future<void> _openSources() async {
    final opened = await widget.actions.openSources().catchError((Object _) => false);
    if (!mounted || opened) return;
    _say(CalendarHome.openMyDataFailed);
  }

  Future<void> _noticeAction(NoticeAction action) async {
    switch (action) {
      case NoticeAction.none:
        return;
      case NoticeAction.openMyData:
        return _openSources();
      case NoticeAction.openSystemSettings:
        final opened = await widget.actions.openCalendarPrivacy().catchError((Object _) => false);
        if (!mounted || opened) return;
        _say(CalendarHome.openSettingsFailed);
    }
  }

  void _say(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _host,
    builder: (context, _) {
      if (MacWindow.of(context)) return _macFrame(context);
      return Scaffold(
        backgroundColor: context.colors.bg,
        body: switch (_connection()) {
          null => _body(context),
          final connection => AppFrame(
            appName: CalendarHome.appName,
            sections: CalendarHome.sections,
            current: _section,
            onSelect: (i) => setState(() => _section = i),
            connection: connection,
            child: _body(context),
          ),
        },
      );
    },
  );

  /// The Mac frame ([MacWindow.of]), as Calendar.app's window: the calendar list in the translucent sidebar (with
  /// the host's state at its bottom when something is wrong), and the month under its own toolbar
  /// ([MacMonthView]). Every other state (starting, an error, no source on) fills the window under an empty
  /// toolbar band, with no sidebar: there is nothing to list, and the state says what is wrong once.
  /// The Calendars section is the sidebar here, so the frame has no sections.
  Widget _macFrame(BuildContext context) {
    final body = _body(context);
    final calendars = _data.calendars;
    final listed = calendars != null && _data.anySourceOn != false;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MacSidebarFrame(
        connection: _connection(),
        sidebar: listed ? MacCalendarList(calendars: calendars, visibility: widget.visibility) : null,
        child: body is MacMonthView
            ? body
            : MacPane(toolbar: MacToolbar(windowControls: !listed), child: body),
      ),
    );
  }

  AppConnection? _connection() => switch (_host.phase) {
    HostPhase.checking || HostPhase.starting || HostPhase.restarting => const AppConnection.starting(),
    HostPhase.running => AppConnection.connected(onOpenMyData: _openMyData),
    HostPhase.notConfigured ||
    HostPhase.failedToStart ||
    HostPhase.unreachable ||
    HostPhase.refused ||
    HostPhase.incompatible ||
    HostPhase.lost => AppConnection.unreachable(
      onRetry: _host.retry,
      lastUpdated: _keepsShowing ? _lastUpdated() : null,
    ),
    HostPhase.unsupported => null,
  };

  /// The host cannot be reached, and what was read before stays on screen.
  bool get _keepsShowing => switch (_host.phase) {
    HostPhase.notConfigured ||
    HostPhase.failedToStart ||
    HostPhase.unreachable ||
    HostPhase.refused ||
    HostPhase.incompatible ||
    HostPhase.lost => _data.ready && _selected != null && _month != null,
    _ => false,
  };

  String? _lastUpdated() {
    final at = _data.updatedAt;
    if (at == null) return null;
    return 'Last updated at ${MyDataDates.time(at)}.';
  }

  Widget _body(BuildContext context) {
    if (_keepsShowing) return _content(context, online: false);
    final status = _host.status;
    return switch (_host.phase) {
      HostPhase.checking => const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Looking for the myData host',
        message: 'Connecting to the host on this computer.',
      ),
      HostPhase.starting => const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Starting the myData host',
        message: 'This can take a few seconds.',
      ),
      HostPhase.restarting => const StatusPanel(
        kind: StatusPanelKind.working,
        title: HostController.restartingTitle,
        message: HostController.restartingMessage,
      ),
      HostPhase.notConfigured => _failure('The myData host is not set up'),
      HostPhase.failedToStart => _failure('The myData host did not start'),
      HostPhase.unreachable => _failure(AppConnection.unreachableText),
      HostPhase.refused => _failure('The myData host refused this app'),
      HostPhase.incompatible => _failure('The myData host is from another build'),
      HostPhase.lost => _failure(AppConnection.lostText),
      HostPhase.unsupported => StatusPanel(
        kind: StatusPanelKind.info,
        title: 'myCalendar needs the desktop app',
        message: _host.error ?? 'Open myCalendar on the computer that runs the myData host.',
      ),
      HostPhase.running when status == null || _selected == null => const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Looking for the myData host',
        message: 'Waiting for its status.',
      ),
      HostPhase.running => _content(context),
    };
  }

  /// The sections. Not [online]: the host cannot be reached, so nothing is fetched and no read error is
  /// shown (the frame's warning line says it).
  Widget _content(BuildContext context, {bool online = true}) {
    if (!_data.ready) {
      if (_data.error != null) {
        return StatusPanel(
          kind: StatusPanelKind.error,
          title: 'myCalendar could not read your calendars',
          message: '${_data.error} Try again in a moment.',
          actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _data.refresh)],
        );
      }
      return const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Reading your calendars',
        message: 'This takes a moment.',
      );
    }
    if (_data.anySourceOn == false) {
      return Padding(
        padding: EdgeInsets.all(context.space(8)),
        child: EmptyState(
          title: CalendarHome.emptyTitle,
          sentence: CalendarHome.emptySentence,
          actionLabel: CalendarHome.openMyData,
          onAction: _openSources,
        ),
      );
    }
    final mac = MacWindow.of(context);
    if (_section == 1 && !mac) {
      return CalendarsPage(calendars: _data.calendars!, visibility: widget.visibility);
    }

    final firstDay = MonthGrid.firstDayOfWeekFor(View.of(context).platformDispatcher.locale);
    final month = _month!;
    final days = MonthPage.visibleDays(month, firstDay);
    // This month's six weeks, and the months either side, so the previous and next buttons show their
    // events at once.
    if (online) {
      _data.ensure(days.first, days.last);
      for (final m in [DateTime(month.year, month.month - 1), DateTime(month.year, month.month + 1)]) {
        final d = MonthPage.visibleDays(m, firstDay);
        _data.ensure(d.first, d.last);
      }
    }
    if (mac) {
      return MacMonthView(
        content: MonthContent.of(
          data: _data,
          hidden: widget.visibility.hidden,
          month: month,
          firstDayOfWeek: firstDay,
          online: online,
          onNoticeAction: _noticeAction,
        ),
        today: _today,
        month: month,
        selected: _selected!,
        firstDayOfWeek: firstDay,
        onSelected: (d) => setState(() => _selected = d),
        onMonthChanged: (m) => setState(() => _month = monthOf(m)),
        gridFocusNode: _gridFocus,
        onRetry: online ? _data.refresh : null,
      );
    }
    return MonthPage(
      data: _data,
      hidden: widget.visibility.hidden,
      today: _today,
      month: month,
      selected: _selected!,
      firstDayOfWeek: firstDay,
      onSelected: (d) => setState(() => _selected = d),
      onMonthChanged: (m) => setState(() => _month = monthOf(m)),
      onNoticeAction: _noticeAction,
      gridFocusNode: _gridFocus,
      onRetry: online ? _data.refresh : null,
    );
  }

  Widget _failure(String title) => StatusPanel(
    kind: StatusPanelKind.error,
    title: title,
    message: _host.error ?? 'Something went wrong while connecting.',
    detail: _host.detail,
    actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _host.retry)],
  );
}
