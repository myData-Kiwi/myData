import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'badge.dart';
import 'icon_tile.dart';
import 'pressable.dart';
import 'status.dart';
import 'switch.dart';

/// A rounded group of rows under a small heading (design/components/GroupedList): the main way to show
/// settings, devices, accounts and any short list of records.
///
/// - The group is `surface` with `radius-lg` and `shadow-1`, with no border. Rows are separated by a
///   full-width 1px `line` divider (preview: `border-top:1px solid var(--line)`, no inset).
/// - The optional [heading] sits above the group, outside it, in `label` and `ink-muted`, `space-2` above
///   the group and `space-2` in from its left edge (preview: 8px and 6px; 6px is between `space-1` and
///   `space-2`, so the nearest token on the larger side).
/// - Each row is a [GroupedRow]; a setting with a switch is a [GroupedRow.toggle] row (decided 2026-10-12: "A
///   switch row is a GroupedList row with an optional icon tile").
/// - Tile colours: at most three different tile tones on one screen (decided 2026-10-12). A list can only
///   check itself, so it asserts in debug builds that its own rows use at most [maxTileTones].
class GroupedList extends StatelessWidget {
  GroupedList({super.key, this.heading, required this.rows})
    : assert(rows.isNotEmpty, 'a grouped list has at least one row'),
      assert(
        rows.where((r) => r.icon != null).map((r) => r.tone).toSet().length <= maxTileTones,
        'use at most $maxTileTones different tile tones on one screen (design/README.md "Colour")',
      );

  /// The small heading above the group, in sentence case ("Sync"). Null for none.
  final String? heading;

  /// The rows, top to bottom.
  final List<GroupedRow> rows;

  /// Spec: "Use at most three [tile colours] on one screen".
  static const maxTileTones = 3;

  /// Preview: `.r{border-top:1px solid var(--line)}`.
  static const dividerWidth = 1.0;

  /// Preview: `.lbl{margin:0 0 8px 6px}`: `space-2` below; 6px in, snapped to `space-2`.
  static const headingPadding = EdgeInsets.only(left: MyDataSpace.s2, bottom: MyDataSpace.s2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const top = BorderRadius.vertical(top: Radius.circular(MyDataRadius.lg));
    const bottom = BorderRadius.vertical(bottom: Radius.circular(MyDataRadius.lg));
    BorderRadius shapeOf(int i) {
      if (rows.length == 1) return MyDataRadii.lg;
      if (i == 0) return top;
      if (i == rows.length - 1) return bottom;
      return BorderRadius.zero;
    }

    // Not clipped: each row takes the group's corners itself, so the selected fill and hover fill follow
    // them and the focus ring, drawn 2px outside the row, is not cut off at the group's edge.
    final group = DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg, boxShadow: context.shadows.shadow1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: dividerWidth, color: c.line),
            _RowShape(borderRadius: shapeOf(i), child: rows[i]),
          ],
        ],
      ),
    );
    if (heading == null) return group;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headingPadding,
          child: Semantics(
            header: true,
            child: Text(heading!, style: MyDataType.label.copyWith(color: c.inkMuted)),
          ),
        ),
        group,
      ],
    );
  }
}

/// Passes a row its corner shape within the group (square in the middle, rounded at the ends).
class _RowShape extends InheritedWidget {
  const _RowShape({required this.borderRadius, required super.child});
  final BorderRadius borderRadius;

  static BorderRadius of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowShape>()?.borderRadius ?? BorderRadius.zero;

  @override
  bool updateShouldNotify(_RowShape old) => old.borderRadius != borderRadius;
}

/// What sits at the right end of a [GroupedRow]: a status chip, a value, a chevron, or a value and a
/// chevron. A switch is not a trailing part: a switch row is its own constructor, [GroupedRow.toggle].
sealed class GroupedTrailing {
  const GroupedTrailing();

  /// A status chip ([Badge]): a word or two in a status tone. Not tappable.
  const factory GroupedTrailing.badge(String label, {required MyDataTone tone}) = GroupedBadge;

  /// A short value in `body` and `ink-muted` ("2 accounts", "Every night").
  const factory GroupedTrailing.value(String text) = GroupedValue;

