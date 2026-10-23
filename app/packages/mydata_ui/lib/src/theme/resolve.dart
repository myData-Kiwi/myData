/// The palette resolver (design/themes/ARCHITECTURE.md 1.3 and 2.2): every role of one palette in one mode,
/// at normal or increased contrast. Pure Dart.
///
/// Order, as 1.3 gives it: the palette's values, then `colour-use.same-as` (for keys whose source has a
/// value), then the derivations for the roles still missing, then `same-as` again. At increased contrast the
/// palette's own `contrast` set is merged over that, or the 7:1 values are derived, and `same-as` is applied
/// once more. Derived colours are mixed in OKLab and then moved in OKLCH lightness only (hue and chroma kept)
/// until the pairs of 2.2 they belong to pass.
library;

import 'colour.dart';
import 'roles.dart';
import 'theme_file.dart';

/// Today's values (Kiwi's palette in design/tokens.json): the starting point for derived status, focus,
/// calendar, glass, scrim, shadow and avatar colours.
class RoleDefaults {
  const RoleDefaults({required this.light, required this.dark});
  final Map<ColourRole, Rgb> light, dark;

  Map<ColourRole, Rgb> of(LookMode mode) => mode == LookMode.dark ? dark : light;
}

/// One palette resolved for one mode.
class ResolvedPalette {
  const ResolvedPalette({
    required this.mode,
    required this.roles,
    required this.derived,
    required this.increasedContrast,
    this.gradient,
  });

  final LookMode mode;

  /// All 43 roles.
  final Map<ColourRole, Rgb> roles;

  /// The roles the palette did not give, which the resolver derived.
  final Set<ColourRole> derived;
  final bool increasedContrast;

  /// The window gradient's stops, when the style's window is a gradient.
  final List<Rgb>? gradient;

  Rgb operator [](ColourRole r) => roles[r]!;

  /// Initials on an avatar: whichever of `ink` and `surface` has more contrast on `avatar-fill` (2.2).
  Rgb get onAvatar {
    final fill = this[ColourRole.avatarFill];
    final ink = this[ColourRole.ink], surface = this[ColourRole.surface];
    return contrast(ink, fill) >= contrast(surface, fill) ? ink : surface;
  }
}

/// System's palette where myData draws it (off macOS, and in checks): Kiwi's default palette ([defaults]).
/// With [tint], a "System, tinted" palette (ARCHITECTURE.md 1.6): its accent replaces Kiwi's, and the roles
/// drawn from the accent (`accent-soft`, `selection`, `link`) are derived again, with those that follow them
/// (`on-selection`, `focus`) and `glass-fill`, which must read over the accent and the selection. Everything
/// else a tint gives is ignored.
ThemePalette systemPalette(RoleDefaults defaults, [ThemePalette? tint]) {
  Map<ColourRole, Rgb> of(LookMode mode) {
    final kiwi = defaults.of(mode);
    final accent = tint?.given(mode)[ColourRole.accent];
    if (accent == null) return kiwi;
    return {
      for (final e in kiwi.entries)
        if (!_fromAccent.contains(e.key)) e.key: e.value,
      ColourRole.accent: accent,
    };
  }

  return ThemePalette(
    id: tint?.id ?? 'system',
    name: tint?.name ?? 'System',
    light: of(LookMode.light),
    dark: of(LookMode.dark),
  );
}

const _fromAccent = {
  ColourRole.accentSoft, ColourRole.selection, ColourRole.link, ColourRole.onSelection, ColourRole.focus,
  ColourRole.glassFill,
};

