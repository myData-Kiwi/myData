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
///
/// `moved` lists the old colours whose choices were moved to the theme each now belongs to
/// ([ThemeSettings.movedOver]), until myData's Appearance has said so ([ThemeController.acknowledgeMoved]).
@immutable
class ThemeSettings {
  const ThemeSettings({this.everywhere, this.apps = const {}, this.moved = const []});

  /// The settings key.
  static const key = 'themes';

  /// The key under [key] that lists the old colours moved and not yet told.
  static const movedKey = 'moved';

  final ThemeChoice? everywhere;

  /// Each app's own choice, by its id ([MyDataAppId.name]: `mycontacts`).
  final Map<String, ThemeChoice> apps;

  /// The old colours (`plum`) whose choices were moved to their new theme, not yet told in myData.
  final List<String> moved;

  /// What [app] draws: its own choice, else the everywhere one, else System.
  ThemeChoice choiceFor(String app) => apps[app] ?? everywhere ?? ThemeChoice.system;

  /// Whether [app] follows the everywhere choice (it has none of its own).
  bool followsEverywhere(String app) => !apps.containsKey(app);

  /// The settings in [value] (the `themes` key's value); null when there is none, which means this device
  /// has not been migrated from the host's theme yet. Entries that are not choices are skipped.
  static ThemeSettings? fromJson(Object? value) {
    if (value is! Map) return null;
    final apps = value['apps'];
    final moved = value[movedKey];
    return ThemeSettings(
      everywhere: ThemeChoice.fromJson(value['everywhere']),
      apps: {
        if (apps is Map)
          for (final e in apps.entries)
            if (e.key is String) e.key as String: ?ThemeChoice.fromJson(e.value),
      },
      moved: [
        if (moved is List)
          for (final c in moved)
            if (c is String && ThemeLibrary.movedColours.containsKey(c)) c,
      ],
    );
  }

  /// The `themes` value [raw] with every choice of Kiwi in one of today's old colours (`{"theme":
  /// "mydata.kiwi", "palette": "plum"}`) moved to the theme that colour now belongs to, in that palette
  /// (Journal in Plum, [ThemeLibrary.movedColours]; ARCHITECTURE.md 4.2), and those colours added to
  /// [movedKey] so myData's Appearance says so once. Everything else is kept as written. Null when there is
  /// nothing to move.
  static Map<String, Object?>? movedOver(Object? raw) {
    if (raw is! Map) return null;
    final colours = <String>[];
    Object? move(Object? choice) {
      final to = ThemeLibrary.moved(ThemeChoice.fromJson(choice));
      if (to == null) return choice;
      colours.add(ThemeChoice.fromJson(choice)!.palette!);
      return to.toJson();
    }

    final out = <String, Object?>{
      for (final e in raw.entries)
        if (e.key is String) e.key as String: e.value,
    };
    if (out.containsKey('everywhere')) out['everywhere'] = move(out['everywhere']);
    if (out['apps'] case final Map apps) {
      out['apps'] = {
        for (final e in apps.entries)
          if (e.key is String) e.key as String: move(e.value),
      };
    }
    if (colours.isEmpty) return null;
    final before = out[movedKey] is List ? (out[movedKey] as List).whereType<String>() : const <String>[];
    out[movedKey] = {...before, ...colours}.toList();
    return out;
  }

  /// As written. A palette on a theme without palettes (System) is never written ([stored]).
  Map<String, Object?> toJson() => {
    'everywhere': ?stored(everywhere)?.toJson(),
    if (apps.isNotEmpty) 'apps': {for (final e in apps.entries) e.key: stored(e.value)!.toJson()},
  };

  /// [c] as it is written: without a palette when its theme has none (a hand-edited file, an older writer).
  /// A theme this build does not know (a custom theme from a later version) is written as it was.
  static ThemeChoice? stored(ThemeChoice? c) {
    if (c == null) return null;
    final theme = ThemeLibrary.byId(c.theme);
    return theme != null && theme.palettes.isEmpty ? ThemeChoice(c.theme) : c;
  }

