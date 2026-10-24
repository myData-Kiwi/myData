/// The built-in themes, generated (design/themes/ARCHITECTURE.md 3.1):
///
/// - **Kiwi as the apps draw it today** (phases 1 and 2): one style from design/tokens.json with today's six
///   colours from design/themes.json as its palettes (`kiwi`, `graphite`, `dusk`, `plum`, `rose`, `amber`).
///   Its style groups that tokens.json does not hold (borders, materials, icons, motion, components) come from
///   design/themes/kiwi/theme.json; its type, radii, density, blur and shadow colour from tokens.json; its
///   corners are `round`, as today's widgets draw them. Every palette gives every role (ARCHITECTURE.md 1.6),
///   the few tokens.json has no token for (`edge`, `link`, `selection`, ...) derived once here by the resolver.
/// - **`lib/src/theme/builtin_themes.g.dart`**: the schema, System and that Kiwi as JSON text, read without
///   waiting for an asset, and the soft elevation's levels (tokens.json "shadow").
/// - **`assets/themes/<slug>.json`**: every file in design/themes, byte for byte: the phase 3 looks, checked
///   by the tests but not drawn yet.
///
/// Used by tool/generate_tokens.dart and by test/generated_tokens_test.dart (staleness).
library;

import 'dart:convert';
import 'dart:io';

import 'package:mydata_ui/src/theme/colour.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

const themesDir = '../../../design/themes';
const builtinThemesPath = 'lib/src/theme/builtin_themes.g.dart';
const themeAssetsDir = 'assets/themes';

/// The folders of design/themes that hold a theme, in name order.
List<String> designThemeSlugs() {
  final dirs = Directory(themesDir).listSync().whereType<Directory>().where((d) => File('${d.path}/theme.json').existsSync());
  return dirs.map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last).toList()..sort();
}

/// tokens.json's colour names that are not palette roles: artwork colours a theme never touches.
const fixedColourTokens = {'brand', 'skin', 'cream', 'paper'};

/// tokens.json names that are palette roles under another name.
const renamedColourTokens = {'kiwi-wash': 'avatar-fill'};

/// "rgba(20, 20, 20, 0.35)" or "#RRGGBB" as `#RRGGBB(AA)`, alpha rounded to 8 bits as tokens.g.dart does.
String cssToHex(String css) {
  final hex = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(css.trim());
  if (hex != null) return '#${hex[1]!.toUpperCase()}';
  final m = RegExp(r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$').firstMatch(css.trim());
  if (m == null) throw FormatException('cannot read colour "$css"');
  final a = ((double.tryParse(m[4] ?? '1') ?? 1) * 255).round();
  return Rgb(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), a).hex;
}

/// One tokens.json shadow: `0 4px 20px rgba(20, 20, 20, 0.07)`.
({double x, double y, double cssBlur, Rgb colour}) readShadow(String css) {
  final m = RegExp(r'^\s*(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)px\s+(rgba?\([^)]*\)|#[0-9A-Fa-f]{6})\s*$')
      .firstMatch(css);
  if (m == null) throw FormatException('cannot read shadow "$css"');
  return (x: double.parse(m[1]!), y: double.parse(m[2]!), cssBlur: double.parse(m[3]!), colour: Rgb.parse(cssToHex(m[4]!)));
}

double _px(String v) => double.parse(v.replaceAll('px', ''));

