// The built-in themes (design/themes/ARCHITECTURE.md 3.1, phase 1): the designed looks of design/themes pass
// every check, every palette at normal and increased contrast; Kiwi as the apps draw it today resolves to
// today's tokens exactly, in each of today's six colours; and today's colours are where the renames put them.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';
import 'package:mydata_ui/src/theme/checks.dart';
import 'package:mydata_ui/src/theme/colour.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';
import 'package:mydata_ui/src/theme/strict_json.dart';
import 'package:mydata_ui/src/theme/validate.dart';

/// The designed theme files as bundled, by id.
Map<String, String> designed() => {
      for (final f in Directory('assets/themes').listSync().whereType<File>())
        'mydata.${f.uri.pathSegments.last.replaceAll('.json', '')}': f.readAsStringSync(),
    };

ThemeFormat designedFormat() => ThemeLibrary.format(extraStyles: {
      for (final e in designed().entries)
        if (e.key != ThemeLibrary.kiwiId && e.key != ThemeLibrary.systemId)
          e.key: readStrictJson(e.value) as Map<String, Object?>,
    });

/// Today's colour themes (design/themes.json) and the theme each became the default palette of.
const homes = {
  'kiwi': 'mydata.kiwi',
  'graphite': 'mydata.hairline',
  'dusk': 'mydata.frosted',
  'plum': 'mydata.journal',
  'rose': 'mydata.sticker',
  'amber': 'mydata.paperback',
};

