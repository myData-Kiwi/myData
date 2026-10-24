import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/agent_list.dart';
import 'package:mydata/src/agent_tokens.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/settings_screen.dart';
import 'package:mydata/src/status_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
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
  Future<LaunchResult> stopHost(HostEnvironment env) async => const LaunchResult(false, '');
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

/// Appearance stacks its parts (design/components/GroupedSection): the mode, then everywhere's theme under
/// it, then each app's, all starting at one edge, so no empty patch opens up beside a control.
void expectStacked(WidgetTester tester) {
  final mode = tester.getRect(find.byType(SegmentedControl<MyDataMode>));
  final everywhere = tester.getRect(find.text(AppearanceSection.everywhereLabel));
  final apps = tester.getRect(find.text(AppearanceSection.appsHeading));
  expect(everywhere.top, greaterThan(mode.bottom), reason: 'everywhere is under the mode');
  expect(apps.top, greaterThan(everywhere.bottom), reason: 'the apps are under everywhere');
  expect(everywhere.left, mode.left, reason: 'the controls start at one edge');
}

/// myData's Change… button for [who] ("myCalendar", or "Everywhere").
Finder changeButton(String who) => find.byWidgetPredicate((w) => w is Button && w.semanticLabel == 'Change $who');

/// myData's Reset button for [app].
Finder resetButton(String app) => find.byWidgetPredicate((w) => w is Button && w.semanticLabel == 'Reset $app');

Future<Map<String, Object?>?> storedThemes(DeviceStore store) async =>
    (await store.read())[ThemeSettings.key] as Map<String, Object?>?;

