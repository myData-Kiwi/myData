import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contact_actions.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';
import 'mac_contact_page.dart';
import 'merge_pane.dart';

/// The contacts screen (design/components/ContactList):
///
/// - **From 600px:** the list pane (search, letter groups) beside the contact pane, `space-8` apart. The
///   contact pane shows the selected contact; Up and Down in the list move the selection and the pane
///   follows at once.
/// - **Under 600px:** the list fills the screen, and pressing a contact pushes its page in, with a back
///   button. A link that opens a contact pushes its page too.
/// - A link to a contact the host does not have is one plain line: in the contact pane from 600px, above
///   the list under 600px.
/// - **Editing** (from 600px): the inspector takes the contact pane's place, at its width, and the list
///   stays beside it and usable (design/components/Inspector). Choosing another contact while it has changes
///   asks "Discard changes?" first. A toast then sits over the list, beside the inspector.
/// - **Several selected** (from 600px): the contact pane shows the count, up to three names, and "Delete 3
///   contacts" (design/components/MultiSelect); followed contacts are counted out, with the reason.
/// - "New contact" sits beside the search field from 600px; on a phone it is in the large title.
/// - **The Mac frame** ([MacLook]): the list column (`list-width`) with the search field in the toolbar band
///   above it and the plain list ([ContactListStyle.plain]) under it, holding the keyboard at first; a
///   hairline; then the contact column with Edit and New contact in the toolbar band and [MacContactPage]
///   under it. The inspector, several selected and Merge take the contact column's place under the band, as
///   above.
class ContactsView extends StatefulWidget {
  const ContactsView({super.key, required this.controller, required this.onOpenLink, required this.actions});

  final ContactsController controller;
  final WebOpener onOpenLink;
  final ContactActions actions;

  static const newContactLabel = ContactActions.newLabel;

  /// "3 contacts selected".
  static String selectedTitle(int n) => '$n contacts selected';

  /// The list's content width at its widest (preview: `.list{flex:0 1 340px}`).
  static const listMaxWidth = 340.0;

  /// The list's content width at its narrowest, in a narrow window.
  static const listMinWidth = 240.0;

  /// The share of the window's content the list pane takes before it reaches [listMaxWidth].
  static const listShare = 0.4;

  /// Between the list and the contact pane (preview: `.two{gap:32px}`), split between their paddings so
  /// neither cuts off the groups' shadows.
  static const paneGap = MyDataSpace.s8;

  static const missingLinkText =
      'The contact that link opens is not on your host. It may have been deleted, '
      'or its source turned off in myData.';

  /// The back button of a pushed contact page.
  static const backLabel = 'Contacts';

