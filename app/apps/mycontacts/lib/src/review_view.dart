import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contacts_controller.dart';
import 'merge_pane.dart';
import 'review.dart';

/// myContacts' third section, Review (design/components/DuplicatePair, "The Review section"): a list of
/// possible duplicates and of contacts changed in a followed account since the import, and a pane with the
/// DuplicatePair for the selected row: "Same person?" (Merge, or "Not the same person") or "Changed in
/// iCloud" (Save changes, or Keep mine). Each answer goes with a Toast and Undo.
class ReviewView extends StatefulWidget {
  const ReviewView({super.key, required this.model, required this.toasts});

  final ReviewModel model;
  final ToastController toasts;

  static const title = 'Review';
  static const emptyTitle = 'Nothing to review';
  static const emptySentence = 'When two contacts look like the same person, or a contact changes in an account '
      'myData follows, it shows here.';
  static const failedTitle = 'myContacts could not read what to review';
  static const failedMessage = 'The host did not answer. Try again in a moment.';
  static const samePerson = 'Same person?';
  static const notSame = 'Not the same person';
  static const saveChanges = 'Save changes';
  static const savingLabel = 'Saving…';
  static const keepMine = 'Keep mine';
  static const keepingLabel = 'Keeping…';
  static const inMyData = 'In myData';
  static const afterSaving = 'Your contact after saving.';
  static const nothingLine = 'This contact has nothing to review any more.';

  /// "Possible duplicates (3)"; "(500+)" when the host's answer reached its limit.
  static String duplicatesHeading(int n, {bool more = false}) => 'Possible duplicates ($n${more ? '+' : ''})';
  static String changedHeading(int n) => 'Changed since import ($n)';

  /// "Ava Fictional and Ava M. Fictional".
  static String pairTitle(DuplicatePairOut p) => p.contacts.map((c) => c.displayName).join(' and ');

  /// "Same email: ava@example.org", "Same phone: 555-0142", "Same name".
  static String pairCaption(DuplicatePairOut p) {
    if (p.signals.contains('email') && p.emails.isNotEmpty) return 'Same email: ${p.emails.first}';
    if (p.signals.contains('phone') && p.phones.isNotEmpty) return 'Same phone: ${p.phones.first}';
    return 'Same name';
  }

  /// "The line under the pane's title" (DuplicatePair, Anatomy): why the two may be one person.
  static String pairReason(DuplicatePairOut p) {
    if (p.signals.contains('email')) return 'They share an email address.';
    if (p.signals.contains('phone')) return 'They share a phone number.';
    return 'They have the same name.';
  }

  /// "Changed in the iCloud account ava@example.org", "Changed on this Mac".
  static String changedCaption(String? label) {
    if (label == null) return 'Changed in a source myData follows';
    return label.startsWith('this Mac') ? 'Changed on $label' : 'Changed in $label';
  }

  /// The pane's title for a change: "Changed in iCloud", "Changed on this Mac".
  static String changesTitle(String label) => label.startsWith('this Mac') ? 'Changed on this Mac' : 'Changed in iCloud';

  /// The followed copy's column: "In iCloud now", "On this Mac now".
  static String followedColumn(String label) => label.startsWith('this Mac') ? 'On this Mac now' : 'In iCloud now';

