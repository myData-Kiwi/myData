import 'package:flutter/material.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../theme/choice.dart';
import '../theme/theme.dart';
import '../widgets/app_frame.dart' show AppConnection, AppSection;
import '../widgets/edges.dart' show CardEdge;
import '../widgets/pressable.dart' show MyDataRadii;
import '../widgets/window_ground.dart';
import 'mac_overlays.dart' show MacAppIcon;
import 'mac_source_list.dart';
import 'mac_system_colors.dart';
import 'mac_theme.dart';
import 'mac_toolbar.dart';
import 'mac_window.dart';

/// The Mac shell: what every app needs to draw the Mac frame on macOS (the system's window, toolbar band,
/// translucent sidebar, font, colours, accent and focus ring) and its branded frame everywhere else
/// (design/platforms.md). Three calls:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await MacShell.setUp(); // the window, on macOS only
///   runApp(const MyApp());
/// }
///
/// // Above the MaterialApp; `themes` is mydata_core's ThemeController.
/// MacShell(
///   theme: themes.theme,
///   builder: (context, light, dark, mode) => MaterialApp(
///     theme: light,
///     darkTheme: dark,
///     themeMode: mode,
///     builder: MacShell.content, // accessibility, and the window's chrome on macOS
///     home: ...,
///   ),
/// );
/// ```
///
/// The Runner copies `macos_snippets/MacShell.swift` (its header says how). Screens then branch on
/// [MacWindow.of]: in the Mac frame, [MacAppFrame] with [MacPane]s; elsewhere AppFrame as before.
class MacShell extends StatelessWidget {
  const MacShell({super.key, required this.theme, required this.builder, this.appIcon});

  /// The app's theme (its choice and this device's mode). On macOS, System is the system's own colours,
  /// accent and font; a drawn theme is drawn inside the Mac window ([MacTheme.forChoice]).
  final MyDataTheme theme;

  /// The app's own icon ([MyDataAppIcons]), which its alerts show ([MacAppIcon]); null shows the kiwi.
  final ImageProvider? appIcon;

  /// Builds the MaterialApp with these themes and mode.
  final Widget Function(BuildContext context, ThemeData light, ThemeData dark, ThemeMode mode) builder;

  /// Sets the window up on macOS (a no-op elsewhere). Call it after `WidgetsFlutterBinding.ensureInitialized`
  /// and before runApp.
  static Future<void> setUp() async {
    if (MacLook.forThisPlatform) await MacWindow.setUp();
  }

  /// For MaterialApp's `builder`: the system's reduced motion and transparency (MyDataAccessibilityScope)
  /// around every route, and on macOS the window's chrome ([MacChrome]: toolbar items that take clicks, the
  /// sidebar's material, whether the window is active).
  static Widget content(BuildContext context, Widget? child) => _ShellContent(child: child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    if (!MacLook.forThisPlatform) return builder(context, theme.light, theme.dark, theme.themeMode);
    return MacAppIcon(icon: appIcon, child: _frame());
  }

  /// The ThemeData an app draws [choice] in, for [brightness], as this shell would: on a Mac with the
  /// system's colours read by the shell above [context] (System) or inside the Mac window (a drawn theme);
  /// elsewhere [MyDataTheme.dataFor]. The theme gallery draws its cards with it.
  static ThemeData themeDataFor(BuildContext context, ThemeChoice choice, Brightness brightness) {
    if (!MacLook.forThisPlatform) return MyDataTheme.dataFor(choice, brightness);
    final palette = context.getInheritedWidgetOfExactType<_MacPaletteScope>()?.palette ?? MacSystemPalette.fallback;
    return MacTheme.forChoice(choice, brightness, brightness == Brightness.dark ? palette.dark : palette.light);
  }

  Widget _frame() {
    return MacSystemColorsScope(
      builder: (context, palette) {
        final brightness = switch (theme.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        MacWindow.follow(brightness);
        return _MacPaletteScope(
          palette: palette,
          child: builder(
            context,
            MacTheme.forChoice(theme.choice, Brightness.light, palette.light),
            MacTheme.forChoice(theme.choice, Brightness.dark, palette.dark),
            theme.themeMode,
          ),
        );
      },
    );
  }
}

/// The system's colours the shell read, for [MacShell.themeDataFor].
class _MacPaletteScope extends InheritedWidget {
  const _MacPaletteScope({required this.palette, required super.child});

  final MacSystemPalette palette;

  @override
  bool updateShouldNotify(_MacPaletteScope old) => old.palette != palette;
}

/// Follows whether the app is active (its window is the key window), for [MacChrome.windowActive].
class _ShellContent extends StatefulWidget {
  const _ShellContent({required this.child});

  final Widget child;

  @override
  State<_ShellContent> createState() => _ShellContentState();
}

class _ShellContentState extends State<_ShellContent> with WidgetsBindingObserver {
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active != _active) setState(() => _active = active);
  }

  @override
  Widget build(BuildContext context) {
    final content = MyDataAccessibilityScope(child: widget.child);
    return MacLook.forThisPlatform ? MacWindow.chrome(windowActive: _active, child: content) : content;
  }
}

