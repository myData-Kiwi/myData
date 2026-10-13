// Screenshots of the main screens in Kiwi and Graphite, light and dark (test/screenshots/), rendered through
// the app's own MaterialApp wiring against a fake host. Refresh with `flutter test --update-goldens`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/sources_section.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';

import 'fixtures.dart';

/// The case being rendered, for the `before` steps.
late ThemeCase current;

/// The app on [host], in [t]'s theme (stored on the host) and mode (stored on this device).
Widget app(FakeHost host, ThemeCase t) {
  current = t;
  host.theme = t.themeId;
  return MyDataApp(
    controller: host.controller(),
    store: MemoryDeviceStore({'mode': t.brightness.name, 'lastTheme': t.themeId}),
    macSystem: FakeMacSystem(),
  );
}

// Timestamps here have no offset, so they parse as local time and formatWhen's toLocal() changes nothing:
// the screenshots read the same in every time zone. The host itself sends UTC ("...Z").
List<AgentOut> get agents => [
  agentWith('Claude on my laptop', connected: true, lastSeenAt: '2026-10-12T08:05:00'),
  agentWith('Notes sync script', lastSeenAt: '2026-10-09T17:40:00'),
  agentWith('Old test agent', revoked: true),
];

StatusOut get running => statusWith(
  ModelOutStateEnum.ready,
  modelBytes: 9300000000,
  lastError: ErrorOut(
    at: '2026-10-12T07:58:00',
    logger: 'mydata.tools',
    message: 'search_mail: the mail index is not built yet',
  ),
)..uptimeSeconds = 8040;

void main() {
  screenMatrix(
    'setup_choose_theme',
    (t) => app(FakeHost(chosen: false), t),
    before: (tester) async {
      await settle(tester);
      // Graphite cases show the step after picking Graphite: the screen previews the pick at once.
      if (current.themeId == 'graphite') await tester.tap(find.text('Graphite'));
      await settle(tester);
    },
  );

  screenMatrix(
    'setup_preparing',
    (t) => app(
      FakeHost(
        status: statusWith(
          ModelOutStateEnum.pulling,
          progress: Progress(completed: 4200000000, total: 9300000000, percent: 45, status: 'pulling'),
        ),
      ),
      t,
    ),
    before: settle,
  );

  screenMatrix('status', (t) => app(FakeHost(status: running, agents: agents), t), before: settle);

  screenMatrix(
    'settings',
    (t) => app(FakeHost(status: running, agents: agents), t),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
    },
  );

  // The bottom of Settings: the agent tokens.
  screenMatrix(
    'settings_agents',
    (t) => app(FakeHost(status: running, agents: agents), t),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text('Old test agent'));
      await settle(tester);
    },
  );

  // First run on a Mac host, after the theme: use the contacts and calendars on this Mac?
  screenMatrix(
    'setup_this_mac',
    (t) => app(FakeHost(mac: macSource(enabled: false, decided: false)), t),
    before: settle,
  );

  // Settings, Sources on a Mac: This Mac on, contacts allowed, calendars turned off in System Settings.
  screenMatrix(
    'settings_sources',
    (t) => app(
      FakeHost(
        status: running..macAvailable = true,
        agents: agents,
        mac: macSource(calendars: 'denied'),
      ),
      t,
    ),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text(SourcesSections.heading));
      await settle(tester);
    },
  );

  // Settings, Advanced on a Mac: following an iCloud account, with one account synced and one failing.
  screenMatrix(
    'settings_sources_advanced',
    (t) => app(
      FakeHost(
        status: running..macAvailable = true,
        agents: agents,
        mac: macSource(),
        accounts: [
          icloudSource('sam@example.com'),
          icloudSource(
            'ava@example.org',
            lastError:
                'Apple did not accept this sign-in. Use the email of your Apple Account, which may '
                'differ from an address on your own domain, and an app-specific password made at '
                'account.apple.com.',
          ),
        ],
      ),
      t,
    ),
    before: (tester) async {
      await settle(tester);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      await tester.ensureVisible(find.text(SourcesSections.advancedHeading));
      await settle(tester);
    },
  );
}
