import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart' show MacSystemLook;
import '../theme/theme.dart';
import 'group_frame.dart' show GroupPartShape;
import 'grouped_list.dart';
import 'pressable.dart';
import 'switch.dart';

/// Reads a colour from the user's data, as the host gives it: `#RRGGBB` or `#RRGGBBAA` (iCloud's form),
/// either case, surrounding spaces ignored. Any alpha is ignored and the colour is opaque
/// (design/components/DataColour: "Any alpha in the value is ignored, and the colour is drawn opaque").
/// Null, empty or anything else gives null: the calendar has no colour, and [DataDot] and [DataBar] then
/// use `line-strong`.
Color? parseDataColour(String? value) {
  if (value == null) return null;
  final m = _hex.firstMatch(value.trim());
  if (m == null) return null;
  final rgb = int.parse(m.group(1)!, radix: 16);
  return Color(rgb | _opaque);
}

final _hex = RegExp(r'^#([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?$');

/// The alpha byte of an opaque ARGB value.
const _opaque = 0xFF << 24;

/// The WCAG contrast ratio of [a] and [b], from 1 to 21. Alpha is ignored: both are taken as opaque.
double dataColourContrast(Color a, Color b) {
  final la = a.withValues(alpha: 1).computeLuminance();
  final lb = b.withValues(alpha: 1).computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Whether a data colour needs the `line-strong` edge on [ground]: it has less than
/// [DataGround.minContrast] (3:1) contrast with it.
bool dataColourNeedsEdge(Color colour, Color ground) => dataColourContrast(colour, ground) < DataGround.minContrast;

/// The ground a [DataDot] or [DataBar] sits on, in the current theme and mode. The edge rule is measured
/// against it.
enum DataGround {
  /// A row, card or month cell: `surface`.
  surface,

  /// A selected row or day: `accent-soft`.
  accentSoft,

  /// A sunken ground, such as a day myData does not read: `surface-sunken`.
  surfaceSunken,

  /// A hovered or pressed list row: `surface-hover`.
  surfaceHover;

  /// Spec: "less than 3:1 contrast with the ground it sits on" gets the edge.
  static const minContrast = 3.0;

  /// This ground's colour in [c].
  Color of(MyDataColors c) =>
      switch (this) {
        surface => c.surface,
        accentSoft => c.accentSoft,
        surfaceSunken => c.surfaceSunken,
        surfaceHover => c.surfaceHover,
      };
}

/// How a data colour is drawn on [ground] and the [alsoOn] grounds: the colour as the source gives it
/// (opaque, never tinted), or `line-strong` when there is none, with a 1px `line-strong` inner edge when it
/// has less than 3:1 contrast with any of those grounds.
({Color fill, bool edge}) _swatch(MyDataColors c, Color? colour, DataGround ground, List<DataGround> alsoOn) {
  if (colour == null) return (fill: c.lineStrong, edge: false);
  final fill = colour.withValues(alpha: 1);
  final edge = dataColourNeedsEdge(fill, ground.of(c)) || alsoOn.any((g) => dataColourNeedsEdge(fill, g.of(c)));
  return (fill: fill, edge: edge);
}

/// Spec: "a 1px inner edge in `line-strong`".
const _edgeWidth = 1.0;

/// The edge, 1px; a hairline in the Mac frame, so a small dark dot or bar reads as filled there, not as a
/// ring (design/components/DataColour, "The Mac frame").
Border? _edge(BuildContext context, MyDataColors c, bool edge) => edge
    ? Border.all(
        color: c.lineStrong,
        width: context.isSystemLook ? MyDataMacSize.hairline : _edgeWidth,
        strokeAlign: BorderSide.strokeAlignInside,
      )
    : null;

/// A colour from the user's data, such as a calendar's colour, as an 8px dot
/// (design/components/DataColour).
///
/// - Drawn exactly as the data gives it, in both modes: no lightening, darkening or theme tint; any alpha is
///   dropped. Null (no colour) is `line-strong`.
/// - When the colour has less than 3:1 contrast with the [ground] it sits on, it gets a 1px `line-strong`
///   inner edge, so a yellow dot on white or a black dot in dark mode keeps its shape.
/// - It has no accessible name and is never the only signal: the name it belongs to sits beside it, or (in
///   a month cell) is one step away and in the cell's accessible name.
/// - Never a fill behind text, a text or icon colour, a chip, a button, a border, or a selected or focused
///   state.
///
/// In a list row use [DataDot.slot], which centres the dot in an `icon-tile` square so names line up with
/// rows that have tiles.
class DataDot extends StatelessWidget {
  /// The bare 8px dot, as a MonthGrid cell under 600px uses it.
  const DataDot({super.key, required this.colour, this.ground = DataGround.surface, this.alsoOn = const []})
      : slot = false;

  /// The dot centred in an `icon-tile` (36px) square, where a row's icon tile would be.
  const DataDot.slot({super.key, required this.colour, this.ground = DataGround.surface, this.alsoOn = const []})
      : slot = true;

  /// The colour from the data ([parseDataColour]); null for none.
  final Color? colour;

  /// What the dot sits on, for the 3:1 edge rule.
  final DataGround ground;

  /// Other grounds the dot can show on without being rebuilt, such as a row's hover and press fill
  /// (`surface-sunken`). The edge is drawn when the colour fails 3:1 on [ground] or on any of these, so it
  /// does not vanish, or flicker, while the pointer is over the row.
  final List<DataGround> alsoOn;

  /// Whether the dot is centred in an `icon-tile` square.
  final bool slot;

  /// Spec: "an 8px circle" (the `space-2` step).
  static double diameter(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _swatch(c, colour, ground, alsoOn);
    Widget dot = ExcludeSemantics(
        child: Container(
            width: diameter(context.look),
            height: diameter(context.look),
            decoration: BoxDecoration(color: s.fill, shape: BoxShape.circle, border: _edge(context, c, s.edge))));
    if (slot) {
      dot = SizedBox.square(dimension: context.density.iconTile, child: Center(child: dot));
    }
    return dot;
  }
}

/// A colour from the user's data, such as a calendar's colour, as a thin bar beside the text it marks
/// (design/components/DataColour): `space-1` (4px) wide, `radius-pill`, as tall as that text. EventRow and
/// MonthGrid cells use it.
///
/// - The same colour rules as [DataDot]: drawn as given (opaque), `line-strong` when null, and a 1px
///   `line-strong` inner edge when it has less than 3:1 contrast with the [ground].
/// - [height] null: in a [Row] with [CrossAxisAlignment.stretch] inside [IntrinsicHeight] (a tight height)
///   it takes that height, so it matches the text beside it; its intrinsic height is zero, so the text
///   decides it. Under any other parent it is one line of `body` text tall ([fallbackHeight]), within the
///   parent's bounds: a loose bound, such as a month cell's, never stretches it, so it never makes a row
///   taller than one `body` line. Beside text of another size, use the stretch pattern or [height].
/// - It has no accessible name.
class DataBar extends StatelessWidget {
  const DataBar(
      {super.key, required this.colour, this.ground = DataGround.surface, this.alsoOn = const [], this.height});

  /// The colour from the data ([parseDataColour]); null for none.
  final Color? colour;

  /// What the bar sits on, for the 3:1 edge rule.
  final DataGround ground;

  /// Other grounds the bar can show on without being rebuilt, such as a row's hover fill; see
  /// [DataDot.alsoOn].
  final List<DataGround> alsoOn;

  /// A fixed height; null to take the height the parent gives.
  final double? height;

  /// Spec: "`space-1` (4px) wide".
  static double width(MyDataLook look) => look.space(1);

  /// The height with no [height] and no tight height from the parent: one line of `body`.
  static double fallbackHeight(MyDataLook look) => look.typeScale.body.fontSize! * look.typeScale.body.height!;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _swatch(c, colour, ground, alsoOn);
    return ExcludeSemantics(
        child: DecoratedBox(
            decoration: BoxDecoration(color: s.fill, borderRadius: MyDataRadii.pill(context.look), border: _edge(context, c, s.edge)),
            child: _BarBox(height: height)));
  }
}

