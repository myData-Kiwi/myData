import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme/checks.dart' show accessibilityThemes;
import '../theme/choice.dart';
import '../theme/colour.dart';
import '../theme/library.dart';
import '../theme/theme.dart';
import 'mac_window.dart';

/// The Mac frame (docs/2026-10-23-plan.md section 5, "native frame, quiet brand"; Flutter on every platform,
/// decided 2026-10-23): the platform owns the window, toolbar, sidebar, font, accent and focus ring; myData
/// owns the content (avatars, wording, empty states).
///
/// - **When.** Every macOS build draws the Mac frame; there is no switch back to the branded frame on a Mac.
///   Other platforms keep the branded frame until their own pass (Material 3 on Android). Screens an app has
///   not moved to the Mac frame yet still draw their branded layout, in the system font and colours.
/// - **The theme.** [MacTheme.data] keeps every token the other widgets read ([MyDataColors]) but maps them
///   to the system's colours, and adds [MyDataMacColors] for the Mac widgets and a [MyDataLook] whose frame
///   is [LookFrame.system].
/// - **Asking where you are** (design/themes/ARCHITECTURE.md 3.3): layout asks [MacWindow.of] (the Mac
///   window's skeleton); how a thing is drawn asks [MacSystemLook.isSystemLook] (System in the Mac window).
abstract final class MacLook {
  /// Tests set this to draw the Mac frame on the test platform (or to keep it off); null follows the
  /// platform.
  static bool? debugOverride;

  /// The app should build the Mac theme: on macOS (or as [debugOverride] says).
  static bool get forThisPlatform => debugOverride ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);
}

/// `context.isSystemLook`: the System look is drawn here, in the Mac window ([MacWindow.of]): the system's
/// colours, font, sizes and controls. Visual branches ask this; layout branches ask [MacWindow.of].
extension MacSystemLook on BuildContext {
  bool get isSystemLook => MacWindow.of(this) && MyDataLook.of(this).frame == LookFrame.system;
}

/// `context.mac`: the Mac frame's colours for this appearance (the defaults outside a [MacTheme]).
extension MacContext on BuildContext {
  MyDataMacColors get mac {
    final theme = Theme.of(this);
    return theme.extension<MyDataMacColors>() ??
        (theme.brightness == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light);
  }
}

