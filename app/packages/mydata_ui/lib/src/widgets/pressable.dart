import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';

/// The press, hover and focus behaviour every interactive control in the design system shares
/// (design/motion.md, design/README.md "Accessibility"):
///
/// - pressing dims to 85% and scales to 97% at once, and returns over `fast` (no scale with reduced motion);
/// - Enter and Space activate it; it is reachable with Tab;
/// - keyboard focus draws a 2px `focus` ring 2px outside the shape given by [borderRadius];
/// - [hoverFill], when given, fills the shape while hovered or pressed (rows); controls leave it null;
/// - disabled: 45% opacity, no focus, no cursor change (the previews' disabled state).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onPressed,
    required this.child,
    required this.borderRadius,
    this.hoverFill,
    this.scaleOnPress = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.button = true,
    this.selected,
    this.toggled,
    this.tooltip,
  });

  /// Null disables the control.
  final VoidCallback? onPressed;
  final Widget child;
  final BorderRadius borderRadius;
  final Color? hoverFill;

  /// Rows fill instead of shrinking; buttons and chips shrink.
  final bool scaleOnPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final bool button;
  final bool? selected;
  final bool? toggled;
  final String? tooltip;

  /// Opacity of a disabled control.
  static const disabledOpacity = 0.45;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _activate() {
    if (!_enabled) return;
    widget.onPressed!();
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    if (!_enabled && (_pressed || _hovered)) {
      _pressed = false;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final down = _pressed && _enabled;
    Widget body = widget.child;
    if (widget.hoverFill != null) {
      body = AnimatedContainer(
        duration: MyDataMotion.fast,
        curve: MyDataMotion.standard,
        decoration: BoxDecoration(
            color: (_hovered || down) && _enabled ? widget.hoverFill : widget.hoverFill!.withValues(alpha: 0),
            borderRadius: widget.borderRadius),
        child: body,
      );
    }
    // Press: in at once (duration zero on the way down), out over `fast`.
    body = AnimatedOpacity(
      opacity: !_enabled ? Pressable.disabledOpacity : (down ? MyDataMotion.pressOpacity : 1),
      duration: down ? Duration.zero : MyDataMotion.fast,
      curve: MyDataMotion.standard,
      child: widget.scaleOnPress && !reduced
          ? AnimatedScale(
              scale: down ? MyDataMotion.pressScale : 1,
              duration: down ? Duration.zero : MyDataMotion.fast,
              curve: MyDataMotion.standard,
              child: body)
          : body,
    );
    body = CustomPaint(
      foregroundPainter: _focused && _enabled ? _FocusRingPainter(c.focus, widget.borderRadius) : null,
      child: body,
    );
    body = FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? _activate : null,
        child: body,
      ),
    );
    body = Semantics(
      button: widget.button,
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      child: body,
    );
    if (widget.tooltip != null) body = Tooltip(message: widget.tooltip!, child: body);
    return body;
  }
}

/// The keyboard focus ring: 2px of `focus`, 2px outside the control (tokens.json "focus").
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter(this.color, this.radius);
  final Color color;
  final BorderRadius radius;

  static const width = 2.0;
  static const offset = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(offset + width / 2);
    final r = radius.resolve(TextDirection.ltr);
    final grown = RRect.fromRectAndCorners(rect,
        topLeft: r.topLeft + const Radius.circular(offset + width / 2),
        topRight: r.topRight + const Radius.circular(offset + width / 2),
        bottomLeft: r.bottomLeft + const Radius.circular(offset + width / 2),
        bottomRight: r.bottomRight + const Radius.circular(offset + width / 2));
    canvas.drawRRect(grown, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) => old.color != color || old.radius != radius;
}

/// Draws the focus ring around a non-[Pressable] focusable thing (a text field), when [visible].
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.visible, required this.borderRadius, required this.child});
  final bool visible;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter: visible ? _FocusRingPainter(context.colors.focus, borderRadius) : null, child: child);
}

/// Radii as BorderRadius, for the shapes the tokens name.
abstract final class MyDataRadii {
  static const sm = BorderRadius.all(Radius.circular(MyDataRadius.sm));
  static const md = BorderRadius.all(Radius.circular(MyDataRadius.md));
  static const lg = BorderRadius.all(Radius.circular(MyDataRadius.lg));
  static const xl = BorderRadius.all(Radius.circular(MyDataRadius.xl));
  static const control = BorderRadius.all(Radius.circular(MyDataRadius.control));
  static const pill = BorderRadius.all(Radius.circular(MyDataRadius.pill));
}
