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
        return MacWindow.of(context) ? _macProblem(sources.error!) : _problem(sources.error!);
      }
      if (list == null && MacWindow.of(context)) {
        return const MacFormSection(heading: heading, rows: [MacFormRow(title: 'Loading the sources')]);
      }
      if (list == null) {
        return GroupedList(
          heading: heading,
          rows: const [GroupedRow(title: 'Loading the sources')],
        );
      }
      final mac = sources.mac;
      if (MacWindow.of(context)) {
        final icloud = IcloudSection(
          controller: controller,
          sources: sources,
          heading: mac == null ? heading : advancedHeading,
          onMacHost: mac != null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (mac != null) ...[
              ThisMacSection(controller: controller, sources: sources, mac: mac, system: system ?? macSystem),
              SizedBox(height: MacForm.gap(context.look)),
              if (mac.enabled) ...[
                IncludedSection(controller: controller, sources: sources, mac: mac),
                SizedBox(height: MacForm.gap(context.look)),
              ],
            ],
            icloud,
          ],
        );
      }
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
            SizedBox(height: PageScaffold.gap(context.look)),
            IncludedSection(controller: controller, sources: sources, mac: mac),
          ],
          SizedBox(height: PageScaffold.gap(context.look)),
          icloud,
        ],
      );
    },
  );

  Widget _macProblem(String error) => MacFormSection(
    heading: heading,
    rows: [
      MacFormRow(
        icon: MyDataIcon.warning,
        title: 'The sources could not be read',
        subtitle: error,
        trailing: [Button(label: 'Retry', variant: ButtonVariant.tonal, onPressed: sources.load)],
      ),
    ],
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

  /// The turn-off dialog's body, with until when the host's backups keep the copies (H8).
  static String offBody(String? backupsKeptUntil) =>
      'myData deletes the contacts and events it copied from this Mac. Nothing on the Mac changes, and you can '
      'turn it on again at any time.${backupsKeptUntil == null ? '' : ' ${RemoveAccountText.backupsKept(backupsKeptUntil)}'}';

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

  Future<bool> _confirmOff() => showMyDataDialog(
        context: context,
        builder: (_) => MyDataDialog(
          title: 'Turn off This Mac?',
          message: ThisMacText.offBody(_mac.backupsKeptUntil),
          confirmLabel: 'Turn off This Mac',
          destructive: true,
        ),
      );

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

  /// The Mac frame: This Mac's switch, then a row per kind with its access and what to do about it.
  Widget _macBuild(BuildContext context) {
    final mac = _mac;
    // No heading: the Settings tab already says Sources.
    return MacFormSection(
      rows: [
        MacFormRow(
          icon: MyDataIcon.thisMac,
          title: ThisMacText.title,
          subtitle: mac.enabled ? ThisMacText.caption(mac) : ThisMacText.off,
          trailing: [MacSwitch(value: mac.enabled, onChanged: _saving ? null : _turn, semanticLabel: ThisMacText.title)],
        ),
        if (mac.enabled) ...[
          _macAccessRow('contacts', MyDataIcon.people, mac.contactsStatus),
          _macAccessRow('calendars', MyDataIcon.calendar, mac.calendarsStatus),
        ],
      ],
    );
  }

  Widget _macAccessRow(String kind, MyDataIcon icon, String? status) {
    final s = ThisMacText.access(kind, status, running: _mac.readerRunning ?? false);
    final asking = _asking.contains(kind);
    return KeyedSubtree(
      key: ValueKey('access-$kind'),
      child: MacFormRow(
        icon: icon,
        title: kind == 'contacts' ? 'Contacts' : 'Calendars',
        subtitle: s.sentence,
        trailing: [
          if (s.action == AccessAction.allow)
            Button(
              label: asking ? ThisMacText.asking : ThisMacText.allow,
              variant: ButtonVariant.tonal,
              onPressed: asking ? null : () => _allow(kind),
            ),
          if (s.action == AccessAction.openSettings)
            Button(label: ThisMacText.openSettings, variant: ButtonVariant.tonal, onPressed: () => _openSettings(kind)),
          MacFormValue(s.label, dot: context.toneStrong(s.tone)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MacWindow.of(context)) return _macBuild(context);
    final mac = _mac;
    return GroupedSection(
      heading: SourcesSections.heading,
      parts: [
        GroupedRow.toggle(
          icon: MyDataIcon.thisMac,
          // A source: the same tone as the followed iCloud accounts. Contacts and calendars are accent.
          tone: MyDataTone.neutral,
          title: ThisMacText.title,
          subtitle: mac.enabled ? ThisMacText.caption(mac) : ThisMacText.off,
          value: mac.enabled,
          onChanged: _saving ? null : _turn,
        ),
        if (mac.enabled) ...[
          _accessRow('contacts', MyDataIcon.people, mac.contactsStatus),
          _accessRow('calendars', MyDataIcon.calendar, mac.calendarsStatus),
        ],
      ],
    );
  }

  Widget _accessRow(String kind, MyDataIcon icon, String? status) {
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
    if (MacWindow.of(context)) {
      return MacFormSection(
        heading: SourcesSections.includedHeading,
        footer: IncludedSection.note(mac),
        rows: [
          if (!contactsReadable || mac.contactContainers.isEmpty)
            MacFormRow(
              key: const ValueKey('included-contacts-none'),
              icon: MyDataIcon.people,
              title: 'Contacts',
              subtitle: IncludedSection.waiting('contacts', readable: contactsReadable),
            )
          else
            for (final k in mac.contactContainers)
              MacFormRow(
                key: ValueKey('container-${k.id}'),
                icon: MyDataIcon.people,
                title: k.name.isEmpty ? 'Contacts' : k.name,
                subtitle: 'Contacts · ${IncludedSection.containerKind(k.kind)}',
                trailing: [
                  MacSwitch(
                    value: k.included,
                    semanticLabel: k.name.isEmpty ? 'Contacts' : k.name,
                    onChanged: _saving ? null : (on) => _set(container: k.id, include: on),
                  ),
                ],
              ),
          if (!calendarsReadable || mac.calendars.isEmpty)
            MacFormRow(
              key: const ValueKey('included-calendars-none'),
              icon: MyDataIcon.calendar,
              title: 'Calendars',
              subtitle: IncludedSection.waiting('calendars', readable: calendarsReadable),
            )
          else
            for (final k in mac.calendars)
              MacFormRow(
                key: ValueKey('calendar-${k.id}'),
                icon: MyDataIcon.calendar,
                title: k.name.isEmpty ? 'Calendar' : k.name,
                subtitle: k.sourceName.isEmpty ? 'Calendar' : 'Calendar · ${k.sourceName}',
                trailing: [
                  MacSwitch(
                    value: k.included,
                    semanticLabel: k.name.isEmpty ? 'Calendar' : k.name,
                    onChanged: _saving ? null : (on) => _set(calendar: k.id, include: on),
                  ),
                ],
              ),
        ],
      );
    }
    return GroupedSection(
      heading: SourcesSections.includedHeading,
      parts: [
        if (!contactsReadable || mac.contactContainers.isEmpty)
          GroupedRow(
            key: const ValueKey('included-contacts-none'),
            icon: MyDataIcon.people,
            title: 'Contacts',
            subtitle: IncludedSection.waiting('contacts', readable: contactsReadable),
          )
        else
          for (final k in mac.contactContainers)
            GroupedRow.toggle(
              key: ValueKey('container-${k.id}'),
              icon: MyDataIcon.people,
              title: k.name.isEmpty ? 'Contacts' : k.name,
              subtitle: 'Contacts · ${IncludedSection.containerKind(k.kind)}',
              value: k.included,
              onChanged: _saving ? null : (on) => _set(container: k.id, include: on),
            ),
        if (!calendarsReadable || mac.calendars.isEmpty)
          GroupedRow(
            key: const ValueKey('included-calendars-none'),
            icon: MyDataIcon.calendar,
            title: 'Calendars',
            subtitle: IncludedSection.waiting('calendars', readable: calendarsReadable),
          )
        else
          for (final k in mac.calendars)
            GroupedRow.toggle(
              key: ValueKey('calendar-${k.id}'),
              icon: MyDataIcon.calendar,
              title: k.name.isEmpty ? 'Calendar' : k.name,
              subtitle: k.sourceName.isEmpty ? 'Calendar' : 'Calendar · ${k.sourceName}',
              value: k.included,
              onChanged: _saving ? null : (on) => _set(calendar: k.id, include: on),
            ),
        GroupedContentPart(
          child: Text(IncludedSection.note(mac), style: context.typeScale.body.copyWith(color: c.inkMuted)),
        ),
      ],
    );
  }
}

/// Following an iCloud account over CardDAV and CalDAV, with an app-specific password: the way for a host
/// that is not a Mac. The form, then each followed account with Sync now and Remove.
///
/// The password is held only in its field and sent once, in the request; it is never logged or printed.
/// Never call toString() on an [AccountIn]: the generated class prints the password. Checked by
/// packages/mydata_ui/test/no_password_logging_test.dart and test/password_not_printed_test.dart.
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

  /// Under a followed account while This Mac is on: the same account usually comes in through This Mac
  /// too. Plain words, not an error: both copies are listed and either can be hidden.
  static const notNeededOnMac =
      'Following this iCloud account is not needed on a Mac that has it in System Settings. Its calendars '
      'appear twice; hide one copy in myCalendar.';

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
    final removed = await showRemoveAccountDialog(
      context: context,
      title: 'Remove $email?',
      message: RemoveAccountText.body(email, backupsKeptUntil: a.backupsKeptUntil),
      confirmLabel: RemoveAccountText.confirm,
      workingLabel: RemoveAccountText.working,
      onConfirm: () async {
        final c = widget.controller.connection;
        if (c == null) return RemoveAccountText.failed(email);
        try {
          await c.sources.removeAccount(a.id);
        } on Object {
          return RemoveAccountText.failed(email);
        }
        return null;
      },
    );
    if (!removed || !mounted) return;
    await widget.sources.load();
    await widget.controller.refresh();
  }

  /// The Mac frame's form is folded on a Mac host (This Mac is the way there), open elsewhere.
  bool _formOpen = false;

  Widget _macBuild(BuildContext context) {
    final accounts = widget.sources.icloud;
    final twice = widget.onMacHost && (widget.sources.mac?.enabled ?? false);
    final form = _macForm(context);
    return MacFormSection(
      heading: widget.heading,
      rows: [
        if (widget.onMacHost)
          MacDisclosure(
            title: IcloudSection.title,
            open: _formOpen,
            onToggle: () => setState(() => _formOpen = !_formOpen),
            child: form,
          )
        else ...[
          MacFormRow(icon: MyDataIcon.cloud, title: IcloudSection.title),
          form,
        ],
        for (final a in accounts) _macRow(a, twice: twice),
      ],
    );
  }

  Widget _macForm(BuildContext context) {
    final mac = context.mac;
    Widget field(String label, Widget input) => Padding(
      padding: EdgeInsets.only(bottom: context.space(2)),
      child: Row(
        children: [
          SizedBox(
            width: IcloudForm.macLabelWidth,
            child: Text(label, style: MyDataMacType.body.copyWith(color: mac.label)),
          ),
          Expanded(child: input),
        ],
      ),
    );
    return MacFormPart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.onMacHost ? IcloudSection.forOtherHosts : ''}${IcloudSection.why}',
            style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel),
          ),
          SizedBox(height: context.space(3)),
          field(
            'Apple Account email',
            MacEditField(
              controller: _email,
              label: 'Apple Account email',
              placeholder: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_adding,
              onChanged: (_) => setState(() {}),
            ),
          ),
          field(
            'App-specific password',
            MacEditField(
              controller: _password,
              label: 'App-specific password',
              placeholder: 'xxxx-xxxx-xxxx-xxxx',
              obscure: true,
              textInputAction: TextInputAction.done,
              enabled: !_adding,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _follow(),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: IcloudForm.macLabelWidth),
            child: Text(
              'Make one at account.apple.com, in Sign-In and Security.',
              style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: context.space(2)),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: MyDataMacType.caption.copyWith(color: context.colors.danger)),
            ),
          ],
          SizedBox(height: context.space(3)),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Button(
              label: _adding ? 'Checking with Apple' : IcloudSection.followLabel,
              variant: widget.onMacHost ? ButtonVariant.tonal : ButtonVariant.filled,
              onPressed: _ready ? _follow : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macRow(SourceOut a, {required bool twice}) {
    final busy = _busy.contains(a.id);
    final String state;
    if (a.lastError != null && a.lastError!.isNotEmpty) {
      state = a.lastError!;
    } else if (a.lastUpdate != null) {
      state = 'Last synced ${formatWhen(a.lastUpdate!)}';
    } else {
      state = 'Not synced yet';
    }
    final status = switch (a.state) {
      SourceOutStateEnum.syncing => MacFormValue('Syncing', dot: context.toneStrong(MyDataTone.info)),
      SourceOutStateEnum.error => MacFormValue('Sync failed', dot: context.toneStrong(MyDataTone.danger)),
      _ => null,
    };
    return KeyedSubtree(
      key: ValueKey('account-${a.id}'),
      child: MacFormRow(
        icon: MyDataIcon.cloud,
        title: a.email ?? 'iCloud account',
        subtitle: twice ? '$state\n${IcloudSection.notNeededOnMac}' : state,
        trailing: [
          ?status,
          Button(label: 'Sync now', variant: ButtonVariant.tonal, onPressed: busy ? null : () => _sync(a)),
          Button(
            label: RemoveAccountText.ask,
            variant: ButtonVariant.plainDanger,
            onPressed: busy ? null : () => _remove(a),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MacWindow.of(context)) return _macBuild(context);
    final accounts = widget.sources.icloud;
    // This Mac is on, so a followed account is usually read twice: say so on a line of its own under it.
    final twice = widget.onMacHost && (widget.sources.mac?.enabled ?? false);
    return GroupedSection(
      heading: widget.heading,
      parts: [_form(context), for (final a in accounts) _row(a, twice: twice)],
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    return GroupedContentPart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(IcloudSection.title, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
          SizedBox(height: context.space(1)),
          Text(
            '${widget.onMacHost ? IcloudSection.forOtherHosts : ''}${IcloudSection.why}',
            style: context.typeScale.body.copyWith(color: c.inkMuted),
          ),
          SizedBox(height: context.space(4)),
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
                SizedBox(height: context.space(4)),
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
          SizedBox(height: context.space(4)),
          Button(
            label: _adding ? 'Checking with Apple' : IcloudSection.followLabel,
            variant: widget.onMacHost ? ButtonVariant.tonal : ButtonVariant.filled,
            onPressed: _ready ? _follow : null,
          ),
          if (_error != null) ...[
            SizedBox(height: context.space(3)),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: context.typeScale.caption.copyWith(color: c.danger)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(SourceOut a, {required bool twice}) {
    final busy = _busy.contains(a.id);
    final String state;
    if (a.lastError != null && a.lastError!.isNotEmpty) {
      state = a.lastError!;
    } else if (a.lastUpdate != null) {
      state = 'Last synced ${formatWhen(a.lastUpdate!)}';
    } else {
      state = 'Not synced yet';
    }
    final subtitle = twice ? '$state\n${IcloudSection.notNeededOnMac}' : state;
    final badge = switch (a.state) {
      SourceOutStateEnum.syncing => const MyDataBadge('Syncing', tone: MyDataTone.info),
      SourceOutStateEnum.error => const MyDataBadge('Sync failed', tone: MyDataTone.danger),
      _ => null,
    };
    return ActionRow(
      key: ValueKey('account-${a.id}'),
      icon: MyDataIcon.cloud,
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

  /// The Mac frame's label column beside the fields.
  static const macLabelWidth = 168.0;
}

/// The words of removing a followed account.
abstract final class RemoveAccountText {
  static const ask = 'Remove';
  static const confirm = 'Remove account';
  static const working = 'Removing…';

  /// The dialog's body, with until when the host's backups keep the copies (H8) when the host says.
  static String body(String email, {String? backupsKeptUntil}) =>
      'myData stops following $email and deletes the contacts and events it copied from it. Nothing in the '
      'iCloud account changes.${backupsKeptUntil == null ? '' : ' ${backupsKept(backupsKeptUntil)}'}';

  /// "Copies in your host's backups are kept until 1 Oct 2027."
  static String backupsKept(String isoDay) {
    return 'Copies in your host’s backups are kept until ${MyDataDates.hostDay(isoDay)}.';
  }

  static String failed(String email) =>
      'myData did not remove $email. The host did not answer. Check that it is running, then try again.';
}

/// Settings' Dialog for removing a followed account, also used by the import's Done step ("Stop following
/// ava@example.org?"): [message] says what goes and until when the backups keep it; the Danger button
/// [confirmLabel] runs [onConfirm], whose failure line keeps the dialog open. True when it was done.
Future<bool> showRemoveAccountDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String workingLabel,
  required Future<String?> Function() onConfirm,
}) => showMyDataDialog(
  context: context,
  builder: (_) => MyDataDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: true,
    workingLabel: workingLabel,
    onConfirm: onConfirm,
  ),
);
