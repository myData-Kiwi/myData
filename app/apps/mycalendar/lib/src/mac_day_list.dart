import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The selected day's events in the Mac frame, beside the month: the heading ([formatDayHeading]) in
/// `title`, then one row per event as Calendar.app lists a day: the calendar's [DataBar], the title in
/// `body`, the times ([EventRow.whenLabel]) and the caption ([eventCaption]: the zone's times, "Day 2 of 3",
/// the location and always the calendar's name, then its source when the same event shows twice) in
/// `caption` and `secondary-label`, rows divided by `separator` hairlines. The same words and rules as
/// [DayList]: hidden calendars are left out by the caller, and a day a source does not read ends with
/// [DayList.notShownLine]; "No events" only when every source reads the day. Its text can be selected. Read-only: rows are not targets.
class MacDayList extends StatelessWidget {
  const MacDayList({
    super.key,
    required this.day,
    required this.today,
    required this.events,
    this.sources = const [],
    this.use24HourFormat,
  });

  final DateTime day;
  final DateTime today;

  /// The events in shown calendars; those on [day] are listed.
  final List<EventItem> events;

  /// The sources with a shown calendar, and the days each reads.
  final List<EventSourceRange> sources;
  final bool? use24HourFormat;

  /// The heading's band: as tall as the month's title row beside it.
  static const headingHeight = MyDataMacSize.toolbarHeight;

  /// Across a row.
  static EdgeInsets rowPadding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(4), vertical: look.space(2));

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final use24 = use24HourFormat ?? MediaQuery.alwaysUse24HourFormatOf(context);
    final shown = eventsOnDay(events, day);
    final unread = [
      for (final s in sources)
        if (!s.reads(day)) s.name,
    ];
    final twice = repeatedEvents(shown);
    final rows = <Widget>[
      for (final e in shown)
        _Row(
          key: e.id == null ? null : ValueKey(e.id),
          event: e,
          day: day,
          use24HourFormat: use24,
          withSource: twice.contains(e),
        ),
      for (final name in unread) _Line(DayList.notShownLine(name)),
      if (shown.isEmpty && unread.isEmpty) const _Line(DayList.noEvents),
    ];
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.only(bottom: context.space(4)),
        children: [
          SizedBox(
            height: headingHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space(4)),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  header: true,
                  child: Text(formatDayHeading(day, today: today),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: context.macLook.title.copyWith(color: mac.label)),
                ),
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsetsDirectional.only(start: context.space(4)),
                child: Divider(height: 1, thickness: 1, color: mac.separator),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.event,
    required this.day,
    required this.use24HourFormat,
    required this.withSource,
  });

  final EventItem event;
  final DateTime day;
  final bool use24HourFormat;

  /// The same event shows twice on the day: the caption ends with its source.
  final bool withSource;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final title = event.title.trim();
    final when = eventWhen(event, day, use24HourFormat: use24HourFormat) ?? (time: '', under: null);
    final caption = eventCaption(event, day, use24HourFormat: use24HourFormat, withSource: withSource);
    final small = context.macLook.caption.copyWith(color: mac.secondaryLabel);
    return MergeSemantics(
      child: Padding(
        padding: MacDayList.rowPadding(context.look),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DataBar(colour: event.calendarColour),
              SizedBox(width: context.space(2)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? EventRow.noTitle : title,
                      maxLines: EventRow.titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: context.macLook.bodyEmphasized.copyWith(color: title.isEmpty ? mac.secondaryLabel : mac.label),
                    ),
                    Text(EventRow.whenLabel(when), style: small),
                    Text(caption, style: small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: MacDayList.rowPadding(context.look),
    child: Text(text, style: context.macLook.secondary(context.macLook.body).copyWith(color: context.mac.secondaryLabel)),
  );
}
