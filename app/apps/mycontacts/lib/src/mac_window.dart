import 'dart:async';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';
import 'package:macos_window_utils/widgets/transparent_macos_sidebar.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The window of the Mac frame, through macos_window_utils (pinned in pubspec.yaml):
///
/// - a full-size content view under a transparent title bar, the title hidden, and a unified toolbar, so the
///   app draws its toolbar band where the title bar is and the window keeps dragging and double-click zoom
///   from the empty parts of the band;
/// - the window's own sidebar material behind the sidebar ([TransparentMacOSSidebar]), so it is translucent
///   and tinted by the desktop as the system's sidebars are;
/// - the window's appearance follows the app's mode, so the material matches a mode chosen in myData.
///
/// Why this package and not macos_ui: macos_ui is a whole widget set and theme of its own (it depends on this
/// one for the window). The People screen keeps mydata_ui's widgets and tokens; it needs the window only.
abstract final class MacWindow {
  static bool _ready = false;
  static Brightness? _brightness;

  /// Sets the window up; call before runApp, on macOS with the Mac frame on.
  static Future<void> setUp() async {
    await WindowManipulator.initialize();
    await WindowManipulator.makeTitlebarTransparent();
    await WindowManipulator.enableFullSizeContentView();
    await WindowManipulator.hideTitle();
    await WindowManipulator.addToolbar();
    await WindowManipulator.setToolbarStyle(toolbarStyle: NSWindowToolbarStyle.unified);
    _ready = true;
  }

  /// The window's appearance (and so its materials) in [brightness].
  static void follow(Brightness brightness) {
    if (!_ready || brightness == _brightness) return;
    _brightness = brightness;
    unawaited(WindowManipulator.overrideMacOSBrightness(dark: brightness == Brightness.dark));
  }

  /// The chrome the Mac widgets use, around [child].
  static Widget chrome({required bool windowActive, required Widget child}) {
    if (!_ready) return MacChrome(windowActive: windowActive, child: child);
    return MacosToolbarPassthroughScope(
      child: MacChrome(
        windowActive: windowActive,
        toolbarItem: _passthrough,
        sidebar: _sidebar,
        child: child,
      ),
    );
  }

  static Widget _passthrough(Widget child) => MacosToolbarPassthrough(child: child);

  static Widget _sidebar(Widget child) => TransparentMacOSSidebar(child: child);
}
