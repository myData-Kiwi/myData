// Merge from a multi-selection, the Review section (possible duplicates, changes since import), the contact
// page's "changed since import" Notice and File > Import…, against a fake host that answers as the real
// one does (etags, undo). Invented data only: Ava Fictional, Ben Sample, example.org, 555-01xx.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_page.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mycontacts/src/home.dart';
import 'package:mycontacts/src/merge.dart';
import 'package:mycontacts/src/merge_pane.dart';
import 'package:mycontacts/src/review_view.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

void desktop(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1280, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Ben Sample, added first, and Ben M. Sample, changed more recently, both the host's own.
ContactDetailOut benOwned() => ownedCard(
      'c-ben1',
      ContactIn(
        givenName: 'Ben',
        familyName: 'Sample',
        jobTitle: 'Head of research',
        phones: [LabeledValueIn(label: 'Mobile', value: '555-0142')],
        emails: [LabeledValueIn(label: 'Work', value: 'ben@example.org')],
      ),
      created: '2026-10-02T09:00:00+00:00',
    );

ContactDetailOut benImported() => ownedCard(
      'c-ben2',
      ContactIn(
        givenName: 'Ben M.',
        familyName: 'Sample',
        jobTitle: 'Researcher',
        phones: [LabeledValueIn(label: 'Work', value: '555-0177')],
        emails: [LabeledValueIn(label: 'Work', value: 'ben@example.org')],
      ),
      rev: 2,
      created: '2026-10-14T09:00:00+00:00',
    );

FakeBackend backendWith(List<ContactDetailOut> owned) {
  final cards = sampleCards()..insertAll(1, owned);
  cards.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return FakeBackend(cards: cards);
}

late List<MyDataLink> opened;

Widget app(FakeBackend backend, {String? lastOpened = 'c-ben1', TargetPlatform? menu}) {
  opened = [];
  return MyContactsApp(
    host: FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus()),
    store: MemoryDeviceStore({ContactsController.lastOpenedKey: ?lastOpened}),
    backend: backend,
    links: const Stream.empty(),
    onOpenLink: (_) {},
    menuPlatform: menu,
    openLink: (l) async {
      opened.add(l);
      return true;
    },
  );
}

Finder row(String name) => find.descendant(of: find.byType(ContactList), matching: find.text(name));
Finder toast(String text) => find.descendant(of: find.byType(ToastHost), matching: find.text(text));

Future<void> outlastToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 9));
  await tester.pumpAndSettle();
}

/// Selects [names] in the list, the first by a click and the rest by ⌘-click (Control-click off macOS).
Future<void> selectSeveral(WidgetTester tester, List<String> names) async {
  await tester.ensureVisible(row(names.first));
  await tester.pumpAndSettle();
  await tester.tap(row(names.first));
  await tester.pumpAndSettle();
  for (final name in names.skip(1)) {
    await tester.ensureVisible(row(name));
    await tester.pumpAndSettle();
    final key = defaultTargetPlatform == TargetPlatform.macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(key);
    await tester.tap(row(name));
    await tester.sendKeyUpEvent(key);
    await tester.pumpAndSettle();
  }
}

/// Taps [f] after scrolling it into view.
Future<void> tapButton(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Opens [name]'s row Menu with a right-click.
Future<void> rowMenu(WidgetTester tester, String name) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await mouse.down(tester.getCenter(row(name)));
  await mouse.up();
  await tester.pumpAndSettle();
}

/// The macOS menus the app last sent.
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

List<({String label, bool enabled, int id})> items(String menu) {
  final top = sent.firstWhere((m) => m['label'] == menu);
  return [
    for (final c in (top['children'] as List).cast<Map<Object?, Object?>>())
      if (c['isDivider'] != true && c['label'] != null)
        (label: c['label'] as String, enabled: c['enabled'] == true, id: c['id'] as int),
  ];
}

Future<void> chooseMenu(WidgetTester tester, String menu, String label) async {
  final id = items(menu).firstWhere((i) => i.label == label).id;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.menu.name, SystemChannels.menu.codec.encodeMethodCall(MethodCall('Menu.selectedCallback', id)), (_) {});
  await tester.pumpAndSettle();
}

