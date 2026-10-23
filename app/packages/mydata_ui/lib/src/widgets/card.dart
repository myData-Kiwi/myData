import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/theme.dart';
import 'icon_tile.dart';
import 'pressable.dart' show MyDataRadii;
import 'status.dart';

/// A white rounded container that lifts off the grey ground, for one subject (design/components/Card).
///
/// - `surface`, `radius-lg`, `shadow-1`, `space-5` padding. No border.
/// - A header row: an [IconTile] in [iconTone] and the [name] in `body-strong` (decision 2026-10-12), then the [child], then at most one [action], usually a tonal `Button`.
/// - The parts are `space-3` apart (preview: 12px).
/// - Lay cards out with [CardGrid]. Never place a card inside a card: building one inside another fails an
///   assertion in debug builds.
///
/// Not interactive itself; the [action] is the card's only control. Screen readers get one group with the
/// name marked as its heading.
class MyDataCard extends StatelessWidget {
  const MyDataCard({
    super.key,
    required this.icon,
    this.iconTone = MyDataTone.accent,
    required this.name,
    required this.child,
    this.action,
  });

  /// The icon on the header's tile. The spec has the caller always provide one, so that the headers of
  /// cards side by side line up.
  final IconData icon;

  /// The tint of the header's tile. Give the same kind of thing the same tone everywhere.
  final MyDataTone iconTone;

  /// What the card is about, in sentence case: "Storage", "Photos".
  final String name;

  /// The content, under the header. Text in it defaults to `body` in `ink`.
  final Widget child;

  /// At most one button, usually a tonal `Button` whose label states its result: "Add a device".
  final Widget? action;

  /// Between the header, the content and the action (preview: `gap: 12px`).
  static double gap(MyDataLook look) => look.space(3);

  /// Between the icon tile and the name (preview: `gap: 12px`).
  static double headerGap(MyDataLook look) => look.space(3);

  /// `space-5` on every side.
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.all(look.space(5));

  @override
  Widget build(BuildContext context) {
    assert(() {
      if (context.getInheritedWidgetOfExactType<_InsideCard>() != null) {
        throw FlutterError.fromParts([
          ErrorSummary('A MyDataCard was built inside another card.'),
          ErrorDescription('design/README.md: never put a card on a card.'),
          ErrorHint('Put the inner content straight into the outer card, or lay the cards side by side in a '
              'CardGrid.'),
        ]);
      }
      return true;
    }());

    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1),
        child: Padding(
          padding: padding(context.look),
          child: _InsideCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  IconTile(icon: icon, tone: iconTone),
                  SizedBox(width: headerGap(context.look)),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(name, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
                    ),
                  ),
                ]),
                SizedBox(height: gap(context.look)),
                DefaultTextStyle(style: context.typeScale.body.copyWith(color: c.ink), child: child),
                if (action != null) ...[
                  SizedBox(height: gap(context.look)),
                  Align(alignment: AlignmentDirectional.centerStart, child: action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card that leads with one large figure (design/components/Card, "stat card").
///
/// The [figure] is in `display-lg`; the [caption] under it, in `caption` / `ink-muted`, gives the figure its
/// meaning ("of 1 TB on Home drive", "126 added this week"). An optional [child] sits between them, such as
/// a meter. Otherwise the same as [MyDataCard].
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    this.iconTone = MyDataTone.accent,
    required this.name,
    required this.figure,
    required this.caption,
    this.child,
    this.action,
  });

  /// The icon on the header's tile.
  final IconData icon;

  /// The tint of the header's tile.
  final MyDataTone iconTone;

  /// What the figure counts, in sentence case: "Photos".
  final String name;

  /// The one large figure: "18,240", "412 GB".
  final String figure;

  /// The line that gives the figure its meaning.
  final String caption;

  /// Shown between the figure and the caption, such as a meter. Not in the spec; the preview's storage card
  /// has one.
  final Widget? child;

  /// At most one button, usually a tonal `Button`.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MyDataCard(
      icon: icon,
      iconTone: iconTone,
      name: name,
      action: action,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(figure, style: context.typeScale.displayLg.copyWith(color: c.ink)),
          SizedBox(height: MyDataCard.gap(context.look)),
          if (child != null) ...[
            child!,
            SizedBox(height: MyDataCard.gap(context.look)),
          ],
          Text(caption, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}

