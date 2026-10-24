import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'action_row.dart';
import 'group_frame.dart';
import 'grouped_list.dart';
import 'status.dart';
import 'role_label.dart';

/// A grouped list whose parts are not all rows: a picker, a short form or a note sits in the same group as
/// the rows, with the same dividers (design/components/GroupedSection).
///
/// - The group is a [GroupedList]'s: `surface`, `radius-lg`, `shadow-1`, no border, with the [heading] in
///   `label` and `ink-muted` above it, outside (a semantics header).
/// - [parts], top to bottom: [GroupedRow]s, [ActionRow]s and [GroupedContentPart]s. Every part is
///   separated from the next by a full-width `line` divider, as rows are.
/// - At most one filled button in the whole section; other actions are tonal or plain. Never a card inside
///   it: a theme sample is an illustration of a screen, not a card.
/// - The three-tile-tone rule counts every row in it: it asserts in debug builds that its rows with icons
///   use at most [GroupedList.maxTileTones] tones.
/// - Use a [GroupedList] when every part is a row; use this when one part is not.
class GroupedSection extends StatelessWidget {
  GroupedSection({super.key, this.heading, this.headingHoldsName = false, required this.parts})
    : assert(parts.isNotEmpty, 'a grouped section has at least one part'),
      assert(
        _tileTones(parts).length <= GroupedList.maxTileTones,
        'use at most ${GroupedList.maxTileTones} different tile tones on one screen (design/README.md "Colour")',
      );

  /// The small heading above the group, in sentence case ("Appearance"). Null for none, as a [GroupedList]
  /// may have none (an import's Done list).
  final String? heading;

  /// The [heading] is a name (an account, a calendar) and keeps its own case ([RoleLabel]).
  final bool headingHoldsName;

  /// The parts, top to bottom.
  final List<Widget> parts;

  /// The distinct tinted tile tones among [parts]' rows that show an icon tile (the untinted
  /// `surface-sunken` tile is no colour).
  static Set<MyDataTone> _tileTones(List<Widget> parts) => {
    for (final p in parts)
      if (p is GroupedRow && p.icon != null) p.tone else if (p is ActionRow && p.icon != null) p.tone,
  }..remove(MyDataTone.neutral);

  @override
  Widget build(BuildContext context) =>
      GroupFrame(heading: heading, headingHoldsName: headingHoldsName, parts: parts);
}

/// A part of a [GroupedSection] that is not a row: `space-5` padding, like a card, around one thing: a
/// picker (a [GroupedStack] of [GroupedControl]s and a sample), a short form (fields above one button), a
/// note in `body` and `ink-muted`, or a sample.
class GroupedContentPart extends StatelessWidget {
  const GroupedContentPart({super.key, required this.child});

  final Widget child;

  /// Spec: "A content part has `space-5` padding, like a card".
  static EdgeInsets padding(MyDataLook look) => EdgeInsets.all(look.space(5));

  @override
  Widget build(BuildContext context) => Padding(padding: padding(context.look), child: child);
}

/// A control in a [GroupedContentPart] with its name above it: [label] in the `label` style and `ink`,
/// `space-2` above the [child]. The control keeps its own accessible name (a ThemePicker's or
/// SegmentedControl's `semanticLabel`); give it the same words. The visible label is hidden from screen
/// readers, so the name is not read twice.
class GroupedControl extends StatelessWidget {
  const GroupedControl({super.key, required this.label, this.holdsName = false, required this.child});

  /// The control's name, in sentence case ("Theme", "Mode").
  final String label;

  /// The [label] is a name (an app such as myAssistant, a person, a calendar) and keeps its own case where
  /// the theme sets labels in upper case ([RoleLabel]).
  final bool holdsName;

  final Widget child;

  /// Spec: "its name above it in the `label` style, `space-2` above the control".
  static double labelGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: RoleLabel(label, color: context.colors.ink, holdsName: holdsName)),
      SizedBox(height: labelGap(context.look)),
      child,
    ],
  );
}

/// Stacks things in a [GroupedContentPart]: each under the last, `space-5` apart, aligned to the start and
/// each at its own width. Nothing sits beside a control, so no empty patch opens up under a short control.
class GroupedStack extends StatelessWidget {
  const GroupedStack({super.key, required this.children});

  final List<Widget> children;

  /// Spec: "each control under the last, `space-5` apart".
  static double gap(MyDataLook look) => look.space(5);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap(context.look)), children[i]],
    ],
  );
}
