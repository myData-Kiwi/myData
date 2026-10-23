import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'calendars_page.dart';

/// The Mac frame's sidebar: the calendar list, as Calendar.app's sidebar has it. The Calendars section's
/// rules ([CalendarsPage]) in the system's shape:
///
/// - One group per source, in the host's order, headed by the source ("This Mac", "iCloud account
///   you@example.com") in `caption-emphasized` and `secondary-label`. This Mac's calendars are grouped
///   under the account each belongs to on the Mac ("iCloud", "Google", "Only on this Mac"), as Calendar.app
///   groups its sidebar, each account in the order it first appears. With This Mac as the only source its
///   heading is left out and the accounts head the groups, as in Calendar.app.
/// - A row is a checkbox in the calendar's own colour (filled and ticked while shown, its outline while
///   hidden) and the name in `body`; the whole row toggles, and it is a Tab stop that Space and Return
///   toggle. It is named "Show" and the calendar's name, says it is checked or not, and gives the account
///   as its hint.
/// - Hiding changes only what myCalendar shows on this device; a change that could not be stored says so
///   ([CalendarsPage.saveFailed]) and the box goes back to what is stored.
class MacCalendarList extends StatelessWidget {
  const MacCalendarList({super.key, required this.calendars, required this.visibility});

  final List<CalendarOut> calendars;
  final CalendarVisibility visibility;

  /// [items] (one source's calendars) by the account each belongs to on the Mac, in first-seen order;
  /// calendars with no account named come first, under no heading.
  static List<(String? account, List<CalendarOut> calendars)> byAccount(List<CalendarOut> items) {
    final out = <(String?, List<CalendarOut>)>[];
    for (final c in items) {
      final caption = c.source_ == CalendarOutSource_Enum.mac ? c.accountCaption?.trim() : null;
      final account = caption == null || caption.isEmpty ? null : caption;
      final i = out.indexWhere((g) => g.$1 == account);
      if (i < 0) {
        account == null ? out.insert(0, (null, [c])) : out.add((account, [c]));
      } else {
        out[i].$2.add(c);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final groups = CalendarsPage.groups(calendars);
    Widget heading(String text, {required bool strong}) => Padding(
      padding: EdgeInsets.fromLTRB(MyDataMacSize.rowInset + MyDataMacSize.rowPadding,
          strong ? context.space(3) : context.space(2), MyDataMacSize.rowInset, context.space(1)),
      child: Semantics(
        header: true,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (strong ? MyDataMacType.captionEmphasized : MyDataMacType.caption).copyWith(color: mac.secondaryLabel)),
      ),
    );
    return ListenableBuilder(
      listenable: visibility,
      builder: (context, _) => Semantics(
        container: true,
        label: CalendarsPage.title,
        hint: CalendarsPage.intro,
        explicitChildNodes: true,
        child: ListView(
          padding: EdgeInsets.only(bottom: context.space(2)),
          children: [
            if (calendars.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MyDataMacSize.rowInset + MyDataMacSize.rowPadding, vertical: context.space(2)),
                child: Text(CalendarsPage.none, style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel)),
              ),
            for (final (source, items) in groups) ...[
              // This Mac alone: its accounts head the groups, as in Calendar.app.
              if (groups.length > 1 || items.first.source_ != CalendarOutSource_Enum.mac) heading(source, strong: true),
              for (final (account, rows) in byAccount(items)) ...[
                if (account != null) heading(account, strong: groups.length == 1),
                for (final cal in rows)
                  MacCalendarRow(
                    key: ValueKey(cal.id),
                    colour: parseDataColour(cal.color),
                    name: cal.name,
                    caption: account,
                    shown: visibility.isVisible(cal.id),
                    onChanged: (show) => visibility.setHidden(cal.id, !show).catchError((Object _) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)
                          ?.showSnackBar(const SnackBar(content: Text(CalendarsPage.saveFailed)));
                    }),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One calendar in [MacCalendarList].
class MacCalendarRow extends StatefulWidget {
  const MacCalendarRow({
    super.key,
    required this.colour,
    required this.name,
    required this.shown,
    required this.onChanged,
    this.caption,
  });

  /// The calendar's colour from the host; null for none (`secondary-label`).
  final Color? colour;
  final String name;

  /// The account the calendar belongs to on the Mac: the row's accessible hint (its group's heading shows
  /// it).
  final String? caption;
  final bool shown;
  final ValueChanged<bool> onChanged;

  /// "Show Family": the row's accessible name, as the Calendars section's switch is named.
  static String showLabel(String name) => 'Show $name';

  @override
  State<MacCalendarRow> createState() => _MacCalendarRowState();
}

class _MacCalendarRowState extends State<MacCalendarRow> {
  bool _hovered = false;
  bool _focused = false;

  void _toggle() => widget.onChanged(!widget.shown);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final caption = widget.caption?.trim();
    const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.selection));
    final row = Container(
      height: MyDataMacSize.rowHeight,
      margin: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset),
      padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowPadding),
      decoration: BoxDecoration(
        color: _hovered ? mac.hover : null,
        borderRadius: radius,
        border: _focused ? Border.all(color: FocusRing.colourFor(context), width: MyDataMacSize.focusRingWidth) : null,
      ),
      child: Row(
        children: [
          MacColourCheckbox(colour: widget.colour, checked: widget.shown),
          SizedBox(width: context.space(2)),
          Expanded(
            child: Text(widget.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataMacType.body.copyWith(color: mac.label)),
          ),
        ],
      ),
    );
    return Semantics(
      checked: widget.shown,
      label: MacCalendarRow.showLabel(widget.name),
      hint: caption,
      onTap: _toggle,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (h) => setState(() => _hovered = h),
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _toggle())},
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle, child: row),
      ),
    );
  }
}

