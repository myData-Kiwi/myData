// GENERATED from design/tokens.json (version 6), design/themes.json and
// design/themes/kiwi/theme.json (the colour roles tokens.json has no token for)
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
    required this.surfaceHover,
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
    required this.dataRed,
    required this.dataOrange,
    required this.dataYellow,
    required this.dataGreen,
    required this.dataBlue,
    required this.dataPurple,
    required this.dataBrown,
    required this.dataGrey,
    required this.sidebar,
    required this.toolbar,
    required this.edge,
    required this.link,
    required this.selection,
    required this.onSelection,
    required this.selectionInactive,
    required this.focusOnDanger,
    required this.avatarFill,
    required this.shadow,
    required this.onAvatar,
  });

  /// Window background: a soft neutral grey with no tint, so every theme sits on it. Cards sit on it. Text uses ink or ink-muted.
  final Color bg;
  /// Cards, grouped lists, inputs and sheets. Lifted from bg by shadow-1 in light and by its lighter value in dark.
  final Color surface;
  /// Menus, popovers and dialogs. Pair with shadow-2.
  final Color surfaceRaised;
  /// Track of a segmented control, wells, icon tiles with no tint.
  final Color surfaceSunken;
  /// Neutral hover and highlight fill: a hovered IconButton, Select field or list row, the pointer's highlight in a Menu or a Select's list. At least 1.3:1 on bg, surface and surface-raised in both modes. Never selection, never the only signal.
  final Color surfaceHover;
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
  /// Red in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataRed;
  /// Orange in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataOrange;
  /// Yellow in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataYellow;
  /// Green in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataGreen;
  /// Blue in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataBlue;
  /// Purple in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataPurple;
  /// Brown in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataBrown;
  /// Grey in the palette for calendars myData owns (ColourPicker). A data colour: one value in both modes, drawn as given with DataColour's edge rule, never a control colour or a fill behind text. Not replaced by a theme.
  final Color dataGrey;
  /// Sidebar ground when solid (and the fallback for a translucent one).
  final Color sidebar;
  /// Toolbar ground when solid.
  final Color toolbar;
  /// The theme's outline colour when its borders use it.
  final Color edge;
  /// Accent used as text: links and text buttons, 4.5:1 on bg and surface.
  final Color link;
  /// The selected row's fill or marker.
  final Color selection;
  /// Text on selection.
  final Color onSelection;
  /// A selection in a list that does not have focus.
  final Color selectionInactive;
  /// The focus ring on anything already red.
  final Color focusOnDanger;
  /// An avatar's ground behind initials (was kiwi-wash).
  final Color avatarFill;
  /// The colour shadows are drawn in, at the elevation's strength.
  final Color shadow;
  /// Initials on avatar-fill: ink or surface, whichever reads better.
  final Color onAvatar;

  /// The Kiwi theme, light mode.
  static const light = MyDataColors(
    bg: Color(0xFFF6F6F5),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEDEB),
    surfaceHover: Color(0xFFD9D9D6),
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
    dataRed: Color(0xFFD34730),
    dataOrange: Color(0xFFEA700F),
    dataYellow: Color(0xFFE7BD1B),
    dataGreen: Color(0xFF36A462),
    dataBlue: Color(0xFF159CE2),
    dataPurple: Color(0xFF8B51E1),
    dataBrown: Color(0xFF8A6859),
    dataGrey: Color(0xFF939393),
    sidebar: Color(0xFFF6F6F5),
    toolbar: Color(0xFFF6F6F5),
    edge: Color(0xFF1A1A19),
    link: Color(0xFF4B7713),
    selection: Color(0xFF4C7814),
    onSelection: Color(0xFFFFFFFF),
    selectionInactive: Color(0xFFEDEDEB),
    focusOnDanger: Color(0xFF1A1A19),
    avatarFill: Color(0xFFE0E0DD),
    shadow: Color(0xFF141414),
    onAvatar: Color(0xFF1A1A19),
  );

  /// The Kiwi theme, dark mode.
  static const dark = MyDataColors(
    bg: Color(0xFF111111),
    surface: Color(0xFF1A1A1A),
    surfaceRaised: Color(0xFF232323),
    surfaceSunken: Color(0xFF0B0B0B),
    surfaceHover: Color(0xFF383838),
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
    dataRed: Color(0xFFD34730),
    dataOrange: Color(0xFFEA700F),
    dataYellow: Color(0xFFE7BD1B),
    dataGreen: Color(0xFF36A462),
    dataBlue: Color(0xFF159CE2),
    dataPurple: Color(0xFF8B51E1),
    dataBrown: Color(0xFF8A6859),
    dataGrey: Color(0xFF939393),
    sidebar: Color(0xFF111111),
    toolbar: Color(0xFF111111),
    edge: Color(0xFFEDEDEB),
    link: Color(0xFFA9CC4E),
    selection: Color(0xFFA9CC4E),
    onSelection: Color(0xFF1A2408),
    selectionInactive: Color(0xFF0B0B0B),
    focusOnDanger: Color(0xFFEDEDEB),
    avatarFill: Color(0xFF333333),
    shadow: Color(0xFF000000),
    onAvatar: Color(0xFFEDEDEB),
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
    Color? surfaceHover,
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
    Color? dataRed,
    Color? dataOrange,
    Color? dataYellow,
    Color? dataGreen,
    Color? dataBlue,
    Color? dataPurple,
    Color? dataBrown,
    Color? dataGrey,
    Color? sidebar,
    Color? toolbar,
    Color? edge,
    Color? link,
    Color? selection,
    Color? onSelection,
    Color? selectionInactive,
    Color? focusOnDanger,
    Color? avatarFill,
    Color? shadow,
    Color? onAvatar,
  }) =>
      MyDataColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        surfaceHover: surfaceHover ?? this.surfaceHover,
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
        dataRed: dataRed ?? this.dataRed,
        dataOrange: dataOrange ?? this.dataOrange,
        dataYellow: dataYellow ?? this.dataYellow,
        dataGreen: dataGreen ?? this.dataGreen,
        dataBlue: dataBlue ?? this.dataBlue,
        dataPurple: dataPurple ?? this.dataPurple,
        dataBrown: dataBrown ?? this.dataBrown,
        dataGrey: dataGrey ?? this.dataGrey,
        sidebar: sidebar ?? this.sidebar,
        toolbar: toolbar ?? this.toolbar,
        edge: edge ?? this.edge,
        link: link ?? this.link,
        selection: selection ?? this.selection,
        onSelection: onSelection ?? this.onSelection,
        selectionInactive: selectionInactive ?? this.selectionInactive,
        focusOnDanger: focusOnDanger ?? this.focusOnDanger,
        avatarFill: avatarFill ?? this.avatarFill,
        shadow: shadow ?? this.shadow,
        onAvatar: onAvatar ?? this.onAvatar,
      );

  @override
  MyDataColors lerp(MyDataColors? other, double t) {
    if (other == null) return this;
    return MyDataColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
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
      dataRed: Color.lerp(dataRed, other.dataRed, t)!,
      dataOrange: Color.lerp(dataOrange, other.dataOrange, t)!,
      dataYellow: Color.lerp(dataYellow, other.dataYellow, t)!,
      dataGreen: Color.lerp(dataGreen, other.dataGreen, t)!,
      dataBlue: Color.lerp(dataBlue, other.dataBlue, t)!,
      dataPurple: Color.lerp(dataPurple, other.dataPurple, t)!,
      dataBrown: Color.lerp(dataBrown, other.dataBrown, t)!,
      dataGrey: Color.lerp(dataGrey, other.dataGrey, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      toolbar: Color.lerp(toolbar, other.toolbar, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      link: Color.lerp(link, other.link, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      onSelection: Color.lerp(onSelection, other.onSelection, t)!,
      selectionInactive: Color.lerp(selectionInactive, other.selectionInactive, t)!,
      focusOnDanger: Color.lerp(focusOnDanger, other.focusOnDanger, t)!,
      avatarFill: Color.lerp(avatarFill, other.avatarFill, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      onAvatar: Color.lerp(onAvatar, other.onAvatar, t)!,
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
  /// The checkbox's box.
  static const double xs = 6;
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
  /// Width of a Dialog's panel, or the window less space-8 on each side when that is narrower.
  static const double dialogWidth = 520;
  /// Width of an Inspector at the end edge of the window.
  static const double inspectorWidth = 440;
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

/// The Mac frame's fonts (tokens.json "macos.families"). [text] and [display] are the system's own
/// (Flutter's macOS engine resolves them through CoreText); [icons] is bundled in this package.
abstract final class MyDataMacFont {
  static const text = '.AppleSystemUIFont';
  static const display = '.AppleSystemUIFont';
  static const icons = 'Lucide';
}

/// The Mac frame's colours for one appearance (tokens.json "macos.color"). The constants are the
/// fallbacks; [withSystem] takes the values the system reports, by token name.
class MyDataMacColors extends ThemeExtension<MyDataMacColors> {
  const MyDataMacColors({
    required this.accent,
    required this.onAccent,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.quaternaryLabel,
    required this.separator,
    required this.contentBackground,
    required this.windowBackground,
    required this.sidebarBackground,
    required this.selectionInactive,
    required this.sidebarSelection,
    required this.hover,
    required this.focusRing,
    required this.red,
    required this.green,
    required this.toolbarItem,
  });

  /// The system's accent colour (controlAccentColor) when it cannot be read: macOS's default blue. Selection in a focused list, the default button, links, sidebar icons.
  final Color accent;

  /// Text and icons on accent: a selected row in a focused list.
  final Color onAccent;

  /// Primary text (labelColor).
  final Color label;

  /// Secondary text: a field's label, a count, a source line (secondaryLabelColor).
  final Color secondaryLabel;

  /// Placeholders and disabled text (tertiaryLabelColor).
  final Color tertiaryLabel;

  /// The faintest fill: a search field's ground (quaternaryLabelColor).
  final Color quaternaryLabel;

  /// Hairlines between columns and under the toolbar (separatorColor).
  final Color separator;

  /// Behind lists and the record they open (controlBackgroundColor).
  final Color contentBackground;

  /// Behind everything else in a window (windowBackgroundColor).
  final Color windowBackground;

  /// The sidebar where it cannot be translucent: reduced transparency, tests and screenshots.
  final Color sidebarBackground;

  /// A selected row while its list does not have focus (unemphasizedSelectedContentBackgroundColor).
  final Color selectionInactive;

  /// The selected row of a sidebar: a neutral fill under its accent icon.
  final Color sidebarSelection;

  /// Under the pointer on a toolbar item or a borderless button.
  final Color hover;

  /// The keyboard focus ring (keyboardFocusIndicatorColor, which follows the system's accent) on every control in the Mac frame, a field in error included: the branded red `focus` ring and its `ink` rule are not used on a Mac.
  final Color focusRing;

  /// The system's red (systemRed): today's date in myCalendar, as Calendar.app marks it.
  final Color red;

  /// The system's green (systemGreen): the round add button in an editing form, as Contacts' edit mode draws it.
  final Color green;

  /// The flat stand-in for a toolbar item's Liquid Glass (Flutter cannot draw glass): with a 0.5 pt `separator` outline.
  final Color toolbarItem;

  /// The system defaults, light appearance.
  static const light = MyDataMacColors(
    accent: Color(0xFF007AFF),
    onAccent: Color(0xFFFFFFFF),
    label: Color(0xD9000000),
    secondaryLabel: Color(0x80000000),
    tertiaryLabel: Color(0x42000000),
    quaternaryLabel: Color(0x1A000000),
    separator: Color(0x1A000000),
    contentBackground: Color(0xFFFFFFFF),
    windowBackground: Color(0xFFECECEC),
    sidebarBackground: Color(0xFFE8E8E8),
    selectionInactive: Color(0xFFDCDCDC),
    sidebarSelection: Color(0x1A000000),
    hover: Color(0x0D000000),
    focusRing: Color(0x80007AFF),
    red: Color(0xFFFF3B30),
    green: Color(0xFF28CD41),
    toolbarItem: Color(0xFFFCFCFC),
  );

  /// The system defaults, dark appearance.
  static const dark = MyDataMacColors(
    accent: Color(0xFF0A84FF),
    onAccent: Color(0xFFFFFFFF),
    label: Color(0xD9FFFFFF),
    secondaryLabel: Color(0x8CFFFFFF),
    tertiaryLabel: Color(0x40FFFFFF),
    quaternaryLabel: Color(0x1AFFFFFF),
    separator: Color(0x1AFFFFFF),
    contentBackground: Color(0xFF1E1E1E),
    windowBackground: Color(0xFF323232),
    sidebarBackground: Color(0xFF2C2C2C),
    selectionInactive: Color(0xFF464646),
    sidebarSelection: Color(0x1FFFFFFF),
    hover: Color(0x12FFFFFF),
    focusRing: Color(0x800A84FF),
    red: Color(0xFFFF453A),
    green: Color(0xFF32D74B),
    toolbarItem: Color(0xFF3D3D3D),
  );

  /// The token names, as the system channel reports them.
  static const tokenNames = ['accent', 'on-accent', 'label', 'secondary-label', 'tertiary-label', 'quaternary-label', 'separator', 'content-background', 'window-background', 'sidebar-background', 'selection-inactive', 'sidebar-selection', 'hover', 'focus-ring', 'red', 'green', 'toolbar-item'];

  /// These colours with the ones in [system] (by token name) in their place.
  MyDataMacColors withSystem(Map<String, Color> system) => MyDataMacColors(
        accent: system['accent'] ?? accent,
        onAccent: system['on-accent'] ?? onAccent,
        label: system['label'] ?? label,
        secondaryLabel: system['secondary-label'] ?? secondaryLabel,
        tertiaryLabel: system['tertiary-label'] ?? tertiaryLabel,
        quaternaryLabel: system['quaternary-label'] ?? quaternaryLabel,
        separator: system['separator'] ?? separator,
        contentBackground: system['content-background'] ?? contentBackground,
        windowBackground: system['window-background'] ?? windowBackground,
        sidebarBackground: system['sidebar-background'] ?? sidebarBackground,
        selectionInactive: system['selection-inactive'] ?? selectionInactive,
        sidebarSelection: system['sidebar-selection'] ?? sidebarSelection,
        hover: system['hover'] ?? hover,
        focusRing: system['focus-ring'] ?? focusRing,
        red: system['red'] ?? red,
        green: system['green'] ?? green,
        toolbarItem: system['toolbar-item'] ?? toolbarItem,
      );

  @override
  MyDataMacColors copyWith({Color? accent, Color? onAccent, Color? label, Color? secondaryLabel, Color? tertiaryLabel, Color? quaternaryLabel, Color? separator, Color? contentBackground, Color? windowBackground, Color? sidebarBackground, Color? selectionInactive, Color? sidebarSelection, Color? hover, Color? focusRing, Color? red, Color? green, Color? toolbarItem}) =>
      MyDataMacColors(accent: accent ?? this.accent, onAccent: onAccent ?? this.onAccent, label: label ?? this.label, secondaryLabel: secondaryLabel ?? this.secondaryLabel, tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel, quaternaryLabel: quaternaryLabel ?? this.quaternaryLabel, separator: separator ?? this.separator, contentBackground: contentBackground ?? this.contentBackground, windowBackground: windowBackground ?? this.windowBackground, sidebarBackground: sidebarBackground ?? this.sidebarBackground, selectionInactive: selectionInactive ?? this.selectionInactive, sidebarSelection: sidebarSelection ?? this.sidebarSelection, hover: hover ?? this.hover, focusRing: focusRing ?? this.focusRing, red: red ?? this.red, green: green ?? this.green, toolbarItem: toolbarItem ?? this.toolbarItem);

  @override
  MyDataMacColors lerp(MyDataMacColors? other, double t) {
    if (other == null) return this;
    return MyDataMacColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
      quaternaryLabel: Color.lerp(quaternaryLabel, other.quaternaryLabel, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      contentBackground: Color.lerp(contentBackground, other.contentBackground, t)!,
      windowBackground: Color.lerp(windowBackground, other.windowBackground, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      selectionInactive: Color.lerp(selectionInactive, other.selectionInactive, t)!,
      sidebarSelection: Color.lerp(sidebarSelection, other.sidebarSelection, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      red: Color.lerp(red, other.red, t)!,
      green: Color.lerp(green, other.green, t)!,
      toolbarItem: Color.lerp(toolbarItem, other.toolbarItem, t)!,
    );
  }
}

/// The Mac frame's type styles (tokens.json "macos.type"), without colour. Letter spacing follows
/// Apple's tracking for SF Pro at each size.
abstract final class MyDataMacType {
  /// Default text: list rows, values on a record (macOS body).
  static const body = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 13,
    height: 1.2308,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.078,
  );
  /// The sorting name in a list row, a toolbar title on its own (macOS body, emphasized).
  static const bodyEmphasized = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 13,
    height: 1.2308,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.078,
  );
  /// A field's label on a record, a button's smaller text.
  static const callout = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 12,
    height: 1.2500,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
  );
  /// Counts, a source line, the sidebar's connection line.
  static const caption = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 11,
    height: 1.2727,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.055,
  );
  /// A list's section letters and a sidebar's headings.
  static const captionEmphasized = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 11,
    height: 1.2727,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.055,
  );
  /// The caption under a round quick action (message, call, mail).
  static const action = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 10,
    height: 1.3000,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.12,
  );
  /// A toolbar title: the section shown.
  static const title = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 15,
    height: 1.3333,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.225,
  );
  /// A pane's title, one per pane: a record's name, "Merge 2 contacts?", "New Contact", a month in myCalendar, a page of myData. The second of the three title roles (toolbar `title`, `pane-title`, `section-header`).
  static const paneTitle = TextStyle(
    fontFamily: MyDataMacFont.display,
    fontSize: 22,
    height: 1.2727,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
  );
  /// A section's heading inside a pane (a Settings group, "After merging", a list's group). The third title role.
  static const sectionHeader = TextStyle(
    fontFamily: MyDataMacFont.text,
    fontSize: 13,
    height: 1.2308,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.078,
  );
  /// A record's name at the top of its page.
  static const name = TextStyle(
    fontFamily: MyDataMacFont.display,
    fontSize: 22,
    height: 1.2727,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
  );
  /// Initials in a record's large avatar.
  static const avatar = TextStyle(
    fontFamily: MyDataMacFont.display,
    fontSize: 24,
    height: 1.1667,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
  );
}

