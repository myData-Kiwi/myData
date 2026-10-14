import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contacts_controller.dart';
import 'merge.dart';

/// Review's state (design/components/DuplicatePair, "The Review section"): the host's possible duplicates
/// among its own contacts (H6a) and the contacts whose followed copy changed since the import (H7), the one
/// selected, and its pair: a [MergeSession] for two people who may be one, a [ChangesSession] for a change.
class ReviewModel extends ChangeNotifier {
  ReviewModel({required this.controller}) {
    controller.addListener(_contactsChanged);
  }

  final ContactsController controller;
  ContactsBackend get backend => controller.backend;

  /// The possible duplicates, strong ones first; null until read.
  List<DuplicatePairOut>? pairs;
  bool failed = false;

  /// The selected row: [pairKey] or [changedKey]; null when none is.
  String? selected;

  MergeSession? pair;
  ChangesSession? changes;

  /// A line in the pane when the selected pair is no longer a duplicate.
  String? paneLine;

  bool _disposed = false;
  int _loads = 0;

  /// The section is on screen: only then is a row selected and its pair read.
  bool get active => _active;
  bool _active = false;
  set active(bool v) {
    if (v == _active) return;
    _active = v;
    if (v) {
      _keepSelection();
    } else {
      _clearPane();
      selected = null;
    }
    _notify();
  }

  /// The contacts of yours whose followed copy changed since the import, in the list's order.
  List<ContactOut> get changed => [
        for (final c in controller.contacts ?? const <ContactOut>[])
          if (c.editable && c.changedInSource != null) c,
      ];

  /// How many things wait here, for the sidebar ("Review, 4").
  int get count => (pairs?.length ?? 0) + changed.length;

  static String pairKey(DuplicatePairOut p) => 'pair:${(p.contacts.map((c) => c.id).toList()..sort()).join('|')}';
  static String changedKey(String id) => 'changed:$id';

  /// The rows in order: the pairs, then the changed contacts.
  List<String> get keys => [
        for (final p in pairs ?? const <DuplicatePairOut>[]) pairKey(p),
        for (final c in changed) changedKey(c.id),
      ];

  DuplicatePairOut? pairOf(String key) => (pairs ?? const <DuplicatePairOut>[]).where((p) => pairKey(p) == key).firstOrNull;

  /// Reads the possible duplicates again; the selection moves to the first row when its own has gone.
  Future<void> load() async {
    final ticket = ++_loads;
    try {
      final read = await backend.duplicates();
      if (_disposed || ticket != _loads) return;
      pairs = read;
      failed = false;
    } on Object {
      if (_disposed || ticket != _loads) return;
      failed = pairs == null;
    }
    _keepSelection();
    _notify();
  }

  void _contactsChanged() {
    if (_disposed) return;
    // Only pages never read: this runs on every notify of the controller, a failed read included, so
    // retrying here would loop on the host. A failed page is read again with the list's next read.
    for (final c in changed) {
      controller.ensureDetail(c.id, retryFailed: false);
    }
    _keepSelection();
    _notify();
  }

  void _keepSelection({int? at}) {
    if (!_active) return;
    final k = keys;
    if (selected != null && k.contains(selected)) return;
    if (k.isEmpty) {
      _clearPane();
      selected = null;
      return;
    }
    select(k[(at ?? 0).clamp(0, k.length - 1)]);
  }

  /// Opens [key]'s pair in the pane.
  void select(String key) {
    if (selected == key && (pair != null || changes != null)) return;
    _clearPane();
    selected = key;
    paneLine = null;
    final p = pairOf(key);
    if (p != null) {
      pair = MergeSession(backend: backend, ids: [for (final c in p.contacts) c.id])..addListener(_notify);
      unawaited(pair!.load());
    } else if (key.startsWith('changed:')) {
      changes = ChangesSession(backend: backend, id: key.substring('changed:'.length))..addListener(_notify);
      unawaited(changes!.load());
    }
    _notify();
  }

  /// The section left the screen (its view is being disposed): the pane goes, without telling anyone, since
  /// nothing on screen shows it any more.
  void leaveQuietly() {
    _active = false;
    _clearPane();
    selected = null;
  }

  /// A link from a contact page's Notice: Review opens on that contact, in Changes.
  void openChanged(String id) {
    _active = true;
    selected = null;
    select(changedKey(id));
  }

  void _clearPane() {
    pair?.removeListener(_notify);
    pair?.dispose();
    pair = null;
    changes?.removeListener(_notify);
    changes?.dispose();
    changes = null;
  }

  /// The row after [key] goes; the selection moves to the next.
  void leave(String key) {
    final at = keys.indexOf(key);
    pairs = [for (final p in pairs ?? const <DuplicatePairOut>[]) if (pairKey(p) != key) p];
    _clearPane();
    selected = null;
    _keepSelection(at: at < 0 ? 0 : at);
    _notify();
  }

  // ---- Not the same person (H6b) ------------------------------------------------------------------------

  /// Records that the selected pair are different people. Returns the Undo entry, or null with [paneLine].
  Future<UndoEntry?> notSamePerson() async {
    final key = selected;
    final p = key == null ? null : pairOf(key);
    if (p == null || key == null) return null;
    final s = pair;
    try {
      final undoId = await backend.notDuplicates(p.contacts[0].id, p.contacts[1].id);
      final entry = controller.reviewed(
        action: markAction,
        undoId: undoId,
        name: '${p.contacts[0].displayName} and ${p.contacts[1].displayName}',
        undone: markUndone,
        contactIds: [p.contacts[0].id, p.contacts[1].id],
      );
      leave(key);
      return entry;
    } on Object {
      s?.message = markFailed;
      s?.messageIsError = true;
      _notify();
      return null;
    }
  }

