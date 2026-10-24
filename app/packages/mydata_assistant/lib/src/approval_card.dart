import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'mac_chat.dart';

/// A held call, shown with the design system's [ApprovalCard] exactly as the host stored it: a question
/// naming the action, every argument with its full value (nothing shortened or hidden, because this is
/// what runs if approved), and the decision once it is made.
///
/// Under the card, in `caption`: the host's own one-line summary of the call ([ApprovalOut.summary]), then
/// who asked; while a decision is being sent, a small loader and
/// "Sending your decision"; a decision that could not be sent, in `danger`; after the decision, who
/// decided and what running it returned. The card has no slot for these, so they sit beneath it.
///
/// Pending: "Approve and send" (or "Approve and run") and Reject, both disabled while [deciding]. There is
/// no Edit: the host has no way to change a held call.
///
/// **The System look in the Mac window** ([MacSystemLook.isSystemLook]): the same card drawn as the system
/// would ([_MacApprovalCard]): a rounded box
/// with a hairline outline, the question in the toolbar's `title` with the state as a small glyph and word
/// at its end, every argument in Contacts' label and value columns ([MacFieldTable]: click a value to copy
/// it), and push buttons at the bottom right, Reject before the default "Approve and send" in the accent, as
/// in a macOS alert. The lines under it are in the system font.
class AssistantApprovalCard extends StatelessWidget {
  const AssistantApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
    this.deciding = false,
    this.error,
  });

  final ApprovalOut approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// A decision was sent and the host has not answered yet.
  final bool deciding;

  /// Why the last decision could not be sent.
  final String? error;

  static const sendingText = 'Sending your decision';

  bool get _isMail => approval.tool == 'send_mail';

  /// "Send this email?" for send_mail; otherwise "Run" and the tool's name in plain words ("Run delete
  /// mail?").
  static String questionFor(String tool) =>
      tool == 'send_mail' ? 'Send this email?' : 'Run ${tool.replaceAll('_', ' ').trim()}?';

  /// An argument name in sentence case: "to" is "To", "start_time" is "Start time".
  static String nameFor(String key) {
    final words = key.replaceAll('_', ' ').trim();
    if (words.isEmpty) return key;
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  ApprovalState get _state => switch (approval.status) {
    ApprovalOutStatusEnum.approved => ApprovalState.approved,
    ApprovalOutStatusEnum.rejected => ApprovalState.rejected,
    ApprovalOutStatusEnum.failed => ApprovalState.failed,
    _ => ApprovalState.pending,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mac = context.isSystemLook;
    final caption = context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted);
    final state = _state;
    final pending = state == ApprovalState.pending;
    final arguments = [for (final MapEntry(:key, :value) in approval.args.entries) (nameFor(key), _show(value))];
    final approveLabel = _isMail ? 'Approve and send' : 'Approve and run';
    final decidedLabel = _isMail ? 'Sent' : 'Done';
    final failure = state == ApprovalState.failed
        ? 'Running it failed: ${_clause(approval.error ?? 'the host gave no reason')}. Ask again to try once more.'
        : null;
    final sidePadding = mac ? context.space(4) : context.space(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mac)
          _MacApprovalCard(
            question: questionFor(approval.tool),
            arguments: arguments,
            approveLabel: approveLabel,
            decidedLabel: decidedLabel,
            state: state,
            onApprove: deciding ? null : onApprove,
            onReject: deciding ? null : onReject,
            error: failure,
          )
        else
          ApprovalCard(
            question: questionFor(approval.tool),
            arguments: arguments,
            approveLabel: approveLabel,
            decidedLabel: decidedLabel,
            state: state,
            onApprove: deciding ? null : onApprove,
            onReject: deciding ? null : onReject,
            error: failure,
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(sidePadding, context.space(2), sidePadding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (approval.summary.trim().isNotEmpty) Text(approval.summary, style: caption),
              Text('Asked by ${approval.caller}', style: caption),
              if (pending && deciding)
                Padding(
                  padding: EdgeInsets.only(top: context.space(1)),
                  child: Row(
                    children: [
                      KiwiLoader(size: mac ? MyDataMacSize.icon : context.density.icon, semanticLabel: sendingText),
                      SizedBox(width: context.space(2)),
                      Flexible(
                        child: ExcludeSemantics(child: Text(sendingText, style: caption)),
                      ),
                    ],
                  ),
                ),
              if (pending && error != null)
                Text(
                  'Your decision was not recorded: ${_clause(error!)}. Try again.',
                  style: context.type(MyDataTypeRole.caption).copyWith(color: c.danger),
                ),
              if (approval.decidedBy != null) Text('Decided by ${approval.decidedBy}', style: caption),
              if (approval.result != null)
                Text.rich(
                  TextSpan(
                    style: caption,
                    children: [
                      const TextSpan(text: 'Result: '),
                      TextSpan(
                        text: _show(approval.result),
                        style: context.typeScale.mono.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [text] without a closing full stop, to go inside a longer sentence.
String _clause(String text) {
  final t = text.trim();
  return t.endsWith('.') ? t.substring(0, t.length - 1) : t;
}

/// Strings as they are; anything else as indented JSON, so nested values are shown whole.
String _show(Object? value) {
  if (value is String) return value;
  return const JsonEncoder.withIndent('  ').convert(value);
}

/// The approval card in the Mac frame. The same states, labels, region names and keyboard behaviour as
/// mydata_ui's [ApprovalCard] (its names are used here), drawn as the system would.
class _MacApprovalCard extends StatefulWidget {
  const _MacApprovalCard({
    required this.question,
    required this.arguments,
    required this.approveLabel,
    required this.decidedLabel,
    required this.state,
    required this.onApprove,
    required this.onReject,
    this.error,
  });

  final String question;
  final List<(String, String)> arguments;
  final String approveLabel;
  final String decidedLabel;
  final ApprovalState state;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final String? error;

  @override
  State<_MacApprovalCard> createState() => _MacApprovalCardState();
}

class _MacApprovalCardState extends State<_MacApprovalCard> {
  /// Holds no focus itself; tells whether one of the buttons has it.
  final _actionsNode = FocusNode(debugLabel: 'Approval actions', canRequestFocus: false, skipTraversal: true);

  /// The card: focused only by code, after a decision removes the focused button.
  final _cardNode = FocusNode(debugLabel: 'Approval card', skipTraversal: true);

  bool _ring = false;

  bool get _pending => widget.state == ApprovalState.pending;

  @override
  void didUpdateWidget(_MacApprovalCard old) {
    super.didUpdateWidget(old);
    if (old.state == ApprovalState.pending && !_pending && _actionsNode.hasFocus) {
      // The focused button is about to go. Move focus to the card once it has, so Tab continues here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cardNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _actionsNode.dispose();
    _cardNode.dispose();
    super.dispose();
  }

  /// The state at the end of the question line: a glyph in its colour and the word, as a small badge would.
  Widget _status(BuildContext context) {
    final c = context.colors;
    final mac = context.mac;
    final (icon, colour, text) = switch (widget.state) {
      ApprovalState.pending => (MyDataIcon.warning, c.warning, ApprovalCard.pendingLabel),
      ApprovalState.approved => (MyDataIcon.success, c.success, widget.decidedLabel),
      ApprovalState.rejected => (MyDataIcon.close, mac.secondaryLabel, ApprovalCard.rejectedLabel),
      ApprovalState.failed => (MyDataIcon.error, c.danger, ApprovalCard.failedLabel),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        key: ValueKey(widget.state),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(context.icon(icon), size: MyDataMacSize.icon, color: colour),
          SizedBox(width: context.space(1)),
          Text(text, style: MyDataMacType.callout.copyWith(color: mac.secondaryLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mac = context.mac;
    final card = MacChat.box(
      context,
      Padding(
        padding: MacChat.cardPadding(context.look),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(widget.question, style: MyDataMacType.title.copyWith(color: mac.label)),
                  ),
                ),
                SizedBox(width: context.space(3)),
                _status(context),
              ],
            ),
            SizedBox(height: context.space(3)),
            // Every argument in full, exactly as it will run. The label column is Contacts'; an empty value
            // still has its line.
            MacFieldTable(groups: [
              [for (final (name, value) in widget.arguments) MacField(label: name, value: value)],
            ]),
            if (_pending)
              Padding(
                padding: EdgeInsets.only(top: context.space(4)),
                child: Focus(
                  focusNode: _actionsNode,
                  includeSemantics: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Button(label: ApprovalCard.rejectLabel, onPressed: widget.onReject),
                      SizedBox(width: ButtonRow.gap(context.look)),
                      Button(label: widget.approveLabel, variant: ButtonVariant.filled, onPressed: widget.onApprove),
                    ],
                  ),
                ),
              )
            else if (widget.state == ApprovalState.failed && widget.error != null)
              Padding(
                padding: EdgeInsets.only(top: context.space(3)),
                child: Text(widget.error!, style: MyDataMacType.body.copyWith(color: c.danger)),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _pending ? ApprovalCard.pendingRegionLabel : ApprovalCard.decidedRegionLabel,
      child: FocusableActionDetector(
        focusNode: _cardNode,
        includeFocusSemantics: false,
        onShowFocusHighlight: (v) => setState(() => _ring = v),
        child: FocusRing(visible: _ring, borderRadius: MacChat.boxRadius(context.look), child: card),
      ),
    );
  }
}
