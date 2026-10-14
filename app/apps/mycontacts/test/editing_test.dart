// Editing in myContacts against a fake host that behaves as the real one does (etags, undo, Recently
// deleted): create, edit, the changed-elsewhere refusal, field errors, delete with Undo, several at once,
// Recently deleted, read-only followed contacts, and the menu bar. Invented data only.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_actions.dart';
import 'package:mycontacts/src/contact_editor.dart';
import 'package:mycontacts/src/contact_form.dart';
import 'package:mycontacts/src/contact_page.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mycontacts/src/trash_view.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

void desktop(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pip, whom the host owns, among the sample contacts, which are followed; Pip opens first.
FakeBackend ownedBackend({List<ContactDetailOut> more = const []}) {
  final cards = sampleCards();
  // After Omar Sample, before Sam Sample (the lazy list builds the rows near Pip, who opens first).
  cards.insertAll(cards.indexWhere((c) => c.id == 'c-sam'), [...more, pipOwned()]);
  return FakeBackend(cards: cards);
}

Widget app(FakeBackend backend, {String? lastOpened = 'c-pip', TargetPlatform? menu}) => MyContactsApp(
      host: FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus()),
      store: MemoryDeviceStore({ContactsController.lastOpenedKey: ?lastOpened}),
      backend: backend,
      links: const Stream.empty(),
      onOpenLink: (_) {},
      menuPlatform: menu,
    );

Finder headerName(String name) => find.descendant(of: find.byType(ContactHeader), matching: find.text(name));
Finder row(String name) => find.descendant(of: find.byType(ContactList), matching: find.text(name));
Finder field(String label) => find.byWidgetPredicate((w) => w is MyDataTextField && w.label == label);
Finder inInspector(Finder f) => find.descendant(of: find.byType(Inspector), matching: f);
Finder toast(String text) => find.descendant(of: find.byType(ToastHost), matching: find.text(text));

/// Taps [f] after scrolling it into view (the inspector's body scrolls).
Future<void> tapIn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(field(label), text);
  await tester.pump();
}

