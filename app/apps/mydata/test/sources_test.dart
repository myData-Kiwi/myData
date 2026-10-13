// This Mac (first-run step, Settings, Sources) and following an iCloud account, against a fake host with
// invented data only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/source_list.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata/src/setup_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

const rejected =
    'Apple did not accept this sign-in. Use the email of your Apple Account, which may differ from an address '
    'on your own domain, and an app-specific password made at account.apple.com.';

/// The controller of the last [pumpApp], to stand in for a status poll (`controller.refresh()`).
late HostController lastController;

/// The app against [host], tall enough that most of Settings shows without scrolling.
Future<FakeMacSystem> pumpApp(WidgetTester tester, FakeHost host, {FakeMacSystem? system}) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final mac = system ?? FakeMacSystem();
  final controller = lastController = host.controller();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MyDataApp(controller: controller, store: MemoryDeviceStore(), macSystem: mac));
  await settle(tester);
  return mac;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await settle(tester);
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// The requests to This Mac's routes and the accounts, in order.
List<String> sourceRequests(FakeHost host) => [
  for (final r in host.requests)
    if (r.contains('/sources/mac') || r.contains('/accounts')) r,
];

/// The switch of the GroupedRow.toggle titled [title].
bool switchOf(WidgetTester tester, String title) {
  final row = tester.widget<GroupedRow>(find.ancestor(of: find.text(title), matching: find.byType(GroupedRow)).first);
  return row.switchValue!;
}

