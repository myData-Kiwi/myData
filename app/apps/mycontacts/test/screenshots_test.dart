// Whole-app screenshots in Kiwi and Graphite, light and dark: test/screenshots/<name>.<theme>-<mode>.png.
// Refresh with `flutter test --update-goldens test/screenshots_test.dart`.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contacts_controller.dart';
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
  backend: FakeBackend(anyOn: anyOn, photos: {'c-ava': portrait}),
  links: links,
  openMyDataSources: () async => true,
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

void main() {
  setUpAll(() async => portrait = await portraitPng());

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
}
