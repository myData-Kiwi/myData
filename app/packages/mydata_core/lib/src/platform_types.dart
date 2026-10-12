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
