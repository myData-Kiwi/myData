import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout;
import 'button.dart';
import 'kiwi.dart';
import 'pressable.dart';

/// The states of a [DropZone] (design/components/DropZone, "States").
enum DropZoneState {
  /// Waiting for a file: the tile, the instruction, the caption and "Choose file…".
  idle,

  /// Files are being dragged over the page the zone is on: `accent-soft` with a 2px `accent` line inside
  /// its edge, and the instruction says what a drop does ("Drop to import contacts-2026-10-14.vcf").
  dragging,

  /// A file is being read: the loading slice in the tile's place, "Reading" and the file name, and Cancel.
  reading,

  /// The last file could not be used: the caption is replaced by the error in `danger`, the tile shows the
  /// `warning` outline on `warning-soft`.
  error,

  /// The host cannot be reached: the tile, instruction and button at 45%, the caption is the reason.
  disabled,
}

/// A place on a page that takes files dropped from the Finder or Explorer, with a button that opens the
/// system's file chooser for the same thing (design/components/DropZone).
///
/// - A `surface-sunken` well on `bg` with `radius-lg`, as wide as it is given (the reading column),
///   `space-8` padding down and `space-6` across, its content centred: an `icon-tile` with an outline
///   "tray with an arrow" (`accent` on `accent-soft`); `space-3` under it the [instruction] in `body-strong`
///   and `ink`; `space-1` under it the [caption] in `caption` and `ink-muted`; `space-4` under it the
///   [chooseLabel] button, Filled where it is the page's main action ([filled]), Tonal elsewhere. No border
///   and no dashed line: the sunken well is the shape.
/// - The zone draws its states; the page it is on takes the drop (the whole page accepts files while they
///   are dragged over the window, so a drop a little off target is not lost) and sets [state].
/// - **Dragging:** the fill becomes `accent-soft` with a 2px `accent` line inside the edge, over `fast`; the
///   instruction becomes "Drop to import [dragName]", or "Drop to import" when the platform does not say
///   the file's name before the drop, so the state never relies on colour.
/// - **Reading:** the tile becomes the loading slice, the instruction "Reading `readingName`…", the caption
///   [readingCaption], and the button "Cancel" (plain, [onCancel]).
/// - **Error:** the caption becomes [error] in `body` and `danger`; the tile's icon becomes the `warning`
///   outline on `warning-soft`. With [onRetry] (the host did not answer) a tonal "Try again" sits beside
///   the button and sends the same file again.
/// - **Disabled:** the tile, instruction and button at 45% opacity; the caption, in full `ink-muted`, is the
///   [disabledReason]. The button leaves the Tab order, since its reason is visible.
/// - **Under 600px** there is nothing to drop from: no instruction; the tile, the caption and the button.
/// - Screen readers: the well is a group named by its instruction, described by its caption.
class DropZone extends StatelessWidget {
  const DropZone({
    super.key,
    required this.instruction,
    required this.caption,
    required this.onChoose,
    this.chooseLabel = defaultChooseLabel,
    this.state = DropZoneState.idle,
    this.dragName,
    this.readingName,
    this.readingCaption = defaultReadingCaption,
    this.onCancel,
    this.error,
    this.onRetry,
    this.disabledReason,
    this.filled = true,
    this.chooseFocusNode,
    this.retryFocusNode,
    this.cancelFocusNode,
  }) : assert(state != DropZoneState.error || error != null, 'an error state says what is wrong'),
       assert(state != DropZoneState.disabled || disabledReason != null, 'a disabled zone says why');

  /// Names the file types the user knows: "Drop a .vcf or .zip file here".
  final String instruction;

  /// Where such files come from and the size limit.
  final String caption;

  /// Opens the system's own file chooser.
  final VoidCallback onChoose;

  /// "Choose file…" ("Choose files…" only where several are taken).
  final String chooseLabel;

  final DropZoneState state;

  /// The dragged file's name, when the platform gives it before the drop.
  final String? dragName;

  /// The file being read.
  final String? readingName;

  /// Under "Reading …": the host reports no progress, so this says how long it can take.
  final String readingCaption;

  /// Cancel while reading: back to idle at once.
  final VoidCallback? onCancel;

  /// The error sentence: names the file, says what is wrong and gives one next step.
  final String? error;

  /// "Try again" (tonal), beside the button, when the host did not answer: sends the same file.
  final VoidCallback? onRetry;

  /// Why the zone takes nothing now, a full sentence.
  final String? disabledReason;

