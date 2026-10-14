import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _id = '2f1c9a52-7d3e-4b8a-9c61-0e5d4f3a2b10';

const _contacts = [
  {'id': _id, 'name': 'Ava Fictional', 'email': 'ava@example.com', 'phone': '+1 202 555 0101'},
];
const _events = [
  {'title': 'Dentist (invented)', 'date': '2026-03-20', 'day': 'Friday 20 March', 'start': '15:00', 'end': '16:00'},
];

void main() {
  group('the result frame', () {
    test('says whether its items are the user\'s own', () {
      ResultEvent parse(String mode) =>
          AssistantEvent.fromFrame('result', '{"kind":"contacts","header":"h","items":[]$mode}')! as ResultEvent;
      expect(parse(',"mode":"real"').realMode, isTrue);
      expect(parse(',"mode":"demo"').realMode, isFalse);
      expect(parse('').realMode, isFalse); // an older host: treated as sample data
    });
  });

  group('ResultCard.linkFor', () {
    test('a contact by its id, an event by its day', () {
      expect(ResultCard.linkFor('contacts', _contacts.single), OpenContact(_id));
      expect(ResultCard.linkFor('events', _events.single), OpenDay(DateTime(2026, 3, 20)));
    });

    test('nothing for other kinds, or items without a valid id or day', () {
      expect(ResultCard.linkFor('mail', {'id': 'm1', 'date': '2026-03-20'}), isNull);
      expect(ResultCard.linkFor('photos', {'id': 'p1'}), isNull);
      expect(ResultCard.linkFor('event_created', {'date': '2026-03-20'}), isNull);
      expect(ResultCard.linkFor('contacts', {'name': 'No id'}), isNull);
      expect(ResultCard.linkFor('contacts', {'id': '../etc'}), isNull);
      expect(ResultCard.linkFor('events', {'date': '2026-02-30'}), isNull);
      expect(ResultCard.linkFor('events', {'date': 20260320}), isNull);
    });
  });

  group('rows that open their item', () {
    late List<MyDataLink> opened;
    setUp(() => opened = []);

    Future<void> show(
      WidgetTester tester,
      String kind,
      List<Map<String, Object?>> items, {
      bool realMode = true,
      Set<MyDataAppId> installed = const {MyDataAppId.mycontacts, MyDataAppId.mycalendar},
      bool links = true,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: MyDataTheme.data('kiwi', Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultCard(
              kind: kind,
              header: 'Header',
              items: items,
              realMode: realMode,
              links: links ? ResultLinks(installed: installed, onOpen: opened.add) : null,
            ),
          ),
        ),
      ),
    );

    testWidgets('a real contact opens in myContacts, with a chevron and a hint', (tester) async {
      final semantics = tester.ensureSemantics();
      await show(tester, 'contacts', _contacts);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('Ava Fictional'));
      expect(opened, [OpenContact(_id)]);
      expect(
        tester.getSemantics(find.text('Ava Fictional')),
        matchesSemantics(
          label: 'Ava Fictional\nava@example.com\n+1 202 555 0101',
          hint: 'Opens in myContacts',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a real event opens its day in myCalendar, also from the keyboard', (tester) async {
      await show(tester, 'events', _events);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(opened, [OpenDay(DateTime(2026, 3, 20))]);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(opened, hasLength(2));
    });

    testWidgets('the hover fills the row with surface-sunken', (tester) async {
      tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
      await show(tester, 'events', _events);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Dentist (invented)')));
      addTearDown(mouse.removePointer);
      await tester.pumpAndSettle();
      final fill = tester
          .widgetList<AnimatedContainer>(
            find.ancestor(of: find.text('Dentist (invented)'), matching: find.byType(AnimatedContainer)),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>();
      expect(fill, contains(MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!.surfaceHover));
    });

    testWidgets('not interactive when its app is not installed', (tester) async {
      await show(tester, 'contacts', _contacts, installed: {MyDataAppId.mycalendar});
      expect(find.byType(Pressable), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      await tester.tap(find.text('Ava Fictional'));
      expect(opened, isEmpty);
    });

    testWidgets('never for sample data (demo mode), even with the app installed', (tester) async {
      await show(tester, 'contacts', _contacts, realMode: false);
      await show(tester, 'events', _events, realMode: false);
      expect(find.byType(Pressable), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('never without links, and never for mail or photos', (tester) async {
      await show(tester, 'events', _events, links: false);
      expect(find.byType(Pressable), findsNothing);
      await show(tester, 'mail', [
        {'id': 'm1', 'from': 'Ava Fictional', 'subject': 'Hello', 'date': '2026-03-20', 'day': 'Friday 20 March'},
      ]);
      expect(find.byType(Pressable), findsNothing);
    });

    testWidgets('only the items with an id or a day open', (tester) async {
      await show(tester, 'contacts', [
        ..._contacts,
        {'name': 'Sam Example', 'email': 'sam@example.com'},
      ]);
      expect(find.byType(Pressable), findsOneWidget);
      await tester.tap(find.text('Sam Example'));
      expect(opened, isEmpty);
    });
  });

  testWidgets('the chat passes its links to every result', (tester) async {
    final opened = <MyDataLink>[];
    final chat = ChatController(
      _Backend([
        const ConversationEvent('c'),
        const ResultEvent(
          tool: 'find_contact',
          kind: 'contacts',
          header: 'Ava Fictional',
          items: _contacts,
          realMode: true,
        ),
        const MessageEvent(text: 'Ava Fictional', outcome: 'answered', byCode: true),
        const DoneEvent(),
      ]),
    );
    await chat.send("Ava's number");
    expect(chat.items.whereType<ResultItem>().single.realMode, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        theme: MyDataTheme.data('kiwi', Brightness.light),
        home: Scaffold(
          body: ChatView(
            controller: chat,
            links: ResultLinks(installed: const {MyDataAppId.mycontacts}, onOpen: opened.add),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ava@example.com'));
    expect(opened, [OpenContact(_id)]);
  });
}

class _Backend implements AssistantBackend {
  _Backend(this.events);
  final List<AssistantEvent> events;
  @override
  Stream<AssistantEvent> send(MessageIn message) => Stream.fromIterable(events);
  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) => throw UnimplementedError();
}
