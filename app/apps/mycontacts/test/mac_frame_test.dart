// The Mac frame (MacLook) of the People screen: its behaviour, and screenshots at 1280x800 in light and dark
// (test/screenshots/mac_*.png), with the bundled Figtree under the system font's names (loadMacFonts); refresh
// with `flutter test --update-goldens test/mac_frame_test.dart` on a Mac.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_actions.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mycontacts/src/contacts_view.dart';
import 'package:mycontacts/src/home.dart';
import 'package:mycontacts/src/mac_contact_page.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

late Uint8List portrait;

/// More invented people, two to four for most letters, as a real address book's first screen has.
List<ContactDetailOut> crowd() {
  const given = ['Abe', 'Bea', 'Cal', 'Dora', 'Edda', 'Finn', 'Gia', 'Hal', 'Ines', 'Jago', 'Kit', 'Lena', 'Milo'];
  const family = [
    'Notreal', 'Dummy', 'Fakeham', 'Mockford', 'Sampleby', 'Testa', 'Placeholt', 'Example-Smith', 'Fictive',
    'Madeup', 'Invento', 'Pretendo', 'Synthetic', 'Imaginary', 'Stand-in', 'Unreal', 'Doe', 'Fakely', 'Specimen',
    'Mockup', 'Facsimile', 'Proxy', 'Dummyton',
  ];
  final out = <ContactDetailOut>[];
  var i = 0;
  for (final g in given) {
    for (final f in family.skip(i % 5).take(3)) {
      out.add(card(
        id: 'c-crowd-${i++}',
        name: '$g $f',
        given: g,
        family: f,
        icloud: i.isEven,
        phones: [('Mobile', '+44 7700 9${(10000 + i * 37).toString().substring(1)}')],
      ));
    }
  }
  return out;
}

/// The sample contacts, the crowd and Pip and Quinn (whom the host owns), in the host's order (by name).
FakeBackend people() {
  final cards = [
    ...sampleCards(),
    ...crowd(),
    pipOwned(),
    ownedCard('c-quinn', ContactIn(givenName: 'Quinn', familyName: 'Owned', emails: [
      LabeledValueIn(label: 'Home', value: 'quinn@example.org'),
    ])),
  ];
  String key(ContactDetailOut c) => c.sortLetter == '#' ? '~${c.displayName}' : c.displayName.toLowerCase();
  cards.sort((a, b) => key(a).compareTo(key(b)));
  return FakeBackend(cards: cards, photos: {'c-ava': portrait});
}

Widget app(ThemeCase t, {String? lastOpened, FakeBackend? backend}) => MyContactsApp(
  host: FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(theme: t.themeId)),
  store: MemoryDeviceStore({
    'mode': t.brightness.name,
    'lastTheme': t.themeId,
    ContactsController.lastOpenedKey: ?lastOpened,
  }),
  backend: backend ?? people(),
  links: const Stream.empty(),
  onOpenLink: (_) {},
);

/// Lets the app read the device's mode, the host's theme and the contacts, and decode the photos.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _row(String name) => find.descendant(of: find.byType(ContactList), matching: find.text(name, findRichText: true));

/// Scrolls the list until [name]'s row is built and in view (the list builds rows lazily).
Future<void> _showRow(WidgetTester tester, String name) async {
  for (var i = 0; i < 20 && _row(name).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ContactList), const Offset(0, -200));
    await settle(tester);
  }
  await tester.ensureVisible(_row(name));
  await settle(tester);
}

