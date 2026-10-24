import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'badge.dart';
import 'button.dart';
import 'grouped_list.dart';
import 'icon_tile.dart';
import 'status.dart';

/// A grouped-list row that ends in one or two buttons, for acting on that one item: revoking a token,
/// retrying what failed (design/components/ActionRow). It sits in a [GroupedSection] (or any group).
///
/// - The row is a [GroupedRow] in geometry: at least `row-height` tall, [GroupedRow.padding] (`space-4`
///   across, `space-2` down), [GroupedRow.gap] (`space-3`) between its parts: an optional [IconTile], the
///   [title] in `body-strong` over the optional [subtitle] in `caption` and `ink-muted`, then at the end the
///   optional status chip ([badge]) and the [actions], `space-2` apart and from the chip.
/// - The buttons are [ButtonVariant.tonal], [ButtonVariant.plain] or [ButtonVariant.plainDanger], never
///   filled: the filled button belongs to the screen's main action. At most two.
/// - A destructive action (Revoke, Remove) is [ButtonVariant.plainDanger]. It always asks first: a dialog
///   that names what will stop working and confirms with a [ButtonVariant.danger] button. The row names the
///   object, so a button may be a verb alone: "Revoke", "Retry".
/// - The buttons are the only targets. The row is not pressable and has no hover fill, so there are never
///   two targets in one place.
/// - When the row is too narrow, the caption wraps first, down to [minTextWidth]; when the text would get
///   less than that (or the title would have to wrap) beside the chip and buttons, they move under the
///   text, [GroupedRow.gap] below it and aligned to its start (after the tile), and wrap further themselves
///   if they still do not fit. A caption is never squeezed into a narrow, tall column.
/// - An item that cannot be acted on any more (a revoked token) keeps its row and chip and loses its
///   buttons; its chip is the inactive one, [MyDataTone.neutral]: red is for errors.
class ActionRow extends StatelessWidget {
  ActionRow({
    super.key,
    this.icon,
    this.tone = MyDataTone.neutral,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
  }) : assert(actions.length <= maxActions, 'an action row ends in at most $maxActions buttons'),
       assert(
         actions.every((b) => allowedVariants.contains(b.variant)),
         'action row buttons are tonal, plain or plainDanger, never filled: the filled button is the '
         "screen's main action (design/components/ActionRow)",
       );

  /// An optional icon on an [IconTile] at the left.
  final MyDataIcon? icon;

  /// The tile's tint. Defaults to [MyDataTone.neutral], the untinted `surface-sunken` tile.
  final MyDataTone tone;

  /// The item's name, in sentence case ("Claude on my laptop").
  final String title;

  /// The secondary line ("Created 1 Oct, last seen today").
  final String? subtitle;

  /// The optional status chip before the buttons ("Connected", "Revoked").
  final MyDataBadge? badge;

  /// The buttons at the end, at most [maxActions]; empty for an item that cannot be acted on any more.
  final List<Button> actions;

  /// Spec: "one or two buttons".
  static const maxActions = 2;

  /// Spec: "The buttons are tonal or plain, never filled"; a destructive one is plain danger.
  static const allowedVariants = {ButtonVariant.tonal, ButtonVariant.plain, ButtonVariant.plainDanger};

  /// Between the chip and the buttons, and between the buttons (preview: `.end{gap:8px}`).
  static double endGap(MyDataLook look) => look.space(2);

  /// The least width the text keeps beside the chip and buttons before they move under it, unless the
  /// text is narrower than this anyway (preview: `.narrow .r .txt{flex:1 1 200px}`).
  static double minTextWidth(MyDataLook look) => look.space(10) * 5;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final end = <Widget>[?badge, ...actions];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: context.density.rowHeight),
        child: Padding(
          padding: GroupedRow.padding(context.look),
          child: _ActionRowLayout(
            tile: icon == null ? null : IconTile(icon: icon!, tone: tone),
            title: Text(title, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
            subtitle: subtitle == null
                ? null
                : Text(subtitle!, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
            end: end.isEmpty
                ? null
                : Wrap(
                    spacing: endGap(context.look),
                    runSpacing: endGap(context.look),
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: end,
                  ),
          ),
        ),
      ),
    );
  }
}

