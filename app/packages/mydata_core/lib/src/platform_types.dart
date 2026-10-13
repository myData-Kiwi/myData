/// Where the host keeps its files, how to reach it, and how to start it.
class HostEnvironment {
  const HostEnvironment({required this.home, required this.baseUrl, required this.hostCommand});

  /// The host's folder (config.toml, app-tokens/, app_config.json, logs/).
  final String home;

  /// e.g. http://127.0.0.1:47821, from config.toml.
  final String baseUrl;

  /// The command that starts the host, or null if none is configured.
  final List<String>? hostCommand;
}

/// Result of running the host-start command.
class LaunchResult {
  const LaunchResult(this.ok, this.output);
  final bool ok;
  final String output;
}

/// Everything platform-specific the controller needs. Swapped for a fake in tests.
abstract class HostPlatform {
  /// False on platforms that cannot run or reach a local host (the web build).
  bool get supported;

  /// Why it is unsupported, for the message.
  String get unsupportedReason;

  Future<HostEnvironment> environment();

  /// This app's token, created by the host on its first start; null if it does not exist yet.
  Future<String?> readAppToken(HostEnvironment env, String app);

  Future<LaunchResult> startHost(HostEnvironment env);

  /// Bring up the myData app (on its Setup screen). Returns false where this is not possible.
  Future<bool> openMyDataApp({bool setup = true});
}

/// Settings that belong to this device, not to the host, shared by every myData app on it (light or dark
/// mode). Swapped for [MemoryDeviceStore] in tests.
abstract class DeviceStore {
  /// The stored JSON object, or an empty map if there is none or it cannot be read.
  Future<Map<String, Object?>> read();

  /// Replaces the stored object.
  Future<void> write(Map<String, Object?> values);
}

/// A [DeviceStore] in memory: the web build (no files) and tests.
class MemoryDeviceStore implements DeviceStore {
  MemoryDeviceStore([Map<String, Object?>? initial]) : _values = {...?initial};
  Map<String, Object?> _values;

  @override
  Future<Map<String, Object?>> read() async => {..._values};

  @override
  Future<void> write(Map<String, Object?> values) async => _values = {...values};
}

/// What the myData app needs from macOS for the This Mac source. Elsewhere it has nothing to report or
/// open. Swapped for a fake in tests.
abstract class MacSystem {
  /// The reader helper inside this app's bundle (`myData.app/Contents/Helpers/myDataReader.app`), or null:
  /// not macOS, or a development build made before the helper existed.
  String? readerHelperPath();

  /// Opens [url] with the system: a System Settings pane (`x-apple.systempreferences:...`). Returns false
  /// where it could not.
  Future<bool> open(String url);
}

/// The System Settings panes where access to contacts and calendars is turned back on.
abstract final class PrivacyPane {
  static const contacts = 'x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts';
  static const calendars = 'x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars';
}
