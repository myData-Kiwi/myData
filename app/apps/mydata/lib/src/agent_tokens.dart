import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'format.dart';
import 'host_action.dart';

/// Tokens for MCP agents: list, create (the token is shown once) and revoke.
class AgentTokensSection extends StatefulWidget {
  const AgentTokensSection({super.key, required this.controller, required this.agents});

  final HostController controller;
  final AgentList agents;

  static const heading = 'Agents';
  static const createLabel = 'Create an agent token';
  static const intro =
      'An agent (an MCP client such as a desktop AI app) reaches myData\'s tools with a token of its own.';
  static const newHeading = 'New token';

  /// In the Mac frame, under the Agents tab.
  static const macHeading = 'Tokens';
  static const namePlaceholder = 'For example, Claude on my laptop';
  static const nameHelp = 'Name it after the agent and the computer it runs on.';

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
        // Names what will stop working (design/components/ActionRow).
        content: Text(RevokeLabels.body(agent.name)),
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
      if (MacWindow.of(context)) return _mac(context);
      return GroupedSection(heading: AgentTokensSection.heading, parts: [_form(context), ..._rows()]);
    },
  );

  /// The Mac frame: the tokens, then a one-line form for a new one.
  Widget _mac(BuildContext context) {
    final list = _agents.agents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MacFormSection(
          heading: AgentTokensSection.macHeading,
          footer: AgentTokensSection.intro,
          rows: [
            if (list == null)
              const MacFormRow(title: 'Loading the tokens')
            else if (list.isEmpty)
              const MacFormRow(title: 'No agent tokens yet', subtitle: 'Tokens you create are listed here.')
            else
              for (final a in list) AgentTokenRow(key: ValueKey(a.id), agent: a, onRevoke: () => _revoke(a)),
          ],
        ),
        SizedBox(height: MacForm.gap(context.look)),
        MacFormSection(
          heading: AgentTokensSection.newHeading,
          footer: AgentTokensSection.nameHelp,
          rows: [
            MacFormPart(
              child: Row(
                children: [
                  Expanded(
                    child: MacEditField(
                      controller: _name,
                      label: 'Name',
                      placeholder: AgentTokensSection.namePlaceholder,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  SizedBox(width: context.space(3)),
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    // A short form, as design/components/GroupedSection says: a note, the field, and the section's one
    // filled button.
    return GroupedContentPart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'An agent (an MCP client such as a desktop AI app) reaches myData\'s tools with a token of its own.',
            style: context.typeScale.body.copyWith(color: c.inkMuted),
          ),
          SizedBox(height: context.space(4)),
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
          SizedBox(height: context.space(4)),
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
    if (list == null) return const [GroupedRow(title: 'Loading the tokens')];
    if (list.isEmpty) {
      return const [GroupedRow(title: 'No agent tokens yet', subtitle: 'Tokens you create are listed here.')];
    }
    return [for (final a in list) AgentTokenRow(key: ValueKey(a.id), agent: a, onRevoke: () => _revoke(a))];
  }
}

/// The words of revoking a token.
abstract final class RevokeLabels {
  /// The row's plain danger button, which asks first.
  static const ask = 'Revoke';

  /// The dialog's danger button, which revokes.
  static const confirm = 'Revoke token';

  /// The dialog's text: what stops working once the token named [name] is revoked.
  static String body(String name) =>
      '$name will no longer reach your data. Any agent using this token stops working at once.';
}

/// One agent token: name, when it was created and last used, and whether it is connected or revoked; an
/// [ActionRow] whose Revoke asks first. A revoked token keeps its row and its inactive chip.
class AgentTokenRow extends StatelessWidget {
  const AgentTokenRow({super.key, required this.agent, required this.onRevoke});

  final AgentOut agent;
  final VoidCallback onRevoke;

  /// The name field's width: room for a long name, not the whole settings column.
  static const fieldMaxWidth = 420.0;

  /// The chip for [agent]: revoked, connected, or not connected. Revoked is the inactive chip, not red:
  /// red is for errors (design/components/ActionRow).
  static (String, MyDataTone) state(AgentOut a) => a.revoked
      ? ('Revoked', MyDataTone.neutral)
      : a.connected
      ? ('Connected', MyDataTone.success)
      : ('Not connected', MyDataTone.neutral);

  @override
  Widget build(BuildContext context) {
    final a = agent;
    final lastSeen = a.lastSeenAt == null ? 'never used' : 'last seen ${formatWhen(a.lastSeenAt!)}';
    final (label, tone) = state(a);
    if (MacWindow.of(context)) {
      return MacFormRow(
        icon: MacIcons.key,
        title: a.name,
        subtitle: 'Created ${formatWhen(a.createdAt)} · $lastSeen',
        trailing: [
          MacFormValue(label, dot: context.toneStrong(tone)),
          if (!a.revoked) Button(label: RevokeLabels.ask, variant: ButtonVariant.plainDanger, onPressed: onRevoke),
        ],
      );
    }
    return ActionRow(
      icon: Icons.key_outlined,
      title: a.name,
      subtitle: 'Created ${formatWhen(a.createdAt)} · $lastSeen',
      badge: MyDataBadge(label, tone: tone),
      actions: [
        if (!a.revoked) Button(label: RevokeLabels.ask, variant: ButtonVariant.plainDanger, onPressed: onRevoke),
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
  Widget build(BuildContext context) => MacWindow.of(context)
      ? MacFormSection(
          heading: heading,
          rows: [
            MacFormRow(
              icon: MacIcons.warning,
              title: 'The agent list could not be read',
              subtitle: error,
              trailing: [Button(label: 'Retry', variant: ButtonVariant.tonal, onPressed: onRetry)],
            ),
          ],
        )
      : GroupedSection(
    heading: heading,
    parts: [
      ActionRow(
        title: 'The agent list could not be read',
        subtitle: error,
        actions: [Button(label: 'Retry', variant: ButtonVariant.tonal, onPressed: onRetry)],
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
            Text('Copy it now. It will not be shown again.', style: context.typeScale.bodyStrong.copyWith(color: c.danger)),
            SizedBox(height: context.space(4)),
            MonoWell(label: 'Token', value: agent.token, copyLabel: 'Copy token'),
            SizedBox(height: context.space(4)),
            MonoWell(label: 'MCP URL', value: mcpUrl, copyLabel: 'Copy URL'),
            SizedBox(height: context.space(4)),
            Text(
              'Give the agent the MCP URL, with the token as a bearer token.',
              style: context.typeScale.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ),
      ),
      actions: [Button(label: 'Done', variant: ButtonVariant.filled, onPressed: () => Navigator.pop(context))],
    );
  }
}
