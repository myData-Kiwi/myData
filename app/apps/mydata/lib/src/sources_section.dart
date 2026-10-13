import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'format.dart';
import 'host_action.dart';
import 'source_list.dart';

/// Where myData's contacts and calendars come from, in Settings.
///
/// - On a Mac host: "Sources" with This Mac (on or off, access to contacts and to calendars), "Included from
///   this Mac" (its contact accounts and calendars, each on or off) while it is on, and "Advanced" with
///   following an iCloud account, which is meant for hosts that are not Macs.
/// - Elsewhere This Mac is absent: "Sources" holds the iCloud form and the followed accounts.
class SourcesSections extends StatelessWidget {
  const SourcesSections({super.key, required this.controller, required this.sources, this.system});

  final HostController controller;
  final SourceList sources;

  /// Opens System Settings; null is the real one ([macSystem]).
  final MacSystem? system;

  static const heading = 'Sources';
  static const includedHeading = 'Included from this Mac';
  static const advancedHeading = 'Advanced';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sources,
    builder: (context, _) {
      final list = sources.sources;
      if (list == null && sources.error != null) {
        return _problem(sources.error!);
      }
      if (list == null) {
        return GroupedList(
          heading: heading,
          rows: const [GroupedRow(title: 'Loading the sources')],
        );
      }
      final mac = sources.mac;
      final icloud = IcloudSection(
        controller: controller,
        sources: sources,
        heading: mac == null ? heading : advancedHeading,
        onMacHost: mac != null,
      );
      if (mac == null) return icloud;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ThisMacSection(controller: controller, sources: sources, mac: mac, system: system ?? macSystem),
          if (mac.enabled) ...[
            const SizedBox(height: PageScaffold.gap),
            IncludedSection(controller: controller, sources: sources, mac: mac),
          ],
          const SizedBox(height: PageScaffold.gap),
          icloud,
        ],
      );
    },
  );

  Widget _problem(String error) => GroupedSection(
    heading: heading,
    parts: [
      ActionRow(
        title: 'The sources could not be read',
        subtitle: error,
        actions: [Button(label: 'Retry', variant: ButtonVariant.tonal, onPressed: sources.load)],
      ),
    ],
  );
}

/// The words of This Mac.
abstract final class ThisMacText {
  static const title = 'This Mac';
  static const off =
      'Reads the contacts and calendars of every account set up on this Mac. Nothing is sent anywhere, and '
      'myData never changes them.';
  static const allow = 'Allow access';
  static const asking = 'Waiting for your answer';
  static const openSettings = 'Open System Settings';
  static const notes = 'Notes on contacts are not included.';

  /// The toggle row's caption while it is on: the last error, or when it last read the Mac.
  static String caption(SourceOut mac) {
    if (mac.lastError != null && mac.lastError!.isNotEmpty) return mac.lastError!;
    if (mac.lastUpdate != null) return 'Last updated ${formatWhen(mac.lastUpdate!)}';
    return mac.readerRunning == true ? 'Not read yet' : 'Starting the reader';
  }

  /// Whether myData may read [kind] ("contacts" or "calendars") with [status]: the host's own test.
  static bool readable(String kind, String? status) =>
      kind == 'contacts' ? status == 'authorized' : status == 'fullAccess';

