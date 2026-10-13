import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

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
    final caption = MyDataType.caption.copyWith(color: c.inkMuted);
    final state = _state;
    final pending = state == ApprovalState.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ApprovalCard(
          question: questionFor(approval.tool),
          arguments: [for (final MapEntry(:key, :value) in approval.args.entries) (nameFor(key), _show(value))],
          approveLabel: _isMail ? 'Approve and send' : 'Approve and run',
          decidedLabel: _isMail ? 'Sent' : 'Done',
          state: state,
          onApprove: deciding ? null : onApprove,
          onReject: deciding ? null : onReject,
          error: state == ApprovalState.failed
              ? 'Running it failed: ${_clause(approval.error ?? 'the host gave no reason')}. Ask again to try once more.'
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s5, MyDataSpace.s2, MyDataSpace.s5, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (approval.summary.trim().isNotEmpty) Text(approval.summary, style: caption),
              Text('Asked by ${approval.caller}', style: caption),
              if (pending && deciding)
                Padding(
                  padding: const EdgeInsets.only(top: MyDataSpace.s1),
                  child: Row(
                    children: [
                      const KiwiLoader(size: MyDataSize.icon, semanticLabel: sendingText),
                      const SizedBox(width: MyDataSpace.s2),
                      Flexible(
                        child: ExcludeSemantics(child: Text(sendingText, style: caption)),
                      ),
                    ],
                  ),
                ),
              if (pending && error != null)
                Text(
                  'Your decision was not recorded: ${_clause(error!)}. Try again.',
                  style: MyDataType.caption.copyWith(color: c.danger),
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
                        style: MyDataType.mono.copyWith(color: c.inkMuted),
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