  /// The toolbar's search field (the Mac frame); the same words as the list's own field.
  static const searchPlaceholder = ContactList.searchPlaceholder;

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  StreamSubscription<String>? _links;
  final _paneScroll = ScrollController();
  final _listFocus = FocusNode(debugLabel: 'Contacts list');
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'Contacts search');
  bool _wasEditing = false;

  ContactsController get _controller => widget.controller;
  ContactActions get _actions => widget.actions;

  @override
  void initState() {
    super.initState();
    _links = _controller.linkOpened.listen(_linkOpened);
    _controller.addListener(_followEditing);
    _wasEditing = _controller.editing != null;
    // The Mac frame starts with the list holding the keyboard, as Contacts.app does: the selection shows in
    // the accent and the arrow keys move it at once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !MacLook.of(context)) return;
      // Only when nothing has the keyboard yet (a scope, not a control, holds the primary focus).
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null || focus is FocusScopeNode) _listFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_followEditing);
    _links?.cancel();
    _paneScroll.dispose();
    _listFocus.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The inspector closed: focus goes to the record's row in the list (the new row after creating one).
  void _followEditing() {
    final editing = _controller.editing != null;
    if (_wasEditing && !editing && !_phone && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _listFocus.canRequestFocus) _listFocus.requestFocus();
      });
    }
    _wasEditing = editing;
  }

  bool get _phone => AppLayout.of(context) == AppLayout.phone;

  void _linkOpened(String id) {
    if (!mounted) return;
    if (_phone) {
      // One contact page at a time: a link replaces the page already open.
      Navigator.of(context).popUntil((route) => route.isFirst);
      _push(id);
    } else if (_paneScroll.hasClients) {
      _paneScroll.jumpTo(0);
    }
  }

  Future<void> _open(String id) async {
    final editing = _controller.editing;
    if (editing != null && editing.id != id) {
      // Choosing another contact leaves the inspector, asking first when it has changes.
      if (!await _actions.leaveEditor()) {
        if (editing.id != null) _controller.open(editing.id!);
        return;
      }
      if (!mounted) return;
    }
    final changed = _controller.selectedId != id;
    _controller.open(id);
    if (_phone) {
      _push(id);
    } else if (changed && _paneScroll.hasClients) {
      _paneScroll.jumpTo(0);
    }
  }

  void _push(String id) {
    Widget page(BuildContext _) =>
        _PushedContactPage(controller: _controller, id: id, onOpenLink: widget.onOpenLink, actions: _actions);
    Navigator.of(context).push(
      // With reduced motion the page simply appears.
      MyDataMotion.reduced(context)
          ? PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => page(context),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            )
          : MaterialPageRoute<void>(builder: page),
    );
  }

  /// The Mac frame: the list column, a hairline, the contact column; each with its part of the toolbar band.
  Widget _macLayout({required bool missing}) {
    final mac = context.mac;
    final selection = _controller.selection;
    final several = selection.count > 1;
    final selected = several ? null : _controller.selectedId;
    final edit = _controller.editing;
    final editable = selected != null && edit == null && _controller.isEditable(selected);
    final platform = Theme.of(context).platform;

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MacToolbar(
          leading: [
            Expanded(
              child: MacSearchField(
                controller: _search,
                focusNode: _searchFocus,
                placeholder: ContactsView.searchPlaceholder,
                width: double.infinity,
                onDown: _listFocus.requestFocus,
              ),
            ),
          ],
        ),
        Expanded(
          child: ContactList(
            style: ContactListStyle.plain,
            showSearch: false,
            searchController: _search,
            searchFocusNode: _searchFocus,
            contacts: _controller.entries,
            selectedId: selected,
            selection: selection,
            focusNode: _listFocus,
            onOpen: (id) => unawaited(_open(id)),
            menuFor: _actions.menuFor,
            onReturn: (id) => unawaited(_actions.edit(id)),
            onDelete: () => unawaited(_actions.deleteSelected()),
            padding: const EdgeInsets.symmetric(vertical: MyDataSpace.s2),
          ),
        ),
      ],
    );

    final Widget pane;
    if (edit != null) {
      pane = _actions.editor(edit);
    } else {
      final Widget content = _controller.merging != null
          ? MergePane(
              key: ValueKey(_controller.merging),
              session: _controller.merging!,
              title: MergePane.mergeTitle(_controller.merging!.ids.length),
              plainLabel: 'Cancel',
              onPlain: _controller.endMerge,
              onMerge: () => unawaited(_actions.confirmMerge()),
            )
          : missing
          ? const _PlainLine(ContactsView.missingLinkText)
          : several
          ? _Selection(controller: _controller, actions: _actions)
          : selected == null
          ? const SizedBox.shrink()
          : MacContactPage(
              key: ValueKey(selected),
              controller: _controller,
              id: selected,
              onOpenLink: widget.onOpenLink,
              actions: _actions,
            );
      pane = Semantics(
        container: true,
        explicitChildNodes: true,
        child: SingleChildScrollView(
          controller: _paneScroll,
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s8, MyDataSpace.s6, MyDataSpace.s8, MyDataSpace.s8),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: MacContactPage.maxWidth), child: content),
          ),
        ),
      );
    }

    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MacToolbar(
          trailing: edit != null
              ? const []
              : [
                  MacToolbarButton.text(
                    text: ContactActions.editButton,
                    label: ContactActions.editLabel,
                    shortcut: AppMenuBar.editShortcut.label(platform),
                    disabledReason: selected == null || several ? null : _actions.reasonFor(selected),
                    onPressed: editable ? () => unawaited(_actions.edit(selected)) : null,
                  ),
                  MacToolbarButton(
                    icon: MacIcons.add,
                    label: ContactsView.newContactLabel,
                    shortcut: AppMenuBar.newShortcut.label(platform),
                    onPressed: () => unawaited(_actions.newContact()),
                  ),
                ],
        ),
        Expanded(child: pane),
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: MyDataMacSize.listWidth, child: list),
        VerticalDivider(width: 1, thickness: 1, color: mac.separator),
        Expanded(child: contact),
      ],
    );
    if (edit == null) return row;
    // A toast centres on the list, beside the inspector, never over it.
    return Stack(children: [
      Positioned.fill(child: row),
      const PositionedDirectional(start: 0, top: 0, bottom: 0, width: MyDataMacSize.listWidth, child: ToastArea()),
    ]);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final layout = AppLayout.of(context);
      final pad = PageScaffold.paddingFor(layout);
      final insets = MediaQuery.paddingOf(context);
      final missing = _controller.missingLinkId != null;

      if (MacLook.of(context)) return _macLayout(missing: missing);

      if (layout == AppLayout.phone) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missing)
              Padding(
                padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right, 0),
                child: const _PlainLine(ContactsView.missingLinkText),
              ),
            Expanded(
              child: ContactList(
                contacts: _controller.entries,
                selectedId: _controller.selectedId,
                onOpen: (id) => unawaited(_open(id)),
                menuFor: _actions.menuFor,
                padding: EdgeInsets.fromLTRB(
                  pad + insets.left,
                  (missing ? MyDataSpace.s4 : pad) + (missing ? 0 : insets.top),
                  pad + insets.right,
                  pad + insets.bottom,
                ),
              ),
            ),
          ],
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final half = ContactsView.paneGap / 2;
          final listWidth = (constraints.maxWidth * ContactsView.listShare - pad - half).clamp(
            ContactsView.listMinWidth,
            ContactsView.listMaxWidth,
          );
          final selection = _controller.selection;
          final several = selection.count > 1;
          final selected = several ? null : _controller.selectedId;
          final edit = _controller.editing;
          final listPane = listWidth + pad + half + insets.left;
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: listPane,
                child: ContactList(
                  contacts: _controller.entries,
                  selectedId: selected,
                  selection: selection,
                  focusNode: _listFocus,
                  onOpen: (id) => unawaited(_open(id)),
                  menuFor: _actions.menuFor,
                  onReturn: (id) => unawaited(_actions.edit(id)),
                  onDelete: () => unawaited(_actions.deleteSelected()),
                  searchTrailing: MyDataIconButton(
                    icon: Icons.add_rounded,
                    label: ContactsView.newContactLabel,
                    shortcut: AppMenuBar.newShortcut.activator(Theme.of(context).platform),
                    onPressed: () => unawaited(_actions.newContact()),
                  ),
                  padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, half, pad + insets.bottom),
                ),
              ),
              if (edit != null)
                // The inspector in the contact pane's place, at its width; the list stays beside it.
                Expanded(child: _actions.editor(edit))
              else
                Expanded(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: SingleChildScrollView(
                    controller: _paneScroll,
                    padding: EdgeInsets.fromLTRB(half, pad + insets.top, pad + insets.right, pad + insets.bottom),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
                        child: _controller.merging != null
                            ? MergePane(
                                key: ValueKey(_controller.merging),
                                session: _controller.merging!,
                                title: MergePane.mergeTitle(_controller.merging!.ids.length),
                                plainLabel: 'Cancel',
                                onPlain: _controller.endMerge,
                                onMerge: () => unawaited(_actions.confirmMerge()),
                              )
                            : missing
                            ? const _PlainLine(ContactsView.missingLinkText)
                            : several
                            ? _Selection(controller: _controller, actions: _actions)
                            : selected == null
                            ? const SizedBox.shrink()
                            : ContactPage(
                                key: ValueKey(selected),
                                controller: _controller,
                                id: selected,
                                onOpenLink: widget.onOpenLink,
                                actions: _actions,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          if (edit == null) return row;
          // A toast centres on the list, beside the inspector, never over it.
          return Stack(children: [
            Positioned.fill(child: row),
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: listPane, child: const ToastArea()),
          ]);
        },
      );
    },
  );
}

