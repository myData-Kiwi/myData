import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/agent_list.dart';
import 'package:mydata/src/app.dart';
import 'package:mydata/src/status_screen.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

/// A platform with no local host, like the web build.
class _NoHostPlatform implements HostPlatform {
  @override
  bool get supported => false;
  @override
  String get unsupportedReason => 'Open the myData desktop app instead.';
  @override
  Future<HostEnvironment> environment() => throw UnsupportedError(unsupportedReason);
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => null;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(false, '');
  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

void main() {
  testWidgets('an unsupported platform shows why, with Retry', (tester) async {
    final controller = HostController(app: 'mydata', platform: _NoHostPlatform());
    await controller.connect();
    await tester.pumpWidget(MyDataApp(controller: controller));
    await tester.pump();
    expect(find.text('Use the desktop app'), findsOneWidget);
    expect(find.text('Open the myData desktop app instead.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('the Status screen shows the host, the model, memory and errors', (tester) async {
    final controller = HostController(app: 'mydata', platform: _NoHostPlatform());
    final agents = AgentList(controller);
    final status = statusWith(ModelOutStateEnum.ready)
      ..memory = MemoryOut(hostBytes: 120000000, modelBytes: 9300000000);
    await tester.pumpWidget(
      MaterialApp(
        theme: legacyTheme(),
        home: Scaffold(
          body: StatusScreen(status: status, agents: agents),
        ),
      ),
    );
    expect(find.text('0.1.0'), findsOneWidget);
    expect(find.text('qwen3:14b is ready'), findsOneWidget);
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('demo date'), findsOneWidget);
    expect(find.text('18 Mar 2026'), findsOneWidget);
    expect(find.text('120 MB'), findsOneWidget);
    expect(find.text('9.3 GB'), findsOneWidget);
    expect(find.text('none'), findsOneWidget);
    agents.dispose();
    controller.dispose();
  });
}
