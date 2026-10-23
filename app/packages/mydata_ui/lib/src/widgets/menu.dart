import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../mac/mac_overlays.dart' show MacMenuLook;
import '../mac/mac_theme.dart' show MacSystemLook;
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'dialog.dart' show phoneWidth;
import 'icon_button.dart';
import 'pressable.dart';

/// One row of a [Menu]: a [MenuItem] or a [MenuSeparator].
@immutable
sealed class MenuEntry {
  const MenuEntry();
}

/// An action in a [Menu] (design/components/Menu, "An item").
class MenuItem extends MenuEntry {
  const MenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.shortcut,
    this.destructive = false,
    this.enabled = true,
    this.disabledReason,
    this.checked = false,
  });

  /// A verb and its object, in sentence case: "Edit contact"; with an ellipsis when a Dialog follows
  /// ("Delete 3 contacts…").
  final String label;

  /// What choosing it does. It runs after the menu has closed.
  final VoidCallback onSelected;

  /// An optional icon in `ink-muted` (`danger` when [destructive]).
  final IconData? icon;

  /// The same action's shortcut, shown at the end as the platform writes it ([MyDataShortcut]); not shown on
  /// a phone.
  final SingleActivator? shortcut;

  /// It deletes or removes: label and icon in `danger`, hover `danger-soft`, focus ring `ink`. The last item,
  /// after a separator.
  final bool destructive;

  /// False: at 45%, no hover fill, choosing does nothing; still reached by the arrow keys.
  final bool enabled;

  /// Why it is disabled, a full sentence on a line under the label in `caption` and full `ink-muted`. When
  /// several items are disabled for one reason, only the first carries it.
  final String? disabledReason;

  /// Only in a Select's list: the check mark in `accent` at the end, read as selected.
  final bool checked;
}

/// A 1px `line` across the panel between groups of actions; never first or last.
class MenuSeparator extends MenuEntry {
  const MenuSeparator();
}

/// A short list of actions that opens over the screen, on a right-click or long-press of an item (a context
/// menu, [ContextMenuRegion]) or from the "More actions" button (an overflow menu, [MoreActionsButton])
/// (design/components/Menu). It closes as soon as one is chosen.
///
/// - **The panel:** `surface-raised`, `radius-md`, `shadow-2`, `space-1` padding, as wide as its widest item.
/// - **An item:** `control-height` (`control-height-compact` with compact), `space-3` across, a `radius-sm`
///   shape inset `space-1` from the panel's edges. An optional icon (`icon`, `ink-muted`) `space-3` before
///   the label (`body`, `ink`; every item keeps the icon's space when one has an icon); an optional shortcut
///   at the end in `body` and `ink-muted`, at least `space-6` from the label; or, in a Select's list, a
///   check mark in `accent`.
/// - **States:** hover fills the shape with `surface-hover` (`danger-soft` on a destructive item) over
///   `fast`; pressed keeps it and dims to 85%; keyboard focus adds a 2px ring inside the shape (`ink` on a
///   destructive item). Disabled: 45%, no hover fill, with its reason line it grows to `row-height`.
/// - **Keyboard:** opened from the keyboard, focus goes to the first enabled item; opened with the pointer,
///   none until the pointer or a key moves. Up and Down go round, stopping on disabled items; Home and End;
///   typing letters moves to the next item starting with them; Return and Space choose; Escape and Tab
///   close and return focus to what opened it. A click outside only closes it.
/// - **Screen readers:** a menu of menu items, each read by its label, then its shortcut, then dimmed and
///   the reason when disabled.
/// - **Motion:** fades in and grows from 97% from the corner nearest its pointer or button over `base`;
///   closes with a `fast` fade, or at once when an item is chosen. With reduced motion it only fades, over
///   `fast`, and closes at once.
/// - **Where:** a context menu's top start corner at the pointer (under the focused item from the
///   keyboard); an overflow menu `space-1` under its button, lined up with its end edge. Either moves or
///   flips to stay `space-2` inside the window.
abstract final class Menu {
  /// Space kept between the menu and the window's edges.
  static double windowMargin(MyDataLook look) => look.space(2);

  /// Gap between an overflow menu and its button.
  static double anchorGap(MyDataLook look) => look.space(1);

  /// Gap between the label and the shortcut, at least.
  static double shortcutGap(MyDataLook look) => look.space(6);

  /// How long typed letters add up before a new search starts.
  static const typeAheadReset = Duration(milliseconds: 800);

  /// The barrier's name for screen readers.
  static const closeLabel = 'Close menu';

