import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/agent_list.dart';
import 'package:mydata/src/agent_tokens.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata/src/setup_screen.dart';
import 'package:mydata/src/status_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// A platform with no local host, like the web build.
class _NoHostPlatform implements HostPlatform {
  @override
  bool get supported => false;
  @override
  String get unsupportedReason => 'Open the myData desktop app instead.';
  @override
  Future<HostEnvironment> environment() => throw UnsupportedError(unsupportedReason);
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => null;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(false, '');
  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

/// The app against [host], as main() builds it, with this device's settings in [store].
Future<HostController> pumpApp(WidgetTester tester, FakeHost host, {DeviceStore? store}) async {
  final controller = host.controller();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MyDataApp(controller: controller, store: store ?? MemoryDeviceStore()));
  await settle(tester);
  return controller;
}

/// Opens Settings from the frame.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await settle(tester);
}

void main() {
  testWidgets('an unsupported platform shows why, with Retry', (tester) async {
    final controller = HostController(app: 'mydata', platform: _NoHostPlatform());
    await controller.connect();
    await tester.pumpWidget(MyDataApp(controller: controller, store: MemoryDeviceStore()));
    await tester.pump();
    expect(find.text('Use the desktop app'), findsOneWidget);
    expect(find.text('Open the myData desktop app instead.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('the Status screen shows the host, the model, memory and errors', (tester) async {
    final controller = HostController(app: 'mydata', platform: _NoHostPlatform());
    final agents = AgentList(controller);
    final status = statusWith(ModelOutStateEnum.ready, modelBytes: 9300000000);
    await tester.pumpWidget(
      MaterialApp(
        theme: MyDataTheme().light,
        home: Scaffold(
          body: StatusScreen(status: status, agents: agents),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('qwen3:14b is ready'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Demo date'), findsOneWidget);
    expect(find.text('18 Mar 2026'), findsOneWidget);
    expect(find.text('120 MB'), findsOneWidget);
    expect(find.text('9.3 GB'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    agents.dispose();
    controller.dispose();
  });

  testWidgets('the Status screen shows the last error and the connected agents', (tester) async {
    final host = FakeHost(
      status: statusWith(
        ModelOutStateEnum.ready,
        lastError: ErrorOut(at: '2026-10-12T08:00:00Z', logger: 'mydata.tools', message: 'tool search_mail failed'),
      ),
      agents: [
        agentWith('Claude on my laptop', connected: true, lastSeenAt: '2026-10-12T08:05:00Z'),
        agentWith('Old script', revoked: true),
      ],
    );
    await pumpApp(tester, host);
    expect(find.text('tool search_mail failed'), findsOneWidget);
    expect(find.text('Claude on my laptop'), findsOneWidget);
    expect(find.text('Old script'), findsNothing, reason: 'only connected agents are listed');
  });

  testWidgets('the availability chip says it in a word, in its status colour', (tester) async {
    final cases = {
      AssistantAvailability.ready: ('Ready', MyDataTone.success),
      AssistantAvailability.preparing: ('Preparing', MyDataTone.info),
      AssistantAvailability.off: ('Off', MyDataTone.neutral),
      AssistantAvailability.notInstalled: ('Ollama missing', MyDataTone.danger),
      AssistantAvailability.failed: ('Error', MyDataTone.danger),
    };
    for (final MapEntry(key: a, value: (label, tone)) in cases.entries) {
      final badge = availabilityBadge(a);
      expect((badge.label, badge.tone), (label, tone), reason: '$a');
    }
  });

  group('first run', () {
    testWidgets('asks for the theme when none was chosen, and stores the one picked', (tester) async {
      final host = FakeHost(chosen: false);
      await pumpApp(tester, host);
      expect(find.text(ThemeStep.title), findsOneWidget);
      await tester.tap(find.text('Graphite'));
      await tester.pump();
      await tester.ensureVisible(find.text(ThemeStep.useLabel));
      await tester.tap(find.text(ThemeStep.useLabel));
      await settle(tester);
      expect(host.requests, contains('PUT /appearance {"theme":"graphite"}'));
      // Then the assistant step, and the whole app in the stored theme.
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text('myData is ready'), findsOneWidget);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.extension<MyDataColors>()!.accent, MyDataThemes.graphite.accentLight);
    });

    testWidgets('stores Kiwi too, so the question is not asked again', (tester) async {
      final host = FakeHost(chosen: false);
      await pumpApp(tester, host);
      await tester.ensureVisible(find.text(ThemeStep.useLabel));
      await tester.tap(find.text(ThemeStep.useLabel));
      await settle(tester);
      expect(host.requests, contains('PUT /appearance {"theme":"kiwi"}'));
      expect(host.chosen, isTrue);
    });

    testWidgets('a theme chosen before skips the step', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      expect(host.requests, contains('GET /appearance'));
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text('Status'), findsWidgets);
      expect(find.text('0.1.0'), findsOneWidget);
    });

    testWidgets('a host that cannot say whether a theme was chosen does not block setup', (tester) async {
      final host = FakeHost(chosen: false)..failAppearance = true;
      await pumpApp(tester, host);
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text('0.1.0'), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('picking a theme sets it on the host at once, with no Save button', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      await openSettings(tester);
      expect(find.text(AppearanceSection.heading), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.text('Dusk'));
      await settle(tester);
      expect(host.requests, contains('PUT /appearance {"theme":"dusk"}'));
      expect(tester.widget<ThemePicker>(find.byType(ThemePicker)).selected, 'dusk');
      expect(tester.widget<ThemeSample>(find.byType(ThemeSample)).themeId, 'dusk');
    });

    testWidgets('a theme the host could not take is reported, and the theme stays', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      await openSettings(tester);
      host.failAppearance = true;
      await tester.tap(find.text('Rose'));
      await settle(tester);
      expect(find.text(AppearanceSection.failed), findsOneWidget);
      expect(tester.widget<ThemePicker>(find.byType(ThemePicker)).selected, 'kiwi');
    });

    testWidgets('the mode is written to this device, where myAssistant reads it', (tester) async {
      final store = MemoryDeviceStore();
      await pumpApp(tester, FakeHost(), store: store);
      await openSettings(tester);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect((await store.read())['mode'], 'dark');
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
      await tester.tap(find.text('Match system'));
      await settle(tester);
      expect((await store.read())['mode'], 'system');
    });

    testWidgets('a theme set in another app arrives with the next status poll', (tester) async {
      final host = FakeHost();
      final controller = await pumpApp(tester, host);
      host.theme = 'plum'; // myAssistant changed it
      await controller.refresh();
      await settle(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.extension<MyDataColors>()!.accent, MyDataThemes.plum.accentLight);
    });

    testWidgets('the assistant switch turns the assistant off and on', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      await openSettings(tester);
      final row = find.ancestor(of: find.textContaining('Switching it off unloads'), matching: find.byType(GroupedRow));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);
      expect(host.requests, contains('PUT /assistant/settings {"enabled":false}'));
      expect(find.textContaining('Off. myData works without it.'), findsOneWidget);

      await tester.tap(find.ancestor(of: find.textContaining('Off. myData works'), matching: find.byType(GroupedRow)));
      await settle(tester);
      expect(host.requests, contains('PUT /assistant/settings {"enabled":true}'));
      expect(find.textContaining('The assistant is on. Its model is being prepared'), findsOneWidget);
    });

    testWidgets('an agent token is created, shown once, and revoked after a confirmation', (tester) async {
      final host = FakeHost();
      await pumpApp(tester, host);
      await openSettings(tester);
      expect(find.text('No agent tokens yet'), findsOneWidget);

      final create = find.ancestor(of: find.text(AgentTokensSection.createLabel), matching: find.byType(Button));
      await tester.ensureVisible(create);
      expect(tester.widget<Button>(create).onPressed, isNull, reason: 'a token needs a name');
      await tester.enterText(find.byType(MyDataTextField), 'Claude on my laptop');
      await tester.pump();
      await tester.tap(create);
      await settle(tester);
      expect(host.requests, contains('POST /agents {"name":"Claude on my laptop"}'));
      expect(find.byType(NewTokenDialog), findsOneWidget);
      expect(find.text('Copy it now. It will not be shown again.'), findsOneWidget);
      expect(find.text('mdt_secret_for_Claude on my laptop'), findsOneWidget);
      expect(find.text('http://127.0.0.1:47821/mcp'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      final row = find.ancestor(of: find.text('Claude on my laptop'), matching: find.byType(AgentTokenRow));
      expect(find.descendant(of: row, matching: find.text('Not connected')), findsOneWidget);
      final revoke = find.descendant(of: row, matching: find.text(RevokeLabels.ask));
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await settle(tester);
      expect(find.text('Revoke Claude on my laptop?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(host.requests.where((r) => r.startsWith('DELETE')), isEmpty);

      await tester.tap(revoke);
      await settle(tester);
      await tester.tap(find.text(RevokeLabels.confirm));
      await settle(tester);
      expect(host.requests, contains('DELETE /agents/id-claude-on-my-laptop'));
      expect(find.descendant(of: row, matching: find.text('Revoked')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(RevokeLabels.ask)), findsNothing);
    });
  });

  testWidgets('a host that stops shows its panel and the frame says it cannot be reached', (tester) async {
    final host = FakeHost();
    final controller = await pumpApp(tester, host);
    host.down = true;
    await controller.refresh();
    await controller.refresh();
    await tester.pump();
    expect(controller.phase, HostPhase.lost);
    expect(find.text('The host stopped'), findsOneWidget);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
    // One next step: the frame's Retry. The panel only explains.
    final retry = find.text(AppConnection.retryText);
    expect(retry, findsOneWidget, reason: 'the frame offers Retry; the panel does not repeat it');
    expect(find.ancestor(of: retry, matching: find.byType(StatusPanel)), findsNothing);
    host.down = false;
    await tester.tap(retry);
    await settle(tester);
    expect(controller.phase, HostPhase.running, reason: "the frame's Retry calls controller.retry");
    expect(find.text('The host stopped'), findsNothing);
    // Reconnecting started the 2 s status poll; losing the host again stops it, so no timer outlives the test.
    host.down = true;
    await controller.refresh();
    await controller.refresh();
    expect(controller.phase, HostPhase.lost);
  });

  group('the six theme swatches sit on one row in a 1280 by 800 window', () {
    void expectOneRow(WidgetTester tester) {
      final top = tester.getTopLeft(find.text(MyDataThemes.all.first.name)).dy;
      for (final t in MyDataThemes.all) {
        expect(tester.getTopLeft(find.text(t.name)).dy, top, reason: '${t.name} is on the first row');
      }
    }

    void bigWindow(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('on the theme step', (tester) async {
      bigWindow(tester);
      await pumpApp(tester, FakeHost(chosen: false));
      expect(find.text(ThemeStep.title), findsOneWidget);
      expectOneRow(tester);
    });

    testWidgets('in Settings, with the mode beside the sample', (tester) async {
      bigWindow(tester);
      await pumpApp(tester, FakeHost());
      await openSettings(tester);
      expectOneRow(tester);
      final mode = tester.getRect(find.byType(SegmentedControl<MyDataMode>));
      final sample = tester.getRect(find.byType(ThemeSample));
      expect(mode.right, lessThan(sample.left), reason: 'the mode is beside the sample');
      expect(mode.top, lessThan(sample.bottom));
    });
  });

  testWidgets('Status, Settings and the theme step fit a phone-width window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = FakeHost(
      status: statusWith(
        ModelOutStateEnum.ready,
        lastError: ErrorOut(at: '2026-10-12T08:00:00Z', logger: 'mydata', message: 'a long error message ' * 4),
      ),
      agents: [agentWith('Claude on my laptop', connected: true), agentWith('Old script', revoked: true)],
      chosen: false,
    );
    await pumpApp(tester, host);
    expect(find.text(ThemeStep.title), findsOneWidget);
    await tester.ensureVisible(find.text(ThemeStep.useLabel));
    await tester.tap(find.text(ThemeStep.useLabel));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('0.1.0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    await tester.ensureVisible(find.text('Old script'));
    await settle(tester);
    expect(find.text('Revoked'), findsOneWidget);
  });
}