void main() {
  setUpAll(() async => portrait = await portraitPng());
  setUp(() {
    MacLook.debugOverride = true;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() {
    MacLook.debugOverride = false;
    EditableText.debugDeterministicCursor = false;
  });

  group('the Mac frame', () {
    testWidgets('draws the source list, the plain list and the contact page', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first, lastOpened: 'c-ava'));
      await settle(tester);

      expect(find.byType(MacSourceList), findsOneWidget);
      expect(find.byType(MacContactPage), findsOneWidget);
      expect(find.byType(MacSearchField), findsOneWidget);
      // Every font is the system's.
      final theme = Theme.of(tester.element(find.byType(ContactsView)));
      expect(theme.textTheme.bodyMedium!.fontFamily, MyDataMacFont.text);
      // The plan's acceptance: at least 20 people's rows wholly on screen at 1280x800 (letter headings not
      // counted).
      final list = tester.getRect(find.byType(ContactList));
      final rows = find.descendant(of: find.byType(ContactList), matching: find.byType(RichText)).evaluate().where((e) {
        if ((e.widget as RichText).text.toPlainText().length < 2) return false;
        final r = tester.getRect(find.byElementPredicate((x) => x == e));
        return r.top >= list.top && r.bottom <= list.bottom;
      });
      expect(rows.length, greaterThanOrEqualTo(20));
      // The quick actions under the name, and the values in two columns.
      expect(find.text(MacContactPage.messageLabel), findsOneWidget);
      expect(find.text('+44 7700 900123'), findsOneWidget);
      expect(find.text('mobile'), findsOneWidget);
    });

    testWidgets('the toolbar search filters the list', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first, lastOpened: 'c-ava'));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(MacSearchField), matching: find.byType(TextField)), 'pip');
      await settle(tester);
      expect(_row('Pip Owned'), findsOneWidget);
      expect(_row('Ben Testwell'), findsNothing);
    });

    testWidgets('Edit in the toolbar opens the inspector for an owned contact, not for a followed one',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first, lastOpened: 'c-ava'));
      await settle(tester);
      Finder edit() => find.byWidgetPredicate((w) => w is MacToolbarButton && w.label == ContactActions.editLabel);
      expect(tester.widget<MacToolbarButton>(edit()).onPressed, isNull);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
      expect(tester.widget<MacToolbarButton>(edit()).onPressed, isNotNull);
      await tester.tap(edit());
      await settle(tester);
      expect(find.byType(MacContactPage), findsNothing);
      expect(find.byWidgetPredicate((w) => w is MyDataTextField && w.label == 'First name'), findsOneWidget);
    });

    testWidgets('the sidebar changes section with a click and with the arrow keys', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first, lastOpened: 'c-ava'));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Recently Deleted')));
      await settle(tester);
      Finder title(int i) => find.descendant(of: find.byType(MacToolbar), matching: find.text(ContactsHome.macTitles[i]));
      expect(title(1), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(title(2), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(find.byType(MacContactPage), findsOneWidget);
    });

    testWidgets('a phone-sized window keeps the branded phone layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first));
      await settle(tester);
      expect(find.byType(MacSourceList), findsNothing);
    });
  });

  group('screenshots', () {
    // The stack gate's screen: the list with an iCloud contact open (photo, notes).
    screenMatrix('mac_people', (t) => app(t, lastOpened: 'c-ava'), themes: macMatrix, before: settle);

    // A contact from This Mac with every kind of field but notes.
    screenMatrix('mac_contact_this_mac', (t) => app(t, lastOpened: 'c-aaron'), themes: macMatrix, before: settle);

    // A contact the host owns: Edit enabled, "On myData only".
    screenMatrix('mac_owned', (t) => app(t, lastOpened: 'c-pip'), themes: macMatrix, before: (tester) async {
      await settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
    });

    // The list has the keyboard: the selection in the accent.
    screenMatrix('mac_list_focused', (t) => app(t, lastOpened: 'c-jun'), themes: macMatrix, before: (tester) async {
      await settle(tester);
      await tester.tap(_row('Jun Placeholder'));
      await settle(tester);
    });

    // Recently deleted.
    screenMatrix('mac_recently_deleted', (t) => app(t, lastOpened: 'c-pip'), themes: macMatrix,
        before: (tester) async {
      await settle(tester);
      for (final name in ['Quinn Owned', 'Pip Owned']) {
        await _showRow(tester, name);
        await tester.tap(_row(name));
        await settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await settle(tester);
      }
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Recently Deleted')));
      await settle(tester);
      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
    });

    // Review: a possible duplicate (Pip and Quinn), and Quinn changed in a followed account since the import.
    screenMatrix('mac_review', (t) => app(t, lastOpened: 'c-ava', backend: reviewBackend()), themes: macMatrix,
        before: (tester) async {
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await settle(tester);
    });

    // Several selected: the count and the actions in the contact column. (Ctrl-click: the tests run as
    // Android, where Ctrl is the command key.)
    screenMatrix('mac_several_selected', (t) => app(t, lastOpened: 'c-pip'), themes: macMatrix,
        before: (tester) async {
      await settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
      for (final name in ['Quinn Owned', 'Omar Sample']) {
        await _showRow(tester, name);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.tap(_row(name));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
      }
    });
  });
}

/// [people] with Pip and Quinn as a possible duplicate, and Quinn changed in a followed iCloud account since
/// the import (as screenshots_test.dart's Review backend).
FakeBackend reviewBackend() {
  final b = people();
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
