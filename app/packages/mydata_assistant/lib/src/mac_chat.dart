import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'chat_controller.dart';

// The chat in the Mac frame (MacLook; docs/2026-10-23-plan.md section 5, "native frame, quiet brand"). Not
// exported: ChatView, ResultCard and AssistantApprovalCard switch to these themselves when `context.isSystemLook` says
// so, and draw their branded look everywhere else.

/// The Mac chat's measures. The reading column keeps the branded column's measure (characters per line) at
/// the Mac's 13 pt body, about 760 pt; the conversation is centred in the window's content, as Messages and
/// other chat apps on the Mac draw it.
abstract final class MacChat {
  static double columnMax(MyDataLook look) => MyDataSize.contentMax * MyDataMacType.body.fontSize! / look.typeScale.body.fontSize!;

  /// Between the column and the content's edges when the window is narrow.
  static double sidePadding(MyDataLook look) => look.space(6);

  /// Between items in the conversation; consecutive progress lines sit closer.
  static double itemGap(MyDataLook look) => look.space(4);
  static double progressGap(MyDataLook look) => look.space(1);

  /// The user's message: a neutral bubble (the accent is kept for the one tinted action, Send).
  static BorderRadius bubbleRadius(MyDataLook look) => MyDataRadii.lg(look);
  static EdgeInsets bubblePadding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(3), vertical: look.space(2));

  /// A result's list and the approval card: a rounded box with a hairline outline, as the system draws a
  /// grouped box (System Settings' groups, Mail's message cards).
  static BorderRadius boxRadius(MyDataLook look) => MyDataRadii.sm(look);

  /// Inside a box's row, and inside the approval card.
  static EdgeInsets rowPadding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(3), vertical: look.space(2));
  static EdgeInsets cardPadding(MyDataLook look) => EdgeInsets.all(look.space(4));

  /// The composer: a rounded field that grows to six lines, with the round Send button inside it.
  static const composerHeight = MyDataMacSize.toolbarItemHeight;
  static const composerRadius = BorderRadius.all(Radius.circular(MyDataMacSize.toolbarItemHeight / 2));
  static const sendSize = MyDataMacSize.pushButtonHeight;

  /// The box's ground: the content's, with half the faintest fill (`quaternary-label`) over it, so it reads
  /// apart from the page and a row's `hover` still shows on it.
  static Color boxFill(BuildContext context) {
    final mac = context.mac;
    return Color.alphaBlend(mac.quaternaryLabel.withValues(alpha: mac.quaternaryLabel.a / 2), mac.contentBackground);
  }

  /// Puts [child] in the box.
  static Widget box(BuildContext context, Widget child) {
    final mac = context.mac;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(borderRadius: boxRadius(context.look), border: Border.all(color: mac.separator, width: MyDataMacSize.hairline)),
      child: ClipRRect(
        borderRadius: boxRadius(context.look),
        child: ColoredBox(color: boxFill(context), child: child),
      ),
    );
  }
}

/// The user's message, right-aligned in a neutral bubble.
class MacUserMessage extends StatelessWidget {
  const MacUserMessage(this.text, {super.key, required this.maxShare});
  final String text;
  final double maxShare;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * maxShare),
          child: DecoratedBox(
            decoration: BoxDecoration(color: mac.quaternaryLabel, borderRadius: MacChat.bubbleRadius(context.look)),
            child: Padding(
              padding: MacChat.bubblePadding(context.look),
              child: Text(text, style: MyDataMacType.body.copyWith(color: mac.label)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The assistant's sentence: plain text on the content's ground.
class MacAssistantText extends StatelessWidget {
  const MacAssistantText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(text, style: MyDataMacType.body.copyWith(color: context.mac.label)),
  );
}

/// "Checking calendar…" with the small turning kiwi, then a check once the run moves on.
class MacProgressRow extends StatelessWidget {
  const MacProgressRow(this.line, {super.key});
  final ProgressLine line;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final label = line.done ? line.label : '${line.label}…';
    return Row(
      children: [
        SizedBox.square(
          dimension: MyDataMacSize.icon,
          child: line.done
              ? Icon(MacIcons.check, size: MyDataMacSize.icon, color: mac.secondaryLabel)
              : const ExcludeSemantics(child: KiwiLoader(size: MyDataMacSize.icon)),
        ),
        SizedBox(width: context.space(2)),
        Flexible(child: Text(label, style: MyDataMacType.callout.copyWith(color: mac.secondaryLabel))),
      ],
    );
  }
}

/// A line from the app rather than either side: centred, `caption` in `secondary-label`. Screen readers
/// hear it when it appears.
class MacNoticeRow extends StatelessWidget {
  const MacNoticeRow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: MyDataMacType.caption.copyWith(color: context.mac.secondaryLabel),
      ),
    ),
  );
}

