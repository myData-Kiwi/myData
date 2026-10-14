import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show MultipartFile;
import 'package:mydata_core/mydata_core.dart';

import '../source_list.dart';
import 'import_files.dart';
import 'import_text.dart';

/// The steps of an import, each on the same page (design/components/ImportFlow).
enum ImportStep { choose, review, importing, done }

/// Where a card of the preview is shown in Review.
enum RowGroup {
  /// "Possible duplicates": new, with a suggestion match to a contact in myData. Ticked.
  duplicates,

  /// "Changed since your last import": status update. Ticked.
  updates,

  /// "Already in myData": duplicate or deleted. Unticked.
  already,

  /// "Not updated": conflicts, text rows.
  conflicts,

  /// "New contacts". Ticked, folded.
  fresh,

  /// Unchanged or repeated in the file: one line, no rows.
  quiet,

  /// Not read: the loss report.
  skipped,

  /// Group cards: imported with the contacts, not listed.
  groups,
}

/// What the host's answer to a request was, as the Import section words it.
class HostRefusal {
  const HostRefusal({this.status, this.code, this.noAnswer = false});

  /// The HTTP status, or null when there was no answer.
  final int? status;

  /// The host's `code` (H4): `too_big`, `no_vcard`, `choice_refused`, …
  final String? code;

  /// The host did not answer (or is not connected).
  final bool noAnswer;

  static HostRefusal of(Object e) {
    if (e is ApiException) {
      if (e.innerException != null) return const HostRefusal(noAnswer: true);
      String? code;
      try {
        final body = jsonDecode(e.message ?? '');
        if (body is Map && body['code'] is String) code = body['code'] as String;
      } on FormatException {
        code = null;
      }
      return HostRefusal(status: e.code, code: code);
    }
    return const HostRefusal(noAnswer: true);
  }
}

/// One card's place in Review, with its tick.
class ReviewRow {
  ReviewRow(this.item, this.group);
  final ImportItemOut item;
  final RowGroup group;

  /// The action a tick gives it: update for a changed card, else import.
  String? get tickedAction {
    if (item.status == 'update' && item.choices.contains('update')) return 'update';
    return item.choices.contains('import') ? 'import' : null;
  }

  /// The action an untick gives it: skip, or the host's default when that is skip or link ("keep yours and
  /// hide the iCloud copy").
  String? get untickedAction {
    if (item.action == 'skip' || item.action == 'link') return item.action;
    return item.choices.contains('skip') ? 'skip' : null;
  }

  /// A row the user can tick: its two actions are both allowed and differ.
  bool get tickable => tickedAction != null && untickedAction != null && tickedAction != untickedAction;

  /// The first match with a contact in myData (Compare's "In myData", the caption's name).
  ImportMatchOut? get ownMatch =>
      item.matches.where((m) => m.source_ == 'mydata' && m.contactId != null).firstOrNull ??
      item.matches.where((m) => m.source_ == 'mydata').firstOrNull;
}

/// A comparison under a row: the card's values (H3) beside the contact in myData.
class CompareState {
  bool loading = true;
  bool failed = false;
  ImportCardOut? card;
  ContactDetailOut? contact;
}

/// The Import section's state and its talk with the host: reading a file or an account copy into a preview,
/// the ticks of Review, the commit, Done, the history and Undo import.
///
/// The host holds a preview for an hour for this app only; the app sends back only the rows whose action
/// differs from the card's default (`choices`). Nothing imported is logged here: failures are reported by
/// their kind, never with a name or value.
class ImportController extends ChangeNotifier {
  ImportController({
    required this.host,
    required this.sources,
    FileChooser? chooser,
    this.importingDelay = const Duration(seconds: 1),
  }) : chooser = chooser ?? chooseContactsFile;

  final HostController host;
  final SourceList sources;
  final FileChooser chooser;

  /// The Importing step shows only when the commit takes longer than this, so a small file goes straight
  /// from Review to Done.
  final Duration importingDelay;

  ImportStep step = ImportStep.choose;

  /// Goes up whenever the step changes, so the page can move focus to the new title.
  int stepSerial = 0;

