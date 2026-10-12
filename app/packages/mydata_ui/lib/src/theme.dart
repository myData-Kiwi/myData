import 'package:flutter/material.dart';

import 'generated/tokens.g.dart';

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

/// The theme of every myData app, built from a theme id (stored on the host, the same in every app) and a
/// mode (stored per device). Widgets read colours through `context.colors`, never a literal.
///
/// ```dart
/// final theme = MyDataTheme(themeId: status.theme, mode: mode);
/// MaterialApp(theme: theme.light, darkTheme: theme.dark, themeMode: theme.themeMode, ...);
/// ```
@immutable
class MyDataTheme {
  MyDataTheme({String? themeId, this.mode = MyDataMode.system}) : spec = MyDataThemes.byId(themeId);

  final MyDataThemeSpec spec;
  final MyDataMode mode;

  ThemeData get light => data(spec.id, Brightness.light);
  ThemeData get dark => data(spec.id, Brightness.dark);
  ThemeMode get themeMode => mode.themeMode;

  @override
  bool operator ==(Object other) => other is MyDataTheme && other.spec.id == spec.id && other.mode == mode;

  @override
  int get hashCode => Object.hash(spec.id, mode);

  /// ThemeData for one theme and brightness. Material widgets that remain (selection, scroll bars, dialogs,
  /// tooltips) take their colours from the same tokens.
  static ThemeData data(String? themeId, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = (dark ? MyDataColors.dark : MyDataColors.light).withTheme(MyDataThemes.byId(themeId), brightness);
    final shadows = dark ? MyDataShadows.dark : MyDataShadows.light;
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
      shadow: shadows.shadow1.first.color,
      scrim: c.scrim,
      inverseSurface: c.ink,
      onInverseSurface: c.bg,
      inversePrimary: c.accentSoft,
    );
    final text = TextTheme(
      displayLarge: MyDataType.displayXl,
      displayMedium: MyDataType.displayLg,
      displaySmall: MyDataType.title,
      headlineLarge: MyDataType.displayLg,
      headlineMedium: MyDataType.title,
      headlineSmall: MyDataType.title,
      titleLarge: MyDataType.title,
      titleMedium: MyDataType.heading,
      titleSmall: MyDataType.bodyStrong,
      bodyLarge: MyDataType.body,
      bodyMedium: MyDataType.body,
      bodySmall: MyDataType.caption,
      labelLarge: MyDataType.bodyStrong,
      labelMedium: MyDataType.label,
      labelSmall: MyDataType.caption,
    ).apply(bodyColor: c.ink, displayColor: c.ink);
    const xl = BorderRadius.all(Radius.circular(MyDataRadius.xl));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: MyDataFontFamily.body,
      package: MyDataFontFamily.package,
      textTheme: text,
      extensions: [c, shadows],
      // Presses dim and shrink (motion.md); no ink ripples.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.ink.withValues(alpha: 0.04),
      focusColor: c.focus.withValues(alpha: 0.12),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.ink, size: MyDataSize.icon),
      textSelectionTheme: TextSelectionThemeData(
          cursorColor: c.accent, selectionColor: c.accent.withValues(alpha: 0.25), selectionHandleColor: c.accent),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: const BorderRadius.all(Radius.circular(MyDataRadius.sm)),
            boxShadow: shadows.shadow2),
        textStyle: MyDataType.caption.copyWith(color: c.ink),
      ),
      dialogTheme: DialogThemeData(
          backgroundColor: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: xl),
          titleTextStyle: MyDataType.title.copyWith(color: c.ink),
          contentTextStyle: MyDataType.body.copyWith(color: c.ink),
          barrierColor: c.scrim),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          modalBarrierColor: c.scrim,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MyDataRadius.xl)))),
      popupMenuTheme: PopupMenuThemeData(
          color: c.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(MyDataRadius.md))),
          textStyle: MyDataType.body.copyWith(color: c.ink)),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: c.ink,
          contentTextStyle: MyDataType.body.copyWith(color: c.bg),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(MyDataRadius.md)))),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(c.inkMuted.withValues(alpha: 0.5))),
    );
  }
}

/// `context.colors.accent`, `context.shadows.shadow1`: the current theme's tokens.
extension MyDataContext on BuildContext {
  MyDataColors get colors => Theme.of(this).extension<MyDataColors>() ?? MyDataColors.light;
  MyDataShadows get shadows => Theme.of(this).extension<MyDataShadows>() ?? MyDataShadows.light;
}
