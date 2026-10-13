import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'format.dart';
import 'host_action.dart';
import 'parts.dart';

/// Tokens for MCP agents: list, create (the token is shown once) and revoke.
class AgentTokensSection extends StatefulWidget {
  const AgentTokensSection({super.key, required this.controller, required this.agents});

  final HostController controller;
  final AgentList agents;

  static const heading = 'Agents';
  static const createLabel = 'Create an agent token';

  @override
  State<AgentTokensSection> createState() => _AgentTokensSectionState();
}

class _AgentTokensSectionState extends State<AgentTokensSection> {
  final _name = TextEditingController();
  bool _creating = false;

  HostController get _controller => widget.controller;
  AgentList get _agents => widget.agents;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _creating) return;
    // The host returns the token only in this answer, so it is shown from the app's navigator, which is
    // still there if this section is not (the person switched to Status, or the host stopped meanwhile).
    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() => _creating = true);
    AgentCreated? created;
    late String mcpUrl;
    await runHostAction(
      context,
      _controller,
      failure: 'Could not create the token',
      action: (c) async {
        mcpUrl = '${c.baseUrl}/mcp';
        created = await c.agents.createAgent(AgentIn(name: name));
      },
    );
    if (mounted) setState(() => _creating = false);
    final agent = created;
    if (agent == null || !navigator.mounted) return;
    if (mounted) _name.clear();
    unawaited(_agents.load());
    await showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => NewTokenDialog(agent: agent, mcpUrl: mcpUrl),
    );
  }

  Future<void> _revoke(AgentOut agent) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke ${agent.name}?'),
        content: const Text('Agents using this token lose access to myData at once. This cannot be undone.'),
        actions: [
          ButtonRow(
            alignment: WrapAlignment.end,
            children: [
              Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: () => Navigator.pop(context, false)),
              Button(
                label: RevokeLabels.confirm,
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await runHostAction(
      context,
      _controller,
      failure: 'Could not revoke ${agent.name}',
      action: (c) => c.agents.revokeAgent(agent.id),
    );
    await _agents.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _agents,
    builder: (context, _) {
      if (_agents.error != null) {
        return AgentListProblem(heading: AgentTokensSection.heading, error: _agents.error!, onRetry: _agents.load);
      }
      return SettingsSection(heading: AgentTokensSection.heading, children: [_form(context), ..._rows()]);
    },
  );

  Widget _form(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(MyDataSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'An agent (an MCP client such as a desktop AI app) reaches myData\'s tools with a token of its own.',
            style: MyDataType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: MyDataSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AgentTokenRow.fieldMaxWidth),
            child: MyDataTextField(
              label: 'Name',
              controller: _name,
              placeholder: 'For example, Claude on my laptop',
              help: 'Name it after the agent and the computer it runs on.',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
            ),
          ),
          const SizedBox(height: MyDataSpace.s4),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => Button(
              label: AgentTokensSection.createLabel,
              variant: ButtonVariant.filled,
              onPressed: _name.text.trim().isEmpty || _creating ? null : _create,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final list = _agents.agents;
    if (list == null) return const [SectionRow(title: 'Loading the tokens')];
    if (list.isEmpty) {
      return const [SectionRow(title: 'No agent tokens yet', subtitle: 'Tokens you create are listed here.')];
    }
    return [for (final a in list) AgentTokenRow(key: ValueKey(a.id), agent: a, onRevoke: () => _revoke(a))];
  }
}

/// The words of revoking a token.
abstract final class RevokeLabels {
  /// The row's plain button, which asks first.
  static const ask = 'Revoke';

  /// The dialog's danger button, which revokes.
  static const confirm = 'Revoke token';
}

/// One agent token: name, when it was created and last used, and whether it is connected or revoked.
class AgentTokenRow extends StatelessWidget {
  const AgentTokenRow({super.key, required this.agent, required this.onRevoke});

  final AgentOut agent;
  final VoidCallback onRevoke;

  /// The name field's width: room for a long name, not the whole settings column.
  static const fieldMaxWidth = 420.0;

  /// The chip for [agent]: revoked, connected, or not connected.
  static (String, MyDataTone) state(AgentOut a) => a.revoked
      ? ('Revoked', MyDataTone.danger)
      : a.connected
      ? ('Connected', MyDataTone.success)
      : ('Not connected', MyDataTone.neutral);

  @override
  Widget build(BuildContext context) {
    final a = agent;
    final lastSeen = a.lastSeenAt == null ? 'never used' : 'last seen ${formatWhen(a.lastSeenAt!)}';
    final (label, tone) = state(a);
    return SectionRow(
      icon: Icons.key_outlined,
      title: a.name,
      subtitle: 'Created ${formatWhen(a.createdAt)} · $lastSeen',
      trailing: [
        MyDataBadge(label, tone: tone),
        if (!a.revoked) Button(label: RevokeLabels.ask, variant: ButtonVariant.plain, onPressed: onRevoke),
      ],
    );
  }
}

/// The agent list could not be read: says so with the host's reason, and offers to read it again.
class AgentListProblem extends StatelessWidget {
  const AgentListProblem({super.key, required this.heading, required this.error, required this.onRetry});

  final String heading;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SettingsSection(
    heading: heading,
    children: [
      SectionRow(
        title: 'The agent list could not be read',
        subtitle: error,
        trailing: [Button(label: 'Retry', onPressed: onRetry)],
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
    final c = context.colors;
    return AlertDialog(
      title: Text('Token for ${agent.name}'),
      content: SizedBox(
        width: StatusPanel.maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copy it now. It will not be shown again.', style: MyDataType.bodyStrong.copyWith(color: c.danger)),
            const SizedBox(height: MyDataSpace.s4),
            _Copyable(label: 'Token', value: agent.token, copyLabel: 'Copy token'),
            const SizedBox(height: MyDataSpace.s4),
            _Copyable(label: 'MCP URL', value: mcpUrl, copyLabel: 'Copy URL'),
            const SizedBox(height: MyDataSpace.s4),
            Text(
              'Give the agent the MCP URL, with the token as a bearer token.',
              style: MyDataType.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
      actions: [Button(label: 'Done', variant: ButtonVariant.filled, onPressed: () => Navigator.pop(context))],
    );
  }
}

class _Copyable extends StatefulWidget {
  const _Copyable({required this.label, required this.value, required this.copyLabel});
  final String label;
  final String value;
  final String copyLabel;

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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.label, style: MyDataType.label.copyWith(color: context.colors.ink)),
      const SizedBox(height: MyDataSpace.s2),
      Row(
        children: [
          Expanded(child: MonoWell(text: widget.value)),
          const SizedBox(width: MyDataSpace.s2),
          Button(label: _copied ? 'Copied' : widget.copyLabel, onPressed: _copy),
        ],
      ),
    ],
  );
}
