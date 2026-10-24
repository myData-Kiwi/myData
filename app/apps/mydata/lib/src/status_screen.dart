import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'agent_tokens.dart';
import 'apps_section.dart';
import 'format.dart';
import 'source_list.dart';

/// The host at a glance. Rebuilt on every status poll.
///
/// Under the cards, the other apps ([AppsSection]) when [apps] and [sources] are given, then the connected
/// agents.
///
/// Tiles: the cards and the apps use the `accent` tile, the agents the untinted one, so the screen has two
/// tile tones.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.status, required this.agents, this.apps, this.sources, this.onOpenApp});

  final StatusOut status;
  final AgentList agents;

  /// Which apps are installed; null leaves out the apps.
  final InstalledApps? apps;

  /// The sources, for the contacts and calendars counts; null leaves out the apps.
  final SourceList? sources;

  /// Opens an installed app.
  final ValueChanged<MyDataAppId>? onOpenApp;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final error = s.lastError;
    return PageScaffold(
      title: 'Status',
      children: [
        CardGrid(
          children: [
            MyDataCard(
              icon: MyDataIcon.host,
              name: 'Host',
              child: _Facts([
                Fact('Version', Text(s.version, style: context.typeScale.mono)),
                Fact('Running for', Text(formatUptime(s.uptimeSeconds))),
                if (s.demoDate)
                  Fact(
                    'Today',
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.space(2),
                      runSpacing: context.space(1),
                      children: [
                        Text(formatDate(s.today)),
                        const MyDataBadge('Demo date', tone: MyDataTone.warning),
                      ],
                    ),
                  ),
                Fact('Host memory', Text(formatSize(s.memory.hostBytes))),
              ]),
            ),
            MyDataCard(
              icon: MyDataIcon.assistant,
              name: 'Assistant',
              child: _Facts([
                Fact('State', availabilityBadge(assistantAvailability(s))),
                Fact('Model', Text(describeModel(s.model))),
                Fact(
                  'Model memory',
                  Text(s.memory.modelBytes == null ? 'Not loaded' : formatSize(s.memory.modelBytes)),
                ),
              ]),
            ),
            MyDataCard(
              icon: MyDataIcon.report,
              name: 'Last error',
              child: error == null
                  ? Text('None', style: context.typeScale.body.copyWith(color: context.colors.inkMuted))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Facts([Fact('When', Text(formatWhen(error.at)))]),
                        SizedBox(height: context.space(3)),
                        MonoWell(value: error.message),
                      ],
                    ),
            ),
          ],
        ),
        if (apps != null && sources != null)
          AppsSection(apps: apps!, sources: sources!, onOpen: onOpenApp ?? (_) {}),
        _ConnectedAgents(agents),
      ],
    );
  }
}

/// The assistant's availability as a status chip with a word.
MyDataBadge availabilityBadge(AssistantAvailability availability) {
  final (label, tone) = switch (availability) {
    AssistantAvailability.ready => ('Ready', MyDataTone.success),
    AssistantAvailability.preparing => ('Preparing', MyDataTone.info),
    AssistantAvailability.off => ('Off', MyDataTone.neutral),
    AssistantAvailability.notInstalled => ('Ollama missing', MyDataTone.danger),
    AssistantAvailability.failed => ('Error', MyDataTone.danger),
  };
  return MyDataBadge(label, tone: tone);
}

/// One line of a card: a name in `ink-muted` and its value at the end.
class Fact {
  const Fact(this.label, this.value);
  final String label;
  final Widget value;
}

class _Facts extends StatelessWidget {
  const _Facts(this.facts);
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) SizedBox(height: context.space(2)),
          ConstrainedBox(
            // A chip is taller than a line of text; every line gets its height, so they sit evenly.
            constraints: const BoxConstraints(minHeight: MyDataBadge.height),
            child: Row(
              children: [
                Text(facts[i].label, style: context.typeScale.body.copyWith(color: c.inkMuted)),
                SizedBox(width: context.space(3)),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DefaultTextStyle.merge(
                      textAlign: TextAlign.end,
                      style: TextStyle(color: c.ink),
                      child: facts[i].value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ConnectedAgents extends StatelessWidget {
  const _ConnectedAgents(this.agents);
  final AgentList agents;

  static const heading = 'Connected agents';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agents,
    builder: (context, _) {
      if (agents.error != null) {
        return AgentListProblem(heading: heading, error: agents.error!, onRetry: agents.load);
      }
      final list = agents.agents;
      final connected = agents.connected.toList();
      return GroupedList(
        heading: heading,
        rows: [
          if (list == null)
            const GroupedRow(title: 'Loading the agents')
          else if (connected.isEmpty)
            const GroupedRow(
              title: 'None connected',
              subtitle: 'An agent connects with a token you create in Settings, Agents.',
            )
          else
            for (final a in connected)
              GroupedRow(
                icon: MyDataIcon.agents,
                tone: MyDataTone.neutral,
                title: a.name,
                subtitle: 'Last seen ${a.lastSeenAt == null ? 'never' : formatWhen(a.lastSeenAt!)}',
              ),
        ],
      );
    },
  );
}
