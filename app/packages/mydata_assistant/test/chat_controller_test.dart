import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_client/api.dart';

import 'fixtures.dart';

/// Replies with the next scripted list of events; records what was sent and decided.
class FakeBackend implements AssistantBackend {
  FakeBackend(this.replies);
  final List<List<AssistantEvent>> replies;
  final sent = <MessageIn>[];
  final decisions = <(String, bool)>[];
  Completer<ApprovalOut>? decision;

  @override
  Stream<AssistantEvent> send(MessageIn message) {
    sent.add(message);
    return Stream.fromIterable(replies.removeAt(0));
  }

  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) {
    decisions.add((approvalId, approve));
    return (decision = Completer<ApprovalOut>()).future;
  }
}

void main() {
  test('delta, then step, then message: only the final text remains', () async {
    final backend = FakeBackend([
      [
        const ConversationEvent('c1'),
        const DeltaEvent('Let me '),
        const DeltaEvent('check.'),
        const StepEvent(),
        const ProgressEvent(tool: 'list_events', label: 'Checking calendar'),
        const DeltaEvent('Tomorrow: '),
        const DeltaEvent('dentist'),
        const MessageEvent(text: 'Tomorrow you have the dentist at 09:30.', outcome: 'answered'),
        const DoneEvent(),
      ],
      [const MessageEvent(text: 'You are welcome.'), const DoneEvent()],
    ]);
    final chat = ChatController(backend);
    final streamed = <String>[];
    chat.addListener(() {
      final reply = chat.items.whereType<AssistantReply>().lastOrNull;
      if (reply != null && reply.streaming) streamed.add(reply.text);
    });

    final sending = chat.send("What's on my calendar tomorrow?");
    expect(chat.busy, isTrue);
    await sending;

    expect(chat.busy, isFalse);
    expect(chat.conversationId, 'c1');
    expect(streamed, containsAllInOrder(['Let me ', 'Let me check.', 'Tomorrow: ', 'Tomorrow: dentist']));
    final items = chat.items;
    expect(items.map((i) => i.runtimeType), [UserMessage, ProgressLine, AssistantReply]);
    expect((items[0] as UserMessage).text, "What's on my calendar tomorrow?");
    expect((items[1] as ProgressLine).label, 'Checking calendar');
    expect((items[1] as ProgressLine).done, isTrue);
    final reply = items[2] as AssistantReply;
    expect(reply.text, 'Tomorrow you have the dentist at 09:30.');
    expect(reply.streaming, isFalse);
    expect(reply.outcome, 'answered');

    await chat.send('Thanks');
    expect(backend.sent.last.conversationId, 'c1', reason: 'the next message continues the conversation');
    expect(chat.items.whereType<AssistantReply>().map((r) => r.text), [
      'Tomorrow you have the dentist at 09:30.',
      'You are welcome.',
    ]);
  });

  test('a progress line is running until the run moves on', () async {
    final events = StreamController<AssistantEvent>();
    final chat = ChatController(_StreamBackend(events.stream));
    final sending = chat.send('hi');
    events.add(const ProgressEvent(tool: 'list_events', label: 'Checking calendar'));
    await pumpEventQueue();
    expect(chat.items.whereType<ProgressLine>().single.done, isFalse);
    events.add(const DeltaEvent('Tomorrow'));
    await pumpEventQueue();
    expect(chat.items.whereType<ProgressLine>().single.done, isTrue);
    events
      ..add(const MessageEvent(text: 'Tomorrow is free.'))
      ..add(const DoneEvent());
    await events.close();
    await sending;
  });

  test('a pending approval creates an approval item that can be decided', () async {
    final backend = FakeBackend([
      [
        const ConversationEvent('c1'),
        const ProgressEvent(tool: 'send_mail', label: 'Preparing email'),
        PendingApprovalEvent(approval()),
        const MessageEvent(text: "I've prepared that. It is waiting for your approval.", outcome: 'pending_approval'),
        const DoneEvent(),
      ],
    ]);
    final chat = ChatController(backend);
    await chat.send('Email Rishita about the dentist');

    expect(chat.items.map((i) => i.runtimeType), [UserMessage, ProgressLine, AssistantReply, ApprovalItem]);
    final item = chat.items.last as ApprovalItem;
    expect(item.approval.id, 'ap_1');
    expect(item.approval.args['body'], longBody);

    final deciding = chat.decide('ap_1', true);
    expect(item.deciding, isTrue);
    await chat.decide('ap_1', true);
    expect(backend.decisions, [('ap_1', true)], reason: 'a second tap while deciding sends nothing');
    backend.decision!.complete(approval(status: 'approved', decidedBy: 'app:myassistant', result: {'status': 'sent'}));
    await deciding;
    expect(item.deciding, isFalse);
    expect(item.approval.status, ApprovalOutStatusEnum.approved);
    expect(item.approval.decidedBy, 'app:myassistant');
  });

  test('a failed decision keeps the call pending with the reason', () async {
    final backend = FakeBackend([
      [PendingApprovalEvent(approval()), const MessageEvent(text: 'Waiting.'), const DoneEvent()],
    ]);
    final chat = ChatController(backend);
    await chat.send('Email Rishita');
    final deciding = chat.decide('ap_1', false);
    backend.decision!.completeError(ApiException(409, '{"detail": "approval ap_1 was already decided"}'));
    await deciding;
    final item = chat.items.whereType<ApprovalItem>().single;
    expect(item.approval.status, ApprovalOutStatusEnum.pending);
    expect(item.error, 'approval ap_1 was already decided');
  });

  test('an error drops the provisional reply and can be retried', () async {
    final backend = FakeBackend([
      [const DeltaEvent('Tomo'), const ErrorEvent('the model is not ready yet; see GET /status', statusCode: 503)],
      [const MessageEvent(text: 'Tomorrow is free.'), const DoneEvent()],
    ]);
    final chat = ChatController(backend);
    await chat.send('Tomorrow?');
    expect(chat.items.map((i) => i.runtimeType), [UserMessage, ChatError]);
    final error = chat.items.last as ChatError;
    expect(error.message, 'the model is not ready yet; see GET /status');
    expect(error.statusCode, 503);

    await chat.retry(error);
    expect(backend.sent.map((m) => m.text), ['Tomorrow?', 'Tomorrow?']);
    expect(chat.items.map((i) => i.runtimeType), [UserMessage, AssistantReply]);
    expect((chat.items.last as AssistantReply).text, 'Tomorrow is free.');
  });

  test('a reply that ends without a message is an error, not a silent stop', () async {
    final chat = ChatController(
      FakeBackend([
        [const ConversationEvent('c1'), const DeltaEvent('Tomo')],
      ]),
    );
    await chat.send('Tomorrow?');
    expect(chat.items.last, isA<ChatError>());
    expect(chat.busy, isFalse);
  });

  group('a switch between demo and real mode', () {
    List<String> notices(ChatController chat) => [for (final n in chat.items.whereType<ConversationNotice>()) n.text];

    test('the first status only records the epoch', () {
      final chat = ChatController(FakeBackend([]));
      chat.followHost(hostAt(epoch: 4, real: true));
      chat.followHost(hostAt(epoch: 4, real: true));
      expect(chat.items, isEmpty);
    });

    test('a new epoch ends the conversation and adds one line; the next message starts a new one', () async {
      final backend = FakeBackend([
        [const ConversationEvent('c1'), const MessageEvent(text: 'Hello.'), const DoneEvent()],
        [const ConversationEvent('e1.new'), const MessageEvent(text: 'Hi again.'), const DoneEvent()],
        [const ConversationEvent('e1.new'), const MessageEvent(text: 'Yes.'), const DoneEvent()],
      ]);
      final chat = ChatController(backend);
      var notified = 0;
      chat.addListener(() => notified++);
      chat.followHost(hostAt(epoch: 0));
      await chat.send('Hi');
      expect(chat.conversationId, 'c1');

      notified = 0;
      chat.followHost(hostAt(epoch: 1, real: true));
      expect(notified, 1);
      expect(chat.conversationId, isNull);
      expect(chat.items.last, isA<ConversationNotice>());
      expect(notices(chat), [ConversationNotice.realText]);
      expect(
        ConversationNotice.realText,
        'myAssistant now uses your contacts and calendars. A new conversation has started.',
      );
      // Later polls with the same epoch change nothing.
      chat.followHost(hostAt(epoch: 1, real: true));
      chat.followHost(hostAt(epoch: 1, real: true));
      expect(notices(chat), hasLength(1));

      await chat.send('Hi again');
      expect(backend.sent[1].conversationId, isNull, reason: 'the message after a switch starts a new conversation');
      await chat.send('And?');
      expect(backend.sent[2].conversationId, 'e1.new');
      expect(notices(chat), hasLength(1));

      // Back to demo: one more line, in demo words.
      chat.followHost(hostAt(epoch: 2));
      expect(notices(chat), [ConversationNotice.realText, ConversationNotice.demoText]);
      expect(ConversationNotice.demoText, 'myAssistant is back on example data. A new conversation has started.');
    });

    test('two switches with nothing said in between leave one line, for the latest', () {
      final chat = ChatController(FakeBackend([]));
      chat.followHost(hostAt(epoch: 0));
      chat.followHost(hostAt(epoch: 1, real: true));
      chat.followHost(hostAt(epoch: 2));
      expect(notices(chat), [ConversationNotice.demoText]);
    });

    test('a switch seen while a reply comes in is shown after the reply', () async {
      final events = StreamController<AssistantEvent>();
      final chat = ChatController(_StreamBackend(events.stream));
      chat.followHost(hostAt(epoch: 0));
      final sending = chat.send('Hi');
      events.add(const ConversationEvent('c1'));
      await pumpEventQueue();
      chat.followHost(hostAt(epoch: 1, real: true));
      expect(notices(chat), isEmpty);
      events
        ..add(const MessageEvent(text: 'Hello.'))
        ..add(const DoneEvent());
      await events.close();
      await sending;
      expect(chat.items.map((i) => i.runtimeType), [UserMessage, AssistantReply, ConversationNotice]);
      expect(chat.conversationId, isNull);
    });

    test("the host's reset event shows the line before the message, once, even when the poll comes after", () async {
      final backend = FakeBackend([
        [const ConversationEvent('c1'), const MessageEvent(text: 'Hello.'), const DoneEvent()],
        [
          const ResetEvent(realMode: true, epoch: 1),
          const ConversationEvent('e1.new'),
          const MessageEvent(text: 'Hi again.'),
          const DoneEvent(),
        ],
        [const ConversationEvent('e1.new'), const MessageEvent(text: 'Yes.'), const DoneEvent()],
      ]);
      final chat = ChatController(backend);
      chat.followHost(hostAt(epoch: 0));
      await chat.send('Hi');
      await chat.send('Hi again'); // sent before the poll saw the switch
      expect(backend.sent[1].conversationId, 'c1');
      expect(chat.conversationId, 'e1.new');
      expect(chat.items.map((i) => i.runtimeType), [
        UserMessage,
        AssistantReply,
        ConversationNotice,
        UserMessage,
        AssistantReply,
      ]);
      chat.followHost(hostAt(epoch: 1, real: true)); // the poll catches up: nothing new
      expect(notices(chat), [ConversationNotice.realText]);
      await chat.send('And?');
      expect(backend.sent[2].conversationId, 'e1.new');
    });
  });

  test('blank messages and messages while busy are not sent', () async {
    final events = StreamController<AssistantEvent>();
    final backend = _StreamBackend(events.stream);
    final chat = ChatController(backend);
    await chat.send('   ');
    expect(chat.items, isEmpty);
    final first = chat.send('one');
    await chat.send('two');
    expect(chat.items.whereType<UserMessage>().map((m) => m.text), ['one']);
    events.add(const MessageEvent(text: 'ok'));
    await events.close();
    await first;
  });
}

class _StreamBackend implements AssistantBackend {
  _StreamBackend(this.stream);
  final Stream<AssistantEvent> stream;

  @override
  Stream<AssistantEvent> send(MessageIn message) => stream;

  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) => throw UnimplementedError();
}
