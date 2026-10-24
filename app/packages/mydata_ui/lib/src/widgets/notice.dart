import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'button.dart';
import 'pressable.dart' show MyDataRadii;

/// The two kinds of [Notice] (design/components/Notice).
enum NoticeTone {
  /// A limit on what is shown ("myData reads events from this Mac between ..."). An `info` outline icon.
  info,

  /// The user must act ("myData is not allowed to read this Mac's calendars ..."). A `warning` outline icon.
  warning;

  /// The icon at the notice's start.
  MyDataIcon get icon => switch (this) {
        info => MyDataIcon.info,
        warning => MyDataIcon.warning,
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
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.symmetric(horizontal: look.space(4), vertical: look.space(3));

  /// Between the icon and the words, and between the words and the button (the preview's 12px gap).
  static double gap(MyDataLook look) => look.space(3);

  /// How far the button reaches into the well's padding above, below and at the end (the preview's -8px).
  static double actionBleed(MyDataLook look) => look.space(2);

  /// Between a notice and the list or grid it is about.
  static double contentGap(MyDataLook look) => look.space(4);

  /// Between two notices, one per source.
  static double stackGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = actionLabel;
    final icon = ExcludeSemantics(child: Icon(context.icon(tone.icon), size: context.density.icon, color: tone.iconColor(c)));
    final words = ExcludeSemantics(child: Text(message, style: context.type(MyDataTypeRole.body).copyWith(color: c.ink)));
    Widget content;
    if (label == null) {
      content = Padding(
        padding: padding(context.look),
        child: Row(children: [icon, SizedBox(width: gap(context.look)), Expanded(child: words)]),
      );
    } else {
      final button = Button(label: label, variant: ButtonVariant.plain, onPressed: onAction);
      // The button reaches into the well's padding by the bleed: the well's padding shrinks by it and the
      // words get it back, so the words sit exactly where they would without a button.
      final bled = EdgeInsetsDirectional.fromSTEB(
          context.space(4), context.space(3) - actionBleed(context.look), context.space(4) - actionBleed(context.look), context.space(3) - actionBleed(context.look));
      content = Padding(
        padding: bled,
        child: Row(children: [
          icon,
          SizedBox(width: gap(context.look)),
          Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: actionBleed(context.look)), child: words)),
          SizedBox(width: gap(context.look)),
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
        decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.md(context.look)),
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
      padding: EdgeInsets.only(bottom: Notice.contentGap(context.look)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notices.length; i++) ...[
            if (i > 0) SizedBox(height: Notice.stackGap(context.look)),
            notices[i],
          ],
        ],
      ),
    );
  }
}
