import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/pressable.dart' show FocusRing;
import 'mac_chrome.dart';
import 'mac_metrics.dart';
import 'mac_overlays.dart' show MacMenuLook;
import 'mac_theme.dart';

/// One button of a [MacToolbarGroup]: a word or an icon.
@immutable
class MacToolbarGroupButton {
  const MacToolbarGroupButton({
    this.text,
    this.icon,
    required this.label,
    this.onPressed,
    this.disabledReason,
    this.shortcut,
  }) : assert((text == null) != (icon == null), 'a button has a word or an icon');

  final String? text;
  final MyDataIcon? icon;

  /// Its tooltip and accessible name.
  final String label;

  /// Null: disabled, with [disabledReason] as the tooltip's second line and its accessible hint.
  final VoidCallback? onPressed;
  final String? disabledReason;

  /// Shown after the label in the tooltip ("⌘T").
  final String? shortcut;
}

/// Several toolbar buttons in one capsule, as Calendar.app's "‹ Today ›" (a momentary segmented control:
/// each part acts, none stays chosen; a choice of one is [MacSegmented]): `toolbar-item-height` tall, on
/// `toolbar-item` with a `separator` hairline (the shell's flat stand-in for Liquid Glass, as
/// [MacToolbarButton]). The part under the pointer has the `hover` tint, a pressed one `quaternary-label`,
/// the one with keyboard focus the system's focus ring. Each part is a Tab stop when enabled, and Space or
/// Return presses it; its tooltip is its label and shortcut, and why it is disabled.
class MacToolbarGroup extends StatelessWidget {
  const MacToolbarGroup({super.key, required this.buttons, this.semanticsLabel});

  final List<MacToolbarGroupButton> buttons;

  /// Names the group for assistive technology ("View").
  final String? semanticsLabel;

  /// Between the capsule's edge and a part's inner capsule.
  static const inset = MyDataMacSize.tight;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final m = context.macLook;
    final item = Container(
      height: m.toolbarItemHeight,
      padding: const EdgeInsets.all(inset),
      decoration: m.decorate(BoxDecoration(
        color: mac.toolbarItem,
        borderRadius: m.controlRadius,
        border: Border.fromBorderSide(m.itemSide ?? BorderSide(color: mac.separator, width: MyDataMacSize.hairline)),
      )),
      child: Row(mainAxisSize: MainAxisSize.min, children: [for (final b in buttons) _Part(button: b)]),
    );
    return MacChrome.of(context).toolbarItem(
      Semantics(container: true, label: semanticsLabel, explicitChildNodes: true, child: item),
    );
  }
}

class _Part extends StatefulWidget {
  const _Part({required this.button});

  final MacToolbarGroupButton button;

  @override
  State<_Part> createState() => _PartState();
}

class _PartState extends State<_Part> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final m = context.macLook;
    final s = widget.button;
    final enabled = s.onPressed != null;
    final ink = enabled ? mac.label : mac.tertiaryLabel;
    final Color? fill = enabled && _pressed
        ? mac.quaternaryLabel
        : enabled && _hovered
        ? mac.hover
        : null;
    final height = m.toolbarItemHeight - 2 * MacToolbarGroup.inset;
    Widget part = AnimatedContainer(
      duration: context.motion.fast,
      height: height,
      constraints: BoxConstraints(minWidth: height),
      padding: EdgeInsets.symmetric(horizontal: s.icon != null ? 0 : context.space(3)),
      alignment: Alignment.center,
      decoration: m.decorate(BoxDecoration(
        color: fill,
        borderRadius: m.controlRadius,
        border: _focused ? Border.all(color: FocusRing.colourFor(context), width: MyDataMacSize.focusRingWidth) : null,
      )),
      child: s.icon != null
          ? Icon(context.icon(s.icon!), size: m.icon, color: ink)
          : Text(s.text!, style: m.body.copyWith(color: ink)),
    );
    part = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: SystemMouseCursors.basic,
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => s.onPressed?.call())},
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: s.onPressed,
        child: part,
      ),
    );
    final tip = [
      s.shortcut == null ? s.label : '${s.label}  ${s.shortcut}',
      if (!enabled && s.disabledReason != null) s.disabledReason!,
    ].join('\n');
    return Semantics(
      button: true,
      enabled: enabled,
      label: s.label,
      hint: enabled ? null : s.disabledReason,
      excludeSemantics: true,
      child: Tooltip(
        message: tip,
        waitDuration: MacMenuLook.helpTagDelay,
        textStyle: MyDataMacType.caption.copyWith(color: mac.label),
        decoration: BoxDecoration(
          color: mac.contentBackground,
          border: Border.all(color: mac.separator),
          borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.control)),
        ),
        child: part,
      ),
    );
  }
}
