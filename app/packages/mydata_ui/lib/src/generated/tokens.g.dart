// GENERATED from design/tokens.json (version 4) and design/themes.json
// by tool/generate_tokens.dart. Do not edit: change the JSON and run
//   (cd app/packages/mydata_ui && dart run tool/generate_tokens.dart)
// This is the only file in the apps that may contain literal colours, radii and font names.
// ignore_for_file: public_member_api_docs

import 'package:flutter/painting.dart';
import 'package:flutter/material.dart' show Brightness, ThemeExtension;

/// Every colour token for one theme and mode. `accent` in tokens.json is `MyDataColors.accent` here.
/// The base values are the Kiwi theme; [withTheme] swaps in another theme's three colours.
class MyDataColors extends ThemeExtension<MyDataColors> {
  const MyDataColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.brand,
    required this.kiwiWash,
    required this.skin,
    required this.cream,
    required this.paper,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.info,
    required this.infoSoft,
    required this.focus,
    required this.glassFill,
    required this.glassStroke,
    required this.scrim,
  });

  /// Window background: a soft neutral grey with no tint, so every theme sits on it. Cards sit on it. Text uses ink or ink-muted.
  final Color bg;
  /// Cards, grouped lists, inputs and sheets. Lifted from bg by shadow-1 in light and by its lighter value in dark.
  final Color surface;
  /// Menus, popovers and dialogs. Pair with shadow-2.
  final Color surfaceRaised;
  /// Track of a segmented control, wells, icon tiles with no tint.
  final Color surfaceSunken;
  /// Dividers inside grouped lists. Decorative; cards themselves have no border.
  final Color line;
  /// Borders of inputs and unchecked switches. Meets 3:1 on bg and surface.
  final Color lineStrong;
  /// Primary text and icons.
  final Color ink;
  /// Secondary text, captions and placeholders on bg, surface and surface-sunken.
  final Color inkMuted;
  /// The theme colour, kiwi green by default: primary buttons, links, switches that are on, the current place. Replaced by the chosen theme.
  final Color accent;
  /// Text and icons on accent. Replaced by the chosen theme.
  final Color onAccent;
  /// Tonal buttons, the current tab's pill, selected rows, tinted icon tiles. Replaced by the chosen theme.
  final Color accentSoft;
  /// The kiwi green, fixed in every theme: the dot beside the host's status and brand artwork. Never a control colour.
  final Color brand;
  /// Fill behind avatars and placeholder artwork.
  final Color kiwiWash;
  /// The kiwi's brown. Illustration only.
  final Color skin;
  /// Soft relief inside illustrations.
  final Color cream;
  /// The ground behind the ink logo mark. Light in both themes because the mark's ink is fixed dark.
  final Color paper;
  /// Healthy and completed states. Text on bg, surface or success-soft.
  final Color success;
  /// Fill of a success status chip or icon tile.
  final Color successSoft;
  /// Needs attention. Text on bg, surface or warning-soft.
  final Color warning;
  /// Fill of a warning status chip or icon tile.
  final Color warningSoft;
  /// Errors and destructive actions. Fill of the danger button; text on bg, surface or danger-soft.
  final Color danger;
  /// Fill of a danger status chip.
  final Color dangerSoft;
  /// Text and icons on danger.
  final Color onDanger;
  /// Informational notices. Text on bg, surface or info-soft.
  final Color info;
  /// Fill of an info status chip or icon tile.
  final Color infoSoft;
  /// Keyboard focus ring, 2px with a 2px offset. A warm colour so it stays visible beside every theme's accent.
  final Color focus;
  /// Fill of floating bars over a blur-glass backdrop blur.
  final Color glassFill;
  /// 1px edge highlight on floating bars.
  final Color glassStroke;
  /// Dimming layer behind sheets and dialogs.
  final Color scrim;

  /// The Kiwi theme, light mode.
  static const light = MyDataColors(
    bg: Color(0xFFF6F6F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEDEB),
    line: Color(0xFFE3E3E0),
    lineStrong: Color(0xFF83837E),
    ink: Color(0xFF1A1A19),
    inkMuted: Color(0xFF5C5C58),
    accent: Color(0xFF4C7814),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEBF3DA),
    brand: Color(0xFF4C7814),
    kiwiWash: Color(0xFFE0E0DD),
    skin: Color(0xFF6B4F35),
    cream: Color(0xFFF4F3EE),
    paper: Color(0xFFFFFFFF),
    success: Color(0xFF256B29),
    successSoft: Color(0xFFDDF2DF),
    warning: Color(0xFF8A5100),
    warningSoft: Color(0xFFFBEBCF),
    danger: Color(0xFFB3261E),
    dangerSoft: Color(0xFFFBE0DD),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF1F5FA8),
    infoSoft: Color(0xFFDCE9F8),
    focus: Color(0xFFB3261E),
    glassFill: Color(0xB8FFFFFF),
    glassStroke: Color(0xCCFFFFFF),
    scrim: Color(0x59141414),
  );

  /// The Kiwi theme, dark mode.
  static const dark = MyDataColors(
    bg: Color(0xFF111111),
    surface: Color(0xFF1A1A1A),
    surfaceRaised: Color(0xFF232323),
    surfaceSunken: Color(0xFF0B0B0B),
    line: Color(0xFF2E2E2E),
    lineStrong: Color(0xFF7C7C7C),
    ink: Color(0xFFEDEDEB),
    inkMuted: Color(0xFFA8A8A4),
    accent: Color(0xFFA9CC4E),
    onAccent: Color(0xFF1A2408),
    accentSoft: Color(0xFF28331A),
    brand: Color(0xFFA9CC4E),
    kiwiWash: Color(0xFF333333),
    skin: Color(0xFFC9A57E),
    cream: Color(0xFF33332F),
    paper: Color(0xFFEDEDEB),
    success: Color(0xFF7BC67E),
    successSoft: Color(0xFF1C3A1F),
    warning: Color(0xFFF0B45A),
    warningSoft: Color(0xFF3D2C0C),
    danger: Color(0xFFF2867E),
    dangerSoft: Color(0xFF45191A),
    onDanger: Color(0xFF2B0B08),
    info: Color(0xFF8AB8EA),
    infoSoft: Color(0xFF17304D),
    focus: Color(0xFFF2867E),
    glassFill: Color(0xB81A1A1A),
    glassStroke: Color(0x1FFFFFFF),
    scrim: Color(0x99000000),
  );

  /// These colours with [theme]'s accent, on-accent and accent-soft for [brightness].
  MyDataColors withTheme(MyDataThemeSpec theme, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return copyWith(
      accent: dark ? theme.accentDark : theme.accentLight,
      onAccent: dark ? theme.onAccentDark : theme.onAccentLight,
      accentSoft: dark ? theme.accentSoftDark : theme.accentSoftLight,
    );
  }

  @override
  MyDataColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkMuted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? brand,
    Color? kiwiWash,
    Color? skin,
    Color? cream,
    Color? paper,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? onDanger,
    Color? info,
    Color? infoSoft,
    Color? focus,
    Color? glassFill,
    Color? glassStroke,
    Color? scrim,
  }) =>
      MyDataColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentSoft: accentSoft ?? this.accentSoft,
        brand: brand ?? this.brand,
        kiwiWash: kiwiWash ?? this.kiwiWash,
        skin: skin ?? this.skin,
        cream: cream ?? this.cream,
        paper: paper ?? this.paper,
        success: success ?? this.success,
        successSoft: successSoft ?? this.successSoft,
        warning: warning ?? this.warning,
        warningSoft: warningSoft ?? this.warningSoft,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        onDanger: onDanger ?? this.onDanger,
        info: info ?? this.info,
        infoSoft: infoSoft ?? this.infoSoft,
        focus: focus ?? this.focus,
        glassFill: glassFill ?? this.glassFill,
        glassStroke: glassStroke ?? this.glassStroke,
        scrim: scrim ?? this.scrim,
      );

  @override
  MyDataColors lerp(MyDataColors? other, double t) {
    if (other == null) return this;
    return MyDataColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      kiwiWash: Color.lerp(kiwiWash, other.kiwiWash, t)!,
      skin: Color.lerp(skin, other.skin, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// A theme the user can pick: it replaces accent, on-accent and accent-soft only (themes.json).
class MyDataThemeSpec {
  const MyDataThemeSpec({
    required this.id,
    required this.name,
    required this.accentLight,
    required this.accentDark,
    required this.onAccentLight,
    required this.onAccentDark,
    required this.accentSoftLight,
    required this.accentSoftDark,
  });

  final String id;
  final String name;
  final Color accentLight;
  final Color accentDark;
  final Color onAccentLight;
  final Color onAccentDark;
  final Color accentSoftLight;
  final Color accentSoftDark;
}

/// The themes in the order the ThemePicker shows them.
abstract final class MyDataThemes {
  static const kiwi = MyDataThemeSpec(
    id: 'kiwi',
    name: 'Kiwi',
    accentLight: Color(0xFF4C7814),
    accentDark: Color(0xFFA9CC4E),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF1A2408),
    accentSoftLight: Color(0xFFEBF3DA),
    accentSoftDark: Color(0xFF28331A),
  );
  static const graphite = MyDataThemeSpec(
    id: 'graphite',
    name: 'Graphite',
    accentLight: Color(0xFF232323),
    accentDark: Color(0xFFE6E6E4),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF161616),
    accentSoftLight: Color(0xFFE7E7E4),
    accentSoftDark: Color(0xFF2C2C2C),
  );
  static const dusk = MyDataThemeSpec(
    id: 'dusk',
    name: 'Dusk',
    accentLight: Color(0xFF3D5AA9),
    accentDark: Color(0xFF9DB4F2),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF0E1A3A),
    accentSoftLight: Color(0xFFE5EAF8),
    accentSoftDark: Color(0xFF232C47),
  );
  static const plum = MyDataThemeSpec(
    id: 'plum',
    name: 'Plum',
    accentLight: Color(0xFF7A3E8E),
    accentDark: Color(0xFFD2A6E0),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF2A0F33),
    accentSoftLight: Color(0xFFF1E4F5),
    accentSoftDark: Color(0xFF3B2145),
  );
  static const rose = MyDataThemeSpec(
    id: 'rose',
    name: 'Rose',
    accentLight: Color(0xFFA63A5B),
    accentDark: Color(0xFFEFA3B8),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF33101C),
    accentSoftLight: Color(0xFFF8E3E9),
    accentSoftDark: Color(0xFF40222B),
  );
  static const amber = MyDataThemeSpec(
    id: 'amber',
    name: 'Amber',
    accentLight: Color(0xFF8A5100),
    accentDark: Color(0xFFF0B45A),
    onAccentLight: Color(0xFFFFFFFF),
    onAccentDark: Color(0xFF2E1B00),
    accentSoftLight: Color(0xFFFBEBCF),
    accentSoftDark: Color(0xFF3D2C0C),
  );

  static const all = [kiwi, graphite, dusk, plum, rose, amber];
  static const fallback = kiwi;

  /// The theme with [id], or the default when the id is unknown or null.
  static MyDataThemeSpec byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => fallback);
}

