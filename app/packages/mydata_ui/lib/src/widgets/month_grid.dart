import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'button.dart';
import 'data_colour.dart';
import 'pressable.dart';

/// One event on one day of a [MonthGrid]: what the cell needs to draw it and to name its calendar.
///
/// The caller decides which days an event falls on, in this device's time zone (an all-day event keeps its
/// dates), and passes it under each of those days.
@immutable
class MonthGridEvent {
  const MonthGridEvent({
    required this.title,
    required this.calendarName,
    this.colour,
    this.allDay = false,
    this.start,
  });

  /// The event's title; empty shows [MonthGrid.noTitle] in `ink-muted`.
  final String title;

  /// The name of the calendar the event is in. It is not drawn in the cell, but it is in the cell's
  /// accessible name (design/components/DataColour: "Never the only signal").
  final String calendarName;

  /// The calendar's colour from the host ([parseDataColour]); null for none (`line-strong`).
  final Color? colour;

  /// An all-day event, or a day between the first and last of a longer one: listed before timed events.
  final bool allDay;

  /// When it starts, in this device's time zone, for the order within the day. Null sorts first among the
  /// timed events.
  final DateTime? start;
}

/// A month as a grid of seven columns, with today marked, one day selected and each day's events
/// (design/components/MonthGrid).
///
/// - **Above the grid:** the month and year in `title`, a tonal "Today" button, and the previous and next
///   buttons: icons only, `control-height` square, named "Previous month" and "Next month". The title
///   wraps between words beside the buttons; when one of its words would not fit there (a large text size
///   on a phone), it takes its own line above them. The optional [notice] (a [Notice] giving the range
///   myData reads) sits between them and the grid.
/// - **The grid** is one `surface` group with `radius-lg` and `shadow-1`, as wide as it is given, cells
///   separated by `line` dividers. Short weekday names in `caption` and `ink-muted` head the columns. It
///   always shows six weeks, starting on [firstDayOfWeek] (the locale's when null), filled from the months
///   before and after.
/// - **A cell:** `space-2` padding, the day number at its top start in `body`, then up to three event lines:
///   a [DataBar] and the title in `caption` and `ink`, cut short with an ellipsis. All-day events come
///   first, then by start time. With more than three events, the third line is "+n" in `ink-muted`. At
///   least twice `row-height` tall.
/// - **Under 600px** (the window, as [AppFrame] decides): cells are `row-height` tall and show up to three
///   [DataDot]s, or two dots and "+n", instead of titles.
/// - **States, from the bottom up:** the fill (`surface-sunken` for a day myData does not read, else
///   `accent-soft` when selected), the number (an `accent` disc with `on-accent` `body-strong` text for
///   today; `ink-muted` for a day not read or outside the month, except that a selected day outside the
///   month is `ink`), then the selection ring (2px `ink` inside the cell's edge) or, on a day that is not
///   selected, the hover edge (1px `line-strong`, over `fast`, no fill), then the focus ring (2px `focus`,
///   inside the selection ring). A day not read shows no events. Days outside the month show theirs in
///   `ink-muted`.
/// - **Keyboard:** the grid is one tab stop and selection follows focus. The arrow keys move the selection
///   by a day or a week, and Home and End to the start and end of the week; when the selection leaves the
///   six weeks shown, [onMonthChanged] asks for the month it moved into. Page Up and Page Down move the
///   selection by a month and show the month it lands in. The previous and next buttons show the month
///   before or after the one shown and move the selection into it, keeping its day of the month. Either
///   way the selected (and focused) day is always on screen. Pressing a cell selects it without changing
///   the month.
/// - **Accessible names:** each cell is named by [dayLabel] ("Friday 16 October, 4 events in Work, Personal
///   and Family") and announced as selected or not; the grid is named by the month ("October 2026").
///   While the grid has keyboard focus, the selected cell is the focused node, so a screen reader follows
///   the selection as the keys move it (the preview's roving `tabindex`).
/// - **Text size:** the number's box, today's disc, the bars and the dot line grow with the system text
///   size, and the cells grow to hold them.
/// - Changing the month swaps the days in place with a `fast` fade, with no slide (also with reduced
///   motion, since a fade does not move).
/// - Read-only: the grid shows events; it never edits them.
class MonthGrid extends StatefulWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.onSelected,
    required this.onMonthChanged,
    this.firstDayOfWeek,
    this.events = const {},
    this.isNotRead,
    this.notice,
    this.focusNode,
    this.autofocus = false,
  }) : assert(firstDayOfWeek == null || (firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday),
            'firstDayOfWeek is a DateTime weekday: DateTime.monday (1) to DateTime.sunday (7)');

  /// The month shown: any date in it. Only the year and month are used.
  final DateTime month;

  /// Today, in this device's time zone. Only the date is used.
  final DateTime today;

  /// The selected day. Only the date is used.
  final DateTime selected;

  /// Called with the newly selected day (local midnight) when a cell is pressed or a key moves the selection,
  /// and with the day the Today, previous and next buttons select.
  final ValueChanged<DateTime> onSelected;

  /// Called with the first day of the month to show when the Today, previous or next button is pressed, on
  /// Page Up and Page Down (the month the new selection is in), and when an arrow key or Home or End moves
  /// the selection out of the six weeks shown. [onSelected] is called first.
  final ValueChanged<DateTime> onMonthChanged;

  /// The first day of the week, as a [DateTime] weekday ([DateTime.monday] to [DateTime.sunday]). Null takes
  /// the device locale's ([firstDayOfWeekFor]).
  final int? firstDayOfWeek;

  /// Each day's events, keyed by the day (the time of day in a key is ignored). The order within a day does
  /// not matter: the grid sorts all-day events first, then by start time.
  final Map<DateTime, List<MonthGridEvent>> events;

  /// Whether myData does not read [day] from any source with a shown calendar: its cell is `surface-sunken`,
  /// shows no events and is named "events not shown". Null: every day is read.
  final bool Function(DateTime day)? isNotRead;

  /// Shown between the header and the grid, `space-4` above the grid: the [Notice] giving the range myData
  /// reads, so the sunken fill is never the only signal.
  final Widget? notice;

  /// The grid's focus node (its one tab stop).
  final FocusNode? focusNode;
  final bool autofocus;

  /// Under this window width, cells show dots ([AppFrame]'s phone layout starts below it too).
  static const compactWidth = 600.0;

  /// Always six weeks, so the grid keeps its height from month to month.
  static const weeks = 6;

  /// Spec: "at most three lines" of events in a cell, or of dots under 600px.
  static const maxLines = 3;

  /// Spec: "a 28px `accent` disc" behind today's number. The number's box is this size on every day, at
  /// the default text size; it grows with the text ([numberBoxSize]).
  static const todayDiameter = 28.0;

  /// The side of a day number's box, and today's disc, at [textScaler]: [todayDiameter] scaled, and never
  /// less than one scaled line of `body`, so the number always fits inside the disc.
  static double numberBoxSize(TextScaler textScaler) => math.max(
      textScaler.scale(todayDiameter), textScaler.scale(MyDataType.body.fontSize!) * MyDataType.body.height!);

  /// One line of `caption` at [textScaler]: the height of an event's bar ("as tall as the text it marks")
  /// and, under 600px, of the line of dots.
  static double captionLineHeight(TextScaler textScaler) =>
      textScaler.scale(MyDataType.caption.fontSize!) * MyDataType.caption.height!;

  /// The selection ring: "2px `ink` inside the cell's edge".
  static const selectionRingWidth = 2.0;

  /// The hover edge: "a 1px `line-strong` edge inside the cell".
  static const hoverEdgeWidth = 1.0;

  /// The focus ring: "2px `focus`", drawn inside the selection ring.
  static const focusRingWidth = 2.0;

  /// Spec: a cell has `space-2` padding.
  static const cellPadding = MyDataSpace.s2;

  /// Under 600px: the preview's 4px (`space-1`), so the number and the dots fit a `row-height` cell.
  static const compactCellPadding = MyDataSpace.s1;

  /// Between the number and the event lines, and between lines (preview: `gap:4px`).
  static const lineGap = MyDataSpace.s1;

  /// Between a bar or dot and the next thing on its line (preview: `gap:4px`).
  static const markGap = MyDataSpace.s1;

  /// Spec: "on desktop, a cell is at least twice `row-height` tall".
  static const cellMinHeight = 2 * MyDataSize.rowHeight;

  /// Spec: "under 600px, cells are `row-height` tall".
  static const compactCellHeight = MyDataSize.rowHeight;

  /// Between the header's parts (preview: `gap:8px`).
  static const headerGap = MyDataSpace.s2;

  /// Below the header, and below the [notice] (preview: `margin:0 0 16px`).
  static const sectionGap = MyDataSpace.s4;

  /// The divider between cells, as between grouped-list rows.
  static const dividerWidth = 1.0;

  /// Words the grid shows or speaks.
  static const todayLabel = 'Today';
  static const previousMonthLabel = 'Previous month';
  static const nextMonthLabel = 'Next month';
  static const noTitle = 'No title';

  static const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// The full weekday name of [weekday] (a [DateTime] weekday): "Monday".
  static String weekdayName(int weekday) => _weekdayNames[weekday - 1];

  /// The short weekday name that heads a column: "Mon".
  static String weekdayShortName(int weekday) => _weekdayNames[weekday - 1].substring(0, 3);

  /// The month and year above the grid, and the grid's accessible name: "October 2026".
  static String monthTitle(DateTime month) => '${_monthNames[month.month - 1]} ${month.year}';

  /// A cell's accessible name (spec, "Each cell's accessible name"): the full date, "today" for today, then
  /// "events not shown" for a day not read, "no events", or the count and the calendars of [events], each
  /// named once in the order the events appear: "Tuesday 13 October, today, 2 events in Family and Choir".
  /// [events] must already be in display order ([sortEvents]).
  static String dayLabel(DateTime day, {bool today = false, bool notRead = false, List<MonthGridEvent> events = const []}) {
    final date = '${weekdayName(day.weekday)} ${day.day} ${_monthNames[day.month - 1]}';
    final String what;
    if (notRead) {
      what = 'events not shown';
    } else if (events.isEmpty) {
      what = 'no events';
    } else {
      final calendars = <String>[];
      for (final e in events) {
        if (!calendars.contains(e.calendarName)) calendars.add(e.calendarName);
      }
      what = '${events.length} ${events.length == 1 ? 'event' : 'events'} in ${joinList(calendars)}';
    }
    return [date, if (today) 'today', what].join(', ');
  }

  /// Joins names as English joins a list: "Work", "Work and Family", "Work, Personal and Family".
  static String joinList(List<String> items) => switch (items.length) {
        0 => '',
        1 => items.single,
        _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
      };

  /// [events] in the order a cell shows them: all-day first, then by start time (no start first among the
  /// timed ones), keeping the given order between equals.
  static List<MonthGridEvent> sortEvents(List<MonthGridEvent> events) {
    final indexed = [for (var i = 0; i < events.length; i++) (i, events[i])];
    indexed.sort((a, b) {
      final ea = a.$2, eb = b.$2;
      if (ea.allDay != eb.allDay) return ea.allDay ? -1 : 1;
      if (!ea.allDay) {
        final sa = ea.start, sb = eb.start;
        if (sa == null && sb != null) return -1;
        if (sa != null && sb == null) return 1;
        if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
      }
      return a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Regions whose week starts on Sunday or Saturday (Unicode CLDR `weekData`, `firstDay`); every other
  /// region starts on Monday.
  static const _sundayFirst = {
    'AG', 'AS', 'BD', 'BR', 'BS', 'BT', 'BW', 'BZ', 'CA', 'CN', 'CO', 'DM', 'DO', 'ET', 'GT', 'GU', 'HK', //
    'HN', 'ID', 'IL', 'IN', 'JM', 'JP', 'KE', 'KH', 'KR', 'LA', 'MH', 'MM', 'MO', 'MT', 'MX', 'MZ', 'NI', //
    'NP', 'PA', 'PE', 'PH', 'PK', 'PR', 'PT', 'PY', 'SA', 'SG', 'SV', 'TH', 'TT', 'TW', 'UM', 'US', 'VE', //
    'VI', 'WS', 'YE', 'ZA', 'ZW',
  };
  static const _saturdayFirst = {
    'AE', 'AF', 'BH', 'DJ', 'DZ', 'EG', 'IQ', 'IR', 'JO', 'KW', 'LY', 'OM', 'QA', 'SD', 'SY',
  };

  /// The first day of the week in [locale]'s region, as a [DateTime] weekday. A locale with no region
  /// starts on Monday (ISO 8601).
  static int firstDayOfWeekFor(Locale locale) {
    final region = locale.countryCode?.toUpperCase();
    if (region == null) return DateTime.monday;
    if (_sundayFirst.contains(region)) return DateTime.sunday;
    if (_saturdayFirst.contains(region)) return DateTime.saturday;
    if (region == 'MV') return DateTime.friday;
    return DateTime.monday;
  }

  /// The 42 days the grid shows for [month], starting on [firstDayOfWeek]: the week holding the 1st first.
  static List<DateTime> visibleDays(DateTime month, int firstDayOfWeek) {
    final first = DateTime.utc(month.year, month.month);
    final back = (first.weekday - firstDayOfWeek + 7) % 7;
    return [for (var i = 0; i < weeks * 7; i++) DateTime(first.year, first.month, first.day - back + i)];
  }

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

/// A day as an integer (yyyymmdd), so lookups ignore the time of day and whether a DateTime is UTC.
int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// [day] moved by [months], its day of the month kept or cut to the new month's last day.
DateTime _addMonths(DateTime day, int months) {
  final first = DateTime.utc(day.year, day.month + months);
  return DateTime(first.year, first.month, math.min(day.day, _daysIn(first.year, first.month)));
}

class _MoveDaysIntent extends Intent {
  const _MoveDaysIntent(this.days);
  final int days;
}

/// Left and right, which follow the text direction.
class _MoveSidewaysIntent extends Intent {
  const _MoveSidewaysIntent(this.forward);
  final bool forward;
}

class _MoveMonthsIntent extends Intent {
  const _MoveMonthsIntent(this.months);
  final int months;
}

class _WeekEdgeIntent extends Intent {
  const _WeekEdgeIntent(this.end);
  final bool end;
}

class _MonthGridState extends State<MonthGrid> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'MonthGrid'));

  /// Keyboard focus is shown (Flutter's focus highlight).
  bool _focusHighlight = false;

  /// The grid took focus from a press, not the keyboard: no focus ring until a key is used (as the web's
  /// `:focus-visible`).
  bool _pointerFocus = false;

  int get _firstDay => widget.firstDayOfWeek ?? MonthGrid.firstDayOfWeekFor(View.of(context).platformDispatcher.locale);

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _select(DateTime day, {bool fromKey = false}) {
    if (fromKey && _pointerFocus) setState(() => _pointerFocus = false);
    final target = _date(day);
    widget.onSelected(target);
    final visible = MonthGrid.visibleDays(widget.month, _firstDay);
    final k = _key(target);
    if (k < _key(visible.first) || k > _key(visible.last)) {
      widget.onMonthChanged(DateTime(target.year, target.month));
    }
  }

  void _moveDays(int days) {
    final s = widget.selected;
    _select(DateTime(s.year, s.month, s.day + days), fromKey: true);
  }

  /// Page Up and Page Down, driven by the selection: it moves by a month, and the grid shows the month it
  /// lands in, so the selected (and focused) day is always on screen, also when it was a day from the month
  /// before or after the one shown.
  void _pageMonths(int months) {
    if (_pointerFocus) setState(() => _pointerFocus = false);
    final target = _addMonths(widget.selected, months);
    widget.onSelected(target);
    widget.onMonthChanged(DateTime(target.year, target.month));
  }

  /// The previous and next buttons, driven by the month: the grid shows the month before or after the one
  /// shown, and the selection moves into it, keeping its day of the month (cut to the month's last day).
  void _stepMonth(int months) {
    final shown = DateTime.utc(widget.month.year, widget.month.month + months);
    final day = math.min(widget.selected.day, _daysIn(shown.year, shown.month));
    widget.onSelected(DateTime(shown.year, shown.month, day));
    widget.onMonthChanged(DateTime(shown.year, shown.month));
  }

  void _weekEdge(bool end) {
    final s = widget.selected;
    final fromStart = (s.weekday - _firstDay + 7) % 7;
    _moveDays(end ? 6 - fromStart : -fromStart);
  }

  void _goToToday() {
    final t = _date(widget.today);
    widget.onSelected(t);
    widget.onMonthChanged(DateTime(t.year, t.month));
  }

  void _pressDay(DateTime day) {
    if (!_node.hasFocus) {
      _pointerFocus = true;
      _node.requestFocus();
    }
    widget.onSelected(_date(day));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < MonthGrid.compactWidth;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final firstDay = _firstDay;
    final month = DateTime(widget.month.year, widget.month.month);

    final grid = FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      mouseCursor: MouseCursor.defer,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveSidewaysIntent(false),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveSidewaysIntent(true),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveDaysIntent(-7),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveDaysIntent(7),
        SingleActivator(LogicalKeyboardKey.pageUp): _MoveMonthsIntent(-1),
        SingleActivator(LogicalKeyboardKey.pageDown): _MoveMonthsIntent(1),
        SingleActivator(LogicalKeyboardKey.home): _WeekEdgeIntent(false),
        SingleActivator(LogicalKeyboardKey.end): _WeekEdgeIntent(true),
      },
      actions: {
        _MoveSidewaysIntent: CallbackAction<_MoveSidewaysIntent>(
            onInvoke: (i) => _moveDays((i.forward != rtl) ? 1 : -1)),
        _MoveDaysIntent: CallbackAction<_MoveDaysIntent>(onInvoke: (i) => _moveDays(i.days)),
        _MoveMonthsIntent: CallbackAction<_MoveMonthsIntent>(onInvoke: (i) => _pageMonths(i.months)),
        _WeekEdgeIntent: CallbackAction<_WeekEdgeIntent>(onInvoke: (i) => _weekEdge(i.end)),
      },
      onShowFocusHighlight: (v) => setState(() => _focusHighlight = v),
      // The grid's own node is not the focused one for a screen reader: the selected cell is (below).
      includeFocusSemantics: false,
      onFocusChange: (focused) => setState(() {
        if (!focused) _pointerFocus = false;
      }),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: MonthGrid.monthTitle(month),
        child: _Grid(
          month: month,
          firstDay: firstDay,
          today: _date(widget.today),
          selected: _date(widget.selected),
          events: {for (final e in widget.events.entries) _key(e.key): e.value},
          isNotRead: widget.isNotRead,
          compact: compact,
          showFocus: _focusHighlight && !_pointerFocus,
          hasFocus: _node.hasFocus,
          onPressed: _pressDay,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: MonthGrid.monthTitle(month),
          onToday: _goToToday,
          onPrevious: () => _stepMonth(-1),
          onNext: () => _stepMonth(1),
        ),
        const SizedBox(height: MonthGrid.sectionGap),
        if (widget.notice != null) ...[widget.notice!, const SizedBox(height: MonthGrid.sectionGap)],
        grid,
      ],
    );
  }
}

