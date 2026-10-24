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

const journalPlum = ThemeChoice('mydata.journal', 'plum');
const frostedDusk = ThemeChoice('mydata.frosted', 'dusk');

/// Kiwi's other palettes: Kiwi's fonts are always loaded, so these are drawn at once.
const kiwiSky = ThemeChoice(ThemeLibrary.kiwiId, 'sky');
const kiwiViolet = ThemeChoice(ThemeLibrary.kiwiId, 'violet');

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
      const s = ThemeSettings(everywhere: frostedDusk, apps: {'mycontacts': journalPlum});
      expect(s.choiceFor('mycontacts'), journalPlum);
      expect(s.choiceFor('mycalendar'), frostedDusk);
      expect(s.followsEverywhere('mycalendar'), isTrue);
      expect(s.followsEverywhere('mycontacts'), isFalse);
      expect(const ThemeSettings().choiceFor('mycalendar'), ThemeChoice.system);
    });

    test('a hand-edited file: entries that are not choices are skipped', () {
      final s = ThemeSettings.fromJson({
        'everywhere': {'theme': 42},
        'apps': {
          'mycontacts': {'theme': 'mydata.kiwi', 'palette': 'sky'},
          'mycalendar': 'kiwi',
          'myassistant': {'palette': 'rose'},
        },
      })!;
      expect(s.everywhere, isNull);
      expect(s.apps, {'mycontacts': const ThemeChoice('mydata.kiwi', 'sky')});
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
      await c.use(journalPlum, app: 'mycalendar');
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
      await contacts.use(journalPlum, app: 'myassistant');
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

    for (final colour in ['graphite', 'dusk', 'plum', 'rose', 'amber']) {
      test('elsewhere $colour becomes the theme it moved to, in $colour, everywhere, with its colours', () async {
        final store = MemoryDeviceStore({'lastTheme': colour});
        final c = _controller(store);
        await c.start();
        final want = ThemeLibrary.movedColours[colour]!;
        expect(c.choice, want);
        // the device drew Kiwi in that colour before, so myData's Appearance says it moved, once
        expect(await _themes(store), {
          'everywhere': want.toJson(),
          'moved': [colour],
        });
        expect(c.settings.moved, [colour]);
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

    for (final (where, store, host) in [
      ('lastTheme', () => MemoryDeviceStore({'lastTheme': 'kiwi'}), null),
      ('the host', MemoryDeviceStore.new, _Host()..answer('kiwi')),
    ]) {
      test("elsewhere the host's default colour, which a host where nobody chose reports, seeds System (from $where)", () async {
        final s = store();
        final c = _controller(s, host: host);
        await c.start();
        expect(c.choice, ThemeChoice.system);
        expect(await _themes(s), {
          'everywhere': {'theme': 'mydata.system'},
        });
        // which draws exactly what Kiwi in Kiwi drew, until this platform's own pass
        for (final b in Brightness.values) {
          final before = MyDataTheme.data('kiwi', b).extension<MyDataColors>()!;
          final now = (b == Brightness.dark ? c.theme.dark : c.theme.light).extension<MyDataColors>()!;
          expect([now.accent, now.bg, now.ink, now.focus], [before.accent, before.bg, before.ink, before.focus]);
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
      expect(c.choice, frostedDusk);
      expect(await _themes(store), {
        'everywhere': frostedDusk.toJson(),
        'moved': ['dusk'],
      });
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
          'apps': {'mycalendar': frostedDusk.toJson()},
        },
      });
      final host = _Host()..answer('rose');
      final c = _controller(store, host: host);
      await c.start();
      expect(c.choice, ThemeChoice.system);
      expect(await _themes(store), {
        'apps': {'mycalendar': frostedDusk.toJson()},
      });
      c.dispose();
    });

    test('two apps starting together seed the file once and agree', () async {
      final store = MemoryDeviceStore({'lastTheme': 'amber'});
      final a = _controller(store);
      final b = _controller(store, app: 'mycalendar');
      await Future.wait([a.start(), b.start()]);
      expect(a.choice, const ThemeChoice('mydata.paperback', 'amber'));
      expect(b.choice, const ThemeChoice('mydata.paperback', 'amber'));
      a.dispose();
      b.dispose();
    });
  });

  group('the old colours move to their themes (phase 3)', () {
    test('Kiwi in an old colour, everywhere or for an app, is written as that colour\'s theme, and listed', () {
      final raw = {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum', 'contrast': 'more'},
        'apps': {
          'mycontacts': {'theme': 'mydata.kiwi', 'palette': 'rose'},
          'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'sky'},
          'myassistant': {'theme': 'mydata.system'},
          'mynotes': {'custom': 'later-format'},
        },
        'library': ['someone.neon'],
        'moved': ['amber'],
      };
      expect(ThemeSettings.movedOver(raw), {
        // a choice of another theme starts afresh, as its palette does
        'everywhere': {'theme': 'mydata.journal', 'palette': 'plum'},
        'apps': {
          'mycontacts': {'theme': 'mydata.sticker', 'palette': 'rose'},
          'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'sky'},
          'myassistant': {'theme': 'mydata.system'},
          'mynotes': {'custom': 'later-format'},
        },
        'library': ['someone.neon'],
        'moved': ['amber', 'plum', 'rose'],
      });
      expect(ThemeSettings.movedOver({'everywhere': {'theme': 'mydata.kiwi', 'palette': 'kiwi'}}), isNull);
      expect(ThemeSettings.movedOver({'everywhere': journalPlum.toJson()}), isNull);
      expect(ThemeSettings.movedOver(null), isNull);
      expect(ThemeSettings.fromJson({'moved': ['plum', 'teal', 3]})!.moved, ['plum']);
    });

    test('a stored Kiwi in Plum is drawn as Journal in Plum at once, never Kiwi in Kiwi, and written so', () async {
      final store = MemoryDeviceStore({
        'mode': 'dark',
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum'},
          'apps': {'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'graphite'}},
        },
      });
      // on a Mac too: phase 2's gallery offered Kiwi in the old colours there
      final c = _controller(store, mac: true);
      final calendar = _controller(store, app: 'mycalendar', mac: true);
      await Future.wait([c.start(), calendar.start()]);
      expect(ThemeLibrary.normalise(c.choice), journalPlum);
      expect(c.theme.choice, journalPlum);
      expect(calendar.theme.choice, const ThemeChoice('mydata.hairline', 'graphite'));
      expect(await _themes(store), {
        'everywhere': journalPlum.toJson(),
        'apps': {'mycalendar': {'theme': 'mydata.hairline', 'palette': 'graphite'}},
        'moved': ['plum', 'graphite'],
      });
      expect((await store.read())['mode'], 'dark');
      c.dispose();
      calendar.dispose();
    });

    test('an older build writing Kiwi in an old colour again is moved again when read', () async {
      final store = MemoryDeviceStore({'themes': {'everywhere': journalPlum.toJson()}});
      final c = _controller(store, mac: true);
      await c.start();
      expect(c.settings.moved, isEmpty);
      await store.write({
        'themes': {'everywhere': {'theme': 'mydata.kiwi', 'palette': 'dusk'}},
      });
      await _until(() => c.choice == frostedDusk);
      expect(c.settings.moved, ['dusk']);
      c.dispose();
    });

    test('once told, the moved colours are taken off the list; what else is there is kept', () async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'plum'},
          'apps': {'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'rose'}},
          'library': ['someone.neon'],
        },
      });
      final c = _controller(store, mac: true);
      await c.start();
      expect(c.settings.moved, ['plum', 'rose']);
      await c.acknowledgeMoved(['plum']);
      expect(c.settings.moved, ['rose']);
      expect((await _themes(store))!['moved'], ['rose']);
      await c.acknowledgeMoved(['rose']);
      expect(c.settings.moved, isEmpty);
      expect(await _themes(store), {
        'everywhere': journalPlum.toJson(),
        'apps': {'mycalendar': {'theme': 'mydata.sticker', 'palette': 'rose'}},
        'library': ['someone.neon'],
      });
      c.dispose();
    });
  });

  group('choosing', () {
    test('Use in this app stores the theme and palette for this app only; the mode is kept', () async {
      final store = MemoryDeviceStore({'mode': 'dark', 'lastTheme': 'dusk'});
      final c = _controller(store);
      await c.start();
      await c.use(journalPlum);
      expect(c.choice, journalPlum);
      final themes = await _themes(store);
      expect(themes!['apps'], {'mycontacts': journalPlum.toJson()});
      expect(themes['everywhere'], frostedDusk.toJson());
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
      await c.use(journalPlum);
      await c.use(frostedDusk, app: 'mycalendar');
      final before = c.settings;
      final undo = await c.useEverywhere(const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
      expect(undo.before, before);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'sky'},
      });
      expect(c.settings.choiceFor('mycalendar'), const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
      expect(c.settings.choiceFor('a-later-app'), const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
      expect(await c.restore(undo), isTrue);
      expect(c.settings, before);
      expect(c.choice, journalPlum);
      c.dispose();
    });

    test('Undo of Use everywhere keeps the choices made since, in this app or another', () async {
      final store = MemoryDeviceStore();
      final contacts = _controller(store, mac: true);
      final mydata = _controller(store, app: 'mydata', mac: true);
      await contacts.start();
      await mydata.start();
      await contacts.use(journalPlum);
      await contacts.use(frostedDusk, app: 'mycalendar');
      await contacts.use(frostedDusk, app: 'myassistant');
      final undo = await contacts.useEverywhere(const ThemeChoice(ThemeLibrary.kiwiId, 'sky'));
      // then, in myData's Appearance: myAssistant gets its own theme
      await mydata.use(const ThemeChoice(ThemeLibrary.kiwiId, 'violet'), app: 'myassistant');
      expect(await contacts.restore(undo), isTrue);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.system'},
        'apps': {
          'mycontacts': journalPlum.toJson(),
          'mycalendar': frostedDusk.toJson(),
          'myassistant': {'theme': 'mydata.kiwi', 'palette': 'violet'},
        },
      });
      contacts.dispose();
      mydata.dispose();
    });

    test('Undo of Use everywhere puts nothing back once everywhere was changed again', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      await c.use(journalPlum);
      final undo = await c.useEverywhere(frostedDusk);
      await c.useEverywhere(const ThemeChoice(ThemeLibrary.kiwiId, 'violet'));
      final now = await _themes(store);
      expect(await c.restore(undo), isFalse);
      expect(await _themes(store), now);
      c.dispose();
    });

    test('Use everywhere and its Undo leave the preview on: the gallery is still open', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      c.preview(journalPlum);
      final undo = await c.useEverywhere(journalPlum);
      c.preview(frostedDusk);
      await c.restore(undo);
      expect(c.previewing, frostedDusk);
      expect(c.choice, frostedDusk);
      c.dispose();
    });

    test("a write keeps what this build does not know under themes: later builds' keys and fields", () async {
      final store = MemoryDeviceStore({
        'themes': {
          'everywhere': {'theme': 'mydata.kiwi', 'palette': 'sky', 'contrast': 'more'},
          'apps': {
            'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'violet', 'density': 'compact'},
            'mynotes': {'custom': 'later-format'},
          },
          'library': ['someone.neon'],
        },
      });
      final c = _controller(store, mac: true);
      await c.start();
      // a palette change keeps a choice's other fields; a new theme starts afresh
      await c.use(const ThemeChoice(ThemeLibrary.kiwiId, 'kiwi'), app: 'mycalendar');
      await c.use(ThemeChoice.system);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'sky', 'contrast': 'more'},
        'apps': {
          'mycalendar': {'theme': 'mydata.kiwi', 'palette': 'kiwi', 'density': 'compact'},
          'mynotes': {'custom': 'later-format'},
          'mycontacts': {'theme': 'mydata.system'},
        },
        'library': ['someone.neon'],
      });
      await c.use(ThemeChoice.system, app: 'mycalendar');
      expect((await _themes(store))!['apps'], containsPair('mycalendar', {'theme': 'mydata.system'}));
      // Use everywhere clears every app's own, the ones this build cannot read too; Undo brings them back
      final undo = await c.useEverywhere(const ThemeChoice(ThemeLibrary.kiwiId, 'violet'));
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'violet', 'contrast': 'more'},
        'library': ['someone.neon'],
      });
      await c.restore(undo);
      expect(await _themes(store), {
        'everywhere': {'theme': 'mydata.kiwi', 'palette': 'sky', 'contrast': 'more'},
        'apps': {
          'mycalendar': {'theme': 'mydata.system'},
          'mynotes': {'custom': 'later-format'},
          'mycontacts': {'theme': 'mydata.system'},
        },
        'library': ['someone.neon'],
      });
      c.dispose();
    });

    test('Reset makes an app follow everywhere again', () async {
      final store = MemoryDeviceStore();
      final c = _controller(store, mac: true);
      await c.start();
      await c.use(journalPlum, app: 'mycalendar');
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
      c.preview(kiwiSky);
      expect(c.choice, kiwiSky);
      expect(c.theme.choice, kiwiSky);
      expect(c.stored, ThemeChoice.system);
      expect(await store.read(), stored);
      c.preview(null);
      expect(c.choice, ThemeChoice.system);
      c.preview(kiwiViolet);
      await c.use(kiwiViolet);
      // Use closes the gallery, so it ends the preview
      expect(c.previewing, isNull);
      expect(c.choice, kiwiViolet);
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
    await c.use(journalPlum);
    expect(c.choice, journalPlum);
    // the held read finishes with the file as it was before this app's write
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.choice, journalPlum);
    c.dispose();
  });

  group('a settings file that cannot be read', () {
    test('changes nothing on screen, and a choice fails without writing over it', () async {
      final dir = Directory.systemTemp.createTempSync('mydata-themes-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/device/settings.json')..createSync(recursive: true);
      file.writeAsStringSync('{"mode": "dark", "themes": {"everywhere": {"theme": "mydata.kiwi", "palette": "sky"}}}');
      final c = _controller(FileDeviceStore(() => file.path), mac: true, poll: const Duration(milliseconds: 20));
      await c.start();
      expect(c.choice, kiwiSky);
      expect(c.mode, MyDataMode.dark);
      var repaints = 0;
      c.addListener(() => repaints++);
      // a hand edit leaves it broken: the window keeps drawing what it drew, not System in match-system
      file.writeAsStringSync('{"mode": "dark", "themes": ');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.choice, kiwiSky);
      expect(c.mode, MyDataMode.dark);
      expect(repaints, 0);
      await expectLater(c.use(kiwiViolet), throwsA(isA<DeviceStoreUnreadable>()));
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
      await mydata.use(journalPlum, app: 'mycontacts');
      await _until(() => contacts.choice == journalPlum);
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
      await contacts.use(frostedDusk);
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
      await mydata.use(journalPlum, app: 'mycontacts');
      await _until(() => contacts.choice == journalPlum);
      await contacts.useEverywhere(frostedDusk);
      await _until(() => mydata.choice == frostedDusk);
      mydata.dispose();
      contacts.dispose();
    }, skip: Platform.isMacOS || Platform.isLinux || Platform.isWindows ? false : 'no folder events here');
  });
}
