import 'dart:async';

import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';

/// A platform with no host: either unsupported (the web build) or with no start command configured. It
/// records every attempt to open the myData app.
class NoHostPlatform implements HostPlatform {
  NoHostPlatform({required this.supported, this.opens = false});

  @override
  final bool supported;

  /// What [openMyDataApp] answers.
  bool opens;
  int environments = 0;

  /// The `setup` argument of each call to [openMyDataApp].
  final openCalls = <bool>[];

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
  Future<bool> openMyDataApp({bool setup = true}) async {
    openCalls.add(setup);
    return opens;
  }
}

/// A host that is already in [phaseOnConnect] with [statusOnConnect], without any network: [connect] and
/// [refresh] just report it.
class FakeHost extends HostController {
  FakeHost({required this.phaseOnConnect, this.statusOnConnect, HostPlatform? platform})
    : super(app: 'myassistant', platform: platform ?? NoHostPlatform(supported: true));

  HostPhase phaseOnConnect;
  StatusOut? statusOnConnect;

  @override
  Future<void> connect({bool startIfNeeded = true}) async {
    phase = phaseOnConnect;
    status = statusOnConnect;
    notifyListeners();
  }

  @override
  Future<bool> refresh() async {
    status = statusOnConnect;
    notifyListeners();
    return true;
  }

  /// A new status, as the next poll would bring it.
  void push(StatusOut s) {
    statusOnConnect = s;
    status = s;
    notifyListeners();
  }
}

/// A host status with the model ready (or [state]) in [theme], in demo mode unless [real].
StatusOut hostStatus({
  String theme = 'kiwi',
  bool enabled = true,
  ModelOutStateEnum state = ModelOutStateEnum.ready,
  bool? demoDate,
  bool real = false,
  int epoch = 0,
}) => StatusOut(
  agentsConnected: 0,
  assistantEnabled: enabled,
  conversationEpoch: epoch,
  demoDate: demoDate ?? !real,
  memory: MemoryOut(hostBytes: 120000000),
  model: ModelOut(
    name: 'qwen3:14b',
    state: state,
    loaded: state == ModelOutStateEnum.ready,
    ollamaReachable: true,
    ollamaStartedByHost: true,
  ),
  mode: real ? StatusOutModeEnum.real : StatusOutModeEnum.demo,
  ready: state == ModelOutStateEnum.ready,
  theme: theme,
  today: '2026-03-18',
  uptimeSeconds: 12,
  version: '0.1.0',
);

/// Answers each message with the next scripted list of events.
class ScriptedBackend implements AssistantBackend {
  ScriptedBackend(this.replies);
  final List<List<AssistantEvent>> replies;
  final sent = <String>[];

  /// The conversation id sent with each message.
  final conversations = <String?>[];

  @override
  Stream<AssistantEvent> send(MessageIn message) {
    sent.add(message.text);
    conversations.add(message.conversationId);
    return Stream.fromIterable(replies.isEmpty ? const [DoneEvent()] : replies.removeAt(0));
  }

  @override
  Future<ApprovalOut> decide(String approvalId, {required bool approve}) => Completer<ApprovalOut>().future;
}

const tomorrowEvents = ResultEvent(
  tool: 'list_events',
  kind: 'events',
  header: '2 events on Thursday 19 March',
  items: [
    {'title': 'Personal training', 'day': 'Thursday 19 March', 'start': '06:30', 'end': '07:30', 'location': 'Gym'},
    {'title': 'Call with mum', 'day': 'Thursday 19 March', 'start': '20:00', 'end': '20:30', 'location': null},
  ],
);

/// "Am I free at 6:30 tomorrow?": the calendar result, then a streamed sentence.
List<AssistantEvent> freeAtSixThirty() => const [
  ConversationEvent('c1'),
  ProgressEvent(tool: 'list_events', label: 'Checking calendar'),
  tomorrowEvents,
  DeltaEvent('No, '),
  DeltaEvent('you have personal training '),
  DeltaEvent('from 06:30 to 07:30 at the gym.'),
  MessageEvent(text: 'No, you have personal training from 06:30 to 07:30 at the gym.', outcome: 'answered'),
  DoneEvent(),
];

const dentistBody =
    'Hi Rishita,\n\nMy dentist appointment is on Friday 20 March at 09:30 at Smile Dental, 14 Harbour Road.\n\nTirth';

/// "Email Rishita the time of my dentist appointment": the calendar and the contact, then the held email.
List<AssistantEvent> emailRishita() => [
  const ConversationEvent('c2'),
  const ProgressEvent(tool: 'list_events', label: 'Checking calendar'),
  const ResultEvent(
    tool: 'list_events',
    kind: 'events',
    header: '1 event: Dentist',
    items: [
      {'title': 'Dentist', 'day': 'Friday 20 March', 'start': '09:30', 'end': '10:15', 'location': 'Smile Dental'},
    ],
  ),
  const ProgressEvent(tool: 'find_contact', label: 'Looking up Rishita'),
  const ResultEvent(
    tool: 'find_contact',
    kind: 'contacts',
    header: 'Rishita Shah',
    items: [
      {'name': 'Rishita Shah', 'email': 'rishita@example.com', 'phone': '+64 21 555 0199'},
    ],
  ),
  PendingApprovalEvent(
    ApprovalOut.fromJson({
      'id': 'ap_1',
      'tool': 'send_mail',
      'args': {'to': 'rishita@example.com', 'subject': 'Dentist on Friday', 'body': dentistBody},
      'summary': 'Send an email to rishita@example.com: Dentist on Friday',
      'caller': 'assistant',
      'context': {'conversation_id': 'c2'},
      'created_at': '2026-03-18T10:00:00+00:00',
      'status': 'pending',
    })!,
  ),
  const MessageEvent(text: 'The email is ready. It is waiting for your approval.', outcome: 'pending_approval'),
  const DoneEvent(),
];

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

  /// The installed apps myAssistant asks about, looked up through this fake.
  InstalledApps apps() => InstalledApps(
    apps: const [MyDataAppId.mycontacts, MyDataAppId.mycalendar],
    links: AppLinks(run: call, macOS: true),
  );
}

/// A contact's id on the host (invented).
const avaId = '2f1c9a52-7d3e-4b8a-9c61-0e5d4f3a2b10';

/// "Ava's number and what's on Friday?" in real mode: the user's own contact and event, which open in their apps.
List<AssistantEvent> realLookups({bool real = true}) => [
  const ConversationEvent('c3'),
  const ProgressEvent(tool: 'find_contact', label: 'Looking up Ava'),
  ResultEvent(
    tool: 'find_contact',
    kind: 'contacts',
    header: 'Ava Fictional',
    realMode: real,
    items: const [
      {'id': avaId, 'name': 'Ava Fictional', 'email': 'ava.fictional@example.com', 'phone': '+1 202 555 0101'},
    ],
  ),
  const ProgressEvent(tool: 'list_events', label: 'Checking calendar'),
  ResultEvent(
    tool: 'list_events',
    kind: 'events',
    header: '1 event on Friday 20 March',
    realMode: real,
    items: const [
      {
        'title': 'Dinner with Ava (invented)',
        'date': '2026-03-20',
        'day': 'Friday 20 March',
        'start': '19:00',
        'end': '21:00',
        'location': '12 Example Street',
      },
    ],
  ),
  const MessageEvent(text: '1 event on Friday 20 March', outcome: 'answered', byCode: true),
  const DoneEvent(),
];