/// The month and year, the Today button, and the previous and next buttons.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onToday, required this.onPrevious, required this.onNext});
  final String title;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return _HeaderLayout(
      // Never cut short: on a narrow phone "September 2026" wraps after the month, and a word that would
      // not fit beside the buttons moves the title to its own line rather than breaking.
      title: Semantics(header: true, child: Text(title, style: MyDataType.title.copyWith(color: c.ink))),
      buttons: Row(mainAxisSize: MainAxisSize.min, children: [
        Button(label: MonthGrid.todayLabel, onPressed: onToday),
        const SizedBox(width: MonthGrid.headerGap),
        _IconButton(
            icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            label: MonthGrid.previousMonthLabel,
            onPressed: onPrevious),
        const SizedBox(width: MonthGrid.headerGap),
        _IconButton(
            icon: rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            label: MonthGrid.nextMonthLabel,
            onPressed: onNext),
      ]),
    );
  }
}

/// The header's title and buttons, [MonthGrid.headerGap] apart. On one line when every word of the title
/// fits beside the buttons: the title takes the room they leave (wrapping between words), the buttons sit
/// at the end edge, both centred vertically. Otherwise the title has its own line and the buttons sit under
/// it at the end edge. A [Row] would break a word that does not fit; this measures the title's longest
/// word (its minimum intrinsic width) first.
class _HeaderLayout extends MultiChildRenderObjectWidget {
  _HeaderLayout({required Widget title, required Widget buttons}) : super(children: [title, buttons]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeaderLayout(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderHeaderLayout renderObject) =>
      renderObject.textDirection = Directionality.of(context);
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

typedef _HeaderLines = ({Size size, bool stacked, Size titleSize, Size buttonsSize});

class _RenderHeaderLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  _RenderHeaderLayout(this._textDirection);

  static const _gap = MonthGrid.headerGap;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _title => firstChild!;
  RenderBox get _buttons => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) child.parentData = _HeaderParentData();
  }

  /// Whether the title goes on its own line in a header [width] wide, beside buttons [buttonsWidth] wide.
  bool _stacks(double width, double buttonsWidth) =>
      width - buttonsWidth - _gap < _title.getMinIntrinsicWidth(double.infinity);

  _HeaderLines _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final buttonsSize = layoutChild(_buttons, BoxConstraints(maxWidth: constraints.maxWidth));
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _title.getMaxIntrinsicWidth(double.infinity) + _gap + buttonsSize.width;
    final stacked = _stacks(width, buttonsSize.width);
    final titleWidth = math.max(0.0, stacked ? width : width - buttonsSize.width - _gap);
    final titleSize = layoutChild(_title, BoxConstraints.tightFor(width: titleWidth));
    final height = stacked
        ? titleSize.height + _gap + buttonsSize.height
        : math.max(titleSize.height, buttonsSize.height);
    return (
      size: constraints.constrain(Size(width, height)),
      stacked: stacked,
      titleSize: titleSize,
      buttonsSize: buttonsSize,
    );
  }

  @override
  void performLayout() {
    final l = _compute(constraints, ChildLayoutHelper.layoutChild);
    size = l.size;
    final ltr = _textDirection == TextDirection.ltr;
    double startX(Size child) => ltr ? 0 : size.width - child.width;
    double endX(Size child) => ltr ? size.width - child.width : 0;
    (_title.parentData! as _HeaderParentData).offset =
        Offset(startX(l.titleSize), l.stacked ? 0 : (size.height - l.titleSize.height) / 2);
    (_buttons.parentData! as _HeaderParentData).offset = Offset(endX(l.buttonsSize),
        l.stacked ? l.titleSize.height + _gap : (size.height - l.buttonsSize.height) / 2);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_title.getMinIntrinsicWidth(double.infinity), _buttons.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(double.infinity) + _gap + _buttons.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    final buttonsWidth = _buttons.getMaxIntrinsicWidth(double.infinity);
    final buttonsHeight = _buttons.getMaxIntrinsicHeight(buttonsWidth);
    if (!width.isFinite) return math.max(_title.getMaxIntrinsicHeight(double.infinity), buttonsHeight);
    if (_stacks(width, buttonsWidth)) return _title.getMaxIntrinsicHeight(width) + _gap + buttonsHeight;
    return math.max(_title.getMaxIntrinsicHeight(math.max(0.0, width - buttonsWidth - _gap)), buttonsHeight);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}

