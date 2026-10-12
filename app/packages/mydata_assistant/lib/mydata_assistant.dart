/// The myAssistant chat: the host's streamed replies as typed events, the conversation state, and the
/// widgets that show it (chat, approval card, the "assistant unavailable" panel).
library;

export 'src/approval_card.dart';
export 'src/assistant_unavailable.dart';
export 'src/backend.dart';
export 'src/chat_controller.dart';
export 'src/chat_view.dart';
export 'src/events.dart';
export 'src/host_errors.dart' show describeHostError;
export 'src/result_view.dart';
export 'src/sse.dart';
