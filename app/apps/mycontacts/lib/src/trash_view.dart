import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contacts_controller.dart';

/// Recently deleted: the contacts deleted in the apps, kept 30 days before the host deletes them for good
/// (design/components/MultiSelect, "Used by", and Dialog).
///
/// - **From 600px:** the list pane (its title, one sentence, then the deleted contacts, several selectable)
///   beside a pane for the selection: one contact's name, when it was deleted and when it goes for good, with
///   Restore and "Delete permanently…"; or, for several, the count, the names, "Restore 3 contacts" and
///   "Delete 3 contacts permanently…".
/// - **Under 600px:** the list; tapping a contact pushes its pane.
/// - Restore brings the contact back at once, with an Undo toast. "Delete permanently…" asks first, saying
///   that it cannot be undone and until when copies stay in the host's backups (the host's
///   `backups_kept_until`); then the contact is gone, with no toast.
/// - Nothing deleted: an EmptyState that leads back to the contacts.
class TrashView extends StatefulWidget {
  const TrashView({super.key, required this.controller, required this.toasts, required this.onShowContacts});

  final ContactsController controller;
  final ToastController toasts;
  final VoidCallback onShowContacts;

  static const title = 'Recently deleted';
  static const intro =
      'Contacts you delete stay here for 30 days, so you can restore them. Then they are deleted for good.';
  static const emptyTitle = 'Nothing recently deleted';
  static const emptySentence =
      'Contacts you delete stay here for 30 days, so you can restore them. Then they are deleted for good.';
  static const emptyAction = 'Show contacts';
  static const restoreLabel = 'Restore';
  static const purgeLabel = 'Delete permanently…';
  static const failedTitle = 'myContacts could not read Recently deleted';
  static const failedMessage = 'The host did not answer. Try again in a moment.';

  /// "14 October 2026", the local day of the host's UTC time [iso].
  static String day(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    final d = iso.length == 10 ? t : t.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// What the purge dialog says of the host's backups.
  static String backupsLine(String keptUntil) =>
      'Copies in your host\'s backups are kept until ${day(keptUntil)}.';

  @override
  State<TrashView> createState() => _TrashViewState();
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _TrashViewState extends State<TrashView> {
  final _selection = MultiSelectController<String>();
  final _paneScroll = ScrollController();
  String? _error;

  ContactsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
    _c.addListener(_trashChanged);
    unawaited(_c.loadTrash());
    _trashChanged();
  }

  @override
  void dispose() {
    _selection.removeListener(_changed);
    _c.removeListener(_trashChanged);
    _selection.dispose();
    _paneScroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => _error = null);
  }

  List<TrashItemOut> get _items => _c.trash ?? const [];

