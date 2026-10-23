// Invented contacts only: example.com addresses, phone numbers from ranges kept for drama and testing
// (UK 07700 900xxx, US 555-01xx), made-up names.
import 'dart:async';
import 'dart:convert';
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

  /// The next writes fail as the host would: no answer, a field error, or a change made elsewhere.
  bool failWrites = false;
  Map<String, String>? nextFieldErrors;

  /// Recently deleted, newest first.
  final trashed = <ContactDetailOut>[];

  /// What each undo id takes back.
  final undoLog = <String, FakeUndo>{};
  final undone = <String>{};

  /// Every write, in order: "create c-new-1", "update c-new-1", "delete c-ava", "undo u-1".
  final writes = <String>[];

  /// The forms sent, in order.
  final forms = <ContactIn>[];
  final etagsSent = <String?>[];
  int _ids = 0;

  /// The day backups keep a copy of what is deleted for good now.
  String backupsKeptUntil = '2027-10-01';

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
    // With no source on, the host lists only the contacts it owns.
    return [for (final c in cards) if (anyOn || c.editable) listView(c)];
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

  int _revOf(ContactDetailOut c) => int.tryParse(c.etag.replaceAll('"', '').split('-').first) ?? 1;

  void _checkWrite() {
    if (failWrites) throw const NoAnswer();
    final errors = nextFieldErrors;
    if (errors != null) {
      nextFieldErrors = null;
      throw FieldErrors(errors);
    }
  }

  String _undoId(FakeUndo u) {
    final id = 'u-${undoLog.length + 1}';
    undoLog[id] = u;
    return id;
  }

  ContactDetailOut? _find(String id) => cards.where((c) => c.id == id).firstOrNull;

  @override
  Future<Written> create(ContactIn form) async {
    forms.add(form);
    _checkWrite();
    final c = ownedCard('c-new-${++_ids}', form, rev: 1);
    cards = [...cards, c]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    writes.add('create ${c.id}');
    return Written(c, _undoId(FakeUndo('create', c.id, 1, null)));
  }

  @override
  Future<Written> update(String id, String etag, ContactIn form) async {
    forms.add(form);
    etagsSent.add(etag);
    _checkWrite();
    final old = _find(id);
    if (old == null) throw const Gone();
    if (!old.editable) throw const Refused('This contact is followed from another source.');
    if (old.etag != etag) throw const ChangedElsewhere();
    final rev = _revOf(old) + 1;
    final c = ownedCard(id, form, rev: rev, created: old.createdAt);
    cards = [for (final x in cards) x.id == id ? c : x];
    writes.add('update $id');
    return Written(c, _undoId(FakeUndo('update', id, rev, old)));
  }

  @override
  Future<Written> delete(String id, String etag) async {
    etagsSent.add(etag);
    _checkWrite();
    final old = _find(id);
    if (old == null) throw const Gone();
    if (!old.editable) throw const Refused('This contact is followed from another source.');
    if (etag != old.etag) throw const ChangedElsewhere();
    final rev = _revOf(old) + 1;
    final gone = _withRev(old, rev, deleted: true);
    cards = [for (final x in cards) if (x.id != id) x];
    trashed.insert(0, gone);
    writes.add('delete $id');
    return Written(gone, _undoId(FakeUndo('delete', id, rev, null)));
  }

  @override
  Future<List<TrashItemOut>> trash() async => [
        for (final c in trashed)
          TrashItemOut(
            id: c.id,
            kind: TrashItemOutKindEnum.contact,
            title: c.displayName,
            deletedAt: c.deletedAt!,
            purgeAfter: c.purgeAfter!,
            backupsKeptUntil: backupsKeptUntil,
            contact: listView(c),
          ),
      ];

  @override
  Future<Written> restore(String id, {String? etag}) async {
    etagsSent.add(etag);
    _checkWrite();
    final old = trashed.where((c) => c.id == id).firstOrNull;
    if (old == null) throw const Gone();
    if (etag != null && etag != old.etag) throw const ChangedElsewhere();
    final rev = _revOf(old) + 1;
    final back = _withRev(old, rev, deleted: false);
    trashed.remove(old);
    cards = [...cards, back]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    writes.add('restore $id');
    return Written(back, _undoId(FakeUndo('restore', id, rev, null)));
  }

  @override
  Future<void> purge(String id, String etag) async {
    etagsSent.add(etag);
    _checkWrite();
    final old = trashed.where((c) => c.id == id).firstOrNull;
    if (old == null) throw const Gone();
    if (etag != old.etag) throw const ChangedElsewhere();
    trashed.remove(old);
    writes.add('purge $id');
  }

  /// While set, an undo waits for it: the host is still answering.
  Completer<void>? holdUndo;

  @override
  Future<ContactDetailOut> undo(String undoId) async {
    await holdUndo?.future;
    if (failWrites) throw const NoAnswer();
    final u = undoLog[undoId];
    if (u == null) throw const Gone();
    if (undone.contains(undoId)) throw const Refused('This was already undone.');
    final now = _find(u.id) ?? trashed.where((c) => c.id == u.id).firstOrNull;
    if (now == null) throw const Refused('This contact was deleted for good.');
    if (u.op != 'notdup' && _revOf(now) != u.rev) throw const Refused('This contact changed since.');
    undone.add(undoId);
    writes.add('undo $undoId');
    final rev = u.rev + 1;
    switch (u.op) {
      case 'merge':
        final merged = _find(u.id)!;
        cards = [for (final x in cards) if (x.id != u.id) x];
        trashed.insert(0, _withRev(merged, rev, deleted: true));
        ContactDetailOut? first;
        for (final id in u.ids) {
          final t = trashed.firstWhere((c) => c.id == id);
          trashed.remove(t);
          final back = _withRev(t, _revOf(t) + 1, deleted: false)..mergedInto = null;
          first ??= back;
          cards = [...cards, back]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        }
        return first!;
      case 'notdup':
        notSame.remove(_pairKey(u.ids[0], u.ids[1]));
        return now;
      case 'keep':
        now
          ..changedInSource = u.mark?.$1
          ..changedInSourceLabel = u.mark?.$2;
        return now;
      case 'save':
        final back = _withRev(u.prior!, rev, deleted: false);
        cards = [for (final x in cards) x.id == u.id ? back : x];
        return back;
      case 'update':
        final back = _withRev(u.prior!, rev, deleted: false);
        cards = [for (final x in cards) x.id == u.id ? back : x];
        return back;
      case 'delete':
        final back = _withRev(now, rev, deleted: false);
        trashed.remove(now);
        cards = [...cards, back]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        return back;
      default: // create, restore: to Recently deleted
        final gone = _withRev(now, rev, deleted: true);
        cards = [for (final x in cards) if (x.id != u.id) x];
        trashed.insert(0, gone);
        return gone;
    }
  }

  // ---- Merge and Review (H6a to H6c, H7) ------------------------------------------------------------------

  /// The host's possible duplicates (GET /contacts/duplicates), less the pairs marked as different people.
  List<DuplicatePairOut> pairs = [];
  final notSame = <String>{};

  /// The followed copies that changed since the import, by contact id.
  final followed = <String, FollowedChangesOut>{};

  /// Merge requests, in order: "preview c-a,c-b names_from=c-a", "merge c-a,c-b names_from=null".
  final mergeCalls = <String>[];

  /// While set, a merge waits for it.
  Completer<void>? holdMerge;
  int _merged = 0;

  /// The contacts [sent] name, checked as the host checks them: each owned, present and at the etag sent.
  List<ContactDetailOut> _merging(List<MergeContactIn> sent) {
    _checkWrite();
    final out = <ContactDetailOut>[];
    for (final m in sent) {
      final c = _find(m.id);
      if (c == null) throw const Gone();
      if (!c.editable) throw const Refused('Only contacts the host owns are merged.');
      if (c.etag != m.etag) throw const ChangedElsewhere();
      out.add(c);
    }
    return out;
  }

  /// The contact whose names a merge keeps: [namesFrom], else the one changed most recently.
  static ContactDetailOut _kept(List<ContactDetailOut> cs, String? namesFrom) =>
      cs.where((c) => c.id == namesFrom).firstOrNull ??
      (cs.toList()..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt))).first;

  static ContactIn _mergedForm(List<ContactDetailOut> cs, ContactDetailOut kept) {
    List<LabeledValueIn> join(List<LabeledValue> Function(ContactDetailOut) of) {
      final seen = <String>{};
      return [
        for (final c in [kept, ...cs.where((c) => c != kept)])
          for (final v in of(c))
            if (seen.add(v.value.toLowerCase())) LabeledValueIn(label: v.label, value: v.value),
      ];
    }

    return ContactIn(
      givenName: kept.givenName,
      familyName: kept.familyName,
      company: kept.company,
      jobTitle: kept.jobTitle.isNotEmpty ? kept.jobTitle : cs.map((c) => c.jobTitle).firstWhere((t) => t.isNotEmpty, orElse: () => ''),
      phones: join((c) => c.phones),
      emails: join((c) => c.emails),
      addresses: [
        for (final c in [kept, ...cs.where((c) => c != kept)])
          for (final a in c.addresses) PostalAddressIn.fromJson(jsonDecode(jsonEncode(a)) as Map<String, dynamic>)!,
      ],
      urls: join((c) => c.urls),
      birthday: kept.birthday ?? cs.map((c) => c.birthday).whereType<String>().firstOrNull ?? '',
      note: [for (final c in cs) if (c.note.isNotEmpty) c.note].join('\n\n'),
    );
  }

  static List<MergeLeftOutValueOut> _leftOut(List<ContactDetailOut> cs, ContactDetailOut kept) => [
        for (final c in cs)
          if (c != kept) ...[
            if (c.jobTitle.isNotEmpty && kept.jobTitle.isNotEmpty && c.jobTitle != kept.jobTitle)
              MergeLeftOutValueOut(contactId: c.id, kind: 'job_title', property: 'TITLE', value: c.jobTitle),
            if (c.birthday != null && kept.birthday != null && c.birthday != kept.birthday)
              MergeLeftOutValueOut(contactId: c.id, kind: 'birthday', property: 'BDAY', value: c.birthday),
          ],
      ];

  @override
  Future<MergePreviewOut> mergePreview(List<MergeContactIn> contacts, {String? namesFrom}) async {
    mergeCalls.add('preview ${contacts.map((c) => c.id).join(',')} names_from=$namesFrom');
    final cs = _merging(contacts);
    final kept = _kept(cs, namesFrom);
    final values = ownedCard('preview', _mergedForm(cs, kept));
    return MergePreviewOut(
      // Through JSON text, so the nested values (phones, emails) become maps as the host sends them.
      contact: CardValuesOut.fromJson({...jsonDecode(jsonEncode(values)) as Map<String, dynamic>, 'kind': 'individual'})!,
      namesFrom: kept.id,
      newest: _kept(cs, null).id,
      leftOut: _leftOut(cs, kept),
    );
  }

  @override
  Future<MergeOut> merge(List<MergeContactIn> contacts, {String? namesFrom}) async {
    mergeCalls.add('merge ${contacts.map((c) => c.id).join(',')} names_from=$namesFrom');
    await holdMerge?.future;
    final cs = _merging(contacts);
    final kept = _kept(cs, namesFrom);
    final merged = ownedCard('c-merged-${++_merged}', _mergedForm(cs, kept), rev: 1);
    final ids = {for (final c in cs) c.id};
    cards = [...cards.where((c) => !ids.contains(c.id)), merged]
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    for (final c in cs) {
      trashed.insert(0, _withRev(c, _revOf(c) + 1, deleted: true)..mergedInto = merged.id);
    }
    writes.add('merge ${ids.join(',')}');
    final left = _leftOut(cs, kept);
    return MergeOut(
      contact: merged,
      merged: [for (final c in cs) c.id],
      undoId: _undoId(FakeUndo('merge', merged.id, 1, null, ids: [for (final c in cs) c.id])),
      leftOut: [
        for (final p in left.map((l) => l.property).toSet())
          MergeLeftOutOut(property: p, count: left.where((l) => l.property == p).length),
      ],
    );
  }

  @override
  Future<List<DuplicatePairOut>> duplicates() async => [
        for (final p in pairs)
          if (!notSame.contains(_pairKey(p.contacts[0].id, p.contacts[1].id)) &&
              p.contacts.every((c) => _find(c.id) != null))
            p,
      ];

  static String _pairKey(String a, String b) => ([a, b]..sort()).join('|');

  @override
  Future<String> notDuplicates(String a, String b) async {
    _checkWrite();
    if (_find(a) == null || _find(b) == null) throw const Gone();
    notSame.add(_pairKey(a, b));
    writes.add('not-duplicates $a,$b');
    return _undoId(FakeUndo('notdup', a, 0, null, ids: [a, b]));
  }

  @override
  Future<FollowedChangesOut> followedChanges(String id) async {
    final c = _find(id);
    if (c == null) throw const Gone();
    final f = followed[id];
    if (f == null || c.changedInSource == null) return FollowedChangesOut(contact: c, changes: const []);
    f.contact = c;
    return f;
  }

  @override
  Future<Written> saveFollowed(String id, String etag, ContactIn form, List<FollowedSeenIn> seen) async {
    final w = await update(id, etag, form);
    writes.removeLast();
    writes.add('save-followed $id');
    final c = _find(id)!..changedInSource = null..changedInSourceLabel = null;
    undoLog[w.undoId!] = FakeUndo('save', id, _revOf(c), undoLog[w.undoId!]!.prior);
    return Written(c, w.undoId);
  }

  @override
  Future<Written> keepMine(String id, List<FollowedSeenIn> seen) async {
    _checkWrite();
    final c = _find(id);
    if (c == null) throw const Gone();
    if (c.changedInSource == null) throw const Refused('That copy has no changes to review (settled already).');
    final label = c.changedInSourceLabel;
    final source = c.changedInSource;
    c
      ..changedInSource = null
      ..changedInSourceLabel = null;
    writes.add('keep $id');
    return Written(c, _undoId(FakeUndo('keep', id, _revOf(c), null, mark: (source, label))));
  }

  /// A change made elsewhere (another app): the etag moves on.
  void changeElsewhere(String id, {String? jobTitle}) {
    final old = _find(id)!;
    final c = _withRev(old, _revOf(old) + 1, deleted: false);
    if (jobTitle != null) c.jobTitle = jobTitle;
    cards = [for (final x in cards) x.id == id ? c : x];
  }

  /// Elsewhere (another app), [id] in Recently deleted was restored, changed and deleted again: its etag
  /// moves on.
  void changeInTrashElsewhere(String id) {
    final i = trashed.indexWhere((c) => c.id == id);
    trashed[i] = _withRev(trashed[i], _revOf(trashed[i]) + 3, deleted: true);
  }

  static ContactDetailOut _withRev(ContactDetailOut c, int rev, {required bool deleted}) {
    final json = c.toJson();
    final copy = ContactDetailOut.fromJson(json)!;
    copy.changedInSource = c.changedInSource;
    copy.changedInSourceLabel = c.changedInSourceLabel;
    copy.etag = '"$rev-${c.id}"';
    copy.deletedAt = deleted ? '2026-10-14T09:30:00+00:00' : null;
    copy.purgeAfter = deleted ? '2026-11-13T09:30:00+00:00' : null;
    return copy;
  }
}

