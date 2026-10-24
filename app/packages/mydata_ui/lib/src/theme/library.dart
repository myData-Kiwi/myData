/// The themes this build knows (design/themes/ARCHITECTURE.md 3.1 and 3.3): the built-ins, read from the
/// generated JSON without waiting for an asset, and the designed looks of design/themes, bundled as assets.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

import 'builtin_themes.g.dart';
import 'choice.dart';
import 'look.dart';
import 'resolve.dart';
import 'roles.dart';
import 'strict_json.dart';
import 'theme_file.dart';
import 'validate.dart';

/// The built-in themes and their resolved looks.
///
/// System (on macOS, the Mac shell) and the six drawn looks of design/themes, each with its palettes: Kiwi
/// (Kiwi, Sky, Violet), Hairline (Graphite, Slate, Cobalt), Frosted (Dusk, Aurora, Sand), Journal (Plum, Ink
/// blue, Forest), Sticker (Rose, Mint, Mustard) and Paperback (Amber, Sepia, Linen).
///
/// **Today's old colours** (`graphite`, `dusk`, `plum`, `rose`, `amber`: the host's old `/appearance` ids,
/// and Kiwi's palettes in phases 1 and 2) are hidden aliases on Kiwi: a choice of Kiwi in one of them is
/// drawn as the theme that colour now belongs to, in that palette ([movedColours], ARCHITECTURE.md 4.2),
/// never as Kiwi's default.
abstract final class ThemeLibrary {
  static const systemId = MyDataLook.systemThemeId;
  static const kiwiId = 'mydata.kiwi';

  static Map<String, Object?> _read(String text) => readStrictJson(text) as Map<String, Object?>;

  static final Map<String, Map<String, Object?>> _json = {
    for (final e in builtInThemeJson.entries) e.key: _read(e.value),
  };

  static Map<String, Object?> get _kiwiJson => _json[kiwiId]!;

  /// Every built-in, by id, in the gallery's order. A theme that says no `based-on` is based on Kiwi.
  static final Map<String, ThemeFile> _builtIn = {
    for (final e in _json.entries)
      e.key: ThemeFile.fromJson(e.value, base: _json[e.value['based-on']] ?? _kiwiJson),
  };

  /// Kiwi, the house style.
  static ThemeFile get kiwi => _builtIn[kiwiId]!;

  /// System: the platform's own look. Its style is Kiwi's wherever the platform has no pass yet.
  static ThemeFile get system => _builtIn[systemId]!;

  /// System, then the six drawn looks, in the gallery's order.
  static List<ThemeFile> get builtIns => _builtIn.values.toList(growable: false);

  /// The themes the gallery offers, in its order (ARCHITECTURE.md 4.4): System, then the built-ins.
  static List<ThemeFile> get offered => builtIns;

  static ThemeFile? byId(String? id) => _testing[id] ?? _builtIn[id];

  static final _testing = <String?, ThemeFile>{};

  /// Makes [theme] known to [byId] until [clearForTesting], for tests of a theme the shipped library does
  /// not have, or of a built-in's file as it is on disk now (the preview harness draws a `design/themes`
  /// file before it is generated): a theme added here is drawn in place of the built-in with its id.
  @visibleForTesting
  static void addForTesting(ThemeFile theme) => _testing[theme.id] = theme;

  @visibleForTesting
  static void clearForTesting() => _testing.clear();

  /// Draws every look at increased contrast ([lookFor]), as the preview harness's `--contrast` asks: the
  /// apps do not follow the system's setting yet (ARCHITECTURE.md 2.3), so this is how a theme's
  /// increased-contrast set is seen in the real app before they do.
  static bool debugIncreasedContrast = false;

  /// Today's five other colours, and the theme and palette each moved to (ARCHITECTURE.md 4.2): a choice of
  /// Kiwi in one of them is that theme in that palette.
  static const movedColours = {
    'graphite': ThemeChoice('mydata.hairline', 'graphite'),
    'dusk': ThemeChoice('mydata.frosted', 'dusk'),
    'plum': ThemeChoice('mydata.journal', 'plum'),
    'rose': ThemeChoice('mydata.sticker', 'rose'),
    'amber': ThemeChoice('mydata.paperback', 'amber'),
  };

  /// Where [choice] moved, when it is Kiwi in one of today's old colours ([movedColours]); else null.
  static ThemeChoice? moved(ThemeChoice? choice) =>
      choice != null && choice.theme == kiwiId ? movedColours[choice.palette] : null;

  /// [choice] as it is drawn: a theme this build has (else System) and, for a theme with palettes, one it
  /// has (else its default); never a palette for System (ARCHITECTURE.md 4.1). Null is System.
  static ThemeChoice normalise(ThemeChoice? choice) {
    choice = moved(choice) ?? choice;
    final theme = byId(choice?.theme);
    if (theme == null || theme.palettes.isEmpty) return ThemeChoice.system;
    return ThemeChoice(theme.id, theme.palette(choice!.palette)!.id);
  }

  /// Whether [choice] names a theme this build has, in a palette that theme has (or none): a choice that
  /// is not falls back ([normalise]), which myData's Appearance says once.
  static bool knows(ThemeChoice choice) {
    if (moved(choice) != null) return true;
    final theme = byId(choice.theme);
    if (theme == null) return false;
    final p = choice.palette;
    return p == null || theme.palettes.isEmpty || theme.palettes.any((x) => x.id == p);
  }

