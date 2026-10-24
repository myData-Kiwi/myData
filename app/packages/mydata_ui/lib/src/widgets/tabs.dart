import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// A row of pill tabs for the sections of one screen (design/components/Tabs).
///
/// - The current tab sits on an `accent-soft` pill with `accent` text in `body-strong`; the others are
///   `ink-muted` with no fill. No underline and no divider beneath the row.
/// - The pill slides to the new tab with `spring`; with reduced motion it jumps. At rest it is drawn inside the
///   current tab, so a press scales and dims pill and label together (motion.md "press"); while sliding it is a
///   separate thumb.
/// - Tabs are `control-height` (44px) tall (decision 2026-10-12, not the preview's 40px), `space-4` either
///   side of the label and `space-2` apart; the row wraps when it does not fit.
/// - Each tab is as wide as its label in `body-strong`, so the row does not shift when the current tab changes.
/// - Keyboard: Tab reaches the current tab only; the arrow keys move to the previous or next tab and make it
///   current (wrapping at the ends), Home and End go to the first and last.
///
/// Use tabs for sections of equal weight inside a screen. Navigation between an app's areas belongs in the
/// sidebar or the phone tab bar.
class MyDataTabs extends StatefulWidget {
  const MyDataTabs({
    super.key,
    required this.tabs,
    required this.current,
    required this.onChanged,
    this.semanticLabel,
  }) : assert(current >= 0);

  /// The tab names, in sentence case.
  final List<String> tabs;

  /// The index in [tabs] of the current tab.
  final int current;

  /// Called with the index of the tab the user picked. Null disables the row.
  final ValueChanged<int>? onChanged;

  /// What the row is for, read by screen readers ("Settings").
  final String? semanticLabel;

  /// Space between tabs, across and down: the preview's 6px gap snapped to a token (decision 2026-10-12).
  static double gap(MyDataLook look) => look.space(2);

  /// Space either side of a tab's label: the preview's `padding: 0 16px`.
  static double labelPadding(MyDataLook look) => look.space(4);

  @override
  State<MyDataTabs> createState() => _MyDataTabsState();
}

class _MyDataTabsState extends State<MyDataTabs> with SingleTickerProviderStateMixin {
  late final AnimationController _slide =
      AnimationController(vsync: this, duration: context.lookNow.motion.springDuration, value: 1);
  static const _curve = SpringCurve();

  final List<FocusNode> _nodes = [];

  /// Where the pill starts its slide; null when it is at rest on the current tab.
  Rect? _from;

  /// True while the pill slides as a separate thumb. At rest the current tab draws the pill itself.
  bool _sliding = false;

  /// The pill's rectangle as last drawn, so a slide can start from wherever the pill is.
  Rect? _shown;

