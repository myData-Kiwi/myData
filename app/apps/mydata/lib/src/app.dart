import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'host_action.dart';
import 'setup_screen.dart';
import 'shell.dart';

/// The myData app: draws in the theme stored on the host and the mode stored on this device, and follows
/// both as they change (a theme picked in myAssistant arrives with the next status poll).
class MyDataApp extends StatefulWidget {
  const MyDataApp({super.key, required this.controller, this.openSetup = false, this.appearance, this.store});

  final HostController controller;

  /// Start on the Setup screen even if the host is ready (launched with --setup, e.g. by myAssistant).
  final bool openSetup;

  /// The theme and mode. Null builds one for [controller] (AppearanceController.forHost), owned by the app.
  final AppearanceController? appearance;

  /// Where this device's mode is kept, for the [AppearanceController] the app builds. Null is the shared
  /// device file every myData app reads ([deviceStore]); tests pass a MemoryDeviceStore.
  final DeviceStore? store;

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
        home: _Home(controller: widget.controller, appearance: _appearance, openSetup: widget.openSetup),
      );
    },
  );
}

/// Setup until the person moves on from it, then the Status and Settings shell.
class _Home extends StatefulWidget {
  const _Home({required this.controller, required this.appearance, required this.openSetup});

  final HostController controller;
  final AppearanceController appearance;
  final bool openSetup;

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

  HostController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onHost);
    _askAppearance();
    _decide();
  }

  @override
  void dispose() {
    _c.removeListener(_onHost);
    super.dispose();
  }

  void _onHost() {
    _askAppearance();
    setState(_decide);
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
    final a = assistantAvailability(s);
    _inSetup = _themeChosen == false || (a != AssistantAvailability.ready && a != AssistantAvailability.off);
  }

  void _leaveSetup() => setState(() => _inSetup = false);

  Future<void> _chooseTheme(String id) async {
    await widget.appearance.setTheme(id);
    if (mounted) setState(() => _themeChosen = true);
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
    if (_inSetup == false) return HomeShell(controller: _c, appearance: widget.appearance);
    // While the host's answer about the theme is on its way, keep showing the host being looked for, so
    // the assistant panel does not flash up before the theme step.
    final waiting = _c.phase == HostPhase.running && _themeChosen == null;
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
    );
  }
}
