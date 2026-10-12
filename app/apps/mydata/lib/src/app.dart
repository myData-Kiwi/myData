import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'host_action.dart';
import 'setup_screen.dart';
import 'shell.dart';

class MyDataApp extends StatelessWidget {
  const MyDataApp({super.key, required this.controller, this.openSetup = false});

  final HostController controller;

  /// Start on the Setup screen even if the host is ready (launched with --setup, e.g. by myAssistant).
  final bool openSetup;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'myData',
    theme: myDataTheme(),
    debugShowCheckedModeBanner: false,
    home: _Home(controller: controller, openSetup: openSetup),
  );
}

/// Setup until the person moves on from it, then the Status and Settings shell.
class _Home extends StatefulWidget {
  const _Home({required this.controller, required this.openSetup});

  final HostController controller;
  final bool openSetup;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  /// Null until the host first answers, unless setup was asked for.
  late bool? _inSetup = widget.openSetup ? true : null;

  HostController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onHost);
    _decide();
  }

  @override
  void dispose() {
    _c.removeListener(_onHost);
    super.dispose();
  }

  void _onHost() => setState(_decide);

  /// Setup is skipped at launch when there is nothing to wait for: the assistant is ready, or switched off.
  void _decide() {
    final s = _c.status;
    if (_inSetup != null || _c.phase != HostPhase.running || s == null) return;
    final a = assistantAvailability(s);
    _inSetup = a != AssistantAvailability.ready && a != AssistantAvailability.off;
  }

  void _leaveSetup() => setState(() => _inSetup = false);

  Future<void> _skip() async {
    final ok = await runHostAction(
      context,
      _c,
      failure: 'Could not switch the assistant off',
      action: (c) => c.assistant.assistantSettings(AssistantSettingsIn(enabled: false)),
    );
    if (ok && mounted) _leaveSetup();
  }

  Future<void> _switchOn() => runHostAction(
    context,
    _c,
    failure: 'Could not switch the assistant on',
    action: (c) => c.assistant.assistantSettings(AssistantSettingsIn(enabled: true)),
  );

  Future<void> _retryModel() => runHostAction(context, _c, failure: 'Could not retry', action: (c) => c.host.retry());

  @override
  Widget build(BuildContext context) {
    if (_inSetup == false) return HomeShell(controller: _c);
    return SetupScreen(
      phase: _c.phase,
      status: _c.status,
      error: _c.error,
      detail: _c.detail,
      onRetryHost: _c.retry,
      onRetryModel: _retryModel,
      onSkip: _skip,
      onContinue: _leaveSetup,
      onSwitchOn: _switchOn,
    );
  }
}
