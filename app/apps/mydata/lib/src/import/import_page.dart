import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import '../source_list.dart';
import '../sources_section.dart';
import 'import_controller.dart';
import 'import_files.dart';
import 'import_text.dart';
import 'import_widgets.dart';
import 'review_step.dart';

/// myData's Import section (design/components/ImportFlow): Choose, Review, Importing and Done on one page,
/// then the import's place in the history, where it can be undone. Contacts only for now.
///
/// - While files are dragged over the window, the whole page takes them on Choose, and the DropZone shows
///   it will (design/components/DropZone, "Where it takes a drop").
/// - Each step replaces the one before, scrolled to the top, and focus moves to its title.
/// - With the host not answering, Choose stays: the DropZone and the "Import a copy" buttons are disabled
///   with the reason, and the history shows what was last read, with the time.
class ImportPage extends StatefulWidget {
  const ImportPage({
    super.key,
    required this.controller,
    required this.sources,
    required this.installedApps,
    required this.openLink,
    this.macHost = false,
    this.acceptDrops = true,
    this.demo = false,
  });

  final ImportController controller;
  final SourceList sources;
  final InstalledApps installedApps;

  /// Opens a link in another app ("Open in myContacts"); false when it could not.
  final Future<bool> Function(MyDataLink link) openLink;

  /// The host is a Mac: a link from myContacts opens "Contacts on a Mac" at first.
  final bool macHost;

  /// Takes files dropped from the Finder (off in tests, which have no drag and drop).
  final bool acceptDrops;

  /// The host is in demo mode: the first import ends the demo.
  final bool demo;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _titleFocus = FocusNode(debugLabel: 'Import title');
  final _chooseFocus = FocusNode(debugLabel: 'Choose file');
  final _retryFocus = FocusNode(debugLabel: 'Try again');
  final _macRowKey = GlobalKey();
  final _historyFocus = <String, FocusNode>{};
  final _open = <String>{};
  bool _dragging = false;
  int _stepSerial = 0;
  int _linkSerial = 0;
  String? _lastError;
  String? _lastUndone;

