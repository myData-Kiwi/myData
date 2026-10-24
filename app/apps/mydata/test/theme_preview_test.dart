// myData in the theme preview harness (mydata_testing's themePreview; app/tool/preview_themes.sh): Settings,
// Sources, in any theme file and palette, light and dark, off-screen; with `--all-screens`, Status, Import
// and Settings, Appearance too.
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/import/import_text.dart';
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  themePreview('mydata', [
    // Settings, Sources: This Mac with calendars denied, groups, switches, a status and a disclosure.
    ThemeScreen(
      'settings',
      (t) => mac.app(mac.realHost(mac: macSource(calendars: 'denied', counts: SyncCounts(contacts: 412))), t),
      before: (tester) => mac.openSettings(tester, SettingsTab.sources),
    ),
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
  ]);
}