  /// The button is Filled where the zone is the page's main action (Import's Choose step), Tonal elsewhere.
  final bool filled;

  final FocusNode? chooseFocusNode;
  final FocusNode? retryFocusNode;
  final FocusNode? cancelFocusNode;

  static const defaultChooseLabel = 'Choose file…';
  static const defaultReadingCaption = 'A large file takes up to half a minute.';
  static const cancelLabel = 'Cancel';
  static const retryLabel = 'Try again';
  static const dropLabel = 'Drop to import';

  /// Spec: "`space-8` padding down and `space-6` across".
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(6), vertical: look.space(8));

  /// Spec: "a 2px `accent` line drawn inside its edge" while dragging.
  static const dragLineWidth = 2.0;

  /// The instruction for [state].
  String instructionText() => switch (state) {
        DropZoneState.dragging => dragName == null ? dropLabel : '$dropLabel $dragName',
        DropZoneState.reading => 'Reading ${readingName ?? 'the file'}…',
        _ => instruction,
      };

  /// The caption line for [state] (the error in an error state).
  String captionText() => switch (state) {
        DropZoneState.reading => readingCaption,
        DropZoneState.error => error!,
        DropZoneState.disabled => disabledReason!,
        _ => caption,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = AppLayout.isPhone(context);
    final dragging = state == DropZoneState.dragging;
    final disabled = state == DropZoneState.disabled;
    Widget faded(Widget w) => disabled ? Opacity(opacity: Pressable.disabledOpacity, child: w) : w;

    final Widget tile = switch (state) {
      DropZoneState.reading => KiwiLoader(size: context.density.iconTile, semanticLabel: 'Reading'),
      DropZoneState.error => _Tile(icon: Icons.warning_amber_rounded, fill: c.warningSoft, ink: c.warning),
      _ => _Tile(icon: Icons.move_to_inbox_outlined, fill: c.accentSoft, ink: c.accent),
    };

    final instructionText = this.instructionText();
    final captionText = this.captionText();
    final captionStyle = state == DropZoneState.error
        ? context.typeScale.body.copyWith(color: c.danger)
        : context.typeScale.caption.copyWith(color: c.inkMuted);

    final Widget buttons = switch (state) {
      DropZoneState.reading => Button(
          label: cancelLabel,
          variant: ButtonVariant.plain,
          focusNode: cancelFocusNode,
          onPressed: onCancel,
        ),
      _ => ButtonRow(alignment: WrapAlignment.center, children: [
          Button(
            label: chooseLabel,
            variant: filled ? ButtonVariant.filled : ButtonVariant.tonal,
            focusNode: chooseFocusNode,
            onPressed: disabled ? null : onChoose,
          ),
          if (state == DropZoneState.error && onRetry != null)
            Button(label: retryLabel, focusNode: retryFocusNode, onPressed: onRetry),
        ]),
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        faded(tile),
        if (!phone || state == DropZoneState.reading) ...[
          SizedBox(height: context.space(3)),
          faded(ExcludeSemantics(
            child: Text(instructionText,
                textAlign: TextAlign.center, style: context.typeScale.bodyStrong.copyWith(color: c.ink)),
          )),
          SizedBox(height: context.space(1)),
        ] else
          SizedBox(height: context.space(3)),
        Semantics(
          liveRegion: state == DropZoneState.error,
          child: ExcludeSemantics(
            excluding: state != DropZoneState.error,
            child: Text(captionText, textAlign: TextAlign.center, style: captionStyle),
          ),
        ),
        SizedBox(height: context.space(4)),
        faded(buttons),
      ],
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: phone && state != DropZoneState.reading ? null : instructionText,
      hint: state == DropZoneState.error ? null : captionText,
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.standard,
        width: double.infinity,
        padding: padding(context.look),
        decoration: BoxDecoration(
          color: dragging ? c.accentSoft : c.surfaceSunken,
          borderRadius: MyDataRadii.lg(context.look),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: MyDataRadii.lg(context.look),
          border: Border.all(
            color: dragging ? c.accent : c.accent.withValues(alpha: 0),
            width: dragLineWidth,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: content,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.fill, required this.ink});
  final IconData icon;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
        width: context.density.iconTile,
        height: context.density.iconTile,
        decoration: BoxDecoration(color: fill, borderRadius: MyDataRadii.sm(context.look)),
        alignment: Alignment.center,
        child: Icon(icon, size: context.density.icon, color: ink),
      );
}
