import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/setup_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// Which callbacks the Setup screen called.
class Calls {
  final names = <String>[];
  VoidCallback call(String name) =>
      () => names.add(name);
}

Future<Calls> pumpSetup(
  WidgetTester tester, {
  HostPhase phase = HostPhase.running,
  StatusOut? status,
  String? error,
  String? detail,
  bool themeChosen = true,
  Future<void> Function(String id)? onChooseTheme,
}) async {
  final calls = Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: MyDataTheme().light,
      home: SetupScreen(
        phase: phase,
        status: status,
        error: error,
        detail: detail,
        onRetryHost: calls.call('retryHost'),
        onRetryModel: calls.call('retryModel'),
        onSkip: calls.call('skip'),
        onContinue: calls.call('continue'),
        onSwitchOn: calls.call('switchOn'),
        themeChosen: themeChosen,
        onChooseTheme:
            onChooseTheme ??
            (id) async {
              calls.names.add('theme $id');
            },
      ),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  testWidgets('the host starting shows a working panel', (tester) async {
    await pumpSetup(tester, phase: HostPhase.starting);
    expect(find.text('Starting the myData host'), findsOneWidget);
    expect(find.byType(KiwiLoader), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a download shows its percent and bytes, and Skip for now', (tester) async {
    final calls = await pumpSetup(
      tester,
      status: statusWith(
        ModelOutStateEnum.pulling,
        progress: Progress(completed: 4200000000, total: 10000000000, percent: 42, status: 'pulling'),
      ),
    );
    expect(find.textContaining('42%'), findsOneWidget);
    expect(find.textContaining('4.2 GB of 10.0 GB'), findsOneWidget);
    // Skipping switches the assistant off, and the host then stops the download: the screen says so.
    expect(find.textContaining('Skipping stops the download'), findsOneWidget);
    expect(find.text('Downloading qwen3:14b'), findsOneWidget);
    expect(tester.widget<MyDataProgressBar>(find.byType(MyDataProgressBar)).value, closeTo(0.42, 1e-9));
    await tester.tap(find.text('Skip for now'));
    expect(calls.names, ['skip']);
  });

  testWidgets('Ollama missing says how to install it, with Retry and Skip', (tester) async {
    final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ollamaMissing));
    expect(find.text('Ollama is not installed'), findsOneWidget);
    expect(find.textContaining('Install Ollama from ollama.com'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(calls.names, ['retryModel']);
  });

  testWidgets('a ready model offers Continue', (tester) async {
    final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ready));
    expect(find.textContaining('qwen3:14b is ready'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(calls.names, ['continue']);
  });

  testWidgets('a model error shows the detail and Retry', (tester) async {
    final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.error, error: 'pull failed: disk full'));
    expect(find.text('pull failed: disk full'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Skip for now'));
    expect(calls.names, ['retryModel', 'skip']);
  });

  testWidgets('a host that failed to start shows the detail and Retry', (tester) async {
    final calls = await pumpSetup(
      tester,
      phase: HostPhase.failedToStart,
      error: 'The myData host did not start.',
      detail: 'mydatad exited with code 1',
    );
    expect(find.text('The myData host did not start.'), findsOneWidget);
    expect(find.text('mydatad exited with code 1'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(calls.names, ['retryHost']);
  });

  testWidgets('replacing a host from another build says so, with nothing to press', (tester) async {
    await pumpSetup(tester, phase: HostPhase.restarting);
    expect(find.text('Restarting the myData host'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a host from another build that is still there names both versions', (tester) async {
    final calls = await pumpSetup(
      tester,
      phase: HostPhase.incompatible,
      error: 'This app and the myData host are from different builds.',
      detail: 'The host is version 0.0.9 (API 000000000000); this app expects version 0.1.0 (API 984fcb90ce8f).',
    );
    expect(find.text('This app and the myData host are from different builds.'), findsOneWidget);
    expect(find.textContaining('API 000000000000'), findsOneWidget);
    expect(find.textContaining('did not start'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(calls.names, ['retryHost']);
  });

  testWidgets('a host that started but does not answer does not say it did not start', (tester) async {
    await pumpSetup(
      tester,
      phase: HostPhase.unreachable,
      error: 'The myData host started but is not answering.',
      detail: 'running; model ready\nNo answer within 60 seconds.',
    );
    expect(find.text('The myData host started but is not answering.'), findsOneWidget);
    expect(find.textContaining('did not start'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a host that is not configured tells the developer what to run', (tester) async {
    await pumpSetup(
      tester,
      phase: HostPhase.notConfigured,
      error: 'There is no command to start the myData host with.',
      detail: 'Development: run `uv run mydata dev-setup` in host/ once, then retry.',
    );
    expect(find.textContaining('uv run mydata dev-setup'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('every host phase and model state shows a panel, and every failure a Retry', (tester) async {
    for (final phase in HostPhase.values) {
      await pumpSetup(
        tester,
        phase: phase,
        status: phase == HostPhase.running ? statusWith(ModelOutStateEnum.ready) : null,
      );
      expect(find.byType(StatusPanel), findsOneWidget, reason: '$phase');
      const failures = {
        HostPhase.notConfigured,
        HostPhase.failedToStart,
        HostPhase.unreachable,
        HostPhase.refused,
        HostPhase.incompatible,
        HostPhase.lost,
        HostPhase.unsupported,
      };
      if (failures.contains(phase)) expect(find.text('Retry'), findsOneWidget, reason: '$phase');
    }
    for (final state in ModelOutStateEnum.values) {
      await pumpSetup(tester, status: statusWith(state));
      expect(find.byType(StatusPanel), findsOneWidget, reason: '$state');
    }
  });

  testWidgets('a switched-off assistant offers Continue and switching it on', (tester) async {
    final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.disabled, enabled: false));
    expect(find.text('The assistant is off'), findsOneWidget);
    await tester.tap(find.text('Switch the assistant on'));
    await tester.tap(find.text('Continue'));
    expect(calls.names, ['switchOn', 'continue']);
  });

  group('the theme step', () {
    testWidgets('shows first, with Kiwi selected, only when no theme was chosen', (tester) async {
      await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ready), themeChosen: false);
      expect(find.text(ThemeStep.title), findsOneWidget);
      expect(find.text(ThemeStep.sentence), findsOneWidget);
      expect(tester.widget<ThemePicker>(find.byType(ThemePicker)).selected, 'kiwi');
      expect(find.byType(ThemeSample), findsOneWidget);
      expect(find.text('myData is ready'), findsNothing);

      await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ready));
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text('myData is ready'), findsOneWidget);
    });

    testWidgets('waits for the host: not shown while it starts', (tester) async {
      await pumpSetup(tester, phase: HostPhase.starting, themeChosen: false);
      expect(find.text(ThemeStep.title), findsNothing);
      expect(find.text('Starting the myData host'), findsOneWidget);
    });

    testWidgets('stores Kiwi when the person keeps it', (tester) async {
      final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ready), themeChosen: false);
      await tester.ensureVisible(find.text(ThemeStep.useLabel));
      await tester.tap(find.text(ThemeStep.useLabel));
      await tester.pump();
      expect(calls.names, ['theme kiwi']);
    });

    testWidgets('previews a picked theme at once and stores it with Use this theme', (tester) async {
      final calls = await pumpSetup(tester, status: statusWith(ModelOutStateEnum.ready), themeChosen: false);
      await tester.tap(find.text('Graphite'));
      await tester.pump();
      expect(calls.names, isEmpty, reason: 'nothing is stored until the person confirms');
      expect(tester.widget<ThemeSample>(find.byType(ThemeSample)).themeId, 'graphite');
      final button = find.ancestor(of: find.text(ThemeStep.useLabel), matching: find.byType(Button));
      expect(Theme.of(tester.element(button)).extension<MyDataColors>()!.accent, MyDataThemes.graphite.accentLight);
      await tester.ensureVisible(find.text(ThemeStep.useLabel));
      await tester.tap(find.text(ThemeStep.useLabel));
      await tester.pump();
      expect(calls.names, ['theme graphite']);
    });

    testWidgets('says so when the theme could not be stored, and stays', (tester) async {
      await pumpSetup(
        tester,
        status: statusWith(ModelOutStateEnum.ready),
        themeChosen: false,
        onChooseTheme: (_) async => throw StateError('The host is not connected.'),
      );
      await tester.ensureVisible(find.text(ThemeStep.useLabel));
      await tester.tap(find.text(ThemeStep.useLabel));
      await tester.pump();
      expect(find.text(ThemeStep.failed), findsOneWidget);
      expect(find.text(ThemeStep.title), findsOneWidget);
    });
  });
}
