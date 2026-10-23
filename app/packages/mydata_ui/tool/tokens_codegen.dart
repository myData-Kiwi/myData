/// Turns design/tokens.json and design/themes.json into Dart (lib/src/generated/tokens.g.dart).
///
/// Used by tool/generate_tokens.dart, which writes the file, and by test/generated_tokens_test.dart,
/// which fails when the committed file no longer matches the JSON.
library;

import 'dart:convert';

/// Where the design system lives, relative to this package.
const designDir = '../../../design';
const generatedPath = 'lib/src/generated/tokens.g.dart';

/// Logo files copied from design/assets/Logos into this package's assets, unchanged.
const logoFiles = ['mydata-kiwi-mark.svg', 'mydata-kiwi-mark-mono.svg', 'mydata-kiwi-app-icon.svg'];

String generateTokens(String tokensJson, String themesJson) {
  final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
  final themes = jsonDecode(themesJson) as Map<String, dynamic>;
  final out = StringBuffer()
    ..writeln('// GENERATED from design/tokens.json (version ${tokens['version']}) and design/themes.json')
    ..writeln('// by tool/generate_tokens.dart. Do not edit: change the JSON and run')
    ..writeln('//   (cd app/packages/mydata_ui && dart run tool/generate_tokens.dart)')
    ..writeln('// This is the only file in the apps that may contain literal colours, radii and font names.')
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln("import 'package:flutter/material.dart' show Brightness, ThemeExtension;")
    ..writeln();
  _colors(out, tokens['color'] as Map<String, dynamic>);
  _themes(out, themes);
  _shadows(out, tokens['shadow'] as Map<String, dynamic>);
  _scale(out, 'MyDataSpace', 'Spacing (tokens.json "spacing").', tokens['spacing'] as Map<String, dynamic>,
      (n) => 's${n.substring('space-'.length)}');
  _scale(out, 'MyDataRadius', 'Corner radii (tokens.json "radius").', tokens['radius'] as Map<String, dynamic>,
      (n) => _camel(n.substring('radius-'.length)));
  _scale(out, 'MyDataSize', 'Sizes (tokens.json "size").', tokens['size'] as Map<String, dynamic>, _camel);
  _scale(out, 'MyDataBlur', 'Blur radii in logical pixels (tokens.json "blur").',
      tokens['blur'] as Map<String, dynamic>, (n) => _camel(n.substring('blur-'.length)));
  _type(out, tokens['type'] as Map<String, dynamic>);
  if (tokens['macos'] case final Map<String, dynamic> macos) _macos(out, macos);
  return out.toString();
}

// ---------------------------------------------------------------- macos

