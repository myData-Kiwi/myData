// myData's key screens in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// status in every theme as goldens (test/screenshots/theme_status.*), and with
// `--dart-define=MYDATA_SHOTS=<folder> --update-goldens` every screen and palette, off-screen, for review.
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/import/import_text.dart';
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  themeScreens('mydata', [
    ThemeScreen('status', (t) => mac.app(mac.realHost(), t), before: settle),
    ThemeScreen(
      'import',
      (t) {
        final host = mac.realHost(accounts: [icloudSource('ava@example.org', counts: SyncCounts(contacts: 128))]);
        host.imports.history = [
          ImportOut(
            id: 'imp-0',
            label: 'contacts-2026-10-01.vcf',
            source_: 'file',
            startedAt: '2026-10-01T09:00:00',
            status: 'done',
            counts: {'created': 12, 'skipped': 1},
          ),
        ];
        return mac.app(host, t);
      },
      before: (tester) async {
        await settle(tester);
        await tester.tap(find.text(ImportText.section).first);
        await settle(tester);
      },
    ),
    ThemeScreen(
      'settings_appearance',
      (t) => mac.app(mac.realHost(), t),
      before: (tester) => mac.openSettings(tester, SettingsTab.appearance),
    ),
    ThemeScreen(
      'settings_sources',
      (t) => mac.app(mac.realHost(mac: macSource(calendars: 'denied', counts: SyncCounts(contacts: 412))), t),
      before: (tester) => mac.openSettings(tester, SettingsTab.sources),
    ),
  ]);
}
