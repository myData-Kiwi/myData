/// The one theme validator (design/themes/ARCHITECTURE.md 2), used by the loader and the tests now and by
/// import and the editor later. Pure Dart.
///
/// Steps, as 2.1 numbers them: 2 parse ([readStrictJson]), 3 the format version, 4 the schema
/// ([checkSchema] over theme.schema.json), 5 the text, 6 the references, then 8 every palette resolved and
/// checked in both modes, at normal and increased contrast. Step 1 (the `.mydatatheme` zip) and step 7 (images)
/// come with import (phase 5) and images (phase 6); until then a file naming an image is refused.
library;

import 'dart:developer' as developer;

import 'catalogue.dart';
import 'checks.dart';
import 'colour.dart';
import 'resolve.dart';
import 'roles.dart';
import 'schema.dart';
import 'strict_json.dart';
import 'theme_file.dart';

/// What the validator needs besides the file: the schema, the built-ins' styles (for `based-on` and as the
/// base of a file that leaves style groups out) and today's colours (the resolver's defaults).
class ThemeFormat {
  const ThemeFormat({
    required this.schema,
    required this.builtInStyles,
    required this.defaults,
    this.fallbackStyle = 'mydata.kiwi',
  });

  final Map<String, Object?> schema;

  /// Each built-in's id and its style groups (a theme file's JSON, read for its style groups only).
  final Map<String, Map<String, Object?>> builtInStyles;
  final RoleDefaults defaults;

  /// The built-in whose style fills a file that has no `based-on`.
  final String fallbackStyle;
}

/// The result of one palette's checks.
class PaletteCheck {
  const PaletteCheck(this.paletteId, this.failures, this.notices);
  final String paletteId;
  final List<String> failures, notices;
  bool get passes => failures.isEmpty;
}

/// The validator's answer for one file.
class ThemeCheck {
  const ThemeCheck({this.theme, required this.errors, required this.notices, this.palettes = const []});

  /// The theme, when the file could be read (null when [errors] stop it before that).
  final ThemeFile? theme;

  /// Reasons the theme cannot be used, as sentences.
  final List<String> errors;

  /// Things that do not block: keys left out, fonts not bundled yet, edges drawn for faint colours.
  final List<String> notices;

  /// Every palette's own checks. For an imported theme a failing palette other than the default is left out
  /// of the picker (its reasons become notices); a failing default fails the theme.
  final List<PaletteCheck> palettes;

  bool get ok => errors.isEmpty && theme != null;

  /// The palettes the picker may offer.
  List<String> get usablePalettes => [for (final p in palettes) if (p.passes) p.paletteId];
}

/// Strips Unicode control (Cc) and format (Cf) characters, bidi overrides and tag characters included (2.1,
/// step 5). Not yet done: NFC normalisation (the Dart SDK has none), so a decomposed name is kept as written.
String cleanThemeText(String s) => _strip(s);

/// Cc and every Cf range of Unicode 15.1: soft hyphen, Arabic and Syriac marks, zero-width and bidi controls,
/// word joiners, the byte-order mark, interlinear annotations, Kaithi, Egyptian, shorthand and musical format
/// controls, and the tag characters (invisible, and used to hide text in a name).
const _strippedRanges = [
  (0x0000, 0x001F), (0x007F, 0x009F), (0x00AD, 0x00AD), (0x0600, 0x0605), (0x061C, 0x061C), (0x06DD, 0x06DD),
  (0x070F, 0x070F), (0x0890, 0x0891), (0x08E2, 0x08E2), (0x180E, 0x180E), (0x200B, 0x200F), (0x202A, 0x202E),
  (0x2060, 0x2064), (0x2066, 0x206F), (0xFEFF, 0xFEFF), (0xFFF9, 0xFFFB), (0x110BD, 0x110BD), (0x110CD, 0x110CD),
  (0x13430, 0x1343F), (0x1BCA0, 0x1BCA3), (0x1D173, 0x1D17A), (0xE0001, 0xE0001), (0xE0020, 0xE007F),
];

String _strip(String s) => String.fromCharCodes(
    s.runes.where((c) => !_strippedRanges.any((r) => c >= r.$1 && c <= r.$2)));

/// Validates [text] as a theme file. [builtIn] for the files that ship with myData: their `mydata.` ids are
/// allowed, every palette must pass and must give every role the style does not fix (1.6).
ThemeCheck validateThemeText(String text, ThemeFormat format, {bool builtIn = false}) {
  final Object? json;
  try {
    json = readStrictJson(text);
  } on StrictJsonError catch (e) {
    return ThemeCheck(errors: [e.message], notices: const []);
  }
  if (json is! Map<String, Object?>) {
    return const ThemeCheck(errors: ['A theme file is one JSON object.'], notices: []);
  }
  return validateThemeJson(json, format, builtIn: builtIn);
}