enum _Slot { tile, title, subtitle, end }

/// Lays out the tile, the title over the subtitle, and the end part (chip and buttons). The end part sits
/// beside the text while the title fits on one line beside it, and moves under the text otherwise. A Row
/// or Wrap cannot express "the caption wraps first", so this is a small render object.
class _ActionRowLayout extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _ActionRowLayout({this.tile, required this.title, this.subtitle, this.end});

  final Widget? tile;
  final Widget title;
  final Widget? subtitle;
  final Widget? end;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.tile => tile,
    _Slot.title => title,
    _Slot.subtitle => subtitle,
    _Slot.end => end,
  };

  @override
  _RenderActionRow createRenderObject(BuildContext context) =>
      _RenderActionRow(Directionality.of(context), context.look);

  @override
  void updateRenderObject(BuildContext context, _RenderActionRow renderObject) => renderObject
    ..textDirection = Directionality.of(context)
    ..look = context.look;
}

typedef _Layout = ({
  Size size,
  bool stacked,
  double lead,
  double textWidth,
  Size? tile,
  Size title,
  Size? subtitle,
  BoxConstraints? endConstraints,
  Size? end,
  double topHeight,
});

class _RenderActionRow extends RenderBox with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderActionRow(this._textDirection, this._look);

  double get _gap => GroupedRow.gap(_look);

  MyDataLook _look;
  set look(MyDataLook value) {
    if (value == _look) return;
    _look = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox? get _tile => childForSlot(_Slot.tile);
  RenderBox get _title => childForSlot(_Slot.title)!;
  RenderBox? get _subtitle => childForSlot(_Slot.subtitle);
  RenderBox? get _end => childForSlot(_Slot.end);

  @override
  // Called while children are still being attached, so every slot may be empty here.
  Iterable<RenderBox> get children => [?_tile, ?childForSlot(_Slot.title), ?_subtitle, ?_end];

  /// The x offset of the text from the start edge: past the tile and its gap.
  double get _leadWidth => _tile == null ? 0 : _tile!.getMaxIntrinsicWidth(double.infinity) + _gap;

  /// The width the text needs beside the end part: the title on one line, and room for the caption to
  /// wrap without becoming a narrow column ([ActionRow.minTextWidth], or the caption's own width if less).
  double get _textNeeds => math.max(
    _title.getMaxIntrinsicWidth(double.infinity),
    math.min(ActionRow.minTextWidth(_look), _subtitle?.getMaxIntrinsicWidth(double.infinity) ?? 0),
  );

  /// Whether the end part must go under the text in a row [width] wide.
  bool _stacks(double width) {
    final end = _end;
    if (end == null || !width.isFinite) return false;
    final room = width - _leadWidth - _gap - end.getMaxIntrinsicWidth(double.infinity);
    return room < _textNeeds;
  }

  _Layout _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final bounded = constraints.hasBoundedWidth;
    final tile = _tile;
    final end = _end;
    final subtitle = _subtitle;
    final lead = _leadWidth;
    final stacked = bounded && _stacks(constraints.maxWidth);
    // The end part first: beside the text it may use whatever the text's need leaves (at least its natural
    // width, or the row would have stacked); under the text, the width after the tile.
    BoxConstraints? endConstraints;
    Size? endSize;
    if (end != null) {
      final double maxWidth;
      if (!bounded) {
        maxWidth = double.infinity;
      } else if (stacked) {
        maxWidth = math.max(0.0, constraints.maxWidth - lead);
      } else {
        maxWidth = math.max(0.0, constraints.maxWidth - lead - _gap - _textNeeds);
      }
      endConstraints = BoxConstraints(maxWidth: maxWidth);
      endSize = layoutChild(end, endConstraints);
    }

    final textWidth = bounded
        ? math.max(0.0, constraints.maxWidth - lead - (endSize == null || stacked ? 0 : _gap + endSize.width))
        : math.max(_title.getMaxIntrinsicWidth(double.infinity), subtitle?.getMaxIntrinsicWidth(double.infinity) ?? 0);
    final textConstraints = BoxConstraints(maxWidth: textWidth);
    final tileSize = tile == null ? null : layoutChild(tile, const BoxConstraints());
    final titleSize = layoutChild(_title, textConstraints);
    final subtitleSize = subtitle == null ? null : layoutChild(subtitle, textConstraints);
    final textHeight = titleSize.height + (subtitleSize?.height ?? 0);
    final topHeight = math.max(tileSize?.height ?? 0, textHeight);

    final double contentHeight;
    final double width;
    if (stacked) {
      contentHeight = topHeight + _gap + endSize!.height;
      width = constraints.maxWidth;
    } else {
      contentHeight = math.max(topHeight, endSize?.height ?? 0);
      width = bounded ? constraints.maxWidth : lead + textWidth + (endSize == null ? 0 : _gap + endSize.width);
    }
    return (
      size: constraints.constrain(Size(width, contentHeight)),
      stacked: stacked,
      lead: lead,
      textWidth: textWidth,
      tile: tileSize,
      title: titleSize,
      subtitle: subtitleSize,
      endConstraints: endConstraints,
      end: endSize,
      topHeight: topHeight,
    );
  }

  /// Places a box of [width] at [x] from the start edge, in the current text direction.
  double _x(_Layout l, double x, double width) => _textDirection == TextDirection.ltr ? x : l.size.width - x - width;

  void _place(RenderBox child, Offset offset) => (child.parentData! as BoxParentData).offset = offset;

  @override
  void performLayout() {
    final l = _compute(constraints, ChildLayoutHelper.layoutChild);
    size = l.size;
    final contentHeight = l.stacked ? l.topHeight + _gap + l.end!.height : math.max(l.topHeight, l.end?.height ?? 0);
    // The whole content is centred in the row's minimum height; the top line's parts are centred on it.
    final top = (size.height - contentHeight) / 2;
    final lineHeight = l.stacked ? l.topHeight : contentHeight;
    final tile = _tile;
    if (tile != null) _place(tile, Offset(_x(l, 0, l.tile!.width), top + (lineHeight - l.tile!.height) / 2));
    final textHeight = l.title.height + (l.subtitle?.height ?? 0);
    final textTop = top + (lineHeight - textHeight) / 2;
    _place(_title, Offset(_x(l, l.lead, l.title.width), textTop));
    final subtitle = _subtitle;
    if (subtitle != null) _place(subtitle, Offset(_x(l, l.lead, l.subtitle!.width), textTop + l.title.height));
    final end = _end;
    if (end != null) {
      _place(
        end,
        l.stacked
            ? Offset(_x(l, l.lead, l.end!.width), top + l.topHeight + _gap)
            : Offset(_x(l, size.width - l.end!.width, l.end!.width), top + (lineHeight - l.end!.height) / 2),
      );
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final title = _title;
    final offset = (title.parentData! as BoxParentData).offset.dy;
    final b = title.getDistanceToActualBaseline(baseline);
    return b == null ? null : b + offset;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    // Narrowest: the end part under the text, everything at its narrowest.
    final lead = _leadWidth;
    return lead +
        [
          _title.getMinIntrinsicWidth(double.infinity),
          _subtitle?.getMinIntrinsicWidth(double.infinity) ?? 0,
          _end?.getMinIntrinsicWidth(double.infinity) ?? 0,
        ].reduce(math.max);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final end = _end;
    return _leadWidth +
        math.max(_title.getMaxIntrinsicWidth(double.infinity), _subtitle?.getMaxIntrinsicWidth(double.infinity) ?? 0) +
        (end == null ? 0 : _gap + end.getMaxIntrinsicWidth(double.infinity));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    if (!width.isFinite) return getDryLayout(const BoxConstraints()).height;
    return getDryLayout(BoxConstraints(maxWidth: width)).height;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }
}
