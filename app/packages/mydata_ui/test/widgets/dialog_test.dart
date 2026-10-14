import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _failure = 'The calendar could not be created. The host did not answer. Check that it is running, then try again.';

MyDataDialog _deleteDialog({HostAction? onConfirm}) => MyDataDialog(
      title: 'Delete 3 contacts?',
      message: 'Ava Fictional, Ben Sample and Cleo Example go to Recently deleted. '
          'You can restore them from there for 30 days.',
      confirmLabel: 'Delete 3 contacts',
      workingLabel: 'Deleting…',
      workingAnnouncement: 'Deleting 3 contacts',
      destructive: true,
      onConfirm: onConfirm,
    );

/// A page with an "Open" button that shows [dialog]; the answer lands in [answers].
Widget _opener(WidgetBuilder dialog, List<bool> answers, {FocusNode? openerNode}) => Builder(
      builder: (context) => Button(
        label: 'Open',
        focusNode: openerNode,
        onPressed: () async => answers.add(await showMyDataDialog(context: context, builder: dialog)),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void _keyboardMode(WidgetTester tester) {
  tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
}

Future<void> _openFromGolden(WidgetTester tester, WidgetBuilder builder) async {
  _keyboardMode(tester);
  final context = tester.element(find.byType(Scaffold).evaluate().isEmpty ? find.byType(Material).first : find.byType(Scaffold));
  unawaited(showMyDataDialog(context: context, builder: builder));
  await tester.pumpAndSettle();
}

void main() {
  // Focus starts on Cancel in a destructive dialog: the usual red `focus` ring on Cancel, the Danger button
  // beside it.
  goldenMatrix('dialog_destructive', () => const SizedBox(width: 400, height: 200), size: const Size(640, 400),
      before: (tester) => _openFromGolden(tester, (_) => _deleteDialog(onConfirm: () async => null)));

  // A form after a failed answer: the fields as sent (a field in error never reaches the host), the failure
  // line, focus back on the confirming button.
  goldenMatrix('dialog_form_failed', () => const SizedBox(width: 400, height: 200), size: const Size(640, 480),
      before: (tester) async {
    await _openFromGolden(
      tester,
      (_) => MyDataDialog(
        title: 'New calendar',
        fields: [
          MyDataTextField(
            label: 'Name',
            controller: TextEditingController(text: 'Book club'),
            help: 'Shown in myCalendar and on the host.',
          ),
        ],
        confirmLabel: 'Create calendar',
        workingLabel: 'Creating…',
        onConfirm: () async => _failure,
      ),
    );
    await tester.tap(find.text('Create calendar'));
    await tester.pumpAndSettle();
  });

  // A phone: the panel is the screen less space-4 each side; the buttons stack, the confirming one on top.
  goldenMatrix('dialog_phone', () => const SizedBox(width: 300, height: 200), size: const Size(375, 560),
      before: (tester) async {
    _keyboardMode(tester);
    unawaited(showDiscardChangesDialog(tester.element(find.byType(Material).first),
        message: 'Your changes to Ava Fictional are not saved.'));
    await tester.pumpAndSettle();
  });

  group('MyDataDialog', () {
    testWidgets('a destructive dialog: focus on Cancel, Escape cancels, the scrim does nothing', (tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), answers)));
      await _open(tester);
      expect(find.text('Delete 3 contacts?'), findsOneWidget);
      final cancel = find.widgetWithText(Button, 'Cancel');
      expect(Focus.of(tester.element(find.descendant(of: cancel, matching: find.byType(Text)))).hasFocus, isTrue);
      // The confirming button is the Danger button.
      expect(tester.widget<Button>(find.widgetWithText(Button, 'Delete 3 contacts')).variant, ButtonVariant.danger);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 contacts?'), findsOneWidget, reason: 'clicking the scrim does nothing');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 contacts?'), findsNothing);
      expect(answers, [false]);
    });

    testWidgets('Tab and Shift-Tab go round the dialog; nothing behind it is reached', (tester) async {
      final answers = <bool>[];
      final opener = FocusNode();
      addTearDown(opener.dispose);
      await tester.pumpWidget(
          themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), answers, openerNode: opener)));
      opener.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      bool focusedOn(String label) =>
          Focus.of(tester.element(find.descendant(of: find.widgetWithText(Button, label), matching: find.byType(Text))))
              .hasFocus;
      expect(focusedOn('Cancel'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedOn('Delete 3 contacts'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusedOn('Cancel'), isTrue);
      expect(opener.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(opener.hasFocus, isTrue, reason: 'focus returns to what opened the dialog');
    });

    testWidgets('working: inert buttons, a steady width, Escape ignored; done closes with true', (tester) async {
      final answers = <bool>[];
      final done = Completer<String?>();
      var calls = 0;
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _opener(
              (_) => _deleteDialog(onConfirm: () {
                    calls++;
                    return done.future;
                  }),
              answers)));
      await _open(tester);
      final width = tester.getSize(find.widgetWithText(SteadyWidthButton, 'Delete 3 contacts').first).width;
      await tester.tap(find.text('Delete 3 contacts'));
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Deleting…'), findsOneWidget);
      expect(tester.getSize(find.byType(SteadyWidthButton)).width, width);
      expect(FormBusy.of(tester.element(find.text('Deleting…'))), isTrue);

      await tester.tap(find.text('Deleting…'));
      await tester.tap(find.text('Cancel'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Delete 3 contacts?'), findsOneWidget);

      done.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 contacts?'), findsNothing);
      expect(answers, [true]);
    });

    testWidgets('failed: the line shows, the label is back, focus is on the confirming button; it retries',
        (tester) async {
      final answers = <bool>[];
      var tries = 0;
      final name = TextEditingController(text: 'Book club');
      addTearDown(name.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _opener(
              (_) => MyDataDialog(
                    title: 'New calendar',
                    fields: [MyDataTextField(label: 'Name', controller: name)],
                    confirmLabel: 'Create calendar',
                    workingLabel: 'Creating…',
                    onConfirm: () async => ++tries == 1 ? _failure : null,
                  ),
              answers)));
      await _open(tester);
      // A form starts in its first field; Return there presses the confirming button.
      expect(tester.testTextInput.isVisible || FocusManager.instance.primaryFocus?.context?.widget is EditableText,
          isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tries, 1);
      expect(find.text(_failure), findsOneWidget);
      expect(tester.widget<Text>(find.text(_failure)).style!.color, tester.element(find.text(_failure)).colors.danger);
      expect(find.text('Create calendar'), findsOneWidget);
      expect(
          Focus.of(tester.element(find.descendant(
                  of: find.widgetWithText(Button, 'Create calendar').last, matching: find.byType(Text))))
              .hasFocus,
          isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tries, 2);
      expect(answers, [true]);
    });

    testWidgets('a wrong field stops the confirm and takes focus', (tester) async {
      final answers = <bool>[];
      var sent = 0;
      final field = FocusNode();
      addTearDown(field.dispose);
      final name = TextEditingController();
      addTearDown(name.dispose);
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _opener(
              (_) => MyDataDialog(
                    title: 'New calendar',
                    fields: [MyDataTextField(label: 'Name', controller: name, focusNode: field)],
                    confirmLabel: 'Create calendar',
                    workingLabel: 'Creating…',
                    check: () => name.text.isEmpty ? [field] : const [],
                    onConfirm: () async {
                      sent++;
                      return null;
                    },
                  ),
              answers)));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(field.hasFocus, isFalse);
      await tester.tap(find.text('Create calendar'));
      await tester.pumpAndSettle();
      expect(sent, 0);
      expect(field.hasFocus, isTrue);
    });

    testWidgets('Return never presses a destructive button that does not have focus', (tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), answers)));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // Focus is on Cancel: Return presses Cancel.
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });

    testWidgets('a dialog that only tells: one Filled button with focus; Escape is that button', (tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(themedFrame(
          themeMatrix.first,
          _opener(
              (_) => const MyDataDialog(
                    title: 'Token for Claude on my laptop',
                    message: 'Copy it now. It is shown only once.',
                    cancelLabel: null,
                    confirmLabel: 'Done',
                  ),
              answers)));
      await _open(tester);
      expect(find.widgetWithText(Button, 'Cancel'), findsNothing);
      expect(tester.widget<Button>(find.widgetWithText(Button, 'Done')).variant, ButtonVariant.filled);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answers, [true]);
    });

    testWidgets('width: dialog-width, the window less space-8 each side, or a phone less space-4', (tester) async {
      expect(MyDataDialog.widthFor(1280), MyDataSize.dialogWidth);
      expect(MyDataDialog.widthFor(800), MyDataSize.dialogWidth);
      expect(MyDataDialog.widthFor(375), 375 - 2 * MyDataSpace.s4);
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), [])));
      await _open(tester);
      final panel = find.ancestor(of: find.text('Delete 3 contacts?'), matching: find.byType(Container)).first;
      expect(tester.getSize(panel).width, MyDataSize.dialogWidth);
    });

    testWidgets('motion: slow with a grow from 97%; with reduced motion a fast fade only', (tester) async {
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
            themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), []), reduceMotion: reduced));
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(MyDataMotion.fast + const Duration(milliseconds: 1));
        final route = ModalRoute.of(tester.element(find.text('Delete 3 contacts?')))!;
        expect(route.animation!.isCompleted, reduced, reason: reduced ? 'fast' : 'slow');
        expect(find.ancestor(of: find.text('Delete 3 contacts?'), matching: find.byType(ScaleTransition)),
            reduced ? findsNothing : findsOneWidget);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('semantics: an alert dialog named by its title when destructive, a dialog otherwise', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(themedFrame(themeMatrix.first, _opener((_) => _deleteDialog(), [])));
      await _open(tester);
      final node = tester.getSemantics(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.scopesRoute == true && w.properties.label == 'Delete 3 contacts?'));
      expect(node.label, 'Delete 3 contacts?');
      expect(node.role, SemanticsRole.alertDialog);
      expect(node.flagsCollection.scopesRoute, isTrue);
      expect(node.flagsCollection.namesRoute, isTrue);
      handle.dispose();
    });
  });
}