/// Kiwi as the apps draw it today, as a theme file (format 1).
Map<String, Object?> kiwiTodayTheme(String tokensJson, String themesJson, String designKiwiJson) {
  final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
  final themes = (jsonDecode(themesJson) as Map<String, dynamic>)['themes'] as List;
  final design = jsonDecode(designKiwiJson) as Map<String, Object?>;

  // The colours tokens.json gives, as palette roles, per mode.
  final base = {'light': <String, String>{}, 'dark': <String, String>{}};
  for (final t in ((tokens['color'] as Map)['tokens'] as List).cast<Map<String, dynamic>>()) {
    final name = t['name'] as String;
    if (fixedColourTokens.contains(name)) continue;
    final role = renamedColourTokens[name] ?? name;
    if (ColourRole.byKey(role) == null) throw FormatException('tokens.json colour $name is not a palette role');
    for (final mode in ['light', 'dark']) {
      base[mode]![role] = cssToHex((t['value'] as Map)[mode] as String);
    }
  }
  // The shadow colour is the colour of the resting shadow, at full strength.
  final shadow1 = ((tokens['shadow'] as Map)['tokens'] as List).cast<Map<String, dynamic>>().first;
  for (final mode in ['light', 'dark']) {
    base[mode]!['shadow'] = readShadow((shadow1['value'] as Map)[mode] as String).colour.withAlpha(255).hex;
  }

  final type = tokens['type'] as Map<String, dynamic>;
  final roles = <String, Object?>{};
  for (final g in (type['groups'] as List).cast<Map<String, dynamic>>()) {
    for (final s in (g['styles'] as List).cast<Map<String, dynamic>>()) {
      final size = _px(s['fontSize'] as String);
      final line = _px(s['lineHeight'] as String);
      final ls = s['letterSpacing'] as String?;
      roles[s['name'] as String] = {
        'size': size,
        // Rounded as tokens.g.dart rounds `height`, so the resolved style is the generated one exactly.
        'line-height': double.parse((line / size).toStringAsFixed(4)),
        'weight': s['fontWeight'],
        if (ls != null) 'tracking': double.parse(ls.replaceAll('em', '')),
        'stack': g['family'],
      };
    }
  }
  final radius = {
    for (final t in ((tokens['radius'] as Map)['tokens'] as List).cast<Map<String, dynamic>>())
      (t['name'] as String).substring('radius-'.length): _px(t['value'] as String),
  };
  final size = {
    for (final t in ((tokens['size'] as Map)['tokens'] as List).cast<Map<String, dynamic>>())
      t['name'] as String: _px(t['value'] as String),
  };
  final blur = _px((((tokens['blur'] as Map)['tokens'] as List).first as Map)['value'] as String);
  final density = {'control': size['control-height'], 'row': size['row-height'], 'icon': size['icon'], 'space': 1};

  final sameAs = (design['colour-use'] as Map<String, Object?>?)?['same-as'] as Map<String, Object?>? ?? const {};
  final theme = <String, Object?>{
    'format': 1,
    'id': 'mydata.kiwi',
    'name': 'Kiwi',
    'version': '0.1.0',
    'author': 'myData',
    'licence': 'CC0-1.0',
    'description': 'Kiwi as the apps draw it today, in today\'s six colours: generated from design/tokens.json and '
        'design/themes.json. Phase 3 replaces it with design/themes/kiwi.',
    'frame': 'drawn',
    'preview': design['preview'],
    'default-palette': (themes.firstWhere((t) => t['default'] == true) as Map)['id'],
    'colour-use': design['colour-use'],
    'type': {
      'display': ['plus-jakarta-sans', 'sans'],
      'body': ['figtree', 'sans'],
      'mono': ['jetbrains-mono', 'mono'],
      'base': (roles['body'] as Map)['size'],
      'ratio': 1.2,
      'numerals': 'proportional',
      'secondary-italic': false,
      'roles': roles,
    },
    'shape': {
      'corners': 'round',
      'radius': {for (final k in ['xs', 'sm', 'md', 'lg', 'xl']) k: radius[k]},
      'controls': radius['control']! >= 999 ? 'pill' : 'match',
    },
    'density': {'desktop': density, 'phone': density},
    'borders': design['borders'],
    'elevation': design['elevation'],
    'materials': {...(design['materials'] as Map<String, Object?>), 'blur': blur},
    'icons': design['icons'],
    'motion': design['motion'],
    'components': design['components'],
    'illustration': design['illustration'],
    'sound': 'none',
  };

  // Each of today's six colours over Kiwi's base, then every role the base does not give, derived once.
  final palettes = <Map<String, Object?>>[];
  for (final t in themes.cast<Map<String, dynamic>>()) {
    final colours = {
      for (final mode in ['light', 'dark'])
        mode: {
          ...base[mode]!,
          for (final e in (t['tokens'] as Map<String, dynamic>).entries) e.key: cssToHex((e.value as Map)[mode] as String),
        },
    };
    // The contrast audit's fixes to Kiwi's own colour (decided 2026-10-23, themes decision 6): its link as
    // design/themes/kiwi gives it (4.5:1 on every ground a link is drawn on). Its glass is tokens.json's.
    final designed = (design['palettes'] as List).cast<Map<String, dynamic>>().where((p) => p['id'] == t['id']);
    for (final p in designed) {
      for (final mode in ['light', 'dark']) {
        final link = ((p['overrides'] as Map?)?[mode] as Map?)?['link'] as String?;
        if (link != null) colours[mode]!['link'] = link;
      }
    }
    palettes.add({'id': t['id'], 'name': t['name'], 'light': colours['light'], 'dark': colours['dark']});
  }
  theme['palettes'] = palettes;

  final file = ThemeFile.fromJson(theme, base: theme);
  final defaults = RoleDefaults(
    light: {for (final e in base['light']!.entries) ColourRole.byKey(e.key)!: Rgb.parse(e.value)},
    dark: {for (final e in base['dark']!.entries) ColourRole.byKey(e.key)!: Rgb.parse(e.value)},
  );
  const seeds = ['bg', 'surface', 'ink', 'ink-muted', 'accent', 'on-accent'];
  for (var i = 0; i < palettes.length; i++) {
    final p = file.palettes[i];
    final out = <String, Object?>{'id': p.id, 'name': p.name};
    final overrides = <String, Object?>{};
    for (final mode in LookMode.values) {
      final resolved = resolvePalette(file, p, mode, defaults: defaults);
      out[mode.key] = {for (final s in seeds) s: resolved[ColourRole.byKey(s)!].hex};
      overrides[mode.key] = {
        for (final r in ColourRole.values)
          if (!r.isSeed && !sameAs.containsKey(r.key)) r.key: resolved[r].hex,
      };
    }
    out['overrides'] = overrides;
    palettes[i] = out;
  }
  return theme;
}

