import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/desktop_lifetime.dart';
import 'package:mydata_core/mydata_core.dart';

void main() {
  test('the menu-bar menu offers Stop host while the host runs, and Start host once it does not', () {
    final running = DesktopLifetime.hostItemFor(HostPhase.running);
    expect(running.label, 'Stop host');
    expect(running.enabled, isTrue);
    for (final phase in [HostPhase.lost, HostPhase.unreachable, HostPhase.failedToStart, HostPhase.incompatible]) {
      final item = DesktopLifetime.hostItemFor(phase);
      expect(item.label, 'Start host', reason: '$phase');
      expect(item.enabled, isTrue, reason: '$phase');
    }
    // Busy finding, starting or replacing the host, or nothing to start it with: shown, not enabled.
    for (final phase in [
      HostPhase.checking,
      HostPhase.starting,
      HostPhase.restarting,
      HostPhase.notConfigured,
      HostPhase.unsupported,
    ]) {
      final item = DesktopLifetime.hostItemFor(phase);
      expect(item.enabled, isFalse, reason: '$phase');
      expect(item.label, isNot('Start host'), reason: '$phase: a disabled item says why');
    }
  });

  test('the menu says the host\'s state on its first line, for every phase', () {
    expect(DesktopLifetime.hostStateFor(HostPhase.running), 'Host running');
    expect(DesktopLifetime.hostStateFor(HostPhase.lost), 'Host stopped');
    expect(DesktopLifetime.hostStateFor(HostPhase.starting), 'Starting the host…');
    for (final phase in HostPhase.values) {
      expect(DesktopLifetime.hostStateFor(phase), isNotEmpty, reason: '$phase');
    }
  });
}
