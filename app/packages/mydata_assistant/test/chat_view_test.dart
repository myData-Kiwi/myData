import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

class ScriptedBackend implements AssistantBackend {
  final sent = <String>[];
  final replies = <StreamController<AssistantEvent>>[];

  @override
  Stream<AssistantEvent> send(MessageIn message) {
    sent.add(message.text);
    replies.add(StreamController<AssistantEvent>());
    return replies.last.stream;
  }

  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) async =>
      approval(status: approve ? 'approved' : 'rejected', decidedBy: 'app:myassistant');
}

Widget app(Widget child) => MaterialApp(
  theme: legacyTheme(),
  home: Scaffold(body: child),
);

StatusOut status({bool enabled = true, String state = 'ready', Map<String, Object>? progress, String? error}) =>
    StatusOut.fromJson({
      'version': '0.1.0',
      'ready': true,
      'assistant_enabled': enabled,
      'uptime_seconds': 1.0,
      'memory': {'host_bytes': 1000},
      'agents_connected': 0,
      'today': '2026-03-18',
      'demo_date': false,
      'model': {
        'name': 'qwen3:14b',
        'state': state,
        'loaded': false,
        'ollama_reachable': true,
        'ollama_started_by_host': false,
        'progress': progress,
        'error': error,
      },
    })!;

void main() {
  testWidgets('Enter sends; the input is disabled until the reply is in', (tester) async {
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    // Tall enough to show the whole conversation, approval card included.
    tester.view
      ..physicalSize = const Size(1000, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(ChatView(controller: chat)));

    await tester.enterText(find.byKey(ChatView.inputKey), "What's on tomorrow?");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(backend.sent, ["What's on tomorrow?"]);
    expect(tester.widget<TextField>(find.byKey(ChatView.inputKey)).enabled, isFalse);
    expect(tester.widget<FilledButton>(find.byKey(ChatView.sendKey)).onPressed, isNull);

    backend.replies.last
      ..add(const ProgressEvent(tool: 'list_events', label: 'Checking calendar'))
      ..add(PendingApprovalEvent(approval()))
      ..add(const MessageEvent(text: 'It is waiting for your approval.'))
      ..add(const DoneEvent());
    await backend.replies.last.close();
    await tester.pumpAndSettle();

    expect(find.text('Checking calendar'), findsOneWidget);
    expect(find.text('It is waiting for your approval.'), findsOneWidget);
    expect(find.byType(ApprovalCard), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(ChatView.inputKey)).enabled, isTrue);

    await tester.ensureVisible(find.text('Approve'));
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Approved and sent'), findsOneWidget);
  });

  testWidgets('a failed message shows the reason and Retry sends it again', (tester) async {
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    await tester.pumpWidget(app(ChatView(controller: chat)));
    await tester.enterText(find.byKey(ChatView.inputKey), 'hello');
    await tester.tap(find.byKey(ChatView.sendKey));
    backend.replies.last.add(const ErrorEvent('the model is not ready yet; see GET /status', statusCode: 503));
    await backend.replies.last.close();
    await tester.pumpAndSettle();
    expect(find.text('the model is not ready yet; see GET /status'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(backend.sent, ['hello', 'hello']);
  });

  testWidgets('AssistantUnavailable explains each state and offers setup and a fresh check', (tester) async {
    var opened = 0, checked = 0;
    Future<void> show(StatusOut s, {String? notice}) => tester.pumpWidget(
      app(AssistantUnavailable(status: s, notice: notice, onOpenSetup: () => opened++, onCheckAgain: () => checked++)),
    );

    await show(status(enabled: false, state: 'disabled'));
    expect(find.text('The assistant is switched off'), findsOneWidget);

    await show(status(state: 'ollama_missing'));
    expect(find.text('Ollama is not installed'), findsOneWidget);

    await show(
      status(state: 'pulling', progress: {'status': 'pulling', 'completed': 42, 'total': 100, 'percent': 42.0}),
    );
    expect(find.textContaining('Downloading qwen3:14b: 42%'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, closeTo(0.42, 1e-9));

    await show(
      status(state: 'error', error: 'pull failed: disk full'),
      notice: 'Open the myData app yourself.',
    );
    expect(find.text('The model could not be prepared'), findsOneWidget);
    expect(find.text('pull failed: disk full'), findsOneWidget);
    expect(find.textContaining('Open the myData app yourself.'), findsOneWidget);

    await tester.tap(find.text('Open myData setup'));
    await tester.tap(find.text('Check again'));
    expect((opened, checked), (1, 1));
  });
}
