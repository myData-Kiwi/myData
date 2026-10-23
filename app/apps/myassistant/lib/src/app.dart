import 'package:flutter/material.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'home.dart';

/// The myAssistant app. It connects to the host (starting it if needed) and never stops it: the host's
/// lifetime belongs to the myData app.
///
/// It draws with the theme stored on the host (it arrives with every /status poll, so a theme chosen in
/// myData shows here within one poll) and this device's mode (re-read from the device store on the same
/// interval), and follows the system's reduced motion and reduced transparency.
///
/// On a Mac it draws the Mac frame ([MacShell], [MacWindow.of]): the system's window, translucent sidebar, font,
/// colours and accent; this device's mode still chooses light or dark. Elsewhere the branded frame.
class MyAssistantApp extends StatefulWidget {
  const MyAssistantApp({super.key, required this.host, this.store, this.backend, this.apps, this.openLink});

  /// This app's view of the host, made with `app: 'myassistant'`. The app connects and disposes it.
  final HostController host;

  /// Where this device keeps its mode; null uses the device's own file. Tests pass a [MemoryDeviceStore].
  final DeviceStore? store;

  /// The chat's way to the host; null uses the host's API. Tests pass a fake.
  final AssistantBackend? backend;

  /// Whether myContacts and myCalendar are installed; null looks them up on this Mac. Tests pass one.
  final InstalledApps? apps;

  /// Opens a link in its app; null uses [appLinks]. Tests pass a fake.
  final Future<bool> Function(MyDataLink link)? openLink;

  @override
  State<MyAssistantApp> createState() => _MyAssistantAppState();
}

class _MyAssistantAppState extends State<MyAssistantApp> {
  late final _appearance = AppearanceController.forHost(widget.host, store: widget.store);

  @override
  void initState() {
    super.initState();
    _appearance.start();
  }

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) {
      return MacShell(
        theme: _appearance.theme,
        appIcon: MyDataAppIcons.myassistant,
        builder: (context, light, dark, mode) => MaterialApp(
          title: 'myAssistant',
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          debugShowCheckedModeBanner: false,
          builder: MacShell.content,
          home: AssistantHome(host: widget.host, backend: widget.backend, apps: widget.apps, openLink: widget.openLink),
        ),
      );
    },
  );
}
