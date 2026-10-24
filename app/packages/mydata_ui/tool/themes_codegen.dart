/// The built-in themes, generated (design/themes/ARCHITECTURE.md 3.1):
///
/// - **`lib/src/theme/builtin_themes.g.dart`**: the schema and every theme file of design/themes as JSON text,
///   byte for byte (System, then the drawn looks in the gallery's order, [builtInOrder]), read without
///   waiting for an asset, and the soft elevation's levels (tokens.json "shadow").
/// - The colour roles MyDataColors carries besides tokens.json's colours, from Kiwi's default palette
///   ([extraColourValues]).
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

/// The built-ins by folder, in the gallery's order (ARCHITECTURE.md 4.4): System, then Kiwi (the house style),
/// the five that were today's other colours, then the new built-ins of phase 4 as each is built.
const builtInOrder = [
  'system', 'kiwi', 'hairline', 'frosted', 'journal', 'sticker', 'paperback', 'high-contrast', 'e-ink', 'large',
  'terminal', 'notebook', 'brutalist', 'retro-desktop', 'swiss', 'blueprint',
];

/// The folders of design/themes that hold a theme, in the gallery's order. A folder [builtInOrder] does not
/// list is refused, so a new built-in is placed in the gallery on purpose.
List<String> designThemeSlugs() {
  final dirs = Directory(themesDir).listSync().whereType<Directory>().where((d) => File('${d.path}/theme.json').existsSync());
  final found = dirs.map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last).toSet();
  final unknown = found.difference(builtInOrder.toSet());
  if (unknown.isNotEmpty) throw FormatException('design/themes/${unknown.join(', ')}: add to builtInOrder');
  return [for (final s in builtInOrder) if (found.contains(s)) s];
}

/// The theme file of design/themes/[slug], as text.
String designThemeText(String slug) => File('$themesDir/$slug/theme.json').readAsStringSync();

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

/// Kiwi's default palette resolved in both modes, every role by key (`#RRGGBB(AA)`), and `on-avatar`.
Map<String, Map<String, String>> kiwiColourValues(String kiwiJson) {
  final json = jsonDecode(kiwiJson) as Map<String, Object?>;
  final file = ThemeFile.fromJson(json, base: json);
  final p = file.defaultPalette!;
  final defaults = RoleDefaults(light: p.light, dark: p.dark);
  return {
    for (final mode in LookMode.values)
      mode.key: () {
        final r = resolvePalette(file, p, mode, defaults: defaults);
        return {for (final role in ColourRole.values) role.key: r[role].hex, 'on-avatar': r.onAvatar.hex};
      }(),
  };
}

/// The extra colour roles of MyDataColors (the ones tokens.json has no token for), per mode, from Kiwi's
/// default palette (design/themes/kiwi/theme.json). Refuses a tokens.json colour that is not Kiwi's: Kiwi's
/// theme file is the source, and tokens.json's colours (MyDataColors.light and dark, the first frame's and the
/// fallback's) only repeat it, with each role's usage.
Map<String, Map<String, String>> extraColourValues(String tokensJson, String kiwiJson) {
  final kiwi = kiwiColourValues(kiwiJson);
  final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
  for (final t in ((tokens['color'] as Map)['tokens'] as List).cast<Map<String, dynamic>>()) {
    final name = t['name'] as String;
    if (fixedColourTokens.contains(name)) continue;
    final role = renamedColourTokens[name] ?? name;
    if (ColourRole.byKey(role) == null) throw FormatException('tokens.json colour $name is not a palette role');
    for (final mode in ['light', 'dark']) {
      final value = cssToHex((t['value'] as Map)[mode] as String);
      if (value != kiwi[mode]![role]) {
        throw FormatException('tokens.json colour $name ($mode) is $value, Kiwi\'s default palette gives '
            '${kiwi[mode]![role]}: design/themes/kiwi/theme.json is the source');
      }
    }
  }
  return {
    for (final mode in ['light', 'dark'])
      mode: {for (final role in [...extraColourRoles.keys, 'on-avatar']) role: kiwi[mode]![role]!},
  };
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

/// Dart source holding the schema, every built-in theme file (by id, in [builtInOrder]) and the soft
/// elevation's levels.
String generateBuiltinThemes({
  required String schemaText,
  required Map<String, String> themeTexts,
  required String tokensJson,
}) {
  for (final t in [schemaText, ...themeTexts.values]) {
    if (t.contains("'''")) throw const FormatException('a theme file holds three quotes');
  }
  final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
  final shadows = ((tokens['shadow'] as Map)['tokens'] as List).cast<Map<String, dynamic>>();
  final out = StringBuffer()
    ..writeln('// GENERATED from design/themes (theme.schema.json and every <slug>/theme.json) and design/tokens.json')
    ..writeln('// by tool/generate_tokens.dart. Do not edit: change the JSON and run')
    ..writeln('//   (cd app/packages/mydata_ui && dart run tool/generate_tokens.dart)')
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln('/// theme.schema.json, the format every theme file is checked against.')
    ..writeln("const themeSchemaJson = r'''$schemaText''';")
    ..writeln()
    ..writeln('/// The built-in themes, each `design/themes/<slug>/theme.json` byte for byte, by id, in the gallery\'s order:')
    ..writeln('/// System, then ${[for (final s in themeTexts.keys.skip(1)) _title(s)].join(', ')}.')
    ..writeln('const builtInThemeJson = {');
  for (final e in themeTexts.entries) {
    out.writeln("  'mydata.${e.key}': r'''${e.value}''',");
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

/// A theme's name from its folder, for the generated comment: each word capitalised (`high-contrast` is
/// High Contrast).
String _title(String slug) => [for (final w in slug.split('-')) '${w[0].toUpperCase()}${w.substring(1)}'].join(' ');

/// Every built-in's theme file as text, by folder, in the gallery's order.
Map<String, String> builtInThemeTexts() => {for (final s in designThemeSlugs()) s: designThemeText(s)};

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