/// `context.type(MyDataTypeRole.body)`: the look's style for a role, or in the System look on a Mac
/// ([MacSystemLook.isSystemLook]) its Mac counterpart ([MacTheme.typeFor]), so the shared widgets
/// (EmptyState, StatusPanel, Notice, Button, the several-selected summary) draw in the system font at Mac
/// sizes there. Call it before `copyWith`.
extension MacTypeContext on BuildContext {
  TextStyle type(MyDataTypeRole role) {
    final scale = typeScale;
    return isSystemLook ? MacTheme.typeFor(role, scale) : scale(role);
  }
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
  /// separator, `accent`, `link` and `selection` the system's accent, `focus` and `focus-on-danger` its focus
  /// ring colour, `selection-inactive` and `sidebar` its own, `toolbar` the window's and `edge` the label's.
  /// The host's theme is not used for the accent here: on the Mac the accent is the system's (the plan's
  /// "System" accent option, the default on the Mac).
  static ThemeData data(String? themeId, Brightness brightness, MyDataMacColors system) {
    final mac = onAccentWhite(system);
    final base = MyDataTheme.data(themeId, brightness);
    final brand = base.extension<MyDataColors>()!;
    final look = base.extension<MyDataLook>()!;
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
      // The roles the theme format added, on the system's colours too, so no link, selection or ring is
      // drawn in the host's colour: the ring is the system's on a field in error as well.
      link: mac.accent,
      selection: mac.accent,
      onSelection: mac.onAccent,
      selectionInactive: mac.selectionInactive,
      focusOnDanger: mac.focusRing,
      sidebar: mac.sidebarBackground,
      toolbar: mac.windowBackground,
      edge: mac.label,
    );
    // Built afresh, not by applying the system font to the branded styles: those carry mydata_ui's package,
    // which would turn the family into `packages/mydata_ui/.AppleSystemUIFont`, a font that does not exist.
    final text = _inheriting(_textTheme(brightness).apply(bodyColor: mac.label, displayColor: mac.label));
    return base.copyWith(
      extensions: [
        colors,
        base.extension<MyDataShadows>()!,
        mac,
        // System, drawn by the Mac shell, with no palette; its sizes and type are still Kiwi's for the
        // branded widgets inside it.
        look.asSystem(colors: colors),
      ],
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

  /// The Mac shell's ThemeData for [choice] in [brightness]: System is [data] (the system's colours over
  /// [system]); a drawn theme is [drawn], drawn inside the Mac window.
  static ThemeData forChoice(ThemeChoice? choice, Brightness brightness, MyDataMacColors system) {
    final look = ThemeLibrary.lookFor(choice, brightness, platform: TargetPlatform.macOS);
    if (look.frame == LookFrame.system) return data(null, brightness, system);
    return drawn(look);
  }

  /// A drawn theme in the Mac window (design/themes/ARCHITECTURE.md 3.4): the theme's own ThemeData, plus
  /// Mac colours made from its palette ([colorsFor]), so the window keeps its skeleton ([MacWindow.of]: the
  /// sidebar, the columns, the toolbar band) and the Mac widgets draw in the theme's colours. Until phase 3
  /// those widgets keep the Mac's type and sizes; the shared widgets draw the theme's variants.
  static ThemeData drawn(MyDataLook look) {
    final base = MyDataTheme.fromLook(look);
    return base.copyWith(
      // The default text the Mac widgets merge their system-font styles into: without mydata_ui's package,
      // which TextStyle.merge would otherwise put before `.AppleSystemUIFont` (a font that does not exist).
      textTheme: _unpackaged(base.textTheme),
      primaryTextTheme: _unpackaged(base.primaryTextTheme),
      extensions: [
        ...base.extensions.values,
        colorsFor(look.colors, look.brightness,
            strongText: look.increasedContrast || accessibilityThemes.contains(look.themeId)),
      ],
    );
  }

  /// [t] with each style's family kept as its full name (`packages/mydata_ui/Figtree`) but no package left
  /// to prefix the family of a style merged into it.
  static TextTheme _unpackaged(TextTheme t) {
    TextStyle? u(TextStyle? s) => s == null
        ? null
        : TextStyle(
            inherit: s.inherit,
            color: s.color,
            backgroundColor: s.backgroundColor,
            fontSize: s.fontSize,
            fontWeight: s.fontWeight,
            fontStyle: s.fontStyle,
            letterSpacing: s.letterSpacing,
            wordSpacing: s.wordSpacing,
            textBaseline: s.textBaseline,
            height: s.height,
            leadingDistribution: s.leadingDistribution,
            locale: s.locale,
            foreground: s.foreground,
            background: s.background,
            shadows: s.shadows,
            fontFeatures: s.fontFeatures,
            fontVariations: s.fontVariations,
            decoration: s.decoration,
            decorationColor: s.decorationColor,
            decorationStyle: s.decorationStyle,
            decorationThickness: s.decorationThickness,
            debugLabel: s.debugLabel,
            fontFamily: s.fontFamily,
            fontFamilyFallback: s.fontFamilyFallback,
            overflow: s.overflow,
          );
    return TextTheme(
      displayLarge: u(t.displayLarge),
      displayMedium: u(t.displayMedium),
      displaySmall: u(t.displaySmall),
      headlineLarge: u(t.headlineLarge),
      headlineMedium: u(t.headlineMedium),
      headlineSmall: u(t.headlineSmall),
      titleLarge: u(t.titleLarge),
      titleMedium: u(t.titleMedium),
      titleSmall: u(t.titleSmall),
      bodyLarge: u(t.bodyLarge),
      bodyMedium: u(t.bodyMedium),
      bodySmall: u(t.bodySmall),
      labelLarge: u(t.labelLarge),
      labelMedium: u(t.labelMedium),
      labelSmall: u(t.labelSmall),
    );
  }

  /// The Mac widgets' colours from a drawn theme's palette: the window is `bg`, the content `surface`, the
  /// sidebar `sidebar`, labels `ink` and `ink-muted`, the accent, ring and selection the palette's. The
  /// faint label shades keep the system's opacity over `ink`; with [strongText] (increased contrast, and
  /// the accessibility themes, High Contrast, E-ink and Large) the tertiary label, which a disabled item and
  /// another month's day are drawn in, is the grey of `ink` over `surface` that reads at 4.5:1 on `surface`
  /// and `bg`: still fainter than `ink-muted`, so a disabled item reads as disabled.
  static MyDataMacColors colorsFor(MyDataColors c, Brightness brightness, {bool strongText = false}) {
    final base = brightness == Brightness.dark ? MyDataMacColors.dark : MyDataMacColors.light;
    Rgb rgb(Color x) => Rgb.argb(x.toARGB32());
    return MyDataMacColors(
      accent: c.accent,
      onAccent: c.onAccent,
      label: c.ink,
      secondaryLabel: c.inkMuted,
      tertiaryLabel: strongText
          ? Color(mixUntil(rgb(c.surface), rgb(c.ink), 4.5, [rgb(c.surface), rgb(c.bg)]).argb)
          : c.ink.withValues(alpha: base.tertiaryLabel.a),
      quaternaryLabel: c.ink.withValues(alpha: base.quaternaryLabel.a),
      separator: c.line,
      contentBackground: c.surface,
      windowBackground: c.bg,
      sidebarBackground: c.sidebar,
      selectionInactive: c.selectionInactive,
      sidebarSelection: c.accentSoft,
      hover: c.ink.withValues(alpha: base.hover.a),
      focusRing: c.focus,
      red: c.danger,
      green: c.success,
      toolbarItem: c.surfaceRaised,
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

  /// [t] with every style marked `inherit`, as a drawn theme's are, so the app's theme animation can lerp
  /// between System and a drawn theme (TextStyle.lerp refuses styles that differ in `inherit`). Each style
  /// gives every field, so Theme.of's merge with the platform's geometry changes nothing on screen.
  static TextTheme _inheriting(TextTheme t) {
    TextStyle? i(TextStyle? s) => s?.copyWith(inherit: true);
    return TextTheme(
      displayLarge: i(t.displayLarge),
      displayMedium: i(t.displayMedium),
      displaySmall: i(t.displaySmall),
      headlineLarge: i(t.headlineLarge),
      headlineMedium: i(t.headlineMedium),
      headlineSmall: i(t.headlineSmall),
      titleLarge: i(t.titleLarge),
      titleMedium: i(t.titleMedium),
      titleSmall: i(t.titleSmall),
      bodyLarge: i(t.bodyLarge),
      bodyMedium: i(t.bodyMedium),
      bodySmall: i(t.bodySmall),
      labelLarge: i(t.labelLarge),
      labelMedium: i(t.labelMedium),
      labelSmall: i(t.labelSmall),
    );
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

  /// The Mac counterpart of a role's style: `display-xl` and `display-lg` are a pane's `pane-title`,
  /// `title` and `heading` the toolbar's `title`, `body-strong` is `body-emphasized`, `label` is `callout`,
  /// `body` and `caption` keep their names. `mono` keeps its size and weight in the system font.
  static TextStyle typeFor(MyDataTypeRole role, MyDataTypeScale branded) {
    switch (role) {
      case MyDataTypeRole.displayXl || MyDataTypeRole.displayLg:
        return MyDataMacType.paneTitle;
      case MyDataTypeRole.title || MyDataTypeRole.heading:
        return MyDataMacType.title;
      case MyDataTypeRole.bodyStrong:
        return MyDataMacType.bodyEmphasized;
      case MyDataTypeRole.body:
        return MyDataMacType.body;
      case MyDataTypeRole.label:
        return MyDataMacType.callout;
      case MyDataTypeRole.caption:
        return MyDataMacType.caption;
      case MyDataTypeRole.mono:
        break;
    }
    final style = branded(role);
    // A new TextStyle, not copyWith: the branded style carries mydata_ui's package (see [data]).
    return TextStyle(
      fontFamily: MyDataMacFont.text,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      height: style.height,
      leadingDistribution: style.leadingDistribution,
      fontFeatures: style.fontFeatures,
    );
  }
}