  /// A chevron: the row opens something. The row needs [GroupedRow.onPressed].
  const factory GroupedTrailing.chevron() = GroupedChevron;

  /// A value and a chevron, `space-2` apart: the row opens the place where the value is changed.
  const factory GroupedTrailing.valueChevron(String text) = GroupedValueChevron;
}

/// A status chip at the right end of a row. See [GroupedTrailing.badge].
final class GroupedBadge extends GroupedTrailing {
  const GroupedBadge(this.label, {required this.tone});
  final String label;
  final MyDataTone tone;
}

/// A value at the right end of a row. See [GroupedTrailing.value].
final class GroupedValue extends GroupedTrailing {
  const GroupedValue(this.text);
  final String text;
}

/// A chevron at the right end of a row. See [GroupedTrailing.chevron].
final class GroupedChevron extends GroupedTrailing {
  const GroupedChevron();
}

/// A value and a chevron at the right end of a row. See [GroupedTrailing.valueChevron].
final class GroupedValueChevron extends GroupedTrailing {
  const GroupedValueChevron(this.text);
  final String text;
}

/// One row of a [GroupedList].
///
/// - At least `row-height` tall, padded `space-4` across and `space-2` down, `space-3` between its parts:
///   an optional [IconTile], the [title] in `body-strong` over the optional [subtitle] in `caption` and
///   `ink-muted`, and the [trailing] part (or the switch) at the right end.
/// - The trailing part takes the width it needs. Only when the title and a long value cannot both fit is
///   the value cut short with an ellipsis, and then it keeps at most [maxTrailingFraction] of the row.
/// - **Selected:** the row fill becomes `accent-soft`.
/// - A row that does something ([onPressed], or a switch) is one target: hovering or pressing fills it with
///   `surface-sunken` over `fast`, a press dims it to 85% without shrinking, keyboard focus draws the focus
///   ring, and Enter and Space activate it. A selected row's hover fill is [selectedHoverInk] of `ink`
///   over its `accent-soft`, the same step that `surface-sunken` is from `surface`. A row that does nothing
///   is not focusable and has no hover.
/// - [enabled] false, on a row that does something, shows it at 45% opacity, not focusable, announced as
///   disabled. A switch row is disabled when its `onChanged` is null.
/// - Assistive technology reads the row as one node: title, subtitle, then the value or chip.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    this.icon,
    this.tone = MyDataTone.accent,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  }) : switchValue = null,
       onSwitchChanged = null,
       assert(
         !(trailing is GroupedChevron || trailing is GroupedValueChevron) || onPressed != null,
         'a chevron says the row opens something; give it onPressed',
       );

  /// A setting and its switch (design/components/Switch): the switch ([SwitchTrack]) sits at the right end
  /// and the whole row is the target that flips it. [onChanged] null disables the row. The [subtitle] is
  /// the one-sentence description; if turning it on starts something large, such as a multi-gigabyte
  /// download, it says so.
  ///
  /// This is the one switch row; a `SwitchRow` builds on it.
  const GroupedRow.toggle({
    super.key,
    this.icon,
    this.tone = MyDataTone.accent,
    required this.title,
    this.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.focusNode,
    this.autofocus = false,
  }) : switchValue = value,
       onSwitchChanged = onChanged,
       trailing = null,
       onPressed = null,
       selected = false,
       enabled = true;

  /// An optional icon on an [IconTile] at the left. The icon set is not drawn yet; pass a Material outlined
  /// or rounded icon.
  final IconData? icon;

  /// The tile's tint: `accent-soft`, a status `-soft` fill, or [MyDataTone.neutral] (`surface-sunken`).
  /// Give the same kind of thing the same tone everywhere.
  final MyDataTone tone;

  /// The row's name, in sentence case.
  final String title;

  /// The secondary line ("2 accounts", "Seen 5 minutes ago"); for a switch row, its description.
  final String? subtitle;

  /// The chip, value or chevron at the right end. Null for none, and always null on a switch row.
  final GroupedTrailing? trailing;

  /// What the row does when activated. Null, on a row without a switch, makes a static row.
  final VoidCallback? onPressed;

  /// Whether the switch is on. Null on a row without a switch ([GroupedRow.toggle] sets it).
  final bool? switchValue;

  /// Called with the new value when the user flips a switch row. Null disables it.
  final ValueChanged<bool>? onSwitchChanged;

  /// Whether this is the current item: an `accent-soft` fill.
  final bool selected;

  /// False disables a row that does something.
  final bool enabled;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Whether this is a switch row ([GroupedRow.toggle]).
  bool get isSwitch => switchValue != null;

  /// Row geometry: `space-4` across, `space-2` down (preview: `padding:8px 16px`).
  static const padding = EdgeInsets.symmetric(horizontal: MyDataSpace.s4, vertical: MyDataSpace.s2);

  /// Between the tile, the text and the trailing part (preview: `gap:12px`).
  static const gap = MyDataSpace.s3;

  /// Between a value and its chevron (preview: `.end{gap:8px}`).
  static const trailingGap = MyDataSpace.s2;

  /// Not in the spec: when the title and a long value cannot both fit, the value keeps at most this much
  /// of the row's inner width and is cut short, so it never squeezes the title out.
  static const maxTrailingFraction = 0.5;

  /// The hover and press fill of a selected row: `ink` at this opacity over `accent-soft`. Not a token;
  /// derived from the spec's hover fill, `surface-sunken`, which is `surface` darkened by about this much
  /// `ink` in light mode (ink #1A1A19 at 8% over #FFFFFF is #ECECEC; surface-sunken is #EDEDEB). The plain
  /// `surface-sunken` cannot be used: it would replace the selected fill, and accent-soft on accent-soft
  /// shows nothing.
  static const selectedHoverInk = 0.08;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = _RowShape.of(context);
    final interactive = isSwitch || onPressed != null;
    final VoidCallback? activate = isSwitch
        ? (onSwitchChanged == null ? null : () => onSwitchChanged!(!switchValue!))
        : (enabled ? onPressed : null);

    final end = isSwitch ? SwitchTrack(value: switchValue!) : (trailing == null ? null : _trailing(c, trailing!));
    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
      child: Padding(
        padding: padding,
        child: _RowLine(
          children: [
            Row(
              children: [
                if (icon != null) ...[IconTile(icon: icon!, tone: tone), const SizedBox(width: gap)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
                      if (subtitle != null) Text(subtitle!, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            ?end,
          ],
        ),
      ),
    );

    if (interactive) {
      content = Pressable(
        onPressed: activate,
        borderRadius: shape,
        hoverFill: selected ? c.ink.withValues(alpha: selectedHoverInk) : c.surfaceSunken,
        scaleOnPress: false,
        focusNode: focusNode,
        autofocus: autofocus,
        button: !isSwitch,
        selected: selected ? true : null,
        toggled: switchValue,
        child: content,
      );
    } else if (selected) {
      content = Semantics(selected: true, child: content);
    }

    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: selected ? c.accentSoft : null, borderRadius: shape),
        child: content,
      ),
    );
  }

  Widget _trailing(MyDataColors c, GroupedTrailing t) {
    Widget value(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MyDataType.body.copyWith(color: c.inkMuted),
    );
    final chevron = Icon(Icons.chevron_right_rounded, size: MyDataSize.icon, color: c.inkMuted);
    return switch (t) {
      GroupedBadge(:final label, :final tone) => MyDataBadge(label, tone: tone),
      GroupedValue(:final text) => value(text),
      GroupedChevron() => chevron,
      GroupedValueChevron(:final text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: value(text)),
          const SizedBox(width: trailingGap),
          chevron,
        ],
      ),
    };
  }
}

