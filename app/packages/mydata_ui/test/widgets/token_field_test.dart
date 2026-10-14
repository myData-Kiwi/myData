import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

final _kiwi = themeMatrix.first.data.extension<MyDataColors>()!;

const _groups = [
  TokenSuggestion(value: 'Book club'),
  TokenSuggestion(value: 'Book club 2023'),
  TokenSuggestion(value: 'Family'),
  TokenSuggestion(value: 'Garden swap'),
  TokenSuggestion(value: 'Neighbours'),
  TokenSuggestion(value: 'Work'),
];

bool _address(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

/// A TokenField that keeps its own values, as a form would.
class _Host extends StatefulWidget {
  const _Host({this.initial = const [], this.onChanged, this.width = 400, this.rule = false, this.allowNew = true});
  final List<String> initial;
  final ValueChanged<List<String>>? onChanged;
  final double width;
  final bool rule;
  final bool allowNew;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<String> values = widget.initial;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: TokenField(
          label: widget.rule ? 'To' : 'Groups',
          values: values,
          suggestions: widget.rule ? const [] : _groups,
          allowNew: widget.allowNew,
          newValueLabel: (t) => 'New group “$t”',
          placeholder: widget.rule ? 'Add a recipient' : 'Add a group',
          isValid: widget.rule ? _address : null,
          errorText: (bad) => bad.length == 1
              ? '${bad.first} is not a complete address. It looks like name@example.org.'
              : '${bad.length} addresses are not complete. Fix or remove them.',
          countLabel: (n) => '$n groups',
          onChanged: (v) {
            setState(() => values = v);
            widget.onChanged?.call(v);
          },
        ),
      );
}

