import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'approval_card.dart';
import 'chat_controller.dart';
import 'mac_chat.dart';
import 'result_view.dart';

/// The conversation and the message input. Enter sends; Shift+Enter starts a new line.
///
/// - The conversation is a reading column at most `content-max` wide, on the ground (`bg`), padded like a
///   page ([PageScaffold.paddingFor]). The user's messages are right-aligned on `accent-soft` with `ink`
///   text and `radius-lg`; the assistant's sentences are plain `body` text, with no bubble. Progress lines
///   are `caption` / `ink-muted` with a small turning kiwi while the tool runs (still with reduced motion)
///   and a check once it is done. Results and approval cards are the only raised surfaces. When the host
///   switches between demo and real mode, one centred `caption` / `ink-muted` line says that a new
///   conversation has started ([ConversationNotice]).
/// - The input is a glass pill floating at the bottom ([FloatingBarSurface]; solid with reduced
///   transparency), holding a borderless field and a send button named "Send". The conversation scrolls
///   beneath it. Both are disabled while a reply is coming in; the field gets focus back afterwards.
/// - Everything in the conversation can be selected and copied.
/// - **The Mac frame** ([MacSystemLook.isSystemLook]): the conversation is a column centred in the content (the branded
///   column's measure at 13 pt), the user's messages in a neutral bubble, the assistant's in plain `body`,
///   progress in `callout` / `secondary-label`. The composer sits at the bottom under the conversation, as in
///   Messages: a rounded field with the round accent Send button inside it, and the system's focus ring. The
///   keys and behaviour are the same.
class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.controller, this.links, this.realMode});

  final ChatController controller;

  /// Whether the host serves the user's own data (real mode) or sample data; the Mac frame's empty state
  /// names what can be asked about from it ([emptyLineFor]). Null: not known.
  final bool? realMode;

  /// Opens real contact and event results in myContacts and myCalendar when installed ([ResultCard]); null
  /// opens nothing.
  final ResultLinks? links;

  static const inputKey = ValueKey('chat-input');
  static const sendKey = ValueKey('chat-send');

  static const placeholder = 'Ask about your data';
  static const sendLabel = 'Send';
  static const emptyText = 'Ask about your calendar, mail, contacts or photos.';

  /// The Mac frame's empty state.
  static const emptyTitle = 'Ask myAssistant';

  /// The one line under [emptyTitle], from the tools the host offers: in real mode only contacts and
  /// calendars (CLAUDE.md, "Demo and real mode"); with sample data the six sample tools.
  static String emptyLineFor(bool? realMode) => switch (realMode) {
        true => 'Ask about your contacts and calendars.',
        false => 'Ask about the sample calendar, mail, contacts or photos.',
        null => 'Ask about your data.',
      };

  /// Why Send does nothing yet.
  static const sendEmptyReason = 'Type a message first.';
  static const sendBusyReason = 'Wait for the answer to this message.';
  static const errorTitle = 'That message did not get an answer';
  static const retryLabel = 'Retry';
  static const workingLabel = 'Working on your message';

  /// Between items in the conversation; consecutive progress lines sit closer ([progressGap]).
  static double itemGap(MyDataLook look) => look.space(4);
  static double progressGap(MyDataLook look) => look.space(2);

  /// Above the first item. Small, because the conversation scrolls up under whatever sits above it (the
  /// page's title); the page adds the rest of its title gap outside the scrolling area.
  static double topPadding(MyDataLook look) => look.space(2);

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

  /// The list's items: each in [view], with the gap above it ([itemGap], or [progressGap] between progress
  /// lines), and [working] last while a reply is on its way and nothing of it shows yet.
  Widget _list(EdgeInsets padding, {required double itemGap, required double progressGap,
      required Widget Function(ChatItem item) view, required Widget working}) {
    final items = _chat.items;
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
          final double gap = i == 0 ? 0 : (item is ProgressLine && previous is ProgressLine ? progressGap : itemGap);
          return Padding(padding: EdgeInsets.only(top: gap), child: item == null ? working : view(item));
        },
      ),
    );
  }

  /// The Mac frame's chat: the conversation centred in a column, the composer under it.
  Widget _mac(BuildContext context) {
    final composer = MacComposer(
      input: _input,
      focus: _focus,
      ring: _ring,
      busy: _chat.busy,
      onSend: _send,
      inputKey: ChatView.inputKey,
      sendKey: ChatView.sendKey,
      placeholder: ChatView.placeholder,
      sendLabel: ChatView.sendLabel,
      emptyReason: ChatView.sendEmptyReason,
      busyReason: ChatView.sendBusyReason,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The column is centred; narrower windows keep side-padding on each side.
        final side = ((constraints.maxWidth - MacChat.columnMax(context.look)) / 2).clamp(MacChat.sidePadding(context.look), double.infinity);
        final Widget conversation = _chat.items.isEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: side),
                child: MacEmptyState(title: ChatView.emptyTitle, line: ChatView.emptyLineFor(widget.realMode)),
              )
            : _list(
                EdgeInsets.fromLTRB(side, context.space(4), side, context.space(4)),
                itemGap: MacChat.itemGap(context.look),
                progressGap: MacChat.progressGap(context.look),
                working: const MacWorking(label: ChatView.workingLabel),
                view: (item) => _MacItemView(item: item, chat: _chat, links: widget.links),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: conversation),
            Padding(
              padding: EdgeInsets.fromLTRB(side, context.space(2), side, context.space(4)),
              child: composer,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.isSystemLook) return _mac(context);
    final items = _chat.items;
    final pad = PageScaffold.paddingFor(context.look, AppLayout.of(context));
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
            ChatView.topPadding(context.look) + insets.top,
            right + insets.right,
            insets.bottom,
          );
          if (items.isEmpty) return Padding(padding: padding, child: const _EmptyChat());
          return _list(
            padding,
            itemGap: ChatView.itemGap(context.look),
            progressGap: ChatView.progressGap(context.look),
            working: const _Working(),
            view: (item) => _ItemView(item: item, chat: _chat, links: widget.links),
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
    padding: EdgeInsets.symmetric(horizontal: (pad - FloatingBarHost.inset(context.look)).clamp(0, double.infinity)),
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
          SizedBox(height: EmptyState.wideGap(context.look)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: EmptyState.maxWidth),
            child: Text(
              ChatView.emptyText,
              textAlign: TextAlign.center,
              style: context.typeScale.body.copyWith(color: context.colors.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, required this.chat, this.links});
  final ChatItem item;
  final ChatController chat;
  final ResultLinks? links;

  @override
  Widget build(BuildContext context) => switch (item) {
    UserMessage(:final text) => _UserMessage(text),
    final AssistantReply reply => _AssistantText(
      reply.text.isEmpty && !reply.streaming ? 'No answer.' : reply.text,
    ),
    final ProgressLine line => _ProgressRow(line),
    final ResultItem r => ResultCard(
      kind: r.kind,
      header: r.header,
      items: r.items,
      realMode: r.realMode,
      links: links,
    ),
    final ApprovalItem a => AssistantApprovalCard(
      approval: a.approval,
      deciding: a.deciding,
      error: a.error,
      onApprove: () => chat.decide(a.approval.id, true),
      onReject: () => chat.decide(a.approval.id, false),
    ),
    final ChatError e => _ErrorRow(error: e, onRetry: chat.busy ? null : () => chat.retry(e)),
    final ConversationNotice n => _NoticeRow(n.text),
  };
}

