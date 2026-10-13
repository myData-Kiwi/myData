import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mydata_core/mydata_core.dart';

/// A host status with the model in [state], built with the generated constructors.
StatusOut statusWith(
  ModelOutStateEnum state, {
  Progress? progress,
  String? error,
  bool enabled = true,
  int? modelBytes,
  ErrorOut? lastError,
  bool macAvailable = false,
}) => StatusOut(
  agentsConnected: 0,
  macAvailable: macAvailable,
  assistantEnabled: enabled,
  conversationEpoch: 0,
  demoDate: true,
  lastError: lastError,
  memory: MemoryOut(hostBytes: 120000000, modelBytes: modelBytes),
  model: ModelOut(
    name: 'qwen3:14b',
    state: state,
    loaded: state == ModelOutStateEnum.ready,
    ollamaReachable: state != ModelOutStateEnum.ollamaMissing,
    ollamaStartedByHost: true,
    progress: progress,
    error: error,
  ),
  mode: StatusOutModeEnum.demo,
  ready: state == ModelOutStateEnum.ready,
  theme: 'kiwi',
  today: '2026-03-18',
  uptimeSeconds: 12,
  version: '0.1.0',
);

/// An agent token as the host lists it.
AgentOut agentWith(String name, {bool connected = false, bool revoked = false, String? lastSeenAt}) => AgentOut(
  id: 'id-${name.toLowerCase().replaceAll(' ', '-')}',
  name: name,
  connected: connected,
  revoked: revoked,
  // No offset: parsed as local time, so screens show 09:30 in every time zone (see screenshots_test.dart).
  createdAt: '2026-10-01T09:30:00',
  lastSeenAt: lastSeenAt,
);

/// This Mac as GET /sources shows it, with invented accounts and calendars. [contacts] and [calendars] are
/// the system's access statuses; [enabled] false clears what it read, as the host does.
SourceOut macSource({
  bool enabled = true,
  bool decided = true,
  String contacts = 'authorized',
  String calendars = 'fullAccess',
  Set<String> leftOut = const {},
  String? lastError,
  SyncCounts? counts,
}) => SourceOut(
  id: 'mac',
  kind: SourceOutKindEnum.mac,
  available: true,
  enabled: enabled,
  decided: decided,
  contactsStatus: enabled ? contacts : 'unknown',
  calendarsStatus: enabled ? calendars : 'unknown',
  contactContainers: !enabled || contacts != 'authorized'
      ? []
      : [
          MacContainerOut(id: 'c-online', name: 'iCloud', kind: 'cardDAV', included: !leftOut.contains('c-online')),
          MacContainerOut(id: 'c-local', name: 'On My Mac', kind: 'local', included: !leftOut.contains('c-local')),
        ],
  calendars: !enabled || calendars != 'fullAccess'
      ? []
      : [
          for (final (id, name) in [('k-home', 'Home'), ('k-work', 'Work'), ('k-club', 'Example Book Club')])
            MacCalendarOut(id: id, name: name, sourceName: 'iCloud', included: !leftOut.contains(id)),
        ],
  allContactContainers: !leftOut.any((id) => id.startsWith('c-')),
  allCalendars: !leftOut.any((id) => id.startsWith('k-')),
  notesIncluded: false,
  window: enabled ? WindowOut(start: '2025-10-13', end: '2028-10-13') : null,
  readerRunning: enabled,
  lastUpdate: enabled ? '2026-10-13T09:12:00' : null,
  lastError: lastError,
  counts: enabled ? (counts ?? SyncCounts(addressBooks: 2, contacts: 214, calendars: 3, events: 1240)) : null,
);

/// A followed iCloud account as GET /sources shows it.
SourceOut icloudSource(String email, {String? lastError, SyncCounts? counts}) => SourceOut(
  id: 'acct-${email.split('@').first}',
  kind: SourceOutKindEnum.icloud,
  enabled: true,
  email: email,
  notesIncluded: true,
  state: lastError == null ? SourceOutStateEnum.idle : SourceOutStateEnum.error,
  lastUpdate: '2026-10-13T08:40:00',
  lastError: lastError,
  counts: counts ?? SyncCounts(addressBooks: 1, contacts: 180, calendars: 4, events: 960),
);

/// The reader helper and System Settings, recorded.
class FakeMacSystem implements MacSystem {
  FakeMacSystem({this.helper = '/Applications/myData.app/Contents/Helpers/myDataReader.app'});

