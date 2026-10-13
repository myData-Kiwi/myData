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

/// myContacts' way to the host. The app only reads: there is no method that changes a contact.
abstract class ContactsBackend {
  /// Which sources are on.
  Future<SourcesState> sources();

  /// Every contact, in the host's order (by name, in the locale's order).
  Future<List<ContactOut>> contacts();

  /// One contact for its page, or null when the host has no contact with [id].
  Future<ContactDetailOut?> contact(String id);

  /// The contact's photo (JPEG or PNG), or null when it has none.
  Future<Uint8List?> photo(String id);
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
}
