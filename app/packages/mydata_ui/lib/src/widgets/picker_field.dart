import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole, SemanticsValidationResult;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'app_frame.dart' show AppLayout, PhoneType;
import 'pressable.dart';

// The parts [DatePicker] and [TimePicker] share (design/components/DatePicker and TimePicker): the field
// that looks like a TextField with an icon at its end, the popover anchored under it, and the list box with
// Select's rows. Not exported from the package: the pickers are the public API.

/// Whether the window is phone-sized ([AppLayout.isPhone]): a picker is then not typed, and tapping it opens
/// a picker sheet (the specs' "Phone (under 600px)").
bool pickerIsPhone(BuildContext context) => AppLayout.isPhone(context);

/// The field's height: `control-height`, or `control-height-compact` in the Compact density on desktop.
double pickerControlHeight({required bool compact, required bool phone}) =>
    compact && !phone ? MyDataSize.controlHeightCompact : MyDataSize.controlHeight;

/// The value's style: `body` in `ink`, at 16px on phones.
TextStyle pickerValueStyle(MyDataColors c, {required bool phone}) =>
    PhoneType.body(MyDataType.body, phone: phone).copyWith(color: c.ink);

/// The width of a picker's field: as wide as the longest of [samples] in [style] at the current text size,
/// plus the field's padding, the gap and the icon. Not the width of the form (the specs: "it is as wide as
/// the longest date in the locale" / "the longest time in the locale").
double pickerFieldWidth(BuildContext context, Iterable<String> samples, TextStyle style) {
  final scaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1);
  var widest = 0.0;
  for (final s in samples) {
    painter.text = TextSpan(text: s, style: style);
    painter.layout();
    widest = math.max(widest, painter.width);
  }
  painter.dispose();
  // The text, the gap and the icon, `space-4` either side, and `space-1` for the caret, which a text field
  // keeps room for after the text (without it the longest value scrolls by a few pixels).
  return (widest + MyDataSpace.s2 + scaler.scale(MyDataSize.icon) + 2 * MyDataSpace.s4 + MyDataSpace.s1)
      .ceilToDouble();
}

