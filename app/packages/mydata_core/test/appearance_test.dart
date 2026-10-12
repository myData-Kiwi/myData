import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

class _Host extends ChangeNotifier {
  String? theme;
  void set(String t) {
    theme = t;
    notifyListeners();
  }
}

AppearanceController _controller(_Host host, DeviceStore store, {List<String>? puts}) => AppearanceController(
      hostChanges: host,
      hostTheme: () => host.theme,
      putTheme: (id) async {
        puts?.add(id);
        host.set(id);
        return id;
      },
      store: store,
      pollInterval: const Duration(milliseconds: 20),
    );

void main() {
  test('before the host answers, the last theme seen on this device is used; then the host wins', () async {
    final store = MemoryDeviceStore({'lastTheme': 'plum', 'mode': 'dark'});
    final host = _Host();
    final a = _controller(host, store);
    await a.start();
    expect(a.theme.spec.id, 'plum');
    expect(a.theme.themeMode.name, 'dark');
    host.set('dusk');
    expect(a.themeId, 'dusk');
    await Future<void>.delayed(Duration.zero);
    expect((await store.read())['lastTheme'], 'dusk');
    a.dispose();
  });

  test('a theme chosen in one app reaches another app through the host, without a restart', () async {
    final host = _Host()..theme = 'kiwi';
    final store = MemoryDeviceStore();
    final mydata = _controller(host, store);
    final assistant = _controller(host, store);
    await mydata.start();
    await assistant.start();
    var repaints = 0;
    assistant.addListener(() => repaints++);
    await mydata.setTheme('graphite');
    expect(assistant.themeId, 'graphite');
    expect(repaints, greaterThan(0));
    mydata.dispose();
    assistant.dispose();
  });

  test('the mode is per device: set in one app, the other app follows on its next read', () async {
    final host = _Host()..theme = 'kiwi';
    final store = MemoryDeviceStore();
    final mydata = _controller(host, store);
    final assistant = _controller(host, store);
    await mydata.start();
    await assistant.start();
    expect(assistant.mode, MyDataMode.system);
    await mydata.setMode(MyDataMode.light);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(assistant.mode, MyDataMode.light);
    // the theme write does not undo the other app's mode
    await assistant.setTheme('rose');
    expect((await store.read())['mode'], 'light');
    mydata.dispose();
    assistant.dispose();
  });

  test('a theme the host refuses does not change what is on screen', () async {
    final host = _Host()..theme = 'kiwi';
    final a = AppearanceController(
        hostChanges: host,
        hostTheme: () => host.theme,
        putTheme: (id) async => throw ApiException(400, 'no such theme'),
        store: MemoryDeviceStore());
    await a.start();
    await expectLater(a.setTheme('nope'), throwsA(isA<ApiException>()));
    expect(a.themeId, 'kiwi');
    a.dispose();
  });
}