/// One item of the conversation in the Mac frame.
class _MacItemView extends StatelessWidget {
  const _MacItemView({required this.item, required this.chat, this.links});
  final ChatItem item;
  final ChatController chat;
  final ResultLinks? links;

  @override
  Widget build(BuildContext context) => switch (item) {
    UserMessage(:final text) => MacUserMessage(text, maxShare: ChatView.bubbleMaxShare),
    final AssistantReply reply => MacAssistantText(reply.text.isEmpty && !reply.streaming ? 'No answer.' : reply.text),
    final ProgressLine line => MacProgressRow(line),
    // ResultCard and the approval card draw their Mac look themselves.
    ResultItem() || ApprovalItem() => _ItemView(item: item, chat: chat, links: links),
    final ChatError e => MacErrorRow(
      title: ChatView.errorTitle,
      message: e.message,
      retryLabel: ChatView.retryLabel,
      onRetry: chat.busy ? null : () => chat.retry(e),
    ),
    final ConversationNotice n => MacNoticeRow(n.text),
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
            decoration: context.radius.decorate(BoxDecoration(color: c.accentSoft, borderRadius: MyDataRadii.lg(context.look))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
              child: Text(text, style: context.typeScale.body.copyWith(color: c.ink)),
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
    child: Text(text, style: context.typeScale.body.copyWith(color: context.colors.ink)),
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
          dimension: context.density.icon,
          child: line.done
              ? Icon(context.icon(MyDataIcon.check), size: context.density.icon, color: c.inkMuted)
              : ExcludeSemantics(child: KiwiLoader(size: context.density.icon)),
        ),
        SizedBox(width: context.space(2)),
        Flexible(child: Text(label, style: context.typeScale.caption.copyWith(color: c.inkMuted))),
      ],
    );
  }
}

