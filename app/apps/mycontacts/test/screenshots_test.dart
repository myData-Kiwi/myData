// Whole-app screenshots in Kiwi and Graphite, light and dark: test/screenshots/<name>.<theme>-<mode>.png.
// Refresh with `flutter test --update-goldens test/screenshots_test.dart`.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_actions.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';

late Uint8List portrait;

/// The app on a device in [t]'s mode that last opened [lastOpened], with the host running in [t]'s theme.
Widget app(
  ThemeCase t, {
  String? lastOpened,
  bool anyOn = true,
  HostPhase phase = HostPhase.running,
  Stream<MyDataLink> links = const Stream.empty(),
  FakeBackend? backend,
}) => MyContactsApp(
  host: FakeHost(
    phaseOnConnect: phase,
    statusOnConnect: hostStatus(theme: t.themeId, real: anyOn),
  ),
  store: MemoryDeviceStore({
    'mode': t.brightness.name,
    'lastTheme': t.themeId,
    ContactsController.lastOpenedKey: ?lastOpened,
  }),
  backend: backend ?? FakeBackend(anyOn: anyOn, photos: {'c-ava': portrait}),
  links: links,
  onOpenLink: (_) {},
);

/// Lets the app read the device's mode, the host's theme and the contacts, and decode the photos (which
/// needs real time, not the test's clock). Frame by frame, not pumpAndSettle: the loading kiwi never settles.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The sample contacts with Pip and Quinn, whom the host owns, after Omar Sample, in the host's order (P
/// before Q).
FakeBackend owned() {
  final cards = sampleCards();
  cards.insertAll(cards.indexWhere((c) => c.id == 'c-sam'), [
    pipOwned(),
    ownedCard('c-quinn', ContactIn(givenName: 'Quinn', familyName: 'Owned', emails: [
      LabeledValueIn(label: 'Home', value: 'quinn@example.org'),
    ])),
  ]);
  return FakeBackend(cards: cards, photos: {'c-ava': portrait});
}

/// Scrolls the contact list until [name]'s row is built and in view (the list builds rows lazily).
Future<void> _showRow(WidgetTester tester, String name) async {
  final row = find.descendant(of: find.byType(ContactList), matching: find.text(name));
  for (var i = 0; i < 10 && row.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ContactList), const Offset(0, -120));
    await settle(tester);
  }
  await tester.ensureVisible(row);
  await settle(tester);
}

Finder _iconButton(String label) => find.byWidgetPredicate((w) => w is MyDataIconButton && w.label == label);

