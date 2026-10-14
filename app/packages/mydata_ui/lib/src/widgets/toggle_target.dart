import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_scope.dart';

// Not exported from the package: the shared behaviour of a Checkbox and a form Switch row, whose look
// (where the hover fill and the focus ring go) differs from a [Pressable]'s.

/// Space on a [ToggleTarget]. Not [ActivateIntent], which the app also maps to Return.
class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

/// What a [ToggleTarget] reports to its builder.
@immutable
class ToggleTargetState {
  const ToggleTargetState({required this.hovered, required this.pressed, required this.focused});

  /// The pointer is over the target (never while disabled).
  final bool hovered;

  /// A press is down on the target (never while disabled).
  final bool pressed;

  /// Keyboard focus is on the target and should show its ring.
  final bool focused;
}

/// A target that flips a value: a click or tap anywhere on it, or **Space** when it has focus. Unlike a
/// [Pressable], Return does nothing: a Checkbox and a form Switch leave Return to the dialog's or form's main
/// button (design/components/Checkbox and Switch, "Keyboard").
///
/// It draws nothing itself: [builder] gets the hover, press and focus state and places the fill, the dim
/// and the ring where its spec puts them. [onToggle] null disables it: no focus, no hover, no cursor. While
/// its form waits for the host ([FormBusy]) it keeps its focus and hover but does not flip.
class ToggleTarget extends StatefulWidget {
  const ToggleTarget({
    super.key,
    required this.onToggle,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onToggle;
  final Widget Function(BuildContext context, ToggleTargetState state) builder;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<ToggleTarget> createState() => _ToggleTargetState();
}

class _ToggleTargetState extends State<ToggleTarget> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onToggle != null;

  @override
  void didUpdateWidget(ToggleTarget old) {
    super.didUpdateWidget(old);
    if (!_enabled) {
      _hovered = false;
      _pressed = false;
    }
  }

  /// Flips, unless the form around waits for the host.
  void _toggle() {
    if (!FormBusy.read(context)) widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        shortcuts: const {SingleActivator(LogicalKeyboardKey.space): _ToggleIntent()},
        actions: {
          _ToggleIntent: CallbackAction<_ToggleIntent>(onInvoke: (_) {
            _toggle();
            return null;
          }),
        },
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: _enabled ? _toggle : null,
          child: widget.builder(
              context,
              ToggleTargetState(
                  hovered: _hovered && _enabled, pressed: _pressed && _enabled, focused: _focused && _enabled)),
        ),
      );
}

/// A 2px ring drawn **inside** a shape, from its edge inwards by [inset] plus the ring's width: the focus
/// ring of a row in a list, a list box's highlighted item, or a selected run's `ink` ring, where a ring
/// outside the shape would be covered by the neighbouring rows.
///
/// [top] and [bottom] false leave out that edge (a run of selected rows shares one ring, open where two
/// rows meet); the corners on an open side are then square.
class InsetRingPainter extends CustomPainter {
  InsetRingPainter({
    required this.color,
    this.borderRadius = BorderRadius.zero,
    this.inset = 0,
    this.width = 2,
    this.top = true,
    this.bottom = true,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double inset;
  final double width;
  final bool top;
  final bool bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final outer = (Offset.zero & size).deflate(inset);
    if (outer.isEmpty) return;
    final r = borderRadius.resolve(TextDirection.ltr);
    Radius shrink(Radius x) => Radius.circular((x.x - inset).clamp(0, double.infinity));
    final o = RRect.fromRectAndCorners(outer,
        topLeft: top ? shrink(r.topLeft) : Radius.zero,
        topRight: top ? shrink(r.topRight) : Radius.zero,
        bottomLeft: bottom ? shrink(r.bottomLeft) : Radius.zero,
        bottomRight: bottom ? shrink(r.bottomRight) : Radius.zero);
    // The inner edge: deflated by the ring's width, except on an open side, where it reaches past the edge
    // so nothing is drawn there.
    final innerRect = Rect.fromLTRB(outer.left + width, outer.top + (top ? width : -1), outer.right - width,
        outer.bottom - (bottom ? width : -1));
    Radius less(Radius x) => Radius.circular((x.x - width).clamp(0, double.infinity));
    final i = RRect.fromRectAndCorners(innerRect,
        topLeft: less(o.tlRadius), topRight: less(o.trRadius), bottomLeft: less(o.blRadius), bottomRight: less(o.brRadius));
    // Even-odd fill of the two shapes, clipped to the outer one: the outer shape less the inner, which may
    // reach past it on an open side.
    canvas
      ..save()
      ..clipRRect(o)
      ..drawPath(Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(o)
        ..addRRect(i), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(InsetRingPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.inset != inset ||
      old.width != width ||
      old.top != top ||
      old.bottom != bottom;
}
