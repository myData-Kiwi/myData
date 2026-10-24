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

  /// The outline of a control (a button with a fill, a field), or null when the theme draws none; never in
  /// the faint `line` ([MyDataEdges.controlColour]).
  static Border? control(MyDataLook look) => look.edges.controls ? Border.fromBorderSide(look.edges.controlSide) : null;

  /// Strokes [path] as [style]: solid, dashed (dashes three widths long, two apart: [dashes]), or a double
  /// line drawn as [path] and [inner] (the same outline two widths further in). A painter that keeps its
  /// [path] while its size stays the same has its dashes worked out once.
  static void stroke(Canvas canvas, Path path, BorderSide side, BorderStyleKind style, {Path? inner}) {
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width;
    switch (style) {
      case BorderStyleKind.solid:
        canvas.drawPath(path, paint);
      case BorderStyleKind.dashed:
        canvas.drawPath(_dashed[path] ??= dashes(path, side.width), paint);
      case BorderStyleKind.doubleLine:
        canvas.drawPath(path, paint);
        if (inner != null) canvas.drawPath(inner, paint);
    }
  }

  static final _dashed = Expando<Path>('dashes');

  /// [path]'s dashes for a line [width] wide, as one path: about three widths on and two off, the period
  /// stretched a little so it fits each contour evenly. A closed outline has whole periods, so no short or
  /// doubled dash at its seam; an open line starts and ends on a dash.
  static Path dashes(Path path, double width) {
    final dash = math.max(3.0, width * 3), gap = math.max(2.0, width * 2);
    final out = Path();
    for (final m in path.computeMetrics()) {
      if (m.length <= dash) {
        out.addPath(m.extractPath(0, m.length), Offset.zero);
        continue;
      }
      // Closed: n periods round the contour. Open: n dashes and n - 1 gaps along it.
      final n = m.isClosed
          ? math.max(1, (m.length / (dash + gap)).round())
          : math.max(1, ((m.length + gap) / (dash + gap)).round());
      final period = m.isClosed ? m.length / n : m.length / (n - gap / (dash + gap));
      final on = period * dash / (dash + gap);
      for (var i = 0; i < n; i++) {
        final d = i * period;
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      }
    }
    return out;
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
    if (rect != _rect) {
      final w = d.side.width;
      _rect = rect;
      _outer = d.shape.ringPath(rect, d.radius, -w / 2);
      _inner = d.style == BorderStyleKind.doubleLine ? d.shape.ringPath(rect, d.radius, -w * 2.5) : null;
    }
    MyDataEdgesPaint.stroke(canvas, _outer!, d.side, d.style, inner: _inner);
  }

  // The outline as last drawn: kept while the box does not move or resize, with its dashes.
  Rect? _rect;
  Path? _outer, _inner;

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
    if (bevel != null) {
      out = CustomPaint(
          foregroundPainter: BevelPainter(bevel, shape: look.shape, radius: radius, fill: context.colors.surface),
          child: out);
    }
    if (edge == null) return out;
    return DecoratedBox(decoration: edge, position: DecorationPosition.foreground, child: out);
  }
}

/// A bevel (`elevation.style: bevel`): one line of [Bevel.light] along the top and left edges and one of
/// [Bevel.dark] along the bottom and right, inside the shape; [pressed] swaps them, so the control reads as
/// pushed in. Each line is the shape's own outline, [width] wide and drawn just inside it, so it follows a
/// pill's ends and a cut corner's chamfer. The two meet on 45° lines through the top-right and bottom-left
/// corners (a mitre), as a window frame's bevel does.
///
/// Given the [fill] it is drawn on, the light line is made more opaque until it is at least [lightContrast]
/// against it (a light line at 0.9 alpha on a mid accent was nearly invisible), where its own colour,
/// opaque, can reach that.
class BevelPainter extends CustomPainter {
  BevelPainter(this.bevel, {required this.shape, required this.radius, this.pressed = false, this.width = 1, this.fill});
  final Bevel bevel;
  final MyDataShape shape;
  final BorderRadius radius;
  final bool pressed;
  final double width;
  final Color? fill;

