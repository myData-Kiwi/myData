import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pressable.dart' show MyDataRadii;

/// The box of every field (a text field, a select, a picker, a token field) in the theme's input style
/// (`components.inputs`, design/themes/ARCHITECTURE.md 3.2):
///
/// - `outlined` (Kiwi): `surface` with `radius-md` and a [width] outline in [edge];
/// - `filled`: a `surface-sunken` well with `radius-md`, its edge only a [width] line along the bottom;
/// - `underlined`: no box, only the line along the bottom.
///
/// In error the outline or the line is `danger` (the field passes [edge]). Hovering fills it with
/// `surface-hover` where the field lights up ([hovered]). The line and the outline grow inward, so the text
/// never moves.
abstract final class InputBox {
  /// A field's outline or line at rest.
  static const borderWidth = 1.0;

  /// The field's box in [look]. [edge] is its outline or line colour (`line-strong`; `danger` in error),
  /// [width] its width (1px; 2px in error).
  static Decoration of(MyDataLook look, {required Color edge, required double width, bool hovered = false}) {
    final c = look.colors;
    final radius = MyDataRadii.md(look);
    final side = BorderSide(color: edge, width: width);
    return switch (look.variants.inputs) {
      InputStyle.outlined => look.shape.decorate(BoxDecoration(
          color: hovered ? c.surfaceHover : c.surface, borderRadius: radius, border: Border.fromBorderSide(side))),
      InputStyle.filled => _UnderlinedBox(
          fill: hovered ? c.surfaceHover : c.surfaceSunken, shape: look.shape, radius: radius, line: side),
      InputStyle.underlined =>
        _UnderlinedBox(fill: hovered ? c.surfaceHover : null, shape: look.shape, radius: BorderRadius.zero, line: side),
    };
  }

  /// Between a field's edge and its text: `space-4` in a box, nothing for an underlined field, whose text
  /// lines up with its label.
  static double inset(MyDataLook look) => look.variants.inputs == InputStyle.underlined ? 0 : look.space(4);

  /// Whether [look]'s fields have a box with corners (outlined or filled), for a focus ring that follows it.
  static bool boxed(MyDataLook look) => look.variants.inputs != InputStyle.underlined;
}

/// A fill in the look's corner style with one line along its bottom edge, clipped to the shape.
class _UnderlinedBox extends Decoration {
  const _UnderlinedBox({required this.fill, required this.shape, required this.radius, required this.line});
  final Color? fill;
  final MyDataShape shape;
  final BorderRadius radius;
  final BorderSide line;

  /// As much room as a [Border] of the line's width takes, so the text sits where an outlined field's does.
  @override
  EdgeInsetsGeometry get padding => EdgeInsets.all(line.width);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _UnderlinedPainter(this);

  @override
  bool operator ==(Object other) =>
      other is _UnderlinedBox &&
      other.fill == fill &&
      other.shape.corners == shape.corners &&
      other.shape.cutSize == shape.cutSize &&
      other.radius == radius &&
      other.line == line;

  @override
  int get hashCode => Object.hash(fill, shape.corners, shape.cutSize, radius, line);
}

class _UnderlinedPainter extends BoxPainter {
  _UnderlinedPainter(this.d);
  final _UnderlinedBox d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final path = d.shape.path(rect, d.radius);
    canvas.save();
    canvas.clipPath(path);
    final fill = d.fill;
    if (fill != null) canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.bottom - d.line.width, rect.right, rect.bottom), Paint()..color = d.line.color);
    canvas.restore();
  }
}
