import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'apps_section.dart';
import 'host_phase_panel.dart';
import 'import/import_controller.dart';
import 'import/import_files.dart';
import 'import/import_page.dart';
import 'mac_status.dart';
import 'settings_screen.dart';
import 'source_list.dart';
import 'status_screen.dart';

/// The myData app after setup: Status, Import and Settings in the app frame. If the host stops, its panel
/// takes the place of Status and Settings and the frame says the host cannot be reached; Import stays, with
/// its file and account buttons disabled and the history as last read (design/components/ImportFlow).
///
/// A `mydata://settings/sources` link ([sourcesAsked] going up) opens Settings and scrolls to Sources; a
/// `mydata://import/contacts` link ([importAsked]) opens Import.
///
/// The menu bar (macOS; the same keys with Control elsewhere): File, Import…; View, Status ⌘1, Import ⌘2,
/// Settings ⌘3, Theme… (the gallery with every app); Settings… ⌘, in the app menu (design/platforms.md).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.themes,
    this.macSystem,
    this.installedApps,
    this.openApp,
    this.sourcesAsked = 0,
    this.importAsked = 0,
    this.openLink,
    this.chooser,
    this.acceptDrops = true,
  });

  final HostController controller;
  final ThemeController themes;

  /// Opens System Settings from Settings, Sources; null is the real one.
  final MacSystem? macSystem;

  /// Which of the other apps are installed, for the Status screen; null looks them up on this Mac.
  final InstalledApps? installedApps;

  /// Opens an app; null uses [appLinks].
  final Future<bool> Function(MyDataAppId app)? openApp;

  /// How many times a link asked for Settings, Sources. Each rise opens it, including the one that came in
  /// before this shell was built (during setup).
  final int sourcesAsked;

  /// How many times a link asked for Import (`mydata://import/contacts`).
  final int importAsked;

  /// Opens a link in another app ("Open in myContacts"); null uses [appLinks].
  final Future<bool> Function(MyDataLink link)? openLink;

  /// The system's file chooser; null is the real one. Tests pass a fake.
  final FileChooser? chooser;

  /// Takes files dropped on the Import page (off in tests).
  final bool acceptDrops;

  /// When opening an app failed.
  static String openFailed(MyDataAppId app) => 'myData could not open ${app.displayName}. Open it yourself.';

  static const sections = [
    AppSection(icon: MyDataIcon.status, label: 'Status'),
    AppSection(icon: MyDataIcon.importFile, label: 'Import'),
    AppSection(icon: MyDataIcon.settings, label: 'Settings'),
  ];

  /// The sections as the Mac frame's sidebar shows them, with its icons (Lucide, in place of SF Symbols).
  static const macSections = [
    AppSection(icon: MyDataIcon.status, label: 'Status'),
    AppSection(icon: MyDataIcon.importFile, label: 'Import'),
    AppSection(icon: MyDataIcon.settings, label: 'Settings'),
  ];

  /// The sections' names in the menu bar's View menu, in its title case.
  static const menuTitles = ['Status', 'Import', 'Settings'];

  /// File, Import… in the menu bar.
  static const importMenuItem = 'Import…';

  /// What the frame says about the host in [phase]. This is myData, so there is no "Open myData" link.
  static AppConnection connectionFor(HostPhase phase, VoidCallback onRetry) => switch (phase) {
    HostPhase.running => const AppConnection.connected(),
    HostPhase.checking || HostPhase.starting || HostPhase.restarting => const AppConnection.starting(),
    HostPhase.lost ||
    HostPhase.failedToStart ||
    HostPhase.unreachable ||
    HostPhase.refused ||
    HostPhase.incompatible ||
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
  late final _import = ImportController(host: widget.controller, sources: _sources, chooser: widget.chooser);
  final _sourcesKey = GlobalKey();
  int _index = 0;

  /// The Mac frame's Settings tab.
  SettingsTab _settingsTab = SettingsTab.sources;
  int _sourcesShown = 0;
  int _importShown = 0;

  static const _status = 0;
  static const _importSection = 1;
  static const _settings = 2;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPoll);
    _agents.load();
    _sources.load();
    unawaited(_apps.start());
    if (widget.sourcesAsked > 0) unawaited(_showSources());
    if (widget.importAsked > 0) _showImport();
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (widget.sourcesAsked > _sourcesShown) unawaited(_showSources());
    if (widget.importAsked > _importShown) _showImport();
  }

  /// Import, from a `mydata://import/contacts` link: Choose, unless an import is in Review or Importing.
  void _showImport() {
    _importShown = widget.importAsked;
    _import.openFromLink();
    setState(() => _index = _importSection);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPoll);
    _agents.dispose();
    _sources.dispose();
    _import.dispose();
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
    setState(() {
      _index = _settings;
      _settingsTab = SettingsTab.sources;
    });
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
    if (i == _settings || i == _importSection) _sources.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => AppMenuBar(
      appName: 'myData',
      file: [AppMenuItem(title: HomeShell.importMenuItem, onSelected: () => _select(_importSection))],
      view: [
        for (var i = 0; i < HomeShell.menuTitles.length; i++)
          AppMenuItem(
            title: HomeShell.menuTitles[i],
            shortcut: AppMenuBar.sectionShortcut(i + 1),
            onSelected: () => _select(i),
          ),
      ],
      onSettings: () => _select(_settings),
      onTheme: () => showAppThemeGallery(context, choosingFor: MyDataAppId.values),
      child: MacWindow.of(context)
          // Transparent: the window's sidebar material shows through the sidebar.
          ? Scaffold(
              backgroundColor: Colors.transparent,
              body: MacAppFrame(
                sections: HomeShell.macSections,
                current: _index,
                onSelect: _select,
                connection: HomeShell.connectionFor(widget.controller.phase, widget.controller.retry),
                // The page says what is wrong, with the one Retry, so the sidebar does not say it again.
                showConnection: !_macPageShowsHost,
                child: _macPage(),
              ),
            )
          : Scaffold(
        backgroundColor: context.colors.bg,
        body: AppFrame(
          appName: 'myData',
          sections: HomeShell.sections,
          current: _index,
          onSelect: _select,
          connection: HomeShell.connectionFor(widget.controller.phase, widget.controller.retry),
          child: _page(),
        ),
      ),
    ),
  );

  /// Settings, Sources, from Status (demo mode's "Use your Mac's data").
  void _openSources() => setState(() {
    _index = _settings;
    _settingsTab = SettingsTab.sources;
    _sources.load();
  });

  /// The Mac page is the host's state panel (the host is not running and nothing else can be shown).
  bool get _macPageShowsHost {
    final c = widget.controller;
    final keepsImport = _index == _importSection && (c.status != null || c.phase == HostPhase.running);
    return !keepsImport && (c.phase != HostPhase.running || c.status == null);
  }

  /// The Mac frame: each section in its pane under its toolbar band. Settings has its tabs in the band, as an
  /// app's Settings window has; Status is a calm overview with the details folded away.
  Widget _macPage() {
    final c = widget.controller;
    final status = c.status;
    final title = HomeShell.macSections[_index].label;
    if (_index == _importSection && (status != null || c.phase == HostPhase.running)) {
      return MacPane(toolbar: MacToolbar(title: title), child: Builder(builder: (context) => _macGroups(context, _page())));
    }
    if (c.phase != HostPhase.running || status == null) {
      return MacPane(
        toolbar: MacToolbar(title: title),
        child: HostPhasePanel(phase: c.phase, error: c.error, detail: c.detail, onRetry: c.retry),
      );
    }
    if (_index == _status) {
      return MacPane(
        toolbar: MacToolbar(title: title),
        child: MacStatusView(
          status: status,
          agents: _agents,
          apps: _apps,
          sources: _sources,
          onOpenApp: _openApp,
          onOpenSources: _openSources,
        ),
      );
    }
    return MacPane(
      toolbar: MacToolbar(
        leading: [
          Expanded(
            child: Center(
              child: MacSegmented<SettingsTab>(
                toolbar: true,
                semanticLabel: 'Settings',
                segments: [for (final t in SettingsTab.values) (t, t.label)],
                selected: _settingsTab,
                onChanged: (t) {
                  setState(() => _settingsTab = t);
                  if (t == SettingsTab.sources) _sources.load();
                },
              ),
            ),
          ),
        ],
      ),
      child: MacSettingsView(
        key: ValueKey(_settingsTab),
        tab: _settingsTab,
        controller: c,
        themes: widget.themes,
        agents: _agents,
        sources: _sources,
        macSystem: widget.macSystem,
      ),
    );
  }

  /// Import's groups drawn as the Mac's grouped forms: the form's faint fill and no shadow
  /// ([MacFormSection.fill]), lines in the system's separator, sunken wells and tiles on `quaternary-label`.
  static Widget _macGroups(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final mac = context.mac;
    final colors = context.colors.copyWith(
      surface: MacFormSection.fill(context),
      surfaceSunken: Color.alphaBlend(mac.quaternaryLabel, mac.contentBackground),
      line: mac.separator,
    );
    final shadows = context.shadows.copyWith(shadow1: const []);
    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final e in theme.extensions.values)
            if (e is MyDataColors)
              colors
            else if (e is MyDataShadows)
              shadows
            else
              e,
        ],
      ),
      child: child,
    );
  }

  Widget _page() {
    final c = widget.controller;
    final status = c.status;
    // Import stays when the host stops: its buttons say why they wait, and the history shows what was read.
    if (_index == _importSection && (status != null || c.phase == HostPhase.running)) {
      return ImportPage(
        key: const ValueKey('import'),
        controller: _import,
        sources: _sources,
        installedApps: _apps,
        openLink: widget.openLink ?? appLinks.openLink,
        macHost: status?.macAvailable ?? false,
        acceptDrops: widget.acceptDrops,
        demo: status?.mode == StatusOutModeEnum.demo,
      );
    }
    if (c.phase != HostPhase.running || status == null) {
      // The frame's connection line carries the Retry ([connectionFor]), so the panel only explains.
      return HostPhasePanel(phase: c.phase, error: c.error, detail: c.detail, onRetry: c.retry, showRetry: false);
    }
    return _index == _status
        ? StatusScreen(status: status, agents: _agents, apps: _apps, sources: _sources, onOpenApp: _openApp)
        : SettingsScreen(
            controller: c,
            themes: widget.themes,
            agents: _agents,
            sources: _sources,
            macSystem: widget.macSystem,
            sourcesKey: _sourcesKey,
          );
  }
}
