import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'pressable.dart';

/// One item in a [FloatingBar]: a tab of the phone tab bar or an action of a toolbar.
@immutable
class FloatingBarItem {
  const FloatingBarItem({required this.label, this.icon, this.onPressed, this.showLabel = true})
      : assert(showLabel || icon != null, 'An item without a visible label needs an icon.');

  /// What the item is or does, in sentence case ("Library", "Add to album"). Shown when [showLabel] is true;
  /// otherwise it is the icon's accessible name and its tooltip.
  final String label;

  /// An optional icon, drawn at `icon` size in the label's colour. With a visible label the icon sits above
  /// it, as on a phone tab bar, so five items fit on a phone. The icon set is not drawn yet; pass a Material
  /// outlined or rounded icon.
  final IconData? icon;

  /// Called when the item is pressed. Null disables it (45% opacity, not focusable).
  final VoidCallback? onPressed;

  /// False draws the [icon] alone (toolbars over a photo grid); [label] then names it for screen readers.
  final bool showLabel;
}

/// A translucent pill-shaped bar that floats above content: the phone tab bar and toolbars over a photo grid
/// (design/components/FloatingBar).
///
/// - Glass: `glass-fill` over a `blur-glass` backdrop blur, a 1px `glass-stroke` edge, `shadow-glass` and
///   `radius-xl` ([FloatingBarSurface]). With reduced transparency, on the web and on slow devices
///   ([forceSolid]) it is `surface` with `shadow-2`, no blur and no stroke.
/// - [items] share the width equally; each is at least `control-height` tall. A tab bar holds five at most.
///   A text label is `body`; an item with an icon and a label stacks the icon over a `caption` label, so five
///   one-word tabs fit a 375px phone. Keep tab labels to one short word.
/// - [current] is the index of the current tab: an `accent-soft` pill with `accent` text, which slides to a
///   new tab with `spring` and jumps with reduced motion. Null for a toolbar, which has no current item.
/// - It fills the width it is given. Inset it `space-4` from the screen edges with [FloatingBarHost], which
///   also lets content scroll beneath it.
class FloatingBar extends StatelessWidget {
  FloatingBar({super.key, required this.items, this.current, this.semanticLabel, this.forceSolid = false})
      : assert(items.isNotEmpty && items.length <= maxItems, 'A floating bar holds one to $maxItems items.'),
        assert(current == null || (current >= 0 && current < items.length), 'current must index items.');

  final List<FloatingBarItem> items;

  /// The current tab, or null for a toolbar.
  final int? current;

  /// Names the bar for screen readers, such as the app's name ("myPhotos").
  final String? semanticLabel;

  /// Draws the solid fallback even where glass is allowed: pass true on a slow device. See
  /// [FloatingBarSurface.forceSolid].
  final bool forceSolid;

  /// Spec: "a tab bar holds five at most".
  static const maxItems = 5;

  /// Space between the bar's edge and its items, and between items. The preview's 6px padding lies halfway
  /// between `space-1` and `space-2`; `space-1` keeps the item pill concentric with the `radius-xl` bar.
  static const padding = MyDataSpace.s1;
  static const gap = MyDataSpace.s1;

  /// Height of the bar: a `control-height` item, [padding] and the stroke on each side.
  static const height = MyDataSize.controlHeight + 2 * (padding + FloatingBarSurface.strokeWidth);

  @override
  Widget build(BuildContext context) {
    final reduced = MyDataMotion.reduced(context);
    return FloatingBarSurface(
      padding: const EdgeInsets.all(padding),
      forceSolid: forceSolid,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: LayoutBuilder(builder: (context, constraints) {
          assert(constraints.hasBoundedWidth, 'A FloatingBar fills its width; give it a bounded one.');
          final n = items.length;
          final itemWidth = (constraints.maxWidth - gap * (n - 1)) / n;
          return SizedBox(
            height: MyDataSize.controlHeight,
            child: Stack(children: [
              if (current != null)
                // Directional, so the pill follows the Row's reading order in right-to-left layouts.
                AnimatedPositionedDirectional(
                  start: current! * (itemWidth + gap),
                  top: 0,
                  width: itemWidth,
                  height: MyDataSize.controlHeight,
                  duration: reduced ? Duration.zero : MyDataMotion.springDuration,
                  curve: const SpringCurve(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: context.colors.accentSoft, borderRadius: MyDataRadii.pill),
                  ),
                ),
              Row(children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _FloatingBarButton(
                      item: items[i],
                      current: current == null ? null : current == i,
                    ),
                  ),
                ],
              ]),
            ]),
          );
        }),
      ),
    );
  }
}

