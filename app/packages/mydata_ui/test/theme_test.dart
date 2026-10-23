import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final (x, y) = (_lum(a), _lum(b));
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('a theme is built from a choice and a mode; unknown themes are System, unknown palettes the default', () {
    final t = MyDataTheme(choice: const ThemeChoice('mydata.kiwi', 'dusk'), mode: MyDataMode.dark);
    expect(t.choice, const ThemeChoice('mydata.kiwi', 'dusk'));
    expect(t.themeMode, ThemeMode.dark);
    expect(MyDataTheme(choice: const ThemeChoice('nonsense', 'plum')).choice, ThemeChoice.system);
    expect(MyDataTheme(choice: const ThemeChoice('mydata.kiwi', 'nonsense')).choice,
        const ThemeChoice('mydata.kiwi', 'kiwi'));
    expect(MyDataTheme().choice, ThemeChoice.system);
    expect(MyDataTheme.kiwi('plum'), MyDataTheme(choice: const ThemeChoice('mydata.kiwi', 'plum')));
    expect(MyDataMode.parse('light'), MyDataMode.light);
    expect(MyDataMode.parse(null), MyDataMode.system);
    expect(MyDataThemes.all.map((t) => t.id), ['kiwi', 'graphite', 'dusk', 'plum', 'rose', 'amber']);
  });

  test("Kiwi in one of today's colours draws exactly what that colour drew before", () {
    for (final spec in MyDataThemes.all) {
      for (final b in Brightness.values) {
        final before = MyDataTheme.data(spec.id, b);
        final now = MyDataTheme.dataFor(ThemeChoice(ThemeLibrary.kiwiId, spec.id), b);
        expect(roles(now.extension<MyDataColors>()!), roles(before.extension<MyDataColors>()!),
            reason: '${spec.id} ${b.name}');
                expect(now.colorScheme, before.colorScheme, reason: '${spec.id} ${b.name}');
      }
    }
  });

  test('off a Mac, System is Kiwi in its own colour until each platform has its pass', () {
    for (final b in Brightness.values) {
      expect(roles(MyDataTheme.dataFor(ThemeChoice.system, b).extension<MyDataColors>()!),
          roles(MyDataTheme.data('kiwi', b).extension<MyDataColors>()!));
    }
  });

  test('a theme replaces accent, on-accent and accent-soft and nothing else', () {
    for (final b in Brightness.values) {
      final base = b == Brightness.dark ? MyDataColors.dark : MyDataColors.light;
      final kiwi = MyDataTheme.data('kiwi', b).extension<MyDataColors>()!;
      final plum = MyDataTheme.data('plum', b).extension<MyDataColors>()!;
      // Kiwi is what tokens.json holds.
      expect(kiwi.accent, base.accent);
      expect(plum.accent, b == Brightness.dark ? MyDataThemes.plum.accentDark : MyDataThemes.plum.accentLight);
      expect(plum.onAccent, b == Brightness.dark ? MyDataThemes.plum.onAccentDark : MyDataThemes.plum.onAccentLight);
      expect(plum.accentSoft,
          b == Brightness.dark ? MyDataThemes.plum.accentSoftDark : MyDataThemes.plum.accentSoftLight);
      expect(plum.copyWith(accent: base.accent, onAccent: base.onAccent, accentSoft: base.accentSoft), isA<MyDataColors>());
      for (final pair in [
        (plum.bg, base.bg), (plum.surface, base.surface), (plum.ink, base.ink), (plum.brand, base.brand),
        (plum.success, base.success), (plum.focus, base.focus), (plum.glassFill, base.glassFill),
      ]) {
        expect(pair.$1, pair.$2);
      }
    }
  });

  test('the theming.md rules hold for every theme in both modes', () {
    final failures = <String>[];
    for (final spec in MyDataThemes.all) {
      for (final b in Brightness.values) {
        final c = MyDataTheme.data(spec.id, b).extension<MyDataColors>()!;
        void rule(String what, Color fg, Color bg) {
          final r = contrast(fg, bg);
          if (r < 4.5) failures.add('${spec.id} ${b.name}: $what ${r.toStringAsFixed(2)}');
        }

        rule('on-accent on accent', c.onAccent, c.accent);
        rule('accent on bg', c.accent, c.bg);
        rule('accent on surface', c.accent, c.surface);
        rule('accent on accent-soft', c.accent, c.accentSoft);
        rule('ink on accent-soft', c.ink, c.accentSoft);
      }
    }
    expect(failures, isEmpty);
  });

  test('text and status colours meet the README contrast rules in both modes', () {
    final failures = <String>[];
    for (final c in [MyDataColors.light, MyDataColors.dark]) {
      void rule(String what, Color fg, Color bg, double min) {
        if (contrast(fg, bg) < min) failures.add('$what ${contrast(fg, bg).toStringAsFixed(2)}');
      }

      for (final g in [c.bg, c.surface, c.surfaceSunken]) {
        rule('ink', c.ink, g, 4.5);
        rule('ink-muted', c.inkMuted, g, 4.5);
      }
      for (final g in [c.bg, c.surface]) {
        rule('line-strong', c.lineStrong, g, 3);
        rule('focus', c.focus, g, 3);
        for (final (s, soft) in [(c.success, c.successSoft), (c.warning, c.warningSoft), (c.danger, c.dangerSoft), (c.info, c.infoSoft)]) {
          rule('status on ground', s, g, 4.5);
          rule('status on its soft fill', s, soft, 4.5);
        }
      }
      rule('on-danger on danger', c.onDanger, c.danger, 4.5);
    }
    expect(failures, isEmpty);
  });

  test('surface-hover shows on every ground, and text on it stays readable (tokens.json)', () {
    final failures = <String>[];
    for (final c in [MyDataColors.light, MyDataColors.dark]) {
      void rule(String what, Color fg, Color bg, double min) {
        if (contrast(fg, bg) < min) failures.add('$what ${contrast(fg, bg).toStringAsFixed(2)}');
      }

      for (final g in [c.bg, c.surface, c.surfaceRaised]) {
        rule('surface-hover on its ground', c.surfaceHover, g, 1.3);
      }
      rule('ink on surface-hover', c.ink, c.surfaceHover, 4.5);
      rule('ink-muted on surface-hover', c.inkMuted, c.surfaceHover, 4.5);
    }
    expect(failures, isEmpty);
  });

  test('the ink focus ring for red things shows on every ground (README "Focus and danger")', () {
    for (final c in [MyDataColors.light, MyDataColors.dark]) {
      for (final g in [c.bg, c.surface, c.surfaceRaised, c.surfaceSunken, c.dangerSoft]) {
        expect(contrast(c.ink, g), greaterThanOrEqualTo(3));
      }
    }
  });

  test('the calendar palette is one value in both modes, and all but yellow reach 3:1 on the surfaces', () {
    List<Color> palette(MyDataColors c) =>
        [c.dataRed, c.dataOrange, c.dataYellow, c.dataGreen, c.dataBlue, c.dataPurple, c.dataBrown, c.dataGrey];
    final light = palette(MyDataColors.light);
    final dark = palette(MyDataColors.dark);
    expect(light, dark);
    expect(light.toSet(), hasLength(8));
    for (final c in [MyDataColors.light, MyDataColors.dark]) {
      for (final colour in palette(c)) {
        if (colour == c.dataYellow) continue;
        for (final g in [c.surface, c.surfaceRaised]) {
          expect(contrast(colour, g), greaterThanOrEqualTo(3), reason: '$colour on $g');
        }
      }
    }
    // Yellow is the one that relies on DataColour's edge on light grounds.
    expect(dataColourNeedsEdge(MyDataColors.light.dataYellow, MyDataColors.light.surface), isTrue);
  });

  test('type styles use the bundled families and tokens.json sizes', () {
    expect(MyDataType.displayXl.fontSize, 40);
    expect(MyDataType.displayXl.fontWeight, FontWeight.w700);
    expect(MyDataType.displayXl.fontFamily, 'packages/${MyDataFontFamily.package}/${MyDataFontFamily.display}');
    expect(MyDataType.displayXl.letterSpacing, closeTo(-0.8, 1e-9));
    expect(MyDataType.body.fontSize! * MyDataType.body.height!, closeTo(22, 1e-3));
    expect(MyDataType.mono.fontFamily, endsWith(MyDataFontFamily.mono));
  });
}

/// Every colour role of [c], to compare two sets (MyDataColors has no ==).
List<Color> roles(MyDataColors c) => [c.bg, c.surface, c.surfaceRaised, c.surfaceSunken, c.surfaceHover, c.line, c.lineStrong, c.ink, c.inkMuted, c.accent, c.onAccent, c.accentSoft, c.brand, c.kiwiWash, c.skin, c.cream, c.paper, c.success, c.successSoft, c.warning, c.warningSoft, c.danger, c.dangerSoft, c.onDanger, c.info, c.infoSoft, c.focus, c.glassFill, c.glassStroke, c.scrim, c.dataRed, c.dataOrange, c.dataYellow, c.dataGreen, c.dataBlue, c.dataPurple, c.dataBrown, c.dataGrey, c.sidebar, c.toolbar, c.edge, c.link, c.selection, c.onSelection, c.selectionInactive, c.focusOnDanger, c.avatarFill, c.shadow, c.onAvatar];
