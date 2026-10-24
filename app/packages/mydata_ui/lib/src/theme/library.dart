/// The themes this build knows (design/themes/ARCHITECTURE.md 3.1 and 3.3): the built-ins, read from the
/// generated JSON without waiting for an asset, and the designed looks of design/themes, bundled as assets.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
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
/// Phases 1 and 2 draw System (on macOS, the Mac shell) and Kiwi in one of today's six colours: Kiwi's
/// palettes are `kiwi`, `graphite`, `dusk`, `plum`, `rose` and `amber`, the ids the host's `/appearance` and
/// the device settings already hold. Phase 3 switches Kiwi to design/themes/kiwi and moves the other five to
/// the themes they now belong to (ARCHITECTURE.md 4.2).
abstract final class ThemeLibrary {
  static const systemId = MyDataLook.systemThemeId;
  static const kiwiId = 'mydata.kiwi';

  static Map<String, Object?> _read(String text) => readStrictJson(text) as Map<String, Object?>;

  static final Map<String, Object?> _kiwiJson = _read(kiwiThemeJson);
  static final Map<String, Object?> _systemJson = _read(systemThemeJson);

  /// Kiwi as the apps draw it today, with today's six colours as its palettes.
  static final ThemeFile kiwi = ThemeFile.fromJson(_kiwiJson, base: _kiwiJson);

  /// System: the platform's own look. Its style is Kiwi's wherever the platform has no pass yet.
  static final ThemeFile system = ThemeFile.fromJson(_systemJson, base: _kiwiJson);

  static List<ThemeFile> get builtIns => [system, kiwi];

  /// The themes the gallery offers, in its order (ARCHITECTURE.md 4.4): System, then the built-ins. Until
  /// phase 3 that is Kiwi alone, in today's six colours: the other five styles are drawn from phase 3, so
  /// offering them now would only be Kiwi in another colour under another name.
  static List<ThemeFile> get offered => builtIns;

  static ThemeFile? byId(String? id) => switch (id) {
        systemId => system,
        kiwiId => kiwi,
        _ => _testing[id],
      };

  static final _testing = <String?, ThemeFile>{};

  /// Makes [theme] known to [byId] until [clearForTesting], for tests of a theme the shipped library does
  /// not offer yet (one that needs fonts loaded on demand, until phase 3 offers the designed six).
  @visibleForTesting
  static void addForTesting(ThemeFile theme) => _testing[theme.id] = theme;

  @visibleForTesting
  static void clearForTesting() => _testing.clear();

  /// [choice] as it is drawn: a theme this build has (else System) and, for a theme with palettes, one it
  /// has (else its default); never a palette for System (ARCHITECTURE.md 4.1). Null is System.
  static ThemeChoice normalise(ThemeChoice? choice) {
    final theme = byId(choice?.theme);
    if (theme == null || theme.palettes.isEmpty) return ThemeChoice.system;
    return ThemeChoice(theme.id, theme.palette(choice!.palette)!.id);
  }

  /// Whether [choice] names a theme this build has, in a palette that theme has (or none): a choice that
  /// is not falls back ([normalise]), which myData's Appearance says once.
  static bool knows(ThemeChoice choice) {
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
  /// a choice: Kiwi in that palette, which is what phases 1 and 2 draw for it (ARCHITECTURE.md 4.2). Null
  /// for anything else.
  static ThemeChoice? fromColour(String? colour) =>
      kiwi.palettes.any((p) => p.id == colour) ? ThemeChoice(kiwiId, colour) : null;

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
  static List<MyDataThemeSpec> paletteSwatches(ThemeFile theme) => _swatches[theme] ??= [
        for (final p in theme.palettes)
          () {
            final l = look(theme, paletteId: p.id, brightness: Brightness.light).colors;
            final d = look(theme, paletteId: p.id, brightness: Brightness.dark).colors;
            return MyDataThemeSpec(
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

  static final _swatches = Expando<List<MyDataThemeSpec>>('swatches');

  /// [choice]'s look for [brightness] (after [normalise]).
  static MyDataLook lookFor(ThemeChoice? choice, Brightness brightness,
      {bool increasedContrast = false, TargetPlatform? platform}) {
    final c = normalise(choice);
    return look(byId(c.theme)!,
        paletteId: c.palette, brightness: brightness, increasedContrast: increasedContrast, platform: platform);
  }

  /// Today's colours, the resolver's starting point for roles a palette leaves out (Kiwi's own palette).
  static final RoleDefaults defaults = RoleDefaults(
    light: kiwi.defaultPalette!.given(LookMode.light),
    dark: kiwi.defaultPalette!.given(LookMode.dark),
  );

  /// What the validator needs: the schema, the built-ins' styles and today's colours.
  static ThemeFormat format({Map<String, Map<String, Object?>> extraStyles = const {}}) => ThemeFormat(
        schema: _schema,
        builtInStyles: {systemId: _systemJson, kiwiId: _kiwiJson, ...extraStyles},
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

  /// Kiwi in one of today's colours, by the id the host and the device settings use (`plum`); an unknown or
  /// missing id is Kiwi's own colour.
  static MyDataLook kiwiLook(String? colour, Brightness brightness, {bool increasedContrast = false}) =>
      look(kiwi, paletteId: colour, brightness: brightness, increasedContrast: increasedContrast);

  /// The theme files of design/themes as bundled (the phase 3 looks: System, Kiwi, Hairline, Frosted,
  /// Journal, Sticker and Paperback), by id, as text.
  static Future<Map<String, String>> loadDesignedThemes([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return {for (final e in designedThemeAssets.entries) e.key: await b.loadString(e.value, cache: false)};
  }
}