DuplicatePairOut pairOf(ContactDetailOut a, ContactDetailOut b, {List<String> signals = const ['email', 'name']}) =>
    DuplicatePairOut(
      contacts: [listView(a), listView(b)],
      signals: signals,
      strength: 'strong',
      emails: signals.contains('email') ? [a.emails.first.value] : const [],
    );

void main() {
  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  group('Merge from a multi-selection', () {
    testWidgets('the pane: the newest contact\'s details kept, After merging from the host, then Merge with Undo',
        (tester) async {
      desktop(tester);
      final backend = backendWith([benOwned(), benImported()]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await selectSeveral(tester, ['Ben M. Sample', 'Ben Sample']);
      await rowMenu(tester, 'Ben Sample');
      await tester.tap(find.text('Merge contacts…'));
      await tester.pumpAndSettle();
      expect(find.text(MergePane.mergeTitle(2)), findsOneWidget);
      expect(backend.mergeCalls, ['preview c-ben2,c-ben1 names_from=null']);
      // The host's newest is the one kept by default; what is left out is said under the kept value.
      final select = tester.widget<MyDataSelect<String>>(find.byType(MyDataSelect<String>));
      expect(select.value, 'c-ben2');
      expect(find.text(PairAfter.mergingTitle), findsOneWidget);
      expect(find.text('Left out: Head of research'), findsOneWidget);
      expect(find.text(MergePane.afterCaption(2)), findsOneWidget);
      expect(find.text(MergePane.leftOutNote), findsOneWidget);

      // Choosing the other contact reads the preview again.
      await tester.tap(find.byType(MyDataSelect<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ben Sample').last);
      await tester.pumpAndSettle();
      expect(backend.mergeCalls.last, 'preview c-ben2,c-ben1 names_from=c-ben1');
      expect(find.text('Left out: Researcher'), findsOneWidget);

      await tapButton(tester, find.widgetWithText(SteadyWidthButton, MergePane.mergeLabel));
      await tester.pumpAndSettle();
      expect(backend.mergeCalls.last, 'merge c-ben2,c-ben1 names_from=c-ben1');
      expect(toast('Contacts merged. 1 job title was left out.'), findsOneWidget);
      expect(row('Ben M. Sample'), findsNothing);
      expect(find.text(MergePane.mergeTitle(2)), findsNothing);
      // Undo puts the originals back.
      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(row('Ben M. Sample'), findsOneWidget);
      await outlastToast(tester);
    });

    testWidgets('Escape and Cancel close the pane without merging', (tester) async {
      desktop(tester);
      final backend = backendWith([benOwned(), benImported()]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await selectSeveral(tester, ['Ben M. Sample', 'Ben Sample']);
      await rowMenu(tester, 'Ben Sample');
      await tester.tap(find.text('Merge contacts…'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(MergePane.mergeTitle(2)), findsNothing);
      expect(find.text('2 contacts selected'), findsOneWidget);
      expect(backend.writes, isEmpty);
    });

    testWidgets('a followed contact among them: Merge is disabled with the reason', (tester) async {
      desktop(tester);
      final backend = backendWith([benOwned()]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await selectSeveral(tester, ['Aaron Example', 'Ben Sample']);
      await rowMenu(tester, 'Ben Sample');
      expect(find.text('Aaron Example is read from this Mac. Only contacts on myData can be merged.'), findsOneWidget);
      await tester.tap(find.text('Merge contacts…'));
      await tester.pumpAndSettle();
      expect(find.text(MergePane.mergeTitle(2)), findsNothing);
    });

    testWidgets('a contact changed while shown is read again and said; nothing is merged on old data',
        (tester) async {
      desktop(tester);
      final backend = backendWith([benOwned(), benImported()]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await selectSeveral(tester, ['Ben M. Sample', 'Ben Sample']);
      await rowMenu(tester, 'Ben Sample');
      await tester.tap(find.text('Merge contacts…'));
      await tester.pumpAndSettle();
      backend.changeElsewhere('c-ben1', jobTitle: 'Director');
      await tapButton(tester, find.widgetWithText(SteadyWidthButton, MergePane.mergeLabel));
      await tester.pumpAndSettle();
      expect(find.text(MergeSession.changedLine('Ben Sample')), findsOneWidget);
      expect(backend.writes, isEmpty);
      await tapButton(tester, find.widgetWithText(SteadyWidthButton, MergePane.mergeLabel));
      await tester.pumpAndSettle();
      expect(backend.writes.single, startsWith('merge '));
      await outlastToast(tester);
    });

    testWidgets('the host not answering: the line under the pair, and the pane stays', (tester) async {
      desktop(tester);
      final backend = backendWith([benOwned(), benImported()]);
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await selectSeveral(tester, ['Ben M. Sample', 'Ben Sample']);
      await rowMenu(tester, 'Ben Sample');
      await tester.tap(find.text('Merge contacts…'));
      await tester.pumpAndSettle();
      backend.failWrites = true;
      await tapButton(tester, find.widgetWithText(SteadyWidthButton, MergePane.mergeLabel));
      await tester.pumpAndSettle();
      expect(find.text(MergeSession.noAnswer), findsOneWidget);
      expect(find.text(MergePane.mergeTitle(2)), findsOneWidget);
    });

    testWidgets('macOS: Edit, Merge Contacts… follows the selection; File, Import… opens myData', (tester) async {
      desktop(tester);
      capture(tester);
      final backend = backendWith([benOwned(), benImported()]);
      await tester.pumpWidget(app(backend, menu: TargetPlatform.macOS));
      await tester.pumpAndSettle();
      expect(items('Edit').firstWhere((i) => i.label == 'Merge Contacts…').enabled, isFalse);
      expect(items('View').map((i) => i.label), containsAll(['Contacts', 'Recently Deleted', 'Review']));
      await selectSeveral(tester, ['Ben M. Sample', 'Ben Sample']);
      expect(items('Edit').firstWhere((i) => i.label == 'Merge Contacts…').enabled, isTrue);
      await chooseMenu(tester, 'Edit', 'Merge Contacts…');
      expect(find.text(MergePane.mergeTitle(2)), findsOneWidget);
      await chooseMenu(tester, 'File', ContactsHome.importMenuItem);
      expect(opened, [const OpenMyDataImport()]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('Review', () {
    testWidgets('the count in the sidebar; Not the same person with Undo', (tester) async {
      desktop(tester);
      final a = benOwned(), b = benImported();
      final backend = backendWith([a, b])..pairs = [pairOf(a, b)];
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Review, 1'), findsOneWidget);
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();
      expect(find.text(ReviewView.duplicatesHeading(1)), findsOneWidget);
      expect(find.text('Ben Sample and Ben M. Sample'), findsOneWidget);
      expect(find.text('Same email: ben@example.org'), findsOneWidget);
      expect(find.text(ReviewView.samePerson), findsOneWidget);
      await tapButton(tester, find.widgetWithText(Button, ReviewView.notSame));
      await tester.pumpAndSettle();
      expect(backend.writes, ['not-duplicates c-ben1,c-ben2']);
      expect(toast('Marked as different people'), findsOneWidget);
      expect(find.text(ReviewView.emptyTitle), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(ToastHost), matching: find.text('Undo')));
      await tester.pumpAndSettle();
      expect(find.text('Ben Sample and Ben M. Sample'), findsOneWidget);
      handle.dispose();
      await outlastToast(tester);
    });

    testWidgets('Merge from Review: the pair leaves the list', (tester) async {
      desktop(tester);
      final a = benOwned(), b = benImported();
      final backend = backendWith([a, b])..pairs = [pairOf(a, b)];
      await tester.pumpWidget(app(backend));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();
      await tapButton(tester, find.widgetWithText(SteadyWidthButton, MergePane.mergeLabel));
      await tester.pumpAndSettle();
      expect(backend.writes.single, startsWith('merge '));
      expect(toast('Contacts merged. 1 job title was left out.'), findsOneWidget);
      expect(find.text('Ben Sample and Ben M. Sample'), findsNothing);
      await outlastToast(tester);
    });

    testWidgets('nothing to review: a title and one sentence, no button', (tester) async {
      desktop(tester);
      await tester.pumpWidget(app(backendWith([benOwned()])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();
      expect(find.text(ReviewView.emptyTitle), findsOneWidget);
      expect(find.text(ReviewView.emptySentence), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    });

    group('changed since import', () {
      FakeBackend changedBackend() {
        final mine = benOwned()
          ..changedInSource = 'acct-ava'
          ..changedInSourceLabel = 'the iCloud account ava@example.org';
        final theirs = card(
          id: 'c-ava-icloud',
          name: 'Ben Sample',
          given: 'Ben',
          family: 'Sample',
          job: 'Director',
          icloud: true,
          phones: [('Mobile', '555-0142')],
          emails: [('Work', 'ben@example.org')],
        );
        final backend = backendWith([mine]);
        backend.followed['c-ben1'] = FollowedChangesOut(
          contact: mine,
          changes: [
            FollowedChangeOut(
              accountId: 'acct-ava',
              differences: ['job_title'],
              followed: theirs,
              sourceLabel: 'the iCloud account ava@example.org',
            ),
          ],
        );
        return backend;
      }

      testWidgets('the contact page says so, and Review opens it; Save changes takes the followed values',
          (tester) async {
        desktop(tester);
        final backend = changedBackend();
        await tester.pumpWidget(app(backend));
        await tester.pumpAndSettle();
        final notice = ContactPage.changedNotice('the iCloud account ava@example.org');
        expect(find.text(notice), findsOneWidget);
        // Between the header and the fields.
        expect(tester.getRect(find.text(notice)).top,
            greaterThan(tester.getRect(find.byType(ContactHeader)).bottom));
        await tester.tap(find.widgetWithText(Button, ContactPage.reviewLabel));
        await tester.pumpAndSettle();
        expect(find.text(ReviewView.changedHeading(1)), findsOneWidget);
        expect(find.text('Changed in iCloud'), findsOneWidget);
        expect(find.text(DuplicatePair.differsLabel), findsWidgets);
        expect(find.byType(MyDataSelect<int>), findsOneWidget);
        await tapButton(tester, find.widgetWithText(SteadyWidthButton, ReviewView.saveChanges));
        await tester.pumpAndSettle();
        expect(backend.writes, ['save-followed c-ben1']);
        expect(backend.forms.last.jobTitle, 'Director');
        expect(toast('Changes saved'), findsOneWidget);
        await outlastToast(tester);
      });

      testWidgets('Keep mine clears the mark without changing the contact, with Undo', (tester) async {
        desktop(tester);
        final backend = changedBackend();
        await tester.pumpWidget(app(backend));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review').first);
        await tester.pumpAndSettle();
        await tapButton(tester, find.widgetWithText(SteadyWidthButton, ReviewView.keepMine));
        await tester.pumpAndSettle();
        expect(backend.writes, ['keep c-ben1']);
        expect(toast('Kept your version'), findsOneWidget);
        expect(find.text(ReviewView.emptyTitle), findsOneWidget);
        await outlastToast(tester);
      });

      testWidgets('choosing "In myData" for a row keeps that value', (tester) async {
        desktop(tester);
        final backend = changedBackend();
        await tester.pumpWidget(app(backend));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(MyDataSelect<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ReviewView.inMyData).last);
        await tester.pumpAndSettle();
        await tapButton(tester, find.widgetWithText(SteadyWidthButton, ReviewView.saveChanges));
        await tester.pumpAndSettle();
        expect(backend.forms.last.jobTitle, 'Head of research');
        await outlastToast(tester);
      });
    });
  });

  group('Import', () {
    testWidgets('a phone has "Import contacts…" in More actions; it opens myData\'s Import', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(backendWith([benOwned()])));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MoreActionsButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ContactsHome.importLabel));
      await tester.pumpAndSettle();
      expect(opened, [const OpenMyDataImport()]);
    });
  });
}
