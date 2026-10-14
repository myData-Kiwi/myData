import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'icon_tile.dart';
import 'pressable.dart';
import 'status.dart';

/// An on or off setting that takes effect immediately (design/components/Switch), as a control on its own.
///
/// - Off: a `surface-sunken` track with a `line-strong` border and thumb. On: an `accent` track with an
///   `on-accent` thumb.
/// - The thumb slides over `fast` with the `standard` curve; with reduced motion it jumps. The colours change
///   over `fast`.
/// - The track is 50 by 30; the target around it, for pointers and for assistive technology alike, is at
///   least `control-height` (44px) tall, and the focus ring follows the track.
/// - [onChanged] null disables it: 45% opacity, not focusable, announced as disabled.
///
/// A switch usually sits at the right end of a row in a grouped list; use [SwitchRow] for that, which makes
/// the whole row the target. Use [MyDataSwitch] alone only where there is no row to hold it.
class MyDataSwitch extends StatelessWidget {
  const MyDataSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// Whether the setting is on.
  final bool value;

  /// Called with the new value when the user flips the switch. Null disables it.
  final ValueChanged<bool>? onChanged;

  /// The setting's name, in sentence case ("Group photos by face"): a switch alone has no visible label.
  final String semanticLabel;

  final FocusNode? focusNode;
  final bool autofocus;

  // MergeSemantics outside the padding: the one node VoiceOver and Switch Control use covers the padded
  // 44px target, not only the drawn track.
  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: _TargetPadding(
          child: Pressable(
            onPressed: onChanged == null ? null : () => onChanged!(!value),
            borderRadius: MyDataRadii.pill,
            focusNode: focusNode,
            autofocus: autofocus,
            semanticLabel: semanticLabel,
            button: false,
            toggled: value,
            child: SwitchTrack(value: value),
          ),
        ),
      );
}

/// The drawn switch (track and thumb) with no behaviour of its own, for a row that is itself the target
/// ([SwitchRow]). It excludes itself from semantics: the row announces the state.
class SwitchTrack extends StatelessWidget {
  const SwitchTrack({super.key, required this.value});

  final bool value;

  /// Preview: `.sw input{width:50px;height:30px}`.
  static const width = 50.0;
  static const height = 30.0;

  /// Preview: `border:1px solid`.
  static const borderWidth = 1.0;

  /// Preview: `.sw input::after{width:22px;height:22px}`.
  static const thumbSize = 22.0;

  /// Preview: the thumb sits 3px inside the border (`top:3px;left:3px`) and moves 20px when on.
  static const thumbInset = 3.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: MyDataMotion.fast,
        curve: MyDataMotion.standard,
        width: width,
        height: height,
        padding: const EdgeInsets.all(thumbInset),
        decoration: BoxDecoration(
          color: value ? c.accent : c.surfaceSunken,
          borderRadius: MyDataRadii.pill,
          border: Border.all(color: value ? c.accent : c.lineStrong, width: borderWidth),
        ),
        child: AnimatedAlign(
          // Movement: slides over `fast`; with reduced motion it jumps.
          duration: reduced ? Duration.zero : MyDataMotion.fast,
          curve: MyDataMotion.standard,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: MyDataMotion.fast,
            curve: MyDataMotion.standard,
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(color: value ? c.onAccent : c.lineStrong, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// A grouped-list row holding a setting and its switch (design/components/Switch and GroupedList). The
/// whole row is the target.
///
/// - At least `row-height` tall, padded `space-4` across and `space-2` down, `space-3` between its parts:
///   an optional [IconTile], the [title] in `body-strong` over the [description] in `caption` and
///   `ink-muted`, and the switch at the right end.
/// - Hovering or pressing fills the row with `surface-hover`; it does not shrink. Keyboard focus draws the
///   focus ring around [borderRadius]; Enter and Space flip it.
/// - It has no background and no divider, so a grouped list can stack it with its other rows and clip it
///   to the group's corners. Pass the group's corner shape as [borderRadius] for the first and last rows.
/// - [onChanged] null disables it: the whole row at 45% opacity.
/// - If turning it on starts something large, such as a multi-gigabyte download, the [description] says so.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.icon,
    this.tone = MyDataTone.accent,
    this.borderRadius = BorderRadius.zero,
    this.focusNode,
    this.autofocus = false,
  });

  /// The setting's name, in sentence case.
  final String title;

  /// One sentence on what it does, and on any large cost of turning it on.
  final String description;

  /// Whether the setting is on.
  final bool value;

  /// Called with the new value when the user flips the row. Null disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional icon on an [IconTile] at the left. The icon set is not drawn yet; pass a Material outlined
  /// or rounded icon.
  final IconData? icon;

  /// The tile's tint; [MyDataTone.neutral] is the untinted `surface-sunken` tile.
  final MyDataTone tone;

  /// The shape of the hover fill and the focus ring. Square by default, for rows inside a group.
  final BorderRadius borderRadius;

  final FocusNode? focusNode;
  final bool autofocus;

  /// GroupedList row geometry: `space-4` across, `space-2` down, `space-3` between parts.
  static const padding = EdgeInsets.symmetric(horizontal: MyDataSpace.s4, vertical: MyDataSpace.s2);
  static const gap = MyDataSpace.s3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Pressable(
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: borderRadius,
        hoverFill: c.surfaceHover,
        scaleOnPress: false,
        focusNode: focusNode,
        autofocus: autofocus,
        button: false,
        toggled: value,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
          child: Padding(
            padding: padding,
            child: Row(children: [
              if (icon != null) ...[
                IconTile(icon: icon!, tone: tone),
                const SizedBox(width: gap),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
                    Text(description, style: MyDataType.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              SwitchTrack(value: value),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Makes the switch's target at least `control-height` square-ish without growing the drawn track or its
/// focus ring: taps in the padding go to the track (as Material's padded tap target does).
class _TargetPadding extends SingleChildRenderObjectWidget {
  const _TargetPadding({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTargetPadding();
}

class _RenderTargetPadding extends RenderShiftedBox {
  _RenderTargetPadding() : super(null);

  static const _min = MyDataSize.controlHeight;

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(Size(math.max(child.size.width, _min), math.max(child.size.height, _min)));
    (child.parentData! as BoxParentData).offset = Alignment.center.alongOffset(size - child.size as Offset);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final s = child!.getDryLayout(constraints.loosen());
    return constraints.constrain(Size(math.max(s.width, _min), math.max(s.height, _min)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (super.hitTest(result, position: position)) return true;
    final center = child!.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(center),
      position: center,
      hitTest: (result, position) => child!.hitTest(result, position: center),
    );
  }
}
