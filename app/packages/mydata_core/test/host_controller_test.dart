import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

/// A host on a real local socket that answers /status like the real one (or not at all).
class FakeHost {
  HttpServer? server;
  bool answering = true;

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) {
      if (!answering || req.headers.value('authorization') != 'Bearer tok') {
        req.response.statusCode = answering ? 401 : 503;
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'version': '0.1.0', 'ready': true, 'assistant_enabled': true, 'uptime_seconds': 1.0,
          'memory': {'host_bytes': 1000}, 'agents_connected': 0, 'today': '2026-03-18', 'demo_date': true,
          'model': {'name': 'qwen3:14b', 'state': 'ready', 'loaded': true, 'ollama_reachable': true,
                    'ollama_started_by_host': false},
        }));
      }
      req.response.close();
    });
    return 'http://127.0.0.1:${server!.port}';
  }
}

class FakePlatform implements HostPlatform {
  FakePlatform(this.baseUrl, {this.command = const ['mydata', 'start'], this.token = 'tok', this.onStart});
  final String baseUrl;
  final List<String>? command;
  String? token;
  int starts = 0;
  final void Function()? onStart;

  @override
  bool get supported => true;
  @override
  String get unsupportedReason => '';
  @override
  Future<HostEnvironment> environment() async =>
      HostEnvironment(home: '/tmp/home', baseUrl: baseUrl, hostCommand: command);
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => token;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async {
    starts++;
    onStart?.call();
    return const LaunchResult(false, 'mydatad exited with code 1');
  }
  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

void main() {
  test('a running host is used without starting another', () async {
    final host = FakeHost();
    final p = FakePlatform(await host.start());
    final c = HostController(app: 'mydata', platform: p);
    await c.connect();
    expect(c.phase, HostPhase.running);
    expect(c.status!.version, '0.1.0');
    expect(p.starts, 0);
    c.dispose();
  });

  test('a stopped host is started, then waited for', () async {
    final host = FakeHost()..answering = false;
    late FakePlatform p;
    p = FakePlatform(await host.start(), onStart: () => host.answering = true);
    final c = HostController(app: 'myassistant', platform: p);
    await c.connect();
    expect(p.starts, 1);
    expect(c.phase, HostPhase.running);
    c.dispose();
  });

  test('no start command is a clear, fixable state', () async {
    final host = FakeHost()..answering = false;
    final c = HostController(app: 'mydata', platform: FakePlatform(await host.start(), command: null));
    await c.connect();
    expect(c.phase, HostPhase.notConfigured);
    expect(c.detail, contains('mydata dev-setup'));
    c.dispose();
  });

  test('a host that never answers is a failure with the launcher output', () async {
    final host = FakeHost()..answering = false;
    final c = HostController(app: 'mydata', platform: FakePlatform(await host.start()),
        startTimeout: const Duration(seconds: 1));
    await c.connect();
    expect(c.phase, HostPhase.failedToStart);
    expect(c.detail, contains('exited with code 1'));
    c.dispose();
  });

  test('a host that stops while open is reported as lost, and retry recovers', () async {
    final host = FakeHost();
    final c = HostController(app: 'mydata', platform: FakePlatform(await host.start()),
        pollInterval: const Duration(milliseconds: 50));
    await c.connect();
    host.answering = false;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(c.phase, HostPhase.lost);
    host.answering = true;
    await c.retry();
    expect(c.phase, HostPhase.running);
    c.dispose();
  });

  test('an unsupported platform never tries anything', () async {
    final c = HostController(app: 'mydata', platform: _Unsupported());
    await c.connect();
    expect(c.phase, HostPhase.unsupported);
    expect(c.error, contains('desktop'));
  });
}

class _Unsupported extends FakePlatform {
  _Unsupported() : super('http://127.0.0.1:1');
  @override
  bool get supported => false;
  @override
  String get unsupportedReason => 'needs the desktop app';
}
