import 'package:mydata_core/mydata_core.dart';

/// A host status with the model in [state], built with the generated constructors.
StatusOut statusWith(ModelOutStateEnum state, {Progress? progress, String? error, bool enabled = true}) => StatusOut(
  agentsConnected: 0,
  assistantEnabled: enabled,
  demoDate: true,
  memory: MemoryOut(hostBytes: 120000000),
  model: ModelOut(
    name: 'qwen3:14b',
    state: state,
    loaded: state == ModelOutStateEnum.ready,
    ollamaReachable: state != ModelOutStateEnum.ollamaMissing,
    ollamaStartedByHost: true,
    progress: progress,
    error: error,
  ),
  ready: state == ModelOutStateEnum.ready,
  theme: 'kiwi',
  today: '2026-03-18',
  uptimeSeconds: 12,
  version: '0.1.0',
);