/// The field of a picker: a TextField's box (`surface`, 1px `line-strong` border, `radius-md`,
/// `control-height`, `space-4` across) holding the value in `body` and, at the end, [icon] at `icon` size in
/// `ink-muted`, `space-2` from the value. The icon is decoration. The label sits above in `label` and `ink`,
/// `space-2` above; [help] `space-2` below in `caption` and `ink-muted`.
///
/// - [error]: a 2px `danger` border, and the error in `danger` in place of the help. The focus ring is then
///   `ink` (design/README.md "Focus and danger").
/// - [disabledReason]: the label and the box at 45% opacity, not focusable, announced as disabled; the
///   reason is the help line and is not faded (design/platforms.md "Disabled controls").
/// - [phone]: not typed. The box is one button that opens the picker sheet ([onTap]).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.boxKey,
    required this.controller,
    required this.focusNode,
    required this.icon,
    required this.fieldWidth,
    required this.semanticLabel,
    this.label,
    this.help,
    this.error,
    this.disabledReason,
    this.compact = false,
    this.phone = false,
    this.readOnly = false,
    this.showRing = false,
    this.semanticsValue,
    this.semanticsHint,
    this.onKeyEvent,
    this.onTap,
    this.onPointerDown,
    this.onChanged,
    this.onEditingComplete,
    this.keyboardType,
  });

  /// On the box itself, so a popover anchors to it and not to the label above it.
  final GlobalKey boxKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final double fieldWidth;

  /// The accessible name: the label, or what the field holds when two fields share one label ("Start date").
  final String semanticLabel;

  /// The visible label above the field. Null when a label above a row of fields covers it ("Starts").
  final String? label;
  final String? help;
  final String? error;
  final String? disabledReason;
  final bool compact;
  final bool phone;

  /// The form waits for the host (FormBusy): focus stays, typing does nothing.
  final bool readOnly;

  /// Draws the keyboard focus ring (focus came from the keyboard, or the popover holds it).
  final bool showRing;

  /// What a screen reader reads as the value ("Wednesday 14 October 2026").
  final String? semanticsValue;
  final String? semanticsHint;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onTap;
  final VoidCallback? onPointerDown;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputType? keyboardType;

  /// Spec: "1px `line-strong` border".
  static const borderWidth = 1.0;

  /// Spec: "a 2px `danger` border".
  static const errorBorderWidth = 2.0;

  bool get _disabled => disabledReason != null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = error != null && !_disabled;
    final note = _disabled ? disabledReason : (error ?? help);
    final border = hasError ? errorBorderWidth : borderWidth;
    final style = pickerValueStyle(c, phone: phone);
    final height = pickerControlHeight(compact: compact, phone: phone);
    final lineHeight = style.fontSize! * style.height!;
    final vertical = math.max(0.0, (height - lineHeight) / 2 - border);

    final Widget text;
    if (phone) {
      text = Padding(
        padding: EdgeInsetsDirectional.only(start: MyDataSpace.s4 - border),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) =>
                Text(value.text, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: style),
          ),
        ),
      );
    } else {
      text = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: onKeyEvent,
        child: Listener(
          onPointerDown: onPointerDown == null ? null : (_) => onPointerDown!(),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !_disabled,
            readOnly: readOnly,
            maxLines: 1,
            style: style,
            cursorColor: c.accent,
            keyboardType: keyboardType,
            textAlignVertical: TextAlignVertical.center,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            onTap: onTap,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsetsDirectional.fromSTEB(MyDataSpace.s4 - border, vertical, 0, vertical),
            ),
          ),
        ),
      );
    }

    Widget box = Container(
      key: boxKey,
      width: fieldWidth,
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: MyDataRadii.md,
        border: Border.all(color: hasError ? c.danger : c.lineStrong, width: border),
      ),
      child: Row(children: [
        Expanded(child: text),
        const SizedBox(width: MyDataSpace.s2),
        ExcludeSemantics(child: Icon(icon, size: MyDataSize.icon, color: c.inkMuted)),
        SizedBox(width: MyDataSpace.s4 - border),
      ]),
    );

    final hint = [?error, ?semanticsHint].join('\n');
    if (phone) {
      box = Semantics(
        value: semanticsValue,
        validationResult: hasError ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
        child: Pressable(
          onPressed: _disabled ? null : onTap,
          focusNode: focusNode,
          borderRadius: MyDataRadii.md,
          scaleOnPress: false,
          danger: hasError,
          semanticLabel: semanticLabel,
          child: ExcludeSemantics(child: box),
        ),
      );
    } else {
      // Merged into the text field's own node, so the name, value and hint are the field's (an
      // OverlayPortal above would otherwise take them).
      box = MergeSemantics(
          child: Semantics(
        label: semanticLabel,
        value: semanticsValue,
        hint: _disabled ? disabledReason : (hint.isEmpty ? null : hint),
        validationResult: hasError ? SemanticsValidationResult.invalid : SemanticsValidationResult.none,
        child: FocusRing(visible: showRing && !_disabled, borderRadius: MyDataRadii.md, danger: hasError, child: box),
      ));
    }

    final faded = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          ExcludeSemantics(child: Text(label!, style: MyDataType.label.copyWith(color: c.ink))),
          const SizedBox(height: MyDataSpace.s2),
        ],
        box,
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _disabled ? Opacity(opacity: Pressable.disabledOpacity, child: faded) : faded,
        if (note != null) ...[
          const SizedBox(height: MyDataSpace.s2),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.max(fieldWidth, MyDataSize.dialogWidth / 2)),
            child: ExcludeSemantics(
              child: Text(note, style: MyDataType.caption.copyWith(color: hasError ? c.danger : c.inkMuted)),
            ),
          ),
        ],
      ],
    );
  }
}

/// A popover anchored to the box with [anchorKey]: under it, aligned to its start, `space-1` below it, or
/// above it when there is no room below. `surface-raised`, `shadow-2`, `radius-md`, with [padding] inside.
///
/// It fades in over `base` with the `standard` curve and out over `fast`; with reduced motion both are a
/// `fast` fade. A tap outside both the anchor and the popover calls [onDismiss].
class PickerPopover extends StatefulWidget {
  const PickerPopover({
    super.key,
    required this.open,
    required this.anchorKey,
    required this.popover,
    required this.child,
    required this.padding,
    this.onDismiss,
    this.semanticLabel,
  });

  final bool open;
  final GlobalKey anchorKey;
  final WidgetBuilder popover;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onDismiss;

  /// The popover is a dialog with this name ("Start date, choose a date"); null for a list box.
  final String? semanticLabel;

