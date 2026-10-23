import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// One event on one day of a [MacMonthGrid], as the cell draws it.
@immutable
class MacCellEvent {
  const MacCellEvent({
    required this.title,
    required this.calendarName,
    this.colour,
    this.allDay = false,
    this.time,
  });

  /// Empty shows [MonthGrid.noTitle].
  final String title;

  /// Not drawn in the cell; in the cell's accessible name, as in [MonthGrid].
  final String calendarName;

  /// The calendar's colour from the host; null for none.
  final Color? colour;

  /// All day on this day (an all-day event, or a middle day of a longer one): drawn as a chip.
  final bool allDay;

  /// The start time on this day's clock, when the event starts on this day.
  final String? time;
}

/// Moves of the month shown, as the toolbar's "‹ Today ›" and the keys make them: the same rules as
/// [MonthGrid]'s header buttons.
abstract final class MacMonthNav {
  static int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  /// The month before or after [month] by [months], and the day in it to select: [selected]'s day of the
  /// month, cut to that month's last day.
  static (DateTime selected, DateTime month) step(DateTime month, DateTime selected, int months) {
    final shown = DateTime.utc(month.year, month.month + months);
    final day = math.min(selected.day, _daysIn(shown.year, shown.month));
    return (DateTime(shown.year, shown.month, day), DateTime(shown.year, shown.month));
  }

  /// [day] moved by [months], keeping its day of the month (cut to the new month's last day).
  static DateTime addMonths(DateTime day, int months) {
    final first = DateTime.utc(day.year, day.month + months);
    return DateTime(first.year, first.month, math.min(day.day, _daysIn(first.year, first.month)));
  }
}

/// The Mac frame's month: six weeks filling the space they are given, close to Calendar.app's month view on
/// macOS 26. The behaviour is [MonthGrid]'s; the drawing is the system's.
///
/// - **Columns** headed by the short weekday names in `callout` and `secondary-label`, at the end edge of
///   each column, over a `separator` hairline; cells divided by `separator` hairlines, edge to edge.
/// - **A cell:** the day number at its top end in `body` ("1 Nov" on the first of a month); today's in a
///   capsule of the system's accent with `on-accent` text. Days outside the month in `tertiary-label`. Then
///   as many event lines as the cell's height holds, the last one "3 more" when they do not all fit:
///   an all-day event as a chip tinted with its calendar's colour, its title in `label`; a timed one as a dot
///   of that colour, the title in `label` and the start time in `secondary-label` at the end.
/// - **States:** a day no source reads is on `window-background` and shows no events. The selected day is
///   tinted with the accent while the grid has the keyboard (and the window is active), with
///   `quaternary-label` otherwise; the system's focus ring is drawn inside it from the keyboard.
/// - **Keyboard and names:** as [MonthGrid]: one Tab stop, the arrows, Home, End, Page Up and Page Down move
///   the selection (and the month when it leaves the six weeks); each cell is named by [MonthGrid.dayLabel].
/// - Read-only.
class MacMonthGrid extends StatefulWidget {
  const MacMonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.firstDayOfWeek,
    required this.onSelected,
    required this.onMonthChanged,
    this.events = const {},
    this.isNotRead,
    this.focusNode,
    this.autofocus = false,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final int firstDayOfWeek;
  final ValueChanged<DateTime> onSelected;
  final ValueChanged<DateTime> onMonthChanged;

  /// Each day's events in the order the cell shows them, keyed by the day at local midnight.
  final Map<DateTime, List<MacCellEvent>> events;
  final bool Function(DateTime day)? isNotRead;
  final FocusNode? focusNode;

  /// Takes the keyboard when it appears, without showing the focus ring until a key is used.
  final bool autofocus;

  /// The weekday headings' row.
  static const headingHeight = MyDataMacSize.rowHeight;

  /// Around a cell's contents.
  static const cellPadding = MyDataSpace.s1;

  /// The day number's capsule height at the default text size.
  static const numberHeight = MyDataMacSize.controlMin + MyDataMacSize.tight;

  /// Between event lines, and between the number and the first line.
  static const lineGap = MyDataSpace.s1 / 2;

  /// An event line's padding above and below its text.
  static const linePadding = 1.0;

  /// A timed event's dot.
  static const dotSize = 6.0;

