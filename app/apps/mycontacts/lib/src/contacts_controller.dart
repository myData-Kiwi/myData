import 'dart:async';

import 'package:flutter/painting.dart' show ImageProvider;
import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'host_photo.dart';

/// Where a contact's page is: still being read, read, gone from the host, or not readable now.
sealed class ContactDetail {
  const ContactDetail();
}

class DetailLoading extends ContactDetail {
  const DetailLoading();
}

class DetailReady extends ContactDetail {
  const DetailReady(this.contact);
  final ContactDetailOut contact;
}

/// The host has no contact with this id (deleted, or its source turned off).
class DetailMissing extends ContactDetail {
  const DetailMissing();
}

class DetailFailed extends ContactDetail {
  const DetailFailed();
}

/// Everything myContacts shows, read from the host: whether a source is on, every contact, the one open,
/// and each opened contact's page. Nothing here writes to the host: the app only reads.
///
/// - The sources are checked when the host is first reached and then at most every [checkInterval] while
///   the host is polled; the contacts are read again whenever a source is turned on or off or reads its
///   contacts again ([SourcesState.revision]).
/// - The contact open from 600px is the one last opened on this device ([lastOpenedKey] in the
///   [DeviceStore]) if it is still there, otherwise the first in the list ([initialContactSelection]).
/// - A link (`mycontacts://contact/<id>`) opens that contact once the list is read. An id the list does not
///   have is asked of the host first, since the link may come from a fresher read (myAssistant's): when the
///   host has it, it opens and the list is read again; otherwise it is kept in [missingLinkId] so the screen
///   can say so, until a later read of the list brings it in.
class ContactsController extends ChangeNotifier {
  ContactsController({required this.backend, DeviceStore? store, this.checkInterval = const Duration(seconds: 5)})
    : store = store ?? deviceStore,
      photos = PhotoCache(backend);

  final ContactsBackend backend;
  final DeviceStore store;
  final Duration checkInterval;
  final PhotoCache photos;

  /// The key in the device store that holds the id of the contact last opened.
  static const lastOpenedKey = 'lastContact';

  /// Whether any source is on; null until the host has answered once.
  bool? anySourceOn;

  /// Every contact, in the host's order; null until read.
  List<ContactOut>? contacts;

  /// [contacts] as the list shows them.
  List<ContactListEntry> entries = const [];

  /// The contacts could not be read (the last attempt failed and none are shown).
  bool loadFailed = false;

  /// When the contacts on screen were last read from the host.
  DateTime? updatedAt;

  /// The contact open in the contact pane (from 600px), or the one the keyboard starts on (under 600px).
  String? selectedId;

  /// A link asked for a contact the host does not have.
  String? missingLinkId;

  /// Each link that opened a contact, so a phone layout can push its page.
  Stream<String> get linkOpened => _linkOpened.stream;
  final _linkOpened = StreamController<String>.broadcast();

  final _details = <String, ContactDetail>{};
  String? _revision;
  DateTime? _lastCheck;
  bool _checking = false;

  /// The list must be read again once the check under way ends.
  bool _again = false;

  /// Bumped by every link and every contact the user opens, so an older link's answer does not win.
  int _openTicket = 0;

  /// A linked contact the host has that the list did not have yet: kept open until the list catches up.
  String? _unlisted;
  String? _lastOpened;
  bool _lastOpenedRead = false;
  String? _pendingLink;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  /// Called on every word from the host (each status poll): reads the sources and, when they changed, the
  /// contacts. Nothing is asked while the host is not running.
  Future<void> follow(HostPhase phase) async {
    if (phase != HostPhase.running || _checking) return;
    final now = DateTime.now();
    final last = _lastCheck;
    if (last != null && !loadFailed && now.difference(last) < checkInterval) return;
    _lastCheck = now;
    await _check();
  }

  /// Read the sources and the contacts again now (Retry).
  Future<void> reload() async {
    if (_checking) return;
    _revision = null;
    loadFailed = false;
    _notify();
    await _check();
  }

  Future<void> _check() async {
    _checking = true;
    try {
      if (!_lastOpenedRead) await _readLastOpened();
      final SourcesState state;
      try {
        state = await backend.sources();
      } on Object {
        // An older host, or a moment without an answer: keep what is shown and try on a later poll.
        if (contacts == null) {
          loadFailed = true;
          _notify();
        }
        return;
      }
      anySourceOn = state.anyOn;
      if (!state.anyOn) {
        _revision = state.revision;
        _setContacts(const []);
        return;
      }
      if (state.revision == _revision && contacts != null) return;
      final List<ContactOut> read;
      try {
        read = await backend.contacts();
      } on Object {
        loadFailed = contacts == null;
        _notify();
        return;
      }
      _revision = state.revision;
      _setContacts(read);
    } finally {
      _checking = false;
      if (_again && !_disposed) {
        _again = false;
        unawaited(_check());
      }
    }
  }

  /// Read the list again now, or as soon as the check under way ends, whatever the sources say.
  void _readListAgain() {
    _revision = null;
    if (_checking) {
      _again = true;
    } else {
      unawaited(_check());
    }
  }

