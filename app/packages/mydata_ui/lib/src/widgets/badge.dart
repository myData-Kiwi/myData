import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pressable.dart';
import 'status.dart';

/// A small tonal chip that states a status in a word or two (design/components/Badge).
///
/// - A pill, 26px tall, with a status `-soft` fill and text in the matching status colour: `success` on
///   `success-soft`, and so on. [MyDataTone.neutral] is the inactive state: `surface-sunken` with `ink-muted`.
/// - [Badge.host] is the one exception: the host's running state, a `surface` chip with `shadow-1`, `ink`
///   text and a `brand` dot. It is the only place the kiwi green appears in the interface.
/// - The word is always present, so colour is never the only signal. One chip per row; do not stack
///   several statuses side by side.
/// - Not tappable (decided 2026-10-12), so it has no press, hover or focus and no 44px target.
///
/// Note: Flutter's material library also has a `Badge`. A file that imports both `package:flutter/material.dart`
/// and this package and uses the name must hide one: `import 'package:flutter/material.dart' hide Badge;`.
class MyDataBadge extends StatelessWidget {
  /// A status chip: [label] in the strong colour of [tone] on its fill. [MyDataTone.accent] is for icon
  /// tiles only and is not a status; use success, warning, danger, info or neutral.
  const MyDataBadge(this.label, {super.key, required this.tone})
      : host = false,
        assert(tone != MyDataTone.accent, 'accent is for icon tiles, not status chips');

  /// The host's running state: a `surface` chip with a `brand` dot and [label] in `ink`.
  const MyDataBadge.host(this.label, {super.key})
      : tone = MyDataTone.neutral,
        host = true;

  /// The word or two, in sentence case ("Up to date", "Needs approval"). Always present.
  final String label;

  /// The status. Ignored for [Badge.host].
  final MyDataTone tone;

  /// Whether this is the host chip ([Badge.host]).
  final bool host;

  /// Spec: "A pill, 26px tall". The height at 1x text; the chip grows with scaled text.
  static const double height = 26;

  /// Preview: the host chip's dot is 8px across.
  static const double dotSize = 8;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Text(
      // A status word, never a name: upper case where the theme sets labels so (semantics keep [label]).
      context.typeScale.cased(MyDataTypeRole.label, label),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      // Preview: 600 13px, which is the `label` type style.
      style: context.typeScale.label.copyWith(color: host ? c.ink : tone.strong(c)),
    );
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        // A minimum, not a fixed height: at 1x the chip is exactly 26px, and when the text is scaled up
        // (Larger Text) it grows instead of clipping the word, which is the only non-colour signal.
        constraints: const BoxConstraints(minHeight: height),
        // Preview: 10px either side, between space-2 and space-3; the nearest token on the larger side.
        padding: EdgeInsets.symmetric(horizontal: context.space(3)),
        decoration: BoxDecoration(
          color: host ? c.surface : tone.fill(c),
          borderRadius: MyDataRadii.pill(context.look),
          boxShadow: host ? context.shadows.shadow1 : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (host) ...[
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
              ),
              // Preview: 6px, between space-1 and space-2; the nearest token on the larger side.
              SizedBox(width: context.space(2)),
            ],
            Flexible(child: text),
          ],
        ),
      ),
    );
  }
}
