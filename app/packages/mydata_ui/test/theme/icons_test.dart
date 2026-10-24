// Icons by meaning (design/themes/ARCHITECTURE.md 1.5 and 3.6): every bundled set maps every semantic id in
// every weight it has, each glyph is in its subset font, the tables agree with tool/icons.json and the
// catalogue, a theme's set and weight are drawn (the nearest weight it lacks, Lucide for a set not bundled),
// and System on a Mac draws Lucide. One golden per icon set and weight the six built-ins use, light and dark.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/catalogue.dart';
import 'package:mydata_ui/src/theme/icon_sets.g.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

import 'cmap.dart';
import 'designed_themes.dart';

IconsSpec _spec(String set, String weight, {bool fill = false}) =>
    IconsSpec(set: set, weight: weight, fillSelected: fill, tiles: 'tinted');

/// Every icon, one per cell, in the look's set and weight; the last row selected (filled where the theme
/// fills selected icons): what an icon golden shows.
class IconSpecimen extends StatelessWidget {
  const IconSpecimen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget cell(MyDataIcon i, {bool selected = false}) => SizedBox.square(
          dimension: context.density.icon + context.space(3),
          child: Center(
            child: Icon(context.icon(i, selected: selected),
                size: context.density.icon, color: selected ? c.accent : c.ink),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(children: [for (final i in MyDataIcon.values) cell(i)]),
        SizedBox(height: context.space(3)),
        Wrap(children: [
          for (final i in [MyDataIcon.people, MyDataIcon.calendar, MyDataIcon.chat, MyDataIcon.settings, MyDataIcon.trash])
            cell(i, selected: true),
        ]),
      ],
    );
  }
}

