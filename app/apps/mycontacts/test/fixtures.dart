// Invented contacts only: example.com addresses, phone numbers from ranges kept for drama and testing
// (UK 07700 900xxx, US 555-01xx), made-up names.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:mycontacts/src/backend.dart';
import 'package:mydata_core/mydata_core.dart';

/// A platform with no host: either unsupported (the web build) or with no start command configured.
class NoHostPlatform implements HostPlatform {
  NoHostPlatform({required this.supported, this.opens = false});

  @override
  final bool supported;

  bool opens;
  int environments = 0;
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
  Future<LaunchResult> stopHost(HostEnvironment env) async => const LaunchResult(false, '');

  @override
  Future<bool> openMyDataApp({bool setup = true}) async {
    openCalls.add(setup);
    return opens;
  }
}

/// A host that is already in [phaseOnConnect] with [statusOnConnect], without any network.
class FakeHost extends HostController {
  FakeHost({required this.phaseOnConnect, this.statusOnConnect, HostPlatform? platform})
    : super(app: 'mycontacts', platform: platform ?? NoHostPlatform(supported: true));

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

  /// The next poll: listeners hear from the host again.
  void poll() => notifyListeners();

  /// The host stops answering.
  void lose() {
    phase = HostPhase.lost;
    error = 'The myData host stopped while the app was open.';
    notifyListeners();
  }
}

/// A host status in [theme], in real mode unless [real] is false.
StatusOut hostStatus({String theme = 'kiwi', bool real = true}) => StatusOut(
  agentsConnected: 0,
  apiVersion: expectedHostApiVersion,
  assistantEnabled: false,
  conversationEpoch: 0,
  demoDate: !real,
  memory: MemoryOut(hostBytes: 120000000),
  model: ModelOut(
    name: 'qwen3:14b',
    state: ModelOutStateEnum.disabled,
    loaded: false,
    ollamaReachable: true,
    ollamaStartedByHost: false,
  ),
  mode: real ? StatusOutModeEnum.real : StatusOutModeEnum.demo,
  ready: false,
  theme: theme,
  today: '2026-10-13',
  uptimeSeconds: 12,
  version: '0.1.0',
);

/// The host's contacts, kept in memory. Records what was asked.
class FakeBackend implements ContactsBackend {
  FakeBackend({List<ContactDetailOut>? cards, this.anyOn = true, Map<String, Uint8List>? photos})
    : cards = cards ?? sampleCards(),
      photos = photos ?? {};

  List<ContactDetailOut> cards;
  bool anyOn;
  String revision = '1';
  Map<String, Uint8List> photos;

  bool failSources = false;
  bool failContacts = false;
  bool failDetails = false;

  int sourceCalls = 0;
  int contactCalls = 0;
  final detailCalls = <String>[];
  final photoCalls = <String>[];

  @override
  Future<SourcesState> sources() async {
    sourceCalls++;
    if (failSources) throw StateError('no answer');
    return SourcesState(anyOn: anyOn, revision: anyOn ? revision : '');
  }

  @override
  Future<List<ContactOut>> contacts() async {
    contactCalls++;
    if (failContacts) throw StateError('no answer');
    return [for (final c in cards) listView(c)];
  }

