import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'format.dart';
import 'host_phase_panel.dart';

/// Shown until the host is ready: the host starting, on first run (on a Mac host) whether to use the contacts
/// and calendars on this Mac, then the assistant's model being prepared. Themes are not asked: System is the
/// default, and the gallery is in every app's View menu (design/themes/ARCHITECTURE.md 4.3). The assistant can
/// be skipped at any point; myData works without it.
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
    this.macStep = false,
    this.onAllowMac,
    this.onSkipMac,
    this.onMacDone,
    this.onOpenMacSettings,
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

  /// Show the This Mac step: a Mac host whose This Mac source was never turned on or
  /// off.
  final bool macStep;

  /// Turns This Mac on and asks for access to contacts, then calendars (the system's prompts appear).
  /// Returns null when both may be read (the step is then done), or what is missing, which the step shows.
  /// Throws when that failed; the step then says so.
  final Future<MacAccessShortfall?> Function()? onAllowMac;

  /// Leaves This Mac off, recording the choice, and moves on.
  final Future<void> Function()? onSkipMac;

  /// Moves on after Allow failed part-way, or without waiting for the answer (the choice can be finished in
  /// Settings).
  final VoidCallback? onMacDone;

  /// Opens System Settings at a privacy pane ([PrivacyPane]).
  final Future<void> Function(String pane)? onOpenMacSettings;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final running = phase == HostPhase.running && s != null;
    final Widget body;
    if (running && macStep && onAllowMac != null && onSkipMac != null) {
      body = ThisMacStep(
        onAllow: onAllowMac!,
        onSkip: onSkipMac!,
        onDone: onMacDone ?? () {},
        onOpenSettings: onOpenMacSettings,
      );
    } else if (running) {
      body = _assistantPanel(s);
    } else {
      body = HostPhasePanel(phase: phase, error: error, detail: detail, onRetry: onRetryHost);
    }
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: SafeArea(child: body),
    );
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

/// What Allow ended with when myData may not read both contacts and calendars: a sentence for people, and
/// the System Settings pane that changes it, when there is one.
class MacAccessShortfall {
  const MacAccessShortfall(this.message, {this.pane});

  final String message;

  /// A [PrivacyPane], or null when System Settings cannot help (a restriction, or no answer yet).
  final String? pane;
}

/// First run on a Mac host: use the contacts and calendars on this Mac? Allow turns This Mac on and asks
/// macOS for access to contacts, then calendars; Skip leaves it off. Either way the question is not asked
/// again (the host records it), and Settings, Sources changes it later. When the person did not allow both,
/// the step stays and says what myData can and cannot read.
class ThisMacStep extends StatefulWidget {
  const ThisMacStep({
    super.key,
    required this.onAllow,
    required this.onSkip,
    required this.onDone,
    this.onOpenSettings,
  });

  /// Returns null when both may be read, else what is missing. Throws when it could not finish.
  final Future<MacAccessShortfall?> Function() onAllow;
  final Future<void> Function() onSkip;

  /// Moves on: after a failure, after a partial answer, or without waiting for the answer.
  final VoidCallback onDone;

  /// Opens System Settings at a [PrivacyPane].
  final Future<void> Function(String pane)? onOpenSettings;

  static const title = 'Use the contacts and calendars on this Mac';
  static const sentence =
      'myData reads them from this Mac, from every account you have set up here. Nothing is sent anywhere, '
      'and myData never changes them.';
  static const allowLabel = 'Allow';
  static const skipLabel = 'Skip';
  static const waitingTitle = 'Waiting for your answer';
  static const waitingMessage =
      'macOS asks whether myData may read your contacts, then your calendars. Answer in its window. If you '
      'cannot see it, continue and finish this later in Settings, Sources.';
  static const continueWithoutWaiting = 'Continue without waiting';
  static const failedTitle = 'Access was not set up';
  static const failedMessage = 'You can finish this later in Settings, Sources, or try again now.';
  static const shortTitle = 'Not everything can be read';
  static const continueLabel = 'Continue';
  static const openSettingsLabel = 'Open System Settings';

  /// The Mac frame's first launch: the same choice, as a welcome.
  static const macTitle = 'Use your Mac’s contacts and calendars';
  static const sampleLabel = 'Try with sample data';
  static const macNote = 'You can change this later in Settings, Sources.';

