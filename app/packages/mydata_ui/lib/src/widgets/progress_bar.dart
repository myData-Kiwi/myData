import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart' show MyDataRadii;

/// A rounded bar showing how much of a known amount of work is done (design/components/ProgressBar).
///
/// - An 8px track in `surface-sunken` with an `accent` fill, both fully rounded (`radius-pill`).
/// - [label] on the left in `body-strong`, the figure ([valueLabel]) on the right.
/// - [caption] below, in `caption` / `ink-muted`, says whether the user can carry on.
///
/// Determinate only: for work of unknown length use `KiwiLoader`. The fill's width eases to a new [value]
/// over `base` with the `standard` curve; with reduced motion it jumps. Not interactive.
///
/// Screen readers get one progress-bar node: [label], the value as a percentage (0 to 100), and the caption.
/// A custom figure ([valueLabel]) is read before the caption, so the counts a sighted user sees are heard
/// too. The value itself stays a percentage so that the web build can still set `aria-valuenow`.
class MyDataProgressBar extends StatelessWidget {
  const MyDataProgressBar({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.valueLabel,
  });

  /// What is in progress, in sentence case: "Downloading the assistant model".
  final String label;

  /// How much is done, from 0 to 1. Values outside that range (and NaN) are clamped.
  final double value;

  /// Whether the user can carry on: "3.4 GB of 9.8 GB. You can keep using myData while this finishes."
  final String caption;

  /// The figure on the right, such as "35%". Null shows [value] as a whole percentage.
  final String? valueLabel;

  /// Spec: "An 8px track".
  static const trackHeight = 8.0;

  /// [value] clamped to 0..1, with NaN as 0.
  double get fraction => value.isNaN ? 0 : value.clamp(0.0, 1.0);

  /// [fraction] as a whole percentage, the figure shown when [valueLabel] is null.
  int get percent => (fraction * 100).round();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataMotion.reduced(context);
    final strong = context.typeScale.bodyStrong.copyWith(color: c.ink);

    return Semantics(
      container: true,
      role: SemanticsRole.progressBar,
      label: label,
      value: '$percent%',
      minValue: '0',
      maxValue: '100',
      hint: valueLabel == null ? caption : '$valueLabel. $caption',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: strong)),
              // Preview: 12px between label and figure, space-3.
              SizedBox(width: context.space(3)),
              Text(valueLabel ?? '$percent%',
                  style: strong.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          // Preview: a 10px gap, between space-2 and space-3; the nearest token on the larger side.
          SizedBox(height: context.space(3)),
          SizedBox(
            height: trackHeight,
            child: DecoratedBox(
              decoration: context.radius.decorate(BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.pill(context.look))),
              child: TweenAnimationBuilder<double>(
                // Begin is left null, so the first build shows [fraction] at once; later changes animate.
                tween: Tween<double>(end: fraction),
                duration: reduced ? Duration.zero : context.motion.base,
                curve: context.motion.standard,
                builder: (context, t, _) => FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: t.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: t <= 0
                      ? const SizedBox.shrink()
                      : DecoratedBox(decoration: context.radius.decorate(BoxDecoration(color: c.accent, borderRadius: MyDataRadii.pill(context.look)))),
                ),
              ),
            ),
          ),
          SizedBox(height: context.space(3)),
          Text(caption, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