/// As [validateThemeText], for JSON already read by [readStrictJson] (it is changed: unknown keys are dropped).
ThemeCheck validateThemeJson(Map<String, Object?> json, ThemeFormat format, {bool builtIn = false}) {
  final errors = <String>[], notices = <String>[];

  // 3. The format.
  final f = json['format'];
  if (f is num && f > 1) {
    return const ThemeCheck(errors: ['Made for a newer myData. Update myData to use it.'], notices: []);
  }

  // 5 (first half). Text fields are cleaned before the schema checks their lengths.
  for (final k in const ['name', 'author', 'description']) {
    if (json[k] case final String s) json[k] = cleanThemeText(s);
  }
  if (json['preview'] case final Map<String, Object?> p) {
    if (p['blurb'] case final String s) p['blurb'] = cleanThemeText(s);
  }
  // Before the schema, so `palettes` may be anything: matched, never cast.
  if (json['palettes'] case final List ps) {
    for (final p in ps.whereType<Map<String, Object?>>()) {
      if (p['name'] case final String s) p['name'] = cleanThemeText(s);
    }
  }

  // 4. The schema. Its root allows any key, so a newer minor version still loads; the ones it does not name are
  // left out here, with a notice.
  final known = (format.schema['properties'] as Map<String, Object?>).keys.toSet();
  for (final k in json.keys.where((k) => !known.contains(k)).toList()) {
    json.remove(k);
    notices.add('"$k" is not part of the theme format and was left out.');
  }
  for (final issue in checkSchema(json, format.schema)) {
    (issue.notice ? notices : errors).add('$issue.');
  }
  if (errors.isNotEmpty) return ThemeCheck(errors: errors, notices: notices);

  // 5 (second half). Ids and names.
  final id = json['id'] as String;
  if (!builtIn && id.startsWith('mydata.')) {
    errors.add('Only the themes that come with myData may have an id starting "mydata.".');
  }
  if (!builtIn) {
    final name = json['name'] as String;
    final clash = format.builtInStyles.values.any((b) => (b['name'] as String?)?.toLowerCase() == name.toLowerCase());
    if (clash) {
      json['name'] = '$name (imported)';
      notices.add('Its name is the same as a built-in theme\'s, so it is called "$name (imported)".');
    }
  }

  // 6. References.
  final basedOn = json['based-on'] as String?;
  if (basedOn != null && !format.builtInStyles.containsKey(basedOn)) {
    errors.add('It is based on "$basedOn", which is not a theme that comes with myData.');
  } else if (basedOn != null && format.builtInStyles[basedOn]!['frame'] == ThemeFrame.system.key) {
    // System has no style of its own to start from: the platform draws it.
    errors.add('A drawn theme can only be based on a drawn theme that comes with myData.');
  }
  if (!spdxLicences.contains(json['licence'])) {
    errors.add('Its licence, "${json['licence']}", is not one myData knows.');
  }
  _colourUseRules(json, errors);
  if (errors.isNotEmpty) return ThemeCheck(errors: errors, notices: notices);

  final base = format.builtInStyles[basedOn ?? format.fallbackStyle] ?? const <String, Object?>{};
  final ThemeFile theme;
  try {
    theme = ThemeFile.fromJson(json, base: base);
  } on Object catch (e, stack) {
    // A file the schema let through but the reader could not build: a gap in the checks above. The person
    // gets a sentence; the exception goes to the log.
    developer.log('theme file passed the checks but could not be read',
        name: 'mydata.theme', error: e, stackTrace: stack);
    return ThemeCheck(errors: ['The theme could not be read. It may have been made for another version of myData.'],
        notices: notices);
  }
  if (!builtIn) _typeScaleNotice(json, base, notices);

  for (final finding in checkStyle(theme)) {
    (finding.notice ? notices : errors).add(finding.message);
  }

  // 8. Palettes. A drawn theme's own; "System, tinted" ones as System draws them off macOS (1.6): Kiwi's
  // default palette with the tint's accent, the roles drawn from the accent derived again.
  final palettes = <PaletteCheck>[];
  final system = theme.frame == ThemeFrame.system;
  if (system && theme.palettes.isNotEmpty) {
    notices.add('"System, tinted" palettes are not applied on macOS, where the accent is the system\'s.');
  }
  if (theme.palettes.isNotEmpty) {
    final ids = [for (final p in theme.palettes) p.id];
    if (ids.toSet().length != ids.length) errors.add('Two palettes have the same id.');
    if (!ids.contains(theme.defaultPaletteId)) {
      errors.add('Its default palette, "${theme.defaultPaletteId}", is not one of its palettes.');
    }
  }
  for (final given in theme.palettes) {
    final p = system ? systemPalette(format.defaults, given) : given;
    final failures = <String>[], pNotices = <String>[];
    if (builtIn && !system) {
      // Every role the style reads: `stripe` only where its lists are tables.
      final tables = theme.style.components.values['list'] == 'table';
      for (final mode in LookMode.values) {
        final missing = [
          for (final r in ColourRole.values)
            if (!p.given(mode).containsKey(r) && !theme.sameAs.containsKey(r) && (tables || r != ColourRole.stripe))
              r.key,
        ];
        if (missing.isNotEmpty) {
          failures.add('${p.name}, ${mode.name} mode: a built-in palette gives every role; it leaves out '
              '${missing.join(', ')}.');
        }
      }
    }
    final gradientWindow = theme.style.materials.window == WindowKind.gradient;
    if (!gradientWindow && (p.gradientLight != null || p.gradientDark != null)) {
      pNotices.add('${p.name}: its gradient stops are not used, since this style\'s window is not a gradient.');
    }
    for (final mode in LookMode.values) {
      for (final increased in const [false, true]) {
        final resolved = resolvePalette(theme, p, mode, defaults: format.defaults, increasedContrast: increased);
        for (final finding in checkColours(theme, resolved, format.defaults, palette: p.name)) {
          (finding.notice ? pNotices : failures).add(finding.message);
        }
      }
    }
    palettes.add(PaletteCheck(p.id, failures, pNotices));
  }
  for (var i = 0; i < theme.palettes.length; i++) {
    for (var j = i + 1; j < theme.palettes.length; j++) {
      final a = theme.palettes[i], b = theme.palettes[j];
      for (final mode in LookMode.values) {
        final x = a.given(mode)[ColourRole.accent], y = b.given(mode)[ColourRole.accent];
        if (x != null && y != null && deltaE(x, y) < 0.08) {
          notices.add('${a.name} and ${b.name} have accents that are hard to tell apart in ${mode.name} mode.');
        }
      }
    }
  }
  for (final pc in palettes) {
    notices.addAll(pc.notices);
    if (pc.passes) continue;
    if (builtIn || pc.paletteId == theme.defaultPaletteId) {
      errors.addAll(pc.failures);
    } else {
      notices.add('The palette "${pc.paletteId}" is left out, because: ${pc.failures.join(' ')}');
    }
  }
  return ThemeCheck(theme: theme, errors: errors, notices: notices, palettes: palettes);
}

