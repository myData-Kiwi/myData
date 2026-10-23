import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'host_controller.dart';
import 'links.dart';
import 'platform.dart';

/// The `themes` key of this device's settings (design/themes/ARCHITECTURE.md 4.1):
///
/// ```json
/// "themes": {
///   "everywhere": { "theme": "mydata.kiwi", "palette": "plum" },
///   "apps": { "mycontacts": { "theme": "mydata.system" } }
/// }
/// ```
///
/// An app draws its own choice ([apps]), else [everywhere], else System ([choiceFor]).
@immutable
class ThemeSettings {
  const ThemeSettings({this.everywhere, this.apps = const {}});

  /// The settings key.
  static const key = 'themes';

  final ThemeChoice? everywhere;

  /// Each app's own choice, by its id ([MyDataAppId.name]: `mycontacts`).
  final Map<String, ThemeChoice> apps;

  /// What [app] draws: its own choice, else the everywhere one, else System.
  ThemeChoice choiceFor(String app) => apps[app] ?? everywhere ?? ThemeChoice.system;

  /// Whether [app] follows the everywhere choice (it has none of its own).
  bool followsEverywhere(String app) => !apps.containsKey(app);

  /// The settings in [value] (the `themes` key's value); null when there is none, which means this device
  /// has not been migrated from the host's theme yet. Entries that are not choices are skipped.
  static ThemeSettings? fromJson(Object? value) {
    if (value is! Map) return null;
    final apps = value['apps'];
    return ThemeSettings(
      everywhere: ThemeChoice.fromJson(value['everywhere']),
      apps: {
        if (apps is Map)
          for (final e in apps.entries)
            if (e.key is String) e.key as String: ?ThemeChoice.fromJson(e.value),
      },
    );
  }

  /// As written. A palette on a theme without palettes (System) is never written ([_written]).
  Map<String, Object?> toJson() => {
    'everywhere': ?_written(everywhere)?.toJson(),
    if (apps.isNotEmpty) 'apps': {for (final e in apps.entries) e.key: _written(e.value)!.toJson()},
  };

  /// [c] without a palette when its theme has none (a hand-edited file, an older writer). A theme this
  /// build does not know (a custom theme from a later version) is written as it was.
  static ThemeChoice? _written(ThemeChoice? c) {
    if (c == null) return null;
    final theme = ThemeLibrary.byId(c.theme);
    return theme != null && theme.palettes.isEmpty ? ThemeChoice(c.theme) : c;
  }

  ThemeSettings copyWith({ThemeChoice? everywhere, Map<String, ThemeChoice>? apps}) =>
      ThemeSettings(everywhere: everywhere ?? this.everywhere, apps: apps ?? this.apps);

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings && other.everywhere == everywhere && mapEquals(other.apps, apps);

  @override
  int get hashCode => Object.hash(everywhere, Object.hashAllUnordered(apps.entries.map((e) => (e.key, e.value))));
}

/// The theme and mode one app draws with (design/themes/ARCHITECTURE.md 4.1 and 4.2):
///
/// - **The theme** is chosen per app and per device ([ThemeSettings] in this device's settings file, shared
///   by every myData app on it, never synced): the app's own choice, else "everywhere", else System.
/// - **The mode** (light, dark, match system) is one per device for every app.
/// - Another app's change (myData's Appearance, Use everywhere in a gallery) arrives through the store's
///   [DeviceStore.changes] and, where those are not promised, the [pollInterval] read.
/// - **Preview** ([preview]) draws a choice without storing it, while the gallery is open; [use],
///   [useEverywhere] or `preview(null)` end it.
/// - **Migration**, once per device, when the file has no `themes` key (ARCHITECTURE.md 4.2): on macOS every
///   app starts on System (the Mac shell already ignored the host's theme, so nothing on screen changes);
///   elsewhere "everywhere" is seeded with the theme the host gave the apps as Kiwi in that palette
///   ([ThemeLibrary.fromColour]: `plum` is Kiwi, Plum), which is exactly what was drawn. The device's
///   `lastTheme` is read first: the old controller wrote the host's theme there at every poll, so it is the
///   host's theme without waiting for the host (an app opened while the host starts draws it at once, as
///   before). Without it, the host's deprecated status `theme` is read once it answers; until then System
///   is drawn (Kiwi in its own colour off a Mac), as the old controller drew Kiwi before the host answered.
class ThemeController extends ChangeNotifier {
  ThemeController({
    required this.appId,
    DeviceStore? store,
    this.pollInterval = const Duration(seconds: 2),
    this._hostChanges,
    String? Function()? hostTheme,
    bool Function()? hostAnswered,
    bool? macOS,
  }) : store = store ?? deviceStore,
       _hostTheme = hostTheme ?? _none,
       _hostAnswered = hostAnswered ?? _never,
       _macOS = macOS ?? MacLook.forThisPlatform;

  /// The usual wiring for [app]: the host's deprecated status `theme` only for migrating this device.
  factory ThemeController.forHost(
    MyDataAppId app,
    HostController host, {
    DeviceStore? store,
    Duration? pollInterval,
    bool? macOS,
  }) => ThemeController(
    appId: app.name,
    store: store,
    pollInterval: pollInterval ?? const Duration(seconds: 2),
    hostChanges: host,
    // ignore: deprecated_member_use
    hostTheme: () => host.status?.theme,
    hostAnswered: () => host.status != null,
    macOS: macOS,
  );

  static String? _none() => null;
  static bool _never() => false;