  // ---- Choose ---------------------------------------------------------------------------------------------

  /// The file being read, by name; null when none is.
  String? readingName;

  /// The followed account whose copy is being read.
  String? readingAccount;

  /// The last file sent, for "Try again".
  PickedFile? lastFile;

  /// Why the last file could not be used; [fileErrorRetry] when the host did not answer.
  String? fileError;
  bool fileErrorRetry = false;

  /// An account copy that could not be read, by account id.
  final accountErrors = <String, String>{};

  /// A link from myContacts asked for Import: on a Mac, "Contacts on a Mac" opens at first.
  int linkSerial = 0;

  int _readTicket = 0;

  // ---- History ----------------------------------------------------------------------------------------------

  List<ImportOut>? history;
  DateTime? historyReadAt;
  bool historyFailed = false;

  /// What an undo of this session kept, by import id ("Kept, because they changed since: …").
  final keptByImport = <String, List<String>>{};

  /// The import whose row just changed to "Undone", for focus.
  String? undoneId;

  // ---- Review -----------------------------------------------------------------------------------------------

  ImportPreviewOut? preview;

  /// For an account copy, the account's id (Read the copy again).
  String? previewAccount;

  /// Actions the user chose, by card index, only where they differ from the card's default.
  final _actions = <int, String>{};

  /// Files of a zip left out.
  final entriesOff = <String>{};

  bool acceptLosses = false;
  bool expired = false;

  /// The line in `danger` above the footer after a failed commit.
  String? reviewFailure;

  final compares = <int, CompareState>{};

  // ---- Importing and Done -------------------------------------------------------------------------------

  bool committing = false;
  ImportCommittedOut? result;

  /// What Review chose, for Done's rows the host does not count.
  int doneLeftOut = 0;
  int doneDuplicates = 0;
  int doneSkipped = 0;
  List<ReviewRow> doneSkippedRows = const [];
  List<ImportNoteOut> doneLosses = const [];

  /// "Keep following" was pressed, or the account was stopped: the question goes.
  bool followingSettled = false;

  bool _disposed = false;

  HostConnection? get _c => host.connection;

  // ------------------------------------------------------------------------------------------------------
  // Choose.
  // ------------------------------------------------------------------------------------------------------

  bool get reachable => host.phase == HostPhase.running && host.connection != null;

  /// "Choose file…": the system's chooser, then the file is read.
  Future<void> chooseFile() async {
    final PickedFile? file;
    try {
      file = await chooser();
    } on Object {
      return;
    }
    if (file == null || _disposed) return;
    await useFiles([file]);
  }

  /// Files dropped or chosen: checked here, then sent to the host as bytes with their name as the label.
  Future<void> useFiles(List<PickedFile> files) async {
    if (files.isEmpty || !reachable || readingName != null || readingAccount != null) return;
    var error = ImportFileCheck.check(files);
    final file = files.length == 1 ? files.single : null;
    if (error == null && file != null) {
      try {
        final size = await file.size();
        error = ImportFileCheck.check(files, sizes: {file: size});
      } on Object {
        error = ImportText.unreadable(file.name);
      }
    }
    if (error != null || file == null) {
      _fail(error ?? ImportText.severalFiles);
      return;
    }
    await _send(file);
  }

  /// "Try again": the same file.
  Future<void> retry() async {
    final f = lastFile;
    if (f != null) await _send(f);
  }

