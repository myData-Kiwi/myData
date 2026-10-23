import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'format.dart';
import 'host_action.dart';
import 'import/import_files.dart';
import 'setup_screen.dart';
import 'source_list.dart';
import 'shell.dart';

/// The myData app: draws in its own theme on this device (else the one chosen for every app, else System)
/// and this device's mode, and follows both as they change, here or in another app.
class MyDataApp extends StatefulWidget {
  const MyDataApp({
    super.key,
    required this.controller,
    this.openSetup = false,
    this.themes,
    this.store,
    this.macSystem,
    this.links,
    this.installedApps,
    this.openApp,
    this.openLink,
    this.chooser,
    this.acceptDrops = true,
  });

  final HostController controller;

  /// Opens a link in another app (Import's "Open in myContacts"); null uses [appLinks]. Tests pass a fake.
  final Future<bool> Function(MyDataLink link)? openLink;

  /// The system's file chooser for Import; null is the real one. Tests pass a fake.
  final FileChooser? chooser;

  /// Takes files dropped on the Import page (off in tests, which have no drag and drop).
  final bool acceptDrops;

  /// Start on the Setup screen even if the host is ready (launched with --setup, e.g. by myAssistant).
  final bool openSetup;

  /// The themes and mode. Null builds one for [controller] (ThemeController.forHost), owned by the app.
  final ThemeController? themes;

  /// Where this device's themes and mode are kept, for the [ThemeController] the app builds. Null is the
  /// shared device file every myData app reads ([deviceStore]); tests pass a MemoryDeviceStore.
  final DeviceStore? store;

  /// The reader helper's path and System Settings. Null is the real one ([macSystem]); tests pass a fake.
  final MacSystem? macSystem;

  /// Links other apps opened myData with ([IncomingLinks.links]); `mydata://settings/sources` opens
  /// Settings at Sources, `mydata://import/contacts` opens Import. Null: none arrive.
  final Stream<MyDataLink>? links;

  /// Which of the other apps are installed, for the Status screen; null looks them up on this Mac.
  final InstalledApps? installedApps;

  /// Opens an app from the Status screen; null uses [appLinks]. Tests pass a fake.
  final Future<bool> Function(MyDataAppId app)? openApp;

  @override
  State<MyDataApp> createState() => _MyDataAppState();
}

class _MyDataAppState extends State<MyDataApp> {
  late final ThemeController _themes =
      widget.themes ??
      ThemeController.forHost(MyDataAppId.mydata, widget.controller, store: widget.store ?? deviceStore);

  @override
  void initState() {
    super.initState();
    unawaited(_themes.start());
  }

  @override
  void dispose() {
    if (widget.themes == null) _themes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _themes,
    builder: (context, _) {
      // System is the Mac shell on a Mac (the system's font, colours and accent); a drawn theme draws inside
      // the Mac window there (MacShell).
      return ThemeScope(
        themes: _themes,
        app: MyDataAppId.mydata,
        child: MacShell(
          theme: _themes.theme,
          appIcon: MyDataAppIcons.mydata,
          builder: (context, light, dark, mode) => MaterialApp(
            title: 'myData',
            theme: light,
            darkTheme: dark,
            themeMode: mode,
            debugShowCheckedModeBanner: false,
            builder: MacShell.content,
            home: _Home(
              controller: widget.controller,
              themes: _themes,
              openSetup: widget.openSetup,
              mac: widget.macSystem ?? macSystem,
              links: widget.links,
              installedApps: widget.installedApps,
              openApp: widget.openApp,
              openLink: widget.openLink,
              chooser: widget.chooser,
              acceptDrops: widget.acceptDrops,
            ),
          ),
        ),
      );
    },
  );
}

/// Setup until the person moves on from it, then the Status and Settings shell. A link to Settings, Sources
/// that arrives during setup waits until setup is done.
class _Home extends StatefulWidget {
  const _Home({
    required this.controller,
    required this.themes,
    required this.openSetup,
    required this.mac,
    this.links,
    this.installedApps,
    this.openApp,
    this.openLink,
    this.chooser,
    this.acceptDrops = true,
  });

  final HostController controller;
  final ThemeController themes;
  final Future<bool> Function(MyDataLink link)? openLink;
  final FileChooser? chooser;
  final bool acceptDrops;
  final bool openSetup;
  final MacSystem mac;
  final Stream<MyDataLink>? links;
  final InstalledApps? installedApps;
  final Future<bool> Function(MyDataAppId app)? openApp;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  /// Null until the host first answers, unless setup was asked for.
  late bool? _inSetup = widget.openSetup ? true : null;

  /// Whether This Mac was ever turned on or off (GET /sources `decided`), so its first-run step is not
  /// needed. Null until known; true on a host that is not a Mac, and when the host could not say, so the
  /// step never blocks setup.
  bool? _macDecided;
  bool _askedMac = false;

  /// The host's uptime at the last poll after the reader helper's path was reported; null until a report
  /// has succeeded (and again after one failed, so the next poll tries again).
  num? _readerUptime;
  bool _reportingReader = false;

  /// How many times a link asked for Settings, Sources ([HomeShell.sourcesAsked]).
  int _sourcesAsked = 0;

  /// How many times a link asked for Import ([HomeShell.importAsked]).
  int _importAsked = 0;
  StreamSubscription<MyDataLink>? _links;

