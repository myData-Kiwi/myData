import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

TextEditingController _c([String text = '']) => TextEditingController(text: text);

void main() {
  // The caret would blink forever; draw it still.
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  late FocusNode focused;
  goldenMatrix(
    'text_field',
    () {
      focused = FocusNode();
      Widget cell(Widget w) => SizedBox(width: 260, child: w);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: MyDataSpace.s5, runSpacing: MyDataSpace.s5, children: [
          cell(MyDataTextField(
              label: 'Folder for your data',
              controller: _c('/Users/you/myData'),
              mono: true,
              help: 'Photos, mail and backups are stored here.')),
          cell(MyDataTextField(
              label: 'Host address',
              controller: _c('192.168.1'),
              mono: true,
              error: 'That address is incomplete. It looks like 192.168.1.20.')),
          cell(MyDataTextField(
              label: 'Device name', controller: _c(), placeholder: 'For example, Kitchen Mac')),
          cell(MyDataTextField(
              label: 'Your name', controller: _c('Rishita'), focusNode: focused, help: 'Shown on shared albums.')),
          cell(MyDataTextField(label: 'Password', controller: _c('kiwi-secret'), obscure: true)),
          cell(MyDataTextField(
              label: 'Mail server', controller: _c('imap.example.com'), enabled: false, help: 'Set by your host.')),
        ]),
        const SizedBox(height: MyDataSpace.s5),
        Wrap(spacing: MyDataSpace.s5, children: [
          cell(MyDataSearchField(controller: _c(), placeholder: 'Search contacts')),
          cell(MyDataSearchField(controller: _c('Patel'), placeholder: 'Search contacts')),
        ]),
      ]);
    },
    size: const Size(588, 460),
    before: (tester) async {
      focused.requestFocus();
      await tester.pump();
      // The test platform is Android, which shows a touch handle under the caret; a desktop app does not.
      tester.state<EditableTextState>(find.byWidgetPredicate((w) => w is EditableText && w.focusNode == focused))
          .hideToolbar();
      await tester.pump();
    },
  );

  // design/README.md "Focus and danger": a field in error keeps its red border, and its ring is `ink`.
  late FocusNode errorNode;
  goldenMatrix(
    'text_field_error_focus',
    () {
      errorNode = FocusNode();
      return SizedBox(
          width: 260,
          child: MyDataTextField(
              label: 'Host address',
              controller: _c('192.168.1'),
              mono: true,
              focusNode: errorNode,
              error: 'That address is incomplete. It looks like 192.168.1.20.'));
    },
    size: const Size(308, 180),
    before: (tester) async {
      errorNode.requestFocus();
      await tester.pump();
      tester.state<EditableTextState>(find.byWidgetPredicate((w) => w is EditableText && w.focusNode == errorNode))
          .hideToolbar();
      await tester.pump();
    },
  );

  testWidgets('focus ring: `focus` normally, `ink` while the field is in error', (tester) async {
    for (final error in [null, 'That address is incomplete.']) {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          SizedBox(width: 300, child: MyDataTextField(label: 'Host', controller: _c(), focusNode: node, error: error))));
      node.requestFocus();
      await tester.pump();
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
      expect(ring.danger, error != null);
      final c = themeMatrix.first.data.extension<MyDataColors>()!;
      expect(FocusRing.colourOf(c, danger: ring.danger), error == null ? c.focus : c.ink);
    }
  });

  testWidgets('typing reaches the controller and onChanged; Enter calls onSubmitted', (tester) async {
    final controller = _c();
    final changes = <String>[];
    String? submitted;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 300,
          child: MyDataTextField(
              label: 'Host address',
              controller: controller,
              onChanged: changes.add,
              onSubmitted: (v) => submitted = v),
        )));
    await tester.enterText(find.byType(EditableText), '192.168.1.20');
    expect(controller.text, '192.168.1.20');
    expect(changes.last, '192.168.1.20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, '192.168.1.20');
  });

  testWidgets('a tap anywhere in the 44px box focuses it, and focus shows the ring', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        SizedBox(width: 300, child: MyDataTextField(label: 'Your name', controller: _c(), focusNode: node))));
    final box = tester.getRect(find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    expect(box.height, MyDataSize.controlHeight);
    expect(find.byWidgetPredicate((w) => w is FocusRing && w.visible), findsNothing);
    // Near the right-hand edge and the bottom, well outside the text itself.
    await tester.tapAt(box.bottomRight - const Offset(4, 3));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    expect(find.byWidgetPredicate((w) => w is FocusRing && w.visible), findsOneWidget);
  });

  testWidgets('Tab moves focus from field to field', (tester) async {
    final a = FocusNode(), b = FocusNode();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 300,
          child: Column(children: [
            MyDataTextField(label: 'First name', controller: _c(), focusNode: a),
            MyDataTextField(label: 'Last name', controller: _c(), focusNode: b),
          ]),
        )));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(a.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(b.hasFocus, isTrue);
  });

  testWidgets('error: 2px danger border, the error replaces the help in danger', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 300,
          child: MyDataTextField(
              label: 'Host address',
              controller: _c('192.168.1'),
              help: 'The address of your host.',
              error: 'That address is incomplete. It looks like 192.168.1.20.'),
        )));
    final colors = MyDataColors.light;
    final box = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    final border = (box.decoration!.box).border! as Border;
    expect(border.top.width, 2);
    expect(border.top.color, colors.danger);
    expect(find.text('The address of your host.'), findsNothing);
    final note = tester.widget<Text>(find.text('That address is incomplete. It looks like 192.168.1.20.'));
    expect(note.style!.color, colors.danger);
    // The border grows inward: the box stays 44px.
    expect(tester.getSize(find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first).height,
        MyDataSize.controlHeight);
  });

  testWidgets('semantics: the label names the field, help is its hint, an error marks it invalid', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 300,
          child: Column(children: [
            MyDataTextField(
                label: 'Folder for your data', controller: _c(), help: 'Photos, mail and backups are stored here.'),
            MyDataTextField(label: 'Host address', controller: _c(), error: 'That address is incomplete.'),
          ]),
        )));
    final first = tester.getSemantics(find.byType(EditableText).first);
    expect(first.label, contains('Folder for your data'));
    expect(first.hint, contains('Photos, mail and backups are stored here.'));
    expect(first.flagsCollection.isTextField, isTrue);
    final second = tester.getSemantics(find.byType(EditableText).last);
    expect(second.label, contains('Host address'));
    expect(second.hint, contains('That address is incomplete.'));
    expect(second.validationResult, SemanticsValidationResult.invalid);
    handle.dispose();
  });

  testWidgets('disabled: label and box at 45% (the help is not faded), not focusable, no typing', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    final controller = _c('imap.example.com');
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
            width: 300,
            child: MyDataTextField(
                label: 'Mail server', controller: controller, enabled: false, focusNode: node, help: 'Set by your host.'))));
    for (final part in [find.text('Mail server'), find.byType(TextField)]) {
      expect(tester.widget<Opacity>(find.ancestor(of: part, matching: find.byType(Opacity)).first).opacity,
          Pressable.disabledOpacity);
    }
    // design/platforms.md "Disabled controls": only the control fades; the reason keeps full ink-muted.
    expect(find.ancestor(of: find.text('Set by your host.'), matching: find.byType(Opacity)), findsNothing);
    await tester.tap(find.byType(TextField), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(node.hasFocus, isFalse);
    expect(controller.text, 'imap.example.com');
  });

  testWidgets('mono uses the mono style, obscure hides the text', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
          width: 300,
          child: Column(children: [
            MyDataTextField(label: 'Folder for your data', controller: _c('/Users/you'), mono: true),
            MyDataTextField(label: 'Password', controller: _c('secret'), obscure: true),
          ]),
        )));
    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields[0].style.fontFamily, MyDataType.mono.fontFamily);
    expect(fields[0].obscureText, isFalse);
    expect(fields[1].style.fontFamily, MyDataType.body.fontFamily);
    expect(fields[1].obscureText, isTrue);
  });

  testWidgets('search field: pill on surface-sunken, no border, 44px, one target named by its placeholder', (tester) async {
    final handle = tester.ensureSemantics();
    final changes = <String>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        SizedBox(
            width: 300,
            child: MyDataSearchField(
                controller: _c(), placeholder: 'Search contacts', onChanged: changes.add, focusNode: node))));
    // Exactly one tappable node, the text field, named once by the placeholder (the icon adds none).
    void expectOneNamedTarget() {
      final tappable = find.semantics.byAction(SemanticsAction.tap);
      expect(tappable, findsOne);
      final target = tappable.evaluate().single;
      final data = target.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.label, 'Search contacts');
      expect(target, same(tester.getSemantics(find.byType(EditableText))));
    }

    final box = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    final deco = box.decoration!.box;
    expect(deco.color, MyDataColors.light.surfaceSunken);
    expect(deco.border, isNull);
    expect(deco.borderRadius, MyDataRadii.pill(kiwiLook));
    expect(tester.getSize(find.byType(MyDataSearchField)).height, MyDataSize.controlHeight);
    expectOneNamedTarget();

    // The icon is part of the target.
    await tester.tap(findIcon(MyDataIcon.search));
    await tester.pump();
    expect(node.hasFocus, isTrue);
    await tester.enterText(find.byType(EditableText), 'Patel');
    // Let the placeholder fade out of the tree: the name must not depend on it.
    await tester.pumpAndSettle();
    expect(changes.last, 'Patel');
    expectOneNamedTarget();
    expect(tester.getSemantics(find.byType(EditableText)).value, 'Patel');
    handle.dispose();
  });

  testWidgets('reduced motion and transparency change nothing: the field has no movement or glass', (tester) async {
    Future<Size> sizeWith(bool reduced) async {
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(width: 300, child: MyDataTextField(label: 'Your name', controller: _c(), help: 'Shown to others.')),
          reduceMotion: reduced,
          reduceTransparency: reduced));
      return tester.getSize(find.byType(MyDataTextField));
    }

    expect(await sizeWith(true), await sizeWith(false));
  });

  testWidgets('body at 16px under 600px, 15px from 600px; the multi-line field too', (tester) async {
    for (final (width, size) in [(390.0, PhoneType.bodySize), (800.0, MyDataType.body.fontSize)]) {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          SizedBox(
            width: 300,
            child: Column(children: [
              MyDataTextField(label: 'Your name', controller: _c('Ava')),
              MyDataTextField.multiline(label: 'Notes', controller: _c('Met at the book club.')),
            ]),
          )));
      for (final e in tester.widgetList<EditableText>(find.byType(EditableText))) {
        expect(e.style.fontSize, size, reason: '$width wide');
      }
    }
  });

  testWidgets('while its form waits for the host (FormBusy) it is read-only, focus kept', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    Widget field(bool busy) => themedFrame(
        themeMatrix.first,
        FormBusy(busy: busy, child: SizedBox(width: 300, child: MyDataTextField(label: 'Name', controller: _c('Ava'), focusNode: node))));
    await tester.pumpWidget(field(false));
    node.requestFocus();
    await tester.pump();
    await tester.pumpWidget(field(true));
    expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isTrue);
    expect(node.hasFocus, isTrue);
    await tester.pumpWidget(field(false));
    expect(tester.widget<EditableText>(find.byType(EditableText)).readOnly, isFalse);
  });
}