  @override
  void initState() {
    super.initState();
    _syncNodes();
    _slide.addStatusListener((status) {
      if (status == AnimationStatus.completed && _sliding && mounted) {
        setState(() {
          _sliding = false;
          _from = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(MyDataTabs old) {
    super.didUpdateWidget(old);
    _syncNodes();
    if (old.current != widget.current) {
      if (MyDataMotion.reduced(context) || _shown == null) {
        _from = null;
        _sliding = false;
        _slide.value = 1;
      } else {
        _from = _shown;
        _sliding = true;
        _slide.forward(from: 0);
      }
    }
  }

  /// One focus node per tab; only the current tab is in the Tab order (the arrow keys reach the rest).
  void _syncNodes() {
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
    }
    while (_nodes.length < widget.tabs.length) {
      _nodes.add(FocusNode(debugLabel: 'MyDataTabs ${_nodes.length}'));
    }
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].skipTraversal = i != widget.current;
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _pick(int index) {
    if (index != widget.current) widget.onChanged?.call(index);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (widget.onChanged == null || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final focused = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final count = widget.tabs.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    int? target;
    if (key == LogicalKeyboardKey.arrowRight) {
      target = rtl ? focused - 1 : focused + 1;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      target = rtl ? focused + 1 : focused - 1;
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = count - 1;
    }
    if (target == null) return KeyEventResult.ignored;
    target %= count;
    _nodes[target].requestFocus();
    _pick(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.tabs.isNotEmpty, 'Tabs need at least one tab');
    assert(widget.current < widget.tabs.length, 'current must index tabs');
    final c = context.colors;
    final enabled = widget.onChanged != null;
    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: LayoutBuilder(builder: (context, constraints) {
          final layout = _layout(context, constraints.maxWidth);
          final tabs = SizedBox(
            width: layout.size.width,
            height: layout.size.height,
            child: Stack(children: [
              for (var i = 0; i < widget.tabs.length; i++)
                Positioned.fromRect(rect: layout.rects[i], child: _tab(context, i, enabled)),
            ]),
          );
          return AnimatedBuilder(
            animation: _slide,
            child: tabs,
            builder: (context, child) {
              final to = layout.rects[widget.current];
              final pill = !_sliding || _from == null || _slide.isCompleted
                  ? to
                  : Rect.lerp(_from, to, _curve.transform(_slide.value))!;
              _shown = pill;
              // The children stay in the same slots whether or not the thumb shows, so the tabs keep their state.
              return Stack(clipBehavior: Clip.none, children: [
                Positioned.fromRect(
                  rect: pill,
                  child: _sliding
                      ? Opacity(
                          opacity: enabled ? 1 : Pressable.disabledOpacity,
                          child: DecoratedBox(decoration: context.radius.decorate(BoxDecoration(color: c.accentSoft, borderRadius: MyDataRadii.pill(context.look)))),
                        )
                      : const SizedBox.shrink(),
                ),
                child!,
              ]);
            },
          );
        }),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, bool enabled) {
    final c = context.colors;
    final selected = i == widget.current;
    return MergeSemantics(
      child: Semantics(
        role: SemanticsRole.tab,
        child: Pressable(
          onPressed: enabled ? () => _pick(i) : null,
          borderRadius: MyDataRadii.pill(context.look),
          focusNode: _nodes[i],
          button: false,
          selected: selected,
          // The resting pill sits inside the Pressable, so it presses (and dims when disabled) with the label.
          child: DecoratedBox(
            decoration: context.radius.decorate(BoxDecoration(
                color: selected && !_sliding ? c.accentSoft : c.accentSoft.withValues(alpha: 0),
                borderRadius: MyDataRadii.pill(context.look))),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: context.motion.fast,
                curve: context.motion.standard,
                style: selected ? context.typeScale.bodyStrong.copyWith(color: c.accent) : context.typeScale.body.copyWith(color: c.inkMuted),
                child: Text(widget.tabs[i], maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Places the tabs left to right (right to left in RTL), wrapping onto a new run when the next tab does not fit.
  _TabsLayout _layout(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final widths = <double>[];
    for (final name in widget.tabs) {
      final painter = TextPainter(
        text: TextSpan(text: name, style: context.typeScale.bodyStrong),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      var w = math.max(context.density.controlHeight, painter.width.ceilToDouble() + 2 * MyDataTabs.labelPadding(context.look));
      painter.dispose();
      if (maxWidth.isFinite) w = math.min(w, maxWidth);
      widths.add(w);
    }
    final h = context.density.controlHeight;
    final rects = <Rect>[];
    var x = 0.0, y = 0.0, extent = 0.0;
    for (final w in widths) {
      if (x > 0 && x + w > maxWidth) {
        x = 0;
        y += h + MyDataTabs.gap(context.look);
      }
      rects.add(Rect.fromLTWH(x, y, w, h));
      extent = math.max(extent, x + w);
      x += w + MyDataTabs.gap(context.look);
    }
    final size = Size(extent, y + h);
    if (direction == TextDirection.rtl) {
      for (var i = 0; i < rects.length; i++) {
        final r = rects[i];
        rects[i] = Rect.fromLTWH(extent - r.right, r.top, r.width, r.height);
      }
    }
    return _TabsLayout(rects, size);
  }
}

class _TabsLayout {
  const _TabsLayout(this.rects, this.size);
  final List<Rect> rects;
  final Size size;
}
