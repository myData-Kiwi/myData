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
class MyAssistantApp extends StatefulWidget {
  const MyAssistantApp({super.key, required this.host, this.store, this.backend});

  /// This app's view of the host, made with `app: 'myassistant'`. The app connects and disposes it.
  final HostController host;

  /// Where this device keeps its mode; null uses the device's own file. Tests pass a [MemoryDeviceStore].
  final DeviceStore? store;

  /// The chat's way to the host; null uses the host's API. Tests pass a fake.
  final AssistantBackend? backend;

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
      final theme = _appearance.theme;
      return MaterialApp(
        title: 'myAssistant',
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: theme.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MyDataAccessibilityScope(child: child ?? const SizedBox.shrink()),
        home: AssistantHome(host: widget.host, backend: widget.backend),
      );
    },
  );
}
