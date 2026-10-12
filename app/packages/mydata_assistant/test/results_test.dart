import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

class _Backend implements AssistantBackend {
  _Backend(this.events);
  final List<AssistantEvent> events;
  @override
  Stream<AssistantEvent> send(MessageIn message) => Stream.fromIterable(events);
  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) => throw UnimplementedError();
}

const _events = ResultEvent(tool: 'list_events', kind: 'events', header: '2 events on Thursday 19 March', items: [
  {'title': 'Personal training', 'day': 'Thursday 19 March', 'start': '06:30', 'end': '07:30', 'location': 'Gym'},
  {'title': 'Call with mum', 'day': 'Thursday 19 March', 'start': '20:00', 'end': '20:30', 'location': null},
]);

void main() {
  test('the result frame parses, with its header and items', () {
    final e = AssistantEvent.fromFrame('result',
        '{"tool":"find_contact","kind":"contacts","header":"Priya Nair","items":[{"name":"Priya Nair","email":"p@x.com"}]}');
    expect(e, isA<ResultEvent>());
    final r = e! as ResultEvent;
    expect((r.kind, r.header, r.items.single['email']), ('contacts', 'Priya Nair', 'p@x.com'));
    final m = AssistantEvent.fromFrame('message', '{"text":"Priya Nair","outcome":"answered","by":"code"}');
    expect((m! as MessageEvent).byCode, isTrue);
  });

  test('a result answered by code shows the card and no extra bubble', () async {
    final chat = ChatController(_Backend([
      const ConversationEvent('c'),
      const ProgressEvent(tool: 'list_events', label: 'Checking calendar'),
      _events,
      const MessageEvent(text: '2 events on Thursday 19 March', outcome: 'answered', byCode: true),
      const DoneEvent(),
    ]));
    await chat.send("What's on tomorrow?");
    expect(chat.items.whereType<ResultItem>().single.header, '2 events on Thursday 19 March');
    expect(chat.items.whereType<AssistantReply>(), isEmpty);
    expect(chat.items.whereType<ChatError>(), isEmpty);
  });

  test('a model sentence after the result is shown under it', () async {
    final chat = ChatController(_Backend([
      const ConversationEvent('c'),
      _events,
      const DeltaEvent('No, '),
      const DeltaEvent('you have training at 6:30.'),
      const MessageEvent(text: 'No, you have training at 6:30.', outcome: 'answered'),
      const DoneEvent(),
    ]));
    await chat.send('Am I free at 6:30 tomorrow?');
    final kinds = chat.items.map((i) => i.runtimeType).toList();
    expect(kinds.indexOf(ResultItem), lessThan(kinds.indexOf(AssistantReply)));
    expect(chat.items.whereType<AssistantReply>().single.text, 'No, you have training at 6:30.');
  });

  testWidgets('the result card shows the header and every item', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: myDataTheme(),
        home: Scaffold(body: ResultCard(kind: _events.kind, header: _events.header, items: _events.items))));
    expect(find.text('2 events on Thursday 19 March'), findsOneWidget);
    expect(find.text('Personal training'), findsOneWidget);
    expect(find.text('Call with mum'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
  });
}
