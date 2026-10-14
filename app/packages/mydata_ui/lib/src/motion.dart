import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'accessibility.dart';

/// design/motion.md: soft and quick. Things ease into place; nothing snaps and nothing lingers.
abstract final class MyDataMotion {
  /// Hover, press, switch and segment state.
  static const fast = Duration(milliseconds: 120);

  /// Menus, popovers, tab changes, cards appearing.
  static const base = Duration(milliseconds: 240);

  /// Sheets, dialogs and screen transitions.
  static const slow = Duration(milliseconds: 380);

  /// How long a Toast stays before it leaves; paused on hover, touch and focus (motion.md `toast-duration`).
  static const toastDuration = Duration(seconds: 8);

  /// Movement within the screen: cubic-bezier(0.2, 0, 0, 1).
  static const standard = Cubic(0.2, 0, 0, 1);

  /// "Gentle, about 350ms, a trace of overshoot": settles in about 350ms with about 1% overshoot.
  /// For sheets, the segmented control's thumb and the tab pill.
  static final spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 194, ratio: 0.82);

  /// How long [spring] takes to settle, for widgets that drive it with a fixed-length controller.
  static const springDuration = Duration(milliseconds: 350);

  /// A pressed control dims slightly and scales to 97%, within one frame; it returns over [fast].
  static const pressScale = 0.97;
  static const pressOpacity = 0.85;

  /// Cards entering a screen fade and rise 8px over [base], staggered by 30ms, at most six.
  static const entranceRise = 8.0;
  static const entranceStagger = Duration(milliseconds: 30);
  static const entranceMaxStaggered = 6;

  /// Whether movement should become a short fade (the system's reduced-motion setting).
  static bool reduced(BuildContext context) => MyDataAccessibility.of(context).reduceMotion;
}

/// A curve that follows [MyDataMotion.spring] from 0 to 1 (with its slight overshoot).
class SpringCurve extends Curve {
  const SpringCurve();

  static final _sim = SpringSimulation(MyDataMotion.spring, 0, 1, 0);

  @override
  double transformInternal(double t) =>
      _sim.x(t * MyDataMotion.springDuration.inMicroseconds / Duration.microsecondsPerSecond);
}
