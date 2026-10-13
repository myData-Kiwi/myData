import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'agent_tokens.dart';
import 'host_action.dart';
import 'source_list.dart';
import 'sources_section.dart';

/// Appearance (theme and mode), the assistant switch, the sources of contacts and calendars, and the agent
/// tokens.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.appearance,
    required this.agents,
    required this.sources,
    this.macSystem,
    this.sourcesKey,
  });

  final HostController controller;
  final AppearanceController appearance;
  final AgentList agents;
  final SourceList sources;

  /// Opens System Settings; null is the real one ([macSystem]).
  final MacSystem? macSystem;

  /// On the Sources sections, so a `mydata://settings/sources` link can scroll to them.
  final Key? sourcesKey;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Settings',
    children: [
      AppearanceSection(appearance: appearance),
      _AssistantSwitch(controller: controller),
      KeyedSubtree(
        key: sourcesKey,
        child: SourcesSections(controller: controller, sources: sources, system: macSystem),
      ),
      AgentTokensSection(controller: controller, agents: agents),
    ],
  );
}

/// The theme (stored on the host, for every app) and the mode (this device), each applied at once with no
/// Save button, and a sample of the chosen theme in the current mode (design/theming.md).
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.appearance});

  final AppearanceController appearance;

  static const heading = 'Appearance';
  static const failed = 'Could not change the theme. Check that your host is running, then try again.';
  static const modes = [(MyDataMode.light, 'Light'), (MyDataMode.dark, 'Dark'), (MyDataMode.system, 'Match system')];

  Future<void> _setTheme(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appearance.setTheme(id);
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) {
      final themeId = appearance.themeId ?? MyDataThemes.fallback.id;
      // Stacked, as design/components/GroupedSection says: the theme, the mode under it, and the sample of
      // what they change under both, at its own width. The swatches get the full width: six on one row.
      return GroupedSection(
        heading: heading,
        parts: [
          GroupedContentPart(
            child: GroupedStack(
              children: [
                GroupedControl(
                  label: 'Theme',
                  child: ThemePicker(selected: themeId, onChanged: (id) => _setTheme(context, id)),
                ),
                GroupedControl(
                  label: 'Mode',
                  child: SegmentedControl<MyDataMode>(
                    segments: modes,
                    selected: appearance.mode,
                    onChanged: appearance.setMode,
                    semanticLabel: 'Mode',
                  ),
                ),
                ThemeSample(themeId: themeId),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _AssistantSwitch extends StatefulWidget {
  const _AssistantSwitch({required this.controller});
  final HostController controller;

  @override
  State<_AssistantSwitch> createState() => _AssistantSwitchState();
}

class _AssistantSwitchState extends State<_AssistantSwitch> {
  bool _saving = false;

  Future<void> _set(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final ok = await runHostAction(
      context,
      widget.controller,
      failure: enabled ? 'Could not switch the assistant on' : 'Could not switch the assistant off',
      action: (c) => c.assistant.assistantSettings(AssistantSettingsIn(enabled: enabled)),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && enabled) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The assistant is on. Its model is being prepared; the Status screen shows the progress.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.controller.status;
    final enabled = status?.assistantEnabled ?? false;
    final text = !enabled
        ? 'Off. myData works without it. Switching it on prepares its model, '
              'downloading it first (several gigabytes) if it is not on this computer yet.'
        : '${describeModel(status!.model)}. Switching it off unloads the model; the rest of myData keeps working.';
    return GroupedList(
      heading: 'Assistant',
      rows: [
        GroupedRow.toggle(
          icon: Icons.auto_awesome_outlined,
          title: 'Assistant',
          subtitle: text,
          value: enabled,
          onChanged: _saving || status == null ? null : _set,
        ),
      ],
    );
  }
}
