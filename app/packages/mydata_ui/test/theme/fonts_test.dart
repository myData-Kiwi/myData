// The theme fonts (design/themes/ARCHITECTURE.md 1.5, 3.5 and 3.6): what the catalogue bundles is what
// tool/subset_fonts.sh cuts and what the pubspec declares, every licence is there and reserves no name, the
// six built-ins find every font they name, the variable fonts draw the weight asked for, and no app goes over
// the font budget (decided 2026-10-23: 6 MB per app).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/catalogue.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

import 'cmap.dart';
import 'designed_themes.dart';

/// The font files a package's pubspec puts in an app: each `fonts:` asset, and each `assets:` entry that is
/// a font file or a folder (its font files), relative to [package]. Files in the folder but not declared are
/// not counted: they never reach the app.
List<File> declaredFonts(String package) {
  final pubspec = File('$package/pubspec.yaml').readAsLinesSync();
  final out = <File>[];
  final font = RegExp(r'\.(ttf|otf)$');
  for (final line in pubspec) {
    final asset = RegExp(r'^\s+- asset: (\S+)').firstMatch(line)?.group(1);
    final listed = RegExp(r'^\s+- (assets/\S+)$').firstMatch(line)?.group(1);
    if (asset != null) out.add(File('$package/$asset'));
    if (listed == null) continue;
    if (listed.endsWith('/')) {
      out.addAll(Directory('$package/$listed').listSync().whereType<File>().where((f) => font.hasMatch(f.path)));
    } else if (font.hasMatch(listed)) {
      out.add(File('$package/$listed'));
    }
  }
  return out;
}

/// The framework's fonts an app carries: Material Icons (every app: mydata_ui sets `uses-material-design`),
/// and Cupertino Icons when the app depends on `cupertino_icons`. Neither is tree-shaken in debug and
/// profile builds.
List<File> frameworkFonts(String app) {
  // flutter_tester is in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final cache = File(Platform.resolvedExecutable).parent.parent.parent;
  final out = [File('${cache.path}/material_fonts/MaterialIcons-Regular.otf')];
  if (File('$app/pubspec.yaml').readAsStringSync().contains(RegExp(r'^\s+cupertino_icons:', multiLine: true))) {
    final config = File('../../.dart_tool/package_config.json').readAsStringSync();
    final root = RegExp(r'"name": "cupertino_icons",\s*"rootUri": "([^"]+)"').firstMatch(config)!.group(1)!;
    out.add(File('${Uri.parse(root).toFilePath()}/assets/CupertinoIcons.ttf'));
  }
  return out;
}

int bytesOf(Iterable<File> files) => files.fold(0, (n, f) => n + f.lengthSync());

/// A font's variation axes from its `fvar` table: tag to (min, default, max).
Map<String, (double, double, double)> fvarAxes(Uint8List font) {
  final d = ByteData.sublistView(font);
  for (var i = 0; i < d.getUint16(4); i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes(font.sublist(rec, rec + 4)) != 'fvar') continue;
    final at = d.getUint32(rec + 8);
    double fixed(int o) => d.getInt32(o) / 65536;
    final first = at + d.getUint16(at + 4), size = d.getUint16(at + 10);
    return {
      for (var a = 0; a < d.getUint16(at + 8); a++)
        String.fromCharCodes(font.sublist(first + a * size, first + a * size + 4)):
            (fixed(first + a * size + 4), fixed(first + a * size + 8), fixed(first + a * size + 12)),
    };
  }
  return const {};
}

/// A font's weight class, from its `OS/2` table (`usWeightClass`).
int weightClass(Uint8List font) {
  final d = ByteData.sublistView(font);
  for (var i = 0; i < d.getUint16(4); i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes(font.sublist(rec, rec + 4)) == 'OS/2') return d.getUint16(d.getUint32(rec + 8) + 4);
  }
  throw StateError('no OS/2 table');
}

/// Names the fonts must draw (Latin Extended-A and -B, the apostrophes names use) and Vietnamese, which
/// names hold too (`Nguyễn`). A glyph the role's first font lacks must come from a later font of its stack.
const nameCorpus = 'ŞşȘșȚțŐőŰűĚěŠšČčŘřŽžŮůİıĞğŁłŃńŹźŻżĄąĘęßẞÆæØøÅåŒœĐđÉéÑñ’‘“”ʼ';
const vietnamese = 'ễệỗộữựằẳẵặấầẩẫậắơưƠƯ';