  /// Spec: "`space-1` below it".
  static const gap = MyDataSpace.s1;

  /// Kept between the popover and the window's edges (the 16px side gutter).
  static const margin = MyDataSpace.s4;

  @override
  State<PickerPopover> createState() => _PickerPopoverState();
}

class _PickerPopoverState extends State<PickerPopover> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final AnimationController _fade = AnimationController(vsync: this, duration: MyDataMotion.base);
  final Object _group = Object();

  @override
  void initState() {
    super.initState();
    if (widget.open) _fade.value = 1;
    // The overlay child stays in the overlay; it is empty while the popover is closed and faded out.
    // (OverlayPortalController.show may not be called during a build.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_portal.isShowing) _portal.show();
    });
  }

  @override
  void didUpdateWidget(PickerPopover old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    if (widget.open) {
      _fade.duration = MyDataMotion.reduced(context) ? MyDataMotion.fast : MyDataMotion.base;
      _fade.forward();
    } else {
      _fade.reverseDuration = MyDataMotion.fast;
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Widget _overlay(BuildContext context) => AnimatedBuilder(
      animation: _fade,
      builder: (context, _) =>
          !widget.open && _fade.isDismissed ? const SizedBox.shrink() : _popover(context));

  Widget _popover(BuildContext context) {
    final c = context.colors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget surface = Container(
      padding: widget.padding,
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: MyDataRadii.md, boxShadow: context.shadows.shadow2),
      child: Builder(builder: widget.popover),
    );
    if (widget.semanticLabel != null) {
      surface = Semantics(
          container: true,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          role: SemanticsRole.dialog,
          label: widget.semanticLabel,
          child: surface);
    }
    Widget popover = TapRegion(
      groupId: _group,
      child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: MyDataMotion.standard), child: surface),
    );
    // A popover opened from inside another (the birthday's Year list) is inside that one too, so a tap in
    // it does not close the outer popover.
    final outer = _PopoverGroup.of(this.context);
    if (outer != null) popover = TapRegion(groupId: outer, child: popover);
    popover = _PopoverGroup(group: _group, child: popover);
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, constraints) {
        final anchorBox = widget.anchorKey.currentContext?.findRenderObject() as RenderBox?;
        final overlayBox = context.findRenderObject() as RenderBox?;
        Rect anchor = Rect.zero;
        if (anchorBox != null && anchorBox.hasSize && overlayBox != null) {
          final origin = anchorBox.localToGlobal(Offset.zero);
          final overlayOrigin = overlayBox.localToGlobal(Offset.zero);
          anchor = (origin - overlayOrigin) & anchorBox.size;
        }
        return CustomSingleChildLayout(delegate: _PopoverLayout(anchor: anchor, rtl: rtl), child: popover);
      }),
    );
  }

  @override
  Widget build(BuildContext context) => TapRegion(
        groupId: _group,
        onTapOutside: widget.open && widget.onDismiss != null ? (_) => widget.onDismiss!() : null,
        child: OverlayPortal(controller: _portal, overlayChildBuilder: _overlay, child: widget.child),
      );
}

/// The tap group of the popover a widget is in.
class _PopoverGroup extends InheritedWidget {
  const _PopoverGroup({required this.group, required super.child});
  final Object group;

  static Object? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_PopoverGroup>()?.group;

  @override
  bool updateShouldNotify(_PopoverGroup old) => old.group != group;
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  _PopoverLayout({required this.anchor, required this.rtl});
  final Rect anchor;
  final bool rtl;

  static const _m = PickerPopover.margin;
  static const _g = PickerPopover.gap;

  double _below(Size size) => size.height - anchor.bottom - _g - _m;
  double _above() => anchor.top - _g - _m;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    return BoxConstraints(
      maxWidth: math.max(0, size.width - 2 * _m),
      maxHeight: math.max(0, math.max(_below(size), _above())),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = rtl ? anchor.right - child.width : anchor.left;
    x = x.clamp(_m, math.max(_m, size.width - _m - child.width));
    final fitsBelow = child.height <= _below(size);
    final y = fitsBelow || _above() < _below(size) ? anchor.bottom + _g : anchor.top - _g - child.height;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout old) => old.anchor != anchor || old.rtl != rtl;
}

/// One row of a [PickerListBox].
@immutable
class PickerListItem {
  const PickerListItem({required this.title, this.detail, this.semanticLabel});

