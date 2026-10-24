import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/floating_bar.dart' show FloatingBarSurface;
import 'mac_chrome.dart';
import 'mac_metrics.dart';
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
    // A drawn theme's toolbar style: `native` is the band as the Mac draws it, `flat` a solid `toolbar`
    // band with a rule under it, `floating` a detached capsule with the theme's lift and outline.
    final style = context.isSystemLook || background != null ? ToolbarStyle.native : context.variants.toolbar;
    final c = context.colors;
    final floating = style == ToolbarStyle.floating;
    final overlaidRule = context.macLook.toolbarTarget > MyDataMacSize.toolbarItemHeight;
    final Decoration? decoration = switch (style) {
      ToolbarStyle.native => BoxDecoration(
          color: background ?? mac.contentBackground,
          border: separator ? Border(bottom: BorderSide(color: mac.separator)) : null,
        ),
      // Under a theme that promises the band's height for every target (Large), the rule is drawn over the
      // band's foot rather than taking its room, so the items keep the band's full height.
      ToolbarStyle.flat => BoxDecoration(
          color: c.toolbar, border: overlaidRule ? null : Border(bottom: context.look.edges.side)),
      // The capsule is a FloatingBarSurface (below), in the theme's bar material.
      ToolbarStyle.floating => null,
    };
    final titleStyle = (context.isSystemLook ? MyDataMacType.title : context.typeScale.heading).copyWith(color: mac.label);
    final subtitleStyle =
        (context.isSystemLook ? MyDataMacType.caption : context.typeScale.caption).copyWith(color: mac.secondaryLabel);
    // A floating capsule stands `space-1` off the band's edges, less where a theme's title and subtitle need
    // the room (Sticker's two lines are taller than the capsule would be).
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle s) => (scaler.scale(s.fontSize!) * (s.height ?? 1)).ceilToDouble();
    final text = title == null ? 0.0 : line(titleStyle) + (subtitle == null ? 0 : line(subtitleStyle));
    final inset = floating
        ? ((MyDataMacSize.toolbarHeight - text) / 2 - FloatingBarSurface.strokeWidth).clamp(0.0, context.space(1))
        : 0.0;
    Widget band = Container(
      height: floating
          ? MyDataMacSize.toolbarHeight - 2 * (inset + FloatingBarSurface.strokeWidth)
          : MyDataMacSize.toolbarHeight,
      padding: EdgeInsetsDirectional.only(
        // A floating capsule leaves the window's buttons their room outside it (below), not inside.
        start: MyDataMacSize.toolbarInset + (windowControls && !floating ? MyDataMacSize.windowControlsWidth : 0),
        end: MyDataMacSize.toolbarInset,
      ),
      decoration: decoration,
      foregroundDecoration: style == ToolbarStyle.flat && overlaidRule
          ? BoxDecoration(border: Border(bottom: context.look.edges.side))
          : null,
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
                    // A drawn theme's title in its own type.
                    Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle),
                  ],
                ),
              ),
              ),
            ),
          // Without a title the trailing items sit at the end, and a search field among them gives up width
          // before anything overflows: at the window's smallest (720 wide) the pane beside a list is narrower
          // than its 325.
          if (title == null && trailing.isNotEmpty && leading.isNotEmpty) SizedBox(width: itemGap(context.look)),
          if (title == null && trailing.isNotEmpty)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final (i, w) in trailing.indexed) ...[
                    if (i > 0) SizedBox(width: itemGap(context.look)),
                    w is MacSearchField ? Flexible(child: w) : w,
                  ],
                ]),
              ),
            )
          else
            for (final (i, w) in trailing.indexed) ...[if (i > 0) SizedBox(width: itemGap(context.look)), w],
        ],
      ),
    );
    if (floating) {
      // A capsule in the theme's bar material (blur, translucent or solid; solid under reduced transparency)
      // over the content's own ground, which shows around it. Beside the window's buttons it starts after
      // them, so none of them sits on the capsule.
      band = Padding(
        padding: EdgeInsetsDirectional.only(
          start: context.space(2) + (windowControls ? MyDataMacSize.windowControlsWidth : 0),
          end: context.space(2),
          top: inset,
          bottom: inset,
        ),
        child: FloatingBarSurface(padding: EdgeInsets.zero, child: band),
      );
    }
    return band;
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
    final m = context.macLook;
    final enabled = widget.onPressed != null;
    final ink = enabled ? mac.label : mac.tertiaryLabel;
    final tip = [
      widget.shortcut == null ? widget.label : '${widget.label}  ${widget.shortcut}',
      if (!enabled && widget.disabledReason != null) widget.disabledReason!,
    ].join('\n');
    final Widget face = widget.icon != null
        ? Icon(context.icon(widget.icon!), size: m.icon, color: ink)
        : Text(widget.text!, style: m.body.copyWith(color: enabled ? mac.label : mac.tertiaryLabel));
    final rest = m.itemSide ?? BorderSide(color: mac.separator, width: MyDataMacSize.hairline);
    Widget button = AnimatedContainer(
      duration: context.motion.fast,
      height: m.toolbarItemHeight,
      constraints: BoxConstraints(minWidth: m.toolbarItemHeight),
      // A word is a capsule (macOS 26's toolbar text items), wider than tall: never a circle round a word.
      padding: EdgeInsets.symmetric(horizontal: widget.icon != null ? 0 : context.space(4)),
      alignment: Alignment.center,
      // An icon on its own is a circle where the controls are capsules, else the controls' corners.
      decoration: m.decorate(BoxDecoration(
        color: enabled && (_hovered || _pressed)
            ? Color.alphaBlend(_pressed ? mac.quaternaryLabel : mac.hover, mac.toolbarItem)
            : mac.toolbarItem,
        borderRadius: m.controlRadius,
        border: _focused
            ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
            : Border.fromBorderSide(rest),
      )),
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
    // A theme that promises its control height for every target (Large) takes the press over the band's
    // height and as wide, around the item drawn at the band's size.
    button = MacTarget(min: Size.square(m.toolbarTarget), onTap: widget.onPressed, child: button);
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
/// toolbar items; only a line under it in a drawn theme whose fields are underlined), a magnifier, the
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
    final m = context.macLook;
    final hasText = widget.controller.text.isNotEmpty;
    // A drawn theme whose fields are underlined (Terminal's prompt line, Journal, Paperback, Notebook) draws
    // no box: a field's line under the text, as its other fields; the focus ring still goes all round.
    final underlined = !m.system && context.variants.inputs == InputStyle.underlined;
    // Its [width] at most: in a narrow pane the toolbar gives it less ([MacToolbar]).
    final field = Container(
      constraints: BoxConstraints(maxWidth: widget.width),
      height: m.toolbarItemHeight,
      padding: EdgeInsets.symmetric(horizontal: underlined && !_focused ? 0 : context.space(3)),
      decoration: underlined
          ? BoxDecoration(
              border: _focused
                  ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
                  : Border(bottom: FloatingBarSurface.fieldSide(context.look)))
          : m.decorate(BoxDecoration(
              color: mac.toolbarItem,
              borderRadius: m.controlRadius,
              border: _focused
                  ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
                  : Border.fromBorderSide(m.itemSide ?? BorderSide(color: mac.separator, width: MyDataMacSize.hairline)),
            )),
      child: Row(
        children: [
          Icon(context.icon(MyDataIcon.search), size: m.icon, color: mac.secondaryLabel),
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
                style: m.body.copyWith(color: mac.label),
                cursorColor: mac.accent,
                cursorHeight: m.body.fontSize! + MyDataMacSize.tight,
                decoration: InputDecoration.collapsed(
                  hintText: widget.placeholder,
                  hintStyle: m.secondary(m.body).copyWith(color: mac.secondaryLabel),
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
                child: Icon(context.icon(MyDataIcon.clear), size: m.icon - MyDataMacSize.tight, color: mac.secondaryLabel),
              ),
            ),
        ],
      ),
    );
    // In a theme that promises its control height for every target (Large), a press anywhere in the band's
    // height above or below the field puts the caret in it.
    return MacChrome.of(context)
        .toolbarItem(MacTarget(min: Size(0, m.toolbarTarget), onTap: _focus.requestFocus, child: field));
  }
}
