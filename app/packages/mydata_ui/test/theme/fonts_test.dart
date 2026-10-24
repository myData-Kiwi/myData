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

import 'designed_themes.dart';

/// The font files an app built with this package carries: every font and icon font in assets/fonts (the
/// pubspec's fonts and the catalogue's on-demand fonts), and any font the app adds itself.
int fontBytes(Iterable<Directory> dirs) {
  var total = 0;
  for (final d in dirs.where((d) => d.existsSync())) {
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (RegExp(r'\.(ttf|otf|woff2?)$').hasMatch(f.path)) total += f.lengthSync();
    }
  }
  return total;
}

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

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final script = File('tool/subset_fonts.sh').readAsStringSync();
  final onDemand = fontCatalogue.values.where((f) => f.variable).toList();

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
      'size axis where the catalogue says so', () {
    for (final f in onDemand) {
      for (final asset in f.assets) {
        final axes = fvarAxes(File(asset).readAsBytesSync());
        expect(axes.keys.toSet(), {'wght', if (f.opticalSizes != null) 'opsz'}, reason: asset);
        if (f.opticalSizes case (final lo, final hi)) expect((axes['opsz']!.$1, axes['opsz']!.$3), (lo, hi), reason: asset);
        expect(axes['wght']!.$2, 400, reason: '$asset: a style without its wght variation is drawn regular');
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

  test('each app stays within the font budget', () {
    final shared = fontBytes([Directory('assets')]);
    final apps = Directory('../../apps').listSync().whereType<Directory>();
    expect(apps, isNotEmpty);
    for (final app in apps) {
      final total = shared + fontBytes([Directory('${app.path}/assets')]);
      expect(total, lessThanOrEqualTo(fontBudgetBytes), reason: '${app.path}: $total bytes of fonts');
    }
    // Recorded for the decision's estimate (ARCHITECTURE.md 3.5).
    // ignore: avoid_print
    print('fonts bundled in every app: ${(shared / 1024 / 1024).toStringAsFixed(2)} MB of '
        '${fontBudgetBytes ~/ 1024 ~/ 1024} MB');
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