  static const markAction = 'Mark as different people';
  static const markUndone = 'Offered as a possible duplicate again';
  static const markFailed =
      'They were not marked as different people. The host did not answer. Check that it is running, then try again.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_contactsChanged);
    _clearPane();
    super.dispose();
  }
}

/// One contact whose followed copy changed since the import (H7): the contact and the copy as they are now,
/// what differs (the host's word), and which side's values the "After" column takes for each, the followed
/// copy's by default.
class ChangesSession extends ChangeNotifier {
  ChangesSession({required this.backend, required this.id});

  final ContactsBackend backend;
  final String id;

  FollowedChangesOut? data;
  bool loading = true;
  bool working = false;

  /// "Saving…" while [working] on a save, else "Keeping…".
  bool saving = false;
  String? message;
  bool messageIsError = false;

  /// Nothing to review any more (settled elsewhere, or the copy changed back).
  bool nothing = false;

  /// By kind: 0 keeps the contact's own values, 1 takes the followed copy's.
  final choices = <PairField, int>{};

  bool _disposed = false;

  FollowedChangeOut? get change => data?.changes.firstOrNull;

  /// The kinds that differ and can be written here (a photo or another detail is said, not chosen).
  Set<PairField> get choosable => {
        for (final d in change?.differences ?? const <String>[])
          if (_field(d) case final f? when f != PairField.photo) f,
      };

  /// Every kind the host says differs, for the band and "Differs".
  Set<PairField> get differences => {
        for (final d in change?.differences ?? const <String>[]) ?_field(d),
      };

  static PairField? _field(String d) => switch (d) {
        'name' || 'nickname' => PairField.name,
        'company' => PairField.company,
        'job_title' => PairField.jobTitle,
        'phone' => PairField.phone,
        'email' => PairField.email,
        'address' => PairField.address,
        'birthday' => PairField.birthday,
        'url' => PairField.links,
        'note' => PairField.notes,
        'photo' => PairField.photo,
        _ => null,
      };

  Future<void> load({String? changedName}) async {
    loading = true;
    _notify();
    try {
      final out = await backend.followedChanges(id);
      if (_disposed) return;
      final before = data;
      data = out;
      nothing = out.changes.isEmpty;
      if (changedName != null && before != null) {
        message = MergeSession.changedLine(changedName);
        messageIsError = false;
      }
      for (final f in choosable) {
        choices.putIfAbsent(f, () => 1);
      }
      choices.removeWhere((f, _) => !choosable.contains(f));
    } on Gone {
      nothing = true;
    } on Object {
      message = loadFailed;
      messageIsError = true;
    }
    loading = false;
    _notify();
  }

  void choose(PairField f, int version) {
    if (working) return;
    choices[f] = version;
    _notify();
  }

  List<FollowedSeenIn> get _seen {
    final c = change;
    return c == null ? const [] : [FollowedSeenIn(id: c.followed.id, etag: c.followed.etag)];
  }

  /// The contact as Save writes it: its own values, with the followed copy's for each kind chosen.
  ContactIn form() {
    final mine = data!.contact;
    final theirs = change!.followed;
    bool take(PairField f) => choosable.contains(f) && (choices[f] ?? 1) == 1;
    final n = take(PairField.name) ? theirs : mine;
    final co = take(PairField.company) ? theirs : mine;
    List<LabeledValueIn> labelled(List<LabeledValue> l) => [for (final v in l) LabeledValueIn(label: v.label, value: v.value)];
    final addresses = (take(PairField.address) ? theirs : mine).addresses;
    return ContactIn(
      givenName: n.givenName,
      familyName: n.familyName,
      middleName: n.middleName,
      namePrefix: n.namePrefix,
      nameSuffix: n.nameSuffix,
      nickname: n.nickname,
      company: co.company,
      department: co.department,
      jobTitle: (take(PairField.jobTitle) ? theirs : mine).jobTitle,
      phones: labelled((take(PairField.phone) ? theirs : mine).phones),
      emails: labelled((take(PairField.email) ? theirs : mine).emails),
      urls: labelled((take(PairField.links) ? theirs : mine).urls),
      addresses: [
        for (final a in addresses)
          PostalAddressIn(
            label: a.label,
            street: a.street,
            locality: a.locality,
            region: a.region,
            postalCode: a.postalCode,
            country: a.country,
          ),
      ],
      birthday: (take(PairField.birthday) ? theirs : mine).birthday ?? '',
      note: (take(PairField.notes) ? theirs : mine).note,
    );
  }

  /// Save changes: the "After" column into the contact (If-Match), clearing the mark. Null on failure, with
  /// [message] set.
  Future<Written?> save() => _write(saving: true, () {
        final c = data!.contact;
        return backend.saveFollowed(c.id, c.etag, form(), _seen);
      });

  /// Keep mine: the mark goes, the contact stays as it is.
  Future<Written?> keep() => _write(saving: false, () => backend.keepMine(data!.contact.id, _seen));

  Future<Written?> _write(Future<Written> Function() call, {required bool saving}) async {
    if (working || data == null || change == null) return null;
    working = true;
    this.saving = saving;
    message = null;
    _notify();
    try {
      final w = await call();
      working = false;
      return w;
    } on ChangedElsewhere {
      working = false;
      await load(changedName: data?.contact.displayName);
      return null;
    } on Object {
      working = false;
      message = saving ? saveFailed : keepFailed;
      messageIsError = true;
      _notify();
      return null;
    }
  }

  static const saveFailed =
      'The changes were not saved. The host did not answer. Check that it is running, then try again.';
  static const keepFailed =
      'Your version was not kept. The host did not answer. Check that it is running, then try again.';
  static const loadFailed =
      'The changes could not be read. The host did not answer. Check that it is running, then try again.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
