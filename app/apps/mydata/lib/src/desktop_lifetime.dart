import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Closing the window only hides it: the app keeps running, and the menu-bar (tray) icon opens the window again.
/// Quitting (the icon's menu, Cmd+Q, the app menu, logging out) quits the app only: the host is a login service
/// that outlives every app. The icon's menu has Stop host (POST /shutdown, which the host accepts only from myData
/// and the `mydata` command) and, once it is stopped, Start host.
class DesktopLifetime with WindowListener, TrayListener {
  DesktopLifetime._(this._controller);

  final HostController _controller;
  ({String key, String label, bool enabled})? _hostItem;

  static const _open = 'open';
  static const _stopHost = 'stop-host';
  static const _startHost = 'start-host';
  static const _quit = 'quit';

  static bool get supported =>
      !kIsWeb &&
      const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform);

  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static Future<void> start(HostController controller) async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('myData');
    final lifetime = DesktopLifetime._(controller);
    // Without a tray icon a hidden window could not be opened again, so closing it then quits as usual.
    if (!await lifetime._createTrayIcon()) return;
    controller.addListener(lifetime._updateMenu);
    await windowManager.setPreventClose(true);
    windowManager.addListener(lifetime);
  }

  /// Stop host while the host is running, Start host once it is not. While the app is still finding, starting or
  /// replacing it, or has nothing to start it with, the item says so instead and is disabled.
  static ({String key, String label, bool enabled}) hostItemFor(HostPhase phase) => switch (phase) {
    HostPhase.running => (key: _stopHost, label: 'Stop host', enabled: true),
    HostPhase.checking => (key: _startHost, label: 'Looking for the host…', enabled: false),
    HostPhase.starting => (key: _startHost, label: 'Starting the host…', enabled: false),
    HostPhase.restarting => (key: _startHost, label: 'Restarting the host…', enabled: false),
    HostPhase.notConfigured || HostPhase.unsupported => (key: _startHost, label: 'No host to start', enabled: false),
    _ => (key: _startHost, label: 'Start host', enabled: true),
  };

  Future<bool> _createTrayIcon() async {
    try {
      // macOS draws an 18 pt menu-bar icon, so the @2x file keeps it sharp. A template image follows the
      // menu bar's light or dark appearance.
      await trayManager.setIcon(
        _isMacOS ? 'assets/tray/tray_icon@2x.png' : 'assets/tray/tray_icon.png',
        isTemplate: _isMacOS,
      );
      if (defaultTargetPlatform != TargetPlatform.linux) await trayManager.setToolTip('myData');
      await _setMenu(hostItemFor(_controller.phase));
      trayManager.addListener(this);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _setMenu(({String key, String label, bool enabled}) host) async {
    _hostItem = host;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _open, label: 'Open myData'),
          MenuItem.separator(),
          MenuItem(key: host.key, label: host.label, disabled: !host.enabled),
          MenuItem.separator(),
          MenuItem(key: _quit, label: 'Quit myData'),
        ],
      ),
    );
  }

  /// The menu follows the host: rebuilt only when its host item changes, not on every status poll.
  void _updateMenu() {
    final host = hostItemFor(_controller.phase);
    if (host != _hostItem) _setMenu(host).ignore();
  }

  // Menu-bar icons open their menu on a click; Windows trays on a right click, and a click opens the app.
  @override
  void onTrayIconMouseDown() => _isMacOS ? trayManager.popUpContextMenu() : _show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _open:
        _show();
      case _stopHost:
        _controller.stopHost().ignore();
      case _startHost:
        _controller.connect().ignore();
      case _quit:
        _quitApp();
    }
  }

  @override
  void onWindowClose() => windowManager.hide();

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Quits the app only; the host keeps running.
  Future<void> _quitApp() async {
    _controller.removeListener(_updateMenu);
    trayManager.removeListener(this);
    await trayManager.destroy();
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
