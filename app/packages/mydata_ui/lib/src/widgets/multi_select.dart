import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../mac/mac_chrome.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'checkbox.dart';
import 'pressable.dart';
import 'toggle_target.dart';

/// The selection of several rows in a list of records (design/components/MultiSelect): which rows are
/// selected, the anchor that ⇧ extends from, and the focused row the keyboard is on. It holds no records,
/// only their keys, in list order ([rows]); list widgets ([MultiSelectList], and later ContactList and the
/// message list) draw from it and feed it clicks and keys.
///
/// - [select]: a plain click or a plain arrow key. Only that row; it becomes the anchor and the focus.
/// - [toggle]: ⌘-click (Ctrl-click elsewhere), or Space on the focused row. Adds or removes the row; it
///   becomes the new anchor.
/// - [extendTo]: ⇧-click, ⇧-Up and ⇧-Down, ⇧-Home and ⇧-End. Every row from the anchor to this one, in list
///   order, keeping the rows added with ⌘ before.
/// - [selectAll]: ⌘A while the list has focus.
/// - [focusOnly]: Option-Up and Option-Down move the focus without changing the selection, so Space can add
///   a row that is not next to the others.
/// - [clearToFocused]: Escape, with two or more rows selected, back to one: the focused row when it is
///   selected, else the anchor, else the first selected row. With one row or none it does nothing, so the
///   key goes on (it clears a search).
/// - Setting [rows] (a search hid some) drops the hidden rows from the selection, and they do not come back
///   when the search is cleared: an action never reaches a record the user cannot see.
class MultiSelectController<K> extends ChangeNotifier {
  MultiSelectController({List<K> rows = const []}) : _rows = List.unmodifiable(rows);

  List<K> _rows;
  final Set<K> _selected = {};

  /// The selection when the anchor was last set: ⇧ adds its range to this.
  Set<K> _base = {};
  K? _anchor;
  K? _focused;

  /// The rows on screen, in list order.
  List<K> get rows => _rows;
  set rows(List<K> rows) {
    _rows = List.unmodifiable(rows);
    final shown = rows.toSet();
    final before = _selected.length;
    _selected.removeWhere((k) => !shown.contains(k));
    _base.removeWhere((k) => !shown.contains(k));
    if (_anchor != null && !shown.contains(_anchor)) _anchor = null;
    if (_focused != null && !shown.contains(_focused)) _focused = null;
    if (before != _selected.length) notifyListeners();
  }

  /// The selected rows, in list order.
  List<K> get selected => [for (final k in _rows) if (_selected.contains(k)) k];
  int get count => _selected.length;
  bool isSelected(K key) => _selected.contains(key);
  K? get anchor => _anchor;
  K? get focused => _focused;

  int _indexOf(K? key) => key == null ? -1 : _rows.indexOf(key);

  void _set(Set<K> selection, {K? anchor, required K? focused, bool rebase = true}) {
    _selected
      ..clear()
      ..addAll(selection);
    if (anchor != null) _anchor = anchor;
    _focused = focused;
    if (rebase) _base = {..._selected};
    notifyListeners();
  }

  /// Only [key]: a plain click.
  void select(K key) => _set({key}, anchor: key, focused: key);

  /// Adds or removes [key]: ⌘-click, or Space on the focused row.
  void toggle(K key) {
    final next = {..._selected};
    if (!next.remove(key)) next.add(key);
    _set(next, anchor: key, focused: key);
  }

  /// Every row from the anchor to [key], keeping the rows added before with ⌘: ⇧-click.
  void extendTo(K key) {
    final a = _indexOf(_anchor);
    final b = _indexOf(key);
    if (b < 0) return;
    if (a < 0) {
      select(key);
      return;
    }
    final range = _rows.sublist(math.min(a, b), math.max(a, b) + 1);
    _set({..._base, ...range}, focused: key, rebase: false);
  }

  /// Every row in the list: ⌘A.
  void selectAll() {
    if (_rows.isEmpty) return;
    _set(_rows.toSet(), anchor: _anchor ?? _rows.first, focused: _focused ?? _rows.first);
  }

  /// Moves the focus to [key] without changing the selection: Option-Up and Option-Down.
  void focusOnly(K key) {
    _focused = key;
    notifyListeners();
  }

