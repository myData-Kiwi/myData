import 'package:flutter/material.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The one screen: a panel for every state of the host and the assistant, and the chat once both are
/// ready. The conversation lives here, so it survives the host going away and coming back.
class AssistantHome extends StatefulWidget {
  const AssistantHome({super.key, required this.host});
  final HostController host;

  @override
  State<AssistantHome> createState() => _AssistantHomeState();
}

class _AssistantHomeState extends State<AssistantHome> {
  late final _backend = HostAssistantBackend(() => widget.host.connection);
  late final _chat = ChatController(_backend);

  /// Set when the myData app could not be opened from here.
  String? _setupNotice;

  HostController get _host => widget.host;

  @override
  void initState() {
    super.initState();
    _host.connect();
  }

  @override
  void dispose() {
    _chat.dispose();
    _backend.close();
    _host.dispose();
    super.dispose();
  }

  Future<void> _openSetup() async {
    // A launcher that throws (e.g. `open` could not be run) gets the same notice as one that says no.
    final opened = await _host.platform.openMyDataApp(setup: true).catchError((Object _) => false);
    if (!mounted) return;
    setState(
      () => _setupNotice = opened
          ? null
          : 'myAssistant could not open it from here. Open the myData app yourself and go to Setup.',
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _host,
    builder: (context, _) {
      final status = _host.status;
      final running = _host.phase == HostPhase.running;
      return Scaffold(
        appBar: AppHeader(
          title: 'myAssistant',
          actions: [
            if (running && status != null && status.demoDate) const StatusPill(label: 'demo data', tone: PillTone.warn),
          ],
        ),
        body: _body(status),
      );
    },
  );

  Widget _body(StatusOut? status) => switch (_host.phase) {
    HostPhase.checking => const MessagePanel(
      kind: PanelKind.working,
      title: 'Looking for the myData host',
      message: 'Connecting to the host on this computer.',
    ),
    HostPhase.starting => const MessagePanel(
      kind: PanelKind.working,
      title: 'Starting the myData host',
      message: 'This can take a few seconds.',
    ),
    HostPhase.notConfigured => _failure('The myData host is not set up'),
    HostPhase.failedToStart => _failure('The myData host did not start'),
    HostPhase.lost => _failure(
      'The myData host stopped',
      extra: _chat.items.isEmpty ? null : 'Your conversation is kept; it continues once the host is back.',
    ),
    HostPhase.unsupported => MessagePanel(
      kind: PanelKind.info,
      title: 'myAssistant needs the desktop app',
      message: _host.error ?? 'Open myAssistant on the computer that runs the myData host.',
    ),
    HostPhase.running when status == null => const MessagePanel(
      kind: PanelKind.working,
      title: 'Looking for the myData host',
      message: 'Waiting for its status.',
    ),
    HostPhase.running =>
      assistantAvailability(status!) == AssistantAvailability.ready
          ? ChatView(controller: _chat)
          : AssistantUnavailable(
              status: status,
              notice: _setupNotice,
              onOpenSetup: _openSetup,
              onCheckAgain: _host.refresh,
            ),
  };

  Widget _failure(String title, {String? extra}) {
    final message = _host.error ?? 'Something went wrong while connecting.';
    return MessagePanel(
      kind: PanelKind.error,
      title: title,
      message: extra == null ? message : '$message $extra',
      detail: _host.detail,
      primaryLabel: 'Retry',
      onPrimary: _host.retry,
    );
  }
}
