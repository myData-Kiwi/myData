import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:mydata_core/mydata_core.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The myData app owns the host's lifetime. Closing the window only hides it: the app and the host keep
/// running. The menu-bar (tray) icon opens the window again. Quitting, from the icon's menu or with the
/// system's Quit (Cmd+Q, the app menu, logging out), stops the host, then the app.
class DesktopLifetime with WindowListener, TrayListener {
  DesktopLifetime._(this._controller);

  final HostController _controller;
  AppLifecycleListener? _exitListener;
  bool _quitting = false;

  static const _open = 'open';
  static const _quit = 'quit';

  static bool get supported =>
      !kIsWeb &&
      const {TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}.contains(defaultTargetPlatform);

  static bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  static Future<void> start(HostController controller) async {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('myData');
    final lifetime = DesktopLifetime._(controller);
    // The system's Quit asks the app first: stop the host, then let it exit.
    lifetime._exitListener = AppLifecycleListener(onExitRequested: () async {
      await lifetime._stopHostOnce();
      return AppExitResponse.exit;
    });
    // Without a tray icon a hidden window could not be opened again, so closing it then quits as usual.
    if (!await lifetime._createTrayIcon()) return;
    await windowManager.setPreventClose(true);
    windowManager.addListener(lifetime);
  }

  Future<bool> _createTrayIcon() async {
    try {
      // macOS draws an 18 pt menu-bar icon, so the @2x file keeps it sharp. A template image follows the
      // menu bar's light or dark appearance.
      await trayManager.setIcon(_isMacOS ? 'assets/tray/tray_icon@2x.png' : 'assets/tray/tray_icon.png',
          isTemplate: _isMacOS);
      if (defaultTargetPlatform != TargetPlatform.linux) await trayManager.setToolTip('myData');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: _open, label: 'Open myData'),
        MenuItem.separator(),
        MenuItem(key: _quit, label: 'Quit myData'),
      ]));
      trayManager.addListener(this);
      return true;
    } on Object {
      return false;
    }
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

  /// If the host is already gone there is nothing to stop; quit anyway.
  Future<void> _stopHostOnce() async {
    if (_quitting) return;
    _quitting = true;
    await _controller.stopHost();
  }

  Future<void> _quitApp() async {
    await _stopHostOnce();
    _exitListener?.dispose();
    trayManager.removeListener(this);
    await trayManager.destroy();
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
