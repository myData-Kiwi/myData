import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mydata_client/api.dart';

import 'platform.dart';

/// Where the app is with the host. Every phase has something to show; there is no blank state.
enum HostPhase {
  /// Looking for a running host.
  checking,

  /// Not running: starting it and waiting for /status.
  starting,

  /// Answering /status; [HostController.status] is fresh.
  running,

  /// No command to start the host with (development: `uv run mydata dev-setup` was not run).
  notConfigured,

  /// The start command failed or the host did not answer in time.
  failedToStart,

  /// It was running and stopped answering while the app was open.
  lost,

  /// This platform cannot run or reach a local host (the web build).
  unsupported,
}

/// The authenticated API of a running host, for this app.
class HostConnection {
  HostConnection(this.baseUrl, this.token)
      : client = ApiClient(basePath: baseUrl, authentication: HttpBearerAuth()..accessToken = token);
  final String baseUrl;
  final String token;
  final ApiClient client;
  late final host = HostApi(client);
  late final assistant = AssistantApi(client);
  late final approvals = ApprovalsApi(client);
  late final agents = AgentsApi(client);
  late final tools = ToolsApi(client);
}

/// Finds the host, starts it if needed (as a separate process that outlives this app), waits for it,
/// and keeps watching it. Both apps use one; only the myData app ever calls [stopHost].
class HostController extends ChangeNotifier {
  HostController({
    required this.app,
    HostPlatform? platform,
    this.pollInterval = const Duration(seconds: 2),
    this.startTimeout = const Duration(seconds: 60),
  }) : platform = platform ?? hostPlatform;

  /// Which app this is: its token is `<home>/app-tokens/<app>` ("mydata" or "myassistant").
  final String app;
  final HostPlatform platform;
  final Duration pollInterval;
  final Duration startTimeout;

  HostPhase phase = HostPhase.checking;

  /// What went wrong, for people; [detail] holds the technical text.
  String? error;
  String? detail;
  StatusOut? status;
  HostConnection? connection;
  HostEnvironment? environment;

  Timer? _poll;
  int _missed = 0;
  bool _busy = false;
  bool _disposed = false;

  void _go(HostPhase p, {String? error, String? detail}) {
    phase = p;
    this.error = error;
    this.detail = detail;
    if (!_disposed) notifyListeners();
  }

  /// Connect to the host, starting it if it is not running.
  Future<void> connect({bool startIfNeeded = true}) async {
    if (_busy) return;
    _busy = true;
    _poll?.cancel();
    try {
      if (!platform.supported) {
        _go(HostPhase.unsupported, error: platform.unsupportedReason);
        return;
      }
      _go(HostPhase.checking);
      final env = environment = await platform.environment();
      if (await _tryStatus(env)) return _running();
      if (!startIfNeeded) {
        _go(HostPhase.failedToStart, error: 'The myData host is not running.');
        return;
      }
      if (env.hostCommand == null) {
        _go(HostPhase.notConfigured,
            error: 'There is no command to start the myData host with.',
            detail: 'Development: run `uv run mydata dev-setup` in host/ once, then retry.\nHost folder: ${env.home}');
        return;
      }
      _go(HostPhase.starting);
      final launch = await platform.startHost(env);
      final deadline = DateTime.now().add(startTimeout);
      while (DateTime.now().isBefore(deadline)) {
        if (await _tryStatus(env)) return _running();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      _go(HostPhase.failedToStart,
          error: 'The myData host did not start.',
          detail: launch.output.isEmpty ? 'No answer within ${startTimeout.inSeconds} seconds.' : launch.output);
    } on Object catch (e) {
      _go(HostPhase.failedToStart, error: 'The myData host could not be reached.', detail: '$e');
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() => connect();

  /// Ask the host for its status with this app's token. A token is re-read every time, so a token the
  /// host replaced (it does so if the file was exposed) is picked up.
  Future<bool> _tryStatus(HostEnvironment env) async {
    final token = await platform.readAppToken(env, app);
    if (token == null) return false;
    final conn = connection?.token == token ? connection! : HostConnection(env.baseUrl, token);
    try {
      final s = await conn.host.status().timeout(const Duration(seconds: 3));
      if (s == null) return false;
      connection = conn;
      status = s;
      return true;
    } on Object {
      return false;
    }
  }

  void _running() {
    _missed = 0;
    _go(HostPhase.running);
    _poll = Timer.periodic(pollInterval, (_) => refresh());
  }

  /// Refresh /status now. Two misses in a row while running means the host stopped.
  Future<void> refresh() async {
    final env = environment;
    if (env == null || phase != HostPhase.running) return;
    if (await _tryStatus(env)) {
      _missed = 0;
      if (!_disposed) notifyListeners();
      return;
    }
    if (++_missed >= 2) {
      _poll?.cancel();
      _go(HostPhase.lost,
          error: 'The myData host stopped while the app was open.',
          detail: 'Its log is in ${env.home}/logs/mydatad.log');
    }
  }

  /// Stop the host. Only the myData app owns the host's lifetime; the host refuses this from others.
  Future<bool> stopHost() async {
    final conn = connection;
    if (conn == null) return false;
    try {
      await conn.host.shutdownHost();
      _poll?.cancel();
      return true;
    } on Object {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
