import 'package:http/http.dart' as http;
import 'package:mydata_core/mydata_core.dart';

import 'events.dart';
import 'sse.dart';

/// What the chat needs from the host. [HostAssistantBackend] is the real one; tests pass a fake.
abstract interface class AssistantBackend {
  /// One message; the reply as events. Failures arrive as an [ErrorEvent], not as a stream error.
  Stream<AssistantEvent> send(MessageIn message);

  /// Approve or reject a held call. Returns the call as the host recorded the decision.
  Future<ApprovalOut> decide(String approvalId, {required bool approve});
}

/// The host, through this app's current connection. The connection is looked up on every call, because
/// the host controller replaces it when the host restarts or rotates this app's token.
class HostAssistantBackend implements AssistantBackend {
  HostAssistantBackend(this._connection, {http.Client? client}) : _client = client ?? http.Client();

  final HostConnection? Function() _connection;
  final http.Client _client;

  @override
  Stream<AssistantEvent> send(MessageIn message) {
    final conn = _connection();
    if (conn == null) return Stream.value(const ErrorEvent('Not connected to the myData host.'));
    return streamAssistantMessage(_client, baseUrl: conn.baseUrl, token: conn.token, message: message);
  }

  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) async {
    final conn = _connection();
    if (conn == null) throw StateError('Not connected to the myData host.');
    final decision = approve ? DecisionInDecisionEnum.approve : DecisionInDecisionEnum.reject;
    final result = await conn.approvals.decide(approvalId, DecisionIn(decision: decision));
    if (result == null) throw StateError('The myData host did not return the decided call.');
    return result;
  }

  void close() => _client.close();
}