  /// The chip's corners: half the push button's.
  static const chipRadius = BorderRadius.all(Radius.circular(MyDataMacRadius.control / 2));

  /// How strongly a chip is tinted with its calendar's colour.
  static const chipTintLight = 0.22;
  static const chipTintDark = 0.36;

  /// Below this cell width a timed event's line leaves its start time out, so the title has the room (the
  /// day list beside the month gives the times).
  static const timeMinCellWidth = MyDataMacSize.gridTimeCellWidth;

  /// The selected day's outline: thin, inside the cell (the cell is never filled, so today's red number
  /// and the selection never compete).
  static const selectionWidth = MyDataMacSize.tight;

  static const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// What a cell's number reads: "16", or "1 Nov" on the first of a month.
  static String numberText(DateTime day) => day.day == 1 ? '1 ${_shortMonths[day.month - 1]}' : '${day.day}';

  /// "3 more".
  static String moreText(int n) => '$n more';

  /// One event line's height at [scaler].
  static double lineHeight(TextScaler scaler) =>
      scaler.scale(MyDataMacType.caption.fontSize!) * MyDataMacType.caption.height! + 2 * linePadding;

  /// The number's row at [scaler].
  static double numberRowHeight(TextScaler scaler) => math.max(
      scaler.scale(numberHeight), scaler.scale(MyDataMacType.body.fontSize!) * MyDataMacType.body.height!);

  /// How many event lines a cell [height] tall holds at [scaler].
  static int linesFor(double height, TextScaler scaler) {
    final room = height - 2 * cellPadding - numberRowHeight(scaler);
    if (room <= 0) return 0;
    return math.max(0, ((room + lineGap) / (lineHeight(scaler) + lineGap)).floor());
  }

  @override
  State<MacMonthGrid> createState() => _MacMonthGridState();
}

int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

class _MoveDays extends Intent {
  const _MoveDays(this.days);
  final int days;
}

class _MoveSideways extends Intent {
  const _MoveSideways(this.forward);
  final bool forward;
}

class _MoveMonths extends Intent {
  const _MoveMonths(this.months);
  final int months;
}

class _WeekEdge extends Intent {
  const _WeekEdge(this.end);
  final bool end;
}

