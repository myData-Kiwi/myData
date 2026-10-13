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

Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: MyDataTheme.data('kiwi', Brightness.light),
  home: MyDataAccessibility(
    reduceMotion: reduceMotion,
    reduceTransparency: false,
    child: Scaffold(body: child),
  ),
);

Pressable sendButton(WidgetTester tester) => tester.widget<Pressable>(find.byKey(ChatView.sendKey));

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
      'theme': 'kiwi',
      'mode': 'demo',
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
    expect(sendButton(tester).onPressed, isNull);
    // Nothing has arrived yet: the working kiwi stands in for the reply.
    expect(find.byType(KiwiLoader), findsOneWidget);

    backend.replies.last.add(const ProgressEvent(tool: 'list_events', label: 'Checking calendar'));
    await tester.pump();
    // While the tool runs: the label with an ellipsis and a small turning kiwi.
    expect(find.text('Checking calendar…'), findsOneWidget);
    expect(find.byType(KiwiLoader), findsOneWidget);

    backend.replies.last
      ..add(PendingApprovalEvent(approval()))
      ..add(const MessageEvent(text: 'It is waiting for your approval.'))
      ..add(const DoneEvent());
    await backend.replies.last.close();
    await tester.pumpAndSettle();

    expect(find.text('Checking calendar'), findsOneWidget);
    expect(find.byType(KiwiLoader), findsNothing);
    expect(find.text('It is waiting for your approval.'), findsOneWidget);
    expect(find.byType(AssistantApprovalCard), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(ChatView.inputKey)).enabled, isTrue);
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(find.text('Approve and send'));
    await tester.tap(find.text('Approve and send'));
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Approve and send'), findsNothing);
  });

  testWidgets('streamed text grows in place; the final message replaces it', (tester) async {
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    await tester.pumpWidget(app(ChatView(controller: chat)));
    await tester.enterText(find.byKey(ChatView.inputKey), 'Am I free at 6:30?');
    await tester.tap(find.byKey(ChatView.sendKey));
    await tester.pump();
    backend.replies.last.add(const DeltaEvent('No, '));
    await tester.pump();
    expect(find.text('No, '), findsOneWidget);
    expect(find.byType(KiwiLoader), findsNothing, reason: 'the streaming text is the sign of progress');
    backend.replies.last.add(const DeltaEvent('you have training.'));
    await tester.pump();
    expect(find.text('No, you have training.'), findsOneWidget);
    backend.replies.last
      ..add(const MessageEvent(text: 'No, you have training at 6:30.', outcome: 'answered'))
      ..add(const DoneEvent());
    await backend.replies.last.close();
    await tester.pumpAndSettle();
    expect(find.text('No, you have training at 6:30.'), findsOneWidget);
    expect(find.text('No, you have training.'), findsNothing);
  });

  testWidgets("the user's message is on accent-soft; the reply is plain text on the ground", (tester) async {
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    await tester.pumpWidget(app(ChatView(controller: chat)));
    await tester.enterText(find.byKey(ChatView.inputKey), 'Hello there');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    backend.replies.last
      ..add(const MessageEvent(text: 'Hello.', outcome: 'answered'))
      ..add(const DoneEvent());
    await backend.replies.last.close();
    await tester.pumpAndSettle();
    final c = tester.element(find.byType(ChatView)).colors;
    final bubble = find.ancestor(of: find.text('Hello there'), matching: find.byType(DecoratedBox)).first;
    final decoration = tester.widget<DecoratedBox>(bubble).decoration as BoxDecoration;
    expect(decoration.color, c.accentSoft);
    expect(decoration.borderRadius, MyDataRadii.lg);
    expect(tester.widget<Text>(find.text('Hello there')).style?.color, c.ink);
    // Right-aligned: the bubble ends at the column's end, the reply starts at its start.
    expect(tester.getTopRight(bubble).dx, greaterThan(tester.getTopRight(find.text('Hello.')).dx));
    final reply = find.text('Hello.');
    expect(find.ancestor(of: reply, matching: find.byType(DecoratedBox)), findsNothing);
  });

  testWidgets('the composer: placeholder, a send button named Send, and Shift+Enter does not send',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    await tester.pumpWidget(app(ChatView(controller: chat)));
    expect(find.text(ChatView.placeholder), findsOneWidget);
    expect(find.bySemanticsLabel(ChatView.sendLabel), findsOneWidget);
    expect(find.text(ChatView.emptyText), findsOneWidget);

    await tester.enterText(find.byKey(ChatView.inputKey), 'two lines');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(backend.sent, isEmpty);
    // Blank input is not sent.
    await tester.enterText(find.byKey(ChatView.inputKey), '   ');
    await tester.tap(find.byKey(ChatView.sendKey));
    expect(backend.sent, isEmpty);
    semantics.dispose();
  });

  testWidgets('the composer draws the focus ring only when reached with the keyboard', (tester) async {
    final chat = ChatController(ScriptedBackend());
    await tester.pumpWidget(app(ChatView(controller: chat)));
    await tester.pump();
    FocusRing ring() => tester.widget<FocusRing>(find.byType(FocusRing));
    final input = tester.widget<TextField>(find.byKey(ChatView.inputKey));
    expect(input.focusNode!.hasFocus, isTrue, reason: 'the input has focus at launch');
    expect(ring().visible, isFalse, reason: 'focus the app gave shows only the caret');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // on to Send
    await tester.pump();
    expect(input.focusNode!.hasFocus, isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // back to the input
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(input.focusNode!.hasFocus, isTrue);
    expect(ring().visible, isTrue);
  });

  testWidgets('with reduced motion the progress kiwi stays still', (tester) async {
    final backend = ScriptedBackend();
    final chat = ChatController(backend);
    await tester.pumpWidget(app(ChatView(controller: chat), reduceMotion: true));
    await tester.enterText(find.byKey(ChatView.inputKey), 'hi');
    await tester.tap(find.byKey(ChatView.sendKey));
    backend.replies.last.add(const ProgressEvent(tool: 'list_events', label: 'Checking calendar'));
    await tester.pump();
    expect(find.byType(KiwiLoader), findsOneWidget);
    expect(find.descendant(of: find.byType(KiwiLoader), matching: find.byType(Transform)), findsNothing);
    // Nothing animates, so the frame settles even while the tool runs.
    await tester.pumpAndSettle();
    await backend.replies.last.close();
    await tester.pumpAndSettle();
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

  testWidgets('AssistantUnavailable: switched off, it is one screen with the kiwi and the way to turn it on',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      app(AssistantUnavailable(status: status(enabled: false, state: 'disabled'), onOpenSetup: () => opened++, onCheckAgain: () {})),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('The assistant is off'), findsOneWidget);
    expect(
      find.text('myAssistant answers questions about your data. Turn it on in myData, under Settings.'),
      findsOneWidget,
    );
    expect(find.text('Check again'), findsNothing);
    await tester.tap(find.text('Open myData'));
    expect(opened, 1);

    await tester.pumpWidget(
      app(
        AssistantUnavailable(
          status: status(enabled: true, state: 'disabled'),
          notice: 'Open the myData app yourself.',
          onOpenSetup: () {},
          onCheckAgain: () {},
        ),
      ),
    );
    expect(find.text('The assistant is off'), findsOneWidget);
    expect(find.text('Open the myData app yourself.'), findsOneWidget);
  });

  testWidgets('AssistantUnavailable explains each other state and offers setup and a fresh check', (tester) async {
    var opened = 0, checked = 0;
    Future<void> show(StatusOut s, {String? notice}) => tester.pumpWidget(
      app(AssistantUnavailable(status: s, notice: notice, onOpenSetup: () => opened++, onCheckAgain: () => checked++)),
    );

    await show(status(state: 'ollama_missing'));
    expect(find.text('Ollama is not installed'), findsOneWidget);

    await show(
      status(state: 'pulling', progress: {'status': 'pulling', 'completed': 42, 'total': 100, 'percent': 42.0}),
    );
    expect(find.textContaining('Downloading qwen3:14b: 42%'), findsOneWidget);
    expect(tester.widget<MyDataProgressBar>(find.byType(MyDataProgressBar)).value, closeTo(0.42, 1e-9));

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

  test('AssistantUnavailable.openFailedNotice names the place its screen points to', () {
    // Off: the sentence and the button say Settings, so the notice does too.
    expect(
      AssistantUnavailable.openFailedNotice(status(enabled: false, state: 'disabled')),
      AssistantUnavailable.offOpenFailed,
    );
    expect(AssistantUnavailable.offOpenFailed, contains('under Settings'));
    // Every other state offers "Open myData setup", so the notice says Setup.
    for (final s in [status(state: 'ollama_missing'), status(state: 'error', error: 'x')]) {
      expect(AssistantUnavailable.openFailedNotice(s), AssistantUnavailable.setupOpenFailed);
    }
    expect(AssistantUnavailable.setupOpenFailed, contains('go to Setup'));
  });
}