/// The Mac frame (tokens.json "macos"): MyDataMacFont, MyDataMacColors, MyDataMacType, MyDataMacSize and
/// MyDataMacRadius. The system font is the platform's, so its styles have no package.
void _macos(StringBuffer out, Map<String, dynamic> macos) {
  final families = (macos['families'] as Map<String, dynamic>).cast<String, String>();
  out
    ..writeln()
    ..writeln('/// The Mac frame\'s fonts (tokens.json "macos.families"). [text] and [display] are the system\'s own')
    ..writeln('/// (Flutter\'s macOS engine resolves them through CoreText); [icons] is bundled in this package.')
    ..writeln('abstract final class MyDataMacFont {');
  for (final e in families.entries) {
    out.writeln("  static const ${e.key} = '${e.value}';");
  }
  out
    ..writeln('}')
    ..writeln();

  final colors = (macos['color'] as List).cast<Map<String, dynamic>>();
  final names = [for (final t in colors) _camel(t['name'] as String)];
  out
    ..writeln('/// The Mac frame\'s colours for one appearance (tokens.json "macos.color"). The constants are the')
    ..writeln('/// fallbacks; [withSystem] takes the values the system reports, by token name.')
    ..writeln('class MyDataMacColors extends ThemeExtension<MyDataMacColors> {')
    ..writeln('  const MyDataMacColors({');
  for (final n in names) {
    out.writeln('    required this.$n,');
  }
  out.writeln('  });');
  for (final t in colors) {
    out
      ..writeln()
      ..writeln('  /// ${_doc(t['usage'] as String)}')
      ..writeln('  final Color ${_camel(t['name'] as String)};');
  }
  for (final mode in ['light', 'dark']) {
    out
      ..writeln()
      ..writeln('  /// The system defaults, $mode appearance.')
      ..writeln('  static const $mode = MyDataMacColors(');
    for (final t in colors) {
      out.writeln('    ${_camel(t['name'] as String)}: ${_color((t['value'] as Map)[mode] as String)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  /// The token names, as the system channel reports them.')
    ..writeln('  static const tokenNames = [${colors.map((t) => "'${t['name']}'").join(', ')}];')
    ..writeln()
    ..writeln('  /// These colours with the ones in [system] (by token name) in their place.')
    ..writeln('  MyDataMacColors withSystem(Map<String, Color> system) => MyDataMacColors(');
  for (final t in colors) {
    final n = _camel(t['name'] as String);
    out.writeln("        $n: system['${t['name']}'] ?? $n,");
  }
  out
    ..writeln('      );')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataMacColors copyWith({${names.map((n) => 'Color? $n').join(', ')}}) =>')
    ..writeln('      MyDataMacColors(${names.map((n) => '$n: $n ?? this.$n').join(', ')});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataMacColors lerp(MyDataMacColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return MyDataMacColors(')
    ..writeln(names.map((n) => '      $n: Color.lerp($n, other.$n, t)!,').join('\n'))
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();

  out
    ..writeln('/// The Mac frame\'s type styles (tokens.json "macos.type"), without colour. Letter spacing follows')
    ..writeln('/// Apple\'s tracking for SF Pro at each size.')
    ..writeln('abstract final class MyDataMacType {');
  for (final s in (macos['type'] as List).cast<Map<String, dynamic>>()) {
    final family = s['family'] as String;
    if (!families.containsKey(family)) throw FormatException('unknown macos family $family');
    final size = _px(s['fontSize'] as String);
    final line = _px(s['lineHeight'] as String);
    final ls = s['letterSpacing'] as String?;
    final spacing = ls == null ? null : double.parse(ls.replaceAll('em', '')) * size;
    out
      ..writeln('  /// ${_doc(s['usage'] as String)}')
      ..writeln('  static const ${_camel(s['name'] as String)} = TextStyle(')
      ..writeln('    fontFamily: MyDataMacFont.$family,')
      ..writeln('    fontSize: ${_num(size)},')
      ..writeln('    height: ${(line / size).toStringAsFixed(4)},')
      ..writeln('    leadingDistribution: TextLeadingDistribution.even,')
      ..writeln('    fontWeight: FontWeight.w${s['fontWeight']},');
    if (spacing != null) out.writeln('    letterSpacing: ${_num(double.parse(spacing.toStringAsFixed(3)))},');
    out.writeln('  );');
  }
  out
    ..writeln('}')
    ..writeln();
  _scale(out, 'MyDataMacSize', 'The Mac frame\'s sizes (tokens.json "macos.size").',
      {'tokens': macos['size']}, _camel);
  _scale(out, 'MyDataMacRadius', 'The Mac frame\'s corner radii (tokens.json "macos.radius").',
      {'tokens': macos['radius']}, _camel);
}

// ---------------------------------------------------------------- colours

void _colors(StringBuffer out, Map<String, dynamic> color) {
  final list = (color['tokens'] as List).cast<Map<String, dynamic>>();
  final names = [for (final t in list) _camel(t['name'] as String)];
  out
    ..writeln('/// Every colour token for one theme and mode. `accent` in tokens.json is `MyDataColors.accent` here.')
    ..writeln('/// The base values are the Kiwi theme; [withTheme] swaps in another theme\'s three colours.')
    ..writeln('class MyDataColors extends ThemeExtension<MyDataColors> {')
    ..writeln('  const MyDataColors({');
  for (final n in names) {
    out.writeln('    required this.$n,');
  }
  out.writeln('  });');
  out.writeln();
  for (final t in list) {
    out
      ..writeln('  /// ${_doc(t['usage'] as String)}')
      ..writeln('  final Color ${_camel(t['name'] as String)};');
  }
  for (final mode in ['light', 'dark']) {
    out
      ..writeln()
      ..writeln('  /// The Kiwi theme, $mode mode.')
      ..writeln('  static const $mode = MyDataColors(');
    for (final t in list) {
      out.writeln('    ${_camel(t['name'] as String)}: ${_color((t['value'] as Map)[mode] as String)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  /// These colours with [theme]\'s accent, on-accent and accent-soft for [brightness].')
    ..writeln('  MyDataColors withTheme(MyDataThemeSpec theme, Brightness brightness) {')
    ..writeln('    final dark = brightness == Brightness.dark;')
    ..writeln('    return copyWith(')
    ..writeln('      accent: dark ? theme.accentDark : theme.accentLight,')
    ..writeln('      onAccent: dark ? theme.onAccentDark : theme.onAccentLight,')
    ..writeln('      accentSoft: dark ? theme.accentSoftDark : theme.accentSoftLight,')
    ..writeln('    );')
    ..writeln('  }')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataColors copyWith({');
  for (final n in names) {
    out.writeln('    Color? $n,');
  }
  out
    ..writeln('  }) =>')
    ..writeln('      MyDataColors(');
  for (final n in names) {
    out.writeln('        $n: $n ?? this.$n,');
  }
  out
    ..writeln('      );')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataColors lerp(MyDataColors? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return MyDataColors(');
  for (final n in names) {
    out.writeln('      $n: Color.lerp($n, other.$n, t)!,');
  }
  out
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();
}

// ---------------------------------------------------------------- themes

void _themes(StringBuffer out, Map<String, dynamic> themes) {
  final list = (themes['themes'] as List).cast<Map<String, dynamic>>();
  final defaults = list.where((t) => t['default'] == true).toList();
  if (defaults.length != 1) throw FormatException('themes.json must mark exactly one theme as default');
  const keys = {'accent': 'accent', 'on-accent': 'onAccent', 'accent-soft': 'accentSoft'};
  out
    ..writeln('/// A theme the user can pick: it replaces accent, on-accent and accent-soft only (themes.json).')
    ..writeln('class MyDataThemeSpec {')
    ..writeln('  const MyDataThemeSpec({')
    ..writeln('    required this.id,')
    ..writeln('    required this.name,');
  for (final k in keys.values) {
    out
      ..writeln('    required this.${k}Light,')
      ..writeln('    required this.${k}Dark,');
  }
  out
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String id;')
    ..writeln('  final String name;');
  for (final k in keys.values) {
    out
      ..writeln('  final Color ${k}Light;')
      ..writeln('  final Color ${k}Dark;');
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('/// The themes in the order the ThemePicker shows them.')
    ..writeln('abstract final class MyDataThemes {');
  for (final t in list) {
    final tk = t['tokens'] as Map<String, dynamic>;
    if (!const {'accent', 'on-accent', 'accent-soft'}.containsAll(tk.keys) || tk.length != 3) {
      throw FormatException('theme ${t['id']} must set exactly accent, on-accent and accent-soft');
    }
    out
      ..writeln('  static const ${_camel(t['id'] as String)} = MyDataThemeSpec(')
      ..writeln("    id: '${t['id']}',")
      ..writeln("    name: '${t['name']}',");
    for (final e in keys.entries) {
      final v = tk[e.key] as Map<String, dynamic>;
      out
        ..writeln('    ${e.value}Light: ${_color(v['light'] as String)},')
        ..writeln('    ${e.value}Dark: ${_color(v['dark'] as String)},');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  static const all = [${list.map((t) => _camel(t['id'] as String)).join(', ')}];')
    ..writeln('  static const fallback = ${_camel(defaults.single['id'] as String)};')
    ..writeln()
    ..writeln('  /// The theme with [id], or the default when the id is unknown or null.')
    ..writeln('  static MyDataThemeSpec byId(String? id) =>')
    ..writeln('      all.firstWhere((t) => t.id == id, orElse: () => fallback);')
    ..writeln('}')
    ..writeln();
}

// ---------------------------------------------------------------- shadows

void _shadows(StringBuffer out, Map<String, dynamic> shadow) {
  final list = (shadow['tokens'] as List).cast<Map<String, dynamic>>();
  final names = [for (final t in list) _camel(t['name'] as String)];
  out
    ..writeln('/// Shadows for one mode (tokens.json "shadow"). CSS blur radii are converted to Flutter\'s')
    ..writeln('/// blurRadius so the rendered softness matches.')
    ..writeln('class MyDataShadows extends ThemeExtension<MyDataShadows> {')
    ..writeln('  const MyDataShadows({${names.map((n) => 'required this.$n').join(', ')}});')
    ..writeln();
  for (var i = 0; i < list.length; i++) {
    out
      ..writeln('  /// ${_doc(list[i]['usage'] as String)}')
      ..writeln('  final List<BoxShadow> ${names[i]};');
  }
  for (final mode in ['light', 'dark']) {
    out
      ..writeln()
      ..writeln('  static const $mode = MyDataShadows(');
    for (var i = 0; i < list.length; i++) {
      out.writeln('    ${names[i]}: [${_shadow((list[i]['value'] as Map)[mode] as String)}],');
    }
    out.writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataShadows copyWith({${names.map((n) => 'List<BoxShadow>? $n').join(', ')}}) =>')
    ..writeln('      MyDataShadows(${names.map((n) => '$n: $n ?? this.$n').join(', ')});')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  MyDataShadows lerp(MyDataShadows? other, double t) {')
    ..writeln('    if (other == null) return this;')
    ..writeln('    return MyDataShadows(')
    ..writeln(names.map((n) => '      $n: BoxShadow.lerpList($n, other.$n, t)!,').join('\n'))
    ..writeln('    );')
    ..writeln('  }')
    ..writeln('}')
    ..writeln();
}

String _shadow(String css) {
  final m = RegExp(r'^\s*(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)px\s+(rgba?\([^)]*\)|#[0-9A-Fa-f]{6})\s*$')
      .firstMatch(css);
  if (m == null) throw FormatException('cannot read shadow "$css"');
  final cssBlur = double.parse(m[3]!);
  // CSS draws a blur radius r as a Gaussian with sigma r/2; Flutter's sigma is blurRadius * 0.57735 + 0.5.
  final blurRadius = cssBlur <= 1 ? 0.0 : (cssBlur / 2 - 0.5) / 0.57735;
  return 'BoxShadow(color: ${_color(m[4]!)}, offset: Offset(${_num(double.parse(m[1]!))}, '
      '${_num(double.parse(m[2]!))}), blurRadius: ${blurRadius.toStringAsFixed(2)})';
}

// ---------------------------------------------------------------- scales

void _scale(StringBuffer out, String cls, String doc, Map<String, dynamic> group, String Function(String) name) {
  final list = (group['tokens'] as List).cast<Map<String, dynamic>>();
  out
    ..writeln('/// $doc')
    ..writeln('abstract final class $cls {');
  for (final t in list) {
    out
      ..writeln('  /// ${_doc(t['usage'] as String)}')
      ..writeln('  static const double ${name(t['name'] as String)} = ${_num(_px(t['value'] as String))};');
  }
  out
    ..writeln('}')
    ..writeln();
}

// ---------------------------------------------------------------- type

void _type(StringBuffer out, Map<String, dynamic> type) {
  final families = (type['families'] as Map<String, dynamic>).map((k, v) => MapEntry(k, _firstFamily(v as String)));
  out
    ..writeln('/// Font families, bundled in this package (tokens.json "type.families", first choice of each stack).')
    ..writeln('abstract final class MyDataFontFamily {');
  for (final e in families.entries) {
    out.writeln("  static const ${e.key} = '${e.value}';");
  }
  for (final e in (type['families'] as Map<String, dynamic>).entries) {
    out
      ..writeln('  /// The ${e.key} font\'s name as people write it (for licences).')
      ..writeln("  static const ${e.key}Name = '${RegExp(r'"([^"]+)"').firstMatch(e.value as String)![1]}';");
  }
  out
    ..writeln("  static const package = 'mydata_ui';")
    ..writeln('}')
    ..writeln()
    ..writeln('/// The type styles (tokens.json "type.groups"), without colour: widgets take colour from')
    ..writeln('/// MyDataColors. Line heights are exact; letter spacing in em is converted to pixels.')
    ..writeln('abstract final class MyDataType {');
  for (final g in (type['groups'] as List).cast<Map<String, dynamic>>()) {
    final family = g['family'] as String;
    if (!families.containsKey(family)) throw FormatException('unknown family $family');
    for (final s in (g['styles'] as List).cast<Map<String, dynamic>>()) {
      final size = _px(s['fontSize'] as String);
      final line = _px(s['lineHeight'] as String);
      final ls = s['letterSpacing'] as String?;
      final spacing = ls == null ? null : double.parse(ls.replaceAll('em', '')) * size;
      out
        ..writeln('  /// ${_doc(s['usage'] as String)}')
        ..writeln('  static const ${_camel(s['name'] as String)} = TextStyle(')
        ..writeln("    fontFamily: MyDataFontFamily.$family,")
        ..writeln('    package: MyDataFontFamily.package,')
        ..writeln('    fontSize: ${_num(size)},')
        ..writeln('    height: ${(line / size).toStringAsFixed(4)},')
        ..writeln('    leadingDistribution: TextLeadingDistribution.even,')
        ..writeln('    fontWeight: FontWeight.w${s['fontWeight']},');
      if (spacing != null) out.writeln('    letterSpacing: ${_num(double.parse(spacing.toStringAsFixed(3)))},');
      out.writeln('  );');
    }
  }
  out.writeln('}');
}

String _firstFamily(String stack) {
  final m = RegExp(r'"([^"]+)"').firstMatch(stack);
  if (m == null) throw FormatException('no named font in "$stack"');
  return m[1]!.replaceAll(' ', '');
}

// ---------------------------------------------------------------- helpers

String _color(String css) {
  final hex = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(css.trim());
  if (hex != null) return 'Color(0xFF${hex[1]!.toUpperCase()})';
  final rgba = RegExp(r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$').firstMatch(css.trim());
  if (rgba == null) throw FormatException('cannot read colour "$css"');
  final a = ((double.tryParse(rgba[4] ?? '1') ?? 1) * 255).round();
  String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  return 'Color(0x${h(a)}${h(int.parse(rgba[1]!))}${h(int.parse(rgba[2]!))}${h(int.parse(rgba[3]!))})';
}

double _px(String v) {
  if (!v.endsWith('px')) throw FormatException('expected a px value, got "$v"');
  return double.parse(v.substring(0, v.length - 2));
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _camel(String s) {
  final parts = s.split(RegExp(r'[-_ ]'));
  final out = parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
  // Dart identifiers cannot start with a digit.
  return RegExp(r'^\d').hasMatch(out) ? 'v$out' : out;
}

String _doc(String s) => s.replaceAll('\n', ' ').trim();
