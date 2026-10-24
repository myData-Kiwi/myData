// The built-in themes (design/themes/ARCHITECTURE.md 3.1): System and the six drawn looks of design/themes,
// generated into builtin_themes.g.dart. Every one passes every check, every palette at normal and increased
// contrast; the library reads them as the validator does; Kiwi's default palette is the generated constants
// (the first frame); and today's old colours are where the renames put them, with the accent they had.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';
import 'package:mydata_ui/src/theme/checks.dart';
import 'package:mydata_ui/src/theme/colour.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';

/// Today's old colours (design/themes.json until phase 3, frozen here) and the theme each became the default
/// palette of, with the accent and on-accent it had: light, then dark.
const homes = {
  'kiwi': ('mydata.kiwi', [0xFF4C7814, 0xFFFFFFFF, 0xFFA9CC4E, 0xFF1A2408]),
  'graphite': ('mydata.hairline', [0xFF232323, 0xFFFFFFFF, 0xFFE6E6E4, 0xFF161616]),
  'dusk': ('mydata.frosted', [0xFF3D5AA9, 0xFFFFFFFF, 0xFF9DB4F2, 0xFF0E1A3A]),
  'plum': ('mydata.journal', [0xFF7A3E8E, 0xFFFFFFFF, 0xFFD2A6E0, 0xFF2A0F33]),
  'rose': ('mydata.sticker', [0xFFA63A5B, 0xFFFFFFFF, 0xFFEFA3B8, 0xFF33101C]),
  'amber': ('mydata.paperback', [0xFF8A5100, 0xFFFFFFFF, 0xFFF0B45A, 0xFF2E1B00]),
};

/// Every field of [c], by name (MyDataColors has no ==).
Map<String, Color> fields(MyDataColors c) => {
      'bg': c.bg, 'surface': c.surface, 'surfaceRaised': c.surfaceRaised, 'surfaceSunken': c.surfaceSunken,
      'surfaceHover': c.surfaceHover, 'line': c.line, 'lineStrong': c.lineStrong, 'ink': c.ink, 'inkMuted': c.inkMuted,
      'accent': c.accent, 'onAccent': c.onAccent, 'accentSoft': c.accentSoft, 'brand': c.brand, 'kiwiWash': c.kiwiWash,
      'skin': c.skin, 'cream': c.cream, 'paper': c.paper, 'success': c.success, 'successSoft': c.successSoft,
      'warning': c.warning, 'warningSoft': c.warningSoft, 'danger': c.danger, 'dangerSoft': c.dangerSoft,
      'onDanger': c.onDanger, 'info': c.info, 'infoSoft': c.infoSoft, 'focus': c.focus, 'glassFill': c.glassFill,
      'glassStroke': c.glassStroke, 'scrim': c.scrim, 'dataRed': c.dataRed, 'dataOrange': c.dataOrange,
      'dataYellow': c.dataYellow, 'dataGreen': c.dataGreen, 'dataBlue': c.dataBlue, 'dataPurple': c.dataPurple,
      'dataBrown': c.dataBrown, 'dataGrey': c.dataGrey, 'sidebar': c.sidebar, 'toolbar': c.toolbar, 'edge': c.edge,
      'link': c.link, 'selection': c.selection, 'onSelection': c.onSelection, 'selectionInactive': c.selectionInactive,
      'focusOnDanger': c.focusOnDanger, 'avatarFill': c.avatarFill, 'shadow': c.shadow, 'onAvatar': c.onAvatar,
    };

