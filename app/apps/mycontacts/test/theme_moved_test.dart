// A device whose myContacts drew Kiwi in an old colour draws that colour's theme now (Kiwi in Plum is Journal
// in Plum, design/themes/ARCHITECTURE.md 4.2), and myContacts' own window says so, once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  setUpAll(() async => mac.portrait = await portraitPng());

  Widget app(DeviceStore store) => MyContactsApp(
    host: FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(real: true)),
    store: store,
    backend: mac.people(),
    links: const Stream.empty(),
    onOpenLink: (_) {},
  );

  for (final onMac in [true, false]) {
    testWidgets('Kiwi in Plum is Journal in Plum, and myContacts says so once (${onMac ? 'in the Mac window' : 'elsewhere'})',
        variant: onMac ? macOS : const DefaultTestVariant(), (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final before = MacLook.debugOverride;
      MacLook.debugOverride = onMac;
      addTearDown(() => MacLook.debugOverride = before);
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum'},
        },
      });
      final message = ThemeMovedNotice.message('plum', MyDataAppId.mycontacts);
      expect(message, 'Plum is now a palette of Journal, so myContacts looks different.');

      await tester.pumpWidget(app(store));
      await mac.settle(tester);
      expect(find.text(message), findsOneWidget);
      // a polite live region, so a screen reader hears it
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(find.text(message)), isNotNull);
      semantics.dispose();
      if (onMac) {
        await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screenshots/theme_moved.journal-light.png'));
      }
      // still listed for myData's Appearance until it is said there
      expect(((await store.read())['themes'] as Map)['moved'], ['plum']);

      await tester.tap(find.text(ThemeMovedNotice.okLabel));
      await mac.settle(tester);
      expect(find.text(message), findsNothing);
      expect(((await store.read())['themes'] as Map)['told'], {'plum': ['mycontacts']});

      // the next start says nothing
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app(store));
      await mac.settle(tester);
      expect(find.text(message), findsNothing);
    });
  }
}
