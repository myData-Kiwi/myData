import 'dart:convert';
import 'dart:io';

import 'package:toml/toml.dart';

import 'file_device_store.dart';
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
    final commands = await _hostCommands(home);
    return HostEnvironment(
      home: home,
      baseUrl: 'http://$hostPart:$port',
      hostCommand: commands.start,
      stopCommand: commands.stop,
    );
  }

  /// How the host is started and stopped: the commands in `<home>/app_config.json`. An installed host (a login
  /// service, host/packaging/macos/install.sh) writes its own `mydata start` and `mydata stop` there; a development
  /// checkout writes its Python's with `uv run mydata dev-setup`.
  Future<({List<String>? start, List<String>? stop})> _hostCommands(String home) async {
    final file = File('$home/app_config.json');
    if (await file.exists()) {
      try {
        return hostCommandsFrom(jsonDecode(await file.readAsString()));
      } on Object {
        return (start: null, stop: null);
      }
    }
    return (start: null, stop: null);
  }

  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async {
    final file = File('${env.home}/app-tokens/$app');
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    return token.isEmpty ? null : token;
  }

  @override
  Future<LaunchResult> startHost(HostEnvironment env) =>
      // `mydata start` runs the host detached and returns once it answers (or fails, or gives up waiting).
      _run(env.hostCommand!, env, const Duration(seconds: 90));

  @override
  Future<LaunchResult> stopHost(HostEnvironment env) async {
    final cmd = env.stopCommand;
    if (cmd == null) return const LaunchResult(false, 'There is no command to stop the myData host with.');
    // `mydata stop` gives a host that is starting up to 10 s to answer, then returns once it has stopped; it
    // kills one that takes more than 15 s.
    return _run([...cmd, ...replaceHostArguments()], env, const Duration(seconds: 45));
  }

  Future<LaunchResult> _run(List<String> cmd, HostEnvironment env, Duration timeout) async {
    try {
      final r = await Process.run(cmd.first, cmd.sublist(1), environment: {'MYDATA_HOME': env.home}).timeout(timeout);
      final out = '${r.stdout}${r.stderr}'.trim();
      return LaunchResult(r.exitCode == 0, out, exitCode: r.exitCode);
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

/// `device/settings.json` in the myData folder: this device's own settings, shared by every myData app on it.
DeviceStore deviceStore = FileDeviceStore(() => '${_myDataHome()}/device/settings.json');

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

/// True on macOS, the only platform where the myData apps open each other (for now).
bool get platformIsMacOS => Platform.isMacOS;

/// Runs [executable] with [arguments], without a shell.
Future<CommandResult> runCommand(String executable, List<String> arguments) async {
  final r = await Process.run(executable, arguments);
  return CommandResult(r.exitCode, '${r.stdout}', '${r.stderr}');
}
