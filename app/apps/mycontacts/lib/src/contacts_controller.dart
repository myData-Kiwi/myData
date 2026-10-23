import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show ImageProvider;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'host_photo.dart';
import 'merge.dart';

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

/// One change this app made on the host that Undo takes back (design/platforms.md "Undo and Redo name the
/// action"). Several ids when one action wrote several contacts ("Delete 3 contacts").
class UndoEntry {
  UndoEntry({
    required this.action,
    required this.undoIds,
    required this.names,
    required this.undone,
    this.contactIds = const [],
  });

  /// The contacts the action wrote, so a delete for good can take the entry off [ContactsController.undoStack].
  final List<String> contactIds;

  /// The action's verb and object in sentence case: "Delete contact", "Delete 3 contacts", "Edit contact",
  /// "Add contact", "Restore contact". The menu bar writes it in title case ("Undo Delete Contact").
  final String action;
  final List<String> undoIds;

  /// The contacts' names, for "Not undone. Ava Fictional was changed after that."
  final List<String> names;

  /// What the toast says once it is undone: "Contact restored", "Changes undone".
  final String undone;
}

/// The contact the inspector is open on: [original] null for a new contact. Each opening has its own
/// [serial], so a new opening (or a reload) gets a fresh form and a fresh inspector.
class ContactEdit {
  ContactEdit(this.original, this.serial);
  final ContactDetailOut? original;
  final int serial;

  /// The inspector, for leaving with the check for changes ([InspectorState.requestClose]).
  final inspector = GlobalKey<InspectorState>();

  String? get id => original?.id;
}

/// What a delete, restore or purge of several contacts came to: the ids it acted on before any [failure].
class BulkResult {
  const BulkResult(this.done, this.failure, this.entry);
  final List<String> done;
  final WriteFailure? failure;

  /// What Undo takes back; null when nothing was done or it cannot be undone (a purge).
  final UndoEntry? entry;
}

