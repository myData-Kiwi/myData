// The on-demand fonts as the controller meets them (design/themes/ARCHITECTURE.md 3.6), with nothing loaded
// beforehand: a stored theme is drawn only once its fonts are, a preview that is overtaken is never drawn,
// and a font that cannot be loaded is reported while the theme is still drawn (in its fallback fonts).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// An asset bundle whose loads finish only when the test says so.
class _GatedBundle extends AssetBundle {
  final pending = <String, Completer<ByteData>>{};

  @override
  Future<ByteData> load(String key) => (pending[key] ??= Completer<ByteData>()).future;

  /// Finishes every load of [file] (`fraunces.ttf`) with the bundled bytes, or with [error].
  void finish(String file, {Object? error}) {
    for (final e in pending.entries.where((e) => e.key.endsWith('/$file') && !e.value.isCompleted)) {
      if (error != null) {
        e.value.completeError(error);
      } else {
        final path = e.key.replaceFirst('packages/mydata_ui/', '../mydata_ui/');
        e.value.complete(ByteData.sublistView(File(path).readAsBytesSync()));
      }
    }
  }

  Iterable<String> get asked => pending.keys.map((k) => k.split('/').last);

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) =>
      throw UnimplementedError();
}

ThemeFile _designed(String slug) {
  final json = jsonDecode(File('../mydata_ui/assets/themes/$slug.json').readAsStringSync()) as Map<String, Object?>;
  return ThemeFile.fromJson(json, base: json);
}

ThemeController _controller(DeviceStore store) =>
    ThemeController(appId: 'mycontacts', store: store, pollInterval: const Duration(milliseconds: 20), macOS: false);

/// Lets the controller's reads, writes and font loads run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _GatedBundle bundle;
  final journal = _designed('journal');
  final paperback = _designed('paperback');
  const journalPlum = ThemeChoice('mydata.journal', 'plum');
  const paperbackAmber = ThemeChoice('mydata.paperback', 'amber');

  setUp(() {
    ThemeFonts.resetForTesting();
    bundle = _GatedBundle();
    ThemeFonts.testBundle = bundle;
    ThemeLibrary.addForTesting(journal);
    ThemeLibrary.addForTesting(paperback);
  });
  tearDown(() {
    ThemeFonts.resetForTesting();
    ThemeLibrary.clearForTesting();
  });

  test('the designed themes need fonts that are not loaded yet', () {
    expect(ThemeFonts.readyFor(journal), isFalse);
    expect(ThemeFonts.readyFor(paperback), isFalse);
  });

  test('a stored theme is not drawn before its fonts are loaded', () async {
    final store = MemoryDeviceStore({
      'themes': {'everywhere': journalPlum.toJson()},
    });
    final c = _controller(store);
    unawaited(c.start());
    await _settle();
    expect(bundle.asked, containsAll(['fraunces.ttf', 'instrument-sans.ttf']));
    expect(c.choice, isNot(journalPlum), reason: 'still waiting for its fonts');
    bundle.finish('fraunces.ttf');
    await _settle();
    expect(c.choice, isNot(journalPlum), reason: 'one of its fonts is still loading');
    bundle.finish('instrument-sans.ttf');
    bundle.finish('instrument-sans-italic.ttf');
    await _settle();
    expect(c.choice, journalPlum);
    expect(ThemeFonts.readyFor(journal), isTrue);
    c.dispose();
  });

  test('preview(A) then preview(B) while both load: only B is ever drawn', () async {
    final c = _controller(MemoryDeviceStore());
    await c.start();
    final drawn = <ThemeChoice?>[];
    c.addListener(() => drawn.add(c.previewing));
    c.preview(journalPlum);
    c.preview(paperbackAmber);
    await _settle();
    expect(c.previewing, isNull);
    // A finishes first: it was overtaken, so it is never drawn.
    bundle.finish('fraunces.ttf');
    bundle.finish('instrument-sans.ttf');
    bundle.finish('instrument-sans-italic.ttf');
    await _settle();
    expect(c.previewing, isNull);
    bundle.finish('literata.ttf');
    bundle.finish('literata-italic.ttf');
    await _settle();
    expect(c.previewing, paperbackAmber);
    expect(drawn.where((d) => d != null), [paperbackAmber]);
    c.dispose();
  });

  test('a font that cannot be loaded is reported, and the theme is still drawn', () async {
    final errors = <FlutterErrorDetails>[];
    final was = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = was);
    final c = _controller(MemoryDeviceStore());
    await c.start();
    c.preview(paperbackAmber);
    await _settle();
    bundle.finish('literata.ttf', error: StateError('no such asset'));
    bundle.finish('literata-italic.ttf', error: StateError('no such asset'));
    await _settle();
    expect(errors, isNotEmpty);
    expect(errors.first.context.toString(), contains('Literata'));
    expect(c.previewing, paperbackAmber, reason: 'drawn in its fallback fonts');
    expect(ThemeFonts.isReady('literata'), isFalse, reason: 'a later ensure tries again');
    c.dispose();
  });
}
