import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// The three tones of [MyDataIconButton] (design/components/IconButton, "Tones").
enum IconButtonTone {
  /// The icon in `ink`: bars, title bars and navigation (MonthGrid's previous and next).
  normal,

  /// The icon in `ink-muted`: a secondary action at the end of a row whose value stays the loudest thing
  /// (FieldRow's copy button).
  quiet,

  /// The icon in `danger`, hover `danger-soft`, focus ring `ink`: only for removing one value from a form
  /// that has not been saved ("Remove mobile number"). Deleting a saved record with Undo uses [normal].
  danger;

  /// The icon's colour at rest.
  Color foreground(MyDataColors c) => switch (this) {
        normal => c.ink,
        quiet => c.inkMuted,
        danger => c.danger,
      };

  /// The circle's fill while hovered.
  Color hoverFill(MyDataColors c) => this == danger ? c.dangerSoft : c.surfaceHover;
}

/// A round button with only an icon, for a frequent action whose icon people already know
/// (design/components/IconButton).
///
/// - A `control-height` circle (`radius-pill`), or `control-height-compact` with [compact]; one outline icon
///   at `icon` size, centred; no border and no fill at rest. The tone sets the icon's colour.
/// - **Hover:** the circle fills with `surface-hover` (`danger-soft` in the danger tone) over `fast`.
///   **Pressed:** the shared press ([Pressable]). **Focused:** the 2px ring 2px outside the circle, `ink` in
///   the danger tone (design/README.md "Focus and danger"); keyboard focus also shows the tooltip at once.
/// - **Disabled** ([onPressed] null): the icon at 45%; a [disabledReason] is required and the button stays
///   focusable (design/platforms.md "Disabled controls"): focus and hover show the tooltip with the reason on
///   a second line in `ink-muted`, and screen readers hear it as the hint.
/// - **Toggled on** ([toggled] true, for a button that switches a state on a record, such as Flag): an
///   `accent-soft` fill, the icon in `accent`, drawn as the theme draws a selected icon (filled where it fills
///   them), or [toggledIcon] when one is given. It is announced as a toggle that is on or off, and its name
///   never changes ("Flag", never "Unflag").
/// - **Done** ([done] true, for a one-shot result shown in place, such as Copy): the icon becomes a check in
///   the button's tone and the tooltip becomes [doneLabel] ("Copied").
/// - **Tooltip:** `surface-raised`, `radius-sm`, `shadow-2`, `caption` in `ink`, `space-1` by `space-2`
///   padding, `space-1` below the button (above when there is no room). It holds [label] exactly, then the
///   [shortcut] in `ink-muted` ("New event ⌘N"). Escape hides it. On iPhone it is not shown; on Android a
///   long press shows it, as the platform does.
/// - [label] is the accessible name and the tooltip: a verb and its object ("Copy work email"), or the
///   destination ("Previous month"); never "Click to…" or the icon's own name.
///
/// Flutter's tooltip fades in over its own 150ms, not `fast` (120ms); its delay is the platform's hover
/// delay as the spec asks.
class MyDataIconButton extends StatefulWidget {
  const MyDataIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = IconButtonTone.normal,
    this.toggled,
    this.toggledIcon,
    this.done = false,
    this.doneLabel,
    this.shortcut,
    this.disabledReason,
    this.compact = false,
    this.expanded,
    this.focusNode,
    this.autofocus = false,
  }) : assert(onPressed != null || disabledReason != null, 'A button is never disabled without a reason.'),
       assert(toggled == null || tone != IconButtonTone.danger, 'The danger tone has no toggled state.');

  /// The icon, by meaning; the look's icon set draws it.
  final MyDataIcon icon;

  /// The accessible name and the tooltip, in sentence case with no full stop.
  final String label;

  /// The action. Null disables the button; [disabledReason] must then say why.
  final VoidCallback? onPressed;

  final IconButtonTone tone;

  /// Non-null makes it a toggle button, announced as on or off.
  final bool? toggled;

  /// Another icon to show while [toggled] is true. Without one, [icon] is drawn as a selected icon.
  final MyDataIcon? toggledIcon;

  /// The one-shot result is showing: a check in place of the icon, and [doneLabel] in the tooltip.
  final bool done;

  /// The result word while [done]: "Copied".
  final String? doneLabel;

  /// A shortcut for the same action, shown after the label in the tooltip ([MyDataShortcut]).
  final SingleActivator? shortcut;

  /// Why the button is disabled: a full sentence with a full stop ("The host cannot be reached.").
  final String? disabledReason;

  /// Compact density on desktop: a `control-height-compact` target. The icon stays `icon` size.
  final bool compact;

  /// For a button that opens a menu ("More actions"): whether the menu is open, announced as expanded or
  /// collapsed. Null for every other button.
  final bool? expanded;

  final FocusNode? focusNode;
  final bool autofocus;

  /// The fill of a toggled-on button changes over `fast`, as the hover fill does.
  static Duration fillDuration(MyDataLook look) => look.motion.fast;

  @override
  State<MyDataIconButton> createState() => _MyDataIconButtonState();
}

