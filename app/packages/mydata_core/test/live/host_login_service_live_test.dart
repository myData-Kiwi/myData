// Live check: the real HostController and IO platform with a host installed as a login service (launchd).
//
// Skipped unless a host folder is given, and never the real one. Install the host for that folder with a test
// label (host/packaging/macos/install.sh --label kiwi.mydata.host-test ...; its config.toml needs a free port),
// stop it (`mydata stop`), then:
//   flutter test test/live/host_login_service_live_test.dart --dart-define=MYDATA_HOME=<folder>
// Uninstall it afterwards (uninstall.sh with the same label).
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
  test('an app starts the installed host through launchd; Stop host leaves it stopped; Start host starts it', () async {
    final controller = HostController(app: 'mydata', startTimeout: const Duration(seconds: 60));
    addTearDown(controller.dispose);
    await controller.connect();
    expect(controller.phase, HostPhase.running, reason: '${controller.error} ${controller.detail}');

    expect(await controller.stopHost(), isTrue);
    expect(controller.error, HostController.stoppedMessage);
    // launchd does not start it again: the host exited with 0.
    await Future<void>.delayed(const Duration(seconds: 20));
    final probe = HostController(app: 'mydata');
    addTearDown(probe.dispose);
    await probe.connect(startIfNeeded: false);
    expect(probe.phase, HostPhase.unreachable, reason: 'launchd started the host again after a clean stop');

    await controller.connect(); // Start host
    expect(controller.phase, HostPhase.running, reason: '${controller.error} ${controller.detail}');
    stdout.writeln('host ${controller.status!.version} running again');
  }, skip: _skip(), timeout: const Timeout(Duration(minutes: 3)));
}
