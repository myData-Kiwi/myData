import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

const _channel = MethodChannel('mydata/links');
const _codec = StandardMethodCodec();

/// The runner: answers "ready" with the links it held, and can send "open" later.
class FakeRunner {
  FakeRunner(this.held);
  List<Object?>? held;
  int readyCalls = 0;
  bool missing = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      if (missing) throw MissingPluginException();
      if (call.method != 'ready') return null;
      readyCalls++;
      final out = held;
      held = [];
      return out;
    });
  }

  /// macOS opened [link] with the app after Dart was listening.
  Future<void> open(Object? link) async {
    final done = Completer<void>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      _codec.encodeMethodCall(MethodCall('open', link)),
      (_) => done.complete(),
    );
    await done.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('the link that started the app is collected on start, and later links follow', () async {
    final runner = FakeRunner(['mycontacts://contact/2f1c9a52-7d3e'])..install();
    final incoming = IncomingLinks(app: MyDataAppId.mycontacts);
    final got = <MyDataLink>[];
    incoming.links.listen(got.add);
    await incoming.start();
    await runner.open('mycontacts://contact/a1b2');
    await pumpEventQueue();
    expect(got, [OpenContact('2f1c9a52-7d3e'), OpenContact('a1b2')]);
    expect(runner.readyCalls, 1);
    incoming.dispose();
  });

  test('links that arrive before anyone listens are kept until someone does', () async {
    final runner = FakeRunner(['mycalendar://day/2026-03-18'])..install();
    final incoming = IncomingLinks(app: MyDataAppId.mycalendar);
    await incoming.start();
    await runner.open('mycalendar://day/2026-03-19');
    expect(await incoming.links.take(2).toList(), [OpenDay(DateTime(2026, 3, 18)), OpenDay(DateTime(2026, 3, 19))]);
    incoming.dispose();
  });

  test('anything invalid, or meant for another app, is ignored', () async {
    final runner = FakeRunner([
      'mycontacts://contact/bad_id',
      42,
      null,
      'mycalendar://day/2026-03-18',
      'https://example.com',
    ])..install();
    final incoming = IncomingLinks(app: MyDataAppId.mycontacts);
    final got = <MyDataLink>[];
    incoming.links.listen(got.add);
    await incoming.start();
    await runner.open('mydata://settings/sources');
    await runner.open(['mycontacts://contact/abc']);
    await runner.open('mycontacts://contact/abc?x=1');
    await runner.open('mycontacts://contact/ok-1');
    await pumpEventQueue();
    expect(got, [OpenContact('ok-1')]);
    incoming.dispose();
  });

  test('myData accepts its settings link', () async {
    FakeRunner(['mydata://settings/sources']).install();
    final incoming = IncomingLinks(app: MyDataAppId.mydata);
    await incoming.start();
    expect(await incoming.links.first, const OpenMyDataSources());
    incoming.dispose();
  });

  test('without the runner code (other platforms, older builds) start is quiet and nothing arrives', () async {
    final runner = FakeRunner(null)
      ..missing = true
      ..install();
    final incoming = IncomingLinks(app: MyDataAppId.mycontacts);
    final got = <MyDataLink>[];
    incoming.links.listen(got.add);
    await incoming.start();
    await pumpEventQueue();
    expect(got, isEmpty);
    expect(runner.readyCalls, 0);
    incoming.dispose();
  });

  test('start twice asks the runner once; after dispose nothing is delivered', () async {
    final runner = FakeRunner([])..install();
    final incoming = IncomingLinks(app: MyDataAppId.mycontacts);
    await incoming.start();
    await incoming.start();
    expect(runner.readyCalls, 1);
    incoming.dispose();
    await runner.open('mycontacts://contact/abc'); // no handler any more: dropped, no error
  });
}
