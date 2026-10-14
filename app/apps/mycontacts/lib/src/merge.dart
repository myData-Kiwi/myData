import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mydata_core/mydata_core.dart';

import 'backend.dart';

/// One merge being decided: the contacts as the host has them now, whose name and details to keep
/// (`names_from`), and the host's merge preview (H6c), read again whenever the choice changes. Used by the
/// Merge pane (a multi-selection) and by Review's possible duplicates (design/components/DuplicatePair).
///
/// Nothing is merged on old data: each contact is read again when the pane opens, the merge sends the
/// etags the user saw, and a contact changed meanwhile (412) is read again and shown with a line saying so.
class MergeSession extends ChangeNotifier {
  MergeSession({required this.backend, required this.ids});

  final ContactsBackend backend;

  /// The contacts, in the order they were selected.
  final List<String> ids;

  /// Each contact as the host has it now; null until read.
  final contacts = <String, ContactDetailOut>{};

  /// Whose name and details the merged contact starts from; the host's `newest` until the user chooses.
  String? namesFrom;

  /// The host's preview of the merged contact, for "After merging"; null while it is read.
  MergePreviewOut? preview;

  bool loading = true;
  bool previewing = false;
  bool working = false;

  /// A line above the buttons: a failure ([messageIsError]) or a contact that changed while shown.
  String? message;
  bool messageIsError = false;

  /// One of the contacts is no longer on the host (deleted, or merged elsewhere): nothing can be merged.
  bool gone = false;

  /// The contact that is gone, when [gone].
  String? goneId;

  bool _disposed = false;
  int _previewTicket = 0;

  /// The contacts in order, as far as they are read.
  List<ContactDetailOut> get inOrder => [for (final id in ids) ?contacts[id]];

  /// Reads each contact again, then the preview.
  Future<void> load() async {
    loading = true;
    _notify();
    final before = {for (final e in contacts.entries) e.key: e.value.etag};
    try {
      for (final id in ids) {
        final c = await backend.contact(id);
        if (c == null || c.deletedAt != null) {
          gone = true;
          goneId = id;
          message = goneLine(c?.displayName ?? contacts[id]?.displayName ?? 'One of them');
          messageIsError = false;
          contacts.remove(id);
        } else {
          final was = before[id];
          if (was != null && was != c.etag) {
            message = changedLine(c.displayName);
            messageIsError = false;
          }
          contacts[id] = c;
        }
      }
    } on Object {
      if (_disposed) return;
      loading = false;
      message = loadFailed;
      messageIsError = true;
      _notify();
      return;
    }
    if (_disposed) return;
    loading = false;
    _notify();
    if (!gone) await refreshPreview();
  }

  /// The contacts with the etags the user saw, as the host takes them.
  List<MergeContactIn> get _sent => [for (final c in inOrder) MergeContactIn(id: c.id, etag: c.etag)];

  /// Reads the preview again (after the choice changed, or the contacts were read again).
  Future<void> refreshPreview() async {
    final ticket = ++_previewTicket;
    previewing = true;
    _notify();
    try {
      final p = await backend.mergePreview(_sent, namesFrom: namesFrom);
      if (_disposed || ticket != _previewTicket) return;
      preview = p;
      namesFrom ??= p.newest;
      previewing = false;
    } on WriteFailure catch (f) {
      if (_disposed || ticket != _previewTicket) return;
      previewing = false;
      await _failed(f);
      return;
    } on Object {
      if (_disposed || ticket != _previewTicket) return;
      previewing = false;
      message = previewFailed;
      messageIsError = true;
    }
    _notify();
  }

  /// "Keep the name and details of": the host's `names_from`.
  Future<void> keepDetailsOf(String id) async {
    if (working || namesFrom == id) return;
    namesFrom = id;
    message = null;
    await refreshPreview();
  }

  /// Merges on the host. Returns what the host made, or null with [message] set.
  Future<MergeOut?> merge() async {
    if (working || loading || gone || preview == null) return null;
    working = true;
    message = null;
    _notify();
    try {
      final out = await backend.merge(_sent, namesFrom: namesFrom);
      working = false;
      return out;
    } on WriteFailure catch (f) {
      working = false;
      await _failed(f);
      return null;
    } on Object {
      working = false;
      message = noAnswer;
      messageIsError = true;
      _notify();
      return null;
    }
  }

  Future<void> _failed(WriteFailure f) async {
    switch (f) {
      case ChangedElsewhere():
        // Read again; the line names the contact that changed.
        await load();
      case Gone():
        await load();
      case Refused():
        message = refused;
        messageIsError = true;
      default:
        message = noAnswer;
        messageIsError = true;
    }
    _notify();
  }

  static String changedLine(String name) => '$name changed while you were looking. This is the new version.';
  static String goneLine(String name) => '$name is no longer on your host, so these contacts cannot be merged.';
  static const noAnswer = 'The contacts were not merged. The host did not answer. Check that it is running, then try '
      'again.';
  static const refused = 'The contacts were not merged. Only contacts on myData can be merged.';
  static const loadFailed = 'The contacts could not be read. The host did not answer. Check that it is running, then '
      'try again.';
  static const previewFailed = 'What merging would make could not be read. The host did not answer. Check that it '
      'is running, then try again.';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