class _MacMonthGridState extends State<MacMonthGrid> {
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'Month grid'));

  bool _highlight = false;

  /// Focus came from a click or from autofocus: no ring until a key is used.
  late bool _quietFocus = widget.autofocus;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _select(DateTime day) {
    if (_quietFocus) setState(() => _quietFocus = false);
    final target = _date(day);
    widget.onSelected(target);
    final visible = MonthGrid.visibleDays(widget.month, widget.firstDayOfWeek);
    final k = _key(target);
    if (k < _key(visible.first) || k > _key(visible.last)) {
      widget.onMonthChanged(DateTime(target.year, target.month));
    }
  }

  void _moveDays(int days) {
    final s = widget.selected;
    _select(DateTime(s.year, s.month, s.day + days));
  }

  void _pageMonths(int months) {
    if (_quietFocus) setState(() => _quietFocus = false);
    final target = MacMonthNav.addMonths(widget.selected, months);
    widget.onSelected(target);
    widget.onMonthChanged(DateTime(target.year, target.month));
  }

  void _weekEdge(bool end) {
    final s = widget.selected;
    final fromStart = (s.weekday - widget.firstDayOfWeek + 7) % 7;
    _moveDays(end ? 6 - fromStart : -fromStart);
  }

  void _press(DateTime day) {
    if (!_node.hasFocus) {
      _quietFocus = true;
      _node.requestFocus();
    }
    widget.onSelected(_date(day));
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final month = DateTime(widget.month.year, widget.month.month);
    final days = MonthGrid.visibleDays(month, widget.firstDayOfWeek);
    final events = {for (final e in widget.events.entries) _key(e.key): e.value};
    final selected = _key(widget.selected), today = _key(widget.today);
    final focused = _node.hasFocus && MacChrome.of(context).windowActive;

    final headings = SizedBox(
      height: MacMonthGrid.headingHeight,
      child: Row(
        children: [
          for (var d = 0; d < 7; d++)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: MacMonthGrid.cellPadding + MyDataSpace.s1),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    MonthGrid.weekdayShortName(days[d].weekday),
                    style: MyDataMacType.callout.copyWith(color: mac.secondaryLabel),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var w = 0; w < MonthGrid.weeks; w++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _Cell(
                      day: days[w * 7 + d],
                      inMonth: days[w * 7 + d].month == month.month,
                      today: _key(days[w * 7 + d]) == today,
                      selected: _key(days[w * 7 + d]) == selected,
                      emphasised: focused,
                      showFocus: _highlight && !_quietFocus && _node.hasFocus,
                      notRead: widget.isNotRead?.call(days[w * 7 + d]) ?? false,
                      events: events[_key(days[w * 7 + d])] ?? const [],
                      leadingEdge: d > 0,
                      onPressed: _press,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      mouseCursor: MouseCursor.defer,
      includeFocusSemantics: false,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveSideways(false),
        SingleActivator(LogicalKeyboardKey.arrowRight): _MoveSideways(true),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveDays(-7),
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveDays(7),
        SingleActivator(LogicalKeyboardKey.pageUp): _MoveMonths(-1),
        SingleActivator(LogicalKeyboardKey.pageDown): _MoveMonths(1),
        SingleActivator(LogicalKeyboardKey.home): _WeekEdge(false),
        SingleActivator(LogicalKeyboardKey.end): _WeekEdge(true),
      },
      actions: {
        _MoveSideways: CallbackAction<_MoveSideways>(onInvoke: (i) => _moveDays((i.forward != rtl) ? 1 : -1)),
        _MoveDays: CallbackAction<_MoveDays>(onInvoke: (i) => _moveDays(i.days)),
        _MoveMonths: CallbackAction<_MoveMonths>(onInvoke: (i) => _pageMonths(i.months)),
        _WeekEdge: CallbackAction<_WeekEdge>(onInvoke: (i) => _weekEdge(i.end)),
      },
      onShowFocusHighlight: (v) => setState(() => _highlight = v),
      onFocusChange: (f) => setState(() {
        if (!f) _quietFocus = false;
      }),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: MonthGrid.monthTitle(month),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(child: headings),
            Expanded(child: rows),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatefulWidget {
  const _Cell({
    required this.day,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.emphasised,
    required this.showFocus,
    required this.notRead,
    required this.events,
    required this.leadingEdge,
    required this.onPressed,
  });

  final DateTime day;
  final bool inMonth;
  final bool today;
  final bool selected;

  /// The grid has the keyboard in the active window: the selection is in the accent.
  final bool emphasised;
  final bool showFocus;
  final bool notRead;
  final List<MacCellEvent> events;

  /// A hairline at the start edge (every column but the first).
  final bool leadingEdge;
  final ValueChanged<DateTime> onPressed;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final w = widget;
    final ground = w.notRead ? mac.windowBackground : mac.contentBackground;
    final fill = _hovered && !w.selected ? Color.alphaBlend(mac.hover, ground) : ground;
    final scaler = MediaQuery.textScalerOf(context);
    final events = w.notRead ? const <MacCellEvent>[] : w.events;
    final label = MonthGrid.dayLabel(
      w.day,
      today: w.today,
      notRead: w.notRead,
      events: [for (final e in events) MonthGridEvent(title: e.title, calendarName: e.calendarName)],
    );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        final fits = MacMonthGrid.linesFor(constraints.maxHeight, scaler);
        final times = constraints.maxWidth >= scaler.scale(MacMonthGrid.timeMinCellWidth);
        final List<Widget> lines;
        if (events.length <= fits) {
          lines = [for (final e in events) _EventLine(event: e, ground: fill, muted: !w.inMonth, time: times)];
        } else if (fits <= 0) {
          lines = const [];
        } else {
          lines = [
            for (final e in events.take(fits - 1)) _EventLine(event: e, ground: fill, muted: !w.inMonth, time: times),
            _MoreLine(count: events.length - (fits - 1)),
          ];
        }
        return Padding(
          padding: const EdgeInsets.all(MacMonthGrid.cellPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: _Number(day: w.day, today: w.today, muted: !w.inMonth || w.notRead),
              ),
              for (final l in lines) ...[const SizedBox(height: MacMonthGrid.lineGap), l],
            ],
          ),
        );
      },
    );

    final cell = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          top: BorderSide(color: mac.separator),
          left: w.leadingEdge ? BorderSide(color: mac.separator) : BorderSide.none,
        ),
      ),
      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        // The selection: a thin outline in the accent (in `tertiary-label` while the grid does not have
        // the keyboard), the system's focus ring once a key was used.
        decoration: BoxDecoration(
          border: w.selected
              ? Border.all(
                  color: w.showFocus
                      ? FocusRing.colourFor(context)
                      : (w.emphasised ? mac.accent : mac.tertiaryLabel),
                  width: w.showFocus ? MyDataMacSize.focusRingWidth : MacMonthGrid.selectionWidth,
                )
              : null,
        ),
        child: ClipRect(child: body),
      ),
    );

    return Semantics(
      button: true,
      selected: w.selected,
      focused: w.selected && w.emphasised,
      label: label,
      onTap: () => w.onPressed(w.day),
      child: ExcludeSemantics(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => w.onPressed(w.day),
            child: cell,
          ),
        ),
      ),
    );
  }
}

