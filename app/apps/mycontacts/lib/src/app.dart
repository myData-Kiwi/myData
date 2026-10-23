import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_page.dart';
import 'home.dart';

/// The myContacts app: the contacts the host mirrors from its sources (read-only), and the contacts the
/// host owns, which it creates, edits and deletes. It connects to the host (starting it if needed) and never
/// stops it: the host's lifetime belongs to the myData app.
///
/// It draws with the theme stored on the host (it arrives with every /status poll, so a theme chosen in
/// myData shows here within one poll) and this device's mode, and follows the system's reduced motion and
/// reduced transparency.
///
/// On a Mac it draws the Mac frame ([MacLook]): the system font and the system's colours and accent
/// ([MacShell]); this device's mode still chooses light or dark.
class MyContactsApp extends StatefulWidget {
  const MyContactsApp({
    super.key,
    required this.host,
    this.store,
    this.backend,
    this.links,
    this.onOpenLink,
    this.menuPlatform,
    this.openLink,
  });

  /// Opens a link in another app (File > Import… opens myData's Import); null uses [appLinks]. Tests pass a
  /// fake.
  final Future<bool> Function(MyDataLink link)? openLink;

  /// This app's view of the host, made with `app: 'mycontacts'`. The app connects and disposes it.
  final HostController host;

  /// Where this device keeps its mode and the contact last opened; null uses the device's own file. Tests
  /// pass a [MemoryDeviceStore].
  final DeviceStore? store;

  /// The way to the host's contacts; null uses the host's API. Tests pass a fake.
  final ContactsBackend? backend;

  /// Links this app was opened with; null listens to macOS ([IncomingLinks]). Tests pass a stream.
  final Stream<MyDataLink>? links;

  /// Opens a contact's web address in the browser; null uses the system's. Tests pass a fake.
  final WebOpener? onOpenLink;

  /// The platform the menu bar is built for; null is the one the app runs on. Tests pass one.
  final TargetPlatform? menuPlatform;

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
    builder: (context, _) => MacShell(
      theme: _appearance.theme,
      appIcon: MyDataAppIcons.mycontacts,
      builder: (context, light, dark, mode) => MaterialApp(
        title: 'myContacts',
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        debugShowCheckedModeBanner: false,
        builder: MacShell.content,
        home: ContactsHome(
          host: widget.host,
          backend: widget.backend,
          store: widget.store,
          links: widget.links,
          onOpenLink: widget.onOpenLink,
          menuPlatform: widget.menuPlatform,
          openLink: widget.openLink,
        ),
      ),
    ),
  );
}
