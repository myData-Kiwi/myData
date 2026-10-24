/// The run-time look (design/themes/ARCHITECTURE.md 3.1): one theme and palette resolved for one brightness,
/// carried in ThemeData as a [ThemeExtension] and read by widgets through `context.look` and its shortcuts
/// (`context.space(4)`, `context.typeScale.body`, `context.radius.lg`, `context.density.controlHeight`,
/// `context.motion.fast`).
///
/// Every built-in is resolved from its theme file in design/themes (System and the six drawn looks, each in
/// its palettes); the fallback is Kiwi's default palette from the generated constants.
library;


import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import 'builtin_themes.g.dart';
import 'catalogue.dart';
import 'colour.dart' show Oklch, Rgb, hueDistance;
import 'icons.dart';
import 'motion.dart';
import 'resolve.dart';
import 'roles.dart';
import 'theme_file.dart';
import 'variants.dart';

export 'variants.dart';

/// A text role, as widgets name it: `context.type(MyDataTypeRole.body)`.
typedef MyDataTypeRole = TypeRole;

/// Who draws the frame: the platform (System: the Mac shell on macOS) or myData, from the theme's rules.
enum LookFrame { system, drawn }

Color _color(Rgb c) => Color(c.argb);

/// The type styles of a look, without colour (widgets take colour from `context.colors`).
@immutable
class MyDataTypeScale {
  const MyDataTypeScale({
    required this.displayXl,
    required this.displayLg,
    required this.title,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
    required this.mono,
    this.upper = const {},
    this.secondaryItalic = false,
  });

  final TextStyle displayXl, displayLg, title, heading, body, bodyStrong, label, caption, mono;

  /// The roles set in upper case (only `label` and `caption`, which the validator enforces).
  final Set<MyDataTypeRole> upper;

  /// Secondary text is italic (`type.secondary-italic`): `caption` is, and [secondary] makes any style so.
  final bool secondaryItalic;

  /// The style of [role].
  TextStyle call(MyDataTypeRole role) => switch (role) {
        TypeRole.displayXl => displayXl,
        TypeRole.displayLg => displayLg,
        TypeRole.title => title,
        TypeRole.heading => heading,
        TypeRole.body => body,
        TypeRole.bodyStrong => bodyStrong,
        TypeRole.label => label,
        TypeRole.caption => caption,
        TypeRole.mono => mono,
      };

  /// The role whose style is [style] (the same object), or null.
  MyDataTypeRole? roleOf(TextStyle style) {
    for (final r in TypeRole.values) {
      if (identical(call(r), style)) return r;
    }
    return null;
  }

  /// [style] as secondary text (an email under a name, a placeholder, a note): italic when the theme sets
  /// secondary text in italic, else unchanged.
  TextStyle secondary(TextStyle style) => secondaryItalic ? style.copyWith(fontStyle: FontStyle.italic) : style;

  /// [text] as [role] shows it: in upper case when the theme sets that role so, unless it [holdsName] (a
  /// person, an app such as myAssistant, a calendar, a file), which always keeps its own case
  /// (design/themes/ARCHITECTURE.md 2.3). Widgets call this for their own labels, never for user text.
  String cased(MyDataTypeRole role, String text, {bool holdsName = false}) =>
      !holdsName && upper.contains(role) ? text.toUpperCase() : text;

  /// How much heavier the system's Bold Text setting draws a variable font (`wght`). Flutter's Text asks
  /// for bold by `fontWeight` alone, which a style's own `wght` variation overrides, so these fonts would not
  /// get heavier at all. A font clamps the value to the top of its axis.
  static const boldTextGain = 300.0;

  static final _bold = Expando<MyDataTypeScale>('bold');

  /// This scale for the system's Bold Text (`MediaQuery.boldTextOf`; iOS and Android): each role in a
  /// variable font [boldTextGain] heavier on its `wght` axis (a static font is left to Text's own bold).
  /// `context.typeScale` and `context.type` give it when Bold Text is on.
  MyDataTypeScale get bold => _bold[this] ??= MyDataTypeScale(
        displayXl: _bolder(displayXl),
        displayLg: _bolder(displayLg),
        title: _bolder(title),
        heading: _bolder(heading),
        body: _bolder(body),
        bodyStrong: _bolder(bodyStrong),
        label: _bolder(label),
        caption: _bolder(caption),
        mono: _bolder(mono),
        upper: upper,
        secondaryItalic: secondaryItalic,
      );