void main() {
  group('the built-ins', () {
    test('are System and the drawn looks, in the gallery\'s order', () {
      expect(ThemeLibrary.builtIns.map((t) => t.id), [
        'mydata.system', 'mydata.kiwi', 'mydata.hairline', 'mydata.frosted', 'mydata.journal', 'mydata.sticker',
        'mydata.paperback', 'mydata.high-contrast',
      ]);
      expect(ThemeLibrary.offered, ThemeLibrary.builtIns);
      expect(ThemeLibrary.builtIns.map((t) => t.name),
          ['System', 'Kiwi', 'Hairline', 'Frosted', 'Journal', 'Sticker', 'Paperback', 'High Contrast']);
    });

    test('have the palettes decided on 2026-10-23, default first', () {
      expect({for (final t in ThemeLibrary.builtIns) t.name: [for (final p in t.palettes) p.name]}, {
        'System': <String>[],
        'Kiwi': ['Kiwi', 'Sky', 'Violet'],
        'Hairline': ['Graphite', 'Slate', 'Cobalt'],
        'Frosted': ['Dusk', 'Aurora', 'Sand'],
        'Journal': ['Plum', 'Ink blue', 'Forest'],
        'Sticker': ['Rose', 'Mint', 'Mustard'],
        'Paperback': ['Amber', 'Sepia', 'Linen'],
        'High Contrast': ['Blue', 'Yellow', 'Cyan'],
      });
      for (final t in ThemeLibrary.builtIns.skip(1)) {
        expect(t.defaultPalette, t.palettes.first, reason: t.name);
      }
    });

    for (final e in builtInThemeJson.entries) {
      test('${e.key} passes every check as a built-in, every palette in both modes at both contrast levels', () {
        final r = validateThemeText(e.value, ThemeLibrary.format(), builtIn: true);
        expect(r.errors, isEmpty, reason: r.errors.join('\n'));
        expect(r.ok, isTrue);
        if (r.theme!.frame == ThemeFrame.drawn) {
          expect(r.palettes, hasLength(inInclusiveRange(2, 4)));
          expect(r.usablePalettes, hasLength(r.palettes.length));
        } else {
          expect(r.theme!.palettes, isEmpty, reason: 'System has no palettes: its colour is the system accent');
        }
      });

      test('${e.key} is read by the library as the validator reads it: every palette resolves the same', () {
        final validated = validateThemeText(e.value, ThemeLibrary.format(), builtIn: true).theme!;
        final library = ThemeLibrary.byId(e.key)!;
        expect(library.style.type.roles.keys, validated.style.type.roles.keys);
        for (final b in Brightness.values) {
          for (final p in [null, ...validated.palettes.map((p) => p.id)]) {
            final a = ThemeLibrary.look(library, paletteId: p, brightness: b);
            final v = MyDataLook.resolve(validated, paletteId: p, brightness: b, defaults: ThemeLibrary.defaults);
            expect(fields(a.colors), fields(v.colors), reason: '$p ${b.name}');
            for (final role in MyDataTypeRole.values) {
              expect(a.typeScale(role), v.typeScale(role), reason: '$p ${role.key}');
            }
            expect(a.variants.values, v.variants.values);
            expect(a.shape.corners, v.shape.corners);
          }
        }
      });
    }

    test('every built-in palette, resolved at increased contrast (their own set, else the derived 7:1 values), pass', () {
      var palettes = 0;
      final failures = <String>[];
      for (final theme in ThemeLibrary.builtIns) {
        for (final p in theme.palettes) {
          palettes++;
          for (final mode in LookMode.values) {
            final resolved =
                resolvePalette(theme, p, mode, defaults: ThemeLibrary.defaults, increasedContrast: true);
            final found = checkColours(theme, resolved, ThemeLibrary.defaults, palette: '${theme.name} ${p.name}');
            failures.addAll(found.where((f) => !f.notice).map((f) => f.message));
            // Text at 7:1: secondary text is ink, and ink reads at 7:1 on every ground.
            for (final g in textGrounds) {
              expect(contrast(resolved[ColourRole.ink], resolved[g]), greaterThanOrEqualTo(7),
                  reason: '${theme.name} ${p.name} $mode ink on ${g.key}');
            }
          }
        }
      }
      // The six of phase 3 have three each; High Contrast three.
      expect(palettes, 21);
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('the six drawn looks are told apart by more than colour: no two share their components and shape', () {
      final drawn = ThemeLibrary.builtIns.where((t) => t.frame == ThemeFrame.drawn).toList();
      final keys = {for (final t in drawn) t.name: '${t.style.shape.corners} ${t.style.components.values}'};
      expect(keys.values.toSet(), hasLength(drawn.length), reason: '$keys');
    });
  });

  group('Kiwi, the house style', () {
    test('its default palette is the generated constants, the roles tokens.json has no token for included', () {
      for (final b in Brightness.values) {
        final look = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b);
        expect(look.paletteId, 'kiwi');
        expect(fields(look.colors), fields(b == Brightness.dark ? MyDataColors.dark : MyDataColors.light));
        expect(look.elevation.shadows.shadow1, (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadow1);
        expect(look.elevation.shadows.shadow2, (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadow2);
        expect(look.elevation.shadows.shadowGlass,
            (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadowGlass);
      }
    });

    test('its corners are continuous, the system\'s corner, as its rules say', () {
      expect(ThemeLibrary.kiwi.style.shape.corners, CornerStyle.continuous);
    });

    test('its type, radii, sizes, spacing, motion and blur are today\'s tokens', () {
      for (final b in Brightness.values) {
        for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
          final look = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b, platform: platform);
          const k = MyDataTypeScale.kiwi;
          for (final role in MyDataTypeRole.values) {
            expect(look.typeScale(role), k(role), reason: role.key);
          }
          final s = look.shape;
          expect([s.xs, s.sm, s.md, s.lg, s.xl, s.control, s.pill],
              [MyDataRadius.xs, MyDataRadius.sm, MyDataRadius.md, MyDataRadius.lg, MyDataRadius.xl, MyDataRadius.control,
               MyDataRadius.pill]);
          final d = look.density;
          expect([d.controlHeight, d.controlHeightCompact, d.rowHeight, d.icon, d.iconTile],
              [MyDataSize.controlHeight, MyDataSize.controlHeightCompact, MyDataSize.rowHeight, MyDataSize.icon,
               MyDataSize.iconTile]);
          expect([for (final n in [1, 2, 3, 4, 5, 6, 8, 10, 12, 16]) look.space(n)],
              [MyDataSpace.s1, MyDataSpace.s2, MyDataSpace.s3, MyDataSpace.s4, MyDataSpace.s5, MyDataSpace.s6,
               MyDataSpace.s8, MyDataSpace.s10, MyDataSpace.s12, MyDataSpace.s16]);
          final m = look.motion;
          expect([m.fast, m.base, m.slow, m.springDuration, m.entranceStagger],
              [MyDataMotion.fast, MyDataMotion.base, MyDataMotion.slow, MyDataMotion.springDuration,
               MyDataMotion.entranceStagger]);
          expect(m.standard, MyDataMotion.standard);
          expect([m.pressScale, m.pressOpacity, m.entranceRise, m.sheetDrop],
              [MyDataMotion.pressScale, MyDataMotion.pressOpacity, MyDataMotion.entranceRise, MyDataMotion.sheetDrop]);
          expect(m.entranceMaxStaggered, MyDataMotion.entranceMaxStaggered);
          expect(look.materials.blur, MyDataBlur.glass);
        }
      }
    });

    test('the generated fallback look is Kiwi in its own colour, resolved', () {
      for (final b in Brightness.values) {
        final resolved = ThemeLibrary.look(ThemeLibrary.kiwi, brightness: b);
        final fallback = MyDataLook.fallback(b);
        expect(fields(resolved.colors), fields(fallback.colors));
        for (final role in MyDataTypeRole.values) {
          expect(resolved.typeScale(role), fallback.typeScale(role));
        }
        expect(resolved.elevation.shadows.shadow1, fallback.elevation.shadows.shadow1);
        expect(resolved.density.controlHeight, fallback.density.controlHeight);
        expect(resolved.variants.values, fallback.variants.values);
        expect(resolved.paletteId, fallback.paletteId);
        expect(resolved.shape.corners, fallback.shape.corners);
      }
    });
  });

  group('today\'s old colours in their new themes', () {
    for (final e in homes.entries) {
      test('${e.key} is the default palette of ${e.value.$1}, with the accent and on-accent it had', () {
        final theme = ThemeLibrary.byId(e.value.$1)!;
        expect(theme.defaultPaletteId, e.key);
        final v = e.value.$2;
        for (final b in Brightness.values) {
          final c = ThemeLibrary.look(theme, brightness: b).colors;
          final dark = b == Brightness.dark;
          expect(c.accent, Color(dark ? v[2] : v[0]), reason: b.name);
          expect(c.onAccent, Color(dark ? v[3] : v[1]), reason: b.name);
        }
      });
    }

    test('Kiwi in an old colour is a hidden alias: it is drawn as that colour\'s theme, never Kiwi\'s default', () {
      for (final e in homes.entries.skip(1)) {
        final kiwiIn = ThemeChoice(ThemeLibrary.kiwiId, e.key);
        expect(ThemeLibrary.moved(kiwiIn), ThemeChoice(e.value.$1, e.key));
        expect(ThemeLibrary.normalise(kiwiIn), ThemeChoice(e.value.$1, e.key));
        expect(ThemeLibrary.knows(kiwiIn), isTrue, reason: 'drawn as meant, so no "not on this device" notice');
        expect(ThemeLibrary.fromColour(e.key), ThemeChoice(e.value.$1, e.key));
        expect(ThemeLibrary.kiwi.palettes.map((p) => p.id), isNot(contains(e.key)), reason: 'hidden from the gallery');
      }
      expect(ThemeLibrary.moved(const ThemeChoice(ThemeLibrary.kiwiId, 'kiwi')), isNull);
      expect(ThemeLibrary.moved(const ThemeChoice('mydata.journal', 'plum')), isNull);
      expect(ThemeLibrary.fromColour('kiwi'), const ThemeChoice(ThemeLibrary.kiwiId, 'kiwi'));
      expect(ThemeLibrary.fromColour('sky'), const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
      expect(ThemeLibrary.fromColour('nonsense'), isNull);
      expect(ThemeLibrary.describe(const ThemeChoice(ThemeLibrary.kiwiId, 'plum')), 'Journal, Plum');
    });
  });
}
