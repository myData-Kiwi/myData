import 'dart:convert';

import 'package:mydata_client/api.dart';

/// One server-sent event from `POST /assistant/messages`, typed.
sealed class AssistantEvent {
  const AssistantEvent();

  /// Decodes one frame. Returns null for event names this app does not know, so a newer host can add
  /// events without breaking older apps.
  static AssistantEvent? fromFrame(String event, String data) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(data);
      json = decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } on FormatException catch (e) {
      return ErrorEvent('The host sent an unreadable "$event" event: ${e.message}');
    }
    String text(String key) => json[key] is String ? json[key] as String : '';
    switch (event) {
      case 'conversation':
        return ConversationEvent(text('conversation_id'));
      case 'progress':
        return ProgressEvent(tool: text('tool'), label: text('label'));
      case 'delta':
        return DeltaEvent(text('text'));
      case 'step':
        return const StepEvent();
      case 'pending_approval':
        final approval = _approval(json['approval']);
        return approval == null
            ? const ErrorEvent(
                'A call is waiting for approval, but the host did not send its details. '
                'Review it in the myData app.',
              )
            : PendingApprovalEvent(approval);
      case 'clarify':
        final options = json['options'] is List ? json['options'] as List : const [];
        return ClarifyEvent(
          text: text('text'),
          options: [
            for (final o in options)
              if (o is Map) o.cast<String, Object?>(),
          ],
        );
      case 'message':
        return MessageEvent(text: text('text'), outcome: json['outcome'] as String?);
      case 'error':
        return ErrorEvent(text('message'));
      case 'done':
        return const DoneEvent();
    }
    return null;
  }

  static ApprovalOut? _approval(Object? json) {
    try {
      final approval = ApprovalOut.fromJson(json);
      // The generated model casts args and context lazily, so a bad value would only throw while the
      // card is being built. Copying them here turns that into the reported error instead.
      return approval
        ?..args = Map.of(approval.args)
        ..context = Map.of(approval.context);
    } on Object {
      // A malformed approval must not end the stream; the caller reports it instead.
      return null;
    }
  }
}

/// The first event of every reply: the id to send with the next message.
final class ConversationEvent extends AssistantEvent {
  const ConversationEvent(this.conversationId);
  final String conversationId;
}

/// A tool started running ("Checking calendar").
final class ProgressEvent extends AssistantEvent {
  const ProgressEvent({required this.tool, required this.label});
  final String tool;
  final String label;
}

/// Reply text as it is generated. Provisional: a [StepEvent] discards it, [MessageEvent] replaces it.
final class DeltaEvent extends AssistantEvent {
  const DeltaEvent(this.text);
  final String text;
}

/// The model moved on to tool calls: discard the delta text streamed so far.
final class StepEvent extends AssistantEvent {
  const StepEvent();
}

/// An irreversible call is held until the user approves exactly this call.
final class PendingApprovalEvent extends AssistantEvent {
  const PendingApprovalEvent(this.approval);
  final ApprovalOut approval;
}

/// A lookup matched several; [text] asks the user which one.
final class ClarifyEvent extends AssistantEvent {
  const ClarifyEvent({required this.text, required this.options});
  final String text;
  final List<Map<String, Object?>> options;
}

/// The authoritative final reply.
final class MessageEvent extends AssistantEvent {
  const MessageEvent({required this.text, this.outcome});
  final String text;
  final String? outcome;
}

/// The request failed. [statusCode] is set when the host refused it outright (503: the assistant is
/// switched off or the model is not ready).
final class ErrorEvent extends AssistantEvent {
  const ErrorEvent(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

/// The last event of a reply.
final class DoneEvent extends AssistantEvent {
  const DoneEvent();
}
