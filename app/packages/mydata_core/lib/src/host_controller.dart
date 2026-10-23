import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mydata_client/api.dart';

import 'host_version.g.dart';
import 'platform.dart';

/// Where the app is with the host. Every phase has something to show; there is no blank state.
enum HostPhase {
  /// Looking for a running host.
  checking,

  /// Not running: starting it and waiting for /status.
  starting,

  /// A host this app cannot use as it is was running (from another build, its code changed since it started, or
  /// it refused this app's token): replacing it with the current one ([HostController.restartingTitle]).
  restarting,

  /// Answering /status; [HostController.status] is fresh.
  running,

  /// No command to start the host with (development: `uv run mydata dev-setup` was not run).
  notConfigured,

  /// The start command failed: the host process exited, or the command could not be run. The only phase that
  /// says the host "did not start". Not a host that is still starting ([HostExit.stillStarting]), and not a
  /// failed stop when replacing a host.
  failedToStart,

  /// No answer: the start command succeeded but /status never answered in time, the host is not running and
  /// this app may not start it, or the request failed.
  unreachable,

  /// The host answered but refused this app's token (401), or this app has no token while a host answers, and
  /// replacing it did not help or was not possible.
  refused,

  /// The host is from another build than this app and could not be replaced (the start command would start
  /// another build too, the host could not be stopped, or there is no command), another build replaced it
  /// while the app was open, or its status cannot be read.
  incompatible,

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
  late final appearance = AppearanceApi(client);

  /// Sources (This Mac, iCloud accounts). POST /sources/mac/request-access waits while the person answers
  /// the system prompt, up to 180 s: package:http sets no timeout of its own, so do not add a shorter one.
  late final sources = SourcesApi(client);
}

/// GET /status as the host sent it: [json] is decoded by hand, so a host from another build still says
/// which version it is. [refused] when it answered 401 to this app's token, or, with [noToken], to a request
/// without one because this app has no token yet.
class _Answer {
  const _Answer(HostConnection this.connection, this.json) : refused = false, noToken = false;
  const _Answer.refused(this.connection, {this.noToken = false}) : json = const {}, refused = true;
  final HostConnection? connection;
  final Map<String, Object?> json;
  final bool refused;
  final bool noToken;
}

/// Why a host that answered cannot be used as it is.
enum _Mismatch {
  /// It refused this app's token, or this app has none: often a host from before this app existed.
  refused,

  /// Its version or API version is not this app's.
  otherBuild,

  /// It is this app's build, but its code on disk changed since it started (`stale` in /status).
  codeChanged,
}

