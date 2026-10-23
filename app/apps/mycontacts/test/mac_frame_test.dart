// The Mac frame (MacLook) of myContacts: its behaviour, and screenshots at 1280x800 in light and dark
// (test/screenshots/mac_*.png), with the bundled Figtree under the system font's names (loadMacFonts); refresh
// with `flutter test --update-goldens test/mac_frame_test.dart` on a Mac.
//
// The Mac frame's accent is the system's. The screenshots are made with the system's accent set to the Kiwi
// and the Graphite themes' accents (the channel the Runner answers, mocked: [withSystemAccent]), as the plan's
// accent options will set it, in light and dark: mac_*.kiwi-light.png ... mac_*.graphite-dark.png.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contact_actions.dart';
import 'package:mycontacts/src/contact_editor.dart';
import 'package:mycontacts/src/contact_form.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mycontacts/src/contacts_view.dart';
import 'package:mycontacts/src/home.dart';
import 'package:mycontacts/src/mac_contact_page.dart';
import 'package:mycontacts/src/merge_pane.dart';
import 'package:mycontacts/src/review_view.dart';
import 'package:mycontacts/src/trash_view.dart';
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

Widget app(ThemeCase t, {String? lastOpened, FakeBackend? backend, bool anyOn = true}) {
  withSystemAccent(t.themeId);
  return MyContactsApp(
    host: FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(theme: t.themeId, real: anyOn)),
    store: MemoryDeviceStore({
      'mode': t.brightness.name,
      'lastTheme': t.themeId,
      ContactsController.lastOpenedKey: ?lastOpened,
    }),
    backend: backend ?? people(),
    links: const Stream.empty(),
    onOpenLink: (_) {},
  );
}

/// The system's colours as the Runner reports them (MacSystemColorsScope's channel), with the accent, the
/// text on it and the focus ring set to [themeId]'s in each appearance: what the Mac frame draws when the
/// system's accent is that colour.
void withSystemAccent(String themeId) {
  int argb(Color c) => c.toARGB32();
  Map<String, int> appearance(Brightness b) {
    final colors = MyDataTheme.data(themeId, b).extension<MyDataColors>()!;
    return {
      'accent': argb(colors.accent),
      'on-accent': argb(colors.onAccent),
      'focus-ring': argb(colors.accent.withValues(alpha: 0.5)),
    };
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MacSystemColorsScope.channel,
    (call) async => call.method == 'get'
        ? {'light': appearance(Brightness.light), 'dark': appearance(Brightness.dark)}
        : null,
  );
}

/// The screenshots' four cases: the Kiwi and the Graphite accents, light and dark.
const accentMatrix = themeMatrix;

/// Lets the app read the device's mode, the host's theme and the contacts, and decode the photos.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A Mac form's field by its accessible name.
Finder _field(String label) => find.byWidgetPredicate((w) => w is MacEditField && w.label == label);

/// Pip, whom the host owns, open in the Mac editor.
Future<void> _editPip(WidgetTester tester) async {
  await settle(tester);
  await _showRow(tester, 'Pip Owned');
  await tester.tap(_row('Pip Owned'));
  await settle(tester);
  await tester.tap(find.byWidgetPredicate((w) => w is MacToolbarButton && w.label == ContactActions.editLabel));
  await settle(tester);
}

/// Pip and Quinn selected, the Menu opened on Quinn's row with a right-click.
Future<void> _selectPipAndQuinn(WidgetTester tester, {bool menu = true}) async {
  await settle(tester);
  await _showRow(tester, 'Pip Owned');
  await tester.tap(_row('Pip Owned'));
  await settle(tester);
  await _showRow(tester, 'Quinn Owned');
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.tap(_row('Quinn Owned'));
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await settle(tester);
  if (!menu) return;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await mouse.down(tester.getCenter(_row('Quinn Owned')));
  await mouse.up();
  await settle(tester);
}

