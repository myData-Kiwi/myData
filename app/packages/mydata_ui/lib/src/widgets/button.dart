import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart';
import '../mac/mac_window.dart';
import '../theme/theme.dart';
import 'pressable.dart';
import 'edges.dart';

/// The five kinds of [Button] (design/components/Button/README.md).
enum ButtonVariant {
  /// `accent` with `on-accent` text. The one main action on a screen or card.
  filled,

  /// `accent-soft` with `accent` text. The usual choice for every other action; it keeps a screen calm.
  tonal,

  /// `accent` text with no fill, for low-emphasis actions such as Cancel.
  plain,

  /// `danger` with `on-danger` text, for destructive actions only.
  danger,

  /// `danger` text with no fill, for a destructive action on one item in a row (an ActionRow's "Revoke").
  /// Pressed, focused and disabled exactly as [plain]. It always opens a confirmation dialog first, and that
  /// dialog confirms with a [danger] button.
  plainDanger;

  /// Drawn in `danger`: the focus ring is then `ink`, not the red `focus` (design/README.md "Focus and danger").
  bool get isRed => this == danger || this == plainDanger;
}

/// How a [Button] is drawn in a look: its theme's variant for the button's role (design/themes/ARCHITECTURE.md
/// 3.2). The app picks the role ([ButtonVariant]); the theme's `components.button` picks how it is drawn:
///
/// - **primary** ([ButtonVariant.filled]), and [ButtonVariant.danger] built the same way in `danger`:
///   - `filled`: the accent with `on-accent` text (Kiwi);
///   - `outline`: no fill, a 2px outline and the label in the accent (Journal);
///   - `brutal`: the accent in a 3px `edge` outline over a solid drop down and to the right (the theme's
///     hard, offset or bevel drop, else 4px of `edge`), which a press always pushes into (Brutalist);
///   - `bevel`: the accent in a 1px `edge` ring, a light line top and left and a dark one bottom and right,
///     swapped while pressed (Retro Desktop);
///   - `push`: the accent with a faint `edge` line and a 1px soft drop, as the Mac's push button;
///   when the accent is within 25° of `danger` ([MyDataLook.accentNearDanger]) the primary is drawn in `ink`
///   with its label in `bg`, so Approve never looks like Delete;
/// - **secondary** ([ButtonVariant.tonal]): `tonal` (`accent-soft`, accent text), `outline` (no fill, the
///   control outline, `ink` text) or `text` (the accent label alone, underlined so it reads as an action);
/// - **plain** ([ButtonVariant.plain] and [ButtonVariant.plainDanger]) stay text in every theme: the label
///   alone (`text`), or underlined (`underline`) where every other control is outlined, so Cancel and Reject
///   still read as actions (High Contrast, E-ink, Large);
/// - near red, every label that would be in the accent (plain, tonal, a text secondary) is `ink` too, so only
///   a destructive action is red (Reject beside Approve, Cancel beside Revoke);
/// - the approval card's Approve ([Button.approval]) is the same in every theme: filled, or outlined where the
///   primary is an outline, with no drop, no bevel and at most a 1px `line-strong` outline;
/// - **shape** (`button.shape`): `pill`, `rounded` (the theme's small radius), `square` or `cut`, whatever the
///   theme's other corners are ([shapeOf]).
@immutable
class ButtonPaint {
  const ButtonPaint({
    required this.fill,
    required this.foreground,
    this.side,
    this.shadows = const [],
    this.bevel,
    this.underline = false,
    this.solid = false,
    this.collapses = false,
  });

  /// Behind the label; null for none.
  final Color? fill;

  /// The label and the icon.
  final Color foreground;

  /// The outline; null for none.
  final BorderSide? side;

  /// The drop and glow under it, at rest.
  final List<BoxShadow> shadows;

  /// The bevel's two lines.
  final Bevel? bevel;

  /// The label is underlined (a text secondary, an underlined plain button).
  final bool underline;

  /// A solid fill: disabled, it is drawn on `surface-sunken` with an `ink-muted` label (about 4.5:1) and a
  /// `line-strong` outline instead of fading, since faded its label fell to about 1.5:1
  /// (ARCHITECTURE.md 6a, decided 2026-10-23). Every other button fades to 45%.
  final bool solid;

