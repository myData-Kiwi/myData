import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'agent_list.dart';
import 'agent_tokens.dart';
import 'host_action.dart';
import 'page.dart';

/// The assistant switch and the agent tokens.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, required this.agents});

  final HostController controller;
  final AgentList agents;

  @override
  Widget build(BuildContext context) => PageList(
    title: 'Settings',
    children: [
      _AssistantSwitch(controller: controller),
      AgentTokensSection(controller: controller, agents: agents),
    ],
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
    return SectionCard(
      title: 'Assistant',
      trailing: Switch(value: enabled, onChanged: _saving || status == null ? null : _set),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