/// Pip deleted with the Delete key, then Recently Deleted shown once the toast has gone.
Future<void> _deletePipAndShowTrash(WidgetTester tester) async {
  await settle(tester);
  await _showRow(tester, 'Pip Owned');
  await tester.tap(_row('Pip Owned'));
  await settle(tester);
  // ⌘⌫, as on a Mac (the plain Delete key is not the list's delete there).
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await settle(tester);
  await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Recently Deleted')));
  await settle(tester);
  await tester.pump(const Duration(seconds: 9));
  await settle(tester);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacSystemColorsScope.channel, null);
  });

  group('the Mac frame', () {
    macTestWidgets('draws the source list, the plain list and the contact page', (tester) async {
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

    macTestWidgets('the toolbar search filters the list', (tester) async {
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

    macTestWidgets('Edit in the toolbar opens the inspector for an owned contact, not for a followed one',
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
      expect(_field('First name'), findsOneWidget);
    });

    macTestWidgets('the sidebar changes section with a click and with the arrow keys', (tester) async {
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

    macTestWidgets('a phone-sized window keeps the branded phone layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(macMatrix.first));
      await settle(tester);
      expect(find.byType(MacSourceList), findsNothing);
    });
  });

  group('the Mac forms', () {
    Future<FakeBackend> open(WidgetTester tester, {FakeBackend? backend}) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = backend ?? people();
      await tester.pumpWidget(app(macMatrix.first, lastOpened: 'c-ava', backend: b));
      return b;
    }

    macTestWidgets('the editor is laid out as Contacts\' card and saves the whole form', (tester) async {
      final b = await open(tester);
      await _editPip(tester);
      // The label column holds each value's label as a pop-up, in Contacts' lower case.
      expect(find.byWidgetPredicate((w) => w is MacPopUpButton<String> && w.shown == 'mobile'), findsOneWidget);
      expect(find.byType(MyDataTextField), findsNothing);
      await tester.enterText(_field('First name'), 'Pippa');
      await tester.tap(find.text('Add phone'));
      await settle(tester);
      // A new row takes the next label, and focus goes to its value.
      final added = _field('Home, phone number');
      expect(added, findsOneWidget);
      await tester.enterText(added, '555-0199');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(b.writes, contains('update c-pip'));
      expect(b.forms.last.givenName, 'Pippa');
      expect([for (final p in b.forms.last.phones!) '${p.label} ${p.value}'], ['Mobile 555-0142', 'Home 555-0199']);
      expect(find.byType(MacContactPage), findsOneWidget);
    });

    macTestWidgets('a label\'s pop-up changes it, and Custom label… asks for one in an alert', (tester) async {
      final b = await open(tester);
      await _editPip(tester);
      await tester.tap(find.text('mobile'));
      await settle(tester);
      await tester.tap(find.text('work').last);
      await settle(tester);
      expect(find.byWidgetPredicate((w) => w is MacPopUpButton<String> && w.shown == 'work'), findsWidgets);
      await tester.tap(find.byWidgetPredicate((w) => w is MacPopUpButton<String> && w.label == 'Label for phone 1'));
      await settle(tester);
      await tester.tap(find.text(MacPopUpButton.defaultCustomLabel));
      await settle(tester);
      expect(find.text(ContactEditor.customLabelTitle), findsOneWidget);
      await tester.enterText(_field(ContactEditor.customLabelField), 'Studio');
      await tester.tap(find.text(ContactEditor.customLabelConfirm));
      await settle(tester);
      expect(find.byWidgetPredicate((w) => w is MacPopUpButton<String> && w.shown == 'Studio'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(b.forms.last.phones!.single.label, 'Studio');
    });

    macTestWidgets('removing a value sends the form without it', (tester) async {
      final b = await open(tester);
      await _editPip(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is MacRemoveButton && w.label == 'Remove mobile number'));
      await settle(tester);
      expect(_field('Mobile, phone number'), findsNothing);
      // Focus goes to the kind's Add button, the last row having gone.
      expect(FocusManager.instance.primaryFocus?.debugLabel, ValueKind.phone.addLabel);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(b.forms.last.phones ?? const [], isEmpty);
    });

    macTestWidgets('a wrong value shows its error under the field and nothing is sent', (tester) async {
      final b = await open(tester);
      await _editPip(tester);
      await tester.enterText(_field('Work, email address'), 'pip@example');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(tester.widget<MacEditField>(_field('Work, email address')).error, isNotNull);
      expect(b.writes, isNot(contains('update c-pip')));
    });

    macTestWidgets('the menus are in the Mac\'s title case and Merge opens the Mac pane', (tester) async {
      final b = await open(tester);
      await _selectPipAndQuinn(tester);
      expect(find.text('Delete 2 Contacts…'), findsOneWidget);
      await tester.tap(find.text('Merge Contacts…'));
      await settle(tester);
      expect(find.byType(MacPairTable), findsOneWidget);
      expect(find.byType(DuplicatePair), findsNothing);
      await tester.ensureVisible(find.text(MergePane.mergeLabel));
      await settle(tester);
      await tester.tap(find.text(MergePane.mergeLabel));
      await settle(tester);
      expect(b.writes.where((w) => w.startsWith('merge ')), hasLength(1));
    });

    macTestWidgets('Delete permanently asks in an alert, then deletes for good', (tester) async {
      final b = await open(tester);
      await _deletePipAndShowTrash(tester);
      await tester.tap(find.text(TrashView.purgeLabel));
      await settle(tester);
      // The alert shows the app's own icon, Cancel is its default button (the accent, and focus, so Return
      // presses it), and Delete is a push button.
      expect(find.byWidgetPredicate((w) => w is Image && w.image == MyDataAppIcons.mycontacts), findsOneWidget);
      expect(find.byType(KiwiTile), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(b.writes, isNot(contains('purge c-pip')), reason: 'Return is Cancel in a destructive alert');
      await tester.tap(find.text(TrashView.purgeLabel));
      await settle(tester);
      await tester.tap(find.text('Delete permanently'));
      await settle(tester);
      expect(b.writes, contains('purge c-pip'));
    });

    macTestWidgets('Review\'s changes are a Mac table with a pop-up per differing row', (tester) async {
      final b = await open(tester, backend: reviewBackend());
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('changed:c-quinn')));
      await settle(tester);
      expect(find.byType(MacPairTable), findsOneWidget);
      expect(find.byType(MacPopUpButton<int>), findsNWidgets(2));
      await tester.tap(find.text(ReviewView.saveChanges));
      await settle(tester);
      expect(b.writes, contains('save-followed c-quinn'));
    });
  });

  group('screenshots', () {
    // The stack gate's screen: the list with an iCloud contact open (photo, notes).
    macScreenMatrix('mac_people', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix, before: settle);

    // A contact from This Mac with every kind of field but notes.
    macScreenMatrix('mac_contact_this_mac', (t) => app(t, lastOpened: 'c-aaron'), themes: accentMatrix, before: settle);

    // A contact the host owns: Edit enabled, "On myData only".
    macScreenMatrix('mac_owned', (t) => app(t, lastOpened: 'c-pip'), themes: accentMatrix, before: (tester) async {
      await settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
    });

    // The list has the keyboard: the selection in the accent.
    macScreenMatrix('mac_list_focused', (t) => app(t, lastOpened: 'c-jun'), themes: accentMatrix, before: (tester) async {
      await settle(tester);
      await tester.tap(_row('Jun Placeholder'));
      await settle(tester);
    });

    // Recently deleted.
    macScreenMatrix('mac_recently_deleted', (t) => app(t, lastOpened: 'c-pip'), themes: accentMatrix,
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
    macScreenMatrix('mac_review', (t) => app(t, lastOpened: 'c-ava', backend: reviewBackend()), themes: accentMatrix,
        before: (tester) async {
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await settle(tester);
    });

    // New contact: the editor as Contacts' card in edit mode, a name typed and a phone added.
    macScreenMatrix('mac_inspector_new', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await settle(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is MacToolbarButton && w.label == ContactActions.newLabel));
      await settle(tester);
      await tester.enterText(_field('First name'), 'Nia');
      await tester.enterText(_field('Last name'), 'Newcomb');
      await tester.tap(find.text('Add phone'));
      await settle(tester);
      await tester.enterText(_field('Mobile, phone number'), '+1 555 0177');
      await settle(tester);
    });

    // Editing Pip: an incomplete email, shown under its field after Save, which sent nothing.
    macScreenMatrix('mac_inspector_error', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await _editPip(tester);
      await tester.enterText(_field('Work, email address'), 'pip@example');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);
    });

    // A value's label pop-up, open.
    macScreenMatrix('mac_label_menu', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await _editPip(tester);
      await tester.tap(find.text('mobile'));
      await settle(tester);
    });

    // The Menu on two selected contacts.
    macScreenMatrix('mac_context_menu', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: _selectPipAndQuinn);

    // Merge from the selection: the Mac pane.
    macScreenMatrix('mac_merge', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix, before: (tester) async {
      await _selectPipAndQuinn(tester);
      await tester.tap(find.text('Merge Contacts…'));
      await settle(tester);
    });

    // Pip deleted with the Delete key: the toast with Undo.
    macScreenMatrix('mac_undo_toast', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await settle(tester);
    });

    // Delete permanently: the alert.
    macScreenMatrix('mac_purge_alert', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await _deletePipAndShowTrash(tester);
      await tester.tap(find.text(TrashView.purgeLabel));
      await settle(tester);
    });

    // Review: Quinn changed in a followed iCloud account since the import.
    macScreenMatrix('mac_review_changes', (t) => app(t, lastOpened: 'c-ava', backend: reviewBackend()),
        themes: accentMatrix, before: (tester) async {
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('changed:c-quinn')));
      await settle(tester);
    });

    // Quinn's page: the "changed since import" Notice under the header.
    macScreenMatrix('mac_contact_changed', (t) => app(t, lastOpened: 'c-quinn', backend: reviewBackend()),
        themes: accentMatrix, before: settle);

    // Review with nothing in it.
    macScreenMatrix('mac_review_empty', (t) => app(t, lastOpened: 'c-ava'), themes: accentMatrix,
        before: (tester) async {
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await settle(tester);
    });

    // No contacts and no source: the empty state with the kiwi.
    macScreenMatrix('mac_no_contacts', (t) => app(t, backend: FakeBackend(cards: const [], anyOn: false), anyOn: false),
        themes: accentMatrix, before: settle);

    // Several selected: the count and the actions in the contact column. (Ctrl-click: the tests run as
    // Android, where Ctrl is the command key.)
    macScreenMatrix('mac_several_selected', (t) => app(t, lastOpened: 'c-pip'), themes: accentMatrix,
        before: (tester) async {
      await settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await settle(tester);
      for (final name in ['Quinn Owned', 'Omar Sample']) {
        await _showRow(tester, name);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.tap(_row(name));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
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