  /// What the person can do about one kind ("contacts" or "calendars") in [status], as macOS reports it.
  /// [running]: the reader is connected, so "unknown" is a state macOS reported that myData does not know,
  /// not one still to come.
  static AccessState access(String kind, String? status, {bool running = false}) {
    final pane = kind == 'contacts' ? 'Contacts' : 'Calendars';
    if (readable(kind, status)) return const AccessState('Allowed', MyDataTone.success, null);
    return switch (status) {
      'notDetermined' => AccessState(
        'Not asked yet',
        MyDataTone.neutral,
        'myData has not asked to read your $kind yet. macOS asks you when you choose Allow access.',
        action: AccessAction.allow,
      ),
      'denied' => AccessState(
        'Off',
        MyDataTone.warning,
        'myData cannot read your $kind because access was turned off. Turn it on in System Settings, '
            'Privacy & Security, $pane.',
        action: AccessAction.openSettings,
      ),
      'writeOnly' => const AccessState(
        'Add only',
        MyDataTone.warning,
        'myData can add events but not read them. Choose Full Access in System Settings, Privacy & Security, '
            'Calendars.',
        action: AccessAction.openSettings,
      ),
      'restricted' => AccessState(
        'Restricted',
        MyDataTone.warning,
        'A restriction set on this Mac, such as Screen Time or a profile, does not let myData read your $kind.',
      ),
      _ when running => AccessState(
        'Not readable',
        MyDataTone.warning,
        'macOS reported an access state myData does not know, so myData does not read your $kind. Check '
            'System Settings, Privacy & Security, $pane.',
        action: AccessAction.openSettings,
      ),
      _ => const AccessState('Checking', MyDataTone.neutral, 'Waiting for the reader to report.'),
    };
  }
}

/// What an access row offers.
enum AccessAction { allow, openSettings }

/// One kind's access, for its row: the chip, a sentence (null when allowed) and the action.
class AccessState {
  const AccessState(this.label, this.tone, this.sentence, {this.action});
  final String label;
  final MyDataTone tone;
  final String? sentence;
  final AccessAction? action;
}

/// "Sources" on a Mac host: This Mac on or off, and its access to contacts and to calendars.
class ThisMacSection extends StatefulWidget {
  const ThisMacSection({
    super.key,
    required this.controller,
    required this.sources,
    required this.mac,
    required this.system,
  });

  final HostController controller;
  final SourceList sources;
  final SourceOut mac;
  final MacSystem system;

  @override
  State<ThisMacSection> createState() => _ThisMacSectionState();
}

class _ThisMacSectionState extends State<ThisMacSection> {
  bool _saving = false;

  /// The kinds whose system prompt is open ("contacts", "calendars").
  final _asking = <String>{};

  SourceOut get _mac => widget.mac;

