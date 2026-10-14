import 'dart:ui' show SemanticsRole;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// An imported calendar's own colour, not in the palette.
final _imported = parseDataColour('#2E8B8B')!;

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.current, this.onChanged});
  final Color initial;
  final Color? current;
  final ValueChanged<Color>? onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Color value = widget.initial;

  @override
  Widget build(BuildContext context) => ColourPicker(
        value: value,
        currentColour: widget.current,
        onChanged: (c) {
          widget.onChanged?.call(c);
          setState(() => value = c);
        },
      );
}

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(800, 400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child));
}

Finder _swatch(String name) => find.byKey(ValueKey('colour-swatch-$name'));

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  const light = MyDataColors.light;
  const dark = MyDataColors.dark;

  group('goldens', () {
    // Blue chosen with keyboard focus; the pointer over Green.
    goldenMatrix(
      'colour_picker',
      () => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Builder(builder: (context) => _Host(initial: context.colors.dataBlue)),
        const SizedBox(height: MyDataSpace.s6),
        // An imported colour: "Current colour", chosen, at the end.
        _Host(initial: _imported, current: _imported),
        const SizedBox(height: MyDataSpace.s6),
        // Yellow chosen: its disc keeps the edge on `accent-soft`.
        Builder(builder: (context) => _Host(initial: context.colors.dataYellow)),
      ]),
      size: const Size(640, 400),
      before: (tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(_swatch('Green').first));
        addTearDown(mouse.removePointer);
      },
    );

    // Under 600px: four columns, two even rows of four, "Current colour" starting a third.
    goldenMatrix(
      'colour_picker_phone',
      () => _Host(initial: _imported, current: _imported),
      size: const Size(390, 260),
    );
  });

  test('the palette: eight data colours in order, one value in both modes', () {
    final names = ColourPicker.palette(light).map((p) => p.name).toList();
    expect(names, ['Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Brown', 'Grey']);
    expect(ColourPicker.palette(light).map((p) => p.colour), ColourPicker.palette(dark).map((p) => p.colour));
    expect(ColourPicker.toHex(light.dataRed), '#D34730');
    expect(ColourPicker.toHex(light.dataBlue), '#159CE2');
  });

  test('a new calendar starts with the first unused colour, or Red', () {
    expect(ColourPicker.firstUnused(light, []), light.dataRed);
    expect(ColourPicker.firstUnused(light, [light.dataRed, light.dataOrange]), light.dataYellow);
    expect(ColourPicker.firstUnused(light, ColourPicker.palette(light).map((p) => p.colour)), light.dataRed);
  });

  test('a palette colour is found by value, whatever its alpha', () {
    expect(ColourPicker.inPalette(light, parseDataColour('#159CE2CC')!)!.name, 'Blue');
    expect(ColourPicker.inPalette(light, _imported), isNull);
  });

  testWidgets('the chosen colour is named under the row', (tester) async {
    await _pump(tester, _Host(initial: light.dataBlue));
    expect(find.text('Colour'), findsOneWidget);
    expect(find.text('Blue'), findsOneWidget);
  });

  testWidgets('a colour not in the palette adds a chosen "Current colour" swatch', (tester) async {
    final changes = <Color>[];
    await _pump(tester, _Host(initial: _imported, current: _imported, onChanged: changes.add));
    expect(_swatch('Current colour'), findsOneWidget);
    expect(find.text('Current colour'), findsOneWidget);
    await tester.tap(_swatch('Purple'));
    await tester.pumpAndSettle();
    expect(changes, [light.dataPurple]);
    // Still there while the form is open, so the user can go back before Save.
    await tester.tap(_swatch('Current colour'));
    await tester.pumpAndSettle();
    expect(changes.last.toARGB32(), _imported.toARGB32());
  });

  testWidgets('a palette colour adds no extra swatch', (tester) async {
    await _pump(tester, _Host(initial: light.dataGreen, current: light.dataGreen));
    expect(_swatch('Current colour'), findsNothing);
  });

  testWidgets('a radio group with one tab stop; the arrow keys choose and wrap', (tester) async {
    final changes = <Color>[];
    await _pump(tester, Column(mainAxisSize: MainAxisSize.min, children: [
      _Host(initial: light.dataGrey, onChanged: changes.add),
      Button(label: 'Save', onPressed: () {}),
    ]));
    await _key(tester, LogicalKeyboardKey.tab);
    final grey = tester.widget<Pressable>(_swatch('Grey')).focusNode!;
    expect(grey.hasPrimaryFocus, isTrue, reason: 'Tab lands on the chosen swatch');
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(changes, [light.dataRed], reason: 'wraps from the last to the first');
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(changes, [light.dataRed, light.dataGrey, light.dataBrown, light.dataGrey]);
    await _key(tester, LogicalKeyboardKey.tab);
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<Button>(), isNotNull,
        reason: 'one Tab leaves the group');
  });

  testWidgets('screen readers: a radio group named Colour, radios named by colour', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _Host(initial: light.dataBlue));
    final group = tester.getSemantics(find.byType(ColourPicker));
    expect(group.label, 'Colour');
    expect(group.role, SemanticsRole.radioGroup);
    expect(tester.getSemantics(_swatch('Blue')), isSemantics(label: 'Blue', isChecked: true, isInMutuallyExclusiveGroup: true));
    expect(tester.getSemantics(_swatch('Red')), isSemantics(label: 'Red', isChecked: false));
    handle.dispose();
  });

  testWidgets('desktop swatches have their name as a tooltip; phones have none', (tester) async {
    await _pump(tester, _Host(initial: light.dataBlue));
    expect(find.byType(Tooltip), findsNWidgets(8));
    await _pump(tester, _Host(initial: light.dataBlue), size: const Size(390, 400));
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('under 600px the swatches are four to a row', (tester) async {
    await _pump(tester, _Host(initial: light.dataBlue), size: const Size(390, 400));
    final red = tester.getTopLeft(_swatch('Red'));
    final green = tester.getTopLeft(_swatch('Green'));
    final blue = tester.getTopLeft(_swatch('Blue'));
    expect(green.dy, red.dy);
    expect(blue.dy, greaterThan(red.dy));
    expect(blue.dx, red.dx);
  });

  test('yellow is the one colour that needs its edge on surface in light mode', () {
    final needs = [
      for (final p in ColourPicker.palette(light))
        if (dataColourNeedsEdge(p.colour, light.surface)) p.name,
    ];
    expect(needs, ['Yellow']);
  });

  testWidgets('while its form waits for the host, a click or an arrow key changes nothing', (tester) async {
    final changes = <Color>[];
    await _pump(tester, FormBusy(busy: true, child: _Host(initial: light.dataBlue, onChanged: changes.add)));
    await tester.tap(_swatch('Green'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(changes, isEmpty);
  });
}
