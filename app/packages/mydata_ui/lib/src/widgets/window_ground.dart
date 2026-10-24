import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart' show MyDataColors;
import '../theme/theme.dart';
import '../theme/theme_file.dart' show PatternSpec, WindowKind;
import '../theme/roles.dart';

/// The window's ground behind [child], in the theme's material (`materials.window`,
/// design/themes/ARCHITECTURE.md 3.5):
///
/// - `solid`: `bg` (Kiwi);
/// - `gradient`: the palette's two or three stops at the theme's angle (CSS degrees: 0 runs to the top, 90
///   to the right), painted once;
/// - `pattern`: `bg` with dots, a grid, ruled lines, ruled lines and a margin rule, grain or scan lines in
///   the pattern's colour at its opacity, painted once behind the content in a [RepaintBoundary], never per
///   row. With reduced transparency it is plain `bg`;
/// - `image`: plain `bg` until phase 6 (no images in theme files yet, decided 2026-10-23).
///
/// Content always sits on its own surfaces (cards, groups): a pattern is only ever seen on `bg`.
class WindowGround extends StatelessWidget {
  const WindowGround({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final c = context.colors;
    final m = look.materials;
    final spec = m.spec;
    switch (spec.window) {
      case WindowKind.gradient:
        final stops = m.gradient;
        if (stops == null || stops.length < 2) return ColoredBox(color: c.bg, child: child);
        final rad = ((spec.gradientAngle ?? 180) - 90) * math.pi / 180;
        final end = Alignment(math.cos(rad), math.sin(rad));
        return DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: -end, end: end, colors: stops)),
          child: child,
        );
      case WindowKind.pattern when spec.pattern != null && !MyDataAccessibility.of(context).reduceTransparency:
        return ColoredBox(
          color: c.bg,
          child: Stack(fit: StackFit.passthrough, children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: PatternPainter(spec.pattern!, colour: patternColour(spec.pattern!, c))),
              ),
            ),
            child,
          ]),
        );
      default:
        return ColoredBox(color: c.bg, child: child);
    }
  }

  /// The pattern's colour: its role at its opacity.
  static Color patternColour(PatternSpec p, MyDataColors c) {
    final base = switch (p.colour) {
      ColourRole.ink => c.ink,
      ColourRole.accent => c.accent,
      _ => c.line,
    };
    return base.withValues(alpha: p.opacity);
  }
}

/// A window pattern (`materials.window.pattern`), every [PatternSpec.spacing] px: dots, a grid, ruled lines,
/// ruled lines with a margin rule three spacings in, grain (dots scattered the same way every time) or scan
/// lines (1px lines half a spacing apart).
class PatternPainter extends CustomPainter {
  PatternPainter(this.spec, {required this.colour});
  final PatternSpec spec;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1;
    final step = spec.spacing;
    void rows(double gap) {
      for (var y = gap; y < size.height; y += gap) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    switch (spec.kind) {
      case 'dots':
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 1, paint);
          }
        }
      case 'grid':
        rows(step);
        for (var x = step; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
      case 'ruled':
        rows(step);
      case 'margin-rule':
        rows(step);
        canvas.drawLine(Offset(step * 3, 0), Offset(step * 3, size.height), paint..strokeWidth = 2);
      case 'scanlines':
        rows(math.max(2, step / 2));
      case 'grain':
        // The same scatter every time: a fixed seed, about one grain per 6 square px.
        final r = math.Random(7);
        final n = (size.width * size.height / 6).clamp(0, 400000).toInt();
        final xy = Float32List(n * 2);
        for (var i = 0; i < n; i++) {
          xy[2 * i] = r.nextDouble() * size.width;
          xy[2 * i + 1] = r.nextDouble() * size.height;
        }
        canvas.drawRawPoints(PointMode.points, xy, paint);
    }
  }

  @override
  bool shouldRepaint(PatternPainter old) =>
      old.colour != colour || old.spec.kind != spec.kind || old.spec.spacing != spec.spacing;
}
