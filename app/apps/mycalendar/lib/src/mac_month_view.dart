import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'mac_day_list.dart';
import 'mac_month_grid.dart';
import 'month_content.dart';
import 'month_page.dart';

/// The Month section in the Mac frame, laid out as Calendar.app's month view on macOS 26:
///
/// - **Toolbar:** "‹ Today ›" at the end, with ⌘←, ⌘T and ⌘→. No view switch until a second view exists
///   (Apple ships no disabled view modes; HIG Segmented controls).
/// - **Under it:** the month and year as the pane's title, the Notices for sources that do not read
///   every day shown, then the [MacMonthGrid] filling the window's height.
/// - **Beside it** (under it in a narrow window): the selected day's [MacDayList], or the month's read error
///   with Retry.
///
/// What it shows is [MonthContent]'s, the same as the branded [MonthPage]. Read-only.
class MacMonthView extends StatelessWidget {
  const MacMonthView({
    super.key,
    required this.content,
    required this.today,
    required this.month,
    required this.selected,
    required this.firstDayOfWeek,
    required this.onSelected,
    required this.onMonthChanged,
    this.gridFocusNode,
    this.onRetry,
  });

  final MonthContent content;
  final DateTime today;
  final DateTime month;
  final DateTime selected;
  final int firstDayOfWeek;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final FocusNode? gridFocusNode;

  /// Read the month again after it failed; null while the host cannot be reached.
  final VoidCallback? onRetry;

  static const todayShortcut = '⌘T';
  static const previousShortcut = '⌘←';
  static const nextShortcut = '⌘→';

  /// The day list's width beside the grid.
  static const dayListWidth = MyDataMacSize.listWidth;

  /// Below this width the day list goes under the grid.
  static const besideMinWidth = MyDataMacSize.besideMinWidth;

  /// Each day's events as the cells draw them: in a day list's order ([eventsOnDay]), all day as a chip,
  /// the start time when the event starts that day.
  static Map<DateTime, List<MacCellEvent>> cellEvents(
      List<EventItem> shown, List<DateTime> days, {required bool use24HourFormat}) {
    final out = <DateTime, List<MacCellEvent>>{};
    for (final day in days) {
      final on = eventsOnDay(shown, day);
      if (on.isEmpty) continue;
      out[day] = [
        for (final e in on)
          () {
            final when = eventWhen(e, day, use24HourFormat: use24HourFormat);
            final allDay = when?.time == EventRow.allDayLabel;
            final startsToday = e.start.year == day.year && e.start.month == day.month && e.start.day == day.day;
            return MacCellEvent(
              title: e.title.trim(),
              calendarName: e.calendarName,
              colour: e.calendarColour,
              allDay: allDay,
              time: !allDay && startsToday ? formatEventTime(e.start, use24HourFormat: use24HourFormat) : null,
            );
          }(),
      ];
    }
    return out;
  }

  void _step(int months) {
    final (day, shown) = MacMonthNav.step(month, selected, months);
    onSelected(day);
    onMonthChanged(shown);
  }

  void _today() {
    final t = DateTime(today.year, today.month, today.day);
    onSelected(t);
    onMonthChanged(DateTime(t.year, t.month));
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final failure = content.failure;

    final toolbar = Container(
      height: MyDataMacSize.toolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.toolbarInset),
      color: mac.contentBackground,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MacToolbarGroup(
                  buttons: [
                    MacToolbarGroupButton(
                      icon: rtl ? MyDataIcon.chevronRight : MyDataIcon.chevronLeft,
                      label: MonthGrid.previousMonthLabel,
                      shortcut: previousShortcut,
                      onPressed: () => _step(-1),
                    ),
                    MacToolbarGroupButton(
                      text: MonthGrid.todayLabel,
                      label: MonthGrid.todayLabel,
                      shortcut: todayShortcut,
                      onPressed: _today,
                    ),
                    MacToolbarGroupButton(
                      icon: rtl ? MyDataIcon.chevronLeft : MyDataIcon.chevronRight,
                      label: MonthGrid.nextMonthLabel,
                      shortcut: nextShortcut,
                      onPressed: () => _step(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final m = DateTime(month.year, month.month);
    final title = SizedBox(
      height: MacDayList.headingHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.space(4)),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            header: true,
            label: MonthGrid.monthTitle(m),
            child: ExcludeSemantics(
              child: Text(
                MyDataDates.month(m),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.macLook.paneTitle.copyWith(color: mac.label),
              ),
            ),
          ),
        ),
      ),
    );

    final grid = MacMonthGrid(
      month: m,
      today: today,
      selected: selected,
      firstDayOfWeek: firstDayOfWeek,
      onSelected: onSelected,
      onMonthChanged: onMonthChanged,
      events: cellEvents(content.shown, content.days, use24HourFormat: use24),
      isNotRead: content.isNotRead,
      focusNode: gridFocusNode,
      autofocus: true,
    );

    final monthColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        for (final n in content.notices)
          Padding(
            padding: EdgeInsets.fromLTRB(context.space(4), 0, context.space(4), context.space(2)),
            child: n,
          ),
        Expanded(child: grid),
      ],
    );

    final Widget day = failure != null
        ? Padding(
            padding: const EdgeInsets.only(top: MacDayList.headingHeight),
            child: StatusPanel(
              kind: StatusPanelKind.error,
              title: MonthPage.failedTitle,
              message: '$failure Try again in a moment.',
              actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: onRetry)],
            ),
          )
        : content.fetched == null
        ? const SizedBox.shrink()
        : MacDayList(day: selected, today: today, events: content.shown, sources: content.ranges);

    // The line between the month and the day list: the Mac's separator, or the theme's own line (its colour
    // and width) in a drawn theme that rules its month so (MacMonthGrid.ruled).
    final ruled = !context.isSystemLook && MacMonthGrid.ruled(context.look);
    final line = ruled ? context.look.edges.colour : mac.separator;
    final lineWidth = ruled ? MacMonthGrid.ruleWidth(context.look) : 1.0;
    // Where the month and the day are panels on the window's ground (MacPanel), the ground divides them.
    final panels = MacPanel.shown(context);
    Widget divider({required bool vertical}) => vertical
        ? VerticalDivider(width: lineWidth, thickness: lineWidth, color: line)
        : Divider(height: lineWidth, thickness: lineWidth, color: line);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): _today,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true): () => _step(rtl ? 1 : -1),
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true): () => _step(rtl ? -1 : 1),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= besideMinWidth) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: MacPanel(child: monthColumn)),
                      if (!panels) divider(vertical: true),
                      SizedBox(width: dayListWidth, child: MacPanel(child: day)),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: MacPanel(child: monthColumn)),
                    if (!panels) divider(vertical: false),
                    Expanded(flex: 2, child: MacPanel(child: day)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
