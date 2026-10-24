import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The theme's borders where they are drawn (design/themes/ARCHITECTURE.md 1.2, `borders`): the outline of
/// a card or group, the rule between rows, and the rule under a page's title. Cards and separators take the
/// theme's style (solid, dashed or double); controls are always solid.
abstract final class MyDataEdgesPaint {
  /// The outline of a card or a group of rows with corners [radius], as a decoration drawn over its
  /// content (so a row's hover or selected fill never covers it), or null when the theme outlines no cards.
  static Decoration? cardEdge(MyDataLook look, BorderRadius radius) {
    final edge = look.edges.card;
    if (edge == null) return null;
    if (look.edges.style == BorderStyleKind.solid) {
      return look.shape.decorate(BoxDecoration(borderRadius: radius, border: Border.fromBorderSide(edge)));
    }
    return _StyledEdgeDecoration(
        base: const BoxDecoration(), shape: look.shape, radius: radius, side: edge, style: look.edges.style);
  }

  /// The outline of a control (a button with a fill, a field), or null when the theme draws none.
  static Border? control(MyDataLook look) => look.edges.controls ? Border.fromBorderSide(look.edges.side) : null;

  /// Strokes [path] as [style]: solid, dashed (dashes three widths long, two apart), or a double line drawn
  /// as [path] and [inner] (the same outline two widths further in).
  static void stroke(Canvas canvas, Path path, BorderSide side, BorderStyleKind style, {Path? inner}) {
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width;
    switch (style) {
      case BorderStyleKind.solid:
        canvas.drawPath(path, paint);
      case BorderStyleKind.dashed:
        final dash = math.max(3.0, side.width * 3), gap = math.max(2.0, side.width * 2);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += dash + gap) {
            canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
          }
        }
      case BorderStyleKind.doubleLine:
        canvas.drawPath(path, paint);
        if (inner != null) canvas.drawPath(inner, paint);
    }
  }
}

/// A decoration with an outline in a dashed or double style, drawn on the look's corners over [base].
class _StyledEdgeDecoration extends Decoration {
  const _StyledEdgeDecoration({
    required this.base,
    required this.shape,
    required this.radius,
    required this.side,
    required this.style,
  });

  final Decoration base;
  final MyDataShape shape;
  final BorderRadius radius;
  final BorderSide side;
  final BorderStyleKind style;

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => base.getClipPath(rect, textDirection);

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      base.hitTest(size, position, textDirection: textDirection);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _StyledEdgePainter(this, onChanged == null ? base.createBoxPainter() : base.createBoxPainter(onChanged));

  @override
  bool operator ==(Object other) =>
      other is _StyledEdgeDecoration &&
      other.base == base &&
      other.shape.corners == shape.corners &&
      other.shape.cutSize == shape.cutSize &&
      other.radius == radius &&
      other.side == side &&
      other.style == style;

  @override
  int get hashCode => Object.hash(base, shape.corners, shape.cutSize, radius, side, style);
}

class _StyledEdgePainter extends BoxPainter {
  _StyledEdgePainter(this.d, this.base);
  final _StyledEdgeDecoration d;
  final BoxPainter base;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    base.paint(canvas, offset, configuration);
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final w = d.side.width;
    final outer = d.shape.ringPath(rect, d.radius, -w / 2);
    final inner = d.style == BorderStyleKind.doubleLine ? d.shape.ringPath(rect, d.radius, -w * 2.5) : null;
    MyDataEdgesPaint.stroke(canvas, outer, d.side, d.style, inner: inner);
  }

  @override
  void dispose() {
    base.dispose();
    super.dispose();
  }
}

/// Draws the theme's card outline ([MyDataEdgesPaint.cardEdge]) over [child], a card or group with corners
/// [radius]; [child] alone when the theme outlines no cards.
class CardEdge extends StatelessWidget {
  const CardEdge({super.key, required this.radius, required this.child});
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final edge = MyDataEdgesPaint.cardEdge(look, radius);
    var out = child;
    final bevel = look.elevation.bevel;
    if (bevel != null) out = CustomPaint(foregroundPainter: BevelPainter(bevel, shape: look.shape, radius: radius), child: out);
    if (edge == null) return out;
    return DecoratedBox(decoration: edge, position: DecorationPosition.foreground, child: out);
  }
}

