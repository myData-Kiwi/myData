import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';

import 'links_test.dart' show FakeRunner;

/// Answers the lookup for the bundle ids in [present] only.
class Installed {
  Installed(this.present);
  Set<String> present;
  int lookups = 0;

  Future<CommandResult> call(String executable, List<String> arguments) async {
    lookups++;
    final id = arguments.last;
    return CommandResult(0, present.contains(id) ? '/Applications/$id.app' : '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nothing counts as installed until the first answer, then the apps found', () async {
    final run = Installed({'kiwi.mydata.mycontacts'});
    final apps = InstalledApps(
      apps: const [MyDataAppId.mycontacts, MyDataAppId.mycalendar],
      links: AppLinks(run: run.call, macOS: true),
    );
    addTearDown(apps.dispose);
    var notified = 0;
    apps.addListener(() => notified++);
    expect(apps.checked, isFalse);
    expect(apps.isInstalled(MyDataAppId.mycontacts), isFalse);
    await apps.start();
    expect(apps.checked, isTrue);
    expect(apps.installed, {MyDataAppId.mycontacts});
    expect(run.lookups, 2);
    expect(notified, 1);

    await apps.refresh(); // the same answer: no rebuild
    expect(notified, 1);
  });

  test('looks again when the app comes back to the front, and only then', () async {
    final run = Installed({});
    final apps = InstalledApps(
      apps: const [MyDataAppId.mycalendar],
      links: AppLinks(run: run.call, macOS: true),
    );
    addTearDown(apps.dispose);
    await apps.start();
    expect(apps.isInstalled(MyDataAppId.mycalendar), isFalse);
    expect(run.lookups, 1);

    run.present = {'kiwi.mydata.mycalendar'};
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(run.lookups, 1); // losing the front asks nothing
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(run.lookups, 2);
    expect(apps.isInstalled(MyDataAppId.mycalendar), isTrue);
  });

  test('off macOS nothing is installed and nothing is run', () async {
    final run = FakeRunner(answer: const CommandResult(0, '/Applications/x.app'));
    final apps = InstalledApps(
      apps: MyDataAppId.values,
      links: AppLinks(run: run.call, macOS: false),
    );
    addTearDown(apps.dispose);
    await apps.start();
    expect(apps.checked, isTrue);
    expect(apps.installed, isEmpty);
    expect(run.calls, isEmpty);
  });

  test('uses the shared appLinks when none is given', () async {
    final run = Installed({'kiwi.mydata.myassistant'});
    final saved = appLinks;
    appLinks = AppLinks(run: run.call, macOS: true);
    addTearDown(() => appLinks = saved);
    final apps = InstalledApps(apps: const [MyDataAppId.myassistant]);
    addTearDown(apps.dispose);
    await apps.refresh();
    expect(apps.installed, {MyDataAppId.myassistant});
  });
}