/// One entry of [FakeBackend.undoLog].
class FakeUndo {
  FakeUndo(this.op, this.id, this.rev, this.prior, {this.ids = const [], this.mark});
  final String op;
  final String id;
  final int rev;
  final ContactDetailOut? prior;

  /// A merge's originals; the two contacts marked as different people.
  final List<String> ids;

  /// The mark "Keep mine" cleared: the source's id and label.
  final (String?, String?)? mark;
}

/// A contact the host owns, as the host gives it after a write of [form].
ContactDetailOut ownedCard(String id, ContactIn form, {int rev = 1, String created = '2026-10-14T09:00:00+00:00'}) {
  String t(String? v) => (v ?? '').trim();
  List<LabeledValue> values(List<LabeledValueIn>? l) => [
        for (final v in l ?? const <LabeledValueIn>[])
          if (t(v.value).isNotEmpty) LabeledValue(label: t(v.label), value: t(v.value)),
      ];
  final phones = values(form.phones);
  final emails = values(form.emails);
  final urls = values(form.urls);
  final addresses = [
    for (final a in form.addresses ?? const <PostalAddressIn>[])
      if ([a.street, a.locality, a.region, a.postalCode, a.country].any((p) => t(p).isNotEmpty))
        PostalAddress(
          label: t(a.label),
          street: t(a.street),
          locality: t(a.locality),
          region: t(a.region),
          postalCode: t(a.postalCode),
          country: t(a.country),
        ),
  ];
  final name = [t(form.givenName), t(form.familyName)].where((p) => p.isNotEmpty).join(' ');
  final company = t(form.company);
  final shown = name.isNotEmpty
      ? name
      : company.isNotEmpty
          ? company
          : (emails.isNotEmpty ? emails.first.value : (phones.isNotEmpty ? phones.first.value : 'No name'));
  final first = shown[0].toUpperCase();
  final birthday = t(form.birthday).isEmpty ? null : t(form.birthday);
  final note = t(form.note);
  String? caption;
  if (company.isNotEmpty && company != shown) {
    caption = company;
  } else {
    for (final v in [...emails.map((e) => e.value), ...phones.map((p) => p.value)]) {
      if (v != shown) {
        caption = v;
        break;
      }
    }
  }
  return ContactDetailOut(
    accountId: 'local',
    addressBookId: 'book-mydata',
    addresses: addresses,
    birthday: birthday,
    caption: caption,
    company: company,
    createdAt: created,
    department: t(form.department),
    displayName: shown,
    editable: true,
    emails: emails,
    etag: '"$rev-$id"',
    familyName: t(form.familyName),
    givenName: t(form.givenName),
    fullName: name,
    id: id,
    jobTitle: t(form.jobTitle),
    middleName: t(form.middleName),
    modifiedAt: '2026-10-14T09:00:0${rev % 10}+00:00',
    namePrefix: t(form.namePrefix),
    nameSuffix: t(form.nameSuffix),
    nickname: t(form.nickname),
    note: note,
    notesIncluded: true,
    onPhone: false,
    organisation: company,
    phones: phones,
    sortLetter: RegExp('[A-Z]').hasMatch(first) ? first : '#',
    source_: ContactDetailOutSource_Enum.mydata,
    sourceLabel: 'myData',
    urls: urls,
    fields: [
      if (phones.isNotEmpty)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.phone, title: 'Phone', items: [
          for (final p in phones) ContactField(label: p.label, value: p.value),
        ]),
      if (emails.isNotEmpty)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.email, title: 'Email', items: [
          for (final e in emails) ContactField(label: e.label, value: e.value),
        ]),
      if (addresses.isNotEmpty)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.address, title: 'Address', items: [
          for (final a in addresses)
            ContactField(
              label: a.label,
              value: [a.street, [a.locality, a.region, a.postalCode].where((p) => p.isNotEmpty).join(' '), a.country]
                  .where((p) => p.isNotEmpty)
                  .join('\n'),
              address: a,
            ),
        ]),
      if (birthday != null)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.birthday, title: 'Birthday', items: [ContactField(value: birthday)]),
      if (urls.isNotEmpty)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.url, title: 'Links', items: [
          for (final u in urls) ContactField(label: u.label, value: u.value),
        ]),
      if (note.isNotEmpty)
        ContactFieldGroup(kind: ContactFieldGroupKindEnum.note, title: 'Notes', items: [ContactField(value: note)]),
    ],
  );
}

