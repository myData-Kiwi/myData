/// The themes this build knows (design/themes/ARCHITECTURE.md 3.1 and 3.3): the built-ins, read from the
/// generated JSON without waiting for an asset, and the designed looks of design/themes, bundled as assets.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'builtin_themes.g.dart';
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
  static const systemId = 'mydata.system';
  static const kiwiId = 'mydata.kiwi';

  static Map<String, Object?> _read(String text) => readStrictJson(text) as Map<String, Object?>;

  static final Map<String, Object?> _kiwiJson = _read(kiwiThemeJson);
  static final Map<String, Object?> _systemJson = _read(systemThemeJson);

  /// Kiwi as the apps draw it today, with today's six colours as its palettes.
  static final ThemeFile kiwi = ThemeFile.fromJson(_kiwiJson, base: _kiwiJson);

  /// System: the platform's own look. Its style is Kiwi's wherever the platform has no pass yet.
  static final ThemeFile system = ThemeFile.fromJson(_systemJson, base: _kiwiJson);

  static List<ThemeFile> get builtIns => [system, kiwi];

  static ThemeFile? byId(String? id) => switch (id) {
        systemId => system,
        kiwiId => kiwi,
        _ => null,
      };

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

  static final _looks = <(String, String?, Brightness, bool, TargetPlatform), MyDataLook>{};

  /// [theme] in [paletteId] for [brightness], resolved once and kept.
  static MyDataLook look(
    ThemeFile theme, {
    String? paletteId,
    required Brightness brightness,
    bool increasedContrast = false,
    TargetPlatform? platform,
  }) {
    final p = platform ?? defaultTargetPlatform;
    final key = (theme.id, theme.palette(paletteId)?.id, brightness, increasedContrast, p);
    if (identical(theme, kiwi) || identical(theme, system)) {
      return _looks[key] ??= MyDataLook.resolve(theme,
          paletteId: paletteId,
          brightness: brightness,
          defaults: defaults,
          increasedContrast: increasedContrast,
          platform: p);
    }
    return MyDataLook.resolve(theme,
        paletteId: paletteId, brightness: brightness, defaults: defaults, increasedContrast: increasedContrast, platform: p);
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
