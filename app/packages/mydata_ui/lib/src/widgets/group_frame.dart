import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'edges.dart';
import 'pressable.dart' show MyDataRadii;
import 'role_label.dart';

// Not exported from the package: the one implementation of the grouped-list look, shared by GroupedList
// and GroupedSection.

/// Draws a group in the theme's list style (`components.list`, design/themes/ARCHITECTURE.md 3.2): the
/// optional heading above it, outside, in `label` and `ink-muted`; then the parts, each separated from the
/// next by the theme's separator. Each part gets its corner shape within the group through [GroupPartShape].
///
/// - `inset` (Kiwi): the parts on `surface` with `radius-lg` and `shadow-1`, with the theme's card outline
///   over them ([CardEdge]);
/// - `bordered`: the same, always outlined ([listOutline]);
/// - `cards`: each part its own card, [cardGap] apart, no separators;
/// - `plain`: the parts on the ground, no card;
/// - `ruled`: the parts on the ground between full-width rules, above, between and below;
/// - `table`: an outlined `radius-sm` box, the heading as a header band on `surface-sunken` inside it, full
///   rules between the rows and every second row on `stripe` (zebra stripes, lighter than the band).
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

  /// The outline of a `bordered` or `table` list: the theme's card outline, else a [MyDataEdges.controlSide]
  /// at least 1px wide (`line-strong` where the theme's borders are the faint `line`).
  static BorderSide listOutline(MyDataLook look) =>
      look.edges.card ?? BorderSide(color: look.edges.controlColour, width: math.max(1, look.edges.width));

  /// The corners of a list in [look]'s list style: `radius-lg` for a group or a card, `radius-sm` for a
  /// table, none for a plain or ruled list.
  static BorderRadius listRadius(MyDataLook look) => switch (look.variants.list) {
        ListStyle.plain || ListStyle.ruled => BorderRadius.zero,
        ListStyle.table => MyDataRadii.sm(look),
        _ => MyDataRadii.lg(look),
      };

  /// Between the cards of a `cards` list.
  static double cardGap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    if (plain) return _plain(context);
    final c = context.colors;
    final look = context.look;
    final style = look.variants.list;
    final radius = listRadius(look);
    final top = BorderRadius.only(topLeft: radius.topLeft, topRight: radius.topRight);
    final bottom = BorderRadius.only(bottomLeft: radius.bottomLeft, bottomRight: radius.bottomRight);
    // A table's heading is its header band, inside the outline.
    final band = style == ListStyle.table && heading != null;
    final count = parts.length + (band ? 1 : 0);
    BorderRadius shapeOf(int i) {
      if (style == ListStyle.cards) return radius;
      if (count == 1) return radius;
      if (i == 0) return top;
      if (i == count - 1) return bottom;
      return BorderRadius.zero;
    }

    // Under each row: from where that row's text starts (as iOS lists do), in the theme's separators; a ruled
    // list and a table always rule their rows, full width.
    final forced = style == ListStyle.ruled || style == ListStyle.table ? Separators.full : null;
    Widget rule(int i) => EdgeRule(
          inCard: style != ListStyle.plain && style != ListStyle.ruled,
          separators: forced,
          inset: textStart(look, lead: parts[i - 1] is LeadingTile && (parts[i - 1] as LeadingTile).hasLeadingTile),
        );

    // Not clipped: each part takes the group's corners itself, so a row's selected fill and hover fill
    // follow them and a focus ring, drawn 2px outside, is not cut off at the group's edge.
    Widget part(int i) {
      final at = i + (band ? 1 : 0);
      Widget p = GroupPartShape(borderRadius: shapeOf(at), child: parts[i]);
      // A table's zebra stripes: every second row on `stripe`.
      if (style == ListStyle.table && i.isOdd) {
        p = DecoratedBox(
            decoration: context.radius.decorate(BoxDecoration(color: c.stripe, borderRadius: shapeOf(at))),
            child: p);
      }
      return p;
    }

    final Widget body;
    switch (style) {
      case ListStyle.cards:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) SizedBox(height: cardGap(look)),
              DecoratedBox(
                decoration: context.radius.decorate(
                    BoxDecoration(color: c.surface, borderRadius: radius, boxShadow: context.shadows.shadow1)),
                child: CardEdge(radius: radius, child: part(i)),
              ),
            ],
          ],
        );
      case ListStyle.plain || ListStyle.ruled:
        final ruled = style == ListStyle.ruled;
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ruled) const EdgeRule(separators: Separators.full, edgeOnly: true),
            for (var i = 0; i < parts.length; i++) ...[if (i > 0) rule(i), part(i)],
            if (ruled) const EdgeRule(separators: Separators.full, edgeOnly: true),
          ],
        );
      case ListStyle.inset || ListStyle.bordered || ListStyle.table:
        final outlined = style != ListStyle.inset;
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (band) ...[
              Container(
                decoration: context.radius.decorate(BoxDecoration(color: c.surfaceSunken, borderRadius: shapeOf(0))),
                padding: EdgeInsets.symmetric(horizontal: look.space(4), vertical: look.space(2)),
                child: Semantics(
                  header: true,
                  child: RoleLabel(heading!, color: c.inkMuted, holdsName: headingHoldsName),
                ),
              ),
              const EdgeRule(inCard: true, separators: Separators.full, edgeOnly: true),
            ],
            for (var i = 0; i < parts.length; i++) ...[if (i > 0) rule(i), part(i)],
          ],
        );
        body = DecoratedBox(
          decoration: context.radius
              .decorate(BoxDecoration(color: c.surface, borderRadius: radius, boxShadow: context.shadows.shadow1)),
          child: outlined
              ? DecoratedBox(
                  position: DecorationPosition.foreground,
                  // In the theme's border style where the outline is its card edge (Blueprint's dashes).
                  decoration: MyDataEdgesPaint.outline(look, radius, listOutline(look)),
                  child: column)
              : CardEdge(radius: radius, child: column),
        );
    }
    if (heading == null || band) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headingPadding(look),
          child: Semantics(
            header: true,
            child: RoleLabel(heading!, color: c.inkMuted, holdsName: headingHoldsName),
          ),
        ),
        body,
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
