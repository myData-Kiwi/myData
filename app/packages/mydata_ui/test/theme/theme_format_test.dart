// The theme format in Dart (design/themes/ARCHITECTURE.md 1 and 2): the strict reader, the schema checker, the
// resolver and the validator, on synthetic files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/colour.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';
import 'package:mydata_ui/src/theme/schema.dart';
import 'package:mydata_ui/src/theme/strict_json.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';
import 'package:mydata_ui/src/theme/validate.dart';

final format = ThemeLibrary.format();

String fixture(String name) => File('test/theme/fixtures/$name').readAsStringSync();

/// A small drawn theme: six seeds per palette, everything else derived, Kiwi's style.
Map<String, Object?> drawn({
  String id = '0b6e2f3a-1c4d-4e5f-8a9b-0c1d2e3f4a5b',
  String name = 'Test theme',
  List<Map<String, Object?>>? palettes,
  Map<String, Object?> extra = const {},
}) =>
    {
      'format': 1,
      'id': id,
      'name': name,
      'version': '1.0.0',
      'licence': 'CC0-1.0',
      'frame': 'drawn',
      'based-on': 'mydata.kiwi',
      'default-palette': 'main',
      'palettes': palettes ?? [palette()],
      ...extra,
    };

Map<String, Object?> palette({
  String id = 'main',
  Map<String, String>? light,
  Map<String, String>? dark,
  Map<String, Object?>? overrides,
  Map<String, Object?>? contrast,
}) =>
    {
      'id': id,
      'name': 'Main',
      'light': light ??
          {'bg': '#F6F6F5', 'surface': '#FFFFFF', 'ink': '#1A1A19', 'ink-muted': '#5C5C58', 'accent': '#1F5FA8', 'on-accent': '#FFFFFF'},
      'dark': dark ??
          {'bg': '#111111', 'surface': '#1A1A1A', 'ink': '#EDEDEB', 'ink-muted': '#A8A8A4', 'accent': '#8AB8EA', 'on-accent': '#0B1A2E'},
      'overrides': ?overrides,
      'contrast': ?contrast,
    };

ThemeCheck check(Map<String, Object?> json, {bool builtIn = false}) =>
    validateThemeText(jsonEncode(json), format, builtIn: builtIn);

