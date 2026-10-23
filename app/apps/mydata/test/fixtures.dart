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
  apiVersion: expectedHostApiVersion,
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
SourceOut icloudSource(String email, {String? lastError, SyncCounts? counts, String? lastUpdate}) => SourceOut(
  id: 'acct-${email.split('@').first}',
  kind: SourceOutKindEnum.icloud,
  enabled: true,
  email: email,
  notesIncluded: true,
  state: lastError == null ? SourceOutStateEnum.idle : SourceOutStateEnum.error,
  lastUpdate: lastUpdate ?? '2026-10-13T08:40:00',
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
  Future<LaunchResult> stopHost(HostEnvironment env) async => const LaunchResult(true, '');
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

  /// The import routes (design/components/ImportFlow), with invented data only.
  final imports = FakeImports();

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
    final json = (r.headers['content-type'] ?? '').startsWith('application/json');
    if (json || r.bodyBytes.isEmpty) {
      requests.add('${r.method} $path${r.body.isEmpty ? '' : ' ${r.body}'}');
    } else {
      // A file sent as it is: only its name and size are recorded.
      requests.add('${r.method} $path?${r.url.query} (${r.bodyBytes.length} bytes)');
    }
    final body = !json || r.body.isEmpty ? null : jsonDecode(r.body) as Map<String, Object?>;
    final imported = await imports.answer(r, path, body, _json);
    if (imported != null) return imported;
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
        if (imports.down) throw http.ClientException('the host stopped answering');
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


typedef JsonAnswer = http.Response Function(Object? body, [int code]);

/// The host's import routes, answered from fields a test sets. A preview is held by its id until it is
/// discarded or committed, as the host holds it.
class FakeImports {
  /// The answer to the next file (POST /import/contacts/preview), by file name; [nextPreview] otherwise.
  final byName = <String, ImportPreviewOut>{};
  ImportPreviewOut? nextPreview;

  /// A copy of a followed account, by account id.
  final byAccount = <String, ImportPreviewOut>{};

  /// The next file is refused with this status and code (H4).
  (int, String)? refuse;

  /// The host does not answer the import routes (and removing an account).
  bool down = false;

  /// While set, a file preview waits for it (the host still reading).
  Completer<void>? previewGate;

  /// While set, an account copy's preview waits for it.
  Completer<void>? accountGate;

  /// Previews held, by id.
  final held = <String, ImportPreviewOut>{};

  /// GET /import/previews/{id} answers 404 for these (an hour passed, or the host restarted).
  final gone = <String>{};

  /// The values of a preview's cards (H3), by index.
  final cards = <int, ImportCardOut>{};

  /// The contacts of myData, for Compare's "In myData".
  final contacts = <String, ContactDetailOut>{};

  /// The commit's answer, or its refusal.
  ImportCommittedOut? commitResult;
  (int, String?)? commitRefusal;

  /// The commit is saved, then its answer is lost (the host was replaced as it answered).
  bool loseCommitAnswer = false;
  Completer<void>? commitGate;

  /// The answer to a preview read again after a refused commit.
  ImportPreviewOut? afterRefusal;

  /// The history, newest first.
  List<ImportOut> history = [];

  /// The answer to the next undo, or 409 when [undoConflict].
  ImportUndoneOut? undoResult;
  bool undoConflict = false;

  Future<http.Response?> answer(http.Request r, String path, Map<String, Object?>? body, JsonAnswer json) async {
    final m = r.method;
    if (!path.startsWith('/import') && !(m == 'GET' && path.startsWith('/contacts/'))) return null;
    if (down) throw http.ClientException('the host stopped answering');
    if (m == 'POST' && path == '/import/contacts/preview') {
      await previewGate?.future;
      final refusal = refuse;
      if (refusal != null) {
        refuse = null;
        return json({'detail': 'refused', 'code': refusal.$2}, refusal.$1);
      }
      final name = r.url.queryParameters['filename'] ?? '';
      final p = byName[name] ?? nextPreview;
      if (p == null) return json({'detail': 'No vCard', 'code': 'no_vcard'}, 400);
      held[p.id] = p;
      return json(p.toJson(), 201);
    }
    final source = RegExp(r'^/import/contacts/from-source/([^/]+)/preview$').firstMatch(path);
    if (m == 'POST' && source != null) {
      await accountGate?.future;
      final p = byAccount[source.group(1)];
      if (p == null) return json({'detail': 'This Mac is never imported.'}, 409);
      held[p.id] = p;
      return json(p.toJson(), 201);
    }
    final item = RegExp(r'^/import/previews/([^/]+)/items/(\d+)$').firstMatch(path);
    if (m == 'GET' && item != null) {
      final card = cards[int.parse(item.group(2)!)];
      return card == null ? json({'detail': 'gone'}, 404) : json(card.toJson());
    }
    final commit = RegExp(r'^/import/previews/([^/]+)/commit$').firstMatch(path);
    if (m == 'POST' && commit != null) {
      await commitGate?.future;
      final refusal = commitRefusal;
      if (refusal != null) {
        commitRefusal = null;
        if (refusal.$1 == 400 && afterRefusal != null) held[commit.group(1)!] = afterRefusal!;
        return json({'detail': 'refused', 'code': ?refusal.$2}, refusal.$1);
      }
      held.remove(commit.group(1));
      final out = commitResult!;
      history = [
        ImportOut(
          id: out.id,
          label: out.label,
          source_: out.source_,
          sourceAccount: out.sourceAccount,
          startedAt: out.startedAt,
          status: 'committed',
          counts: out.counts,
        ),
        ...history,
      ];
      if (loseCommitAnswer) throw http.ClientException('the host stopped answering');
      return json(out.toJson(), 201);
    }
    final preview = RegExp(r'^/import/previews/([^/]+)$').firstMatch(path);
    if (preview != null) {
      final id = preview.group(1)!;
      if (m == 'DELETE') {
        held.remove(id);
        return http.Response('', 204);
      }
      final p = held[id];
      if (p == null || gone.contains(id)) return json({'detail': 'gone'}, 404);
      return json(p.toJson());
    }
    if (m == 'GET' && path == '/imports') return json([for (final i in history) i.toJson()]);
    final undo = RegExp(r'^/imports/([^/]+)/undo$').firstMatch(path);
    if (m == 'POST' && undo != null) {
      final id = undo.group(1)!;
      final i = history.firstWhere((x) => x.id == id);
      if (undoConflict || i.status == 'undone') {
        history = [for (final x in history) x.id == id ? _undone(x) : x];
        return json({'detail': 'already undone'}, 409);
      }
      final u = undoResult!;
      history = [for (final x in history) x.id == id ? _undone(x) : x];
      u.summary = history.firstWhere((x) => x.id == id);
      return json(u.toJson());
    }
    final contact = RegExp(r'^/contacts/([^/]+)$').firstMatch(path);
    if (m == 'GET' && contact != null) {
      final c = contacts[contact.group(1)];
      return c == null ? json({'detail': 'gone'}, 404) : json(c.toJson());
    }
    return null;
  }

  ImportOut _undone(ImportOut i) => ImportOut(
        id: i.id,
        label: i.label,
        source_: i.source_,
        sourceAccount: i.sourceAccount,
        startedAt: i.startedAt,
        status: 'undone',
        undoneAt: '2026-10-15T09:00:00',
        counts: {
          ...i.counts,
          'undo': {'removed': undoResult?.removed ?? 0, 'reverted': undoResult?.reverted ?? 0, 'kept': undoResult?.kept.length ?? 0},
        },
      );
}

/// One card of a preview: [status] with its default [action] and the [choices] it may take.
ImportItemOut importItem(
  int index,
  String name, {
  String status = 'new',
  String action = 'import',
  List<String> choices = const ['import', 'skip'],
  List<ImportMatchOut> matches = const [],
  String? reason,
  String? entry,
  String kind = 'individual',
}) => ImportItemOut(
  index: index,
  displayName: status == 'skipped' ? '' : name,
  status: status,
  action: action,
  choices: choices,
  matches: matches,
  reason: reason,
  entry: entry,
  kind: status == 'skipped' ? null : kind,
);

/// A match with a contact in myData.
ImportMatchOut ownMatch(String name, {String strength = 'suggestion', List<String> signals = const ['name'], String id = 'c-own'}) =>
    ImportMatchOut(displayName: name, source_: 'mydata', strength: strength, signals: signals, contactId: id);

/// A preview as the host gives it, its counts worked out from [items] the way the host counts them.
ImportPreviewOut previewOf(
  List<ImportItemOut> items, {
  String id = 'pv-1',
  String label = 'contacts-2026-10-14.vcf',
  String source = 'file',
  String? accountId,
  List<ImportNoteOut> losses = const [],
  List<ImportNoteOut> changes = const [],
  List<ImportMissingOut> missing = const [],
  int followedMatches = 0,
  int groups = 0,
  StopFollowingOut? stopFollowing,
}) {
  int n(bool Function(ImportItemOut) f) => items.where(f).length;
  return ImportPreviewOut(
    id: id,
    expiresAt: '2026-10-14T10:00:00Z',
    source_: source,
    accountId: accountId,
    label: label,
    losses: losses,
    changes: changes,
    needsAcceptance: losses.isNotEmpty,
    missing: missing,
    stopFollowing: stopFollowing,
    items: items,
    counts: ImportCountsOut(
      cards: items.length,
      contacts: n((i) => i.status != 'skipped' && i.kind != 'group'),
      groups: groups,
      skipped: n((i) => i.status == 'skipped'),
      new_: n((i) => i.status == 'new'),
      duplicates: n((i) => i.status == 'duplicate'),
      inFile: n((i) => i.status == 'in_file'),
      unchanged: n((i) => i.status == 'unchanged'),
      updates: n((i) => i.status == 'update'),
      conflicts: n((i) => i.status == 'conflict'),
      deleted: n((i) => i.status == 'deleted'),
      suggestions: n((i) => i.matches.any((m) => m.strength == 'suggestion')),
      followedMatches: followedMatches,
      missing: missing.length,
      toImport: n((i) => i.action == 'import'),
      toUpdate: n((i) => i.action == 'update'),
      toLink: n((i) => i.action == 'link'),
    ),
  );
}

/// The host's answer to a commit.
ImportCommittedOut committed({
  String id = 'imp-1',
  String label = 'contacts-2026-10-14.vcf',
  String source = 'file',
  String? account,
  int created = 0,
  int updated = 0,
  int linked = 0,
  int skipped = 0,
  List<ImportConflictOut> conflicts = const [],
  List<ImportMissingOut> missing = const [],
  StopFollowingOut? stopFollowing,
  String startedAt = '2026-10-14T09:30:00',
}) => ImportCommittedOut(
  id: id,
  label: label,
  source_: source,
  sourceAccount: account,
  startedAt: startedAt,
  status: 'committed',
  counts: {'created': created, 'updated': updated, 'linked': linked, 'skipped': skipped},
  conflicts: conflicts,
  missing: missing,
  stopFollowing: stopFollowing,
);
