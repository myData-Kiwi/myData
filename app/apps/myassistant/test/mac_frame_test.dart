// The Mac frame (MacLook) of myAssistant: its behaviour, and screenshots at the window's size (1280x800) in
// light and dark (test/screenshots/mac_*.png), with the bundled Figtree under the system font's names
// (loadMacFonts). On a Mac the accent is the system's, not the host's theme; the screenshots stand in two
// accents for it, Kiwi and Graphite (the plan's accent options; macOS has a Graphite accent too), by
// answering the system colours channel with that theme's accent. Refresh with
// `flutter test --update-goldens test/mac_frame_test.dart` on a Mac.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:myassistant/src/app.dart';
import 'package:myassistant/src/home.dart';

import 'fixtures.dart';

/// The system's colours as the Runner would report them with [t]'s theme as the accent: the accent, the
/// text on it and the focus ring (which follows the accent).
void systemAccentOf(ThemeCase t) {
  Map<String, int> palette(Brightness b) {
    final c = MyDataTheme.data(t.themeId, b).extension<MyDataColors>()!;
    return {
      'accent': c.accent.toARGB32(),
      'on-accent': c.onAccent.toARGB32(),
      'focus-ring': c.accent.withValues(alpha: 0.5).toARGB32(),
    };
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    MacSystemColorsScope.channel,
    (call) async => call.method == 'get' ? {'light': palette(Brightness.light), 'dark': palette(Brightness.dark)} : null,
  );
}

/// The app in [t]'s mode and accent, with the host in [phase].
Widget app(
  ThemeCase t,
  HostPhase phase, {
  StatusOut? status,
  AssistantBackend? backend,
  InstalledApps? apps,
  Future<bool> Function(MyDataLink link)? openLink,
}) {
  systemAccentOf(t);
  return MyAssistantApp(
    host: FakeHost(phaseOnConnect: phase, statusOnConnect: status),
    store: MemoryDeviceStore({'mode': t.brightness.name, 'lastTheme': t.themeId}),
    backend: backend,
    apps: apps,
    openLink: openLink ?? (_) async => true,
  );
}

/// Lets the app read the device's mode, the host's theme and the system's colours, frame by frame (the
/// loading kiwi never settles).
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> ask(WidgetTester tester, String text) async {
  await settle(tester);
  await tester.enterText(find.byKey(ChatView.inputKey), text);
  // Send turns on once there is text.
  await tester.pump();
  await tester.tap(find.byKey(ChatView.sendKey));
  await tester.pumpAndSettle();
}

