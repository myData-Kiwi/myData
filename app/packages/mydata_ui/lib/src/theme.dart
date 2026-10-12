import 'package:flutter/material.dart';

import 'colors.dart';

TextStyle _t(String family, double size, FontWeight weight, {Color color = MyDataColors.fg, double? height}) =>
    TextStyle(fontFamily: family, package: MyDataFonts.package, fontSize: size, fontWeight: weight, color: color,
        height: height);

/// Monospace text, for anything exact: tool names, arguments, ids, tokens.
TextStyle monoStyle({double size = 13, FontWeight weight = FontWeight.w400, Color color = MyDataColors.fg}) =>
    _t(MyDataFonts.mono, size, weight, color: color, height: 1.4);

/// The one theme of every myData app. Light only.
ThemeData myDataTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: MyDataColors.kiwiDeep,
    onPrimary: MyDataColors.surface,
    primaryContainer: MyDataColors.band,
    onPrimaryContainer: MyDataColors.fg,
    secondary: MyDataColors.skin,
    onSecondary: MyDataColors.surface,
    secondaryContainer: MyDataColors.cream,
    onSecondaryContainer: MyDataColors.fg,
    tertiary: MyDataColors.kiwi,
    onTertiary: MyDataColors.fg,
    error: MyDataColors.danger,
    onError: MyDataColors.surface,
    errorContainer: MyDataColors.dangerBg,
    onErrorContainer: MyDataColors.danger,
    surface: MyDataColors.bg,
    onSurface: MyDataColors.fg,
    onSurfaceVariant: MyDataColors.muted,
    surfaceContainerLowest: MyDataColors.surface,
    surfaceContainerLow: MyDataColors.surface,
    surfaceContainer: MyDataColors.cream,
    surfaceContainerHigh: MyDataColors.cream,
    surfaceContainerHighest: MyDataColors.band,
    outline: MyDataColors.line,
    outlineVariant: MyDataColors.line,
  );
  final text = TextTheme(
    displaySmall: _t(MyDataFonts.display, 32, FontWeight.w700),
    headlineMedium: _t(MyDataFonts.display, 26, FontWeight.w700),
    headlineSmall: _t(MyDataFonts.display, 22, FontWeight.w700),
    titleLarge: _t(MyDataFonts.display, 19, FontWeight.w600),
    titleMedium: _t(MyDataFonts.body, 16, FontWeight.w600),
    titleSmall: _t(MyDataFonts.body, 14, FontWeight.w600),
    bodyLarge: _t(MyDataFonts.body, 16, FontWeight.w400, height: 1.45),
    bodyMedium: _t(MyDataFonts.body, 14, FontWeight.w400, height: 1.45),
    bodySmall: _t(MyDataFonts.body, 12, FontWeight.w400, color: MyDataColors.muted),
    labelLarge: _t(MyDataFonts.body, 14, FontWeight.w600),
    labelMedium: _t(MyDataFonts.body, 12, FontWeight.w600, color: MyDataColors.muted),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MyDataColors.bg,
    fontFamily: MyDataFonts.body,
    package: MyDataFonts.package,
    textTheme: text,
    dividerTheme: const DividerThemeData(color: MyDataColors.line, thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: MyDataColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)), side: BorderSide(color: MyDataColors.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
          backgroundColor: MyDataColors.kiwiDeep,
          foregroundColor: MyDataColors.surface,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
          foregroundColor: MyDataColors.fg,
          side: const BorderSide(color: MyDataColors.line),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: MyDataColors.kiwiDeep, textStyle: text.labelLarge)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MyDataColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MyDataColors.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MyDataColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MyDataColors.kiwiDeep, width: 1.5)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: MyDataColors.kiwiDeep, linearTrackColor: MyDataColors.band),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? MyDataColors.surface : MyDataColors.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? MyDataColors.kiwiDeep : MyDataColors.line),
    ),
    navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: MyDataColors.cream, indicatorColor: MyDataColors.band),
  );
}
