import 'package:flutter/material.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The one screen, in the app's frame: a panel for every state of the host and the assistant, and the chat
/// once both are ready. The conversation lives here, so it survives the host going away and coming back.
///
/// The frame's one section is Chat. At the bottom of the sidebar it says how the host is: starting,
/// connected (with a link that opens myData), or unreachable (with Retry). The web build, which cannot reach
/// a host, shows only its panel, without the frame.
class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key, required this.host, this.backend});
  final HostController host;

  /// The chat's way to the host; null uses the host's API through [host]'s connection.
  final AssistantBackend? backend;

  static const appName = 'myAssistant';
  static const sections = [AppSection(icon: Icons.chat_bubble_outline_rounded, label: 'Chat')];
  static const chatTitle = 'Chat';
  static const demoLabel = 'Demo data';

  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> {
  HostAssistantBackend? _hostBackend;
  late final AssistantBackend _backend =
      widget.backend ?? (_hostBackend = HostAssistantBackend(() => widget.host.connection));
  late final _chat = ChatController(_backend);

  /// Set when the myData app could not be opened from here; the notice names the place to go for the
  /// screen it is shown on ([AssistantUnavailable.openFailedNotice]).
  bool _openFailed = false;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.connect();
  }

  @override
  void dispose() {
    _chat.dispose();
    _hostBackend?.close();
    _host.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _host,
    builder: (context, _) => Scaffold(
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
    HostPhase.checking || HostPhase.starting => const AppConnection.starting(),
    HostPhase.running => AppConnection.connected(onOpenMyData: _openMyData),
    HostPhase.notConfigured ||
    HostPhase.failedToStart ||
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
    HostPhase.notConfigured => _failure('The myData host is not set up'),
    HostPhase.failedToStart => _failure('The myData host did not start'),
    HostPhase.lost => _failure(
      'The myData host stopped',
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
          ? _ChatPage(chat: _chat, demoDate: status.demoDate)
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
  const _ChatPage({required this.chat, required this.demoDate});
  final ChatController chat;
  final bool demoDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pad = PageScaffold.paddingFor(AppLayout.of(context));
    final insets = MediaQuery.paddingOf(context);
    // Under a phone frame the app name is already the large title; the section's name is smaller.
    final style = AppFrame.phoneAppNameOf(context) == null ? MyDataType.displayLg : MyDataType.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pad + insets.left,
            pad + insets.top,
            pad + insets.right,
            PageScaffold.titleGap - ChatView.topPadding,
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
                    const SizedBox(width: MyDataSpace.s3),
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
            child: ChatView(controller: chat),
          ),
        ),
      ],
    );
  }
}
