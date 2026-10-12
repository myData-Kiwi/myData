import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// Shown instead of the chat whenever the assistant cannot answer: says why in plain words and
/// offers the way out (the myData app's setup) and a fresh look.
class AssistantUnavailable extends StatelessWidget {
  const AssistantUnavailable({
    super.key,
    required this.status,
    required this.onOpenSetup,
    required this.onCheckAgain,
    this.notice,
  });

  final StatusOut status;
  final VoidCallback onOpenSetup;
  final VoidCallback onCheckAgain;

  /// An extra line under the message, e.g. that the myData app could not be opened from here.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final model = status.model;
    final (kind, title, message) = switch (assistantAvailability(status)) {
      AssistantAvailability.off => (
        PanelKind.info,
        'The assistant is switched off',
        'Switch it on in the myData app to chat here. Until then nothing you type is answered.',
      ),
      AssistantAvailability.notInstalled => (
        PanelKind.info,
        'Ollama is not installed',
        'The assistant runs its language model on this computer through Ollama. '
            'Open myData setup to install it, then check again.',
      ),
      AssistantAvailability.preparing => (
        PanelKind.working,
        'The assistant is getting ready',
        '${describeModel(model)}. This page switches to the chat by itself when the model is ready.',
      ),
      AssistantAvailability.failed => (
        PanelKind.error,
        'The model could not be prepared',
        'Open myData setup to see what went wrong and try again.',
      ),
      AssistantAvailability.ready => (PanelKind.info, 'The assistant is ready', 'Check again to start chatting.'),
    };
    final pulling = model.state == ModelOutStateEnum.pulling ? model.progress : null;
    return MessagePanel(
      kind: kind,
      title: title,
      message: notice == null ? message : '$message\n\n$notice',
      detail: kind == PanelKind.error ? model.error : null,
      progress: pulling == null ? null : (pulling.percent / 100).clamp(0, 1).toDouble(),
      primaryLabel: 'Open myData setup',
      onPrimary: onOpenSetup,
      secondaryLabel: 'Check again',
      onSecondary: onCheckAgain,
    );
  }
}
