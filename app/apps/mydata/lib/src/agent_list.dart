import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';

import 'format.dart';

/// The host's agent tokens (GET /agents), shared by the Status and Settings screens.
class AgentList extends ChangeNotifier {
  AgentList(this._controller);

  final HostController _controller;

  /// Null until the first answer.
  List<AgentOut>? agents;

  /// Why the last load failed, for people; null when it worked.
  String? error;

  Future<void>? _loading;
  bool _again = false;
  bool _disposed = false;

  Iterable<AgentOut> get connected => (agents ?? const <AgentOut>[]).where((a) => a.connected && !a.revoked);

  /// Reads the list. A call during a read waits for it and then reads once more, because the read under
  /// way may have started before the change (a token created or revoked) the caller wants to see.
  Future<void> load() {
    if (_loading != null) {
      _again = true;
      return _loading!;
    }
    return _loading = _readUntilCurrent().whenComplete(() => _loading = null);
  }

  Future<void> _readUntilCurrent() async {
    do {
      _again = false;
      await _read();
    } while (_again && !_disposed);
  }

  Future<void> _read() async {
    final connection = _controller.connection;
    if (connection == null) return;
    try {
      agents = await connection.agents.agents() ?? const [];
      error = null;
    } on Object catch (e) {
      error = errorText(e);
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
