import 'dart:convert';
import 'dart:io';

import 'package:toml/toml.dart';

import 'platform_types.dart';

export 'platform_types.dart';

/// Overrides the host folder at build time (integration tests): --dart-define=MYDATA_HOME=/path
const _homeOverride = String.fromEnvironment('MYDATA_HOME');

/// The host's folder on this machine: the same rules as the host (host/src/mydata/service/config.py).
String _myDataHome() {
  if (_homeOverride.isNotEmpty) return _homeOverride;
  final env = Platform.environment;
  if (env['MYDATA_HOME']?.isNotEmpty ?? false) return env['MYDATA_HOME']!;
  final userHome = env['HOME'] ?? env['USERPROFILE'] ?? '.';
  if (Platform.isMacOS) return '$userHome/Library/Application Support/myData';
  if (Platform.isWindows) return '${env['APPDATA'] ?? '$userHome\\AppData\\Roaming'}\\myData';
  return '${env['XDG_DATA_HOME'] ?? '$userHome/.local/share'}/mydata';
}

/// Desktop: the same folder rules as the host (host/src/mydata/service/config.py).
class _IoPlatform implements HostPlatform {
  @override
  bool get supported => true;

  @override
  String get unsupportedReason => '';

  String _home() => _myDataHome();

  @override
  Future<HostEnvironment> environment() async {
    final home = _home();
    var host = '127.0.0.1';
    var port = 47821;
    final config = File('$home/config.toml');
    if (await config.exists()) {
      try {
        final server = TomlDocument.parse(await config.readAsString()).toMap()['server'];
        if (server is Map) {
          host = (server['host'] as String?) ?? host;
          port = (server['port'] as int?) ?? port;
        }
      } on Object {
        // A broken config is the host's to report; use the defaults to reach it.
      }
    }
    final hostPart = host.contains(':') ? '[$host]' : host;
    return HostEnvironment(home: home, baseUrl: 'http://$hostPart:$port', hostCommand: await _hostCommand(home));
  }

  /// ┌────────────────────────────────────────────────────────────────────────────────────────┐
  /// │ HOW THE HOST IS STARTED                                                                │
  /// │ Development: the command in `<home>/app_config.json`, written by `uv run mydata        │
  /// │ dev-setup` in host/ (this checkout's Python running `mydata start`).                   │
  /// │ BUNDLED HOST (later): when the apps ship with a packaged host binary, return its path  │
  /// │ here (e.g. inside the app bundle) and keep app_config.json as a development override.  │
  /// └────────────────────────────────────────────────────────────────────────────────────────┘
  Future<List<String>?> _hostCommand(String home) async {
    final file = File('$home/app_config.json');
    if (await file.exists()) {
      try {
        final cmd = (jsonDecode(await file.readAsString()) as Map)['host_command'];
        if (cmd is List && cmd.isNotEmpty) return cmd.cast<String>();
      } on Object {
        return null;
      }
    }
    // TODO(bundled host): return the bundled host binary's path and arguments here.
    return null;
  }

  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async {
    final file = File('${env.home}/app-tokens/$app');
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    return token.isEmpty ? null : token;
  }

  @override
  Future<LaunchResult> startHost(HostEnvironment env) async {
    final cmd = env.hostCommand!;
    try {
      // `mydata start` runs the host detached and returns once it answers (or fails).
      final r = await Process.run(
        cmd.first,
        cmd.sublist(1),
        environment: {'MYDATA_HOME': env.home},
      ).timeout(const Duration(seconds: 90));
      final out = '${r.stdout}${r.stderr}'.trim();
      return LaunchResult(r.exitCode == 0, out);
    } on Object catch (e) {
      return LaunchResult(false, 'Could not run ${cmd.join(' ')}: $e');
    }
  }

  @override
  Future<bool> openMyDataApp({bool setup = true}) async {
    if (Platform.isMacOS) {
      try {
        final r = await Process.run('open', [
          '-b',
          'kiwi.mydata.mydata',
          if (setup) ...['--args', '--setup'],
        ]);
        return r.exitCode == 0;
      } on ProcessException {
        return false;
      }
    }
    // TODO(windows, linux): launch the installed myData app once there are installers.
    return false;
  }
}

HostPlatform hostPlatform = _IoPlatform();

/// `device/settings.json` in the myData folder: this device's own settings (mode), shared by every myData
/// app on it. Not host data: a later remote host never sees it.
class _FileDeviceStore implements DeviceStore {
  File get _file => File('${_myDataHome()}/device/settings.json');

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
    // Write then rename, so the other app never reads half a file.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(values));
    await tmp.rename(f.path);
  }
}

DeviceStore deviceStore = _FileDeviceStore();

/// macOS: the helper next to this app's executable, and `open` for System Settings.
class _IoMacSystem implements MacSystem {
  @override
  String? readerHelperPath() {
    if (!Platform.isMacOS) return null;
    // .../myData.app/Contents/MacOS/myData -> .../myData.app/Contents/Helpers/myDataReader.app
    final contents = File(Platform.resolvedExecutable).parent.parent;
    final helper = Directory('${contents.path}/Helpers/myDataReader.app');
    return helper.existsSync() ? helper.path : null;
  }

  @override
  Future<bool> open(String url) async {
    if (!Platform.isMacOS) return false;
    try {
      return (await Process.run('open', [url])).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

MacSystem macSystem = _IoMacSystem();
