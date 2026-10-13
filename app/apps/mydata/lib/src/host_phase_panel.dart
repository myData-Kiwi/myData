import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// What to show while the host is not running: every phase has a message, and every failure a Retry, here
/// or in the app frame around it.
class HostPhasePanel extends StatelessWidget {
  const HostPhasePanel({
    super.key,
    required this.phase,
    this.error,
    this.detail,
    required this.onRetry,
    this.showRetry = true,
  });

  final HostPhase phase;

  /// [HostController.error] and [HostController.detail].
  final String? error;
  final String? detail;
  final VoidCallback onRetry;

  /// Whether the panel offers its own Retry on a failure. False inside the app frame, whose connection line
  /// already has one: an error offers one next step (design/platforms.md "Offline and errors").
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final (kind, title, message) = switch (phase) {
      HostPhase.checking => (StatusPanelKind.working, 'Looking for the myData host', 'Checking whether it is running.'),
      HostPhase.starting => (StatusPanelKind.working, 'Starting the myData host', 'This takes a few seconds.'),
      HostPhase.running => (StatusPanelKind.info, 'Connected', 'The myData host is running.'),
      HostPhase.notConfigured => (
        StatusPanelKind.error,
        'myData is not set up',
        error ?? 'There is no way to start the host.',
      ),
      HostPhase.failedToStart => (
        StatusPanelKind.error,
        'The host did not start',
        error ?? 'The myData host did not start.',
      ),
      HostPhase.lost => (StatusPanelKind.error, 'The host stopped', error ?? 'The myData host stopped answering.'),
      HostPhase.unsupported => (
        StatusPanelKind.info,
        'Use the desktop app',
        error ?? 'This version cannot reach the host.',
      ),
    };
    final canRetry = showRetry && kind != StatusPanelKind.working && phase != HostPhase.running;
    return StatusPanel(
      kind: kind,
      title: title,
      message: message,
      detail: kind == StatusPanelKind.working ? null : detail,
      actions: [if (canRetry) Button(label: 'Retry', onPressed: onRetry, variant: ButtonVariant.filled)],
    );
  }
}
