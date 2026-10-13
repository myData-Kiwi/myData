// Live check: the real HostController and IO platform replace a running host from another build.
//
// Skipped unless a host folder is given, and never the real one. Start a host from an older build in that
// folder, write its app_config.json with this checkout's `mydata dev-setup`, then:
//   flutter test test/live --dart-define=MYDATA_HOME=<folder>
// The folder needs its own config.toml with a free port; the replaced host is left running there.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

const _home = String.fromEnvironment('MYDATA_HOME');

String? _skip() {
  if (_home.isEmpty) return 'live: pass --dart-define=MYDATA_HOME=<a temporary host folder>';
  if (_home.contains('Application Support/myData')) return 'live: refuses the real host folder';
  return null;
}

void main() {
  // No test binding: it would fake every HTTP request.
  test('replaces a host from another build with the current one', () async {
    final controller = HostController(app: 'mydata', startTimeout: const Duration(seconds: 60));
    addTearDown(controller.dispose);
    final phases = <HostPhase>[];
    controller.addListener(() {
      if (phases.isEmpty || phases.last != controller.phase) phases.add(controller.phase);
    });
    final watch = Stopwatch()..start();
    await controller.connect();
    stdout.writeln('phases: ${phases.map((p) => p.name).join(' -> ')} in ${watch.elapsedMilliseconds} ms');
    stdout.writeln('error: ${controller.error}; detail: ${controller.detail}');
    expect(phases, containsAllInOrder([HostPhase.restarting, HostPhase.running]));
    expect(phases, isNot(contains(HostPhase.failedToStart)));
    expect(controller.phase, HostPhase.running);
    final s = controller.status!;
    stdout.writeln('status: version ${s.version}, api_version ${s.apiVersion}, stale ${s.stale}');
    expect(s.version, expectedHostVersion);
    expect(s.apiVersion, expectedHostApiVersion);
  }, skip: _skip(), timeout: const Timeout(Duration(minutes: 3)));
}
