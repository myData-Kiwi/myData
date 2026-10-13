import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'apps_section.dart';
import 'host_phase_panel.dart';
import 'settings_screen.dart';
import 'source_list.dart';
import 'status_screen.dart';

/// The myData app after setup: Status and Settings in the app frame. If the host stops, its panel takes
/// their place and the frame says the host cannot be reached.
///
/// A `mydata://settings/sources` link ([sourcesAsked] going up) opens Settings and scrolls to Sources.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.appearance,
    this.macSystem,
    this.installedApps,
    this.openApp,
    this.sourcesAsked = 0,
  });

  final HostController controller;
  final AppearanceController appearance;

  /// Opens System Settings from Settings, Sources; null is the real one.
  final MacSystem? macSystem;

  /// Which of the other apps are installed, for the Status screen; null looks them up on this Mac.
  final InstalledApps? installedApps;

  /// Opens an app; null uses [appLinks].
  final Future<bool> Function(MyDataAppId app)? openApp;

  /// How many times a link asked for Settings, Sources. Each rise opens it, including the one that came in
  /// before this shell was built (during setup).
  final int sourcesAsked;

  /// When opening an app failed.
  static String openFailed(MyDataAppId app) => 'myData could not open ${app.displayName}. Open it yourself.';

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
  late final InstalledApps _apps =
      widget.installedApps ?? InstalledApps(apps: AppsSection.listed);
  final _sourcesKey = GlobalKey();
  int _index = 0;
  int _sourcesShown = 0;

  static const _settings = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPoll);
    _agents.load();
    _sources.load();
    unawaited(_apps.start());
    if (widget.sourcesAsked > 0) unawaited(_showSources());
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (widget.sourcesAsked > _sourcesShown) unawaited(_showSources());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPoll);
    _agents.dispose();
    _sources.dispose();
    if (widget.installedApps == null) _apps.dispose();
    super.dispose();
  }

  // The agent list and the sources follow the controller's status polling, so "connected", the counts on
  // Status and the sources in Settings stay current (a permission answered in System Settings, a sync that
  // finished).
  void _onPoll() {
    if (widget.controller.phase != HostPhase.running) return;
    _agents.load();
    _sources.load();
  }

  /// Settings, scrolled to Sources (a `mydata://settings/sources` link). It scrolls once the sources have
  /// been read: before that the page is too short to bring them to the top.
  Future<void> _showSources() async {
    _sourcesShown = widget.sourcesAsked;
    setState(() => _index = _settings);
    await _sources.load();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _sourcesKey.currentContext;
      if (!mounted || target == null) return;
      unawaited(Scrollable.ensureVisible(target));
    });
  }

  Future<void> _openApp(MyDataAppId app) async {
    final open = widget.openApp ?? appLinks.openApp;
    final opened = await open(app).catchError((Object _) => false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(HomeShell.openFailed(app))));
    unawaited(_apps.refresh());
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
        ? StatusScreen(status: status, agents: _agents, apps: _apps, sources: _sources, onOpenApp: _openApp)
        : SettingsScreen(
            controller: c,
            appearance: widget.appearance,
            agents: _agents,
            sources: _sources,
            macSystem: widget.macSystem,
            sourcesKey: _sourcesKey,
          );
  }
}
