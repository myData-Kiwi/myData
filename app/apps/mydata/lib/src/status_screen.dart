import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'format.dart';
import 'page.dart';

/// The host at a glance. Rebuilt on every status poll.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.status, required this.agents});

  final StatusOut status;
  final AgentList agents;

  @override
  Widget build(BuildContext context) {
    final s = status;
    return PageList(
      title: 'Status',
      children: [
        SectionCard(
          title: 'Host',
          trailing: s.demoDate ? const StatusPill(label: 'demo date', tone: PillTone.warn) : null,
          child: Column(
            children: [
              InfoRow(label: 'Version', value: s.version, mono: true),
              InfoRow(label: 'Running for', value: formatUptime(s.uptimeSeconds)),
              if (s.demoDate) InfoRow(label: 'Today (pinned)', value: formatDate(s.today)),
              InfoRow(label: 'Host memory', value: formatBytes(s.memory.hostBytes)),
            ],
          ),
        ),
        SectionCard(
          title: 'Assistant',
          trailing: _AvailabilityPill(assistantAvailability(s)),
          child: Column(
            children: [
              InfoRow(label: 'Model', value: describeModel(s.model)),
              InfoRow(
                label: 'Model memory',
                value: s.memory.modelBytes == null ? 'not loaded' : formatBytes(s.memory.modelBytes),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Last error',
          child: s.lastError == null
              ? const InfoRow(label: 'Error', value: 'none')
              : Column(
                  children: [
                    InfoRow(label: 'When', value: formatWhen(s.lastError!.at)),
                    InfoRow(label: 'Message', value: s.lastError!.message, mono: true),
                  ],
                ),
        ),
        SectionCard(title: 'Connected agents', child: _ConnectedAgents(agents)),
      ],
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill(this.availability);
  final AssistantAvailability availability;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (availability) {
      AssistantAvailability.ready => ('ready', PillTone.good),
      AssistantAvailability.preparing => ('preparing', PillTone.warn),
      AssistantAvailability.off => ('off', PillTone.neutral),
      AssistantAvailability.notInstalled => ('Ollama missing', PillTone.bad),
      AssistantAvailability.failed => ('error', PillTone.bad),
    };
    return StatusPill(label: label, tone: tone);
  }
}

class _ConnectedAgents extends StatelessWidget {
  const _ConnectedAgents(this.agents);
  final AgentList agents;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agents,
    builder: (context, _) {
      if (agents.error != null) {
        return MessagePanel(
          kind: PanelKind.error,
          title: 'No agent list',
          message: 'The agent list could not be read.',
          detail: agents.error,
          onPrimary: agents.load,
        );
      }
      if (agents.agents == null) return const InfoRow(label: 'Agents', value: 'loading…');
      final connected = agents.connected.toList();
      if (connected.isEmpty) return const InfoRow(label: 'Agents', value: 'none');
      return Column(
        children: [
          for (final a in connected)
            InfoRow(label: a.name, value: 'last seen ${a.lastSeenAt == null ? 'never' : formatWhen(a.lastSeenAt!)}'),
        ],
      );
    },
  );
}