/// A reply is on its way and nothing has arrived yet: the turning kiwi.
class MacWorking extends StatelessWidget {
  const MacWorking({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: KiwiLoader(size: MyDataMacSize.icon, semanticLabel: label),
  );
}

/// A message that got no answer: what went wrong, in the host's words, and a Retry push button.
class MacErrorRow extends StatelessWidget {
  const MacErrorRow({super.key, required this.title, required this.message, required this.retryLabel, this.onRetry});
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final lineHeight = MyDataMacType.bodyEmphasized.fontSize! * MyDataMacType.bodyEmphasized.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centres the icon on the title's first line.
          padding: EdgeInsets.only(top: (lineHeight - MyDataMacSize.icon) / 2),
          child: Icon(MacIcons.error, size: MyDataMacSize.icon, color: context.colors.danger),
        ),
        SizedBox(width: context.space(2)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: MyDataMacType.bodyEmphasized.copyWith(color: mac.label)),
              Text(message, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
              SizedBox(height: context.space(2)),
              Button(label: retryLabel, onPressed: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

/// The composer at the bottom of the conversation, as Messages draws it: a rounded field with a hairline
/// outline on the content's ground, the placeholder in `secondary-label`, growing to six lines, and the
/// round Send button inside its end, in the accent (the screen's one tinted action) once there is text and
/// no answer is coming, else grey with its reason. The system's focus
/// ring when the field was reached with the keyboard.
class MacComposer extends StatelessWidget {
  const MacComposer({
    super.key,
    required this.input,
    required this.focus,
    required this.ring,
    required this.busy,
    required this.onSend,
    required this.inputKey,
    required this.sendKey,
    required this.placeholder,
    required this.sendLabel,
    required this.emptyReason,
    required this.busyReason,
  });

  final TextEditingController input;
  final FocusNode focus;
  final bool ring;
  final bool busy;
  final VoidCallback onSend;
  final Key inputKey;
  final Key sendKey;
  final String placeholder;
  final String sendLabel;

  /// Why Send waits: nothing typed yet, or an answer still coming.
  final String emptyReason;
  final String busyReason;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final lineHeight = MyDataMacType.body.fontSize! * MyDataMacType.body.height!;
    // Centres one line in the field; the button sits the same distance from the field's end.
    final inset = (MacChat.composerHeight - lineHeight) / 2;
    final buttonInset = (MacChat.composerHeight - MacChat.sendSize) / 2;
    return FocusRing(
      visible: ring,
      borderRadius: MacChat.composerRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: MacChat.composerHeight),
        decoration: BoxDecoration(
          color: mac.contentBackground,
          borderRadius: MacChat.composerRadius,
          border: Border.all(color: mac.separator, width: MyDataMacSize.hairline),
        ),
        padding: EdgeInsetsDirectional.only(start: context.space(4), end: buttonInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: inputKey,
                controller: input,
                focusNode: focus,
                enabled: !busy,
                autofocus: true,
                minLines: 1,
                maxLines: 6,
                style: MyDataMacType.body.copyWith(color: mac.label),
                cursorColor: mac.accent,
                cursorHeight: MyDataMacType.body.fontSize! + MyDataMacSize.tight,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: inset),
                  hintText: placeholder,
                  hintStyle: MyDataMacType.body.copyWith(color: mac.secondaryLabel),
                ),
              ),
            ),
            SizedBox(width: context.space(2)),
            // Grey and inert until there is something to send, as Messages draws it; the reason is its
            // help tag and hint.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: input,
              builder: (context, value, _) {
                final reason = busy ? busyReason : (value.text.trim().isEmpty ? emptyReason : null);
                final ready = reason == null;
                return Padding(
                  padding: EdgeInsets.only(bottom: buttonInset),
                  child: Pressable(
                    key: sendKey,
                    onPressed: ready ? onSend : null,
                    borderRadius: MyDataRadii.pill(context.look),
                    semanticLabel: sendLabel,
                    tooltip: sendLabel,
                    disabledReason: reason,
                    child: Container(
                      width: MacChat.sendSize,
                      height: MacChat.sendSize,
                      decoration: BoxDecoration(color: ready ? mac.accent : mac.quaternaryLabel, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Icon(MacIcons.send, size: MyDataMacSize.icon, color: ready ? mac.onAccent : mac.tertiaryLabel),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
