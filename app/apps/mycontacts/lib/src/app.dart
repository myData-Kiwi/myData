import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_page.dart';
import 'home.dart';

/// The myContacts app: the contacts the host mirrors from its sources, read-only. It connects to the host
/// (starting it if needed) and never stops it: the host's lifetime belongs to the myData app.
///
/// It draws with the theme stored on the host (it arrives with every /status poll, so a theme chosen in
/// myData shows here within one poll) and this device's mode, and follows the system's reduced motion and
/// reduced transparency.
class MyContactsApp extends StatefulWidget {
  const MyContactsApp({
    super.key,
    required this.host,
    this.store,
    this.backend,
    this.links,
    this.openMyDataSources,
    this.onOpenLink,
  });

  /// This app's view of the host, made with `app: 'mycontacts'`. The app connects and disposes it.
  final HostController host;

  /// Where this device keeps its mode and the contact last opened; null uses the device's own file. Tests
  /// pass a [MemoryDeviceStore].
  final DeviceStore? store;

  /// The way to the host's contacts; null uses the host's API. Tests pass a fake.
  final ContactsBackend? backend;

  /// Links this app was opened with; null listens to macOS ([IncomingLinks]). Tests pass a stream.
  final Stream<MyDataLink>? links;

  /// Opens myData at Settings, Sources; null uses mydata_core's. Tests pass a fake.
  final OpenMyData? openMyDataSources;

  /// Opens a contact's web address in the browser; null uses the system's. Tests pass a fake.
  final WebOpener? onOpenLink;

  @override
  State<MyContactsApp> createState() => _MyContactsAppState();
}

class _MyContactsAppState extends State<MyContactsApp> {
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
        title: 'myContacts',
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: theme.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MyDataAccessibilityScope(child: child ?? const SizedBox.shrink()),
        home: ContactsHome(
          host: widget.host,
          backend: widget.backend,
          store: widget.store,
          links: widget.links,
          openMyDataSources: widget.openMyDataSources,
          onOpenLink: widget.onOpenLink,
        ),
      );
    },
  );
}