  /// Back to one row: Escape. With two or more selected, keeps the focused row when it is selected, else the
  /// anchor, else the first selected row in list order. False with one row or none, which is not a selection
  /// of several: nothing changes and the key goes on (it then clears a search). Escape never moves or makes a
  /// single selection.
  bool clearToFocused() {
    if (_selected.length <= 1) return false;
    final K keep;
    if (_focused != null && _selected.contains(_focused)) {
      keep = _focused as K;
    } else if (_anchor != null && _selected.contains(_anchor)) {
      keep = _anchor as K;
    } else {
      keep = selected.first;
    }
    _set({keep}, anchor: keep, focused: keep);
    return true;
  }

  /// The platform's command key: ⌘ on Apple platforms, Control elsewhere. On macOS Control is the
  /// context-menu modifier (design/components/Menu), never ⌘.
  static bool commandPressed(HardwareKeyboard k) => switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => k.isMetaPressed && !k.isControlPressed,
        _ => k.isControlPressed && !k.isMetaPressed,
      };

  /// Clears the selection (leaving select mode on a phone).
  void clear() {
    _anchor = null;
    _set({}, focused: _focused);
  }

  /// Whether [key]'s selection joins the row before it and the row after it (both selected and adjacent in
  /// the list): a run of selected rows shares one ring and no divider.
  ({bool up, bool down}) joins(K key) {
    final i = _indexOf(key);
    if (i < 0 || !_selected.contains(key)) return (up: false, down: false);
    return (
      up: i > 0 && _selected.contains(_rows[i - 1]),
      down: i < _rows.length - 1 && _selected.contains(_rows[i + 1]),
    );
  }

  /// The keyboard of a list with this selection (design/components/MultiSelect, "Keyboard"): Up and Down
  /// select one row; ⇧ extends from the anchor; Option moves the focus only; Space toggles the focused row;
  /// Home and End; ⌘A; Escape. [page] is how many rows Page Up and Page Down move.
  KeyEventResult handleKey(KeyEvent event, {int page = 10}) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_rows.isEmpty) return KeyEventResult.ignored;
    final k = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyA && commandPressed(k)) {
      selectAll();
      return KeyEventResult.handled;
    }
    // Other keys with ⌘ or Control (either platform's) are the app's or the system's.
    if (k.isMetaPressed || k.isControlPressed) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape) {
      return clearToFocused() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    final at = _indexOf(_focused);
    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      toggle(_rows[at < 0 ? 0 : at]);
      return KeyEventResult.handled;
    }
    final last = _rows.length - 1;
    int? to;
    if (key == LogicalKeyboardKey.arrowDown) {
      to = at < 0 ? 0 : math.min(last, at + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = at < 0 ? 0 : math.max(0, at - 1);
    } else if (key == LogicalKeyboardKey.home) {
      to = 0;
    } else if (key == LogicalKeyboardKey.end) {
      to = last;
    } else if (key == LogicalKeyboardKey.pageDown) {
      to = math.min(last, math.max(at, 0) + page);
    } else if (key == LogicalKeyboardKey.pageUp) {
      to = math.max(0, at - page);
    }
    if (to == null) return KeyEventResult.ignored;
    final target = _rows[to];
    if (k.isShiftPressed) {
      if (_anchor == null) _anchor = _focused ?? target;
      extendTo(target);
    } else if (k.isAltPressed) {
      focusOnly(target);
    } else {
      select(target);
    }
    return KeyEventResult.handled;
  }
}

/// "Ava Fictional, Ben Sample, Cleo Example and 9 more": up to [shown] names and the rest as a count, as a
/// Dialog writes them; "Ava Fictional and Ben Sample" when all fit.
String summariseNames(List<String> names, {int shown = 3}) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length <= shown) {
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }
  return '${names.take(shown).join(', ')} and ${names.length - shown} more';
}

/// How a selected row looks, and its focus (design/components/MultiSelect, "How selection looks"): the
/// ContactList mark extended to several rows.
///
/// - Selected: the `accent-soft` fill and a 2px `ink` ring inside the row. A run of adjacent selected rows
///   shares one ring: [joinsUp] and [joinsDown] leave the ring open where two selected rows meet (the
///   list also leaves out the divider there). The ring, not the fill, is the signal.
/// - Not selected: hover fills the row with `surface-hover`. A selected row keeps its `accent-soft` under
///   the pointer.
/// - [focused]: the 2px `focus` ring inside the selection ring, with a 2px gap, so both show.
/// - The fill and the ring change over `fast`; with reduced motion too (it is a fade, not a movement).
class MultiSelectRowFrame extends StatelessWidget {
  const MultiSelectRowFrame({
    super.key,
    required this.selected,
    required this.child,
    this.joinsUp = false,
    this.joinsDown = false,
    this.focused = false,
    this.hovered = false,
    this.borderRadius = BorderRadius.zero,
  });

