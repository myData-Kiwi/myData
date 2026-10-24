import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop(bool _) {}

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

List<CheckboxListItem> _items(List<bool> checked) => [
      CheckboxListItem(title: 'Ava Fictional', caption: 'ava@example.org', checked: checked[0]),
      CheckboxListItem(title: 'Ben Sample', caption: '555-0142', checked: checked[1]),
      CheckboxListItem(title: 'Cleo Example', caption: 'cleo@example.org', checked: checked[2]),
      CheckboxListItem(title: 'Dev Placeholder', caption: 'dev@example.org', checked: checked[3]),
    ];

/// A CheckboxList that keeps its own state, as a screen would.
class _ListHost extends StatefulWidget {
  const _ListHost({required this.initial, this.onChanged});
  final List<bool> initial;
  final ValueChanged<List<bool>>? onChanged;
  @override
  State<_ListHost> createState() => _ListHostState();
}

class _ListHostState extends State<_ListHost> {
  late List<bool> values = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 420,
        child: CheckboxList(
          heading: 'Contacts in the file',
          selectAllTitle: 'All ${values.length} contacts',
          items: _items(values),
          onChanged: (v) {
            setState(() => values = v);
            widget.onChanged?.call(v);
          },
        ),
      );
}

/// Kiwi with [icon]-sized icons, so the box is taller than a line of the label.
ThemeData _bigIcons(double icon) {
  final json = jsonDecode(jsonEncode(ThemeLibrary.kiwi.json)) as Map<String, dynamic>;
  for (final c in ['desktop', 'phone']) {
    ((json['density'] as Map)[c] as Map)['icon'] = icon;
  }
  final file = ThemeFile.fromJson(json, base: json);
  return MyDataTheme.fromLook(ThemeLibrary.look(file, brightness: Brightness.light));
}