  /// The list's rows follow Recently deleted; when nothing is selected the first is.
  void _trashChanged() {
    final ids = [for (final t in _items) t.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ids.join('\u0001') != _selection.rows.join('\u0001')) _selection.rows = ids;
      if (_selection.count == 0 && ids.isNotEmpty && !AppLayout.isPhone(context)) _selection.select(ids.first);
    });
  }

  TrashItemOut? _item(String id) => _items.where((t) => t.id == id).firstOrNull;

  bool get _phone => AppLayout.isPhone(context);

  Future<void> _restore(List<String> ids) async {
    final result = await _c.restore(ids);
    if (!mounted) return;
    final entry = result.entry;
    if (result.done.isNotEmpty && entry != null) {
      final n = result.done.length;
      widget.toasts.show(n == 1 ? 'Contact restored' : '$n contacts restored', undo: () async {
        return UndoResult(await _c.undo(entry));
      });
    }
    final failure = result.failure;
    if (failure != null) {
      final one = ids.length == 1;
      final lead = one ? 'The contact could not be restored.' : 'The contacts could not all be restored.';
      final changed = one
          ? 'It changed elsewhere since this list was read. Look at it again, then try again.'
          : changedSince;
      setState(() => _error = failure is ChangedElsewhere
          ? '$lead $changed'
          : '$lead ${one ? _whyOne(failure) : _why(failure)} Check that the host is running, then try again.');
    }
    if (_phone && result.done.isNotEmpty) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  static String _why(WriteFailure f) => f is NoAnswer ? 'The host did not answer.' : 'The host refused one of them.';
  static String _whyOne(WriteFailure f) => f is NoAnswer ? 'The host did not answer.' : 'The host refused it.';

  /// A contact here was restored, changed and deleted again elsewhere since this list was read: the list is
  /// read again, so the user sees that version before acting on it.
  static const changedSince = 'One of them changed elsewhere since this list was read. Look at it again, then try '
      'again.';

  Future<void> _purge(List<String> ids) async {
    final items = [for (final id in ids) ?_item(id)];
    if (items.isEmpty) return;
    final one = items.length == 1;
    final kept = TrashView.backupsLine(items.first.backupsKeptUntil);
    final remaining = [...ids];
    // The versions this dialog names: pressing its button again after a failure never deletes a version
    // changed elsewhere meanwhile.
    final seen = {for (final i in items) i.id: i.contact?.etag};
    final done = await showMyDataDialog(
      context: context,
      builder: (_) => MyDataDialog(
        title: one ? 'Delete ${items.single.title} permanently?' : 'Delete ${items.length} contacts permanently?',
        message: one
            ? 'It is deleted for good. This cannot be undone. $kept'
            : '${summariseNames([for (final i in items) i.title])} are deleted for good. This cannot be undone. '
                '$kept',
        confirmLabel: one ? 'Delete permanently' : 'Delete ${items.length} contacts',
        destructive: true,
        workingLabel: 'Deleting…',
        workingAnnouncement: one ? 'Deleting ${items.single.title}' : 'Deleting ${items.length} contacts',
        onConfirm: () async {
          final result = await _c.purge([...remaining], seen: seen);
          remaining.removeWhere(result.done.contains);
          final failure = result.failure;
          if (failure == null) return null;
          if (failure is ChangedElsewhere) {
            return one
                ? 'The contact was not deleted. It changed elsewhere since this list was read. Look at it again, '
                    'then try again.'
                : 'The contacts could not all be deleted. $changedSince';
          }
          return '${one ? 'The contact' : 'The contacts'} could not be deleted. ${_why(failure)} Check that '
              'the host is running, then try again.';
        },
      ),
    );
    if (!mounted) return;
    if (done && _phone) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final trash = _c.trash;
          if (trash == null) {
            return _c.trashFailed
                ? StatusPanel(
                    kind: StatusPanelKind.error,
                    title: TrashView.failedTitle,
                    message: TrashView.failedMessage,
                    actions: [
                      Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _c.loadTrash),
                    ],
                  )
                : const StatusPanel(
                    kind: StatusPanelKind.working,
                    title: 'Reading Recently deleted',
                    message: 'Getting it from the host.',
                  );
          }
          if (trash.isEmpty) {
            return EmptyState(
              title: TrashView.emptyTitle,
              sentence: TrashView.emptySentence,
              actionLabel: TrashView.emptyAction,
              onAction: widget.onShowContacts,
            );
          }
          return _layout(context);
        },
      );

  Widget _list(EdgeInsets padding) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!_phone) ...[
          Semantics(header: true, child: Text(TrashView.title, style: MyDataType.title.copyWith(color: c.ink))),
          const SizedBox(height: MyDataSpace.s2),
        ],
        Text(TrashView.intro, style: MyDataType.body.copyWith(color: c.inkMuted)),
        const SizedBox(height: MyDataSpace.s4),
        MultiSelectList<String>(
          controller: _selection,
          label: TrashView.title,
          countLabel: (n) => _phone ? '$n selected' : '$n contacts selected',
          semanticLabelOf: (id) {
            final t = _item(id);
            return t == null ? '' : '${t.title}, deleted ${TrashView.day(t.deletedAt)}';
          },
          onOpen: (id) {
            if (_phone) _push(id);
          },
          itemBuilder: (context, id) => _row(id),
        ),
      ]),
    );
  }

  Widget _row(String id) {
    final c = context.colors;
    final t = _item(id);
    if (t == null) return const SizedBox.shrink();
    final contact = t.contact;
    return Row(children: [
      Avatar(name: t.title, givenName: contact?.givenName ?? '', familyName: contact?.familyName ?? ''),
      const SizedBox(width: GroupedRow.gap),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t.title,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
          Text('Deleted ${TrashView.day(t.deletedAt)}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataType.caption.copyWith(color: c.inkMuted)),
        ]),
      ),
    ]);
  }

  /// The pane for the selection: one contact, or the count of several.
  Widget _pane() {
    final ids = _selection.selected;
    if (ids.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final error = _error;
    final Widget body;
    if (ids.length == 1) {
      final t = _item(ids.single);
      if (t == null) return const SizedBox.shrink();
      body = _One(item: t, onRestore: () => _restore([t.id]), onPurge: () => _purge([t.id]));
    } else {
      final names = [for (final id in ids) _item(id)?.title ?? ''];
      body = MultiSelectSummary(
        title: '${ids.length} contacts selected',
        names: summariseNames(names),
        actions: [
          Button(label: 'Restore ${ids.length} contacts', onPressed: () => _restore(ids)),
          Button(
            label: 'Delete ${ids.length} contacts permanently…',
            variant: ButtonVariant.plainDanger,
            onPressed: () => _purge(ids),
          ),
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (error != null) ...[
        Semantics(liveRegion: true, child: Text(error, style: context.type(MyDataType.body).copyWith(color: c.danger))),
        const SizedBox(height: MyDataSpace.s4),
      ],
      body,
    ]);
  }

  /// The Mac frame: the list column (`list-width`) of plain two-line rows (the name, and when it was deleted
  /// in `caption`), a hairline, then the pane for the selection on `content-background`.
  Widget _macLayout() {
    final mac = context.mac;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: MyDataMacSize.listWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: MyDataSpace.s2),
          child: MultiSelectList<String>(
            controller: _selection,
            label: TrashView.title,
            countLabel: (n) => '$n contacts selected',
            semanticLabelOf: (id) {
              final t = _item(id);
              return t == null ? '' : '${t.title}, deleted ${TrashView.day(t.deletedAt)}';
            },
            itemBuilder: (context, id) => _macRow(context, id),
          ),
        ),
      ),
      VerticalDivider(width: 1, thickness: 1, color: mac.separator),
      Expanded(
        child: SingleChildScrollView(
          controller: _paneScroll,
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s8, MyDataSpace.s6, MyDataSpace.s8, MyDataSpace.s8),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
              child: KeyedSubtree(key: ValueKey(_selection.selected.join(',')), child: _pane()),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _macRow(BuildContext context, String id) {
    final mac = context.mac;
    final t = _item(id);
    if (t == null) return const SizedBox.shrink();
    final on = MacRowEmphasis.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyDataMacType.body.copyWith(color: on ? mac.onAccent : mac.label)),
      Text('Deleted ${TrashView.day(t.deletedAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MyDataMacType.caption.copyWith(color: on ? mac.onAccent : mac.secondaryLabel)),
    ]);
  }

  Widget _layout(BuildContext context) {
    if (MacLook.of(context)) return _macLayout();
    final layout = AppLayout.of(context);
    final pad = PageScaffold.paddingFor(layout);
    final insets = MediaQuery.paddingOf(context);
    if (layout == AppLayout.phone) {
      return _list(EdgeInsets.fromLTRB(pad + insets.left, insets.top, pad + insets.right, pad + insets.bottom));
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
                child: AnimatedSwitcher(duration: MyDataMotion.fast, child: KeyedSubtree(
                  key: ValueKey(_selection.selected.join(',')),
                  child: _pane(),
                )),
              ),
            ),
          ),
        ),
      ]);
    });
  }

  void _push(String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([_c, _selection]),
            builder: (context, _) {
              final t = _item(id);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(MyDataSpace.s4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Button(
                      label: TrashView.title,
                      icon: Icons.arrow_back_ios_new_rounded,
                      variant: ButtonVariant.plain,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: MyDataSpace.s4),
                  if (t != null) _One(item: t, onRestore: () => _restore([id]), onPurge: () => _purge([id])),
                ]),
              );
            },
          ),
        ),
      ),
    ));
  }
}

/// One deleted contact: its name, when it was deleted and when it goes for good, Restore and "Delete
/// permanently…".
class _One extends StatelessWidget {
  const _One({required this.item, required this.onRestore, required this.onPurge});

  final TrashItemOut item;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Semantics(header: true, child: Text(item.title, style: context.type(MyDataType.displayLg).copyWith(color: c.ink))),
      const SizedBox(height: MyDataSpace.s2),
      Text(
        'Deleted on ${TrashView.day(item.deletedAt)}. It is deleted for good on ${TrashView.day(item.purgeAfter)}, '
        'unless you restore it.',
        style: context.type(MyDataType.body).copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: MultiSelectSummary.actionsGap),
      ButtonRow(children: [
        Button(label: TrashView.restoreLabel, onPressed: onRestore),
        Button(label: TrashView.purgeLabel, variant: ButtonVariant.plainDanger, onPressed: onPurge),
      ]),
    ]);
  }
}
