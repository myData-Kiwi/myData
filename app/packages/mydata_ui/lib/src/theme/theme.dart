import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import 'choice.dart';
import 'library.dart';
import 'icons.dart';
import 'look.dart';

export 'look.dart' show MyDataLook, MyDataTypeRole, MyDataTypeScale, MyDataShape, MyDataDensity, MyDataMotionSpec, LookFrame;
export 'icons.dart' show MyDataIcon;

/// Light, dark, or whatever the device uses. Stored per device.
enum MyDataMode {
  light,
  dark,
  system;

  ThemeMode get themeMode => switch (this) {
        MyDataMode.light => ThemeMode.light,
        MyDataMode.dark => ThemeMode.dark,
        MyDataMode.system => ThemeMode.system,
      };

  /// The mode named [name], or [system] for null or anything unknown.
  static MyDataMode parse(String? name) => values.firstWhere((m) => m.name == name, orElse: () => system);
}

/// The theme an app draws with: a [ThemeChoice] (a theme and its palette, chosen per app and per device;
/// System by default) and a [mode] (light, dark or match system, per device). Widgets read the look through
/// `context.colors`, `context.typeScale`, `context.space(n)` and the other `context` shortcuts, never a
/// literal.
///
/// ```dart
/// final theme = MyDataTheme(choice: const ThemeChoice('mydata.kiwi', 'plum'), mode: mode);
/// MaterialApp(theme: theme.light, darkTheme: theme.dark, themeMode: theme.themeMode, ...);
/// ```
///
/// On a Mac the Mac shell builds the ThemeData itself (`MacShell`): System is the system's own colours there.
@immutable
class MyDataTheme {
  /// [choice] is drawn as [ThemeLibrary.normalise] says: an unknown theme is System, an unknown palette the
  /// theme's default.
  MyDataTheme({ThemeChoice? choice, this.mode = MyDataMode.system}) : choice = ThemeLibrary.normalise(choice);

  /// Kiwi in one of today's colours (`plum`): the colour ids of the host's old `/appearance`, and tests.
  factory MyDataTheme.kiwi(String? colour, {MyDataMode mode = MyDataMode.system}) =>
      MyDataTheme(choice: ThemeChoice(ThemeLibrary.kiwiId, colour), mode: mode);

  final ThemeChoice choice;
  final MyDataMode mode;

  ThemeData get light => dataFor(choice, Brightness.light);
  ThemeData get dark => dataFor(choice, Brightness.dark);
  ThemeMode get themeMode => mode.themeMode;

  @override
  bool operator ==(Object other) => other is MyDataTheme && other.choice == choice && other.mode == mode;

  @override
  int get hashCode => Object.hash(choice, mode);

  /// ThemeData for Kiwi in today's colour [themeId] and [brightness].
  static ThemeData data(String? themeId, Brightness brightness) =>
      fromLook(ThemeLibrary.kiwiLook(MyDataThemes.byId(themeId).id, brightness));

  /// ThemeData for [choice] in [brightness], off the Mac shell (System is Kiwi's style in Kiwi's colour there
  /// until each platform's pass).
  static ThemeData dataFor(ThemeChoice? choice, Brightness brightness) =>
      fromLook(ThemeLibrary.lookFor(choice, brightness));

  /// How long the app takes to move to a new theme or mode: none. A switch is one rebuild with the new
  /// look's fonts already loaded (ThemeController), never a lerp through in-between type, which would relay
  /// out every line for a dozen frames and flip the font halfway (design/themes/ARCHITECTURE.md 3.5 and 3.6).
  /// Every app passes it as MaterialApp's `themeAnimationDuration`.
  static const switchDuration = Duration.zero;

