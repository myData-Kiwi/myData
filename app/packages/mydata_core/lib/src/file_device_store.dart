import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'platform_types.dart';

/// This device's settings in one JSON file (`device/settings.json` in the myData folder), shared by every
/// myData app on it. Not host data: a later remote host never sees it.
///
/// - **Writes** go to their own temporary file next to it (named with the process id and a random part),
///   then are renamed over it, so another app never reads half a file, and two apps writing at once cannot
///   rename or remove each other's temporary file. The last rename wins.
/// - **[update]** reads, changes and writes, and checks just before the rename that the file is still the
///   one it read (its text); when another app wrote meanwhile it reads again and retries, so two apps
///   changing different keys at once both keep their change (design/themes/ARCHITECTURE.md 4.1). Updates in
///   one process run one at a time; between processes the check and the rename are not one step, so a write
///   from another app that lands between them is still lost, which is rare for settings people change by
///   hand.
/// - **A file that cannot be read** (no permission, not a JSON object) is never taken for "nothing stored":
///   [read] throws [DeviceStoreUnreadable], and [update] tries again briefly, then throws it, writing
///   nothing. No file, or an empty one, is no settings yet.
/// - **[changes]** fires when the file is written, by this app or another, through the folder's file system
///   events; apps keep polling as well, since such events are not promised on every file system.
class FileDeviceStore extends DeviceStore {
  FileDeviceStore(this._path);

  final String Function() _path;

  static final _random = Random();

  /// How many times [update] reads again after another app wrote, before it writes regardless.
  static const updateAttempts = 5;

  File get _file => File(_path());

  StreamController<void>? _changes;
  StreamSubscription<FileSystemEvent>? _watch;

  @override
  Future<Map<String, Object?>> read() async => _decode(await _text());

  /// The file's text, or null when there is no file. Throws [DeviceStoreUnreadable] when there is one that
  /// cannot be read.
  Future<String?> _text() async {
    final f = _file;
    try {
      return await f.readAsString();
    } on FileSystemException catch (e) {
      if (!await f.exists()) return null;
      throw DeviceStoreUnreadable('cannot read it: ${e.osError?.message ?? e.message}');
    } on FormatException {
      throw const DeviceStoreUnreadable('not UTF-8 text');
    }
  }

  /// [text] as the settings: none for no file or an empty one. Throws [DeviceStoreUnreadable] when it is not
  /// a JSON object.
  static Map<String, Object?> _decode(String? text) {
    if (text == null || text.trim().isEmpty) return {};
    final Object? v;
    try {
      v = jsonDecode(text);
    } on FormatException {
      throw const DeviceStoreUnreadable('not JSON');
    }
    if (v is! Map<String, Object?>) throw const DeviceStoreUnreadable('not a JSON object');
    return v;
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    await _write(values);
  }

  /// The update running on each path in this process: updates from one app (or two stores on one file) run
  /// one after another, so only another process can come between a check and its rename.
  static final _running = <String, Future<void>>{};

  @override
  Future<Map<String, Object?>> update(Map<String, Object?> Function(Map<String, Object?> values) change) async {
    final path = _file.path;
    final previous = _running[path];
    final done = Completer<void>();
    final mine = done.future;
    _running[path] = mine;
    try {
      if (previous != null) await previous;
      return await _update(change);
    } finally {
      done.complete();
      if (identical(_running[path], mine)) _running.remove(path);
    }
  }

  Future<Map<String, Object?>> _update(Map<String, Object?> Function(Map<String, Object?> values) change) async {
    for (var attempt = 1; ; attempt++) {
      final text = await _readable();
      final next = change(_decode(text));
      final last = attempt >= updateAttempts;
      if (await _write(next, expect: last ? null : (text,))) return next;
    }
  }

  /// How many times [update] reads a file it cannot read or parse before it gives up, and the pause between.
  static const unreadableAttempts = 3;
  static const unreadablePause = Duration(milliseconds: 50);

  /// The file's text for [update], read again after a short pause while it cannot be read or parsed (a disk
  /// that is slow to answer). Throws [DeviceStoreUnreadable] after [unreadableAttempts], so nothing is ever
  /// written over settings that could not be read.
  Future<String?> _readable() async {
    for (var attempt = 1; ; attempt++) {
      try {
        final text = await _text();
        _decode(text);
        return text;
      } on DeviceStoreUnreadable {
        if (attempt >= unreadableAttempts) rethrow;
        await Future<void>.delayed(unreadablePause);
      }
    }
  }

  /// Writes [values]; with [expect] given, only while the file still holds that text (its record's field;
  /// null: no file), and false otherwise, writing nothing. The text, not the modification time: two apps
  /// writing within the same millisecond leave the same time and often the same size.
  Future<bool> _write(Map<String, Object?> values, {(String?,)? expect}) async {
    final f = _file;
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.$pid.${_random.nextInt(1 << 32).toRadixString(16)}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(values), flush: true);
      if (expect != null && await _textOrUnreadable() != expect.$1) {
        await tmp.delete();
        return false;
      }
      await tmp.rename(f.path);
      return true;
    } on Object {
      try {
        await tmp.delete();
      } on Object {
        // already gone
      }
      rethrow;
    }
  }

  /// The text for [_write]'s check: a file that cannot be read now is not the one [update] read.
  Future<Object?> _textOrUnreadable() async {
    try {
      return await _text();
    } on DeviceStoreUnreadable catch (e) {
      return e;
    }
  }

  @override
  Stream<void> get changes {
    final c = _changes ??= StreamController<void>.broadcast(onListen: _startWatching, onCancel: _stopWatching);
    return c.stream;
  }

  void _startWatching() {
    unawaited(() async {
      final f = _file;
      try {
        await f.parent.create(recursive: true);
        final name = f.uri.pathSegments.last;
        _watch = f.parent.watch().listen((e) {
          final hit =
              e.path.endsWith('/$name') ||
              e.path.endsWith('\\$name') ||
              (e is FileSystemMoveEvent && (e.destination?.endsWith(name) ?? false));
          if (hit) _changes?.add(null);
        }, onError: (Object _) {});
      } on Object {
        // No events here: the apps' poll still reads the file.
      }
    }());
  }

  void _stopWatching() {
    unawaited(_watch?.cancel());
    _watch = null;
  }
}
