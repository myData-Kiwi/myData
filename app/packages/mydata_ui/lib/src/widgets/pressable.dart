import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../theme/theme.dart';

/// The press, hover and focus behaviour every interactive control in the design system shares
/// (design/motion.md, design/README.md "Accessibility"):
///
/// - pressing dims to 85% and scales to 97% at once, and returns over `fast` (no scale with reduced motion);
/// - Enter and Space activate it; it is reachable with Tab;
/// - keyboard focus draws a 2px `focus` ring 2px outside the shape given by [borderRadius], in `ink` instead
///   when [danger] says the control is already red (design/README.md "Focus and danger"); in the Mac frame
///   the system's ring ([FocusRing.painter]);
/// - [hoverFill], when given, fills the shape while hovered or pressed (rows); controls leave it null;
/// - disabled ([onPressed] null): 45% opacity, no focus, no cursor change (the previews' disabled state);
///   a control that draws its own disabled look (a filled button on `surface-sunken`) sets [fadeWhenDisabled]
///   false;
/// - disabled with a [disabledReason]: focusable but inert (design/platforms.md "Disabled controls"), for a
///   control whose reason shows only on demand (an icon button's tooltip, a menu item's caption).
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
    this.danger = false,
    this.disabledReason,
    this.fadeWhenDisabled = true,
    this.focusOnFill = false,
  });

  /// Null disables the control: out of the Tab order, or focusable but inert with a [disabledReason].
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

  /// The control is drawn in `danger` or `danger-soft` right now (a Danger button, a destructive menu item):
  /// its focus ring is then `ink`, so it cannot be told apart from the red ([FocusRing.colourOf]).
  final bool danger;

  /// Why the control is disabled, as a full sentence with a full stop ("The host cannot be reached.").
  ///
  /// Only read while [onPressed] is null. Given, the disabled control **stays focusable** (design/platforms.md
  /// "Disabled controls"): Tab and arrow keys reach it and keyboard focus draws the ring, it is announced as
  /// disabled with the reason as its hint, and pressing, Enter and Space do nothing. It has no hover fill and
  /// no click cursor. With a [tooltip], the tooltip adds the reason on a second line in `ink-muted`, appears
  /// at once on keyboard focus, and on hover as usual. Leave it null where the reason is visible text next to
  /// the control (a help line or caption): the control then leaves the Tab order.
  final String? disabledReason;

  /// The control sits on a filled shape (a solid or inverse selected row): its focus ring is two-tone
  /// ([FocusRing.onFill]).
  final bool focusOnFill;

  /// Whether a disabled control fades to [disabledOpacity]. False for a control that draws its own disabled
  /// colours: a filled button, whose label would fall to about 1.5:1 faded (design/themes/ARCHITECTURE.md 6a).
  final bool fadeWhenDisabled;

  /// Opacity of a disabled control.
  static const disabledOpacity = 0.45;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  final _tooltipKey = GlobalKey<TooltipState>();

  bool get _enabled => widget.onPressed != null;

  /// Disabled, but focusable because its reason shows only on demand.
  bool get _inert => !_enabled && widget.disabledReason != null;

  void _focusHighlight(bool visible) {
    setState(() => _focused = visible);
    if (!_inert || widget.tooltip == null) return;
    // The reason is in the tooltip: keyboard focus shows it at once, and leaving takes it away.
    if (visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tooltipKey.currentState?.ensureTooltipVisible());
    } else {
      Tooltip.dismissAllToolTips();
    }
  }

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
    // The child can draw its own pressed state (a shadow that collapses, a bevel that flips).
    Widget body = PressedScope(pressed: down, child: widget.child);
    if (widget.hoverFill != null) {
      body = AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.standard,
        decoration: context.radius.decorate(BoxDecoration(
            color: (_hovered || down) && _enabled ? widget.hoverFill : widget.hoverFill!.withValues(alpha: 0),
            borderRadius: widget.borderRadius)),
        child: body,
      );
    }
    // Press: in at once (duration zero on the way down), out over `fast`.
    body = AnimatedOpacity(
      opacity: !_enabled
          ? (widget.fadeWhenDisabled ? Pressable.disabledOpacity : 1)
          : (down ? context.motion.pressOpacity : 1),
      duration: down ? Duration.zero : context.motion.fast,
      curve: context.motion.standard,
      child: widget.scaleOnPress && !reduced
          ? AnimatedScale(
              scale: down ? context.motion.pressScale : 1,
              duration: down ? Duration.zero : context.motion.fast,
              curve: context.motion.standard,
              child: body)
          : body,
    );
    body = CustomPaint(
      foregroundPainter: _focused && (_enabled || _inert)
          ? FocusRing.painter(context, widget.borderRadius, danger: widget.danger, onFill: widget.focusOnFill)
          : null,
      child: body,
    );
    body = FocusableActionDetector(
      enabled: _enabled || _inert,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
      onShowFocusHighlight: _focusHighlight,
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
      label: widget.semanticLabel ?? (_inert ? widget.tooltip : null),
      hint: _inert ? widget.disabledReason : null,
      child: body,
    );
    final tooltip = widget.tooltip;
    if (tooltip != null && _inert) {
      // The name, then the reason on its own line in full `ink-muted` (not faded with the control). Screen
      // readers hear the name and the reason through the Semantics above, once.
      body = Tooltip(
        key: _tooltipKey,
        excludeFromSemantics: true,
        richMessage: TextSpan(text: tooltip, children: [
          TextSpan(text: '\n${widget.disabledReason}', style: TextStyle(color: c.inkMuted)),
        ]),
        child: body,
      );
    } else if (tooltip != null) {
      body = Tooltip(key: _tooltipKey, message: tooltip, child: body);
    }
    return body;
  }
}

