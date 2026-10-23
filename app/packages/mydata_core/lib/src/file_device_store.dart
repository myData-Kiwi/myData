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

  /// The file's text, or null when there is none or it cannot be read.
  Future<String?> _text() async {
    try {
      return await _file.readAsString();
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _decode(String? text) {
    if (text == null) return {};
    try {
      final v = jsonDecode(text);
      return v is Map<String, Object?> ? v : {};
    } on Object {
      return {};
    }
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
      final text = await _text();
      final next = change(_decode(text));
      final last = attempt >= updateAttempts;
      if (await _write(next, expect: last ? null : (text,))) return next;
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
      if (expect != null && await _text() != expect.$1) {
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
