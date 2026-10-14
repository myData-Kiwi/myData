import 'dart:convert';
import 'dart:typed_data';

import 'package:mydata_core/mydata_core.dart';

/// What the sources look like now: whether any is on, and a fingerprint that changes whenever one of them
/// is turned on or off or reads its contacts again, so the app knows when to read the list again.
class SourcesState {
  const SourcesState({required this.anyOn, required this.revision});

  /// At least one source (This Mac, an iCloud account) is on.
  final bool anyOn;

  /// Changes when a source is turned on or off or its last update changes.
  final String revision;

  /// The state the host's `GET /sources` answer describes.
  factory SourcesState.of(SourcesOut out) {
    final on = out.sources.where((s) => s.enabled).toList();
    return SourcesState(
      anyOn: on.isNotEmpty,
      revision: [for (final s in on) '${s.id}:${s.lastUpdate ?? ''}:${s.counts?.contacts ?? ''}'].join('|'),
    );
  }
}

/// Why the host refused or could not do a write. The messages here are the app's own; the host's text is
/// never shown as it is.
sealed class WriteFailure implements Exception {
  const WriteFailure();
}

/// Some fields are not valid: the host's message per field, by its path in the body ("emails[1].value").
class FieldErrors extends WriteFailure {
  const FieldErrors(this.fields);
  final Map<String, String> fields;
}

/// The contact changed on the host since the etag the change was made from (412).
class ChangedElsewhere extends WriteFailure {
  const ChangedElsewhere();
}

/// The host refused: the contact is followed from a source, is in Recently deleted, or the undo is no longer
/// possible because it changed since or was deleted for good (409).
class Refused extends WriteFailure {
  const Refused(this.detail);

  /// The host's sentence, for logs and tests only.
  final String detail;
}

/// The host has no such contact (404): deleted for good, or its source turned off.
class Gone extends WriteFailure {
  const Gone();
}

/// The host did not answer, or answered something the app does not understand.
class NoAnswer extends WriteFailure {
  const NoAnswer();
}

/// What a write left behind: the contact as it is now and the id that undoes the write (null when nothing
/// changed).
class Written {
  const Written(this.contact, this.undoId);
  final ContactDetailOut contact;
  final String? undoId;
}

/// myContacts' way to the host: reading every contact, and writing the ones the host owns (`editable`).
/// Followed contacts (This Mac, an iCloud account) are never written; the host refuses them anyway.
abstract class ContactsBackend {
  /// Which sources are on.
  Future<SourcesState> sources();

  /// Every contact, in the host's order (by name, in the locale's order).
  Future<List<ContactOut>> contacts();

  /// One contact for its page, or null when the host has no contact with [id].
  Future<ContactDetailOut?> contact(String id);

  /// The contact's photo (JPEG or PNG), or null when it has none.
  Future<Uint8List?> photo(String id);

  /// A new contact the host owns. Throws a [WriteFailure].
  Future<Written> create(ContactIn form);

  /// Changes contact [id] from the version [etag]; the whole form is sent. Throws a [WriteFailure]
  /// ([ChangedElsewhere] when it changed since).
  Future<Written> update(String id, String etag, ContactIn form);

  /// Moves contact [id] to Recently deleted, from the version [etag] the user chose (the host requires it).
  /// Throws a [WriteFailure] ([ChangedElsewhere] when it changed since).
  Future<Written> delete(String id, String etag);

  /// Recently deleted, the most recently deleted first.
  Future<List<TrashItemOut>> trash();

  /// Brings [id] back from Recently deleted, from the version [etag] Recently deleted listed when known.
  /// Throws a [WriteFailure] ([ChangedElsewhere] when it changed since).
  Future<Written> restore(String id, {String? etag});

  /// Deletes [id], which is in Recently deleted, for good, from the version [etag] Recently deleted listed
  /// (the host requires it, so a version changed elsewhere is never deleted unseen). Throws a [WriteFailure].
  Future<void> purge(String id, String etag);

  /// Undoes the write [undoId] names. Throws a [WriteFailure] ([Refused] when the contact changed since).
  Future<ContactDetailOut> undo(String undoId);

  /// What merging [contacts] (each with the etag the user saw, in order) would make, keeping the names and
  /// details of [namesFrom] (null: the one changed most recently). Writes nothing (H6c). Throws a
  /// [WriteFailure].
  Future<MergePreviewOut> mergePreview(List<MergeContactIn> contacts, {String? namesFrom});

  /// Merges [contacts] into a new contact; the originals go to Recently deleted. Throws a [WriteFailure]
  /// ([ChangedElsewhere] when one changed since, [Gone] when one is gone, [Refused] for a followed one).
  Future<MergeOut> merge(List<MergeContactIn> contacts, {String? namesFrom});

  /// Pairs of the host's own contacts that may be the same person, strong ones first (H6a).
  Future<List<DuplicatePairOut>> duplicates();

  /// Records that [a] and [b] are different people, until undone (H6b). Returns the undo id.
  Future<String> notDuplicates(String a, String b);

  /// The followed copies of contact [id] that changed since the import, beside it (H7).
  Future<FollowedChangesOut> followedChanges(String id);

  /// Writes [form] into contact [id] from the version [etag], and clears the mark of the copies [seen]
  /// (H7). Throws a [WriteFailure].
  Future<Written> saveFollowed(String id, String etag, ContactIn form, List<FollowedSeenIn> seen);