void _colourUseRules(Map<String, Object?> json, List<String> errors) {
  final same = ((json['colour-use'] as Map<String, Object?>?)?['same-as'] as Map<String, Object?>?) ?? const {};
  for (final e in same.entries) {
    if (same.containsKey(e.value)) {
      errors.add('colour-use: ${e.key} follows ${e.value}, which itself follows ${same[e.value]}; a role may only '
          'follow one that the palettes give.');
    }
  }
  for (final p in (json['palettes'] as List? ?? const []).whereType<Map<String, Object?>>()) {
    for (final where in const ['overrides', 'contrast']) {
      final group = p[where] as Map<String, Object?>?;
      for (final mode in const ['light', 'dark']) {
        final m = group?[mode] as Map<String, Object?>?;
        for (final k in same.keys) {
          if (m != null && m.containsKey(k)) {
            errors.add('The palette "${p['id']}" gives $k in its ${where == 'contrast' ? 'contrast set' : 'colours'} '
                '($mode), but this style always draws $k as ${same[k]}.');
          }
        }
      }
    }
  }
}

/// `type.base` and `type.ratio` size only the roles that neither the file nor the theme it is based on gives
/// (a file that gives them and no roles is sized from them alone: [mergeStyle]). Says so when they change
/// nothing a role would otherwise have.
void _typeScaleNotice(Map<String, Object?> json, Map<String, Object?> base, List<String> notices) {
  final type = json['type'];
  if (type is! Map<String, Object?> || (!type.containsKey('base') && !type.containsKey('ratio'))) return;
  final roles = type['roles'];
  if (roles is! Map<String, Object?> || roles.isEmpty) return;
  final baseRoles = ((base['type'] as Map<String, Object?>?)?['roles'] as Map<String, Object?>?) ?? const {};
  final kept = [
    for (final r in TypeRole.values)
      if ((roles[r.key] as Map<String, Object?>?)?['size'] == null &&
          (baseRoles[r.key] as Map<String, Object?>?)?['size'] != null)
        r.key,
  ];
  if (kept.isEmpty) return;
  notices.add('type: base and ratio do not size ${kept.join(', ')}, which keep the sizes of the theme it is '
      'based on; give their sizes, or leave out every role to size them all from base and ratio.');
}
