import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_page.dart';
import 'home.dart';
import 'mac_window.dart';

/// The myContacts app: the contacts the host mirrors from its sources (read-only), and the contacts the
/// host owns, which it creates, edits and deletes. It connects to the host (starting it if needed) and never
/// stops it: the host's lifetime belongs to the myData app.
///
/// It draws with the theme stored on the host (it arrives with every /status poll, so a theme chosen in
/// myData shows here within one poll) and this device's mode, and follows the system's reduced motion and
/// reduced transparency.
///
/// On a Mac (unless built with `--dart-define=MYDATA_MAC_LOOK=false`) it draws the Mac frame ([MacLook]):
/// the system font and the system's colours and accent ([MacSystemColorsScope], [MacTheme]), in the window
/// [MacWindow] sets up; this device's mode still chooses light or dark.
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

class _MyContactsAppState extends State<MyContactsApp> with WidgetsBindingObserver {
  late final _appearance = AppearanceController.forHost(widget.host, store: widget.store);
  final _mac = MacLook.forThisPlatform;

  /// The window is the key window (the app is active): selections are in the accent.
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _appearance.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appearance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _active) setState(() => _active = active);
  }

  @override
  void didChangePlatformBrightness() {
    if (_mac) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) {
      final theme = _appearance.theme;
      if (!_mac) return _app(theme.light, theme.dark, theme.themeMode);
      return MacSystemColorsScope(
        builder: (context, palette) {
          final brightness = switch (theme.themeMode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => MediaQuery.platformBrightnessOf(context),
          };
          MacWindow.follow(brightness);
          return _app(
            MacTheme.data(theme.spec.id, Brightness.light, palette.light),
            MacTheme.data(theme.spec.id, Brightness.dark, palette.dark),
            theme.themeMode,
          );
        },
      );
    },
  );

  Widget _app(ThemeData light, ThemeData dark, ThemeMode mode) => MaterialApp(
        title: 'myContacts',
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final content = MyDataAccessibilityScope(child: child ?? const SizedBox.shrink());
          return _mac ? MacWindow.chrome(windowActive: _active, child: content) : content;
        },
        home: ContactsHome(
          host: widget.host,
          backend: widget.backend,
          store: widget.store,
          links: widget.links,
          onOpenLink: widget.onOpenLink,
          menuPlatform: widget.menuPlatform,
          openLink: widget.openLink,
        ),
      );
}