/// Lets the toast's 8 s run out, so no timer is left when the test ends.
Future<void> outlastToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 9));
  await tester.pumpAndSettle();
}

Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  group('new contact', () {
    testWidgets('New contact opens the inspector in the pane; Save adds it, with an Undo toast', (tester) async {
      desktop(tester);
      final backend = FakeBackend();
      await tester.pumpWidget(app(backend, lastOpened: 'c-ava'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      expect(find.byType(Inspector), findsOneWidget);
      expect(inInspector(find.text('New contact')), findsOneWidget);
      expect(find.byType(ContactList), findsOneWidget, reason: 'the list stays beside it');
      expect(find.byType(ContactHeader), findsNothing, reason: 'the inspector takes the contact pane\'s place');
      // The first field has focus.
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<MyDataTextField>()?.label,
          'First name');

      await enter(tester, 'First name', 'Nia');
      await enter(tester, 'Last name', 'Newcomb');
      await tapIn(tester, find.text('Add phone'));
      await tester.enterText(field('Mobile, phone number'), '+1 555 0177');
      await tester.pump();
      await tapIn(tester, find.text('Add email'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(backend.writes, ['create c-new-1']);
      final sent = backend.forms.single;
      expect(sent.givenName, 'Nia');
      expect(sent.phones!.single.label, 'Mobile');
      expect(sent.emails!.single.value, '', reason: 'the empty email row is sent and dropped by the host');
      expect(find.byType(Inspector), findsNothing);
      expect(headerName('Nia Newcomb'), findsOneWidget);
      expect(find.text(ContactPage.ownedLine), findsOneWidget);
      expect(row('Nia Newcomb'), findsOneWidget);
      expect(toast('Contact added'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(backend.writes.last, 'undo u-1');
      expect(toast(ContactsController.addUndone), findsOneWidget);
      expect(row('Nia Newcomb'), findsNothing);
      await outlastToast(tester);
    });

    testWidgets('a contact needs a name, a company, a phone or an email: said once, nothing sent', (tester) async {
      desktop(tester);
      final backend = FakeBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'Notes'), 'Only notes');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(ContactDraft.formRuleText), findsOneWidget);
      expect(backend.writes, isEmpty);
      expect(find.byType(Inspector), findsOneWidget);
    });

    testWidgets('an email that is incomplete: its error on leaving the field, and Save sends nothing', (tester) async {
      desktop(tester);
      final backend = FakeBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      await enter(tester, 'First name', 'Nia');
      await tapIn(tester, find.text('Add email'));
      await tester.enterText(field('Home, email address'), 'nia@example');
      await tester.pump();
      expect(find.text(emailError), findsNothing, reason: 'never while it is first being typed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(emailError), findsOneWidget);
      expect(backend.writes, isEmpty);
      await tester.enterText(field('Home, email address'), 'nia@example.org');
      await tester.pump();
      expect(find.text(emailError), findsNothing, reason: 'the error goes as soon as the value is right');
    });

    testWidgets('a field the host refuses shows its error on the field, in the app\'s words', (tester) async {
      desktop(tester);
      final backend = FakeBackend()..nextFieldErrors = {'phones[0].value': 'Not a phone number.'};
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      await enter(tester, 'First name', 'Nia');
      await tapIn(tester, find.text('Add phone'));
      await tester.enterText(field('Mobile, phone number'), '555 0177');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(phoneError), findsOneWidget);
      expect(find.text(ContactEditor.fieldsWrong('Nia', 1)), findsOneWidget);
      expect(find.byType(Inspector), findsOneWidget);
      expect(find.text('Not a phone number.'), findsNothing, reason: 'the host\'s words are never shown');
    });

    testWidgets('the host not answering: the failure line, the changes kept, and Save tries again', (tester) async {
      desktop(tester);
      final backend = FakeBackend()..failWrites = true;
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      await enter(tester, 'First name', 'Nia');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(ContactEditor.noAnswer('Nia')), findsOneWidget);
      backend.failWrites = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.writes, ['create c-new-1']);
      await outlastToast(tester);
    });
  });

  group('edit', () {
    testWidgets('Edit beside the header; Save sends the whole form with the etag; Undo takes it back',
        (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      expect(headerName('Pip Owned'), findsOneWidget);
      expect(find.text(ContactPage.ownedLine), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      expect(inInspector(find.text('Edit contact')), findsOneWidget);
      expect(find.widgetWithText(MyDataTextField, 'Pip'), findsOneWidget);
      expect(find.text('9 March'), findsOneWidget, reason: 'the birthday without a year');

      await enter(tester, 'Job title', 'Head archivist');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.writes, ['update c-pip']);
      expect(backend.etagsSent, ['"3-c-pip"']);
      final sent = backend.forms.single;
      expect(sent.jobTitle, 'Head archivist');
      expect(sent.middleName, 'Quinn', reason: 'fields not in the form are sent as loaded');
      expect(sent.nickname, 'Pipster');
      expect(sent.birthday, '--03-09');
      expect(find.text('Head archivist, Example Library'), findsOneWidget);
      expect(toast('Changes saved'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(toast('Changes undone'), findsOneWidget);
      expect(find.text('Archivist, Example Library'), findsOneWidget);
      await outlastToast(tester);
    });

    testWidgets('changed elsewhere since it opened: nothing is overwritten; Reload shows the other change',
        (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      backend.changeElsewhere('c-pip', jobTitle: 'Curator');
      await enter(tester, 'Job title', 'Head archivist');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.writes, isEmpty, reason: 'the host refused: nothing written');
      expect(find.text(ContactEditor.changedElsewhere('Pip Owned')), findsOneWidget);
      expect(find.widgetWithText(MyDataTextField, 'Head archivist'), findsOneWidget, reason: 'the changes stay');
      await tester.tap(find.widgetWithText(Button, ContactEditor.reloadLabel));
      await tester.pumpAndSettle();
      expect(find.byType(Inspector), findsOneWidget);
      expect(find.widgetWithText(MyDataTextField, 'Curator'), findsOneWidget);
      expect(find.text(ContactEditor.changedElsewhere('Pip Owned')), findsNothing);
      await enter(tester, 'Job title', 'Head curator');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.writes, ['update c-pip']);
      expect(backend.etagsSent.last, '"4-c-pip"');
      await outlastToast(tester);
    });

    testWidgets('choosing another contact with changes asks first: Keep editing stays, Discard leaves',
        (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      await enter(tester, 'Job title', 'Head archivist');
      await tapIn(tester, row('Omar Sample'));
      expect(find.text(discardTitle), findsOneWidget);
      expect(find.text('Your changes to Pip Owned are not saved.'), findsOneWidget);
      await tester.tap(find.text(keepEditingLabel));
      await tester.pumpAndSettle();
      expect(find.byType(Inspector), findsOneWidget);
      expect(find.widgetWithText(MyDataTextField, 'Head archivist'), findsOneWidget);
      await tapIn(tester, row('Omar Sample'));
      await tester.tap(find.text(discardLabel));
      await tester.pumpAndSettle();
      expect(find.byType(Inspector), findsNothing);
      expect(headerName('Omar Sample'), findsOneWidget);
      expect(backend.writes, isEmpty);
    });

    testWidgets('rows: Add phone takes the next label; remove asks nothing; Cancel brings it back', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      await tapIn(tester, find.text('Add phone'));
      expect(field('Home, phone number'), findsOneWidget, reason: 'Mobile is taken: Home is next');
      await tapIn(tester, find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'Remove mobile number'));
      expect(field('Mobile, phone number'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(discardLabel));
      await tester.pumpAndSettle();
      expect(find.byType(Inspector), findsNothing);
      expect(find.text('555-0142'), findsOneWidget, reason: 'nothing was removed on the host');
      expect(backend.writes, isEmpty);
    });

    testWidgets('remove the birthday, then save: it is cleared', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      await tapIn(tester, find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'Remove birthday'));
      expect(find.text(ContactEditor.addBirthdayLabel), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.forms.single.birthday, '');
      await outlastToast(tester);
    });
  });

  group('delete', () {
    testWidgets('the Delete key on the list deletes the open contact at once, with Undo', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(row('Pip Owned'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.byType(MyDataDialog), findsNothing, reason: 'one contact: no dialog');
      expect(backend.writes, ['delete c-pip']);
      expect(backend.etagsSent, ['"3-c-pip"']);
      expect(toast('Contact deleted'), findsOneWidget);
      expect(row('Pip Owned'), findsNothing);
      expect(headerName('Sam Sample'), findsOneWidget, reason: 'the row now in its place opens');

      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(toast('Contact restored'), findsOneWidget);
      expect(row('Pip Owned'), findsOneWidget);
      await outlastToast(tester);
    });

    testWidgets('More actions beside Edit: Delete contact', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MoreActionsButton));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      await tester.tap(find.text('Delete contact'));
      await tester.pumpAndSettle();
      expect(backend.writes, ['delete c-pip']);
      await outlastToast(tester);
    });

    testWidgets('several selected: the count in the pane, followed ones counted out, and the Dialog',
        (tester) async {
      desktop(tester);
      final backend = ownedBackend(more: [
        ownedCard('c-quinn', ContactIn(givenName: 'Quinn', familyName: 'Owned', emails: [
          LabeledValueIn(label: 'Home', value: 'quinn@example.org'),
        ])),
      ]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(row('Pip Owned'));
      await tester.pumpAndSettle();
      for (final name in ['Quinn Owned', 'Omar Sample']) {
        await tester.ensureVisible(row(name));
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(row(name));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }
      expect(find.text('3 contacts selected'), findsOneWidget);
      expect(find.text('Omar Sample, Quinn Owned and Pip Owned'), findsOneWidget);
      expect(find.text('1 of them is from this Mac and is changed in Contacts.'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, 'Delete 2 contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 contacts?'), findsOneWidget);
      expect(find.textContaining('Quinn Owned and Pip Owned go to Recently deleted'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(MyDataDialog), matching: find.text('Delete 2 contacts')));
      await tester.pumpAndSettle();
      expect(backend.writes, ['delete c-quinn', 'delete c-pip']);
      expect(toast('2 contacts deleted'), findsOneWidget);
      expect(row('Omar Sample'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(toast('2 contacts restored'), findsOneWidget);
      expect(row('Pip Owned'), findsOneWidget);
      expect(row('Quinn Owned'), findsOneWidget);
      await outlastToast(tester);
    });

    testWidgets('Undo refused after a later change: the toast says so', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
      await tester.pumpAndSettle();
      await enter(tester, 'Job title', 'Head archivist');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      backend.changeElsewhere('c-pip');
      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(toast('Not undone. Pip Owned was changed after that.'), findsOneWidget);
      await outlastToast(tester);
    });
  });

  group('followed contacts stay read-only', () {
    testWidgets('no Edit, the source line; the Menu\'s Edit and Delete are disabled with the reason',
        (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend, lastOpened: 'c-aaron'));
      await tester.pumpAndSettle();
      expect(headerName('Aaron Example'), findsOneWidget);
      expect(find.text('From this Mac. Change it in Contacts.'), findsOneWidget);
      expect(find.widgetWithText(Button, ContactActions.editButton), findsNothing);
      expect(find.byType(MoreActionsButton), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      await mouse.down(tester.getCenter(row('Aaron Example')));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text(ContactActions.fromMacReason), findsOneWidget);
      await tester.tap(find.text('Delete contact'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(row('Aaron Example'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(backend.writes, isEmpty);
    });
  });

  group('Recently deleted', () {
    testWidgets('restore with Undo, and delete permanently after a Dialog naming the backups', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(row('Pip Owned'));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deleted'));
      await tester.pumpAndSettle();
      expect(find.text(TrashView.title), findsOneWidget);
      expect(find.text('Deleted on 14 October 2026. It is deleted for good on 13 November 2026, unless you '
          'restore it.'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, TrashView.restoreLabel));
      await tester.pumpAndSettle();
      expect(backend.writes.last, 'restore c-pip');
      expect(toast('Contact restored'), findsOneWidget);
      expect(find.text(TrashView.emptyTitle), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(toast('Contact moved back to Recently deleted'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, TrashView.purgeLabel));
      await tester.pumpAndSettle();
      expect(find.text('Delete Pip Owned permanently?'), findsOneWidget);
      expect(find.text('It is deleted for good. This cannot be undone. Copies in your host\'s backups are kept until '
          '1 October 2027.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(MyDataDialog), matching: find.text('Delete permanently')));
      await tester.pumpAndSettle();
      expect(backend.writes.last, 'purge c-pip');
      expect(find.text(TrashView.emptyTitle), findsOneWidget);
      await outlastToast(tester);
    });
  });

  group('the menu bar', () {
    List<Map<Object?, Object?>> sent = [];

    void capture(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, (call) async {
        if (call.method == 'Menu.setMenus') {
          sent = [for (final m in ((call.arguments as Map)['0'] as List)) m as Map<Object?, Object?>];
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.menu, null));
    }

    List<({String label, bool enabled})> items(String menu) {
      final top = sent.firstWhere((m) => m['label'] == menu);
      return [
        for (final c in (top['children'] as List).cast<Map<Object?, Object?>>())
          if (c['isDivider'] != true && c['label'] != null)
            (label: c['label'] as String, enabled: c['enabled'] == true),
      ];
    }

    testWidgets('macOS: New Contact, Edit Contact, Delete Contact, the sections, and Undo named from the action',
        (tester) async {
      desktop(tester);
      capture(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend, menu: TargetPlatform.macOS));
      await tester.pumpAndSettle();
      expect(items('File').map((i) => i.label), containsAll(['New Contact', 'Save', 'Close Window']));
      final edit = items('Edit');
      expect(edit.firstWhere((i) => i.label == 'Undo').enabled, isFalse);
      expect(edit.firstWhere((i) => i.label == 'Edit Contact').enabled, isTrue);
      expect(edit.firstWhere((i) => i.label == 'Delete Contact').enabled, isTrue);
      expect(items('View').map((i) => i.label), containsAll(['Contacts', 'Recently Deleted']));

      await tester.tap(find.byType(MoreActionsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete contact'));
      await tester.pumpAndSettle();
      await outlastToast(tester);
      expect(items('Edit').map((i) => i.label), contains('Undo Delete Contact'));

      await tester.tap(row('Omar Sample'));
      await tester.pumpAndSettle();
      final followed = items('Edit');
      expect(followed.firstWhere((i) => i.label == 'Edit Contact').enabled, isFalse);
      expect(followed.firstWhere((i) => i.label == 'Delete Contact').enabled, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Windows: Ctrl+N, Ctrl+S, Ctrl+Z and Ctrl+E work without a drawn menu bar', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend, menu: TargetPlatform.windows));
      await tester.pumpAndSettle();
      // Keys reach the menu bar's handler from inside the window's content: the list has focus.
      await tester.tap(row('Pip Owned'));
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyE);
      expect(inInspector(find.text('Edit contact')), findsOneWidget);
      await enter(tester, 'Job title', 'Head archivist');
      await ctrl(tester, LogicalKeyboardKey.keyS);
      expect(backend.writes, ['update c-pip']);
      expect(find.byType(Inspector), findsNothing);
      await tester.tap(row('Pip Owned'));
      await tester.pumpAndSettle();
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(backend.writes.last, 'undo u-1');
      expect(toast('Changes undone'), findsOneWidget);
      await ctrl(tester, LogicalKeyboardKey.keyN);
      expect(inInspector(find.text('New contact')), findsOneWidget);
      await outlastToast(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('under 600px', () {
    testWidgets('New contact in the large title opens the editor sheet; Save adds it', (tester) async {
      phone(tester);
      final backend = FakeBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == 'New contact'));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsOneWidget);
      await enter(tester, 'First name', 'Nia');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(Sheet), findsNothing);
      expect(backend.writes, ['create c-new-1']);
      expect(toast('Contact added'), findsOneWidget);
      await outlastToast(tester);
    });
  });
  group('etags on every delete (review)', () {
    testWidgets('a delete of rows never opened sends each row\'s etag from the list', (tester) async {
      desktop(tester);
      final backend = ownedBackend(more: [
        ownedCard('c-quinn', ContactIn(givenName: 'Quinn', familyName: 'Owned'), rev: 2),
      ]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.ensureVisible(row('Quinn Owned'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row('Quinn Owned'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(backend.detailCalls, isNot(contains('c-quinn')), reason: 'Quinn\'s page was never read');
      await tester.tap(find.widgetWithText(Button, 'Delete 2 contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MyDataDialog), matching: find.text('Delete 2 contacts')));
      await tester.pumpAndSettle();
      expect(backend.writes, ['delete c-quinn', 'delete c-pip']);
      expect(backend.etagsSent, ['"2-c-quinn"', '"3-c-pip"']);
      await outlastToast(tester);
    });

    testWidgets('a stale list deletes nothing: the host refuses the old etag', (tester) async {
      desktop(tester);
      final backend = ownedBackend(more: [ownedCard('c-quinn', ContactIn(givenName: 'Quinn', familyName: 'Owned'))]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      backend.changeElsewhere('c-quinn'); // the myData app saved a new phone; this window's list is older
      await tester.ensureVisible(row('Quinn Owned'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row('Quinn Owned'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Delete 2 contacts'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(MyDataDialog), matching: find.text('Delete 2 contacts')));
      await tester.pumpAndSettle();
      expect(backend.writes, isEmpty);
      expect(find.textContaining('One of them changed since'), findsOneWidget);
    });

    testWidgets('delete permanently refuses a version changed elsewhere, even when pressed again', (tester) async {
      desktop(tester);
      final backend = ownedBackend();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(row('Pip Owned'));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deleted'));
      await tester.pumpAndSettle();
      backend.changeInTrashElsewhere('c-pip');
      await tester.tap(find.widgetWithText(Button, TrashView.purgeLabel));
      await tester.pumpAndSettle();
      final confirm = find.descendant(of: find.byType(MyDataDialog), matching: find.text('Delete permanently'));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.textContaining('It changed elsewhere since this list was read'), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(backend.writes.where((w) => w.startsWith('purge')), isEmpty);
      expect(backend.etagsSent.last, '"4-c-pip"', reason: 'the version the dialog named');
      await tester.tap(find.descendant(of: find.byType(MyDataDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      // Recently deleted was read again: looking at it again and deleting goes, at the newer version.
      await tester.tap(find.widgetWithText(Button, TrashView.purgeLabel));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(backend.writes.last, 'purge c-pip');
      expect(backend.etagsSent.last, '"7-c-pip"');
      await outlastToast(tester);
    });
  });
}