  final bool selected;
  final bool joinsUp;
  final bool joinsDown;
  final bool focused;
  final bool hovered;

  /// The row's shape within its group (rounded at the group's ends).
  final BorderRadius borderRadius;
  final Widget child;

  /// Spec: "a 2px `ink` ring".
  static const ringWidth = 2.0;

  /// Preview: the focus ring's `outline-offset:-6px`: 2px wide, from 4px to 6px inside the row.
  static const focusInset = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = BorderRadius.only(
      topLeft: joinsUp ? Radius.zero : borderRadius.topLeft,
      topRight: joinsUp ? Radius.zero : borderRadius.topRight,
      bottomLeft: joinsDown ? Radius.zero : borderRadius.bottomLeft,
      bottomRight: joinsDown ? Radius.zero : borderRadius.bottomRight,
    );
    return CustomPaint(
      foregroundPainter: focused
          ? InsetRingPainter(color: FocusRing.colourFor(context), borderRadius: shape, inset: focusInset)
          : null,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? c.ink : c.ink.withValues(alpha: 0)),
        duration: context.motion.fast,
        curve: context.motion.standard,
        builder: (context, ring, child) => CustomPaint(
          foregroundPainter: InsetRingPainter(
              color: ring!, borderRadius: shape, width: ringWidth, top: !joinsUp, bottom: !joinsDown),
          child: child,
        ),
        child: AnimatedContainer(
          duration: context.motion.fast,
          curve: context.motion.standard,
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : (hovered ? c.surfaceHover : c.surfaceHover.withValues(alpha: 0)),
            borderRadius: shape,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A list of records the user can select several of (design/components/MultiSelect), on one `surface`
/// group: each row `row-height` at least, padded `space-4` by `space-2`, `line` dividers between them except
/// inside a run of selected rows.
///
/// - **From 600px:** a click selects that one row and calls [onOpen]; ⌘-click (Ctrl-click on Windows and
///   Linux) adds or removes it; ⇧-click selects the range from the anchor. A Control-click on macOS is the
///   context-menu gesture and changes nothing here. The list is one Tab stop with the keys of
///   [MultiSelectController.handleKey]; a press focuses it without the ring, which shows once a key moves.
/// - **Select mode** ([selectMode], phones): each row shows a [CheckboxBox] at its start, centred in an
///   `icon-tile` square, sliding in from the start edge over `base` (a `fast` fade with reduced motion); a
///   tap toggles the row and opens nothing; rows read as checkboxes. The box alone shows the selection:
///   rows take no fill or ring, as in the preview.
/// - **Screen readers:** each row reads its [semanticLabelOf] and "selected"; the row the keys are on is
///   the focused one while the list has focus, so screen readers follow the arrows; the count is announced
///   politely ([countLabel], "3 contacts selected") whenever it changes.
class MultiSelectList<K> extends StatefulWidget {
  const MultiSelectList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.semanticLabelOf,
    required this.countLabel,
    this.label,
    this.onOpen,
    this.selectMode = false,
    this.focusNode,
  });

  final MultiSelectController<K> controller;

  /// The row's content (avatar, name, caption), without its padding.
  final Widget Function(BuildContext context, K key) itemBuilder;

  /// The row's accessible name: its name and caption ("Ava Fictional, ava@example.org").
  final String Function(K key) semanticLabelOf;

  /// "3 contacts selected" (from 600px), "3 selected" on a phone.
  final String Function(int count) countLabel;

  /// The list's accessible name ("Contacts").
  final String? label;

  /// Called when a plain click (or a plain arrow key) selects one row, which the detail pane then shows.
  final ValueChanged<K>? onOpen;

  /// Phones: the checkboxes show and a tap toggles.
  final bool selectMode;
  final FocusNode? focusNode;

  /// Between the checkbox slot and the row's content.
  static double slotGap(MyDataLook look) => look.space(3);

  @override
  State<MultiSelectList<K>> createState() => _MultiSelectListState<K>();
}

