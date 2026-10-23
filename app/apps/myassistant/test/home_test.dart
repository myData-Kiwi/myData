import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:myassistant/src/app.dart';
import 'package:myassistant/src/home.dart';

import 'fixtures.dart';

/// A desktop window, so the frame is the sidebar with the app's name.
void desktop(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1280, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

MyDataColors colorsOf(WidgetTester tester) => tester.element(find.byType(AppFrame)).colors;

void main() {
  group('opening results in their apps', linksTests);

  testWidgets('without a start command: the error, its detail, and Retry that tries again', (tester) async {
    desktop(tester);
    final platform = NoHostPlatform(supported: true);
    await tester.pumpWidget(
      MyAssistantApp(
        host: HostController(app: 'myassistant', platform: platform),
        store: MemoryDeviceStore(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('myAssistant'), findsOneWidget);
    expect(find.text('The myData host is not set up'), findsOneWidget);
    expect(find.textContaining('uv run mydata dev-setup'), findsOneWidget);
    // The frame says the host cannot be reached.
    expect(find.text(AppConnection.unreachableText), findsOneWidget);

    // The panel's Retry, then the frame's: both try again.
    await tester.tap(find.descendant(of: find.byType(StatusPanel), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(platform.environments, 2);
    await tester.tap(find.descendant(of: find.byType(AppFrame), matching: find.text('Retry')).first);
    await tester.pumpAndSettle();
    expect(platform.environments, 3);
  });

  testWidgets('the web build explains that the desktop app is needed', (tester) async {
    desktop(tester);
    final host = HostController(app: 'myassistant', platform: NoHostPlatform(supported: false));
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore()));
    await tester.pumpAndSettle();
    expect(find.text('myAssistant needs the desktop app'), findsOneWidget);
    expect(find.text('The web version needs the desktop app.'), findsOneWidget);
    // Retry cannot help here: no frame, so no "Cannot reach your host" and no Retry anywhere.
    expect(find.byType(AppFrame), findsNothing);
    expect(find.text(AppConnection.unreachableText), findsNothing);
    expect(find.text(AppConnection.retryText), findsNothing);
  });

  testWidgets('starting: the panel and the frame say so', (tester) async {
    desktop(tester);
    final host = FakeHost(phaseOnConnect: HostPhase.starting);
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore()));
    await tester.pump();
    expect(find.text('Starting the myData host'), findsOneWidget);
    expect(find.text(AppConnection.startingText), findsOneWidget);
  });

  testWidgets('restarting a host from another build: the panel and the frame say so', (tester) async {
    desktop(tester);
    final host = FakeHost(phaseOnConnect: HostPhase.restarting);
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore()));
    await tester.pump();
    expect(find.text('Restarting the myData host'), findsOneWidget);
    expect(find.text(AppConnection.startingText), findsOneWidget);
  });

  testWidgets('ready: the chat in the frame, "Connected to your host", and Open myData', (tester) async {
    desktop(tester);
    final platform = NoHostPlatform(supported: true);
    final backend = ScriptedBackend([freeAtSixThirty()]);
    final host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus(), platform: platform);
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore(), backend: backend));
    await tester.pumpAndSettle();

    expect(find.byType(AppFrame), findsOneWidget);
    expect(find.text('Chat'), findsWidgets); // the section and the page title
    expect(find.text('Demo data'), findsOneWidget);
    expect(find.byType(ChatView), findsOneWidget);
    expect(find.text(AppConnection.connectedText), findsOneWidget);

    await tester.enterText(find.byKey(ChatView.inputKey), 'Am I free at 6:30 tomorrow?');
    await tester.tap(find.byKey(ChatView.sendKey));
    await tester.pumpAndSettle();
    expect(backend.sent, ['Am I free at 6:30 tomorrow?']);
    expect(find.byType(ResultCard), findsOneWidget);
    expect(find.text('No, you have personal training from 06:30 to 07:30 at the gym.'), findsOneWidget);

    // Open myData: the app itself, not its setup. When it cannot be opened, the app says what to do.
    await tester.tap(find.text(AppConnection.openMyDataText));
    await tester.pump();
    expect(platform.openCalls, [false]);
    expect(find.textContaining('Open the myData app yourself'), findsOneWidget);
  });

  testWidgets('switched off: one screen, and its button opens myData', (tester) async {
    desktop(tester);
    final platform = NoHostPlatform(supported: true);
    final host = FakeHost(
      phaseOnConnect: HostPhase.running,
      statusOnConnect: hostStatus(enabled: false, state: ModelOutStateEnum.disabled),
      platform: platform,
    );
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore()));
    await tester.pumpAndSettle();
    expect(find.text('The assistant is off'), findsOneWidget);
    expect(find.byType(ChatView), findsNothing);

    await tester.tap(find.widgetWithText(Button, 'Open myData'));
    await tester.pumpAndSettle();
    expect(platform.openCalls, [true]);
    // The notice names the same place as the sentence: Settings in myData.
    expect(
      find.text(
        'myAssistant could not open myData from here. Open the myData app yourself and turn the assistant on '
        'under Settings.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('go to Setup'), findsNothing);
  });

  testWidgets("the theme and the mode follow this device's settings, without a restart", (tester) async {
    desktop(tester);
    final store = MemoryDeviceStore({'mode': 'light'});
    final host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus());
    await tester.pumpWidget(MyAssistantApp(host: host, store: store, backend: ScriptedBackend([])));
    await tester.pumpAndSettle();
    // This device's first start: the host's old theme (Kiwi) is kept, as Kiwi in that palette.
    final kiwi = MyDataColors.light.withTheme(MyDataThemes.kiwi, Brightness.light);
    expect(colorsOf(tester).accent, kiwi.accent);
    expect((await store.read())['themes'], {
      'everywhere': {'theme': 'mydata.kiwi', 'palette': 'kiwi'},
    });

    // The host's theme no longer changes anything: themes are chosen on each device.
    host.push(hostStatus(theme: 'graphite'));
    await tester.pumpAndSettle();
    expect(colorsOf(tester).accent, kiwi.accent);

    // A theme chosen for myAssistant in myData's Appearance arrives through the device's settings.
    final mydata = ThemeController(appId: 'mydata', store: store, macOS: false);
    await mydata.start();
    await mydata.use(const ThemeChoice('mydata.kiwi', 'graphite'), app: 'myassistant');
    mydata.dispose();
    await tester.pumpAndSettle();
    final graphite = MyDataColors.light.withTheme(MyDataThemes.graphite, Brightness.light);
    expect(colorsOf(tester).accent, graphite.accent);

    // Dark mode set in another app on this device is read within one interval.
    await store.write({...await store.read(), 'mode': 'dark'});
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppFrame))).brightness, Brightness.dark);
    expect(colorsOf(tester).bg, MyDataColors.dark.bg);
  });

  testWidgets('a switch between demo and real mode ends the conversation, with one line each time', (tester) async {
    desktop(tester);
    final backend = ScriptedBackend([
      freeAtSixThirty(),
      [
        const ConversationEvent('e1.new'),
        const MessageEvent(text: 'Hello.', outcome: 'answered'),
        const DoneEvent(),
      ],
      [
        const ConversationEvent('e1.new'),
        const MessageEvent(text: 'Yes.', outcome: 'answered'),
        const DoneEvent(),
      ],
    ]);
    final host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus());
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore(), backend: backend));
    await tester.pumpAndSettle();

    Future<void> say(String text) async {
      await tester.enterText(find.byKey(ChatView.inputKey), text);
      await tester.tap(find.byKey(ChatView.sendKey));
      await tester.pumpAndSettle();
    }

    await say('Am I free at 6:30 tomorrow?');
    expect(find.text(ConversationNotice.realText), findsNothing);

    // The user turns on a source in myData: the next poll brings real mode and a new epoch.
    host.push(hostStatus(real: true, epoch: 1));
    await tester.pumpAndSettle();
    expect(find.text('myAssistant now uses your contacts and calendars. A new conversation has started.'), findsOneWidget);
    expect(find.text(AssistantHome.demoLabel), findsNothing);
    // Every later poll is the same epoch: still one line.
    host.push(hostStatus(real: true, epoch: 1));
    await tester.pumpAndSettle();
    expect(find.text(ConversationNotice.realText), findsOneWidget);

    await say('Hello');
    await say('Are you there?');
    expect(backend.conversations, [null, null, 'e1.new'],
        reason: 'the first message after the switch starts a new conversation, and the one after continues it');

    // Back to example data.
    host.push(hostStatus(epoch: 2));
    await tester.pumpAndSettle();
    expect(find.text('myAssistant is back on example data. A new conversation has started.'), findsOneWidget);
    expect(find.text(ConversationNotice.realText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app follows reduced transparency and reduced motion through its scope', (tester) async {
    desktop(tester);
    final host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus());
    await tester.pumpWidget(MyAssistantApp(host: host, store: MemoryDeviceStore(), backend: ScriptedBackend([])));
    await tester.pumpAndSettle();
    expect(find.byType(MyDataAccessibilityScope), findsOneWidget);
  });

  for (final size in const [Size(800, 600), Size(390, 844)]) {
    testWidgets('the chat and an approval fit a ${size.width.toInt()}px window', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = FakeHost(phaseOnConnect: HostPhase.running, statusOnConnect: hostStatus());
      await tester.pumpWidget(
        MyAssistantApp(host: host, store: MemoryDeviceStore(), backend: ScriptedBackend([emailRishita()])),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ChatView.inputKey), 'Email Rishita the time of my dentist appointment');
      await tester.tap(find.byKey(ChatView.sendKey));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantApprovalCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void linksTests() {
  Future<void> ask(WidgetTester tester, String text) async {
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ChatView.inputKey), text);
    await tester.tap(find.byKey(ChatView.sendKey));
    await tester.pumpAndSettle();
  }

  Widget app(FakeLaunchServices launch, List<MyDataLink> opened, {bool real = true, bool opens = true}) =>
      MyAssistantApp(
        host: FakeHost(
          phaseOnConnect: HostPhase.running,
          statusOnConnect: hostStatus(real: real),
        ),
        store: MemoryDeviceStore(),
        backend: ScriptedBackend([realLookups(real: real)]),
        apps: launch.apps(),
        openLink: (link) async {
          opened.add(link);
          return opens;
        },
      );

  testWidgets('a real contact opens in myContacts and an event\'s day in myCalendar', (tester) async {
    desktop(tester);
    final launch = FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.mycalendar});
    final opened = <MyDataLink>[];
    await tester.pumpWidget(app(launch, opened));
    await ask(tester, "Ava's number and what's on Friday?");
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    await tester.tap(find.text('ava.fictional@example.com'));
    await tester.tap(find.text('Dinner with Ava (invented)'));
    await tester.pump();
    expect(opened, [OpenContact(avaId), OpenDay(DateTime(2026, 3, 20))]);
  });

  testWidgets('installed apps are looked up once, and again when myAssistant comes back to the front', (tester) async {
    desktop(tester);
    final launch = FakeLaunchServices({MyDataAppId.mycontacts});
    final opened = <MyDataLink>[];
    await tester.pumpWidget(app(launch, opened));
    await ask(tester, "Ava's number and what's on Friday?");
    expect(launch.lookups, 2); // one per app, once
    // myCalendar is not installed: its row does nothing.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.text('Dinner with Ava (invented)'));
    expect(opened, isEmpty);

    launch.present.add(MyDataAppId.mycalendar);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(launch.lookups, 4);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    await tester.tap(find.text('Dinner with Ava (invented)'));
    expect(opened, [OpenDay(DateTime(2026, 3, 20))]);
  });

  testWidgets('with neither app installed no row is interactive', (tester) async {
    desktop(tester);
    final opened = <MyDataLink>[];
    await tester.pumpWidget(app(FakeLaunchServices(), opened));
    await ask(tester, "Ava's number and what's on Friday?");
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byType(Pressable), findsWidgets); // the composer's button; not the rows:
    await tester.tap(find.text('ava.fictional@example.com'));
    expect(opened, isEmpty);
  });

  testWidgets('sample results (demo mode) never open anything', (tester) async {
    desktop(tester);
    final opened = <MyDataLink>[];
    await tester.pumpWidget(app(FakeLaunchServices({...MyDataAppId.values}), opened, real: false));
    await ask(tester, "Ava's number and what's on Friday?");
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    await tester.tap(find.text('ava.fictional@example.com'));
    expect(opened, isEmpty);
  });

  testWidgets('an app that would not open: one line says so, and the apps are looked up again', (tester) async {
    desktop(tester);
    final launch = FakeLaunchServices({MyDataAppId.mycontacts, MyDataAppId.mycalendar});
    final opened = <MyDataLink>[];
    await tester.pumpWidget(app(launch, opened, opens: false));
    await ask(tester, "Ava's number and what's on Friday?");
    launch.present.clear(); // removed meanwhile
    await tester.tap(find.text('ava.fictional@example.com'));
    await tester.pumpAndSettle();
    expect(find.text(AssistantHome.openFailed(MyDataAppId.mycontacts)), findsOneWidget);
    expect(launch.lookups, 4);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
