import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'pressable.dart';
import 'status.dart';

/// A 20px outline icon on a 36px rounded tile (design/README.md "Icons and illustration"). The icon takes
/// the strong colour of the tile's tint: `accent` on `accent-soft`, `success` on `success-soft`; an
/// untinted tile is `surface-sunken` with an `ink-muted` icon. Use at most three tile tones on one screen,
/// and give the same kind of thing the same tone everywhere.
///
/// The icon set has not been drawn; until it is, callers pass Material outline icons.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.tone = MyDataTone.accent, this.semanticLabel});

  final IconData icon;
  final MyDataTone tone;

  /// An icon alone always has an accessible name; leave null when the tile sits beside its label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: context.density.iconTile,
      height: context.density.iconTile,
      decoration: BoxDecoration(color: tone.fill(c), borderRadius: MyDataRadii.sm(context.look)),
      alignment: Alignment.center,
      child: Icon(icon, size: context.density.icon, color: tone.strong(c), semanticLabel: semanticLabel),
    );
  }
}
