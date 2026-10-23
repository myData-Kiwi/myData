import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'host_version.g.dart';

/// Where the host keeps its files, how to reach it, and how to start and stop it.
class HostEnvironment {
  const HostEnvironment({required this.home, required this.baseUrl, required this.hostCommand, this.stopCommand});

  /// The host's folder (config.toml, app-tokens/, app_config.json, logs/).
  final String home;

  /// e.g. http://127.0.0.1:47821, from config.toml.
  final String baseUrl;

  /// The command that starts the host, or null if none is configured.
  final List<String>? hostCommand;

  /// The command that stops it (`mydata stop`), used to replace a host from another build; null if none.
  final List<String>? stopCommand;
}

/// The start and stop commands in a decoded `<home>/app_config.json`, written by `mydata service install` (an
/// installed host) or `uv run mydata dev-setup` (a development checkout).
/// A file written before it had `stop_command` gets the start command with its final "start" made "stop".
({List<String>? start, List<String>? stop}) hostCommandsFrom(Object? appConfig) {
  List<String>? command(Object? v) =>
      v is List && v.isNotEmpty && v.every((e) => e is String) ? List<String>.unmodifiable(v) : null;
  if (appConfig is! Map) return (start: null, stop: null);
  final start = command(appConfig['host_command']);
  final stop =
      command(appConfig['stop_command']) ??
      (start != null && start.last == 'start' ? [...start.sublist(0, start.length - 1), 'stop'] : null);
  return (start: start, stop: stop);
}

/// Result of running the host-start (or stop) command.
class LaunchResult {
  const LaunchResult(this.ok, this.output, {this.exitCode});
  final bool ok;
  final String output;

  /// The command's exit code, when it ran; see [HostExit].
  final int? exitCode;
}

/// Exit codes of `mydata start` and `mydata stop` (host/src/mydata/cli.py) that are not plain failures.
abstract final class HostExit {
  /// `mydata start`: the host is running but did not answer within the command's own wait. It may still.
  static const stillStarting = 4;

  /// `mydata stop --expect`: a host started by this command would be another build than this app's as well,
  /// so nothing was stopped.
  static const wouldNotMatch = 5;
}

/// What [HostPlatform.stopHost] adds to the stop command: leave a host that already runs the current code (another
/// app may have just replaced it), and stop nothing unless the host this command starts is this app's build.
List<String> replaceHostArguments() => ['--unless-current', '--expect', expectedHostVersion, expectedHostApiVersion];

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

  /// Run [HostEnvironment.stopCommand] with [replaceHostArguments] (`mydata stop --unless-current --expect ...`),
  /// which returns once the host has stopped, or at once with [HostExit.wouldNotMatch]. Used only to replace a
  /// host from another build, which is then started again; not the myData app's Stop host.
  Future<LaunchResult> stopHost(HostEnvironment env);

  /// Bring up the myData app (on its Setup screen). Returns false where this is not possible.
  Future<bool> openMyDataApp({bool setup = true});
}

/// Settings that belong to this device, not to the host, shared by every myData app on it (light or dark
/// mode, each app's theme, hidden calendars, the last contact opened). Swapped for [MemoryDeviceStore] in
/// tests.
///
/// Apps change it only through [update], which keeps every key another app (or another part of this app)
/// wrote; [write] replaces the whole object and is for tests and for stores to implement.
abstract class DeviceStore {
  /// The stored JSON object; an empty map when there is none yet. Throws [DeviceStoreUnreadable] when there
  /// is one that cannot be read or is not a JSON object, so a reader never mistakes it for "nothing stored".
  Future<Map<String, Object?>> read();

  /// Replaces the stored object. Apps use [update]: a plain read and write loses what another app wrote in
  /// between, and turns a file that could not be read into one with a single key.
  @visibleForTesting
  Future<void> write(Map<String, Object?> values);

  /// Reads, applies [change] and writes, keeping what another app wrote there meanwhile as far as the
  /// store can tell ([FileDeviceStore] reads again and retries when the file changed under it). Returns
  /// what was written. Never writes over a file it cannot read: throws [DeviceStoreUnreadable] instead.
  Future<Map<String, Object?>> update(Map<String, Object?> Function(Map<String, Object?> values) change) async {
    final next = change(await read());
    await write(next);
    return next;
  }

  /// Fires when the stored object may have changed, from this app or another; nothing where the store cannot
  /// tell (readers poll as well).
  Stream<void> get changes => const Stream.empty();
}

/// This device's settings exist but cannot be read (no permission, a disk error) or are not a JSON object
/// (a hand-edited file). Nothing is written over them.
class DeviceStoreUnreadable implements Exception {
  const DeviceStoreUnreadable(this.reason);

  /// Why, for the log: never the file's contents.
  final String reason;

  @override
  String toString() => "This device's settings cannot be read ($reason).";
}

/// A [DeviceStore] in memory: the web build (no files) and tests. Two controllers given the same one see
/// each other's writes at once ([changes]), as two apps sharing the device's file do.
class MemoryDeviceStore extends DeviceStore {
  MemoryDeviceStore([Map<String, Object?>? initial]) : _values = {...?initial};
  Map<String, Object?> _values;
  final _changes = StreamController<void>.broadcast(sync: false);

  @override
  Future<Map<String, Object?>> read() async => {..._values};

  @override
  Future<void> write(Map<String, Object?> values) async {
    _values = {...values};
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;
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

/// What a command printed and how it ended.
class CommandResult {
  const CommandResult(this.exitCode, this.stdout, [this.stderr = '']);
  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Runs a program (no shell) and waits for it. The real one is [runCommand]; tests pass a fake.
typedef CommandRunner = Future<CommandResult> Function(String executable, List<String> arguments);
