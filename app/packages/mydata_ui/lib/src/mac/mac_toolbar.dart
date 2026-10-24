import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'mac_chrome.dart';
import 'mac_overlays.dart' show MacMenuLook;
import 'mac_theme.dart';

/// The Mac frame's toolbar band: `toolbar-height` tall across the content, in the window's title bar
/// (the window has a full-size content view and a unified toolbar), on [background], items `toolbar-inset`
/// from the column's edges. No hairline under it by default: macOS 26 toolbars have none. [leading] and
/// [trailing] are toolbar items ([MacToolbarButton], [MacSearchField]); [title] is the section shown, in
/// `title`, 20 pt in as the system's toolbar titles are. The empty parts of the band drag the window, as the
/// system's do.
class MacToolbar extends StatelessWidget {
  const MacToolbar({
    super.key,
    this.leading = const [],
    this.title,
    this.subtitle,
    this.trailing = const [],
    this.background,
    this.separator = false,
    this.windowControls = false,
  });

  final List<Widget> leading;
  final String? title;
  final String? subtitle;
  final List<Widget> trailing;

  /// The band's ground; null: `content-background`.
  final Color? background;

  /// The hairline under the band.
  final bool separator;

  /// The band starts at the window's leading edge (no sidebar beside it): it leaves the window's close,
  /// minimise and zoom buttons their room (`window-controls-width`).
  final bool windowControls;

  /// Between items in the band.
  static double itemGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    return Container(
      height: MyDataMacSize.toolbarHeight,
      padding: EdgeInsetsDirectional.only(
        start: MyDataMacSize.toolbarInset + (windowControls ? MyDataMacSize.windowControlsWidth : 0),
        end: MyDataMacSize.toolbarInset,
      ),
      decoration: BoxDecoration(
        color: background ?? mac.contentBackground,
        border: separator ? Border(bottom: BorderSide(color: mac.separator)) : null,
      ),
      child: Row(
        children: [
          for (final (i, w) in leading.indexed) ...[if (i > 0) SizedBox(width: itemGap(context.look)), w],
          if (leading.isNotEmpty && title != null) SizedBox(width: itemGap(context.look)),
          if (title != null)
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: leading.isEmpty ? context.space(3) : 0),
                child: Semantics(
                header: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: MyDataMacType.title.copyWith(color: mac.label)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: MyDataMacType.caption.copyWith(color: mac.secondaryLabel)),
                  ],
                ),
              ),
              ),
            ),
          if (title == null && trailing.isNotEmpty) const Spacer(),
          for (final (i, w) in trailing.indexed) ...[if (i > 0) SizedBox(width: itemGap(context.look)), w],
        ],
      ),
    );
  }
}

/// A toolbar item: an icon in a `toolbar-item-height` circle, or a short word ([MacToolbarButton.text]) in a
/// capsule, on `toolbar-item` with a `separator` outline: a flat stand-in for macOS 26's Liquid Glass, which
/// Flutter cannot draw. The `hover` tint under the pointer, the system's `focus-ring` from the keyboard. Its [label] is its tooltip and
/// accessible name; a disabled item keeps its tooltip and gives [disabledReason] as the second line.
class MacToolbarButton extends StatefulWidget {
  const MacToolbarButton({
    super.key,
    required MyDataIcon this.icon,
    required this.label,
    required this.onPressed,
    this.disabledReason,
    this.shortcut,
  }) : text = null;

  const MacToolbarButton.text({
    super.key,
    required String this.text,
    required this.label,
    required this.onPressed,
    this.disabledReason,
    this.shortcut,
  }) : icon = null;

  final MyDataIcon? icon;
  final String? text;
  final String label;
  final VoidCallback? onPressed;
  final String? disabledReason;

  /// Shown after the label in the tooltip ("⌘N").
  final String? shortcut;

  @override
  State<MacToolbarButton> createState() => _MacToolbarButtonState();
}