/// A plain icon-only button, `control-height` square, its icon in `ink` (preview: `.ib`).
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
        onPressed: onPressed,
        borderRadius: MyDataRadii.control,
        semanticLabel: label,
        child: SizedBox.square(
            dimension: MyDataSize.controlHeight,
            child: Center(child: Icon(icon, size: MyDataSize.icon, color: context.colors.ink))),
      );
}

/// The weekday headings and the six weeks of cells, on one grouped-list group.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.month,
    required this.firstDay,
    required this.today,
    required this.selected,
    required this.events,
    required this.isNotRead,
    required this.compact,
    required this.showFocus,
    required this.hasFocus,
    required this.onPressed,
  });

  final DateTime month;
  final int firstDay;
  final DateTime today;
  final DateTime selected;
  final Map<int, List<MonthGridEvent>> events;
  final bool Function(DateTime day)? isNotRead;
  final bool compact;
  final bool showFocus;

  /// The grid has keyboard focus (shown or not): the selected cell is then the focused semantics node.
  final bool hasFocus;
  final ValueChanged<DateTime> onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = MonthGrid.visibleDays(month, firstDay);
    final divider = Container(height: MonthGrid.dividerWidth, color: c.line);
    final weekdayStyle = MyDataType.caption.copyWith(color: c.inkMuted);

    Widget columns(List<Widget> children) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Container(width: MonthGrid.dividerWidth, color: c.line),
            Expanded(child: children[i]),
          ],
        ]);

    final headings = Row(children: [
      for (var i = 0; i < 7; i++)
        Expanded(
            child: Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(vertical: MonthGrid.cellPadding, horizontal: MonthGrid.compactCellPadding)
                    : const EdgeInsets.all(MonthGrid.cellPadding),
                child: Text(MonthGrid.weekdayShortName((firstDay - 1 + i) % 7 + 1),
                    semanticsLabel: MonthGrid.weekdayName((firstDay - 1 + i) % 7 + 1),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: weekdayStyle))),
    ]);

    const corner = Radius.circular(MyDataRadius.lg);
    final weeksBody = Column(
      key: ValueKey(_key(month)),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var w = 0; w < MonthGrid.weeks; w++) ...[
          divider,
          IntrinsicHeight(
            child: columns([
              for (var d = 0; d < 7; d++)
                _Cell(
                  day: days[w * 7 + d],
                  inMonth: days[w * 7 + d].month == month.month,
                  today: _key(days[w * 7 + d]) == _key(today),
                  selected: _key(days[w * 7 + d]) == _key(selected),
                  notRead: isNotRead?.call(days[w * 7 + d]) ?? false,
                  events: events[_key(days[w * 7 + d])] ?? const [],
                  compact: compact,
                  showFocus: showFocus,
                  gridFocused: hasFocus,
                  shape: w == MonthGrid.weeks - 1 && d == 0
                      ? const BorderRadiusDirectional.only(bottomStart: corner)
                      : w == MonthGrid.weeks - 1 && d == 6
                          ? const BorderRadiusDirectional.only(bottomEnd: corner)
                          : BorderRadiusDirectional.zero,
                  onPressed: onPressed,
                ),
            ]),
          ),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg, boxShadow: context.shadows.shadow1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: headings),
          AnimatedSwitcher(
            duration: MyDataMotion.fast,
            switchInCurve: MyDataMotion.standard,
            switchOutCurve: MyDataMotion.standard,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: weeksBody,
          ),
        ],
      ),
    );
  }
}

