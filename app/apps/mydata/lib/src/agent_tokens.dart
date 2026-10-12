import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'format.dart';
import 'host_action.dart';

/// Tokens for MCP agents: list, create (the token is shown once) and revoke.
class AgentTokensSection extends StatelessWidget {
  const AgentTokensSection({super.key, required this.controller, required this.agents});

  final HostController controller;
  final AgentList agents;

  Future<void> _create(BuildContext context) async {
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name == null || !context.mounted) return;
    // The host returns the token only in this answer, so it is shown from the app's navigator, which is
    // still there if this section is not (the person switched to Status, or the host stopped meanwhile).
    final navigator = Navigator.of(context, rootNavigator: true);
    AgentCreated? created;
    late String mcpUrl;
    await runHostAction(
      context,
      controller,
      failure: 'Could not create the token',
      action: (c) async {
        mcpUrl = '${c.baseUrl}/mcp';
        created = await c.agents.createAgent(AgentIn(name: name));
      },
    );
    final agent = created;
    if (agent == null || !navigator.mounted) return;
    unawaited(agents.load());
    await showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => NewTokenDialog(agent: agent, mcpUrl: mcpUrl),
    );
  }

  Future<void> _revoke(BuildContext context, AgentOut agent) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke ${agent.name}?'),
        content: const Text('Agents using this token lose access to myData at once. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await runHostAction(
      context,
      controller,
      failure: 'Could not revoke ${agent.name}',
      action: (c) => c.agents.revokeAgent(agent.id),
    );
    await agents.load();
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Agent tokens',
    trailing: TextButton.icon(
      onPressed: () => _create(context),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Create token'),
    ),
    child: ListenableBuilder(
      listenable: agents,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'An agent (an MCP client such as a desktop AI app) reaches myData\'s tools with a token of its own.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ..._rows(context),
        ],
      ),
    ),
  );

  List<Widget> _rows(BuildContext context) {
    if (agents.error != null) {
      return [
        MessagePanel(
          kind: PanelKind.error,
          title: 'No agent list',
          message: 'The agent tokens could not be read.',
          detail: agents.error,
          onPrimary: agents.load,
        ),
      ];
    }
    final list = agents.agents;
    if (list == null) return const [InfoRow(label: 'Tokens', value: 'loading…')];
    if (list.isEmpty) return const [InfoRow(label: 'Tokens', value: 'none yet')];
    return [for (final a in list) AgentTokenRow(key: ValueKey(a.id), agent: a, onRevoke: () => _revoke(context, a))];
  }
}

/// One agent token: name, when it was created and last used, and whether it is connected or revoked.
class AgentTokenRow extends StatelessWidget {
  const AgentTokenRow({super.key, required this.agent, required this.onRevoke});

  final AgentOut agent;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = agent;
    final lastSeen = a.lastSeenAt == null ? 'never used' : 'last seen ${formatWhen(a.lastSeenAt!)}';
    final (label, tone) = a.revoked
        ? ('revoked', PillTone.bad)
        : a.connected
        ? ('connected', PillTone.good)
        : ('not connected', PillTone.neutral);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LegacyColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: t.titleSmall),
                const SizedBox(height: 2),
                Text('Created ${formatWhen(a.createdAt)} · $lastSeen', style: t.bodySmall),
              ],
            ),
          ),
          StatusPill(label: label, tone: tone),
          if (!a.revoked) ...[const SizedBox(width: 8), TextButton(onPressed: onRevoke, child: const Text('Revoke'))],
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create an agent token'),
    content: SizedBox(
      width: 400,
      child: TextField(
        controller: _name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Claude on my laptop'),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ListenableBuilder(
        listenable: _name,
        builder: (context, _) =>
            FilledButton(onPressed: _name.text.trim().isEmpty ? null : _submit, child: const Text('Create')),
      ),
    ],
  );
}

/// The new token, shown this once: the host keeps only its hash.
class NewTokenDialog extends StatelessWidget {
  const NewTokenDialog({super.key, required this.agent, required this.mcpUrl});

  final AgentCreated agent;
  final String mcpUrl;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text('Token for ${agent.name}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Copy it now. It will not be shown again.',
              style: t.bodyMedium?.copyWith(color: LegacyColors.danger, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _Copyable(label: 'Token', value: agent.token),
            const SizedBox(height: 12),
            _Copyable(label: 'MCP URL', value: mcpUrl),
            const SizedBox(height: 12),
            Text('Give the agent the MCP URL, with the token as a bearer token.', style: t.bodySmall),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
    );
  }
}

class _Copyable extends StatefulWidget {
  const _Copyable({required this.label, required this.value});
  final String label;
  final String value;

  @override
  State<_Copyable> createState() => _CopyableState();
}

class _CopyableState extends State<_Copyable> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: LegacyColors.cream, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(child: SelectableText(widget.value, style: legacyMonoStyle(size: 12))),
            TextButton(onPressed: _copy, child: Text(_copied ? 'Copied' : 'Copy')),
          ],
        ),
      ),
    ],
  );
}