/// Everything myContacts shows, read from the host: whether a source is on, every contact, the one open (or
/// the several selected), each opened contact's page, Recently deleted, the inspector's record, and what
/// Undo takes back. It writes only contacts the host owns (`editable`); followed ones are never written.
///
/// - The contacts are read whatever the sources say, since the host owns contacts made here; a source
///   turned on or off, or a write of this app's, reads them again.
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
      photos = PhotoCache(backend) {
    selection.addListener(_selectionChanged);
  }

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

  /// The rows selected in the list (from 600px): one is the contact open; several show the count.
  final selection = MultiSelectController<String>();

  /// The inspector's record, or null while none is open.
  ContactEdit? editing;
  int _editSerial = 0;

  /// What Undo takes back, newest last: this app's changes in this session.
  final undoStack = <UndoEntry>[];

  /// Recently deleted, newest first; null until read.
  List<TrashItemOut>? trash;
  bool trashFailed = false;

  /// A failure to say in the contact pane for [paneErrorId] ("… could not be deleted"), until the next
  /// action or another contact.
  String? paneError;
  String? paneErrorId;

  final _byId = <String, ContactOut>{};

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
      if (_disposed) return;
      anySourceOn = state.anyOn;
      // The host's own contacts are listed whatever the sources say.
      if (state.revision == _revision && contacts != null) return;
      final List<ContactOut> read;
      try {
        read = await backend.contacts();
      } on Object {
        loadFailed = contacts == null;
        _notify();
        return;
      }
      if (_disposed) return;
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
    _byId
      ..clear()
      ..addEntries(read.map((c) => MapEntry(c.id, c)));
    final ids = {for (final c in read) c.id};
    if (_unlisted != null && ids.contains(_unlisted)) _unlisted = null;
    final pending = _pendingLink ?? (missingLinkId != null && ids.contains(missingLinkId) ? missingLinkId : null);
    if (pending != null) {
      _pendingLink = null;
      _openLink(pending, ids);
    } else if (_wanted != null && ids.contains(_wanted)) {
      // A contact this app just made or brought back: open it.
      selectedId = _wanted;
      _wanted = null;
    } else if (selectedId == null || (!ids.contains(selectedId) && selectedId != _unlisted)) {
      selectedId = initialContactSelection(entries, _lastOpened);
    }
    final selected = selectedId;
    if (selected != null && selection.count <= 1 && !(selection.count == 1 && selection.isSelected(selected))) {
      _selecting = true;
      selection.select(selected);
      _selecting = false;
    }
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
    if (paneErrorId != id) paneError = paneErrorId = null;
    if (selectedId != id) selectedId = id;
    if (selection.count != 1 || !selection.isSelected(id)) {
      _selecting = true;
      selection.select(id);
      _selecting = false;
    }
    ensureDetail(id);
    _remember(id);
    _notify();
  }

  bool _selecting = false;

  /// The list changed the selection (a click, ⌘-click, ⇧-click or a key): one row is the contact open.
  void _selectionChanged() {
    if (_selecting || _disposed) return;
    final m = merging;
    if (m != null && !(selection.count == m.ids.length && m.ids.every(selection.isSelected))) {
      // Another selection: the Merge pane was about the one before.
      merging = null;
      m.removeListener(_notify);
      m.dispose();
    }
    if (selection.count == 1) {
      final id = selection.selected.first;
      if (id != selectedId) {
        _openTicket++;
        missingLinkId = null;
        selectedId = id;
        ensureDetail(id);
        _remember(id);
      }
    }
    if (paneErrorId != null && !(selection.count == 1 && selection.isSelected(paneErrorId!))) {
      paneError = paneErrorId = null;
    }
    _notify();
  }

  /// The contacts the selection's actions apply to: every selected row, or the open contact.
  List<String> get selectedIds {
    if (selection.count > 1) return selection.selected;
    final id = selectedId;
    return id == null ? const [] : [id];
  }

  /// Whether the host lets this app change and delete [id] (it owns it).
  bool isEditable(String id) {
    final listed = _byId[id];
    if (listed != null) return listed.editable;
    final d = _details[id];
    return d is DetailReady && d.contact.editable;
  }

  /// The name the list shows for [id].
  String nameOf(String id) => _byId[id]?.displayName ?? entryFor(id)?.name ?? 'This contact';

  /// [id] comes from This Mac (else from an iCloud account), for the reason it cannot be changed here.
  bool isFromThisMac(String id) => _byId[id]?.source_ == ContactOutSource_Enum.mac;

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
    _selecting = true;
    selection.select(id);
    _selecting = false;
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

  /// Read contact [id]'s page unless it is read or being read. A page that failed is read again, unless
  /// [retryFailed] is false: a listener of this controller passes false, since a failed read notifies and
  /// would ask again at once, without end, while the host keeps failing.
  void ensureDetail(String id, {bool retryFailed = true}) {
    final known = _details[id];
    if (known != null && (known is! DetailFailed || !retryFailed)) return;
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

  // ------------------------------------------------------------------------------------------------------
  // Editing: the inspector's record, saving, deleting, Recently deleted and Undo.
  // ------------------------------------------------------------------------------------------------------

  /// Opens the inspector on a new contact.
  void startNew() {
    editing = ContactEdit(null, ++_editSerial);
    _notify();
  }

  /// Opens the inspector on [contact], which the host owns.
  void startEdit(ContactDetailOut contact) {
    if (!contact.editable) return;
    editing = ContactEdit(contact, ++_editSerial);
    _notify();
  }

  /// Contact [id] as the host has it now, for the inspector to open on (a page read earlier may be older than
  /// a change made in another app). It replaces the page shown. When the host does not answer, the page read
  /// earlier, if any (a save from it is refused if it is stale); null when the host has no such contact.
  Future<ContactDetailOut?> readForEdit(String id) async {
    final ContactDetailOut? fresh;
    try {
      fresh = await backend.contact(id);
    } on Object {
      final known = _details[id];
      return known is DetailReady ? known.contact : null;
    }
    if (_disposed) return fresh;
    _details[id] = fresh == null ? const DetailMissing() : DetailReady(fresh);
    _notify();
    return fresh;
  }

  /// The inspector closed.
  void endEdit() {
    if (editing == null) return;
    editing = null;
    _notify();
  }

  /// "Reload" after the host refused a save because the contact changed elsewhere: the inspector opens again
  /// on the host's version, dropping the user's changes. Null when it did (or the inspector moved on
  /// meanwhile); otherwise why not, and the inspector stays as it is: [Refused] when the contact is in
  /// Recently deleted now, [Gone] when the host no longer has it, [NoAnswer] when the host did not answer.
  Future<WriteFailure?> reloadEdit() async {
    final id = editing?.id;
    if (id == null) return null;
    final ContactDetailOut? fresh;
    try {
      fresh = await backend.contact(id);
    } on Object {
      return const NoAnswer();
    }
    if (_disposed || editing?.id != id) return null;
    if (fresh == null) {
      // Not found: moved to Recently deleted, or gone for good (or its source turned off).
      try {
        final deleted = await backend.trash();
        if (deleted.any((t) => t.id == id)) return const Refused('in Recently deleted');
      } on Object {
        // Said as gone: the host does not have it as a contact either way.
      }
      return const Gone();
    }
    _details[id] = DetailReady(fresh);
    editing = ContactEdit(fresh, ++_editSerial);
    _readListAgain();
    _notify();
    return null;
  }

  /// Saves the inspector's [form]: a new contact, or a change to [edit]'s from the version it opened on.
  /// Null when the host has it (the contact is then open and Undo can take it back), else why not.
  Future<WriteFailure?> save(ContactEdit edit, ContactIn form) async {
    final original = edit.original;
    final Written written;
    try {
      written = original == null
          ? await backend.create(form)
          : await backend.update(original.id, original.etag, form);
    } on WriteFailure catch (f) {
      return f;
    } on Object {
      return const NoAnswer();
    }
    if (_disposed) return null;
    final c = written.contact;
    _details[c.id] = DetailReady(c);
    if (written.undoId != null) {
      undoStack.add(UndoEntry(
        action: original == null ? addAction : editAction,
        undoIds: [written.undoId!],
        names: [c.displayName],
        undone: original == null ? addUndone : editUndone,
        contactIds: [c.id],
      ));
    }
    lastSaved = written.undoId == null ? null : undoStack.last;
    _wanted = c.id;
    open(c.id);
    _readListAgain();
    _notify();
    return null;
  }

  /// What the last save can undo, for its toast; null when it changed nothing.
  UndoEntry? lastSaved;

  /// A contact to open once the list has it.
  String? _wanted;

  static const addAction = 'Add contact';
  static const editAction = 'Edit contact';
  static const addUndone = 'Contact moved to Recently deleted';
  static const editUndone = 'Changes undone';

  /// Moves [ids] to Recently deleted, one by one, stopping at the first failure. The selection then moves to
  /// the row now in the first deleted row's place ([rowsInOrder]: the list's order).
  ///
  /// The change goes on [undoStack] unless [remember] is false (the caller then adds one entry for several
  /// calls with [remember]).
  Future<BulkResult> delete(List<String> ids, {List<String>? rowsInOrder, bool remember = true}) async {
    final order = rowsInOrder ?? [for (final e in entries) e.id];
    final done = <String>[];
    final undoIds = <String>[];
    final names = <String>[];
    WriteFailure? failure;
    String? failedId;
    for (final id in ids) {
      failedId = id;
      try {
        final etag = await _etagOf(id);
        if (etag == null) throw const Gone();
        final w = await backend.delete(id, etag);
        done.add(id);
        names.add(w.contact.displayName);
        if (w.undoId != null) undoIds.add(w.undoId!);
      } on WriteFailure catch (f) {
        failure = f;
        break;
      } on Object {
        failure = const NoAnswer();
        break;
      }
    }
    if (_disposed) return BulkResult(done, failure, null);
    if (failure is ChangedElsewhere && failedId != null) {
      // It changed elsewhere since this app read it: read its page and the list again, so the pane shows the
      // host's version and the next Delete names it.
      if (failedId == selectedId && _details[failedId] is DetailReady) {
        unawaited(_readDetail(failedId)); // the page stays on screen until the host's version replaces it
      } else {
        _details.remove(failedId);
      }
      _readListAgain();
    }
    UndoEntry? entry;
    if (done.isNotEmpty) {
      final n = done.length;
      entry = UndoEntry(
        action: n == 1 ? 'Delete contact' : 'Delete $n contacts',
        undoIds: undoIds,
        names: names,
        undone: n == 1 ? 'Contact restored' : '$n contacts restored',
        contactIds: [...done],
      );
      if (undoIds.isNotEmpty && remember) undoStack.add(entry);
      _afterRemoving(done, order);
    }
    _notify();
    return BulkResult(done, failure, entry);
  }

  /// The version of [id] the user sees, which a delete names (the host requires it): its page's when read,
  /// else the list row's, else the host's now (a contact neither shows, such as one a link opened). Null
  /// when the host has no such contact.
  Future<String?> _etagOf(String id) async {
    final d = _details[id];
    if (d is DetailReady) return d.contact.etag;
    final listed = _byId[id];
    if (listed != null) return listed.etag;
    return (await backend.contact(id))?.etag;
  }

  /// [gone] left the list: read the list again, and when the open contact or a selected row was among them,
  /// open the row now in the first one's place. Deleting another row (from its Menu) leaves the open contact
  /// open.
  void _afterRemoving(List<String> gone, List<String> order) {
    final goneSet = gone.toSet();
    final moves = goneSet.contains(selectedId) || selection.selected.any(goneSet.contains);
    final first = order.indexWhere(goneSet.contains);
    final left = [for (final id in order) if (!goneSet.contains(id)) id];
    String? next;
    if (left.isNotEmpty) {
      final at = first < 0 ? 0 : first.clamp(0, left.length - 1);
      // The row that followed the first deleted one, else the one before it.
      next = order.skip(first < 0 ? 0 : first).firstWhere((id) => !goneSet.contains(id), orElse: () => left[at]);
    }
    for (final id in gone) {
      _details.remove(id);
    }
    contacts = [for (final c in contacts ?? const <ContactOut>[]) if (!goneSet.contains(c.id)) c];
    entries = [for (final e in entries) if (!goneSet.contains(e.id)) e];
    if (!moves) {
      // The open contact stays.
    } else if (next != null) {
      open(next);
    } else {
      selectedId = null;
      _selecting = true;
      selection.clear();
      _selecting = false;
    }
    _readListAgain();
    if (trash != null) unawaited(loadTrash());
  }

  /// Puts [entry] on [undoStack] (for changes made in several calls).
  void remember(UndoEntry entry) {
    undoStack.add(entry);
    _notify();
  }

  /// Whether an undo is under way: Undo does nothing more until it ends.
  bool get undoing => _undoRuns.isNotEmpty;
  final _undoRuns = <UndoEntry, Future<String>>{};

  /// What each entry's finished undo said, so a later Undo of the same entry (the toast's, after ⌘Z took it
  /// back) repeats it instead of asking the host a second time.
  final _undoSaid = Expando<String>('undo said');

  /// Takes back [entry]. Completes with what the toast then says: what came back, or why it did not. The
  /// entry leaves [undoStack] at once, so a second Undo (another press, the toast's and ⌘Z) never sends the
  /// same change to the host again: it gets the first one's answer.
  Future<String> undo(UndoEntry entry) {
    final said = _undoSaid[entry];
    if (said != null) return Future.value(said);
    return _undoRuns[entry] ??= _undo(entry);
  }

  Future<String> _undo(UndoEntry entry) async {
    final at = undoStack.indexOf(entry);
    undoStack.remove(entry);
    _notify();
    try {
      final said = await _undoOnHost(entry, at);
      if (said != undoNoAnswer) _undoSaid[entry] = said;
      return said;
    } finally {
      _undoRuns.remove(entry);
      _notify();
    }
  }

  Future<String> _undoOnHost(UndoEntry entry, int at) async {
    final refused = <String>[];
    final purged = <String>[];
    var undone = 0;
    String? lastId;
    for (var i = 0; i < entry.undoIds.length; i++) {
      final name = i < entry.names.length ? entry.names[i] : 'This contact';
      try {
        final c = await backend.undo(entry.undoIds[i]);
        undone++;
        lastId = c.id;
        _details[c.id] = DetailReady(c);
      } on Refused catch (r) {
        // The host refuses an undo of a contact deleted for good in its own words (409); a missing undo id
        // is Gone.
        (r.detail.contains('deleted for good') ? purged : refused).add(name);
      } on Gone {
        purged.add(name);
      } on Object {
        if (undone == 0 && refused.isEmpty && purged.isEmpty) {
          // Nothing reached the host: Undo can try it again.
          if (!_disposed && !undoStack.contains(entry)) undoStack.insert(at < 0 ? undoStack.length : at, entry);
          return undoNoAnswer;
        }
        break;
      }
    }
    if (undone > 0) {
      // A deleted contact that came back, or an edit taken back: open it.
      if (lastId != null && (entry.action.startsWith('Delete') || entry.action == editAction)) _wanted = lastId;
      _readListAgain();
      if (trash != null) unawaited(loadTrash());
    }
    _notify();
    return undoSaid(entry, undone: undone, changed: refused, purged: purged);
  }

  /// What the toast says after an undo of [entry]: what came back, or why not: [changed] were changed after
  /// that, [purged] were deleted for good.
  static String undoSaid(UndoEntry entry,
      {required int undone, required List<String> changed, required List<String> purged}) {
    final failed = changed.length + purged.length;
    if (failed == 0) return entry.undone;
    if (failed == 1 && entry.undoIds.length == 1) {
      return changed.isEmpty
          ? 'Not undone. ${purged.single} was deleted for good.'
          : 'Not undone. ${changed.single} was changed after that.';
    }
    final why = purged.isEmpty
        ? 'changed after that'
        : changed.isEmpty
            ? 'deleted for good'
            : 'changed or deleted for good after that';
    if (undone == 0) return 'Not undone. $failed contacts were $why.';
    return 'Not all undone. $failed of the contacts were $why.';
  }

  static const undoNoAnswer = 'Not undone. The host did not answer; try Undo again in a moment.';

  /// Reads Recently deleted.
  Future<void> loadTrash() async {
    try {
      final read = await backend.trash();
      if (_disposed) return;
      trash = read;
      trashFailed = false;
    } on Object {
      if (_disposed) return;
      trashFailed = trash == null;
    }
    _notify();
  }

  /// Brings [ids] back from Recently deleted, stopping at the first failure.
  Future<BulkResult> restore(List<String> ids) async {
    final done = <String>[];
    final undoIds = <String>[];
    final names = <String>[];
    WriteFailure? failure;
    for (final id in ids) {
      try {
        final w = await backend.restore(id, etag: _trashEtagOf(id));
        done.add(id);
        names.add(w.contact.displayName);
        if (w.undoId != null) undoIds.add(w.undoId!);
      } on WriteFailure catch (f) {
        failure = f;
        break;
      } on Object {
        failure = const NoAnswer();
        break;
      }
    }
    if (_disposed) return BulkResult(done, failure, null);
    if (done.isEmpty && failure is ChangedElsewhere) await loadTrash();
    UndoEntry? entry;
    if (done.isNotEmpty) {
      final n = done.length;
      entry = UndoEntry(
        action: n == 1 ? 'Restore contact' : 'Restore $n contacts',
        undoIds: undoIds,
        names: names,
        undone: n == 1 ? 'Contact moved back to Recently deleted' : '$n contacts moved back to Recently deleted',
        contactIds: [...done],
      );
      if (undoIds.isNotEmpty) undoStack.add(entry);
      _readListAgain();
      await loadTrash();
    }
    _notify();
    return BulkResult(done, failure, entry);
  }

  /// The version of [id] Recently deleted listed, or null when it does not list it.
  String? _trashEtagOf(String id) {
    for (final t in trash ?? const <TrashItemOut>[]) {
      if (t.id == id) return t.contact?.etag;
    }
    return null;
  }

  /// Deletes [ids], which are in Recently deleted, for good, stopping at the first failure. It cannot be
  /// undone. Each goes only at the version the user saw: [seen] (the versions listed when the dialog asked),
  /// else the one Recently deleted lists now. One changed elsewhere since (restored, edited and deleted
  /// again) stops it with [ChangedElsewhere], and Recently deleted is read again.
  Future<BulkResult> purge(List<String> ids, {Map<String, String?> seen = const {}}) async {
    final done = <String>[];
    WriteFailure? failure;
    for (final id in ids) {
      try {
        final etag = seen.containsKey(id) ? seen[id] : _trashEtagOf(id);
        if (etag == null) throw const Gone();
        await backend.purge(id, etag);
        done.add(id);
      } on Gone {
        done.add(id); // Already gone: what the user asked for.
      } on WriteFailure catch (f) {
        failure = f;
        break;
      } on Object {
        failure = const NoAnswer();
        break;
      }
    }
    if (_disposed) return BulkResult(done, failure, null);
    // What is deleted for good can no longer be undone: its entries leave Undo.
    final purgedSet = done.toSet();
    undoStack.removeWhere((e) => e.contactIds.isNotEmpty && e.contactIds.every(purgedSet.contains));
    if (done.isNotEmpty || failure is ChangedElsewhere) await loadTrash();
    _notify();
    return BulkResult(done, failure, null);
  }

  // ------------------------------------------------------------------------------------------------------
  // Merge (design/components/DuplicatePair, "Merge from a multi-selection") and Review.
  // ------------------------------------------------------------------------------------------------------

  /// The Merge pane in the contact pane's place, or null.
  MergeSession? merging;

  /// The most contacts the host merges at once.
  static const mergeMax = 20;

  /// Why [ids] cannot be merged now, a full sentence; null when they can.
  String? mergeDisabledReason(List<String> ids) {
    if (ids.length < 2) return mergeTooFew;
    if (ids.length > mergeMax) return mergeTooMany;
    for (final id in ids) {
      if (!isEditable(id)) {
        final from = isFromThisMac(id) ? 'this Mac' : 'an iCloud account';
        return '${nameOf(id)} is read from $from. Only contacts on myData can be merged.';
      }
    }
    return null;
  }

  static const mergeTooFew = 'Select two or more contacts to merge.';
  static const mergeTooMany = 'Merge at most 20 contacts at a time.';

  /// Opens the Merge pane on [ids] (two to twenty contacts the host owns), reading each one again first.
  void startMerge(List<String> ids) {
    if (mergeDisabledReason(ids) != null) return;
    merging?.dispose();
    merging = MergeSession(backend: backend, ids: ids)..addListener(_notify);
    unawaited(merging!.load());
    _notify();
  }

  /// Closes the Merge pane without merging.
  void endMerge() {
    final m = merging;
    if (m == null) return;
    merging = null;
    m.removeListener(_notify);
    m.dispose();
    _notify();
  }

  /// [out] was merged on the host: the originals leave the list, the merged contact opens, and Undo can take
  /// it back ("Undo Merge Contacts"). Returns the entry Undo uses.
  UndoEntry merged(MergeOut out, {required List<String> names}) {
    final order = [for (final e in entries) e.id];
    final entry = UndoEntry(
      action: mergeAction,
      undoIds: [out.undoId],
      names: [out.contact.displayName],
      undone: mergeUndone,
      contactIds: [out.contact.id, ...out.merged],
    );
    undoStack.add(entry);
    _details[out.contact.id] = DetailReady(out.contact);
    _wanted = out.contact.id;
    if (merging != null) {
      merging!.removeListener(_notify);
      merging!.dispose();
      merging = null;
    }
    _afterRemoving(out.merged, order);
    selectedId = out.contact.id;
    _selecting = true;
    selection.select(out.contact.id);
    _selecting = false;
    _notify();
    return entry;
  }

  static const mergeAction = 'Merge contacts';
  static const mergeUndone = 'Contacts unmerged';

  /// A change made from Review (a save, a kept version, two people marked as different): Undo can take it
  /// back, and the list and pages are read again.
  UndoEntry reviewed({required String action, required String undoId, required String name, required String undone,
      required List<String> contactIds, ContactDetailOut? contact}) {
    final entry = UndoEntry(action: action, undoIds: [undoId], names: [name], undone: undone, contactIds: contactIds);
    undoStack.add(entry);
    if (contact != null) _details[contact.id] = DetailReady(contact);
    _readListAgain();
    _notify();
    return entry;
  }

  /// Read the list (and so the marks of contacts changed in their source) again now.
  void readListAgain() => _readListAgain();

  /// Says in the contact pane that [id] could not be deleted.
  void showPaneError(String id, String message) {
    paneErrorId = id;
    paneError = message;
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
    // Through update, so the mode, the themes and the other apps' settings are kept, and a file that cannot
    // be read is never written over; one write at a time.
    _writes = _writes.then((_) async {
      try {
        await store.update((values) => {...values, lastOpenedKey: id});
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
    merging?.dispose();
    selection.removeListener(_selectionChanged);
    selection.dispose();
    unawaited(_linkOpened.close());
    super.dispose();
  }
}
