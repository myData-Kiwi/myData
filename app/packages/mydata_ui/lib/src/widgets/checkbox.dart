import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'app_frame.dart' show PhoneType;
import 'form_scope.dart';
import 'group_frame.dart';
import 'pressable.dart';
import 'toggle_target.dart';

/// The drawn box of a checkbox (design/components/Checkbox), with no behaviour of its own: for a row that is
/// itself the target ([MyDataCheckbox], [CheckboxList], a MultiSelect row in select mode). It excludes itself
/// from semantics: what holds it announces the state.
///
/// - `icon` (20px) across, a rounded square with `radius-xs` corners, everywhere.
/// - [value] false: `surface` with a 1px `line-strong` edge (`surface-hover` while [hovered]); true: `accent`
///   with a check mark in `on-accent`; null (mixed, only on a select-all box): `accent` with a short dash.
/// - The mark, not the fill, carries the state, so Graphite (whose `accent` is close to `ink`) and a reader
///   who cannot see the colour lose nothing.
/// - The fill and the mark fade over `fast` with the `standard` curve; nothing moves.
class CheckboxBox extends StatelessWidget {
  const CheckboxBox({super.key, required this.value, this.hovered = false});

  /// Checked (true), unchecked (false) or mixed (null).
  final bool? value;

  /// The pointer is over the target: an unchecked box fills with `surface-hover`; a checked one does not
  /// change.
  final bool hovered;

  /// Spec: "`icon` (20px) across".
  static const size = MyDataSize.icon;

  /// Spec: "a 1px `line-strong` edge".
  static const edgeWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = value != false;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: MyDataMotion.fast,
        curve: MyDataMotion.standard,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: on ? c.accent : (hovered ? c.surfaceHover : c.surface),
          borderRadius: MyDataRadii.xs,
          border: Border.all(color: on ? c.accent : c.lineStrong, width: edgeWidth),
        ),
        child: AnimatedOpacity(
          duration: MyDataMotion.fast,
          curve: MyDataMotion.standard,
          opacity: on ? 1 : 0,
          child: CustomPaint(painter: _MarkPainter(mixed: value == null, color: c.onAccent)),
        ),
      ),
    );
  }
}

/// The check mark or the dash, from the preview's 24-unit icons (`M6.5 12.5l3.5 3.5 7.5-8` and
/// `M7.5 12h9`), with a 1.75 rounded stroke, drawn over the whole 20px box as the preview's svg is.
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.mixed, required this.color});
  final bool mixed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The painter gets the box less its 1px edge; the mark is laid out on the whole box.
    final s = (size.width + 2 * CheckboxBox.edgeWidth) / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = mixed
        ? (Path()
          ..moveTo(7.5 * s, 12 * s)
          ..lineTo(16.5 * s, 12 * s))
        : (Path()
          ..moveTo(6.5 * s, 12.5 * s)
          ..lineTo(10 * s, 16 * s)
          ..lineTo(17.5 * s, 8 * s));
    canvas.translate(-CheckboxBox.edgeWidth, -CheckboxBox.edgeWidth);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mixed != mixed || old.color != color;
}