  static TextStyle _bolder(TextStyle s) {
    final v = s.fontVariations;
    final i = v?.indexWhere((f) => f.axis == 'wght') ?? -1;
    // A static font: Text's own bold already reaches it.
    if (i < 0) return s;
    final wght = math.min(v![i].value + boldTextGain, 1000.0);
    final w = FontWeight.values[((wght / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];
    return s.copyWith(
        fontWeight: w, fontVariations: [for (final (j, f) in v.indexed) j == i ? FontVariation.weight(wght) : f]);
  }

  /// Today's Kiwi type (design/tokens.json), the fallback.
  static const kiwi = MyDataTypeScale(
    displayXl: MyDataType.displayXl,
    displayLg: MyDataType.displayLg,
    title: MyDataType.title,
    heading: MyDataType.heading,
    body: MyDataType.body,
    bodyStrong: MyDataType.bodyStrong,
    label: MyDataType.label,
    caption: MyDataType.caption,
    mono: MyDataType.mono,
  );

  /// The styles a theme's `type` group gives, on [platform] (this device's when null):
  /// - each role is set in the first font of its stack that this build bundles (a display-only font only at
  ///   16 px or more), with the stack's later bundled fonts as fallbacks for glyphs it lacks; a generic
  ///   family is the platform's own font (a generic `mono` the platform's monospace, `genericMonoFamilies`);
  /// - a variable font is drawn at the role's exact weight (`wght`), a core font at the nearest weight it has;
  ///   a font that keeps its optical size axis (Inter, Literata) at the role's size (`opsz`);
  /// - tracking in em becomes letter spacing, `numerals: tabular` tabular figures, `secondary-italic` an
  ///   italic `caption`, and `case: upper` is carried in [upper] for [cased].
  ///
  /// Fonts loaded on demand must be loaded (`ThemeFonts.ensure`) before this look is drawn, or the text
  /// shows in a fallback font until they are.
  factory MyDataTypeScale.of(TypeSpec spec, {TargetPlatform? platform}) {
    final target = platform ?? defaultTargetPlatform;

    TextStyle style(TypeRole role) {
      final r = spec.roles[role]!;
      // The first usable entry is the role's font; the stack's later bundled fonts are fallbacks. A generic
      // ends the stack: after it, the engine falls back to the platform's own fonts.
      CatalogueFont? font;
      String? primary;
      var chosen = false;
      final fallback = <String>[];
      for (final id in spec.stack(r.stack)) {
        final f = fontCatalogue[id];
        if (f != null && f.bundled && !(f.displayOnly && r.size < 16)) {
          if (!chosen) {
            font = f;
            chosen = true;
          } else {
            fallback.add(f.family!);
          }
        } else if (genericFonts.contains(id)) {
          if (!chosen && (id == 'mono' || id == 'system-mono')) primary = genericMonoFamilies[target.name];
          break;
        }
      }
      final weight = FontWeight.values[((r.weight / 100).round() - 1).clamp(0, FontWeight.values.length - 1)];
      final variable = font?.variable ?? false;
      final italic = spec.secondaryItalic && role == TypeRole.caption;
      return TextStyle(
        fontFamily: font?.family ?? primary,
        package: font == null ? null : fontPackage,
        fontFamilyFallback: fallback.isEmpty ? null : fallback,
        fontSize: r.size,
        // Rounded as tokens.g.dart rounds them, so Kiwi's styles are today's exactly.
        height: double.parse(r.lineHeight.toStringAsFixed(4)),
        leadingDistribution: TextLeadingDistribution.even,
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : null,
        // No tracking and a tracking of 0 are the same style: the engine lays out a set letter spacing, even 0,
        // apart from the font's own kerning, so 0 would draw text a pixel off where none draws it.
        letterSpacing: r.tracking == null || r.tracking == 0
            ? null
            : double.parse((r.tracking! * r.size).toStringAsFixed(3)),
        fontFeatures: spec.tabular ? const [FontFeature.tabularFigures()] : null,
        fontVariations: variable
            ? [
                FontVariation.weight(r.weight.toDouble()),
                if (font!.opticalSizes case (final lo, final hi)) FontVariation('opsz', r.size.clamp(lo, hi).toDouble()),
              ]
            : null,
      );
    }

    return MyDataTypeScale(
      displayXl: style(TypeRole.displayXl),
      displayLg: style(TypeRole.displayLg),
      title: style(TypeRole.title),
      heading: style(TypeRole.heading),
      body: style(TypeRole.body),
      bodyStrong: style(TypeRole.bodyStrong),
      label: style(TypeRole.label),
      caption: style(TypeRole.caption),
      mono: style(TypeRole.mono),
      upper: {for (final e in spec.roles.entries) if (e.value.upper) e.key},
      secondaryItalic: spec.secondaryItalic,
    );
  }
}

/// Corner radii and the corner style.
@immutable
class MyDataShape {
  const MyDataShape({
    required this.corners,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.control,
    required this.pill,
    required this.cutSize,
  });

  final CornerStyle corners;
  final double xs, sm, md, lg, xl;

  /// Buttons (a capsule, or [sm] when the theme's controls match).
  final double control;

  /// Chips, segmented controls, switches and avatars.
  final double pill;

  /// The chamfer when [corners] is cut.
  final double cutSize;

  static const kiwi = MyDataShape(
    corners: CornerStyle.continuous,
    xs: MyDataRadius.xs,
    sm: MyDataRadius.sm,
    md: MyDataRadius.md,
    lg: MyDataRadius.lg,
    xl: MyDataRadius.xl,
    control: MyDataRadius.control,
    pill: MyDataRadius.pill,
    cutSize: 0,
  );

  factory MyDataShape.of(ShapeSpec s) {
    final square = s.corners == CornerStyle.square;
    double r(double v) => square ? 0 : v;
    return MyDataShape(
      corners: s.corners,
      xs: r(s.xs),
      sm: r(s.sm),
      md: r(s.md),
      lg: r(s.lg),
      xl: r(s.xl),
      control: r(s.pillControls ? MyDataRadius.control : s.sm),
      pill: r(s.pillControls ? MyDataRadius.pill : s.sm),
      cutSize: s.cutSize,
    );
  }

  /// A capsule's radius: more than half of any height.
  static const capsule = MyDataRadius.pill;

  /// A small radius for a rounded control in a theme whose corners are square (`button.shape: rounded`).
  static const roundedControl = MyDataRadius.sm;

  /// This shape drawn in [corners] instead (a button whose `button.shape` is cut in a round theme). The radii
  /// stay as they are: a widget that takes another corner style gives its own.
  MyDataShape withCorners(CornerStyle corners) => MyDataShape(
      corners: corners, xs: xs, sm: sm, md: md, lg: lg, xl: xl, control: control, pill: pill, cutSize: cutSize);

  /// The outline of a shape with corner [radius], in this look's corner style (3.2).
  OutlinedBorder border(double radius, {BorderSide side = BorderSide.none}) =>
      outline(BorderRadius.circular(radius), side: side);

  /// The outline of a shape whose corners the tokens give as [radius] (`MyDataRadii.lg(look)`), in this
  /// look's corner style (ARCHITECTURE.md 3.2):
  /// - round: the radii as given (`RoundedRectangleBorder`);
  /// - continuous: the same radii as a superellipse, the system's corner (`RoundedSuperellipseBorder`);
  /// - cut: a chamfer of [cutSize] on every rounded corner, never more than the radius it replaces, so a
  ///   small row keeps a small cut and a square corner stays square (`BeveledRectangleBorder`);
  /// - square: no rounding at all.
  OutlinedBorder outline(BorderRadiusGeometry radius, {BorderSide side = BorderSide.none}) => switch (corners) {
        CornerStyle.round => RoundedRectangleBorder(borderRadius: radius, side: side),
        CornerStyle.continuous => RoundedSuperellipseBorder(borderRadius: radius, side: side),
        CornerStyle.cut => BeveledRectangleBorder(borderRadius: _cut(radius.resolve(TextDirection.ltr)), side: side),
        CornerStyle.square => RoundedRectangleBorder(side: side),
      };

  BorderRadius _cut(BorderRadius r) {
    Radius c(Radius x) => x.x <= 0 ? Radius.zero : Radius.circular(math.min(cutSize, x.x));
    return BorderRadius.only(
        topLeft: c(r.topLeft), topRight: c(r.topRight), bottomLeft: c(r.bottomLeft), bottomRight: c(r.bottomRight));
  }

  /// Whether a [BoxDecoration] with a border radius already draws this look's corners: round corners, and
  /// square ones (whose radii are all 0). Then [decorate] gives it back unchanged.
  bool get boxCorners => corners == CornerStyle.round || corners == CornerStyle.square;

  /// [d] in this look's corner style: unchanged when a box draws it ([boxCorners]), a circle, without a
  /// border radius, or with a border that is not the same on every side (an underline); otherwise the same
  /// fill, gradient, shadows and uniform border on [outline]. Every widget passes its rounded decorations
  /// through here (`context.radius.decorate(BoxDecoration(...))`), so a theme's corners reach all of them.
  Decoration decorate(BoxDecoration d) {
    final radius = d.borderRadius;
    if (boxCorners || radius == null || d.shape != BoxShape.rectangle) return d;
    final border = d.border;
    BorderSide side = BorderSide.none;
    if (border != null) {
      if (border is! Border || !border.isUniform) return d;
      side = border.top;
    }
    return ShapeDecoration(
      color: d.color,
      gradient: d.gradient,
      image: d.image,
      shadows: d.boxShadow,
      shape: outline(radius, side: side),
    );
  }

  /// [child] clipped to a shape with corners [radius] in this look's corner style: a `ClipRRect` for box
  /// corners (as before), else a clip to [outline].
  Widget clip(BorderRadius radius, {required Widget child}) => boxCorners
      ? ClipRRect(borderRadius: radius, child: child)
      : ClipPath(clipper: ShapeBorderClipper(shape: outline(radius)), child: child);

  /// The path of a shape with corners [radius] filling [rect], in this look's corner style.
  Path path(Rect rect, BorderRadius radius) => outline(radius).getOuterPath(rect);

  /// Corners [radius] grown by [by] on every side, so the shape [by] outside a rounded one keeps an even
  /// gap: a round or continuous radius grows by [by], a chamfer by `by × (2 − √2)` (a cut corner's diagonal
  /// moves out by [by] too). A corner of 0 grows into the same curve as any other, as today's ring does.
  BorderRadius grow(BorderRadius radius, double by) {
    Radius g(Radius r) => switch (corners) {
          CornerStyle.square => Radius.circular(math.max(0, by)),
          CornerStyle.cut =>
            r.x <= 0 ? Radius.zero : Radius.circular(math.max(0, math.min(cutSize, r.x) + by * (2 - math.sqrt2))),
          _ => Radius.circular(math.max(0, r.x + by)),
        };
    return BorderRadius.only(
        topLeft: g(radius.topLeft),
        topRight: g(radius.topRight),
        bottomLeft: g(radius.bottomLeft),
        bottomRight: g(radius.bottomRight));
  }

  /// The ring around (or, with a negative [by], inside) a shape with corners [radius] in [rect]: its path
  /// [by] outside the shape. A cut ring is cut again, with its chamfer grown so the gap stays even; other
  /// rings are rounded, as the shape is (a square shape's ring rounds by the gap, as a CSS outline does).
  Path ringPath(Rect rect, BorderRadius radius, double by) => cornerPath(rect.inflate(by), grow(radius, by));

  /// [rect] with corners [radii] taken as they are (already cut or grown, [grow]), in this look's corner
  /// style: chamfered when cut, a superellipse when continuous, rounded otherwise.
  Path cornerPath(Rect rect, BorderRadius radii) => switch (corners) {
        CornerStyle.cut => BeveledRectangleBorder(borderRadius: radii).getOuterPath(rect),
        CornerStyle.continuous => RoundedSuperellipseBorder(borderRadius: radii).getOuterPath(rect),
        _ => Path()..addRRect(radii.toRRect(rect)),
      };

  static MyDataShape lerp(MyDataShape a, MyDataShape b, double t) => MyDataShape(
        corners: t < 0.5 ? a.corners : b.corners,
        xs: lerpDouble(a.xs, b.xs, t),
        sm: lerpDouble(a.sm, b.sm, t),
        md: lerpDouble(a.md, b.md, t),
        lg: lerpDouble(a.lg, b.lg, t),
        xl: lerpDouble(a.xl, b.xl, t),
        control: lerpDouble(a.control, b.control, t),
        pill: lerpDouble(a.pill, b.pill, t),
        cutSize: lerpDouble(a.cutSize, b.cutSize, t),
      );
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Control, row and icon sizes and the spacing scale, for this device's class (desktop or phone), never
/// under the platform's floor for a target ([minTarget], ARCHITECTURE.md 1.4).
@immutable
class MyDataDensity {
  const MyDataDensity({
    required this.controlHeight,
    required this.controlHeightCompact,
    required this.rowHeight,
    required this.icon,
    required this.iconTile,
    required this.spaceScale,
    this.minTarget = desktopFloor,
  });

  /// Buttons, inputs, chips and the minimum touch target.
  final double controlHeight;

  /// Desktop-only compact controls: 8 below [controlHeight], never under 24.
  final double controlHeightCompact;

  /// Rows in a grouped list.
  final double rowHeight;

  /// The icon box.
  final double icon;

  /// The tile behind a row's icon: the icon and 8 on each side.
  final double iconTile;

  /// Multiplier on the 4px spacing scale.
  final double spaceScale;

  /// The smallest target this device takes: 24 on a desktop (WCAG 2.2 SC 2.5.8), 44 on iOS and for a coarse
  /// pointer anywhere, 48 on Android. Controls and rows are never smaller, whatever the theme says.
  final double minTarget;

  /// `space-n` (`space(4)` is 16 at 1×).
  double space(num n) => n * 4 * spaceScale;

  /// The floors of ARCHITECTURE.md 1.4.
  static const desktopFloor = 24.0, iosFloor = 44.0, androidFloor = 48.0, coarsePointerFloor = 44.0;

  /// The floor while the pointer is coarse ([debugFloor] in tests).
  static double get coarseFloor => debugFloor ?? coarsePointerFloor;

  /// Stands in for every platform's floor while set: the test harness sets [desktopFloor], so the shared
  /// goldens, which Flutter renders as Android by default, show the look's own sizes rather than Android's
  /// floor; the floors themselves have their own tests. Never set outside tests (mydata_testing).
  static double? debugFloor;

  /// [platform]'s floor for a target (with a fine pointer; [atLeast] raises it for a coarse one).
  static double floorFor(TargetPlatform platform) => debugFloor ?? switch (platform) {
        TargetPlatform.iOS => iosFloor,
        TargetPlatform.android || TargetPlatform.fuchsia => androidFloor,
        _ => desktopFloor,
      };

  static const kiwi = MyDataDensity(
    controlHeight: MyDataSize.controlHeight,
    controlHeightCompact: MyDataSize.controlHeightCompact,
    rowHeight: MyDataSize.rowHeight,
    icon: MyDataSize.icon,
    iconTile: MyDataSize.iconTile,
    spaceScale: 1,
  );

  /// A theme's density set [d], raised to [floor] where it is smaller: controls and rows are targets.
  factory MyDataDensity.of(DensitySet d, {double floor = desktopFloor}) {
    final control = math.max(d.control, floor);
    return MyDataDensity(
      controlHeight: control,
      controlHeightCompact: math.max((d.control - 8).clamp(24, d.control).toDouble(), floor),
      rowHeight: math.max(d.row, floor),
      icon: d.icon,
      iconTile: d.icon + 16,
      spaceScale: d.space,
      minTarget: floor,
    );
  }

  /// This density for a floor of at least [floor] (a coarse pointer on a desktop): itself when already there.
  MyDataDensity atLeast(double floor) => floor <= minTarget
      ? this
      : MyDataDensity(
          controlHeight: math.max(controlHeight, floor),
          controlHeightCompact: math.max(controlHeightCompact, floor),
          rowHeight: math.max(rowHeight, floor),
          icon: icon,
          iconTile: iconTile,
          spaceScale: spaceScale,
          minTarget: floor,
        );

  static MyDataDensity lerp(MyDataDensity a, MyDataDensity b, double t) => MyDataDensity(
        controlHeight: lerpDouble(a.controlHeight, b.controlHeight, t),
        controlHeightCompact: lerpDouble(a.controlHeightCompact, b.controlHeightCompact, t),
        rowHeight: lerpDouble(a.rowHeight, b.rowHeight, t),
        icon: lerpDouble(a.icon, b.icon, t),
        iconTile: lerpDouble(a.iconTile, b.iconTile, t),
        spaceScale: lerpDouble(a.spaceScale, b.spaceScale, t),
        minTarget: t < 0.5 ? a.minTarget : b.minTarget,
      );
}

/// Borders (theme.schema.json `borders`): their width, style and colour, and where they are drawn.
@immutable
class MyDataEdges {
  const MyDataEdges(this.spec, {required this.colour, this.allControls = false, Color? controlColour})
      : controlColour = controlColour ?? colour;
  final BordersSpec spec;

  /// The borders' colour, from the palette (`line`, `line-strong`, `edge` or `accent`).
  final Color colour;

  /// The colour of a control's outline ([controlSide]): [colour], or `line-strong` where that is `line`,
  /// which is under 3:1 and would not outline anything (as the text field already does). Increased contrast
  /// outlines every control in it.
  final Color controlColour;

  /// Increased contrast draws an edge on every control, whatever the theme says (ARCHITECTURE.md 2.3).
  final bool allControls;

  /// The line width: a hairline is the Mac's half point.
  double get width => switch (spec.width) {
        BorderWidth.hairline => MyDataMacSize.hairline,
        BorderWidth.one => 1,
        BorderWidth.two => 2,
        BorderWidth.three => 3,
      };

  /// Solid, dashed or double: on cards and separators only. Controls, inputs and focus rings stay solid.
  BorderStyleKind get style => spec.style;

  /// A solid line of [width] in [colour].
  BorderSide get side => BorderSide(color: colour, width: width);

  /// A control's outline: a solid line of [width] in [controlColour].
  BorderSide get controlSide => BorderSide(color: controlColour, width: width);

  /// The outline of a card or a group of rows, or null when the theme draws none.
  BorderSide? get card => spec.cards ? side : null;

  /// Whether buttons and fields carry an outline (solid, [side]).
  bool get controls => spec.controls || allControls;

  /// Between rows: none, from the text's start (inset) or the full width.
  Separators get separators => spec.separators;

  /// Under a page's title: none, one rule or two.
  TitleRule get titleRule => spec.titleRule;

  /// How tall a separator between rows is: nothing when there is none, three widths for a double rule.
  double get separatorExtent => switch (separators) {
        Separators.none => 0,
        _ => style == BorderStyleKind.doubleLine ? width * 3 : width,
      };

  /// How tall the rule under a title is.
  double get titleRuleExtent => switch (titleRule) {
        TitleRule.none => 0,
        TitleRule.single => width,
        TitleRule.doubleLine => width * 3,
      };

  /// These borders in the colours [c] (a look whose colours are replaced, as the Mac shell replaces them with
  /// the system's).
  MyDataEdges withColours(MyDataColors c) =>
      MyDataEdges(spec, colour: colourOf(spec, c), controlColour: controlColourOf(spec, c), allControls: allControls);

  /// [spec]'s colour for a control's outline in [c]: `line-strong` where the borders are `line`.
  static Color controlColourOf(BordersSpec spec, MyDataColors c) =>
      spec.colour == BorderColour.line ? c.lineStrong : colourOf(spec, c);

  /// [spec]'s colour in [c].
  static Color colourOf(BordersSpec spec, MyDataColors c) => switch (spec.colour) {
        BorderColour.line => c.line,
        BorderColour.lineStrong => c.lineStrong,
        BorderColour.edge => c.edge,
        BorderColour.accent => c.accent,
      };
}

/// Shadows and how a press changes them (theme.schema.json `elevation`):
/// - soft: today's blurred lift under cards, groups and overlays, and nothing under controls (Kiwi);
/// - hard: a solid shadow straight down by `offset` (a sticker), under cards and controls;
/// - offset: the same shadow down and to the right (brutalist);
/// - bevel: a light top-left and dark bottom-right line on cards and controls, over an `offset` drop;
/// - glow: the accent, blurred, under the primary button and the selection marker only; overlays keep a
///   soft lift;
/// - none: flat.
/// With `press: collapse` a pressed control's hard, offset or bevel shadow drops to nothing ([pressed]), and
/// a `sink` press moves it by [sink], into where its shadow was.
@immutable
class MyDataElevation {
  const MyDataElevation({
    required this.style,
    required this.shadows,
    required this.collapse,
    this.control = const [],
    this.glow = const [],
    this.sink = Offset.zero,
    this.bevel,
  });

  final ElevationStyle style;

  /// The resting, raised and floating shadows (`shadow-1`, `shadow-2`, `shadow-glass`).
  final MyDataShadows shadows;

  /// A pressed hard, offset or bevel shadow drops to 0.
  final bool collapse;

  /// Under a control with a fill (a button): the hard, offset or bevel drop; nothing for soft or none.
  final List<BoxShadow> control;

  /// The glow of the primary button and the selection marker (style glow only).
  final List<BoxShadow> glow;

  /// How far a pressed control moves when it sinks into its shadow: the shadow's own offset.
  final Offset sink;

  /// The bevel's two lines (style bevel only): [Bevel.light] along the top and left edges, [Bevel.dark] along
  /// the bottom and right; swapped while pressed.
  final Bevel? bevel;

  /// The shadows under a control with a fill, resting or [pressed]; the primary button adds [glow]. A
  /// control that [sinks] when pressed (`motion.press: sink`) moves into where its drop was, so the drop
  /// goes with or without `press: collapse`: kept, it would move with the control to twice its offset.
  List<BoxShadow> controlShadows({bool pressed = false, bool primary = false, bool sinks = false}) => [
        if (!(pressed && (collapse || sinks))) ...control,
        if (primary) ...glow,
      ];

  /// The CSS-to-Flutter blur conversion tokens.g.dart uses: CSS draws a blur radius r as a Gaussian with
  /// sigma r/2; Flutter's sigma is blurRadius × 0.57735 + 0.5. Rounded to 0.01 as the generated file is.
  static double blurRadiusOf(double cssBlur) =>
      cssBlur <= 1 ? 0.0 : double.parse(((cssBlur / 2 - 0.5) / 0.57735).toStringAsFixed(2));

  factory MyDataElevation.of(ElevationSpec e,
      {required Color shadow, required Color accent, required Color surface, required Color ink, required bool dark}) {
    List<BoxShadow> level(int i, {double? strength}) {
      final l = softElevationLevels[i];
      final base = dark ? l.alphaDark : l.alphaLight;
      final alpha = (base * (strength ?? e.strength) / 0.5).round().clamp(0, 255);
      return [
        BoxShadow(
          color: shadow.withAlpha(alpha),
          offset: Offset(0, l.y.toDouble()),
          blurRadius: blurRadiusOf(l.cssBlur.toDouble()),
        ),
      ];
    }

    final drop = switch (e.style) {
      ElevationStyle.hard => Offset(0, e.offset),
      ElevationStyle.offset || ElevationStyle.bevel => Offset(e.offset, e.offset),
      _ => Offset.zero,
    };
    // A solid shadow with no blur, in the palette's `shadow` at the theme's strength.
    final hard = drop == Offset.zero ? const <BoxShadow>[] : [BoxShadow(color: shadow.withValues(alpha: e.strength), offset: drop)];
    final glow = e.style == ElevationStyle.glow
        ? [BoxShadow(color: accent.withValues(alpha: 0.6 * e.strength), blurRadius: 12 * e.strength)]
        : const <BoxShadow>[];

    final shadows = switch (e.style) {
      ElevationStyle.none => const MyDataShadows(shadow1: [], shadow2: [], shadowGlass: []),
      ElevationStyle.soft => MyDataShadows(shadow1: level(0), shadow2: level(1), shadowGlass: level(2)),
      ElevationStyle.hard || ElevationStyle.offset || ElevationStyle.bevel =>
        MyDataShadows(shadow1: hard, shadow2: hard, shadowGlass: hard),
      // Glow lights the primary button and the selection marker only; overlays keep a soft lift.
      ElevationStyle.glow => MyDataShadows(shadow1: const [], shadow2: level(1, strength: 0.5), shadowGlass: level(2, strength: 0.5)),
    };
    return MyDataElevation(
      style: e.style,
      shadows: shadows,
      collapse: e.collapse,
      control: hard,
      glow: glow,
      sink: drop,
      bevel: e.style == ElevationStyle.bevel
          ? Bevel(
              light: (dark ? ink : surface).withValues(alpha: (dark ? 0.25 : 0.9) * e.strength),
              dark: shadow.withValues(alpha: (dark ? 0.8 : 0.45) * e.strength),
            )
          : null,
    );
  }
}

/// The two lines of a bevel: [light] on the top and left edges, [dark] on the bottom and right.
@immutable
class Bevel {
  const Bevel({required this.light, required this.dark});
  final Color light, dark;

  @override
  bool operator ==(Object other) => other is Bevel && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// Window ground, sidebar and bars (theme.schema.json `materials`).
@immutable
class MyDataMaterials {
  const MyDataMaterials({required this.spec, required this.blur, this.gradient});
  final MaterialsSpec spec;

  /// The backdrop blur behind glass, as a sigma.
  final double blur;

  /// The window gradient's stops in this palette and mode (`window: gradient`); null otherwise.
  final List<Color>? gradient;
}

/// Durations, curves, press and entrance (theme.schema.json `motion`). `standard` at scale 1 is
/// design/motion.md ([MyDataMotion]).
@immutable
class MyDataMotionSpec {
  const MyDataMotionSpec({
    required this.personality,
    required this.fast,
    required this.base,
    required this.slow,
    required this.standard,
    required this.spring,
    required this.springDuration,
    required this.pressScale,
    required this.pressOpacity,
    required this.press,
    required this.enter,
    required this.entranceRise,
    required this.entranceStagger,
    required this.entranceMaxStaggered,
    required this.sheetDrop,
    this.fixedSpringCurve,
  });

  final MotionPersonality personality;
  final Duration fast, base, slow;

  /// Movement within the screen.
  final Curve standard;

  /// Sheets, the segmented control's thumb and the tab pill.
  final SpringDescription spring;
  final Duration springDuration;

  /// Stands in for [springCurve] (reduced motion's [standard]).
  final Curve? fixedSpringCurve;
  static final _springCurves = Expando<Curve>('spring curve');

  /// [spring] over [springDuration] as a curve, for the widgets that spring (the segmented control's thumb,
  /// the tab pill, the floating bar's pill, a sheet's rise): this personality's own spring, made once per
  /// motion. With reduced motion it is [standard]: nothing overshoots.
  Curve get springCurve => fixedSpringCurve ?? (_springCurves[this] ??= SpringCurve(spring, springDuration));

  /// A pressed control scales to [pressScale] and dims to [pressOpacity] at once, and returns over [fast].
  final double pressScale, pressOpacity;
  final PressStyle press;
  final EnterStyle enter;

  /// Cards entering a screen rise [entranceRise] px over [base], [entranceStagger] apart, at most
  /// [entranceMaxStaggered].
  final double entranceRise;
  final Duration entranceStagger;
  final int entranceMaxStaggered;

  /// How far a Mac frame's sheet travels as it comes down, as a share of the window's height.
  final double sheetDrop;

  static final kiwi = MyDataMotionSpec(
    personality: MotionPersonality.standard,
    fast: MyDataMotion.fast,
    base: MyDataMotion.base,
    slow: MyDataMotion.slow,
    standard: MyDataMotion.standard,
    spring: MyDataMotion.spring,
    springDuration: MyDataMotion.springDuration,
    pressScale: MyDataMotion.pressScale,
    pressOpacity: MyDataMotion.pressOpacity,
    press: PressStyle.dimScale,
    enter: EnterStyle.fadeRise,
    entranceRise: MyDataMotion.entranceRise,
    entranceStagger: MyDataMotion.entranceStagger,
    entranceMaxStaggered: MyDataMotion.entranceMaxStaggered,
    sheetDrop: MyDataMotion.sheetDrop,
  );

  static final _reduced = Expando<MyDataMotionSpec>('reduced');

  /// This motion when the system asks for less (ARCHITECTURE.md 2.3, "System settings win"): every
  /// personality becomes a `fast` fade, and `none` stays nothing. Nothing moves: no scale or sink on a press
  /// (a dim instead; `invert` keeps its colours, which do not move), no rise on entering, no sheet travel,
  /// and every duration, spring included, is at most `fast`.
  MyDataMotionSpec get reduced => _reduced[this] ??= MyDataMotionSpec(
        personality: personality,
        fast: fast,
        base: fast,
        slow: fast,
        standard: standard,
        spring: spring,
        springDuration: fast,
        pressScale: 1,
        pressOpacity: press == PressStyle.none || press == PressStyle.invert ? pressOpacity : MyDataMotion.pressOpacity,
        press: switch (press) {
          PressStyle.dimScale || PressStyle.sink => PressStyle.dim,
          _ => press,
        },
        enter: enter == EnterStyle.fadeRise ? EnterStyle.fade : enter,
        entranceRise: 0,
        entranceStagger: Duration.zero,
        entranceMaxStaggered: entranceMaxStaggered,
        sheetDrop: 0,
        fixedSpringCurve: standard,
      );

  /// The personalities, at scale 1 (`motion.scale` multiplies them; `slow` is capped at 500 ms):
  /// - standard: design/motion.md, today's (120, 240 and 380 ms, a gentle spring);
  /// - calm: a third longer, an even curve and a spring with no overshoot;
  /// - crisp: a quarter shorter, a sharp curve and a stiff spring;
  /// - lively: about as long, with an overshooting curve and a bouncy spring;
  /// - none: nothing animates; every change is at once.
  factory MyDataMotionSpec.of(MotionSpec m) {
    final (fast, base, slow, curve, spring, springMs) = switch (m.personality) {
      MotionPersonality.standard => (
          MyDataMotion.fast, MyDataMotion.base, MyDataMotion.slow, MyDataMotion.standard, MyDataMotion.spring,
          MyDataMotion.springDuration,
        ),
      MotionPersonality.none => (
          Duration.zero, Duration.zero, Duration.zero, MyDataMotion.standard, MyDataMotion.spring, Duration.zero,
        ),
      MotionPersonality.calm => (
          MyDataMotion.fast * 4 ~/ 3, MyDataMotion.base * 4 ~/ 3, MyDataMotion.slow * 5 ~/ 4,
          const Cubic(0.25, 0.1, 0.25, 1), SpringDescription.withDampingRatio(mass: 1, stiffness: 120, ratio: 1),
          MyDataMotion.springDuration * 9 ~/ 7,
        ),
      MotionPersonality.crisp => (
          MyDataMotion.fast * 3 ~/ 4, MyDataMotion.base * 3 ~/ 4, MyDataMotion.slow * 3 ~/ 4,
          const Cubic(0.3, 0, 0, 1), SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.95),
          MyDataMotion.springDuration * 5 ~/ 7,
        ),
      MotionPersonality.lively => (
          MyDataMotion.fast, MyDataMotion.base * 13 ~/ 12, MyDataMotion.slow * 20 ~/ 19,
          const Cubic(0.34, 1.3, 0.64, 1), SpringDescription.withDampingRatio(mass: 1, stiffness: 220, ratio: 0.6),
          MyDataMotion.springDuration * 9 ~/ 7,
        ),
    };
    Duration scaled(Duration d, {Duration? cap}) {
      final v = Duration(microseconds: (d.inMicroseconds * m.scale).round());
      return cap != null && v > cap ? cap : v;
    }

    final pressScale = m.press == PressStyle.dimScale ? MyDataMotion.pressScale : 1.0;
    final pressOpacity = m.press == PressStyle.dim || m.press == PressStyle.dimScale ? MyDataMotion.pressOpacity : 1.0;
    return MyDataMotionSpec(
      personality: m.personality,
      fast: scaled(fast),
      base: scaled(base),
      slow: scaled(slow, cap: const Duration(milliseconds: 500)),
      standard: curve,
      spring: spring,
      springDuration: scaled(springMs),
      pressScale: pressScale,
      pressOpacity: pressOpacity,
      press: m.press,
      enter: m.enter,
      entranceRise: m.enter == EnterStyle.fadeRise ? MyDataMotion.entranceRise : 0,
      entranceStagger: m.enter == EnterStyle.none ? Duration.zero : MyDataMotion.entranceStagger,
      entranceMaxStaggered: m.enter == EnterStyle.none ? 0 : MyDataMotion.entranceMaxStaggered,
      sheetDrop: MyDataMotion.sheetDrop,
    );
  }
}

/// One theme and palette, resolved for one brightness.
@immutable
class MyDataLook extends ThemeExtension<MyDataLook> {
  const MyDataLook({
    required this.themeId,
    required this.paletteId,
    required this.frame,
    required this.brightness,
    this.increasedContrast = false,
    required this.colors,
    required this.typeScale,
    required this.shape,
    required this.density,
    required this.edges,
    required this.elevation,
    required this.materials,
    required this.icons,
    required this.motion,
    required this.variants,
  });

  final String themeId;

  /// Null for a theme without palettes (System).
  final String? paletteId;
  final LookFrame frame;
  final Brightness brightness;
  final bool increasedContrast;
  final MyDataColors colors;

  /// The text styles. Not `type`: ThemeExtension keys extensions by their `type`.
  final MyDataTypeScale typeScale;
  final MyDataShape shape;
  final MyDataDensity density;
  final MyDataEdges edges;
  final MyDataElevation elevation;
  final MyDataMaterials materials;
  final MyDataIconTheme icons;
  final MyDataMotionSpec motion;
  final MyDataVariants variants;

  static final _nearDanger = Expando<bool>('accent near danger');

  /// The accent is within 25° of hue of `danger`, both colourful (2.2, "Kept apart"): Approve and every
  /// filled primary button are then drawn in `ink`, with their label in `bg`, so Approve never looks like
  /// Delete. Never in System, whose accent is the system's and whose destructive buttons are red text.
  bool get accentNearDanger =>
      frame == LookFrame.drawn && (_nearDanger[colors] ??= accentNearDangerOf(colors.accent, colors.danger));

  /// Whether [accent] and [danger] are within 25° of hue, both with OKLCH chroma over 0.04 (the validator's
  /// notice, checks.dart).
  static bool accentNearDangerOf(Color accent, Color danger) {
    final a = Oklch.of(Rgb.argb(accent.toARGB32())), d = Oklch.of(Rgb.argb(danger.toARGB32()));
    return a.c > 0.04 && d.c > 0.04 && hueDistance(a.h, d.h) < 25;
  }

  /// `space-n` in this look (`space(4)` is 16 at Kiwi's density).
  double space(num n) => density.space(n);

  /// [theme] in [paletteId] (its default palette when null or unknown) for [brightness]. The density class
  /// is the platform's: phones (iOS, Android) take the theme's phone set, everything else the desktop set.
  ///
  /// System (`frame: system`) is drawn here with its style (Kiwi's until each platform's pass, but with round
  /// corners, as it was drawn before phase 3) in Kiwi's default palette, or in a "System, tinted" palette off macOS ([systemPalette]); its [paletteId] is null
  /// unless a tint is drawn. On macOS the Mac shell puts the system's own colours over it (`MacTheme.data`).
  factory MyDataLook.resolve(
    ThemeFile theme, {
    String? paletteId,
    required Brightness brightness,
    required RoleDefaults defaults,
    bool increasedContrast = false,
    TargetPlatform? platform,
  }) {
    final target = platform ?? defaultTargetPlatform;
    final system = theme.frame == ThemeFrame.system;
    final tint = system && target != TargetPlatform.macOS ? theme.palette(paletteId) : null;
    final palette = system ? systemPalette(defaults, tint) : theme.palette(paletteId)!;
    final mode = brightness == Brightness.dark ? LookMode.dark : LookMode.light;
    final p = resolvePalette(theme, palette, mode, defaults: defaults, increasedContrast: increasedContrast);
    final fixed = brightness == Brightness.dark ? MyDataColors.dark : MyDataColors.light;
    final colors = colorsOf(p, fixed: fixed);
    final s = theme.style;
    final phone = switch (target) {
      TargetPlatform.iOS || TargetPlatform.android => true,
      _ => false,
    };
    return MyDataLook(
      themeId: theme.id,
      paletteId: system ? tint?.id : palette.id,
      frame: system ? LookFrame.system : LookFrame.drawn,
      brightness: brightness,
      increasedContrast: increasedContrast,
      colors: colors,
      typeScale: MyDataTypeScale.of(s.type, platform: target),
      // System keeps round corners on every platform until that platform's own pass (the Mac shell's
      // too, [asSystem]), though its style is Kiwi's, whose corners are continuous since phase 3.
      shape: system ? MyDataShape.of(s.shape).withCorners(CornerStyle.round) : MyDataShape.of(s.shape),
      density: MyDataDensity.of(phone ? s.density.phone : s.density.desktop, floor: MyDataDensity.floorFor(target)),
      edges: MyDataEdges(s.borders,
          colour: MyDataEdges.colourOf(s.borders, colors),
          controlColour: MyDataEdges.controlColourOf(s.borders, colors),
          allControls: increasedContrast),
      elevation: MyDataElevation.of(s.elevation,
          shadow: colors.shadow,
          accent: colors.accent,
          surface: colors.surface,
          ink: colors.ink,
          dark: brightness == Brightness.dark),
      materials: MyDataMaterials(
          spec: s.materials, blur: s.materials.blur, gradient: p.gradient?.map(_color).toList(growable: false)),
      icons: MyDataIconTheme(s.icons),
      motion: MyDataMotionSpec.of(s.motion),
      variants: MyDataVariants(s.components.values),
    );
  }

  /// Kiwi in its own colour from the generated constants: the first frame, tests, and whenever no look is
  /// in the theme, so nothing is ever drawn unthemed.
  /// Its density is held at the platform's floor ([MyDataDensity.floorFor]), as a resolved look's is, so
  /// Android's first frame has 48 px targets too.
  static MyDataLook fallback(Brightness brightness) {
    final floor = MyDataDensity.floorFor(defaultTargetPlatform);
    return _fallbacks[(brightness, floor)] ??= _fallback(brightness, floor);
  }

  static final _fallbacks = <(Brightness, double), MyDataLook>{};

  static MyDataLook _fallback(Brightness b, double floor) {
    final dark = b == Brightness.dark;
    return MyDataLook(
      themeId: 'mydata.kiwi',
      paletteId: 'kiwi',
      frame: LookFrame.drawn,
      brightness: b,
      colors: dark ? MyDataColors.dark : MyDataColors.light,
      typeScale: MyDataTypeScale.kiwi,
      shape: MyDataShape.kiwi,
      density: MyDataDensity.kiwi.atLeast(floor),
      edges: MyDataEdges(_kiwiBorders,
          colour: (dark ? MyDataColors.dark : MyDataColors.light).line,
          controlColour: (dark ? MyDataColors.dark : MyDataColors.light).lineStrong),
      elevation: MyDataElevation(
          style: ElevationStyle.soft, shadows: dark ? MyDataShadows.dark : MyDataShadows.light, collapse: false),
      materials: const MyDataMaterials(spec: _kiwiMaterials, blur: MyDataBlur.glass),
      icons: MyDataIconTheme(_kiwiIcons),
      motion: MyDataMotionSpec.kiwi,
      variants: MyDataVariants.kiwi,
    );
  }

  /// The look in [context]'s theme. With [listen] false the widget is not rebuilt when the theme changes, and
  /// it may be read where a dependency cannot be made (`initState`, a late field first used there).
  ///
  /// While the pointer is coarse (a finger on a desktop's touch screen, [MyDataAccessibility.coarsePointer])
  /// its density is raised to [MyDataDensity.coarseFloor] ([coarse]), so every read of a size, `look.density`
  /// in a layout sum as much as `context.density` in a build, agrees with what is drawn.
  static MyDataLook of(BuildContext context, {bool listen = true}) {
    final theme = listen ? Theme.of(context) : context.findAncestorWidgetOfExactType<Theme>()?.data;
    final look = theme?.extension<MyDataLook>() ?? fallback(theme?.brightness ?? Brightness.light);
    final access = listen
        ? context.dependOnInheritedWidgetOfExactType<MyDataAccessibility>()
        : context.getInheritedWidgetOfExactType<MyDataAccessibility>();
    return access?.coarsePointer ?? false ? look.coarse : look;
  }

  static final _coarse = Expando<(double, MyDataLook)>('coarse');

  /// This look for a coarse pointer: its density at least [MyDataDensity.coarseFloor]; itself when already
  /// there. Kept per look, so a widget that reads it many times a build makes it once.
  MyDataLook get coarse {
    final floor = MyDataDensity.coarseFloor;
    if (floor <= density.minTarget) return this;
    final kept = _coarse[this];
    if (kept != null && kept.$1 == floor) return kept.$2;
    final raised = copyWith(density: density.atLeast(floor));
    _coarse[this] = (floor, raised);
    return raised;
  }

  @override
  MyDataLook copyWith({
    String? themeId,
    String? paletteId,
    LookFrame? frame,
    Brightness? brightness,
    bool? increasedContrast,
    MyDataColors? colors,
    MyDataTypeScale? typeScale,
    MyDataShape? shape,
    MyDataDensity? density,
    MyDataEdges? edges,
    MyDataElevation? elevation,
    MyDataMaterials? materials,
    MyDataIconTheme? icons,
    MyDataMotionSpec? motion,
    MyDataVariants? variants,
  }) =>
      MyDataLook(
        themeId: themeId ?? this.themeId,
        paletteId: paletteId ?? this.paletteId,
        frame: frame ?? this.frame,
        brightness: brightness ?? this.brightness,
        increasedContrast: increasedContrast ?? this.increasedContrast,
        colors: colors ?? this.colors,
        typeScale: typeScale ?? this.typeScale,
        shape: shape ?? this.shape,
        density: density ?? this.density,
        edges: edges ?? (colors == null ? this.edges : this.edges.withColours(colors)),
        elevation: elevation ?? this.elevation,
        materials: materials ?? this.materials,
        icons: icons ?? this.icons,
        motion: motion ?? this.motion,
        variants: variants ?? this.variants,
      );

  /// This look as System draws it in the Mac shell: [colors] are the system's, and System has no palette
  /// ([copyWith] cannot clear [paletteId]). Its corners stay round, as the Mac shell was drawn when it was
  /// chosen (decision 8), though Kiwi, whose style System takes, has continuous corners since phase 3: the
  /// Mac's own pass decides, not Kiwi's.
  MyDataLook asSystem({required MyDataColors colors}) => MyDataLook(
        themeId: systemThemeId,
        paletteId: null,
        frame: LookFrame.system,
        brightness: brightness,
        increasedContrast: increasedContrast,
        colors: colors,
        typeScale: typeScale,
        shape: shape.withCorners(CornerStyle.round),
        density: density,
        edges: edges.withColours(colors),
        elevation: elevation,
        materials: materials,
        icons: icons,
        motion: motion,
        variants: variants,
      );

  /// System's theme id.
  static const systemThemeId = 'mydata.system';

  /// Colours, sizes and shadows are interpolated; everything else switches at the half way point.
  @override
  MyDataLook lerp(MyDataLook? other, double t) {
    if (other == null) return this;
    final o = t < 0.5 ? this : other;
    return MyDataLook(
      themeId: o.themeId,
      paletteId: o.paletteId,
      frame: o.frame,
      brightness: o.brightness,
      increasedContrast: o.increasedContrast,
      colors: colors.lerp(other.colors, t),
      // Type is never drawn in between: past t = 0 it is the new look's (fonts, sizes and weights at once).
      typeScale: t == 0 ? typeScale : other.typeScale,
      shape: MyDataShape.lerp(shape, other.shape, t),
      density: MyDataDensity.lerp(density, other.density, t),
      edges: o.edges,
      elevation: MyDataElevation(
          style: o.elevation.style,
          shadows: elevation.shadows.lerp(other.elevation.shadows, t),
          collapse: o.elevation.collapse,
          control: BoxShadow.lerpList(elevation.control, other.elevation.control, t)!,
          glow: BoxShadow.lerpList(elevation.glow, other.elevation.glow, t)!,
          sink: Offset.lerp(elevation.sink, other.elevation.sink, t)!,
          bevel: o.elevation.bevel),
      materials: MyDataMaterials(
          spec: o.materials.spec,
          blur: lerpDouble(materials.blur, other.materials.blur, t),
          gradient: o.materials.gradient),
      icons: o.icons,
      motion: o.motion,
      variants: o.variants,
    );
  }
}

/// MyDataColors from a resolved palette. The artwork colours (`brand`, `skin`, `cream`, `paper`) are never
/// a theme's: they come from [fixed].
MyDataColors colorsOf(ResolvedPalette p, {required MyDataColors fixed}) {
  Color v(ColourRole r) => _color(p[r]);
  return MyDataColors(
    bg: v(ColourRole.bg),
    surface: v(ColourRole.surface),
    surfaceRaised: v(ColourRole.surfaceRaised),
    surfaceSunken: v(ColourRole.surfaceSunken),
    surfaceHover: v(ColourRole.surfaceHover),
    line: v(ColourRole.line),
    lineStrong: v(ColourRole.lineStrong),
    ink: v(ColourRole.ink),
    inkMuted: v(ColourRole.inkMuted),
    accent: v(ColourRole.accent),
    onAccent: v(ColourRole.onAccent),
    accentSoft: v(ColourRole.accentSoft),
    brand: fixed.brand,
    kiwiWash: v(ColourRole.avatarFill),
    skin: fixed.skin,
    cream: fixed.cream,
    paper: fixed.paper,
    success: v(ColourRole.success),
    successSoft: v(ColourRole.successSoft),
    warning: v(ColourRole.warning),
    warningSoft: v(ColourRole.warningSoft),
    danger: v(ColourRole.danger),
    dangerSoft: v(ColourRole.dangerSoft),
    onDanger: v(ColourRole.onDanger),
    info: v(ColourRole.info),
    infoSoft: v(ColourRole.infoSoft),
    focus: v(ColourRole.focus),
    glassFill: v(ColourRole.glassFill),
    glassStroke: v(ColourRole.glassStroke),
    scrim: v(ColourRole.scrim),
    dataRed: v(ColourRole.dataRed),
    dataOrange: v(ColourRole.dataOrange),
    dataYellow: v(ColourRole.dataYellow),
    dataGreen: v(ColourRole.dataGreen),
    dataBlue: v(ColourRole.dataBlue),
    dataPurple: v(ColourRole.dataPurple),
    dataBrown: v(ColourRole.dataBrown),
    dataGrey: v(ColourRole.dataGrey),
    sidebar: v(ColourRole.sidebar),
    toolbar: v(ColourRole.toolbar),
    edge: v(ColourRole.edge),
    link: v(ColourRole.link),
    selection: v(ColourRole.selection),
    onSelection: v(ColourRole.onSelection),
    selectionInactive: v(ColourRole.selectionInactive),
    focusOnDanger: v(ColourRole.focusOnDanger),
    avatarFill: v(ColourRole.avatarFill),
    shadow: v(ColourRole.shadow),
    onAvatar: _color(p.onAvatar),
  );
}

const _kiwiBorders = BordersSpec(
  width: BorderWidth.one,
  style: BorderStyleKind.solid,
  colour: BorderColour.line,
  cards: false,
  controls: false,
  separators: Separators.full,
  titleRule: TitleRule.none,
);
const _kiwiMaterials = MaterialsSpec(
  window: WindowKind.solid,
  sidebar: SidebarMaterial.solid,
  bars: BarMaterial.blur,
  blur: MyDataBlur.glass,
);
const _kiwiIcons = IconsSpec(set: 'lucide', weight: 'regular', fillSelected: false, tiles: 'tinted');
