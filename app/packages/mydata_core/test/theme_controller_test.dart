import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_core/src/file_device_store.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The host's deprecated status `theme`, as the migration reads it.
class _Host extends ChangeNotifier {
  String? theme;
  bool answered = false;

  void answer(String t) {
    theme = t;
    answered = true;
    notifyListeners();
  }
}

ThemeController _controller(
  DeviceStore store, {
  String app = 'mycontacts',
  bool mac = false,
  _Host? host,
  Duration poll = const Duration(milliseconds: 20),
}) => ThemeController(
  appId: app,
  store: store,
  pollInterval: poll,
  hostChanges: host,
  hostTheme: () => host?.theme,
  hostAnswered: () => host?.answered ?? false,
  macOS: mac,
);

const kiwiPlum = ThemeChoice(ThemeLibrary.kiwiId, 'plum');
const kiwiDusk = ThemeChoice(ThemeLibrary.kiwiId, 'dusk');

Future<Map<String, Object?>?> _themes(DeviceStore store) async =>
    (await store.read())[ThemeSettings.key] as Map<String, Object?>?;

/// Waits until [done] holds, for at most [within].
Future<void> _until(bool Function() done, {Duration within = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(within);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// A store whose next read waits for [gate], as a slow disk does, returning what the store held when the read
/// began.
class _SlowStore extends MemoryDeviceStore {
  _SlowStore();
  Completer<void>? gate;

  @override
  Future<Map<String, Object?>> read() async {
    final held = await super.read();
    final g = gate;
    if (g != null) await g.future;
    return held;
  }
}

void main() {
  group('resolution', () {
    test("an app draws its own choice, else everywhere's, else System", () {
      const s = ThemeSettings(everywhere: kiwiDusk, apps: {'mycontacts': kiwiPlum});
      expect(s.choiceFor('mycontacts'), kiwiPlum);
      expect(s.choiceFor('mycalendar'), kiwiDusk);
      expect(s.followsEverywhere('mycalendar'), isTrue);
      expect(s.followsEverywhere('mycontacts'), isFalse);
      expect(const ThemeSettings().choiceFor('mycalendar'), ThemeChoice.system);
    });

    test('a hand-edited file: entries that are not choices are skipped', () {
      final s = ThemeSettings.fromJson({
        'everywhere': {'theme': 42},
        'apps': {
          'mycontacts': {'theme': 'mydata.kiwi', 'palette': 'rose'},
          'mycalendar': 'kiwi',
          'myassistant': {'palette': 'rose'},
        },
      })!;
      expect(s.everywhere, isNull);
      expect(s.apps, {'mycontacts': const ThemeChoice('mydata.kiwi', 'rose')});
      expect(ThemeSettings.fromJson(null), isNull);
      expect(ThemeSettings.fromJson('System'), isNull);
    });

    test('System with a stray palette resolves as System, and loses it at the next write', () async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.system', 'palette': 'plum'},
        },
      });
      final c = _controller(store);
      await c.start();
      expect(c.theme.choice, ThemeChoice.system);
      expect(ThemeLibrary.lookFor(c.choice, Brightness.light).paletteId, isNull);
      await c.use(kiwiPlum, app: 'mycalendar');
      expect((await _themes(store))!['everywhere'], {'theme': 'mydata.system'});
      c.dispose();
    });

    test('an unknown theme draws System and an unknown palette the theme default', () async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'someone.neon'},
          'apps': {
            'mycontacts': {'theme': 'mydata.kiwi', 'palette': 'teal'},
          },
        },
      });
      final contacts = _controller(store);
      final calendar = _controller(store, app: 'mycalendar');
      await contacts.start();
      await calendar.start();
      expect(contacts.theme.choice, const ThemeChoice(ThemeLibrary.kiwiId, 'kiwi'));
      expect(calendar.theme.choice, ThemeChoice.system);
      // a choice this build does not know is kept as it was written (a later version's theme)
      await contacts.use(kiwiPlum, app: 'myassistant');
      expect((await _themes(store))!['everywhere'], {'theme': 'someone.neon'});
      contacts.dispose();
      calendar.dispose();
    });
  });

  group('migration from the host theme', () {
    test('on macOS every app starts on System, whatever the host held', () async {
      final store = MemoryDeviceStore({'lastTheme': 'plum', 'mode': 'dark'});
      final c = _controller(store, mac: true, host: _Host()..answer('plum'));
      await c.start();
      expect(c.migrated, isTrue);
      expect(c.choice, ThemeChoice.system);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.system'},
      });
      expect((await store.read())['mode'], 'dark');
      c.dispose();
    });

    for (final colour in ['kiwi', 'graphite', 'dusk', 'plum', 'rose', 'amber']) {
      test('elsewhere $colour becomes Kiwi in $colour everywhere, which draws exactly what $colour drew', () async {
        final store = MemoryDeviceStore({'lastTheme': colour});
        final c = _controller(store);
        await c.start();
        final want = ThemeChoice(ThemeLibrary.kiwiId, colour);
        expect(c.choice, want);
        expect(await _themes(store), {'everywhere': want.toJson()});
        for (final b in Brightness.values) {
          final before = MyDataTheme.data(colour, b).extension<MyDataColors>()!;
          final now = (b == Brightness.dark ? c.theme.dark : c.theme.light).extension<MyDataColors>()!;
          expect(
            [now.accent, now.onAccent, now.accentSoft, now.bg, now.surface, now.ink, now.focus, now.glassFill],
            [
              before.accent,
              before.onAccent,
              before.accentSoft,
              before.bg,
              before.surface,
              before.ink,
              before.focus,
              before.glassFill,
            ],
          );
        }
        c.dispose();
      });
    }

    test("elsewhere with no lastTheme, the host's theme is read once it answers; System until then", () async {
      final store = MemoryDeviceStore();
      final host = _Host();
      final c = _controller(store, host: host);
      await c.start();
      expect(c.migrated, isFalse);
      expect(c.choice, ThemeChoice.system);
      expect(await _themes(store), isNull);
      host.answer('dusk');
      await _until(() => c.migrated);
      expect(c.choice, kiwiDusk);
      expect(await _themes(store), {'everywhere': kiwiDusk.toJson()});
      c.dispose();
    });

    test('a theme the host does not know (a hand-edited state.json) migrates to System', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, host: _Host()..answer('neon'));
      await c.start();
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.system'},
      });
      c.dispose();
    });

    test('runs once: a device that has its themes is never seeded again', () async {
      final store = MemoryDeviceStore({
        'lastTheme': 'plum',
        'themes': {
          'apps': {'mycalendar': kiwiDusk.toJson()},
        },
      });
      final host = _Host()..answer('rose');
      final c = _controller(store, host: host);
      await c.start();
      expect(c.choice, ThemeChoice.system);
      expect(await _themes(store), {
        'apps': {'mycalendar': kiwiDusk.toJson()},
      });
      c.dispose();
    });

    test('two apps starting together seed the file once and agree', () async {
      final store = MemoryDeviceStore({'lastTheme': 'amber'});
      final a = _controller(store);
      final b = _controller(store, app: 'mycalendar');
      await Future.wait([a.start(), b.start()]);
      expect(a.choice, const ThemeChoice(ThemeLibrary.kiwiId, 'amber'));
      expect(b.choice, const ThemeChoice(ThemeLibrary.kiwiId, 'amber'));
      a.dispose();
      b.dispose();
    });
  });

  group('choosing', () {
    test('Use in this app stores the theme and palette for this app only; the mode is kept', () async {
      final store = MemoryDeviceStore({'mode': 'dark', 'lastTheme': 'kiwi'});
      final c = _controller(store);
      await c.start();
      await c.use(kiwiPlum);
      expect(c.choice, kiwiPlum);
      final themes = await _themes(store);
      expect(themes!['apps'], {'mycontacts': kiwiPlum.toJson()});
      expect(themes['everywhere'], const ThemeChoice(ThemeLibrary.kiwiId, 'kiwi').toJson());
      expect((await store.read())['mode'], 'dark');
      c.dispose();
    });

    test('Use in this app and Use everywhere never write a palette for System', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      await c.use(const ThemeChoice('mydata.system', 'plum'));
      expect((await _themes(store))!['apps'], {
        'mycontacts': {'theme': 'mydata.system'},
      });
      await c.useEverywhere(const ThemeChoice('mydata.system', 'plum'));
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.system'},
      });
      c.dispose();
    });

    test("Use everywhere carries the palette and clears each app's own; Undo puts them back", () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      await c.use(kiwiPlum);
      await c.use(kiwiDusk, app: 'mycalendar');
      final before = c.settings;
      final undo = await c.useEverywhere(const ThemeChoice(ThemeLibrary.kiwiId, 'rose'));
      expect(undo, before);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'rose'},
      });
      expect(c.settings.choiceFor('mycalendar'), const ThemeChoice(ThemeLibrary.kiwiId, 'rose'));
      expect(c.settings.choiceFor('a-later-app'), const ThemeChoice(ThemeLibrary.kiwiId, 'rose'));
      await c.restore(undo);
      expect(c.settings, before);
      expect(c.choice, kiwiPlum);
      c.dispose();
    });

    test("a write keeps what this build does not know under themes: later builds' keys and fields", () async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum', 'contrast': 'more'},
          'apps': {
            'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'dusk', 'density': 'compact'},
            'mynotes': {'custom': 'later-format'},
          },
          'library': ['someone.neon'],
        },
      });
      final c = _controller(store, mac: true);
      await c.start();
      // a palette change keeps a choice's other fields; a new theme starts afresh
      await c.use(const ThemeChoice(ThemeLibrary.kiwiId, 'rose'), app: 'mycalendar');
      await c.use(ThemeChoice.system);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum', 'contrast': 'more'},
        'apps': {
          'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'rose', 'density': 'compact'},
          'mynotes': {'custom': 'later-format'},
          'mycontacts': {'theme': 'mydata.system'},
        },
        'library': ['someone.neon'],
      });
      await c.use(ThemeChoice.system, app: 'mycalendar');
      expect((await _themes(store))!['apps'], containsPair('mycalendar', {'theme': 'mydata.system'}));
      // Use everywhere clears every app's own, the ones this build cannot read too
      await c.useEverywhere(kiwiDusk);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'dusk', 'contrast': 'more'},
        'library': ['someone.neon'],
      });
      c.dispose();
    });

    test('Reset makes an app follow everywhere again', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      await c.use(kiwiPlum, app: 'mycalendar');
      await c.reset('mycalendar');
      expect(c.settings.followsEverywhere('mycalendar'), isTrue);
      expect(c.settings.choiceFor('mycalendar'), ThemeChoice.system);
      c.dispose();
    });

    test('a preview draws a choice without storing it, and ends with a choice or null', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      final stored = await store.read();
      c.preview(kiwiPlum);
      expect(c.choice, kiwiPlum);
      expect(c.theme.choice, kiwiPlum);
      expect(c.stored, ThemeChoice.system);
      expect(await store.read(), stored);
      c.preview(null);
      expect(c.choice, ThemeChoice.system);
      c.preview(kiwiDusk);
      await c.use(kiwiDusk);
      expect(c.previewing, isNull);
      expect(c.choice, kiwiDusk);
      c.dispose();
    });
  });

  test('a read that finishes after this app wrote is dropped: the old choice never comes back', () async {
    final store = _SlowStore();
    final c = _controller(store, mac: true, poll: const Duration(hours: 1));
    await c.start();
    expect(c.choice, ThemeChoice.system);
    // another app writes something else; this app's read of it is held by a slow disk
    final gate = Completer<void>();
    store.gate = gate;
    await store.write({
      ...await MemoryDeviceStore().read(),
      'hiddenCalendars': ['x'],
      'themes': c.settings.toJson(),
    });
    await Future<void>.delayed(Duration.zero);
    store.gate = null;
    await c.use(kiwiPlum);
    expect(c.choice, kiwiPlum);
    // the held read finishes with the file as it was before this app's write
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.choice, kiwiPlum);
    c.dispose();
  });

  group('a settings file that cannot be read', () {
    test('changes nothing on screen, and a choice fails without writing over it', () async {
      final dir = Directory.systemTemp.createTempSync('mydata-themes-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/device/settings.json')..createSync(recursive: true);
      file.writeAsStringSync('{"mode": "dark", "themes": {"everywhere": {"theme": "mydata.kiwi", "palette": "plum"}}}');
      final c = _controller(FileDeviceStore(() => file.path), mac: true, poll: const Duration(milliseconds: 20));
      await c.start();
      expect(c.choice, kiwiPlum);
      expect(c.mode, MyDataMode.dark);
      var repaints = 0;
      c.addListener(() => repaints++);
      // a hand edit leaves it broken: the window keeps drawing what it drew, not System in match-system
      file.writeAsStringSync('{"mode": "dark", "themes": ');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.choice, kiwiPlum);
      expect(c.mode, MyDataMode.dark);
      expect(repaints, 0);
      await expectLater(c.use(kiwiDusk), throwsA(isA<DeviceStoreUnreadable>()));
      await expectLater(c.setMode(MyDataMode.light), throwsA(isA<DeviceStoreUnreadable>()));
      expect(c.mode, MyDataMode.dark, reason: 'the mode that could not be stored is not drawn');
      expect(file.readAsStringSync(), '{"mode": "dark", "themes": ');
      c.dispose();
    });
  });

  group('two apps on one device', () {
    test('a choice made in myData reaches myContacts without a restart', () async {
      final store = MemoryDeviceStore();
      final mydata = _controller(store, app: 'mydata', mac: true, poll: const Duration(hours: 1));
      final contacts = _controller(store, mac: true, poll: const Duration(hours: 1));
      await mydata.start();
      await contacts.start();
      var repaints = 0;
      contacts.addListener(() => repaints++);
      await mydata.use(kiwiPlum, app: 'mycontacts');
      await _until(() => contacts.choice == kiwiPlum);
      expect(repaints, greaterThan(0));
      expect(mydata.choice, ThemeChoice.system);
      mydata.dispose();
      contacts.dispose();
    });

    test("the mode is per device: set in one app, the other follows, and a theme write keeps it", () async {
      final store = MemoryDeviceStore();
      final mydata = _controller(store, app: 'mydata', mac: true);
      final contacts = _controller(store, mac: true);
      await mydata.start();
      await contacts.start();
      await mydata.setMode(MyDataMode.light);
      await _until(() => contacts.mode == MyDataMode.light);
      await contacts.use(kiwiDusk);
      expect((await store.read())['mode'], 'light');
      mydata.dispose();
      contacts.dispose();
    });

    test('through the device file: the folder watch carries a change between two apps', () async {
      final dir = Directory.systemTemp.createTempSync('mydata-themes-');
      addTearDown(() => dir.deleteSync(recursive: true));
      String path() => '${dir.path}/device/settings.json';
      // An hour's poll: only the file system's events can carry the change in time.
      final mydata = _controller(FileDeviceStore(path), app: 'mydata', mac: true, poll: const Duration(hours: 1));
      final contacts = _controller(FileDeviceStore(path), mac: true, poll: const Duration(hours: 1));
      await mydata.start();
      await contacts.start();
      // let the folder watches start
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await mydata.use(kiwiPlum, app: 'mycontacts');
      await _until(() => contacts.choice == kiwiPlum);
      await contacts.useEverywhere(kiwiDusk);
      await _until(() => mydata.choice == kiwiDusk);
      mydata.dispose();
      contacts.dispose();
    }, skip: Platform.isMacOS || Platform.isLinux || Platform.isWindows ? false : 'no folder events here');
  });
}
