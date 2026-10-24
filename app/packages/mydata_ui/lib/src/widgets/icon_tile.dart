import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pressable.dart';
import 'status.dart';

/// A 20px outline icon on a 36px rounded tile (design/README.md "Icons and illustration"), in the theme's
/// tile style (`icons.tiles`): tinted as below (Kiwi), outlined, or the icon alone. The icon takes
/// the strong colour of the tile's tint: `accent` on `accent-soft`, `success` on `success-soft`; an
/// untinted tile is `surface-sunken` with an `ink-muted` icon. Use at most three tile tones on one screen,
/// and give the same kind of thing the same tone everywhere. Where the accent is near `danger`
/// ([MyDataLook.accentNearDanger]: Swiss Red, Geometric Red) an accent tile is drawn neutral with its icon in
/// `ink`, as the primary button is: a red phone or cloud beside a source reads as an error.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.tone = MyDataTone.accent, this.semanticLabel});

  final MyDataIcon icon;
  final MyDataTone tone;

  /// An icon alone always has an accessible name; leave null when the tile sits beside its label.
  final String? semanticLabel;

  /// The outline of an `outlined` tile.
  static const outlineWidth = 1.0;

  /// The tone [tone] is drawn in for [look]: neutral in place of the accent where the accent is near danger.
  static MyDataTone shownTone(MyDataLook look, MyDataTone tone) =>
      tone == MyDataTone.accent && look.accentNearDanger ? MyDataTone.neutral : tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = shownTone(context.look, tone);
    final nearRed = shown != tone;
    // The theme's tiles (`icons.tiles`): tinted (Kiwi), an outline in the control outline's colour, or none
    // (the icon alone in the tile's room, so names still line up).
    final tiles = context.look.icons.tiles;
    final Decoration? decoration = switch (tiles) {
      'outlined' => context.radius.decorate(BoxDecoration(
          borderRadius: MyDataRadii.sm(context.look),
          border: Border.all(color: context.look.edges.controlColour, width: outlineWidth))),
      'none' => null,
      _ => context.radius.decorate(BoxDecoration(color: shown.fill(c), borderRadius: MyDataRadii.sm(context.look))),
    };
    return Container(
      width: context.density.iconTile,
      height: context.density.iconTile,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(context.icon(icon),
          size: context.density.icon, color: nearRed ? c.ink : shown.strong(c), semanticLabel: semanticLabel),
    );
  }
}