class _MyDataIconButtonState extends State<MyDataIconButton> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'MyDataIconButton'));
  final _tooltipKey = GlobalKey<TooltipState>();
  bool _showingForFocus = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(MyDataIconButton old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownNode)?.removeListener(_focusChanged);
      _node.addListener(_focusChanged);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_focusChanged);
    _ownNode?.dispose();
    super.dispose();
  }

  /// Keyboard focus shows the tooltip at once; losing focus takes it away.
  void _focusChanged() {
    final keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (_node.hasPrimaryFocus && keyboard) {
      _showingForFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _node.hasPrimaryFocus) _tooltipKey.currentState?.ensureTooltipVisible();
      });
    } else if (_showingForFocus && !_node.hasPrimaryFocus) {
      _showingForFocus = false;
      Tooltip.dismissAllToolTips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = widget.toggled == true;
    final size = widget.compact ? context.density.controlHeightCompact : context.density.controlHeight;
    final fg = on ? c.accent : widget.tone.foreground(c);
    final glyph = widget.done
        ? MyDataIcon.check
        : (on && widget.toggledIcon != null ? widget.toggledIcon! : widget.icon);

    Widget body = AnimatedContainer(
      duration: MyDataIconButton.fillDuration(context.look),
      curve: context.motion.standard,
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: on ? c.accentSoft : c.accentSoft.withValues(alpha: 0), borderRadius: MyDataRadii.pill(context.look)),
      alignment: Alignment.center,
      child: Icon(context.icon(glyph, selected: on && !widget.done), size: context.density.icon, color: fg),
    );

    body = Pressable(
      onPressed: widget.onPressed,
      borderRadius: MyDataRadii.pill(context.look),
      hoverFill: widget.tone.hoverFill(c),
      focusNode: _node,
      autofocus: widget.autofocus,
      semanticLabel: widget.label,
      toggled: widget.toggled,
      danger: widget.tone == IconButtonTone.danger,
      disabledReason: widget.disabledReason,
      child: ExcludeSemantics(child: body),
    );
    if (widget.expanded != null) body = Semantics(expanded: widget.expanded, child: body);
    // Escape hides a showing tooltip first; with none showing, the key goes on (a dialog's Cancel).
    body = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, e) => e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && Tooltip.dismissAllToolTips()
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: body,
    );

    if (defaultTargetPlatform == TargetPlatform.iOS) return body;
    final name = widget.done && widget.doneLabel != null ? widget.doneLabel! : widget.label;
    final shortcut = widget.shortcut;
    final enabled = widget.onPressed != null;
    return Tooltip(
      key: _tooltipKey,
      excludeFromSemantics: true,
      preferBelow: true,
      verticalOffset: size / 2 + context.space(1),
      padding: EdgeInsets.symmetric(vertical: context.space(1), horizontal: context.space(2)),
      richMessage: TextSpan(text: name, children: [
        if (shortcut != null && !widget.done)
          TextSpan(text: ' ${MyDataShortcut.shown(shortcut, platform: Theme.of(context).platform)}', style: TextStyle(color: c.inkMuted)),
        if (!enabled) TextSpan(text: '\n${widget.disabledReason}', style: TextStyle(color: c.inkMuted)),
      ]),
      child: body,
    );
  }
}