/// Marks the subtree of a [MyDataCard], so that a card built inside it can be caught.
class _InsideCard extends InheritedWidget {
  const _InsideCard({required super.child});

  @override
  bool updateShouldNotify(_InsideCard oldWidget) => false;
}

/// Lays cards out in equal columns, `space-4` apart (decision 2026-10-12), and plays their entrance.
///
/// - Columns are at least [minCardWidth] wide and share the width equally; with fewer cards than columns
///   fit, the cards share the whole width (CSS `repeat(auto-fit, minmax(220px, 1fr))`, as in the preview).
/// - The cards in one row are stretched to the tallest of them.
/// - On first build the cards fade and rise [MyDataMotion.entranceRise] over `base` with the `standard`
///   curve, [MyDataMotion.entranceStagger] apart; the first [MyDataMotion.entranceMaxStaggered] are
///   staggered and the rest enter with the last of those. With reduced motion they all fade in over `fast`,
///   without moving. Cards added later appear at once.
///
/// Needs a bounded width (put it in a scroll view, not a horizontal Row).
class CardGrid extends StatefulWidget {
  const CardGrid({super.key, required this.children, this.entrance = true});

  /// The cards: [MyDataCard]s and [StatCard]s.
  final List<Widget> children;

  /// Whether the cards play their entrance on first build. Turn it off when returning to a screen whose
  /// cards the user has already seen.
  final bool entrance;

  /// Between cards, across and down: `space-4`.
  static double gap(MyDataLook look) => look.space(4);

  /// Preview: `grid-template-columns: repeat(auto-fit, minmax(220px, 1fr))`.
  static const minCardWidth = 220.0;

  @override
  State<CardGrid> createState() => _CardGridState();
}

class _CardGridState extends State<CardGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: widget.entrance ? 0 : 1);
  bool _started = false;
  bool _reduced = false;

  /// The whole entrance: the last staggered card starts after (max - 1) staggers and takes `base`.
  Duration get _total {
    final m = context.lookNow.motion;
    return m.base + m.entranceStagger * (m.entranceMaxStaggered - 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MyDataMotion.reduced(context);
    if (_controller.value < 1) {
      _controller.duration = _reduced ? context.motion.fast : _total;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The part of the controller's run in which card [index] enters. A plain [Curve], not a
  /// [CurvedAnimation]: each card listens to the one controller, so a rebuild adds no listeners to it.
  Curve _curve(int index) {
    // With reduced motion every card fades together over the whole (`fast`) run.
    if (_reduced) return context.motion.standard;
    final total = _total.inMicroseconds;
    final delay = (context.motion.entranceStagger * math.min(index, context.motion.entranceMaxStaggered - 1))
        .inMicroseconds;
    return Interval(delay / total, (delay + context.motion.base.inMicroseconds) / total,
        curve: context.motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    return _CardGridLayout(
      gap: CardGrid.gap(context.look),
      minChildWidth: CardGrid.minCardWidth,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _Entrance(controller: _controller, curve: _curve(i), rise: !_reduced, child: widget.children[i]),
      ],
    );
  }
}

/// Fades a card in and, unless [rise] is false, lifts it [MyDataMotion.entranceRise] into place.
class _Entrance extends AnimatedWidget {
  const _Entrance({
    required AnimationController controller,
    required this.curve,
    required this.rise,
    required this.child,
  }) : super(listenable: controller);

  /// Maps the controller's value to this card's progress.
  final Curve curve;
  final bool rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = curve.transform((listenable as AnimationController).value);
    // The same tree at every value, so the card keeps its state when the entrance ends.
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, rise ? (1 - t) * context.motion.entranceRise : 0),
        child: child,
      ),
    );
  }
}

class _CardGridLayout extends MultiChildRenderObjectWidget {
  const _CardGridLayout({required this.gap, required this.minChildWidth, required super.children});

  final double gap;
  final double minChildWidth;

  @override
  _RenderCardGrid createRenderObject(BuildContext context) =>
      _RenderCardGrid(gap, minChildWidth, Directionality.maybeOf(context) ?? TextDirection.ltr);

