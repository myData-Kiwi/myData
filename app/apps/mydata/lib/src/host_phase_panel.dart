import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// What to show while the host is not running: every phase has a message, and every failure a Retry.
class HostPhasePanel extends StatelessWidget {
  const HostPhasePanel({super.key, required this.phase, this.error, this.detail, required this.onRetry});

  final HostPhase phase;

  /// [HostController.error] and [HostController.detail].
  final String? error;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (kind, title, message) = switch (phase) {
      HostPhase.checking => (PanelKind.working, 'Looking for the myData host', 'Checking whether it is running.'),
      HostPhase.starting => (PanelKind.working, 'Starting the myData host', 'This takes a few seconds.'),
      HostPhase.running => (PanelKind.info, 'Connected', 'The myData host is running.'),
      HostPhase.notConfigured => (
        PanelKind.error,
        'myData is not set up',
        error ?? 'There is no way to start the host.',
      ),
      HostPhase.failedToStart => (PanelKind.error, 'The host did not start', error ?? 'The myData host did not start.'),
      HostPhase.lost => (PanelKind.error, 'The host stopped', error ?? 'The myData host stopped answering.'),
      HostPhase.unsupported => (PanelKind.info, 'Use the desktop app', error ?? 'This version cannot reach the host.'),
    };
    final canRetry = kind != PanelKind.working && phase != HostPhase.running;
    return MessagePanel(
      kind: kind,
      title: title,
      message: message,
      detail: kind == PanelKind.working ? null : detail,
      primaryLabel: 'Retry',
      onPrimary: canRetry ? onRetry : null,
    );
  }
}