/// Resolves [palette] of [theme] in [mode].
ResolvedPalette resolvePalette(
  ThemeFile theme,
  ThemePalette palette,
  LookMode mode, {
  required RoleDefaults defaults,
  bool increasedContrast = false,
}) {
  final given = palette.given(mode);
  final c = <ColourRole, Rgb>{...given};
  _applySameAs(theme.sameAs, c, onlyWhereSourceKnown: true);
  final derived = {
    for (final r in ColourRole.values)
      if (!c.containsKey(r)) r,
  };
  _derive(c, mode, defaults.of(mode),
      edgeIsBorder: theme.style.borders.colour == BorderColour.edge,
      inverseSelection: theme.style.components.values['selection'] == 'inverse');
  _applySameAs(theme.sameAs, c);
  if (increasedContrast) {
    final set = palette.contrastSet(mode);
    if (set.isNotEmpty) {
      c.addAll(set);
    } else {
      _deriveIncreased(c, theme);
    }
    _applySameAs(theme.sameAs, c);
  }
  List<Rgb>? gradient;
  if (theme.style.materials.window == WindowKind.gradient) {
    gradient = palette.gradient(mode) ??
        [
          mix(c[ColourRole.bg]!, c[ColourRole.accent]!, 0.08),
          c[ColourRole.bg]!,
          mix(c[ColourRole.bg]!, c[ColourRole.ink]!, 0.05),
        ];
  }
  return ResolvedPalette(
    mode: mode,
    roles: Map.unmodifiable(c),
    derived: derived,
    increasedContrast: increasedContrast,
    gradient: gradient,
  );
}

void _applySameAs(Map<ColourRole, ColourRole> sameAs, Map<ColourRole, Rgb> c, {bool onlyWhereSourceKnown = false}) {
  for (final e in sameAs.entries) {
    final v = c[e.value];
    if (v != null) {
      c[e.key] = v;
    } else if (!onlyWhereSourceKnown) {
      throw StateError('same-as source ${e.value.key} has no value');
    }
  }
}

const _ink45 = 4.5;