/// A bevel (`elevation.style: bevel`): one line of [Bevel.light] along the top and left edges and one of
/// [Bevel.dark] along the bottom and right, inside the shape; [pressed] swaps them, so the control reads as
/// pushed in. The lines are [width] wide, clipped to the shape so they follow its corners.
class BevelPainter extends CustomPainter {
  BevelPainter(this.bevel, {required this.shape, required this.radius, this.pressed = false, this.width = 1});
  final Bevel bevel;
  final MyDataShape shape;
  final BorderRadius radius;
  final bool pressed;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final lit = Paint()..color = pressed ? bevel.dark : bevel.light;
    final shade = Paint()..color = pressed ? bevel.light : bevel.dark;
    canvas
      ..save()
      ..clipPath(shape.path(rect, radius))
      ..drawRect(Rect.fromLTWH(0, 0, size.width, width), lit)
      ..drawRect(Rect.fromLTWH(0, 0, width, size.height), lit)
      ..drawRect(Rect.fromLTWH(0, size.height - width, size.width, width), shade)
      ..drawRect(Rect.fromLTWH(size.width - width, 0, width, size.height), shade)
      ..restore();
  }

  @override
  bool shouldRepaint(BevelPainter old) =>
      old.bevel != bevel ||
      old.shape.corners != shape.corners ||
      old.radius != radius ||
      old.pressed != pressed ||
      old.width != width;
}

/// The rule between two rows, in the theme's separator style: nothing for `none`, from [inset] for `inset`
/// (where the row's text starts), across the whole width for `full`. It is [MyDataEdges.separatorExtent]
/// tall, unless [extent] fixes it (a list whose row heights are counted ahead draws it in its slot).
/// [colour] stands in for the theme's (a run of selected rows hides it in its own fill).
///
/// [inCard]: the rule is inside a group with the theme's card outline. A double outline's inner line runs
/// two widths in from the edge; the rule then stops at that inner line instead of crossing it to the outer
/// one ([innerOutlineInset]).
class EdgeRule extends StatelessWidget {
  const EdgeRule({super.key, this.inset = 0, this.colour, this.extent, this.inCard = false});

  final double inset;
  final Color? colour;
  final double? extent;
  final bool inCard;

  /// How far in from a card's sides its rules start and end: to the inner line of a double outline (which
  /// lies from two to three widths in), else nothing.
  static double innerOutlineInset(MyDataEdges edges) =>
      edges.card != null && edges.style == BorderStyleKind.doubleLine ? edges.width * 2 : 0;

  @override
  Widget build(BuildContext context) {
    final edges = context.look.edges;
    final height = extent ?? edges.separatorExtent;
    if (height <= 0) return const SizedBox.shrink();
    if (edges.separators == Separators.none) return SizedBox(height: height);
    final side = inCard ? innerOutlineInset(edges) : 0.0;
    return CustomPaint(
      size: Size.fromHeight(height),
      painter: _RulePainter(
        side: BorderSide(color: colour ?? edges.colour, width: math.min(edges.width, height)),
        style: edges.style,
        start: math.max(side, edges.separators == Separators.inset ? inset : 0),
        end: side,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

/// A horizontal rule in [style], [start] in from the leading edge and [end] in from the trailing one.
class _RulePainter extends CustomPainter {
  _RulePainter({required this.side, required this.style, required this.start, this.end = 0, required this.textDirection});
  final BorderSide side;
  final BorderStyleKind style;
  final double start;
  final double end;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final w = side.width;
    final rtl = textDirection == TextDirection.rtl;
    final from = rtl ? end : start;
    final to = size.width - (rtl ? start : end);
    if (to <= from) return;
    Path line(double y) => Path()
      ..moveTo(from, y)
      ..lineTo(to, y);
    final twoLines = style == BorderStyleKind.doubleLine && size.height >= w * 3;
    if (twoLines) {
      MyDataEdgesPaint.stroke(canvas, line(w / 2), side, BorderStyleKind.doubleLine, inner: line(w * 2.5));
    } else {
      MyDataEdgesPaint.stroke(canvas, line(size.height / 2), side,
          style == BorderStyleKind.doubleLine ? BorderStyleKind.solid : style);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.side != side ||
      old.style != style ||
      old.start != start ||
      old.end != end ||
      old.textDirection != textDirection;
}

/// The rule under a page's title (`borders.title-rule`): one or two lines in the theme's edge colour and
/// width, across the title row. Nothing for `none`.
class TitleRuleLine extends StatelessWidget {
  const TitleRuleLine({super.key});

  @override
  Widget build(BuildContext context) {
    final edges = context.look.edges;
    final h = edges.titleRuleExtent;
    if (h <= 0) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.fromHeight(h),
      painter: _RulePainter(
        side: edges.side,
        style: edges.titleRule == TitleRule.doubleLine ? BorderStyleKind.doubleLine : BorderStyleKind.solid,
        start: 0,
        textDirection: Directionality.of(context),
      ),
    );
  }
}