void main() {
  final json = jsonDecode(File('tool/icons.json').readAsStringSync()) as Map<String, Object?>;
  final rows = (json['icons'] as List).cast<Map<String, Object?>>();

  test('tool/icons.json names every semantic id once, in order, with a glyph in every bundled set', () {
    expect(rows.map((r) => r['id']), MyDataIcon.values.map((i) => i.name));
    for (final r in rows) {
      for (final set in bundledIconSets) {
        // Material Symbols' styles share one set of names.
        final key = set.startsWith('material-') ? 'material' : set;
        expect(r[key], isA<String>().having((s) => s.isNotEmpty, 'non-empty', isTrue), reason: '${r['id']} in $set');
      }
      expect(r['meaning'], isNotEmpty);
    }
  });

  test('every bundled set and weight maps every id, as the catalogue says', () {
    expect(iconTables.keys.toSet(), bundledIconSets);
    for (final e in iconTables.entries) {
      expect(e.value.keys.toSet(), bundledIconWeights[e.key], reason: e.key);
      for (final table in e.value.entries) {
        expect(table.value.keys.toSet(), MyDataIcon.values.toSet(), reason: '${e.key} ${table.key} misses an id');
      }
    }
  });

  test('every glyph is in its subset font, declared in the pubspec, with its licence', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final weights in iconTables.values) {
      for (final table in weights.values) {
        final family = table.values.first.fontFamily!;
        final file = 'assets/fonts/$family-subset.ttf';
        expect(pubspec, contains('family: $family\n      fonts:\n        - asset: $file'), reason: family);
        final mapped = codePoints(File(file).readAsBytesSync());
        for (final e in table.entries) {
          expect(e.value.fontFamily, family);
          expect(e.value.fontPackage, fontPackage);
          expect(mapped, contains(e.value.codePoint), reason: '$family has no glyph for ${e.key.name}');
        }
      }
    }
    for (final l in ['ISC-lucide.txt', 'MIT-tabler.txt', 'MIT-phosphor.txt', 'Apache-material-symbols.txt']) {
      expect(File('assets/fonts/$l').existsSync(), isTrue, reason: l);
      expect(pubspec, contains('- assets/fonts/$l'));
      expect(bundledFontLicenses.values, contains(l));
    }
  });

  test('a theme draws its set at its weight, the nearest weight a set lacks, and Lucide for a set not bundled', () {
    expect(MyDataIconTheme(_spec('tabler', 'light'))(MyDataIcon.add), tablerLightIcons[MyDataIcon.add]);
    expect(MyDataIconTheme(_spec('tabler', 'bold')).weight, 'regular');
    expect(MyDataIconTheme(_spec('tabler', 'fill')).weight, 'regular');
    expect(MyDataIconTheme(_spec('phosphor', 'thin')).weight, 'light');
    expect(MyDataIconTheme(_spec('lucide', 'light')).weight, 'regular');
    expect(MyDataIconTheme(_spec('material-outlined', 'thin')).weight, 'light');
    final iconoir = MyDataIconTheme(_spec('iconoir', 'regular'));
    expect(iconoir.set, 'lucide');
    expect(iconoir(MyDataIcon.add), lucideIcons[MyDataIcon.add]);
  });

  test('a theme that fills selected icons draws the fill for a selected one, where the set has a fill', () {
    final phosphor = MyDataIconTheme(_spec('phosphor', 'bold', fill: true));
    expect(phosphor(MyDataIcon.people), phosphorBoldIcons[MyDataIcon.people]);
    expect(phosphor(MyDataIcon.people, selected: true), phosphorFillIcons[MyDataIcon.people]);
    final same = MyDataIconTheme(_spec('phosphor', 'light'));
    expect(same(MyDataIcon.people, selected: true), phosphorLightIcons[MyDataIcon.people]);
    final lucide = MyDataIconTheme(_spec('lucide', 'regular', fill: true));
    expect(lucide(MyDataIcon.people, selected: true), lucideIcons[MyDataIcon.people]);
  });

  test('Kiwi and System draw Lucide; the six built-ins draw the sets their rules name', () {
    expect(iconOf(MyDataIcon.add), lucideIcons[MyDataIcon.add]);
    final system = MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light).extension<MyDataLook>()!;
    expect(system.icons.set, 'lucide');
    expect(system.icons(MyDataIcon.add).fontFamily, MyDataMacFont.icons);
    final sets = {
      for (final id in drawnBuiltIns)
        id: (designedLook(id, Brightness.light).icons.set, designedLook(id, Brightness.light).icons.weight),
    };
    expect(sets, {
      'mydata.kiwi': ('lucide', 'regular'),
      'mydata.hairline': ('tabler', 'light'),
      'mydata.frosted': ('phosphor', 'regular'),
      'mydata.journal': ('phosphor', 'light'),
      'mydata.sticker': ('phosphor', 'bold'),
      'mydata.paperback': ('lucide', 'regular'),
      'mydata.high-contrast': ('material-outlined', 'bold'),
      'mydata.e-ink': ('phosphor', 'regular'),
      'mydata.large': ('material-rounded', 'regular'),
      'mydata.terminal': ('lucide', 'regular'),
      'mydata.notebook': ('phosphor', 'regular'),
      'mydata.brutalist': ('phosphor', 'bold'),
      'mydata.retro-desktop': ('pixelarticons', 'regular'),
      'mydata.swiss': ('material-sharp', 'regular'),
      'mydata.blueprint': ('tabler', 'thin'),
      'mydata.arcade': ('phosphor', 'regular'),
      'mydata.geometric': ('phosphor', 'fill'),
      'mydata.zen': ('phosphor', 'light'),
    });
  });

  testWidgets('context.icon resolves through the look, and the app frame fills a selected section', (tester) async {
    final sticker = designedLook('mydata.sticker', Brightness.light);
    late IconData plain, selected;
    await tester.pumpWidget(MaterialApp(
      theme: MyDataTheme.fromLook(sticker),
      home: Builder(builder: (context) {
        plain = context.icon(MyDataIcon.people);
        selected = context.icon(MyDataIcon.people, selected: true);
        return const SizedBox();
      }),
    ));
    expect(plain, phosphorBoldIcons[MyDataIcon.people]);
    expect(selected, phosphorFillIcons[MyDataIcon.people]);
  });

  // One golden per set and weight the six built-ins draw: Kiwi (Lucide), Hairline (Tabler light), Frosted
  // (Phosphor regular, filled when selected), Journal (Phosphor light), Sticker (Phosphor bold, filled when
  // selected). Paperback draws Lucide as Kiwi does (its `light` is Lucide's one weight).
  for (final id in ['mydata.kiwi', 'mydata.hairline', 'mydata.frosted', 'mydata.journal', 'mydata.sticker']) {
    for (final b in Brightness.values) {
      final slug = id.substring('mydata.'.length);
      testWidgets('icon golden ($slug-${b.name})', (tester) async {
        tester.view.physicalSize = const Size(480, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MyDataTheme.fromLook(designedLook(id, b)),
          home: Builder(
            builder: (context) => Material(
              color: context.colors.bg,
              child: Padding(padding: EdgeInsets.all(context.space(4)), child: const IconSpecimen()),
            ),
          ),
        ));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/icons.$slug-${b.name}.png'));
      });
    }
  }

  // Material Symbols, Outlined, Rounded and Sharp, in every weight they are cut in (the fill as the selected row),
  // and Pixelarticons in its one weight, on Kiwi's look: the glyphs as the sets draw them, whichever theme
  // names them.
  for (final (set, weights) in [
    ('material-outlined', ['light', 'regular', 'bold']),
    ('material-rounded', ['light', 'regular', 'bold']),
    ('material-sharp', ['light', 'regular', 'bold']),
    ('pixelarticons', ['regular']),
  ]) {
    for (final weight in weights) {
      testWidgets('icon golden ($set-$weight)', (tester) async {
        tester.view.physicalSize = const Size(480, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final look = designedLook('mydata.kiwi', Brightness.light)
            .copyWith(icons: MyDataIconTheme(_spec(set, weight, fill: true)));
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MyDataTheme.fromLook(look),
          home: Builder(
            builder: (context) => Material(
              color: context.colors.bg,
              child: Padding(padding: EdgeInsets.all(context.space(4)), child: const IconSpecimen()),
            ),
          ),
        ));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/icons.$set-$weight.png'));
      });
    }
  }

  // Two meanings never share a glyph, so icons shown side by side always tell things apart (Pixelarticons
  // drew the search field's clear and a sheet's close as one glyph).
  test('no two ids share a glyph in any set and weight', () {
    for (final weights in iconTables.entries) {
      for (final table in weights.value.entries) {
        final seen = <int, MyDataIcon>{};
        for (final e in table.value.entries) {
          final other = seen[e.value.codePoint];
          expect(other, isNull, reason: '${weights.key} ${table.key}: ${e.key.name} draws ${other?.name}\'s glyph');
          seen[e.value.codePoint] = e.key;
        }
      }
    }
  });
}