  HostController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _links = widget.links?.listen(_onLink);
    _c.addListener(_onHost);
    _askMac();
    _reportReader();
    _decide();
  }

  @override
  void dispose() {
    _links?.cancel();
    _c.removeListener(_onHost);
    super.dispose();
  }

  void _onLink(MyDataLink link) {
    if (link is OpenMyDataSources) setState(() => _sourcesAsked++);
    if (link is OpenMyDataImport) setState(() => _importAsked++);
  }

  void _onHost() {
    _askMac();
    _reportReader();
    setState(_decide);
  }

  /// Once the host runs, ask it once whether This Mac's first-run question was answered.
  void _askMac() {
    final connection = _c.connection;
    final s = _c.status;
    if (_askedMac || _c.phase != HostPhase.running || connection == null || s == null) return;
    _askedMac = true;
    if (!s.macAvailable) {
      _macDecided = true;
      return;
    }
    unawaited(() async {
      bool decided;
      try {
        final out = await connection.sources.sources().timeout(const Duration(seconds: 5));
        final mac = out?.sources.where((x) => x.kind == SourceOutKindEnum.mac).firstOrNull;
        decided = mac == null || (mac.decided ?? true);
      } on Object {
        decided = true;
      }
      if (!mounted) return;
      setState(() {
        _macDecided = decided;
        _decide();
      });
    }());
  }

  /// On a Mac host, tell the host where this app's reader helper is (PUT /sources/mac/reader) at this
  /// app's start and again whenever the host restarts (its uptime goes back): the host starts the helper
  /// from there. Nothing to say when this is not macOS, or this build has no helper (one made before it
  /// existed).
  void _reportReader() {
    final connection = _c.connection;
    final s = _c.status;
    if (_c.phase != HostPhase.running || connection == null || s == null || !s.macAvailable) return;
    if (_reportingReader) return;
    final last = _readerUptime;
    if (last != null && s.uptimeSeconds >= last) {
      _readerUptime = s.uptimeSeconds; // the same host run: already told
      return;
    }
    final path = widget.mac.readerHelperPath();
    if (path == null) return;
    _reportingReader = true;
    final uptime = s.uptimeSeconds;
    unawaited(() async {
      try {
        await connection.sources.setMacReader(ReaderIn(path: path));
        _readerUptime = uptime;
      } on Object catch (e) {
        _readerUptime = null; // try again at the next poll
        debugPrint('myData: the host did not take the reader path: ${errorText(e)}');
      } finally {
        _reportingReader = false;
      }
    }());
  }

  /// Setup is skipped at launch when there is nothing to ask or wait for: This Mac's question was answered
  /// and the assistant is ready, or switched off. Themes are not part of first run: System is the default
  /// (design/themes/ARCHITECTURE.md 4.3).
  void _decide() {
    final s = _c.status;
    if (_inSetup != null || _c.phase != HostPhase.running || s == null) return;
    if (_macDecided == null) return;
    final a = assistantAvailability(s);
    _inSetup = _macDecided == false || (a != AssistantAvailability.ready && a != AssistantAvailability.off);
  }

  void _leaveSetup() => setState(() => _inSetup = false);

  /// This Mac's first-run Allow: turn it on with everything included, then ask for contacts, then
  /// calendars. Each request-access waits while the person answers the system's prompt. Moves on when both
  /// may be read; otherwise returns what is missing, and the step says so.
  Future<MacAccessShortfall?> _allowMac() async {
    final c = _c.connection;
    if (c == null) throw StateError('The host is not connected.');
    await c.sources.configureMac(MacChoice.turn(on: true));
    await c.sources.requestMacAccess(AccessIn(what: AccessInWhatEnum.contacts));
    final out = await c.sources.requestMacAccess(AccessIn(what: AccessInWhatEnum.calendars));
    final short = ThisMacStep.shortfall(out?.contactsStatus, out?.calendarsStatus);
    if (short == null && mounted) setState(_macDone);
    return short;
  }

  /// This Mac's first-run Skip: leave it off, which records the choice on the host.
  Future<void> _skipMac() async {
    try {
      await _c.connection?.sources.configureMac(MacChoice.turn(on: false));
    } on Object catch (e) {
      // Setup moves on regardless; the question comes back at the next start.
      debugPrint('myData: could not record skipping This Mac: ${errorText(e)}');
    }
    if (mounted) setState(_macDone);
  }

  /// This Mac's question is answered. On a Mac that is the whole first launch: unless the assistant still
  /// needs something (its model on its way, Ollama missing, an error), myData opens at Status.
  void _macDone() {
    _macDecided = true;
    final s = _c.status;
    if (!MacLook.forThisPlatform || s == null) return;
    final a = assistantAvailability(s);
    if (a == AssistantAvailability.ready || a == AssistantAvailability.off) _inSetup = false;
  }

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
    if (_inSetup == false) {
      return HomeShell(
        controller: _c,
        themes: widget.themes,
        macSystem: widget.mac,
        installedApps: widget.installedApps,
        openApp: widget.openApp,
        sourcesAsked: _sourcesAsked,
        importAsked: _importAsked,
        openLink: widget.openLink,
        chooser: widget.chooser,
        acceptDrops: widget.acceptDrops,
      );
    }
    // While the host's answer about This Mac is on its way, keep showing the host being looked for, so the
    // assistant panel does not flash up before that step.
    final waiting = _c.phase == HostPhase.running && _macDecided == null;
    return SetupScreen(
      phase: waiting ? HostPhase.checking : _c.phase,
      status: _c.status,
      error: _c.error,
      detail: _c.detail,
      onRetryHost: _c.retry,
      onRetryModel: _retryModel,
      onSkip: _skip,
      onContinue: _leaveSetup,
      onSwitchOn: _switchOn,
      macStep: _macDecided == false,
      onAllowMac: _allowMac,
      onSkipMac: _skipMac,
      onMacDone: () => setState(_macDone),
      onOpenMacSettings: (pane) => widget.mac.open(pane),
    );
  }
}