  /// The `themes` value to write for these settings over [raw] (the value the file holds now), keeping
  /// what this build does not know, since the apps are built and installed one by one and share the file:
  ///
  /// - keys under `themes` other than `everywhere` and `apps`;
  /// - a choice's other fields, while its theme stays the same (a choice of another theme starts afresh,
  ///   as its palette does);
  /// - entries under `apps` this build cannot read as a choice, unless [clearApps] (Use everywhere clears
  ///   every app's own).
  Map<String, Object?> writtenOver(Object? raw, {bool clearApps = false}) {
    final old = raw is Map ? raw : const <Object?, Object?>{};
    final out = <String, Object?>{
      for (final e in old.entries)
        if (e.key is String && e.key != 'everywhere' && e.key != 'apps') e.key as String: e.value,
    };
    if (_choiceOver(old['everywhere'], everywhere) case final e?) out['everywhere'] = e;
    final oldApps = old['apps'] is Map ? old['apps'] as Map : const <Object?, Object?>{};
    final apps = <String, Object?>{
      if (!clearApps)
        for (final e in oldApps.entries)
          if (e.key is String && ThemeChoice.fromJson(e.value) == null) e.key as String: e.value,
      for (final e in this.apps.entries) e.key: _choiceOver(oldApps[e.key], e.value),
    };
    if (apps.isNotEmpty) out['apps'] = apps;
    return out;
  }

  /// [choice] as written over [raw], the choice the file holds in that place now: [raw]'s other fields are
  /// kept while the theme is the same.
  static Map<String, Object?>? _choiceOver(Object? raw, ThemeChoice? choice) {
    final c = stored(choice);
    if (c == null) return null;
    final was = ThemeChoice.fromJson(raw);
    if (raw is! Map || was == null || was.theme != c.theme) return c.toJson();
    return {
      for (final e in raw.entries)
        if (e.key is String && e.key != 'theme' && e.key != 'palette') e.key as String: e.value,
      ...c.toJson(),
    };
  }

  ThemeSettings copyWith({ThemeChoice? everywhere, Map<String, ThemeChoice>? apps}) =>
      ThemeSettings(everywhere: everywhere ?? this.everywhere, apps: apps ?? this.apps, moved: moved);

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.everywhere == everywhere &&
      mapEquals(other.apps, apps) &&
      listEquals(other.moved, moved);

  @override
  int get hashCode => Object.hash(
    everywhere,
    Object.hashAllUnordered(apps.entries.map((e) => (e.key, e.value))),
    Object.hashAll(moved),
  );
}

/// What a Use everywhere changed, for its Undo ([ThemeController.restore]).
@immutable
class EverywhereUndo {
  const EverywhereUndo._(this.before, this.written, this._raw);

  /// The settings just before.
  final ThemeSettings before;

  /// The choice it stored for every app.
  final ThemeChoice written;

  /// The `themes` value just before, as the file held it.
  final Map<Object?, Object?> _raw;
}

