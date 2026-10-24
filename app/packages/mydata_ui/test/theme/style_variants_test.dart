// The design rules a theme's style sets (design/themes/ARCHITECTURE.md 1.2 and 5, phase 3): one golden per
// value of each rule, in light and dark, on the same specimen of real components. Each look is Kiwi as the
// apps draw it with that one rule changed, so the golden shows what the rule does and nothing else.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

void _noop() {}

/// Kiwi as drawn today, with [edit] applied to its JSON.
ThemeFile variantTheme(void Function(Map<String, dynamic> json) edit) {
  final json = jsonDecode(kiwiThemeJson) as Map<String, dynamic>;
  edit(json);
  return ThemeFile.fromJson(json, base: json);
}

/// One value of one rule: its name in the golden's file name and the edit that sets it.
typedef StyleVariant = ({String name, void Function(Map<String, dynamic> json) edit});

void Function(Map<String, dynamic>) _set(String group, Map<String, Object?> values) =>
    (json) => (json[group] as Map<String, dynamic>).addAll(values);

/// Every value of every rule this file covers.
final List<StyleVariant> styleVariants = [
  for (final corners in ['round', 'continuous', 'cut', 'square'])
    (name: 'corners-$corners', edit: _set('shape', {'corners': corners, 'cut-size': 8})),
  for (final controls in ['pill', 'match']) (name: 'controls-$controls', edit: _set('shape', {'controls': controls})),
  // Borders: width, style and colour shown on outlined cards and controls; then where they are drawn.
  for (final width in ['hairline', 1, 2, 3])
    (name: 'border-width-$width', edit: _set('borders', {'width': width, 'cards': true, 'controls': true})),
  for (final style in ['solid', 'dashed', 'double'])
    (name: 'border-style-$style', edit: _set('borders', {'style': style, 'width': 2, 'cards': true, 'colour': 'edge'})),
  for (final colour in ['line', 'line-strong', 'edge', 'accent'])
    (name: 'border-colour-$colour', edit: _set('borders', {'colour': colour, 'width': 2, 'cards': true, 'controls': true})),
  for (final cards in [true, false]) (name: 'border-cards-$cards', edit: _set('borders', {'cards': cards})),
  for (final controls in [true, false])
    (name: 'border-controls-$controls', edit: _set('borders', {'controls': controls, 'colour': 'edge'})),
  for (final separators in ['none', 'inset', 'full'])
    (name: 'separators-$separators', edit: _set('borders', {'separators': separators})),
  for (final rule in ['none', 'single', 'double'])
    (name: 'title-rule-$rule', edit: _set('borders', {'title-rule': rule, 'colour': 'edge'})),
  // Depth: each elevation style at full strength, its drop 4px.
  for (final style in ['none', 'soft', 'hard', 'offset', 'bevel', 'glow'])
    (name: 'elevation-$style', edit: _set('elevation', {'style': style, 'strength': 1, 'offset': 4})),
];

/// Drawn with the filled button held down: the press styles of elevation and motion.
final List<StyleVariant> pressedVariants = [
  for (final press in ['none', 'collapse'])
    (name: 'elevation-press-$press', edit: _set('elevation', {'style': 'hard', 'strength': 1, 'offset': 4, 'press': press})),
];

/// Real components: buttons (the first focused by keyboard), an icon button, a segmented control and a
/// switch, a card, a grouped list, a text field and a badge.
class StyleSpecimen extends StatelessWidget {
  const StyleSpecimen({super.key, required this.focus, required this.controller});
  final FocusNode focus;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => PageScaffold(
        title: 'Devices',
        children: [
          ButtonRow(children: [
            Button(label: 'Approve and send', variant: ButtonVariant.filled, focusNode: focus, onPressed: _noop),
            const Button(label: 'Edit', onPressed: _noop),
            const Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: _noop),
            const Button(label: 'Delete', variant: ButtonVariant.danger, onPressed: _noop),
            const Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: null),
          ]),
          Row(children: [
            MyDataIconButton(icon: MyDataIcon.add, label: 'Add', onPressed: _noop),
            SizedBox(width: context.space(3)),
            SegmentedControl<int>(segments: const [(0, 'Day'), (1, 'Week'), (2, 'Month')], selected: 1, onChanged: (_) {}),
            SizedBox(width: context.space(3)),
            MyDataSwitch(value: true, onChanged: (_) {}, semanticLabel: 'Sync'),
          ]),
          MyDataCard(
            icon: MyDataIcon.cloud,
            name: 'Storage',
            action: const Button(label: 'Add a drive', onPressed: _noop),
            child: const Text('412 GB of 1 TB used on Home drive.'),
          ),
          GroupedList(heading: 'Phone', rows: const [
            GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
            GroupedRow(
              icon: MyDataIcon.cloud,
              title: 'iCloud',
              trailing: GroupedBadge('Connected', tone: MyDataTone.success),
            ),
            GroupedRow(title: 'Open in myContacts', trailing: GroupedChevron(), onPressed: _noop),
          ]),
          MyDataTextField(label: 'Device name', controller: controller, help: 'Shown to your other devices.'),
        ],
      );
}

/// Pumps [theme] in [brightness] on the specimen, with the filled button focused by keyboard.
Future<void> pumpSpecimen(WidgetTester tester, ThemeFile theme, Brightness brightness, {Size size = const Size(600, 860)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final focus = FocusNode();
  final controller = TextEditingController(text: 'Kitchen Mac');
  addTearDown(focus.dispose);
  addTearDown(controller.dispose);
  final look = ThemeLibrary.look(theme, brightness: brightness, platform: TargetPlatform.linux);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MyDataTheme.fromLook(look),
    home: Builder(
      builder: (context) => Material(
        color: context.colors.bg,
        child: StyleSpecimen(focus: focus, controller: controller),
      ),
    ),
  ));
  // Keyboard mode, so the focus ring shows.
  await tester.sendKeyEvent(LogicalKeyboardKey.shift);
  focus.requestFocus();
  await tester.pumpAndSettle();
}

void main() {
  for (final (v, pressed) in [for (final v in styleVariants) (v, false), for (final v in pressedVariants) (v, true)]) {
    for (final b in Brightness.values) {
      testWidgets('style golden: ${v.name}, ${b.name}', (tester) async {
        debugDisableShadows = false;
        TestGesture? hold;
        try {
          await pumpSpecimen(tester, variantTheme(v.edit), b);
          if (pressed) {
            hold = await tester.startGesture(tester.getCenter(find.text('Approve and send')));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/style.${v.name}.${b.name}.png'));
        } finally {
          await hold?.up();
          debugDisableShadows = true;
        }
      });
    }
  }
}