Color _c(Rgb c) => Color(c.argb);

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
  group('the designed themes (design/themes, the phase 3 looks)', () {
    test('System and the six drawn themes are bundled', () {
      expect(designed().keys.toSet(), {
        'mydata.system', 'mydata.kiwi', 'mydata.hairline', 'mydata.frosted', 'mydata.journal', 'mydata.sticker',
        'mydata.paperback',
      });
    });

    for (final e in designed().entries) {
      test('${e.key} passes every check as a built-in, every palette in both modes at both contrast levels', () {
        final r = validateThemeText(e.value, designedFormat(), builtIn: true);
        expect(r.errors, isEmpty, reason: r.errors.join('\n'));
        expect(r.ok, isTrue);
        if (r.theme!.frame == ThemeFrame.drawn) {
          expect(r.palettes, hasLength(inInclusiveRange(2, 4)));
          expect(r.usablePalettes, hasLength(r.palettes.length));
        } else {
          expect(r.theme!.palettes, isEmpty, reason: 'System has no palettes: its colour is the system accent');
        }
      });
    }

    test('all 18 palettes, resolved at increased contrast (their own set, else the derived 7:1 values), pass', () {
      var palettes = 0;
      final failures = <String>[];
      for (final text in designed().values) {
        final theme = validateThemeText(text, designedFormat(), builtIn: true).theme!;
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
      expect(palettes, 18);
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('the bundle loads them by id from the app\'s assets', () async {
      final loaded = await ThemeLibrary.loadDesignedThemes();
      expect(loaded, designed());
    });
  });

  group('Kiwi as drawn today (phases 1 and 2)', () {
    test('its palettes are today\'s six colours, in the picker\'s order, Kiwi first', () {
      expect(ThemeLibrary.kiwi.palettes.map((p) => p.id), MyDataThemes.all.map((t) => t.id));
      expect(ThemeLibrary.kiwi.palettes.map((p) => p.name), MyDataThemes.all.map((t) => t.name));
      expect(ThemeLibrary.kiwi.defaultPaletteId, MyDataThemes.fallback.id);
    });

    test('it passes every check except the gaps the contrast audit found in today\'s look, which phase 3 fixes', () {
      final r = validateThemeText(kiwiThemeJson, ThemeLibrary.format(), builtIn: true, todaysKiwi: true);
      // Known, decided 2026-10-23 (themes decision 6): glass at 72% is too thin for secondary text over
      // dark or coloured content (Kiwi moves to 80-84% in phase 3), and a red focus ring is lost on a rose or
      // amber selection (those colours move to Sticker and Paperback, where Paperback's Amber has a blue ring).
      final known = RegExp(r'secondary text \(ink-muted\) on glass over (ink|accent|selection)'
          r'|^(Rose|Amber), .*: the focus ring and the selection differ');
      final unexpected = r.errors.where((e) => !known.hasMatch(e)).toList();
      expect(unexpected, isEmpty, reason: unexpected.join('\n'));
      expect(r.errors, isNotEmpty, reason: 'the gaps are fixed: drop this exception');
    });

    for (final spec in MyDataThemes.all) {
      for (final b in Brightness.values) {
        test('Kiwi in ${spec.id}, ${b.name}: the resolved look is today\'s tokens', () {
          final look = ThemeLibrary.kiwiLook(spec.id, b);
          final today = (b == Brightness.dark ? MyDataColors.dark : MyDataColors.light).withTheme(spec, b);
          final c = look.colors;
          final pairs = <String, (Color, Color)>{
            'bg': (c.bg, today.bg), 'surface': (c.surface, today.surface),
            'surface-raised': (c.surfaceRaised, today.surfaceRaised),
            'surface-sunken': (c.surfaceSunken, today.surfaceSunken),
            'surface-hover': (c.surfaceHover, today.surfaceHover), 'line': (c.line, today.line),
            'line-strong': (c.lineStrong, today.lineStrong), 'ink': (c.ink, today.ink),
            'ink-muted': (c.inkMuted, today.inkMuted), 'accent': (c.accent, today.accent),
            'on-accent': (c.onAccent, today.onAccent), 'accent-soft': (c.accentSoft, today.accentSoft),
            'brand': (c.brand, today.brand), 'kiwi-wash': (c.kiwiWash, today.kiwiWash), 'skin': (c.skin, today.skin),
            'cream': (c.cream, today.cream), 'paper': (c.paper, today.paper), 'success': (c.success, today.success),
            'success-soft': (c.successSoft, today.successSoft), 'warning': (c.warning, today.warning),
            'warning-soft': (c.warningSoft, today.warningSoft), 'danger': (c.danger, today.danger),
            'danger-soft': (c.dangerSoft, today.dangerSoft), 'on-danger': (c.onDanger, today.onDanger),
            'info': (c.info, today.info), 'info-soft': (c.infoSoft, today.infoSoft), 'focus': (c.focus, today.focus),
            'glass-fill': (c.glassFill, today.glassFill), 'glass-stroke': (c.glassStroke, today.glassStroke),
            'scrim': (c.scrim, today.scrim), 'data-red': (c.dataRed, today.dataRed),
            'data-orange': (c.dataOrange, today.dataOrange), 'data-yellow': (c.dataYellow, today.dataYellow),
            'data-green': (c.dataGreen, today.dataGreen), 'data-blue': (c.dataBlue, today.dataBlue),
            'data-purple': (c.dataPurple, today.dataPurple), 'data-brown': (c.dataBrown, today.dataBrown),
            'data-grey': (c.dataGrey, today.dataGrey),
          };
          for (final e in pairs.entries) {
            expect(e.value.$1, e.value.$2, reason: e.key);
          }
          if (spec.id == MyDataThemes.fallback.id) {
            // Kiwi's own colour is the generated constants, the roles tokens.json has no token for included.
            expect(fields(c), fields(b == Brightness.dark ? MyDataColors.dark : MyDataColors.light));
          }
          expect(look.elevation.shadows.shadow1, (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadow1);
          expect(look.elevation.shadows.shadow2, (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadow2);
          expect(look.elevation.shadows.shadowGlass,
              (b == Brightness.dark ? MyDataShadows.dark : MyDataShadows.light).shadowGlass);
        });
      }
    }

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
        final resolved = ThemeLibrary.kiwiLook(null, b);
        final fallback = MyDataLook.fallback(b);
        expect(fields(resolved.colors), fields(fallback.colors));
        for (final role in MyDataTypeRole.values) {
          expect(resolved.typeScale(role), fallback.typeScale(role));
        }
        expect(resolved.elevation.shadows.shadow1, fallback.elevation.shadows.shadow1);
        expect(resolved.density.controlHeight, fallback.density.controlHeight);
        expect(resolved.variants.values, fallback.variants.values);
        expect(resolved.paletteId, fallback.paletteId);
      }
    });
  });

  group('today\'s colours in their new themes', () {
    for (final e in homes.entries) {
      test('${e.key} is the default palette of ${e.value}, with today\'s accent and on-accent', () {
        final theme = validateThemeText(designed()[e.value]!, designedFormat(), builtIn: true).theme!;
        expect(theme.defaultPaletteId, e.key);
        final spec = MyDataThemes.byId(e.key);
        for (final b in Brightness.values) {
          final dark = b == Brightness.dark;
          final p = resolvePalette(theme, theme.defaultPalette!, dark ? LookMode.dark : LookMode.light,
              defaults: ThemeLibrary.defaults);
          expect(_c(p[ColourRole.accent]), dark ? spec.accentDark : spec.accentLight);
          expect(_c(p[ColourRole.onAccent]), dark ? spec.onAccentDark : spec.onAccentLight);
        }
      });
    }

    test('accent-soft is today\'s, except where the contrast audit moved it (Frosted, Sticker, Paperback light)', () {
      final moved = <String>[];
      for (final e in homes.entries) {
        final theme = validateThemeText(designed()[e.value]!, designedFormat(), builtIn: true).theme!;
        final spec = MyDataThemes.byId(e.key);
        for (final b in Brightness.values) {
          final dark = b == Brightness.dark;
          final p = theme.defaultPalette!.given(dark ? LookMode.dark : LookMode.light);
          if (_c(p[ColourRole.accentSoft]!) != (dark ? spec.accentSoftDark : spec.accentSoftLight)) {
            moved.add('${e.key} ${b.name}');
          }
        }
      }
      expect(moved.toSet(), {'dusk light', 'dusk dark', 'rose light', 'rose dark', 'amber light'});
    });

    test('Kiwi\'s designed palette keeps today\'s colours but for its glass, thickened by the audit', () {
      final theme = validateThemeText(designed()['mydata.kiwi']!, designedFormat(), builtIn: true).theme!;
      final today = ThemeLibrary.kiwi.defaultPalette!;
      for (final mode in LookMode.values) {
        final differ = [
          for (final r in today.given(mode).keys)
            if (theme.defaultPalette!.given(mode)[r] != today.given(mode)[r] && !theme.sameAs.containsKey(r)) r.key,
        ];
        // link and the other roles tokens.json never had are not compared: today they were never drawn.
        differ.removeWhere((k) => const {'link', 'edge', 'selection', 'on-selection', 'selection-inactive',
              'focus-on-danger'}.contains(k));
        expect(differ, ['glass-fill'], reason: mode.name);
      }
    });
  });
}