void main() {
  goldenMatrix(
    'checkbox',
    () => SizedBox(
      width: 460,
      child: CheckboxStack(children: [
        const MyDataCheckbox(label: 'Unchecked', value: false, onChanged: _noop, autofocus: true),
        const MyDataCheckbox(
            key: ValueKey('hovered'), label: 'Hovered, unchecked', value: false, onChanged: _noop),
        const MyDataCheckbox(
            label: 'Also remove the 3 contacts you changed after the import',
            caption: 'Ava Fictional, Ben Sample and Chloe Example',
            value: true,
            onChanged: _noop),
        const MyDataCheckbox(
            label: 'Disabled, checked',
            value: true,
            onChanged: null,
            disabledReason: 'This Mac’s contacts cannot be removed here.'),
        Row(children: const [
          CheckboxBox(value: false),
          SizedBox(width: MyDataSpace.s3),
          CheckboxBox(value: true),
          SizedBox(width: MyDataSpace.s3),
          CheckboxBox(value: null),
        ]),
      ]),
    ),
    size: const Size(508, 360),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byKey(const ValueKey('hovered'))));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  goldenMatrix(
    'checkbox_list',
    () => const _ListHost(initial: [true, false, true, false]),
    size: const Size(468, 420),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      // Keyboard focus in the list, on its second row.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    },
  );

  group('CheckboxBox', () {
    testWidgets('20px rounded square: unchecked surface with line-strong edge, checked and mixed accent',
        (tester) async {
      Future<BoxDecoration> deco(bool? v, {bool hovered = false}) async {
        await tester.pumpWidget(themedFrame(themeMatrix.first, CheckboxBox(value: v, hovered: hovered)));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(CheckboxBox)), const Size.square(MyDataSize.icon));
        return tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!.box;
      }

      final off = await deco(false);
      expect(off.color, _kiwi.surface);
      expect((off.border! as Border).top.color, _kiwi.lineStrong);
      expect(off.borderRadius, MyDataRadii.xs(kiwiLook));
      expect((await deco(false, hovered: true)).color, _kiwi.surfaceHover);
      expect((await deco(true)).color, _kiwi.accent);
      // A checked box does not change on hover.
      expect((await deco(true, hovered: true)).color, _kiwi.accent);
      expect((await deco(null)).color, _kiwi.accent);
    });
  });

  group('MyDataCheckbox', () {
    testWidgets('the box and the label are one target, at least control-height tall', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          MyDataCheckbox(label: 'Also remove', caption: 'Ava Fictional', value: false, onChanged: got.add)));
      expect(tester.getSize(find.byType(MyDataCheckbox)).height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      await tester.tap(find.byType(CheckboxBox));
      await tester.tap(find.text('Also remove'));
      await tester.tap(find.text('Ava Fictional'));
      await tester.pump();
      expect(got, [true, true, true]);
      // The box sits space-3 before the label, centred on its first line.
      final box = tester.getRect(find.byType(CheckboxBox));
      final label = tester.getRect(find.text('Also remove'));
      expect(label.left - box.right, MyDataSpace.s3);
      expect(box.center.dy, closeTo(label.center.dy, 0.5));
    });

    testWidgets('Space toggles it; Return does nothing (it is left to the main button)', (tester) async {
      final got = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          MyDataCheckbox(label: 'Also remove', value: false, onChanged: got.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(got, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, [true]);
    });

    testWidgets('keyboard focus rings the box, not the label', (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, const MyDataCheckbox(label: 'Also remove', value: false, onChanged: _noop)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
      expect(ring.borderRadius, MyDataRadii.xs(kiwiLook));
      expect(find.descendant(of: find.byType(FocusRing), matching: find.byType(CheckboxBox)), findsOneWidget);
      expect(find.descendant(of: find.byType(FocusRing), matching: find.text('Also remove')), findsNothing);
    });

    testWidgets('disabled: box and label at 45%, the reason not faded, not focusable', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const Column(mainAxisSize: MainAxisSize.min, children: [
            MyDataCheckbox(
                label: 'Remove these',
                value: true,
                onChanged: null,
                disabledReason: 'This Mac’s contacts cannot be removed here.'),
            MyDataCheckbox(label: 'After', value: false, onChanged: _noop),
          ])));
      final reason = find.text('This Mac’s contacts cannot be removed here.');
      expect(reason, findsOneWidget);
      expect(find.ancestor(of: reason, matching: find.byType(Opacity)), findsNothing);
      final label = find.text('Remove these');
      expect(tester.widget<Opacity>(find.ancestor(of: label, matching: find.byType(Opacity)).first).opacity,
          Pressable.disabledOpacity);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus!.context!;
      expect(find.descendant(of: find.byType(MyDataCheckbox).last, matching: find.byWidget(focused.widget)),
          findsOneWidget);
      expect(
          tester.getSemantics(find.byType(MyDataCheckbox).first),
          isSemantics(
              label: 'Remove these\nThis Mac’s contacts cannot be removed here.',
              hasCheckedState: true,
              isChecked: true,
              hasEnabledState: true,
              isEnabled: false));
      handle.dispose();
    });

    testWidgets('semantics: label, caption, checkbox, checked', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          const MyDataCheckbox(label: 'Ava Fictional', caption: 'ava@example.org', value: true, onChanged: _noop)));
      expect(
          tester.getSemantics(find.byType(MyDataCheckbox)),
          isSemantics(
              label: 'Ava Fictional\nava@example.org',
              hasCheckedState: true,
              isChecked: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true));
      handle.dispose();
    });

    testWidgets('a press dims it to 85% without shrinking', (tester) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, const MyDataCheckbox(label: 'Also remove', value: false, onChanged: _noop)));
      final before = tester.getSize(find.byType(MyDataCheckbox));
      final g = await tester.startGesture(tester.getCenter(find.text('Also remove')));
      await tester.pump();
      final dim = tester.widget<AnimatedOpacity>(
          find.descendant(of: find.byType(MyDataCheckbox), matching: find.byType(AnimatedOpacity)).first);
      expect(dim.opacity, MyDataMotion.pressOpacity);
      expect(find.descendant(of: find.byType(MyDataCheckbox), matching: find.byType(AnimatedScale)), findsNothing);
      expect(tester.getSize(find.byType(MyDataCheckbox)), before);
      await g.up();
    });
  });

  group('CheckboxList', () {
    testWidgets('select all: mixed when some are checked; pressing checks all, then clears all', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = <List<bool>>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _ListHost(initial: const [true, false, true, false], onChanged: changes.add)));
      expect(find.text('2 of 4 selected'), findsOneWidget);
      final all = find.ancestor(of: find.text('All 4 contacts'), matching: find.byType(MergeSemantics)).first;
      expect(tester.getSemantics(all),
          isSemantics(label: 'All 4 contacts\n2 of 4 selected', hasCheckedState: true, isCheckStateMixed: true,
              hasEnabledState: true, isEnabled: true, isFocusable: true, hasTapAction: true));
      await tester.tap(find.text('All 4 contacts'));
      await tester.pump();
      expect(changes.last, [true, true, true, true]);
      expect(find.text('4 of 4 selected'), findsOneWidget);
      expect(tester.takeAnnouncements().map((a) => a.message), ['4 of 4 selected']);
      await tester.tap(find.text('All 4 contacts'));
      await tester.pump();
      expect(changes.last, [false, false, false, false]);
      handle.dispose();
    });

    testWidgets('one Tab stop after select all: arrows move, Space toggles, ⌘A checks all', (tester) async {
      final changes = <List<bool>>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _ListHost(initial: const [false, false, false, false], onChanged: changes.add)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // select all
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // the list
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes.last, [false, true, false, false]);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes.last, [false, true, false, true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes.last, [true, true, false, true]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(changes.last, [true, true, true, true]);
      // Tab leaves the list: it is one stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byType(CheckboxList), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('⇧-Space and ⇧-click set the range from the last one changed to this one\'s new state',
        (tester) async {
      final changes = <List<bool>>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _ListHost(initial: const [false, false, false, false], onChanged: changes.add)));
      await tester.tap(find.text('Ava Fictional'));
      await tester.pump();
      expect(changes.last, [true, false, false, false]);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Cleo Example'));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(changes.last, [true, true, true, false]);
      // ⇧-Space on the last row: from Cleo (changed last) to Dev, Dev's new state (checked).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(changes.last, [true, true, true, true]);
    });

    testWidgets('rows: box in an icon-tile slot, row-height, a checked row has no fill', (tester) async {
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _ListHost(initial: [true, false, false, false])));
      final row = tester.getRect(find.ancestor(of: find.text('Ava Fictional'), matching: find.byType(ConstrainedBox)).first);
      expect(row.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      final box = tester.getRect(find.byType(CheckboxBox).at(1));
      expect(box.center.dx - row.left, MyDataSpace.s4 + MyDataSize.iconTile / 2);
      final fills = tester.widgetList<AnimatedContainer>(find.descendant(
          of: find.ancestor(of: find.text('Ava Fictional'), matching: find.byType(MergeSemantics)).first,
          matching: find.byType(AnimatedContainer)));
      for (final f in fills) {
        final color = (f.decoration!.box).color;
        expect(color == _kiwi.accentSoft, isFalse);
      }
    });

    testWidgets('a disabled item is skipped by the keys and left alone by select all', (tester) async {
      List<bool>? got;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 420,
            child: CheckboxList(
              heading: 'Address books',
              selectAllTitle: 'All 3 address books',
              items: const [
                CheckboxListItem(title: 'Family', checked: false),
                CheckboxListItem(title: 'This Mac', checked: false, disabledReason: 'This Mac is followed only.'),
                CheckboxListItem(title: 'Work', checked: false),
              ],
              onChanged: (v) => got = v,
            ),
          )));
      await tester.tap(find.text('All 3 address books'));
      await tester.pump();
      expect(got, [true, false, true]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // select all
      await tester.sendKeyEvent(LogicalKeyboardKey.tab); // the list
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(got, [false, false, true]);
      expect(find.text('This Mac is followed only.'), findsOneWidget);
    });
  });

  testWidgets('CheckboxList: screen readers follow the row the keys are on', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _ListHost(initial: [false, false, false, false])));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // select all
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // the list
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.getSemantics(find.text('Ben Sample')).flagsCollection.isFocused, Tristate.isTrue);
    expect(tester.getSemantics(find.text('Ava Fictional')).flagsCollection.isFocused, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('CheckboxList rows are body-strong at 16px on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(themeMatrix.first, const _ListHost(initial: [false, false, false, false])));
    expect(tester.widget<Text>(find.text('Ava Fictional')).style!.fontSize, PhoneType.bodySize);
    expect(tester.widget<Text>(find.text('All 4 contacts')).style!.fontSize, PhoneType.bodySize);
  });

  testWidgets('while its form waits for the host nothing is checked: a box, a row or select all', (tester) async {
    final changes = <List<bool>>[];
    var box = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        FormBusy(
          busy: true,
          child: Column(children: [
            MyDataCheckbox(label: 'Also remove the changed ones', value: false, onChanged: (_) => box++),
            _ListHost(initial: const [false, false, false, false], onChanged: changes.add),
          ]),
        )));
    await tester.tap(find.text('Also remove the changed ones'));
    await tester.tap(find.text('Ben Sample'));
    await tester.tap(find.text('All 4 contacts'));
    await tester.pump();
    expect(box, 0);
    expect(changes, isEmpty);
  });

  testWidgets('a row with a trailing button: two targets side by side, and what is below it', (tester) async {
    var compared = 0;
    var changes = <List<bool>>[];
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SizedBox(
        width: 600,
        child: CheckboxList(
          heading: 'Possible duplicates (1)',
          items: [
            CheckboxListItem(
              title: 'Ben Sample',
              caption: 'Same name as Ben Sample in myData.',
              checked: true,
              trailing: Button(label: 'Compare', variant: ButtonVariant.plain, onPressed: () => compared++),
              below: const Text('The comparison'),
            ),
          ],
          onChanged: (v) => changes.add(v),
        ),
      ),
    ));
    await tester.tap(find.text('Compare'));
    expect(compared, 1);
    expect(changes, isEmpty, reason: 'the button is not inside the checkbox target');
    await tester.tap(find.text('Ben Sample'));
    expect(changes, [
      [false],
    ]);
    expect(find.text('The comparison'), findsOneWidget);
  });

  testWidgets('folded: no rows, but select all acts on every item', (tester) async {
    List<bool>? got;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SizedBox(
        width: 600,
        child: CheckboxList(
          heading: 'New contacts (2)',
          selectAllTitle: 'All 2 contacts',
          folded: true,
          items: const [
            CheckboxListItem(title: 'Cleo Example', checked: true),
            CheckboxListItem(title: 'Dev Placeholder', checked: true),
          ],
          onChanged: (v) => got = v,
        ),
      ),
    ));
    expect(find.text('Cleo Example'), findsNothing);
    await tester.tap(find.text('All 2 contacts'));
    expect(got, [false, false]);
  });

  testWidgets('shown: a list of thousands draws only its first rows; select all still acts on every item',
      (tester) async {
    List<bool>? got;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = [
      for (var i = 0; i < 5000; i++) CheckboxListItem(title: 'Ava Fictional $i', checked: true),
    ];
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: CheckboxList(
            heading: 'New contacts (5,000)',
            selectAllTitle: 'All 5,000 contacts',
            shown: 200,
            items: items,
            onChanged: (v) => got = v,
          ),
        ),
      ),
    ));
    // 200 rows and select all: the build stays bounded, whatever the list's length.
    expect(find.byType(CheckboxBox), findsNWidgets(201));
    expect(find.text('Ava Fictional 199', skipOffstage: false), findsOneWidget);
    expect(find.text('Ava Fictional 200', skipOffstage: false), findsNothing);
    await tester.tap(find.text('All 5,000 contacts'));
    expect(got, hasLength(5000));
    expect(got!.every((v) => !v), isTrue);
  });

  testWidgets('shown: End stops at the last row drawn', (tester) async {
    List<bool>? got;
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SizedBox(
        width: 420,
        child: CheckboxList(
          heading: 'Contacts in the file',
          shown: 2,
          items: _items(const [false, false, false, false]),
          onChanged: (v) => got = v,
        ),
      ),
    ));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(got, [false, true, false, false]);
  });

  testWidgets('a box taller than a line of its label moves the label down to it, never the box up', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: _bigIcons(32),
      home: const Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: MyDataCheckbox(label: 'Unchecked', value: false, onChanged: _noop),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.byType(CheckboxBox));
    final label = tester.getRect(find.text('Unchecked'));
    expect(box.top, greaterThanOrEqualTo(0));
    expect(label.center.dy, closeTo(box.center.dy, 0.5), reason: 'the label is centred on the box');
  });
}
