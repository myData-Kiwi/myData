import 'package:mydata_client/api.dart';

/// Whether the assistant can answer, and if not, why, in words for people.
enum AssistantAvailability { ready, off, preparing, notInstalled, failed }

AssistantAvailability assistantAvailability(StatusOut s) {
  if (!s.assistantEnabled) return AssistantAvailability.off;
  return switch (s.model.state) {
    ModelOutStateEnum.ready => AssistantAvailability.ready,
    ModelOutStateEnum.disabled => AssistantAvailability.off,
    ModelOutStateEnum.ollamaMissing => AssistantAvailability.notInstalled,
    ModelOutStateEnum.error => AssistantAvailability.failed,
    _ => AssistantAvailability.preparing,
  };
}

/// One line describing the model's state.
String describeModel(ModelOut m) {
  final state = m.state;
  if (state == ModelOutStateEnum.pulling && m.progress != null) {
    return 'Downloading ${m.name}: ${m.progress!.percent.toStringAsFixed(0)}%';
  }
  return switch (state) {
    ModelOutStateEnum.starting => 'Getting ${m.name} ready',
    ModelOutStateEnum.ollamaStarting => 'Starting Ollama',
    ModelOutStateEnum.ollamaMissing => 'Ollama is not installed',
    ModelOutStateEnum.pulling => 'Downloading ${m.name}',
    ModelOutStateEnum.loading => 'Loading ${m.name} into memory',
    ModelOutStateEnum.ready => '${m.name} is ready',
    ModelOutStateEnum.error => 'The model could not be prepared',
    ModelOutStateEnum.disabled => 'The assistant is switched off',
  };
}
