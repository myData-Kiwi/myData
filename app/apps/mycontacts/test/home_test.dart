import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_page.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mycontacts/src/contacts_view.dart';
import 'package:mycontacts/src/home.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// A desktop window, so the frame is the sidebar and the list and the contact pane sit side by side.
void desktop(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A phone-sized window: the list alone, and a pushed page for a contact.
void phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class Harness {
  Harness({FakeBackend? backend, MemoryDeviceStore? store, HostPhase phase = HostPhase.running})
    : backend = backend ?? FakeBackend(),
      store = store ?? MemoryDeviceStore(),
      host = FakeHost(phaseOnConnect: phase, statusOnConnect: hostStatus());

  final FakeBackend backend;
  final MemoryDeviceStore store;
  final FakeHost host;
  final links = FakeLinks();
  final opened = <Uri>[];
  var sourcesOpened = 0;
  var sourcesOpen = true;

  Widget get app => MyContactsApp(
    host: host,
    store: store,
    backend: backend,
    links: links.stream,
    openMyDataSources: () async {
      sourcesOpened++;
      return sourcesOpen;
    },
    onOpenLink: opened.add,
  );
}

/// The contact pane's title: the name in the header (the list's row has the name too).
Finder headerName(String name) => find.descendant(of: find.byType(ContactHeader), matching: find.text(name));

Finder row(String name) => find.descendant(of: find.byType(ContactList), matching: find.text(name));

void main() {
  testWidgets('without a start command: the error, its detail, and Retry that tries again', (tester) async {
    desktop(tester);
    final platform = NoHostPlatform(supported: true);
    await tester.pumpWidget(
      MyContactsApp(
        host: HostController(app: 'mycontacts', platform: platform),
        store: MemoryDeviceStore(),
        backend: FakeBackend(),
        links: const Stream.empty(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('myContacts'), findsOneWidget);
    expect(find.text('The myData host is not set up'), findsOneWidget);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(StatusPanel), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(platform.environments, 2);
  });

  testWidgets('the web build explains that the desktop app is needed, with no frame', (tester) async {
    desktop(tester);
    final host = HostController(app: 'mycontacts', platform: NoHostPlatform(supported: false));
    await tester.pumpWidget(
      MyContactsApp(host: host, store: MemoryDeviceStore(), backend: FakeBackend(), links: const Stream.empty()),
    );
    await tester.pumpAndSettle();
    expect(find.text('myContacts needs the desktop app'), findsOneWidget);
    expect(find.byType(AppFrame), findsNothing);
    expect(find.text(AppConnection.retryText), findsNothing);
  });

  testWidgets('starting: the panel and the frame say so', (tester) async {
    desktop(tester);
    final h = Harness(phase: HostPhase.starting);
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('Starting the myData host'), findsOneWidget);
    expect(find.text(AppConnection.startingText), findsOneWidget);
    expect(h.backend.sourceCalls, 0, reason: 'nothing is asked of a host that is not running');
  });

  group('no contacts', () {
    testWidgets('no source on: the empty state, whose button opens myData at Settings, Sources', (tester) async {
      desktop(tester);
      final h = Harness(backend: FakeBackend(anyOn: false));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text(ContactsHome.noSourceSentence), findsOneWidget);
      expect(find.byType(ContactList), findsNothing);
      expect(h.backend.contactCalls, 0);

      await tester.tap(find.widgetWithText(Button, ContactsHome.openMyDataLabel));
      await tester.pumpAndSettle();
      expect(h.sourcesOpened, 1);
      expect(find.text(ContactsHome.openFailedText), findsNothing);
    });

    testWidgets('when myData cannot be opened, a line says where to go', (tester) async {
      desktop(tester);
      final h = Harness(backend: FakeBackend(anyOn: false))..sourcesOpen = false;
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, ContactsHome.openMyDataLabel));
      await tester.pumpAndSettle();
      expect(find.text(ContactsHome.openFailedText), findsOneWidget);
    });

    testWidgets('a source on that has read nothing yet says so', (tester) async {
      desktop(tester);
      final h = Harness(backend: FakeBackend(cards: []));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text(ContactsHome.nothingReadSentence), findsOneWidget);
    });

    testWidgets('contacts that cannot be read: an error with Retry, which reads them again', (tester) async {
      desktop(tester);
      final h = Harness()..backend.failContacts = true;
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text('myContacts could not read your contacts'), findsOneWidget);
      h.backend.failContacts = false;
      await tester.tap(find.descendant(of: find.byType(StatusPanel), matching: find.text('Retry')));
      await tester.pumpAndSettle();
      expect(find.byType(ContactList), findsOneWidget);
    });
  });

  group('from 600px', () {
    testWidgets('opens on the first contact of the first group when none was opened before', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.byType(AppFrame), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget); // the frame's one section
      expect(headerName('Aaron Example'), findsOneWidget);
      expect(h.backend.detailCalls, ['c-aaron']);
    });

    testWidgets('opens on the contact last opened on this device', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-ava'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(headerName('Ava Fictional'), findsOneWidget);
    });

    testWidgets('a last-opened contact that is gone falls back to the first', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-gone'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(headerName('Aaron Example'), findsOneWidget);
    });

    testWidgets('pressing a row opens it beside the list and remembers it, keeping the other settings', (tester) async {
      desktop(tester);
      final h = Harness(
        store: MemoryDeviceStore({
          'mode': 'dark',
          'hiddenCalendars': ['cal-1'],
        }),
      );
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.tap(row('Eli Sample'));
      await tester.pumpAndSettle();
      expect(headerName('Eli Sample'), findsOneWidget);
      final stored = await h.store.read();
      expect(stored[ContactsController.lastOpenedKey], 'c-eli');
      expect(stored['mode'], 'dark');
      expect(stored['hiddenCalendars'], ['cal-1']);
    });

    testWidgets('Down in the list moves the selection and the pane follows', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.tap(row('Aaron Example'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(headerName('Ava Fictional'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(headerName('Ben Testwell'), findsOneWidget);
    });

    testWidgets('search filters the list and the open contact stays open', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-ava'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'emile');
      await tester.pumpAndSettle();
      expect(row('Émile Exemple'), findsOneWidget);
      expect(row('Aaron Example'), findsNothing);
      expect(headerName('Ava Fictional'), findsOneWidget);
    });

    testWidgets('a contact from This Mac: its fields, no Notes, and the source line', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-aaron'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text('From this Mac. Change it in Contacts.'), findsOneWidget);
      for (final heading in ['Phone', 'Email', 'Address', 'Birthday', 'Links']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      expect(find.text('Notes'), findsNothing);
      expect(find.text('12 May 1990'), findsOneWidget);
      expect(find.text('4 Placeholder Lane\nSampleford ZZ9 8XY\nUnited Kingdom'), findsOneWidget);
    });

    testWidgets('a contact from iCloud: role line, notes, a birthday without a year, and a web link', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-ava'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text('Head of research, Example Labs'), findsOneWidget);
      expect(find.text('From the iCloud account you@example.com. Change it in your iCloud account.'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('12 May'), findsOneWidget);
      await tester.tap(find.text('example.com/ava'));
      await tester.pumpAndSettle();
      expect(h.opened, [Uri.parse('https://example.com/ava')]);
    });

    testWidgets('a link to another app is plain text that opens nothing', (tester) async {
      desktop(tester);
      final h = Harness(store: MemoryDeviceStore({ContactsController.lastOpenedKey: 'c-aaron'}));
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('x-example-app://open?id=aaron'));
      await tester.pumpAndSettle();
      expect(h.opened, isEmpty);
    });

    testWidgets('a page that cannot be read says so, and Try again reads it', (tester) async {
      desktop(tester);
      final h = Harness()..backend.failDetails = true;
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.text(ContactPage.failedText), findsOneWidget);
      h.backend.failDetails = false;
      await tester.tap(find.widgetWithText(Button, ContactPage.retryLabel));
      await tester.pumpAndSettle();
      expect(find.text(ContactPage.failedText), findsNothing);
      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('a contact deleted since the list was read says so', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.backend.cards = h.backend.cards.where((c) => c.id != 'c-eli').toList();
      await tester.tap(row('Eli Sample'));
      await tester.pumpAndSettle();
      expect(find.text(ContactPage.missingText), findsOneWidget);
    });

    testWidgets('mycontacts://contact/<id> opens that contact', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.links.open('mycontacts://contact/c-ava');
      await tester.pumpAndSettle();
      expect(headerName('Ava Fictional'), findsOneWidget);
      expect((await h.store.read())[ContactsController.lastOpenedKey], 'c-ava');
    });

    testWidgets('a link that arrives before the list is read opens its contact once it is', (tester) async {
      desktop(tester);
      final h = Harness(phase: HostPhase.starting);
      await tester.pumpWidget(h.app);
      await tester.pump();
      h.links.open('mycontacts://contact/c-maya');
      await tester.pump();
      h.host
        ..phaseOnConnect = HostPhase.running
        ..phase = HostPhase.running
        ..poll();
      await tester.pumpAndSettle();
      expect(headerName('Maya Mock'), findsOneWidget);
    });

    testWidgets('a link to a contact the host does not have is one plain line', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.links.open('mycontacts://contact/c-unknown');
      await tester.pumpAndSettle();
      expect(find.text(ContactsView.missingLinkText), findsOneWidget);
      expect(find.byType(ContactHeader), findsNothing);
      // Opening a contact replaces the line.
      await tester.tap(row('Ben Testwell'));
      await tester.pumpAndSettle();
      expect(find.text(ContactsView.missingLinkText), findsNothing);
      expect(headerName('Ben Testwell'), findsOneWidget);
    });

    testWidgets('a link to a contact synced since the list was read opens it, and the list catches up', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      // myAssistant read the host after myContacts did: the contact is new to this app's list.
      h.backend.cards = [...h.backend.cards, card(id: 'c-nina', name: 'Nina Newcard', given: 'Nina', family: 'Newcard')];
      final listReads = h.backend.contactCalls;
      h.links.open('mycontacts://contact/c-nina');
      await tester.pumpAndSettle();
      expect(find.text(ContactsView.missingLinkText), findsNothing);
      expect(headerName('Nina Newcard'), findsOneWidget);
      expect(h.backend.contactCalls, listReads + 1, reason: 'the list is read again');
      expect(row('Nina Newcard'), findsOneWidget);
      expect((await h.store.read())[ContactsController.lastOpenedKey], 'c-nina');
    });

    testWidgets('when the host stops, the contacts stay with the time they were read', (tester) async {
      desktop(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.host.lose();
      await tester.pumpAndSettle();
      expect(find.byType(ContactList), findsOneWidget);
      expect(find.text(AppConnection.unreachableText), findsOneWidget);
      expect(find.textContaining('Last updated at'), findsOneWidget);
    });
  });

  group('under 600px', () {
    testWidgets('the list fills the screen; pressing a contact pushes its page, and back returns', (tester) async {
      phone(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(find.byType(ContactHeader), findsNothing);
      await tester.tap(row('Ava Fictional'));
      await tester.pumpAndSettle();
      expect(headerName('Ava Fictional'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, ContactsView.backLabel));
      await tester.pumpAndSettle();
      expect(find.byType(ContactHeader), findsNothing);
      expect(row('Ava Fictional'), findsOneWidget);
    });

    testWidgets('with reduced motion the page simply appears', (tester) async {
      phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      await tester.tap(row('Ava Fictional'));
      await tester.pump();
      await tester.pump();
      final first = tester.getTopLeft(headerName('Ava Fictional'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(headerName('Ava Fictional')), first, reason: 'no slide');
    });

    testWidgets('a link pushes the contact\'s page', (tester) async {
      phone(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.links.open('mycontacts://contact/c-ben');
      await tester.pumpAndSettle();
      expect(headerName('Ben Testwell'), findsOneWidget);
      h.links.open('mycontacts://contact/c-eli');
      await tester.pumpAndSettle();
      expect(headerName('Eli Sample'), findsOneWidget);
      expect(headerName('Ben Testwell'), findsNothing, reason: 'one contact page at a time');
    });

    testWidgets('an unknown link is a line above the list', (tester) async {
      phone(tester);
      final h = Harness();
      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      h.links.open('mycontacts://contact/c-unknown');
      await tester.pumpAndSettle();
      expect(find.text(ContactsView.missingLinkText), findsOneWidget);
      expect(find.byType(ContactList), findsOneWidget);
    });
  });
}
