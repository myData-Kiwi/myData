import 'dart:async';

import 'package:flutter/foundation.dart';

import 'platform.dart';

/// Which calendars are hidden on this device. Like the mode, this belongs to the device, not the host: it
/// is kept in the [DeviceStore] under [storeKey] (a list of calendar ids), and every open copy re-reads the
/// store on [pollInterval]. myCalendar is the app that follows it today; myAssistant's answers come from
/// the host, which does not know about it, so they still include hidden calendars. Hiding only changes
/// what myCalendar shows; nothing is written to the host or to any calendar.
///
/// A calendar that reaches the host through two sources (say iCloud and This Mac) is two calendars with two
/// ids, so either can be hidden on its own.
class CalendarVisibility extends ChangeNotifier {
  CalendarVisibility({DeviceStore? store, this.pollInterval = const Duration(seconds: 2)})
    : store = store ?? deviceStore;

  /// The key in the device store.
  static const storeKey = 'hiddenCalendars';

  final DeviceStore store;
  final Duration pollInterval;

  Set<String> _hidden = const {};
  Timer? _poll;
  bool _started = false;
  bool _disposed = false;

  /// Bumped by every change made here, so a read that started before it cannot undo it.
  int _generation = 0;

  /// Changes not yet written: while there are any, a poll's read is older than what is shown.
  int _pending = 0;
  Future<void> _writes = Future.value();

  /// The hidden calendars' ids.
  Set<String> get hidden => Set.unmodifiable(_hidden);

  bool isHidden(String calendarId) => _hidden.contains(calendarId);
  bool isVisible(String calendarId) => !_hidden.contains(calendarId);

  /// Read this device's choice, then follow changes other apps make.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _read();
    if (_disposed) return;
    _poll = Timer.periodic(pollInterval, (_) => _read());
  }

  static Set<String> _parse(Object? v) => {
    if (v is List)
      for (final id in v)
        if (id is String && id.isNotEmpty && id.length <= 256) id,
  };

  Future<void> _read() async {
    final generation = _generation;
    final Set<String> stored;
    try {
      stored = _parse((await store.read())[storeKey]);
    } on Object {
      return;
    }
    if (_disposed || generation != _generation || _pending > 0) return;
    if (setEquals(stored, _hidden)) return;
    _hidden = stored;
    notifyListeners();
  }

  /// Hide or show one calendar on this device. Shown at once; the returned future completes when it is
  /// stored, and with an error when it could not be. Then what is stored is read back (so the switch
  /// shows what will last), and later changes are still written.
  Future<void> setHidden(String calendarId, bool hidden) =>
      _change((ids) => hidden ? ids.add(calendarId) : ids.remove(calendarId));

  /// Show every calendar again.
  Future<void> showAll() => _change((ids) => ids.clear());

  Future<void> _change(void Function(Set<String> ids) apply) {
    _generation++;
    final next = {..._hidden};
    apply(next);
    if (!setEquals(next, _hidden)) {
      _hidden = next;
      if (!_disposed) notifyListeners();
    }
    // Apply the same change to what is stored now, so a change another app made meanwhile is kept, and
    // write one change at a time.
    _pending++;
    final write = _writes.then((_) async {
      await store.update((values) {
        final ids = _parse(values[storeKey]);
        apply(ids);
        return {...values, storeKey: ids.toList()..sort()};
      });
    });
    // The queue outlives a failed write: the next change is still written.
    _writes = write.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      _pending--;
    });
    return write.catchError((Object e) async {
      // Not stored: once nothing else is waiting to be written, show what is stored.
      await _writes;
      if (_pending == 0 && !_disposed) {
        _generation++;
        await _read();
      }
      throw e;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