  /// This app's id in the settings ([MyDataAppId.name]).
  final String appId;
  final DeviceStore store;
  final Duration pollInterval;
  final Listenable? _hostChanges;
  final String? Function() _hostTheme;
  final bool Function() _hostAnswered;
  final bool _macOS;

  MyDataMode _mode = MyDataMode.system;
  ThemeSettings _settings = const ThemeSettings();
  bool _migrated = false;
  ThemeChoice? _preview;
  Timer? _poll;
  StreamSubscription<void>? _changes;
  bool _started = false;
  bool _disposed = false;

  /// Counts reads and writes: a read that finishes after a later one started (a poll in flight while this
  /// app writes) is dropped, so the window never flicks back to what the file held before.
  int _generation = 0;

  MyDataMode get mode => _mode;

  /// Every app's choices on this device.
  ThemeSettings get settings => _settings;

  /// Whether this device's settings have their `themes` key (migrated from the host's theme).
  bool get migrated => _migrated;

  /// What this app has stored: its own choice, else everywhere's, else System.
  ThemeChoice get stored => _settings.choiceFor(appId);

  /// The choice the gallery is previewing, or null.
  ThemeChoice? get previewing => _preview;

  /// What this app draws now: the preview, else [stored].
  ThemeChoice get choice => _preview ?? stored;

  MyDataTheme get theme => MyDataTheme(choice: choice, mode: _mode);

  /// Read this device's settings (migrating them once), then follow them.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _readDevice();
    _hostChanges?.addListener(_onHost);
    _changes = store.changes.listen((_) => unawaited(_readDevice()));
    _poll = Timer.periodic(pollInterval, (_) => unawaited(_readDevice()));
  }

  void _onHost() {
    if (!_migrated) unawaited(_readDevice());
  }

  Future<void> _readDevice() async {
    final generation = ++_generation;
    var v = await store.read();
    if (_disposed || generation != _generation) return;
    if (v[ThemeSettings.key] == null) {
      final seed = _seed(v);
      if (seed != null) {
        v = await store.update(
          (now) => now[ThemeSettings.key] == null
              ? {...now, ThemeSettings.key: ThemeSettings(everywhere: seed).toJson()}
              : now,
        );
        if (_disposed || generation != _generation) return;
      }
    }
    _apply(v);
  }

  /// The everywhere choice a device that has none starts with, or null while it cannot be known yet.
  ThemeChoice? _seed(Map<String, Object?> v) {
    if (_macOS) return ThemeChoice.system;
    final last = v['lastTheme'];
    final fromDevice = ThemeLibrary.fromColour(last is String ? last : null);
    if (fromDevice != null) return fromDevice;
    if (!_hostAnswered()) return null;
    return ThemeLibrary.fromColour(_hostTheme()) ?? ThemeChoice.system;
  }

  void _apply(Map<String, Object?> v) {
    var changed = false;
    final m = MyDataMode.parse(v['mode'] as String?);
    if (m != _mode) {
      _mode = m;
      changed = true;
    }
    final parsed = ThemeSettings.fromJson(v[ThemeSettings.key]);
    final s = parsed ?? const ThemeSettings();
    if (s != _settings) {
      _settings = s;
      changed = true;
    }
    final migrated = parsed != null;
    if (migrated != _migrated) {
      _migrated = migrated;
      changed = true;
    }
    if (changed && _started && !_disposed) notifyListeners();
  }

  /// Writes [change] of the stored settings, keeping what other apps wrote meanwhile, and draws the result.
  /// Returns the settings [change] was given (what the file held just before), for an undo.
  Future<ThemeSettings> _change(ThemeSettings Function(ThemeSettings now) change) async {
    var before = const ThemeSettings();
    ++_generation;
    final v = await store.update((now) {
      before = ThemeSettings.fromJson(now[ThemeSettings.key]) ?? const ThemeSettings();
      return {...now, ThemeSettings.key: change(before).toJson()};
    });
    _preview = null;
    if (_disposed) return before;
    _apply(v);
    notifyListeners();
    return before;
  }

  /// Draws [choice] without storing it (the gallery's live preview); null ends the preview.
  void preview(ThemeChoice? choice) {
    if (_disposed || choice == _preview) return;
    _preview = choice;
    notifyListeners();
  }

  /// Use in this app (or in [app]): stores [choice] as that app's own. Changing only the palette is the same
  /// write; a palette is never written for a theme without palettes (System).
  Future<void> use(ThemeChoice choice, {String? app}) =>
      _change((s) => s.copyWith(apps: {...s.apps, app ?? appId: choice}));

  /// Use everywhere: stores [choice], palette included, for every app, including ones installed later, and
  /// clears each app's own. Returns the settings before, for [restore] (the Undo in the gallery's toast).
  Future<ThemeSettings> useEverywhere(ThemeChoice choice) => _change((_) => ThemeSettings(everywhere: choice));

  /// Puts [settings] back (Undo of [useEverywhere]).
  Future<void> restore(ThemeSettings settings) => _change((_) => settings);

  /// Reset: [app] (this app when null) follows the everywhere choice again.
  Future<void> reset([String? app]) => _change((s) => s.copyWith(apps: {...s.apps}..remove(app ?? appId)));

  /// Light, dark or match system, for this device (every myData app on it follows).
  Future<void> setMode(MyDataMode mode) async {
    if (_disposed) return;
    ++_generation;
    _mode = mode;
    notifyListeners();
    await store.update((now) => {...now, 'mode': mode.name});
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    unawaited(_changes?.cancel());
    if (_started) _hostChanges?.removeListener(_onHost);
    super.dispose();
  }
}
