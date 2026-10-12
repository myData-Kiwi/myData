import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'host_phase_panel.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

/// The myData app after setup: Status and Settings. If the host stops, its panel takes their place.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final HostController controller;

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
    appBar: const AppHeader(title: 'myData'),
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.monitor_heart_outlined), label: Text('Status')),
            NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _page()),
        ),
      ],
    ),
  );

  Widget _page() {
    final c = widget.controller;
    final status = c.status;
    if (c.phase != HostPhase.running || status == null) {
      return Center(
        child: SingleChildScrollView(
          child: HostPhasePanel(phase: c.phase, error: c.error, detail: c.detail, onRetry: c.retry),
        ),
      );
    }
    return _index == 0 ? StatusScreen(status: status, agents: _agents) : SettingsScreen(controller: c, agents: _agents);
  }
}
