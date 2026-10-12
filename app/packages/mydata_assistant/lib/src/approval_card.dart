import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A held call, shown exactly as the host stored it: the tool, its summary, every argument with its
/// full value, and who asked. Nothing is shortened or hidden, because this is what runs if approved.
///
/// Pending: Approve and Reject (disabled while [deciding]). Decided: the outcome and who decided.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pending = approval.status == ApprovalOutStatusEnum.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.front_hand_outlined, size: 20, color: MyDataColors.skin),
                const SizedBox(width: 8),
                Expanded(child: Text('This needs your approval', style: t.titleMedium)),
                _StatusBadge(approval.status),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(approval.summary, style: t.bodyLarge),
            const SizedBox(height: 14),
            _Field(label: 'Tool', value: approval.tool),
            for (final MapEntry(:key, :value) in approval.args.entries) _Field(label: key, value: _show(value)),
            _Field(label: 'Asked by', value: approval.caller),
            const SizedBox(height: 6),
            if (pending)
              _Actions(deciding: deciding, error: error, onApprove: onApprove, onReject: onReject)
            else
              _Outcome(approval),
          ],
        ),
      ),
    );
  }
}

/// Strings as they are; anything else as indented JSON, so nested values are shown whole.
String _show(Object? value) {
  if (value is String) return value;
  return const JsonEncoder.withIndent('  ').convert(value);
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: monoStyle(size: 12, color: MyDataColors.muted)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: MyDataColors.cream, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(value, style: monoStyle()),
        ),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.deciding, required this.error, required this.onApprove, required this.onReject});
  final bool deciding;
  final String? error;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          Text('Your decision was not recorded: $error', style: t.bodyMedium?.copyWith(color: MyDataColors.danger)),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(onPressed: deciding ? null : onApprove, child: const Text('Approve')),
            OutlinedButton(onPressed: deciding ? null : onReject, child: const Text('Reject')),
            if (deciding) ...[
              const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              Text('Sending your decision', style: t.bodyMedium?.copyWith(color: MyDataColors.muted)),
            ],
          ],
        ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome(this.approval);
  final ApprovalOut approval;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (text, color) = switch (approval.status) {
      ApprovalOutStatusEnum.approved => (
        approval.tool == 'send_mail' ? 'Approved and sent' : 'Approved and done',
        MyDataColors.kiwiDeep,
      ),
      ApprovalOutStatusEnum.rejected => ('Rejected. Nothing was done.', MyDataColors.fg),
      ApprovalOutStatusEnum.failed => ('Failed: ${approval.error ?? 'no reason given'}', MyDataColors.danger),
      _ => ('Waiting for a decision', MyDataColors.muted),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(text, style: t.titleSmall?.copyWith(color: color)),
        if (approval.decidedBy != null) ...[
          const SizedBox(height: 4),
          Text('Decided by ${approval.decidedBy}', style: t.bodySmall),
        ],
        if (approval.result != null) ...[
          const SizedBox(height: 10),
          _Field(label: 'Result', value: _show(approval.result)),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final ApprovalOutStatusEnum status;

  @override
  Widget build(BuildContext context) => switch (status) {
    ApprovalOutStatusEnum.approved => const StatusPill(label: 'approved', tone: PillTone.good),
    ApprovalOutStatusEnum.rejected => const StatusPill(label: 'rejected'),
    ApprovalOutStatusEnum.failed => const StatusPill(label: 'failed', tone: PillTone.bad),
    _ => const StatusPill(label: 'waiting', tone: PillTone.warn),
  };
}