  Future<void> _turn(bool on) async {
    if (!on && !await _confirmOff()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    SourceOut? out;
    await runHostAction(
      context,
      widget.controller,
      failure: on ? 'Could not turn on This Mac' : 'Could not turn off This Mac',
      action: (c) async => out = await c.sources.configureMac(MacChoice.turn(on: on)),
    );
    widget.sources.useMac(out);
    await widget.sources.load();
    if (mounted) setState(() => _saving = false);
  }

  Future<bool> _confirmOff() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off This Mac?'),
        content: const Text(
          'myData deletes the contacts and events it copied from this Mac. Nothing on the Mac changes, and '
          'you can turn it on again at any time.',
        ),
        actions: [
          ButtonRow(
            alignment: WrapAlignment.end,
            children: [
              Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: () => Navigator.pop(context, false)),
              Button(
                label: 'Turn off This Mac',
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    return sure == true;
  }

  /// Shows the system's prompt (the host waits for the answer, up to a few minutes).
  Future<void> _allow(String kind) async {
    setState(() => _asking.add(kind));
    SourceOut? out;
    await runHostAction(
      context,
      widget.controller,
      failure: 'Could not ask for access',
      action: (c) async => out = await c.sources.requestMacAccess(
        AccessIn(what: kind == 'contacts' ? AccessInWhatEnum.contacts : AccessInWhatEnum.calendars),
      ),
    );
    widget.sources.useMac(out);
    if (mounted) setState(() => _asking.remove(kind));
  }

  Future<void> _openSettings(String kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final pane = kind == 'contacts' ? 'Contacts' : 'Calendars';
    final opened = await widget.system.open(kind == 'contacts' ? PrivacyPane.contacts : PrivacyPane.calendars);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open System Settings. Open it, then Privacy & Security, $pane.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mac = _mac;
    return GroupedSection(
      heading: SourcesSections.heading,
      parts: [
        GroupedRow.toggle(
          icon: Icons.laptop_mac_outlined,
          // A source: the same tone as the followed iCloud accounts. Contacts and calendars are accent.
          tone: MyDataTone.neutral,
          title: ThisMacText.title,
          subtitle: mac.enabled ? ThisMacText.caption(mac) : ThisMacText.off,
          value: mac.enabled,
          onChanged: _saving ? null : _turn,
        ),
        if (mac.enabled) ...[
          _accessRow('contacts', Icons.people_outline, mac.contactsStatus),
          _accessRow('calendars', Icons.event_outlined, mac.calendarsStatus),
        ],
      ],
    );
  }

  Widget _accessRow(String kind, IconData icon, String? status) {
    final s = ThisMacText.access(kind, status, running: _mac.readerRunning ?? false);
    final asking = _asking.contains(kind);
    return ActionRow(
      key: ValueKey('access-$kind'),
      icon: icon,
      tone: MyDataTone.accent, // as the same kind under "Included from this Mac"
      title: kind == 'contacts' ? 'Contacts' : 'Calendars',
      subtitle: s.sentence,
      badge: MyDataBadge(s.label, tone: s.tone),
      actions: [
        if (s.action == AccessAction.allow)
          Button(
            label: asking ? ThisMacText.asking : ThisMacText.allow,
            variant: ButtonVariant.tonal,
            onPressed: asking ? null : () => _allow(kind),
          ),
        if (s.action == AccessAction.openSettings)
          Button(label: ThisMacText.openSettings, variant: ButtonVariant.tonal, onPressed: () => _openSettings(kind)),
      ],
    );
  }
}

/// "Included from this Mac": each contact account and calendar on this Mac, on or off (all by default),
/// and what is never included.
class IncludedSection extends StatefulWidget {
  const IncludedSection({super.key, required this.controller, required this.sources, required this.mac});

  final HostController controller;
  final SourceList sources;
  final SourceOut mac;

  /// The kind of a contact account, for people.
  static String containerKind(String kind) => switch (kind) {
    'local' => 'On this Mac',
    'exchange' => 'Exchange account',
    'cardDAV' => 'Online account',
    _ => 'Not in an account',
  };

  /// The last line: what is never included, and the days of events myData keeps (only while it may read
  /// the calendars: otherwise it keeps none).
  static String note(SourceOut mac) {
    final w = mac.window;
    final reading = ThisMacText.readable('calendars', mac.calendarsStatus);
    final days = w == null || !reading ? '' : ' Events are kept from ${formatDate(w.start)} to ${formatDate(w.end)}.';
    return '${ThisMacText.notes}$days';
  }

  /// The row standing in for a kind with nothing listed: why, in one sentence.
  static String waiting(String kind, {required bool readable}) => readable
      ? 'Your ${kind == 'contacts' ? 'contact accounts' : 'calendars'} appear here once myData has read them.'
      : '${kind == 'contacts' ? 'Contacts' : 'Calendars'} appear here once myData may read them.';

  @override
  State<IncludedSection> createState() => _IncludedSectionState();
}

class _IncludedSectionState extends State<IncludedSection> {
  bool _saving = false;

  Future<void> _set({String? container, String? calendar, required bool include}) async {
    setState(() => _saving = true);
    SourceOut? out;
    await runHostAction(
      context,
      widget.controller,
      failure: 'Could not change what is included',
      action: (c) async => out = await c.sources.configureMac(
        MacChoice.change(widget.mac, container: container, calendar: calendar, include: include),
      ),
    );
    widget.sources.useMac(out);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final mac = widget.mac;
    final c = context.colors;
    final contactsReadable = ThisMacText.readable('contacts', mac.contactsStatus);
    final calendarsReadable = ThisMacText.readable('calendars', mac.calendarsStatus);
    return GroupedSection(
      heading: SourcesSections.includedHeading,
      parts: [
        if (!contactsReadable || mac.contactContainers.isEmpty)
          GroupedRow(
            key: const ValueKey('included-contacts-none'),
            icon: Icons.people_outline,
            title: 'Contacts',
            subtitle: IncludedSection.waiting('contacts', readable: contactsReadable),
          )
        else
          for (final k in mac.contactContainers)
            GroupedRow.toggle(
              key: ValueKey('container-${k.id}'),
              icon: Icons.people_outline,
              title: k.name.isEmpty ? 'Contacts' : k.name,
              subtitle: 'Contacts · ${IncludedSection.containerKind(k.kind)}',
              value: k.included,
              onChanged: _saving ? null : (on) => _set(container: k.id, include: on),
            ),
        if (!calendarsReadable || mac.calendars.isEmpty)
          GroupedRow(
            key: const ValueKey('included-calendars-none'),
            icon: Icons.event_outlined,
            title: 'Calendars',
            subtitle: IncludedSection.waiting('calendars', readable: calendarsReadable),
          )
        else
          for (final k in mac.calendars)
            GroupedRow.toggle(
              key: ValueKey('calendar-${k.id}'),
              icon: Icons.event_outlined,
              title: k.name.isEmpty ? 'Calendar' : k.name,
              subtitle: k.sourceName.isEmpty ? 'Calendar' : 'Calendar · ${k.sourceName}',
              value: k.included,
              onChanged: _saving ? null : (on) => _set(calendar: k.id, include: on),
            ),
        GroupedContentPart(
          child: Text(IncludedSection.note(mac), style: MyDataType.body.copyWith(color: c.inkMuted)),
        ),
      ],
    );
  }
}

/// Following an iCloud account over CardDAV and CalDAV, with an app-specific password: the way for a host
/// that is not a Mac. The form, then each followed account with Sync now and Remove.
///
/// The password is held only in its field and sent once, in the request; it is never logged or printed.
/// Never call toString() on an [AccountIn]: the generated class prints the password.
class IcloudSection extends StatefulWidget {
  const IcloudSection({
    super.key,
    required this.controller,
    required this.sources,
    required this.heading,
    required this.onMacHost,
  });

  final HostController controller;
  final SourceList sources;
  final String heading;

  /// On a Mac, This Mac is the main way and this button is tonal; elsewhere it is the section's filled one.
  final bool onMacHost;

  static const title = 'Follow an iCloud account';
  static const followLabel = 'Follow this account';
  static const why =
      'Apple does not let other apps sign in with your normal password, so this needs an app-specific '
      'password, made at account.apple.com, and the email of your Apple Account, which may differ from an '
      'address on your own domain.';
  static const forOtherHosts =
      'For a host that is not a Mac. On this Mac, This Mac above already includes '
      'your iCloud account. ';

  @override
  State<IcloudSection> createState() => _IcloudSectionState();
}

class _IcloudSectionState extends State<IcloudSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _adding = false;
  String? _error;

  /// The accounts with a sync or a removal under way.
  final _busy = <String>{};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _email.text.trim().isNotEmpty && _password.text.isNotEmpty && !_adding;

  Future<void> _follow() async {
    if (!_ready) return;
    final connection = widget.controller.connection;
    final messenger = ScaffoldMessenger.of(context);
    final email = _email.text.trim();
    setState(() {
      _adding = true;
      _error = null;
    });
    String? error;
    if (connection == null) {
      error = 'The host is not connected.';
    } else {
      try {
        await connection.sources.addAccount(
          AccountIn(provider: AccountInProviderEnum.icloud, email: email, password: _password.text),
        );
      } on Object catch (e) {
        // The host's own words ("Apple did not accept this sign-in. ..."); it never repeats the password.
        error = errorText(e);
      }
    }
    if (!mounted) return;
    setState(() {
      _adding = false;
      _error = error;
      if (error == null) {
        _email.clear();
        _password.clear();
      }
    });
    if (error == null) {
      messenger.showSnackBar(SnackBar(content: Text('Following $email. Its contacts and calendars are on their way.')));
      await widget.sources.load();
    }
  }

  Future<void> _sync(SourceOut a) async {
    setState(() => _busy.add(a.id));
    await runHostAction(
      context,
      widget.controller,
      failure: 'Could not sync ${a.email ?? 'the account'}',
      action: (c) => c.sources.syncAccount(a.id),
    );
    await widget.sources.load();
    if (mounted) setState(() => _busy.remove(a.id));
  }

  Future<void> _remove(SourceOut a) async {
    final email = a.email ?? 'this account';
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $email?'),
        content: Text(RemoveAccountText.body(email)),
        actions: [
          ButtonRow(
            alignment: WrapAlignment.end,
            children: [
              Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: () => Navigator.pop(context, false)),
              Button(
                label: RemoveAccountText.confirm,
                variant: ButtonVariant.danger,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy.add(a.id));
    await runHostAction(
      context,
      widget.controller,
      failure: 'Could not remove $email',
      action: (c) => c.sources.removeAccount(a.id),
    );
    await widget.sources.load();
    if (mounted) setState(() => _busy.remove(a.id));
  }

  @override
  Widget build(BuildContext context) {
    final accounts = widget.sources.icloud;
    return GroupedSection(heading: widget.heading, parts: [_form(context), for (final a in accounts) _row(a)]);
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    return GroupedContentPart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(IcloudSection.title, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
          const SizedBox(height: MyDataSpace.s1),
          Text(
            '${widget.onMacHost ? IcloudSection.forOtherHosts : ''}${IcloudSection.why}',
            style: MyDataType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: MyDataSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: IcloudForm.fieldMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MyDataTextField(
                  label: 'Apple Account email',
                  controller: _email,
                  placeholder: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  enabled: !_adding,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: MyDataSpace.s4),
                MyDataTextField(
                  label: 'App-specific password',
                  controller: _password,
                  placeholder: 'xxxx-xxxx-xxxx-xxxx',
                  help: 'Make one at account.apple.com, in Sign-In and Security.',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_adding,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _follow(),
                ),
              ],
            ),
          ),
          const SizedBox(height: MyDataSpace.s4),
          Button(
            label: _adding ? 'Checking with Apple' : IcloudSection.followLabel,
            variant: widget.onMacHost ? ButtonVariant.tonal : ButtonVariant.filled,
            onPressed: _ready ? _follow : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: MyDataSpace.s3),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: MyDataType.caption.copyWith(color: c.danger)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(SourceOut a) {
    final busy = _busy.contains(a.id);
    final String subtitle;
    if (a.lastError != null && a.lastError!.isNotEmpty) {
      subtitle = a.lastError!;
    } else if (a.lastUpdate != null) {
      subtitle = 'Last synced ${formatWhen(a.lastUpdate!)}';
    } else {
      subtitle = 'Not synced yet';
    }
    final badge = switch (a.state) {
      SourceOutStateEnum.syncing => const MyDataBadge('Syncing', tone: MyDataTone.info),
      SourceOutStateEnum.error => const MyDataBadge('Sync failed', tone: MyDataTone.danger),
      _ => null,
    };
    return ActionRow(
      key: ValueKey('account-${a.id}'),
      icon: Icons.cloud_outlined,
      title: a.email ?? 'iCloud account',
      subtitle: subtitle,
      badge: badge,
      actions: [
        Button(label: 'Sync now', variant: ButtonVariant.tonal, onPressed: busy ? null : () => _sync(a)),
        Button(
          label: RemoveAccountText.ask,
          variant: ButtonVariant.plainDanger,
          onPressed: busy ? null : () => _remove(a),
        ),
      ],
    );
  }
}

/// Sizes of the iCloud form.
abstract final class IcloudForm {
  /// The fields' width: room for a long email, not the whole settings column.
  static const fieldMaxWidth = 420.0;
}

/// The words of removing a followed account.
abstract final class RemoveAccountText {
  static const ask = 'Remove';
  static const confirm = 'Remove account';

  static String body(String email) =>
      'myData stops following $email and deletes the contacts and events it copied from it. Nothing in the '
      'iCloud account changes.';
}