  /// Opens a context menu with its top start corner at [position] (global). Completes after the menu has
  /// closed and the chosen item's action has run.
  static Future<void> showAt(BuildContext context,
          {required Offset position, required List<MenuEntry> entries, bool fromKeyboard = false, bool compact = false}) =>
      _show(context, entries: entries, anchor: position & Size.zero, overflow: false, fromKeyboard: fromKeyboard, compact: compact);

  /// Opens an overflow menu `space-1` under [anchor] (the button's global rect), lined up with its end edge.
  static Future<void> showBelow(BuildContext context,
          {required Rect anchor, required List<MenuEntry> entries, bool fromKeyboard = false, bool compact = false}) =>
      _show(context, entries: entries, anchor: anchor, overflow: true, fromKeyboard: fromKeyboard, compact: compact);

  static Future<void> _show(BuildContext context,
      {required List<MenuEntry> entries,
      required Rect anchor,
      required bool overflow,
      required bool fromKeyboard,
      required bool compact}) async {
    assert(entries.isNotEmpty && entries.first is MenuItem && entries.last is MenuItem,
        'A separator never starts or ends a menu.');
    final navigator = Navigator.of(context, rootNavigator: true);
    final chosen = await navigator.push<VoidCallback>(_MenuRoute(
      entries: entries,
      anchor: anchor,
      overflow: overflow,
      fromKeyboard: fromKeyboard,
      compact: compact,
      reduced: MyDataMotion.reduced(context),
      look: context.look,
      textDirection: Directionality.of(context),
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
    ));
    chosen?.call();
  }
}

class _MenuRoute extends PopupRoute<VoidCallback> {
  _MenuRoute({
    required this.entries,
    required this.anchor,
    required this.overflow,
    required this.fromKeyboard,
    required this.compact,
    required this.reduced,
    required this.look,
    required this.textDirection,
    required this.capturedThemes,
  });

  final List<MenuEntry> entries;
  final Rect anchor;
  final bool overflow;
  final bool fromKeyboard;
  final bool compact;
  final bool reduced;
  final MyDataLook look;
  final TextDirection textDirection;
  final CapturedThemes capturedThemes;

  /// Set when an item is chosen: the menu then closes at once.
  bool instant = false;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => Menu.closeLabel;

  @override
  Duration get transitionDuration => reduced ? look.motion.fast : look.motion.base;

  @override
  Duration get reverseTransitionDuration => instant || reduced ? Duration.zero : look.motion.fast;

  /// The point the menu grows from: the pointer, or the button's bottom end corner.
  Offset get _origin => overflow
      ? (textDirection == TextDirection.ltr ? anchor.bottomRight : anchor.bottomLeft)
      : anchor.topLeft;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      capturedThemes.wrap(MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: CustomSingleChildLayout(
          delegate: _MenuLayout(anchor: anchor, overflow: overflow, textDirection: textDirection, look: look),
          child: _MenuPanel(route: this),
        ),
      ));

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: context.motion.standard);
    final faded = FadeTransition(opacity: curved, child: child);
    if (reduced) return faded;
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final s = context.motion.pressScale + (1 - context.motion.pressScale) * curved.value;
        final o = _origin;
        final m = Matrix4.identity()
          ..translateByDouble(o.dx, o.dy, 0, 1)
          ..scaleByDouble(s, s, 1, 1)
          ..translateByDouble(-o.dx, -o.dy, 0, 1);
        return Transform(transform: m, child: child);
      },
      child: faded,
    );
  }

  void choose(BuildContext context, VoidCallback action) {
    instant = true;
    controller?.reverseDuration = Duration.zero;
    Navigator.of(context).pop(action);
  }
}