/// What a font lacks and leaves to the system's fonts, accepted with its reason (they draw these
/// letters in the platform's font, mid-word). Anything else missing fails the test.
const acceptedGaps = {
  // Kiwi's body, before phase 3: no modifier apostrophe and no Vietnamese.
  'figtree': 'ʼ$vietnamese',
  'plus-jakarta-sans': 'ʼ',
  // Journal's body.
  'instrument-sans': 'ʼ$vietnamese',
  // Frosted's titles and body.
  'sora': 'ʼ$vietnamese',
  // High Contrast's and Large's: no Vietnamese and no modifier apostrophe.
  'atkinson-hyperlegible-next': 'ʼ$vietnamese',
  'atkinson-hyperlegible-mono': 'ʼ$vietnamese',
  'manrope': 'ʼ',
  // Retro Desktop's titles: Pixelify Sans, and Atkinson Hyperlegible Next behind it, have neither.
  'pixelify-sans': 'ʼ$vietnamese',
};

/// A bundled font's files: a core font's static weights, a font loaded on demand and its italic.
List<String> fontFiles(CatalogueFont f) => f.core
    ? [
        for (final e in Directory('assets/fonts').listSync().whereType<File>())
          if (e.uri.pathSegments.last.startsWith('${f.family}-')) e.path,
      ]
    : f.assets;

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final script = File('tool/subset_fonts.sh').readAsStringSync();
  final onDemand = fontCatalogue.values.where((f) => f.onDemand).toList();

  test('every font loaded on demand is cut by the script, in the assets, and nothing else is', () {
    final cut = RegExp(r'^([a-z-]+)\|[^|]*\|[^|]*\|[0-9a-f]{64}\|[^|]*\|(italic)?$', multiLine: true)
        .allMatches(script)
        .map((m) => 'assets/fonts/catalogue/${m[1]}${m[2] == null ? '' : '-italic'}.ttf')
        .toSet();
    final wanted = {for (final f in onDemand) ...f.assets};
    expect(cut, wanted, reason: 'tool/subset_fonts.sh and fontCatalogue must name the same files');
    final present = Directory('assets/fonts/catalogue')
        .listSync()
        .whereType<File>()
        .map((f) => 'assets/fonts/catalogue/${f.uri.pathSegments.last}')
        .toSet();
    expect(present, wanted);
    expect(pubspec, contains('- assets/fonts/catalogue/'));
  });

  test('each font loaded on demand keeps its weight axis, with regular (400) as its default, and its optical '
      'size axis where the catalogue says so; a static one has no axis and its one weight', () {
    for (final f in onDemand) {
      for (final asset in f.assets) {
        final bytes = File(asset).readAsBytesSync();
        final axes = fvarAxes(bytes);
        if (f.staticWeight case final w?) {
          expect(axes, isEmpty, reason: asset);
          expect(weightClass(bytes), w, reason: asset);
          continue;
        }
        expect(axes.keys.toSet(), {'wght', if (f.opticalSizes != null) 'opsz'}, reason: asset);
        if (f.opticalSizes case (final lo, final hi)) expect((axes['opsz']!.$1, axes['opsz']!.$3), (lo, hi), reason: asset);
        expect(axes['wght']!.$2, 400, reason: '$asset: a style without its wght variation is drawn regular');
      }
    }
  });

  test("every role of the six built-ins draws people's names in its own fonts, or in a later font of its "
      'stack, but for the gaps accepted above', () {
    final maps = <String, Set<int>>{};
    Set<int> mapped(CatalogueFont f) => maps[f.id] ??= {
          for (final file in fontFiles(f)) ...codePoints(File(file).readAsBytesSync()),
        };
    for (final id in drawnBuiltIns) {
      final type = designedTheme(id).style.type;
      for (final role in TypeRole.values) {
        final r = type.roles[role]!;
        final fonts = <CatalogueFont>[];
        for (final fid in type.stack(r.stack)) {
          final f = fontCatalogue[fid];
          if (f == null || !f.bundled) break;
          if (f.displayOnly && r.size < 16) continue;
          fonts.add(f);
        }
        expect(fonts, isNotEmpty, reason: '$id ${role.key}');
        final missing = [
          for (final c in (nameCorpus + vietnamese).runes)
            if (!fonts.any((f) => mapped(f).contains(c))) String.fromCharCode(c),
        ].join();
        final accepted = acceptedGaps[fonts.first.id] ?? '';
        expect(missing.runes.where((c) => !accepted.runes.contains(c)).map(String.fromCharCode).join(), isEmpty,
            reason: '$id ${role.key} (${fonts.map((f) => f.id).join(', ')}) cannot draw these');
      }
    }
  });

  test('every accepted gap is still a gap: a font that gains the glyphs loses its entry', () {
    for (final e in acceptedGaps.entries) {
      final f = fontCatalogue[e.key]!;
      final map = {for (final file in fontFiles(f)) ...codePoints(File(file).readAsBytesSync())};
      for (final c in e.value.runes) {
        expect(map.contains(c), isFalse, reason: '${e.key} has ${String.fromCharCode(c)} now');
      }
    }
  });

  test('the core fonts are in the pubspec and only they are', () {
    for (final f in fontCatalogue.values.where((f) => f.core)) {
      expect(pubspec, contains('family: ${f.family}'), reason: f.name);
    }
    for (final f in onDemand) {
      expect(pubspec, isNot(contains('family: ${f.family}\n')), reason: '${f.name} is loaded on demand');
    }
  });

  test('every bundled font has its licence, declared as an asset: SIL OFL 1.1 with no Reserved Font Name', () {
    for (final f in fontCatalogue.values.where((f) => f.bundled)) {
      final file = File('assets/fonts/${f.licence}');
      expect(file.existsSync(), isTrue, reason: f.licence);
      expect(pubspec, contains('- assets/fonts/${f.licence}'), reason: f.licence);
      final text = file.readAsStringSync();
      expect(text, contains('SIL Open Font License, Version 1.1'), reason: f.licence);
      // The copyright lines come before the licence text, which defines the term: a reserved name is
      // declared there ("with Reserved Font Name ...").
      final head = text.substring(0, text.indexOf('This Font Software is licensed'));
      expect(head.toLowerCase(), isNot(contains('reserved font name')), reason: f.licence);
    }
    expect(bundledFontLicenses.keys, containsAll(fontCatalogue.values.where((f) => f.bundled).map((f) => f.name)));
  });

  test('every font the six built-ins name is bundled', () {
    for (final id in drawnBuiltIns) {
      final type = designedTheme(id).style.type;
      for (final s in [type.display, type.body, type.mono]) {
        final fonts = s.where(fontCatalogue.containsKey);
        expect(fonts.every((f) => fontCatalogue[f]!.bundled), isTrue, reason: '$id: $s');
      }
    }
  });

  test('each app stays within the font budget: every font it carries, the framework\'s included', () {
    final shared = bytesOf(declaredFonts('.'));
    final apps = Directory('../../apps').listSync().whereType<Directory>().toList();
    expect(apps, isNotEmpty);
    for (final app in apps) {
      for (final f in frameworkFonts(app.path)) {
        expect(f.existsSync(), isTrue, reason: f.path);
      }
      final total = shared + bytesOf(declaredFonts(app.path)) + bytesOf(frameworkFonts(app.path));
      expect(total, lessThanOrEqualTo(fontBudgetBytes), reason: '${app.path}: $total bytes of fonts');
      // Recorded for the decision's estimate (ARCHITECTURE.md 3.5; tool/measure_fonts.sh measures the bundle).
      // ignore: avoid_print
      print('${app.uri.pathSegments[app.uri.pathSegments.length - 2]}: ${(total / 1024 / 1024).toStringAsFixed(2)} MB '
          'of ${fontBudgetBytes ~/ 1024 ~/ 1024} MB of fonts');
    }
  });

  test('every font file in assets/fonts is declared: none is carried by mistake, none left behind', () {
    final declared = declaredFonts('.').map((f) => f.uri.normalizePath().toFilePath()).toSet();
    for (final f in Directory('assets/fonts').listSync(recursive: true).whereType<File>()) {
      if (!RegExp(r'\.(ttf|otf)$').hasMatch(f.path)) continue;
      expect(declared, contains(File(f.path).uri.normalizePath().toFilePath()), reason: '${f.path} is not declared');
    }
  });

  testWidgets('a variable font is drawn at the weight a theme names, its italic from its own file',
      (tester) async {
    await ThemeFonts.ensure(['inter', 'literata']);
    expect(ThemeFonts.isReady('inter'), isTrue);
    double width(TextStyle s) {
      final p = TextPainter(text: TextSpan(text: 'Hamburgefonstiv 0123456789', style: s),
          textDirection: TextDirection.ltr)
        ..layout();
      return p.width;
    }

    TextStyle inter(double w) => TextStyle(
        fontFamily: 'Inter', package: fontPackage, fontSize: 20, fontVariations: [FontVariation.weight(w)]);
    expect(width(inter(400)), lessThan(width(inter(550))));
    expect(width(inter(550)), lessThan(width(inter(700))));
    const literata = TextStyle(fontFamily: 'Literata', package: fontPackage, fontSize: 20);
    expect(width(literata.copyWith(fontStyle: FontStyle.italic)), isNot(width(literata)));
    // The optical size axis is live: display optics set the same text tighter than caption optics.
    TextStyle optical(double o) => literata.copyWith(fontVariations: [FontVariation('opsz', o)]);
    expect(width(optical(72)), lessThan(width(optical(7))));
  });

  test('ensure skips fonts it does not bundle and the core fonts, which are always ready', () async {
    await ThemeFonts.ensure(['figtree', 'inter-tight', 'nonsense']);
    expect(ThemeFonts.isReady('figtree'), isTrue);
    expect(ThemeFonts.isReady('inter-tight'), isFalse);
    expect(ThemeFonts.isReady('nonsense'), isFalse);
    for (final id in drawnBuiltIns) {
      expect(ThemeFonts.readyFor(designedTheme(id)), isTrue, reason: '$id (the test config loads every font)');
    }
  });
}