/// A checkbox on its own, at the start of its label (design/components/Checkbox): an option that goes with
/// an action ("Also remove the 3 contacts you changed after the import").
///
/// - The [CheckboxBox] sits `space-3` before the [label] (`body`, `ink`), centred on its first line, with an
///   optional [caption] under it in `caption` and `ink-muted` that names exactly what it covers.
/// - The box and its label are one target, at least `control-height` tall; a click anywhere on either
///   toggles it. Stack several `space-2` apart ([CheckboxStack]), never side by side.
/// - Hover fills an unchecked box with `surface-hover`; a press dims the target to 85% at once and it
///   returns over `fast`, without shrinking. Keyboard focus draws the 2px `focus` ring 2px outside the box,
///   following its shape.
/// - **Space** toggles it; Return is left to the dialog's or form's main button.
/// - [onChanged] null disables it: the box and the label at 45%, not focusable (the reason is visible),
///   announced as disabled. The [disabledReason] shows in the caption line, in full `ink-muted`, not faded.
///   It keeps its state, so the user can see what will happen.
/// - There is no error state: an empty selection disables the action that uses it, with the reason.
/// - Screen readers: "Ava Fictional, ava@example.org, checkbox, checked".
/// - The label says what checking it does, in the positive. The safer choice is unchecked by default.
class MyDataCheckbox extends StatelessWidget {
  const MyDataCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
    this.disabledReason,
    this.focusNode,
    this.autofocus = false,
  }) : assert(onChanged != null || disabledReason != null, 'a disabled checkbox says why (platforms.md)');

  /// Sentence case, no full stop.
  final String label;

  /// Whether it is checked.
  final bool value;

  /// Called with the new value. Null disables it; give the [disabledReason] then.
  final ValueChanged<bool>? onChanged;

  /// One optional line under the label naming what it covers ("Ava Fictional, Ben Sample and Chloe
  /// Example").
  final String? caption;

  /// Why it is disabled, a full sentence with a full stop. Shown in the caption line while disabled.
  final String? disabledReason;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Spec: the box sits `space-3` from its label.
  static const gap = MyDataSpace.s3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final note = enabled ? caption : (disabledReason ?? caption);
    final labelStyle = PhoneType.bodyOf(context).copyWith(color: c.ink);
    final line = labelStyle.fontSize! * labelStyle.height!;
    // The target is at least `control-height`: the label's line centred in it (the preview's 11px padding).
    final vertical = math.max(0.0, (MyDataSize.controlHeight - line) / 2);
    return MergeSemantics(
      child: Semantics(
        checked: value,
        enabled: enabled,
        child: ToggleTarget(
          onToggle: enabled ? () => onChanged!(!value) : null,
          focusNode: focusNode,
          autofocus: autofocus,
          builder: (context, s) {
            Widget faded(Widget w) => enabled ? w : Opacity(opacity: Pressable.disabledOpacity, child: w);
            return AnimatedOpacity(
              opacity: s.pressed ? MyDataMotion.pressOpacity : 1,
              duration: s.pressed ? Duration.zero : MyDataMotion.fast,
              curve: MyDataMotion.standard,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: vertical),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: (line - CheckboxBox.size) / 2),
                      child: faded(FocusRing(
                        visible: s.focused,
                        borderRadius: MyDataRadii.xs,
                        child: CheckboxBox(value: value, hovered: s.hovered),
                      )),
                    ),
                    const SizedBox(width: gap),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          faded(Text(label, style: labelStyle)),
                          if (note != null) Text(note, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Several [MyDataCheckbox]es, one under the other, `space-2` apart (never side by side).
class CheckboxStack extends StatelessWidget {
  const CheckboxStack({super.key, required this.children});
  final List<Widget> children;

  /// Spec: "several options stack `space-2` apart".
  static const gap = MyDataSpace.s2;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: gap), children[i]],
        ],
      );
}

/// One item of a [CheckboxList].
@immutable
class CheckboxListItem {
  const CheckboxListItem({
    required this.title,
    this.caption,
    required this.checked,
    this.disabledReason,
    this.trailing,
    this.below,
  });

  /// The item's name ("Ava Fictional").
  final String title;

  /// What tells it apart ("ava@example.org"). Replaced by [disabledReason] while that is set.
  final String? caption;

  final bool checked;

  /// Non-null disables the item, with this reason as its caption line ("This Mac’s contacts cannot be
  /// removed here.").
  final String? disabledReason;

  bool get enabled => disabledReason == null;

  /// A control beside the row's target, at its end ("Compare", plain): a second target side by side with
  /// the checkbox, never inside it, so a screen reader reaches both. Only the row the keys are on has it in
  /// the Tab order, after the list.
  final Widget? trailing;

  /// Shown under the row while given (the import's comparison, opened by [trailing]).
  final Widget? below;
}

