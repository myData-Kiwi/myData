import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import '../widgets/app_frame.dart' show AppLayout;

/// The Mac frame (docs/2026-10-23-plan.md section 5, "native frame, quiet brand"; Flutter on every platform,
/// decided 2026-10-23): the platform owns the window, toolbar, sidebar, font, accent and focus ring; myData
/// owns the content (avatars, wording, empty states).
///
/// - **When.** Every macOS build draws the Mac frame; there is no switch back to the branded frame on a Mac.
///   Other platforms keep the branded frame until their own pass (Material 3 on Android). Screens an app has
///   not moved to the Mac frame yet still draw their branded layout, in the system font and colours.
/// - **The theme.** [MacTheme.data] keeps every token the other widgets read ([MyDataColors]) but maps them
///   to the system's colours, and adds [MyDataMacColors] for the Mac widgets. Its presence is what
///   [MacLook.of] reads.
abstract final class MacLook {
  /// Tests set this to draw the Mac frame on the test platform (or to keep it off); null follows the
  /// platform.
  static bool? debugOverride;

  /// The app should build the Mac theme: on macOS (or as [debugOverride] says).
  static bool get forThisPlatform => debugOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);

  /// The Mac frame is drawn here: the theme is [MacTheme]'s and the window is wider than a phone's.
  static bool of(BuildContext context) =>
      Theme.of(context).extension<MyDataMacColors>() != null && !AppLayout.isPhone(context);
}

/// `context.mac`: the Mac frame's colours for this appearance (the defaults outside a [MacTheme]).
extension MacContext on BuildContext {
  MyDataMacColors get mac {
    final theme = Theme.of(this);
    return theme.extension<MyDataMacColors>() ??
        (theme.brightness == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light);
  }
}

/// `context.type(MyDataType.body)`: a branded type style, or in the Mac frame ([MacLook.of]) its Mac
/// counterpart ([MacTheme.typeFor]), so the shared widgets (EmptyState, StatusPanel, Notice, Button, the
/// several-selected summary) draw in the system font at Mac sizes there. Call it before `copyWith`.
extension MacTypeContext on BuildContext {
  TextStyle type(TextStyle branded) => MacLook.of(this) ? MacTheme.typeFor(branded) : branded;
}

/// A row of a list in the Mac frame tells its content whether it is drawn on the accent (selected, in a
/// focused list, in the active window), so text and icons switch to `on-accent` as the system's do.
class MacRowEmphasis extends InheritedWidget {
  const MacRowEmphasis({super.key, required this.emphasised, required super.child});

  final bool emphasised;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MacRowEmphasis>()?.emphasised ?? false;

  @override
  bool updateShouldNotify(MacRowEmphasis old) => old.emphasised != emphasised;
}

/// The Mac frame's ThemeData for one appearance.
abstract final class MacTheme {
  /// The app's theme ([MyDataTheme.data] for [themeId]) moved onto the system: the system font for every
  /// Material text style, the system's colours behind every token, and [system] (white on its accent:
  /// [onAccentWhite]) for the Mac widgets.
  ///
  /// The tokens map to the system's meanings: `bg` is the window's background, `surface` the content's,
  /// `surface-sunken` a `quaternary-label` shade over it, `ink` and `ink-muted` the label colours, `line` the
  /// separator, `accent` the system's accent and `focus` its focus ring colour.
  /// The host's theme is not used for the accent here: on the Mac the accent is the system's (the plan's
  /// "System" accent option, the default on the Mac).
  static ThemeData data(String? themeId, Brightness brightness, MyDataMacColors system) {
    final mac = onAccentWhite(system);
    final base = MyDataTheme.data(themeId, brightness);
    final brand = base.extension<MyDataColors>()!;
    final soft = Color.alphaBlend(mac.accent.withValues(alpha: 0.18), mac.contentBackground);
    final colors = brand.copyWith(
      bg: mac.windowBackground,
      surface: mac.contentBackground,
      surfaceRaised: mac.contentBackground,
      // Wells, notices and code: a shade of `quaternary-label` over the content, so they are raised in dark
      // mode (as the system's secondary surfaces are), never a hole darker than the window.
      surfaceSunken: Color.alphaBlend(mac.quaternaryLabel, mac.contentBackground),
      surfaceHover: Color.alphaBlend(mac.hover, mac.contentBackground),
      ink: mac.label,
      inkMuted: mac.secondaryLabel,
      line: mac.separator,
      accent: mac.accent,
      onAccent: mac.onAccent,
      accentSoft: soft,
      focus: mac.focusRing,
    );
    // Built afresh, not by applying the system font to the branded styles: those carry mydata_ui's package,
    // which would turn the family into `packages/mydata_ui/.AppleSystemUIFont`, a font that does not exist.
    final text = _textTheme(brightness).apply(bodyColor: mac.label, displayColor: mac.label);
    return base.copyWith(
      extensions: [colors, base.extension<MyDataShadows>()!, mac],
      scaffoldBackgroundColor: mac.windowBackground,
      canvasColor: mac.windowBackground,
      textTheme: text,
      primaryTextTheme: text,
      colorScheme: base.colorScheme.copyWith(
        primary: mac.accent,
        onPrimary: mac.onAccent,
        secondary: mac.accent,
        primaryContainer: soft,
        surface: mac.contentBackground,
        onSurface: mac.label,
        onSurfaceVariant: mac.secondaryLabel,
        outlineVariant: mac.separator,
      ),
      dividerTheme: DividerThemeData(color: mac.separator, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: mac.accent,
        selectionColor: mac.accent.withValues(alpha: 0.3),
        selectionHandleColor: mac.accent,
      ),
      iconTheme: IconThemeData(color: mac.secondaryLabel, size: MyDataMacSize.icon),
    );
  }

