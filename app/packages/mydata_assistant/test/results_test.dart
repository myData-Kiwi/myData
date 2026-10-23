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

  Future<void> showCard(WidgetTester tester, String kind, String header, List<Map<String, Object?>> items) =>
      tester.pumpWidget(MaterialApp(
          theme: MyDataTheme.data('kiwi', Brightness.light),
          home: Scaffold(body: SingleChildScrollView(child: ResultCard(kind: kind, header: header, items: items)))));

  testWidgets('the result card shows the header and every item', (tester) async {
    await showCard(tester, _events.kind, _events.header, _events.items);
    expect(find.text('2 events on Thursday 19 March'), findsOneWidget);
    expect(find.text('Personal training'), findsOneWidget);
    expect(find.text('Call with mum'), findsOneWidget);
    expect(find.textContaining('Gym'), findsOneWidget);
    // Times on this device's clock, as every app writes them (MyDataDates): 12-hour in tests.
    expect(find.textContaining('6:30 am to 7:30 am'), findsOneWidget);
    expect(find.textContaining('8:00 pm to 8:30 pm'), findsOneWidget);
  });

  testWidgets('the header is body-strong on the ground; the items are a grouped list with calendar tiles',
      (tester) async {
    await showCard(tester, _events.kind, _events.header, _events.items);
    final header = tester.widget<Text>(find.text('2 events on Thursday 19 March'));
    expect(header.style?.fontWeight, MyDataType.bodyStrong.fontWeight);
    expect(header.style?.fontSize, MyDataType.bodyStrong.fontSize);
    expect(find.ancestor(of: find.text('2 events on Thursday 19 March'), matching: find.byType(GroupedList)),
        findsNothing);
    expect(find.byType(GroupedList), findsOneWidget);
    final tiles = tester.widgetList<IconTile>(find.byType(IconTile)).toList();
    expect(tiles, hasLength(2));
    expect(tiles.every((t) => t.icon == Icons.event_outlined && t.tone == MyDataTone.accent), isTrue);
  });

  testWidgets('mail: sender, subject, snippet and day', (tester) async {
    await showCard(tester, 'mail', '1 email from Priya', [
      {'from': 'Priya Nair', 'subject': 'Slides 4 to 9', 'day': '17 March', 'snippet': 'Here are the slides.'},
    ]);
    for (final t in ['Priya Nair', 'Slides 4 to 9', '17 March', 'Here are the slides.']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  testWidgets('contacts: the name, and the address and phone in mono', (tester) async {
    await showCard(tester, 'contacts', 'Priya Nair', [
      {'name': 'Priya Nair', 'email': 'priya@example.com', 'phone': '+64 21 555 0101'},
    ]);
    expect(find.text('Priya Nair'), findsNWidgets(2)); // the header and the row
    for (final t in ['priya@example.com', '+64 21 555 0101']) {
      expect(tester.widget<Text>(find.text(t)).style?.fontFamily, MyDataType.mono.fontFamily);
    }
  });

  testWidgets('photos: place, day and people', (tester) async {
    await showCard(tester, 'photos', '1 photo from Goa', [
      {'place': 'Goa', 'day': '24 December 2025', 'people': ['Asha', 'Ravi']},
    ]);
    expect(find.text('Goa'), findsOneWidget);
    expect(find.text('24 December 2025 · Asha, Ravi'), findsOneWidget);
  });

  testWidgets('a created event is one row carrying the header; an empty result is the header alone', (tester) async {
    await showCard(tester, 'event_created', 'Added Dentist on Friday 20 March at 09:30', [
      {'title': 'Dentist'},
    ]);
    expect(find.text('Added Dentist on Friday 20 March at 09:30'), findsOneWidget);
    expect(find.byType(GroupedList), findsOneWidget);
    expect(find.text('Dentist'), findsNothing);

    await showCard(tester, 'events', 'No events on Friday 20 March', const []);
    expect(find.text('No events on Friday 20 March'), findsOneWidget);
    expect(find.byType(GroupedList), findsNothing);
  });

  test('every kind of result uses one of at most three tile tones', () {
    final tones = {for (final k in ['events', 'event_created', 'mail', 'contacts', 'photos', 'other']) ResultCard.toneFor(k)};
    expect(tones.length, lessThanOrEqualTo(GroupedList.maxTileTones));
  });
}
