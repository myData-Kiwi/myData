// myContacts' key screen in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): the
// people list with a contact open in every theme as goldens (test/screenshots/theme_people.*). Every theme
// file, palette and screen for review: the preview harness (theme_preview_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  setUpAll(() async => mac.portrait = await portraitPng());

  final people = ThemeScreen('people', (t) => mac.app(t, lastOpened: 'c-ava'), before: mac.settle);
  themeScreens(people);

  // Large's 52 px targets reach the Mac window's own controls: the toolbar, the record's actions.
  themeTargets(people);

  // The pictures above differ by more than colour between every two themes.
  themesDistinct('people');
}
