// myData's key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// status in every theme as goldens (test/screenshots/theme_status.*). Every theme file, palette and screen for
// review: the preview harness (theme_preview_test.dart).
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  final status = ThemeScreen('status', (t) => mac.app(mac.realHost(), t), before: settle);
  themeScreens(status);

  // Large's 52 px targets reach the Mac window's own controls: the toolbar, the switches, the segments.
  themeTargets(status);

  // The smallest window, in the largest type and the heaviest edges.
  themeNarrow(status);
  themeTargets(ThemeScreen(
    'settings',
    (t) => mac.app(mac.realHost(mac: macSource(calendars: 'denied', counts: SyncCounts(contacts: 412))), t),
    before: (tester) => mac.openSettings(tester, SettingsTab.sources),
  ));
  for (final tab in [SettingsTab.appearance, SettingsTab.assistant]) {
    themeTargets(ThemeScreen(tab.name, (t) => mac.app(mac.realHost(), t), before: (tester) => mac.openSettings(tester, tab)));
  }

  // The pictures above differ by more than colour between every two themes.
  themesDistinct('status', alike: {
    // 0.26: two paper themes with a serif, italic secondary text and the same rows; what sets Notebook
    // apart here (its ruled paper, 12% lines a step under the metric's, the handwritten titles, unboxed
    // groups and the highlighter) mostly falls inside the same blocks. They score 0.3 or more elsewhere.
    'notebook and paperback': (0.26, 'ruled paper under the edge step'),
    // 0.28: both rule every row in ink and draw Inter-like grotesk titles; Brutalist's boxes, 3 px edges and
    // offset shadows on a grey ground against Swiss's open white page are set apart by more than the metric's
    // 16 px blocks see, since the rules fall in the same rows. They score 0.3 or more elsewhere.
    'brutalist and swiss': (0.28, 'ink rules in the same rows'),
  });
}