String kiwiTodayThemeText(String tokensJson, String themesJson, String designKiwiJson) =>
    '${const JsonEncoder.withIndent('  ').convert(kiwiTodayTheme(tokensJson, themesJson, designKiwiJson))}\n';

/// The extra colour roles of MyDataColors (the ones tokens.json has no token for), per mode, from Kiwi's
/// default palette.
Map<String, Map<String, String>> extraColourValues(Map<String, Object?> kiwiToday) {
  final file = ThemeFile.fromJson(kiwiToday, base: kiwiToday);
  final p = file.defaultPalette!;
  final out = <String, Map<String, String>>{};
  for (final mode in LookMode.values) {
    final defaults = RoleDefaults(light: p.light, dark: p.dark);
    final r = resolvePalette(file, p, mode, defaults: defaults);
    out[mode.key] = {
      for (final role in extraColourRoles.keys) role: r[ColourRole.byKey(role)!].hex,
      'on-avatar': r.onAvatar.hex,
    };
  }
  return out;
}

/// The palette roles MyDataColors carries besides tokens.json's colours, with their documentation.
const extraColourRoles = {
  'sidebar': 'Sidebar ground when solid (and the fallback for a translucent one).',
  'toolbar': 'Toolbar ground when solid.',
  'edge': 'The theme\'s outline colour when its borders use it.',
  'link': 'Accent used as text: links and text buttons, 4.5:1 on bg and surface.',
  'selection': 'The selected row\'s fill or marker.',
  'on-selection': 'Text on selection.',
  'selection-inactive': 'A selection in a list that does not have focus.',
  'focus-on-danger': 'The focus ring on anything already red.',
  'avatar-fill': 'An avatar\'s ground behind initials (was kiwi-wash).',
  'shadow': 'The colour shadows are drawn in, at the elevation\'s strength.',
};

/// Dart source holding the built-ins' JSON and the soft elevation's levels.
String generateBuiltinThemes({
  required String schemaText,
  required String systemText,
  required String kiwiText,
  required String tokensJson,
  required List<String> assetSlugs,
}) {
  for (final t in [schemaText, systemText, kiwiText]) {
    if (t.contains("'''")) throw const FormatException('a theme file holds three quotes');
  }
  final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
  final shadows = ((tokens['shadow'] as Map)['tokens'] as List).cast<Map<String, dynamic>>();
  final out = StringBuffer()
    ..writeln('// GENERATED from design/themes/theme.schema.json, design/themes/system/theme.json, design/tokens.json')
    ..writeln('// and design/themes.json by tool/generate_tokens.dart. Do not edit: change the JSON and run')
    ..writeln('//   (cd app/packages/mydata_ui && dart run tool/generate_tokens.dart)')
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln('/// theme.schema.json, the format every theme file is checked against.')
    ..writeln("const themeSchemaJson = r'''$schemaText''';")
    ..writeln()
    ..writeln('/// The System theme (design/themes/system/theme.json).')
    ..writeln("const systemThemeJson = r'''$systemText''';")
    ..writeln()
    ..writeln('/// Kiwi as the apps draw it today, in today\'s six colours (tool/themes_codegen.dart).')
    ..writeln("const kiwiThemeJson = r'''$kiwiText''';")
    ..writeln()
    ..writeln('/// The theme files of design/themes, bundled as assets (the phase 3 looks), by id.')
    ..writeln('const designedThemeAssets = {');
  for (final slug in assetSlugs) {
    out.writeln("  'mydata.$slug': 'packages/mydata_ui/$themeAssetsDir/$slug.json',");
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('/// The soft elevation at strength 0.5, from tokens.json "shadow": y offset, CSS blur and alpha in')
    ..writeln('/// light and dark, for the resting, raised and floating levels.')
    ..writeln('const softElevationLevels = [');
  for (final s in shadows) {
    final l = readShadow((s['value'] as Map)['light'] as String);
    final d = readShadow((s['value'] as Map)['dark'] as String);
    if (l.x != 0 || d.x != 0 || l.y != d.y || l.cssBlur != d.cssBlur) {
      throw FormatException('shadow ${s['name']}: light and dark differ in more than colour');
    }
    out.writeln('  (y: ${_num(l.y)}, cssBlur: ${_num(l.cssBlur)}, alphaLight: ${l.colour.a}, alphaDark: ${d.colour.a}), '
        '// ${s['name']}');
  }
  out.writeln('];');
  return out.toString();
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