/// The day number at a cell's top end; today's in a capsule in the system red, as Calendar.app marks it.
class _Number extends StatelessWidget {
  const _Number({required this.day, required this.today, required this.muted});

  final DateTime day;
  final bool today;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final scaler = MediaQuery.textScalerOf(context);
    final height = MacMonthGrid.numberRowHeight(scaler);
    final text = MacMonthGrid.numberText(day);
    if (today) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: mac.red,
          borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.field)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: height, minHeight: height, maxHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s1 + MyDataMacSize.tight),
            child: Center(
              widthFactor: 1,
              child: Text(text, style: MyDataMacType.bodyEmphasized.copyWith(color: MyDataMacColors.dark.onAccent)),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: MyDataSpace.s1 + MyDataMacSize.tight),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: 1,
          child: Text(text, style: MyDataMacType.body.copyWith(color: muted ? mac.tertiaryLabel : mac.label)),
        ),
      ),
    );
  }
}

/// One event in a cell: a tinted chip for all day, else a dot, the title and the start time.
class _EventLine extends StatelessWidget {
  const _EventLine({required this.event, required this.ground, required this.muted, required this.time});

  final MacCellEvent event;

  /// The cell's fill, for the dot's edge rule.
  final Color ground;

  /// A day outside the month: the title in `secondary-label`.
  final bool muted;

  /// The start time is shown (the cell is wide enough).
  final bool time;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scaler = MediaQuery.textScalerOf(context);
    final height = MacMonthGrid.lineHeight(scaler);
    final title = event.title.trim();
    final style = MyDataMacType.caption.copyWith(
      color: title.isEmpty || muted ? mac.secondaryLabel : mac.label,
    );
    final text = Text(title.isEmpty ? MonthGrid.noTitle : title, maxLines: 1, softWrap: false,
        overflow: TextOverflow.ellipsis, style: style);
    final colour = event.colour;
    if (event.allDay) {
      final tint = colour == null
          ? mac.quaternaryLabel
          : colour.withValues(alpha: dark ? MacMonthGrid.chipTintDark : MacMonthGrid.chipTintLight);
      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s1),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(color: Color.alphaBlend(tint, ground), borderRadius: MacMonthGrid.chipRadius),
        child: text,
      );
    }
    final dot = colour ?? mac.tertiaryLabel;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s1),
        child: Row(
          children: [
            Container(
              width: MacMonthGrid.dotSize,
              height: MacMonthGrid.dotSize,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                // A hairline, so a dark dot on a dark cell reads as filled, not as a ring.
                border: dataColourNeedsEdge(dot, ground)
                    ? Border.all(color: mac.tertiaryLabel, width: MyDataMacSize.hairline)
                    : null,
              ),
            ),
            const SizedBox(width: MyDataSpace.s1),
            Expanded(child: text),
            if (time && event.time != null) ...[
              const SizedBox(width: MyDataSpace.s1),
              Text(event.time!, style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreLine extends StatelessWidget {
  const _MoreLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MacMonthGrid.lineHeight(MediaQuery.textScalerOf(context)),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: MyDataSpace.s1 + MacMonthGrid.dotSize + MyDataSpace.s1),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(MacMonthGrid.moreText(count),
            style: MyDataMacType.caption.copyWith(color: context.mac.secondaryLabel)),
      ),
    ),
  );
}