class _MultiSelectListState<K> extends State<MultiSelectList<K>> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'MultiSelectList'));

  bool _keyboard = false;
  K? _hovered;
  /// The count last announced.
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _count = widget.controller.count;
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(MultiSelectList<K> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _count = widget.controller.count;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final n = widget.controller.count;
    if (n != _count) {
      _count = n;
      SemanticsService.sendAnnouncement(View.of(context), widget.countLabel(n), Directionality.of(context));
    }
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final ctrl = widget.controller;
    final before = ctrl.selected;
    final result = ctrl.handleKey(event);
    if (result == KeyEventResult.handled) {
      setState(() => _keyboard = true);
      final after = ctrl.selected;
      if (after.length == 1 && (before.length != 1 || before.first != after.first) && !widget.selectMode) {
        widget.onOpen?.call(after.first);
      }
    }
    return result;
  }

  void _press(K key) {
    final ctrl = widget.controller;
    if (!_focus.hasFocus) _focus.requestFocus();
    setState(() => _keyboard = false);
    if (widget.selectMode) {
      ctrl.toggle(key);
      return;
    }
    final k = HardwareKeyboard.instance;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    if (apple && k.isControlPressed && !k.isMetaPressed) return; // The context-menu gesture.
    if (k.isShiftPressed) {
      ctrl.extendTo(key);
    } else if (MultiSelectController.commandPressed(k)) {
      ctrl.toggle(key);
    } else {
      ctrl.select(key);
      widget.onOpen?.call(key);
    }
  }

  /// The list's focus node with the keys, around [rows] (the list's accessible container).
  Widget _focusable(Widget rows) => Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.label,
        child: Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          onFocusChange: (v) => setState(() {
            if (v && FocusManager.instance.highlightMode == FocusHighlightMode.traditional && !_keyboard) {
              _keyboard = true;
            }
            if (!v) _keyboard = false;
          }),
          child: rows,
        ),
      );

  /// One row's semantics and pointer handling around its drawing.
  Widget _rowShell(K key, bool selected, Widget drawn, {MouseCursor cursor = SystemMouseCursors.click}) =>
      Semantics(
        selected: widget.selectMode ? null : selected,
        checked: widget.selectMode ? selected : null,
        // The list is one focus node with a cursor: the row the keys are on is the focused one.
        focusable: true,
        focused: _focus.hasFocus && widget.controller.focused == key,
        label: widget.semanticLabelOf(key),
        onTap: () => _press(key),
        child: ExcludeSemantics(
          child: MouseRegion(
            cursor: cursor,
            onEnter: (_) => setState(() => _hovered = key),
            onExit: (_) => setState(() => _hovered = _hovered == key ? null : _hovered),
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _press(key), child: drawn),
          ),
        ),
      );

  /// The System look's list in the Mac window ([MacSystemLook.isSystemLook]): no card and no dividers; rows
  /// `row-inset` from the sides, at least
  /// `row-height` tall; the selection a `selection` rounded fill (a run of rows joins into one block), the
  /// accent while the list has focus in the active window, with its rows' content told so through
  /// [MacRowEmphasis], and `selection-inactive` otherwise; the keyboard's row, when not selected, gets a
  /// 2pt accent ring. Phones never get here, so there is no select mode.
  Widget _mac(BuildContext context) {
    final mac = context.mac;
    final ctrl = widget.controller;
    final active = _focus.hasFocus && MacChrome.of(context).windowActive;
    final showFocus = _keyboard && _focus.hasFocus;
    const corner = Radius.circular(MyDataMacRadius.selection);
    return _focusable(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in ctrl.rows)
          () {
            final selected = ctrl.isSelected(key);
            final joins = selected ? ctrl.joins(key) : (up: false, down: false);
            final emphasised = selected && active;
            return _rowShell(
              key,
              selected,
              cursor: SystemMouseCursors.basic,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset),
                child: Container(
                  constraints: const BoxConstraints(minHeight: MyDataMacSize.rowHeight),
                  padding: EdgeInsets.symmetric(horizontal: MyDataMacSize.rowPadding, vertical: context.space(1)),
                  alignment: AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: selected ? (active ? mac.accent : mac.selectionInactive) : null,
                    borderRadius: BorderRadius.vertical(
                      top: joins.up ? Radius.zero : corner,
                      bottom: joins.down ? Radius.zero : corner,
                    ),
                    border: showFocus && ctrl.focused == key && !selected
                        ? Border.all(color: mac.focusRing, width: MultiSelectRowFrame.ringWidth)
                        : null,
                  ),
                  child: MacRowEmphasis(emphasised: emphasised, child: widget.itemBuilder(context, key)),
                ),
              ),
            );
          }(),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (context.isSystemLook) return _mac(context);
    final c = context.colors;
    final ctrl = widget.controller;
    final rows = ctrl.rows;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final showFocus = _keyboard && _focus.hasFocus;
    final outer = BorderRadius.all(Radius.circular(context.radius.lg));
    BorderRadius shapeOf(int i) => BorderRadius.only(
          topLeft: i == 0 ? outer.topLeft : Radius.zero,
          topRight: i == 0 ? outer.topRight : Radius.zero,
          bottomLeft: i == rows.length - 1 ? outer.bottomLeft : Radius.zero,
          bottomRight: i == rows.length - 1 ? outer.bottomRight : Radius.zero,
        );

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final key = rows[i];
      final selected = ctrl.isSelected(key);
      // In select mode the box carries the selection; the rows take no fill or ring (the preview's phone).
      final marked = selected && !widget.selectMode;
      final joins = marked ? ctrl.joins(key) : (up: false, down: false);
      if (i > 0) {
        // No divider inside a run of selected rows: the run's fill and its ring's sides go on through.
        children.add(joins.up
            ? Container(
                height: 1,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  border: Border.symmetric(
                      vertical: BorderSide(color: c.ink, width: MultiSelectRowFrame.ringWidth)),
                ),
              )
            : Container(height: 1, color: c.line));
      }
      final slot = AnimatedContainer(
        duration: reduced ? Duration.zero : context.motion.base,
        curve: context.motion.standard,
        width: widget.selectMode ? context.density.iconTile + MultiSelectList.slotGap(context.look) : 0,
        height: context.density.iconTile,
        child: ClipRect(
          child: AnimatedOpacity(
            duration: reduced ? context.motion.fast : context.motion.base,
            opacity: widget.selectMode ? 1 : 0,
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: context.density.iconTile + MultiSelectList.slotGap(context.look),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox.square(
                    dimension: context.density.iconTile, child: Center(child: CheckboxBox(value: selected))),
                SizedBox(width: MultiSelectList.slotGap(context.look)),
              ]),
            ),
          ),
        ),
      );
      children.add(_rowShell(
        key,
        selected,
        MultiSelectRowFrame(
          selected: marked,
          joinsUp: joins.up,
          joinsDown: joins.down,
          focused: showFocus && ctrl.focused == key,
          hovered: _hovered == key,
          borderRadius: shapeOf(i),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.density.rowHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(2)),
              child: Row(children: [slot, Expanded(child: widget.itemBuilder(context, key))]),
            ),
          ),
        ),
      ));
    }

    return _focusable(DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ));
  }
}