  Future<void> _send(PickedFile file) async {
    final ticket = ++_readTicket;
    lastFile = file;
    readingName = file.name;
    fileError = null;
    fileErrorRetry = false;
    _notify();
    ImportPreviewOut? out;
    int? size;
    try {
      final bytes = await file.read();
      size = bytes.length;
      final c = _c;
      if (c == null) throw StateError('not connected');
      out = await ImportsApi(c.client)
          .previewContactsImport(MultipartFile.fromBytes('file', bytes, filename: file.name), filename: file.name);
    } on Object catch (e) {
      if (ticket != _readTicket || _disposed) return;
      readingName = null;
      final r = HostRefusal.of(e);
      if (e is! ApiException && e is! StateError && e is! TimeoutException) {
        _fail(ImportText.unreadable(file.name));
      } else if (r.noAnswer || (r.status != 400 && r.status != 413)) {
        _fail(ImportText.notRead(file.name), retry: true);
      } else {
        _fail(ImportText.refused(file.name, r.code ?? (r.status == 413 ? 'too_big' : null), bytes: size));
      }
      return;
    }
    if (ticket != _readTicket || _disposed) {
      // Cancelled while the host read it: its answer is discarded, so the file is not held for the hour.
      if (out != null) unawaited(_discard(out.id));
      return;
    }
    readingName = null;
    if (out == null) {
      _fail(ImportText.notRead(file.name), retry: true);
      return;
    }
    if (out.counts.cards > 0 && out.items.isNotEmpty && out.items.every((i) => i.status == 'skipped')) {
      unawaited(_discard(out.id));
      _fail(ImportText.noneReadable(file.name, out.counts.cards));
      return;
    }
    _startReview(out, account: null);
  }

  void _fail(String message, {bool retry = false}) {
    fileError = message;
    fileErrorRetry = retry;
    _notify();
  }

  /// Cancel while reading: back to Choose at once. The host finishes reading anyway; its answer is
  /// discarded when it comes.
  void cancelReading() {
    _readTicket++;
    readingName = null;
    readingAccount = null;
    _notify();
  }

  /// "Import a copy" of a followed iCloud account: read as the mirror holds it, nothing uploaded.
  Future<void> readAccount(SourceOut account) async {
    if (!reachable || readingName != null || readingAccount != null) return;
    final ticket = ++_readTicket;
    readingAccount = account.id;
    accountErrors.remove(account.id);
    fileError = null;
    _notify();
    ImportPreviewOut? out;
    try {
      final c = _c;
      if (c == null) throw StateError('not connected');
      out = await ImportsApi(c.client).previewSourceImport(account.id);
    } on Object {
      if (ticket != _readTicket || _disposed) return;
      readingAccount = null;
      accountErrors[account.id] = ImportText.accountNotRead;
      _notify();
      return;
    }
    if (ticket != _readTicket || _disposed) {
      if (out != null) unawaited(_discard(out.id));
      return;
    }
    readingAccount = null;
    if (out == null) {
      accountErrors[account.id] = ImportText.accountNotRead;
      _notify();
      return;
    }
    _startReview(out, account: account.id);
  }

  void _startReview(ImportPreviewOut p, {required String? account}) {
    preview = p;
    previewAccount = account;
    _actions.clear();
    entriesOff.clear();
    compares.clear();
    acceptLosses = false;
    expired = false;
    reviewFailure = null;
    _go(ImportStep.review);
  }

  Future<void> _discard(String id) async {
    try {
      final c = _c;
      if (c != null) await ImportsApi(c.client).discardImportPreview(id);
    } on Object {
      // The host drops it within the hour anyway.
    }
  }

  void _go(ImportStep to) {
    step = to;
    stepSerial++;
    _notify();
  }

  /// A `mydata://import/contacts` link: Choose comes forward, unless an import is in Review or Importing,
  /// which is not restarted.
  void openFromLink() {
    linkSerial++;
    if (step == ImportStep.done) _go(ImportStep.choose);
    _notify();
  }

  // ------------------------------------------------------------------------------------------------------
  // History.
  // ------------------------------------------------------------------------------------------------------

  Future<void> loadHistory() async {
    final c = _c;
    if (c == null || !reachable) return;
    try {
      final read = await ImportsApi(c.client).importHistory() ?? const <ImportOut>[];
      if (_disposed) return;
      history = read;
      historyReadAt = DateTime.now();
      historyFailed = false;
    } on Object {
      if (_disposed) return;
      historyFailed = history == null;
    }
    _notify();
  }

