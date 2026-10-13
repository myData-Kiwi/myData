import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'button.dart';
import 'pressable.dart' show MyDataRadii;

/// The two kinds of [Notice] (design/components/Notice).
enum NoticeTone {
  /// A limit on what is shown ("myData reads events from this Mac between ..."). An `info` outline icon.
  info,

  /// The user must act ("myData is not allowed to read this Mac's calendars ..."). A `warning` outline icon.
  warning;

  /// The outline icon at the notice's start. The icon set is not drawn yet; these are Material outlines.
  IconData get icon => switch (this) {
        info => Icons.info_outline_rounded,
        warning => Icons.warning_amber_rounded,
      };

  /// The icon's colour: the tone's strong colour.
  Color iconColor(MyDataColors c) => switch (this) {
        info => c.info,
        warning => c.warning,
      };
}

/// One or two plain sentences above a list or grid that say what it cannot show, such as the dates myData
/// reads from a source (design/components/Notice).
///
/// - A `surface-sunken` well with `radius-md`, `space-3` padding down and `space-4` across, as wide as the
///   width it is given (the content it is about). It sits on `bg`, [Notice.contentGap] above that content;
///   several notices are [Notice.stackGap] apart. [NoticeStack] lays both out.
/// - At its start, an outline icon at `icon` size in the [tone]'s colour; the [message] follows in `body` and
///   `ink`, `space-3` from the icon. Icon, words and button are centred on one another.
/// - With [actionLabel] and [onAction], a [ButtonVariant.plain] button at its end, `space-3` after the words,
///   for the one next step. It names where it leads ("Open myData", "Open System Settings"); the sentence
///   before it says what to do there. Never filled: the screen's main action stays the main one. The button
///   bleeds `space-2` into the well's padding (the preview's `margin:-8px -8px -8px 0`), so a one-line notice
///   with a button is only as tall as its 44px button plus `space-1` above and below. The button keeps its
///   width at every width; on a narrow screen the words wrap to more lines beside it (the preview's
///   `flex:none` button and `flex:1; min-width:0` words).
/// - It cannot be dismissed, and it does not animate, so nothing changes with reduced motion.
/// - Screen readers hear it politely when it appears or its words change (a live region whose label is the
///   [message]). The icon is decoration: the words carry the meaning, and the tone is never the only signal.
/// - Wording is about reading, never keeping: "reads", "not shown", never "kept".
/// - Not for errors (a host that cannot be reached is the app frame's warning line) and not for screens with
///   nothing to list yet (EmptyState).
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.message,
    this.tone = NoticeTone.info,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null), 'An action needs both a label and a callback.');

  /// One or two plain sentences, in sentence case.
  final String message;

  /// [NoticeTone.info] for a limit on what is shown, [NoticeTone.warning] when the user must act.
  final NoticeTone tone;

  /// The plain button's label: where it leads ("Open myData"). Null for no button.
  final String? actionLabel;

  /// The one next step. Given exactly when [actionLabel] is.
  final VoidCallback? onAction;

  /// Spec: "`space-3` padding down, `space-4` across".
  static const padding = EdgeInsets.symmetric(horizontal: MyDataSpace.s4, vertical: MyDataSpace.s3);

  /// Between the icon and the words, and between the words and the button (the preview's 12px gap).
  static const gap = MyDataSpace.s3;

  /// How far the button reaches into the well's padding above, below and at the end (the preview's -8px).
  static const actionBleed = MyDataSpace.s2;

  /// Between a notice and the list or grid it is about.
  static const contentGap = MyDataSpace.s4;

  /// Between two notices, one per source.
  static const stackGap = MyDataSpace.s2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    final icon = ExcludeSemantics(child: Icon(tone.icon, size: MyDataSize.icon, color: tone.iconColor(c)));
    final words = ExcludeSemantics(child: Text(message, style: MyDataType.body.copyWith(color: c.ink)));
    Widget content;
    if (label == null) {
      content = Padding(
        padding: padding,
        child: Row(children: [icon, const SizedBox(width: gap), Expanded(child: words)]),
      );
    } else {
      final button = Button(label: label, variant: ButtonVariant.plain, onPressed: onAction);
      // The button reaches into the well's padding by the bleed: the well's padding shrinks by it and the
      // words get it back, so the words sit exactly where they would without a button.
      const bled = EdgeInsetsDirectional.fromSTEB(
          MyDataSpace.s4, MyDataSpace.s3 - actionBleed, MyDataSpace.s4 - actionBleed, MyDataSpace.s3 - actionBleed);
      content = Padding(
        padding: bled,
        child: Row(children: [
          icon,
          const SizedBox(width: gap),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: actionBleed), child: words)),
          const SizedBox(width: gap),
          button,
        ]),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.md),
        child: content,
      ),
    );
  }
}

/// The notices above one list or grid, one per source that needs one: [Notice.stackGap] apart, with
/// [Notice.contentGap] below the last. With no notices it takes no space, so the content does not move
/// down for a gap that has nothing above it.
class NoticeStack extends StatelessWidget {
  const NoticeStack({super.key, required this.notices});

  /// Usually [Notice]s, in the order of their sources.
  final List<Widget> notices;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Notice.contentGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notices.length; i++) ...[
            if (i > 0) const SizedBox(height: Notice.stackGap),
            notices[i],
          ],
        ],
      ),
    );
  }
}