void main() {
  group('reading', () {
    test('a key given twice is refused, not silently overwritten', () {
      expect(() => readStrictJson('{"name": "A", "name": "B"}'),
          throwsA(isA<StrictJsonError>().having((e) => e.message, 'message', contains('"name" twice'))));
    });

    test('more than eight levels deep, or more than 128 KB, is refused', () {
      expect(() => readStrictJson('${'[' * 9}${']' * 9}'),
          throwsA(isA<StrictJsonError>().having((e) => e.message, 'message', contains('8 levels'))));
      expect(readStrictJson('${'[' * 8}${']' * 8}'), isA<List>());
      expect(() => readStrictJson('"${'a' * (129 * 1024)}"'),
          throwsA(isA<StrictJsonError>().having((e) => e.message, 'message', contains('128 KB'))));
    });

    test('NaN, Infinity, numbers that overflow a double and trailing text are refused', () {
      for (final text in ['{"a": NaN}', '{"a": Infinity}', '{"a": 1e400}', '{"a": 1} x', "{'a': 1}", '{"a": 01}']) {
        expect(() => readStrictJson(text), throwsA(isA<StrictJsonError>()), reason: text);
      }
      expect(readStrictJson('{"a": [1, 2.5, -3e2, true, null, "x\\u00e9"]}'), {
        'a': [1, 2.5, -300.0, true, null, 'xé'],
      });
    });

    test('a newer format is refused with the sentence the import shows', () {
      final r = check({...drawn(), 'format': 2});
      expect(r.errors, ['Made for a newer myData. Update myData to use it.']);
    });
  });

  group('the schema', () {
    test('the checker applies every keyword theme.schema.json uses', () {
      final schema = jsonDecode(File('../../../design/themes/theme.schema.json').readAsStringSync()) as Map<String, Object?>;
      expect(unsupportedKeywords(schema), isEmpty);
    });

    test('the bundled schema is design/themes/theme.schema.json', () {
      expect(format.schema, jsonDecode(File('../../../design/themes/theme.schema.json').readAsStringSync()));
    });

    test('an unknown key is left out with a notice, at any depth', () {
      final r = check(drawn(extra: {
        'futureKey': {'ignored': true},
        'motion': {'personality': 'calm', 'bounce': 3},
      }));
      expect(r.errors, isEmpty);
      expect(r.notices, containsAll([contains('futureKey'), contains('motion/bounce')]));
      expect(r.theme!.json.containsKey('futureKey'), isFalse);
    });

    test('bounds, enumerations and colours are checked, with where and why', () {
      final r = check(drawn(
        palettes: [
          palette(light: {
            'bg': 'url(http://x)', 'surface': '#FFF', 'ink': '#000000', 'ink-muted': '#333333', 'accent': '#0000FF',
            'on-accent': '#FFFFFF',
          }),
        ],
        extra: {
          'density': {
            'desktop': {'control': 12},
          },
          'elevation': {'style': 'neumorphic'},
        },
      ));
      expect(r.ok, isFalse);
      expect(r.errors, containsAll([
        contains('palettes/0/light/bg: "url(http://x)" is not an opaque colour written #RRGGBB'),
        contains('palettes/0/light/surface: "#FFF" is not an opaque colour written #RRGGBB'),
        contains('density/desktop/control: 12 is below the least allowed, 24'),
        contains('elevation/style: "neumorphic" is not one of'),
      ]));
    });
  });

  group('must-fail files (the prototype\'s bad-* examples)', () {
    test('bad-drawn: a mydata. id, a URL, a short colour, a tiny control, an unknown elevation, image paths and a '
        'text primary button', () {
      final r = validateThemeText(fixture('bad-drawn.json'), format);
      expect(r.ok, isFalse);
      expect(r.errors, containsAll([
        contains('palettes/0/light/bg'),
        contains('palettes/0/light/surface'),
        contains('density/desktop/control'),
        contains('elevation/style'),
        contains('materials/window/image/light'),
        contains('materials/window/image/dark'),
        contains('components/button/primary: "text" is not one of'),
      ]));
    });

    test('bad-system-tint: a style group on a system frame is refused; a tinted palette keeps its accent only', () {
      final r = validateThemeText(fixture('bad-system-tint.json'), format);
      expect(r.ok, isFalse);
      expect(r.errors, [contains('may not give "type", "shape"')]);
      expect(r.notices, contains(contains('palettes/0/light/ink')));
    });

    test('an imported file may not take a built-in id, nor be based on something else', () {
      final r = check({
        ...drawn(id: 'mydata.kiwi2', palettes: [palette(), palette(id: 'second')]),
        'based-on': 'mydata.nothing',
      });
      expect(r.errors, containsAll([contains('starting "mydata."'), contains('"mydata.nothing"')]));
    });

    test('a licence myData does not know is refused', () {
      expect(check({...drawn(), 'licence': 'Made-Up-1.0'}).errors, [contains('"Made-Up-1.0"')]);
    });

    test('a background image is refused until images come (phase 6)', () {
      final r = check(drawn(extra: {
        'materials': {
          'window': {
            'kind': 'image',
            'image': {'light': 'images/a.png', 'dark': 'images/b.png'},
          },
        },
      }));
      expect(r.errors, contains('Background images come with a later version of myData.'));
    });

    test('a display-only font in the body fonts, and upper case on a title, are refused', () {
      final r = check(drawn(extra: {
        'type': {
          'body': ['kalam', 'sans'],
          'roles': {
            'title': {'case': 'upper', 'tracking': 0.05},
          },
        },
      }));
      expect(r.errors, containsAll([contains('display-only font cannot be in the body'), contains('not title')]));
    });

    test('fonts and icons this build does not bundle yet are notices, not failures', () {
      final r = check(drawn(extra: {
        'type': {
          'display': ['kalam', 'serif'],
          'unknown': 1,
        },
        'icons': {'set': 'pixelarticons'},
      }));
      expect(r.errors, isEmpty);
      expect(r.notices, containsAll([contains('Kalam'), contains('pixelarticons'), contains('type/unknown')]));
    });
  });

  group('text', () {
    test('control and format characters, bidi overrides included, are stripped from names', () {
      final r = check(drawn(name: 'Ha${String.fromCharCode(0x202E)}rbour${String.fromCharCode(7)} Fog${String.fromCharCode(0x200B)}'));
      expect(r.theme!.name, 'Harbour Fog');
    });

    test('a name equal to a built-in\'s gets "(imported)"', () {
      final r = check(drawn(name: 'kiwi'));
      expect(r.theme!.name, 'kiwi (imported)');
      expect(r.notices, contains(contains('(imported)')));
    });
  });

  group('colour-use.same-as', () {
    test('a key in a palette\'s contrast set or overrides is refused, and so is a chain', () {
      final r = check(drawn(
        palettes: [
          palette(overrides: {
            'light': {'toolbar': '#FFFFFF'},
          }, contrast: {
            'dark': {'sidebar': '#000000'},
          }),
        ],
        extra: {
          'colour-use': {
            'same-as': {'sidebar': 'bg', 'toolbar': 'bg', 'edge': 'selection', 'selection': 'ink'},
          },
        },
      ));
      expect(r.errors, containsAll([
        contains('gives toolbar in its colours (light)'),
        contains('gives sidebar in its contrast set (dark)'),
        contains('edge follows selection, which itself follows ink'),
      ]));
    });

    test('a seed may not be a key (the schema)', () {
      final r = check(drawn(extra: {
        'colour-use': {
          'same-as': {'ink': 'bg'},
        },
      }));
      expect(r.errors, [contains('"ink" is not allowed here')]);
    });

    test('a role follows its source after derivation and at increased contrast', () {
      final r = check(drawn(extra: {
        'colour-use': {
          'same-as': {'toolbar': 'surface-sunken', 'edge': 'link'},
        },
      }));
      expect(r.errors, isEmpty);
      final theme = r.theme!;
      for (final mode in LookMode.values) {
        for (final increased in [false, true]) {
          final p = resolvePalette(theme, theme.palettes.single, mode,
              defaults: ThemeLibrary.defaults, increasedContrast: increased);
          // Both sources are derived (and move at increased contrast); the followers keep up.
          expect(p.derived, containsAll([ColourRole.surfaceSunken, ColourRole.link]));
          expect(p[ColourRole.toolbar], p[ColourRole.surfaceSunken], reason: '$mode $increased');
          expect(p[ColourRole.edge], p[ColourRole.link], reason: '$mode $increased');
        }
      }
    });
  });

  group('the resolver', () {
    test('six seeds give all 43 roles, derived in the order of 1.3 and tuned to their pairs', () {
      final r = check(drawn());
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      final theme = r.theme!;
      for (final mode in LookMode.values) {
        final p = resolvePalette(theme, theme.palettes.single, mode, defaults: ThemeLibrary.defaults);
        expect(p.roles.keys.toSet(), ColourRole.values.toSet());
        expect(p.derived, hasLength(ColourRole.values.length - 6));
        expect(contrast(p[ColourRole.link], p[ColourRole.surfaceSunken]), greaterThanOrEqualTo(4.5));
        expect(contrast(p[ColourRole.lineStrong], p[ColourRole.bg]), greaterThanOrEqualTo(3));
        expect(contrast(p.onAvatar, p[ColourRole.avatarFill]), greaterThanOrEqualTo(4.5));
        expect(p[ColourRole.edge], p[ColourRole.ink]);
        expect(p[ColourRole.selection], p[ColourRole.accent]);
      }
    });

    test('derived glass is the palette\'s surface, made opaque enough for text over anything beneath', () {
      final theme = check(drawn()).theme!;
      final p = resolvePalette(theme, theme.palettes.single, LookMode.dark, defaults: ThemeLibrary.defaults);
      final glass = p[ColourRole.glassFill];
      expect(glass.withAlpha(255), p[ColourRole.surface]);
      expect(glass.a, greaterThanOrEqualTo(ThemeLibrary.defaults.dark[ColourRole.glassFill]!.a));
      for (final under in [ColourRole.bg, ColourRole.ink, ColourRole.accent]) {
        expect(contrast(p[ColourRole.inkMuted], glass.over(p[under])), greaterThanOrEqualTo(4.5));
      }
    });

    test('increased contrast is derived at 7:1 when a palette has no contrast set', () {
      final theme = check(drawn()).theme!;
      for (final mode in LookMode.values) {
        final p = resolvePalette(theme, theme.palettes.single, mode,
            defaults: ThemeLibrary.defaults, increasedContrast: true);
        expect(p[ColourRole.inkMuted], p[ColourRole.ink]);
        expect(p[ColourRole.line], p[ColourRole.lineStrong]);
        for (final g in [ColourRole.bg, ColourRole.surface, ColourRole.surfaceSunken, ColourRole.accentSoft]) {
          expect(contrast(p[ColourRole.link], p[g]), greaterThanOrEqualTo(7), reason: '$mode link on ${g.key}');
        }
        expect(contrast(p[ColourRole.onAccent], p[ColourRole.accent]), greaterThanOrEqualTo(7));
        expect(contrast(p[ColourRole.danger], p[ColourRole.dangerSoft]), greaterThanOrEqualTo(7));
      }
    });

    test('a palette\'s own contrast set is used as given, and must itself pass at 7:1', () {
      final weak = check(drawn(palettes: [
        palette(contrast: {
          'light': {'ink-muted': '#8A8A86'},
        }),
      ]));
      expect(weak.ok, isFalse);
      expect(weak.errors, contains(contains('light mode, increased contrast: secondary text (ink-muted)')));
    });
  });

  group('palettes', () {
    test('an imported theme keeps its good palettes and leaves out a failing one, with the reasons', () {
      final r = check(drawn(palettes: [
        palette(),
        palette(id: 'faint', light: {
          'bg': '#FFFFFF', 'surface': '#FFFFFF', 'ink': '#9A9A9A', 'ink-muted': '#B0B0B0', 'accent': '#FFD500',
          'on-accent': '#FFFFFF',
        }),
      ]));
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      expect(r.usablePalettes, ['main']);
      expect(r.notices, contains(startsWith('The palette "faint" is left out, because:')));
    });

    test('a failing default palette fails the theme, and a built-in fails on any palette', () {
      final bad = palette(light: {
        'bg': '#FFFFFF', 'surface': '#FFFFFF', 'ink': '#9A9A9A', 'ink-muted': '#B0B0B0', 'accent': '#FFD500',
        'on-accent': '#FFFFFF',
      });
      expect(check(drawn(palettes: [bad])).ok, isFalse);
      final builtIn = check(drawn(id: 'mydata.test', palettes: [palette(), {...bad, 'id': 'other'}]), builtIn: true);
      expect(builtIn.ok, isFalse);
      expect(builtIn.errors, contains(contains('a built-in palette gives every role')));
    });

    test('palette ids are unique and the default names one of them', () {
      final r = check({
        ...drawn(palettes: [palette(), palette()]),
        'default-palette': 'nowhere',
      });
      expect(r.errors, containsAll(['Two palettes have the same id.', contains('"nowhere"')]));
    });

    test('the good imported example passes, its unknown key left out', () {
      final r = validateThemeText(fixture('good-imported.json'), format);
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      expect(r.usablePalettes, ['fog', 'lantern']);
      expect(r.notices, contains(contains('futureKey')));
      expect(r.theme!.style.motion.personality, MotionPersonality.calm);
      // Groups it leaves out come from Kiwi, its based-on.
      expect(r.theme!.style.shape.lg, ThemeLibrary.kiwi.style.shape.lg);
    });
  });

  group('files that once crashed or slipped through', () {
    test('"palettes" of any other type is refused with a reason, never a crash', () {
      for (final v in ['{}', '"x"', '0.4', 'true', 'null', '[1, "a", []]']) {
        final r = validateThemeText('{"format": 1, "palettes": $v}', format);
        expect(r.ok, isFalse, reason: v);
        expect(r.errors, isNotEmpty, reason: v);
      }
      final full = drawn()..['palettes'] = {'main': palette()};
      expect(check(full).errors, contains(contains('palettes')));
    });

    test('a drawn theme based on System is refused with a sentence', () {
      final r = check({...drawn(), 'based-on': 'mydata.system'});
      expect(r.ok, isFalse);
      expect(r.errors, ['A drawn theme can only be based on a drawn theme that comes with myData.']);
    });

    test('tag characters and the other format controls are stripped from names', () {
      final hidden = String.fromCharCodes([0xE0001, 0xE0041, 0xE0042, 0xE007F, 0x1D173, 0x110BD, 0x0890]);
      final r = check(drawn(name: 'Fog$hidden'));
      expect(r.theme!.name, 'Fog');
      expect(r.theme!.name.runes, hasLength(3));
    });

    test('a file that starts with a byte-order mark is read; one elsewhere is refused', () {
      final text = jsonEncode(drawn());
      expect(validateThemeText('﻿$text', format).ok, isTrue);
      expect(readStrictJson('﻿ {"a": 1}'), {'a': 1});
      expect(() => readStrictJson('{"a": 1}﻿'), throwsA(isA<StrictJsonError>()));
      expect(() => readStrictJson('﻿﻿{}'), throwsA(isA<StrictJsonError>()));
    });

    test('type.base and ratio with no roles size every role from them alone', () {
      final r = check(drawn(extra: {
        'type': {'base': 18, 'ratio': 1.3},
      }));
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      final type = r.theme!.style.type;
      expect(type.roles[TypeRole.body]!.size, 18);
      expect(type.roles[TypeRole.heading]!.size, (18 * 1.3).roundToDouble());
      expect(type.roles[TypeRole.label]!.size, (18 / 1.3).roundToDouble());
      // Kiwi's weights and line heights stay.
      final kiwi = ThemeLibrary.kiwi.style.type.roles;
      expect(type.roles[TypeRole.title]!.weight, kiwi[TypeRole.title]!.weight);
      expect(type.roles[TypeRole.body]!.lineHeight, kiwi[TypeRole.body]!.lineHeight);
      expect(r.notices.where((n) => n.contains('base and ratio')), isEmpty);
    });

    test('type.base with some roles keeps the based-on sizes of the others, and says so', () {
      final r = check(drawn(extra: {
        'type': {
          'base': 18,
          'roles': {
            'body': {'size': 18},
          },
        },
      }));
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      expect(r.theme!.style.type.roles[TypeRole.body]!.size, 18);
      expect(r.theme!.style.type.roles[TypeRole.label]!.size, ThemeLibrary.kiwi.style.type.roles[TypeRole.label]!.size);
      expect(r.notices, contains(allOf(contains('base and ratio do not size'), contains('label'))));
    });
  });

  group('"System, tinted" (1.6)', () {
    Map<String, Object?> tinted(String light, String dark) => {
          'format': 1,
          'id': '11111111-2222-3333-4444-555555555556',
          'name': 'System, tinted',
          'version': '1.0.0',
          'licence': 'CC0-1.0',
          'frame': 'system',
          'default-palette': 'tint',
          'palettes': [
            {'id': 'tint', 'name': 'Tint', 'light': {'accent': light}, 'dark': {'accent': dark}},
          ],
        };

    test('a tint is checked as System draws it: Kiwi\'s colours with its accent', () {
      final r = check(tinted('#1F5FA8', '#8AB8EA'));
      expect(r.ok, isTrue, reason: r.errors.join('\n'));
      expect(r.usablePalettes, ['tint']);
      expect(r.notices, contains(contains('not applied on macOS')));
    });

    test('an unreadable tint fails, with the reason', () {
      final r = check(tinted('#FFFF66', '#8AB8EA'));
      expect(r.ok, isFalse);
      expect(r.usablePalettes, isEmpty);
      expect(r.errors, contains(contains('light mode')));
    });

    test('the tinted palette keeps Kiwi\'s colours and derives the accent\'s roles again', () {
      final theme = check(tinted('#1F5FA8', '#8AB8EA')).theme!;
      final p = systemPalette(ThemeLibrary.defaults, theme.palettes.single);
      final kiwi = ThemeLibrary.defaults.light;
      expect(p.light[ColourRole.accent], Rgb.parse('#1F5FA8'));
      expect(p.light[ColourRole.bg], kiwi[ColourRole.bg]);
      expect(p.light[ColourRole.onAccent], kiwi[ColourRole.onAccent]);
      for (final r in [ColourRole.link, ColourRole.selection, ColourRole.accentSoft]) {
        expect(p.light.containsKey(r), isFalse, reason: r.key);
      }
      final resolved = resolvePalette(theme, p, LookMode.light, defaults: ThemeLibrary.defaults);
      expect(resolved[ColourRole.selection], Rgb.parse('#1F5FA8'));
      expect(systemPalette(ThemeLibrary.defaults).light, kiwi);
    });
  });
}