/// Calendar.app's checkbox: a small rounded square in the calendar's [colour], filled with a tick while
/// [checked], its outline otherwise. The tick is white or black, whichever reads better on the colour; a
/// colour with less than 3:1 contrast with the sidebar gets a `tertiary-label` edge, as DataColour's edge
/// rule says, so a yellow or a black box keeps its shape.
class MacColourCheckbox extends StatelessWidget {
  const MacColourCheckbox({super.key, required this.colour, required this.checked});

  /// The calendar's colour; null for none: `secondary-label` on the sidebar.
  final Color? colour;
  final bool checked;

  /// The box: Calendar.app's 14 pt.
  static const size = MyDataMacSize.icon - MyDataMacSize.tight;

  /// The branded checkbox's corners, in proportion to this smaller box.
  static BorderRadius radius(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.xs * size / CheckboxBox.size(look)));

  static const outlineWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final fill = colour?.withValues(alpha: 1) ?? Color.alphaBlend(mac.secondaryLabel, mac.sidebarBackground);
    final weak = dataColourNeedsEdge(fill, mac.sidebarBackground);
    final white = MyDataMacColors.light.contentBackground, black = MyDataMacColors.light.label;
    final tick = dataColourContrast(fill, white) >= dataColourContrast(fill, black) ? white : black;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: checked ? fill : null,
          borderRadius: radius(context.look),
          border: checked
              ? (weak ? Border.all(color: mac.tertiaryLabel, width: MyDataMacSize.hairline) : null)
              : Border.all(color: weak ? mac.tertiaryLabel : fill, width: outlineWidth),
        ),
        child: checked ? CustomPaint(painter: _Tick(tick)) : null,
      ),
    );
  }
}

class _Tick extends CustomPainter {
  const _Tick(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.24, h * 0.52)
      ..lineTo(w * 0.43, h * 0.71)
      ..lineTo(w * 0.77, h * 0.31);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Tick old) => old.color != color;
}
