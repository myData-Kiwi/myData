import 'package:flutter/material.dart';

import 'legacy_colors.dart';

TextStyle _t(String family, double size, FontWeight weight, {Color color = LegacyColors.fg, double? height}) =>
    TextStyle(fontFamily: family, package: LegacyFonts.package, fontSize: size, fontWeight: weight, color: color,
        height: height);

/// Monospace text, for anything exact: tool names, arguments, ids, tokens.
TextStyle legacyMonoStyle({double size = 13, FontWeight weight = FontWeight.w400, Color color = LegacyColors.fg}) =>
    _t(LegacyFonts.mono, size, weight, color: color, height: 1.4);

/// The one theme of every myData app. Light only.
ThemeData legacyTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: LegacyColors.kiwiDeep,
    onPrimary: LegacyColors.surface,
    primaryContainer: LegacyColors.band,
    onPrimaryContainer: LegacyColors.fg,
    secondary: LegacyColors.skin,
    onSecondary: LegacyColors.surface,
    secondaryContainer: LegacyColors.cream,
    onSecondaryContainer: LegacyColors.fg,
    tertiary: LegacyColors.kiwi,
    onTertiary: LegacyColors.fg,
    error: LegacyColors.danger,
    onError: LegacyColors.surface,
    errorContainer: LegacyColors.dangerBg,
    onErrorContainer: LegacyColors.danger,
    surface: LegacyColors.bg,
    onSurface: LegacyColors.fg,
    onSurfaceVariant: LegacyColors.muted,
    surfaceContainerLowest: LegacyColors.surface,
    surfaceContainerLow: LegacyColors.surface,
    surfaceContainer: LegacyColors.cream,
    surfaceContainerHigh: LegacyColors.cream,
    surfaceContainerHighest: LegacyColors.band,
    outline: LegacyColors.line,
    outlineVariant: LegacyColors.line,
  );
  final text = TextTheme(
    displaySmall: _t(LegacyFonts.display, 32, FontWeight.w700),
    headlineMedium: _t(LegacyFonts.display, 26, FontWeight.w700),
    headlineSmall: _t(LegacyFonts.display, 22, FontWeight.w700),
    titleLarge: _t(LegacyFonts.display, 19, FontWeight.w600),
    titleMedium: _t(LegacyFonts.body, 16, FontWeight.w600),
    titleSmall: _t(LegacyFonts.body, 14, FontWeight.w600),
    bodyLarge: _t(LegacyFonts.body, 16, FontWeight.w400, height: 1.45),
    bodyMedium: _t(LegacyFonts.body, 14, FontWeight.w400, height: 1.45),
    bodySmall: _t(LegacyFonts.body, 12, FontWeight.w400, color: LegacyColors.muted),
    labelLarge: _t(LegacyFonts.body, 14, FontWeight.w600),
    labelMedium: _t(LegacyFonts.body, 12, FontWeight.w600, color: LegacyColors.muted),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LegacyColors.bg,
    fontFamily: LegacyFonts.body,
    package: LegacyFonts.package,
    textTheme: text,
    dividerTheme: const DividerThemeData(color: LegacyColors.line, thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: LegacyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)), side: BorderSide(color: LegacyColors.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          backgroundColor: LegacyColors.kiwiDeep,
          foregroundColor: LegacyColors.surface,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          foregroundColor: LegacyColors.fg,
          side: const BorderSide(color: LegacyColors.line),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: LegacyColors.kiwiDeep, textStyle: text.labelLarge)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LegacyColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LegacyColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LegacyColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: LegacyColors.kiwiDeep, width: 1.5)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: LegacyColors.kiwiDeep, linearTrackColor: LegacyColors.band),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LegacyColors.surface : LegacyColors.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LegacyColors.kiwiDeep : LegacyColors.line),
    ),
    navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: LegacyColors.cream, indicatorColor: LegacyColors.band),
  );
}
