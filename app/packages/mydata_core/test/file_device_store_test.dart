import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart' show DeviceStoreUnreadable;
import 'package:mydata_core/src/file_device_store.dart';

void main() {
  late Directory dir;
  late FileDeviceStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mydata-device-');
    store = FileDeviceStore(() => '${dir.path}/device/settings.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('reads what was written, and nothing from a missing or empty file', () async {
    expect(await store.read(), isEmpty);
    await store.write({'mode': 'dark'});
    expect(await store.read(), {'mode': 'dark'});
    File('${dir.path}/device/settings.json').writeAsStringSync('  \n');
    expect(await store.read(), isEmpty);
  });

  for (final (what, text) in [('not JSON', '{not json'), ('not an object', '["mode"]')]) {
    test('a file that is $what is never taken for "nothing stored", and update never writes over it', () async {
      final file = File('${dir.path}/device/settings.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      await expectLater(store.read(), throwsA(isA<DeviceStoreUnreadable>()));
      await expectLater(
        store.update((now) => {...now, 'lastOpened': 'c-1'}),
        throwsA(isA<DeviceStoreUnreadable>()),
      );
      expect(file.readAsStringSync(), text);
      expect(Directory('${dir.path}/device').listSync().map((f) => f.uri.pathSegments.last), ['settings.json']);
    });
  }

  test('update reads again when the file could not be read for a moment', () async {
    final file = File('${dir.path}/device/settings.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{not json');
    // an app's own write lands while this one waits to read again
    Future<void>.delayed(
      FileDeviceStore.unreadablePause ~/ 2,
      () => file.writeAsStringSync('{"mode": "dark"}'),
    );
    final out = await store.update((now) => {...now, 'lastOpened': 'c-1'});
    expect(out, {'mode': 'dark', 'lastOpened': 'c-1'});
  });

  test('a file that cannot be read (no permission) is refused the same way', () async {
    final file = File('${dir.path}/device/settings.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"mode": "dark"}');
    final made = Process.runSync('chmod', ['000', file.path]);
    addTearDown(() => Process.runSync('chmod', ['600', file.path]));
    if (made.exitCode != 0 || _readable(file)) {
      markTestSkipped('this user can read any file');
      return;
    }
    await expectLater(store.read(), throwsA(isA<DeviceStoreUnreadable>()));
    await expectLater(store.update((now) => {...now, 'k': 1}), throwsA(isA<DeviceStoreUnreadable>()));
    Process.runSync('chmod', ['600', file.path]);
    expect(await store.read(), {'mode': 'dark'});
  }, skip: Platform.isWindows ? 'no chmod' : false);

  test('writes at the same time (four apps on one device) never fail or leave half a file', () async {
    // With one shared temporary name, one write's rename found its file already moved by another (or moved
    // the other's half-written file into place).
    final stores = [for (var i = 0; i < 4; i++) FileDeviceStore(() => '${dir.path}/device/settings.json')];
    await Future.wait([
      for (var i = 0; i < 40; i++) stores[i % 4].write({'mode': 'dark', 'n': i, 'pad': 'x' * 20000}),
    ]);
    final stored = await store.read();
    expect(stored['mode'], 'dark');
    expect(stored['n'], isA<int>());
    expect(Directory('${dir.path}/device').listSync().map((f) => f.uri.pathSegments.last), ['settings.json']);
  });

  test('update keeps what another app wrote between its read and its write', () async {
    final other = FileDeviceStore(() => '${dir.path}/device/settings.json');
    await store.write({'mode': 'dark'});
    var first = true;
    final out = await store.update((now) {
      if (first) {
        first = false;
        // another app writes while this one is changing what it read
        File('${dir.path}/device/settings.json').writeAsStringSync('{"mode": "light", "hiddenCalendars": ["a"]}');
      }
      return {...now, 'themes': {'everywhere': {'theme': 'mydata.system'}}};
    });
    expect(out['mode'], 'light');
    expect(await other.read(), {
      'mode': 'light',
      'hiddenCalendars': ['a'],
      'themes': {'everywhere': {'theme': 'mydata.system'}},
    });
  });

  test('updates of different keys from four apps at once all land', () async {
    final stores = [for (var i = 0; i < 4; i++) FileDeviceStore(() => '${dir.path}/device/settings.json')];
    await Future.wait([for (var i = 0; i < 4; i++) stores[i].update((now) => {...now, 'k$i': i})]);
    final stored = await store.read();
    expect(stored, {'k0': 0, 'k1': 1, 'k2': 2, 'k3': 3});
  });

  test('changes fires when another app writes the file', () async {
    final events = <void>[];
    final sub = store.changes.listen(events.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await FileDeviceStore(() => '${dir.path}/device/settings.json').write({'mode': 'dark'});
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (events.isEmpty && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(events, isNotEmpty);
  });
}

bool _readable(File f) {
  try {
    f.readAsStringSync();
    return true;
  } on FileSystemException {
    return false;
  }
}