  /// In `body` and `ink`.
  final String title;

  /// After the title, `space-2` from it, in `ink-muted` (an end time's length: "1 hr 45 min").
  final String? detail;

  /// Read in place of the title and detail ("10:30, 1 hour").
  final String? semanticLabel;
}

/// Select's list (design/components/Select, "Open, the list"), as a list box: rows `control-height` tall,
/// `space-3` across, `body` in `ink`; the highlighted row filled with `surface-hover` and `radius-sm`, with
/// the 2px `focus` ring inside it when the keys moved it there; a check mark in `accent` at the end of the
/// [checked] row. About [visibleRows] rows show, then it scrolls, opening with [highlighted] in the middle.
///
/// Keys (while [focusNode] has focus): Up and Down move the highlight and stop at the ends, Home and End go
/// to the first and last, Page Up and Page Down move by a screen, Return or Space picks ([onPicked]),
/// Escape and Tab dismiss ([onDismiss]). Typing moves the highlight to the next row whose title starts with
/// what was typed.
class PickerListBox extends StatefulWidget {
  const PickerListBox({
    super.key,
    required this.items,
    required this.highlighted,
    required this.onPicked,
    required this.onDismiss,
    required this.semanticLabel,
    this.checked,
    this.focusNode,
    this.autofocus = false,
    this.compact = false,
    this.width,
    this.visibleRows = 8,
    this.rowHeight,
  });

  final List<PickerListItem> items;

  /// The row highlighted (and centred) when the list opens. A new value moves the highlight there.
  final int highlighted;

  /// The row with the check mark; null for none.
  final int? checked;
  final ValueChanged<int> onPicked;
  final VoidCallback onDismiss;
  final String semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool compact;

  /// At least this wide (the field's width).
  final double? width;
  final int visibleRows;

  /// The rows' height when not `control-height` (a phone sheet's `row-height`).
  final double? rowHeight;

  /// The check mark's size: `icon`.
  static const checkSize = MyDataSize.icon;

  /// The ring around a row reached with the keys: 2px of `focus`, inside the row's shape.
  static const ringWidth = 2.0;

  /// How long typed letters are joined into one search.
  static const typeAheadReset = Duration(seconds: 1);

  @override
  State<PickerListBox> createState() => _PickerListBoxState();
}