  @override
  State<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<ReviewView> {
  final _paneScroll = ScrollController();

  ReviewModel get _m => widget.model;
  ContactsController get _c => _m.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _m.active = true;
    });
    unawaited(_m.load());
  }

  @override
  void dispose() {
    _m.leaveQuietly();
    _paneScroll.dispose();
    super.dispose();
  }

  bool get _phone => AppLayout.isPhone(context);

  Future<UndoResult> _undo(UndoEntry entry) async {
    final said = await _c.undo(entry);
    unawaited(_m.load());
    return UndoResult(said);
  }

  Future<void> _merge() async {
    final s = _m.pair;
    final key = _m.selected;
    if (s == null || key == null) return;
    final names = [for (final x in s.inOrder) x.displayName];
    final out = await s.merge();
    if (out == null || !mounted) return;
    final entry = _c.merged(out, names: names);
    _m.leave(key);
    widget.toasts.show(mergedToast(out), undo: () => _undo(entry));
    unawaited(_m.load());
    if (_phone) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _notSame() async {
    final entry = await _m.notSamePerson();
    if (entry == null || !mounted) return;
    widget.toasts.show('Marked as different people', undo: () => _undo(entry));
    if (_phone) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _settle({required bool save}) async {
    final s = _m.changes;
    final key = _m.selected;
    if (s == null || key == null) return;
    final name = s.data?.contact.displayName ?? 'This contact';
    final w = save ? await s.save() : await s.keep();
    if (w == null || !mounted) return;
    final undoId = w.undoId;
    if (undoId == null) return;
    final entry = _c.reviewed(
      action: save ? 'Save changes' : 'Keep my version',
      undoId: undoId,
      name: name,
      undone: save ? 'Changes undone' : 'Marked as changed again',
      contactIds: [w.contact.id],
      contact: w.contact,
    );
    widget.toasts.show(save ? 'Changes saved' : 'Kept your version', undo: () => _undo(entry));
    if (_phone) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_m, _c]),
        builder: (context, _) {
          if (_m.pairs == null) {
            return _m.failed
                ? StatusPanel(
                    kind: StatusPanelKind.error,
                    title: ReviewView.failedTitle,
                    message: ReviewView.failedMessage,
                    actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _m.load)],
                  )
                : const StatusPanel(
                    kind: StatusPanelKind.working,
                    title: 'Reading what to review',
                    message: 'Getting it from the host.',
                  );
          }
          if (_m.keys.isEmpty && _m.paneLine == null) return const _Empty();
          final layout = AppLayout.of(context);
          final pad = PageScaffold.paddingFor(layout);
          final insets = MediaQuery.paddingOf(context);
          if (layout == AppLayout.phone) {
            return _list(EdgeInsets.fromLTRB(pad + insets.left, insets.top, pad + insets.right, pad + insets.bottom));
          }
          // The Mac frame: the list column (`list-width`, plain lists, the count in the toolbar's title), a
          // hairline, then the pane.
          if (MacLook.of(context)) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: MyDataMacSize.listWidth,
                child: _list(const EdgeInsets.symmetric(vertical: MyDataSpace.s2)),
              ),
              VerticalDivider(width: 1, thickness: 1, color: context.mac.separator),
              Expanded(
                child: SingleChildScrollView(
                  controller: _paneScroll,
                  padding: const EdgeInsets.fromLTRB(MyDataSpace.s8, MyDataSpace.s6, MyDataSpace.s8, MyDataSpace.s8),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: MyDataMacSize.contentWidth),
                      child: KeyedSubtree(key: ValueKey(_m.selected), child: _pane()),
                    ),
                  ),
                ),
              ),
            ]);
          }
          return LayoutBuilder(builder: (context, constraints) {
            const gap = MyDataSpace.s8;
            final listWidth = (constraints.maxWidth * 0.4 - pad - gap / 2).clamp(240.0, 340.0);
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: listWidth + pad + gap / 2 + insets.left,
                child: _list(EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, gap / 2, pad + insets.bottom)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _paneScroll,
                  padding: EdgeInsets.fromLTRB(gap / 2, pad + insets.top, pad + insets.right, pad + insets.bottom),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
                      child: KeyedSubtree(key: ValueKey(_m.selected), child: _pane()),
                    ),
                  ),
                ),
              ),
            ]);
          });
        },
      );

  Widget _list(EdgeInsets padding) {
    final c = context.colors;
    final pairs = _m.pairs ?? const <DuplicatePairOut>[];
    final changed = _m.changed;
    return SingleChildScrollView(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_phone && !MacLook.of(context)) ...[
          Semantics(
            header: true,
            child: Text('${ReviewView.title}, ${_m.countText}', style: MyDataType.title.copyWith(color: c.ink)),
          ),
          const SizedBox(height: MyDataSpace.s4),
        ],
        if (pairs.isNotEmpty)
          GroupedList(
            heading: ReviewView.duplicatesHeading(pairs.length, more: _m.capped),
            rows: [
              for (final p in pairs)
                GroupedRow(
                  key: ValueKey(ReviewModel.pairKey(p)),
                  title: ReviewView.pairTitle(p),
                  subtitle: ReviewView.pairCaption(p),
                  selected: !_phone && _m.selected == ReviewModel.pairKey(p),
                  onPressed: () => _open(ReviewModel.pairKey(p)),
                ),
            ],
          ),
        if (pairs.isNotEmpty && changed.isNotEmpty)
          SizedBox(height: MacLook.of(context) ? MyDataSpace.s2 : PageScaffold.gap),
        if (changed.isNotEmpty)
          GroupedList(
            heading: ReviewView.changedHeading(changed.length),
            rows: [
              for (final x in changed)
                GroupedRow(
                  key: ValueKey(ReviewModel.changedKey(x.id)),
                  title: x.displayName,
                  subtitle: ReviewView.changedCaption(_labelOf(x.id)),
                  selected: !_phone && _m.selected == ReviewModel.changedKey(x.id),
                  onPressed: () => _open(ReviewModel.changedKey(x.id)),
                ),
            ],
          ),
      ]),
    );
  }

  String? _labelOf(String id) => switch (_c.detailOf(id)) {
        DetailReady(:final contact) => contact.changedInSourceLabel,
        _ => null,
      };

  void _open(String key) {
    _m.select(key);
    if (_phone) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: context.colors.bg,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: _m,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(MyDataSpace.s4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Button(
                      label: ReviewView.title,
                      icon: Icons.arrow_back_ios_new_rounded,
                      variant: ButtonVariant.plain,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: MyDataSpace.s4),
                  _pane(),
                ]),
              ),
            ),
          ),
        ),
      ));
    }
  }

  /// The pane for the selected row.
  Widget _pane() {
    final line = _m.paneLine;
    if (line != null) {
      // The pair is no longer a duplicate: the line alone, with no actions.
      return Semantics(
        liveRegion: true,
        child: Text(line, style: context.type(MyDataType.body).copyWith(color: context.colors.inkMuted)),
      );
    }
    final pair = _m.pair;
    if (pair != null) {
      final p = _m.selected == null ? null : _m.pairOf(_m.selected!);
      return MergePane(
        session: pair,
        title: ReviewView.samePerson,
        reason: p == null ? null : ReviewView.pairReason(p),
        plainLabel: ReviewView.notSame,
        onPlain: () => unawaited(_notSame()),
        onMerge: () => unawaited(_merge()),
        escapeCancels: false,
      );
    }
    final changes = _m.changes;
    if (changes != null) return _ChangesPane(session: changes, onSave: () => _settle(save: true), onKeep: () => _settle(save: false));
    return const SizedBox.shrink();
  }
}