/// The contact pane while several contacts are selected (design/components/MultiSelect): the count, up to
/// three names, and Delete for the ones the host owns; the others are counted out with the reason.
class _Selection extends StatelessWidget {
  const _Selection({required this.controller, required this.actions});

  final ContactsController controller;
  final ContactActions actions;

  @override
  Widget build(BuildContext context) {
    final ids = controller.selection.selected;
    final deletable = actions.deletable(ids);
    final leftOut = leftOutReason(controller, ids, deletable.length);
    final n = deletable.length;
    return MultiSelectSummary(
      title: ContactsView.selectedTitle(ids.length),
      names: summariseNames([for (final id in ids) controller.nameOf(id)]),
      leftOut: leftOut,
      actions: [
        Button(
          label: n <= 1 ? 'Delete contact' : 'Delete $n contacts',
          variant: ButtonVariant.plainDanger,
          onPressed: n == 0 ? null : () => unawaited(actions.delete(ids)),
        ),
      ],
    );
  }
}

/// Why some of [ids] are left out of the selection's actions (followed contacts), or null when none is:
/// "1 of them is from this Mac and is changed in Contacts."
String? leftOutReason(ContactsController controller, List<String> ids, int actionable) {
  final out = [for (final id in ids) if (!controller.isEditable(id)) id];
  if (out.isEmpty) return null;
  final n = out.length;
  final mac = out.where(controller.isFromThisMac).length;
  final one = n == 1;
  final where = mac == n
      ? 'from this Mac and ${one ? 'is' : 'are'} changed in Contacts'
      : mac == 0
          ? 'from ${one ? 'an iCloud account' : 'iCloud accounts'} and ${one ? 'is' : 'are'} changed there'
          : 'from sources and are changed there';
  if (actionable == 0) return 'None of them can be deleted here. ${one ? 'It is' : 'They are'} $where.';
  return '$n of them ${one ? 'is' : 'are'} $where.';
}