void window(WidgetTester tester, [Size size = const Size(1280, 800)]) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    MacLook.debugOverride = true;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() {
    MacLook.debugOverride = false;
    EditableText.debugDeterministicCursor = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacSystemColorsScope.channel, null);
  });

  group('the Mac frame', () {
    macTestWidgets('no sidebar; the toolbar names the conversation and says when the data is a demo', (
      tester,
    ) async {
      window(tester);
      final backend = ScriptedBackend([freeAtSixThirty()]);
      await tester.pumpWidget(
        app(macMatrix.first, HostPhase.running, status: hostStatus(), backend: backend),
      );
      await settle(tester);

      // One conversation and no history: no sidebar (it would be one row repeating the title).
      expect(find.byType(MacSourceList), findsNothing);
      expect(find.byType(AppFrame), findsNothing);
      expect(find.text(AssistantHome.appName), findsNothing);
      expect(find.descendant(of: find.byType(MacToolbar), matching: find.text(AssistantHome.newConversation)),
          findsOneWidget);
      // The empty conversation says what can be asked, from the sample tools.
      expect(find.text(ChatView.emptyLineFor(false)), findsOneWidget);
      // Send is grey, with its reason, until there is text.
      expect(tester.getSemantics(find.bySemanticsLabel(ChatView.sendLabel)),
          isSemantics(isButton: true, isEnabled: false, hint: ChatView.sendEmptyReason));
      expect(find.descendant(of: find.byType(MacToolbar), matching: find.text(AssistantHome.demoLabel)),
          findsOneWidget);
      // Every font is the system's.
      final theme = Theme.of(tester.element(find.byType(ChatView)));
      expect(theme.textTheme.bodyMedium!.fontFamily, MyDataMacFont.text);
      // The accent is the system's (here Kiwi's, as the channel reported it).
      expect(theme.extension<MyDataMacColors>()!.accent,
          MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!.accent);

      await ask(tester, 'Am I free at 6:30 tomorrow?');
      expect(backend.sent, ['Am I free at 6:30 tomorrow?']);
      expect(find.descendant(of: find.byType(MacToolbar), matching: find.text('Am I free at 6:30 tomorrow?')),
          findsOneWidget);
      expect(find.text('No, you have personal training from 06:30 to 07:30 at the gym.'), findsOneWidget);
    });

    macTestWidgets('in real mode the toolbar has no demo line', (tester) async {
      window(tester);
      await tester.pumpWidget(app(macMatrix.first, HostPhase.running, status: hostStatus(real: true)));
      await settle(tester);
      expect(find.text(AssistantHome.demoLabel), findsNothing);
    });

    macTestWidgets('Return sends from the composer; Shift+Return does not', (tester) async {
      window(tester);
      final backend = ScriptedBackend([freeAtSixThirty()]);
      await tester.pumpWidget(app(macMatrix.first, HostPhase.running, status: hostStatus(), backend: backend));
      await settle(tester);
      await tester.tap(find.byKey(ChatView.inputKey));
      await tester.enterText(find.byKey(ChatView.inputKey), 'Am I free?');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(backend.sent, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(backend.sent, hasLength(1));
    });

    macTestWidgets('the approval card shows every argument and sends the decision', (tester) async {
      window(tester);
      await tester.pumpWidget(
        app(macMatrix.first, HostPhase.running, status: hostStatus(), backend: ScriptedBackend([emailRishita()])),
      );
      await ask(tester, 'Email Rishita the time of my dentist appointment');

      expect(find.byType(ApprovalCard), findsNothing, reason: 'the branded card is not drawn on a Mac');
      expect(find.text('Send this email?'), findsOneWidget);
      expect(find.text(ApprovalCard.pendingLabel), findsOneWidget);
      expect(find.bySemanticsLabel(ApprovalCard.pendingRegionLabel), findsOneWidget);
      for (final value in ['rishita@example.com', 'Dentist on Friday', dentistBody]) {
        expect(find.descendant(of: find.byType(MacFieldTable), matching: find.text(value)), findsOneWidget);
      }
      await tester.tap(find.text('Approve and send'));
      await tester.pump();
      expect(find.text(AssistantApprovalCard.sendingText), findsOneWidget);
    });

    macTestWidgets("a real contact and event open in their apps", (tester) async {
      window(tester);
      final opened = <MyDataLink>[];
      await tester.pumpWidget(
        app(
          macMatrix.first,
          HostPhase.running,
          status: hostStatus(real: true),
          backend: ScriptedBackend([realLookups()]),
          apps: FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.mycalendar}).apps(),
          openLink: (link) async {
            opened.add(link);
            return true;
          },
        ),
      );
      await ask(tester, "Ava's number and what's on Friday?");
      await tester.tap(find.text('Ava Fictional').last);
      await tester.tap(find.text('Dinner with Ava (invented)'));
      await tester.pumpAndSettle();
      expect(opened.map((l) => l.app), [MyDataAppId.mycontacts, MyDataAppId.mycalendar]);
      // Each row that opens something ends in a chevron.
      expect(find.byIcon(MacIcons.chevronRight), findsNWidgets(2));
    });

    macTestWidgets('a phone-sized window keeps the branded phone layout', (tester) async {
      window(tester, const Size(390, 844));
      await tester.pumpWidget(app(macMatrix.first, HostPhase.running, status: hostStatus()));
      await settle(tester);
      expect(find.byType(MacSourceList), findsNothing);
      expect(find.byType(AppFrame), findsOneWidget);
    });
  });

  group('the conversation title', () {
    test('is the first message, on one line', () {
      expect(AssistantHome.conversationTitle([]), AssistantHome.newConversation);
      expect(
        AssistantHome.conversationTitle([UserMessage('  What is on\n tomorrow? '), UserMessage('And Friday?')]),
        'What is on tomorrow?',
      );
    });

    test('starts again after a switch between demo and real mode', () {
      final items = [UserMessage('Old question'), ConversationNotice(realMode: true)];
      expect(AssistantHome.conversationTitle(items), AssistantHome.newConversation);
      expect(AssistantHome.conversationTitle([...items, UserMessage('New question')]), 'New question');
    });
  });

  group('screenshots', () {
    macScreenMatrix(
      'mac_chat',
      (t) => app(t, HostPhase.running, status: hostStatus(theme: t.themeId), backend: ScriptedBackend([freeAtSixThirty()])),
      before: (tester) => ask(tester, 'Am I free at 6:30 tomorrow?'),
    );

    // Real mode, with myContacts and myCalendar installed: each row has a chevron; the event row is hovered.
    macScreenMatrix(
      'mac_chat_links',
      (t) => app(
        t,
        HostPhase.running,
        status: hostStatus(theme: t.themeId, real: true),
        backend: ScriptedBackend([realLookups()]),
        apps: FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.mycalendar}).apps(),
      ),
      before: (tester) async {
        await ask(tester, "Ava's number and what's on Friday?");
        // Hover shows with a mouse in use (traditional highlights), as on a Mac.
        tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: tester.getCenter(find.text('Dinner with Ava (invented)')));
        addTearDown(mouse.removePointer);
        await tester.pumpAndSettle();
      },
    );

    macScreenMatrix(
      'mac_approval',
      (t) => app(t, HostPhase.running, status: hostStatus(theme: t.themeId), backend: ScriptedBackend([emailRishita()])),
      before: (tester) => ask(tester, 'Email Rishita the time of my dentist appointment'),
    );

    macScreenMatrix(
      'mac_empty',
      (t) => app(t, HostPhase.running, status: hostStatus(theme: t.themeId)),
      before: settle,
    );

    macScreenMatrix(
      'mac_assistant_off',
      (t) => app(t, HostPhase.running,
          status: hostStatus(theme: t.themeId, enabled: false, state: ModelOutStateEnum.disabled)),
      before: settle,
    );

    macScreenMatrix('mac_host_starting', (t) => app(t, HostPhase.starting), before: settle);

    macScreenMatrix('mac_host_unreachable', (t) => app(t, HostPhase.unreachable), before: settle);
  });
}
