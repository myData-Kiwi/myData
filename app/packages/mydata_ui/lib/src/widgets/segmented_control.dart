import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../accessibility.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// A pill-shaped set of two to five mutually exclusive options that switch or filter the view below it
/// (design/components/SegmentedControl).
///
/// - The track is `surface-sunken` with `radius-pill` and no border, padded by `space-1`.
/// - The selected segment is a separate `surface` thumb with `shadow-1` behind an `ink` label in `body-strong`
///   (the preview's 600 15px); the other labels are `ink-muted` in `body` (400 15px). Labels change colour and
///   weight over `fast`.
/// - The thumb slides to its new place with `spring` over [MyDataMotion.springDuration] (decided 2026-10-12);
///   with reduced motion it jumps.
/// - Each segment is as wide as its label in `body-strong` plus `space-4` each side, so a label does not
///   shift when it becomes selected. Segments are `space-1` apart (the preview's 2px gap, snapped to the scale).
/// - When the parent is narrower than that, the side padding shrinks evenly down to [minSidePadding]; if the
///   labels still do not fit, the narrow segments keep their label and padding and the wide ones share what
///   is left equally, their labels ending in an ellipsis. No segment goes below `control-height` (44px) wide,
///   so the control needs at least that per segment plus its gaps; narrower than that it overflows.
/// - The control is `control-height` (44px) tall and each segment's target is the full height; the thumb is
///   `control-height-compact` (36px) inside the track's padding, and the focus ring follows the thumb's shape.
/// - Keyboard: Tab reaches the selected segment only; the arrow keys move the selection (wrapping), Home and
///   End go to the first and last. Enter and Space select the focused segment.
/// - Semantics: a radio group, each segment a radio that is checked when selected.
/// - [onChanged] null disables the whole control (45% opacity, no focus).
/// - For more than five options use a menu.
class SegmentedControl<T> extends StatefulWidget {
  /// [segments] are the options in order, two to five, each a value and its label (sentence case, a word
  /// or two); [selected] is the value of the selected one and must be among them. Both are asserted when the
  /// control builds (a const constructor cannot check a list's length).
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
  });

  /// The options, in order: each a value and its label.
  final List<(T value, String label)> segments;

  /// The value of the selected option.
  final T selected;

  /// Called with the newly chosen value. Not called when the selected option is chosen again.
  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// What the group chooses, for screen readers ("View", "Filter photos").
  final String? semanticLabel;

  /// Spec: "two to five mutually exclusive options".
  static const minSegments = 2;
  static const maxSegments = 5;

  /// Not in the spec: the least side padding a label keeps when the parent is too narrow for `space-4`.
  static double minSidePadding(MyDataLook look) => look.space(2);

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  final List<FocusNode> _nodes = [];

  bool get _enabled => widget.onChanged != null;

  int get _selectedIndex => widget.segments.indexWhere((s) => s.$1 == widget.selected);

  void _syncNodes() {
    while (_nodes.length < widget.segments.length) {
      _nodes.add(FocusNode(debugLabel: 'SegmentedControl segment ${_nodes.length}'));
    }
    while (_nodes.length > widget.segments.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _choose(int index) {
    final value = widget.segments[index].$1;
    if (value != widget.selected) widget.onChanged?.call(value);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final focused = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final n = widget.segments.length;
    final key = event.logicalKey;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (focused + 1) % n;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (focused - 1 + n) % n;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = n - 1;
    }
    if (next == null) return KeyEventResult.ignored;
    _nodes[next].requestFocus();
    _choose(next);
    return KeyEventResult.handled;
  }

  /// The width of each label at its widest (selected, `body-strong`), as the text will render.
  List<double> _labelWidths(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final bold = MediaQuery.boldTextOf(context);
    final direction = Directionality.of(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: bold ? style.merge(const TextStyle(fontWeight: FontWeight.bold)) : style,
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    return [
      for (final s in widget.segments)
        math.max(measure(s.$2, context.typeScale.bodyStrong), measure(s.$2, context.typeScale.body)).ceilToDouble(),
    ];
  }

  /// Each segment's width: the label plus `space-4` each side when that fits in [maxWidth]; otherwise the side
  /// padding shrinks evenly to [SegmentedControl.minSidePadding]; otherwise the widest segments share what is
  /// left equally (their labels ellipsize), never below `control-height`.
  static List<double> _fitWidths(MyDataLook look, List<double> labels, double maxWidth) {
    final n = labels.length;
    final chrome = (n + 1) * look.space(1); // The track's padding at both ends and the gaps.
    final labelSum = labels.fold(0.0, (a, w) => a + w);
    final natural = [for (final w in labels) w + 2 * look.space(4)];
    if (!maxWidth.isFinite || labelSum + 2 * n * look.space(4) + chrome <= maxWidth) return natural;

    final available = maxWidth - chrome;
    final pad = (available - labelSum) / (2 * n);
    final shortest = labels.reduce(math.min);
    if (pad >= SegmentedControl.minSidePadding(look) && shortest + 2 * pad >= look.density.controlHeight) {
      return [for (final w in labels) w + 2 * pad];
    }

    // Water-fill: segments narrower than the cap keep their label, the least padding and a 44px target; the
    // rest are cut to the cap.
    final wanted = [
      for (final w in labels) math.max(look.density.controlHeight, w + 2 * SegmentedControl.minSidePadding(look)),
    ];
    final sorted = [...wanted]..sort();
    var remaining = available;
    var cap = 0.0;
    for (var k = 0; k < n; k++) {
      cap = remaining / (n - k);
      if (sorted[k] > cap) break;
      remaining -= sorted[k];
      cap = sorted[k];
    }
    return [for (final w in wanted) math.max(look.density.controlHeight, math.min(w, cap))];
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.segments.length >= SegmentedControl.minSegments && widget.segments.length <= SegmentedControl.maxSegments,
      'A segmented control has two to five options; for more use a menu.',
    );
    assert(_selectedIndex >= 0, 'selected must be one of the segment values');
    _syncNodes();
    return Semantics(
      container: true,
      role: SemanticsRole.radioGroup,
      label: widget.semanticLabel,
      enabled: _enabled,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: _buildTrack),
      ),
    );
  }

  /// The track, thumb and segments, sized to fit [constraints] (see [_fitWidths]).
  Widget _buildTrack(BuildContext context, BoxConstraints constraints) {
    final c = context.colors;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final selected = _selectedIndex;

    // Only the selected segment is a Tab stop (a radio group); the arrow keys move within it.
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].skipTraversal = i != selected && selected >= 0;
    }

    final lineHeight = MediaQuery.textScalerOf(context)
        .scale(context.typeScale.bodyStrong.fontSize! * context.typeScale.bodyStrong.height!)
        .ceilToDouble();
    final thumbHeight = math.max(context.density.controlHeightCompact, lineHeight + context.space(2));
    final trackHeight = thumbHeight + 2 * context.space(1);
    final widths = _fitWidths(context.look, _labelWidths(context), constraints.maxWidth);

    var thumbStart = context.space(1);
    for (var i = 0; i < selected; i++) {
      thumbStart += widths[i] + context.space(1);
    }

    final segments = <Widget>[];
    for (var i = 0; i < widget.segments.length; i++) {
      if (i > 0) segments.add(SizedBox(width: context.space(1)));
      final isSelected = i == selected;
      final choose = _enabled ? () => _choose(i) : null;
      // The target is the full track height (44px); the pressable shape, and so the focus ring, is the thumb's
      // (36px), so the ring sits inside the track's padding as in the preview. A tap on the 4px of padding
      // above or below still selects the segment.
      segments.add(
        Semantics(
          container: true,
          inMutuallyExclusiveGroup: true,
          checked: isSelected,
          child: MouseRegion(
            cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: choose,
              child: SizedBox(
                width: widths[i],
                height: trackHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: context.space(1)),
                  child: Pressable(
                    onPressed: choose,
                    borderRadius: MyDataRadii.pill(context.look),
                    focusNode: _nodes[i],
                    button: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: SegmentedControl.minSidePadding(context.look)),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: context.motion.fast,
                          curve: context.motion.standard,
                          style: isSelected
                              ? context.typeScale.bodyStrong.copyWith(color: c.ink)
                              : context.typeScale.body.copyWith(color: c.inkMuted),
                          child: Text(
                            widget.segments[i].$2,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final disabledOpacity = _enabled ? 1.0 : Pressable.disabledOpacity;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: disabledOpacity,
            child: DecoratedBox(
              decoration: context.radius.decorate(BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.pill(context.look))),
            ),
          ),
        ),
        if (selected >= 0)
          AnimatedPositionedDirectional(
            duration: reduced ? Duration.zero : context.motion.springDuration,
            curve: const SpringCurve(),
            start: thumbStart,
            top: context.space(1),
            width: widths[selected],
            height: thumbHeight,
            child: Opacity(
              opacity: disabledOpacity,
              child: DecoratedBox(
                decoration: context.radius.decorate(BoxDecoration(
                  color: c.surface,
                  borderRadius: MyDataRadii.pill(context.look),
                  boxShadow: context.shadows.shadow1,
                )),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space(1)),
          child: Row(mainAxisSize: MainAxisSize.min, children: segments),
        ),
      ],
    );
  }
}
