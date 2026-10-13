import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import 'pressable.dart' show MyDataRadii;

// Not exported from the package: the one implementation of the grouped-list look, shared by GroupedList
// and GroupedSection.

/// Draws a group: the optional heading above it, outside, in `label` and `ink-muted`; then the parts on
/// `surface` with `radius-lg` and `shadow-1`, no border, each separated from the next by a full-width 1px
/// `line` divider. Each part gets its corner shape within the group through [GroupPartShape].
class GroupFrame extends StatelessWidget {
  const GroupFrame({super.key, this.heading, required this.parts});

  final String? heading;
  final List<Widget> parts;

  /// Preview: `.r{border-top:1px solid var(--line)}`.
  static const dividerWidth = 1.0;

  /// Preview: `.lbl{margin:0 0 8px 6px}`: `space-2` below; 6px in, snapped to `space-2`.
  static const headingPadding = EdgeInsets.only(left: MyDataSpace.s2, bottom: MyDataSpace.s2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const top = BorderRadius.vertical(top: Radius.circular(MyDataRadius.lg));
    const bottom = BorderRadius.vertical(bottom: Radius.circular(MyDataRadius.lg));
    BorderRadius shapeOf(int i) {
      if (parts.length == 1) return MyDataRadii.lg;
      if (i == 0) return top;
      if (i == parts.length - 1) return bottom;
      return BorderRadius.zero;
    }

    // Not clipped: each part takes the group's corners itself, so a row's selected fill and hover fill
    // follow them and a focus ring, drawn 2px outside, is not cut off at the group's edge.
    final group = DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg, boxShadow: context.shadows.shadow1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0) Container(height: dividerWidth, color: c.line),
            GroupPartShape(borderRadius: shapeOf(i), child: parts[i]),
          ],
        ],
      ),
    );
    if (heading == null) return group;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headingPadding,
          child: Semantics(
            header: true,
            child: Text(heading!, style: MyDataType.label.copyWith(color: c.inkMuted)),
          ),
        ),
        group,
      ],
    );
  }
}

/// Passes a part its corner shape within the group (square in the middle, rounded at the ends).
class GroupPartShape extends InheritedWidget {
  const GroupPartShape({super.key, required this.borderRadius, required super.child});
  final BorderRadius borderRadius;

  /// The shape of the part around [context]; square outside a group.
  static BorderRadius of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupPartShape>()?.borderRadius ?? BorderRadius.zero;

  @override
  bool updateShouldNotify(GroupPartShape old) => old.borderRadius != borderRadius;
}