  /// Undoes [i]: null when done (or already undone elsewhere, when the row is read again), else the
  /// Dialog's failure line.
  Future<String?> undo(ImportOut i) async {
    final c = _c;
    if (c == null) return ImportText.undoFailed;
    ImportUndoneOut? out;
    try {
      out = await ImportsApi(c.client).undoImport(i.id);
    } on Object catch (e) {
      final r = HostRefusal.of(e);
      if (r.status == 409 || r.status == 404) {
        undoneId = i.id;
        await loadHistory();
        return null;
      }
      return ImportText.undoFailed;
    }
    if (out == null) return ImportText.undoFailed;
    keptByImport[i.id] = [for (final k in out.kept) k.displayName];
    lastUndone = out;
    undoneId = i.id;
    if (step == ImportStep.done && result?.id == i.id) _go(ImportStep.choose);
    await loadHistory();
    return null;
  }

  /// The last undo's answer, for its polite announcement.
  ImportUndoneOut? lastUndone;

  // ------------------------------------------------------------------------------------------------------
  // Review.
  // ------------------------------------------------------------------------------------------------------

  /// The section came into view again: Review is read again from the host, so a change made in myContacts
  /// meanwhile shows; a preview the host no longer holds is "Expired".
  Future<void> refreshPreview() async {
    final p = preview;
    final c = _c;
    if (p == null || c == null || step != ImportStep.review || expired) return;
    try {
      final fresh = await ImportsApi(c.client).importPreview(p.id);
      if (_disposed || preview?.id != p.id) return;
      if (fresh == null) return;
      preview = fresh;
      final byIndex = {for (final i in fresh.items) i.index: i};
      _actions.removeWhere((index, action) => !(byIndex[index]?.choices.contains(action) ?? false));
      compares.clear();
    } on Object catch (e) {
      if (_disposed || preview?.id != p.id) return;
      if (HostRefusal.of(e).status == 404) expired = true;
    }
    _notify();
  }

  /// Every card's row, in the input's order.
  List<ReviewRow> get rows {
    final p = preview;
    if (p == null) return const [];
    return [for (final i in p.items) ReviewRow(i, _groupOf(i))];
  }

  static RowGroup _groupOf(ImportItemOut i) {
    if (i.status == 'skipped') return RowGroup.skipped;
    if (i.kind == 'group') return RowGroup.groups;
    return switch (i.status) {
      'update' => RowGroup.updates,
      'duplicate' || 'deleted' => RowGroup.already,
      'conflict' => RowGroup.conflicts,
      'unchanged' || 'in_file' => RowGroup.quiet,
      'new' when i.matches.any((m) => m.source_ == 'mydata' && m.strength == 'suggestion') => RowGroup.duplicates,
      _ => RowGroup.fresh,
    };
  }

  List<ReviewRow> rowsIn(RowGroup g) => [for (final r in rows) if (r.group == g) r];

  /// The action [row]'s card will be given: the user's choice, else skip when its file in the zip is left
  /// out, else the host's default.
  String actionOf(ReviewRow row) {
    final entry = row.item.entry;
    if (entry != null && entriesOff.contains(entry) && row.item.choices.contains('skip')) return 'skip';
    return _actions[row.item.index] ?? row.item.action;
  }

  bool isTicked(ReviewRow row) => row.tickable ? actionOf(row) == row.tickedAction : actionOf(row) != 'skip';

  /// Whether [row] can be ticked now (not while its file in the zip is left out).
  bool canTick(ReviewRow row) {
    final entry = row.item.entry;
    return row.tickable && !(entry != null && entriesOff.contains(entry));
  }

  void setTicked(ReviewRow row, bool ticked) {
    if (!canTick(row) || committing) return;
    final action = ticked ? row.tickedAction! : row.untickedAction!;
    if (action == row.item.action) {
      _actions.remove(row.item.index);
    } else {
      _actions[row.item.index] = action;
    }
    _notify();
  }

  /// Several rows at once (a list's select all, ⇧-click).
  void setTickedAll(List<ReviewRow> rows, List<bool> ticked) {
    for (var i = 0; i < rows.length && i < ticked.length; i++) {
      if (!canTick(rows[i])) continue;
      final action = ticked[i] ? rows[i].tickedAction! : rows[i].untickedAction!;
      if (action == rows[i].item.action) {
        _actions.remove(rows[i].item.index);
      } else {
        _actions[rows[i].item.index] = action;
      }
    }
    _notify();
  }

