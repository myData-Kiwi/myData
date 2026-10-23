import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_actions.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';
import 'contacts_view.dart';
import 'review.dart';
import 'review_view.dart';
import 'trash_view.dart';

/// The app's screen, in its frame: a panel for every state of the host, an EmptyState while there are no
/// contacts, the contacts once there are some, and Recently deleted.
///
/// The frame's sections are Contacts and Recently deleted. At the bottom of the sidebar it says how the host
/// is: starting, connected (with a link that opens myData), or unreachable (with Retry). Contacts already
/// read stay on screen while the host cannot be reached, with the time they were read. The web build, which
/// cannot reach a host, shows only its panel, without the frame.
///
/// The menu bar (macOS; the same keys with Control on Windows and Linux) has New Contact ⌘N, Save ⌘S, Undo
/// and Redo named from the action, Edit Contact ⌘E, Delete Contact ⌘⌫ ("Delete 3 Contacts…") and the two
/// sections ⌘1 and ⌘2 (design/platforms.md). A phone has "New contact" and "More actions" (Undo) in its large
/// title instead. Toasts sit at the bottom of the content area.
class ContactsHome extends StatefulWidget {
  const ContactsHome({
    super.key,
    required this.host,
    this.backend,
    this.store,
    this.links,
    this.onOpenLink,
    this.menuPlatform,
    this.openLink,
  });

  final HostController host;

  /// Opens a link in another app (File > Import… opens myData's Import); null uses [appLinks]. Tests pass a
  /// fake.
  final Future<bool> Function(MyDataLink link)? openLink;

  /// The platform the menu bar is built for; null is the one the app runs on. Tests pass one.
  final TargetPlatform? menuPlatform;

  /// The way to the host's contacts; null uses the host's API through [host]'s connection.
  final ContactsBackend? backend;

  /// Where this device remembers the contact last opened; null uses the device's own file.
  final DeviceStore? store;

  /// Links macOS opened this app with; null listens on the runner's channel ([IncomingLinks]).
  final Stream<MyDataLink>? links;

  /// Opens a contact's web address; null uses the system's browser ([openInBrowser]).
  final WebOpener? onOpenLink;

  static const appName = 'myContacts';
  static const sections = [
    AppSection(icon: Icons.contacts_outlined, label: 'Contacts'),
    AppSection(icon: Icons.delete_outline_rounded, label: 'Deleted'),
    AppSection(icon: Icons.fact_check_outlined, label: 'Review'),
  ];

  /// The sections with Review's count ("Review, 4").
  static List<AppSection> sectionsWith(int review, {bool more = false}) => [
        sections[0],
        sections[1],
        AppSection(icon: sections[2].icon, label: sections[2].label, count: review, countMore: more),
      ];

  /// The sections as the Mac frame's sidebar shows them, with its icons (Lucide, in place of SF Symbols), in
  /// the Mac's title case and without counts, as Contacts.app's sidebar (and the SwiftUI prototype's).
  static List<AppSection> get macSections => [
        for (final (i, icon) in [MacIcons.people, MacIcons.trash, MacIcons.review].indexed)
          AppSection(icon: icon, label: macTitles[i]),
      ];

  /// The Mac frame's sidebar labels and toolbar titles.
  static const macTitles = ['Contacts', 'Recently Deleted', 'Review'];

  /// File, Import… (design/platforms.md; ImportFlow, "Where it lives"): opens myData at its Import section.
  static const importMenuItem = 'Import…';
  static const importLabel = 'Import contacts…';
  static const importFailed = 'myContacts could not open myData. Open it, then choose Import.';

  static const noSourceTitle = 'No contacts yet';
  static const noSourceSentence =
      'Add a contact here, or import a file of your contacts in myData, under Import. To see the contacts you '
      'already have, turn on a source in myData, under Settings, Sources.';
  static const nothingReadTitle = 'No contacts yet';
  static const nothingReadSentence =
      'myData has not read any contacts from your sources yet. They appear here when it has; you can add one '
      'now.';
  static const newContactLabel = ContactActions.newLabel;

  @override
  State<ContactsHome> createState() => _ContactsHomeState();
}