/// Whether the [Pressable] around a widget is pressed right now, for a control that draws its pressed state
/// itself: a hard, offset or bevel shadow that collapses (`elevation.press: collapse`), a bevel that flips.
class PressedScope extends InheritedWidget {
  const PressedScope({super.key, required this.pressed, required super.child});
  final bool pressed;

  /// False outside a [Pressable].
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PressedScope>()?.pressed ?? false;

  @override
  bool updateShouldNotify(PressedScope old) => old.pressed != pressed;
}

/// The keyboard focus ring: 2px of `focus`, 2px outside the control (tokens.json "focus"); in the Mac frame
/// `focus-ring-width` of `focus-ring`, `focus-ring-offset` outside it (tokens.json "macos").
///
/// It follows the control's shape in the look's corner style ([shape]; round when null, as in the Mac
/// frame), drawn as a stroke of the shape grown outward, never a clip, so a cut or continuous corner keeps
/// its ring (ARCHITECTURE.md 3.2). With a [keyline], a 1px line in that colour runs along the ring's inner
/// edge: the two-tone ring for a ring that sits on a fill (WCAG technique C40, ARCHITECTURE.md 2.3).
class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter(this.color, this.radius, {this.width = 2, this.offset = 2, this.shape, this.keyline});
  final Color color;
  final BorderRadius radius;
  final double width;
  final double offset;
  final MyDataShape? shape;
  final Color? keyline;

  Path _ring(Size size, double by) {
    final r = radius.resolve(TextDirection.ltr);
    final s = shape;
    if (s != null && s.corners != CornerStyle.round) return s.ringPath(Offset.zero & size, r, by);
    final grow = Radius.circular(by);
    return Path()
      ..addRRect(RRect.fromRectAndCorners((Offset.zero & size).inflate(by),
          topLeft: r.topLeft + grow,
          topRight: r.topRight + grow,
          bottomLeft: r.bottomLeft + grow,
          bottomRight: r.bottomRight + grow));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final s = shape;
    if (keyline == null && (s == null || s.corners == CornerStyle.round)) {
      // Today's ring, drawn exactly as before.
      final rect = (Offset.zero & size).inflate(offset + width / 2);
      final r = radius.resolve(TextDirection.ltr);
      final grow = Radius.circular(offset + width / 2);
      canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              topLeft: r.topLeft + grow,
              topRight: r.topRight + grow,
              bottomLeft: r.bottomLeft + grow,
              bottomRight: r.bottomRight + grow),
          paint);
      return;
    }
    canvas.drawPath(_ring(size, offset + width / 2), paint);
    if (keyline != null) {
      canvas.drawPath(
          _ring(size, offset - 0.5),
          Paint()
            ..color = keyline!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.width != width ||
      old.offset != offset ||
      old.shape?.corners != shape?.corners ||
      old.shape?.cutSize != shape?.cutSize ||
      old.keyline != keyline;
}

/// Draws the focus ring around a non-[Pressable] focusable thing (a text field), when [visible].
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.visible,
    required this.borderRadius,
    required this.child,
    this.danger = false,
    this.onFill = false,
  });
  final bool visible;
  final BorderRadius borderRadius;
  final Widget child;

  /// The thing is in its red state (a field in error): the ring is `ink` ([colourOf]).
  final bool danger;

  /// The ring sits on a filled shape (a solid or inverse selected row): it gets a 1px `surface` keyline on
  /// its inner edge, so it reads at 3:1 against both sides whatever the fill (WCAG C40).
  final bool onFill;

  /// The branded rule for a keyboard focus ring's colour (design/README.md "Focus and danger"): `focus` (red)
  /// everywhere, `ink` on something already red ([danger]: drawn in `danger` or `danger-soft`), where a red
  /// ring could not be told apart. Widgets call [colourFor], which also knows the Mac frame.
  static Color colourOf(MyDataColors c, {bool danger = false}) => danger ? c.ink : c.focus;

  /// The colour of every keyboard focus ring, chosen here only: in the Mac frame the system's `focus-ring`
  /// on every control ([danger] does not matter there), elsewhere [colourOf]. No widget picks `focus` or
  /// `ink` for a ring by itself.
  static Color colourFor(BuildContext context, {bool danger = false}) {
    final mac = Theme.of(context).extension<MyDataMacColors>();
    return mac != null ? mac.focusRing : colourOf(context.colors, danger: danger);
  }

  /// The keyline of a ring that sits on a fill ([onFill]): `surface`; none in the Mac frame, whose ring is
  /// the system's.
  static Color? keylineFor(BuildContext context, {bool onFill = false}) =>
      !onFill || Theme.of(context).extension<MyDataMacColors>() != null ? null : context.colors.surface;

  /// The ring around a shape with [radius]: 2px of [colourFor] 2px outside it, following the look's corner
  /// style; in the Mac frame `focus-ring-width` at `focus-ring-offset` (tokens.json "macos"), round.
  static CustomPainter painter(BuildContext context, BorderRadius radius, {bool danger = false, bool onFill = false}) {
    final color = colourFor(context, danger: danger);
    if (Theme.of(context).extension<MyDataMacColors>() == null) {
      return _FocusRingPainter(color, radius, shape: context.radius, keyline: keylineFor(context, onFill: onFill));
    }
    return _FocusRingPainter(color, radius,
        width: MyDataMacSize.focusRingWidth, offset: MyDataMacSize.focusRingOffset);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter: visible ? painter(context, borderRadius, danger: danger, onFill: onFill) : null,
      child: child);
}

/// Radii as BorderRadius, for the shapes the tokens name.
abstract final class MyDataRadii {
  static BorderRadius xs(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.xs));
  static BorderRadius sm(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.sm));
  static BorderRadius md(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.md));
  static BorderRadius lg(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.lg));
  static BorderRadius xl(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.xl));
  static BorderRadius control(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.control));
  static BorderRadius pill(MyDataLook look) => BorderRadius.all(Radius.circular(look.shape.pill));
}
