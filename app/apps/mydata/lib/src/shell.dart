import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'host_phase_panel.dart';
import 'settings_screen.dart';
import 'source_list.dart';
import 'status_screen.dart';

/// The myData app after setup: Status and Settings in the app frame. If the host stops, its panel takes
/// their place and the frame says the host cannot be reached.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.appearance, this.macSystem});

  final HostController controller;
  final AppearanceController appearance;

  /// Opens System Settings from Settings, Sources; null is the real one.
  final MacSystem? macSystem;

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
  late final _sources = SourceList(widget.controller);
  int _index = 0;

  static const _settings = 1;

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
    _sources.dispose();
    super.dispose();
  }

  // The agent list follows the controller's status polling, so "connected" stays current; so do the
  // sources while Settings shows them (a permission answered in System Settings, a sync that finished).
  void _onPoll() {
    if (widget.controller.phase != HostPhase.running) return;
    _agents.load();
    if (_index == _settings) _sources.load();
  }

  void _select(int i) {
    setState(() => _index = i);
    if (i == _settings) _sources.load();
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
          onSelect: _select,
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
        : SettingsScreen(
            controller: c,
            appearance: widget.appearance,
            agents: _agents,
            sources: _sources,
            macSystem: widget.macSystem,
          );
  }
}