/// Items picked from a list, each with a checkbox (design/components/Checkbox, "In a list" and "Select
/// all"): the import review, a list of address books.
///
/// - A GroupedList group under its [heading]: each item a row with its [CheckboxBox] centred in an
///   `icon-tile` square at the start, the title in `body-strong` and the caption in `caption` and
///   `ink-muted`. The row is the target. A checked row has no fill.
/// - **Select all** ([selectAllTitle]) is the first row, above a divider: the box, the title in
///   `body-strong` ("All 12 contacts") and a caption that counts ([countLabel]: "9 of 12 selected"). Its box
///   is checked when every item is, unchecked when none is, and mixed otherwise. Pressing it when mixed or
///   unchecked checks every item; pressing it when checked clears every item. It is a Tab stop of its own.
/// - Hover fills a row with `surface-hover`; a press dims it to 85%. Keyboard focus draws the 2px `focus`
///   ring inside the row.
/// - **Keyboard:** the list is one Tab stop. Up and Down move between rows, Home and End jump to the first
///   and last, Space toggles the focused row, ⌘A (Control+A elsewhere) checks every row. ⇧-Space, or
///   ⇧-click, sets every row from the last one changed to this one to this one's new state.
/// - A disabled item is at 45% (its box and title), with its reason in full `ink-muted`; the keys pass over
///   it and select all leaves it as it is.
/// - Screen readers: the list is a group named by its heading; each row a checkbox ("Ava Fictional,
///   ava@example.org, checkbox, checked"); after a change the new count is announced politely.
///
/// [onChanged] gets every item's new state, in order.
class CheckboxList extends StatefulWidget {
  const CheckboxList({
    super.key,
    required this.heading,
    required this.items,
    required this.onChanged,
    this.selectAllTitle,
    this.countLabel = defaultCountLabel,
    this.focusNode,
    this.folded = false,
    this.shown,
  });

  /// The group's heading, which also names it for screen readers ("Contacts in the file").
  final String heading;
  final List<CheckboxListItem> items;
  final ValueChanged<List<bool>> onChanged;

  /// The select-all row's title ("All 12 contacts"); null for no select-all row.
  final String? selectAllTitle;

  /// The count under select all and in the announcement: "9 of 12 selected".
  final String Function(int checked, int total) countLabel;

  /// The list's one focus node (the select-all row has its own).
  final FocusNode? focusNode;

  /// Folded: the rows are not drawn, but select all shows and acts on every item, so a long list ("New
  /// contacts (125)") can be unticked at once. The holder puts its disclosure ("Show all 125") under it.
  final bool folded;

  /// Draws only the first [shown] rows (null: every row), so a list of thousands builds a page at a time; the
  /// holder puts its "Show 200 more" under it. As when [folded], select all and ⌘A act on every item, and the
  /// keys move among the rows drawn.
  final int? shown;

  static String defaultCountLabel(int checked, int total) => '$checked of $total selected';

  @override
  State<CheckboxList> createState() => _CheckboxListState();
}

