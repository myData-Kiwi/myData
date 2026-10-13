import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_client/api.dart';

import 'fixtures.dart';

String frame(String event, Object data) => 'event: $event\ndata: ${jsonEncode(data)}\n\n';

/// A whole reply as the host streams it.
final reply = [
  frame('conversation', {'conversation_id': 'c1'}),
  frame('progress', {'tool': 'list_events', 'label': 'Checking calendar'}),
  frame('delta', {'text': 'Thinking'}),
  frame('step', {}),
  frame('delta', {'text': 'Tomorrow you have '}),
  frame('pending_approval', {'approval': approvalJson()}),
  frame('clarify', {
    'options': [
      {'name': 'Asha Patel'},
      {'name': 'Ravi Patel'},
    ],
    'text': 'Which Patel?',
  }),
  frame('message', {'text': 'Tomorrow you have the dentist at 09:30. Café après.', 'outcome': 'answered'}),
  frame('error', {'message': 'model fell over'}),
  frame('done', {}),
].join();

/// [text] as UTF-8 bytes cut into pieces of [size] bytes, so cuts land inside lines, field names,
/// `\r\n` pairs and multi-byte characters.
Stream<List<int>> chunked(String text, int size) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += size) {
    yield bytes.sublist(i, i + size > bytes.length ? bytes.length : i + size);
  }
}

void expectWholeReply(List<AssistantEvent> events) {
  expect(events.map((e) => e.runtimeType).toList(), [
    ConversationEvent,
    ProgressEvent,
    DeltaEvent,
    StepEvent,
    DeltaEvent,
    PendingApprovalEvent,
    ClarifyEvent,
    MessageEvent,
    ErrorEvent,
    DoneEvent,
  ]);
  expect((events[0] as ConversationEvent).conversationId, 'c1');
  final progress = events[1] as ProgressEvent;
  expect((progress.tool, progress.label), ('list_events', 'Checking calendar'));
  expect((events[4] as DeltaEvent).text, 'Tomorrow you have ');
  final approval = (events[5] as PendingApprovalEvent).approval;
  expect(approval.tool, 'send_mail');
  expect(approval.args['body'], longBody);
  expect(approval.status, ApprovalOutStatusEnum.pending);
  final clarify = events[6] as ClarifyEvent;
  expect(clarify.text, 'Which Patel?');
  expect(clarify.options.map((o) => o['name']), ['Asha Patel', 'Ravi Patel']);
  final message = events[7] as MessageEvent;
  expect(message.text, 'Tomorrow you have the dentist at 09:30. Café après.');
  expect(message.outcome, 'answered');
  expect((events[8] as ErrorEvent).message, 'model fell over');
}

void main() {
  test('every event type is decoded', () async {
    expectWholeReply(await decodeAssistantEvents(chunked(reply, 1 << 20)).toList());
  });

  test('a reset event says the mode and the epoch', () async {
    final events = await decodeAssistantEvents(
      chunked(
        [
          frame('reset', {'mode': 'real', 'epoch': 3}),
          frame('reset', {'mode': 'demo'}),
          frame('conversation', {'conversation_id': 'e3.x'}),
        ].join(),
        7,
      ),
    ).toList();
    final real = events[0] as ResetEvent;
    expect((real.realMode, real.epoch), (true, 3));
    final demo = events[1] as ResetEvent;
    expect((demo.realMode, demo.epoch), (false, null));
    expect((events[2] as ConversationEvent).conversationId, 'e3.x');
  });

  test('an approval that cannot be shown whole is an error, not a card', () {
    for (final approval in [
      null,
      {...approvalJson(), 'args': {...approvalJson()['args'] as Map, 'cc': null}},
    ]) {
      expect(AssistantEvent.fromFrame('pending_approval', jsonEncode({'approval': approval})), isA<ErrorEvent>());
    }
  });

  test('frames split across chunks at every size decode the same', () async {
    for (final size in [1, 2, 3, 5, 7, 13, 64]) {
      expectWholeReply(await decodeAssistantEvents(chunked(reply, size)).toList());
      expectWholeReply(await decodeAssistantEvents(chunked(reply.replaceAll('\n', '\r\n'), size)).toList());
    }
  });

  test('multi-line data is joined with newlines; comments and unknown fields are ignored', () async {
    const raw =
        ': keep-alive\n'
        'event: delta\n'
        'id: 7\n'
        'data: {"text":\n'
        'data:  "two lines"}\n'
        '\n'
        'event: future_event\ndata: {}\n\n'
        'event: done\ndata: {}\n\n'
        'event: delta\ndata: {"text": "unfinished"}\n';
    final frames = await parseSseFrames(chunked(raw, 4)).toList();
    expect(frames.first, (event: 'delta', data: '{"text":\n "two lines"}'));
    final events = await decodeAssistantEvents(chunked(raw, 4)).toList();
    expect(events.length, 2, reason: 'unknown events are skipped and an unfinished frame is dropped');
    expect((events.first as DeltaEvent).text, 'two lines');
    expect(events.last, isA<DoneEvent>());
  });

  test('the request carries the token, accepts event-stream and sends MessageIn', () async {
    late http.BaseRequest seen;
    late String body;
    final client = MockClient.streaming((request, bodyStream) async {
      seen = request;
      body = await bodyStream.bytesToString();
      return http.StreamedResponse(chunked(reply, 9), 200, headers: {'content-type': 'text/event-stream'});
    });
    final events = await streamAssistantMessage(
      client,
      baseUrl: 'http://127.0.0.1:47821',
      token: 'tok',
      message: MessageIn(text: "What's on tomorrow?", conversationId: 'c1'),
    ).toList();
    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'http://127.0.0.1:47821/assistant/messages');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(seen.headers['Accept'], 'text/event-stream');
    expect(jsonDecode(body), {'text': "What's on tomorrow?", 'conversation_id': 'c1'});
    expectWholeReply(events);
  });

  test('a refused request becomes one error event with the host detail', () async {
    final client = MockClient(
      (request) async =>
          http.Response(jsonEncode({'detail': 'the assistant is switched off; switch it on in the myData app'}), 503),
    );
    final events = await streamAssistantMessage(
      client,
      baseUrl: 'http://h',
      token: 't',
      message: MessageIn(text: 'hi'),
    ).toList();
    expect(events, hasLength(1));
    final error = events.single as ErrorEvent;
    expect(error.statusCode, 503);
    expect(error.message, 'the assistant is switched off; switch it on in the myData app');
  });

  test('an unreachable host and a broken stream become error events', () async {
    final down = MockClient((request) async => throw http.ClientException('Connection refused'));
    final events = await streamAssistantMessage(
      down,
      baseUrl: 'http://h',
      token: 't',
      message: MessageIn(text: 'hi'),
    ).toList();
    expect((events.single as ErrorEvent).message, contains('Connection refused'));

    Stream<List<int>> breaks() async* {
      yield utf8.encode(frame('delta', {'text': 'Tomo'}));
      throw http.ClientException('Connection reset');
    }

    final broken = MockClient.streaming((request, body) async => http.StreamedResponse(breaks(), 200));
    final partial = await streamAssistantMessage(
      broken,
      baseUrl: 'http://h',
      token: 't',
      message: MessageIn(text: 'hi'),
    ).toList();
    expect(partial.first, isA<DeltaEvent>());
    expect((partial.last as ErrorEvent).message, contains('Connection reset'));
  });
}