class _MacToolbarButtonState extends State<MacToolbarButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final enabled = widget.onPressed != null;
    final ink = enabled ? mac.label : mac.tertiaryLabel;
    final tip = [
      widget.shortcut == null ? widget.label : '${widget.label}  ${widget.shortcut}',
      if (!enabled && widget.disabledReason != null) widget.disabledReason!,
    ].join('\n');
    final Widget face = widget.icon != null
        ? Icon(context.icon(widget.icon!), size: MyDataMacSize.icon, color: ink)
        : Text(widget.text!, style: MyDataMacType.body.copyWith(color: enabled ? mac.label : mac.tertiaryLabel));
    Widget button = AnimatedContainer(
      duration: context.motion.fast,
      height: MyDataMacSize.toolbarItemHeight,
      constraints: const BoxConstraints(minWidth: MyDataMacSize.toolbarItemHeight),
      // A word is a capsule (macOS 26's toolbar text items), wider than tall: never a circle round a word.
      padding: EdgeInsets.symmetric(horizontal: widget.icon != null ? 0 : context.space(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled && (_hovered || _pressed)
            ? Color.alphaBlend(_pressed ? mac.quaternaryLabel : mac.hover, mac.toolbarItem)
            : mac.toolbarItem,
        borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.field)),
        border: Border.all(color: _focused ? mac.focusRing : mac.separator, width: _focused ? MyDataMacSize.focusRingWidth : MyDataMacSize.hairline),
      ),
      child: face,
    );
    button = FocusableActionDetector(
      enabled: enabled,
      mouseCursor: SystemMouseCursors.basic,
      onShowHoverHighlight: (h) => setState(() => _hovered = h),
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: button,
      ),
    );
    button = Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: enabled ? null : widget.disabledReason,
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
        child: button,
      ),
    );
    return MacChrome.of(context).toolbarItem(button);
  }
}

/// The toolbar's search field: a `toolbar-item-height` capsule on `toolbar-item` (the glass stand-in, as the
/// toolbar items), a magnifier, the
/// [placeholder] in `tertiary-label` (also its accessible name), and a clear button once there is text.
/// Escape clears it; Down calls [onDown] (the list takes the keyboard).
class MacSearchField extends StatefulWidget {
  const MacSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.focusNode,
    this.onDown,
    this.width = MyDataMacSize.searchWidth,
  });

  final TextEditingController controller;
  final String placeholder;
  final FocusNode? focusNode;
  final VoidCallback? onDown;
  final double width;

  static const clearLabel = 'Clear search';

  @override
  State<MacSearchField> createState() => _MacSearchFieldState();
}

class _MacSearchFieldState extends State<MacSearchField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'Search'));
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(MacSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && widget.controller.text.isNotEmpty) {
      widget.controller.clear();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.onDown != null) {
      widget.onDown!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final hasText = widget.controller.text.isNotEmpty;
    final field = Container(
      width: widget.width,
      height: MyDataMacSize.toolbarItemHeight,
      padding: EdgeInsets.symmetric(horizontal: context.space(3)),
      decoration: BoxDecoration(
        color: mac.toolbarItem,
        borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.field)),
        border: _focused
            ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
            : Border.all(color: mac.separator, width: MyDataMacSize.hairline),
      ),
      child: Row(
        children: [
          Icon(context.icon(MyDataIcon.search), size: MyDataMacSize.icon, color: mac.secondaryLabel),
          SizedBox(width: context.space(2)),
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              skipTraversal: true,
              canRequestFocus: false,
              onFocusChange: (f) => setState(() => _focused = f),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                style: MyDataMacType.body.copyWith(color: mac.label),
                cursorColor: mac.accent,
                cursorHeight: MyDataMacType.body.fontSize! + MyDataMacSize.tight,
                decoration: InputDecoration.collapsed(
                  hintText: widget.placeholder,
                  hintStyle: MyDataMacType.body.copyWith(color: mac.secondaryLabel),
                ),
              ),
            ),
          ),
          if (hasText)
            Semantics(
              button: true,
              label: MacSearchField.clearLabel,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: widget.controller.clear,
                child: Icon(context.icon(MyDataIcon.clear), size: MyDataMacSize.icon - MyDataMacSize.tight, color: mac.secondaryLabel),
              ),
            ),
        ],
      ),
    );
    return MacChrome.of(context).toolbarItem(field);
  }
}