class _CheckboxListState extends State<CheckboxList> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'CheckboxList'));

  int _cursor = 0;
  int? _lastChanged;
  bool _focusVisible = false;

  /// How many rows are drawn.
  int get _drawn => math.min(widget.items.length, math.max(0, widget.shown ?? widget.items.length));

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  List<bool> get _values => [for (final i in widget.items) i.checked];
  int get _checked => widget.items.where((i) => i.checked).length;

  void _emit(List<bool> next) {
    widget.onChanged(next);
    final count = next.where((v) => v).length;
    SemanticsService.sendAnnouncement(
        View.of(context), widget.countLabel(count, next.length), Directionality.of(context));
  }

  /// Toggles [index]; with [range], sets every row from the last one changed to [index] to [index]'s new
  /// state.
  void _toggle(int index, {bool range = false}) {
    final item = widget.items[index];
    if (!item.enabled || FormBusy.read(context)) return;
    final next = _values;
    final to = !item.checked;
    if (range && _lastChanged != null) {
      final a = math.min(_lastChanged!, index), b = math.max(_lastChanged!, index);
      for (var i = a; i <= b; i++) {
        if (widget.items[i].enabled) next[i] = to;
      }
    } else {
      next[index] = to;
    }
    _lastChanged = index;
    _emit(next);
  }

  /// Select all: checks every enabled item unless every one is checked already, which clears them.
  void _all({bool? to}) {
    if (FormBusy.read(context)) return;
    final enabled = [for (final i in widget.items) if (i.enabled) i];
    final target = to ?? !enabled.every((i) => i.checked);
    _emit([for (final i in widget.items) i.enabled ? target : i.checked]);
  }

  int? _step(int from, int direction) {
    for (var i = from + direction; i >= 0 && i < _drawn; i += direction) {
      if (widget.items[i].enabled) return i;
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (widget.items.isEmpty) return KeyEventResult.ignored;
    final k = HardwareKeyboard.instance;
    final key = event.logicalKey;
    int? to;
    if (key == LogicalKeyboardKey.arrowDown) {
      to = _step(_cursor, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = _step(_cursor, -1);
    } else if (key == LogicalKeyboardKey.home) {
      to = _step(-1, 1);
    } else if (key == LogicalKeyboardKey.end) {
      to = _step(_drawn, -1);
    } else if (key == LogicalKeyboardKey.space) {
      _toggle(_cursor, range: k.isShiftPressed);
      setState(() => _focusVisible = true);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyA && _command(k)) {
      _all(to: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end) {
      setState(() {
        if (to != null) _cursor = to;
        _focusVisible = true;
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// ⌘ on Apple platforms, Control elsewhere (on macOS Control is the context-menu modifier).
  static bool _command(HardwareKeyboard k) => switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => k.isMetaPressed && !k.isControlPressed,
        _ => k.isControlPressed && !k.isMetaPressed,
      };

  void _press(int index) {
    if (!widget.items[index].enabled) return;
    setState(() {
      _cursor = index;
      _focusVisible = false;
    });
    if (!_focus.hasFocus) _focus.requestFocus();
    _toggle(index, range: HardwareKeyboard.instance.isShiftPressed);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final drawn = _drawn;
    if (_cursor >= drawn || (drawn > 0 && !items[_cursor].enabled)) {
      _cursor = _step(-1, 1) ?? 0;
    }
    final checked = _checked;
    // The rows are one part of the group, inside the list's one focus node; select all is a part (and a
    // Tab stop) of its own before it.
    final rows = Builder(builder: (context) {
      final part = GroupPartShape.of(context);
      final c = context.colors;
      BorderRadius shapeOf(int i) => BorderRadius.only(
            topLeft: i == 0 ? part.topLeft : Radius.zero,
            topRight: i == 0 ? part.topRight : Radius.zero,
            bottomLeft: i == drawn - 1 ? part.bottomLeft : Radius.zero,
            bottomRight: i == drawn - 1 ? part.bottomRight : Radius.zero,
          );
      return Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        onFocusChange: (v) => setState(() {
          if (v && FocusManager.instance.highlightMode == FocusHighlightMode.traditional) _focusVisible = true;
          if (!v) _focusVisible = false;
        }),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < drawn; i++) ...[
              if (i > 0) Container(height: GroupFrame.dividerWidth, color: c.line),
              GroupPartShape(
                borderRadius: shapeOf(i),
                child: _CheckboxListRow(
                  item: items[i],
                  focused: _focus.hasFocus && _focusVisible && i == _cursor,
                  // The list is one focus node; screen readers follow the row the keys are on.
                  semanticsFocused: _focus.hasFocus && i == _cursor,
                  onTap: () => _press(i),
                  current: i == _cursor,
                ),
              ),
            ],
          ],
        ),
      );
    });
    final parts = <Widget>[
      if (widget.selectAllTitle != null)
        _SelectAllRow(
          title: widget.selectAllTitle!,
          caption: widget.countLabel(checked, items.length),
          value: checked == 0 ? false : (checked == items.length ? true : null),
          onToggle: items.any((i) => i.enabled) ? () => _all() : null,
        ),
      if (drawn > 0 && !widget.folded) rows,
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.heading,
      child: GroupFrame(heading: widget.heading, parts: parts),
    );
  }
}

/// The select-all row: its own Tab stop, with a mixed state.
class _SelectAllRow extends StatelessWidget {
  const _SelectAllRow({required this.title, required this.caption, required this.value, required this.onToggle});
  final String title;
  final String caption;
  final bool? value;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = GroupPartShape.of(context);
    return MergeSemantics(
      child: Semantics(
        checked: value ?? false,
        mixed: value == null,
        enabled: onToggle != null,
        child: ToggleTarget(
          onToggle: onToggle,
          builder: (context, s) => _RowShell(
            shape: shape,
            hovered: s.hovered,
            pressed: s.pressed,
            focused: s.focused,
            enabled: onToggle != null,
            box: CheckboxBox(value: value),
            title: Text(title, style: PhoneType.bodyOf(context, MyDataType.bodyStrong).copyWith(color: c.ink)),
            caption: Text(caption, style: MyDataType.caption.copyWith(color: c.inkMuted)),
          ),
        ),
      ),
    );
  }
}