/// One sentence in `body` and `ink-muted`.
class _PlainLine extends StatelessWidget {
  const _PlainLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: context.type(MyDataType.body).copyWith(color: context.colors.inkMuted));
}

/// A contact's page pushed over the list under 600px, with a back button to the list. If the window
/// grows past 600px while it is open, it closes: the two panes then show the same contact.
class _PushedContactPage extends StatefulWidget {
  const _PushedContactPage({
    required this.controller,
    required this.id,
    required this.onOpenLink,
    required this.actions,
  });

  final ContactsController controller;
  final String id;
  final WebOpener onOpenLink;
  final ContactActions actions;

  @override
  State<_PushedContactPage> createState() => _PushedContactPageState();
}

class _PushedContactPageState extends State<_PushedContactPage> {
  /// The contact was in the list when its page opened: once it leaves the list (deleted here), the page
  /// goes back to the list.
  late final bool _listed = widget.controller.entryFor(widget.id) != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_follow);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_follow);
    super.dispose();
  }

  void _follow() {
    if (_listed && widget.controller.entryFor(widget.id) == null && mounted) {
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final id = widget.id;
    final onOpenLink = widget.onOpenLink;
    final layout = AppLayout.of(context);
    if (layout != AppLayout.phone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    final pad = PageScaffold.paddingFor(layout);
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right, pad + insets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Button(
                  label: ContactsView.backLabel,
                  icon: Icons.arrow_back_ios_new_rounded,
                  variant: ButtonVariant.plain,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (controller.detailOf(id) case DetailReady(:final contact) when contact.editable)
                  ContactPageActions(actions: widget.actions, contact: contact),
              ]),
              const SizedBox(height: MyDataSpace.s4),
              ContactPage(
                controller: controller,
                id: id,
                onOpenLink: onOpenLink,
                actions: widget.actions,
                showActions: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
