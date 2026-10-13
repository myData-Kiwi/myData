import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'app_frame.dart';
import 'button.dart';

/// One screen of an app inside the [AppFrame]: a big title, its actions, and the screen's sections in a
/// scrolling column (design/README.md "Shape, depth and space", design/platforms.md "Window layouts").
///
/// - Padding `space-8` on desktop and tablets, `space-4` on phones (under 600px), plus any safe-area or
///   floating-bar inset from MediaQuery, so the last section clears a phone's tab bar.
/// - The [title] is `display-lg` on desktop. On a phone the large title is the app's name, which the
///   [AppFrame] shows above the page ([AppFrame.phoneAppNameOf]); the [title] is then the section's name in
///   the `title` style, left out when it is the app name. A page on a phone with no frame above it shows
///   the [title] as the large title, in `display-xl`.
/// - [actions], usually tonal or plain buttons, sit at the end of the title row (under the title on phones).
///   When they do not fit beside the title they wrap, right-aligned, keeping at least a third of the row for
///   the title.
/// - The first section is `space-6` under the title row ([titleGap]); sections are `space-4` apart ([gap]),
///   as cards are everywhere. The column stops at `content-max`; [fullWidth] lets photo grids and calendars
///   use the whole width.
/// - Children are cards, grouped lists and the like, laid side by side with CardGrid where needed. Never
///   put a card in a card.
/// - Scrolls with the platform's physics and scroll bars. Children are laid out in full (not lazily); a long
///   list belongs in its own scrolling view instead.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.children,
    this.fullWidth = false,
  });

  /// In sentence case: "Library", "Settings".
  final String title;

  /// Buttons for the whole screen. At most one filled button on a screen.
  final List<Widget> actions;

  final List<Widget> children;

  /// True for photo grids and calendars; false stops the column at `content-max`.
  final bool fullWidth;

  /// Between sections: `space-4`, the same as between cards (design/README.md, CardGrid.gap).
  static const gap = MyDataSpace.s4;

  /// Between the title row and the first section.
  static const titleGap = MyDataSpace.s6;

  /// Between the title and its actions.
  static const actionsGap = MyDataSpace.s4;

  /// The share of the title row the actions may take before they wrap, so a long set of actions never
  /// squeezes the title to nothing.
  static const actionsMaxShare = 2 / 3;

  /// The screen padding for [layout]: `space-8`, or `space-4` on phones.
  static double paddingFor(AppLayout layout) => layout == AppLayout.phone ? MyDataSpace.s4 : MyDataSpace.s8;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = AppLayout.of(context);
    final phone = layout == AppLayout.phone;
    final pad = paddingFor(layout);
    final insets = MediaQuery.paddingOf(context);
    final frameName = AppFrame.phoneAppNameOf(context);

    // Under a phone frame the app name is the large title, so the section's name is smaller, or left out.
    final TextStyle titleStyle;
    if (frameName != null) {
      titleStyle = MyDataType.title;
    } else {
      titleStyle = phone ? MyDataType.displayXl : MyDataType.displayLg;
    }
    final Widget? heading = frameName == title
        ? null
        : Semantics(header: true, child: Text(title, style: titleStyle.copyWith(color: c.ink)));

    final Widget? top;
    if (actions.isEmpty) {
      top = heading;
    } else if (heading == null) {
      top = ButtonRow(children: actions);
    } else if (phone || frameName != null) {
      top = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        heading,
        const SizedBox(height: actionsGap),
        ButtonRow(children: actions),
      ]);
    } else {
      top = LayoutBuilder(builder: (context, constraints) {
        // A Wrap in a Row has no width to wrap at; cap it so the actions wrap instead of overflowing.
        final actionsMax = (constraints.maxWidth - actionsGap) * actionsMaxShare;
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: heading),
          const SizedBox(width: actionsGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: actionsMax < 0 ? 0 : actionsMax),
            child: ButtonRow(alignment: WrapAlignment.end, children: actions),
          ),
        ]);
      });
    }

    Widget column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ?top,
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0)
          const SizedBox(height: gap)
        else if (top != null)
          const SizedBox(height: titleGap),
        children[i],
      ],
    ]);
    if (!fullWidth) {
      column = Align(
        alignment: AlignmentDirectional.topStart,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax), child: column),
      );
    }
    return DefaultTextStyle.merge(
      style: MyDataType.body.copyWith(color: c.ink),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            pad + insets.left, pad + insets.top, pad + insets.right, pad + insets.bottom),
        child: column,
      ),
    );
  }
}