/// Shadows for one mode (tokens.json "shadow"). CSS blur radii are converted to Flutter's
/// blurRadius so the rendered softness matches.
class MyDataShadows extends ThemeExtension<MyDataShadows> {
  const MyDataShadows({required this.shadow1, required this.shadow2, required this.shadowGlass});

  /// Resting cards and grouped lists on bg. This soft lift replaces borders.
  final List<BoxShadow> shadow1;
  /// Menus, popovers, sheets and dialogs.
  final List<BoxShadow> shadow2;
  /// Floating bars.
  final List<BoxShadow> shadowGlass;

  static const light = MyDataShadows(
    shadow1: [BoxShadow(color: Color(0x12141414), offset: Offset(0, 4), blurRadius: 16.45)],
    shadow2: [BoxShadow(color: Color(0x24141414), offset: Offset(0, 12), blurRadius: 30.31)],
    shadowGlass: [BoxShadow(color: Color(0x24141414), offset: Offset(0, 10), blurRadius: 26.85)],
  );

  static const dark = MyDataShadows(
    shadow1: [BoxShadow(color: Color(0x59000000), offset: Offset(0, 4), blurRadius: 16.45)],
    shadow2: [BoxShadow(color: Color(0x99000000), offset: Offset(0, 12), blurRadius: 30.31)],
    shadowGlass: [BoxShadow(color: Color(0x99000000), offset: Offset(0, 10), blurRadius: 26.85)],
  );

