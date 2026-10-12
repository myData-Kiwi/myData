import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:myassistant/src/app.dart';

/// A platform with no host: either unsupported (the web build) or with no start command configured.
class NoHostPlatform implements HostPlatform {
  NoHostPlatform({required this.supported});

  @override
  final bool supported;
  int environments = 0;

  @override
  String get unsupportedReason => 'The web version needs the desktop app.';

  @override
  Future<HostEnvironment> environment() async {
    environments++;
    return const HostEnvironment(home: '/tmp/mydata', baseUrl: 'http://127.0.0.1:1', hostCommand: null);
  }

  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => null;

  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(false, '');

  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

void main() {
  testWidgets('without a start command: the error, its detail, and Retry that tries again', (tester) async {
    final platform = NoHostPlatform(supported: true);
    await tester.pumpWidget(
      MyAssistantApp(
        host: HostController(app: 'myassistant', platform: platform),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('myAssistant'), findsOneWidget);
    expect(find.text('The myData host is not set up'), findsOneWidget);
    expect(find.textContaining('uv run mydata dev-setup'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(platform.environments, 2);
  });

  testWidgets('the web build explains that the desktop app is needed', (tester) async {
    final host = HostController(app: 'myassistant', platform: NoHostPlatform(supported: false));
    await tester.pumpWidget(MyAssistantApp(host: host));
    await tester.pumpAndSettle();
    expect(find.text('myAssistant needs the desktop app'), findsOneWidget);
    expect(find.text('The web version needs the desktop app.'), findsOneWidget);
  });
}