/// A line from the app rather than either side of the conversation: centred, `caption` / `ink-muted`.
/// Screen readers hear it when it appears.
class _NoticeRow extends StatelessWidget {
  const _NoticeRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.typeScale.caption.copyWith(color: context.colors.inkMuted),
      ),
    ),
  );
}

/// A reply is on its way and nothing has arrived yet.
class _Working extends StatelessWidget {
  const _Working();

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: KiwiLoader(size: context.density.icon, semanticLabel: ChatView.workingLabel),
  );
}

/// A message that got no answer: what went wrong, in the host's words, and Retry.
class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.error, required this.onRetry});
  final ChatError error;
  final VoidCallback? onRetry;

  static double _lineHeight(MyDataLook look) => look.typeScale.bodyStrong.fontSize! * look.typeScale.bodyStrong.height!;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centres the icon on the title's first line.
          padding: EdgeInsets.only(top: (_lineHeight(context.look) - context.density.icon) / 2),
          child: Icon(context.icon(MyDataIcon.error), size: context.density.icon, color: c.danger),
        ),
        SizedBox(width: context.space(2)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ChatView.errorTitle, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
              Text(error.message, style: context.typeScale.body.copyWith(color: c.inkMuted)),
              SizedBox(height: context.space(3)),
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
  static double fieldInset(MyDataLook look) => (look.density.controlHeight - look.typeScale.body.fontSize! * look.typeScale.body.height!) / 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusRing(
      visible: ring,
      borderRadius: MyDataRadii.xl(context.look),
      child: FloatingBarSurface(
        padding: EdgeInsetsDirectional.fromSTEB(
          context.space(4),
          FloatingBar.padding(context.look),
          FloatingBar.padding(context.look),
          FloatingBar.padding(context.look),
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
                style: context.typeScale.body.copyWith(color: c.ink),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: fieldInset(context.look)),
                  hintText: ChatView.placeholder,
                  hintStyle: context.typeScale.body.copyWith(color: c.inkMuted),
                ),
              ),
            ),
            SizedBox(width: context.space(2)),
            Pressable(
              key: ChatView.sendKey,
              onPressed: busy ? null : onSend,
              borderRadius: MyDataRadii.pill(context.look),
              semanticLabel: ChatView.sendLabel,
              tooltip: ChatView.sendLabel,
              child: Container(
                width: context.density.controlHeight,
                height: context.density.controlHeight,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(context.icon(MyDataIcon.send), size: context.density.icon, color: c.onAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