Color windowAccent(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.extension<MyDataColors>()!.accent;

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
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeAnimationDuration, MyDataTheme.switchDuration,
        reason: 'a theme switch is drawn at once, never through in-between type');
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
    testWidgets('never asks for a theme, and never calls the retired host route', (tester) async {
      final host = FakeHost(chosen: false);
      await pumpApp(tester, host);
      expect(find.text('Status'), findsWidgets);
      expect(find.text('0.1.0'), findsOneWidget);
      expect(host.requests.where((r) => r.contains('/appearance')), isEmpty);
    });

    testWidgets("this device's first start keeps the host's old theme, as Kiwi in it, for every app", (tester) async {
      final host = FakeHost()..theme = 'plum';
      final store = MemoryDeviceStore();
      await pumpApp(tester, host, store: store);
      expect(await storedThemes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum'},
      });
      expect(windowAccent(tester), MyDataThemes.plum.accentLight);
      expect(host.requests.where((r) => r.contains('/appearance')), isEmpty);
    });
  });

  group('Settings', () {
    testWidgets("Appearance lists every app with its theme on this device; Reset follows everywhere", (tester) async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.system'},
          'apps': {
            'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'dusk'},
          },
        },
      });
      await pumpApp(tester, FakeHost(), store: store);
      await openSettings(tester);
      expect(find.text(AppearanceSection.heading), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      for (final a in MyDataAppId.values) {
        expect(find.text(a.displayName), findsWidgets, reason: a.displayName);
      }
      expect(find.text('Kiwi, Dusk'), findsOneWidget);
      expect(find.text(AppearanceSection.sameAsEverywhere), findsNWidgets(3));
      expect(tester.widget<Button>(resetButton('myContacts')).onPressed, isNull);
      expect(tester.widget<Button>(resetButton('myContacts')).disabledReason, AppearanceSection.resetReason);
      await tester.ensureVisible(resetButton('myCalendar'));
      await tester.tap(resetButton('myCalendar'));
      await settle(tester);
      expect(await storedThemes(store), {
        'everywhere': {'theme': 'mydata.system'},
      });
      expect(find.text(AppearanceSection.sameAsEverywhere), findsNWidgets(4));
    });

    testWidgets('under a theme that sets labels in upper case, the apps keep their names: never MYASSISTANT', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themes = ThemeController(appId: 'mydata', store: MemoryDeviceStore(), macOS: false);
      await themes.start();
      await tester.pumpWidget(MaterialApp(
        theme: MyDataTheme.fromLook(upperCaseLook(Brightness.light)),
        home: Material(child: SingleChildScrollView(child: AppearanceSection(themes: themes))),
      ));
      await tester.pump();
      for (final a in MyDataAppId.values) {
        expect(find.text(a.displayName), findsOneWidget, reason: a.displayName);
        expect(find.text(a.displayName.toUpperCase()), findsNothing, reason: a.displayName);
      }
      // Its own labels follow the theme.
      expect(find.text(AppearanceSection.modeLabel.toUpperCase()), findsOneWidget);
      expect(find.text(AppearanceSection.appsHeading.toUpperCase()), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      themes.dispose();
    });

    testWidgets("Change… opens the gallery on that app; Use stores it on this device, never on the host", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final host = FakeHost();
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.system'},
        },
      });
      await pumpApp(tester, host, store: store);
      await openSettings(tester);
      final before = windowAccent(tester);
      await tester.ensureVisible(changeButton('myCalendar'));
      await tester.tap(changeButton('myCalendar'));
      await settle(tester);
      expect(find.text(ThemeGallery.useLabel('myCalendar')), findsOneWidget);
      // the app switcher: a theme can be judged on another app's scene
      expect(find.byType(SegmentedControl<String>), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(windowAccent(tester), before, reason: "myCalendar's choice is not previewed on myData's window");
      await tester.tap(find.text(ThemeGallery.useLabel('myCalendar')));
      await settle(tester);
      expect(await storedThemes(store), {
        'everywhere': {'theme': 'mydata.system'},
        'apps': {
          'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'kiwi'},
        },
      });
      expect(find.text('Kiwi, Kiwi'), findsOneWidget);
      expect(host.requests.where((r) => r.contains('/appearance')), isEmpty);
    });

    testWidgets('Use everywhere carries the palette to every app, and Undo puts each back', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mine = {
        'everywhere': {'theme': 'mydata.system'},
        'apps': {
          'mycontacts': {'theme': 'mydata.kiwi', 'palette': 'rose'},
        },
      };
      final store = MemoryDeviceStore({'themes': mine});
      await pumpApp(tester, FakeHost(), store: store);
      await openSettings(tester);
      await tester.ensureVisible(changeButton(AppearanceSection.everywhereLabel));
      await tester.tap(changeButton(AppearanceSection.everywhereLabel));
      await settle(tester);
      // myData's own window previews as the selection moves
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(windowAccent(tester), MyDataThemes.kiwi.accentLight);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester);
      expect(windowAccent(tester), MyDataThemes.graphite.accentLight);
      await tester.tap(find.text(ThemeGallery.everywhereLabel));
      await settle(tester);
      expect(await storedThemes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'graphite'},
      });
      expect(find.text(ThemeGallery.everywhereDone('Kiwi, Graphite')), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await storedThemes(store), mine);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text(ThemeGallery.title), findsNothing);
      // phones have one theme per app until native phone apps: a desktop runs this test
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets("Everywhere's Change… starts on everywhere's choice, and Return uses it everywhere", (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'dusk'},
          'apps': {
            'mydata': {'theme': 'mydata.kiwi', 'palette': 'rose'},
          },
        },
      });
      await pumpApp(tester, FakeHost(), store: store);
      await openSettings(tester);
      await tester.ensureVisible(changeButton(AppearanceSection.everywhereLabel));
      await tester.tap(changeButton(AppearanceSection.everywhereLabel));
      await settle(tester);
      expect(find.text(ThemeGallery.everywhereSentence), findsOneWidget);
      expect(find.text(ThemeGallery.useLabel('myData')), findsNothing);
      // the selection is everywhere's Kiwi in Dusk, not myData's own Kiwi in Rose
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(await storedThemes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'dusk'},
      });
      expect(find.text(ThemeGallery.everywhereDone('Kiwi, Dusk')), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('on a phone, Everywhere has no Change…: phones have one theme per app', (tester) async {
      await pumpApp(tester, FakeHost(), store: MemoryDeviceStore());
      await openSettings(tester);
      expect(find.text(AppearanceSection.everywhereLabel), findsOneWidget);
      expect(changeButton(AppearanceSection.everywhereLabel), findsNothing);
      expect(changeButton('myCalendar'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a stored theme this build does not have says what it draws instead', (tester) async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'someone.neon'},
        },
      });
      await pumpApp(tester, FakeHost(), store: store);
      await openSettings(tester);
      expect(
        find.text(AppearanceSection.missing(AppearanceSection.everywhereLabel, ThemeChoice.system)),
        findsOneWidget,
      );
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

    testWidgets('a theme chosen in another app on this device arrives without a restart', (tester) async {
      final store = MemoryDeviceStore();
      await pumpApp(tester, FakeHost(), store: store);
      // myContacts' gallery, Use everywhere
      final other = ThemeController(appId: 'mycontacts', store: store, macOS: false);
      await other.start();
      await other.useEverywhere(const ThemeChoice('mydata.kiwi', 'plum'));
      other.dispose();
      await settle(tester);
      expect(windowAccent(tester), MyDataThemes.plum.accentLight);
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
      await tester.enterText(find.widgetWithText(MyDataTextField, 'Name'), 'Claude on my laptop');
      await tester.pump();
      await tester.tap(create);
      await settle(tester);
      expect(host.requests, contains('POST /agents {"name":"Claude on my laptop"}'));
      expect(find.byType(NewTokenDialog), findsOneWidget);
      expect(find.text('Copy it now. It will not be shown again.'), findsOneWidget);
      expect(find.text('mdt_secret_for_Claude on my laptop'), findsOneWidget);
      expect(find.text('http://127.0.0.1:47821/mcp'), findsOneWidget);
      expect(find.byType(MonoWell), findsNWidgets(2));
      final copy = find.widgetWithText(Button, 'Copy token');
      final copyWidth = tester.getSize(copy).width;
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(copy);
      await settle(tester);
      expect(clipboard, 'mdt_secret_for_Claude on my laptop');
      final copied = find.widgetWithText(Button, MonoWell.copiedLabel);
      expect(copied, findsOneWidget);
      expect(tester.getSize(copied).width, copyWidth, reason: 'the button keeps its width when it says Copied');
      await tester.tap(find.text('Done'));
      await settle(tester);

      final row = find.ancestor(of: find.text('Claude on my laptop'), matching: find.byType(AgentTokenRow));
      expect(find.descendant(of: row, matching: find.text('Not connected')), findsOneWidget);
      expect(
        tester.widget<ActionRow>(find.descendant(of: row, matching: find.byType(ActionRow))).tone,
        MyDataTone.neutral,
        reason: 'a token row has the untinted tile',
      );
      final revoke = find.descendant(of: row, matching: find.text(RevokeLabels.ask));
      expect(
        tester.widget<Button>(find.ancestor(of: revoke, matching: find.byType(Button))).variant,
        ButtonVariant.plainDanger,
        reason: 'a destructive row action is plain danger (design/components/ActionRow)',
      );
      await tester.ensureVisible(revoke);
      await tester.tap(revoke);
      await settle(tester);
      expect(find.text('Revoke Claude on my laptop?'), findsOneWidget);
      expect(
        find.text(
          'Claude on my laptop will no longer reach your data. Any agent using this token stops working at once.',
        ),
        findsOneWidget,
        reason: 'the confirmation names what will stop working',
      );
      expect(find.widgetWithText(Button, 'Cancel'), findsOneWidget);
      expect(
        tester.widget<Button>(find.widgetWithText(Button, RevokeLabels.confirm)).variant,
        ButtonVariant.danger,
        reason: 'the dialog confirms with a danger button',
      );
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
      expect(
        tester.widget<MyDataBadge>(find.descendant(of: row, matching: find.byType(MyDataBadge))).tone,
        MyDataTone.neutral,
        reason: 'a revoked token has the inactive chip: red is for errors',
      );
    });
  });

  test('a token is connected (success), not connected or revoked (both the inactive chip)', () {
    expect(AgentTokenRow.state(agentWith('a', connected: true)), ('Connected', MyDataTone.success));
    expect(AgentTokenRow.state(agentWith('b')), ('Not connected', MyDataTone.neutral));
    expect(AgentTokenRow.state(agentWith('c', revoked: true)), (
      'Revoked',
      MyDataTone.neutral,
    ), reason: 'red is for errors, and a revoked token is not one');
  });

  testWidgets('an agent list that could not be read is a row with a tonal Retry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        AgentListProblem(
          heading: AgentTokensSection.heading,
          error: 'the host did not answer',
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.byType(ActionRow), findsOneWidget);
    expect(find.text('The agent list could not be read'), findsOneWidget);
    expect(find.text('the host did not answer'), findsOneWidget);
    final retry = find.widgetWithText(Button, 'Retry');
    expect(tester.widget<Button>(retry).variant, ButtonVariant.tonal);
    await tester.tap(retry);
    expect(retried, 1);
  });

  testWidgets('a host that stops shows its panel and the frame says it cannot be reached', (tester) async {
    final host = FakeHost();
    final controller = await pumpApp(tester, host);
    host.down = true;
    await controller.refresh();
    await controller.refresh();
    await tester.pump();
    expect(controller.phase, HostPhase.lost);
    expect(find.text(AppConnection.lostText), findsOneWidget);
    expect(find.text(AppConnection.unreachableText), findsOneWidget);
    // One next step: the frame's Retry. The panel only explains.
    final retry = find.text(AppConnection.retryText);
    expect(retry, findsOneWidget, reason: 'the frame offers Retry; the panel does not repeat it');
    expect(find.ancestor(of: retry, matching: find.byType(StatusPanel)), findsNothing);
    host.down = false;
    await tester.tap(retry);
    await settle(tester);
    expect(controller.phase, HostPhase.running, reason: "the frame's Retry calls controller.retry");
    expect(find.text(AppConnection.lostText), findsNothing);
    // Reconnecting started the 2 s status poll; losing the host again stops it, so no timer outlives the test.
    host.down = true;
    await controller.refresh();
    await controller.refresh();
    expect(controller.phase, HostPhase.lost);
  });

  testWidgets('the Appearance parts stay stacked in a 1280 by 800 window', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, FakeHost());
    await openSettings(tester);
    expectStacked(tester);
  });

  testWidgets('the Appearance parts stay stacked in a phone-width window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, FakeHost());
    await openSettings(tester);
    expectStacked(tester);
  });

  testWidgets('Status and Settings fit a phone-width window', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final host = FakeHost(
      status: statusWith(
        ModelOutStateEnum.ready,
        lastError: ErrorOut(at: '2026-10-12T08:00:00Z', logger: 'mydata', message: 'a long error message ' * 4),
      ),
      agents: [agentWith('Claude on my laptop', connected: true), agentWith('Old script', revoked: true)],
    );
    await pumpApp(tester, host);
    expect(find.text('0.1.0'), findsOneWidget);
    await tester.tap(findIcon(MyDataIcon.settings));
    await settle(tester);
    await tester.ensureVisible(find.text('Old script'));
    await settle(tester);
    expect(find.text('Revoked'), findsOneWidget);
  });
}
