import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

/// A host on a real local socket that answers /status like the real one (or not at all). [version] and
/// [apiVersion] are this build's unless a test makes it a host from another build; [old] leaves out the
/// fields an older host did not have, so the generated client cannot read its status.
class FakeHost {
  HttpServer? server;
  bool answering = true;
  String version = expectedHostVersion;
  String apiVersion = expectedHostApiVersion;
  bool old = false;

  /// Its code on disk changed since it started.
  bool stale = false;

  /// How many times it was really stopped.
  int stopped = 0;

  /// Leaves out fields this build needs while reporting this build's versions.
  bool partial = false;

  /// Answers every request with this code instead (e.g. 401 for a token the host does not know).
  int? code;

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server?.close(force: true));
    server!.listen((req) {
      if (code != null) {
        req.response.statusCode = code!;
      } else if (answering && req.method == 'POST' && req.uri.path == '/shutdown') {
        // The myData app's Stop host: the host answers, then exits.
        req.response
          ..statusCode = 202
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'stopping': true}));
        stop();
      } else if (!answering || req.headers.value('authorization') != 'Bearer tok') {
        req.response.statusCode = answering ? 401 : 503;
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write(
          jsonEncode({
            'version': version,
            if (!old) 'api_version': apiVersion,
            if (!old) 'stale': stale,
            'ready': true,
            'assistant_enabled': true,
            'uptime_seconds': 1.0,
            'memory': {'host_bytes': 1000},
            'agents_connected': 0,
            'today': '2026-03-18',
            'demo_date': true,
            'theme': 'kiwi',
            if (!old && !partial) 'mode': 'demo',
            if (!old && !partial) 'conversation_epoch': 0,
            'model': {
              'name': 'qwen3:14b',
              'state': 'ready',
              'loaded': true,
              'ollama_reachable': true,
              'ollama_started_by_host': false,
            },
          }),
        );
      }
      req.response.close();
    });
    return 'http://127.0.0.1:${server!.port}';
  }

  /// What `mydata stop` does to it.
  void stop() {
    answering = false;
    code = null;
    stopped++;
  }

  /// What `mydata start` of this build does to it: this build's host answers.
  void startCurrent() {
    answering = true;
    version = expectedHostVersion;
    apiVersion = expectedHostApiVersion;
    old = false;
    stale = false;
  }
}

class FakePlatform implements HostPlatform {
  FakePlatform(
    this.baseUrl, {
    this.command = const ['mydata', 'start'],
    this.stopCommand = const ['mydata', 'stop'],
    this.token = 'tok',
    this.onStart,
    this.onStop,
    this.startResult = const LaunchResult(true, 'running; model ready'),
    this.stopResult = const LaunchResult(true, 'mydatad stopped'),
    bool? stopStops,
  }) : stopStops = stopStops ?? stopResult.ok;
  final String baseUrl;
  final List<String>? command;
  final List<String>? stopCommand;
  String? token;
  final void Function()? onStart;
  final void Function()? onStop;
  final LaunchResult startResult;
  final LaunchResult stopResult;

  /// Whether the stop command stops the host ([onStop] runs); by default when it exits 0.
  final bool stopStops;

  /// "start" and "stop", in the order the controller ran them.
  final calls = <String>[];
  int get starts => calls.where((c) => c == 'start').length;
  int get stops => calls.where((c) => c == 'stop').length;

  @override
  bool get supported => true;
  @override
  String get unsupportedReason => '';
  @override
  Future<HostEnvironment> environment() async =>
      HostEnvironment(home: '/tmp/home', baseUrl: baseUrl, hostCommand: command, stopCommand: stopCommand);
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => token;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async {
    calls.add('start');
    onStart?.call();
    return startResult;
  }