/// "Changed in iCloud": the contact beside its followed copy as it is now, with a Select per differing row
/// in the "After" column, then "Keep mine" and "Save changes".
class _ChangesPane extends StatelessWidget {
  const _ChangesPane({required this.session, required this.onSave, required this.onKeep});

  final ChangesSession session;
  final VoidCallback onSave;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final c = context.colors;
          final s = session;
          final change = s.change;
          final data = s.data;
          if (!s.loading && (s.nothing || data == null || change == null)) {
            return Text(s.message ?? ReviewView.nothingLine, style: context.type(MyDataType.body).copyWith(color: c.inkMuted));
          }
          final label = change?.sourceLabel ?? '';
          final apple = Theme.of(context).platform == TargetPlatform.macOS;
          final versions = data == null || change == null
              ? [
                  const PairVersion(name: ReviewView.inMyData, caption: '', fields: {}),
                  const PairVersion(name: 'In iCloud now', caption: '', fields: {}),
                ]
              : [
                  ContactPair.ofContact(data.contact, name: ReviewView.inMyData, caption: MergePane.added(data.contact)),
                  ContactPair.ofContact(change.followed,
                      name: ReviewView.followedColumn(label), caption: _changedCaption(change)),
                ];
          final title = change == null ? 'Changed since import' : ReviewView.changesTitle(label);
          final mac = MacLook.of(context);
          final after = PairAfter(
            title: PairAfter.changesTitle,
            caption: ReviewView.afterSaving,
            fields: data == null ? const {} : ContactPair.ofContact(data.contact, caption: '').fields,
            choices: s.choices,
            onChoose: s.working ? null : s.choose,
          );
          final actions = [
            SteadyWidthButton(
              label: ReviewView.keepMine,
              shown: s.working && !s.saving ? ReviewView.keepingLabel : ReviewView.keepMine,
              // The Mac frame: push buttons, the plain one grey.
              variant: mac ? ButtonVariant.tonal : ButtonVariant.plain,
              onPressed: s.loading ? null : (s.working ? _inert : onKeep),
            ),
            SteadyWidthButton(
              label: ReviewView.saveChanges,
              shown: s.working && s.saving ? ReviewView.savingLabel : ReviewView.saveChanges,
              variant: ButtonVariant.filled,
              onPressed: s.loading ? null : (s.working ? _inert : onSave),
            ),
          ];
          return CallbackShortcuts(
            bindings: {
              SingleActivator(LogicalKeyboardKey.enter, meta: apple, control: !apple): () {
                if (!s.working && !s.loading) onSave();
              },
            },
            child: FocusScope(
              child: FormBusy(
                busy: s.working,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Semantics(header: true, child: Text(title, style: context.type(MyDataType.displayLg).copyWith(color: c.ink))),
                  const SizedBox(height: MyDataSpace.s2),
                  if (change != null)
                    Text(
                      'This contact changed in ${change.sourceLabel} after you imported it.',
                      style: context.type(MyDataType.body).copyWith(color: c.inkMuted),
                    ),
                  const SizedBox(height: MyDataSpace.s4),
                  if (mac)
                    // The Mac frame: the same pair as a Mac table on the pane's ground (MacPairTable).
                    MacPairTable(
                      mode: PairMode.changes,
                      loading: s.loading,
                      versions: versions,
                      differences: s.differences,
                      after: after,
                      message: s.message,
                      messageIsError: s.messageIsError,
                      actions: actions,
                    )
                  else
                    DuplicatePair(
                      mode: PairMode.changes,
                      loading: s.loading,
                      versions: versions,
                      differences: s.differences,
                      after: after,
                      message: s.message,
                      messageIsError: s.messageIsError,
                      actions: actions,
                    ),
                ]),
              ),
            ),
          );
        },
      );

  static String _changedCaption(FollowedChangeOut change) {
    final d = DateTime.tryParse(change.followed.modifiedAt);
    final where = change.sourceLabel.startsWith('this Mac') ? 'on this Mac' : 'in iCloud';
    if (d == null) return 'Changed $where';
    return 'Changed $where ${MyDataDates.day(d.toLocal())}';
  }

  static void _inert() {}
}

/// Nothing to review: a centred title and one sentence; no button, so it is not an EmptyState and has no
/// kiwi.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The Mac frame: the one empty state, with the kiwi (MacEmptyState).
    if (MacLook.of(context)) return const MacEmptyState(title: ReviewView.emptyTitle, line: ReviewView.emptySentence);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MyDataSpace.s8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(
              header: true,
              child: Text(ReviewView.emptyTitle, textAlign: TextAlign.center, style: context.type(MyDataType.title).copyWith(color: c.ink)),
            ),
            const SizedBox(height: MyDataSpace.s2),
            Text(ReviewView.emptySentence, textAlign: TextAlign.center, style: context.type(MyDataType.body).copyWith(color: c.inkMuted)),
          ]),
        ),
      ),
    );
  }
}