/// The Mac frame's window: the sidebar ([MacSourceList], the app's [sections] and the host's state when
/// something is wrong), then [child] on `content-background`. With no [connection] (a build that cannot have
/// a host) [child] alone. Put it in a Scaffold with a transparent background, so the sidebar's material
/// shows; [child] is usually a [MacPane], or the app's own columns each with a toolbar band.
class MacAppFrame extends StatelessWidget {
  const MacAppFrame({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.connection,
    required this.child,
    this.showConnection = true,
  });

  /// False while [child] says the host cannot be reached, with its Retry: the sidebar's line would say it
  /// again ([MacSourceList.showConnection]).
  final bool showConnection;

  /// The app's own sections, as in AppFrame; their icons by meaning ([MyDataIcon]).
  final List<AppSection> sections;
  final int current;
  final ValueChanged<int> onSelect;
  final AppConnection? connection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = MacContentGround(child: child);
    final c = connection;
    if (c == null) return content;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // macOS 26's floating sidebar panel has no divider beside it.
        MacSourceList(
          sections: sections,
          current: current,
          onSelect: onSelect,
          connection: c,
          showConnection: showConnection,
        ),
        Expanded(child: content),
      ],
    );
  }
}

/// The ground of the Mac frame's content column: `content-background` (the system's, or a drawn theme's
/// `surface`), or, for a drawn theme whose window is a gradient or a pattern (Frosted, Paperback), that
/// window ground ([WindowGround]), so the theme's material is drawn in the Mac window as in the branded frame;
/// and the window ground too where the panes are panels on it ([MacPanel]: Retro Desktop's dotted desk,
/// Brutalist's poster ground). Never under the sidebar, whose panel keeps the window's own material.
class MacContentGround extends StatelessWidget {
  const MacContentGround({super.key, required this.child});
  final Widget child;

  /// Whether [look]'s content column shows its window ground rather than `content-background`.
  static bool drawsMaterial(MyDataLook look) =>
      look.frame != LookFrame.system && (look.materials.spec.window != WindowKind.solid || MacPanel.drawn(look));

  @override
  Widget build(BuildContext context) => drawsMaterial(context.look)
      ? WindowGround(child: child)
      : ColoredBox(color: context.mac.contentBackground, child: child);
}

/// One column of the Mac frame: its [toolbar] band (`toolbar-height`) over [child].
class MacPane extends StatelessWidget {
  const MacPane({super.key, required this.toolbar, required this.child});

  final MacToolbar toolbar;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [toolbar, Expanded(child: child)],
  );
}

/// A pane of the Mac window (a list, a record, a month, a day) as a panel on the window's ground, in a drawn
/// theme whose lists are bordered panels with a slab's depth: Retro Desktop's bevelled grey windows on its
/// dotted desk ("Lists: bordered panels on the desk"; the dots never under a panel) and Brutalist's boxes on
/// its poster ground, each with its hard offset shadow. The panel is the theme's card: `surface`, its corners,
/// its card edge (and bevel) and its resting shadow, [gutter] in from the pane's edges, so the ground shows
/// between panes. The window's skeleton (its columns and their widths) stays the Mac's. Anywhere else, and
/// in System, [child] as it is.
class MacPanel extends StatelessWidget {
  const MacPanel({super.key, required this.child});

  final Widget child;

  /// Whether [look] draws its panes as panels: a drawn look whose lists are bordered and whose depth is a
  /// slab's (an offset shadow or a bevel).
  static bool drawn(MyDataLook look) =>
      look.frame != LookFrame.system &&
      look.variants.list == ListStyle.bordered &&
      (look.elevation.style == ElevationStyle.offset || look.elevation.style == ElevationStyle.bevel);

  /// Whether the panes are panels here: [drawn] in the Mac window, never in System. A column's divider is
  /// then left out, since the ground between the panels divides them.
  static bool shown(BuildContext context) => !context.isSystemLook && drawn(context.look);

  /// The drop under a Mac control in a theme whose panes are panels (Brutalist's offset shadow, Retro
  /// Desktop's 2 px drop), gone while it is [pressed] where the theme collapses it; none elsewhere.
  static List<BoxShadow> controlShadows(BuildContext context, {bool pressed = false}) =>
      shown(context) ? context.look.elevation.controlShadows(pressed: pressed) : const [];

  /// The resting shadow under a Mac form's group in a theme whose panes are panels; none elsewhere.
  static List<BoxShadow> groupShadows(BuildContext context) => shown(context) ? context.shadows.shadow1 : const [];

  /// Between a panel and its pane's edges: the sidebar panel's margin, more than the deepest offset shadow.
  static const gutter = MyDataMacSize.sidebarMargin;

  @override
  Widget build(BuildContext context) {
    if (!shown(context)) return child;
    final look = context.look;
    final radius = MyDataRadii.md(look);
    return Padding(
      padding: const EdgeInsets.all(gutter),
      child: DecoratedBox(
        decoration: context.radius
            .decorate(BoxDecoration(color: context.colors.surface, borderRadius: radius, boxShadow: context.shadows.shadow1)),
        child: CardEdge(radius: radius, child: look.shape.clip(radius, child: child)),
      ),
    );
  }
}