  /// Its drop goes while it is pressed, whatever `elevation.press` says (a brutal button).
  final bool collapses;

  /// The width of an `outline` primary's line.
  static const outlineWidth = 2.0;

  /// The width of a `brutal` primary's line.
  static const brutalWidth = 3.0;

  /// The ring around a `bevel` primary (the default button's outer ring) and a `push` one's faint edge.
  static const bevelEdgeWidth = 1.0;

  /// A `brutal` primary's drop, when the theme's elevation gives none.
  static const brutalDrop = Offset(4, 4);

  /// [variant] in [look], at rest and enabled. An [approval] button (the approval card's Approve) is filled
  /// or outlined only, whatever primary, elevation and borders the theme draws ([_approval]): the card's
  /// structure never changes with a theme.
  factory ButtonPaint.of(MyDataLook look, ButtonVariant variant, {bool approval = false}) {
    final c = look.colors;
    final v = look.variants;
    final control = MyDataEdgesPaint.control(look)?.top;
    final elevation = look.elevation;
    // An accent near `danger`'s red: every accent-coloured label is `ink`, so only a destructive action is red.
    final nearRed = look.accentNearDanger;
    final accentText = nearRed ? c.ink : c.accent;
    switch (variant) {
      case ButtonVariant.plain:
        return ButtonPaint(fill: null, foreground: accentText, underline: v.plain == PlainStyle.underline);
      case ButtonVariant.plainDanger:
        return ButtonPaint(fill: null, foreground: c.danger, underline: v.plain == PlainStyle.underline);
      case ButtonVariant.tonal:
        return switch (v.secondary) {
          SecondaryStyle.tonal => ButtonPaint(
              fill: c.accentSoft, foreground: accentText, side: control, shadows: elevation.control, bevel: elevation.bevel),
          SecondaryStyle.outline => ButtonPaint(
              fill: null,
              foreground: c.ink,
              side: BorderSide(color: look.edges.controlColour, width: math.max(1, look.edges.width))),
          SecondaryStyle.text => ButtonPaint(fill: null, foreground: accentText, underline: true),
        };
      case ButtonVariant.filled || ButtonVariant.danger:
        final danger = variant == ButtonVariant.danger;
        final ink = !danger && nearRed;
        final base = danger ? c.danger : (ink ? c.ink : c.accent);
        final on = danger ? c.onDanger : (ink ? c.bg : c.onAccent);
        final primary = variant == ButtonVariant.filled;
        final drop = elevation.control;
        final glow = primary ? elevation.glow : const <BoxShadow>[];
        if (approval && primary) return _approval(look, base: base, on: on, glow: glow);
        return switch (v.primary) {
          PrimaryStyle.filled =>
            ButtonPaint(fill: base, foreground: on, side: control, shadows: [...drop, ...glow], bevel: elevation.bevel, solid: true),
          PrimaryStyle.outline => ButtonPaint(
              fill: null,
              foreground: base,
              side: BorderSide(color: base, width: math.max(outlineWidth, look.edges.width)),
              shadows: glow),
          PrimaryStyle.brutal => ButtonPaint(
              fill: base,
              foreground: on,
              side: BorderSide(color: c.edge, width: brutalWidth),
              shadows: [...(drop.isNotEmpty ? drop : [BoxShadow(color: c.edge, offset: brutalDrop)]), ...glow],
              solid: true,
              collapses: true),
          PrimaryStyle.bevel => ButtonPaint(
              fill: base,
              foreground: on,
              side: BorderSide(color: c.edge, width: bevelEdgeWidth),
              shadows: [...drop, ...glow],
              bevel: elevation.bevel ?? bevelOf(look),
              solid: true),
          PrimaryStyle.push => ButtonPaint(
              fill: base,
              foreground: on,
              side: BorderSide(color: c.edge.withValues(alpha: 0.2), width: bevelEdgeWidth),
              shadows: [
                ...drop,
                BoxShadow(color: c.shadow.withValues(alpha: 0.3), offset: const Offset(0, 1), blurRadius: 1),
                ...glow,
              ],
              solid: true),
        };
    }
  }