  /// The least contrast white text needs on the accent (WCAG's for large text and controls; the system's
  /// blue in dark mode, #0A84FF, has 3.6).
  static const accentContrast = 3.0;

  /// [mac] with white text on the accent, as macOS draws a selection and a default button in both
  /// appearances (HIG Color): a light accent (a Kiwi green or a Graphite grey in dark mode, which would
  /// otherwise carry dark text and read as a highlighter) is darkened in its own hue until white text on it
  /// has [accentContrast]. The system's own accents already have it, so on a Mac this changes nothing.
  static MyDataMacColors onAccentWhite(MyDataMacColors mac) {
    final white = MyDataMacColors.light.onAccent;
    var accent = mac.accent;
    var hsl = HSLColor.fromColor(accent);
    while (_contrast(white, accent) < accentContrast && hsl.lightness > 0) {
      hsl = hsl.withLightness((hsl.lightness - 0.01).clamp(0.0, 1.0));
      accent = hsl.toColor().withValues(alpha: mac.accent.a);
    }
    if (accent == mac.accent && mac.onAccent == white) return mac;
    return mac.withSystem({'accent': accent, 'on-accent': white});
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// The Mac's type ramp: Flutter's macOS typography (the system font) for the large styles, and the Mac
  /// tokens for the ones the screens use (body 13pt, callout, caption, the toolbar title, a record's name).
  static TextTheme _textTheme(Brightness brightness) {
    final typography = Typography.material2021(platform: TargetPlatform.macOS);
    final colored = brightness == Brightness.dark ? typography.white : typography.black;
    final ramp = typography.englishLike.merge(colored).apply(fontFamily: MyDataMacFont.text);
    return ramp.copyWith(
      displaySmall: MyDataMacType.paneTitle,
      headlineLarge: MyDataMacType.paneTitle,
      headlineMedium: MyDataMacType.paneTitle,
      headlineSmall: MyDataMacType.title,
      titleLarge: MyDataMacType.title,
      titleMedium: MyDataMacType.bodyEmphasized,
      titleSmall: MyDataMacType.bodyEmphasized,
      bodyLarge: MyDataMacType.body,
      bodyMedium: MyDataMacType.body,
      bodySmall: MyDataMacType.caption,
      labelLarge: MyDataMacType.body,
      labelMedium: MyDataMacType.callout,
      labelSmall: MyDataMacType.caption,
    );
  }

  /// The Mac counterpart of a branded type style: `display-xl` and `display-lg` are a pane's `pane-title`,
  /// `title` and `heading` the toolbar's `title`, `body-strong` is `body-emphasized`, `label` is `callout`,
  /// `body` and `caption` keep their names. Anything else keeps its size and weight in the system font.
  static TextStyle typeFor(TextStyle branded) {
    if (identical(branded, MyDataType.displayXl) || identical(branded, MyDataType.displayLg)) {
      return MyDataMacType.paneTitle;
    }
    if (identical(branded, MyDataType.title) || identical(branded, MyDataType.heading)) return MyDataMacType.title;
    if (identical(branded, MyDataType.bodyStrong)) return MyDataMacType.bodyEmphasized;
    if (identical(branded, MyDataType.body)) return MyDataMacType.body;
    if (identical(branded, MyDataType.label)) return MyDataMacType.callout;
    if (identical(branded, MyDataType.caption)) return MyDataMacType.caption;
    // A new TextStyle, not copyWith: the branded style carries mydata_ui's package (see [data]).
    return TextStyle(
      fontFamily: MyDataMacFont.text,
      fontSize: branded.fontSize,
      fontWeight: branded.fontWeight,
      fontStyle: branded.fontStyle,
      height: branded.height,
      leadingDistribution: branded.leadingDistribution,
      fontFeatures: branded.fontFeatures,
    );
  }
}