/// What the detail pane shows while two or more rows are selected (design/components/MultiSelect, "The
/// count and the actions"):
///
/// - the [title] (the count, "3 contacts selected") in `display-lg`;
/// - under it, `space-2` below, the [names] in `body` and `ink-muted` ([summariseNames]);
/// - optionally the [leftOut] sentence in `caption` and full `ink-muted`, `space-2` below ("1 of them is
///   from this Mac and is changed in Contacts.");
/// - then the [actions], as Buttons `space-2` apart, `space-6` below: Tonal "Add to group…" and Plain
///   danger "Delete 3 contacts".
class MultiSelectSummary extends StatelessWidget {
  const MultiSelectSummary({super.key, required this.title, required this.names, this.leftOut, this.actions = const []});

  final String title;
  final String names;
  final String? leftOut;
  final List<Widget> actions;

  /// Preview: `.pane .acts{margin-top:24px}`.
  static double actionsGap(MyDataLook look) => look.space(6);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
            header: true,
            liveRegion: true,
            child: Text(title, style: context.type(MyDataTypeRole.displayLg).copyWith(color: c.ink))),
        SizedBox(height: context.space(2)),
        Text(names, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
        if (leftOut != null) ...[
          SizedBox(height: context.space(2)),
          Text(leftOut!, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
        ],
        if (actions.isNotEmpty) ...[
          SizedBox(height: actionsGap(context.look)),
          ButtonRow(children: actions),
        ],
      ],
    );
  }
}