  /// The vCard files of a zip with their card counts, in order; empty unless there is more than one.
  List<(String, int)> get entries {
    final counts = <String, int>{};
    for (final i in preview?.items ?? const <ImportItemOut>[]) {
      final e = i.entry;
      if (e != null) counts[e] = (counts[e] ?? 0) + 1;
    }
    return counts.length > 1 ? [for (final e in counts.entries) (e.key, e.value)] : const [];
  }

  void setEntry(String entry, bool on) {
    if (committing) return;
    on ? entriesOff.remove(entry) : entriesOff.add(entry);
    _notify();
  }

  void setAcceptLosses(bool v) {
    if (committing) return;
    acceptLosses = v;
    _notify();
  }

  /// The contacts (not groups) whose action is [action] now.
  int countAction(String action) =>
      rows.where((r) => r.group != RowGroup.groups && r.group != RowGroup.skipped && actionOf(r) == action).length;

  int get toImport => countAction('import');
  int get toUpdate => countAction('update');
  int get toLink => countAction('link');

  /// Nothing to send: no card has an action other than skip.
  bool get nothingToImport => toImport + toUpdate + toLink == 0;

  bool get needsAcceptance => preview?.needsAcceptance ?? false;

  /// Why Import is disabled now, or null when it may be pressed.
  String? get importDisabledReason {
    if (nothingToImport) return ImportText.chooseOne;
    if (needsAcceptance && !acceptLosses) return ImportText.acceptFirst;
    return null;
  }

  /// The footer's filled button: "Import 128 contacts", "Update 3 contacts", or "Keep 4 contacts as yours".
  String get importLabel {
    if (toImport > 0) return ImportText.importN(toImport + toUpdate);
    if (toUpdate > 0) return ImportText.updateN(toUpdate);
    if (toLink > 0) return ImportText.keepN(toLink);
    return ImportText.importN(0);
  }

  /// No card has an action other than skip by default: the filled button is "Choose another file".
  bool get nothingByDefault =>
      rows.every((r) => r.group == RowGroup.groups || r.item.action == 'skip') && _actions.isEmpty;

  /// The choices sent: only those that differ from the cards' defaults.
  List<ImportChoiceIn> get choices => [
        for (final r in rows)
          if (r.group != RowGroup.skipped && actionOf(r) != r.item.action)
            ImportChoiceIn(index: r.item.index, action: ImportChoiceInActionEnum.fromJson(actionOf(r))!),
      ];

  /// Cancel: the preview is discarded and Choose shows. Nothing was written, so it never asks.
  Future<void> cancelReview() async {
    final p = preview;
    preview = null;
    previewAccount = null;
    _go(ImportStep.choose);
    if (p != null) await _discard(p.id);
  }

  /// Read the copy again (an expired account review), or back to Choose for a file.
  Future<void> startOver() async {
    final account = previewAccount;
    preview = null;
    previewAccount = null;
    _go(ImportStep.choose);
    if (account != null) {
      final a = sources.icloud.where((s) => s.id == account).firstOrNull;
      if (a != null) await readAccount(a);
    }
  }

  // ------------------------------------------------------------------------------------------------------
  // Compare (H3).
  // ------------------------------------------------------------------------------------------------------

  bool isComparing(ReviewRow r) => compares.containsKey(r.item.index);

  void toggleCompare(ReviewRow r) {
    final index = r.item.index;
    if (compares.remove(index) != null) {
      _notify();
      return;
    }
    final state = compares[index] = CompareState();
    _notify();
    unawaited(_loadCompare(r, state));
  }

