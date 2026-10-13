import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'approval_card.dart';
import 'chat_controller.dart';
import 'result_view.dart';

/// The conversation and the message input. Enter sends; Shift+Enter starts a new line.
///
/// - The conversation is a reading column at most `content-max` wide, on the ground (`bg`), padded like a
///   page ([PageScaffold.paddingFor]). The user's messages are right-aligned on `accent-soft` with `ink`
///   text and `radius-lg`; the assistant's sentences are plain `body` text, with no bubble. Progress lines
///   are `caption` / `ink-muted` with a small turning kiwi while the tool runs (still with reduced motion)
///   and a check once it is done. Results and approval cards are the only raised surfaces.
/// - The input is a glass pill floating at the bottom ([FloatingBarSurface]; solid with reduced
///   transparency), holding a borderless field and a send button named "Send". The conversation scrolls
///   beneath it. Both are disabled while a reply is coming in; the field gets focus back afterwards.
/// - Everything in the conversation can be selected and copied.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.controller});

  final ChatController controller;

  static const inputKey = ValueKey('chat-input');
  static const sendKey = ValueKey('chat-send');

  static const placeholder = 'Ask about your data';
  static const sendLabel = 'Send';
  static const emptyText = 'Ask about your calendar, mail, contacts or photos.';
  static const errorTitle = 'That message did not get an answer';
  static const retryLabel = 'Retry';
  static const workingLabel = 'Working on your message';

  /// Between items in the conversation; consecutive progress lines sit closer ([progressGap]).
  static const itemGap = MyDataSpace.s4;
  static const progressGap = MyDataSpace.s2;

  /// Above the first item. Small, because the conversation scrolls up under whatever sits above it (the
  /// page's title); the page adds the rest of its title gap outside the scrolling area.
  static const topPadding = MyDataSpace.s2;

  /// The widest a message of the user's gets, as a share of the column.
  static const bubbleMaxShare = 3 / 4;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final _focus = FocusNode(onKeyEvent: _onKey)..addListener(_focusChanged);
  late bool _wasBusy = widget.controller.busy;

  /// Whether the composer shows the focus ring: the field was reached with the keyboard (Tab), as for any
  /// keyboard focus. Focus the app gives it (at launch, and back after a reply) or a click shows only the
  /// caret, so the warm ring does not sit around the input all the time.
  bool _ring = false;

  /// The next focus gain is the app's own (the field's autofocus at first).
  bool _focusByApp = true;

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

  void _focusChanged() {
    final ring = _focus.hasFocus &&
        !_focusByApp &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (_focus.hasFocus) _focusByApp = false;
    if (ring != _ring) setState(() => _ring = ring);
  }

  void _changed() {
    // The input is disabled while busy, which drops its focus; give it back once the reply is in.
    final refocus = _wasBusy && !_chat.busy;
    _wasBusy = _chat.busy;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      if (refocus && !_focus.hasFocus) {
        _focusByApp = true;
        _focus.requestFocus();
      }
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

  /// Whether to show the bare working kiwi: a reply is under way and nothing of it is on screen yet.
  bool get _waiting {
    if (!_chat.busy) return false;
    final last = _chat.items.lastOrNull;
    return switch (last) {
      ProgressLine(:final done) => done,
      AssistantReply(:final streaming, :final text) => !streaming || text.isEmpty,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = _chat.items;
    final pad = PageScaffold.paddingFor(AppLayout.of(context));
    return FloatingBarHost(
      bar: _ComposerBar(
        pad: pad,
        child: _Composer(
          input: _input,
          focus: _focus,
          ring: _ring,
          busy: _chat.busy,
          onSend: _send,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final insets = MediaQuery.paddingOf(context);
          // The column starts at the page padding and stops at content-max, like every page.
          final right = (constraints.maxWidth - pad - MyDataSize.contentMax).clamp(pad, double.infinity);
          final padding = EdgeInsets.fromLTRB(
            pad + insets.left,
            ChatView.topPadding + insets.top,
            right + insets.right,
            insets.bottom,
          );
          if (items.isEmpty) return Padding(padding: padding, child: const _EmptyChat());
          final waiting = _waiting;
          final count = items.length + (waiting ? 1 : 0);
          return SelectionArea(
            child: ListView.builder(
              controller: _scroll,
              padding: padding,
              itemCount: count,
              itemBuilder: (_, i) {
                final item = i < items.length ? items[i] : null;
                final previous = i == 0 ? null : items[i - 1];
                final double gap = i == 0
                    ? 0
                    : (item is ProgressLine && previous is ProgressLine ? ChatView.progressGap : ChatView.itemGap);
                return Padding(
                  padding: EdgeInsets.only(top: gap),
                  child: item == null ? const _Working() : _ItemView(item: item, chat: _chat),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Lines the floating input up with the conversation column.
class _ComposerBar extends StatelessWidget {
  const _ComposerBar({required this.pad, required this.child});
  final double pad;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    // The host already insets the bar by space-4; add the rest of the page padding.
    padding: EdgeInsets.symmetric(horizontal: (pad - FloatingBarHost.inset).clamp(0, double.infinity)),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
        child: child,
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: KiwiTile(size: EmptyState.tileSize)),
          const SizedBox(height: EmptyState.wideGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
            child: Text(
              ChatView.emptyText,
              textAlign: TextAlign.center,
              style: MyDataType.body.copyWith(color: context.colors.inkMuted),
            ),
          ),
        ],
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
    UserMessage(:final text) => _UserMessage(text),
    final AssistantReply reply => _AssistantText(
      reply.text.isEmpty && !reply.streaming ? 'No answer.' : reply.text,
    ),
    final ProgressLine line => _ProgressRow(line),
    final ResultItem r => ResultCard(kind: r.kind, header: r.header, items: r.items),
    final ApprovalItem a => AssistantApprovalCard(
      approval: a.approval,
      deciding: a.deciding,
      error: a.error,
      onApprove: () => chat.decide(a.approval.id, true),
      onReject: () => chat.decide(a.approval.id, false),
    ),
    final ChatError e => _ErrorRow(error: e, onRetry: chat.busy ? null : () => chat.retry(e)),
  };
}

/// The user's message: right-aligned on `accent-soft`, `ink` text, `radius-lg`.
class _UserMessage extends StatelessWidget {
  const _UserMessage(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * ChatView.bubbleMaxShare),
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: MyDataRadii.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4, vertical: MyDataSpace.s3),
              child: Text(text, style: MyDataType.body.copyWith(color: c.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The assistant's sentence: plain body text on the ground.
class _AssistantText extends StatelessWidget {
  const _AssistantText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(text, style: MyDataType.body.copyWith(color: context.colors.ink)),
  );
}

/// "Checking calendar…" with a small turning kiwi, then the label with a check once the run moves on.
class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.line);
  final ProgressLine line;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = line.done ? line.label : '${line.label}…';
    return Row(
      children: [
        SizedBox.square(
          dimension: MyDataSize.icon,
          child: line.done
              ? Icon(Icons.check_rounded, size: MyDataSize.icon, color: c.inkMuted)
              : const ExcludeSemantics(child: KiwiLoader(size: MyDataSize.icon)),
        ),
        const SizedBox(width: MyDataSpace.s2),
        Flexible(child: Text(label, style: MyDataType.caption.copyWith(color: c.inkMuted))),
      ],
    );
  }
}

/// A reply is on its way and nothing has arrived yet.
class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: AlignmentDirectional.centerStart,
    child: KiwiLoader(size: MyDataSize.icon, semanticLabel: ChatView.workingLabel),
  );
}

/// A message that got no answer: what went wrong, in the host's words, and Retry.
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.error, required this.onRetry});
  final ChatError error;
  final VoidCallback? onRetry;

  static final _lineHeight = MyDataType.bodyStrong.fontSize! * MyDataType.bodyStrong.height!;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centres the icon on the title's first line.
          padding: EdgeInsets.only(top: (_lineHeight - MyDataSize.icon) / 2),
          child: Icon(Icons.error_outline_rounded, size: MyDataSize.icon, color: c.danger),
        ),
        const SizedBox(width: MyDataSpace.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ChatView.errorTitle, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
              Text(error.message, style: MyDataType.body.copyWith(color: c.inkMuted)),
              const SizedBox(height: MyDataSpace.s3),
              Button(label: ChatView.retryLabel, onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

/// The input bar: a borderless field and the send button on the floating glass pill. The pill draws the
/// focus ring when the field was reached with the keyboard.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.focus,
    required this.ring,
    required this.busy,
    required this.onSend,
  });
  final TextEditingController input;
  final FocusNode focus;
  final bool ring;
  final bool busy;
  final VoidCallback onSend;

  /// Centres one line of `body` in a `control-height` field.
  static final fieldInset = (MyDataSize.controlHeight - MyDataType.body.fontSize! * MyDataType.body.height!) / 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusRing(
      visible: ring,
      borderRadius: MyDataRadii.xl,
      child: FloatingBarSurface(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MyDataSpace.s4,
          FloatingBar.padding,
          FloatingBar.padding,
          FloatingBar.padding,
        ),
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
                style: MyDataType.body.copyWith(color: c.ink),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: fieldInset),
                  hintText: ChatView.placeholder,
                  hintStyle: MyDataType.body.copyWith(color: c.inkMuted),
                ),
              ),
            ),
            const SizedBox(width: MyDataSpace.s2),
            Pressable(
              key: ChatView.sendKey,
              onPressed: busy ? null : onSend,
              borderRadius: MyDataRadii.pill,
              semanticLabel: ChatView.sendLabel,
              tooltip: ChatView.sendLabel,
              child: Container(
                width: MyDataSize.controlHeight,
                height: MyDataSize.controlHeight,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.arrow_upward_rounded, size: MyDataSize.icon, color: c.onAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