void main() {
  group('first run on a Mac host', () {
    testWidgets('Allow turns This Mac on, then asks for contacts, then calendars, and moves on', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false, decided: false));
      await pumpApp(tester, host);
      expect(find.text(ThisMacStep.title), findsOneWidget);
      expect(find.text(ThisMacStep.sentence), findsOneWidget);

      await tester.tap(find.text(ThisMacStep.allowLabel));
      await settle(tester);
      expect(sourceRequests(host), [
        'PUT /sources/mac/reader {"path":"/Applications/myData.app/Contents/Helpers/myDataReader.app"}',
        'PUT /sources/mac {"calendars":null,"contact_containers":null,"enabled":true}',
        'POST /sources/mac/request-access {"what":"contacts"}',
        'POST /sources/mac/request-access {"what":"calendars"}',
      ]);
      expect(find.text(ThisMacStep.title), findsNothing);
      expect(find.text('myData is ready'), findsOneWidget);
    });

    testWidgets('a "Don\'t Allow" answer keeps the step and says what myData cannot read', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false, decided: false))
        ..accessAnswers = {'contacts': 'authorized', 'calendars': 'denied'};
      final system = await pumpApp(tester, host);
      await tester.tap(find.text(ThisMacStep.allowLabel));
      await settle(tester);
      expect(find.text(ThisMacStep.shortTitle), findsOneWidget);
      expect(
        find.text(
          'myData can read your contacts but not your calendars. You can turn access on later in System '
          'Settings, Privacy & Security, Calendars.',
        ),
        findsOneWidget,
      );
      expect(find.text('myData is ready'), findsNothing);
      await tester.tap(find.text(ThisMacStep.openSettingsLabel));
      await settle(tester);
      expect(system.opened, [PrivacyPane.calendars]);
      await tester.tap(find.text(ThisMacStep.continueLabel));
      await settle(tester);
      expect(find.text('myData is ready'), findsOneWidget);
    });

    testWidgets('while it waits for the answer, the person can continue without waiting', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false, decided: false))..accessGate = Completer<void>();
      await pumpApp(tester, host);
      await tester.tap(find.text(ThisMacStep.allowLabel));
      await settle(tester);
      expect(find.text(ThisMacStep.waitingTitle), findsOneWidget);
      await tester.tap(find.text(ThisMacStep.continueWithoutWaiting));
      await settle(tester);
      expect(find.text('myData is ready'), findsOneWidget);
      // The prompt is answered later: the app has moved on and stays where it is.
      host.accessGate!.complete();
      await settle(tester);
      expect(find.text('myData is ready'), findsOneWidget);
      expect(host.requests.where((r) => r.contains('request-access')), hasLength(2));
    });

    testWidgets('Skip leaves This Mac off and records the choice', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false, decided: false));
      await pumpApp(tester, host);
      await tester.tap(find.text(ThisMacStep.skipLabel));
      await settle(tester);
      expect(
        sourceRequests(host).last,
        'PUT /sources/mac {"calendars":null,"contact_containers":null,"enabled":false}',
      );
      expect(host.mac!.decided, isTrue);
      expect(host.requests.where((r) => r.contains('request-access')), isEmpty);
      expect(find.text('myData is ready'), findsOneWidget);
    });

    testWidgets('comes after the theme step', (tester) async {
      final host = FakeHost(chosen: false, mac: macSource(enabled: false, decided: false));
      await pumpApp(tester, host);
      expect(find.text(ThemeStep.title), findsOneWidget);
      await tapVisible(tester, find.text(ThemeStep.useLabel));
      expect(find.text(ThisMacStep.title), findsOneWidget);
    });

    testWidgets('a host that lists no This Mac source does not ask', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false, decided: false));
      host.mac = null; // every This Mac route answers 404 from now on
      host.status.macAvailable = true;
      await pumpApp(tester, host);
      // GET /sources said nothing about This Mac, so there is nothing to ask.
      expect(find.text(ThisMacStep.title), findsNothing);
    });

    testWidgets('is not asked once decided, nor on a host that is not a Mac', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource(enabled: false)));
      expect(find.text(ThisMacStep.title), findsNothing);
      expect(find.text('Status'), findsWidgets);

      final other = FakeHost();
      await pumpApp(tester, other);
      expect(find.text(ThisMacStep.title), findsNothing);
      expect(other.requests.where((r) => r.contains('/sources')), isEmpty);
    });

    testWidgets('a build without the helper reports no path', (tester) async {
      final host = FakeHost(mac: macSource());
      await pumpApp(tester, host, system: FakeMacSystem(helper: null));
      expect(host.requests.where((r) => r.contains('/sources/mac/reader')), isEmpty);
    });
  });

  test('what Allow ended with, in one sentence', () {
    expect(ThisMacStep.shortfall('authorized', 'fullAccess'), isNull);
    final calendars = ThisMacStep.shortfall('authorized', 'writeOnly')!;
    expect(calendars.message, startsWith('myData can read your contacts but not your calendars. '));
    expect(calendars.pane, PrivacyPane.calendars);
    final contacts = ThisMacStep.shortfall('denied', 'fullAccess')!;
    expect(
      contacts.message,
      'myData can read your calendars but not your contacts. You can turn access on later in System Settings, '
      'Privacy & Security, Contacts.',
    );
    expect(contacts.pane, PrivacyPane.contacts);
    final both = ThisMacStep.shortfall('denied', 'denied')!;
    expect(both.message, contains('cannot read your contacts or your calendars'));
    expect(both.message, endsWith('Privacy & Security, Contacts and Calendars.'));
    final restricted = ThisMacStep.shortfall('restricted', 'fullAccess')!;
    expect(restricted.message, contains('A restriction set on this Mac'));
    expect(restricted.pane, isNull);
    // No answer yet (the host stopped waiting): nothing to change in System Settings.
    final unanswered = ThisMacStep.shortfall('authorized', 'notDetermined')!;
    expect(unanswered.message, endsWith('You can allow it later in Settings, Sources.'));
    expect(unanswered.pane, isNull);
  });

  group('the reader helper\'s path', () {
    testWidgets('is reported again when the host restarts', (tester) async {
      final host = FakeHost(mac: macSource());
      await pumpApp(tester, host);
      List<String> reports() => [
        for (final r in host.requests)
          if (r.startsWith('PUT /sources/mac/reader')) r,
      ];
      expect(reports(), hasLength(1));
      host.status.uptimeSeconds = 40; // the same host run
      await lastController.refresh();
      await settle(tester);
      expect(reports(), hasLength(1));
      host.status.uptimeSeconds = 2; // the host restarted
      await lastController.refresh();
      await settle(tester);
      expect(reports(), hasLength(2));
    });

    testWidgets('is sent again at the next poll when the host did not take it', (tester) async {
      final host = FakeHost(mac: macSource())..failReader = 1;
      await pumpApp(tester, host);
      List<String> reports() => [
        for (final r in host.requests)
          if (r.startsWith('PUT /sources/mac/reader')) r,
      ];
      expect(reports(), hasLength(1)); // failed
      await lastController.refresh();
      await settle(tester);
      expect(reports(), hasLength(2)); // taken
      await lastController.refresh();
      await settle(tester);
      expect(reports(), hasLength(2)); // not repeated
    });
  });

  testWidgets('the step shows what failed and offers to try again or continue', (tester) async {
    var calls = 0;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: MyDataTheme().light,
        home: Scaffold(
          body: ThisMacStep(
            onAllow: () async {
              calls++;
              throw ApiException(504, '{"detail":"The reader did not start."}');
            },
            onSkip: () async {},
            onDone: () => done = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text(ThisMacStep.allowLabel));
    await tester.pump();
    await tester.pump();
    expect(find.text(ThisMacStep.failedTitle), findsOneWidget);
    expect(find.text('The reader did not start.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    await tester.tap(find.text('Continue'));
    expect(done, isTrue);
  });

  group('Settings, Sources', () {
    testWidgets('off: This Mac says what it does; turning it on asks for nothing yet', (tester) async {
      final host = FakeHost(mac: macSource(enabled: false));
      await pumpApp(tester, host);
      await openSettings(tester);
      expect(find.text(SourcesSections.heading), findsOneWidget);
      expect(find.text(ThisMacText.off), findsOneWidget);
      expect(switchOf(tester, ThisMacText.title), isFalse);
      expect(find.text(SourcesSections.includedHeading), findsNothing);

      await tapVisible(tester, find.text(ThisMacText.title));
      expect(sourceRequests(host).last, 'PUT /sources/mac {"calendars":null,"contact_containers":null,"enabled":true}');
      expect(switchOf(tester, ThisMacText.title), isTrue);
      expect(find.text(ThisMacText.allow), findsNWidgets(2));
      expect(host.requests.where((r) => r.contains('request-access')), isEmpty);
    });

    testWidgets('on, with everything included, and what is never included', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource()));
      await openSettings(tester);
      expect(find.text('Last updated 13 Oct 2026, 09:12'), findsOneWidget);
      expect(find.text('Allowed'), findsNWidgets(2));
      expect(find.text(SourcesSections.includedHeading), findsOneWidget);
      for (final name in ['iCloud', 'On My Mac', 'Home', 'Work', 'Example Book Club']) {
        expect(switchOf(tester, name), isTrue, reason: name);
      }
      expect(
        find.text('Notes on contacts are not included. Events are kept from 13 Oct 2025 to 13 Oct 2028.'),
        findsOneWidget,
      );
    });

    testWidgets('leaving out a calendar sends the others and keeps the contact choice', (tester) async {
      final host = FakeHost(mac: macSource());
      await pumpApp(tester, host);
      await openSettings(tester);
      await tapVisible(tester, find.text('Work'));
      expect(
        sourceRequests(host).last,
        'PUT /sources/mac {"calendars":["k-club","k-home"],"contact_containers":null,"enabled":null}',
      );
      expect(switchOf(tester, 'Work'), isFalse);

      // Taking it back in returns to "everything", which includes calendars added later.
      await tapVisible(tester, find.text('Work'));
      expect(sourceRequests(host).last, 'PUT /sources/mac {"calendars":null,"contact_containers":null,"enabled":null}');
    });

    testWidgets('leaving out an account keeps the calendar choice as it is', (tester) async {
      final host = FakeHost(mac: macSource(leftOut: {'k-work'}));
      await pumpApp(tester, host);
      await openSettings(tester);
      await tapVisible(tester, find.text('On My Mac'));
      expect(
        sourceRequests(host).last,
        'PUT /sources/mac {"calendars":["k-club","k-home"],"contact_containers":["c-online"],"enabled":null}',
      );
    });

    testWidgets('denied: says why, and opens System Settings at Calendars', (tester) async {
      final host = FakeHost(mac: macSource(calendars: 'denied'));
      final system = await pumpApp(tester, host);
      await openSettings(tester);
      // "Included from this Mac" says calendars cannot be read, and keeps no window of events.
      expect(find.text('Calendars appear here once myData may read them.'), findsOneWidget);
      expect(find.text(ThisMacText.notes), findsOneWidget);
      expect(find.textContaining('Events are kept'), findsNothing);
      expect(switchOf(tester, 'iCloud'), isTrue);
      expect(
        find.text(
          'myData cannot read your calendars because access was turned off. Turn it on in System Settings, '
          'Privacy & Security, Calendars.',
        ),
        findsOneWidget,
      );
      expect(find.text('Off'), findsOneWidget);
      await tapVisible(tester, find.text(ThisMacText.openSettings));
      expect(system.opened, [PrivacyPane.calendars]);
    });

    testWidgets('not asked yet: Allow access shows the prompt for that kind only', (tester) async {
      final host = FakeHost(mac: macSource(contacts: 'notDetermined'));
      await pumpApp(tester, host);
      await openSettings(tester);
      expect(find.text('Not asked yet'), findsOneWidget);
      await tapVisible(tester, find.text(ThisMacText.allow));
      expect(sourceRequests(host).last, 'POST /sources/mac/request-access {"what":"contacts"}');
      expect(find.text('Allowed'), findsNWidgets(2));
      expect(find.text(ThisMacText.allow), findsNothing);
    });

    testWidgets('turning it off asks first, saying what is deleted', (tester) async {
      final host = FakeHost(mac: macSource());
      await pumpApp(tester, host);
      await openSettings(tester);
      await tapVisible(tester, find.text(ThisMacText.title));
      expect(find.textContaining('deletes the contacts and events it copied from this Mac'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(sourceRequests(host).where((r) => r.startsWith('PUT /sources/mac ')), isEmpty);

      await tapVisible(tester, find.text(ThisMacText.title));
      await tester.tap(find.text('Turn off This Mac'));
      await settle(tester);
      expect(
        sourceRequests(host).last,
        'PUT /sources/mac {"calendars":null,"contact_containers":null,"enabled":false}',
      );
      expect(find.text(SourcesSections.includedHeading), findsNothing);
    });

    testWidgets('a reported state myData does not know is not shown as still checking', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource(contacts: 'unknown')));
      await openSettings(tester);
      expect(find.text('Not readable'), findsOneWidget);
      expect(find.text('Contacts appear here once myData may read them.'), findsOneWidget);
    });

    testWidgets('the same kind of thing has the same tile tone', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource(), accounts: [icloudSource('sam@example.com')]));
      await openSettings(tester);
      MyDataTone toneOf(Finder title) {
        final row = find.ancestor(
          of: title,
          matching: find.byWidgetPredicate((w) => w is GroupedRow || w is ActionRow),
        );
        final w = tester.widget(row.first);
        return w is GroupedRow ? w.tone : (w as ActionRow).tone;
      }

      // Sources: This Mac and the followed accounts.
      expect(toneOf(find.text(ThisMacText.title)), MyDataTone.neutral);
      expect(toneOf(find.text('sam@example.com')), MyDataTone.neutral);
      // Kinds of data, under Sources and under Included from this Mac.
      for (final title in ['Contacts', 'Calendars', 'iCloud', 'On My Mac', 'Home', 'Work']) {
        expect(toneOf(find.text(title).first), MyDataTone.accent, reason: title);
      }
    });

    testWidgets('a host that is not a Mac has no This Mac row; iCloud is the way, with the filled button', (
      tester,
    ) async {
      await pumpApp(tester, FakeHost());
      await openSettings(tester);
      expect(find.text(ThisMacText.title), findsNothing);
      expect(find.text(SourcesSections.advancedHeading), findsNothing);
      expect(find.text(SourcesSections.heading), findsOneWidget);
      expect(find.text(IcloudSection.title), findsOneWidget);
      final button = tester.widget<Button>(find.widgetWithText(Button, IcloudSection.followLabel));
      expect(button.variant, ButtonVariant.filled);
    });

    testWidgets('on a Mac host, iCloud is under Advanced, with a tonal button', (tester) async {
      await pumpApp(tester, FakeHost(mac: macSource()));
      await openSettings(tester);
      expect(find.text(SourcesSections.advancedHeading), findsOneWidget);
      final button = tester.widget<Button>(find.widgetWithText(Button, IcloudSection.followLabel));
      expect(button.variant, ButtonVariant.tonal);
    });
  });

  group('Follow an iCloud account', () {
    Future<void> fill(WidgetTester tester, String email, String password) async {
      await tester.enterText(find.widgetWithText(MyDataTextField, 'Apple Account email'), email);
      await tester.enterText(find.widgetWithText(MyDataTextField, 'App-specific password'), password);
      await tester.pump();
    }

    testWidgets('a rejected sign-in shows the host\'s message, and never the password', (tester) async {
      final host = FakeHost()..rejectAccount = rejected;
      await pumpApp(tester, host);
      await openSettings(tester);
      await fill(tester, 'sam@example.com', 'abcd-efgh-ijkl-mnop');
      await tapVisible(tester, find.text(IcloudSection.followLabel));
      expect(find.text(rejected), findsOneWidget);
      // Only in its obscured field: no text on screen shows it.
      expect(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('abcd-efgh')), findsNothing);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(MyDataTextField, 'App-specific password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.obscureText, isTrue);
      // The person can correct the email and try again.
      expect(find.text('sam@example.com'), findsOneWidget);
    });

    testWidgets('a followed account is listed; the fields are cleared', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      await openSettings(tester);
      await fill(tester, 'sam@example.com', 'abcd-efgh-ijkl-mnop');
      await tapVisible(tester, find.text(IcloudSection.followLabel));
      expect(
        host.requests.where((r) => r.startsWith('POST /accounts')).single,
        'POST /accounts {"email":"sam@example.com","password":"abcd-efgh-ijkl-mnop","provider":"icloud"}',
      );
      expect(find.text('sam@example.com'), findsOneWidget); // the account row, not the field
      expect(find.text('Last synced 13 Oct 2026, 08:40'), findsOneWidget);
    });

    testWidgets('Sync now, and Remove after saying that the mirrored data is deleted', (tester) async {
      final host = FakeHost(accounts: [icloudSource('sam@example.com')]);
      await pumpApp(tester, host);
      await openSettings(tester);
      await tapVisible(tester, find.text('Sync now'));
      expect(sourceRequests(host).last, 'POST /accounts/acct-sam/sync');

      await tapVisible(tester, find.text(RemoveAccountText.ask));
      expect(find.text(RemoveAccountText.body('sam@example.com')), findsOneWidget);
      await tester.tap(find.text(RemoveAccountText.confirm));
      await settle(tester);
      expect(sourceRequests(host).last, 'DELETE /accounts/acct-sam');
      expect(find.text('sam@example.com'), findsNothing);
    });
  });

  test('MacChoice sets every field, so nothing is left out by accident', () {
    expect(MacChoice.turn(on: true).toJson(), {'calendars': null, 'contact_containers': null, 'enabled': true});
  });
}
