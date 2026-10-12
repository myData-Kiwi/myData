// Runs the myData app against a real development host, which it starts. Not part of `flutter test`:
//
//   cd host && MYDATA_HOME=/tmp/mydata-it uv run mydata dev-setup
//   cd app/apps/mydata && flutter test integration_test -d macos --dart-define=MYDATA_HOME=/tmp/mydata-it
//
// It switches the assistant off if setup offers to skip, creates and revokes an agent token, and stops
// the host at the end, so point MYDATA_HOME at a folder used only for testing.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mydata/src/agent_tokens.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata_core/mydata_core.dart';

/// Pumps real frames until [done] holds, or fails after [timeout].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String what, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

bool shows(Finder finder) => finder.evaluate().isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts the host, reaches Status, and manages agent tokens', (tester) async {
    expect(
      const String.fromEnvironment('MYDATA_HOME'),
      isNotEmpty,
      reason: 'Pass --dart-define=MYDATA_HOME=<a test-only folder>: this test stops the host it reaches.',
    );
    final controller = HostController(app: 'mydata');
    addTearDown(() async {
      await controller.stopHost();
      controller.dispose();
    });
    await tester.pumpWidget(MyDataApp(controller: controller));
    unawaited(controller.connect());

    const settled = {HostPhase.running, HostPhase.failedToStart, HostPhase.notConfigured, HostPhase.unsupported};
    await pumpUntil(tester, () => settled.contains(controller.phase), 'the host');
    expect(controller.phase, HostPhase.running, reason: '${controller.error}\n${controller.detail}');

    // Setup, if shown: skip the assistant (or continue, if its model is already ready).
    await tester.pump();
    if (shows(find.text('Skip for now'))) {
      await tester.tap(find.text('Skip for now'));
    } else if (shows(find.text('Continue'))) {
      await tester.tap(find.text('Continue'));
    }
    final version = controller.status!.version;
    await pumpUntil(tester, () => shows(find.text(version)), 'the Status screen');

    await tester.tap(find.text('Settings'));
    await pumpUntil(tester, () => shows(find.text('Agent tokens')), 'the Settings screen');
    await pumpUntil(tester, () => !shows(find.text('loading…')), 'the agent list');

    final name = 'integration test ${DateTime.now().millisecondsSinceEpoch}';
    await tester.tap(find.text('Create token'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await pumpUntil(tester, () => shows(find.byType(NewTokenDialog)), 'the new token');
    expect(find.text('Copy it now. It will not be shown again.'), findsOneWidget);
    await tester.tap(find.text('Done'));

    final row = find.ancestor(of: find.text(name), matching: find.byType(AgentTokenRow));
    await pumpUntil(tester, () => shows(row), 'the new agent in the list');
    expect(find.descendant(of: row, matching: find.text('not connected')), findsOneWidget);

    final revoke = find.descendant(of: row, matching: find.text('Revoke'));
    await tester.ensureVisible(revoke); // the settings page scrolls; the new row may be below the fold
    await tester.pumpAndSettle();
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await pumpUntil(tester, () => shows(find.descendant(of: row, matching: find.text('revoked'))), 'the revoke');
  });
}
