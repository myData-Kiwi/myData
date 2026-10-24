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

/// Appearance (the mode, and each app's theme on this device), the assistant switch, the sources of contacts
/// and calendars, and the agent tokens.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.themes,
    required this.agents,
    required this.sources,
    this.macSystem,
    this.sourcesKey,
  });

  final HostController controller;
  final ThemeController themes;
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
      AppearanceSection(themes: themes),
      AssistantSection(controller: controller),
      KeyedSubtree(
        key: sourcesKey,
        child: SourcesSections(controller: controller, sources: sources, system: macSystem),
      ),
      AgentTokensSection(controller: controller, agents: agents),
    ],
  );
}

/// Appearance (design/themes/ARCHITECTURE.md 4.3): this device's mode, then each app's theme and palette,
/// chosen on this device and never synced.
///
/// - **Mode:** Light, Dark or Match system, for every app on this device, applied at once.
/// - **Everywhere:** the theme and palette every app follows unless it has its own ("Kiwi, Plum"; System by
///   default). Change… opens the gallery on it, where Use everywhere (Return) sets it. Phones have one theme
///   per app until native phone apps, so there it is shown without Change….
/// - **Apps:** one row per app, "Same as everywhere" or its own theme and palette, with Change… (the gallery
///   on that app's scene, with the app switcher) and Reset (back to everywhere).
/// - **Themes:** the themes on this device and their palettes. Duplicate, Edit, Export and Import come with
///   custom themes (phase 5).
/// - A stored choice this build does not have (a theme removed, a palette renamed) says what it draws instead.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key, required this.themes});

  final ThemeController themes;

  static const heading = 'Appearance';
  static const modeLabel = 'Mode';
  static const modes = [(MyDataMode.light, 'Light'), (MyDataMode.dark, 'Dark'), (MyDataMode.system, 'Match system')];
  static const everywhereLabel = 'Everywhere';
  static const everywhereNote = 'Every app uses this unless it has its own.';
  static const appsHeading = 'Apps';
  static const sameAsEverywhere = 'Same as everywhere';
  static const changeLabel = 'Change…';
  static const resetLabel = 'Reset';
  static const resetReason = 'Already the same as everywhere.';
  static const libraryHeading = 'Themes';
  static const libraryFooter = 'Themes and palettes are chosen on this device and never leave it.';
  static const failed = 'Could not change the theme on this device. Try again.';

  /// "myCalendar's theme is not on this device: it draws System." (ARCHITECTURE.md 4.1)
  static String missing(String who, ThemeChoice drawn) =>
      "$who's theme is not on this device: it draws ${ThemeLibrary.describe(drawn)}.";

  /// The apps in Settings' order: myData first, then the others.
  static const apps = MyDataAppId.values;

  static String describe(ThemeController themes, MyDataAppId app) => themes.settings.followsEverywhere(app.name)
      ? sameAsEverywhere
      : ThemeLibrary.describe(themes.settings.choiceFor(app.name));

  static String describeEverywhere(ThemeController themes) =>
      ThemeLibrary.describe(themes.settings.everywhere ?? ThemeChoice.system);

  /// "Palettes: Kiwi, Graphite, Dusk, Plum, Rose and Amber."; a theme without palettes says where its colour
  /// comes from on a Mac.
  static String palettesOf(ThemeFile theme) {
    if (theme.palettes.isEmpty) return MacLook.forThisPlatform ? 'Its colour is the accent in System Settings.' : '';
    final names = [for (final p in theme.palettes) p.name];
    final list = names.length < 2 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return 'Palettes: $list.';
  }

  /// A library row's line: the theme's blurb, then its palettes.
  static String aboutTheme(ThemeFile theme) =>
      [theme.blurb ?? '', palettesOf(theme)].where((x) => x.isNotEmpty).join(' ');

  /// The gallery for [app], or for everywhere when null.
  Future<void> _change(BuildContext context, {MyDataAppId? app}) => showThemeGalleryFor(
    context,
    themes,
    app: MyDataAppId.mydata,
    choosingFor: apps,
    initialApp: app ?? MyDataAppId.mydata,
    everywhere: app == null,
  );

  Future<void> _setMode(BuildContext context, MyDataMode mode) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await themes.setMode(mode);
    } on Object {
      messenger?.showSnackBar(const SnackBar(content: Text(failed)));
    }
  }

  Future<void> _reset(BuildContext context, MyDataAppId app) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await themes.reset(app.name);
    } on Object {
      messenger?.showSnackBar(const SnackBar(content: Text(failed)));
    }
  }

  /// The stored choices this build cannot draw as written, as sentences.
  List<String> _missing() {
    final s = themes.settings;
    return [
      if (s.everywhere != null && !ThemeLibrary.knows(s.everywhere!))
        missing(everywhereLabel, ThemeLibrary.normalise(s.everywhere)),
      for (final a in apps)
        if (s.apps[a.name] case final c? when !ThemeLibrary.knows(c)) missing(a.displayName, ThemeLibrary.normalise(c)),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: themes,
    builder: (context, _) {
      final missingNow = _missing();
      Widget change(MyDataAppId? app, String who) => Button(
        label: changeLabel,
        variant: ButtonVariant.tonal,
        semanticLabel: 'Change $who',
        onPressed: () => _change(context, app: app),
      );
      Widget reset(MyDataAppId app) => Button(
        label: resetLabel,
        variant: ButtonVariant.plain,
        semanticLabel: 'Reset ${app.displayName}',
        disabledReason: resetReason,
        onPressed: themes.settings.followsEverywhere(app.name) ? null : () => _reset(context, app),
      );
      if (MacWindow.of(context)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final m in missingNow) ...[
              Notice(message: m, tone: NoticeTone.warning),
              SizedBox(height: context.space(3)),
            ],
            MacFormSection(
              rows: [
                MacFormRow(
                  title: heading,
                  trailing: [
                    MacSegmented<MyDataMode>(
                      segments: modes,
                      selected: themes.mode,
                      onChanged: (m) => _setMode(context, m),
                      semanticLabel: heading,
                    ),
                  ],
                ),
                MacFormRow(
                  title: everywhereLabel,
                  subtitle: describeEverywhere(themes),
                  trailing: [if (canUseEverywhere) change(null, everywhereLabel)],
                ),
              ],
              footer: everywhereNote,
            ),
            SizedBox(height: MacForm.gap(context.look)),
            MacFormSection(
              heading: appsHeading,
              rows: [
                for (final a in apps)
                  MacFormRow(
                    title: a.displayName,
                    subtitle: describe(themes, a),
                    trailing: [reset(a), change(a, a.displayName)],
                  ),
              ],
            ),
            SizedBox(height: MacForm.gap(context.look)),
            MacFormSection(
              heading: libraryHeading,
              footer: libraryFooter,
              rows: [for (final t in ThemeLibrary.offered) MacFormRow(title: t.name, subtitle: aboutTheme(t))],
            ),
          ],
        );
      }
      Widget line(String text, List<Widget> buttons) => Wrap(
        spacing: context.space(3),
        runSpacing: context.space(2),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(text, style: context.typeScale.body.copyWith(color: context.colors.ink)),
          ...buttons,
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GroupedSection(
            heading: heading,
            parts: [
              GroupedContentPart(
                child: GroupedStack(
                  children: [
                    for (final m in missingNow) Notice(message: m, tone: NoticeTone.warning),
                    GroupedControl(
                      label: modeLabel,
                      child: SegmentedControl<MyDataMode>(
                        segments: modes,
                        selected: themes.mode,
                        onChanged: (m) => _setMode(context, m),
                        semanticLabel: modeLabel,
                      ),
                    ),
                    GroupedControl(
                      label: everywhereLabel,
                      child: line(describeEverywhere(themes), [if (canUseEverywhere) change(null, everywhereLabel)]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.space(6)),
          GroupedSection(
            heading: appsHeading,
            parts: [
              GroupedContentPart(
                child: GroupedStack(
                  children: [
                    for (final a in apps)
                      GroupedControl(
                        label: a.displayName,
                        holdsName: true,
                        child: line(describe(themes, a), [change(a, a.displayName), reset(a)]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.space(6)),
          GroupedList(
            heading: libraryHeading,
            rows: [for (final t in ThemeLibrary.offered) GroupedRow(title: t.name, subtitle: aboutTheme(t))],
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
    if (MacWindow.of(context)) {
      return MacFormSection(
        footer: text,
        rows: [
          MacFormRow(
            icon: MyDataIcon.assistant,
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
          icon: MyDataIcon.assistant,
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
    required this.themes,
    required this.agents,
    required this.sources,
    this.macSystem,
  });

  final SettingsTab tab;
  final HostController controller;
  final ThemeController themes;
  final AgentList agents;
  final SourceList sources;
  final MacSystem? macSystem;

  @override
  Widget build(BuildContext context) => MacForm(
    children: switch (tab) {
      SettingsTab.sources => [SourcesSections(controller: controller, sources: sources, system: macSystem)],
      SettingsTab.appearance => [AppearanceSection(themes: themes)],
      SettingsTab.assistant => [AssistantSection(controller: controller)],
      SettingsTab.agents => [AgentTokensSection(controller: controller, agents: agents)],
      SettingsTab.about => [AboutSection(status: controller.status)],
    },
  );
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
        SizedBox(height: context.space(5)),
        const Center(child: KiwiTile(size: MyDataMacSize.avatar * 1.25)),
        SizedBox(height: context.space(3)),
        Center(
          child: Semantics(
            header: true,
            child: Text('myData', style: MyDataMacType.name.copyWith(color: mac.label)),
          ),
        ),
        SizedBox(height: context.space(1)),
        Center(
          child: Text(
            tagline,
            textAlign: TextAlign.center,
            style: MyDataMacType.body.copyWith(color: mac.secondaryLabel),
          ),
        ),
        SizedBox(height: context.space(6)),
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
