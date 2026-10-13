import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';

import 'format.dart';

/// The host's sources (GET /sources): This Mac, on a Mac host only, then each followed iCloud account.
/// Read by the Settings screen, which reloads it with each status poll while it shows.
class SourceList extends ChangeNotifier {
  SourceList(this._controller);

  final HostController _controller;

  /// Null until the first answer.
  List<SourceOut>? sources;

  /// Why the last load failed, for people; null when it worked.
  String? error;

  Future<void>? _loading;
  bool _again = false;
  bool _disposed = false;

  /// This Mac, or null: not a Mac host (the source is absent, not broken), or not read yet.
  SourceOut? get mac => sources?.where((s) => s.kind == SourceOutKindEnum.mac).firstOrNull;

  /// The followed iCloud accounts.
  List<SourceOut> get icloud => [...?sources?.where((s) => s.kind == SourceOutKindEnum.icloud)];

  /// Reads the list. A call during a read waits for it and then reads once more, so a change the caller
  /// just made is always in the answer it waits for.
  Future<void> load() {
    if (_loading != null) {
      _again = true;
      return _loading!;
    }
    return _loading = _readUntilCurrent().whenComplete(() => _loading = null);
  }

  Future<void> _readUntilCurrent() async {
    do {
      _again = false;
      await _read();
    } while (_again && !_disposed);
  }

  Future<void> _read() async {
    final connection = _controller.connection;
    if (connection == null) return;
    try {
      sources = (await connection.sources.sources())?.sources ?? const [];
      error = null;
    } on Object catch (e) {
      error = errorText(e);
    }
    if (!_disposed) notifyListeners();
  }

  /// Uses This Mac as the host just returned it (from PUT /sources/mac and the other This Mac routes).
  void useMac(SourceOut? fresh) {
    final list = sources;
    if (fresh == null || list == null) return;
    sources = [for (final s in list) s.kind == SourceOutKindEnum.mac ? fresh : s];
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The body of PUT /sources/mac. The generated [MacSourceIn] defaults its lists to empty (nothing
/// included) and always sends every field, where null means everything, so every field is set here on
/// purpose.
abstract final class MacChoice {
  /// Turn This Mac on or off with everything included, as on first use. Turning it off deletes what it
  /// mirrored; turning it on again starts from everything.
  static MacSourceIn turn({required bool on}) => MacSourceIn(enabled: on, contactContainers: null, calendars: null);

  /// Keep This Mac as it is, but include ([include] true) or leave out the contact account or calendar
  /// [id]. The other kind's choice is sent back as GET /sources shows it. Including the last one left out
  /// goes back to "everything", which also takes in accounts and calendars added later.
  static MacSourceIn change(SourceOut mac, {String? container, String? calendar, required bool include}) => MacSourceIn(
    enabled: null,
    contactContainers: _choice(
      all: mac.allContactContainers ?? true,
      items: [for (final c in mac.contactContainers) (c.id, c.included)],
      id: container,
      include: include,
    ),
    calendars: _choice(
      all: mac.allCalendars ?? true,
      items: [for (final c in mac.calendars) (c.id, c.included)],
      id: calendar,
      include: include,
    ),
  );

  /// The ids to send for one kind: null for everything, otherwise the ids included.
  static List<String>? _choice({
    required bool all,
    required List<(String, bool)> items,
    required String? id,
    required bool include,
  }) {
    if (id == null) {
      if (all) return null;
      return [
        for (final (i, on) in items)
          if (on) i,
      ]..sort();
    }
    final chosen = {
      for (final (i, on) in items)
        if (all || on) i,
    };
    include ? chosen.add(id) : chosen.remove(id);
    final everything = items.every((item) => chosen.contains(item.$1));
    return everything ? null : (chosen.toList()..sort());
  }
}