  @override
  MyDataShadows copyWith({List<BoxShadow>? shadow1, List<BoxShadow>? shadow2, List<BoxShadow>? shadowGlass}) =>
      MyDataShadows(shadow1: shadow1 ?? this.shadow1, shadow2: shadow2 ?? this.shadow2, shadowGlass: shadowGlass ?? this.shadowGlass);

  @override
  MyDataShadows lerp(MyDataShadows? other, double t) {
    if (other == null) return this;
    return MyDataShadows(
      shadow1: BoxShadow.lerpList(shadow1, other.shadow1, t)!,
      shadow2: BoxShadow.lerpList(shadow2, other.shadow2, t)!,
      shadowGlass: BoxShadow.lerpList(shadowGlass, other.shadowGlass, t)!,
    );
  }
}

/// Spacing (tokens.json "spacing").
abstract final class MyDataSpace {
  /// Gap between an icon and its label.
  static const double s1 = 4;
  /// Gap between chips and between buttons.
  static const double s2 = 8;
  /// Gap between an icon tile and its text; gap between cards in a tight grid.
  static const double s3 = 12;
  /// Row padding; side gutter on phone; gap between cards.
  static const double s4 = 16;
  /// Card padding.
  static const double s5 = 20;
  /// Gap between sections.
  static const double s6 = 24;
  /// Screen padding on desktop.
  static const double s8 = 32;
  /// Gap between major groups.
  static const double s10 = 40;
  /// First-run and empty-state breathing room.
  static const double s12 = 48;
  /// Top inset on phone screens without a bar.
  static const double s16 = 64;
}