  /// What [readerHelperPath] returns: null for a build with no helper.
  final String? helper;

  /// The URLs opened.
  final opened = <String>[];

  @override
  String? readerHelperPath() => helper;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return true;
  }
}

/// A platform whose host is always there; the [FakeHost] answers its requests.
class _FakePlatform implements HostPlatform {
  @override
  bool get supported => true;
  @override
  String get unsupportedReason => '';
  @override
  Future<HostEnvironment> environment() async => FakeHost.environment;
  @override
  Future<String?> readAppToken(HostEnvironment env, String app) async => FakeHost.token;
  @override
  Future<LaunchResult> startHost(HostEnvironment env) async => const LaunchResult(true, '');
  @override
  Future<bool> openMyDataApp({bool setup = true}) async => false;
}

/// A running host in memory: the API the apps use, answered from fields a test can set and read, with
/// every request recorded ("PUT /appearance {"theme":"dusk"}").
class FakeHost {
  FakeHost({
    StatusOut? status,
    this.theme = 'kiwi',
    this.chosen = true,
    List<AgentOut>? agents,
    this.mac,
    List<SourceOut>? accounts,
  }) : status = status ?? statusWith(ModelOutStateEnum.ready, macAvailable: mac != null),
       agents = agents ?? [],
       accounts = accounts ?? [];

  static const token = 'test-token';
  static const environment = HostEnvironment(home: '/tmp/mydata-test', baseUrl: 'http://127.0.0.1:47821', hostCommand: null);

  StatusOut status;

  /// The stored theme and whether it was ever chosen (GET /appearance).
  String theme;
  bool chosen;
  List<AgentOut> agents;

  /// This Mac, or null on a host that is not a Mac (GET /sources leaves it out; its routes answer 404).
  SourceOut? mac;

  /// The followed iCloud accounts.
  List<SourceOut> accounts;

  /// What the system's prompt answers, per kind, when the app asks for access.
  Map<String, String> accessAnswers = {'contacts': 'authorized', 'calendars': 'fullAccess'};

  /// POST /accounts answers 400 with this, as the host does when Apple refuses the sign-in.
  String? rejectAccount;

  /// How many of the next PUT /sources/mac/reader answer with a server error.
  int failReader = 0;

  /// While set, POST /sources/mac/request-access waits for it, as the host waits for the person to answer
  /// the system's prompt.
  Completer<void>? accessGate;

  /// GET and PUT /appearance answer with a server error.
  bool failAppearance = false;

  /// The host has stopped: /status does not answer.
  bool down = false;

  final requests = <String>[];

  late final http.Client client = MockClient(_answer);

  /// A controller already connected to this host, as after a successful connect, without its poll timer.
  HostController controller() {
    final c = HostController(app: 'mydata', platform: _FakePlatform());
    c.environment = environment;
    c.connection = HostConnection(environment.baseUrl, token)..client.client = client;
    c.status = status..theme = theme;
    c.phase = HostPhase.running;
    return c;
  }

  http.Response _json(Object? body, [int code = 200]) =>
      http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

  AppearanceOut get _appearance => AppearanceOut(chosen: chosen, theme: theme);

