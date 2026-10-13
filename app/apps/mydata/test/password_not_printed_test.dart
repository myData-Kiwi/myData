// An account password never reaches anything the app prints or logs: debugPrint, the zone's print, or
// FlutterError's output. The iCloud form is filled with a password no other string contains and submitted
// to a fake host, once accepted and once refused. Invented data only.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// Unlike any other text in the app or the fake host.
const password = 'zq7v-kiwi-unique-pw-41x9';

const refused = 'Apple did not accept this sign-in.';

/// Runs [body] with every printed line, debugPrint line and FlutterError report collected in [out], and puts
/// the originals back afterwards (before the test's own checks of the foundation globals).
Future<void> capturing(List<String> out, Future<void> Function() body) async {
  final debugPrintBefore = debugPrint;
  final onErrorBefore = FlutterError.onError;
  debugPrint = (String? message, {int? wrapWidth}) {
    out.add('debugPrint: $message');
    debugPrintBefore(message, wrapWidth: wrapWidth);
  };
  FlutterError.onError = (details) {
    out
      ..add('FlutterError: ${details.exceptionAsString()}')
      ..add('FlutterError: ${details.toString()}')
      ..add('FlutterError: ${details.stack}');
    onErrorBefore?.call(details);
  };
  try {
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          out.add('print: $line');
          parent.print(zone, line);
        },
      ),
    );
  } finally {
    debugPrint = debugPrintBefore;
    FlutterError.onError = onErrorBefore;
  }
}

Future<void> followWithPassword(WidgetTester tester, FakeHost host) async {
  tester.view
    ..physicalSize = const Size(1280, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = host.controller();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MyDataApp(controller: controller, store: MemoryDeviceStore(), macSystem: FakeMacSystem()));
  await settle(tester);
  await tester.tap(find.text('Settings'));
  await settle(tester);
  await tester.enterText(find.widgetWithText(MyDataTextField, 'Apple Account email'), 'sam@example.com');
  await tester.enterText(find.widgetWithText(MyDataTextField, 'App-specific password'), password);
  await tester.pump();
  final follow = find.text(IcloudSection.followLabel);
  await tester.ensureVisible(follow);
  await tester.pump();
  await tester.tap(follow);
  await settle(tester);
}

void main() {
  testWidgets('the capture sees what is printed', (tester) async {
    final out = <String>[];
    await capturing(out, () async {
      print('probe one'); // ignore: avoid_print
      debugPrint('probe two');
    });
    expect(out, containsAll(['print: probe one', 'debugPrint: probe two']));
  });

  for (final accepted in [true, false]) {
    testWidgets('following an account ${accepted ? 'that is accepted' : 'that Apple refuses'} '
        'never prints the password', (tester) async {
      final host = FakeHost()..rejectAccount = accepted ? null : refused;
      final out = <String>[];
      await capturing(out, () async {
        await followWithPassword(tester, host);
        // Something to show the capture was live during the run, not only around it.
        debugPrint('the form was submitted');
      });

      // The password did go to the host, so the form really was submitted with it.
      expect(host.requests.where((r) => r.startsWith('POST /accounts') && r.contains(password)), hasLength(1));
      expect(find.text(accepted ? 'sam@example.com' : refused), findsOneWidget);
      expect(out, contains('debugPrint: the form was submitted'));
      expect(tester.takeException(), isNull);
      final leaks = [for (final line in out) if (line.contains(password)) line];
      expect(leaks, isEmpty, reason: 'the password was printed or logged');
    });
  }
}