/// Corner radii (tokens.json "radius").
abstract final class MyDataRadius {
  /// Photo tiles, icon tiles, small wells.
  static const double sm = 10;
  /// Inputs.
  static const double md = 14;
  /// Cards and grouped lists.
  static const double lg = 20;
  /// Sheets, dialogs and floating bars.
  static const double xl = 28;
  /// Buttons.
  static const double control = 999;
  /// Chips, segmented controls, switches, avatars.
  static const double pill = 999;
}

/// Sizes (tokens.json "size").
abstract final class MyDataSize {
  /// Buttons, inputs, chips and the minimum touch target.
  static const double controlHeight = 44;
  /// Desktop-only compact density.
  static const double controlHeightCompact = 36;
  /// Rows in a grouped list.
  static const double rowHeight = 56;
  /// The rounded tile behind a row's icon.
  static const double iconTile = 36;
  /// Default icon box. Icons use a 1.75px rounded stroke.
  static const double icon = 20;
  /// Desktop sidebar.
  static const double sidebarWidth = 248;
  /// Maximum width of reading and settings columns.
  static const double contentMax = 880;
}

/// Blur radii in logical pixels (tokens.json "blur").
abstract final class MyDataBlur {
  /// Backdrop blur behind glass-fill. Becomes 0, with a surface fill, when the user reduces transparency.
  static const double glass = 24;
}

/// Font families, bundled in this package (tokens.json "type.families", first choice of each stack).
abstract final class MyDataFontFamily {
  static const display = 'PlusJakartaSans';
  static const body = 'Figtree';
  static const mono = 'JetBrainsMono';
  /// The display font's name as people write it (for licences).
  static const displayName = 'Plus Jakarta Sans';
  /// The body font's name as people write it (for licences).
  static const bodyName = 'Figtree';
  /// The mono font's name as people write it (for licences).
  static const monoName = 'JetBrains Mono';
  static const package = 'mydata_ui';
}

/// The type styles (tokens.json "type.groups"), without colour: widgets take colour from
/// MyDataColors. Line heights are exact; letter spacing in em is converted to pixels.
abstract final class MyDataType {
  /// First-run headlines and the large title at the top of a phone screen.
  static const displayXl = TextStyle(
    fontFamily: MyDataFontFamily.display,
    package: MyDataFontFamily.package,
    fontSize: 40,
    height: 1.1500,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
  /// Screen titles on desktop; the figure in a stat tile.
  static const displayLg = TextStyle(
    fontFamily: MyDataFontFamily.display,
    package: MyDataFontFamily.package,
    fontSize: 30,
    height: 1.2000,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
  /// Card titles that lead a screen, dialog titles.
  static const title = TextStyle(
    fontFamily: MyDataFontFamily.display,
    package: MyDataFontFamily.package,
    fontSize: 22,
    height: 1.2727,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.22,
  );
  /// Card and section headings.
  static const heading = TextStyle(
    fontFamily: MyDataFontFamily.body,
    package: MyDataFontFamily.package,
    fontSize: 17,
    height: 1.4118,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
  );
  /// Default text on desktop. Phones use 16px.
  static const body = TextStyle(
    fontFamily: MyDataFontFamily.body,
    package: MyDataFontFamily.package,
    fontSize: 15,
    height: 1.4667,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
  );
  /// Row titles, button labels, emphasis.
  static const bodyStrong = TextStyle(
    fontFamily: MyDataFontFamily.body,
    package: MyDataFontFamily.package,
    fontSize: 15,
    height: 1.4667,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
  );
  /// Secondary lines, helper text, metadata. Use ink-muted.
  static const caption = TextStyle(
    fontFamily: MyDataFontFamily.body,
    package: MyDataFontFamily.package,
    fontSize: 13,
    height: 1.3846,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
  );
  /// Field labels and the small heading above a grouped list. Sentence case, not uppercase.
  static const label = TextStyle(
    fontFamily: MyDataFontFamily.body,
    package: MyDataFontFamily.package,
    fontSize: 13,
    height: 1.3846,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
  );
  /// Paths, addresses and values the user copies.
  static const mono = TextStyle(
    fontFamily: MyDataFontFamily.mono,
    package: MyDataFontFamily.package,
    fontSize: 13,
    height: 1.5385,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
  );
}
