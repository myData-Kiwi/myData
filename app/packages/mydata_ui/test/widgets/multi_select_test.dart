import 'package:flutter/material.dart';
import 'dart:ui' show CheckedState, Tristate;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

const _people = {
  'ava': ('Ava Fictional', 'ava@example.org'),
  'ben': ('Ben Sample', '555-0142'),
  'cleo': ('Cleo Example', 'cleo@example.org'),
  'dev': ('Dev Placeholder', 'dev@example.org'),
  'eli': ('Eli Testcase', '555-0177'),
  'fay': ('Fay Mockup', 'fay@example.org'),
};

Widget _row(BuildContext context, String key) {
  final c = context.colors;
  final (name, caption) = _people[key]!;
  return Row(children: [
    Avatar(name: name, size: AvatarSize.small),
    const SizedBox(width: MyDataSpace.s3),
    Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
        Text(caption, style: MyDataType.caption.copyWith(color: c.inkMuted)),
      ]),
    ),
  ]);
}

Widget _list(MultiSelectController<String> ctrl, {bool selectMode = false, ValueChanged<String>? onOpen}) => SizedBox(
      width: 360,
      child: Builder(
        builder: (context) => MultiSelectList<String>(
          controller: ctrl,
          label: 'Contacts',
          itemBuilder: _row,
          semanticLabelOf: (k) => '${_people[k]!.$1}, ${_people[k]!.$2}',
          countLabel: (n) => '$n ${n == 1 ? 'contact' : 'contacts'} selected',
          selectMode: selectMode,
          onOpen: onOpen,
        ),
      ),
    );

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key, {LogicalKeyboardKey? withKey}) async {
  if (withKey != null) await tester.sendKeyDownEvent(withKey);
  await tester.sendKeyEvent(key);
  if (withKey != null) await tester.sendKeyUpEvent(withKey);
  await tester.pump();
}

