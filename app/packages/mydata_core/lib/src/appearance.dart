import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'host_controller.dart';
import 'platform.dart';

/// The theme and mode an app draws with (design/theming.md):
///
/// - the **theme** is stored on the host and is the same in every app; it arrives with every /status poll,
///   so a change made in one app reaches the others within one poll, without a restart;
/// - the **mode** (light, dark, match system) belongs to this device and is shared by the myData apps on it
///   through the [DeviceStore]; the file is re-read on the same interval, so a change in one app reaches the
///   others too.
///
/// The last theme seen is also kept on the device, so an app opened while the host is still starting draws
/// in the right theme instead of flashing the default.
class AppearanceController extends ChangeNotifier {
  AppearanceController({
    required this._hostChanges,
    required this._hostTheme,
    required this._putTheme,
    DeviceStore? store,
    this.pollInterval = const Duration(seconds: 2),
  }) : store = store ?? deviceStore;

  /// The usual wiring: the theme from [host]'s status, set with PUT /appearance.
  factory AppearanceController.forHost(HostController host, {DeviceStore? store, Duration? pollInterval}) =>
      AppearanceController(
        hostChanges: host,
        hostTheme: () => host.status?.theme,
        putTheme: (id) async {
          final conn = host.connection;
          if (conn == null) throw StateError('The host is not connected.');
          final out = await conn.appearance.setAppearance(AppearanceIn(theme: id));
          return out?.theme ?? id;
        },
        store: store,
        pollInterval: pollInterval ?? const Duration(seconds: 2),
      );

  final Listenable _hostChanges;
  final String? Function() _hostTheme;
  final Future<String> Function(String id) _putTheme;
  final DeviceStore store;
  final Duration pollInterval;

  String? _themeId;
  MyDataMode _mode = MyDataMode.system;
  Timer? _poll;
  bool _started = false;

  /// The host's theme id, the last one seen on this device, or null (the default theme) before either.
  String? get themeId => _themeId;
  MyDataMode get mode => _mode;
  MyDataTheme get theme => MyDataTheme.kiwi(_themeId, mode: _mode);

  /// Read this device's settings, then follow the host and the device file.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _readDevice();
    _hostChanges.addListener(_onHost);
    _onHost();
    _poll = Timer.periodic(pollInterval, (_) => _readDevice());
  }

  void _onHost() {
    final t = _hostTheme();
    if (t == null || t == _themeId) return;
    _themeId = t;
    notifyListeners();
    unawaited(_merge({'lastTheme': t}));
  }

  Future<void> _readDevice() async {
    final v = await store.read();
    var changed = false;
    final m = MyDataMode.parse(v['mode'] as String?);
    if (m != _mode) {
      _mode = m;
      changed = true;
    }
    final last = v['lastTheme'];
    if (_themeId == null && last is String) {
      _themeId = last;
      changed = true;
    }
    if (changed && _started) notifyListeners();
  }

  /// Merge into the device file, keeping what another app wrote there.
  Future<void> _merge(Map<String, Object?> changes) async => store.write({...await store.read(), ...changes});

  /// Light, dark or match system, for this device (every myData app on it follows).
  Future<void> setMode(MyDataMode mode) async {
    _mode = mode;
    notifyListeners();
    await _merge({'mode': mode.name});
  }

  /// Sets the theme on the host, for every app. Throws when the host refuses or cannot be reached; the
  /// theme on screen only changes once the host has it.
  Future<void> setTheme(String id) async {
    final stored = await _putTheme(id);
    _themeId = stored;
    notifyListeners();
    await _merge({'lastTheme': stored});
  }

  @override
  void dispose() {
    _poll?.cancel();
    if (_started) _hostChanges.removeListener(_onHost);
    super.dispose();
  }
}