class _PickerListBoxState extends State<PickerListBox> {
  late int _highlight = widget.highlighted;
  bool _fromKeys = false;
  late final ScrollController _scroll;
  String _typed = '';
  Timer? _typedTimer;
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'PickerListBox'));

  double get _rowHeight =>
      widget.rowHeight ?? (widget.compact ? MyDataSize.controlHeightCompact : MyDataSize.controlHeight);

  double get _viewport => math.min(widget.items.length, widget.visibleRows) * _rowHeight;

  double _centredOffset(int index) {
    final max = math.max(0.0, widget.items.length * _rowHeight - _viewport);
    return ((index + 0.5) * _rowHeight - _viewport / 2).clamp(0.0, max);
  }

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _centredOffset(_highlight));
  }

  @override
  void didUpdateWidget(PickerListBox old) {
    super.didUpdateWidget(old);
    if (widget.highlighted != old.highlighted || widget.items.length != old.items.length) {
      _highlight = widget.highlighted.clamp(0, widget.items.length - 1);
      _fromKeys = false;
      if (_scroll.hasClients) _scroll.jumpTo(_centredOffset(_highlight));
    }
  }

  @override
  void dispose() {
    _typedTimer?.cancel();
    _scroll.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  void _move(int to) {
    final i = to.clamp(0, widget.items.length - 1);
    setState(() {
      _highlight = i;
      _fromKeys = true;
    });
    _reveal(i);
  }

  void _reveal(int i) {
    if (!_scroll.hasClients) return;
    final top = i * _rowHeight;
    final bottom = top + _rowHeight;
    final offset = _scroll.offset;
    if (top < offset) {
      _scroll.jumpTo(top);
    } else if (bottom > offset + _viewport) {
      _scroll.jumpTo(bottom - _viewport);
    }
  }

  void _typeAhead(String character) {
    _typedTimer?.cancel();
    _typedTimer = Timer(PickerListBox.typeAheadReset, () => _typed = '');
    _typed += character.toLowerCase();
    final n = widget.items.length;
    // A repeated first letter steps through the matches; otherwise the search starts at the highlight.
    final start = _typed.length == 1 ? _highlight + 1 : _highlight;
    for (var k = 0; k < n; k++) {
      final i = (start + k) % n;
      if (widget.items[i].title.toLowerCase().startsWith(_typed)) {
        _move(i);
        return;
      }
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final page = widget.visibleRows;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(_highlight + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(_highlight - 1);
    } else if (key == LogicalKeyboardKey.home) {
      _move(0);
    } else if (key == LogicalKeyboardKey.end) {
      _move(widget.items.length - 1);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _move(_highlight + page);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _move(_highlight - page);
    } else if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            (key == LogicalKeyboardKey.space && _typed.isEmpty))) {
      widget.onPicked(_highlight);
    } else if (event is KeyDownEvent && (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.tab)) {
      widget.onDismiss();
    } else if (event.character != null &&
        event.character!.trim().isNotEmpty &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed) {
      _typeAhead(event.character!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// The widest row: its padding, title, detail and check mark, at the current text size.
  double _naturalWidth(BuildContext context) {
    final painter = TextPainter(textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context));
    var widest = 0.0;
    for (final item in widget.items) {
      painter.text = TextSpan(text: item.title, style: MyDataType.body);
      painter.layout();
      var w = painter.width;
      if (item.detail != null) {
        painter.text = TextSpan(text: item.detail, style: MyDataType.body);
        painter.layout();
        w += MyDataSpace.s2 + painter.width;
      }
      widest = math.max(widest, w);
    }
    painter.dispose();
    // `space-1` of slack: a row is never cut short by a fraction of a pixel.
    return (widest + 2 * MyDataSpace.s3 + MyDataSpace.s2 + PickerListBox.checkSize + MyDataSpace.s1).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.items.length;
    final list = SizedBox(
      height: _viewport,
      child: ListView.builder(
        controller: _scroll,
        itemExtent: _rowHeight,
        padding: EdgeInsets.zero,
        itemCount: n,
        itemBuilder: (context, i) {
          final item = widget.items[i];
          final highlighted = i == _highlight;
          final checked = i == widget.checked;
          return Semantics(
            container: true,
            selected: checked,
            // The list box is one focus node: screen readers follow the highlighted row.
            focusable: true,
            focused: highlighted && _node.hasFocus,
            label: item.semanticLabel ?? [item.title, ?item.detail].join(', '),
            hint: '${i + 1} of $n',
            onTap: () => widget.onPicked(i),
            child: ExcludeSemantics(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() {
                  _highlight = i;
                  _fromKeys = false;
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onPicked(i),
                  child: CustomPaint(
                    foregroundPainter: highlighted && _fromKeys && _node.hasFocus
                        ? _RowRingPainter(FocusRing.colourOf(c))
                        : null,
                    child: Container(
                      key: ValueKey('picker-row-$i'),
                      decoration: BoxDecoration(
                          color: highlighted ? c.surfaceHover : null, borderRadius: MyDataRadii.sm),
                      padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s3),
                      child: Row(children: [
                        Text(item.title, maxLines: 1, softWrap: false, style: MyDataType.body.copyWith(color: c.ink)),
                        if (item.detail != null) ...[
                          const SizedBox(width: MyDataSpace.s2),
                          Expanded(
                            child: Text(item.detail!,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: MyDataType.body.copyWith(color: c.inkMuted)),
                          ),
                        ] else
                          const Spacer(),
                        const SizedBox(width: MyDataSpace.s2),
                        SizedBox.square(
                          dimension: PickerListBox.checkSize,
                          child: checked
                              ? Icon(Icons.check_rounded, size: PickerListBox.checkSize, color: c.accent)
                              : null,
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Focus(
        focusNode: _node,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        onFocusChange: (_) => setState(() {}),
        child: SizedBox(width: math.max(widget.width ?? 0, _naturalWidth(context)), child: list),
      ),
    );
  }
}

/// The 2px `focus` ring inside a list row's `radius-sm` shape.
class _RowRingPainter extends CustomPainter {
  _RowRingPainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    const w = PickerListBox.ringWidth;
    final rect = (Offset.zero & size).deflate(w / 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(MyDataRadius.sm - w / 2)),
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = w);
  }

  @override
  bool shouldRepaint(_RowRingPainter old) => old.colour != colour;
}
