import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../accessibility.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout, PhoneType;
import 'icon_tile.dart';
import 'pressable.dart';
import 'status.dart';
import 'toggle_target.dart';

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
            borderRadius: MyDataRadii.pill(context.look),
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
        duration: context.motion.fast,
        curve: context.motion.standard,
        width: width,
        height: height,
        padding: const EdgeInsets.all(thumbInset),
        decoration: BoxDecoration(
          color: value ? c.accent : c.surfaceSunken,
          borderRadius: MyDataRadii.pill(context.look),
          border: Border.all(color: value ? c.accent : c.lineStrong, width: borderWidth),
        ),
        child: AnimatedAlign(
          // Movement: slides over `fast`; with reduced motion it jumps.
          duration: reduced ? Duration.zero : context.motion.fast,
          curve: context.motion.standard,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: context.motion.fast,
            curve: context.motion.standard,
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

  /// An optional icon on an [IconTile] at the left.
  final MyDataIcon? icon;

  /// The tile's tint; [MyDataTone.neutral] is the untinted `surface-sunken` tile.
  final MyDataTone tone;

  /// The shape of the hover fill and the focus ring. Square by default, for rows inside a group.
  final BorderRadius borderRadius;

  final FocusNode? focusNode;
  final bool autofocus;

  /// GroupedList row geometry: `space-4` across, `space-2` down, `space-3` between parts.
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(4), vertical: look.space(2));
  static double gap(MyDataLook look) => look.space(3);

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
          constraints: BoxConstraints(minHeight: context.density.rowHeight),
          child: Padding(
            padding: padding(context.look),
            child: Row(children: [
              if (icon != null) ...[
                IconTile(icon: icon!, tone: tone),
                SizedBox(width: gap(context.look)),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
                    Text(description, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              SizedBox(width: gap(context.look)),
              SwitchTrack(value: value),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A Switch inside a form that has Save and Cancel, such as "All-day" in an event (design/components/Switch,
/// "In a form"). It looks the same as the settings switch; it sets a value of the thing being edited, which
/// applies on Save.
///
/// - The row is a FormRow: the [title] in `body` and `ink` at the start, sentence case with no full stop,
///   and the switch at the row's end, `space-3` apart. No [description] unless the effect is not obvious
///   from the title. The whole row is the target; it is at least `control-height` tall (`row-height` under
///   600px), with the title at 16px there.
/// - Hover fills the row with `surface-hover`; a press dims it to 85%. The fill reaches [hoverOutset] past
///   the row's sides, so the title keeps the form's start edge and is not pressed against the fill's edge
///   (not in the spec; decided here).
/// - Keyboard focus draws the `focus` ring around the track. **Space** toggles it; Return is left to the
///   form. While the form waits for the host ([FormBusy]) it does not flip.
/// - [onChanged] null disables it: the title and the switch at 45%, with the [disabledReason] in a
///   `caption` line under the title in full `ink-muted`, not faded. It leaves the Tab order, since its
///   reason is visible.
/// - Screen readers: "All-day, switch, off". [announce] gives what the form changes as a result ("Start and
///   end are now dates"), announced politely once after a flip.
class FormSwitchRow extends StatelessWidget {
  const FormSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.disabledReason,
    this.announce,
    this.focusNode,
    this.autofocus = false,
  }) : assert(onChanged != null || disabledReason != null, 'a disabled switch says why (platforms.md)');

  /// The property, in sentence case ("All-day").
  final String title;
  final bool value;

  /// Called with the new value. Null disables the row; give the [disabledReason] then.
  final ValueChanged<bool>? onChanged;

  /// Only when the effect is not obvious from the title.
  final String? description;

  /// Why it cannot be changed, a full sentence ("This event comes from an invitation and cannot be changed
  /// here.").
  final String? disabledReason;

  /// What the form changes as a result of the new value, announced politely; null for nothing.
  final String? Function(bool value)? announce;

  final FocusNode? focusNode;
  final bool autofocus;

  /// Between the title and the switch (preview: `.swrow{gap:12px}`).
  static double gap(MyDataLook look) => look.space(3);

  /// How far the hover fill reaches past each side of the row.
  static double hoverOutset(MyDataLook look) => look.space(2);

  void _flip(BuildContext context) {
    final next = !value;
    onChanged!(next);
    final message = announce?.call(next);
    if (message != null) {
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    final phone = AppLayout.of(context) == AppLayout.phone;
    final note = enabled ? description : (disabledReason ?? description);
    Widget faded(Widget w) => enabled ? w : Opacity(opacity: Pressable.disabledOpacity, child: w);
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: enabled,
        child: ToggleTarget(
          onToggle: enabled ? () => _flip(context) : null,
          focusNode: focusNode,
          autofocus: autofocus,
          builder: (context, s) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: s.hovered || s.pressed ? c.surfaceHover : c.surfaceHover.withValues(alpha: 0)),
            duration: context.motion.fast,
            curve: context.motion.standard,
            builder: (context, fill, child) =>
                CustomPaint(painter: _OutsetFill(color: fill!, outset: hoverOutset(context.look), radius: context.radius.sm), child: child),
            child: AnimatedOpacity(
              opacity: s.pressed ? context.motion.pressOpacity : 1,
              duration: s.pressed ? Duration.zero : context.motion.fast,
              curve: context.motion.standard,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: phone ? context.density.rowHeight : context.density.controlHeight),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        faded(Text(title, style: PhoneType.body(context.typeScale.body, phone: phone).copyWith(color: c.ink))),
                        if (note != null) Text(note, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  SizedBox(width: gap(context.look)),
                  faded(FocusRing(visible: s.focused, borderRadius: MyDataRadii.pill(context.look), child: SwitchTrack(value: value))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The form switch row's hover fill: `radius-sm`, reaching [outset] past the row's start and end.
class _OutsetFill extends CustomPainter {
  _OutsetFill({required this.color, required this.outset, required this.radius});
  final Color color;
  final double outset;

  /// `radius-sm`.
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final rect = Rect.fromLTRB(-outset, 0, size.width + outset, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OutsetFill old) => old.color != color || old.outset != outset || old.radius != radius;
}

/// Makes the switch's target at least `control-height` square-ish without growing the drawn track or its
/// focus ring: taps in the padding go to the track (as Material's padded tap target does).
class _TargetPadding extends SingleChildRenderObjectWidget {
  const _TargetPadding({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTargetPadding(context.density.controlHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderTargetPadding renderObject) =>
      renderObject.minSide = context.density.controlHeight;
}

class _RenderTargetPadding extends RenderShiftedBox {
  _RenderTargetPadding(this._min) : super(null);

  /// `control-height`.
  double _min;
  set minSide(double value) {
    if (value == _min) return;
    _min = value;
    markNeedsLayout();
  }

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
