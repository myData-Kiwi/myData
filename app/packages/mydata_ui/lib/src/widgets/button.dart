import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart';
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

  /// The fill behind the label; null for [plain] and [plainDanger], which have none.
  Color? fill(MyDataColors c) => switch (this) {
        filled => c.accent,
        tonal => c.accentSoft,
        plain => null,
        danger => c.danger,
        plainDanger => null,
      };

  /// Drawn in `danger`: the focus ring is then `ink`, not the red `focus` (design/README.md "Focus and danger").
  bool get isRed => this == danger || this == plainDanger;

  /// A solid fill ([filled], [danger]). Disabled, such a button is drawn on `surface-sunken` with an
  /// `ink-muted` label (about 4.5:1) instead of fading: faded, its label fell to about 1.5:1
  /// (design/themes/ARCHITECTURE.md 6a, decided 2026-10-23). The other variants fade to 45%.
  bool get isSolid => this == filled || this == danger;

  /// The fill of a disabled button: `surface-sunken` for a [isSolid] one, else its usual fill (it fades).
  Color? disabledFill(MyDataColors c) => isSolid ? c.surfaceSunken : fill(c);

  /// The label of a disabled button: `ink-muted` for a [isSolid] one, else its usual colour (it fades).
  Color disabledForeground(MyDataColors c) => isSolid ? c.inkMuted : foreground(c);

  /// The colour of the label and the icon.
  Color foreground(MyDataColors c) => switch (this) {
        filled => c.onAccent,
        tonal => c.accent,
        plain => c.accent,
        danger => c.onDanger,
        plainDanger => c.danger,
      };
}

/// A pill-shaped control that states the result of pressing it (design/components/Button).
///
/// - Shape `radius-control`, height `control-height`, label `body-strong`; no border on any variant in
///   Kiwi. A theme that outlines controls (`borders.controls`) outlines the variants with a fill.
/// - Keyboard focus draws the 2px `focus` ring 2px outside the pill; on [ButtonVariant.danger] and
///   [ButtonVariant.plainDanger] it is `ink` (design/README.md "Focus and danger").
/// - Pressing dims to 85% and scales to 97% at once and returns over `fast` ([Pressable]); with reduced
///   motion it only dims.
/// - [onPressed] null disables it: not focusable (unless [disabledReason] is given), announced as disabled. A
///   [ButtonVariant.filled] or [ButtonVariant.danger] button is then drawn on `surface-sunken` with an
///   `ink-muted` label, in every drawn theme; the others fade to 45%.
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

  /// Space on each side of the label. The preview's 22px lies halfway between `space-5` and `space-6`;
  /// `space-5` (20px) is used.
  static double horizontalPadding(MyDataLook look) => look.space(5);

  /// Space between the leading icon and the label.
  static double iconGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    if (context.isSystemLook) return _mac(context);
    final c = context.colors;
    final disabled = onPressed == null;
    final fg = disabled ? variant.disabledForeground(c) : variant.foreground(c);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: context.typeScale.bodyStrong.copyWith(color: fg),
    );
    return Pressable(
      onPressed: onPressed,
      borderRadius: MyDataRadii.control(context.look),
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? label,
      danger: variant.isRed,
      disabledReason: disabledReason,
      fadeWhenDisabled: !variant.isSolid,
      child: ExcludeSemantics(
        child: Container(
          height: context.density.controlHeight,
          constraints: BoxConstraints(minWidth: context.density.controlHeight),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding(context.look)),
          decoration: context.radius.decorate(BoxDecoration(
              color: disabled ? variant.disabledFill(c) : variant.fill(c),
              borderRadius: MyDataRadii.control(context.look),
              // A theme that outlines controls outlines every button with a fill; a plain one stays bare.
              border: variant.fill(c) == null ? null : MyDataEdgesPaint.control(context.look))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(context.icon(icon!), size: context.density.icon, color: fg),
                SizedBox(width: iconGap(context.look)),
              ],
              Flexible(child: text),
            ],
          ),
        ),
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
