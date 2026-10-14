import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_actions.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';
import 'contacts_view.dart';
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
  });

  final HostController host;

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
  ];

  static const noSourceTitle = 'No contacts yet';
  static const noSourceSentence =
      'Add a contact here, or turn on a source in myData, under Settings, Sources, to see the contacts you '
      'already have.';
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
  late final _actions = ContactActions(controller: _contacts, toasts: _toasts, context: () => context);

  /// 0: Contacts; 1: Recently deleted.
  int _section = 0;
  IncomingLinks? _incoming;
  StreamSubscription<MyDataLink>? _links;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.addListener(_followHost);
    _host.connect();
    final links = widget.links ?? (_incoming = IncomingLinks(app: MyDataAppId.mycontacts)).links;
    _links = links.listen(_onLink);
    unawaited(_incoming?.start());
  }

  void _followHost() => unawaited(_contacts.follow(_host.phase));

  void _onLink(MyDataLink link) {
    if (link is OpenContact) _contacts.openLink(link);
  }

  @override
  void dispose() {
    _host.removeListener(_followHost);
    _links?.cancel();
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
    final canEdit = contacts && _contacts.editing == null && one != null && _contacts.isEditable(one);
    return AppMenuBar(
      appName: ContactsHome.appName,
      platform: widget.menuPlatform,
      file: [
        AppMenuItem(
          title: menuTitleCase(ContactActions.newLabel),
          shortcut: AppMenuBar.newShortcut,
          onSelected: _isRunning ? () => unawaited(_newContact()) : null,
        ),
        // Enabled while an inspector is open: it claims Save.
        const AppMenuItem(title: 'Save', shortcut: AppMenuBar.saveShortcut),
      ],
      edit: [
        AppMenuItem(
          title: menuTitleCase(ContactActions.editLabel),
          shortcut: AppMenuBar.editShortcut,
          onSelected: canEdit ? () => unawaited(_actions.edit(one)) : null,
        ),
        AppMenuItem.delete(
          title: menuTitleCase(_actions.deleteLabelFor(ids)),
          onSelected: deletable.isEmpty ? null : () => unawaited(_actions.delete(ids)),
        ),
      ],
      view: [
        for (var i = 0; i < ContactsHome.sections.length; i++)
          AppMenuItem(
            title: i == 0 ? 'Contacts' : 'Recently Deleted',
            shortcut: AppMenuBar.sectionShortcut(i + 1),
            onSelected: () => unawaited(_select(i)),
          ),
      ],
      undoAction: _isRunning ? _actions.undoTitle : null,
      onUndo: () => unawaited(_actions.undoLast()),
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
          MoreActionsButton(entries: () => [_actions.undoMenuItem()]),
        ];

  /// The frame's "Open myData" link.
  Future<void> _openMyData() async {
    final opened = await _host.platform.openMyDataApp(setup: false).catchError((Object _) => false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('myContacts could not open myData from here. Open the myData app yourself.')),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_host, _contacts, _contacts.selection]),
    builder: (context, _) => _menuBar(
      Scaffold(
        backgroundColor: context.colors.bg,
        body: switch (_connection()) {
          // No host to connect to (the web build): the panel alone, without a frame whose connection line
          // would offer a Retry that cannot help.
          null => _body(),
          final connection => AppFrame(
            appName: ContactsHome.appName,
            sections: ContactsHome.sections,
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
      HostPhase.unreachable => _failure('The myData host is not answering'),
      HostPhase.refused => _failure('The myData host refused this app'),
      HostPhase.incompatible => _failure('The myData host is from another build'),
      HostPhase.lost => _failure('The myData host stopped'),
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