  Future<void> _loadCompare(ReviewRow r, CompareState state) async {
    final p = preview;
    final c = _c;
    if (p == null || c == null) {
      state
        ..loading = false
        ..failed = true;
      _notify();
      return;
    }
    try {
      final match = r.ownMatch;
      final results = await Future.wait<Object?>([
        ImportsApi(c.client).importPreviewItem(p.id, r.item.index),
        if (match?.contactId != null) c.sources.contact(match!.contactId!, includeDeleted: true),
      ]);
      state.card = results[0] as ImportCardOut?;
      state.contact = results.length > 1 ? results[1] as ContactDetailOut? : null;
      state.failed = state.card == null;
    } on Object catch (e) {
      if (HostRefusal.of(e).status == 404 && preview?.id == p.id) expired = true;
      state.failed = true;
    }
    state.loading = false;
    _notify();
  }

  // ------------------------------------------------------------------------------------------------------
  // Importing.
  // ------------------------------------------------------------------------------------------------------

  /// Import: one request; the host makes its backup copy first, then saves every card in one
  /// transaction. Done shows what the host returns, never the preview's counts.
  Future<void> commit() async {
    final p = preview;
    final c = _c;
    if (p == null || committing || importDisabledReason != null || expired) return;
    committing = true;
    reviewFailure = null;
    _notify();
    final leftOut = rows
        .where((r) =>
            r.group != RowGroup.groups &&
            r.group != RowGroup.skipped &&
            r.group != RowGroup.conflicts &&
            actionOf(r) == 'skip')
        .length;
    final duplicates = rowsIn(RowGroup.duplicates).where(isTicked).length;
    final skippedRows = rowsIn(RowGroup.skipped);
    final timer = Timer(importingDelay, () {
      if (committing && !_disposed) _go(ImportStep.importing);
    });
    ImportCommittedOut? out;
    HostRefusal? refusal;
    try {
      if (c == null) throw StateError('not connected');
      out = await ImportsApi(c.client).commitImport(
        p.id,
        ImportCommitIn(choices: choices, acceptLosses: needsAcceptance && acceptLosses),
      );
      if (out == null) refusal = const HostRefusal(noAnswer: true);
    } on Object catch (e) {
      refusal = HostRefusal.of(e);
    } finally {
      timer.cancel();
      committing = false;
    }
    if (_disposed) return;
    if (refusal != null || out == null) {
      final r = refusal ?? const HostRefusal(noAnswer: true);
      if (r.status == 404) {
        expired = true;
      } else if (r.status == 503) {
        reviewFailure = ImportText.commitNoBackup;
      } else if (r.status == 400) {
        reviewFailure = ImportText.commitChanged;
      } else {
        reviewFailure = ImportText.commitNoAnswer;
      }
      if (step != ImportStep.review) {
        _go(ImportStep.review);
      } else {
        stepSerial++;
        _notify();
      }
      if (r.status == 400) await refreshPreview();
      return;
    }
    result = out;
    doneLeftOut = leftOut;
    doneDuplicates = duplicates;
    doneSkipped = p.counts.skipped;
    doneSkippedRows = skippedRows;
    doneLosses = p.losses;
    followingSettled = false;
    preview = null;
    _go(ImportStep.done);
    unawaited(loadHistory());
    unawaited(sources.load());
    unawaited(host.refresh());
  }

  /// "Import more": back to Choose.
  void importMore() => _go(ImportStep.choose);

  /// A count of the committed import's (`counts.created`, …).
  int resultCount(String key) {
    final v = result?.counts[key];
    return v is num ? v.toInt() : 0;
  }

  /// "Keep following": the question goes; following stays as it is (Settings, Sources).
  void keepFollowing() {
    followingSettled = true;
    _notify();
  }

  /// Stops following the account of the import: null when done, else the Dialog's failure line.
  Future<String?> stopFollowing(String accountId, String email) async {
    final c = _c;
    if (c == null) return ImportText.stopFailed(email);
    try {
      await c.sources.removeAccount(accountId);
    } on Object {
      return ImportText.stopFailed(email);
    }
    followingSettled = true;
    _notify();
    unawaited(sources.load());
    unawaited(host.refresh());
    return null;
  }

  /// The email of followed account [id], from the sources (null when it is not followed any more).
  String? emailOf(String? id) => id == null ? null : sources.icloud.where((s) => s.id == id).firstOrNull?.email;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