/// Places the panel at the pointer or under its button, flipping and moving it to stay inside the window.
class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({required this.anchor, required this.overflow, required this.textDirection, required this.look});

  final Rect anchor;
  final bool overflow;
  final TextDirection textDirection;
  final MyDataLook look;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(EdgeInsets.all(Menu.windowMargin(look)));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final m = Menu.windowMargin(look);
    final ltr = textDirection == TextDirection.ltr;
    double x;
    double y;
    if (overflow) {
      x = ltr ? anchor.right - child.width : anchor.left;
      y = anchor.bottom + Menu.anchorGap(look);
      if (y + child.height > size.height - m) y = anchor.top - Menu.anchorGap(look) - child.height;
    } else {
      x = ltr ? anchor.left : anchor.left - child.width;
      y = anchor.top;
      if (ltr && x + child.width > size.width - m) x = anchor.left - child.width;
      if (!ltr && x < m) x = anchor.left;
      if (y + child.height > size.height - m) y = anchor.top - child.height;
    }
    x = x.clamp(m, math.max(m, size.width - m - child.width));
    y = y.clamp(m, math.max(m, size.height - m - child.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor || old.overflow != overflow || old.textDirection != textDirection || old.look != look;
}

class _MenuPanel extends StatefulWidget {
  const _MenuPanel({required this.route});
  final _MenuRoute route;

  @override
  State<_MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<_MenuPanel> {
  final _panelNode = FocusNode(debugLabel: 'Menu');
  late final List<MenuItem> _items = widget.route.entries.whereType<MenuItem>().toList();
  late final List<FocusNode> _nodes = [for (final i in _items) FocusNode(debugLabel: 'Menu item ${i.label}')];
  int? _active;
  int? _pressed;
  bool _keyboard = false;
  String _typed = '';
  Timer? _typedTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.route.fromKeyboard) {
        final first = _items.indexWhere((i) => i.enabled);
        _moveTo(first < 0 ? 0 : first);
      } else {
        _panelNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _typedTimer?.cancel();
    _panelNode.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _moveTo(int i) {
    setState(() {
      _active = i;
      _keyboard = true;
    });
    _nodes[i].requestFocus();
  }

  void _close() => Navigator.of(context).pop();

  void _choose(int i) {
    final item = _items[i];
    if (!item.enabled) return;
    widget.route.choose(context, item.onSelected);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = _items.length;
    final at = _active;
    if (k == LogicalKeyboardKey.arrowDown) {
      _moveTo(at == null ? 0 : (at + 1) % n);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _moveTo(at == null ? n - 1 : (at - 1 + n) % n);
    } else if (k == LogicalKeyboardKey.home) {
      _moveTo(0);
    } else if (k == LogicalKeyboardKey.end) {
      _moveTo(n - 1);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent && at != null) _choose(at);
    } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.tab) {
      if (e is KeyDownEvent) _close();
    } else {
      final ch = e.character;
      if (ch == null || ch.trim().isEmpty || HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored;
      }
      _typeAhead(ch);
    }
    return KeyEventResult.handled;
  }

  /// Moves to the next item (from the one after the current) whose label starts with what was typed.
  void _typeAhead(String ch) {
    _typedTimer?.cancel();
    _typedTimer = Timer(Menu.typeAheadReset, () => _typed = '');
    _typed += ch.toLowerCase();
    final n = _items.length;
    final start = _typed.length == 1 ? ((_active ?? -1) + 1) : (_active ?? 0);
    for (var step = 0; step < n; step++) {
      final i = (start + step) % n;
      if (_items[i].label.toLowerCase().startsWith(_typed)) return _moveTo(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = widget.route.compact;
    final phone = MediaQuery.sizeOf(context).width < phoneWidth;
    // The Mac frame: a macOS menu (mac/mac_overlays.dart), with the same behaviour.
    final mac = context.isSystemLook;
    final iconSpace = _items.any((i) => i.icon != null);
    final children = <Widget>[];
    var index = 0;
    for (final e in widget.route.entries) {
      switch (e) {
        case MenuSeparator():
          children.add(ExcludeSemantics(
            child: mac
                ? MacMenuLook.separator(context)
                : Container(height: 1, margin: EdgeInsets.symmetric(vertical: context.space(1)), color: c.line),
          ));
        case MenuItem():
          final i = index++;
          children.add(_MenuItemTile(
            item: e,
            node: _nodes[i],
            active: _active == i,
            ring: _active == i && _keyboard,
            pressed: _pressed == i,
            compact: compact,
            iconSpace: iconSpace,
            showShortcut: !phone,
            onHover: (inside) => setState(() {
              if (inside) {
                _active = i;
                _keyboard = false;
              } else if (_active == i && !_keyboard) {
                _active = null;
              }
            }),
            onPressed: (down) => setState(() => _pressed = down && e.enabled ? i : null),
            onChoose: () => _choose(i),
          ));
      }
    }
    return Focus(
      focusNode: _panelNode,
      onKeyEvent: _onKey,
      child: Semantics(
        role: SemanticsRole.menu,
        explicitChildNodes: true,
        scopesRoute: true,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: mac ? MacMenuLook.padding(context.look) : EdgeInsets.all(context.space(1)),
            decoration: mac
                ? MacMenuLook.panel(context)
                : BoxDecoration(color: c.surfaceRaised, borderRadius: MyDataRadii.md(context.look), boxShadow: context.shadows.shadow2),
            child: IntrinsicWidth(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.node,
    required this.active,
    required this.ring,
    required this.pressed,
    required this.compact,
    required this.iconSpace,
    required this.showShortcut,
    required this.onHover,
    required this.onPressed,
    required this.onChoose,
  });

  final MenuItem item;
  final FocusNode node;
  final bool active;
  final bool ring;
  final bool pressed;
  final bool compact;
  final bool iconSpace;
  final bool showShortcut;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onPressed;
  final VoidCallback onChoose;

  /// Width of the ring drawn inside the item's shape.
  static const ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = item.destructive ? c.danger : c.ink;
    final iconColour = item.destructive ? c.danger : c.inkMuted;
    final fill = item.destructive ? c.dangerSoft : c.surfaceHover;
    final shortcut = item.shortcut;
    final faded = item.enabled ? 1.0 : Pressable.disabledOpacity;
    final reason = item.enabled ? null : item.disabledReason;

    Widget label = Text(item.label, maxLines: 1, softWrap: false, style: context.typeScale.body.copyWith(color: fg));
    label = Opacity(opacity: faded, child: label);
    if (reason != null) {
      label = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        label,
        Text(reason, maxLines: 1, softWrap: false, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
      ]);
    }

    final row = Row(children: [
      if (iconSpace) ...[
        Opacity(
          opacity: faded,
          child: SizedBox.square(
            dimension: context.density.icon,
            child: item.icon == null ? null : Icon(item.icon, size: context.density.icon, color: iconColour),
          ),
        ),
        SizedBox(width: context.space(3)),
      ],
      Expanded(child: label),
      if (shortcut != null && showShortcut) ...[
        SizedBox(width: Menu.shortcutGap(context.look)),
        Opacity(
          opacity: faded,
          child: Text(MyDataShortcut.shown(shortcut, platform: Theme.of(context).platform),
              style: context.typeScale.body.copyWith(color: c.inkMuted)),
        ),
      ],
      if (item.checked) ...[
        SizedBox(width: Menu.shortcutGap(context.look)),
        Icon(Icons.check_rounded, size: context.density.icon, color: c.accent),
      ],
    ]);

    final height = reason != null
        ? context.density.rowHeight
        : (compact ? context.density.controlHeightCompact : context.density.controlHeight);
    // The Mac frame: a macOS menu item (mac/mac_overlays.dart); the keyboard's item is on the accent. A macOS
    // menu item has no second line: a disabled item's reason is its help tag (a tooltip) and its hint.
    final mac = context.isSystemLook;
    Widget tile = mac
        ? MacMenuLook.item(
            context,
            label: item.label,
            icon: item.icon,
            iconSpace: iconSpace,
            shortcut: shortcut != null && showShortcut
                ? MyDataShortcut.shown(shortcut, platform: Theme.of(context).platform)
                : null,
            checked: item.checked,
            active: active,
            enabled: item.enabled,
            destructive: item.destructive,
          )
        : AnimatedContainer(
      duration: context.motion.fast,
      curve: context.motion.standard,
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(horizontal: context.space(3), vertical: reason != null ? context.space(2) : 0),
      decoration: BoxDecoration(
        color: active && item.enabled ? fill : fill.withValues(alpha: 0),
        borderRadius: MyDataRadii.sm(context.look),
      ),
      foregroundDecoration: ring
          ? BoxDecoration(
              borderRadius: MyDataRadii.sm(context.look),
              border: Border.all(color: FocusRing.colourFor(context, danger: item.destructive), width: ringWidth),
            )
          : null,
      child: row,
    );
    tile = Opacity(opacity: pressed ? context.motion.pressOpacity : 1, child: tile);
    if (mac && reason != null) tile = MacMenuLook.helpTag(context, message: reason, child: tile);

    final spokenShortcut = shortcut == null ? null : MyDataShortcut.spoken(shortcut);
    final hint = [?spokenShortcut, ?reason].join(', ');
    return Semantics(
      role: SemanticsRole.menuItem,
      label: item.label,
      hint: hint.isEmpty ? null : hint,
      enabled: item.enabled,
      // The item's own Focus is excluded with its tile: screen readers hear which item has focus from here.
      focusable: true,
      focused: node.hasFocus,
      selected: item.checked ? true : null,
      onTap: item.enabled ? onChoose : null,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: node,
          child: MouseRegion(
            cursor: item.enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => onPressed(true),
              onTapCancel: () => onPressed(false),
              onTap: () {
                onPressed(false);
                onChoose();
              },
              child: tile,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a context menu for [child] (design/components/Menu, "Opening"): on a right-click, a Control-click
/// on macOS, a long-press (with the platform's light tap), and from the keyboard with Shift-F10 or the
/// context menu key while focus is inside [child] (under the focused item). Each enabled item is also a
/// custom action of [child] for screen readers (VoiceOver's Actions rotor, TalkBack's actions), so nothing
/// needs the long-press.
///
/// The menu acts on the item under the pointer; [onOpenChanged] lets that item keep its hover fill while
/// the menu is open. The selection does not move: a Control-click does not reach [child].
class ContextMenuRegion extends StatefulWidget {
  const ContextMenuRegion({super.key, required this.entries, required this.child, this.onOpenChanged, this.compact = false});

  /// Built when the menu opens, so the labels can give the current count ("Delete 3 contacts…").
  final List<MenuEntry> Function() entries;
  final Widget child;
  final ValueChanged<bool>? onOpenChanged;
  final bool compact;

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  bool _open = false;

  Future<void> _openAt(Offset position, {required bool fromKeyboard}) async {
    if (_open) return;
    _open = true;
    widget.onOpenChanged?.call(true);
    try {
      await Menu.showAt(context,
          position: position, entries: widget.entries(), fromKeyboard: fromKeyboard, compact: widget.compact);
    } finally {
      _open = false;
      if (mounted) widget.onOpenChanged?.call(false);
    }
  }

  void _pointerDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse && e.kind != PointerDeviceKind.trackpad) return;
    final secondary = e.buttons & kSecondaryMouseButton != 0;
    final controlClick = defaultTargetPlatform == TargetPlatform.macOS &&
        e.buttons & kPrimaryMouseButton != 0 &&
        HardwareKeyboard.instance.isControlPressed;
    if (!secondary && !controlClick) return;
    // The click opens the menu and nothing else: the row under it is not pressed or selected.
    GestureBinding.instance.cancelPointer(e.pointer);
    unawaited(_openAt(e.position, fromKeyboard: false));
  }

  void _fromKeyboard() {
    final focused = FocusManager.instance.primaryFocus;
    final box = context.findRenderObject() as RenderBox?;
    final rect = focused?.rect ?? (box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size);
    final ltr = Directionality.of(context) == TextDirection.ltr;
    unawaited(_openAt(ltr ? rect.bottomLeft : rect.bottomRight, fromKeyboard: true));
  }

  @override
  Widget build(BuildContext context) {
    final actions = {
      for (final e in widget.entries())
        if (e is MenuItem && e.enabled) CustomSemanticsAction(label: e.label): e.onSelected,
    };
    return Semantics(
      customSemanticsActions: actions,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): _fromKeyboard,
          const SingleActivator(LogicalKeyboardKey.contextMenu): _fromKeyboard,
        },
        child: Listener(
          onPointerDown: _pointerDown,
          child: GestureDetector(
            onLongPressStart: (d) {
              unawaited(HapticFeedback.lightImpact());
              unawaited(_openAt(d.globalPosition, fromKeyboard: false));
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The "More actions" button (three dots): the one [MyDataIconButton] that opens a [Menu], an overflow menu
/// `space-1` under it, lined up with its end edge, on a click, Return, Space or Down. It is announced as
/// expanded or collapsed.
class MoreActionsButton extends StatefulWidget {
  const MoreActionsButton({
    super.key,
    required this.entries,
    this.label = defaultLabel,
    this.tone = IconButtonTone.normal,
    this.compact = false,
    this.focusNode,
  });

  /// Built when the menu opens.
  final List<MenuEntry> Function() entries;

  /// "More actions", or what it acts on when several share a screen.
  final String label;
  final IconButtonTone tone;
  final bool compact;
  final FocusNode? focusNode;

  static const defaultLabel = 'More actions';

  @override
  State<MoreActionsButton> createState() => _MoreActionsButtonState();
}

class _MoreActionsButtonState extends State<MoreActionsButton> {
  bool _open = false;
  bool _pointer = false;

  Future<void> _openMenu({required bool fromKeyboard}) async {
    if (_open) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _open = true);
    try {
      await Menu.showBelow(context,
          anchor: box.localToGlobal(Offset.zero) & box.size,
          entries: widget.entries(),
          fromKeyboard: fromKeyboard,
          compact: widget.compact);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => unawaited(_openMenu(fromKeyboard: true)),
        },
        child: Listener(
          onPointerDown: (_) => _pointer = true,
          child: MyDataIconButton(
            icon: Icons.more_horiz_rounded,
            label: widget.label,
            tone: widget.tone,
            compact: widget.compact,
            focusNode: widget.focusNode,
            expanded: _open,
            onPressed: () {
              final fromKeyboard = !_pointer;
              _pointer = false;
              unawaited(_openMenu(fromKeyboard: fromKeyboard));
            },
          ),
        ),
      );
}
