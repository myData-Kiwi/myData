import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'host_phase_panel.dart';

/// Shown until the host is ready: the host starting, then the assistant's model being prepared.
/// The assistant can be skipped at any point; myData works without it.
///
/// It takes plain inputs (no controller) so it can be tested without a host.
class SetupScreen extends StatelessWidget {
  const SetupScreen({
    super.key,
    required this.phase,
    required this.status,
    this.error,
    this.detail,
    required this.onRetryHost,
    required this.onRetryModel,
    required this.onSkip,
    required this.onContinue,
    required this.onSwitchOn,
  });

  final HostPhase phase;

  /// The host's latest status; used once [phase] is [HostPhase.running].
  final StatusOut? status;
  final String? error;
  final String? detail;

  /// Connect to (or start) the host again.
  final VoidCallback onRetryHost;

  /// Ask the host to try again to get the model ready.
  final VoidCallback onRetryModel;

  /// Switch the assistant off and move on.
  final VoidCallback onSkip;

  /// Move on, leaving the assistant as it is.
  final VoidCallback onContinue;

  /// Switch the assistant on (it was off).
  final VoidCallback onSwitchOn;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final panel = phase == HostPhase.running && s != null
        ? _assistantPanel(s)
        : HostPhasePanel(phase: phase, error: error, detail: detail, onRetry: onRetryHost);
    return Scaffold(
      appBar: const AppHeader(title: 'myData'),
      body: Center(child: SingleChildScrollView(child: panel)),
    );
  }

  Widget _assistantPanel(StatusOut s) {
    final m = s.model;
    if (!s.assistantEnabled || m.state == ModelOutStateEnum.disabled) {
      return MessagePanel(
        kind: PanelKind.info,
        title: 'The assistant is off',
        message: 'myData works without it. Switching it on downloads its model if it is not on this computer yet.',
        primaryLabel: 'Continue',
        onPrimary: onContinue,
        secondaryLabel: 'Switch the assistant on',
        onSecondary: onSwitchOn,
      );
    }
    return switch (m.state) {
      ModelOutStateEnum.ready => MessagePanel(
        kind: PanelKind.info,
        title: 'myData is ready',
        message: '${describeModel(m)}. The assistant can answer.',
        primaryLabel: 'Continue',
        onPrimary: onContinue,
      ),
      ModelOutStateEnum.ollamaMissing => MessagePanel(
        kind: PanelKind.info,
        title: 'Ollama is not installed',
        message:
            'The assistant runs its model with Ollama. Install Ollama from ollama.com, then choose Retry. '
            'Everything else in myData works without it.',
        primaryLabel: 'Retry',
        onPrimary: onRetryModel,
        secondaryLabel: 'Skip for now',
        onSecondary: onSkip,
      ),
      ModelOutStateEnum.error => MessagePanel(
        kind: PanelKind.error,
        title: describeModel(m),
        message: 'Retry, or skip for now and use myData without the assistant.',
        detail: m.error,
        primaryLabel: 'Retry',
        onPrimary: onRetryModel,
        secondaryLabel: 'Skip for now',
        onSecondary: onSkip,
      ),
      _ => MessagePanel(
        kind: PanelKind.working,
        title: 'Preparing the assistant',
        message: _progressLine(m),
        progress: _fraction(m),
        secondaryLabel: 'Skip for now',
        onSecondary: onSkip,
      ),
    };
  }

  static String _progressLine(ModelOut m) {
    final p = m.progress;
    if (m.state != ModelOutStateEnum.pulling || p == null || p.total <= 0) return describeModel(m);
    return '${describeModel(m)} (${formatBytes(p.completed)} of ${formatBytes(p.total)})';
  }

  static double? _fraction(ModelOut m) {
    final p = m.progress;
    if (m.state != ModelOutStateEnum.pulling || p == null) return null;
    return (p.percent / 100).clamp(0, 1).toDouble();
  }
}
