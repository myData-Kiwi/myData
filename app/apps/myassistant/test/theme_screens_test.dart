// myAssistant's key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): an
// approval card in every theme as goldens (test/screenshots/theme_approval.*). Every theme file, palette and
// screen for review: the preview harness (theme_preview_test.dart).
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  // The approval card's structure stays in every theme (decision 2026-10-23): the one screen to see first.
  final approval = ThemeScreen(
    'approval',
    (t) => mac.app(t, HostPhase.running, status: hostStatus(), backend: ScriptedBackend([emailRishita()])),
    before: (tester) => mac.ask(tester, 'Email Rishita the time of my dentist appointment'),
  );
  themeScreens(approval);

  // Large's 52 px targets reach the Mac window's own controls.
  themeTargets(approval);

  // The smallest window, in the largest type and the heaviest edges.
  themeNarrow(approval);

  // The pictures above differ by more than colour between every two themes.
  themesDistinct('approval');
}