/// One day: its fill, number, events, and the selection, hover and focus marks.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.notRead,
    required this.events,
    required this.compact,
    required this.showFocus,
    required this.gridFocused,
    required this.shape,
    required this.onPressed,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;
  final bool selected;
  final bool notRead;
  final List<MonthGridEvent> events;
  final bool compact;
  final bool showFocus;
  final bool gridFocused;
  final BorderRadiusDirectional shape;
  final ValueChanged<DateTime> onPressed;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = widget.shape.resolve(Directionality.of(context));
    final sorted = MonthGrid.sortEvents(widget.events);
    final shown = widget.notRead ? const <MonthGridEvent>[] : sorted;
    final ground = widget.notRead
        ? DataGround.surfaceSunken
        : (widget.selected ? DataGround.accentSoft : DataGround.surface);
    final fill = widget.notRead ? c.surfaceSunken : (widget.selected ? c.accentSoft : null);
    final muted = !widget.inMonth;

    // The number: today's disc; else ink-muted when not read, ink when selected, ink-muted outside the month.
    final Color numberColour = widget.today
        ? c.onAccent
        : widget.notRead
            ? c.inkMuted
            : widget.selected
                ? c.ink
                : (muted ? c.inkMuted : c.ink);
    final scaler = MediaQuery.textScalerOf(context);
    final numberBox = MonthGrid.numberBoxSize(scaler);
    final number = Container(
      width: numberBox,
      height: numberBox,
      alignment: Alignment.center,
      decoration: widget.today ? BoxDecoration(color: c.accent, shape: BoxShape.circle) : null,
      child: Text('${widget.day.day}',
          maxLines: 1,
          softWrap: false,
          style: (widget.today ? MyDataType.bodyStrong : MyDataType.body).copyWith(color: numberColour)),
    );

    final overflow = shown.length > MonthGrid.maxLines;
    final visible = overflow ? shown.sublist(0, MonthGrid.maxLines - 1) : shown;
    final more = overflow
        ? Text('+${shown.length - visible.length}',
            maxLines: 1, softWrap: false, style: MyDataType.caption.copyWith(color: c.inkMuted))
        : null;
    final captionLine = MonthGrid.captionLineHeight(scaler);

    final List<Widget> marks;
    if (widget.compact) {
      marks = [
        if (shown.isNotEmpty)
          // At least one caption line tall, dots centred on it; at a large text size "+n" goes under the
          // dots when the cell is too narrow for both, rather than being cut off.
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: captionLine),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MonthGrid.markGap,
              children: [
                for (final e in visible) DataDot(colour: e.colour, ground: ground),
                ?more,
              ],
            ),
          ),
      ];
    } else {
      final textColour = muted ? c.inkMuted : c.ink;
      marks = [
        for (final e in visible)
          Row(children: [
            DataBar(colour: e.colour, ground: ground, height: captionLine),
            const SizedBox(width: MonthGrid.markGap),
            Expanded(
                child: Text(e.title.isEmpty ? MonthGrid.noTitle : e.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: MyDataType.caption.copyWith(color: e.title.isEmpty ? c.inkMuted : textColour))),
          ]),
        ?more,
      ];
    }

    final content = Padding(
      padding: EdgeInsets.all(widget.compact ? MonthGrid.compactCellPadding : MonthGrid.cellPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          number,
          // Under 600px the dots sit right under the number's box (28px at the default text size), whose
          // own space below the digits is the gap, so the number and the dots fit a `row-height` cell.
          for (final m in marks) ...[if (!widget.compact) const SizedBox(height: MonthGrid.lineGap), m],
        ],
      ),
    );

    final cell = ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.compact ? MonthGrid.compactCellHeight : MonthGrid.cellMinHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, borderRadius: shape),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: _hovered && !widget.selected ? 1 : 0),
          duration: MyDataMotion.fast,
          curve: MyDataMotion.standard,
          builder: (context, hover, child) => CustomPaint(
            foregroundPainter: _MarksPainter(
              shape: shape,
              hover: hover,
              hoverColour: c.lineStrong,
              selected: widget.selected,
              ringColour: c.ink,
              focused: widget.selected && widget.showFocus,
              focusColour: FocusRing.colourOf(c),
            ),
            child: child,
          ),
          child: Align(alignment: AlignmentDirectional.topStart, widthFactor: 1, heightFactor: 1, child: content),
        ),
      ),
    );

    return Semantics(
      container: true,
      selected: widget.selected,
      // Selection follows focus: while the grid has keyboard focus, the selected cell is the focused node,
      // so a screen reader moves to it and reads it as the keys move the selection.
      focusable: widget.selected ? true : null,
      focused: widget.selected ? widget.gridFocused : null,
      label: MonthGrid.dayLabel(widget.day, today: widget.today, notRead: widget.notRead, events: sorted),
      onTap: () => widget.onPressed(widget.day),
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => widget.onPressed(widget.day),
            child: cell,
          ),
        ),
      ),
    );
  }
}