  void _setContacts(List<ContactOut> read) {
    final changed = contacts != null;
    // Photos are keyed by each card's last change, so an unchanged photo is not fetched again; a removed
    // contact's photo is forgotten here.
    if (changed) photos.clear();
    contacts = read;
    loadFailed = false;
    updatedAt = DateTime.now();
    entries = [for (final c in read) _entry(c)];
    final ids = {for (final c in read) c.id};
    if (_unlisted != null && ids.contains(_unlisted)) _unlisted = null;
    final pending = _pendingLink ?? (missingLinkId != null && ids.contains(missingLinkId) ? missingLinkId : null);
    if (pending != null) {
      _pendingLink = null;
      _openLink(pending, ids);
    } else if (selectedId == null || (!ids.contains(selectedId) && selectedId != _unlisted)) {
      selectedId = initialContactSelection(entries, _lastOpened);
    }
    final selected = selectedId;
    if (changed) {
      // What changed on the host may have changed any page: forget them, and read the open one again while
      // it stays on screen, so it does not blink.
      final shown = selected == null ? null : _details[selected];
      _details.clear();
      if (selected != null && shown is DetailReady) {
        _details[selected] = shown;
        unawaited(_readDetail(selected));
      }
    }
    if (selected != null) ensureDetail(selected);
    _notify();
  }

  ContactListEntry _entry(ContactOut c) => ContactListEntry(
    id: c.id,
    name: c.displayName,
    givenName: c.givenName,
    familyName: c.familyName,
    organisation: c.organisation,
    emails: [for (final e in c.emails) e.value],
    phones: [for (final p in c.phones) p.value],
    caption: c.caption,
    letter: c.sortLetter,
    photo: c.hasPhoto ? HostPhoto(photos, c.id, c.modifiedAt) : null,
  );

  /// The list entry for [id], or null.
  ContactListEntry? entryFor(String? id) {
    if (id == null) return null;
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The contact's photo for its page, or null when it has none.
  ImageProvider? photoFor(ContactDetailOut c) => c.hasPhoto ? HostPhoto(photos, c.id, c.modifiedAt) : null;

  /// The user opened [id]: it becomes the open contact and is remembered on this device.
  void open(String id) {
    _openTicket++;
    _unlisted = null;
    missingLinkId = null;
    if (selectedId != id) selectedId = id;
    ensureDetail(id);
    _remember(id);
    _notify();
  }

  /// A link asked for [link]'s contact. It opens once the list is read; an unknown id is reported.
  void openLink(OpenContact link) {
    final read = contacts;
    if (read == null) {
      _pendingLink = link.id;
      return;
    }
    _openLink(link.id, {for (final c in read) c.id});
    _notify();
  }

  void _openLink(String id, Set<String> ids) {
    final ticket = ++_openTicket;
    if (!ids.contains(id)) {
      unawaited(_openUnlisted(id, ticket));
      return;
    }
    _unlisted = null;
    _showLinked(id);
  }

  void _showLinked(String id) {
    missingLinkId = null;
    selectedId = id;
    ensureDetail(id);
    _remember(id);
    _linkOpened.add(id);
  }

  /// A link to a contact the list read earlier does not have. The host may have it (synced since), so it is
  /// asked: when it has it, the contact opens now and the list is read again so it appears there too;
  /// otherwise the screen says it is missing.
  Future<void> _openUnlisted(String id, int ticket) async {
    ContactDetailOut? found;
    try {
      found = await backend.contact(id);
    } on Object {
      found = null;
    }
    if (_disposed || ticket != _openTicket) return;
    if (found == null) {
      missingLinkId = id;
      selectedId = null;
    } else {
      _details[id] = DetailReady(found);
      _unlisted = id;
      _showLinked(id);
      _readListAgain();
    }
    _notify();
  }

  /// The page of contact [id] as far as it has been read.
  ContactDetail detailOf(String id) => _details[id] ?? const DetailLoading();

  /// Read contact [id]'s page unless it is read or being read.
  void ensureDetail(String id) {
    final known = _details[id];
    if (known != null && known is! DetailFailed) return;
    _details[id] = const DetailLoading();
    unawaited(_readDetail(id));
  }

  /// Read contact [id]'s page again after it failed.
  void retryDetail(String id) {
    _details.remove(id);
    ensureDetail(id);
    _notify();
  }

  Future<void> _readDetail(String id) async {
    ContactDetail result;
    try {
      final c = await backend.contact(id);
      result = c == null ? const DetailMissing() : DetailReady(c);
    } on Object {
      result = const DetailFailed();
    }
    if (_disposed) return;
    _details[id] = result;
    _notify();
  }

  Future<void> _readLastOpened() async {
    try {
      final v = (await store.read())[lastOpenedKey];
      _lastOpened = v is String && OpenContact.isValidId(v) ? v : null;
    } on Object {
      _lastOpened = null;
    }
    _lastOpenedRead = true;
  }

  void _remember(String id) {
    if (_lastOpened == id) return;
    _lastOpened = id;
    // Merged into what is stored now, so the mode and the other apps' settings are kept; one write at a time.
    _writes = _writes.then((_) async {
      try {
        final values = await store.read();
        await store.write({...values, lastOpenedKey: id});
      } on Object {
        // Not remembered this time: the app works the same without it.
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_linkOpened.close());
    super.dispose();
  }
}