/// Pip Owned: a contact the host owns (made in myContacts), with a phone, an email, an address, a birthday
/// without a year, a link and notes.
ContactDetailOut pipOwned() => ownedCard(
      'c-pip',
      ContactIn(
        givenName: 'Pip',
        familyName: 'Owned',
        company: 'Example Library',
        jobTitle: 'Archivist',
        middleName: 'Quinn',
        nickname: 'Pipster',
        phones: [LabeledValueIn(label: 'Mobile', value: '555-0142')],
        emails: [LabeledValueIn(label: 'Work', value: 'pip@example.org')],
        addresses: [
          PostalAddressIn(label: 'Home', street: '1 Example Street', locality: 'Sampleton', postalCode: 'ZZ1 1AA', country: 'United Kingdom'),
        ],
        birthday: '--03-09',
        urls: [LabeledValueIn(label: 'Home page', value: 'example.org/pip')],
        note: 'Keeps the invented archive.',
      ),
      rev: 3,
    );

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
  source_: switch (c.source_) {
    ContactDetailOutSource_Enum.mac => ContactOutSource_Enum.mac,
    ContactDetailOutSource_Enum.icloud => ContactOutSource_Enum.icloud,
    ContactDetailOutSource_Enum.mydata => ContactOutSource_Enum.mydata,
  },
  notesIncluded: c.notesIncluded,
  etag: c.etag,
  editable: c.editable,
  onPhone: c.onPhone,
  purgeAfter: c.purgeAfter,
  changedInSource: c.changedInSource,
  mergedInto: c.mergedInto,
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
    editable: false,
    emails: [for (final e in emails) LabeledValue(label: e.$1, value: e.$2)],
    etag: '"1-$id"',
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
