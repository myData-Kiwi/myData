import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'pressable.dart';

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
/// - Shape `radius-control`, height `control-height`, label `body-strong`; no border on any variant.
/// - Keyboard focus draws the 2px `focus` ring 2px outside the pill; on [ButtonVariant.danger] and
///   [ButtonVariant.plainDanger] it is `ink` (design/README.md "Focus and danger").
/// - Pressing dims to 85% and scales to 97% at once and returns over `fast` ([Pressable]); with reduced
///   motion it only dims.
/// - [onPressed] null disables it: 45% opacity, not focusable, announced as disabled.
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
  });

  /// What pressing it does: a verb and its object, in sentence case.
  final String label;

  /// The action. Null disables the button.
  final VoidCallback? onPressed;

  /// Defaults to [ButtonVariant.tonal], the spec's usual choice.
  final ButtonVariant variant;

  /// An optional leading icon, drawn at `icon` size in the label's colour. Decorative: the label names the
  /// button. The icon set is not drawn yet; pass a Material outlined or rounded icon.
  final IconData? icon;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Why the button is disabled, a full sentence, when no text beside it says so: it then stays focusable
  /// but inert, and its reason is its hint (Pressable, design/platforms.md "Disabled controls"). Only read
  /// while [onPressed] is null.
  final String? disabledReason;

  /// Space on each side of the label. The preview's 22px lies halfway between `space-5` and `space-6`;
  /// `space-5` (20px) is used.
  static const horizontalPadding = MyDataSpace.s5;

  /// Space between the leading icon and the label.
  static const iconGap = MyDataSpace.s2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = variant.foreground(c);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: MyDataType.bodyStrong.copyWith(color: fg),
    );
    return Pressable(
      onPressed: onPressed,
      borderRadius: MyDataRadii.control,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: label,
      danger: variant.isRed,
      disabledReason: disabledReason,
      child: ExcludeSemantics(
        child: Container(
          height: MyDataSize.controlHeight,
          constraints: const BoxConstraints(minWidth: MyDataSize.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(color: variant.fill(c), borderRadius: MyDataRadii.control),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: MyDataSize.icon, color: fg),
                const SizedBox(width: iconGap),
              ],
              Flexible(child: text),
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
  static const gap = MyDataSpace.s2;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: gap,
        runSpacing: gap,
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
}
