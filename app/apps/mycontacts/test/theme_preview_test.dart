// myContacts in the theme preview harness (mydata_testing's themePreview; app/tool/preview_themes.sh): the
// people with Ava's page open, in any theme file and palette, light and dark, off-screen; with
// `--all-screens`, a contact the host owns, Review and a new contact too.
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/contact_actions.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

Finder _row(String name) => find.descendant(of: find.byType(ContactList), matching: find.text(name, findRichText: true));

/// Scrolls the list until [name]'s row is built and in view (the list builds rows lazily).
Future<void> _showRow(WidgetTester tester, String name) async {
  for (var i = 0; i < 20 && _row(name).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ContactList), const Offset(0, -200));
    await mac.settle(tester);
  }
  await tester.ensureVisible(_row(name));
  await mac.settle(tester);
}

Finder _field(String label) => find.byWidgetPredicate((w) => w is MacEditField && w.label == label);

void main() {
  setUpAll(() async => mac.portrait = await portraitPng());

  themePreview('mycontacts', [
    ThemeScreen('people', (t) => mac.app(t, lastOpened: 'c-ava'), before: mac.settle),
    ThemeScreen('owned', (t) => mac.app(t, lastOpened: 'c-pip'), before: (tester) async {
      await mac.settle(tester);
      await _showRow(tester, 'Pip Owned');
      await tester.tap(_row('Pip Owned'));
      await mac.settle(tester);
    }),
    ThemeScreen('review', (t) => mac.app(t, lastOpened: 'c-ava', backend: mac.reviewBackend()),
        before: (tester) async {
      await mac.settle(tester);
      await tester.tap(find.descendant(of: find.byType(MacSourceList), matching: find.text('Review')));
      await mac.settle(tester);
    }),
    ThemeScreen('new_contact', (t) => mac.app(t, lastOpened: 'c-ava'), before: (tester) async {
      await mac.settle(tester);
      await tester.tap(find.byWidgetPredicate((w) => w is MacToolbarButton && w.label == ContactActions.newLabel));
      await mac.settle(tester);
      await tester.enterText(_field('First name'), 'Nia');
      await tester.enterText(_field('Last name'), 'Newcomb');
      await tester.tap(find.text('Add phone'));
      await mac.settle(tester);
      await tester.enterText(_field('Mobile, phone number'), '+1 555 0177');
      await mac.settle(tester);
    }),
  ]);
}
