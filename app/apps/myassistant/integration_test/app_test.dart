// End to end against the real host and model. Not run in CI; run it by hand on macOS:
//
//   cd host && uv run mydata dev-setup          # once: writes the start command into the host folder
//   cd app/apps/myassistant
//   flutter test integration_test/app_test.dart -d macos --dart-define=MYDATA_HOME=<host folder>
//
// The app starts the host itself if it is not running, and leaves it running afterwards.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:myassistant/src/app.dart';

/// Pumps real time until [done] is true, failing after [timeout].
Future<void> pumpUntil(WidgetTester tester, bool Function() done, {required Duration timeout, String? what}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out after $timeout waiting for ${what ?? 'a condition'}.');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('asks about tomorrow and gets a streamed answer', (tester) async {
    await tester.pumpWidget(MyAssistantApp(host: HostController(app: 'myassistant')));

    // Starting the host and getting the model ready can take a while on a cold machine.
    await pumpUntil(
      tester,
      () => find.byKey(ChatView.inputKey).evaluate().isNotEmpty,
      timeout: const Duration(minutes: 3),
      what: 'the chat input (host running, model ready)',
    );

    final chat = tester.widget<ChatView>(find.byType(ChatView)).controller;
    // Every length the reply had while it was still streaming, before the final message replaced it.
    final streamedLengths = <int>[];
    void sample() {
      final reply = chat.items.whereType<AssistantReply>().lastOrNull;
      if (reply != null && reply.streaming) streamedLengths.add(reply.text.length);
    }

    chat.addListener(sample);
    addTearDown(() => chat.removeListener(sample));

    await tester.enterText(find.byKey(ChatView.inputKey), "What's on my calendar tomorrow?");
    await tester.tap(find.byKey(ChatView.sendKey));
    await tester.pump();
    expect(chat.busy, isTrue);

    await pumpUntil(tester, () => !chat.busy, timeout: const Duration(minutes: 3), what: 'the reply');

    expect(
      chat.items.whereType<ChatError>(),
      isEmpty,
      reason: chat.items.whereType<ChatError>().map((e) => e.message).join('\n'),
    );
    expect(
      chat.items.whereType<ProgressLine>(),
      isNotEmpty,
      reason: 'expected a progress line such as "Checking calendar"',
    );
    expect(find.textContaining(chat.items.whereType<ProgressLine>().first.label), findsWidgets);

    final grew = [for (var i = 1; i < streamedLengths.length; i++) streamedLengths[i] > streamedLengths[i - 1]];
    expect(streamedLengths.where((n) => n > 0), isNotEmpty, reason: 'no delta text arrived before the final message');
    expect(grew, contains(true), reason: 'the reply did not grow while streaming: $streamedLengths');

    final reply = chat.items.whereType<AssistantReply>().last;
    expect(reply.streaming, isFalse);
    expect(reply.text.trim(), isNotEmpty);
    expect(find.text(reply.text), findsOneWidget);
  });
}
