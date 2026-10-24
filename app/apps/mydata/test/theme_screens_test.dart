// myData's key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// status in every theme as goldens (test/screenshots/theme_status.*). Every theme file, palette and screen for
// review: the preview harness (theme_preview_test.dart).
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  themeScreens(ThemeScreen('status', (t) => mac.app(mac.realHost(), t), before: settle));

  // The pictures above differ by more than colour between every two themes.
  themesDistinct('status');
}
