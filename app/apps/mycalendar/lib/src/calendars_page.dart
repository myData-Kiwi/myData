import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The Calendars section: one grouped list per source, headed by the source ("This Mac", "iCloud account
/// you@example.com"), with a Show switch per calendar (design/components/DataColour, "The calendar list").
///
/// - Under This Mac each row has a caption naming the account the calendar belongs to on the Mac, as the
///   host gives it; an iCloud account's rows have none, because the heading names the account.
/// - When This Mac and an iCloud account are both on, that account's calendars come through both, and both
///   copies are listed, each under its source; either can be hidden.
/// - Hiding changes only what myCalendar shows on this device ([CalendarVisibility]); nothing changes in the
///   calendar. myAssistant's answers come from the host and still include hidden calendars, so the intro
///   names myCalendar rather than the device.
/// - A change that could not be stored on the device says so, and the switch goes back to what is stored.
class CalendarsPage extends StatelessWidget {
  const CalendarsPage({super.key, required this.calendars, required this.visibility});

  /// In the host's order: This Mac first, then each iCloud account.
  final List<CalendarOut> calendars;
  final CalendarVisibility visibility;

  static const title = 'Calendars';
  static const intro =
      'Choose which calendars myCalendar shows on this device. Hiding one changes nothing in the calendar.';
  static const saveFailed = 'myCalendar could not save that change on this device. Try again.';
  static const none = 'myData has not read any calendars yet. They appear here when it has.';

  /// The calendars grouped by their source's heading, in the host's order.
  static List<(String heading, List<CalendarOut> calendars)> groups(List<CalendarOut> calendars) {
    final out = <(String, List<CalendarOut>)>[];
    for (final c in calendars) {
      final i = out.indexWhere((g) => g.$1 == c.sourceLabel);
      if (i < 0) {
        out.add((c.sourceLabel, [c]));
      } else {
        out[i].$2.add(c);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: visibility,
      builder: (context, _) => PageScaffold(
        title: title,
        children: [
          Text(calendars.isEmpty ? none : intro, style: MyDataType.body.copyWith(color: c.inkMuted)),
          for (final (heading, items) in groups(calendars))
            GroupedList(
              heading: heading,
              rows: [
                for (final cal in items)
                  CalendarListRow(
                    key: ValueKey(cal.id),
                    colour: parseDataColour(cal.color),
                    name: cal.name,
                    caption: cal.source_ == CalendarOutSource_Enum.mac ? cal.accountCaption : null,
                    shown: visibility.isVisible(cal.id),
                    onChanged: (show) => visibility.setHidden(cal.id, !show).catchError((Object _) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text(saveFailed)));
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
