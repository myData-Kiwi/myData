import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'platform_types.dart';

/// This device's settings in one JSON file (`device/settings.json` in the myData folder), shared by every
/// myData app on it. Not host data: a later remote host never sees it.
///
/// Each write goes to its own temporary file next to it (named with the process id and a random part), then
/// is renamed over it, so another app never reads half a file, and two apps writing at once cannot rename
/// or remove each other's temporary file. The last rename wins.
class FileDeviceStore implements DeviceStore {
  FileDeviceStore(this._path);

  final String Function() _path;

  static final _random = Random();

  File get _file => File(_path());

  @override
  Future<Map<String, Object?>> read() async {
    try {
      final v = jsonDecode(await _file.readAsString());
      return v is Map<String, Object?> ? v : {};
    } on Object {
      return {};
    }
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    final f = _file;
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.$pid.${_random.nextInt(1 << 32).toRadixString(16)}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(values), flush: true);
      await tmp.rename(f.path);
    } on Object {
      try {
        await tmp.delete();
      } on Object {
        // Already renamed or never made.
      }
      rethrow;
    }
  }
}
