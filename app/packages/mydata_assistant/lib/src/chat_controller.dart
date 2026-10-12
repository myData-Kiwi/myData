import 'package:flutter/foundation.dart';
import 'package:mydata_client/api.dart';

import 'backend.dart';
import 'events.dart';
import 'host_errors.dart';

/// One entry in the conversation, in the order it is shown.
sealed class ChatItem {}

/// What the user sent.
final class UserMessage extends ChatItem {
  UserMessage(this.text);
  final String text;
}

/// The assistant's reply. While [streaming], [text] is provisional delta text; once the host sends the
/// final message it is replaced by that message's text.
final class AssistantReply extends ChatItem {
  String _text = '';
  bool _streaming = true;
  String? _outcome;

  String get text => _text;
  bool get streaming => _streaming;

  /// The run's outcome as the host named it ("answered", "pending_approval", "clarify", ...).
  String? get outcome => _outcome;
}

/// A tool the assistant ran ("Checking calendar"). [done] once the run has moved on.
final class ProgressLine extends ChatItem {
  ProgressLine({required this.tool, required this.label});
  final String tool;
  final String label;
  bool _done = false;
  bool get done => _done;
}

/// A call held for the user's approval, and later what was decided.
final class ApprovalItem extends ChatItem {
  ApprovalItem(this._approval);
  ApprovalOut _approval;
  bool _deciding = false;
  String? _error;

  ApprovalOut get approval => _approval;

  /// A decision has been sent and the host has not answered yet.
  bool get deciding => _deciding;

  /// Why the last decision could not be sent; the call is still pending.
  String? get error => _error;
}

/// A message that failed. [retryText] is the user's message, to send again.
final class ChatError extends ChatItem {
  ChatError(this.message, {required this.retryText, this.statusCode});
  final String message;
  final String retryText;
  final int? statusCode;
}

/// The conversation with the host's assistant: sends messages, folds the streamed events into
/// [items], and decides held calls.
class ChatController extends ChangeNotifier {
  ChatController(this._backend);

  final AssistantBackend _backend;
  final List<ChatItem> _items = [];
  String? _conversationId;
  bool _busy = false;
  bool _disposed = false;

  /// This run's reply and the calls it held; the held calls are shown after the reply when it ends.
  AssistantReply? _reply;
  final List<ApprovalItem> _held = [];

  List<ChatItem> get items => List.unmodifiable(_items);
  String? get conversationId => _conversationId;

  /// A message is being answered; another cannot be sent until it is.
  bool get busy => _busy;

  /// Send a message. Ignored while [busy] or when [text] is blank.
  Future<void> send(String text) async {
    final message = text.trim();
    if (_busy || message.isEmpty) return;
    _items.add(UserMessage(message));
    await _run(message);
  }

  /// Send the failed message again.
  Future<void> retry(ChatError error) async {
    if (_busy || !_items.remove(error)) return;
    await _run(error.retryText);
  }

  /// Approve or reject a held call; the item then shows the call as the host recorded it.
  Future<void> decide(String approvalId, bool approve) async {
    final item = _items.whereType<ApprovalItem>().where((i) => i.approval.id == approvalId).firstOrNull;
    if (item == null || item.deciding || item.approval.status != ApprovalOutStatusEnum.pending) return;
    item
      .._deciding = true
      .._error = null;
    _notify();
    try {
      item._approval = await _backend.decide(approvalId, approve: approve);
    } on Object catch (e) {
      item._error = describeHostError(e);
    } finally {
      item._deciding = false;
      _notify();
    }
  }

  Future<void> _run(String text) async {
    _busy = true;
    _reply = null;
    _held.clear();
    _notify();
    var ended = false;
    try {
      await for (final event in _backend.send(MessageIn(text: text, conversationId: _conversationId))) {
        if (_disposed) return;
        ended = _apply(event, text) || ended;
        _notify();
      }
    } on Object catch (e) {
      _fail(describeHostError(e), text);
      ended = true;
    }
    if (!ended) _fail('The reply stopped before it finished.', text);
    _settleProgress();
    _items.addAll(_held);
    _held.clear();
    _reply = null;
    _busy = false;
    _notify();
  }

  /// Folds one event into the conversation. Returns true when the event ends the reply.
  bool _apply(AssistantEvent event, String text) {
    if (event is! ConversationEvent && event is! StepEvent) _settleProgress();
    switch (event) {
      case ConversationEvent(:final conversationId):
        _conversationId = conversationId;
      case ProgressEvent(:final tool, :final label):
        _items.add(ProgressLine(tool: tool, label: label));
      case DeltaEvent(text: final delta):
        _currentReply()._text += delta;
      case StepEvent():
        final reply = _reply;
        if (reply != null && reply.streaming) _items.remove(reply);
        _reply = null;
      case PendingApprovalEvent(:final approval):
        _held.add(ApprovalItem(approval));
      case ClarifyEvent(text: final question):
        _finish(question, 'clarify');
      case MessageEvent(text: final reply, :final outcome):
        _finish(reply, outcome);
        return true;
      case ErrorEvent(:final message, :final statusCode):
        _fail(message, text, statusCode: statusCode);
        return true;
      case DoneEvent():
    }
    return false;
  }

  AssistantReply _currentReply() {
    final existing = _reply;
    if (existing != null) return existing;
    final reply = _reply = AssistantReply();
    _items.add(reply);
    return reply;
  }

  void _finish(String text, String? outcome) {
    _currentReply()
      .._text = text
      .._streaming = false
      .._outcome = outcome;
  }

  void _fail(String message, String text, {int? statusCode}) {
    final reply = _reply;
    if (reply != null && reply.streaming) _items.remove(reply);
    _reply = null;
    _items.add(ChatError(message, retryText: text, statusCode: statusCode));
  }

  void _settleProgress() {
    for (final line in _items.whereType<ProgressLine>()) {
      line._done = true;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
