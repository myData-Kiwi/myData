import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The one screen, in the app's frame: a panel for every state of the host and the assistant, and the chat
/// once both are ready. The conversation lives here, so it survives the host going away and coming back. It
/// ends when the host switches between demo and real mode, and the chat says so.
///
/// The frame's one section is Chat. At the bottom of the sidebar it says how the host is: starting,
/// connected (with a link that opens myData), or unreachable (with Retry). The web build, which cannot reach
/// a host, shows only its panel, without the frame.
///
/// **On a Mac** ([MacWindow.of]) it draws the Mac frame with no sidebar: the host keeps one conversation per app
/// session and no history, so a sidebar would hold one row repeating the title. The toolbar band names the
/// conversation by its first message ([conversationTitle]) at its leading edge, after the window's buttons,
/// and says "Demo data" under it while the host serves sample data; then the chat, or the state's panel
/// (which says what is wrong once). A sidebar with a New Conversation button comes with conversation
/// history. The web build has no frame.
///
/// In real mode, a contact or event in a result opens in myContacts or myCalendar when that app is installed
/// on this Mac; whether it is, is looked up once and again whenever myAssistant comes back to the front.
class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key, required this.host, this.backend, this.apps, this.openLink});
  final HostController host;

  /// The chat's way to the host; null uses the host's API through [host]'s connection.
  final AssistantBackend? backend;

  /// Whether myContacts and myCalendar are installed; null looks them up ([InstalledApps]).
  final InstalledApps? apps;

  /// Opens a link in its app; null uses [appLinks].
  final Future<bool> Function(MyDataLink link)? openLink;

  /// The apps a result can open its items in.
  static const linkedApps = [MyDataAppId.mycontacts, MyDataAppId.mycalendar];

  /// When opening an item in its app failed.
  static String openFailed(MyDataAppId app) => 'myAssistant could not open ${app.displayName}. Open it yourself.';

  static const appName = 'myAssistant';
  static const sections = [AppSection(icon: MyDataIcon.chat, label: 'Chat')];
  static const chatTitle = 'Chat';
  static const demoLabel = 'Demo data';

  /// The Mac frame's name for a conversation with no message yet.
  static const newConversation = 'New conversation';

  /// The Mac frame's name for the conversation: the first message the user sent in it, on one line, or
  /// [newConversation]. A switch between demo and real mode starts a new conversation
  /// ([ConversationNotice]), so only the messages after the last notice count.
  static String conversationTitle(List<ChatItem> items) {
    final start = items.lastIndexWhere((i) => i is ConversationNotice) + 1;
    for (final item in items.skip(start)) {
      if (item is UserMessage) {
        final line = item.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (line.isNotEmpty) return line;
      }
    }
    return newConversation;
  }

  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> {
  HostAssistantBackend? _hostBackend;
  late final AssistantBackend _backend =
      widget.backend ?? (_hostBackend = HostAssistantBackend(() => widget.host.connection));
  late final _chat = ChatController(_backend);
  late final InstalledApps _apps = widget.apps ?? InstalledApps(apps: AssistantHome.linkedApps);

  /// Set when the myData app could not be opened from here; the notice names the place to go for the
  /// screen it is shown on ([AssistantUnavailable.openFailedNotice]).
  bool _openFailed = false;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.addListener(_followHost);
    _host.connect();
    unawaited(_apps.start());
  }

  /// Every status poll goes to the chat: a switch between demo and real mode ends the conversation there.
  void _followHost() {
    final status = _host.status;
    if (status != null) _chat.followHost(status);
  }

  @override
  void dispose() {
    _host.removeListener(_followHost);
    _chat.dispose();
    if (widget.apps == null) _apps.dispose();
    _hostBackend?.close();
    _host.dispose();
    super.dispose();
  }

  /// Opens a result's item in its app. If that fails (the app was removed meanwhile), says so and looks again,
  /// so its rows stop offering it.
  Future<void> _openItem(MyDataLink link) async {
    final open = widget.openLink ?? appLinks.openLink;
    final opened = await open(link).catchError((Object _) => false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(AssistantHome.openFailed(link.app))));
    unawaited(_apps.refresh());
  }

  /// Whether the myData app came up. A launcher that throws (e.g. `open` could not be run) counts as no.
  Future<bool> _launchMyData({required bool setup}) =>
      _host.platform.openMyDataApp(setup: setup).catchError((Object _) => false);

  Future<void> _openSetup() async {
    final opened = await _launchMyData(setup: true);
    if (!mounted) return;
    setState(() => _openFailed = !opened);
  }

  /// The frame's "Open myData" link.
  Future<void> _openMyData() async {
    final opened = await _launchMyData(setup: false);
    if (!mounted || opened) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('myAssistant could not open myData from here. Open the myData app yourself.')),
    );
  }

  /// The Mac frame: the toolbar band over the chat or the state's panel, the whole window wide (no
  /// sidebar). The band names the conversation only while the chat is shown.
  Widget _macFrame() {
    final status = _host.status;
    final chatShown = _host.phase == HostPhase.running &&
        status != null &&
        assistantAvailability(status) == AssistantAvailability.ready;
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) => MacContentGround(
        child: MacPane(
          toolbar: MacToolbar(
            windowControls: true,
            title: chatShown ? AssistantHome.conversationTitle(_chat.items) : null,
            subtitle: chatShown && status.demoDate ? AssistantHome.demoLabel : null,
          ),
          child: _body(status),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _host,
    builder: (context, _) => MacWindow.of(context)
        // Transparent: the window's sidebar material shows through the sidebar.
        ? Scaffold(backgroundColor: Colors.transparent, body: _macFrame())
        : Scaffold(
      backgroundColor: context.colors.bg,
      body: switch (_connection()) {
        // No host to connect to (the web build): the panel alone, without a frame whose connection line
        // would offer a Retry that cannot help.
        null => _body(_host.status),
        final connection => AppFrame(
          appName: AssistantHome.appName,
          sections: AssistantHome.sections,
          current: 0,
          onSelect: (_) {},
          connection: connection,
          child: _body(_host.status),
        ),
      },
    ),
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
    HostPhase.lost => AppConnection.unreachable(onRetry: _host.retry),
    HostPhase.unsupported => null,
  };

  Widget _body(StatusOut? status) => switch (_host.phase) {
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
    HostPhase.lost => _failure(
      AppConnection.lostText,
      extra: _chat.items.isEmpty ? null : 'Your conversation is kept; it continues once the host is back.',
    ),
    HostPhase.unsupported => StatusPanel(
      kind: StatusPanelKind.info,
      title: 'myAssistant needs the desktop app',
      message: _host.error ?? 'Open myAssistant on the computer that runs the myData host.',
    ),
    HostPhase.running when status == null => const StatusPanel(
      kind: StatusPanelKind.working,
      title: 'Looking for the myData host',
      message: 'Waiting for its status.',
    ),
    HostPhase.running =>
      assistantAvailability(status!) == AssistantAvailability.ready
          ? (MacWindow.of(context)
                ? _MacChatPage(chat: _chat, apps: _apps, onOpen: _openItem, realMode: !status.demoDate)
                : _ChatPage(chat: _chat, demoDate: status.demoDate, apps: _apps, onOpen: _openItem))
          : AssistantUnavailable(
              status: status,
              notice: _openFailed ? AssistantUnavailable.openFailedNotice(status) : null,
              onOpenSetup: _openSetup,
              onCheckAgain: _host.refresh,
            ),
  };

  Widget _failure(String title, {String? extra}) {
    final message = _host.error ?? 'Something went wrong while connecting.';
    return StatusPanel(
      kind: StatusPanelKind.error,
      title: title,
      message: extra == null ? message : '$message $extra',
      detail: _host.detail,
      actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: _host.retry)],
    );
  }
}

