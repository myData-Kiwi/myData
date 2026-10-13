import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'host_phase_panel.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

/// The myData app after setup: Status and Settings in the app frame. If the host stops, its panel takes
/// their place and the frame says the host cannot be reached.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.appearance});

  final HostController controller;
  final AppearanceController appearance;

  static const sections = [
    AppSection(icon: Icons.monitor_heart_outlined, label: 'Status'),
    AppSection(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  /// What the frame says about the host in [phase]. This is myData, so there is no "Open myData" link.
  static AppConnection connectionFor(HostPhase phase, VoidCallback onRetry) => switch (phase) {
    HostPhase.running => const AppConnection.connected(),
    HostPhase.checking || HostPhase.starting => const AppConnection.starting(),
    HostPhase.lost ||
    HostPhase.failedToStart ||
    HostPhase.notConfigured ||
    HostPhase.unsupported => AppConnection.unreachable(onRetry: onRetry),
  };

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final _agents = AgentList(widget.controller);
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPoll);
    _agents.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPoll);
    _agents.dispose();
    super.dispose();
  }

  // The agent list follows the controller's status polling, so "connected" stays current.
  void _onPoll() {
    if (widget.controller.phase == HostPhase.running) _agents.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.bg,
    body: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return AppFrame(
          appName: 'myData',
          sections: HomeShell.sections,
          current: _index,
          onSelect: (i) => setState(() => _index = i),
          connection: HomeShell.connectionFor(c.phase, c.retry),
          child: _page(),
        );
      },
    ),
  );

  Widget _page() {
    final c = widget.controller;
    final status = c.status;
    if (c.phase != HostPhase.running || status == null) {
      // The frame's connection line carries the Retry ([connectionFor]), so the panel only explains.
      return HostPhasePanel(phase: c.phase, error: c.error, detail: c.detail, onRetry: c.retry, showRetry: false);
    }
    return _index == 0
        ? StatusScreen(status: status, agents: _agents)
        : SettingsScreen(controller: c, appearance: widget.appearance, agents: _agents);
  }
}
