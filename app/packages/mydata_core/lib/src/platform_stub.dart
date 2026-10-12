import 'platform_types.dart';

export 'platform_types.dart';

/// The web build: a browser can neither start the host nor read its token files, and the host
/// refuses requests from web pages. The apps show a clear message instead of a broken screen.
class _UnsupportedPlatform implements HostPlatform {
  @override
  bool get supported => false;

  @override
  String get unsupportedReason =>
      'The web version of myData needs the desktop app on this computer, which runs and reaches the host. '
      'Open the myData desktop app instead.';

  @override
  Future<HostEnvironment> environment() => throw UnsupportedError(unsupportedReason);

  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => null;

  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => LaunchResult(false, unsupportedReason);

  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

HostPlatform hostPlatform = _UnsupportedPlatform();