  /// What is missing after Allow, from the statuses the host reports; null when both may be read.
  static MacAccessShortfall? shortfall(String? contacts, String? calendars) {
    final contactsOk = contacts == 'authorized';
    final calendarsOk = calendars == 'fullAccess';
    if (contactsOk && calendarsOk) return null;
    final what = contactsOk
        ? 'myData can read your contacts but not your calendars.'
        : calendarsOk
        ? 'myData can read your calendars but not your contacts.'
        : 'myData cannot read your contacts or your calendars.';
    final missing = [if (!contactsOk) ('contacts', contacts), if (!calendarsOk) ('calendars', calendars)];
    final turnedOff = [
      for (final (kind, status) in missing)
        if (status == 'denied' || status == 'writeOnly') kind,
    ];
    if (turnedOff.isNotEmpty) {
      final panes = turnedOff.map((k) => k == 'contacts' ? 'Contacts' : 'Calendars').join(' and ');
      return MacAccessShortfall(
        '$what You can turn access on later in System Settings, Privacy & Security, $panes.',
        pane: turnedOff.first == 'contacts' ? PrivacyPane.contacts : PrivacyPane.calendars,
      );
    }
    if (missing.any((m) => m.$2 == 'restricted')) {
      return MacAccessShortfall(
        '$what A restriction set on this Mac, such as Screen Time or a profile, does not allow it.',
      );
    }
    return MacAccessShortfall('$what You can allow it later in Settings, Sources.');
  }

  @override
  State<ThisMacStep> createState() => _ThisMacStepState();
}

class _ThisMacStepState extends State<ThisMacStep> {
  bool _working = false;
  bool _skipping = false;
  String? _error;
  MacAccessShortfall? _short;

  Future<void> _allow() async {
    setState(() {
      _working = true;
      _error = null;
      _short = null;
    });
    try {
      final short = await widget.onAllow();
      if (mounted) setState(() => _short = short);
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _skipping = true);
    try {
      await widget.onSkip();
    } finally {
      if (mounted) setState(() => _skipping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_working) {
      return StatusPanel(
        kind: StatusPanelKind.working,
        title: ThisMacStep.waitingTitle,
        message: ThisMacStep.waitingMessage,
        actions: [
          Button(label: ThisMacStep.continueWithoutWaiting, onPressed: widget.onDone, variant: ButtonVariant.plain),
        ],
      );
    }
    if (_error != null) {
      return StatusPanel(
        kind: StatusPanelKind.error,
        title: ThisMacStep.failedTitle,
        message: ThisMacStep.failedMessage,
        detail: _error,
        actions: [
          Button(label: 'Try again', onPressed: _allow, variant: ButtonVariant.filled),
          Button(label: ThisMacStep.continueLabel, onPressed: widget.onDone, variant: ButtonVariant.plain),
        ],
      );
    }
    final short = _short;
    if (short != null) {
      final pane = short.pane;
      final open = widget.onOpenSettings;
      return StatusPanel(
        kind: StatusPanelKind.info,
        title: ThisMacStep.shortTitle,
        message: short.message,
        actions: [
          Button(label: ThisMacStep.continueLabel, onPressed: widget.onDone, variant: ButtonVariant.filled),
          if (pane != null && open != null)
            Button(label: ThisMacStep.openSettingsLabel, onPressed: () => open(pane), variant: ButtonVariant.plain),
        ],
      );
    }
    if (MacWindow.of(context)) return _macWelcome(context);
    return StatusPanel(
      kind: StatusPanelKind.info,
      title: ThisMacStep.title,
      message: ThisMacStep.sentence,
      actions: [
        Button(label: ThisMacStep.allowLabel, onPressed: _skipping ? null : _allow, variant: ButtonVariant.filled),
        Button(label: ThisMacStep.skipLabel, onPressed: _skipping ? null : _skip, variant: ButtonVariant.plain),
      ],
    );
  }

  /// The Mac frame's welcome: the kiwi, the question, and the two answers, Allow the default.
  Widget _macWelcome(BuildContext context) {
    final mac = context.mac;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(context.space(8), MyDataMacSize.toolbarHeight, context.space(8), context.space(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MyDataSize.dialogWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MacKiwi(height: MyDataMacSize.avatar),
              SizedBox(height: context.space(6)),
              Semantics(
                header: true,
                child: Text(
                  ThisMacStep.macTitle,
                  textAlign: TextAlign.center,
                  style: MyDataMacType.name.copyWith(color: mac.label),
                ),
              ),
              SizedBox(height: context.space(2)),
              Text(
                ThisMacStep.sentence,
                textAlign: TextAlign.center,
                style: MyDataMacType.body.copyWith(color: mac.secondaryLabel),
              ),
              SizedBox(height: context.space(6)),
              ButtonRow(
                alignment: WrapAlignment.center,
                children: [
                  Button(
                    label: ThisMacStep.sampleLabel,
                    variant: ButtonVariant.tonal,
                    onPressed: _skipping ? null : _skip,
                  ),
                  // The default button: focus starts here, so Return presses it, as a Mac welcome's does.
                  Button(
                    label: ThisMacStep.allowLabel,
                    variant: ButtonVariant.filled,
                    autofocus: true,
                    onPressed: _skipping ? null : _allow,
                  ),
                ],
              ),
              SizedBox(height: context.space(5)),
              Text(
                ThisMacStep.macNote,
                textAlign: TextAlign.center,
                style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