/// Fills every role missing from [c] (1.3's table), each tuned to its 2.2 pairs.
void _derive(
  Map<ColourRole, Rgb> c,
  LookMode mode,
  Map<ColourRole, Rgb> today, {
  required bool edgeIsBorder,
  required bool inverseSelection,
}) {
  final dark = mode == LookMode.dark;
  Rgb v(ColourRole r) => c[r]!;
  void put(ColourRole r, Rgb Function() make, [List<ContrastNeed> Function()? needs]) {
    if (c.containsKey(r)) return;
    var x = make();
    if (needs != null) x = tuneLightness(x, needs()) ?? x;
    c[r] = x;
  }

  // A ground that text sits on: tuned until ink (and secondary text) can be read on it.
  List<ContrastNeed> textGround({bool muted = true}) => [
        (ground: v(ColourRole.ink), ratio: _ink45),
        if (muted) (ground: v(ColourRole.inkMuted), ratio: _ink45),
      ];

  put(ColourRole.surfaceRaised, () => dark ? shiftLightness(v(ColourRole.surface), 0.04) : v(ColourRole.surface),
      textGround);
  put(ColourRole.surfaceSunken, () => mix(v(ColourRole.bg), v(ColourRole.ink), 0.06), textGround);
  put(
    ColourRole.surfaceHover,
    () => mixUntil(v(ColourRole.surface), v(ColourRole.ink), 1.3,
        [v(ColourRole.bg), v(ColourRole.surface), v(ColourRole.surfaceRaised)]),
    textGround,
  );
  put(ColourRole.sidebar, () => v(ColourRole.bg), textGround);
  put(ColourRole.toolbar, () => v(ColourRole.surface), textGround);
  put(ColourRole.line, () => mix(v(ColourRole.surface), v(ColourRole.ink), 0.10));
  put(
    ColourRole.lineStrong,
    () => mixUntil(v(ColourRole.surface), v(ColourRole.ink), 3,
        [v(ColourRole.bg), v(ColourRole.surface), v(ColourRole.surfaceRaised), v(ColourRole.sidebar)]),
  );
  put(
    ColourRole.edge,
    () => v(ColourRole.ink),
    edgeIsBorder ? () => [(ground: v(ColourRole.bg), ratio: 3), (ground: v(ColourRole.surface), ratio: 3)] : null,
  );
  put(ColourRole.accentSoft, () => mix(v(ColourRole.surface), v(ColourRole.accent), dark ? 0.22 : 0.12), textGround);
  put(ColourRole.selection, () => v(ColourRole.accent));
  put(ColourRole.selectionInactive, () => v(ColourRole.surfaceSunken), () => textGround());
  if (!c.containsKey(ColourRole.link)) {
    c[ColourRole.link] = tuneLightness(v(ColourRole.accent), [
          for (final g in linkGrounds) (ground: v(g), ratio: _ink45),
        ]) ??
        v(ColourRole.ink);
  }
  put(ColourRole.onSelection, () => v(ColourRole.onAccent),
      () => [(ground: v(ColourRole.selection), ratio: _ink45)]);
  if (!c.containsKey(ColourRole.focus)) {
    // Today's red ring, else today's blue (Sticker's and Paperback's), where red would be lost on the
    // selection (2.2, "Kept apart"); ink when neither can be seen.
    final marker = inverseSelection ? v(ColourRole.ink) : v(ColourRole.selection);
    final needs = [for (final g in focusGrounds) (ground: v(g), ratio: 3.0)];
    c[ColourRole.focus] = [today[ColourRole.focus]!, today[ColourRole.info]!]
            .map((x) => tuneLightness(x, needs))
            .firstWhere((x) => x != null && focusKeptApart(x, marker), orElse: () => null) ??
        v(ColourRole.ink);
  }
  for (final e in ColourRole.status.entries) {
    put(e.value, () => today[e.value]!, () => textGround(muted: false));
    if (!c.containsKey(e.key)) {
      c[e.key] = tuneLightness(today[e.key]!, [
            for (final g in [ColourRole.surface, ColourRole.bg, ColourRole.surfaceRaised, e.value])
              (ground: v(g), ratio: _ink45),
          ]) ??
          v(ColourRole.ink);
    }
  }
  put(ColourRole.onDanger, () => today[ColourRole.onDanger]!, () => [(ground: v(ColourRole.danger), ratio: _ink45)]);
  put(ColourRole.focusOnDanger, () => v(ColourRole.ink),
      () => [(ground: v(ColourRole.dangerSoft), ratio: 3), (ground: v(ColourRole.surface), ratio: 3)]);
  put(ColourRole.avatarFill, () => today[ColourRole.avatarFill]!);
  for (final d in ColourRole.data) {
    put(d, () => today[d]!);
  }
  for (final r in [ColourRole.scrim, ColourRole.glassStroke, ColourRole.shadow]) {
    put(r, () => today[r]!);
  }
  // Glass: this palette's surface at today's opacity, made more opaque until text over it reads on whatever
  // scrolls beneath (2.2, "Glass and translucent bars").
  if (!c.containsKey(ColourRole.glassFill)) {
    final under = [ColourRole.bg, ColourRole.surface, ColourRole.ink, ColourRole.accent, ColourRole.selection];
    var glass = v(ColourRole.surface).withAlpha(today[ColourRole.glassFill]!.a);
    bool reads(Rgb g) => under.every((u) {
          final ground = g.over(v(u));
          return contrast(v(ColourRole.ink), ground) >= _ink45 && contrast(v(ColourRole.inkMuted), ground) >= _ink45;
        });
    while (glass.a < 255 && !reads(glass)) {
      glass = glass.withAlpha(glass.a + 1);
    }
    c[ColourRole.glassFill] = glass;
  }
}

/// Whether a focus ring [focus] can be told from the selection [marker] it may sit on (2.2, "Kept apart"):
/// 3:1, or a ring much more colourful than a grey marker, or 60° of hue between two colours.
bool focusKeptApart(Rgb focus, Rgb marker) {
  final f = Oklch.of(focus), s = Oklch.of(marker);
  return contrast(focus, marker) >= 3 ||
      (s.c < 0.04 && f.c - s.c >= 0.08) ||
      (f.c >= 0.04 && s.c >= 0.04 && hueDistance(f.h, s.h) >= 60);
}

/// The grounds a link may be drawn on (2.2).
const linkGrounds = [
  ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.surfaceSunken, ColourRole.sidebar,
  ColourRole.accentSoft,
];

const _ink7 = 7.0;

/// The grounds text is drawn on (2.2's text rows), for the 7:1 derivation.
const textGrounds = [
  ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.surfaceSunken, ColourRole.surfaceHover,
  ColourRole.sidebar, ColourRole.toolbar, ColourRole.accentSoft, ColourRole.selectionInactive,
];