  /// The approval card's Approve, the same in every drawn theme whatever its primary, elevation and borders
  /// (the card's fixed structure, ARCHITECTURE.md 1.2): [base] with its label in [on], a 1px `line-strong`
  /// outline only where the theme outlines its controls, no drop and no bevel (so never brutal, bevelled or a
  /// push button), only a blurred glow kept; outlined, in [base] and 2px, where the primary is an outline.
  static ButtonPaint _approval(MyDataLook look, {required Color base, required Color on, required List<BoxShadow> glow}) {
    final soft = [for (final s in glow) if (s.blurRadius > 0 && s.offset == Offset.zero) s];
    if (look.variants.primary == PrimaryStyle.outline) {
      return ButtonPaint(
          fill: null, foreground: base, side: BorderSide(color: base, width: outlineWidth), shadows: soft);
    }
    return ButtonPaint(
        fill: base,
        foreground: on,
        side: look.edges.controls ? BorderSide(color: look.colors.lineStrong, width: approvalEdgeWidth) : null,
        shadows: soft,
        solid: true);
  }

  /// The outline of a filled Approve in a theme that outlines its controls.
  static const approvalEdgeWidth = 1.0;

  /// A bevel for a `bevel` primary in a theme whose elevation draws none: the elevation's own lines at full
  /// strength.
  static Bevel bevelOf(MyDataLook look) {
    final dark = look.brightness == Brightness.dark;
    final c = look.colors;
    return Bevel(
      light: (dark ? c.ink : c.surface).withValues(alpha: dark ? 0.25 : 0.9),
      dark: c.shadow.withValues(alpha: dark ? 0.8 : 0.45),
    );
  }
}

