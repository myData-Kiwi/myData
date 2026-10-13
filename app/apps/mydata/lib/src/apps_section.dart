import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'source_list.dart';

/// The other apps of the family, on the Status screen: one row each for myContacts, myCalendar and
/// myAssistant, saying whether it is installed on this Mac and, for the two data apps, how many contacts or
/// calendars the host holds and from which sources. An installed app has a tonal "Open" button; one that
/// is not installed has the inactive "Not installed" chip instead.
///
/// Whether an app is installed is looked up once when the screen first shows and again whenever myData
/// comes back to the front ([InstalledApps]); the counts follow GET /sources, read with each status poll.
class AppsSection extends StatelessWidget {
  const AppsSection({super.key, required this.apps, required this.sources, required this.onOpen});

  final InstalledApps apps;
  final SourceList sources;

  /// Opens the app (brings it forward, or starts it).
  final ValueChanged<MyDataAppId> onOpen;

  static const heading = 'Apps';
  static const openLabel = 'Open';
  static const notInstalled = 'Not installed';

  /// The apps listed, in this order.
  static const listed = [MyDataAppId.mycontacts, MyDataAppId.mycalendar, MyDataAppId.myassistant];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([apps, sources]),
    builder: (context, _) => GroupedSection(
      heading: heading,
      parts: [
        for (final app in listed)
          ActionRow(
            key: ValueKey('app-${app.name}'),
            icon: AppsText.icon(app),
            tone: MyDataTone.accent,
            title: app.displayName,
            subtitle: AppsText.caption(app, sources),
            badge: apps.isInstalled(app) ? null : const MyDataBadge(notInstalled, tone: MyDataTone.neutral),
            actions: [
              if (apps.isInstalled(app))
                Button(label: openLabel, variant: ButtonVariant.tonal, onPressed: () => onOpen(app)),
            ],
          ),
      ],
    ),
  );
}

/// The words of the apps' rows.
abstract final class AppsText {
  static IconData icon(MyDataAppId app) => switch (app) {
    MyDataAppId.mycontacts => Icons.people_outline,
    MyDataAppId.mycalendar => Icons.event_outlined,
    MyDataAppId.myassistant => Icons.chat_bubble_outline_rounded,
    MyDataAppId.mydata => Icons.dns_outlined,
  };

  static const assistant = 'Ask about your contacts and calendars in a chat.';
  static const noSource = 'No source is on. Turn one on in Settings, Sources.';
  static const reading = 'Reading the sources';

  /// The row's caption: for myContacts and myCalendar the count and the sources it comes from, for
  /// myAssistant what it does.
  static String? caption(MyDataAppId app, SourceList sources) => switch (app) {
    MyDataAppId.mycontacts => _data(sources, (c) => c.contacts, 'contact', 'contacts'),
    MyDataAppId.mycalendar => _data(sources, (c) => c.calendars, 'calendar', 'calendars'),
    MyDataAppId.myassistant => assistant,
    MyDataAppId.mydata => null,
  };

  static String? _data(SourceList sources, int Function(SyncCounts) count, String one, String many) {
    final list = sources.sources;
    if (list == null) return sources.error == null ? reading : null;
    final on = list.where((s) => s.enabled).toList();
    if (on.isEmpty) return noSource;
    final n = on.fold<int>(0, (sum, s) => sum + (s.counts == null ? 0 : count(s.counts!)));
    return '${counted(n, one, many)} from ${sourceNames(on)}';
  }

  /// "No contacts", "1 contact", "128 contacts".
  static String counted(int n, String one, String many) => n == 0 ? 'No $many' : '$n ${n == 1 ? one : many}';

  /// The sources, named as everywhere else (design/components/Notice): "this Mac", "the iCloud account
  /// sam@example.com", joined with commas and a last "and".
  static String sourceNames(List<SourceOut> on) {
    final names = [
      for (final s in on) s.kind == SourceOutKindEnum.mac ? 'this Mac' : 'the iCloud account ${s.email ?? ''}'.trim(),
    ];
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
}
