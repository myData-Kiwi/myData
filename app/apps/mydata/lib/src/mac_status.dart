import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'apps_section.dart';
import 'format.dart';
import 'source_list.dart';

/// Status in the Mac frame: a calm overview, not a dashboard (plan section 5, "status only when something is
/// wrong"). The host's state in one line, a line when it reported an error, the apps with what they hold and
/// Open, the agents only while one is connected, and the developer's facts (version, uptime, memory, the
/// model, the last error) folded under Details. Rebuilt on every status poll.
class MacStatusView extends StatefulWidget {
  const MacStatusView({
    super.key,
    required this.status,
    required this.agents,
    required this.apps,
    required this.sources,
    required this.onOpenApp,
    required this.onOpenSources,
  });

  final StatusOut status;
  final AgentList agents;
  final InstalledApps apps;
  final SourceList sources;
  final ValueChanged<MyDataAppId> onOpenApp;

  /// Opens Settings, Sources (the sample data's "Use your Mac's data").
  final VoidCallback onOpenSources;

  static const title = 'Your host is running';
  static const details = 'Details';
  static const errorTitle = 'The host reported an error';
  static const showDetails = 'Show details';
  static const useYourData = 'Use your Mac’s data';
  static const appsHeading = 'Apps';
  static const agentsHeading = 'Connected agents';

  /// The line under the title: sample data and its date, or where the data comes from.
  static String line(StatusOut s, SourceList sources) {
    if (s.mode == StatusOutModeEnum.demo) {
      return 'Showing sample data, with the date set to ${formatDate(s.today)}. Your own contacts and calendars '
          'are not read until you turn on a source.';
    }
    final on = [...?sources.sources?.where((x) => x.enabled)];
    if (on.isEmpty) return 'Your contacts are kept on this Mac.';
    return 'Reading your contacts and calendars from ${AppsText.sourceNames(on)}.';
  }

  @override
  State<MacStatusView> createState() => _MacStatusViewState();
}

class _MacStatusViewState extends State<MacStatusView> {
  bool _details = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.agents, widget.apps, widget.sources]),
    builder: (context, _) {
      final s = widget.status;
      final error = s.lastError;
      final connected = widget.agents.connected.toList();
      return MacForm(
        children: [
          _header(context, s),
          if (error != null)
            MacFormSection(
              rows: [
                MacFormRow(
                  icon: MacIcons.warning,
                  title: MacStatusView.errorTitle,
                  subtitle: formatWhen(error.at),
                  trailing: [
                    Button(
                      label: MacStatusView.showDetails,
                      variant: ButtonVariant.plain,
                      onPressed: () => setState(() => _details = true),
                    ),
                  ],
                ),
              ],
            ),
          MacFormSection(
            heading: MacStatusView.appsHeading,
            rows: [for (final app in AppsSection.listed) _app(context, app)],
          ),
          if (connected.isNotEmpty)
            MacFormSection(
              heading: MacStatusView.agentsHeading,
              rows: [
                for (final a in connected)
                  MacFormRow(
                    icon: MacIcons.agents,
                    title: a.name,
                    subtitle: 'Last seen ${a.lastSeenAt == null ? 'never' : formatWhen(a.lastSeenAt!)}',
                  ),
              ],
            ),
          MacFormSection(
            rows: [
              MacDisclosure(
                title: MacStatusView.details,
                open: _details,
                onToggle: () => setState(() => _details = !_details),
                child: _facts(context, s),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _header(BuildContext context, StatusOut s) {
    final mac = context.mac;
    final demo = s.mode == StatusOutModeEnum.demo;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space(3)),
      child: Row(
        children: [
          const KiwiTile(size: MyDataMacSize.avatar),
          SizedBox(width: context.space(4)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MacStatusDot(color: context.toneStrong(MyDataTone.success)),
                    SizedBox(width: context.space(2)),
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(MacStatusView.title, style: MyDataMacType.name.copyWith(color: mac.label)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.space(1)),
                Text(MacStatusView.line(s, widget.sources), style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
                if (demo) ...[
                  SizedBox(height: context.space(2)),
                  Button(
                    label: MacStatusView.useYourData,
                    variant: ButtonVariant.filled,
                    onPressed: widget.onOpenSources,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _app(BuildContext context, MyDataAppId app) {
    final installed = widget.apps.isInstalled(app);
    return KeyedSubtree(
      key: ValueKey('app-${app.name}'),
      child: MacFormRow(
        icon: macAppIcon(app),
        title: app.displayName,
        subtitle: AppsText.caption(app, widget.sources),
        trailing: [
          if (app == MyDataAppId.myassistant) macAvailability(context, assistantAvailability(widget.status)),
          if (installed)
            Button(label: AppsSection.openLabel, variant: ButtonVariant.tonal, onPressed: () => widget.onOpenApp(app))
          else
            const MacFormValue(AppsSection.notInstalled),
        ],
      ),
    );
  }

  /// The developer's facts, as the branded Status shows them in its cards.
  Widget _facts(BuildContext context, StatusOut s) {
    final error = s.lastError;
    final m = s.model;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: context.space(5), bottom: context.space(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fact('Host version', s.version),
          _fact('Running for', formatUptime(s.uptimeSeconds)),
          if (s.demoDate) _fact('Today', '${formatDate(s.today)} (demo date)'),
          _fact('Host memory', formatSize(s.memory.hostBytes)),
          _fact('Model', describeModel(m)),
          _fact('Model memory', s.memory.modelBytes == null ? 'Not loaded' : formatSize(s.memory.modelBytes)),
          _fact('Last error', error == null ? 'None' : formatWhen(error.at)),
          if (error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(context.space(3), context.space(1), context.space(3), 0),
              child: MonoWell(value: error.message),
            ),
        ],
      ),
    );
  }

  /// One fact on a Mac list row's height, label and value apart.
  Widget _fact(String label, String value) => Builder(
    builder: (context) {
      final mac = context.mac;
      return MergeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MyDataMacSize.rowHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.space(3), vertical: MyDataMacSize.tight),
            child: Row(
              children: [
                Text(label, style: MyDataMacType.body.copyWith(color: mac.label)),
                SizedBox(width: context.space(3)),
                Expanded(
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.end,
                    style: MyDataMacType.body.copyWith(color: mac.secondaryLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Each app's icon in the Mac frame.
IconData macAppIcon(MyDataAppId app) => switch (app) {
  MyDataAppId.mycontacts => MacIcons.people,
  MyDataAppId.mycalendar => MacIcons.calendar,
  MyDataAppId.myassistant => MacIcons.chat,
  MyDataAppId.mydata => MacIcons.host,
};

/// The assistant's availability in the Mac frame: a status dot and a word.
Widget macAvailability(BuildContext context, AssistantAvailability availability) {
  final (label, tone) = switch (availability) {
    AssistantAvailability.ready => ('Ready', MyDataTone.success),
    AssistantAvailability.preparing => ('Preparing', MyDataTone.info),
    AssistantAvailability.off => ('Off', MyDataTone.neutral),
    AssistantAvailability.notInstalled => ('Ollama missing', MyDataTone.danger),
    AssistantAvailability.failed => ('Error', MyDataTone.danger),
  };
  return MacFormValue(label, dot: context.toneStrong(tone));
}