  /// The least contrast of the light line against [fill].
  static const lightContrast = 1.5;

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [light] as it shows on [fill], made more opaque until it is [lightContrast] from [fill], or opaque.
  static Color liftedLight(Color light, Color fill) {
    final opaque = light.withValues(alpha: 1);
    final shown = Color.alphaBlend(light, fill);
    for (var step = 0; step <= 20; step++) {
      final c = Color.lerp(shown, opaque, step / 20)!;
      if (_contrast(c, fill) >= lightContrast) return c;
    }
    return opaque;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height, m = math.min(w, h) / 2;
    final light = fill == null ? bevel.light : liftedLight(bevel.light, fill!);
    final line = shape.ringPath(rect, radius, -width / 2);
    // The top-left half and the bottom-right half, split on 45° lines through the two corners.
    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w - m, m)
      ..lineTo(m, h - m)
      ..lineTo(0, h)
      ..close();
    final bottomRight = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(m, h - m)
      ..lineTo(w - m, m)
      ..close();
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas
      ..save()
      ..clipPath(shape.path(rect, radius))
      ..save()
      ..clipPath(topLeft)
      ..drawPath(line, stroke(pressed ? bevel.dark : light))
      ..restore()
      ..clipPath(bottomRight)
      ..drawPath(line, stroke(pressed ? light : bevel.dark))
      ..restore();
  }

  @override
  bool shouldRepaint(BevelPainter old) =>
      old.bevel != bevel ||
      old.shape.corners != shape.corners ||
      old.shape.cutSize != shape.cutSize ||
      old.radius != radius ||
      old.pressed != pressed ||
      old.width != width ||
      old.fill != fill;
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
  const EdgeRule({
    super.key,
    this.inset = 0,
    this.colour,
    this.extent,
    this.inCard = false,
    this.separators,
    this.edgeOnly = false,
  });

  final double inset;
  final Color? colour;
  final double? extent;
  final bool inCard;

  /// Stands in for the theme's separators (a ruled list and a table always rule their rows, full width).
  final Separators? separators;

  /// A list's own edge (a ruled list's top and bottom, under a table's header band): one solid line of the
  /// border's width, never double or dashed.
  final bool edgeOnly;

  /// How far in from a card's sides its rules start and end: to the inner line of a double outline (which
  /// lies from two to three widths in), else nothing.
  static double innerOutlineInset(MyDataEdges edges) =>
      edges.card != null && edges.style == BorderStyleKind.doubleLine ? edges.width * 2 : 0;

  @override
  Widget build(BuildContext context) {
    final edges = context.look.edges;
    final separators = this.separators ?? edges.separators;
    final double height = extent ??
        (edgeOnly
            ? edges.width
            : switch (separators) {
                Separators.none => 0,
                _ => edges.style == BorderStyleKind.doubleLine ? edges.width * 3 : edges.width,
              });
    if (height <= 0) return const SizedBox.shrink();
    if (separators == Separators.none) return SizedBox(height: height);
    final side = inCard ? innerOutlineInset(edges) : 0.0;
    return CustomPaint(
      size: Size.fromHeight(height),
      painter: _RulePainter(
        side: BorderSide(color: colour ?? edges.colour, width: math.min(edges.width, height)),
        style: edgeOnly ? BorderStyleKind.solid : edges.style,
        start: math.max(side, separators == Separators.inset ? inset : 0),
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
    if (size != _size) {
      _size = size;
      _line = line(twoLines ? w / 2 : size.height / 2);
      _second = twoLines ? line(w * 2.5) : null;
    }
    if (twoLines) {
      MyDataEdgesPaint.stroke(canvas, _line!, side, BorderStyleKind.doubleLine, inner: _second);
    } else {
      MyDataEdgesPaint.stroke(canvas, _line!, side, style == BorderStyleKind.doubleLine ? BorderStyleKind.solid : style);
    }
  }

  // The rule as last drawn, kept while the size stays (a list repainting on hover reuses its dashes).
  Size? _size;
  Path? _line, _second;

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
