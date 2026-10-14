import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

TextEditingController _c([String text = '']) => TextEditingController(text: text);

final _line = MyDataType.body.fontSize! * MyDataType.body.height!;

/// The box around the text: three lines and `space-3` down at rest.
Rect _box(WidgetTester tester) =>
    tester.getRect(find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  late FocusNode focused;
  goldenMatrix(
    'text_field_multiline',
    () {
      focused = FocusNode();
      Widget cell(Widget w) => SizedBox(width: 260, child: w);
      return Wrap(spacing: MyDataSpace.s5, runSpacing: MyDataSpace.s5, children: [
        cell(MyDataTextField.multiline(label: 'Notes', controller: _c(), placeholder: 'Add notes')),
        cell(MyDataTextField.multiline(
            label: 'Notes',
            controller: _c('Met Ava Fictional at the book club.\nBrings the good biscuits.\nAsk about the garden.'
                '\nPrefers email to calls.'),
            focusNode: focused,
            help: 'Only you can see these notes.')),
        cell(MyDataTextField.multiline(
            label: 'Description', controller: _c('Too long.'), error: 'Descriptions can be 10 characters at most.')),
        cell(MyDataTextField.multiline(
            label: 'Notes', controller: _c('Read from This Mac.'), enabled: false, help: 'This Mac never reads notes.')),
      ]);
    },
    size: const Size(588, 470),
    before: (tester) async {
      focused.requestFocus();
      await tester.pump();
      tester.state<EditableTextState>(find.byWidgetPredicate((w) => w is EditableText && w.focusNode == focused))
          .hideToolbar();
      await tester.pump();
    },
  );

  testWidgets('it starts three lines tall with space-3 down, and never shrinks below that', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first, SizedBox(width: 300, child: MyDataTextField.multiline(label: 'Notes', controller: _c()))));
    expect(_box(tester).height, closeTo(3 * _line + 2 * MyDataSpace.s3, 0.5));
    final text = tester.getRect(find.byType(EditableText));
    expect(text.top - _box(tester).top, closeTo(MyDataSpace.s3, 0.5));
    expect(text.left - _box(tester).left, closeTo(MyDataSpace.s4, 0.5));
  });

  testWidgets('it grows a line at a time, at once, up to twelve lines, then scrolls inside', (tester) async {
    final controller = _c();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        SizedBox(width: 300, child: MyDataTextField.multiline(label: 'Notes', controller: controller))));
    controller.text = List.filled(5, 'line').join('\n');
    await tester.pump();
    expect(_box(tester).height, closeTo(5 * _line + 2 * MyDataSpace.s3, 0.5));
    controller.text = List.filled(30, 'line').join('\n');
    await tester.pump();
    expect(_box(tester).height, closeTo(MyDataTextField.maxLines * _line + 2 * MyDataSpace.s3, 0.5));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.maxLines, MyDataTextField.maxLines);
    expect(editable.minLines, MyDataTextField.minLines);
  });

  testWidgets('Return inserts a new line; Tab moves on; ⌘Return reaches the holder', (tester) async {
    final controller = _c();
    final next = FocusNode();
    addTearDown(next.dispose);
    var saved = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter, meta: true): () => saved++},
          child: SizedBox(
            width: 300,
            child: Column(children: [
              MyDataTextField.multiline(label: 'Notes', controller: controller),
              MyDataTextField(label: 'After', controller: _c(), focusNode: next),
            ]),
          ),
        )));
    final editable = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(editable.keyboardType, TextInputType.multiline);
    expect(editable.textInputAction, TextInputAction.newline);
    await tester.tap(find.byType(EditableText).first);
    await tester.enterText(find.byType(EditableText).first, 'one');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(saved, 1);
    expect(controller.text, 'one');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(next.hasFocus, isTrue);
    expect(controller.text, 'one');
  });

  testWidgets('error: 2px danger border, the error replaces the help; focus ring ink', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
            width: 300,
            child: MyDataTextField.multiline(
                label: 'Notes', controller: _c(), focusNode: node, help: 'Help.', error: 'Too long.'))));
    node.requestFocus();
    await tester.pump();
    final border = ((tester.widget<Container>(
                find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first))
            .decoration! as BoxDecoration)
        .border! as Border;
    expect(border.top.width, MyDataTextField.errorBorderWidth);
    expect(find.text('Help.'), findsNothing);
    expect(tester.widget<FocusRing>(find.byType(FocusRing)).danger, isTrue);
    // The text does not move when the border grows inward.
    expect(_box(tester).height, closeTo(3 * _line + 2 * MyDataSpace.s3, 0.5));
  });

  testWidgets('semantics: a multi-line text field with its label and its help as hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        SizedBox(width: 300, child: MyDataTextField.multiline(label: 'Notes', controller: _c(), help: 'Only you.'))));
    final node = tester.getSemantics(find.byType(EditableText));
    expect(node.label, contains('Notes'));
    expect(node.hint, contains('Only you.'));
    expect(node.flagsCollection.isTextField, isTrue);
    expect(node.flagsCollection.isMultiline, isTrue);
    handle.dispose();
  });
}
