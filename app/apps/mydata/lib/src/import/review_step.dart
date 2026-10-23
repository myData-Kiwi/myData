import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import '../format.dart';
import 'import_controller.dart';
import 'import_text.dart';
import 'import_widgets.dart';

/// Review: the host has read everything and written nothing (design/components/ImportFlow, "2. Review").
/// The summary, the loss report with its checkbox, what changed on the way in, where the contacts go, the
/// notices, the files of a zip, the lists with their ticks and Compare, and the footer with Cancel and
/// Import. ⌘Return presses Import from anywhere on the page while it is enabled.
class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key, required this.controller, required this.titleFocus, required this.demo});

  final ImportController controller;
  final FocusNode titleFocus;

  /// The host is in demo mode: the first import ends the demo.
  final bool demo;

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  bool _showAllNew = false;
  bool _showAllMissing = false;
  bool _showAllSkipped = false;
  final _importNode = FocusNode(debugLabel: 'Import');

  /// A long list is drawn a page at a time ("Show 200 more"), so a file of thousands of cards never builds
  /// thousands of rows at once.
  static const page = 200;

  /// How many rows each list draws, by its kind; [page] at first.
  final _shown = <String, int>{};

  int _shownOf(String list) => _shown[list] ?? page;

  ImportController get _c => widget.controller;

  @override
  void dispose() {
    _importNode.dispose();
    super.dispose();
  }

  void _import() => unawaited(_c.commit());

  @override
  Widget build(BuildContext context) {
    final p = _c.preview;
    if (p == null) return const SizedBox.shrink();
    final apple = Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.iOS;
    final enabled = _c.importDisabledReason == null && !_c.expired;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter, meta: apple, control: !apple): () {
          if (enabled && !_c.committing) _import();
        },
      },
      child: Focus(
        skipTraversal: true,
        // While the import is saved, nothing on the page can change what was sent.
        child: FormBusy(
          busy: _c.committing,
          child: StepPage(
            title: ImportText.reviewTitle,
            titleFocus: widget.titleFocus,
            subtitle: ImportText.readLine(p, vcardFiles: _c.entries.length, email: _c.emailOf(_c.previewAccount)),
            footer: _footer(p),
            children: _c.expired ? [_expired(p)] : _sections(p),
          ),
        ),
      ),
    );
  }

  Widget _expired(ImportPreviewOut p) => Text(
        p.source_ == 'icloud' ? ImportText.expiredAccount : ImportText.expired,
        style: context.type(MyDataType.body).copyWith(color: context.colors.ink),
      );

  Widget _footer(ImportPreviewOut p) {
    final c = _c;
    if (c.expired) {
      return StepFooter(buttons: [
        Button(
          label: p.source_ == 'icloud' ? ImportText.readCopyAgain : DropZone.defaultChooseLabel,
          variant: ButtonVariant.filled,
          onPressed: () => p.source_ == 'icloud' ? unawaited(c.startOver()) : unawaited(_chooseAgain()),
        ),
      ]);
    }
    final working = c.committing;
    if (c.nothingByDefault && c.nothingToImport) {
      return StepFooter(
        reason: p.source_ == 'icloud' ? ImportText.nothingToImportAccount : ImportText.nothingToImport,
        failure: c.reviewFailure,
        buttons: [
          Button(label: ImportText.cancel, variant: ButtonVariant.plain, onPressed: () => unawaited(c.cancelReview())),
          Button(
            label: ImportText.chooseAnother,
            variant: ButtonVariant.filled,
            onPressed: () => unawaited(_chooseAgain()),
          ),
        ],
      );
    }
    final reason = c.importDisabledReason;
    return StepFooter(
      reason: reason,
      failure: c.reviewFailure,
      buttons: [
        Button(
          label: ImportText.cancel,
          variant: ButtonVariant.plain,
          onPressed: working ? _inert : () => unawaited(c.cancelReview()),
        ),
        Semantics(
          hint: reason,
          child: Button(
            label: c.importLabel,
            variant: ButtonVariant.filled,
            focusNode: _importNode,
            onPressed: reason != null ? null : (working ? _inert : _import),
          ),
        ),
      ],
    );
  }

  static void _inert() {}

  Future<void> _chooseAgain() async {
    await _c.cancelReview();
    await _c.chooseFile();
  }

  List<Widget> _sections(ImportPreviewOut p) {
    final c = _c;
    final out = <Widget>[];
    final summary = _summary(p);
    if (summary != null) out.add(summary);
    if (p.needsAcceptance || p.losses.isNotEmpty) out.add(_losses(p));
    if (p.changes.isNotEmpty) {
      out.add(GroupedSection(
        heading: ImportText.changesHeading,
        parts: [for (final ch in p.changes) TextRowPart(ImportText.change(ch))],
      ));
    }
    out.add(Text(ImportText.whereTheyGo, style: context.type(MyDataType.body).copyWith(color: context.colors.ink)));
    final notices = _notices(p);
    if (notices.isNotEmpty) out.add(NoticeStack(notices: notices));
    final entries = c.entries;
    if (entries.isNotEmpty) {
      out.add(CheckboxList(
        heading: ImportText.filesHeading(entries.length),
        items: [
          for (final (e, n) in entries)
            CheckboxListItem(title: ImportText.fileRow(e, n), checked: !c.entriesOff.contains(e)),
        ],
        onChanged: (v) {
          for (var i = 0; i < entries.length; i++) {
            c.setEntry(entries[i].$1, v[i]);
          }
        },
      ));
    }
    final dup = c.rowsIn(RowGroup.duplicates);
    if (dup.isNotEmpty) {
      out.add(_list('duplicates', ImportText.duplicatesHeading(dup.length), dup, compare: true));
      out.add(_note(ImportText.duplicatesNote));
    }
    final upd = c.rowsIn(RowGroup.updates);
    if (upd.isNotEmpty) out.add(_list('updates', ImportText.updatesHeading(upd.length), upd));
    final already = [for (final r in c.rowsIn(RowGroup.already)) if (r.tickable) r];
    final quiet = c.rowsIn(RowGroup.quiet);
    if (already.isNotEmpty) {
      out.add(_list('already', ImportText.alreadyHeading(already.length), already, compare: true));
    }
    if (quiet.isNotEmpty) {
      out.add(_note(ImportText.leftOutLine(
        quiet.where((r) => r.item.status == 'unchanged').length,
        quiet.where((r) => r.item.status == 'in_file').length,
      )));
    }
    final conflicts = c.rowsIn(RowGroup.conflicts);
    if (conflicts.isNotEmpty) {
      final shown = _shownOf('conflicts');
      out.add(GroupedSection(
        heading: ImportText.conflictsHeading(conflicts.length),
        parts: [
          for (final r in conflicts.take(shown))
            TextRowPart(ImportText.conflict(r.item.reason), title: r.item.displayName),
        ],
      ));
      if (conflicts.length > shown) out.add(_more('conflicts', conflicts.length));
    }
    final fresh = [for (final r in c.rowsIn(RowGroup.fresh)) if (r.tickable) r];
    if (fresh.isNotEmpty) {
      out.add(_list('fresh', ImportText.newHeading(fresh.length), fresh, folded: !_showAllNew));
      if (_showAllNew && fresh.length > _shownOf('fresh')) out.add(_more('fresh', fresh.length));
      out.add(Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          expanded: _showAllNew,
          child: Button(
            label: _showAllNew ? ImportText.hideAll : ImportText.showAll(fresh.length),
            variant: ButtonVariant.plain,
            onPressed: () => setState(() {
              _showAllNew = !_showAllNew;
              _shown.remove('fresh');
            }),
          ),
        ),
      ));
    }
    if (p.missing.isNotEmpty) out.add(_missing(p.missing));
    return out;
  }

  /// "Show 200 more" under a list drawn a page at a time.
  Widget _more(String list, int total) {
    final left = total - _shownOf(list);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Button(
        label: ImportText.showMore(left < page ? left : page),
        variant: ButtonVariant.plain,
        onPressed: () => setState(() => _shown[list] = _shownOf(list) + page),
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s2),
        child: Text(text, style: context.type(MyDataType.caption).copyWith(color: context.colors.inkMuted)),
      );

  /// The summary: one row per kind with a count, rows with nothing left out; at most three tile colours.
  Widget? _summary(ImportPreviewOut p) {
    final c = _c;
    final fresh = c.tickedIn(RowGroup.fresh);
    final dup = c.tickedIn(RowGroup.duplicates);
    final upd = c.tickedIn(RowGroup.updates);
    final linked = c.linkedAlready;
    final already = c.alreadyKept;
    final conflicts = c.rowsIn(RowGroup.conflicts).length;
    final skipped = p.counts.skipped;
    final rows = <GroupedRow>[
      if (fresh > 0)
        GroupedRow(
          icon: Icons.person_add_alt_outlined,
          tone: MyDataTone.accent,
          title: ImportText.summaryNew(fresh),
          subtitle: ImportText.summaryNewCaption,
        ),
      if (dup > 0)
        GroupedRow(
          icon: Icons.people_alt_outlined,
          tone: MyDataTone.info,
          title: ImportText.summaryDuplicates(dup),
          subtitle: ImportText.summaryDuplicatesCaption,
        ),
      if (upd > 0)
        GroupedRow(
          icon: Icons.sync_outlined,
          tone: MyDataTone.neutral,
          title: ImportText.summaryUpdates(upd),
          subtitle: ImportText.summaryUpdatesCaption,
        ),
      if (already > 0)
        GroupedRow(
          icon: Icons.check_circle_outline_rounded,
          tone: MyDataTone.neutral,
          title: ImportText.summaryAlready(already),
          subtitle: linked > 0 && linked == already ? ImportText.summaryLinkedCaption : ImportText.summaryAlreadyCaption,
        ),
      if (conflicts > 0)
        GroupedRow(
          icon: Icons.edit_note_outlined,
          tone: MyDataTone.neutral,
          title: ImportText.summaryConflicts(conflicts),
          subtitle: ImportText.summaryConflictsCaption,
        ),
      if (skipped > 0)
        GroupedRow(
          icon: Icons.warning_amber_rounded,
          tone: MyDataTone.warning,
          title: ImportText.summarySkipped(skipped),
          subtitle: ImportText.summarySkippedCaption,
        ),
    ];
    return rows.isEmpty ? null : GroupedList(rows: rows);
  }

  /// The loss report: one row per unreadable card (the first five, then "Show 12 more"), one per other loss,
  /// and the checkbox that accepts them.
  Widget _losses(ImportPreviewOut p) {
    final c = _c;
    final skipped = c.rowsIn(RowGroup.skipped);
    final rest = skipped.skip(5).take(_shownOf('skipped')).toList();
    final style = context.type(MyDataType.body).copyWith(color: context.colors.ink);
    final parts = <Widget>[
      for (final r in skipped.take(5)) TextRowPart(ImportText.skippedCard(r.item)),
      if (skipped.length > 5)
        // A disclosure: the rest open under it, in place, a page at a time.
        DisclosurePart(
          title: _showAllSkipped ? ImportText.hideAll : ImportText.showMore(skipped.length - 5),
          open: _showAllSkipped,
          onToggle: () => setState(() {
            _showAllSkipped = !_showAllSkipped;
            _shown.remove('skipped');
          }),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final r in rest)
              Padding(
                padding: const EdgeInsets.only(bottom: MyDataSpace.s2),
                child: Text(ImportText.skippedCard(r.item), style: style),
              ),
            if (skipped.length - 5 > rest.length) _more('skipped', skipped.length - 5),
          ]),
        ),
      for (final l in p.losses)
        if (ImportText.loss(l) case final text?) TextRowPart(text),
      GroupedContentPart(
        child: MyDataCheckbox(
          label: ImportText.acceptLabel,
          caption: ImportText.acceptCaption(
            skipped: p.counts.skipped,
            noNotes: p.losses.any((l) => l.code == 'no_notes'),
          ),
          value: c.acceptLosses,
          onChanged: c.committing ? null : c.setAcceptLosses,
          disabledReason: c.committing ? 'The import is being saved.' : null,
        ),
      ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: ImportText.lossHeading,
      child: GroupedSection(heading: ImportText.lossHeading, parts: parts),
    );
  }

  List<Widget> _notices(ImportPreviewOut p) {
    final c = _c;
    final out = <Widget>[];
    if (widget.demo) out.add(const Notice(message: ImportText.firstData));
    if (p.counts.groups > 0) out.add(Notice(message: ImportText.groups(p.counts.groups)));
    if (p.source_ == 'icloud') {
      out.add(Notice(message: ImportText.shadowAccount(p.counts.contacts, c.emailOf(c.previewAccount))));
    } else if (p.counts.followedMatches > 0) {
      out.add(Notice(message: ImportText.shadowFile(p.counts.followedMatches, _hiddenFrom())));
    }
    return out;
  }

  /// Where the followed copies a file hides are read from: "this Mac", "the iCloud account …", or both.
  String _hiddenFrom() {
    final mac = _c.hiddenFromMac;
    final icloud = _c.hiddenFromAccounts.toList();
    if (mac && icloud.isEmpty) return 'this Mac';
    if (!mac && icloud.length == 1) {
      final email = _c.emailOf(icloud.single);
      return email == null ? 'an iCloud account myData follows' : 'the iCloud account $email';
    }
    return 'the sources myData follows';
  }

  /// A list with its select-all row and its rows' ticks; Compare beside each row when [compare].
  ///
  /// [list] names the list for its page count: only its first rows are drawn, with "Show 200 more" under it,
  /// so a long file builds a page of rows at a time.
  Widget _list(String list, String heading, List<ReviewRow> rows, {bool compare = false, bool folded = false}) {
    final c = _c;
    final phone = AppLayout.isPhone(context);
    final shown = _shownOf(list);
    final more = !folded && rows.length > shown && list != 'fresh';
    final checkboxes = CheckboxList(
      heading: heading,
      selectAllTitle: ImportText.allContacts(rows.length),
      folded: folded,
      shown: shown,
      items: [
        for (var n = 0; n < rows.length; n++)
          _item(rows[n], drawn: n < shown && !folded, compare: compare, phone: phone),
      ],
      onChanged: (v) => c.setTickedAll(rows, v),
    );
    if (!more) return checkboxes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      checkboxes,
      const SizedBox(height: MyDataSpace.s2),
      _more(list, rows.length),
    ]);
  }

  /// One row's item; the Compare button and its comparison only for a row that is drawn.
  CheckboxListItem _item(ReviewRow r, {required bool drawn, required bool compare, required bool phone}) {
    final c = _c;
    final comparing = c.isComparing(r);
    final name = r.item.displayName;
    return CheckboxListItem(
            title: name,
            caption: drawn ? _caption(r) : null,
            checked: c.isTicked(r),
            disabledReason: c.canTick(r) ? null : (r.tickable ? 'Its file in the zip is left out.' : null),
            trailing: drawn && compare && r.ownMatch != null
                ? Semantics(
                    expanded: comparing,
                    child: Button(
                      label: comparing && !phone ? ImportText.hideComparison : ImportText.compare,
                      // "Compare Ben Sample, button, collapsed" (ImportFlow, Screen readers).
                      semanticLabel: '${comparing && !phone ? ImportText.hideComparison : ImportText.compare} $name',
                      variant: ButtonVariant.plain,
                      onPressed: () => phone ? unawaited(_compareSheet(r)) : c.toggleCompare(r),
                    ),
                  )
                : null,
            below: drawn && compare && !phone && comparing
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(MyDataSpace.s4, 0, MyDataSpace.s4, MyDataSpace.s4),
                    child: _comparison(r),
                  )
                : null,
    );
  }

  String? _caption(ReviewRow r) {
    final item = r.item;
    switch (r.group) {
      case RowGroup.updates:
        return ImportText.updateCaption;
      case RowGroup.duplicates:
      case RowGroup.already:
        final m = r.ownMatch ?? item.matches.firstOrNull;
        if (m == null) return null;
        final linkDefault = item.action == 'link';
        final twoLink = item.action == 'skip' && item.choices.contains('link');
        return ImportText.matchCaption(item, m, linkDefault: linkDefault, twoLink: twoLink);
      default:
        return item.entry;
    }
  }

  /// The comparison under a row: "In the file" beside "In myData".
  Widget _comparison(ReviewRow r) {
    final state = _c.compares[r.item.index];
    final names = [ImportText.inFile, ImportText.inMyData];
    if (state == null || state.loading) {
      return DuplicatePair(
        framed: false,
        loading: true,
        versions: [
          for (final n in names) PairVersion(name: n, caption: r.item.displayName, fields: const {}),
        ],
      );
    }
    if (state.failed || state.card == null) {
      return Text(ImportText.compareFailed, style: context.type(MyDataType.body).copyWith(color: context.colors.danger));
    }
    final contact = state.contact;
    return DuplicatePair(
      framed: AppLayout.isPhone(context),
      versions: [
        ContactPair.ofCard(state.card!, name: ImportText.inFile, caption: state.card!.displayName),
        if (contact != null)
          ContactPair.ofContact(contact, name: ImportText.inMyData, caption: _added(contact))
        else
          PairVersion(
            name: ImportText.inMyData,
            caption: state.contactGone ? ImportText.contactGone : (r.ownMatch?.displayName ?? ''),
            fields: const {},
          ),
      ],
    );
  }

  static String _added(ContactDetailOut c) {
    final d = DateTime.tryParse(c.createdAt);
    return d == null ? c.displayName : '${c.displayName}, added ${formatDay(d.toLocal())}';
  }

  /// On a phone, Compare opens the pair in a picker-height Sheet.
  Future<void> _compareSheet(ReviewRow r) async {
    if (!_c.isComparing(r)) _c.toggleCompare(r);
    await showSheet<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) => Sheet(
          kind: SheetKind.picker,
          title: ImportText.compare,
          leadingLabel: 'Done',
          body: _comparison(r),
        ),
      ),
    );
    if (_c.isComparing(r)) _c.toggleCompare(r);
  }

  Widget _missing(List<ImportMissingOut> missing) {
    final c = context.colors;
    return GroupedSection(
      heading: ImportText.missingHeading(missing.length),
      parts: [
        GroupedContentPart(child: Text(ImportText.missingCaption, style: context.type(MyDataType.body).copyWith(color: c.inkMuted))),
        DisclosurePart(
          title: _showAllMissing ? ImportText.hideAll : ImportText.showAll(missing.length),
          open: _showAllMissing,
          onToggle: () => setState(() {
            _showAllMissing = !_showAllMissing;
            _shown.remove('missing');
          }),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final m in missing.take(_shownOf('missing')))
              Text(m.displayName, style: context.type(MyDataType.body).copyWith(color: c.ink)),
            if (missing.length > _shownOf('missing')) ...[
              const SizedBox(height: MyDataSpace.s2),
              _more('missing', missing.length),
            ],
          ]),
        ),
      ],
    );
  }
}
