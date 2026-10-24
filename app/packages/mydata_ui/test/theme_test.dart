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
    final t = MyDataTheme(choice: const ThemeChoice('mydata.journal', 'forest'), mode: MyDataMode.dark);
    expect(t.choice, const ThemeChoice('mydata.journal', 'forest'));
    expect(t.themeMode, ThemeMode.dark);
    expect(MyDataTheme(choice: const ThemeChoice('nonsense', 'plum')).choice, ThemeChoice.system);
    expect(MyDataTheme(choice: const ThemeChoice('mydata.kiwi', 'nonsense')).choice,
        const ThemeChoice('mydata.kiwi', 'kiwi'));
    expect(MyDataTheme(choice: const ThemeChoice('mydata.hairline')).choice,
        const ThemeChoice('mydata.hairline', 'graphite'));
    expect(MyDataTheme().choice, ThemeChoice.system);
    expect(MyDataMode.parse('light'), MyDataMode.light);
    expect(MyDataMode.parse(null), MyDataMode.system);
  });

  test("Kiwi in one of today's old colours draws the theme that colour moved to, in that palette", () {
    for (final e in ThemeLibrary.movedColours.entries) {
      expect(MyDataTheme(choice: ThemeChoice(ThemeLibrary.kiwiId, e.key)).choice, e.value);
      for (final b in Brightness.values) {
        final old = MyDataTheme.dataFor(ThemeChoice(ThemeLibrary.kiwiId, e.key), b);
        final now = MyDataTheme.dataFor(e.value, b);
        expect(roles(old.extension<MyDataColors>()!), roles(now.extension<MyDataColors>()!), reason: '${e.key} ${b.name}');
        expect(old.extension<MyDataLook>()!.themeId, e.value.theme);
      }
    }
  });

  test('off a Mac, System is Kiwi in its own colour until each platform has its pass', () {
    for (final b in Brightness.values) {
      expect(roles(MyDataTheme.dataFor(ThemeChoice.system, b).extension<MyDataColors>()!),
          roles(MyDataTheme.data('kiwi', b).extension<MyDataColors>()!));
    }
  });

  test('every palette of every built-in keeps its accent readable (theming.md), in both modes', () {
    final failures = <String>[];
    for (final theme in ThemeLibrary.builtIns) {
      for (final p in theme.palettes) {
        for (final b in Brightness.values) {
          final c = MyDataTheme.dataFor(ThemeChoice(theme.id, p.id), b).extension<MyDataColors>()!;
          void rule(String what, Color fg, Color bg, double min) {
            final r = contrast(fg, bg);
            if (r < min) failures.add('${theme.name} ${p.name} ${b.name}: $what ${r.toStringAsFixed(2)}');
          }

          rule('on-accent on accent', c.onAccent, c.accent, 4.5);
          rule('link on bg', c.link, c.bg, 4.5);
          rule('link on surface', c.link, c.surface, 4.5);
          rule('ink on accent-soft', c.ink, c.accentSoft, 4.5);
          rule('accent on surface', c.accent, c.surface, 3);
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
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
List<Color> roles(MyDataColors c) => [c.bg, c.surface, c.surfaceRaised, c.surfaceSunken, c.surfaceHover, c.stripe, c.line, c.lineStrong, c.ink, c.inkMuted, c.accent, c.onAccent, c.accentSoft, c.brand, c.kiwiWash, c.skin, c.cream, c.paper, c.success, c.successSoft, c.warning, c.warningSoft, c.danger, c.dangerSoft, c.onDanger, c.info, c.infoSoft, c.focus, c.glassFill, c.glassStroke, c.scrim, c.dataRed, c.dataOrange, c.dataYellow, c.dataGreen, c.dataBlue, c.dataPurple, c.dataBrown, c.dataGrey, c.sidebar, c.toolbar, c.edge, c.link, c.selection, c.onSelection, c.selectionInactive, c.focusOnDanger, c.avatarFill, c.shadow, c.onAvatar];
