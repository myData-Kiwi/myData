// The component variants as typed values (design/themes/ARCHITECTURE.md 3.2): every value the schema
// defines has its typed counterpart, a file's values reach the look, and a missing key is Kiwi's.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/theme_file.dart' show KeyedEnum;

import 'designed_themes.dart';

void main() {
  final schema = jsonDecode(File('../../../design/themes/theme.schema.json').readAsStringSync()) as Map<String, Object?>;
  final components = ((schema[r'$defs'] as Map)['components'] as Map)['properties'] as Map<String, Object?>;
  List<String> enumOf(Map<String, Object?> props, String key) =>
      ((props[key] as Map)['enum'] as List).cast<String>();
  final button = (components['button'] as Map)['properties'] as Map<String, Object?>;

  final typed = <String, (List<String>, List<Object> Function(MyDataVariants))>{
    'button.primary': (enumOf(button, 'primary'), (v) => [v.primary]),
    'button.secondary': (enumOf(button, 'secondary'), (v) => [v.secondary]),
    'button.shape': (enumOf(button, 'shape'), (v) => [v.buttonShape]),
    for (final k in ['list', 'sidebar', 'toolbar', 'inputs', 'selection', 'avatar', 'tabs', 'chat', 'month', 'today', 'data-colours'])
      k: (enumOf(components, k), (MyDataVariants v) => [switch (k) {
            'list' => v.list,
            'sidebar' => v.sidebar,
            'toolbar' => v.toolbar,
            'inputs' => v.inputs,
            'selection' => v.selection,
            'avatar' => v.avatar,
            'tabs' => v.tabs,
            'chat' => v.chat,
            'month' => v.month,
            'today' => v.today,
            _ => v.dataColours,
          }]),
  };

  test('every value the schema defines reads as its own typed variant', () {
    for (final MapEntry(key: k, value: (values, read)) in typed.entries) {
      final seen = <Object>{};
      for (final value in values) {
        final got = read(MyDataVariants({k: value})).single as KeyedEnum;
        expect(got.key, value, reason: '$k: $value');
        seen.add(got);
      }
      expect(seen, hasLength(values.length), reason: k);
    }
  });

  test('a key a file leaves out is Kiwi\'s', () {
    final none = MyDataVariants(const {});
    expect(none, isNot(MyDataVariants.kiwi));
    expect(none.primary, MyDataVariants.kiwi.primary);
    expect(none.list, ListStyle.inset);
    expect(none.selection, SelectionStyle.tint);
    expect(none.inputs, InputStyle.outlined);
    expect(none.month, MonthStyle.boxed);
  });

  test('the designed themes\' variants reach their looks', () {
    final journal = designedLook('mydata.journal', Brightness.light);
    expect(journal.variants.primary, PrimaryStyle.outline);
    expect(journal.variants.secondary, SecondaryStyle.text);
    expect(journal.variants.list, ListStyle.ruled);
    expect(journal.variants.avatar, AvatarStyle.none);
    expect(journal.variants.chat, ChatStyle.transcript);
    final sticker = designedLook('mydata.sticker', Brightness.dark);
    expect(sticker.variants.primary, PrimaryStyle.brutal);
    expect(sticker.variants.sidebar, SidebarStyle.sourceList);
    expect(sticker.variants.toolbar, ToolbarStyle.floating);
  });

  test('an accent within 25° of danger, both colourful, is near danger', () {
    expect(MyDataLook.accentNearDangerOf(const Color(0xFFD7261E), const Color(0xFFC8102E)), isTrue);
    expect(MyDataLook.accentNearDangerOf(const Color(0xFF2A4BA8), const Color(0xFFC8102E)), isFalse);
    // A grey accent is never near anything.
    expect(MyDataLook.accentNearDangerOf(const Color(0xFF333333), const Color(0xFFC8102E)), isFalse);
    expect(MyDataLook.fallback(Brightness.light).accentNearDanger, isFalse);
  });
}
