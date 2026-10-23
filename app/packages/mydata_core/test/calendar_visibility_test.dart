import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_core/src/file_device_store.dart';

const _poll = Duration(milliseconds: 20);

CalendarVisibility _visibility(DeviceStore store) => CalendarVisibility(store: store, pollInterval: _poll);

/// A store whose reads can be held back, to race a slow read against a change.
class SlowStore extends MemoryDeviceStore {
  SlowStore([super.initial]);
  Completer<void>? gate;

  @override
  Future<Map<String, Object?>> read() async {
    final v = await super.read();
    if (gate != null) await gate!.future;
    return v;
  }
}

/// A store whose writes fail while [failing], and whose writes can be held back with [writeGate].
class FlakyStore extends MemoryDeviceStore {
  FlakyStore([super.initial]);
  bool failing = false;
  Completer<void>? writeGate;
  int writes = 0;

  @override
  Future<void> write(Map<String, Object?> values) async {
    if (writeGate != null) await writeGate!.future;
    if (failing) throw const FileSystemException('disk full');
    writes++;
    await super.write(values);
  }
}

void main() {
  test('starts from what this device stored', () async {
    final v = _visibility(MemoryDeviceStore({'hiddenCalendars': ['cal-b', 'cal-a']}));
    await v.start();
    expect(v.hidden, {'cal-a', 'cal-b'});
    expect(v.isHidden('cal-a'), isTrue);
    expect(v.isVisible('cal-c'), isTrue);
    v.dispose();
  });

  test('hiding and showing notifies at once and is stored, keeping the other settings', () async {
    final store = MemoryDeviceStore({'mode': 'dark', 'lastTheme': 'plum'});
    final v = _visibility(store);
    await v.start();
    var notified = 0;
    v.addListener(() => notified++);
    final pending = v.setHidden('cal-a', true);
    expect(v.isHidden('cal-a'), isTrue);
    expect(notified, 1);
    await pending;
    await v.setHidden('cal-c', true);
    expect(await store.read(), {'mode': 'dark', 'lastTheme': 'plum', 'hiddenCalendars': ['cal-a', 'cal-c']});
    await v.setHidden('cal-a', false);
    expect((await store.read())['hiddenCalendars'], ['cal-c']);
    await v.setHidden('cal-a', false); // already shown: nothing to tell anyone
    expect(notified, 3);
    await v.showAll();
    expect(v.hidden, isEmpty);
    expect((await store.read())['hiddenCalendars'], isEmpty);
    v.dispose();
  });

  test('a calendar hidden in one app is hidden in the other on its next read', () async {
    final store = MemoryDeviceStore();
    final contacts = _visibility(store);
    final calendar = _visibility(store);
    await contacts.start();
    await calendar.start();
    var notified = 0;
    calendar.addListener(() => notified++);
    await contacts.setHidden('cal-a', true);
    await Future<void>.delayed(_poll * 3);
    expect(calendar.isHidden('cal-a'), isTrue);
    expect(notified, 1); // later reads that find nothing new stay quiet
    contacts.dispose();
    calendar.dispose();
  });

  test('a change merges with what another app stored meanwhile', () async {
    final store = MemoryDeviceStore();
    final a = CalendarVisibility(store: store, pollInterval: const Duration(hours: 1));
    final b = CalendarVisibility(store: store, pollInterval: const Duration(hours: 1));
    await a.start();
    await b.start();
    await a.setHidden('cal-a', true);
    await b.setHidden('cal-b', true); // b has not re-read yet
    expect((await store.read())['hiddenCalendars'], ['cal-a', 'cal-b']);
    a.dispose();
    b.dispose();
  });

  test('a read that started before a change cannot undo it when it finishes after', () async {
    final store = SlowStore()..gate = Completer<void>();
    final v = CalendarVisibility(store: store, pollInterval: const Duration(hours: 1));
    final starting = v.start(); // reads the empty store, held back
    await Future<void>.delayed(Duration.zero);
    final change = v.setHidden('cal-a', true); // made while that read is held
    store.gate!.complete();
    store.gate = null;
    await starting;
    await change;
    expect(v.isHidden('cal-a'), isTrue);
    expect((await store.read())['hiddenCalendars'], ['cal-a']);
    v.dispose();
  });

  test('junk in the store is ignored', () async {
    final v = _visibility(MemoryDeviceStore({
      'hiddenCalendars': ['cal-a', 3, null, '', 'x' * 300],
    }));
    await v.start();
    expect(v.hidden, {'cal-a'});
    v.dispose();
    final w = _visibility(MemoryDeviceStore({'hiddenCalendars': 'cal-a'}));
    await w.start();
    expect(w.hidden, isEmpty);
    w.dispose();
  });

  test('the hidden set cannot be changed from outside', () async {
    final v = _visibility(MemoryDeviceStore({'hiddenCalendars': ['cal-a']}));
    await v.start();
    expect(() => v.hidden.add('cal-b'), throwsUnsupportedError);
    v.dispose();
  });

  test('a write that fails is reported, the switch shows what is stored, and later changes are still written',
      () async {
    final store = FlakyStore({'mode': 'dark'});
    final v = CalendarVisibility(store: store, pollInterval: const Duration(hours: 1));
    await v.start();
    store.failing = true;
    await expectLater(v.setHidden('cal-a', true), throwsA(isA<FileSystemException>()));
    expect(v.isHidden('cal-a'), isFalse, reason: 'not stored, so not shown as hidden');
    store.failing = false;
    await v.setHidden('cal-b', true);
    expect(v.hidden, {'cal-b'});
    expect(await store.read(), {'mode': 'dark', 'hiddenCalendars': ['cal-b']});
    v.dispose();
  });

  test('a poll while a change is being written does not undo it', () async {
    final store = FlakyStore()..writeGate = Completer<void>();
    final v = _visibility(store);
    await v.start();
    final change = v.setHidden('cal-a', true);
    await Future<void>.delayed(_poll * 4); // several polls read the store, which still says nothing is hidden
    expect(v.isHidden('cal-a'), isTrue);
    store.writeGate!.complete();
    await change;
    await Future<void>.delayed(_poll * 2);
    expect(v.isHidden('cal-a'), isTrue);
    v.dispose();
  });

  group('through the device file', () {
    late Directory dir;
    late File file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('mydata-visibility-');
      file = File('${dir.path}/device/settings.json')..createSync(recursive: true);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test("a theme another app stores while a calendar is hidden is kept", () async {
      file.writeAsStringSync('{"mode": "dark"}');
      final store = FileDeviceStore(() => file.path);
      final v = _visibility(store);
      await v.start();
      var first = true;
      // the theme lands between this change's read and its write
      final racing = _RacingStore(store, () {
        if (!first) return;
        first = false;
        file.writeAsStringSync('{"mode": "dark", "themes": {"everywhere": {"theme": "mydata.system"}}}');
      });
      final w = _visibility(racing);
      await w.setHidden('cal-a', true);
      expect(jsonDecode(file.readAsStringSync()), {
        'mode': 'dark',
        'themes': {
          'everywhere': {'theme': 'mydata.system'},
        },
        'hiddenCalendars': ['cal-a'],
      });
      v.dispose();
      w.dispose();
    });

    test('a settings file that cannot be read is never written over with only the hidden calendars', () async {
      file.writeAsStringSync('{"mode": "dark", "themes": ');
      final v = _visibility(FileDeviceStore(() => file.path));
      await v.start();
      await expectLater(v.setHidden('cal-a', true), throwsA(isA<DeviceStoreUnreadable>()));
      expect(file.readAsStringSync(), '{"mode": "dark", "themes": ');
      v.dispose();
    });
  });
}

/// [inner], calling [during] inside each update's change, as another app writing at that moment.
class _RacingStore extends DeviceStore {
  _RacingStore(this.inner, this.during);
  final DeviceStore inner;
  final void Function() during;

  @override
  Future<Map<String, Object?>> read() => inner.read();

  @override
  Future<void> write(Map<String, Object?> values) => inner.write(values);

  @override
  Future<Map<String, Object?>> update(Map<String, Object?> Function(Map<String, Object?> values) change) =>
      inner.update((now) {
        during();
        return change(now);
      });
}
