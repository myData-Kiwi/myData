// The accessibility themes keep their own, stricter promises (design/themes/<slug>/RULES.md, "Accessibility"),
// beyond the rules every theme keeps (ARCHITECTURE.md 2.2 and 2.3): High Contrast's text at 7:1 in every
// palette, its 2 px edges and double ring; E-ink's text at 7:1, no colour and nothing that moves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/checks.dart';
import 'package:mydata_ui/src/theme/colour.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

import 'designed_themes.dart';

/// Every text pair of [p] at normal contrast: what 2.2 checks at 4.5:1 (7:1 for an accessibility-first theme).
Map<String, double> textPairs(ResolvedPalette p) {
  final out = <String, double>{};
  void pair(ColourRole fg, ColourRole bg) => out['${fg.key} on ${bg.key}'] = contrast(p[fg], p[bg]);
  for (final g in textGrounds) {
    pair(ColourRole.ink, g);
    pair(ColourRole.inkMuted, g);
  }
  for (final soft in ColourRole.status.values) {
    pair(ColourRole.ink, soft);
  }
  for (final g in const [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.accentSoft]) {
    pair(ColourRole.link, g);
  }
  pair(ColourRole.onAccent, ColourRole.accent);
  pair(ColourRole.onSelection, ColourRole.selection);
  pair(ColourRole.onDanger, ColourRole.danger);
  for (final e in ColourRole.status.entries) {
    for (final g in [ColourRole.bg, ColourRole.surface, e.value]) {
      pair(e.key, g);
    }
  }
  out['initials on avatar-fill'] = contrast(p.onAvatar, p[ColourRole.avatarFill]);
  return out;
}

void main() {
  group('High Contrast', () {
    final theme = designedTheme('mydata.high-contrast');
    final style = theme.style;

    test('is checked at 7:1 at normal contrast, and every text pair of every palette reaches it', () {
      expect(accessibilityFirst, contains(theme.id));
      for (final palette in theme.palettes) {
        for (final mode in LookMode.values) {
          final p = resolvePalette(theme, palette, mode, defaults: ThemeLibrary.defaults);
          for (final e in textPairs(p).entries) {
            expect(e.value, greaterThanOrEqualTo(7), reason: '${palette.id} ${mode.key}: ${e.key}');
          }
        }
      }
    });

    test('outlines every control and container 2 px in ink, and draws a double ring', () {
      expect(style.borders.width, BorderWidth.two);
      expect(style.borders.colour, BorderColour.edge);
      expect(style.borders.cards, isTrue);
      expect(style.borders.controls, isTrue);
      expect(style.borders.focus, FocusRingStyle.doubleRing);
      final look = designedLook(theme.id, Brightness.light);
      expect(look.edges.doubleFocus, isTrue);
      expect(look.colors.edge, look.colors.ink);
    });

    test('selects inverse, in every palette, and draws nothing translucent or raised', () {
      expect(style.components.values['selection'], 'inverse');
      for (final palette in theme.palettes) {
        for (final b in Brightness.values) {
          final c = designedLook(theme.id, b, palette: palette.id).colors;
          expect(c.selection, c.ink, reason: palette.id);
          expect(c.onSelection, c.bg, reason: palette.id);
        }
      }
      expect(style.materials.window, WindowKind.solid);
      expect(style.materials.bars, BarMaterial.solid);
      expect(style.elevation.style, ElevationStyle.none);
    });

    test('sets nothing under 14 px', () {
      for (final e in style.type.roles.entries) {
        expect(e.value.size, greaterThanOrEqualTo(14), reason: e.key.key);
      }
      expect(style.type.roles[TypeRole.body]!.size, greaterThanOrEqualTo(16));
    });
  });

  group('E-ink', () {
    final theme = designedTheme('mydata.e-ink');
    final style = theme.style;

    test('is checked at 7:1 at normal contrast, and every text pair of every palette reaches it', () {
      expect(accessibilityFirst, contains(theme.id));
      for (final palette in theme.palettes) {
        for (final mode in LookMode.values) {
          final p = resolvePalette(theme, palette, mode, defaults: ThemeLibrary.defaults);
          for (final e in textPairs(p).entries) {
            expect(e.value, greaterThanOrEqualTo(7), reason: '${palette.id} ${mode.key}: ${e.key}');
          }
        }
      }
    });

    test('has no colour: every role it draws is a grey, at both contrast levels, and calendars are patterns', () {
      expect(style.components.values['data-colours'], 'pattern');
      expect(style.components.values['selection'], 'inverse');
      for (final palette in theme.palettes) {
        for (final mode in LookMode.values) {
          for (final increased in [false, true]) {
            final p = resolvePalette(theme, palette, mode, defaults: ThemeLibrary.defaults, increasedContrast: increased);
            for (final role in ColourRole.values) {
              // Calendar colours are never drawn here (patterns); the user's own colours stay theirs.
              if (ColourRole.data.contains(role)) continue;
              expect(Oklch.of(p[role]).c, lessThan(0.04),
                  reason: '${palette.id} ${mode.key}${increased ? ' increased' : ''}: ${role.key} has colour');
            }
          }
        }
      }
    });

    test('moves nothing: no transition, fade, rise or spring, whatever the system says', () {
      expect(style.motion.personality, MotionPersonality.none);
      expect(style.motion.enter, EnterStyle.none);
      for (final b in Brightness.values) {
        final m = designedLook(theme.id, b).motion;
        expect([m.fast, m.base, m.slow], everyElement(Duration.zero));
      }
    });

    test('rules its pages instead of boxing them, and draws nothing translucent or raised', () {
      expect(style.borders.cards, isFalse);
      expect(style.components.values['list'], 'ruled');
      expect(style.materials.window, WindowKind.solid);
      expect(style.materials.bars, BarMaterial.solid);
      expect(style.elevation.style, ElevationStyle.none);
    });
  });
}