/// The Mac frame's sizes (tokens.json "macos.size").
abstract final class MyDataMacSize {
  /// The unified toolbar: the title bar and the toolbar in one band.
  static const double toolbarHeight = 52;
  /// The sidebar column: the floating panel (`sidebar-margin` in from the window's left, top and bottom edges) with the app's sections. 208 is SwiftUI's default on macOS 26 (a 200 pt panel 8 pt in).
  static const double sidebarWidth = 208;
  /// The list column beside the record it opens.
  static const double listWidth = 280;
  /// A row in a plain list: about 30 in an 800pt window.
  static const double rowHeight = 24;
  /// A list's section heading (its letter).
  static const double sectionHeight = 22;
  /// A sidebar row (macOS 26: 32 pt, as SwiftUI's sidebar).
  static const double sidebarRowHeight = 32;
  /// Toolbar items and the search field.
  static const double controlHeight = 28;
  /// A push button (Restore, Retry, a dialog's buttons) in the Mac frame: a capsule with the label in `body`.
  static const double pushButtonHeight = 24;
  /// The smallest target: a push button in a dense row.
  static const double controlMin = 20;
  /// The toolbar's search field (as SwiftUI's `.searchable` in the toolbar on macOS 26).
  static const double searchWidth = 325;
  /// Icons in the sidebar, the toolbar and buttons.
  static const double icon = 16;
  /// The avatar at the top of a record's page.
  static const double avatar = 64;
  /// A round quick action under a record's name.
  static const double actionButton = 32;
  /// The labels' column on a record's page, right-aligned.
  static const double labelColumn = 104;
  /// Between a list's side and its selection fill.
  static const double rowInset = 10;
  /// Between the selection fill's side and the row's text.
  static const double rowPadding = 8;
  /// A toolbar item's capsule or circle (macOS 26 toolbar items, 36 pt).
  static const double toolbarItemHeight = 36;
  /// From the column's edges to the first and last toolbar items.
  static const double toolbarInset = 8;
  /// The room the window's close, minimise and zoom buttons take at the toolbar band's leading edge when no sidebar is beside the pane (a window showing one state, such as no source yet).
  static const double windowControlsWidth = 72;
  /// The floating sidebar panel's gap to the window's left, top and bottom edges (macOS 26).
  static const double sidebarMargin = 8;
  /// The keyboard focus ring's width in the Mac frame (the system's is about 3 pt; check it against a live window).
  static const double focusRingWidth = 3;
  /// The gap between a control and its focus ring in the Mac frame: none, the ring hugs the control as the system's does.
  static const double focusRingOffset = 0;
  /// A hairline: a group's outline, a toolbar item's edge, a switch thumb's edge (one pixel on a Retina screen).
  static const double hairline = 0.5;
  /// The smallest gap: between a title and the line under it, inside a segmented control, a field's text from its bezel.
  static const double tight = 2;
  /// A detail pane's readable column (a record's page, the editor, Merge, Review), leading-aligned; and a Settings-style form's column, centred.
  static const double contentWidth = 640;
  /// An alert's panel: macOS 26 alerts are narrow, their text wrapping (NSAlert is about 260 pt plus its margins).
  static const double alertWidth = 300;
  /// A list column beside a record, at its narrowest.
  static const double listMinWidth = 240;
  /// A list column beside a record, at its widest.
  static const double listMaxWidth = 340;
  /// A day's or an item's list beside a grid (myCalendar's day list).
  static const double sideListWidth = 320;
  /// The narrowest content beside which a side list still fits; narrower, the side list goes under it.
  static const double besideMinWidth = 760;
  /// A month grid's cell at least this wide shows each event's start time.
  static const double gridTimeCellWidth = 136;
}

/// The Mac frame's corner radii (tokens.json "macos.radius").
abstract final class MyDataMacRadius {
  /// A selected list row, and a run of them.
  static const double selection = 6;
  /// A selected sidebar row.
  static const double sidebarSelection = 8;
  /// Toolbar items and borderless buttons under the pointer.
  static const double control = 7;
  /// The toolbar's search field: a capsule.
  static const double field = 999;
  /// The floating sidebar panel's corners (macOS 26).
  static const double sidebar = 16;
}