class _ContactsHomeState extends State<ContactsHome> {
  late final ContactsController _contacts = ContactsController(
    backend: widget.backend ?? HostContactsBackend(() => widget.host.connection),
    store: widget.store,
  );
  final _toasts = ToastController();
  late final _actions =
      ContactActions(controller: _contacts, toasts: _toasts, context: () => context, onReview: _openReview);
  late final _review = ReviewModel(controller: _contacts);
  DateTime? _reviewRead;

  /// 0: Contacts; 1: Recently deleted; 2: Review.
  int _section = 0;
  IncomingLinks? _incoming;
  StreamSubscription<MyDataLink>? _links;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.addListener(_followHost);
    _contacts.addListener(_followContacts);
    _host.connect();
    final links = widget.links ?? (_incoming = IncomingLinks(app: MyDataAppId.mycontacts)).links;
    _links = links.listen(_onLink);
    unawaited(_incoming?.start());
  }

  void _followHost() => unawaited(_contacts.follow(_host.phase));

  /// The possible duplicates are read again whenever the contacts were (Review's count follows them).
  void _followContacts() {
    final at = _contacts.updatedAt;
    if (at == null || at == _reviewRead || _host.phase != HostPhase.running) return;
    _reviewRead = at;
    unawaited(_review.load());
  }

  /// The contact page's "Review": Review opens on that contact.
  Future<void> _openReview(String id) async {
    await _select(2);
    if (_section == 2) _review.openChanged(id);
  }

  /// File, Import…: myData comes forward at its Import section (mydata://import/contacts); myContacts stays as
  /// it was.
  Future<void> _import() async {
    final open = widget.openLink ?? appLinks.openLink;
    final ok = await open(const OpenMyDataImport()).catchError((Object _) => false);
    if (!mounted || ok) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text(ContactsHome.importFailed)));
  }

  void _onLink(MyDataLink link) {
    if (link is OpenContact) {
      if (_section != 0) unawaited(_select(0));
      _contacts.openLink(link);
    }
    if (link is OpenContactList) {
      // myData's Done ("Open in myContacts"): the import made contacts this app has not read yet, and may
      // have hidden followed copies; Review's pairs follow the list.
      _contacts.readListAgain();
      if (_section != 0) unawaited(_select(0));
    }
  }

  @override
  void dispose() {
    _host.removeListener(_followHost);
    _contacts.removeListener(_followContacts);
    _links?.cancel();
    _review.dispose();
    _incoming?.dispose();
    _contacts.dispose();
    _toasts.dispose();
    _host.dispose();
    super.dispose();
  }

  /// Changing section leaves an open inspector first, asking when it has changes.
  Future<void> _select(int section) async {
    if (section == _section) return;
    if (!await _actions.leaveEditor()) return;
    _contacts.endMerge();
    if (mounted) setState(() => _section = section);
  }

  Future<void> _newContact() async {
    if (_section != 0) await _select(0);
    if (_section == 0) await _actions.newContact();
  }

  bool get _isRunning => _host.phase == HostPhase.running;

  /// The menu bar's items (design/platforms.md "The menu bar on macOS"), in its title case.
  Widget _menuBar(Widget child) {
    final contacts = _section == 0 && _isRunning;
    final ids = contacts ? _contacts.selectedIds : const <String>[];
    final deletable = _actions.deletable(ids);
    final one = ids.length == 1 ? ids.single : null;
    final editing = _contacts.editing != null;
    final canEdit = contacts && !editing && one != null && _contacts.isEditable(one);
    final canMerge = contacts && _contacts.merging == null && _contacts.mergeDisabledReason(ids) == null;
    return AppMenuBar(
      appName: ContactsHome.appName,
      platform: widget.menuPlatform,
      file: [
        AppMenuItem(
          title: menuTitleCase(ContactActions.newLabel),
          shortcut: AppMenuBar.newShortcut,
          onSelected: _isRunning ? () => unawaited(_newContact()) : null,
        ),
        AppMenuItem(title: ContactsHome.importMenuItem, onSelected: () => unawaited(_import())),
        // Enabled while an inspector is open: it claims Save.
        const AppMenuItem(title: 'Save', shortcut: AppMenuBar.saveShortcut),
      ],
      edit: [
        AppMenuItem(
          title: menuTitleCase(ContactActions.editLabel),
          shortcut: AppMenuBar.editShortcut,
          onSelected: canEdit ? () => unawaited(_actions.edit(one)) : null,
        ),
        AppMenuItem(
          title: menuTitleCase(ContactActions.mergeLabel),
          onSelected: canMerge ? () => unawaited(_actions.merge(ids)) : null,
        ),
        AppMenuItem.delete(
          title: menuTitleCase(_actions.deleteLabelFor(ids)),
          onSelected: deletable.isEmpty || !_actions.canDeleteNow(ids) ? null : () => unawaited(_actions.delete(ids)),
        ),
      ],
      view: [
        for (var i = 0; i < ContactsHome.sections.length; i++)
          AppMenuItem(
            title: const ['Contacts', 'Recently Deleted', 'Review'][i],
            shortcut: AppMenuBar.sectionShortcut(i + 1),
            onSelected: () => unawaited(_select(i)),
          ),
      ],
      // While the inspector is open, ⌘Z and Edit, Undo are the form's typing only: taking back a change on the
      // host would leave the open form stale.
      undoAction: _isRunning && !editing ? _actions.undoTitle : null,
      onUndo: editing ? null : () => unawaited(_actions.undoLast()),
      child: child,
    );
  }

  /// A phone's large title: "New contact" and "More actions" (Undo), since a phone has no menu bar.
  List<Widget> _phoneTitleActions() => !_isRunning
      ? const []
      : [
          MyDataIconButton(
            icon: Icons.add_rounded,
            label: ContactActions.newLabel,
            onPressed: () => unawaited(_newContact()),
          ),
          MoreActionsButton(
            entries: () => [
              _actions.undoMenuItem(),
              const MenuSeparator(),
              MenuItem(label: ContactsHome.importLabel, onSelected: () => unawaited(_import())),
            ],
          ),
        ];

  /// The frame's "Open myData" link.
  Future<void> _openMyData() async {
    final opened = await _host.platform.openMyDataApp(setup: false).catchError((Object _) => false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('myContacts could not open myData from here. Open the myData app yourself.')),
    );
  }

  /// The Mac frame ([MacLook]): the translucent sidebar with the sections and the host's state, then the
  /// section on `content-background` under its toolbar band. Contacts draws its own bands (search, Edit, New).
  /// Its other states (no contacts yet, waiting, an error) have no New button in the band: + sits only at the
  /// list's top, and the empty state's one button is New Contact (⌘N works throughout).
  Widget _macFrame(AppConnection? connection) {
    final body = _body();
    final Widget content = body is ContactsView
        ? body
        : MacPane(toolbar: MacToolbar(title: ContactsHome.macTitles[_section]), child: body);
    final phase = _host.phase;
    // A host failure's panel says it, with its Retry: the sidebar's line would say it again.
    final panelShowsHost = phase != HostPhase.running && phase != HostPhase.unsupported && !_showingContacts;
    return MacAppFrame(
      sections: ContactsHome.macSections,
      current: _section,
      onSelect: (i) => unawaited(_select(i)),
      connection: connection,
      showConnection: !panelShowsHost,
      child: connection == null ? content : ToastHost(controller: _toasts, child: content),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_host, _contacts, _contacts.selection, _review]),
    builder: (context, _) => _menuBar(
      MacLook.of(context)
          // Transparent: the window's sidebar material shows through the sidebar.
          ? Scaffold(backgroundColor: Colors.transparent, body: _macFrame(_connection()))
          : Scaffold(
        backgroundColor: context.colors.bg,
        body: switch (_connection()) {
          // No host to connect to (the web build): the panel alone, without a frame whose connection line
          // would offer a Retry that cannot help.
          null => _body(),
          final connection => AppFrame(
            appName: ContactsHome.appName,
            sections: ContactsHome.sectionsWith(_review.count, more: _review.capped),
            current: _section,
            onSelect: (i) => unawaited(_select(i)),
            connection: connection,
            phoneTitleActions: _phoneTitleActions(),
            child: ToastHost(
              controller: _toasts,
              aboveFloatingBar: AppLayout.isPhone(context) && ContactsHome.sections.length > 1,
              child: _body(),
            ),
          ),
        },
      ),
    ),
  );

  Widget _view() => ContactsView(
    controller: _contacts,
    onOpenLink: widget.onOpenLink ?? openInBrowser,
    actions: _actions,
  );

  /// How the frame shows the host; null when this build cannot have one ([HostPhase.unsupported]).
  AppConnection? _connection() => switch (_host.phase) {
    HostPhase.checking || HostPhase.starting || HostPhase.restarting => const AppConnection.starting(),
    HostPhase.running => AppConnection.connected(onOpenMyData: _openMyData),
    HostPhase.notConfigured ||
    HostPhase.failedToStart ||
    HostPhase.unreachable ||
    HostPhase.refused ||
    HostPhase.incompatible ||
    HostPhase.lost => AppConnection.unreachable(
      onRetry: _host.retry,
      lastUpdated: _showingContacts ? _lastUpdated() : null,
    ),
    HostPhase.unsupported => null,
  };

  /// Contacts are on screen (they stay while the host cannot be reached).
  bool get _showingContacts => _contacts.entries.isNotEmpty;

  String? _lastUpdated() {
    final at = _contacts.updatedAt;
    if (at == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Last updated at ${two(at.hour)}:${two(at.minute)}.';
  }

  Widget _body() {
    final phase = _host.phase;
    if (phase != HostPhase.unsupported && phase != HostPhase.running && _showingContacts) {
      return _view();
    }
    return switch (phase) {
      HostPhase.checking => const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Looking for the myData host',
        message: 'Connecting to the host on this computer.',
      ),
      HostPhase.starting => const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Starting the myData host',
        message: 'This can take a few seconds.',
      ),
      HostPhase.restarting => const StatusPanel(
        kind: StatusPanelKind.working,
        title: HostController.restartingTitle,
        message: HostController.restartingMessage,
      ),
      HostPhase.notConfigured => _failure('The myData host is not set up'),
      HostPhase.failedToStart => _failure('The myData host did not start'),
      HostPhase.unreachable => _failure(AppConnection.unreachableText),
      HostPhase.refused => _failure('The myData host refused this app'),
      HostPhase.incompatible => _failure('The myData host is from another build'),
      HostPhase.lost => _failure(AppConnection.lostText),
      HostPhase.unsupported => StatusPanel(
        kind: StatusPanelKind.info,
        title: 'myContacts needs the desktop app',
        message: _host.error ?? 'Open myContacts on the computer that runs the myData host.',
      ),
      HostPhase.running => _running(),
    };
  }

  Widget _running() {
    final contacts = _contacts;
    if (_section == 1) {
      return TrashView(controller: contacts, toasts: _toasts, onShowContacts: () => unawaited(_select(0)));
    }
    if (_section == 2) return ReviewView(model: _review, toasts: _toasts);
    // A new contact's inspector, even while there are no contacts yet.
    if (contacts.editing != null && !AppLayout.isPhone(context)) return _view();
    if (contacts.loadFailed) {
      return StatusPanel(
        kind: StatusPanelKind.error,
        title: 'myContacts could not read your contacts',
        message: 'The host did not answer. Try again in a moment.',
        actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: contacts.reload)],
      );
    }
    if (contacts.anySourceOn == null || contacts.contacts == null) {
      return const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Reading your contacts',
        message: 'Getting them from the host.',
      );
    }
    if (contacts.entries.isEmpty) {
      final noSource = !contacts.anySourceOn!;
      return EmptyState(
        title: noSource ? ContactsHome.noSourceTitle : ContactsHome.nothingReadTitle,
        sentence: noSource ? ContactsHome.noSourceSentence : ContactsHome.nothingReadSentence,
        actionLabel: ContactsHome.newContactLabel,
        onAction: () => unawaited(_newContact()),
      );
    }
    return _view();
  }

  Widget _failure(String title) => StatusPanel(
    kind: StatusPanelKind.error,
    title: title,
    message: _host.error ?? 'Something went wrong while connecting.',
    detail: _host.detail,
    actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _host.retry)],
  );
}