  @override
  void updateRenderObject(BuildContext context, _RenderCardGrid renderObject) {
    renderObject
      ..gap = gap
      ..minChildWidth = minChildWidth
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

class _CardGridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCardGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardGridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardGridParentData> {
  _RenderCardGrid(this._gap, this._minChildWidth, this._textDirection);

  /// Right to left fills each row from the right.
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _minChildWidth;
  set minChildWidth(double value) {
    if (value == _minChildWidth) return;
    _minChildWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardGridParentData) child.parentData = _CardGridParentData();
  }

  List<RenderBox> get _children {
    final list = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      list.add(child);
      child = childAfter(child);
    }
    return list;
  }

  /// The width the grid takes for [constraints]: all of it when bounded, otherwise one row at the minimum.
  double _width(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth) return constraints.maxWidth;
    assert(() {
      throw FlutterError.fromParts([
        ErrorSummary('CardGrid was given an unbounded width.'),
        ErrorHint('Put it where its width is known, such as in a vertical scroll view.'),
      ]);
    }());
    return childCount * _minChildWidth + math.max(0, childCount - 1) * _gap;
  }

  /// How many columns fit in [width]: as many [_minChildWidth] columns as fit, but no more than cards.
  int _columns(double width) {
    final fit = ((width + _gap) / (_minChildWidth + _gap)).floor();
    return math.max(1, math.min(fit, childCount));
  }

  double _columnWidth(double width, int columns) => math.max(0, (width - _gap * (columns - 1)) / columns);

  /// The height of each row, measured by [height] (a child and its column width).
  List<double> _rowHeights(int columns, double columnWidth, double Function(RenderBox, double) height) {
    final children = _children;
    final rows = <double>[];
    for (var start = 0; start < children.length; start += columns) {
      var tallest = 0.0;
      for (final child in children.skip(start).take(columns)) {
        tallest = math.max(tallest, height(child, columnWidth));
      }
      rows.add(tallest);
    }
    return rows;
  }

  double _totalHeight(List<double> rows) =>
      rows.isEmpty ? 0 : rows.fold<double>(0, (a, b) => a + b) + _gap * (rows.length - 1);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (childCount == 0) return constraints.smallest;
    final width = _width(constraints);
    final columns = _columns(width);
    final rows = _rowHeights(columns, _columnWidth(width, columns),
        (child, w) => child.getDryLayout(BoxConstraints(minWidth: w, maxWidth: w)).height);
    return constraints.constrain(Size(width, _totalHeight(rows)));
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }
    final width = _width(constraints);
    final columns = _columns(width);
    final columnWidth = _columnWidth(width, columns);
    final rows = _rowHeights(columns, columnWidth, (child, w) {
      child.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
      return child.size.height;
    });

    final children = _children;
    final rtl = _textDirection == TextDirection.rtl;
    var y = 0.0;
    for (var row = 0; row < rows.length; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        if (index >= children.length) break;
        final child = children[index];
        // Stretch every card in the row to the tallest.
        child.layout(BoxConstraints.tightFor(width: columnWidth, height: rows[row]));
        final x = column * (columnWidth + _gap);
        (child.parentData! as _CardGridParentData).offset = Offset(rtl ? width - x - columnWidth : x, y);
      }
      y += rows[row] + _gap;
    }
    size = constraints.constrain(Size(width, _totalHeight(rows)));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _children.fold<double>(0, (w, child) => math.max(w, child.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    if (children.isEmpty) return 0;
    return children.fold<double>(0, (w, child) => w + math.max(_minChildWidth, child.getMaxIntrinsicWidth(height))) +
        _gap * (children.length - 1);
  }

  double _intrinsicHeight(double width) {
    if (childCount == 0 || !width.isFinite) return 0;
    final columns = _columns(width);
    return _totalHeight(_rowHeights(columns, _columnWidth(width, columns), (c, w) => c.getMaxIntrinsicHeight(w)));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('gap', _gap))
      ..add(DoubleProperty('minChildWidth', _minChildWidth))
      ..add(EnumProperty<TextDirection>('textDirection', _textDirection));
  }
}