/// Keyboard shortcuts as the platform writes and speaks them (design/platforms.md "The menu bar on macOS";
/// Menu "Copy"): "⌘⌫" on macOS and "Delete" elsewhere; "Command Delete" to a screen reader.
abstract final class MyDataShortcut {
  /// Whether [platform] (the current one when null) writes shortcuts the Apple way.
  static bool _apple(TargetPlatform? platform) =>
      switch (platform ?? defaultTargetPlatform) { TargetPlatform.macOS || TargetPlatform.iOS => true, _ => false };

  /// The platform's command modifier with [key]: Command on macOS, Control elsewhere (⌘N, Ctrl+N).
  static SingleActivator primary(LogicalKeyboardKey key, {bool shift = false, bool alt = false, TargetPlatform? platform}) =>
      _apple(platform)
          ? SingleActivator(key, meta: true, shift: shift, alt: alt)
          : SingleActivator(key, control: true, shift: shift, alt: alt);

  /// As shown in a menu or tooltip: "⌘N", "⌥⌘N", "⌘⌫" on macOS; "Ctrl+N", "Ctrl+Alt+N", "Delete" elsewhere.
  static String shown(SingleActivator s, {TargetPlatform? platform}) {
    final apple = _apple(platform);
    if (apple) {
      return [
        if (s.control) '⌃',
        if (s.alt) '⌥',
        if (s.shift) '⇧',
        if (s.meta) '⌘',
        _keyShown(s.trigger, apple: true),
      ].join();
    }
    return [
      if (s.control) 'Ctrl',
      if (s.alt) 'Alt',
      if (s.shift) 'Shift',
      if (s.meta) 'Meta',
      _keyShown(s.trigger, apple: false),
    ].join('+');
  }

  /// As a screen reader says it: "Command Delete", "Control N".
  static String spoken(SingleActivator s, {TargetPlatform? platform}) {
    final apple = _apple(platform);
    return [
      if (s.control) 'Control',
      if (s.alt) apple ? 'Option' : 'Alt',
      if (s.shift) 'Shift',
      if (s.meta) apple ? 'Command' : 'Meta',
      _keySpoken(s.trigger, apple: apple),
    ].join(' ');
  }

  static String _keyShown(LogicalKeyboardKey k, {required bool apple}) {
    if (apple) {
      final glyph = _appleGlyphs[k];
      if (glyph != null) return glyph;
    }
    return _keySpoken(k, apple: apple);
  }

  static String _keySpoken(LogicalKeyboardKey k, {required bool apple}) {
    if (k == LogicalKeyboardKey.backspace) return apple ? 'Delete' : 'Backspace';
    if (k == LogicalKeyboardKey.delete) return apple ? 'Forward Delete' : 'Delete';
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) return apple ? 'Return' : 'Enter';
    final name = _names[k];
    if (name != null) return name;
    final label = k.keyLabel;
    return label.length == 1 ? label.toUpperCase() : label;
  }

  static final _appleGlyphs = {
    LogicalKeyboardKey.backspace: '⌫',
    LogicalKeyboardKey.delete: '⌦',
    LogicalKeyboardKey.enter: '↩',
    LogicalKeyboardKey.numpadEnter: '↩',
    LogicalKeyboardKey.escape: '⎋',
    LogicalKeyboardKey.tab: '⇥',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.period: '.',
    LogicalKeyboardKey.comma: ',',
  };

  static final _names = {
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.arrowUp: 'Up',
    LogicalKeyboardKey.arrowDown: 'Down',
    LogicalKeyboardKey.arrowLeft: 'Left',
    LogicalKeyboardKey.arrowRight: 'Right',
    LogicalKeyboardKey.period: 'Period',
    LogicalKeyboardKey.comma: 'Comma',
  };
}