  ImportController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _stepSerial = _c.stepSerial;
    _linkSerial = _c.linkSerial;
    _c.addListener(_changed);
    if (_c.linkSerial > 0 && widget.macHost) _open.add(ImportText.places.first.title);
    unawaited(_c.loadHistory());
    unawaited(_c.refreshPreview());
  }

  @override
  void didUpdateWidget(ImportPage old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _titleFocus.dispose();
    _chooseFocus.dispose();
    _retryFocus.dispose();
    for (final n in _historyFocus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_c.linkSerial != _linkSerial) {
      _linkSerial = _c.linkSerial;
      if (widget.macHost) setState(() => _open.add(ImportText.places.first.title));
    }
    if (_c.stepSerial != _stepSerial) {
      _stepSerial = _c.stepSerial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _titleFocus.requestFocus();
        if (_c.reviewFailure != null) {
          announce(context, _c.reviewFailure!, assertive: true);
        } else {
          announce(context, _title());
        }
      });
    }
    final error = _c.fileError;
    if (error != null && error != _lastError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_c.fileErrorRetry ? _retryFocus : _chooseFocus).requestFocus();
        announce(context, error, assertive: true);
      });
    }
    _lastError = error;
    final undone = _c.undoneId;
    if (undone != null && undone != _lastUndone) {
      _lastUndone = undone;
      final out = _c.lastUndone;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _historyFocus[undone]?.requestFocus();
        if (out != null) announce(context, ImportText.undone(out));
      });
    }
  }

  String _title() => switch (_c.step) {
        ImportStep.choose => ImportText.chooseTitle,
        ImportStep.review => ImportText.reviewTitle,
        ImportStep.importing => ImportText.importingTitle(_c.toImport + _c.toUpdate),
        ImportStep.done => _doneTitle(),
      };

  String _doneTitle() => ImportText.doneTitle(
        created: _c.resultCount('created'),
        updated: _c.resultCount('updated'),
        linked: _c.resultCount('linked'),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([widget.sources, widget.installedApps]),
        builder: (context, _) {
          final Widget page = switch (_c.step) {
            ImportStep.choose => _choose(),
            ImportStep.review => ReviewStep(controller: _c, titleFocus: _titleFocus, demo: widget.demo),
            ImportStep.importing => _importing(),
            ImportStep.done => _done(),
          };
          final keyed = KeyedSubtree(key: ValueKey(_c.step), child: page);
          if (!widget.acceptDrops || AppLayout.isPhone(context)) return keyed;
          final takes = _c.step == ImportStep.choose && _c.reachable && _c.readingName == null && _c.readingAccount == null;
          return DropTarget(
            enable: takes,
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (d) {
              setState(() => _dragging = false);
              unawaited(_c.useFiles([
                for (final f in d.files) XPickedFile(f, isDirectory: f is DropItemDirectory),
              ]));
            },
            child: keyed,
          );
        },
      );

  // ------------------------------------------------------------------------------------------------------
  // 1. Choose.
  // ------------------------------------------------------------------------------------------------------

  Widget _choose() {
    final c = _c;
    final reachable = c.reachable;
    final DropZoneState state;
    if (!reachable) {
      state = DropZoneState.disabled;
    } else if (c.readingName != null) {
      state = DropZoneState.reading;
    } else if (_dragging) {
      state = DropZoneState.dragging;
    } else if (c.fileError != null) {
      state = DropZoneState.error;
    } else {
      state = DropZoneState.idle;
    }
    final children = <Widget>[
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PlainHeading(ImportText.fromFile),
        DropZone(
          instruction: ImportText.instruction,
          caption: ImportText.caption,
          state: state,
          readingName: c.readingName,
          onChoose: () => unawaited(c.chooseFile()),
          onCancel: c.cancelReading,
          error: c.fileError,
          onRetry: c.fileErrorRetry && c.lastFile != null ? () => unawaited(c.retry()) : null,
          disabledReason: ImportText.hostDown,
          chooseFocusNode: _chooseFocus,
          retryFocusNode: _retryFocus,
        ),
      ]),
      _where(),
    ];
    final accounts = _accounts();
    if (accounts != null) children.add(accounts);
    final history = _history();
    if (history != null) children.add(history);
    return StepPage(title: ImportText.chooseTitle, titleFocus: _titleFocus, children: children);
  }

  Widget _where() => GroupedSection(
        heading: ImportText.whereHeading,
        parts: [
          for (final place in ImportText.places)
            DisclosurePart(
              key: place == ImportText.places.first ? _macRowKey : null,
              title: place.title,
              open: _open.contains(place.title),
              onToggle: () => setState(() {
                _open.contains(place.title) ? _open.remove(place.title) : _open.add(place.title);
              }),
              child: NumberedSteps(steps: place.steps, before: place.before, after: place.after),
            ),
        ],
      );

  /// "From an account myData follows": each followed iCloud account that holds contacts, and This Mac, never
  /// importable, with the reason and the way round it.
  Widget? _accounts() {
    final c = _c;
    final mac = widget.sources.mac;
    final accounts = [for (final a in widget.sources.icloud) if ((a.counts?.contacts ?? 0) > 0) a];
    final macShown = mac != null && mac.enabled;
    if (accounts.isEmpty && !macShown) return null;
    final busy = c.readingAccount != null || c.readingName != null;
    return GroupedSection(
      heading: ImportText.fromAccountHeading,
      parts: [
        for (final a in accounts)
          ActionRow(
            key: ValueKey('import-account-${a.id}'),
            icon: Icons.cloud_outlined,
            title: ImportText.account(a.email),
            subtitle: c.readingAccount == a.id
                ? ImportText.readingAccount(a.counts?.contacts ?? 0)
                : (c.accountErrors[a.id] ??
                    ImportText.accountCaption(a.counts?.contacts ?? 0, a.lastUpdate)),
            actions: [
              Button(
                label: ImportText.importCopy,
                onPressed: !c.reachable || busy ? null : () => unawaited(c.readAccount(a)),
              ),
            ],
          ),
        if (macShown)
          ActionRow(
            key: const ValueKey('import-account-mac'),
            icon: Icons.laptop_mac_outlined,
            title: ThisMacText.title,
            subtitle: ImportText.macNotImportable,
            actions: [Button(label: ImportText.showHow, variant: ButtonVariant.plain, onPressed: _showHow)],
          ),
      ],
    );
  }

  /// "Show how": opens "Contacts on a Mac" and scrolls to it.
  void _showHow() {
    setState(() => _open.add(ImportText.places.first.title));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _macRowKey.currentContext;
      if (target != null) unawaited(Scrollable.ensureVisible(target, duration: MyDataMotion.base));
    });
  }

  /// "Earlier imports", newest first; left out until there has been one.
  Widget? _history() {
    final c = _c;
    final list = c.history;
    if (list == null || list.isEmpty) return null;
    final at = c.historyReadAt;
    final parts = <Widget>[
      for (final i in list)
        Focus(
          focusNode: _historyFocus.putIfAbsent(i.id, () => FocusNode(debugLabel: 'Import ${i.id}', skipTraversal: true)),
          child: ActionRow(
            key: ValueKey('import-${i.id}'),
            title: ImportText.historyTitle(i, email: i.source_ == 'icloud' ? c.emailOf(i.sourceAccount) : null),
            subtitle: ImportText.historyCaption(i, kept: c.keptByImport[i.id] ?? const []),
            badge: i.status == 'undone' ? const MyDataBadge(ImportText.undoneChip, tone: MyDataTone.neutral) : null,
            actions: [
              if (i.status == 'committed')
                Button(
                  label: ImportText.undoImport,
                  variant: ButtonVariant.plainDanger,
                  onPressed: c.reachable ? () => unawaited(_confirmUndo(i)) : null,
                ),
            ],
          ),
        ),
      if (!c.reachable && at != null)
        GroupedContentPart(
          child: Text(ImportText.historyAsOf(at), style: MyDataType.caption.copyWith(color: context.colors.inkMuted)),
        ),
    ];
    return GroupedSection(heading: ImportText.historyHeading, parts: parts);
  }

  Future<void> _confirmUndo(ImportOut i) => showMyDataDialog(
        context: context,
        builder: (_) => MyDataDialog(
          title: ImportText.undoTitle,
          message: [
            ImportText.undoBody,
            if (i.source_ == 'icloud') ImportText.undoAccount,
            ImportText.undoCannot,
          ].join(' '),
          confirmLabel: ImportText.undoImport,
          destructive: true,
          workingLabel: ImportText.undoing,
          onConfirm: () => _c.undo(i),
        ),
      );

  // ------------------------------------------------------------------------------------------------------
  // 3. Importing.
  // ------------------------------------------------------------------------------------------------------

  Widget _importing() {
    final c = context.colors;
    return StepPage(
      title: _title(),
      titleFocus: _titleFocus,
      children: [
        Semantics(
          container: true,
          liveRegion: true,
          label: '${ImportText.savingLabel}. ${ImportText.savingCaption}',
          excludeSemantics: true,
          child: Row(children: [
            const KiwiLoader(size: MyDataSize.iconTile, semanticLabel: ImportText.savingLabel),
            const SizedBox(width: MyDataSpace.s4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ImportText.savingLabel, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
                const SizedBox(height: MyDataSpace.s1),
                Text(ImportText.savingCaption, style: MyDataType.caption.copyWith(color: c.inkMuted)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------------------------------------------
  // 4. Done.
  // ------------------------------------------------------------------------------------------------------

  Widget _done() {
    final c = _c;
    final r = c.result;
    if (r == null) return const SizedBox.shrink();
    final rows = <GroupedRow>[
      if (c.resultCount('updated') > 0) GroupedRow(title: ImportText.doneUpdated(c.resultCount('updated'))),
      if (c.resultCount('linked') > 0) GroupedRow(title: ImportText.doneLinked(c.resultCount('linked'))),
      if (c.doneLeftOut > 0) GroupedRow(title: ImportText.doneLeftOut(c.doneLeftOut)),
      if (c.doneSkipped > 0) GroupedRow(title: ImportText.doneSkipped(c.doneSkipped)),
      if (c.doneDuplicates > 0)
        GroupedRow(title: ImportText.doneDuplicates(c.doneDuplicates), subtitle: ImportText.doneDuplicatesCaption),
      if (r.conflicts.isNotEmpty)
        GroupedRow(
          title: ImportText.doneConflicts([for (final x in r.conflicts) x.displayName]),
          subtitle: ImportText.names([for (final x in r.conflicts) x.displayName]),
        ),
      if (r.missing.isNotEmpty) GroupedRow(title: ImportText.doneMissing(r.missing.length)),
    ];
    final contacts = widget.installedApps.isInstalled(MyDataAppId.mycontacts);
    final buttons = [
      if (contacts)
        Button(label: ImportText.openInMyContacts, variant: ButtonVariant.filled, onPressed: () => unawaited(_openContacts())),
      Button(label: ImportText.undoImport, onPressed: c.reachable ? () => unawaited(_undoFromDone(r)) : null),
      Button(
        label: ImportText.importMore,
        variant: contacts ? ButtonVariant.plain : ButtonVariant.filled,
        onPressed: c.importMore,
      ),
    ];
    final phone = AppLayout.isPhone(context);
    final children = <Widget>[
      if (rows.isNotEmpty) GroupedList(rows: rows),
      if (c.doneSkipped > 0 && c.doneSkippedRows.isNotEmpty) _skippedDisclosure(),
      phone
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(height: ButtonRow.gap), buttons[i]],
            ])
          : ButtonRow(children: buttons),
      if (r.stopFollowing != null && !c.followingSettled) _keepFollowing(r.stopFollowing!),
    ];
    return StepPage(title: _doneTitle(), titleFocus: _titleFocus, children: children);
  }

  bool _showWhich = false;

  /// "Show which": the cards that could not be read, as the loss report listed them.
  Widget _skippedDisclosure() => GroupedSection(
        heading: ImportText.lossHeading,
        parts: [
          DisclosurePart(
            title: ImportText.showWhich,
            open: _showWhich,
            onToggle: () => setState(() => _showWhich = !_showWhich),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final row in _c.doneSkippedRows)
                Text(ImportText.skippedCard(row.item), style: MyDataType.body.copyWith(color: context.colors.ink)),
              for (final l in _c.doneLosses)
                if (ImportText.loss(l) case final text?)
                  Text(text, style: MyDataType.body.copyWith(color: context.colors.ink)),
            ]),
          ),
        ],
      );

  Future<void> _openContacts() async {
    final ok = await widget.openLink(const OpenContactList()).catchError((Object _) => false);
    if (!mounted || ok) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text(ImportText.openFailed)));
    unawaited(widget.installedApps.refresh());
  }

  Future<void> _undoFromDone(ImportCommittedOut r) => _confirmUndo(ImportOut(
        id: r.id,
        label: r.label,
        source_: r.source_,
        sourceAccount: r.sourceAccount,
        startedAt: r.startedAt,
        status: r.status,
        counts: r.counts,
      ));

  /// "Keep following the iCloud account …?" after a copy of a followed account.
  Widget _keepFollowing(StopFollowingOut s) {
    final c = context.colors;
    final email = _c.emailOf(s.accountId) ?? s.label;
    final lines = [
      ImportText.keepFollowingShadow,
      ImportText.keepFollowingChanges,
      if (s.calendarsFollowed > 0) ImportText.keepFollowingCalendars(s.calendarsFollowed),
      if (s.contactsFollowed > 0) ImportText.keepFollowingLeft(s.contactsFollowed),
      if (s.contactsLinked > 0) ImportText.keepFollowingLinked(s.contactsLinked),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: MyDataSpace.s4),
      Semantics(
        header: true,
        child: Text(ImportText.keepFollowingTitle(email), style: MyDataType.heading.copyWith(color: c.ink)),
      ),
      const SizedBox(height: MyDataSpace.s3),
      Container(
        padding: GroupedContentPart.padding,
        decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg, boxShadow: context.shadows.shadow1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: MyDataSpace.s2),
            Text(lines[i], style: MyDataType.body.copyWith(color: c.ink)),
          ],
          const SizedBox(height: MyDataSpace.s4),
          ButtonRow(children: [
            Button(label: ImportText.stopFollowing, onPressed: () => unawaited(_stopFollowing(s, email))),
            Button(label: ImportText.keepFollowing, variant: ButtonVariant.plain, onPressed: _c.keepFollowing),
          ]),
        ]),
      ),
    ]);
  }

  /// Settings' own Dialog for removing an account, with the import's sentences and the backups day (H8).
  Future<void> _stopFollowing(StopFollowingOut s, String email) => showRemoveAccountDialog(
        context: context,
        title: ImportText.stopFollowingTitle(email),
        message: ImportText.stopFollowingBody(
          imported: _c.resultCount('created') + _c.resultCount('updated') + _c.resultCount('linked'),
          calendars: s.calendarsFollowed,
          keptUntil: s.backupsKeptUntil,
        ),
        confirmLabel: ImportText.stopFollowing,
        workingLabel: ImportText.stoppingWork,
        onConfirm: () => _c.stopFollowing(s.accountId, email),
      );
}
