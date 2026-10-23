import 'package:flutter/widgets.dart';

/// What the app's window gives the Mac frame's widgets. This package has no platform plugins, so the app
/// (which sets up the window: full-size content, a unified toolbar, a translucent sidebar) passes these in.
///
/// - [toolbarItem] wraps a control drawn in the toolbar band, so clicks reach it rather than the window's
///   title bar, which takes the rest of the band for dragging and double-click zoom. Identity outside a
///   real window.
/// - [sidebar] wraps the sidebar's area in the window's own translucent material (vibrancy); null: the
///   sidebar is not translucent and paints `sidebar-background` itself.
/// - [windowActive]: the window is the key window. When it is not, selections turn grey and the sidebar's
///   icons lose the accent, as the system does.
class MacChrome extends InheritedWidget {
  const MacChrome({
    super.key,
    this.toolbarItem = _identity,
    this.sidebar,
    this.windowActive = true,
    required super.child,
  });

  final Widget Function(Widget child) toolbarItem;
  final Widget Function(Widget child)? sidebar;
  final bool windowActive;

  static Widget _identity(Widget child) => child;

  /// No window around the widgets (tests, screenshots): nothing to wrap, a solid sidebar, an active window.
  static const none = MacChrome(child: SizedBox.shrink());

  static MacChrome of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MacChrome>() ?? none;

  @override
  bool updateShouldNotify(MacChrome old) =>
      old.windowActive != windowActive || old.sidebar != sidebar || old.toolbarItem != toolbarItem;
}
