import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _labels = ['Mobile', 'Home', 'Work', 'Other', 'Custom label…'];

/// A picker sheet of phone labels, Home chosen; a tap pops the label.
Widget _labelPicker(BuildContext context, {FocusNode? chosenNode}) => Sheet(
      kind: SheetKind.picker,
      title: 'Label for phone 1',
      body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in _labels)
          SheetPickerRow(
            label: l,
            chosen: l == 'Home',
            focusNode: l == 'Home' ? chosenNode : null,
            onPressed: () => Navigator.of(context).pop(l),
          ),
      ]),
      initialFocus: chosenNode,
      scrollable: false,
    );

/// An editor sheet with one field; [pending] says whether it has changes.
Widget _editor({required bool pending, FocusNode? field, VoidCallback? onCancel, bool busy = false}) => Sheet(
      kind: SheetKind.editor,
      title: 'Edit contact',
      pending: pending,
      busy: busy,
      discardMessage: 'Your changes to Ava Fictional are not saved.',
      onCancel: onCancel,
      trailing: Button(label: Sheet.saveLabel, variant: ButtonVariant.filled, onPressed: () {}),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyDataTextField(
            label: 'First name',
            controller: TextEditingController(text: 'Ava')..selection = const TextSelection.collapsed(offset: 3),
            focusNode: field),
        const SizedBox(height: MyDataSpace.s4),
        MyDataTextField(label: 'Last name', controller: TextEditingController(text: 'Fictional')),
      ]),
    );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 667);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A page whose "Open" button shows [sheet]; the popped values land in [results].
Widget _opener(WidgetBuilder sheet, List<Object?> results, {FocusNode? node}) => Builder(
      builder: (context) => Button(
        label: 'Open',
        focusNode: node,
        onPressed: () async => results.add(await showSheet<Object?>(context: context, builder: sheet)),
      ),
    );

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  // A picker sheet stacked on an editor sheet: the second scrim, `surface-raised` over `surface`, the check
  // mark on the chosen row.
  goldenMatrix('sheet_picker', () => const SizedBox(width: 327, height: 600), size: const Size(375, 667),
      before: (tester) async {
    final context = tester.element(find.byType(SizedBox).first);
    unawaited(showSheet<void>(context: context, builder: (_) => _editor(pending: false)));
    await tester.pumpAndSettle();
    unawaited(showSheet<String>(context: tester.element(find.text('First name')), builder: _labelPicker));
    await tester.pumpAndSettle();
  });

  group('Sheet', () {
    testWidgets('Cancel, the scrim, Escape and back each leave a sheet without changes', (tester) async {
      await _phone(tester);
      final results = <Object?>[];
      var cancels = 0;
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: false, onCancel: () => cancels++), results)));
      Future<void> leave(Future<void> Function() how) async {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Edit contact'), findsOneWidget);
        await how();
        await tester.pumpAndSettle();
        expect(find.text('Edit contact'), findsNothing);
      }

      await leave(() => tester.tap(find.text(Sheet.cancelLabel)));
      await leave(() => tester.tapAt(const Offset(187, 4)));
      await leave(() => tester.sendKeyEvent(LogicalKeyboardKey.escape));
      await leave(() async => tester.binding.handlePopRoute());
      expect(cancels, 4);
      expect(results, [null, null, null, null]);
    });

    testWidgets('with changes it asks first: Keep editing stays, Discard changes leaves', (tester) async {
      await _phone(tester);
      var cancels = 0;
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: true, onCancel: () => cancels++), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(187, 4));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      expect(cancels, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget, reason: 'back asks too');
      await tester.tap(find.text(discardLabel));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing);
      expect(cancels, 1);
    });

    testWidgets('a drag past a third of its height leaves; a short one springs back', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: false), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Edit contact')).dy;
      await tester.drag(find.text('Edit contact'), const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Edit contact')).dy, closeTo(top, 0.5));
      await tester.drag(find.text('Edit contact'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing);
    });

    testWidgets('with changes a drag resists at space-8, springs back, and asks', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: true), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Edit contact')).dy;
      final drag = await tester.startGesture(tester.getCenter(find.text('Edit contact')));
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(0, 30));
      }
      await tester.pump();
      expect(tester.getTopLeft(find.text('Edit contact')).dy - top, lessThanOrEqualTo(Sheet.resistance(kiwiLook) + 0.5));
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsOneWidget);
      expect(tester.getTopLeft(find.text('Edit contact')).dy, closeTo(top, 0.5));
    });

    testWidgets('with changes, a drag up or a short drag only springs back; it does not ask', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: true), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(find.text('Edit contact')).dy;
      await tester.drag(find.text('Edit contact'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsNothing);
      await tester.timedDrag(find.text('Edit contact'), const Offset(0, 6), const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(discardTitle), findsNothing);
      expect(tester.getTopLeft(find.text('Edit contact')).dy, closeTo(top, 0.5));
    });

    testWidgets('busy: Cancel is inert and nothing closes it', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: false, busy: true), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Sheet.cancelLabel));
      await tester.tapAt(const Offset(187, 4));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
    });

    testWidgets('focus: the first field on opening, the chosen row in a picker, back to the opener after',
        (tester) async {
      await _phone(tester);
      final field = FocusNode();
      final opener = FocusNode();
      final chosen = FocusNode();
      addTearDown(field.dispose);
      addTearDown(opener.dispose);
      addTearDown(chosen.dispose);
      final results = <Object?>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, Column(children: [
        _opener((_) => _editor(pending: false, field: field), results, node: opener),
        Builder(builder: (context) => Button(
            label: 'Pick', onPressed: () async => results.add(
                await showSheet<String>(context: context, builder: (c) => _labelPicker(c, chosenNode: chosen))))),
      ])));
      opener.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(field.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(opener.hasFocus, isTrue);

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(chosen.hasFocus, isTrue);
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(results, [null, 'Work']);
    });

    testWidgets('shape: the editor leaves space-3 under the status bar; the picker is as tall as its rows',
        (tester) async {
      await _phone(tester);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: false), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final editor = find.ancestor(of: find.text('Edit contact'), matching: find.byType(Container)).last;
      expect(tester.getTopLeft(editor).dy, Sheet.topGap(kiwiLook));
      expect(tester.getBottomLeft(editor).dy, 667);
      final c = tester.element(editor).colors;
      expect((tester.widget<Container>(editor).decoration!.box).color, c.surface);
      await tester.tap(find.text(Sheet.cancelLabel));
      await tester.pumpAndSettle();

      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener(_labelPicker, [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final picker = find.ancestor(of: find.text('Label for phone 1'), matching: find.byType(Container)).last;
      expect((tester.widget<Container>(picker).decoration!.box).color, c.surfaceRaised);
      expect(tester.getSize(picker).height, lessThan(667 / 2 + _labels.length * MyDataSize.rowHeight));
      expect(tester.getSize(find.ancestor(of: find.text('Work'), matching: find.byType(Container)).first).height,
          MyDataSize.rowHeight);
    });

    testWidgets('semantics: a modal dialog named by its title, dismissed as Cancel', (tester) async {
      await _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _editor(pending: false), [])));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final finder = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.scopesRoute == true && w.properties.label == 'Edit contact');
      final node = tester.getSemantics(finder);
      expect(node.flagsCollection.namesRoute, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.dismiss);
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsNothing);
      handle.dispose();
    });
  });
}