  Future<http.Response> _answer(http.Request r) async {
    final path = r.url.path;
    requests.add('${r.method} $path${r.body.isEmpty ? '' : ' ${r.body}'}');
    final body = r.body.isEmpty ? null : jsonDecode(r.body) as Map<String, Object?>;
    switch ((r.method, path)) {
      case ('GET', '/status'):
        if (down) return _json({'detail': 'gone'}, 503);
        return _json((status..theme = theme).toJson());
      case ('GET', '/appearance'):
        return failAppearance ? _json({'detail': 'appearance is broken'}, 500) : _json(_appearance.toJson());
      case ('PUT', '/appearance'):
        if (failAppearance) return _json({'detail': 'appearance is broken'}, 500);
        theme = body!['theme']! as String;
        chosen = true;
        return _json(_appearance.toJson());
      case ('PUT', '/assistant/settings'):
        status.assistantEnabled = body!['enabled']! as bool;
        return _json(status.toJson());
      case ('POST', '/model/retry'):
        return _json(status.toJson());
      case ('GET', '/agents'):
        return _json([for (final a in agents) a.toJson()]);
      case ('POST', '/agents'):
        final name = body!['name']! as String;
        final a = agentWith(name);
        agents = [...agents, a];
        return _json(
          AgentCreated(
            id: a.id,
            name: a.name,
            connected: false,
            revoked: false,
            createdAt: a.createdAt,
            token: 'mdt_secret_for_$name',
          ).toJson(),
        );
      case ('GET', '/sources'):
        return _json(SourcesOut(sources: [?mac, ...accounts]).toJson());
      case (_, final p) when p.startsWith('/sources/mac') && mac == null:
        return _json({'detail': 'This host is not a Mac, so there is no This Mac source.'}, 404);
      case ('PUT', '/sources/mac'):
        final m = mac!;
        final on = body!['enabled'] as bool?;
        final containers = (body['contact_containers'] as List?)?.cast<String>();
        final calendars = (body['calendars'] as List?)?.cast<String>();
        final leftOut = {
          if (containers != null) ...m.contactContainers.map((c) => c.id).where((id) => !containers.contains(id)),
          if (calendars != null) ...m.calendars.map((c) => c.id).where((id) => !calendars.contains(id)),
        };
        final enabled = on ?? m.enabled;
        mac = macSource(
          enabled: enabled,
          contacts: enabled && m.enabled ? m.contactsStatus! : 'notDetermined',
          calendars: enabled && m.enabled ? m.calendarsStatus! : 'notDetermined',
          leftOut: leftOut,
        );
        return _json(mac!.toJson());
      case ('POST', '/sources/mac/request-access'):
        await accessGate?.future;
        final what = body!['what']! as String;
        final m = mac!;
        mac = macSource(
          contacts: what == 'contacts' ? accessAnswers['contacts']! : m.contactsStatus!,
          calendars: what == 'calendars' ? accessAnswers['calendars']! : m.calendarsStatus!,
        );
        return _json(mac!.toJson());
      case ('PUT', '/sources/mac/reader'):
        if (failReader > 0) {
          failReader--;
          return _json({'detail': 'the host is busy'}, 500);
        }
        return _json(mac!.toJson());
      case ('POST', '/accounts'):
        if (rejectAccount != null) return _json({'detail': rejectAccount}, 400);
        final email = body!['email']! as String;
        final a = icloudSource(email);
        accounts = [...accounts, a];
        return _json(
          AccountOut(
            id: a.id,
            provider: 'icloud',
            email: email,
            createdAt: '2026-10-13T09:00:00',
            label: email,
          ).toJson(),
          201,
        );
      case ('POST', final p) when p.startsWith('/accounts/') && p.endsWith('/sync'):
        final id = p.split('/')[2];
        return _json(
          AccountSyncOut(accountId: id, state: AccountSyncOutStateEnum.syncing, counts: SyncCounts()).toJson(),
          202,
        );
      case ('DELETE', final p) when p.startsWith('/accounts/'):
        final id = p.substring('/accounts/'.length);
        final a = accounts.firstWhere((a) => a.id == id);
        accounts = [...accounts]..remove(a);
        return _json(
          AccountOut(
            id: id,
            provider: 'icloud',
            email: a.email!,
            createdAt: '2026-10-13T09:00:00',
            label: a.email!,
          ).toJson(),
        );
      case ('DELETE', final p) when p.startsWith('/agents/'):
        final id = p.substring('/agents/'.length);
        final a = agents.firstWhere((a) => a.id == id);
        a
          ..revoked = true
          ..connected = false;
        return _json(a.toJson());
    }
    return _json({'detail': 'Not found'}, 404);
  }
}

/// Pumps frames until the fake host's answers have arrived. Not pumpAndSettle: the loading kiwi turns
/// for as long as it shows.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// LaunchServices as a fake: the apps in [present] are installed. Counts the lookups.
class FakeLaunchServices {
  FakeLaunchServices([Set<MyDataAppId> present = const {}]) : present = {...present};
  Set<MyDataAppId> present;
  int lookups = 0;

  Future<CommandResult> call(String executable, List<String> arguments) async {
    lookups++;
    final installed = present.any((a) => a.bundleId == arguments.last);
    return CommandResult(0, installed ? '/Applications/${arguments.last}.app' : '');
  }

  /// The installed apps the Status screen asks about, looked up through this fake.
  InstalledApps apps() => InstalledApps(
    apps: const [MyDataAppId.mycontacts, MyDataAppId.mycalendar, MyDataAppId.myassistant],
    links: AppLinks(run: call, macOS: true),
  );
}
