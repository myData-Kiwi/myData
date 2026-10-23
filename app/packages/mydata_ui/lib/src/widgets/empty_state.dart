import 'package:flutter/widgets.dart';

import '../mac/mac_empty_state.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'kiwi.dart';
import 'pressable.dart';

/// What a screen shows when it has nothing to list yet (design/components/EmptyState).
///
/// - The kiwi mark on a `paper` tile with `radius-xl` and `shadow-1` (the preview's `.mark`), a [title] in the `title` style,
///   one [sentence] in `ink-muted` and one filled [Button].
/// - The sentence says how the screen gets filled; the button does the first step.
/// - Centred, at most [maxWidth] wide. No animation, so nothing changes with reduced motion or
///   transparency.
/// - Not for errors.
/// - When the action needs the host and the host cannot be reached, pass [onAction] null and say why in
///   [disabledReason]: the button is disabled and the reason sits under it in `caption` (platforms.md:
///   "Actions that need the host are disabled with a reason next to them").
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.sentence,
    required this.actionLabel,
    required this.onAction,
    this.disabledReason,
  });

  /// What is missing, in sentence case ("No photos yet").
  final String title;

  /// One sentence that says how the screen gets filled.
  final String sentence;

  /// The button's label: the first step, as a verb and its object ("Import photos").
  final String actionLabel;

  /// The first step. Null disables the button.
  final VoidCallback? onAction;

  /// Why the button is disabled ("The host cannot be reached."). Shown under the button only while
  /// [onAction] is null.
  final String? disabledReason;

  /// Spec: "Centred, at most 400px wide."
  static const maxWidth = 400.0;

  /// The preview's `.mark`: 96px square.
  static const tileSize = 96.0;

  /// The preview's `.mark img{width:72px}`: the kiwi is 72px wide (about 62px tall), three quarters of the tile.
  static const markWidth = 72.0;

  /// The preview's column gap (12px).
  static double gap(MyDataLook look) => look.space(3);

  /// The tile-to-title and sentence-to-button gaps: the preview's 12px gap plus a 6px margin (18px), which
  /// lies halfway between `space-4` and `space-5`; `space-4` is used.
  static double wideGap(MyDataLook look) => look.space(4);

  /// Between the disabled button and its reason.
  static double reasonGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reason = onAction == null ? disabledReason : null;
    // The Mac frame: the bare kiwi, the title, one line and the button (ContentUnavailableView).
    if (context.isSystemLook) {
      return MacEmptyState(
        title: title,
        line: sentence,
        action: Button(
          label: actionLabel,
          variant: ButtonVariant.filled,
          onPressed: onAction,
          disabledReason: disabledReason,
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Decorative, as the preview's empty alt text: the title says what the screen is.
            ExcludeSemantics(
              child: Container(
                width: tileSize,
                height: tileSize,
                alignment: Alignment.center,
                // The preview's `.mark`: `border-radius:28px`, which is `radius-xl`.
                decoration:
                    BoxDecoration(color: c.paper, borderRadius: MyDataRadii.xl(context.look), boxShadow: context.shadows.shadow1),
                child: const KiwiMark(height: markWidth / KiwiMark.aspect, semanticLabel: null),
              ),
            ),
            SizedBox(height: wideGap(context.look)),
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: context.type(MyDataTypeRole.title).copyWith(color: c.ink)),
            ),
            SizedBox(height: gap(context.look)),
            Text(sentence, textAlign: TextAlign.center, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
            SizedBox(height: wideGap(context.look)),
            Button(label: actionLabel, variant: ButtonVariant.filled, onPressed: onAction),
            if (reason != null) ...[
              SizedBox(height: reasonGap(context.look)),
              Text(reason, textAlign: TextAlign.center, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