class _FloatingBarButton extends StatelessWidget {
  const _FloatingBarButton({required this.item, required this.current});

  final FloatingBarItem item;

  /// Null in a toolbar.
  final bool? current;

  /// Side padding inside an item. `space-1`, not `space-2`, so a five-item tab bar on a 375px phone
  /// (about 63px per item) leaves room for a one-word label.
  static const itemPadding = MyDataSpace.s1;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCurrent = current ?? false;
    return Pressable(
      onPressed: item.onPressed,
      borderRadius: MyDataRadii.pill,
      selected: current,
      semanticLabel: item.showLabel ? null : item.label,
      tooltip: item.showLabel ? null : item.label,
      child: SizedBox(
        height: MyDataSize.controlHeight,
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: isCurrent ? c.accent : c.ink),
          duration: MyDataMotion.fast,
          curve: MyDataMotion.standard,
          builder: (context, color, _) {
            final icon = item.icon == null ? null : Icon(item.icon, size: MyDataSize.icon, color: color);
            if (!item.showLabel) return Center(child: icon);
            // The preview's 14px label is between `body` and `caption`. A text tab is `body` (400) or
            // `body-strong` (600), keeping the preview's weights. Under an icon the label is `caption` (400)
            // or `label` (600), the same weights one size down: a 20px icon and an 18px line fit the 44px item.
            final stacked = icon != null;
            final style = stacked
                ? (isCurrent ? MyDataType.label : MyDataType.caption)
                : (isCurrent ? MyDataType.bodyStrong : MyDataType.body);
            final text = Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: TextAlign.center,
              style: style.copyWith(color: color),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: itemPadding),
              child: stacked
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, text])
                  : Center(child: text),
            );
          },
        ),
      ),
    );
  }
}