  /// ThemeData for [look]: the look itself as an extension, its colours ([MyDataColors]) and shadows
  /// ([MyDataShadows]) as their own, and the Material widgets that remain (selection, scroll bars, dialogs,
  /// tooltips) set from the same values.
  static ThemeData fromLook(MyDataLook look) {
    final brightness = look.brightness;
    final c = look.colors;
    final shadows = look.elevation.shadows;
    final type = look.typeScale;
    final r = look.shape;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.ink,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.ink,
      tertiary: c.info,
      onTertiary: c.surface,
      error: c.danger,
      onError: c.onDanger,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceSunken,
      outline: c.lineStrong,
      outlineVariant: c.line,
      shadow: shadows.shadow1.isEmpty ? c.shadow : shadows.shadow1.first.color,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.bg,
      inversePrimary: c.accentSoft,
    );
    final text = TextTheme(
      displayLarge: type.displayXl,
      displayMedium: type.displayLg,
      displaySmall: type.title,
      headlineLarge: type.displayLg,
      headlineMedium: type.title,
      headlineSmall: type.title,
      titleLarge: type.title,
      titleMedium: type.heading,
      titleSmall: type.bodyStrong,
      bodyLarge: type.body,
      bodyMedium: type.body,
      bodySmall: type.caption,
      labelLarge: type.bodyStrong,
      labelMedium: type.label,
      labelSmall: type.caption,
    ).apply(bodyColor: c.ink, displayColor: c.ink);
    final xl = BorderRadius.all(Radius.circular(r.xl));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      // No ThemeData.fontFamily: it would set every Material role in the body's family (display roles too)
      // and prefix even a platform family with this package. Each role of [text] carries its own family.
      textTheme: text,
      extensions: [c, shadows, look],
      // Presses dim and shrink (motion.md); no ink ripples.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.ink.withValues(alpha: 0.04),
      focusColor: c.focus.withValues(alpha: 0.12),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.ink, size: look.density.icon),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.accent, selectionColor: c.accent.withValues(alpha: 0.25), selectionHandleColor: c.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.all(Radius.circular(r.sm)),
            boxShadow: shadows.shadow2),
        textStyle: type.caption.copyWith(color: c.ink),
      ),
      dialogTheme: DialogThemeData(
          backgroundColor: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: xl),
          titleTextStyle: type.title.copyWith(color: c.ink),
          contentTextStyle: type.body.copyWith(color: c.ink),
          barrierColor: c.scrim),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          modalBarrierColor: c.scrim,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(r.xl)))),
      popupMenuTheme: PopupMenuThemeData(
          color: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(r.md))),
          textStyle: type.body.copyWith(color: c.ink)),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: c.ink,
          contentTextStyle: type.body.copyWith(color: c.bg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(r.md)))),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(c.inkMuted.withValues(alpha: 0.5))),
    );
  }
}

/// `context.colors.accent`, `context.shadows.shadow1`: the current look's colours and shadows.
extension MyDataContext on BuildContext {
  MyDataColors get colors => Theme.of(this).extension<MyDataColors>() ?? MyDataColors.light;
  MyDataShadows get shadows => Theme.of(this).extension<MyDataShadows>() ?? MyDataShadows.light;
}

/// The current look and its shortcuts: `context.space(4)`, `context.typeScale.body`, `context.radius.lg`,
/// `context.density.controlHeight`, `context.motion.fast`. Each makes the widget depend on the theme, as
/// `Theme.of` does; `context.lookNow` reads without depending, for `initState` and fields first used there.
extension MyDataLookContext on BuildContext {
  MyDataLook get look => MyDataLook.of(this);
  MyDataLook get lookNow => MyDataLook.of(this, listen: false);
  /// The look's type, heavier where the system asks for Bold Text ([MyDataTypeScale.bold]).
  MyDataTypeScale get typeScale =>
      (MediaQuery.maybeBoldTextOf(this) ?? false) ? look.typeScale.bold : look.typeScale;
  double space(num n) => look.density.space(n);
  MyDataShape get radius => look.shape;
  MyDataDensity get density => look.density;
  MyDataMotionSpec get motion => look.motion;

  /// [icon]'s glyph in this look's icon set and weight; filled when [selected] and the theme fills selected
  /// icons (`Icon(context.icon(MyDataIcon.add))`).
  IconData icon(MyDataIcon icon, {bool selected = false}) => look.icons(icon, selected: selected);
}
