import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'calendar_model.dart';
import 'month_content.dart';

/// The Month section: the [MonthGrid] with its header, the Notices above the grid for every source that
/// does not read all the days on screen, and the selected day's [DayList] beside the grid (wide) or under
/// it (narrow). Calendars hidden on this device are left out of both. Read-only.
///
/// When the month's events could not be read and nothing older is here, the day list's place holds an
/// error that says so, with Retry ([onRetry]), and the grid shows its days as not shown rather than empty.
class MonthPage extends StatelessWidget {
  const MonthPage({
    super.key,
    required this.data,
    required this.hidden,
    required this.today,
    required this.month,
    required this.selected,
    required this.firstDayOfWeek,
    required this.onSelected,
    required this.onMonthChanged,
    required this.onNoticeAction,
    this.gridFocusNode,
    this.onRetry,
  });

  final CalendarData data;

  /// The calendars hidden on this device.
  final Set<String> hidden;

  final DateTime today;
  final DateTime month;
  final DateTime selected;
  final int firstDayOfWeek;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<NoticeAction> onNoticeAction;
  final FocusNode? gridFocusNode;

  /// Read the month again after it failed; null while the host cannot be reached (the app frame says so),
  /// and then no error is shown here.
  final VoidCallback? onRetry;

  static const title = 'Month';
  static const failedTitle = 'myCalendar could not read this month';

  /// The day list's width beside the grid.
  static const dayListWidth = 320.0;

  /// Below this content width the day list goes under the grid.
  static const besideMinWidth = 860.0;

  /// Between the grid and the day list.
  static const gap = MyDataSpace.s6;

  /// The six weeks the grid shows for [month].
  static List<DateTime> visibleDays(DateTime month, int firstDayOfWeek) =>
      MonthGrid.visibleDays(month, firstDayOfWeek);

  @override
  Widget build(BuildContext context) {
    final content = MonthContent.of(
      data: data,
      hidden: hidden,
      month: month,
      firstDayOfWeek: firstDayOfWeek,
      online: onRetry != null,
      onNoticeAction: onNoticeAction,
    );
    final fetched = content.fetched;
    final failure = content.failure;
    final notices = content.notices;

    final grid = MonthGrid(
      month: month,
      today: today,
      selected: selected,
      firstDayOfWeek: firstDayOfWeek,
      onSelected: onSelected,
      onMonthChanged: onMonthChanged,
      events: content.cells,
      isNotRead: content.isNotRead,
      notice: notices.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < notices.length; i++) ...[
                  if (i > 0) const SizedBox(height: Notice.stackGap),
                  notices[i],
                ],
              ],
            ),
      focusNode: gridFocusNode,
    );

    // Until the month's events arrive, the day list waits rather than saying "No events".
    final Widget dayList = failure != null
        ? StatusPanel(
            kind: StatusPanelKind.error,
            title: failedTitle,
            message: '$failure Try again in a moment.',
            actions: [Button(label: AppConnection.retryText, variant: ButtonVariant.filled, onPressed: onRetry)],
          )
        : fetched == null
        ? const SizedBox.shrink()
        : DayList(
            days: [selected],
            today: today,
            events: fetched.events,
            sources: content.ranges,
            hiddenCalendarIds: hidden,
          );

    return PageScaffold(
      title: title,
      fullWidth: true,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= besideMinWidth) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: grid),
                  const SizedBox(width: gap),
                  // Level with the month's title row, so the day's heading starts where the header does.
                  SizedBox(
                    width: dayListWidth,
                    child: Padding(
                      padding: EdgeInsets.only(top: _dayListTopFor(MediaQuery.textScalerOf(context))),
                      child: dayList,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [grid, const SizedBox(height: gap), dayList],
            );
          },
        ),
      ],
    );
  }

  /// Beside the grid, the day list's group lines up with the top of the notices or the grid: under the
  /// month's header row (`control-height` and the header's gap), less the day's heading above the group.
  static double _dayListTopFor(TextScaler scaler) => (MyDataSize.controlHeight +
          MonthGrid.sectionGap -
          scaler.scale(MyDataType.label.fontSize!) * MyDataType.label.height! -
          GroupedList.headingPadding.bottom)
      .clamp(0.0, double.infinity);
}
