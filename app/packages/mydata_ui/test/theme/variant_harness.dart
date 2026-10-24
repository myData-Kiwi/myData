// What the component variant goldens share (design/themes/ARCHITECTURE.md 5, phase 3): Kiwi as the apps draw
// it with one `components` value changed, pumped on a specimen of real widgets in light and dark.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

void noop() {}

/// Kiwi as drawn today, with [edit] applied to its JSON.
ThemeFile kiwiWith(void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(kiwiThemeJson) as Map<String, dynamic>;
  edit(json);
  return ThemeFile.fromJson(json, base: json);
}

/// Sets `components[key]` (`button.primary` sets `components.button.primary`).
void Function(Map<String, dynamic>) component(String key, String value) => (json) {
      final components = json['components'] as Map<String, dynamic>;
      if (key.startsWith('button.')) {
        (components['button'] as Map<String, dynamic>)[key.substring('button.'.length)] = value;
      } else {
        components[key] = value;
      }
    };

/// Sets [values] in the style group [group] (`borders`, `materials`).
void Function(Map<String, dynamic>) styleGroup(String group, Map<String, Object?> values) =>
    (json) => (json[group] as Map<String, dynamic>).addAll(values);

/// Every edit in [edits], in order.
void Function(Map<String, dynamic>) all(List<void Function(Map<String, dynamic>)> edits) => (json) {
      for (final e in edits) {
        e(json);
      }
    };

/// Kiwi's palettes with the accent moved near `danger`'s red (light and dark), so Approve and the primary
/// are drawn in `ink`.
void nearRedAccent(Map<String, dynamic> json) {
  final palette = (json['palettes'] as List).first as Map<String, dynamic>;
  (palette['light'] as Map<String, dynamic>)
    ..['accent'] = '#B0302A'
    ..['on-accent'] = '#FFFFFF';
  (palette['dark'] as Map<String, dynamic>)
    ..['accent'] = '#F0948A'
    ..['on-accent'] = '#2A0B08';
  final overrides = palette['overrides'] as Map<String, dynamic>?;
  for (final mode in ['light', 'dark']) {
    final o = overrides?[mode] as Map<String, dynamic>?;
    o?.removeWhere((k, _) => const {'accent-soft', 'link', 'selection', 'on-selection'}.contains(k));
  }
}

/// Every value of every component in [keys], from the schema's enumerations.
const componentValues = <String, List<String>>{
  'button.primary': ['filled', 'outline', 'brutal', 'bevel', 'push'],
  'button.secondary': ['tonal', 'outline', 'text'],
  'button.shape': ['pill', 'rounded', 'square', 'cut'],
  'list': ['plain', 'inset', 'cards', 'bordered', 'ruled', 'table'],
  'sidebar': ['source-list', 'column', 'rail', 'tabs'],
  'toolbar': ['native', 'flat', 'floating'],
  'inputs': ['filled', 'outlined', 'underlined'],
  'selection': ['tint', 'solid', 'inverse', 'bar', 'outline', 'highlighter'],
  'avatar': ['circle', 'rounded', 'square', 'shape', 'none'],
  'tabs': ['pill', 'underline', 'boxed'],
  'chat': ['bubbles', 'blocks', 'transcript'],
  'month': ['boxed', 'open', 'table'],
  'today': ['disc', 'ring', 'inverse'],
  'data-colours': ['colour', 'pattern'],
};

/// Pumps [child] in [theme] for [brightness] on the look's ground, [size] at 1x, off the Mac shell; with
/// [focus], that node is focused by keyboard so its ring shows.
Future<void> pumpVariant(WidgetTester tester, ThemeFile theme, Brightness brightness, Widget child,
    {Size size = const Size(560, 200), FocusNode? focus, MediaQueryData? media}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final look = ThemeLibrary.look(theme, brightness: brightness, platform: TargetPlatform.linux);
  Widget home = Builder(
    builder: (context) => Material(
      color: context.colors.bg,
      child: Padding(padding: EdgeInsets.all(context.space(4)), child: child),
    ),
  );
  if (media != null) home = MediaQuery(data: media.copyWith(size: size), child: home);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    // A desktop, so a focused field shows no touch selection handle.
    theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
    home: home,
  ));
  if (focus != null) {
    await tester.sendKeyEvent(LogicalKeyboardKey.shift);
    focus.requestFocus();
  }
  await tester.pumpAndSettle();
}

/// A phone's width and height, for the variant goldens' phone pass.
const phoneSize = Size(360, 740);

/// One golden per value of [key] in light and dark, `goldens/variant.<key>-<value>[-<name>].<mode>.png`, each
/// [build] pumped in Kiwi with that value (and [also]); every target meets [minTarget] (the desktop floor),
/// and nothing overflows. [modes] narrows the modes (a phone pass draws light only).
void variantGoldens(String key, Widget Function(FocusNode focus) build,
    {Size size = const Size(560, 200),
    bool focused = true,
    List<String>? values,
    String? name,
    void Function(Map<String, dynamic> json)? also,
    Future<void> Function(WidgetTester tester)? before,
    List<Brightness> modes = Brightness.values,
    double minTarget = 24}) {
  for (final value in values ?? componentValues[key]!) {
    for (final b in modes) {
      final file = '$key-$value${name == null ? '' : '-$name'}';
      testWidgets('variant golden: $file, ${b.name}', (tester) async {
        debugDisableShadows = false;
        try {
          final focus = FocusNode();
          addTearDown(focus.dispose);
          await pumpVariant(
              tester, kiwiWith(all([component(key, value), ?also])), b, build(focus),
              size: size, focus: focused ? focus : null);
          await before?.call(tester);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(MinimumTapTargetGuideline(size: Size(minTarget, minTarget), link: '')));
          await expectLater(
              find.byType(MaterialApp), matchesGoldenFile('goldens/variant.$file.${b.name}.png'));
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}