/// A control that states the result of pressing it (design/components/Button), drawn in the theme's variant
/// for its role ([ButtonPaint]).
///
/// - Shape from `button.shape` ([shapeOf]; Kiwi's is a pill), height `control-height`, label `body-strong`.
///   A theme that outlines controls (`borders.controls`) outlines the variants with a fill.
/// - Keyboard focus draws the 2px `focus` ring 2px outside the shape; on [ButtonVariant.danger] and
///   [ButtonVariant.plainDanger] it is `ink` (design/README.md "Focus and danger"). Over a drop it is
///   two-tone.
/// - Pressing is the theme's press ([Pressable]); a drop that collapses goes while it is held.
/// - [onPressed] null disables it: not focusable (unless [disabledReason] is given), announced as disabled. A
///   button with a solid fill ([ButtonPaint.solid]) is then drawn on `surface-sunken` with an `ink-muted`
///   label and a 1px `line-strong` outline ([edgeOf]), in every drawn theme; the others fade to 45%.
/// - The label is a verb and its object ("Approve and send", "Delete 12 photos"), in sentence case. Never
///   "OK" or "Submit".
/// - Use one [ButtonVariant.filled] per screen or card; other actions are [ButtonVariant.tonal] or
///   [ButtonVariant.plain]. Lay several out with [ButtonRow].
class Button extends StatelessWidget {
  const Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.tonal,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.disabledReason,
    this.semanticLabel,
    this.approval = false,
  });

  /// What pressing it does: a verb and its object, in sentence case.
  final String label;

  /// The action. Null disables the button.
  final VoidCallback? onPressed;

  /// Defaults to [ButtonVariant.tonal], the spec's usual choice.
  final ButtonVariant variant;

  /// An optional leading icon, drawn at `icon` size in the label's colour. Decorative: the label names the
  /// button.
  final MyDataIcon? icon;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Why the button is disabled, a full sentence, when no text beside it says so: it then stays focusable
  /// but inert, and its reason is its hint (Pressable, design/platforms.md "Disabled controls"). Only read
  /// while [onPressed] is null.
  final String? disabledReason;

  /// What screen readers hear instead of [label], when the label alone does not say what the button acts
  /// on: one "Compare" per row reads "Compare Ben Sample".
  final String? semanticLabel;

  /// The approval card's Approve: drawn filled, or outlined in a theme whose primary is an outline, never
  /// brutal, bevelled or as a push button, and with no drop or bevel from the theme's elevation
  /// (ARCHITECTURE.md 1.2, the card's fixed structure).
  final bool approval;

  /// Space on each side of the label. The preview's 22px lies halfway between `space-5` and `space-6`;
  /// `space-5` (20px) is used.
  static double horizontalPadding(MyDataLook look) => look.space(5);

  /// Space between the leading icon and the label.
  static double iconGap(MyDataLook look) => look.space(2);

  /// A disabled solid button's outline, in `line-strong`: `surface-sunken` is about 1.05:1 on `bg`, so
  /// without it the button read as loose grey text, and vanished on a sunken ground. A theme that outlines
  /// controls keeps its own outline instead.
  static const disabledEdgeWidth = 1.0;

  /// The outline of a disabled button with a solid fill, or of an enabled filled one in a theme that
  /// outlines controls: the theme's control outline, else a disabled solid button's own.
  static Border? edgeOf(MyDataLook look, ButtonVariant variant, {required bool disabled}) {
    final paint = ButtonPaint.of(look, variant);
    if (!disabled) return paint.side == null ? null : Border.fromBorderSide(paint.side!);
    if (!paint.solid) return null;
    return MyDataEdgesPaint.control(look) ?? Border.all(color: look.colors.lineStrong, width: disabledEdgeWidth);
  }

  /// A button's corners in [look] (`button.shape`) and the corner style they are drawn in:
  /// - pill: a capsule, in the theme's corner style (round where the theme cuts or squares its corners);
  /// - rounded: the theme's small radius (`radius-sm`, today's when the theme's corners are square);
  /// - square: none;
  /// - cut: a chamfer of the theme's `cut-size` on every corner.
  static (MyDataShape, BorderRadius) shapeOf(MyDataLook look) {
    final s = look.shape;
    MyDataShape corners(CornerStyle c) => c == s.corners ? s : s.withCorners(c);
    final soft = s.corners == CornerStyle.cut || s.corners == CornerStyle.square ? CornerStyle.round : s.corners;
    return switch (look.variants.buttonShape) {
      ButtonShapeStyle.pill => (corners(soft), const BorderRadius.all(Radius.circular(MyDataShape.capsule))),
      ButtonShapeStyle.rounded =>
        (corners(soft), BorderRadius.all(Radius.circular(s.sm > 0 ? s.sm : MyDataShape.roundedControl))),
      ButtonShapeStyle.square => (corners(CornerStyle.square), BorderRadius.zero),
      ButtonShapeStyle.cut => (corners(CornerStyle.cut), BorderRadius.all(Radius.circular(s.cutSize))),
    };
  }

  /// A drawn button's label: `body-strong`; inside the Mac window no larger than the theme's `label`, so a
  /// button beside a form row's title never outweighs it (Paperback's 16 px Literata semibold did).
  static TextStyle labelStyle(BuildContext context) {
    final s = context.typeScale;
    if (!MacWindow.of(context) || s.bodyStrong.fontSize! <= s.label.fontSize!) return s.bodyStrong;
    return s.bodyStrong.copyWith(fontSize: s.label.fontSize);
  }

  @override
  Widget build(BuildContext context) {
    if (context.isSystemLook) return _mac(context);
    final c = context.colors;
    final look = context.look;
    final disabled = onPressed == null;
    final paint = ButtonPaint.of(look, variant, approval: approval);
    final (shape, radius) = shapeOf(look);
    final solidDisabled = disabled && paint.solid;
    return Pressable(
      onPressed: onPressed,
      borderRadius: radius,
      shape: shape,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? label,
      danger: variant.isRed,
      disabledReason: disabledReason,
      fadeWhenDisabled: !paint.solid,
      // A drop fills the band the ring is drawn in, along the bottom (and the right): the ring is two-tone
      // there, its `surface` keyline between it and the drop (WCAG C40).
      focusOnFill: !disabled && paint.shadows.any((s) => s.blurRadius == 0 && s.offset != Offset.zero),
      drawsInvert: true,
      child: ExcludeSemantics(
        child: Builder(builder: (context) {
          final pressed = PressedScope.of(context);
          // An `invert` press: the roles swap, an `ink` fill with the label in `bg`, in every variant.
          final inverted = PressedScope.invertedOf(context);
          final fg = inverted ? c.bg : (solidDisabled ? c.inkMuted : paint.foreground);
          final text = Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: labelStyle(context).copyWith(
                color: fg,
                decoration: paint.underline ? TextDecoration.underline : null,
                decorationColor: fg),
          );
          // A drop that collapses while pressed (`elevation.press: collapse`, a brutal button) or that the
          // button sinks into (`motion.press: sink`); a disabled button has no depth.
          final sinks = context.motion.press == PressStyle.sink;
          final shadows = disabled || (pressed && (paint.collapses || look.elevation.collapse || sinks))
              ? [for (final s in paint.shadows) if (!(disabled || s.blurRadius == 0)) s]
              : paint.shadows;
          final side = solidDisabled
              ? (approval
                  ? BorderSide(color: c.lineStrong, width: disabledEdgeWidth)
                  : (MyDataEdgesPaint.control(look)?.top ?? BorderSide(color: c.lineStrong, width: disabledEdgeWidth)))
              : paint.side;
          Widget box = Container(
            height: context.density.controlHeight,
            constraints: BoxConstraints(minWidth: context.density.controlHeight),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding(look)),
            decoration: shape.decorate(BoxDecoration(
                color: inverted ? c.ink : (solidDisabled ? c.surfaceSunken : paint.fill),
                borderRadius: radius,
                boxShadow: shadows.isEmpty || disabled ? null : shadows,
                border: side == null ? null : Border.fromBorderSide(side))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(context.icon(icon!), size: context.density.icon, color: fg),
                  SizedBox(width: iconGap(look)),
                ],
                Flexible(child: text),
              ],
            ),
          );
          final bevel = paint.bevel;
          if (bevel != null && paint.fill != null && !disabled) {
            box = CustomPaint(
                foregroundPainter:
                    BevelPainter(bevel, shape: shape, radius: radius, pressed: pressed, fill: paint.fill),
                child: box);
          }
          return box;
        }),
      ),
    );
  }

  /// The Mac frame's push button: a `push-button-height` capsule with the label in `body`. [ButtonVariant.filled]
  /// is the default button (the accent, `on-accent` text), [ButtonVariant.tonal] a plain push button on
  /// `quaternary-label`, [ButtonVariant.danger] the same with its label in `danger` (a destructive push
  /// button: red text, never a red fill); the plain variants are the label alone in the accent or `danger`,
  /// as borderless buttons are. Pressing, focus and disabling are [Pressable]'s.
  Widget _mac(BuildContext context) {
    final c = context.colors;
    final mac = context.mac;
    final (Color? fill, Color fg) = switch (variant) {
      ButtonVariant.filled => (mac.accent, mac.onAccent),
      ButtonVariant.tonal => (mac.quaternaryLabel, mac.label),
      ButtonVariant.plain => (null, mac.accent),
      // A destructive push button: red text on the push button's own fill, never a red fill (HIG Alerts).
      ButtonVariant.danger => (mac.quaternaryLabel, c.danger),
      ButtonVariant.plainDanger => (null, c.danger),
    };
    const shape = BorderRadius.all(Radius.circular(MyDataMacRadius.field));
    return Pressable(
      onPressed: onPressed,
      borderRadius: shape,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? label,
      danger: variant.isRed,
      disabledReason: disabledReason,
      child: ExcludeSemantics(
        child: Container(
          height: MyDataMacSize.pushButtonHeight,
          constraints: const BoxConstraints(minWidth: MyDataMacSize.pushButtonHeight * 3),
          padding: EdgeInsets.symmetric(horizontal: fill == null ? context.space(1) : context.space(3)),
          decoration: context.radius.decorate(BoxDecoration(color: fill, borderRadius: shape)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(context.icon(icon!), size: MyDataMacSize.icon, color: fg),
                SizedBox(width: context.space(1)),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                    style: MyDataMacType.body.copyWith(color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays buttons out in a row, `space-2` apart, wrapping onto further rows (also `space-2` apart) when they
/// do not fit.
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children, this.alignment = WrapAlignment.start});

  final List<Widget> children;

  /// Where the buttons sit along each row; [WrapAlignment.end] for dialog and card footers.
  final WrapAlignment alignment;

  /// The gap between buttons (the owner's decision: buttons are `space-2` apart).
  static double gap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: gap(context.look),
        runSpacing: gap(context.look),
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
}