/// Lays out a row's leading part (tile and text) and its optional trailing part, `GroupedRow.gap` apart,
/// both centred vertically, the trailing part at the end edge.
///
/// The trailing part gets the width it needs, up to whatever the leading part's natural width leaves, and
/// never less than [GroupedRow.maxTrailingFraction] of the room if it needs that much; the leading part
/// gets the rest. A [Row] cannot give one child priority like this, and a LayoutBuilder cannot report
/// intrinsic sizes, so this is a small render object that can (a group inside IntrinsicHeight, or inside
/// a dialog sized to its content, measures its rows).
class _RowLine extends MultiChildRenderObjectWidget {
  const _RowLine({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderRowLine(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderRowLine renderObject) =>
      renderObject.textDirection = Directionality.of(context);
}

class _RowLineParentData extends ContainerBoxParentData<RenderBox> {}

typedef _RowLineLayout = ({Size size, BoxConstraints lead, Size leadSize, BoxConstraints? end, Size? endSize});

class _RenderRowLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowLineParentData> {
  _RenderRowLine(this._textDirection);

  static const _gap = GroupedRow.gap;

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _lead => firstChild!;
  RenderBox? get _end => childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowLineParentData) child.parentData = _RowLineParentData();
  }

  /// The widest the trailing part may be in a row [width] wide.
  double _endMax(double width) {
    final room = math.max(0.0, width - _gap);
    final leadNeeds = _lead.getMaxIntrinsicWidth(double.infinity);
    return math.min(room, math.max(room * GroupedRow.maxTrailingFraction, room - leadNeeds));
  }

