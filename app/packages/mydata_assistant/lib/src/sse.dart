import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mydata_client/api.dart';

import 'events.dart';
import 'host_errors.dart';

/// One server-sent event frame: its `event:` name and its `data:` lines joined by newlines.
typedef SseFrame = ({String event, String data});

/// Splits a byte stream into SSE frames as bytes arrive. Chunks may end anywhere, even inside a
/// UTF-8 character or between `\r` and `\n`. A frame left unfinished when the stream ends is dropped,
/// as the SSE spec says.
Stream<SseFrame> parseSseFrames(Stream<List<int>> bytes) async* {
  var event = '';
  final data = StringBuffer();
  var hasData = false;
  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (hasData) yield (event: event.isEmpty ? 'message' : event, data: data.toString());
      event = '';
      data.clear();
      hasData = false;
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        event = value;
      case 'data':
        if (hasData) data.write('\n');
        data.write(value);
        hasData = true;
    }
  }
}

/// The typed events in an SSE byte stream from `POST /assistant/messages`.
Stream<AssistantEvent> decodeAssistantEvents(Stream<List<int>> bytes) async* {
  await for (final frame in parseSseFrames(bytes)) {
    final event = AssistantEvent.fromFrame(frame.event, frame.data);
    if (event != null) yield event;
  }
}

/// Sends one message to the assistant and yields its reply as typed events.
///
/// Failures never surface as stream errors: a refused request (503 when the assistant is switched off
/// or the model is not ready), an unreachable host or a broken stream each become one [ErrorEvent]
/// carrying the host's own words where it gave some.
Stream<AssistantEvent> streamAssistantMessage(
  http.Client client, {
  required String baseUrl,
  required String token,
  required MessageIn message,
}) async* {
  final request = http.Request('POST', Uri.parse('$baseUrl/assistant/messages'))
    ..headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'text/event-stream',
      'Content-Type': 'application/json',
    })
    ..body = jsonEncode(message.toJson());
  final http.StreamedResponse response;
  try {
    response = await client.send(request);
  } on Object catch (e) {
    yield ErrorEvent('Could not reach the myData host: $e');
    return;
  }
  if (response.statusCode != 200) {
    final body = await response.stream.bytesToString().catchError((Object _) => '');
    yield ErrorEvent(
      hostDetail(body) ?? 'The myData host answered ${response.statusCode}.',
      statusCode: response.statusCode,
    );
    return;
  }
  try {
    // `await for`, not `yield*`: errors must surface here to become an event.
    await for (final event in decodeAssistantEvents(response.stream)) {
      yield event;
    }
  } on Object catch (e) {
    yield ErrorEvent('The connection to the myData host broke during the reply: $e');
  }
}
