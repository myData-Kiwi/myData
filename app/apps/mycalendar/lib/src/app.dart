import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'home.dart';

/// The myCalendar app: a month of the user's calendars, as the host reads them, and which calendars this
/// device shows. Read-only. It connects to the host (starting it if needed) and never stops it: the host's
/// lifetime belongs to the myData app.
///
/// It draws with the theme stored on the host and this device's mode, as every myData app does, and
/// follows the system's reduced motion and reduced transparency. On a Mac it draws the Mac frame
/// ([MacShell]): the system's window, font, colours and accent; this device's mode still chooses light or
/// dark.
class MyCalendarApp extends StatefulWidget {
  const MyCalendarApp({
    super.key,
    required this.host,
    this.store,
    this.backend,
    this.zones = const ChannelZoneOffsets(),
    this.links,
    this.actions = const CalendarActions(),
    this.now,
  });

  /// This app's view of the host, made with `app: 'mycalendar'`. The app connects and disposes it.
  final HostController host;

  /// Where this device keeps its mode and its hidden calendars; null uses the device's own file. Tests
  /// pass a [MemoryDeviceStore].
  final DeviceStore? store;

  /// The host's calendars and events; null uses the host's API. Tests pass a fake.
  final CalendarBackend? backend;

  /// Time zone offsets for events set in another zone.
  final ZoneOffsets zones;

  /// Links other apps opened this one with ([IncomingLinks.links]).
  final Stream<MyDataLink>? links;

  final CalendarActions actions;

  /// The clock for "Last updated at"; null is the device's.
  final DateTime Function()? now;

  @override
  State<MyCalendarApp> createState() => _MyCalendarAppState();
}

class _MyCalendarAppState extends State<MyCalendarApp> {
  late final _themes = ThemeController.forHost(MyDataAppId.mycalendar, widget.host, store: widget.store);
  late final _visibility = CalendarVisibility(store: widget.store);

  @override
  void initState() {
    super.initState();
    _themes.start();
    _visibility.start();
  }

  @override
  void dispose() {
    _themes.dispose();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _themes,
    builder: (context, _) => ThemeScope(
      themes: _themes,
      app: MyDataAppId.mycalendar,
      child: MacShell(
        theme: _themes.theme,
        appIcon: MyDataAppIcons.mycalendar,
        builder: (context, light, dark, mode) => MaterialApp(
          title: 'myCalendar',
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          // A theme change is drawn at once, in one rebuild: no lerp of type through in-between sizes and
          // fonts (design/themes/ARCHITECTURE.md 3.5).
          themeAnimationDuration: MyDataTheme.switchDuration,
          debugShowCheckedModeBanner: false,
          builder: MacShell.content,
          home: Builder(
            builder: (context) => AppMenuBar(
              appName: 'myCalendar',
              onTheme: () => showAppThemeGallery(context),
              child: CalendarHome(
                host: widget.host,
                visibility: _visibility,
                backend: widget.backend,
                zones: widget.zones,
                links: widget.links,
                actions: widget.actions,
                now: widget.now,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
