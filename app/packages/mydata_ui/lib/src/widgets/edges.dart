import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/look.dart';
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
    final edge = MyDataEdgesPaint.cardEdge(context.look, radius);
    if (edge == null) return child;
    return DecoratedBox(decoration: edge, position: DecorationPosition.foreground, child: child);
  }
}

/// The rule between two rows, in the theme's separator style: nothing for `none`, from [inset] for `inset`
/// (where the row's text starts), across the whole width for `full`. It is [MyDataEdges.separatorExtent]
/// tall, unless [extent] fixes it (a list whose row heights are counted ahead draws it in its slot).
/// [colour] stands in for the theme's (a run of selected rows hides it in its own fill).
class EdgeRule extends StatelessWidget {
  const EdgeRule({super.key, this.inset = 0, this.colour, this.extent});

  final double inset;
  final Color? colour;
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final edges = context.look.edges;
    final height = extent ?? edges.separatorExtent;
    if (height <= 0) return const SizedBox.shrink();
    if (edges.separators == Separators.none) return SizedBox(height: height);
    return CustomPaint(
      size: Size.fromHeight(height),
      painter: _RulePainter(
        side: BorderSide(color: colour ?? edges.colour, width: math.min(edges.width, height)),
        style: edges.style,
        start: edges.separators == Separators.inset ? inset : 0,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

/// A horizontal rule in [style], [start] in from the leading edge.
class _RulePainter extends CustomPainter {
  _RulePainter({required this.side, required this.style, required this.start, required this.textDirection});
  final BorderSide side;
  final BorderStyleKind style;
  final double start;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final w = side.width;
    final from = textDirection == TextDirection.rtl ? 0.0 : start;
    final to = textDirection == TextDirection.rtl ? size.width - start : size.width;
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
      old.side != side || old.style != style || old.start != start || old.textDirection != textDirection;
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