/// The 7:1 values when the palette has no `contrast` set (2.2, the 7:1 row; 2.3, "increase contrast"):
/// secondary text becomes `ink` and decorative lines `line-strong`; every other text colour, and the grounds
/// and fills text sits on, move in lightness until each text pair reaches 7:1; a status `-soft` fill that
/// leaves no room becomes `surface-sunken`. Non-text roles are tuned again to 3:1 against the grounds that
/// moved.
void _deriveIncreased(Map<ColourRole, Rgb> c, ThemeFile theme) {
  Rgb v(ColourRole r) => c[r]!;
  List<ContrastNeed> on(Iterable<ColourRole> grounds, double ratio) =>
      [for (final g in grounds) (ground: v(g), ratio: ratio)];

  c[ColourRole.inkMuted] = v(ColourRole.ink);
  c[ColourRole.line] = v(ColourRole.lineStrong);

  // Grounds: each must carry ink at 7:1. bg and surface are seeds: when they cannot, ink moves instead.
  for (final g in textGrounds) {
    if (g == ColourRole.bg || g == ColourRole.surface) continue;
    c[g] = tuneLightness(v(g), [(ground: v(ColourRole.ink), ratio: _ink7)]) ?? v(g);
  }
  c[ColourRole.ink] = tuneLightness(v(ColourRole.ink), on(textGrounds, _ink7)) ?? v(ColourRole.ink);
  c[ColourRole.inkMuted] = v(ColourRole.ink);
  for (final s in ColourRole.status.values) {
    c[s] = tuneLightness(v(s), [(ground: v(ColourRole.ink), ratio: _ink7)]) ?? v(s);
  }

  c[ColourRole.link] = tuneLightness(v(ColourRole.link), on(linkGrounds, _ink7)) ?? v(ColourRole.ink);

  // A label on its fill: the label moves; when it is already as dark or light as it goes, the fill moves.
  void label(ColourRole fg, ColourRole fill) {
    final moved = tuneLightness(v(fg), [(ground: v(fill), ratio: _ink7)]);
    if (moved != null) {
      c[fg] = moved;
    } else {
      c[fill] = tuneLightness(v(fill), [(ground: v(fg), ratio: _ink7)]) ?? v(fill);
    }
  }

  if (_accentIsText(theme)) {
    c[ColourRole.accent] =
        tuneLightness(v(ColourRole.accent), on([ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised], _ink7)) ??
            v(ColourRole.accent);
  }
  label(ColourRole.onAccent, ColourRole.accent);
  label(ColourRole.onSelection, ColourRole.selection);

  for (final e in ColourRole.status.entries) {
    const statusGrounds = [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised];
    var moved = tuneLightness(v(e.key), [...on(statusGrounds, _ink7), (ground: v(e.value), ratio: _ink7)]);
    if (moved == null) {
      c[e.value] = v(ColourRole.surfaceSunken);
      moved = tuneLightness(v(e.key), [...on(statusGrounds, _ink7), (ground: v(e.value), ratio: _ink7)]);
    }
    c[e.key] = moved ?? v(e.key);
  }
  label(ColourRole.onDanger, ColourRole.danger);
  c[ColourRole.focusOnDanger] =
      tuneLightness(v(ColourRole.focusOnDanger), on([ColourRole.dangerSoft, ColourRole.surface], 3)) ??
          v(ColourRole.focusOnDanger);

  // Non-text marks against the grounds that moved.
  c[ColourRole.lineStrong] =
      tuneLightness(v(ColourRole.lineStrong), on([ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.sidebar], 3)) ??
          v(ColourRole.lineStrong);
  c[ColourRole.line] = v(ColourRole.lineStrong);
  c[ColourRole.focus] = tuneLightness(v(ColourRole.focus), on(focusGrounds, 3)) ?? v(ColourRole.focus);
}

/// The grounds a focus ring may sit on (2.2, 3:1 non-text).
const focusGrounds = [
  ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.surfaceSunken, ColourRole.sidebar,
  ColourRole.toolbar, ColourRole.accentSoft, ColourRole.surfaceHover, ColourRole.selectionInactive,
];

/// Whether this style draws `accent` as text (an outline primary, a text or outline secondary, underlined tabs).
bool _accentIsText(ThemeFile theme) => accentIsText(theme.style.components);

bool accentIsText(ComponentsSpec components) =>
    components.values['button.primary'] == 'outline' ||
    const {'text', 'outline'}.contains(components.values['button.secondary']) ||
    components.values['tabs'] == 'underline';