Future<void> _desktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder get _typing => find.byType(EditableText);

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  goldenMatrix(
    'token_field',
    () => Column(mainAxisSize: MainAxisSize.min, children: const [
      _Host(initial: ['Book club', 'Family', 'Neighbours', 'A very long group name that is cut short at the end']),
      SizedBox(height: MyDataSpace.s5),
      _Host(initial: [], width: 400),
      SizedBox(height: MyDataSpace.s5),
      _Host(initial: ['ava@example.org', 'ben@example'], rule: true),
    ]),
    size: const Size(448, 470),
  );

  goldenMatrix(
    'token_field_suggestions',
    () => const _Host(initial: ['Family']),
    size: const Size(640, 360),
    before: (tester) async {
      await tester.tap(_typing);
      await tester.enterText(_typing, 'bo');
      await tester.pumpAndSettle();
      tester.state<EditableTextState>(_typing).hideToolbar();
      await tester.pump();
    },
  );

  goldenMatrix(
    'token_field_selected',
    () => const _Host(initial: ['Book club', 'Family'], rule: true),
    size: const Size(448, 240),
    before: (tester) async {
      await tester.tap(_typing);
      await tester.pump();
      tester.state<EditableTextState>(_typing).hideToolbar();
      // Backspace selects the last token (invalid: its ring is ink).
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
    },
  );

  group('adding', () {
    testWidgets('typing opens suggestions on word starts; Return takes the highlighted one', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(initial: const ['Family'], onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'club');
      await tester.pumpAndSettle();
      expect(find.text('Book club'), findsOneWidget);
      expect(find.text('Book club 2023'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget, reason: 'only the token: values already in are left out');
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes.last, ['Family', 'Book club']);
      expect(tester.widget<EditableText>(_typing).controller.text, '');
      expect(tester.takeAnnouncements().map((a) => a.message), contains('Added Book club'));
    });

    testWidgets('a comma takes the highlight too; Down moves it; the new-value row comes last', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'book');
      await tester.pumpAndSettle();
      expect(find.text('New group “book”'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.enterText(_typing, 'book,');
      await tester.pumpAndSettle();
      expect(changes.last, ['Book club 2023']);
      await tester.enterText(_typing, 'Book club 2');
      await tester.pumpAndSettle();
      // Nothing matches: the new-value row is the only one, and it is highlighted.
      expect(find.text('New group “Book club 2”'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes.last, ['Book club 2023', 'Book club 2']);
    });

    testWidgets('Tab takes the typed text as typed, never the highlight, then moves on', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            _Host(onChanged: changes.add),
            MyDataTextField(label: 'After', controller: TextEditingController(), focusNode: after),
          ])));
      await tester.tap(_typing.first);
      await tester.enterText(_typing.first, 'bo');
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.tab);
      expect(changes.last, ['bo']);
      expect(after.hasFocus, isTrue);
    });

    testWidgets('leaving the field turns the typed text into a token', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'Allotment');
      await tester.pump();
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pumpAndSettle();
      expect(changes.last, ['Allotment']);
    });

    testWidgets('pasting text with commas, semicolons or line breaks makes one token per part', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'Family; Work,,\nGarden swap');
      await tester.pumpAndSettle();
      expect(changes.last, ['Family', 'Work', 'Garden swap']);
    });

    testWidgets('a value already in is not added twice: its token is selected briefly and it is announced',
        (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(initial: const ['Family'], onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'family');
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes, isEmpty);
      expect(tester.takeAnnouncements().map((a) => a.message), contains('Family is already added'));
      final pill = tester.widget<Container>(
          find.descendant(of: find.byKey(const ValueKey('token:Family')), matching: find.byType(Container)).first);
      expect((pill.decoration! as BoxDecoration).color, _kiwi.accentSoft);
      await tester.pump(TokenField.duplicateFlash);
      final after = tester.widget<Container>(
          find.descendant(of: find.byKey(const ValueKey('token:Family')), matching: find.byType(Container)).first);
      expect((after.decoration! as BoxDecoration).color, _kiwi.surfaceSunken);
    });

    testWidgets('with nothing typed no list opens; Down opens the full list', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host()));
      await tester.tap(_typing);
      await tester.pumpAndSettle();
      expect(find.text('Neighbours'), findsNothing);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Neighbours'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Neighbours'), findsNothing);
    });

    testWidgets('the number of suggestions is announced after typing stops', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(allowNew: false)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'bo');
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);
      await tester.pump(TokenField.announceDelay);
      expect(tester.takeAnnouncements().map((a) => a.message), ['2 suggestions']);
    });
  });

  group('removing', () {
    testWidgets('Backspace at the start selects the last token; Backspace again removes it', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, _Host(initial: const ['Family', 'Work'], onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.backspace);
      expect(changes, isEmpty);
      final pill = tester.widget<Container>(
          find.descendant(of: find.byKey(const ValueKey('token:Work')), matching: find.byType(Container)).first);
      expect((pill.decoration! as BoxDecoration).color, _kiwi.accentSoft);
      await _key(tester, LogicalKeyboardKey.backspace);
      expect(changes.last, ['Family']);
      expect(tester.takeAnnouncements().map((a) => a.message), contains('Removed Work'));
    });

    testWidgets('Left and Right move the selection; past the last returns to the typing point; Delete removes',
        (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host(initial: const ['Family', 'Work', 'Neighbours'], onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.arrowLeft); // Neighbours
      await _key(tester, LogicalKeyboardKey.arrowLeft); // Work
      await _key(tester, LogicalKeyboardKey.arrowLeft); // Family
      await _key(tester, LogicalKeyboardKey.arrowLeft); // stays on Family
      await _key(tester, LogicalKeyboardKey.arrowRight); // Work
      await _key(tester, LogicalKeyboardKey.delete);
      expect(changes.last, ['Family', 'Neighbours']);
      await _key(tester, LogicalKeyboardKey.arrowLeft); // Neighbours
      await _key(tester, LogicalKeyboardKey.arrowRight); // the typing point
      await _key(tester, LogicalKeyboardKey.backspace); // selects Neighbours again
      await _key(tester, LogicalKeyboardKey.escape); // clears the selection
      await _key(tester, LogicalKeyboardKey.delete);
      expect(changes.length, 1);
    });

    testWidgets('the × removes its token and is not a Tab stop', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          Column(mainAxisSize: MainAxisSize.min, children: [
            _Host(initial: const ['Family', 'Work'], onChanged: changes.add),
            MyDataTextField(label: 'After', controller: TextEditingController(), focusNode: after),
          ])));
      await _key(tester, LogicalKeyboardKey.tab);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(after.hasFocus, isTrue, reason: 'the typing point, then on: the × are not stops');
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(changes.last, ['Work']);
    });

    testWidgets('⌘Z brings back the last removed token when there is no typing to undo', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, _Host(initial: const ['Family', 'Work'], onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.backspace);
      await _key(tester, LogicalKeyboardKey.backspace);
      expect(changes.last, ['Family']);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(changes.last, ['Family', 'Work']);
    });

    testWidgets('Return on a selected token, or a double-click, turns it back into text', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host(initial: const ['ava@example.org', 'ben@example'], rule: true, onChanged: changes.add)));
      await tester.tap(_typing);
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.backspace);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(changes.last, ['ava@example.org']);
      expect(tester.widget<EditableText>(_typing).controller.text, 'ben@example');
    });
  });

  testWidgets('a double-click on a token turns it back into text; one click selects it', (tester) async {
    await _desktop(tester);
    final changes = <List<String>>[];
    await tester.pumpWidget(
        themedFrame(themeMatrix.first, _Host(initial: const ['Family', 'Work'], onChanged: changes.add)));
    await tester.tap(find.text('Family'));
    await tester.pump();
    final pill = tester.widget<Container>(
        find.descendant(of: find.byKey(const ValueKey('token:Family')), matching: find.byType(Container)).first);
    expect((pill.decoration! as BoxDecoration).color, _kiwi.accentSoft);
    expect(changes, isEmpty);
    await tester.tap(find.text('Family'));
    await tester.pump();
    expect(changes.last, ['Work']);
    expect(tester.widget<EditableText>(_typing).controller.text, 'Family');
  });

  group('look and states', () {
    testWidgets('tokens: control-height-compact pills on surface-sunken, space-1 apart; field at least 44px',
        (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: ['Family', 'Work'])));
      final a = tester.getRect(find.byKey(const ValueKey('token:Family')));
      final b = tester.getRect(find.byKey(const ValueKey('token:Work')));
      expect(a.height, MyDataSize.controlHeightCompact);
      expect(b.left - a.right, MyDataSpace.s1);
      final pill = tester.widget<Container>(
          find.descendant(of: find.byKey(const ValueKey('token:Family')), matching: find.byType(Container)).first);
      final deco = pill.decoration! as BoxDecoration;
      expect(deco.color, _kiwi.surfaceSunken);
      expect(deco.borderRadius, MyDataRadii.pill);
      final field = tester.getRect(find.ancestor(of: find.byKey(const ValueKey('token:Family')), matching: find.byType(Container)).last);
      expect(field.height, MyDataSize.controlHeight);
      expect(a.left - field.left, MyDataSpace.s1);
    });

    testWidgets('the field grows a line at a time up to four lines, then scrolls', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first, _Host(initial: [for (var i = 0; i < 30; i++) 'Group number $i'], width: 300)));
      final field = tester.getRect(find.byType(SingleChildScrollView));
      expect(field.height, closeTo(4 * MyDataSize.controlHeightCompact + 3 * MyDataSpace.s1 + 2 * (MyDataSpace.s1 - 1), 0.5));
    });

    testWidgets('invalid: danger-soft pill, alert icon, 2px danger border and the error; ring ink', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, const _Host(initial: ['ava@example.org', 'ben@example'], rule: true)));
      final bad = tester.widget<Container>(
          find.descendant(of: find.byKey(const ValueKey('token:ben@example')), matching: find.byType(Container)).first);
      expect((bad.decoration! as BoxDecoration).color, _kiwi.dangerSoft);
      expect(find.descendant(of: find.byKey(const ValueKey('token:ben@example')), matching: find.byIcon(Icons.error_outline_rounded)),
          findsOneWidget);
      expect(find.text('ben@example is not a complete address. It looks like name@example.org.'), findsOneWidget);
      await tester.tap(_typing);
      await tester.pump();
      final ring = tester.widgetList<FocusRing>(find.byType(FocusRing)).firstWhere((r) => r.visible);
      expect(ring.danger, isTrue);
    });

    testWidgets('semantics: a group with its label and count; tokens as options with Remove as an action',
        (tester) async {
      await _desktop(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: ['Family', 'Work'])));
      expect(find.bySemanticsLabel('Groups, 2 groups'), findsOneWidget);
      final token = tester.getSemantics(find.byKey(const ValueKey('token:Work')));
      expect(token.label, 'Work');
      expect(token.hint, contains('2 of 2'));
      expect(token.getSemanticsData().customSemanticsActionIds, isNotEmpty);
      handle.dispose();
    });

    testWidgets('disabled: 45%, tokens without ×, not focusable, the reason as help', (tester) async {
      await _desktop(tester);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          const SizedBox(
              width: 400,
              child: TokenField(
                  label: 'Groups',
                  values: ['Family'],
                  onChanged: null,
                  disabledReason: 'Groups from this Mac are changed in Contacts.'))));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.ancestor(of: find.text('Groups from this Mac are changed in Contacts.'), matching: find.byType(Opacity)),
          findsNothing);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus?.context?.widget is EditableText, isFalse);
    });

    testWidgets('hovering the × shows a surface circle', (tester) async {
      await _desktop(tester);
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.pumpWidget(themedFrame(themeMatrix.first, const _Host(initial: ['Family'])));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.byIcon(Icons.close_rounded)));
      addTearDown(mouse.removePointer);
      await tester.pump();
      final circle = tester.widget<Container>(
          find.ancestor(of: find.byIcon(Icons.close_rounded), matching: find.byType(Container)).first);
      expect((circle.decoration! as BoxDecoration).color, _kiwi.surface);
      expect(tester.getSize(find.ancestor(of: find.byIcon(Icons.close_rounded), matching: find.byType(Container)).first),
          const Size.square(MyDataSize.iconTile));
    });

    testWidgets('a tap just outside the × (in the field padding) still removes', (tester) async {
      await _desktop(tester);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(initial: const ['Family'], onChanged: changes.add)));
      final x = tester.getRect(find.byIcon(Icons.close_rounded));
      final circle = tester.getRect(find.ancestor(of: find.byIcon(Icons.close_rounded), matching: find.byType(Container)).first);
      await tester.tapAt(Offset(x.center.dx, circle.top - 3));
      await tester.pumpAndSettle();
      expect(changes.last, isEmpty);
    });

    testWidgets('on a phone the suggestions are rows under the field, inside the page', (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final changes = <List<String>>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _Host(onChanged: changes.add, width: 340)));
      await tester.tap(_typing);
      await tester.enterText(_typing, 'fam');
      await tester.pumpAndSettle();
      final row = find.text('Family');
      expect(row, findsOneWidget);
      expect(tester.getSize(find.ancestor(of: row, matching: find.byType(Container)).first).height, MyDataSize.rowHeight);
      expect(find.ancestor(of: row, matching: find.byType(TokenField)), findsOneWidget, reason: 'inside the field\'s column');
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(changes.last, ['Family']);
    });
  });
}
