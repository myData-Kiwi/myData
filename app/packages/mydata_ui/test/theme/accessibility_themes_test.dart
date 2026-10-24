// The accessibility themes keep their own, stricter promises (design/themes/<slug>/RULES.md, "Accessibility"),
// beyond the rules every theme keeps (ARCHITECTURE.md 2.2 and 2.3): High Contrast's text at 7:1 in every
// palette, its 2 px edges and double ring; E-ink's text at 7:1, no colour and nothing that moves; Large's
// bigger text and targets, with the same layout.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';
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
      expect(style.access.textContrast, 7);
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
      expect(style.access.textContrast, 7);
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

    testWidgets("edges the Mac window's sidebar panel in a full point of ink, never a half-point grey",
        (tester) async {
      for (final b in Brightness.values) {
        final look = designedLook(theme.id, b, platform: TargetPlatform.macOS);
        await tester.pumpWidget(MaterialApp(
          theme: MacTheme.drawn(look),
          home: const Material(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MacSidebar(connection: AppConnection.connected(), child: SizedBox()),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        final panel = tester.widgetList<DecoratedBox>(
            find.descendant(of: find.byType(MacSidebar), matching: find.byType(DecoratedBox)));
        final sides = [
          for (final d in panel)
            if (d.position == DecorationPosition.foreground && d.decoration is BoxDecoration)
              (d.decoration as BoxDecoration).border?.top,
        ].nonNulls.toList();
        expect(sides, isNotEmpty);
        expect(sides.first.color, look.colors.ink, reason: b.name);
        expect(sides.first.width, greaterThanOrEqualTo(1), reason: b.name);
      }
    });
  });

  group('Large', () {
    final theme = designedTheme('mydata.large');
    final style = theme.style;

    test('sets nothing under 16 px, body at 19', () {
      for (final e in style.type.roles.entries) {
        expect(e.value.size, greaterThanOrEqualTo(16), reason: e.key.key);
      }
      expect(style.type.roles[TypeRole.body]!.size, 19);
      expect(style.type.roles[TypeRole.bodyStrong]!.size, 19);
    });

    test('makes every target at least 52 px on the desktop and 56 on phones, with 24 px icons', () {
      final d = style.density;
      expect(d.desktop.control, greaterThanOrEqualTo(52));
      expect(d.desktop.row, greaterThanOrEqualTo(52));
      expect(d.phone.control, greaterThanOrEqualTo(56));
      expect(d.phone.row, greaterThanOrEqualTo(56));
      expect(d.desktop.icon, greaterThanOrEqualTo(24));
      final look = designedLook(theme.id, Brightness.light, platform: TargetPlatform.macOS);
      expect(look.density.controlHeight, greaterThanOrEqualTo(52));
      expect(look.density.rowHeight, greaterThanOrEqualTo(52));
    });

    test('outlines controls 2 px and never marks a selection by its tint alone', () {
      expect(style.borders.width, BorderWidth.two);
      expect(style.borders.controls, isTrue);
      expect(style.components.values['selection'], 'outline');
    });

    test('rings focus in amber, never in danger\'s red: 3:1 on every ground, kept apart from the accent outline',
        () {
      for (final palette in theme.palettes) {
        for (final mode in LookMode.values) {
          for (final increased in [false, true]) {
            final p = resolvePalette(theme, palette, mode, defaults: ThemeLibrary.defaults, increasedContrast: increased);
            final where = '${palette.id} ${mode.key}${increased ? ' increased' : ''}';
            final focus = Oklch.of(p[ColourRole.focus]), danger = Oklch.of(p[ColourRole.danger]);
            expect(hueDistance(focus.h, danger.h), greaterThanOrEqualTo(25), reason: where);
            expect(focus.c, greaterThan(0.08), reason: '$where: a colour, not a grey');
            for (final g in focusGrounds) {
              expect(contrast(p[ColourRole.focus], p[g]), greaterThanOrEqualTo(3), reason: '$where on ${g.key}');
            }
            expect(focusKeptApart(p[ColourRole.focus], p[ColourRole.selection]), isTrue, reason: where);
          }
        }
      }
    });

    test('keeps the Mac window\'s skeleton: only the sidebar widens, in proportion, so a section name fits', () {
      MacLookMetrics m(String id) => MacLookMetrics.forLook(designedLook(id, Brightness.light), system: false);
      for (final id in drawnBuiltIns.where((id) => id != theme.id)) {
        expect(MacSidebar.width(m(id)), MyDataMacSize.sidebarWidth, reason: id);
      }
      expect(MacSidebar.width(m(theme.id)), MyDataMacSize.sidebarWidth * 19 / 16);
    });

    test('is one of the accessibility themes, whose faint text in the Mac window reads at 4.5:1', () {
      expect(style.access.readableFaintText, isTrue);
      for (final b in Brightness.values) {
        final look = designedLook(theme.id, b);
        final mac = MacTheme.drawn(look).extension<MyDataMacColors>()!;
        Rgb rgb(Color c) => Rgb.argb(c.toARGB32());
        expect(contrast(rgb(mac.tertiaryLabel), rgb(look.colors.surface)), greaterThanOrEqualTo(4.5), reason: b.name);
      }
    });
  });

  // The promises are the theme file's, not its id's: a theme of another id that makes them is held to them.
  group('a custom theme making the same promises', () {
    Map<String, dynamic> kiwi() => jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
    String custom(Map<String, dynamic> access) => jsonEncode(kiwi()
      ..['id'] = '0b6f0c7e-3d2a-4f51-9a6e-2c1d5b7e8f90'
      ..['name'] = 'Kiwi, promised'
      ..['accessibility'] = access);

    test('is checked at 7:1 when it says text-contrast 7:1, and at 4.5:1 when it says nothing', () {
      final strict = validateThemeText(custom({'text-contrast': '7:1'}), ThemeLibrary.format());
      final plain = validateThemeText(custom({}), ThemeLibrary.format());
      bool asks7(ThemeCheck c) => [
            ...c.errors,
            for (final p in c.palettes) ...p.failures,
            ...c.notices,
          ].any((m) => m.contains('it needs 7:1') && !m.contains('increased contrast'));
      expect(asks7(strict), isTrue, reason: 'Kiwi\'s secondary text is under 7:1');
      expect(asks7(plain), isFalse);
    });

    test('draws faint Mac text at 4.5:1 when it says faint-text readable', () {
      final json = jsonDecode(custom({'faint-text': 'readable'})) as Map<String, dynamic>;
      final theme = ThemeFile.fromJson(json, base: kiwi());
      for (final b in Brightness.values) {
        final look = ThemeLibrary.look(theme, brightness: b);
        expect(look.access.readableFaintText, isTrue);
        final mac = MacTheme.drawn(look).extension<MyDataMacColors>()!;
        Rgb rgb(Color c) => Rgb.argb(c.toARGB32());
        expect(contrast(rgb(mac.tertiaryLabel), rgb(look.colors.surface)), greaterThanOrEqualTo(4.5), reason: b.name);
      }
      final kiwiLook = ThemeLibrary.look(ThemeFile.fromJson(kiwi(), base: kiwi()), brightness: Brightness.light);
      expect(kiwiLook.access.readableFaintText, isFalse);
    });
  });
}