/// The theme and mode one app draws with (design/themes/ARCHITECTURE.md 4.1 and 4.2):
///
/// - **The theme** is chosen per app and per device ([ThemeSettings] in this device's settings file, shared
///   by every myData app on it, never synced): the app's own choice, else "everywhere", else System.
/// - **The mode** (light, dark, match system) is one per device for every app.
/// - Another app's change (myData's Appearance, Use everywhere in a gallery) arrives through the store's
///   [DeviceStore.changes] and, where those are not promised, the [pollInterval] read.
/// - **Preview** ([preview]) draws a choice without storing it, while the gallery is open; [use] (which
///   closes the gallery) or `preview(null)` ends it. Use everywhere and its Undo leave it as it is, since
///   the gallery stays open and still shows its selection.
/// - **A settings file that cannot be read** ([DeviceStoreUnreadable]) changes nothing on screen: a read
///   that fails is ignored, and a change fails with that error, writing nothing.
/// - **Migration**, once per device, when the file has no `themes` key (ARCHITECTURE.md 4.2): on macOS every
///   app starts on System (the Mac shell already ignored the host's theme, so nothing on screen changes);
///   elsewhere "everywhere" is seeded with the colour someone chose on the host, in the theme that colour
///   belongs to now (`plum` is Journal, Plum; moved as below). The host's default colour (`kiwi`, what a host
///   where nobody chose reports) seeds System, the default, which draws Kiwi in Kiwi until each platform's
///   own pass, so nothing on screen changes and the device follows that pass.
/// - **The old colours move** (phase 3, ARCHITECTURE.md 4.2): a stored choice of Kiwi in `graphite`, `dusk`,
///   `plum`, `rose` or `amber` (phase 2's gallery offered them; an older build may write one again) is
///   written as the theme that colour belongs to, in that palette, whenever it is read
///   ([ThemeSettings.movedOver]), and the colour is listed for myData's Appearance to say so once
///   ([acknowledgeMoved]). It is drawn that way before the write lands ([ThemeLibrary.normalise]).
///   The device's `lastTheme` is read first: the old controller wrote the host's theme there at every poll,
///   so it is the host's theme without waiting for the host (an app opened while the host starts draws it
///   at once, as before). Without it, the host's deprecated status `theme` is read once it answers; until
///   then System is drawn.
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
    Map<String, Object?> v;
    try {
      v = await store.read();
      if (_disposed || generation != _generation) return;
      if (v[ThemeSettings.key] == null) {
        final seed = _seed(v);
        if (seed != null) {
          v = await store.update((now) {
            if (now[ThemeSettings.key] != null) return now;
            final seeded = ThemeSettings(everywhere: seed).toJson();
            return {...now, ThemeSettings.key: ThemeSettings.movedOver(seeded) ?? seeded};
          });
          if (_disposed || generation != _generation) return;
        }
      } else if (ThemeSettings.movedOver(v[ThemeSettings.key]) != null) {
        v = await store.update((now) {
          final moved = ThemeSettings.movedOver(now[ThemeSettings.key]);
          return moved == null ? now : {...now, ThemeSettings.key: moved};
        });
        if (_disposed || generation != _generation) return;
      }
    } on DeviceStoreUnreadable {
      // Keep drawing what was read last; the next poll tries again.
      return;
    }
    // The theme's fonts first, so its text never shows in a fallback font and reflows (ARCHITECTURE.md 3.6).
    await _fontsFor(ThemeSettings.fromJson(v[ThemeSettings.key])?.choiceFor(appId));
    if (_disposed || generation != _generation) return;
    _apply(v);
  }

  /// Loads the fonts [choice]'s theme needs (none for a theme this build does not have).
  static Future<void> _fontsFor(ThemeChoice? choice) async {
    final theme = ThemeLibrary.byId(ThemeLibrary.normalise(choice).theme);
    if (theme != null && !ThemeFonts.readyFor(theme)) await ThemeFonts.ensureFor(theme);
  }

  /// The everywhere choice a device that has none starts with, or null while it cannot be known yet.
  ThemeChoice? _seed(Map<String, Object?> v) {
    if (_macOS) return ThemeChoice.system;
    final last = v['lastTheme'];
    final fromDevice = _chosenOnHost(last is String ? last : null);
    if (fromDevice != null) return fromDevice;
    if (!_hostAnswered()) return null;
    return _chosenOnHost(_hostTheme()) ?? ThemeChoice.system;
  }

  /// Kiwi in [colour], one of the host's old colours, as phase 2 drew it (the write moves it to its theme
  /// now, [ThemeSettings.movedOver]); System for the host's default, which a host where nobody chose reports
  /// too; null for none or one this build does not know.
  static ThemeChoice? _chosenOnHost(String? colour) {
    if (colour == defaultHostColour) return ThemeChoice.system;
    if (colour != null && ThemeLibrary.movedColours.containsKey(colour)) {
      return ThemeChoice(ThemeLibrary.kiwiId, colour);
    }
    return ThemeLibrary.fromColour(colour);
  }

  /// The host's default colour (`DEFAULT_THEME` in the host's appearance.py).
  static const defaultHostColour = 'kiwi';

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

  /// Writes [change] of the stored settings over what the file holds now, keeping what other apps wrote
  /// meanwhile and what this build does not know ([ThemeSettings.writtenOver]), and draws the result.
  /// Returns the `themes` value and the settings [change] was given (what the file held just before).
  Future<(Map<Object?, Object?>, ThemeSettings)> _change(
    ThemeSettings Function(ThemeSettings now) change, {
    bool clearApps = false,
  }) async {
    var raw = const <Object?, Object?>{};
    var before = const ThemeSettings();
    ++_generation;
    final v = await store.update((now) {
      final r = now[ThemeSettings.key];
      raw = r is Map ? r : const {};
      before = ThemeSettings.fromJson(r) ?? const ThemeSettings();
      return {...now, ThemeSettings.key: change(before).writtenOver(r, clearApps: clearApps)};
    });
    await _fontsFor(ThemeSettings.fromJson(v[ThemeSettings.key])?.choiceFor(appId));
    if (!_disposed) {
      _apply(v);
      notifyListeners();
    }
    return (raw, before);
  }

  /// Draws [choice] without storing it (the gallery's live preview); null ends the preview. A theme whose
  /// fonts are not loaded yet is drawn once they are, unless another preview came first.
  void preview(ThemeChoice? choice) {
    if (_disposed) return;
    _previewWanted = choice;
    if (choice == _preview) return;
    final theme = choice == null ? null : ThemeLibrary.byId(ThemeLibrary.normalise(choice).theme);
    if (theme != null && !ThemeFonts.readyFor(theme)) {
      unawaited(ThemeFonts.ensureFor(theme).then((_) {
        if (!_disposed && _previewWanted == choice && _preview != choice) {
          _preview = choice;
          notifyListeners();
        }
      }));
      return;
    }
    _preview = choice;
    notifyListeners();
  }

  /// The last preview asked for, which a font load still running may be waiting to draw.
  ThemeChoice? _previewWanted;

  /// Use in this app (or in [app]): stores [choice] as that app's own, and ends the preview (the gallery
  /// closes). Changing only the palette is the same write; a palette is never written for a theme without
  /// palettes (System).
  Future<void> use(ThemeChoice choice, {String? app}) async {
    await _change((s) => s.copyWith(apps: {...s.apps, app ?? appId: choice}));
    _previewWanted = null;
    if (_disposed || _preview == null) return;
    _preview = null;
    notifyListeners();
  }

  /// Use everywhere: stores [choice], palette included, for every app, including ones installed later, and
  /// clears each app's own. Returns what it changed, for [restore] (the Undo in the gallery's toast). The
  /// gallery stays open, so a preview goes on.
  Future<EverywhereUndo> useEverywhere(ThemeChoice choice) async {
    final (raw, before) = await _change((_) => ThemeSettings(everywhere: choice), clearApps: true);
    return EverywhereUndo._(before, ThemeSettings.stored(choice)!, raw);
  }

  /// Undo of [useEverywhere], as its inverse rather than the whole settings as they were, so a choice made
  /// since (another app's Reset or Use in, in this app or another) is kept: the everywhere choice goes
  /// back, and each app's own comes back where that app still has none. When everywhere was changed since
  /// (another Use everywhere), nothing is put back and this returns false.
  Future<bool> restore(EverywhereUndo undo) async {
    var restored = false;
    ++_generation;
    final v = await store.update((now) {
      restored = false;
      final r = now[ThemeSettings.key];
      final current = ThemeSettings.fromJson(r) ?? const ThemeSettings();
      if (ThemeSettings.stored(current.everywhere) != undo.written) return now;
      restored = true;
      final out = <String, Object?>{
        for (final e in (r is Map ? r : const <Object?, Object?>{}).entries)
          if (e.key is String && e.key != 'everywhere') e.key as String: e.value,
      };
      if (undo._raw['everywhere'] case final e?) out['everywhere'] = e;
      final nowApps = out['apps'] is Map ? out['apps'] as Map : const <Object?, Object?>{};
      final beforeApps = undo._raw['apps'] is Map ? undo._raw['apps'] as Map : const <Object?, Object?>{};
      final apps = <String, Object?>{
        for (final e in beforeApps.entries)
          if (e.key is String && !nowApps.containsKey(e.key)) e.key as String: e.value,
        for (final e in nowApps.entries)
          if (e.key is String) e.key as String: e.value,
      };
      if (apps.isEmpty) {
        out.remove('apps');
      } else {
        out['apps'] = apps;
      }
      return {...now, ThemeSettings.key: out};
    });
    if (!_disposed) {
      _apply(v);
      notifyListeners();
    }
    return restored;
  }

  /// Reset: [app] (this app when null) follows the everywhere choice again.
  Future<void> reset([String? app]) async {
    await _change((s) => s.copyWith(apps: {...s.apps}..remove(app ?? appId)));
  }

  /// myData's Appearance has said that [colours] moved to their new themes: they are taken off the list, so
  /// it is said once. Another app's write meanwhile is kept.
  Future<void> acknowledgeMoved(Iterable<String> colours) async {
    if (_disposed) return;
    final told = colours.toSet();
    ++_generation;
    final v = await store.update((now) {
      final raw = now[ThemeSettings.key];
      if (raw is! Map || raw[ThemeSettings.movedKey] is! List) return now;
      final left = (raw[ThemeSettings.movedKey] as List).where((c) => !told.contains(c)).toList();
      final out = <String, Object?>{
        for (final e in raw.entries)
          if (e.key is String && e.key != ThemeSettings.movedKey) e.key as String: e.value,
        if (left.isNotEmpty) ThemeSettings.movedKey: left,
      };
      return {...now, ThemeSettings.key: out};
    });
    if (!_disposed) _apply(v);
  }

  /// Light, dark or match system, for this device (every myData app on it follows). Drawn at once; when it
  /// cannot be stored, the mode before is drawn again and the error is passed on.
  Future<void> setMode(MyDataMode mode) async {
    if (_disposed) return;
    ++_generation;
    final before = _mode;
    _mode = mode;
    notifyListeners();
    try {
      await store.update((now) => {...now, 'mode': mode.name});
    } on Object {
      if (!_disposed && _mode == mode) {
        _mode = before;
        notifyListeners();
      }
      rethrow;
    }
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
