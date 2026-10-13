import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mydata_core/mydata_core.dart';

/// A host status with the model in [state], built with the generated constructors.
StatusOut statusWith(
  ModelOutStateEnum state, {
  Progress? progress,
  String? error,
  bool enabled = true,
  int? modelBytes,
  ErrorOut? lastError,
}) => StatusOut(
  agentsConnected: 0,
  assistantEnabled: enabled,
  demoDate: true,
  lastError: lastError,
  memory: MemoryOut(hostBytes: 120000000, modelBytes: modelBytes),
  model: ModelOut(
    name: 'qwen3:14b',
    state: state,
    loaded: state == ModelOutStateEnum.ready,
    ollamaReachable: state != ModelOutStateEnum.ollamaMissing,
    ollamaStartedByHost: true,
    progress: progress,
    error: error,
  ),
  mode: StatusOutModeEnum.demo,
  ready: state == ModelOutStateEnum.ready,
  theme: 'kiwi',
  today: '2026-03-18',
  uptimeSeconds: 12,
  version: '0.1.0',
);

/// An agent token as the host lists it.
AgentOut agentWith(String name, {bool connected = false, bool revoked = false, String? lastSeenAt}) => AgentOut(
  id: 'id-${name.toLowerCase().replaceAll(' ', '-')}',
  name: name,
  connected: connected,
  revoked: revoked,
  // No offset: parsed as local time, so screens show 09:30 in every time zone (see screenshots_test.dart).
  createdAt: '2026-10-01T09:30:00',
  lastSeenAt: lastSeenAt,
);

/// A platform whose host is always there; the [FakeHost] answers its requests.
class _FakePlatform implements HostPlatform {
  @override
  bool get supported => true;
  @override
  String get unsupportedReason => '';
  @override
  Future<HostEnvironment> environment() async => FakeHost.environment;
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => FakeHost.token;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(true, '');
  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

/// A running host in memory: the API the apps use, answered from fields a test can set and read, with
/// every request recorded ("PUT /appearance {"theme":"dusk"}").
class FakeHost {
  FakeHost({StatusOut? status, this.theme = 'kiwi', this.chosen = true, List<AgentOut>? agents})
    : status = status ?? statusWith(ModelOutStateEnum.ready),
      agents = agents ?? [];

  static const token = 'test-token';
  static const environment = HostEnvironment(home: '/tmp/mydata-test', baseUrl: 'http://127.0.0.1:47821', hostCommand: null);

  StatusOut status;

  /// The stored theme and whether it was ever chosen (GET /appearance).
  String theme;
  bool chosen;
  List<AgentOut> agents;

  /// GET and PUT /appearance answer with a server error.
  bool failAppearance = false;

  /// The host has stopped: /status does not answer.
  bool down = false;

  final requests = <String>[];

  late final http.Client client = MockClient(_answer);

  /// A controller already connected to this host, as after a successful connect, without its poll timer.
  HostController controller() {
    final c = HostController(app: 'mydata', platform: _FakePlatform());
    c.environment = environment;
    c.connection = HostConnection(environment.baseUrl, token)..client.client = client;
    c.status = status..theme = theme;
    c.phase = HostPhase.running;
    return c;
  }

  http.Response _json(Object? body, [int code = 200]) =>
      http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

  AppearanceOut get _appearance => AppearanceOut(chosen: chosen, theme: theme);

  Future<http.Response> _answer(http.Request r) async {
    final path = r.url.path;
    requests.add('${r.method} $path${r.body.isEmpty ? '' : ' ${r.body}'}');
    final body = r.body.isEmpty ? null : jsonDecode(r.body) as Map<String, Object?>;
    switch ((r.method, path)) {
      case ('GET', '/status'):
        if (down) return _json({'detail': 'gone'}, 503);
        return _json((status..theme = theme).toJson());
      case ('GET', '/appearance'):
        return failAppearance ? _json({'detail': 'appearance is broken'}, 500) : _json(_appearance.toJson());
      case ('PUT', '/appearance'):
        if (failAppearance) return _json({'detail': 'appearance is broken'}, 500);
        theme = body!['theme']! as String;
        chosen = true;
        return _json(_appearance.toJson());
      case ('PUT', '/assistant/settings'):
        status.assistantEnabled = body!['enabled']! as bool;
        return _json(status.toJson());
      case ('POST', '/model/retry'):
        return _json(status.toJson());
      case ('GET', '/agents'):
        return _json([for (final a in agents) a.toJson()]);
      case ('POST', '/agents'):
        final name = body!['name']! as String;
        final a = agentWith(name);
        agents = [...agents, a];
        return _json(
          AgentCreated(
            id: a.id,
            name: a.name,
            connected: false,
            revoked: false,
            createdAt: a.createdAt,
            token: 'mdt_secret_for_$name',
          ).toJson(),
        );
      case ('DELETE', final p) when p.startsWith('/agents/'):
        final id = p.substring('/agents/'.length);
        final a = agents.firstWhere((a) => a.id == id);
        a
          ..revoked = true
          ..connected = false;
        return _json(a.toJson());
    }
    return _json({'detail': 'Not found'}, 404);
  }
}

/// Pumps frames until the fake host's answers have arrived. Not pumpAndSettle: the loading kiwi turns
/// for as long as it shows.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