/// The chat under its title, with a "Demo data" chip while the host's tools serve sample data.
class _ChatPage extends StatelessWidget {
  const _ChatPage({required this.chat, required this.demoDate, required this.apps, required this.onOpen});
  final ChatController chat;
  final bool demoDate;
  final InstalledApps apps;
  final ValueChanged<MyDataLink> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = PageScaffold.paddingFor(context.look, AppLayout.of(context));
    final insets = MediaQuery.paddingOf(context);
    // Under a phone frame the app name is already the large title; the section's name is smaller.
    final style = AppFrame.phoneAppNameOf(context) == null ? context.typeScale.displayLg : context.typeScale.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pad + insets.left,
            pad + insets.top,
            pad + insets.right,
            PageScaffold.titleGap(context.look) - ChatView.topPadding(context.look),
          ),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(AssistantHome.chatTitle, style: style.copyWith(color: c.ink)),
                    ),
                  ),
                  if (demoDate) ...[
                    SizedBox(width: context.space(3)),
                    const MyDataBadge(AssistantHome.demoLabel, tone: MyDataTone.warning),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListenableBuilder(
              listenable: apps,
              builder: (context, _) => ChatView(
                controller: chat,
                links: ResultLinks(installed: apps.installed, onOpen: onOpen),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The chat in the Mac frame, under the toolbar band (which names the conversation and says "Demo data").
class _MacChatPage extends StatelessWidget {
  const _MacChatPage({required this.chat, required this.apps, required this.onOpen, required this.realMode});
  final ChatController chat;
  final InstalledApps apps;
  final ValueChanged<MyDataLink> onOpen;
  final bool realMode;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: apps,
    builder: (context, _) => ChatView(
      controller: chat,
      links: ResultLinks(installed: apps.installed, onOpen: onOpen),
      realMode: realMode,
    ),
  );
}
