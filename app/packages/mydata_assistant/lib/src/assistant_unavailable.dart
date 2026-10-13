import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// Shown instead of the chat whenever the assistant cannot answer: says why in plain words and offers the
/// way out (the myData app) and, where it helps, a fresh look.
///
/// Switched off, it is the one screen design/platforms.md asks for: what myAssistant is, that it is off, and
/// the way to turn it on in myData ([EmptyState], with the kiwi). Every other state is a [StatusPanel].
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

  static const offTitle = 'The assistant is off';
  static const offSentence = 'myAssistant answers questions about your data. Turn it on in myData, under Settings.';
  static const offAction = 'Open myData';
  static const setupAction = 'Open myData setup';
  static const checkAgain = 'Check again';

  /// The [notice] when the off screen's button could not open myData: the same destination as the
  /// sentence and the button, Settings.
  static const offOpenFailed =
      'myAssistant could not open myData from here. Open the myData app yourself and turn the assistant on '
      'under Settings.';

  /// The [notice] when "Open myData setup" could not open myData.
  static const setupOpenFailed =
      'myAssistant could not open myData from here. Open the myData app yourself and go to Setup.';

  /// The [notice] for [status] after myData could not be opened from here: [offOpenFailed] while the
  /// assistant is off, otherwise [setupOpenFailed].
  static String openFailedNotice(StatusOut status) =>
      assistantAvailability(status) == AssistantAvailability.off ? offOpenFailed : setupOpenFailed;

  @override
  Widget build(BuildContext context) {
    final model = status.model;
    final availability = assistantAvailability(status);
    if (availability == AssistantAvailability.off) return _off(context);
    final (kind, title, message) = switch (availability) {
      AssistantAvailability.notInstalled => (
        StatusPanelKind.info,
        'Ollama is not installed',
        'The assistant runs its language model on this computer through Ollama. '
            'Open myData setup to install it, then check again.',
      ),
      AssistantAvailability.preparing => (
        StatusPanelKind.working,
        'The assistant is getting ready',
        '${describeModel(model)}. This page switches to the chat by itself when the model is ready.',
      ),
      AssistantAvailability.failed => (
        StatusPanelKind.error,
        'The model could not be prepared',
        'Open myData setup to see what went wrong and try again.',
      ),
      _ => (StatusPanelKind.info, 'The assistant is ready', 'Check again to start chatting.'),
    };
    final pulling = model.state == ModelOutStateEnum.pulling ? model.progress : null;
    final shown = pulling == null ? message : 'This page switches to the chat by itself when the model is ready.';
    return StatusPanel(
      kind: kind,
      title: title,
      message: notice == null ? shown : '$shown\n\n$notice',
      detail: kind == StatusPanelKind.error ? model.error : null,
      progress: pulling == null ? null : (pulling.percent / 100).clamp(0, 1).toDouble(),
      progressLabel: pulling == null ? null : describeModel(model),
      actions: [
        Button(label: setupAction, variant: ButtonVariant.filled, onPressed: onOpenSetup),
        Button(label: checkAgain, onPressed: onCheckAgain),
      ],
    );
  }

  Widget _off(BuildContext context) {
    final c = context.colors;
    final screen = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EmptyState(title: offTitle, sentence: offSentence, actionLabel: offAction, onAction: onOpenSetup),
        if (notice != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
            child: Padding(
              padding: const EdgeInsets.only(top: EmptyState.reasonGap),
              child: Text(
                notice!,
                textAlign: TextAlign.center,
                style: MyDataType.caption.copyWith(color: c.inkMuted),
              ),
            ),
          ),
      ],
    );
    // Centred in the space it has, and scrolling when a short window cannot hold it.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(StatusPanel.padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - 2 * StatusPanel.padding).clamp(0, double.infinity)
                : 0,
          ),
          child: Center(child: screen),
        ),
      ),
    );
  }
}
