import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';

/// The status colours (design/README.md "Colour"): each a strong colour for text and icons and a `-soft`
/// fill for chips and tiles. [neutral] is the inactive state: `surface-sunken` with `ink-muted`.
/// [accent] is for tiles only: `accent-soft` with `accent`.
enum MyDataTone {
  accent,
  success,
  warning,
  danger,
  info,
  neutral;

  /// The fill (a `-soft` token, `accent-soft` or `surface-sunken`).
  Color fill(MyDataColors c) => switch (this) {
        accent => c.accentSoft,
        success => c.successSoft,
        warning => c.warningSoft,
        danger => c.dangerSoft,
        info => c.infoSoft,
        neutral => c.surfaceSunken,
      };

  /// The strong colour used on [fill] for text and icons.
  Color strong(MyDataColors c) => switch (this) {
        accent => c.accent,
        success => c.success,
        warning => c.warning,
        danger => c.danger,
        info => c.info,
        neutral => c.inkMuted,
      };
}

extension MyDataToneContext on BuildContext {
  Color toneFill(MyDataTone tone) => tone.fill(colors);
  Color toneStrong(MyDataTone tone) => tone.strong(colors);
}