/// Finds the host, starts it if needed (as a separate process that outlives this app), waits for it,
/// and keeps watching it. Every app uses one; only the myData app ever calls [stopHost] (its Stop host).
///
/// A host this app cannot use as it is (its version or API version differs from [expectedHostVersion] and
/// [expectedHostApiVersion], its code changed on disk since it started, or it refuses this app's token) is
/// replaced on connect: `mydata stop --unless-current --expect <this app's versions>`, then a start. Any app
/// may do this; it is not the myData app's Stop host, since a host is started again at once. The stop does
/// nothing when it cannot help: when the host the start command starts is another build than this app's as
/// well (a stale app, or a checkout that moved on), and when the running host is already current (another app
/// just replaced it). So an app never stops a host it could not use after, and Retry does not stop it again.
/// It happens at most once per [connect], never from the poll.
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

  /// What the apps show in [HostPhase.restarting].
  static const restartingTitle = 'Restarting the myData host';
  static const restartingMessage = 'The host that was running is from another build of myData.';

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

  /// Connect to the host, starting it if it is not running, and replacing it if it is from another build.
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
      final found = await _ask(env);
      if (found != null) return await _use(env, found, restarted: false);
      if (!startIfNeeded) {
        _go(HostPhase.unreachable, error: 'The myData host is not running.');
        return;
      }
      if (env.hostCommand == null) {
        _go(
          HostPhase.notConfigured,
          error: 'There is no command to start the myData host with.',
          detail:
              'Install the host (host/packaging/macos/install.sh), or for development run `uv run mydata dev-setup` '
              'in host/ once, then retry.\nHost folder: ${env.home}',
        );
        return;
      }
      _go(HostPhase.starting);
      await _startAndWait(env, restarted: false);
    } on Object catch (e) {
      _go(HostPhase.unreachable, error: 'The myData host could not be reached.', detail: '$e');
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() => connect();

  /// Run the start command and wait for /status. "Did not start" only when the command itself failed; a host
  /// that is running but did not answer within the command's own wait is waited for up to [startTimeout].
  Future<void> _startAndWait(HostEnvironment env, {required bool restarted}) async {
    final launch = await platform.startHost(env);
    if (!launch.ok && launch.exitCode != HostExit.stillStarting) {
      // The command failed, but a host may be up anyway (another app's start won the race).
      final found = await _ask(env);
      if (found != null) return _use(env, found, restarted: restarted);
      _go(
        HostPhase.failedToStart,
        error: 'The myData host did not start.',
        detail: launch.output.isEmpty ? null : launch.output,
      );
      return;
    }
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final found = await _ask(env);
      if (found != null) return _use(env, found, restarted: restarted);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final waited = 'No answer within ${startTimeout.inSeconds} seconds.';
    _go(
      HostPhase.unreachable,
      error: 'The myData host started but is not answering.',
      detail: launch.output.isEmpty ? waited : '${launch.output}\n$waited',
    );
  }

  /// Use a host that answered: replace it once if this app cannot use it as it is, else settle on it.
  Future<void> _use(HostEnvironment env, _Answer found, {required bool restarted}) async {
    final why = _mismatchOf(found);
    // Without both commands a stopped host could not be started again: leave it running.
    if (why != null && !restarted && env.hostCommand != null && env.stopCommand != null) {
      return _restart(env, found, why);
    }
    _settle(env, found, why);
  }

  static _Mismatch? _mismatchOf(_Answer found) {
    if (found.refused) return _Mismatch.refused;
    if (found.json['version'] != expectedHostVersion || found.json['api_version'] != expectedHostApiVersion) {
      return _Mismatch.otherBuild;
    }
    return found.json['stale'] == true ? _Mismatch.codeChanged : null;
  }

  /// Replace the host with the current one: stop it, then start. Called at most once per [connect].
  Future<void> _restart(HostEnvironment env, _Answer found, _Mismatch why) async {
    _go(HostPhase.restarting);
    final stop = await platform.stopHost(env);
    // The host the start command starts is another build too: nothing was stopped, and replacing would not help.
    if (stop.exitCode == HostExit.wouldNotMatch) return _settle(env, found, why, note: stop.output);
    // A failed stop matters only if the old host is still there (`mydata stop` kills one that does not stop).
    if (!stop.ok) {
      final still = await _ask(env);
      if (still != null) {
        final output = stop.output.isEmpty ? '' : ':\n${stop.output}';
        return _settle(env, still, _mismatchOf(still), note: 'It could not be stopped$output');
      }
    }
    await _startAndWait(env, restarted: true);
  }

  /// Settle on a host that is not (or no longer) being replaced. One whose code changed on disk is still this
  /// app's build, so it is used. [note] says why it was not replaced.
  void _settle(HostEnvironment env, _Answer found, _Mismatch? why, {String? note}) {
    final version = found.json['version'];
    final apiVersion = found.json['api_version'];
    switch (why) {
      case _Mismatch.refused:
        _go(
          HostPhase.refused,
          error: found.noToken
              ? 'The myData host that is running has no token for this app.'
              : "The myData host did not accept this app's token.",
          detail: [
            'Token file: ${env.home}/app-tokens/$app',
            'The host makes and reads its tokens when it starts, so a host started before this app existed, or a '
                'token changed since then, is refused until it starts again.',
            ?note,
          ].join('\n'),
        );
      case _Mismatch.otherBuild:
        _incompatible(version, apiVersion, note: note);
      case _Mismatch.codeChanged || null:
        final s = _typed(found.json);
        if (s == null) return _incompatible(version, apiVersion, why: 'Its status could not be read.');
        connection = found.connection;
        status = s;
        _running();
    }
  }

  void _incompatible(Object? version, Object? apiVersion, {String? why, String? note}) => _go(
    HostPhase.incompatible,
    error: 'This app and the myData host are from different builds.',
    detail: [
      ?why,
      'The host is version ${version ?? 'unknown'} (API ${apiVersion ?? 'unknown'}); this app expects version '
          '$expectedHostVersion (API $expectedHostApiVersion).',
      ?note,
      'Development: build the app and the host from the same checkout. Rebuild this app, or run '
          '`uv run mydata dev-setup` in host/ of the checkout it was built from, so the apps start that host.',
    ].join('\n'),
  );

  /// GET /status with this app's token, decoded by hand; null when nothing answered (not running, no token
  /// yet, an error). A token is re-read every time, so a token the host replaced (it does so if the file was
  /// exposed) is picked up.
  Future<_Answer?> _ask(HostEnvironment env) async {
    final token = await platform.readAppToken(env, app);
    if (token == null) return _askWithoutToken(env);
    final conn = connection?.token == token ? connection! : HostConnection(env.baseUrl, token);
    try {
      final r = await conn.host.statusWithHttpInfo().timeout(const Duration(seconds: 3));
      if (r.statusCode == 401) return _Answer.refused(conn);
      if (r.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(r.bodyBytes));
      return json is Map ? _Answer(conn, json.cast<String, Object?>()) : null;
    } on Object {
      return null;
    }
  }

  /// No token yet: a host that answers 401 is running but never made one for this app (one started before this
  /// app existed). Null when nothing answers, so the host is started and makes the token.
  Future<_Answer?> _askWithoutToken(HostEnvironment env) async {
    try {
      final r = await HostApi(ApiClient(basePath: env.baseUrl))
          .statusWithHttpInfo()
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 401 ? const _Answer.refused(null, noToken: true) : null;
    } on Object {
      return null;
    }
  }

  /// The status as the generated client reads it, or null if it does not match this build's [StatusOut].
  static StatusOut? _typed(Map<String, Object?> json) {
    try {
      return StatusOut.fromJson(json);
    } on Object {
      return null; // a missing field: an assertion in debug builds, a null check in release
    }
  }

  void _running() {
    if (_disposed) return; // disposed while connecting: start nothing
    _missed = 0;
    _go(HostPhase.running);
    _poll = Timer.periodic(pollInterval, (_) => refresh());
  }

  /// Refresh /status now; returns whether the host answered. Two misses in a row while running means
  /// the host stopped. Listeners hear about every attempt, so a "Check again" button always responds.
  Future<bool> refresh() async {
    final env = environment;
    if (env == null || phase != HostPhase.running) return false;
    final found = await _ask(env);
    if (found != null && !found.refused && _mismatchOf(found) == _Mismatch.otherBuild) {
      // Another app replaced the host with another build's. Never replaced from the poll; Retry connects again.
      _poll?.cancel();
      _incompatible(
        found.json['version'],
        found.json['api_version'],
        why: 'The host was replaced by one from another build while this app was open.',
      );
      return false;
    }
    final s = found == null || found.refused ? null : _typed(found.json);
    if (s != null) {
      connection = found!.connection;
      status = s;
      _missed = 0;
      if (!_disposed) notifyListeners();
      return true;
    }
    if (++_missed >= 2) {
      _poll?.cancel();
      _go(
        HostPhase.lost,
        error: 'The myData host stopped while the app was open.',
        detail: 'Its log is in ${env.home}/logs/mydatad.log',
      );
    } else if (!_disposed) {
      notifyListeners();
    }
    return false;
  }

  /// Use a status the host just returned (e.g. from PUT /assistant/settings) without asking again.
  void updateStatus(StatusOut fresh) {
    if (phase != HostPhase.running) return;
    status = fresh;
    if (!_disposed) notifyListeners();
  }

  /// What the apps show once the myData app's Stop host has stopped the host.
  static const stoppedMessage = 'The myData host is stopped.';

  /// Stop the host: the myData app's Stop host (POST /shutdown, which the host refuses from other apps). Quitting an
  /// app never stops it. The host exits cleanly, so launchd (an installed host) leaves it stopped until [connect]
  /// starts it again (Start host, Retry, or any app connecting) or the next login.
  /// Replacing a host from another build on connect is different: [HostPlatform.stopHost], then a start.
  Future<bool> stopHost() async {
    final conn = connection;
    if (conn == null || _busy) return false;
    try {
      // The raw response: the generated client cannot decode the body ({"stopping": true}) into its map type.
      final r = await conn.host.shutdownHostWithHttpInfo();
      if (r.statusCode >= 400) return false;
      _poll?.cancel();
      connection = null;
      status = null;
      _go(
        HostPhase.unreachable,
        error: stoppedMessage,
        detail: 'Start it again from the menu-bar icon, or with Retry.',
      );
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