/// The bar's box: [DataBar.width] wide; [height] tall, or the parent's height when that is tight (the
/// stretch pattern), or else [DataBar.fallbackHeight] within the parent's bounds.
/// Its intrinsic height is [height] or zero, so a row measured with [IntrinsicHeight] takes its height from
/// the text, and the bar then stretches to it.
class _BarBox extends LeafRenderObjectWidget {
  const _BarBox({required this.height});
  final double? height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarBox(height, context.look);

  @override
  void updateRenderObject(BuildContext context, _RenderBarBox renderObject) => renderObject
    ..height = height
    ..look = context.look;
}

class _RenderBarBox extends RenderBox {
  _RenderBarBox(this._height, this._look);

  MyDataLook _look;
  set look(MyDataLook value) {
    if (value == _look) return;
    _look = value;
    markNeedsLayout();
  }

  double? _height;
  set height(double? value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  double _heightFor(BoxConstraints constraints) =>
      _height ?? (constraints.hasTightHeight ? constraints.maxHeight : DataBar.fallbackHeight(_look));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(DataBar.width(_look), _heightFor(constraints)));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  double computeMinIntrinsicWidth(double height) => DataBar.width(_look);

  @override
  double computeMaxIntrinsicWidth(double height) => DataBar.width(_look);

