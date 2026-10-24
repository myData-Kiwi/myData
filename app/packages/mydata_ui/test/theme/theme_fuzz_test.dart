// The validator and the resolver on mutated files (design/themes/ARCHITECTURE.md 2): whatever a file holds, the
// validator never throws, refuses with at least one sentence, and a file it accepts resolves every role of
// every palette it offers, in both modes, at normal and increased contrast. Seeded, so a failure repeats.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';
import 'package:mydata_ui/src/theme/resolve.dart';
import 'package:mydata_ui/src/theme/roles.dart';

/// The files mutated: the good imported example and the designed themes, as an import would see them (ids
/// that are not `mydata.`).
List<Map<String, Object?>> seeds() {
  var n = 0;
  String uuid() => '00000000-0000-4000-8000-${(++n).toString().padLeft(12, '0')}';
  return [
    jsonDecode(File('test/theme/fixtures/good-imported.json').readAsStringSync()) as Map<String, Object?>,
    // The built-ins in name order, as their files were listed before they were generated into Dart.
    for (final id in builtInThemeJson.keys.toList()..sort())
      {...jsonDecode(builtInThemeJson[id]!) as Map<String, Object?>, 'id': uuid()},
  ];
}

/// The built-ins' styles, so a mutated `based-on` may name one.
ThemeFormat designedFormat() => ThemeLibrary.format();

/// Typed to hold anything, so a mutation may put null or junk anywhere (an inferred `Map<String, Object>`
/// would throw on null).
Object? deepCopy(Object? v) => switch (v) {
      Map() => <String, Object?>{for (final e in v.entries) e.key as String: deepCopy(e.value)},
      List() => <Object?>[for (final x in v) deepCopy(x)],
      _ => v,
    };

class Mutator {
  Mutator(int seed) : r = Random(seed);
  final Random r;

  String colour() => '#${r.nextInt(0x1000000).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Object? junk() => switch (r.nextInt(14)) {
        0 => <String, Object?>{},
        1 => <Object?>[],
        2 => 'x',
        3 => 0,
        4 => -1,
        5 => 1e300,
        6 => 0.4,
        7 => true,
        8 => null,
        9 => colour(),
        10 => 'a' * (1 + r.nextInt(400)),
        11 => <Object?>[colour(), 3, null],
        12 => <String, Object?>{'light': colour(), 'dark': 7},
        _ => r.nextBool() ? 'mydata.kiwi' : 'mydata.system',
      };

  /// Every (container, key) in [v], depth first.
  void slots(Object? v, List<(Object, Object)> out) {
    if (v is Map<String, Object?>) {
      for (final k in v.keys) {
        out.add((v, k));
        slots(v[k], out);
      }
    } else if (v is List) {
      for (var i = 0; i < v.length; i++) {
        out.add((v, i));
        slots(v[i], out);
      }
    }
  }

  Object? mutateValue(Object? old) {
    if (old is num && r.nextBool()) {
      return [0, -0.0, 1e-9, 1e9, -1e9, old * 10, old / 10, old + 1, 0.5, 48, 49, 9][r.nextInt(12)];
    }
    if (old is String && old.startsWith('#') && r.nextInt(3) > 0) return colour();
    return junk();
  }

  void mutate(Map<String, Object?> json) {
    final all = <(Object, Object)>[];
    slots(json, all);
    if (all.isEmpty) return;
    final (container, key) = all[r.nextInt(all.length)];
    switch (r.nextInt(4)) {
      case 0: // remove
        if (container is Map) {
          container.remove(key);
        } else if (container is List && container.isNotEmpty) {
          container.removeAt(key as int);
        }
      case 1: // a key of another type, or an unusual value
      case 2:
        if (container is Map) {
          container[key] = mutateValue(container[key]);
        } else if (container is List) {
          container[key as int] = mutateValue(container[key]);
        }
      default: // a key that does not belong, or a known key moved somewhere else
        if (container is Map) {
          const keys = ['frame', 'based-on', 'palettes', 'type', 'roles', 'size', 'accent', 'contrast', 'overrides',
              'gradient', 'same-as', 'preset', 'base', 'ratio', 'window', 'kind', 'name', 'id'];
          container[r.nextBool() ? keys[r.nextInt(keys.length)] : 'k${r.nextInt(99)}'] = junk();
        }
    }
  }
}

void main() {
  final format = designedFormat();
  final base = seeds();
  final fails = <String>[];

  for (final seed in const [1, 2, 3, 4]) {
    test('seed $seed: 600 mutated files are each refused with reasons or resolve every role', () {
      final m = Mutator(seed);
      var accepted = 0;
      for (var i = 0; i < 600; i++) {
        final json = deepCopy(base[m.r.nextInt(base.length)]) as Map<String, Object?>;
        final times = 1 + m.r.nextInt(4);
        for (var t = 0; t < times; t++) {
          m.mutate(json);
        }
        var text = jsonEncode(json);
        if (m.r.nextInt(40) == 0) text = '﻿$text';
        if (m.r.nextInt(40) == 0) text = text.substring(0, m.r.nextInt(text.length));
        final where = 'seed $seed, file $i: $text';

        final ThemeCheck r;
        try {
          r = validateThemeText(text, format);
        } on Object catch (e) {
          fails.add('threw $e\n$where');
          continue;
        }
        if (!r.ok) {
          if (r.errors.isEmpty || r.errors.any((e) => e.trim().isEmpty)) fails.add('refused without a reason\n$where');
          continue;
        }
        accepted++;
        final theme = r.theme!;
        final palettes = theme.frame == ThemeFrame.system
            ? [systemPalette(format.defaults), for (final p in theme.palettes) systemPalette(format.defaults, p)]
            : [for (final p in theme.palettes) if (r.usablePalettes.contains(p.id)) p];
        if (theme.frame == ThemeFrame.drawn && palettes.isEmpty) fails.add('accepted with no palette\n$where');
        try {
          for (final p in palettes) {
            for (final mode in LookMode.values) {
              for (final increased in const [false, true]) {
                final resolved =
                    resolvePalette(theme, p, mode, defaults: format.defaults, increasedContrast: increased);
                if (resolved.roles.length != ColourRole.values.length) {
                  fails.add('${p.id} $mode resolved ${resolved.roles.length} roles\n$where');
                }
              }
            }
          }
          for (final b in Brightness.values) {
            ThemeLibrary.look(theme, brightness: b, platform: TargetPlatform.linux);
          }
        } on Object catch (e) {
          fails.add('accepted, then resolving threw $e\n$where');
        }
      }
      expect(fails, isEmpty, reason: fails.take(5).join('\n\n'));
      // The mutations must leave enough files whole for the second half of the test to mean something.
      expect(accepted, greaterThan(30));
    });
  }
}