void main() {
  setUpAll(() async => portrait = await portraitPng());
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  // A contact the host owns, selected: Edit and More actions beside the header, "On myData only".
  screenMatrix('owned_contact', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: settle);

  // New contact: the inspector in the contact pane's place, a name typed and a phone row added.
  screenMatrix('inspector_new', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    await tester.tap(_iconButton(ContactActions.newLabel));
    await settle(tester);
    await tester.enterText(find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'First name'), 'Nia');
    await tester.enterText(find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'Last name'), 'Newcomb');
    await tester.tap(find.text('Add phone'));
    await settle(tester);
    await tester.enterText(
        find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'Mobile, phone number'), '+1 555 0177');
    await settle(tester);
  });

  // Editing Pip: an email that is incomplete, shown after Save, which sent nothing.
  screenMatrix('inspector_field_error', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    await tester.tap(find.widgetWithText(Button, ContactActions.editButton));
    await settle(tester);
    await tester.enterText(find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'Work, email address'),
        'pip@example');
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
  });

  // Two of the host's contacts and one from This Mac selected: the count and Delete in the pane.
  screenMatrix('several_selected', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    for (final name in ['Quinn Owned', 'Omar Sample']) {
      await _showRow(tester, name);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.descendant(of: find.byType(ContactList), matching: find.text(name)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }
  });

  // Pip deleted with the Delete key: the toast with Undo, the next contact open.
  screenMatrix('undo_toast', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(ContactList), matching: find.text('Pip Owned')));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await settle(tester);
  });

  // Recently deleted, with Pip and Quinn in it and Pip's pane.
  screenMatrix('recently_deleted', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    for (final name in ['Quinn Owned', 'Pip Owned']) {
      await _showRow(tester, name);
      await tester.tap(find.descendant(of: find.byType(ContactList), matching: find.text(name)));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
    }
    await tester.tap(find.text('Deleted'));
    await settle(tester);
    // The toasts' time runs out, so the page is shown alone.
    await tester.pump(const Duration(seconds: 9));
    await settle(tester);
  });

  // The list with a contact selected in the middle of it; its page beside it.
  screenMatrix('contacts_list', (t) => app(t, lastOpened: 'c-jun'), before: settle);

  // A contact from This Mac: every kind of field but Notes, which This Mac never reads.
  screenMatrix('contact_page_mac', (t) => app(t, lastOpened: 'c-aaron'), before: settle);

  // A contact from an iCloud account, with a photo and notes.
  screenMatrix('contact_page_icloud', (t) => app(t, lastOpened: 'c-ava'), before: settle);

  // No source on: the empty state, whose button opens myData at Settings, Sources.
  screenMatrix('no_source', (t) => app(t, anyOn: false), before: settle);

  // A link to a contact the host does not have: one plain line in the contact pane.
  screenMatrix(
    'missing_link',
    (t) => app(t, lastOpened: 'c-ava', links: Stream.value(MyDataLink.parse('mycontacts://contact/c-unknown')!)),
    before: settle,
  );

  // Under 600px: the list alone, with a chevron on each row.
  screenMatrix(
    'phone_list',
    (t) => app(t, lastOpened: 'c-ava'),
    size: const Size(390, 844),
    before: settle,
  );

  // Under 600px: a contact's page pushed over the list.
  screenMatrix(
    'phone_contact_page',
    (t) => app(t),
    size: const Size(390, 844),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Ava Fictional'));
      await settle(tester);
    },
  );

  // Merge from a multi-selection: Pip and Quinn, whom the host owns, with "After merging".
  screenMatrix('merge_pane', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    await _showRow(tester, 'Quinn Owned');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.descendant(of: find.byType(ContactList), matching: find.text('Quinn Owned')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await mouse.down(tester.getCenter(find.descendant(of: find.byType(ContactList), matching: find.text('Quinn Owned'))));
    await mouse.up();
    await settle(tester);
    await tester.tap(find.text('Merge contacts…'));
    await settle(tester);
  });

  // Review: a possible duplicate, "Same person?".
  screenMatrix('review_duplicate', (t) => app(t, lastOpened: 'c-pip', backend: _reviewBackend()), before: (tester) async {
    await settle(tester);
    await tester.tap(find.text('Review').first);
    await settle(tester);
  });

  // Review: Quinn changed in a followed iCloud account since the import.
  screenMatrix('review_changes', (t) => app(t, lastOpened: 'c-quinn', backend: _reviewBackend()), before: (tester) async {
    await settle(tester);
    await tester.tap(find.text('Review').first);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('changed:c-quinn')));
    await settle(tester);
  });

  // Quinn's page: the "changed since import" Notice between the header and the fields.
  screenMatrix('contact_changed', (t) => app(t, lastOpened: 'c-quinn', backend: _reviewBackend()), before: settle);

  // Review with nothing in it.
  screenMatrix('review_empty', (t) => app(t, lastOpened: 'c-pip', backend: owned()), before: (tester) async {
    await settle(tester);
    await tester.tap(find.text('Review').first);
    await settle(tester);
  });
}

/// Pip and Quinn, whom the host owns, as a possible duplicate (a shared phone under another name), and Quinn
/// changed in a followed iCloud account since the import.
FakeBackend _reviewBackend() {
  final b = owned();
  final pip = b.cards.firstWhere((c) => c.id == 'c-pip');
  final quinn = b.cards.firstWhere((c) => c.id == 'c-quinn')
    ..changedInSource = 'acct-quinn'
    ..changedInSourceLabel = 'the iCloud account quinn@example.org';
  b.pairs = [
    DuplicatePairOut(
      contacts: [listView(pip), listView(quinn)],
      signals: const ['email'],
      strength: 'suggestion',
      emails: const ['quinn@example.org'],
    ),
  ];
  b.followed['c-quinn'] = FollowedChangesOut(
    contact: quinn,
    changes: [
      FollowedChangeOut(
        accountId: 'acct-quinn',
        differences: const ['job_title', 'phone'],
        followed: card(
          id: 'c-quinn-icloud',
          name: 'Quinn Owned',
          given: 'Quinn',
          family: 'Owned',
          job: 'Editor',
          icloud: true,
          phones: [('Mobile', '555-0188')],
          emails: [('Home', 'quinn@example.org')],
        ),
        sourceLabel: 'the iCloud account quinn@example.org',
      ),
    ],
  );
  return b;
}
