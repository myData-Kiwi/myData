import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'format.dart';
import 'host_phase_panel.dart';

/// Shown until the host is ready: the host starting, on first run the theme, then the assistant's model
/// being prepared. The assistant can be skipped at any point; myData works without it.
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
    this.themeChosen = true,
    this.onChooseTheme,
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

  /// Whether a theme has been chosen on this host (GET /appearance `chosen`). False shows the theme step
  /// before the assistant, once the host runs (design/theming.md "Choosing a theme").
  final bool themeChosen;

  /// Stores the theme picked on the theme step (PUT /appearance), even the default. Throws when it could
  /// not be stored; the step then says so and stays.
  final Future<void> Function(String themeId)? onChooseTheme;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final running = phase == HostPhase.running && s != null;
    final Widget body;
    if (running && !themeChosen && onChooseTheme != null) {
      body = ThemeStep(onChoose: onChooseTheme!);
    } else if (running) {
      body = _assistantPanel(s);
    } else {
      body = HostPhasePanel(phase: phase, error: error, detail: detail, onRetry: onRetryHost);
    }
    return Scaffold(backgroundColor: context.colors.bg, body: SafeArea(child: body));
  }

  Widget _assistantPanel(StatusOut s) {
    final m = s.model;
    const skip = 'Skip for now';
    if (!s.assistantEnabled || m.state == ModelOutStateEnum.disabled) {
      return StatusPanel(
        kind: StatusPanelKind.info,
        title: 'The assistant is off',
        message: 'myData works without it. Switching it on downloads its model if it is not on this computer yet.',
        actions: [
          Button(label: 'Continue', onPressed: onContinue, variant: ButtonVariant.filled),
          Button(label: 'Switch the assistant on', onPressed: onSwitchOn),
        ],
      );
    }
    return switch (m.state) {
      ModelOutStateEnum.ready => StatusPanel(
        kind: StatusPanelKind.info,
        title: 'myData is ready',
        message: '${describeModel(m)}. The assistant can answer.',
        actions: [Button(label: 'Continue', onPressed: onContinue, variant: ButtonVariant.filled)],
      ),
      ModelOutStateEnum.ollamaMissing => StatusPanel(
        kind: StatusPanelKind.info,
        title: 'Ollama is not installed',
        message:
            'The assistant runs its model with Ollama. Install Ollama from ollama.com, then choose Retry. '
            'Everything else in myData works without it.',
        actions: [
          Button(label: 'Retry', onPressed: onRetryModel, variant: ButtonVariant.filled),
          Button(label: skip, onPressed: onSkip),
        ],
      ),
      ModelOutStateEnum.error => StatusPanel(
        kind: StatusPanelKind.error,
        title: describeModel(m),
        message: 'Retry, or skip for now and use myData without the assistant.',
        detail: m.error,
        actions: [
          Button(label: 'Retry', onPressed: onRetryModel, variant: ButtonVariant.filled),
          Button(label: skip, onPressed: onSkip),
        ],
      ),
      _ => _preparing(m, skip),
    };
  }

  /// The model on its way: a progress bar while it downloads, the loading kiwi for the other steps.
  Widget _preparing(ModelOut m, String skip) {
    final p = m.progress;
    final downloading = m.state == ModelOutStateEnum.pulling && p != null;
    return StatusPanel(
      kind: StatusPanelKind.working,
      title: 'Preparing the assistant',
      message: downloading && p.total > 0
          ? '${formatSize(p.completed)} of ${formatSize(p.total)}. Skipping stops the download; '
                'you can switch the assistant on later in Settings.'
          : describeModel(m),
      progress: downloading ? (p.percent / 100).clamp(0, 1).toDouble() : null,
      progressLabel: downloading ? 'Downloading ${m.name}' : null,
      actions: [Button(label: skip, onPressed: onSkip)],
    );
  }
}

/// First run: one screen to choose the theme every myData app uses, with Kiwi selected. Picking a theme
/// previews it here at once; "Use this theme" stores it on the host (even Kiwi, so the question is not asked
/// again) and setup moves on.
class ThemeStep extends StatefulWidget {
  const ThemeStep({super.key, required this.onChoose});

  /// Stores the theme; throws when it could not.
  final Future<void> Function(String themeId) onChoose;

  static const title = 'Choose a theme';
  static const sentence = 'Every myData app uses it. You can change it later in Settings, Appearance.';
  static const useLabel = 'Use this theme';
  static const failed = 'Could not change the theme. Check that your host is running, then try again.';

  /// The step's column: wide enough for the six theme swatches on one row (about 630 px in the bundled
  /// fonts) and the theme sample at its natural size. A test checks that the swatches stay on one row.
  static const maxWidth = ThemeSample.naturalWidth + 3 * MyDataSpace.s12;

  @override
  State<ThemeStep> createState() => _ThemeStepState();
}

class _ThemeStepState extends State<ThemeStep> {
  String _selected = MyDataThemes.fallback.id;
  bool _saving = false;
  String? _error;

  Future<void> _use() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onChoose(_selected);
    } on Object {
      if (mounted) setState(() => _error = ThemeStep.failed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The pick is previewed on this screen only; the host (and every app) gets it with "Use this theme".
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: MyDataTheme.data(_selected, brightness),
      child: Builder(builder: (context) {
        final c = context.colors;
        return Material(
          color: c.bg,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(MyDataSpace.s8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ThemeStep.maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(ThemeStep.title, style: MyDataType.displayLg.copyWith(color: c.ink)),
                    ),
                    const SizedBox(height: MyDataSpace.s2),
                    Text(ThemeStep.sentence, style: MyDataType.body.copyWith(color: c.inkMuted)),
                    const SizedBox(height: MyDataSpace.s6),
                    ThemePicker(
                      selected: _selected,
                      onChanged: _saving ? null : (id) => setState(() => _selected = id),
                    ),
                    const SizedBox(height: MyDataSpace.s6),
                    ThemeSample(themeId: _selected),
                    const SizedBox(height: MyDataSpace.s6),
                    Button(
                      label: ThemeStep.useLabel,
                      variant: ButtonVariant.filled,
                      onPressed: _saving ? null : _use,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: MyDataSpace.s3),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: MyDataType.caption.copyWith(color: c.danger)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