  _RowLineLayout _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final end = _end;
    final height = constraints.maxHeight;
    BoxConstraints? endConstraints;
    Size? endSize;
    final double leadWidth;
    if (end != null) {
      endConstraints = BoxConstraints(
        maxWidth: constraints.hasBoundedWidth ? _endMax(constraints.maxWidth) : double.infinity,
        maxHeight: height,
      );
      endSize = layoutChild(end, endConstraints);
    }
    final endSpace = endSize == null ? 0.0 : _gap + endSize.width;
    leadWidth = constraints.hasBoundedWidth
        ? math.max(0.0, constraints.maxWidth - endSpace)
        : _lead.getMaxIntrinsicWidth(double.infinity);
    final leadConstraints = BoxConstraints(minWidth: leadWidth, maxWidth: leadWidth, maxHeight: height);
    final leadSize = layoutChild(_lead, leadConstraints);
    final size = constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : leadWidth + endSpace,
        math.max(leadSize.height, endSize?.height ?? 0),
      ),
    );
    return (size: size, lead: leadConstraints, leadSize: leadSize, end: endConstraints, endSize: endSize);
  }

  Offset _leadOffset(_RowLineLayout l) => Offset(
    _textDirection == TextDirection.ltr ? 0 : l.size.width - l.leadSize.width,
    (l.size.height - l.leadSize.height) / 2,
  );

  Offset _endOffset(_RowLineLayout l) => Offset(
    _textDirection == TextDirection.ltr ? l.size.width - l.endSize!.width : 0,
    (l.size.height - l.endSize!.height) / 2,
  );

  @override
  void performLayout() {
    final l = _compute(constraints, ChildLayoutHelper.layoutChild);
    size = l.size;
    (_lead.parentData! as _RowLineParentData).offset = _leadOffset(l);
    final end = _end;
    if (end != null) (end.parentData! as _RowLineParentData).offset = _endOffset(l);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final l = _compute(constraints, ChildLayoutHelper.dryLayoutChild);
    var result = BaselineOffset(_lead.getDryBaseline(l.lead, baseline)) + _leadOffset(l).dy;
    final end = _end;
    if (end != null) result = result.minOf(BaselineOffset(end.getDryBaseline(l.end!, baseline)) + _endOffset(l).dy);
    return result.offset;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _lead.getMinIntrinsicWidth(height) + (_end == null ? 0 : _gap + _end!.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _lead.getMaxIntrinsicWidth(height) + (_end == null ? 0 : _gap + _end!.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width, (c, w) => c.getMaxIntrinsicHeight(w));

  double _intrinsicHeight(double width, double Function(RenderBox child, double width) height) {
    final end = _end;
    if (end == null) return height(_lead, width);
    if (!width.isFinite) return math.max(height(_lead, width), height(end, width));
    final endWidth = math.min(end.getMaxIntrinsicWidth(double.infinity), _endMax(width));
    return math.max(height(_lead, math.max(0.0, width - _gap - endWidth)), height(end, endWidth));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