  /// [theme] with its default palette: what the gallery shows when the theme changes, since palette ids
  /// belong to one theme.
  static ThemeChoice defaultChoice(ThemeFile theme) =>
      theme.palettes.isEmpty ? ThemeChoice(theme.id) : ThemeChoice(theme.id, theme.defaultPalette!.id);

  /// One of today's colour ids (the host's old `/appearance` theme, `lastTheme` in the device's settings) as
  /// the choice it is drawn as now: Kiwi for `kiwi`, else the theme the colour moved to, in that palette
  /// ([movedColours]: `plum` is Journal, Plum). Null for anything else.
  static ThemeChoice? fromColour(String? colour) {
    if (colour == null) return null;
    if (movedColours[colour] case final c?) return c;
    return kiwi.palettes.any((p) => p.id == colour) ? ThemeChoice(kiwiId, colour) : null;
  }

  /// How people see a choice: "System", or the theme and its palette ("Kiwi, Plum"; "Kiwi, Kiwi" too, so the
  /// palette is always named when the theme has more than one).
  static String describe(ThemeChoice choice) {
    final c = normalise(choice);
    final theme = byId(c.theme)!;
    if (theme.palettes.length < 2) return theme.name;
    return '${theme.name}, ${theme.palette(c.palette)!.name}';
  }

  /// [theme]'s palettes as the swatches a palette row shows: each one's name, and its accent, on-accent and
  /// accent-soft in light and dark as resolved.
  static List<PaletteSwatch> paletteSwatches(ThemeFile theme) => _swatches[theme] ??= [
        for (final p in theme.palettes)
          () {
            final l = look(theme, paletteId: p.id, brightness: Brightness.light).colors;
            final d = look(theme, paletteId: p.id, brightness: Brightness.dark).colors;
            return PaletteSwatch(
              id: p.id,
              name: p.name,
              accentLight: l.accent,
              accentDark: d.accent,
              onAccentLight: l.onAccent,
              onAccentDark: d.onAccent,
              accentSoftLight: l.accentSoft,
              accentSoftDark: d.accentSoft,
            );
          }(),
      ];

  static final _swatches = Expando<List<PaletteSwatch>>('swatches');

  /// [choice]'s look for [brightness] (after [normalise]).
  static MyDataLook lookFor(ThemeChoice? choice, Brightness brightness,
      {bool increasedContrast = false, TargetPlatform? platform}) {
    final c = normalise(choice);
    return look(byId(c.theme)!,
        paletteId: c.palette,
        brightness: brightness,
        increasedContrast: increasedContrast || debugIncreasedContrast,
        platform: platform);
  }

  /// Kiwi's default palette, the resolver's starting point for roles a palette leaves out.
  static final RoleDefaults defaults = RoleDefaults(
    light: kiwi.defaultPalette!.given(LookMode.light),
    dark: kiwi.defaultPalette!.given(LookMode.dark),
  );

  /// What the validator needs: the schema, the built-ins' styles and today's colours.
  static ThemeFormat format({Map<String, Map<String, Object?>> extraStyles = const {}}) => ThemeFormat(
        schema: _schema,
        builtInStyles: {..._json, ...extraStyles},
        defaults: defaults,
      );

  /// The schema is ours, not a theme file, so it is read with `dart:convert` (it is deeper than a theme
  /// file may be).
  static final Map<String, Object?> _schema = jsonDecode(themeSchemaJson) as Map<String, Object?>;

  /// Resolved looks, per theme file (the object: a file read again, or edited, is resolved again) and
  /// (palette, brightness, contrast, platform). Kept as long as the file is.
  static final _looks = Expando<Map<(String?, Brightness, bool, TargetPlatform), MyDataLook>>('looks');

  /// [theme] in [paletteId] for [brightness], resolved once per theme file and kept, so a rebuild gets the
  /// same look (and ThemeData does not animate between two equal ones).
  static MyDataLook look(
    ThemeFile theme, {
    String? paletteId,
    required Brightness brightness,
    bool increasedContrast = false,
    TargetPlatform? platform,
  }) {
    final p = platform ?? defaultTargetPlatform;
    final key = (theme.palette(paletteId)?.id, brightness, increasedContrast, p);
    return (_looks[theme] ??= {})[key] ??= MyDataLook.resolve(theme,
        paletteId: paletteId,
        brightness: brightness,
        defaults: defaults,
        increasedContrast: increasedContrast,
        platform: p);
  }
}

/// One palette as a palette row's swatch shows it ([ThemeLibrary.paletteSwatches]): its id and name, and its
/// accent, on-accent and accent-soft in light and dark as resolved.
@immutable
class PaletteSwatch {
  const PaletteSwatch({
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
  final Color accentLight, accentDark, onAccentLight, onAccentDark, accentSoftLight, accentSoftDark;

  Color accent(Brightness b) => b == Brightness.dark ? accentDark : accentLight;
  Color onAccent(Brightness b) => b == Brightness.dark ? onAccentDark : onAccentLight;
  Color accentSoft(Brightness b) => b == Brightness.dark ? accentSoftDark : accentSoftLight;
}
