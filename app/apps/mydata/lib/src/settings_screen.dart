import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'agent_tokens.dart';
import 'format.dart';
import 'host_action.dart';
import 'mac_status.dart';
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
      AssistantSection(controller: controller),
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

  /// The Mac frame's theme row: the accent here is the system's, so the host's theme is named for what it
  /// changes, the other devices (an accent choice for the Mac comes with the plan's Settings window).
  static const macThemeTitle = 'Theme on other devices';
  static const macThemeSubtitle = 'This Mac uses the accent colour in System Settings.';

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
      if (MacLook.of(context)) {
        return MacFormSection(
          rows: [
            MacFormRow(
              title: heading,
              trailing: [
                MacSegmented<MyDataMode>(
                  segments: modes,
                  selected: appearance.mode,
                  onChanged: appearance.setMode,
                  semanticLabel: heading,
                ),
              ],
            ),
            MacFormRow(
              title: macThemeTitle,
              subtitle: macThemeSubtitle,
              trailing: [MacThemeDots(selected: themeId, onChanged: (id) => _setTheme(context, id))],
            ),
          ],
        );
      }
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

/// The assistant on or off.
class AssistantSection extends StatefulWidget {
  const AssistantSection({super.key, required this.controller});
  final HostController controller;

  @override
  State<AssistantSection> createState() => _AssistantSectionState();
}

class _AssistantSectionState extends State<AssistantSection> {
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
    if (MacLook.of(context)) {
      return MacFormSection(
        footer: text,
        rows: [
          MacFormRow(
            icon: MacIcons.assistant,
            title: 'Assistant',
            trailing: [
              MacSwitch(value: enabled, onChanged: _saving || status == null ? null : _set, semanticLabel: 'Assistant'),
            ],
          ),
          if (enabled && status != null)
            MacFormRow(
              title: 'Model',
              subtitle: status.model.name,
              trailing: [macAvailability(context, assistantAvailability(status))],
            ),
        ],
      );
    }
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

/// The Mac frame's Settings tabs, in the toolbar band as an app's Settings window has them.
enum SettingsTab {
  sources('Sources'),
  appearance('Appearance'),
  assistant('Assistant'),
  agents('Agents'),
  about('About');

  const SettingsTab(this.label);
  final String label;
}

/// Settings in the Mac frame: the [tab]'s grouped form, as System Settings draws its panes. The sections are
/// the branded Settings' own, each drawing its Mac form, so what they do is the same.
class MacSettingsView extends StatelessWidget {
  const MacSettingsView({
    super.key,
    required this.tab,
    required this.controller,
    required this.appearance,
    required this.agents,
    required this.sources,
    this.macSystem,
  });

  final SettingsTab tab;
  final HostController controller;
  final AppearanceController appearance;
  final AgentList agents;
  final SourceList sources;
  final MacSystem? macSystem;

  @override
  Widget build(BuildContext context) => MacForm(
    children: switch (tab) {
      SettingsTab.sources => [SourcesSections(controller: controller, sources: sources, system: macSystem)],
      SettingsTab.appearance => [AppearanceSection(appearance: appearance)],
      SettingsTab.assistant => [AssistantSection(controller: controller)],
      SettingsTab.agents => [AgentTokensSection(controller: controller, agents: agents)],
      SettingsTab.about => [AboutSection(status: controller.status)],
    },
  );
}

/// The six themes as small round swatches in their accent, as System Settings' accent colour row: the
/// chosen one ringed. Each is a button named after its theme.
class MacThemeDots extends StatelessWidget {
  const MacThemeDots({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String>? onChanged;

  static const size = MyDataMacSize.icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mac = context.mac;
    return Wrap(
      spacing: MyDataSpace.s2,
      children: [
        for (final t in MyDataThemes.all)
          Tooltip(
            message: t.name,
            waitDuration: MacMenuLook.helpTagDelay,
            child: Pressable(
              onPressed: onChanged == null ? null : () => onChanged!(t.id),
              borderRadius: const BorderRadius.all(Radius.circular(MyDataRadius.pill)),
              scaleOnPress: false,
              semanticLabel: t.name,
              selected: t.id == selected,
              child: Container(
                width: size + 3 * MyDataMacSize.tight,
                height: size + 3 * MyDataMacSize.tight,
                padding: const EdgeInsets.all(MyDataMacSize.tight),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: t.id == selected ? mac.secondaryLabel : Colors.transparent, width: MyDataMacSize.tight),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? t.accentDark : t.accentLight,
                    border: Border.all(color: mac.separator, width: MyDataMacSize.hairline),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// About, in the Mac frame: the kiwi, the name, the host's version, and where the data lives.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, this.status});

  final StatusOut? status;

  static const tagline = 'Your contacts, calendars and assistant, on hardware you own.';
  static const privacy =
      'Your data stays on this Mac: the host keeps it, and the assistant\'s model runs here too. Open source '
      'under the AGPL-3.0. Not affiliated with MyData Global.';
  static const acknowledgements = 'Acknowledgements';

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final s = status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MyDataSpace.s5),
        const Center(child: KiwiTile(size: MyDataMacSize.avatar * 1.25)),
        const SizedBox(height: MyDataSpace.s3),
        Center(
          child: Semantics(header: true, child: Text('myData', style: MyDataMacType.name.copyWith(color: mac.label))),
        ),
        const SizedBox(height: MyDataSpace.s1),
        Center(
          child: Text(tagline, textAlign: TextAlign.center, style: MyDataMacType.body.copyWith(color: mac.secondaryLabel)),
        ),
        const SizedBox(height: MyDataSpace.s6),
        MacFormSection(
          footer: privacy,
          rows: [
            if (s != null) ...[
              MacFormRow(title: 'Host version', trailing: [MacFormValue(s.version)]),
              MacFormRow(title: 'Host running for', trailing: [MacFormValue(formatUptime(s.uptimeSeconds))]),
            ],
            MacFormRow(
              title: acknowledgements,
              subtitle: 'The open-source software and fonts myData is built with.',
              trailing: [
                Button(
                  label: 'Show',
                  variant: ButtonVariant.tonal,
                  onPressed: () => showLicensePage(context: context, applicationName: 'myData'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
