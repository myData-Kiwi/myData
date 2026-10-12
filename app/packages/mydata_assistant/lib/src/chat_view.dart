import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'approval_card.dart';
import 'chat_controller.dart';
import 'result_view.dart';

/// The conversation and the message input. Enter sends; Shift+Enter starts a new line.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.controller});

  final ChatController controller;

  static const inputKey = ValueKey('chat-input');
  static const sendKey = ValueKey('chat-send');

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final _focus = FocusNode(onKeyEvent: _onKey);
  late bool _wasBusy = widget.controller.busy;

  ChatController get _chat => widget.controller;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_changed);
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _wasBusy = widget.controller.busy;
    }
  }

  @override
  void dispose() {
    _chat.removeListener(_changed);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    // The input is disabled while busy, which drops its focus; give it back once the reply is in.
    final refocus = _wasBusy && !_chat.busy;
    _wasBusy = _chat.busy;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      if (refocus) _focus.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _send() {
    final text = _input.text.trim();
    if (_chat.busy || text.isEmpty) return;
    _input.clear();
    _chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final items = _chat.items;
    return Column(
      children: [
        Expanded(
          child: items.isEmpty
              ? const _EmptyChat()
              : ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _ItemView(item: items[i], chat: _chat),
                    ),
                  ),
                ),
        ),
        if (_chat.busy) const LinearProgressIndicator(minHeight: 2),
        _Composer(input: _input, focus: _focus, busy: _chat.busy, onSend: _send),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        'Ask about your calendar, mail, contacts or photos.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: MyDataColors.muted),
      ),
    ),
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, required this.chat});
  final ChatItem item;
  final ChatController chat;

  @override
  Widget build(BuildContext context) => switch (item) {
    UserMessage(:final text) => _Bubble(text: text, mine: true),
    final AssistantReply reply => _Bubble(
      text: reply.text.isEmpty && !reply.streaming ? 'No answer.' : reply.text,
      mine: false,
    ),
    final ProgressLine line => _ProgressRow(line),
    final ResultItem r => ResultCard(kind: r.kind, header: r.header, items: r.items),
    final ApprovalItem a => ApprovalCard(
      approval: a.approval,
      deciding: a.deciding,
      error: a.error,
      onApprove: () => chat.decide(a.approval.id, true),
      onReject: () => chat.decide(a.approval.id, false),
    ),
    final ChatError e => MessagePanel(
      kind: PanelKind.error,
      title: 'That message did not get an answer',
      message: e.message,
      primaryLabel: 'Retry',
      onPrimary: chat.busy ? null : () => chat.retry(e),
    ),
  };
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? MyDataColors.band : MyDataColors.surface,
          border: mine ? null : Border.all(color: MyDataColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.line);
  final ProgressLine line;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: 16,
        child: line.done
            ? const Icon(Icons.check, size: 16, color: MyDataColors.kiwiDeep)
            : const CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          line.done ? line.label : '${line.label}…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MyDataColors.muted),
        ),
      ),
    ],
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.input, required this.focus, required this.busy, required this.onSend});
  final TextEditingController input;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: MyDataColors.line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: ChatView.inputKey,
                controller: input,
                focusNode: focus,
                enabled: !busy,
                autofocus: true,
                minLines: 1,
                maxLines: 6,
                decoration: const InputDecoration(hintText: 'Message myAssistant'),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(key: ChatView.sendKey, onPressed: busy ? null : onSend, child: const Text('Send')),
          ],
        ),
      ),
    ),
  );
}
