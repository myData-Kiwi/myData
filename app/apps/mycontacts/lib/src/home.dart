import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_page.dart';
import 'contacts_controller.dart';
import 'contacts_view.dart';

/// Opens the myData app at Settings, Sources; true when it came up.
typedef OpenMyData = Future<bool> Function();

/// The one screen, in the app's frame: a panel for every state of the host, an EmptyState while no source
/// is on or no contact has been read, and the contacts once there are some.
///
/// The frame's one section is Contacts. At the bottom of the sidebar it says how the host is: starting,
/// connected (with a link that opens myData), or unreachable (with Retry). Contacts already read stay on
/// screen while the host cannot be reached, with the time they were read. The web build, which cannot
/// reach a host, shows only its panel, without the frame.
class ContactsHome extends StatefulWidget {
  const ContactsHome({
    super.key,
    required this.host,
    this.backend,
    this.store,
    this.links,
    this.openMyDataSources,
    this.onOpenLink,
  });

  final HostController host;

  /// The way to the host's contacts; null uses the host's API through [host]'s connection.
  final ContactsBackend? backend;

  /// Where this device remembers the contact last opened; null uses the device's own file.
  final DeviceStore? store;

  /// Links macOS opened this app with; null listens on the runner's channel ([IncomingLinks]).
  final Stream<MyDataLink>? links;

  /// Opens myData at Settings, Sources; null uses mydata_core's [openMyDataSources].
  final OpenMyData? openMyDataSources;

  /// Opens a contact's web address; null uses the system's browser ([openInBrowser]).
  final WebOpener? onOpenLink;

  static const appName = 'myContacts';
  static const sections = [AppSection(icon: Icons.contacts_outlined, label: 'Contacts')];

  static const noSourceTitle = 'No contacts yet';
  static const noSourceSentence =
      'Turn on a source in myData, under Settings, Sources, and your contacts '
      'appear here.';
  static const nothingReadTitle = 'No contacts yet';
  static const nothingReadSentence = 'myData has not read any contacts yet. They appear here when it has.';
  static const openMyDataLabel = 'Open myData';
  static const openFailedText =
      'myContacts could not open myData. Open the myData app yourself, under '
      'Settings, Sources.';

  @override
  State<ContactsHome> createState() => _ContactsHomeState();
}

class _ContactsHomeState extends State<ContactsHome> {
  late final ContactsController _contacts = ContactsController(
    backend: widget.backend ?? HostContactsBackend(() => widget.host.connection),
    store: widget.store,
  );
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
    _host.dispose();
    super.dispose();
  }

  Future<void> _openSources() async {
    final open = widget.openMyDataSources ?? openMyDataSources;
    final opened = await open().catchError((Object _) => false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text(ContactsHome.openFailedText)));
  }

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
    listenable: Listenable.merge([_host, _contacts]),
    builder: (context, _) => Scaffold(
      backgroundColor: context.colors.bg,
      body: switch (_connection()) {
        // No host to connect to (the web build): the panel alone, without a frame whose connection line
        // would offer a Retry that cannot help.
        null => _body(),
        final connection => AppFrame(
          appName: ContactsHome.appName,
          sections: ContactsHome.sections,
          current: 0,
          onSelect: (_) {},
          connection: connection,
          child: _body(),
        ),
      },
    ),
  );

  /// How the frame shows the host; null when this build cannot have one ([HostPhase.unsupported]).
  AppConnection? _connection() => switch (_host.phase) {
    HostPhase.checking || HostPhase.starting => const AppConnection.starting(),
    HostPhase.running => AppConnection.connected(onOpenMyData: _openMyData),
    HostPhase.notConfigured || HostPhase.failedToStart || HostPhase.lost => AppConnection.unreachable(
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
      return ContactsView(controller: _contacts, onOpenLink: widget.onOpenLink ?? openInBrowser);
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
      HostPhase.notConfigured => _failure('The myData host is not set up'),
      HostPhase.failedToStart => _failure('The myData host did not start'),
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
    if (contacts.loadFailed) {
      return StatusPanel(
        kind: StatusPanelKind.error,
        title: 'myContacts could not read your contacts',
        message: 'The host did not answer. Try again in a moment.',
        actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: contacts.reload)],
      );
    }
    if (contacts.anySourceOn == null || (contacts.anySourceOn! && contacts.contacts == null)) {
      return const StatusPanel(
        kind: StatusPanelKind.working,
        title: 'Reading your contacts',
        message: 'Getting them from the host.',
      );
    }
    if (!contacts.anySourceOn!) {
      return EmptyState(
        title: ContactsHome.noSourceTitle,
        sentence: ContactsHome.noSourceSentence,
        actionLabel: ContactsHome.openMyDataLabel,
        onAction: _openSources,
      );
    }
    if (contacts.entries.isEmpty) {
      return EmptyState(
        title: ContactsHome.nothingReadTitle,
        sentence: ContactsHome.nothingReadSentence,
        actionLabel: ContactsHome.openMyDataLabel,
        onAction: _openSources,
      );
    }
    return ContactsView(controller: contacts, onOpenLink: widget.onOpenLink ?? openInBrowser);
  }

  Widget _failure(String title) => StatusPanel(
    kind: StatusPanelKind.error,
    title: title,
    message: _host.error ?? 'Something went wrong while connecting.',
    detail: _host.detail,
    actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _host.retry)],
  );
}