/// The floating bar's surface alone: the glass (or solid) `radius-xl` pill, for bars that are not a row of
/// items, such as the assistant's input bar.
///
/// - Glass: `glass-fill` over a `blur-glass` backdrop blur (with the preview's saturate(1.6)), a 1px
///   `glass-stroke` edge and `shadow-glass` outside the shape.
/// - With reduced transparency (MyDataAccessibility), on the web and on slow devices: `surface` with
///   `shadow-2`, no blur and no stroke. The child keeps the same inset either way. The widget cannot tell a
///   slow device; the app decides that and passes [forceSolid].
class FloatingBarSurface extends StatelessWidget {
  const FloatingBarSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FloatingBar.padding),
    this.forceSolid = false,
  });

  final Widget child;

  /// Draws the solid fallback even where glass is allowed. Spec: "Reduced transparency, the web build and
  /// slow devices: the fill is surface with shadow-2 and no blur." Pass true on a slow device (one where the
  /// backdrop blur drops frames). False never forces glass: reduced transparency and the web stay solid.
  final bool forceSolid;

  /// Space between the edge (inside the stroke) and [child].
  final EdgeInsetsGeometry padding;

  /// Spec: "a 1px glass-stroke edge".
  static const strokeWidth = 1.0;

  /// The preview's backdrop-filter: saturate(1.6), which keeps colours behind the glass lively.
  static const saturation = 1.6;

  /// Whether the bar is drawn solid here regardless of [forceSolid]: reduced transparency, or the web build.
  /// Slow devices are the app's call, through [forceSolid].
  static bool solid(BuildContext context) => kIsWeb || MyDataAccessibility.of(context).reduceTransparency;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shadows = context.shadows;
    final inner = Padding(padding: padding.add(const EdgeInsets.all(strokeWidth)), child: child);
    if (forceSolid || solid(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.xl, boxShadow: shadows.shadow2),
        child: inner,
      );
    }
    return CustomPaint(
      painter: _OutsideShadowPainter(shadows.shadowGlass, MyDataRadii.xl),
      child: ClipRRect(
        borderRadius: MyDataRadii.xl,
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: const ColorFilter.matrix(_saturate),
            inner: ImageFilter.blur(sigmaX: MyDataBlur.glass, sigmaY: MyDataBlur.glass),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.glassFill,
              borderRadius: MyDataRadii.xl,
              border: Border.all(color: c.glassStroke, width: strokeWidth),
            ),
            child: inner,
          ),
        ),
      ),
    );
  }

  /// The CSS saturate() matrix (Filter Effects spec) for [saturation].
  static const _saturate = <double>[
    0.213 + 0.787 * saturation, 0.715 - 0.715 * saturation, 0.072 - 0.072 * saturation, 0, 0, //
    0.213 - 0.213 * saturation, 0.715 + 0.285 * saturation, 0.072 - 0.072 * saturation, 0, 0, //
    0.213 - 0.213 * saturation, 0.715 - 0.715 * saturation, 0.072 + 0.928 * saturation, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// Paints box shadows outside the shape only, as CSS does, so the translucent glass is not darkened by its
/// own shadow.
class _OutsideShadowPainter extends CustomPainter {
  _OutsideShadowPainter(this.shadows, this.radius);
  final List<BoxShadow> shadows;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = radius.toRRect(rect);
    var reach = 0.0;
    for (final s in shadows) {
      final r = s.blurRadius * 2 + s.spreadRadius + s.offset.distance;
      if (r > reach) reach = r;
    }
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(reach))
      ..addRRect(shape));
    for (final s in shadows) {
      canvas.drawRRect(shape.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadowPainter old) => !listEquals(old.shadows, shadows) || old.radius != radius;
}

/// Stacks [bar] over [child] the way floating bars sit on a screen: inset `space-4` from the edges and from
/// the bottom of the safe area, with [child] filling the whole area so content scrolls beneath the bar.
///
/// [child] sees the bar's height plus `space-4` above and below added to its MediaQuery bottom padding, so a
/// ListView, GridView or SafeArea inside it keeps its last item clear of the bar. The bar's height is
/// measured, so a taller bar (an input bar that grows) works too.
class FloatingBarHost extends StatefulWidget {
  const FloatingBarHost({super.key, required this.child, required this.bar});

  /// The screen's content.
  final Widget child;

  /// Usually a [FloatingBar] or a bar built on [FloatingBarSurface].
  final Widget bar;

  /// Spec: "inset from the screen edges by space-4".
  static const inset = MyDataSpace.s4;

  @override
  State<FloatingBarHost> createState() => _FloatingBarHostState();
}

class _FloatingBarHostState extends State<FloatingBarHost> {
  double _barHeight = FloatingBar.height;

  void _measured(double height) {
    if (mounted && height != _barHeight) setState(() => _barHeight = height);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final clearance = FloatingBarHost.inset + _barHeight + FloatingBarHost.inset;
    return Stack(children: [
      Positioned.fill(
        child: MediaQuery(
          data: mq.copyWith(
            padding: mq.padding.copyWith(bottom: mq.padding.bottom + clearance),
            viewPadding: mq.viewPadding.copyWith(bottom: mq.viewPadding.bottom + clearance),
          ),
          child: widget.child,
        ),
      ),
      Positioned(
        left: FloatingBarHost.inset + mq.padding.left,
        right: FloatingBarHost.inset + mq.padding.right,
        bottom: FloatingBarHost.inset + mq.padding.bottom,
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeRight: true,
          removeBottom: true,
          child: _HeightReporter(onHeight: _measured, child: widget.bar),
        ),
      ),
    ]);
  }
}

/// Reports its child's laid-out height after the frame, whenever it changes.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightReporter renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _reported) return;
    _reported = h;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}
