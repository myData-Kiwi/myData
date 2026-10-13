// Whole-app screenshots in Kiwi and Graphite, light and dark: test/screenshots/<name>.<theme>-<mode>.png.
// Refresh with `flutter test --update-goldens test/screenshots_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:myassistant/src/app.dart';

import 'fixtures.dart';

/// The app as it starts on a device in [t]'s mode, with the host in [phase] reporting [t]'s theme.
Widget app(ThemeCase t, HostPhase phase, {StatusOut? status, AssistantBackend? backend}) => MyAssistantApp(
  host: FakeHost(phaseOnConnect: phase, statusOnConnect: status),
  // The device remembers the last theme seen, so the app draws in it before the host answers.
  store: MemoryDeviceStore({'mode': t.brightness.name, 'lastTheme': t.themeId}),
  backend: backend,
);

/// Lets the app read the device's mode and the host's theme, which land after the first frame, and lets
/// the theme's cross-fade finish. Frame by frame, not pumpAndSettle: the loading kiwi never settles.
Future<void> settleAppearance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> ask(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(ChatView.inputKey), text);
  await tester.tap(find.byKey(ChatView.sendKey));
  await tester.pumpAndSettle();
}

void main() {
  screenMatrix(
    'chat',
    (t) => app(t, HostPhase.running,
        status: hostStatus(theme: t.themeId), backend: ScriptedBackend([freeAtSixThirty()])),
    before: (tester) => ask(tester, 'Am I free at 6:30 tomorrow?'),
  );

  screenMatrix(
    'approval',
    (t) => app(t, HostPhase.running,
        status: hostStatus(theme: t.themeId), backend: ScriptedBackend([emailRishita()])),
    before: (tester) => ask(tester, 'Email Rishita the time of my dentist appointment'),
  );

  screenMatrix(
    'assistant_off',
    (t) => app(t, HostPhase.running,
        status: hostStatus(theme: t.themeId, enabled: false, state: ModelOutStateEnum.disabled)),
    before: settleAppearance,
  );

  // The off screen after myData could not be opened from here: the notice names Settings, as the button does.
  screenMatrix(
    'assistant_off_notice',
    (t) => app(t, HostPhase.running,
        status: hostStatus(theme: t.themeId, enabled: false, state: ModelOutStateEnum.disabled)),
    before: (tester) async {
      await settleAppearance(tester);
      await tester.tap(find.widgetWithText(Button, AssistantUnavailable.offAction));
      await settleAppearance(tester);
    },
  );

  screenMatrix('host_starting', (t) => app(t, HostPhase.starting), before: settleAppearance);

  // The web build: the panel alone, with no frame and no Retry.
  screenMatrix('web_build', (t) => app(t, HostPhase.unsupported), before: settleAppearance);
}
