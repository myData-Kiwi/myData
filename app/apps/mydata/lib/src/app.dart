import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'format.dart';
import 'host_action.dart';
import 'setup_screen.dart';
import 'source_list.dart';
import 'shell.dart';

/// The myData app: draws in the theme stored on the host and the mode stored on this device, and follows
/// both as they change (a theme picked in myAssistant arrives with the next status poll).
class MyDataApp extends StatefulWidget {
  const MyDataApp({
    super.key,
    required this.controller,
    this.openSetup = false,
    this.appearance,
    this.store,
    this.macSystem,
    this.links,
    this.installedApps,
    this.openApp,
  });

  final HostController controller;

  /// Start on the Setup screen even if the host is ready (launched with --setup, e.g. by myAssistant).
  final bool openSetup;

  /// The theme and mode. Null builds one for [controller] (AppearanceController.forHost), owned by the app.
  final AppearanceController? appearance;

  /// Where this device's mode is kept, for the [AppearanceController] the app builds. Null is the shared
  /// device file every myData app reads ([deviceStore]); tests pass a MemoryDeviceStore.
  final DeviceStore? store;

  /// The reader helper's path and System Settings. Null is the real one ([macSystem]); tests pass a fake.
  final MacSystem? macSystem;

  /// Links other apps opened myData with ([IncomingLinks.links]); `mydata://settings/sources` opens
  /// Settings at Sources. Null: none arrive.
  final Stream<MyDataLink>? links;

  /// Which of the other apps are installed, for the Status screen; null looks them up on this Mac.
  final InstalledApps? installedApps;

  /// Opens an app from the Status screen; null uses [appLinks]. Tests pass a fake.
  final Future<bool> Function(MyDataAppId app)? openApp;

  @override
  State<MyDataApp> createState() => _MyDataAppState();
}

class _MyDataAppState extends State<MyDataApp> {
  late final AppearanceController _appearance =
      widget.appearance ?? AppearanceController.forHost(widget.controller, store: widget.store ?? deviceStore);

  @override
  void initState() {
    super.initState();
    unawaited(_appearance.start());
  }

  @override
  void dispose() {
    if (widget.appearance == null) _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _appearance,
    builder: (context, _) {
      final theme = _appearance.theme;
      return MaterialApp(
        title: 'myData',
        theme: theme.light,
        darkTheme: theme.dark,
        themeMode: theme.themeMode,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MyDataAccessibilityScope(child: child ?? const SizedBox.shrink()),
        home: _Home(
          controller: widget.controller,
          appearance: _appearance,
          openSetup: widget.openSetup,
          mac: widget.macSystem ?? macSystem,
          links: widget.links,
          installedApps: widget.installedApps,
          openApp: widget.openApp,
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
    required this.appearance,
    required this.openSetup,
    required this.mac,
    this.links,
    this.installedApps,
    this.openApp,
  });

  final HostController controller;
  final AppearanceController appearance;
  final bool openSetup;
  final MacSystem mac;
  final Stream<MyDataLink>? links;
  final InstalledApps? installedApps;
  final Future<bool> Function(MyDataAppId app)? openApp;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  /// Null until the host first answers (and its appearance is known), unless setup was asked for.
  late bool? _inSetup = widget.openSetup ? true : null;

  /// Whether the host has a chosen theme (GET /appearance). Null until it has answered once; a failed
  /// read counts as chosen, so the theme step never blocks setup.
  bool? _themeChosen;
  bool _askedAppearance = false;

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
  StreamSubscription<MyDataLink>? _links;

  HostController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _links = widget.links?.listen(_onLink);
    _c.addListener(_onHost);
    _askAppearance();
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
  }

  void _onHost() {
    _askAppearance();
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

  /// Once the host runs, ask it once whether a theme was ever chosen.
  void _askAppearance() {
    final connection = _c.connection;
    if (_askedAppearance || _c.phase != HostPhase.running || connection == null) return;
    _askedAppearance = true;
    unawaited(() async {
      bool chosen;
      try {
        final out = await connection.appearance.appearance().timeout(const Duration(seconds: 5));
        chosen = out?.chosen ?? true;
      } on Object {
        chosen = true;
      }
      if (!mounted) return;
      setState(() {
        _themeChosen = chosen;
        _decide();
      });
    }());
  }

  /// Setup is skipped at launch when there is nothing to ask or wait for: the theme was chosen before and
  /// the assistant is ready, or switched off.
  void _decide() {
    final s = _c.status;
    if (_inSetup != null || _c.phase != HostPhase.running || s == null || _themeChosen == null) return;
    if (_macDecided == null) return;
    final a = assistantAvailability(s);
    _inSetup =
        _themeChosen == false ||
        _macDecided == false ||
        (a != AssistantAvailability.ready && a != AssistantAvailability.off);
  }

  void _leaveSetup() => setState(() => _inSetup = false);

  Future<void> _chooseTheme(String id) async {
    await widget.appearance.setTheme(id);
    if (mounted) setState(() => _themeChosen = true);
  }

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
    if (short == null && mounted) setState(() => _macDecided = true);
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
    if (mounted) setState(() => _macDecided = true);
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
        appearance: widget.appearance,
        macSystem: widget.mac,
        installedApps: widget.installedApps,
        openApp: widget.openApp,
        sourcesAsked: _sourcesAsked,
      );
    }
    // While the host's answers about the theme and This Mac are on their way, keep showing the host being
    // looked for, so the assistant panel does not flash up before those steps.
    final waiting = _c.phase == HostPhase.running && (_themeChosen == null || _macDecided == null);
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
      themeChosen: _themeChosen ?? true,
      onChooseTheme: _chooseTheme,
      macStep: _macDecided == false,
      onAllowMac: _allowMac,
      onSkipMac: _skipMac,
      onMacDone: () => setState(() => _macDecided = true),
      onOpenMacSettings: (pane) => widget.mac.open(pane),
    );
  }
}