void main() {
  group('MultiSelectController', () {
    MultiSelectController<String> make() => MultiSelectController(rows: _people.keys.toList());

    test('a click selects one row and makes it the anchor and the focus', () {
      final c = make()..select('cleo');
      expect(c.selected, ['cleo']);
      expect(c.anchor, 'cleo');
      expect(c.focused, 'cleo');
    });

    test('⌘-click adds and removes, and moves the anchor', () {
      final c = make()
        ..select('ava')
        ..toggle('cleo');
      expect(c.selected, ['ava', 'cleo']);
      expect(c.anchor, 'cleo');
      c.toggle('ava');
      expect(c.selected, ['cleo']);
    });

    test('⇧-click selects the range from the anchor, keeping rows added with ⌘', () {
      final c = make()
        ..select('ava')
        ..toggle('dev')
        ..extendTo('fay');
      expect(c.selected, ['ava', 'dev', 'eli', 'fay']);
      // A second ⇧-click replaces the range, not the ⌘ rows.
      c.extendTo('eli');
      expect(c.selected, ['ava', 'dev', 'eli']);
      c.extendTo('ben');
      expect(c.selected, ['ava', 'ben', 'cleo', 'dev']);
    });

    test('⌘A selects every row; Escape returns to the focused row, then has nothing to do', () {
      final c = make()
        ..select('ben')
        ..selectAll();
      expect(c.count, 6);
      expect(c.clearToFocused(), isTrue);
      expect(c.selected, ['ben']);
      expect(c.clearToFocused(), isFalse);
    });

    test('Escape with one row selected and focus moved elsewhere changes nothing and goes on', () {
      final c = make()
        ..select('ava')
        ..focusOnly('cleo');
      expect(c.clearToFocused(), isFalse);
      expect(c.selected, ['ava']);
      expect(c.focused, 'cleo');
    });

    test('Escape with nothing selected selects nothing, so it can go on to clear the search', () {
      final c = make()
        ..toggle('ben')
        ..toggle('ben');
      expect(c.selected, isEmpty);
      expect(c.focused, 'ben');
      expect(c.clearToFocused(), isFalse);
      expect(c.selected, isEmpty);
    });

    test('Escape keeps the focused row when selected, else the anchor, else the first selected', () {
      final c = make()
        ..select('ben')
        ..toggle('dev')
        ..focusOnly('fay');
      // Focus on a row that is not selected: the anchor (dev, the last ⌘-click) stays.
      expect(c.clearToFocused(), isTrue);
      expect(c.selected, ['dev']);
    });

    test('rows hidden by a search leave the selection and do not come back', () {
      final c = make()
        ..select('ava')
        ..toggle('ben')
        ..toggle('cleo');
      c.rows = ['ava', 'cleo'];
      expect(c.selected, ['ava', 'cleo']);
      c.rows = _people.keys.toList();
      expect(c.selected, ['ava', 'cleo']);
    });

    test('runs: adjacent selected rows join', () {
      final c = make()
        ..select('ben')
        ..extendTo('dev')
        ..toggle('fay');
      expect(c.joins('ben'), (up: false, down: true));
      expect(c.joins('cleo'), (up: true, down: true));
      expect(c.joins('dev'), (up: true, down: false));
      expect(c.joins('fay'), (up: false, down: false));
      expect(c.joins('ava'), (up: false, down: false));
    });

    test('summariseNames: up to three names and the rest as a count', () {
      expect(summariseNames(['Ava Fictional']), 'Ava Fictional');
      expect(summariseNames(['Ava Fictional', 'Ben Sample']), 'Ava Fictional and Ben Sample');
      expect(summariseNames(['A', 'B', 'C']), 'A, B and C');
      expect(summariseNames(['Ava Fictional', 'Ben Sample', 'Cleo Example', ...List.filled(9, 'X')]),
          'Ava Fictional, Ben Sample, Cleo Example and 9 more');
    });
  });

  goldenMatrix(
    'multi_select',
    () {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList())
        ..select('ben')
        ..extendTo('dev')
        ..toggle('fay')
        ..focusOnly('cleo');
      return Builder(
        builder: (context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _list(ctrl),
          const SizedBox(width: MyDataSpace.s8),
          Expanded(
            child: MultiSelectSummary(
              title: '4 contacts selected',
              names: summariseNames(['Ben Sample', 'Cleo Example', 'Dev Placeholder', 'Fay Mockup']),
              leftOut: '1 of them is from this Mac and is changed in Contacts.',
              actions: [
                Button(label: 'Add to group…', onPressed: () {}),
                Button(label: 'Delete 3 contacts', onPressed: () {}, variant: ButtonVariant.plainDanger),
              ],
            ),
          ),
        ]),
      );
    },
    size: const Size(860, 460),
    before: (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    },
  );

  goldenMatrix(
    'multi_select_phone',
    () {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList())
        ..toggle('ava')
        ..toggle('cleo');
      return _list(ctrl, selectMode: true);
    },
    size: const Size(408, 460),
  );

  group('MultiSelectList', () {
    testWidgets('click, ⌘-click and ⇧-click; a plain click opens the row', (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      final opened = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl, onOpen: opened.add)));
      await tester.tap(find.text('Ben Sample'));
      await tester.pump();
      expect(ctrl.selected, ['ben']);
      expect(opened, ['ben']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tap(find.text('Eli Testcase'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(ctrl.selected, ['ben', 'eli']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Cleo Example'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(ctrl.selected, ['ben', 'cleo', 'dev', 'eli']);
      expect(opened, ['ben']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('keyboard: one Tab stop; Up and Down select; ⇧ extends; Option moves focus; Space adds',
        (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      final opened = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl, onOpen: opened.add)));
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(ctrl.selected, ['ava']);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(ctrl.selected, ['ben']);
      expect(opened, ['ava', 'ben']);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.shiftLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.shiftLeft);
      expect(ctrl.selected, ['ben', 'cleo', 'dev']);
      await _press(tester, LogicalKeyboardKey.arrowUp, withKey: LogicalKeyboardKey.shiftLeft);
      expect(ctrl.selected, ['ben', 'cleo']);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.altLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.altLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.altLeft);
      expect(ctrl.focused, 'fay');
      expect(ctrl.selected, ['ben', 'cleo']);
      await _press(tester, LogicalKeyboardKey.space);
      expect(ctrl.selected, ['ben', 'cleo', 'fay']);
      await _press(tester, LogicalKeyboardKey.end, withKey: LogicalKeyboardKey.shiftLeft);
      await _press(tester, LogicalKeyboardKey.home, withKey: LogicalKeyboardKey.shiftLeft);
      expect(ctrl.selected, ['ava', 'ben', 'cleo', 'dev', 'eli', 'fay']);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(ctrl.selected, ['ava']);
      await _press(tester, LogicalKeyboardKey.keyA, withKey: LogicalKeyboardKey.metaLeft);
      expect(ctrl.count, 6);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('the count is announced politely when it changes', (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      await tester.tap(find.text('Ava Fictional'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tap(find.text('Ben Sample'));
      await tester.tap(find.text('Cleo Example'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message),
          ['1 contact selected', '2 contacts selected', '3 contacts selected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('⌘-click toggles on macOS; a Control-click there is the context menu and changes nothing',
        (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      final opened = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl, onOpen: opened.add)));
      await tester.tap(find.text('Ben Sample'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Eli Testcase'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(ctrl.selected, ['ben']);
      expect(opened, ['ben']);
      await _press(tester, LogicalKeyboardKey.keyA, withKey: LogicalKeyboardKey.controlLeft);
      expect(ctrl.count, 1, reason: 'Control-A is not Select all on macOS');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Ctrl-click toggles and Ctrl+A selects all on Windows and Linux', (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      await tester.tap(find.text('Ben Sample'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('Eli Testcase'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(ctrl.selected, ['ben', 'eli']);
      await _press(tester, LogicalKeyboardKey.keyA, withKey: LogicalKeyboardKey.controlLeft);
      expect(ctrl.count, 6);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('screen readers follow the row the keys are on', (tester) async {
      final handle = tester.ensureSemantics();
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowDown, withKey: LogicalKeyboardKey.altLeft);
      expect(ctrl.focused, 'ben');
      expect(tester.getSemantics(find.text('Ben Sample')).flagsCollection.isFocused, Tristate.isTrue);
      expect(tester.getSemantics(find.text('Ava Fictional')).flagsCollection.isFocused, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('a run shares one ring: no divider and no ring between adjacent selected rows', (tester) async {
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList())
        ..select('ben')
        ..extendTo('cleo');
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      final frames = tester.widgetList<MultiSelectRowFrame>(find.byType(MultiSelectRowFrame)).toList();
      expect(frames[1].selected && frames[1].joinsDown && !frames[1].joinsUp, isTrue);
      expect(frames[2].selected && frames[2].joinsUp && !frames[2].joinsDown, isTrue);
      expect(frames[0].selected, isFalse);
      // The 1px between Ben and Cleo is the run's fill, not a `line` divider.
      final between = tester.getRect(find.byType(MultiSelectRowFrame).at(1)).bottom;
      final divider = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final deco = c.decoration;
        return deco is BoxDecoration && deco.color == _kiwi.accentSoft && deco.border != null;
      });
      expect(divider, hasLength(1));
      expect(tester.getRect(find.byWidget(divider.first)).top, between);
    });

    testWidgets('semantics: each row reads its name and "selected"', (tester) async {
      final handle = tester.ensureSemantics();
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList())..select('ben');
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      final ben = tester.getSemantics(find.bySemanticsLabel('Ben Sample, 555-0142'));
      expect(ben.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      final ava = tester.getSemantics(find.bySemanticsLabel('Ava Fictional, ava@example.org'));
      expect(ava.flagsCollection.isSelected.toBoolOrNull(), isFalse);
      handle.dispose();
    });

    testWidgets('select mode: the boxes show, a tap toggles and opens nothing, rows read as checkboxes',
        (tester) async {
      final handle = tester.ensureSemantics();
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList());
      final opened = <String>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl, selectMode: true, onOpen: opened.add)));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxBox), findsNWidgets(6));
      await tester.tap(find.text('Ava Fictional'));
      await tester.tap(find.text('Cleo Example'));
      await tester.pump();
      expect(ctrl.selected, ['ava', 'cleo']);
      expect(opened, isEmpty);
      final ava = tester.getSemantics(find.bySemanticsLabel('Ava Fictional, ava@example.org'));
      expect(ava.flagsCollection.isChecked, CheckedState.isTrue);
      await tester.tap(find.text('Ava Fictional'));
      await tester.pump();
      expect(ctrl.selected, ['cleo']);
      handle.dispose();
    });

    testWidgets('selected rows: accent-soft fill; the focused row gets the focus ring inside', (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      final ctrl = MultiSelectController<String>(rows: _people.keys.toList())..select('ben');
      await tester.pumpWidget(themedFrame(themeMatrix.first, _list(ctrl)));
      await _press(tester, LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final frame = tester.widget<MultiSelectRowFrame>(find.byType(MultiSelectRowFrame).at(1));
      expect(frame.selected, isTrue);
      expect(frame.focused, isTrue);
      final fill = tester.widget<AnimatedContainer>(
          find.descendant(of: find.byType(MultiSelectRowFrame).at(1), matching: find.byType(AnimatedContainer)).first);
      expect((fill.decoration! as BoxDecoration).color, _kiwi.accentSoft);
    });
  });
}
