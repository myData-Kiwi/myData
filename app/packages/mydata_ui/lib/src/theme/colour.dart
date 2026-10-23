/// Colour arithmetic for the theme resolver and validator (design/themes/ARCHITECTURE.md 1.3 and 2.2).
///
/// Pure Dart, no Flutter: `tool/generate_tokens.dart` runs the resolver without the engine. Contrast is
/// WCAG 2.x relative luminance (https://www.w3.org/TR/WCAG22/#dfn-contrast-ratio); OKLab and OKLCH are Björn
/// Ottosson's (https://bottosson.github.io/posts/oklab/).
library;

import 'dart:math' as math;

/// An sRGB colour with 8-bit channels, as a theme file writes it (`#RRGGBB` or `#RRGGBBAA`).
class Rgb {
  const Rgb(this.r, this.g, this.b, [this.a = 255]);

  /// From `0xAARRGGBB`.
  const Rgb.argb(int v)
      : a = (v >> 24) & 0xFF,
        r = (v >> 16) & 0xFF,
        g = (v >> 8) & 0xFF,
        b = v & 0xFF;

  final int r, g, b, a;

  static final _hex = RegExp(r'^#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$');

  /// `#RRGGBB` or `#RRGGBBAA`, or null.
  static Rgb? tryParse(String text) {
    final m = _hex.firstMatch(text);
    if (m == null) return null;
    final v = int.parse(m[1]!, radix: 16);
    final a = m[2] == null ? 255 : int.parse(m[2]!, radix: 16);
    return Rgb((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, a);
  }

  static Rgb parse(String text) => tryParse(text) ?? (throw FormatException('not a colour: $text'));

  /// `0xAARRGGBB`.
  int get argb => (a << 24) | (r << 16) | (g << 8) | b;

  bool get opaque => a == 255;

  /// `#RRGGBB`, with `AA` only when not opaque.
  String get hex {
    String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${h(r)}${h(g)}${h(b)}${opaque ? '' : h(a)}';
  }

  Rgb withAlpha(int alpha) => Rgb(r, g, b, alpha);

  /// This colour, at its alpha, over an opaque [ground].
  Rgb over(Rgb ground) {
    if (opaque) return this;
    final t = a / 255;
    int ch(int f, int b) => (f * t + b * (1 - t)).round().clamp(0, 255);
    return Rgb(ch(r, ground.r), ch(g, ground.g), ch(b, ground.b));
  }

  /// WCAG relative luminance (alpha ignored: composite first).
  double get luminance => 0.2126 * _lin(r / 255) + 0.7152 * _lin(g / 255) + 0.0722 * _lin(b / 255);

  @override
  bool operator ==(Object other) => other is Rgb && other.argb == argb;

  @override
  int get hashCode => argb;

  @override
  String toString() => hex;
}

double _lin(double x) => x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();

double _gam(double x) => x <= 0.0031308 ? 12.92 * x : 1.055 * math.pow(x, 1 / 2.4) - 0.055;

/// WCAG contrast ratio of two colours; a translucent one is composited over the other first.
double contrast(Rgb a, Rgb b) {
  final fg = a.opaque ? a : a.over(b.opaque ? b : b.over(const Rgb(255, 255, 255)));
  final bg = b.opaque ? b : b.over(fg);
  final la = fg.luminance, lb = bg.luminance;
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A colour in OKLab.
class Oklab {
  const Oklab(this.l, this.a, this.b);
  final double l, a, b;

  factory Oklab.of(Rgb c) {
    final r = _lin(c.r / 255), g = _lin(c.g / 255), b = _lin(c.b / 255);
    double cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
    final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return Oklab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  /// Back to sRGB, each channel clamped to the gamut, with [alpha].
  Rgb toRgb([int alpha = 255]) {
    final l = math.pow(this.l + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
    final m = math.pow(this.l - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
    final s = math.pow(this.l - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
    final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    final bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    int ch(double v) => (_gam(v.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
    return Rgb(ch(r), ch(g), ch(bb), alpha);
  }
}

/// A colour in OKLCH: lightness 0–1, chroma, hue in degrees.
class Oklch {
  const Oklch(this.l, this.c, this.h);
  final double l, c, h;

  factory Oklch.of(Rgb rgb) {
    final lab = Oklab.of(rgb);
    final h = math.atan2(lab.b, lab.a) * 180 / math.pi;
    return Oklch(lab.l, math.sqrt(lab.a * lab.a + lab.b * lab.b), (h + 360) % 360);
  }

  Rgb toRgb([int alpha = 255]) {
    final rad = h * math.pi / 180;
    return Oklab(l, c * math.cos(rad), c * math.sin(rad)).toRgb(alpha);
  }
}

/// [t] of the way from [a] to [b], interpolated in OKLab (alpha kept from [a]).
Rgb mix(Rgb a, Rgb b, double t) {
  final x = Oklab.of(a), y = Oklab.of(b);
  return Oklab(x.l + (y.l - x.l) * t, x.a + (y.a - x.a) * t, x.b + (y.b - x.b) * t).toRgb(a.a);
}

/// [c] with its OKLCH lightness moved by [delta], hue and chroma kept.
Rgb shiftLightness(Rgb c, double delta) {
  final o = Oklch.of(c);
  return Oklch((o.l + delta).clamp(0.0, 1.0), o.c, o.h).toRgb(c.a);
}

/// Distance in OKLab (ΔE_OK).
double deltaE(Rgb a, Rgb b) {
  final x = Oklab.of(a), y = Oklab.of(b);
  final dl = x.l - y.l, da = x.a - y.a, db = x.b - y.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// The shorter way round between two hues, in degrees.
double hueDistance(double h1, double h2) {
  final d = (h1 - h2).abs() % 360;
  return math.min(d, 360 - d);
}

/// One requirement a colour must meet: [ratio]:1 against [ground].
typedef ContrastNeed = ({Rgb ground, double ratio});

/// [c] moved in OKLCH lightness only (hue and chroma kept) the least distance that meets every need, or null
/// when no lightness does. [c] itself when it already meets them.
Rgb? tuneLightness(Rgb c, List<ContrastNeed> needs) {
  bool ok(Rgb x) => needs.every((n) => contrast(x, n.ground) >= n.ratio);
  if (ok(c)) return c;
  final o = Oklch.of(c);
  for (var i = 1; i <= 1000; i++) {
    final d = i / 1000;
    for (final l in [o.l - d, o.l + d]) {
      if (l < 0 || l > 1) continue;
      final x = Oklch(l, o.c, o.h).toRgb(c.a);
      if (ok(x)) return x;
    }
  }
  return null;
}

/// From [start] towards [target] in steps of 1% until [ratio]:1 against every ground; [target] if never.
Rgb mixUntil(Rgb start, Rgb target, double ratio, List<Rgb> grounds, {int from = 0}) {
  for (var i = from; i <= 100; i++) {
    final x = mix(start, target, i / 100);
    if (grounds.every((g) => contrast(x, g) >= ratio)) return x;
  }
  return target;
}