/// One row of a [CheckboxList]. Its hover and press are its own, so moving the mouse over a long list
/// rebuilds one row, not the list.
class _CheckboxListRow extends StatefulWidget {
  const _CheckboxListRow({
    required this.item,
    required this.focused,
    required this.semanticsFocused,
    required this.onTap,
    this.current = false,
  });
  final CheckboxListItem item;

  /// The keys are on this row: its [CheckboxListItem.trailing] is in the Tab order.
  final bool current;
  final bool focused;

  /// The keys are on this row while the list has focus (with or without the ring).
  final bool semanticsFocused;
  final VoidCallback onTap;

  @override
  State<_CheckboxListRow> createState() => _CheckboxListRowState();
}

class _CheckboxListRowState extends State<_CheckboxListRow> {
  bool _hovered = false;
  bool _pressed = false;

  void _hover(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  void _press(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = widget.item;
    final focused = widget.focused;
    final semanticsFocused = widget.semanticsFocused;
    final onTap = widget.onTap;
    final current = widget.current;
    final hovered = _hovered;
    final pressed = _pressed;
    final enabled = item.enabled;
    final note = item.disabledReason ?? item.caption;
    final target = MergeSemantics(
      child: Semantics(
        checked: item.checked,
        enabled: enabled,
        focusable: true,
        focused: semanticsFocused,
        onTap: enabled ? onTap : null,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: enabled ? (_) => _hover(true) : null,
          onExit: enabled ? (_) => _hover(false) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled ? (_) => _press(true) : null,
            onTapUp: enabled ? (_) => _press(false) : null,
            onTapCancel: enabled ? () => _press(false) : null,
            onTap: enabled ? onTap : null,
            child: _RowShell(
              shape: GroupPartShape.of(context),
              hovered: hovered && enabled,
              pressed: pressed && enabled,
              focused: focused,
              enabled: enabled,
              box: CheckboxBox(value: item.checked),
              title: Text(item.title, style: PhoneType.bodyOf(context, MyDataType.bodyStrong).copyWith(color: c.ink)),
              caption: note == null ? null : Text(note, style: MyDataType.caption.copyWith(color: c.inkMuted)),
            ),
          ),
        ),
      ),
    );
    final trailing = item.trailing;
    final below = item.below;
    if (trailing == null && below == null) return target;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: target),
        if (trailing != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: MyDataSpace.s2),
            child: ExcludeFocusTraversal(excluding: !current, child: trailing),
          ),
      ]),
      ?below,
    ]);
  }
}

/// A GroupedList row with a box in an `icon-tile` slot: hover fill, press dim, the inside focus ring.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.shape,
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.enabled,
    required this.box,
    required this.title,
    this.caption,
  });
  final BorderRadius shape;
  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool enabled;
  final Widget box;
  final Widget title;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget faded(Widget w) => enabled ? w : Opacity(opacity: Pressable.disabledOpacity, child: w);
    return CustomPaint(
      foregroundPainter: focused ? InsetRingPainter(color: FocusRing.colourOf(c), borderRadius: shape) : null,
      child: AnimatedContainer(
        duration: MyDataMotion.fast,
        curve: MyDataMotion.standard,
        decoration: BoxDecoration(
            color: hovered || pressed ? c.surfaceHover : c.surfaceHover.withValues(alpha: 0), borderRadius: shape),
        child: AnimatedOpacity(
          opacity: pressed ? MyDataMotion.pressOpacity : 1,
          duration: pressed ? Duration.zero : MyDataMotion.fast,
          curve: MyDataMotion.standard,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s4, vertical: MyDataSpace.s2),
              child: Row(children: [
                faded(SizedBox.square(dimension: MyDataSize.iconTile, child: Center(child: box))),
                const SizedBox(width: MyDataSpace.s3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [faded(title), ?caption],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
