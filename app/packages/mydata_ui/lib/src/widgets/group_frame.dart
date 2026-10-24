import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'edges.dart';
import 'pressable.dart' show MyDataRadii;
import 'role_label.dart';

// Not exported from the package: the one implementation of the grouped-list look, shared by GroupedList
// and GroupedSection.

/// Draws a group: the optional heading above it, outside, in `label` and `ink-muted`; then the parts on
/// `surface` with `radius-lg` and `shadow-1`, each separated from the next by the theme's separator (Kiwi: a
/// full-width 1px `line` divider, and no border), with the theme's card outline over them ([CardEdge]). Each part gets its corner shape within the group through [GroupPartShape].
///
/// [plain] (a GroupedList in the Mac frame, plan section 5 "Lists are lists"): no card, no dividers; the
/// heading in `caption-emphasized` and `secondary-label`, lined up with the rows' text; each part's shape is
/// the `selection` radius, inset `row-inset` from the sides.
class GroupFrame extends StatelessWidget {
  const GroupFrame({super.key, this.heading, this.headingHoldsName = false, required this.parts, this.plain = false});

  final String? heading;

  /// The [heading] is a name (an account, a calendar) and keeps its own case ([RoleLabel]).
  final bool headingHoldsName;
  final List<Widget> parts;
  final bool plain;

  /// Preview: `.r{border-top:1px solid var(--line)}`. Kiwi's; a theme's separators are
  /// [MyDataEdges.separatorExtent] tall ([EdgeRule]), and lists that count their rows ahead keep this slot.
  static const dividerWidth = 1.0;

  /// Where a row's text starts, and so an `inset` separator below it: the row's padding, then, when it
  /// [lead]s with an icon tile, an avatar or a checkbox (all `icon-tile` wide), the tile and the gap.
  static double textStart(MyDataLook look, {bool lead = false}) =>
      look.space(4) + (lead ? look.density.iconTile + look.space(3) : 0);

  /// Preview: `.lbl{margin:0 0 8px 6px}`: `space-2` below; 6px in, snapped to `space-2`.
  static EdgeInsets headingPadding(MyDataLook look) => EdgeInsets.only(left: look.space(2), bottom: look.space(2));

  Widget _plain(BuildContext context) {
    final mac = context.mac;
    const shape = BorderRadius.all(Radius.circular(MyDataMacRadius.selection));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null)
          Container(
            height: MyDataMacSize.sectionHeight,
            alignment: AlignmentDirectional.bottomStart,
            padding: EdgeInsetsDirectional.only(
                start: MyDataMacSize.rowInset + MyDataMacSize.rowPadding, bottom: context.space(1)),
            child: Semantics(
              header: true,
              child: Text(heading!, style: MyDataMacType.captionEmphasized.copyWith(color: mac.secondaryLabel)),
            ),
          ),
        for (final part in parts)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset),
            child: GroupPartShape(borderRadius: shape, child: part),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (plain) return _plain(context);
    final c = context.colors;
    final top = BorderRadius.vertical(top: Radius.circular(context.radius.lg));
    final bottom = BorderRadius.vertical(bottom: Radius.circular(context.radius.lg));
    BorderRadius shapeOf(int i) {
      if (parts.length == 1) return MyDataRadii.lg(context.look);
      if (i == 0) return top;
      if (i == parts.length - 1) return bottom;
      return BorderRadius.zero;
    }

    // Not clipped: each part takes the group's corners itself, so a row's selected fill and hover fill
    // follow them and a focus ring, drawn 2px outside, is not cut off at the group's edge.
    final group = DecoratedBox(
      decoration: context.radius.decorate(BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1)),
      child: CardEdge(
        radius: MyDataRadii.lg(context.look),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              // Under each row, from where that row's text starts (as iOS lists do).
              if (i > 0)
                EdgeRule(
                  inCard: true,
                  inset: textStart(context.look, lead: parts[i - 1] is LeadingTile && (parts[i - 1] as LeadingTile).hasLeadingTile),
                ),
              GroupPartShape(borderRadius: shapeOf(i), child: parts[i]),
            ],
          ],
        ),
      ),
    );
    if (heading == null) return group;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headingPadding(context.look),
          child: Semantics(
            header: true,
            child: RoleLabel(heading!, color: c.inkMuted, holdsName: headingHoldsName),
          ),
        ),
        group,
      ],
    );
  }
}

/// A part of a group that may start with a tile (an icon tile, an avatar, a checkbox): an `inset` separator
/// below it then starts where its text does ([GroupFrame.textStart]).
abstract interface class LeadingTile {
  bool get hasLeadingTile;
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
