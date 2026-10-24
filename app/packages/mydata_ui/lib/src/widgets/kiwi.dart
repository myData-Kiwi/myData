import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'pressable.dart';

/// The kiwi mark with its green wash (design/assets/Logos). Inside the apps it always sits on `paper`, which
/// stays light in both modes, because the mark's ink is a fixed dark colour. Never recoloured or tinted.
class KiwiMark extends StatelessWidget {
  const KiwiMark({super.key, this.height = 36, this.semanticLabel = 'myData'});
  final double height;
  final String? semanticLabel;

  /// The mark's drawing is 210 by 180.
  static const aspect = 210 / 180;

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/logo/mydata-kiwi-mark.svg',
      package: MyDataFontFamily.package, height: height, width: height * aspect, semanticsLabel: semanticLabel);
}

/// The kiwi mark on a rounded `paper` tile with `shadow-1`: empty screens, first run (EmptyState spec).
class KiwiTile extends StatelessWidget {
  const KiwiTile({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: context.radius.decorate(BoxDecoration(color: context.colors.paper, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1)),
        alignment: Alignment.center,
        child: KiwiMark(height: size * 0.5),
      );
}

/// Loading of unknown length. The design calls for "the kiwi slice", which has not been drawn; until it is,
/// this is the kiwi mark on a round `paper` badge that turns (as on the website), and stays still with
/// reduced motion. A placeholder: replace the drawing, keep the widget.
class KiwiLoader extends StatefulWidget {
  const KiwiLoader({super.key, this.size = 40, this.semanticLabel = 'Loading'});
  final double size;
  final String semanticLabel;

  @override
  State<KiwiLoader> createState() => _KiwiLoaderState();
}

class _KiwiLoaderState extends State<KiwiLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MyDataAccessibility.of(context).reduceMotion || TickerMode.valuesOf(context).enabled == false) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: context.colors.paper, shape: BoxShape.circle, boxShadow: context.shadows.shadow1),
      alignment: Alignment.center,
      child: KiwiMark(height: widget.size * 0.5, semanticLabel: null),
    );
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: MyDataAccessibility.of(context).reduceMotion
          ? badge
          : AnimatedBuilder(
              animation: _spin,
              builder: (context, child) => Transform.rotate(angle: _spin.value * 2 * math.pi, child: child),
              child: badge),
    );
  }
}
