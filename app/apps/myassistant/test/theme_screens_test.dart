// myAssistant's key screens in each drawn built-in, inside the Mac window (mydata_testing's themeScreens): an
// approval card in every theme as goldens (test/screenshots/theme_approval.*), and with
// `--dart-define=MYDATA_SHOTS=<folder> --update-goldens` every screen and palette, off-screen, for review.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';
import 'mac_frame_test.dart' as mac;

void main() {
  themeScreens('myassistant', [
    // The approval card's structure stays in every theme (decision 2026-10-23): the one screen to see first.
    ThemeScreen(
      'approval',
      (t) => mac.app(t, HostPhase.running, status: hostStatus(), backend: ScriptedBackend([emailRishita()])),
      before: (tester) => mac.ask(tester, 'Email Rishita the time of my dentist appointment'),
    ),
    ThemeScreen(
      'chat',
      (t) => mac.app(t, HostPhase.running, status: hostStatus(), backend: ScriptedBackend([freeAtSixThirty()])),
      before: (tester) => mac.ask(tester, 'Am I free at 6:30 tomorrow?'),
    ),
    ThemeScreen(
      'chat_links',
      (t) => mac.app(
        t,
        HostPhase.running,
        status: hostStatus(real: true),
        backend: ScriptedBackend([realLookups()]),
        apps: FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.mycalendar}).apps(),
      ),
      before: (tester) async {
        await mac.ask(tester, "Ava's number and what's on Friday?");
        tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(find.text('Dinner with Ava (invented)')));
        addTearDown(mouse.removePointer);
        await tester.pumpAndSettle();
      },
    ),
    ThemeScreen('empty', (t) => mac.app(t, HostPhase.running, status: hostStatus()), before: mac.settle),
  ]);
}