  @override
  double computeMinIntrinsicHeight(double width) => _height ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => _height ?? 0;
}

/// One calendar in the calendar list (design/components/DataColour, "The calendar list"): shows or hides
/// that calendar on this device only. It is a [GroupedRow], so it goes in a [GroupedList], one list per
/// source, headed by the source's name with a capital at the start ("This Mac", "iCloud account
/// you@example.com").
///
/// - The calendar's [DataDot] in an `icon-tile` slot, the [name] in `body-strong`, the optional [caption] in
///   `caption` and `ink-muted`, and the switch at the right end. The whole row is the target, with the
///   GroupedList switch row's hover fill, press dim, focus ring and Enter and Space.
/// - [caption], under This Mac only: the account the calendar belongs to on the Mac, as macOS names it
///   ("iCloud", "Google", "Exchange"), or myData's own words for the three cases macOS calls "Other":
///   [onlyOnThisMac], [birthdaysFromContacts], [subscribed]. A source that reads one account needs none.
/// - A hidden calendar ([shown] false) keeps its row and its dot.
/// - The dot's 3:1 edge rule is measured on `surface` and on the hover and press fill (`surface-hover`),
///   and the edge is drawn when either fails, so a pale dot keeps its shape under the pointer.
/// - Its accessible name is "Show" and the calendar's name, then the caption; it is announced as a switch,
///   on or off. The dot has no accessible name.
/// - [onChanged] null disables it: the whole row at 45% opacity.
/// - Read-only data: the switch changes only what this device shows, never the calendar.
class CalendarListRow extends GroupedRow {
  const CalendarListRow(
      {super.key,
      required this.colour,
      required String name,
      String? caption,
      required bool shown,
      required super.onChanged,
      super.focusNode,
      super.autofocus})
      : super.toggle(title: name, subtitle: caption, value: shown);

  /// The calendar's colour from the host ([parseDataColour]); null for none (`line-strong`).
  final Color? colour;

  /// The calendar's name.
  String get name => title;

  /// The account line under This Mac; null elsewhere.
  String? get caption => subtitle;

  /// Whether the calendar is shown on this device.
  bool get shown => switchValue!;

  /// Caption for a calendar stored only on the Mac (macOS: "Other").
  static const onlyOnThisMac = 'Only on this Mac';

  /// Caption for the Birthdays calendar (macOS: "Other").
  static const birthdaysFromContacts = 'Birthdays from Contacts';

  /// Caption for a subscribed calendar (macOS: "Other").
  static const subscribed = 'Subscribed';

  /// The switch's accessible name for a calendar called [name]: "Show Family".
  static String showLabel(String name) => 'Show $name';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = GroupPartShape.of(context);
    final onChanged = onSwitchChanged;
    return MergeSemantics(
        child: Pressable(
            onPressed: onChanged == null ? null : () => onChanged(!shown),
            borderRadius: shape,
            hoverFill: c.surfaceHover,
            scaleOnPress: false,
            focusNode: focusNode,
            autofocus: autofocus,
            semanticLabel: showLabel(name),
            button: false,
            toggled: shown,
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: context.density.rowHeight),
                child: Padding(
                    padding: GroupedRow.padding(context.look),
                    child: Row(children: [
                      // The row's hover and press fill is `surface-hover`: the edge rule covers both grounds.
                      DataDot.slot(colour: colour, alsoOn: const [DataGround.surfaceHover]),
                      SizedBox(width: GroupedRow.gap(context.look)),
                      Expanded(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            // The name is already in the accessible name ("Show Family").
                            ExcludeSemantics(child: Text(name, style: context.typeScale.bodyStrong.copyWith(color: c.ink))),
                            if (caption != null) Text(caption!, style: context.typeScale.caption.copyWith(color: c.inkMuted))
                          ])),
                      SizedBox(width: GroupedRow.gap(context.look)),
                      SwitchTrack(value: shown)
                    ])))));
  }
}