  @override
  Future<ContactDetailOut?> contact(String id) async {
    detailCalls.add(id);
    if (failDetails) throw StateError('no answer');
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<Uint8List?> photo(String id) async {
    photoCalls.add(id);
    return photos[id];
  }
}

/// The list's view of a card, as `GET /contacts` gives it.
ContactOut listView(ContactDetailOut c) => ContactOut(
  accountId: c.accountId,
  addressBookId: c.addressBookId,
  caption: c.caption,
  createdAt: c.createdAt,
  displayName: c.displayName,
  emails: c.emails,
  familyName: c.familyName,
  givenName: c.givenName,
  hasPhoto: c.hasPhoto,
  id: c.id,
  modifiedAt: c.modifiedAt,
  organisation: c.organisation,
  phones: c.phones,
  sortLetter: c.sortLetter,
  source_: c.source_ == ContactDetailOutSource_Enum.mac ? ContactOutSource_Enum.mac : ContactOutSource_Enum.icloud,
  notesIncluded: c.notesIncluded,
);

typedef Labeled = (String label, String value);

/// A contact's page as the host gives it: fields grouped Phone, Email, Address, Birthday, Links, Notes, with
/// empty kinds left out. From This Mac unless [icloud]; This Mac never reads notes.
ContactDetailOut card({
  required String id,
  required String name,
  String given = '',
  String family = '',
  String org = '',
  String job = '',
  bool icloud = false,
  List<Labeled> phones = const [],
  List<Labeled> emails = const [],
  List<Labeled> addresses = const [],
  String? birthday,
  List<Labeled> urls = const [],
  String note = '',
  bool photo = false,
  String? letter,
}) {
  final shown = name.trim();
  String? caption;
  if (org.isNotEmpty && org != shown) {
    caption = org;
  } else {
    for (final v in [...emails.map((e) => e.$2), ...phones.map((p) => p.$2)]) {
      if (v != shown) {
        caption = v;
        break;
      }
    }
  }
  final first = shown.isEmpty ? '#' : shown[0].toUpperCase();
  final notes = icloud && note.trim().isNotEmpty;
  ContactFieldGroup group(ContactFieldGroupKindEnum kind, String title, List<ContactField> items) =>
      ContactFieldGroup(kind: kind, title: title, items: items);
  return ContactDetailOut(
    accountId: icloud ? 'acc-icloud' : 'mac',
    addressBookId: icloud ? 'book-icloud' : 'book-mac',
    birthday: birthday,
    caption: caption,
    createdAt: '2026-01-05T09:00:00+00:00',
    displayName: name,
    emails: [for (final e in emails) LabeledValue(label: e.$1, value: e.$2)],
    familyName: family,
    givenName: given,
    fullName: name,
    hasPhoto: photo,
    id: id,
    jobTitle: job,
    modifiedAt: '2026-09-30T18:00:00+00:00',
    note: notes ? note : '',
    notesIncluded: icloud,
    organisation: org,
    phones: [for (final p in phones) LabeledValue(label: p.$1, value: p.$2)],
    sortLetter: letter ?? (RegExp('[A-Z]').hasMatch(first) ? first : '#'),
    source_: icloud ? ContactDetailOutSource_Enum.icloud : ContactDetailOutSource_Enum.mac,
    sourceLabel: icloud ? 'the iCloud account you@example.com' : 'this Mac',
    urls: [for (final u in urls) LabeledValue(label: u.$1, value: u.$2)],
    fields: [
      if (phones.isNotEmpty)
        group(ContactFieldGroupKindEnum.phone, 'Phone', [
          for (final p in phones) ContactField(label: p.$1, value: p.$2),
        ]),
      if (emails.isNotEmpty)
        group(ContactFieldGroupKindEnum.email, 'Email', [
          for (final e in emails) ContactField(label: e.$1, value: e.$2),
        ]),
      if (addresses.isNotEmpty)
        group(ContactFieldGroupKindEnum.address, 'Address', [
          for (final a in addresses) ContactField(label: a.$1, value: a.$2),
        ]),
      if (birthday != null) group(ContactFieldGroupKindEnum.birthday, 'Birthday', [ContactField(value: birthday)]),
      if (urls.isNotEmpty)
        group(ContactFieldGroupKindEnum.url, 'Links', [for (final u in urls) ContactField(label: u.$1, value: u.$2)]),
      if (notes) group(ContactFieldGroupKindEnum.note, 'Notes', [ContactField(value: note.trim())]),
    ],
  );
}

/// Ava Fictional: from iCloud, with a job title, a photo and notes.
final ava = card(
  id: 'c-ava',
  name: 'Ava Fictional',
  given: 'Ava',
  family: 'Fictional',
  org: 'Example Labs',
  job: 'Head of research',
  icloud: true,
  photo: true,
  phones: [('Mobile', '+44 7700 900123'), ('Work', '+1 555 0142')],
  emails: [('Work', 'ava@example.com')],
  birthday: '--05-12',
  urls: [('Website', 'example.com/ava')],
  note: 'Met at the example meetup.\nPrefers calls in the morning.',
);

/// Aaron Example: from This Mac, so no notes, with every other kind of field.
final aaron = card(
  id: 'c-aaron',
  name: 'Aaron Example',
  given: 'Aaron',
  family: 'Example',
  phones: [('Mobile', '+44 7700 900456')],
  emails: [('Home', 'aaron@example.com')],
  addresses: [('Home', '4 Placeholder Lane\nSampleford ZZ9 8XY\nUnited Kingdom')],
  birthday: '1990-05-12',
  urls: [('Home page', 'https://example.org/aaron'), ('Other', 'x-example-app://open?id=aaron')],
);

/// Every contact, in the host's order.
List<ContactDetailOut> sampleCards() => [
  aaron,
  ava,
  card(id: 'c-ben', name: 'Ben Testwell', given: 'Ben', family: 'Testwell', emails: [('Work', 'ben@example.net')]),
  card(id: 'c-eli', name: 'Eli Sample', given: 'Eli', family: 'Sample', phones: [('Mobile', '+1 555 0123')]),
  card(id: 'c-emil', name: 'Émile Exemple', given: 'Émile', family: 'Exemple', letter: 'E', icloud: true),
  card(
    id: 'c-labs',
    name: 'Example Labs',
    org: 'Example Labs',
    emails: [('Work', 'info@example.com')],
    urls: [('Website', 'https://example.com')],
  ),
  card(
    id: 'c-jun',
    name: 'Jun Placeholder',
    given: 'Jun',
    family: 'Placeholder',
    org: 'Sample & Co',
    job: 'Designer',
    phones: [('Work', '+1 555 0188')],
    emails: [('Work', 'jun@example.net')],
    addresses: [('Work', '20 Example Road\nSampleton ZZ3 4CD\nUnited Kingdom')],
  ),
  card(id: 'c-lee', name: 'Lee Placeholder', given: 'Lee', family: 'Placeholder', phones: [('Work', '+1 555 0177')]),
  card(id: 'c-maya', name: 'Maya Mock', given: 'Maya', family: 'Mock', emails: [('Home', 'maya@example.org')]),
  card(id: 'c-noor', name: 'Noor Example', given: 'Noor', family: 'Example', org: 'Example Clinic', job: 'Nurse'),
  card(id: 'c-omar', name: 'Omar Sample', given: 'Omar', family: 'Sample', phones: [('Mobile', '+44 7700 900321')]),
  card(id: 'c-sam', name: 'Sam Sample', given: 'Sam', family: 'Sample'),
  card(id: 'c-zoe', name: 'Zoe Example', given: 'Zoe', family: 'Example', org: 'Example Studio'),
  card(id: 'c-phone', name: '+44 7700 900654', phones: [('Mobile', '+44 7700 900654')]),
];

/// An invented portrait as PNG bytes: a round head and shoulders on a plain ground, as the design preview
/// draws one. Call outside the fake clock (setUpAll, or tester.runAsync).
Future<Uint8List> portraitPng({int size = 192}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size / 96;
  canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), Paint()..color = const Color(0xFFFBF7EC));
  final skin = Paint()..color = const Color(0xFF6B4F35);
  canvas.drawCircle(Offset(48 * s, 38 * s), 17 * s, skin);
  canvas.drawPath(
    Path()
      ..moveTo(14 * s, 96 * s)
      ..cubicTo(17 * s, 76 * s, 31 * s, 65 * s, 48 * s, 65 * s)
      ..cubicTo(65 * s, 65 * s, 79 * s, 76 * s, 82 * s, 96 * s)
      ..close(),
    skin,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// A stream of links to hand the app, as macOS would.
class FakeLinks {
  final controller = StreamController<MyDataLink>();
  Stream<MyDataLink> get stream => controller.stream;
  void open(String link) => controller.add(MyDataLink.parse(link)!);
}