/// Draws a cell's edges, inside its shape: the hover edge (1px `line-strong`, faded by [hover]), or the
/// selection ring (2px `ink`); then the focus ring (2px `focus`) just inside the selection ring.
class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.shape,
    required this.hover,
    required this.hoverColour,
    required this.selected,
    required this.ringColour,
    required this.focused,
    required this.focusColour,
  });

  final BorderRadius shape;
  final double hover;
  final Color hoverColour;
  final bool selected;
  final Color ringColour;
  final bool focused;
  final Color focusColour;

  /// A stroke of [width] whose outer edge is [inset] inside the cell, following its corners.
  void _ring(Canvas canvas, Size size, double inset, double width, Color colour) {
    final d = inset + width / 2;
    final rect = (Offset.zero & size).deflate(d);
    Radius shrink(Radius r) => Radius.circular(math.max(0, r.x - d));
    canvas.drawRRect(
        RRect.fromRectAndCorners(rect,
            topLeft: shrink(shape.topLeft),
            topRight: shrink(shape.topRight),
            bottomLeft: shrink(shape.bottomLeft),
            bottomRight: shrink(shape.bottomRight)),
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (selected) {
      _ring(canvas, size, 0, MonthGrid.selectionRingWidth, ringColour);
    } else if (hover > 0) {
      _ring(canvas, size, 0, MonthGrid.hoverEdgeWidth, hoverColour.withValues(alpha: hoverColour.a * hover));
    }
    if (focused) _ring(canvas, size, MonthGrid.selectionRingWidth, MonthGrid.focusRingWidth, focusColour);
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.shape != shape ||
      old.hover != hover ||
      old.hoverColour != hoverColour ||
      old.selected != selected ||
      old.ringColour != ringColour ||
      old.focused != focused ||
      old.focusColour != focusColour;
}