  /// Clears the mark of the copies [seen] without changing contact [id] (H7). Throws a [WriteFailure].
  Future<Written> keepMine(String id, List<FollowedSeenIn> seen);
}

/// The host's API, through the app's current connection.
class HostContactsBackend implements ContactsBackend {
  HostContactsBackend(this._connection);

  final HostConnection? Function() _connection;

  /// The most contacts asked for at once (the host's limit).
  static const pageSize = 1000;

  SourcesApi get _api {
    final c = _connection();
    if (c == null) throw StateError('The myData host is not connected.');
    return c.sources;
  }

  @override
  Future<SourcesState> sources() async {
    final out = await _api.sources();
    if (out == null) throw StateError('The host sent no sources.');
    return SourcesState.of(out);
  }

  @override
  Future<List<ContactOut>> contacts() async {
    final api = _api;
    final all = <ContactOut>[];
    while (true) {
      final page = await api.contacts(limit: pageSize, offset: all.length) ?? const <ContactOut>[];
      all.addAll(page);
      if (page.length < pageSize) return all;
    }
  }

  @override
  Future<ContactDetailOut?> contact(String id) async {
    try {
      return await _api.contact(id);
    } on ApiException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Uint8List?> photo(String id) async {
    final response = await _api.contactPhotoWithHttpInfo(id);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  @override
  Future<Written> create(ContactIn form) => _write(() => _api.createContact(form));

  @override
  Future<Written> update(String id, String etag, ContactIn form) =>
      _write(() => _api.updateContact(id, form, ifMatch: etag));

  @override
  Future<Written> delete(String id, String etag) => _write(() => _api.deleteContact(id, ifMatch: etag));

  @override
  Future<Written> restore(String id, {String? etag}) => _write(() => _api.restoreItem(id, ifMatch: etag));

  @override
  Future<List<TrashItemOut>> trash() async => await _api.trash(kind: 'contact') ?? const <TrashItemOut>[];

  @override
  Future<void> purge(String id, String etag) => _guard(() => _api.purgeItem(id, ifMatch: etag));

  @override
  Future<ContactDetailOut> undo(String undoId) async {
    final out = await _guard(() => _api.undo(undoId));
    if (out == null) throw const NoAnswer();
    return out.contact;
  }

  @override
  Future<MergePreviewOut> mergePreview(List<MergeContactIn> contacts, {String? namesFrom}) async {
    final out = await _guard(() => _api.mergePreview(MergeIn(contacts: contacts, namesFrom: namesFrom)));
    if (out == null) throw const NoAnswer();
    return out;
  }

  @override
  Future<MergeOut> merge(List<MergeContactIn> contacts, {String? namesFrom}) async {
    final out = await _guard(() => _api.mergeContacts(MergeIn(contacts: contacts, namesFrom: namesFrom)));
    if (out == null) throw const NoAnswer();
    return out;
  }

  @override
  Future<List<DuplicatePairOut>> duplicates() async => await _api.duplicates() ?? const <DuplicatePairOut>[];

  @override
  Future<String> notDuplicates(String a, String b) async {
    final out = await _guard(() => _api.notDuplicates(NotDuplicatesIn(ids: [a, b])));
    if (out == null) throw const NoAnswer();
    return out.undoId;
  }

  @override
  Future<FollowedChangesOut> followedChanges(String id) async {
    final out = await _guard(() => _api.followedChanges(id));
    if (out == null) throw const NoAnswer();
    return out;
  }

  @override
  Future<Written> saveFollowed(String id, String etag, ContactIn form, List<FollowedSeenIn> seen) =>
      _write(() => _api.saveFollowedChanges(id, FollowedSaveIn(contact: form, followed: seen), ifMatch: etag));

  @override
  Future<Written> keepMine(String id, List<FollowedSeenIn> seen) =>
      _write(() => _api.keepMine(id, FollowedKeepIn(followed: seen)));

  static Future<Written> _write(Future<ContactWriteOut?> Function() call) async {
    final out = await _guard(call);
    if (out == null) throw const NoAnswer();
    return Written(out.contact, out.undoId);
  }

  /// Runs [call], turning the host's refusals into [WriteFailure]s.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw writeFailureOf(e.code, e.message);
    } on WriteFailure {
      rethrow;
    } on Object {
      throw const NoAnswer();
    }
  }
}

/// The [WriteFailure] for the host's answer [code] with [body].
WriteFailure writeFailureOf(int code, String? body) {
  switch (code) {
    case 400:
      try {
        final json = jsonDecode(body ?? '');
        final fields = json is Map ? json['fields'] : null;
        if (fields is Map) return FieldErrors({for (final e in fields.entries) '${e.key}': '${e.value}'});
      } on FormatException {
        // Not the host's field errors: treated as no answer.
      }
      return const NoAnswer();
    case 412:
      return const ChangedElsewhere();
    case 404:
      return const Gone();
    case 409:
      String detail = '';
      try {
        final json = jsonDecode(body ?? '');
        if (json is Map && json['detail'] is String) detail = json['detail'] as String;
      } on FormatException {
        detail = '';
      }
      return Refused(detail);
    default:
      return const NoAnswer();
  }
}