  @override
  Future<LaunchResult> stopHost(HostEnvironment env) async {
    calls.add('stop');
    if (stopStops) onStop?.call();
    return stopResult;
  }

  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

/// Every phase [c] goes through, in order.
List<HostPhase> phasesOf(HostController c) {
  final seen = <HostPhase>[];
  c.addListener(() {
    if (seen.isEmpty || seen.last != c.phase) seen.add(c.phase);
  });
  return seen;
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

  test("Stop host stops the host and says so; connecting starts it again", () async {
    final host = FakeHost();
    final p = FakePlatform(await host.start(), onStart: host.startCurrent);
    final c = HostController(app: 'mydata', platform: p);
    await c.connect();
    expect(c.phase, HostPhase.running);
    expect(await c.stopHost(), isTrue);
    expect(host.stopped, 1);
    expect(c.phase, HostPhase.unreachable);
    expect(c.error, HostController.stoppedMessage);
    expect(c.connection, isNull);
    expect(await c.stopHost(), isFalse); // nothing to stop
    await c.connect(); // Start host
    expect(p.calls, ['start']);
    expect(c.phase, HostPhase.running);
    c.dispose();
  });

  test('a stopped host is started, then waited for', () async {
    final host = FakeHost()..answering = false;
    final p = FakePlatform(await host.start(), onStart: () => host.answering = true);
    final c = HostController(app: 'myassistant', platform: p);
    await c.connect();
    expect(p.calls, ['start']);
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

  test('a start command that fails is "did not start", with its output', () async {
    final host = FakeHost()..answering = false;
    final c = HostController(
      app: 'mydata',
      platform: FakePlatform(await host.start(), startResult: const LaunchResult(false, 'mydatad exited with code 1')),
      startTimeout: const Duration(seconds: 1),
    );
    await c.connect();
    expect(c.phase, HostPhase.failedToStart);
    expect(c.error, 'The myData host did not start.');
    expect(c.detail, contains('exited with code 1'));
    c.dispose();
  });

  test('a start command that succeeds with no answer after is not "did not start"', () async {
    final host = FakeHost()..answering = false;
    final c = HostController(
      app: 'mydata',
      platform: FakePlatform(await host.start()),
      startTimeout: const Duration(seconds: 1),
    );
    await c.connect();
    expect(c.phase, HostPhase.unreachable);
    expect(c.error, 'The myData host started but is not answering.');
    expect(c.error, isNot(contains('did not start')));
    expect(c.detail, contains('running; model ready'));
    c.dispose();
  });

  group('a host that refuses the token', () {
    test('is replaced once, like one from another build (a host from before this app existed)', () async {
      final host = FakeHost()..code = 401;
      final p = FakePlatform(await host.start(), onStop: host.stop, onStart: host.startCurrent);
      final c = HostController(app: 'mycontacts', platform: p);
      final phases = phasesOf(c);
      await c.connect();
      expect(p.calls, ['stop', 'start']);
      expect(phases, [HostPhase.checking, HostPhase.restarting, HostPhase.running]);
      c.dispose();
    });

    test('that is already current is left running and reported, never "did not start"', () async {
      final host = FakeHost()..code = 401;
      // `mydata stop --unless-current`: the host already runs the current code, so nothing is stopped.
      final p = FakePlatform(
        await host.start(),
        stopResult: const LaunchResult(true, 'mydatad was not stopped: it is already this build', exitCode: 0),
      );
      final c = HostController(app: 'mycontacts', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.refused);
      expect(p.calls, ['stop', 'start']);
      expect(host.stopped, 0);
      expect(c.error, isNot(contains('did not start')));
      expect(c.detail, contains('/tmp/home/app-tokens/mycontacts'));
      c.dispose();
    });

    test('when the start command would start another build, is left running', () async {
      final host = FakeHost()..code = 401;
      final p = FakePlatform(
        await host.start(),
        onStop: host.stop,
        stopResult: const LaunchResult(false, 'mydatad was not stopped: ...', exitCode: HostExit.wouldNotMatch),
      );
      final c = HostController(app: 'mycontacts', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.refused);
      expect(p.calls, ['stop']);
      expect(host.stopped, 0);
      expect(c.detail, contains('mydatad was not stopped'));
      c.dispose();
    });
  });

  test('no token while a host answers: that host is replaced, and the new one makes the token', () async {
    // A host from before this app existed: it never made app-tokens/mycalendar, and answers 401 without one.
    final host = FakeHost();
    late final FakePlatform p;
    p = FakePlatform(
      await host.start(),
      token: null,
      onStop: host.stop,
      onStart: () {
        host.startCurrent();
        p.token = 'tok';
      },
    );
    final c = HostController(app: 'mycalendar', platform: p);
    await c.connect();
    expect(p.calls, ['stop', 'start']);
    expect(c.phase, HostPhase.running);
    c.dispose();
  });

  test('no token and nothing answering: the host is started, with no stop', () async {
    final host = FakeHost()..answering = false;
    late final FakePlatform p;
    p = FakePlatform(
      await host.start(),
      token: null,
      onStart: () {
        host.startCurrent();
        p.token = 'tok';
      },
    );
    final c = HostController(app: 'mycalendar', platform: p);
    await c.connect();
    expect(p.calls, ['start']);
    expect(c.phase, HostPhase.running);
    c.dispose();
  });

  test('a host that is still starting when the start command gives up is waited for', () async {
    final host = FakeHost()..answering = false;
    final p = FakePlatform(
      await host.start(),
      startResult: const LaunchResult(
        false,
        'mydatad started but did not answer within 20 seconds',
        exitCode: HostExit.stillStarting,
      ),
      onStart: () => Timer(const Duration(milliseconds: 300), () => host.answering = true),
    );
    final c = HostController(app: 'mydata', platform: p, startTimeout: const Duration(seconds: 5));
    final phases = phasesOf(c);
    await c.connect();
    expect(c.phase, HostPhase.running);
    expect(phases, isNot(contains(HostPhase.failedToStart)));
    c.dispose();
  });

  group('a host from another build', () {
    test('is stopped, then this build\'s is started', () async {
      final host = FakeHost()
        ..version = '0.0.9'
        ..apiVersion = '000000000000';
      final p = FakePlatform(await host.start(), onStop: host.stop, onStart: host.startCurrent);
      final c = HostController(app: 'myassistant', platform: p);
      final phases = phasesOf(c);
      await c.connect();
      expect(p.calls, ['stop', 'start']);
      expect(phases, [HostPhase.checking, HostPhase.restarting, HostPhase.running]);
      expect(HostController.restartingTitle, 'Restarting the myData host');
      expect(c.status!.apiVersion, expectedHostApiVersion);
      c.dispose();
    });

    test('whose status this build cannot read is replaced the same way', () async {
      final host = FakeHost()..old = true;
      final p = FakePlatform(await host.start(), onStop: host.stop, onStart: host.startCurrent);
      final c = HostController(app: 'mycalendar', platform: p);
      final phases = phasesOf(c);
      await c.connect();
      expect(p.calls, ['stop', 'start']);
      expect(phases, contains(HostPhase.restarting));
      expect(c.phase, HostPhase.running);
      c.dispose();
    });

    test('is left running when the start command would start another build too, also on Retry', () async {
      // A stale app: the checkout the start command runs has moved on. Stopping would not help.
      final host = FakeHost()..apiVersion = 'abcdefabcdef';
      final p = FakePlatform(
        await host.start(),
        onStop: host.stop,
        onStart: host.startCurrent,
        stopResult: const LaunchResult(
          false,
          'mydatad was not stopped: a host started from here is version 0.1.0 (API abcdefabcdef)',
          exitCode: HostExit.wouldNotMatch,
        ),
      );
      final c = HostController(app: 'mycalendar', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.incompatible);
      expect(c.detail, contains('a host started from here is version 0.1.0 (API abcdefabcdef)'));
      await c.retry();
      expect(c.phase, HostPhase.incompatible);
      expect(host.stopped, 0);
      expect(p.starts, 0);
      expect(host.answering, isTrue);
      c.dispose();
    });

    test('still there after one restart is incompatible, with no second restart', () async {
      final host = FakeHost()..apiVersion = 'abcdefabcdef';
      // `mydata start` of another checkout: the host that answers is still not this build's.
      final p = FakePlatform(await host.start(), onStop: host.stop, onStart: () => host.answering = true);
      final c = HostController(app: 'mydata', platform: p, startTimeout: const Duration(seconds: 1));
      await c.connect();
      expect(c.phase, HostPhase.incompatible);
      expect(p.calls, ['stop', 'start']);
      expect(c.error, 'This app and the myData host are from different builds.');
      expect(c.detail, contains('abcdefabcdef'));
      expect(c.detail, contains(expectedHostApiVersion));
      expect(c.detail, contains('mydata dev-setup'));
      c.dispose();
    });

    test('that cannot be stopped is incompatible, never "did not start", and nothing is started', () async {
      final host = FakeHost()..version = '0.0.9';
      final p = FakePlatform(await host.start(), stopResult: const LaunchResult(false, 'permission denied'));
      final c = HostController(app: 'mydata', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.incompatible);
      expect(c.error, isNot(contains('did not start')));
      expect(c.detail, contains('could not be stopped:\npermission denied'));
      expect(c.detail, isNot(contains('did not start')));
      expect(p.calls, ['stop']);
      c.dispose();
    });

    test('whose stop failed but which is gone is followed by a start', () async {
      final host = FakeHost()..version = '0.0.9';
      // `mydata stop` exits 1 when it had to kill the host after 15 s; the host is gone all the same.
      final p = FakePlatform(
        await host.start(),
        stopResult: const LaunchResult(false, 'mydatad did not stop in 15 seconds and was killed', exitCode: 1),
        stopStops: true,
        onStop: host.stop,
        onStart: host.startCurrent,
      );
      final c = HostController(app: 'mydata', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.running);
      expect(p.calls, ['stop', 'start']);
      c.dispose();
    });

    test('with no start command is left running and reported', () async {
      final host = FakeHost()..version = '0.0.9';
      final p = FakePlatform(await host.start(), command: null);
      final c = HostController(app: 'mydata', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.incompatible);
      expect(p.calls, isEmpty);
      c.dispose();
    });

    test('with no stop command is left running and reported, never "did not start"', () async {
      // app_config.json with a host_command that does not end in "start" and no stop_command.
      final host = FakeHost()..version = '0.0.9';
      final p = FakePlatform(await host.start(), stopCommand: null);
      final c = HostController(app: 'mydata', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.incompatible);
      expect(c.error, isNot(contains('did not start')));
      expect(p.calls, isEmpty);
      c.dispose();
    });

    test('that another app swaps in while this one is open is incompatible, and nothing is stopped', () async {
      final host = FakeHost();
      final p = FakePlatform(await host.start(), onStop: host.stop);
      final c = HostController(app: 'myassistant', platform: p, pollInterval: const Duration(milliseconds: 50));
      await c.connect();
      expect(c.phase, HostPhase.running);
      host.apiVersion = 'fedcbafedcba';
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.phase, HostPhase.incompatible);
      expect(c.detail, contains('replaced by one from another build'));
      expect(p.calls, isEmpty);
      c.dispose();
    });
  });

  group('a host of this build whose code changed since it started', () {
    test('is replaced once', () async {
      final host = FakeHost()..stale = true;
      final p = FakePlatform(await host.start(), onStop: host.stop, onStart: host.startCurrent);
      final c = HostController(app: 'myassistant', platform: p);
      await c.connect();
      expect(p.calls, ['stop', 'start']);
      expect(c.phase, HostPhase.running);
      expect(host.stale, isFalse);
      c.dispose();
    });

    test('is used as it is when the start command would start another build', () async {
      final host = FakeHost()..stale = true;
      final p = FakePlatform(
        await host.start(),
        onStop: host.stop,
        stopResult: const LaunchResult(false, 'not stopped', exitCode: HostExit.wouldNotMatch),
      );
      final c = HostController(app: 'myassistant', platform: p);
      await c.connect();
      expect(c.phase, HostPhase.running);
      expect(p.calls, ['stop']);
      expect(host.stopped, 0);
      c.dispose();
    });
  });

  test('the stop command is told this app\'s versions and to leave a current host', () {
    expect(replaceHostArguments(), ['--unless-current', '--expect', expectedHostVersion, expectedHostApiVersion]);
  });

  test('a host of this build whose status cannot be read is incompatible, not restarted', () async {
    // The same versions, but fields this build needs are missing: a mismatch the hash did not catch.
    final host = FakeHost()..partial = true;
    final p = FakePlatform(await host.start());
    final c = HostController(app: 'mydata', platform: p);
    await c.connect();
    expect(c.phase, HostPhase.incompatible);
    expect(c.detail, contains('could not be read'));
    expect(p.calls, isEmpty);
    c.dispose();
  });

  test('a host of this build is used as it is', () async {
    final host = FakeHost();
    final p = FakePlatform(await host.start());
    final c = HostController(app: 'mydata', platform: p);
    await c.connect();
    expect(c.phase, HostPhase.running);
    expect(p.calls, isEmpty);
    c.dispose();
  });

  group('app_config.json', () {
    test('stop_command is taken as written', () {
      final c = hostCommandsFrom({
        'host_command': ['/py', '-m', 'mydata.cli', 'start'],
        'stop_command': ['/py', '-m', 'mydata.cli', 'stop', '--now'],
      });
      expect(c.start, ['/py', '-m', 'mydata.cli', 'start']);
      expect(c.stop, ['/py', '-m', 'mydata.cli', 'stop', '--now']);
    });

    test('without stop_command, the stop command is the start command ending in "stop"', () {
      final c = hostCommandsFrom({
        'host_command': ['/py', '-m', 'mydata.cli', 'start'],
      });
      expect(c.stop, ['/py', '-m', 'mydata.cli', 'stop']);
    });

    test('a start command that does not end in "start" gives no stop command', () {
      expect(
        hostCommandsFrom({
          'host_command': ['/opt/mydata/run'],
        }).stop,
        isNull,
      );
    });

    test('anything else gives no commands', () {
      expect(hostCommandsFrom(null).start, isNull);
      expect(hostCommandsFrom({'host_command': []}).start, isNull);
      expect(
        hostCommandsFrom({
          'host_command': [1, 2],
        }).start,
        isNull,
      );
      expect(hostCommandsFrom(['start']).stop, isNull);
    });
  });

  test('a host that stops while open is reported as lost, and retry recovers', () async {
    final host = FakeHost();
    final c = HostController(
      app: 'mydata',
      platform: FakePlatform(await host.start()),
      pollInterval: const Duration(milliseconds: 50),
    );
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
