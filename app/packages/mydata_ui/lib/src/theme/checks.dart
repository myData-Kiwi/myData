/// The checks every theme passes (design/themes/ARCHITECTURE.md 2.2 and 2.3), run on resolved palettes and
/// on the style. One set of pairs: the batch-3 validator's and the critique's (`critique/contrast.py`), as 6a
/// asked. Pure Dart.
library;

import 'catalogue.dart';
import 'colour.dart';
import 'resolve.dart';
import 'roles.dart';
import 'theme_file.dart';

/// One check that did not pass, or a notice.
class ThemeFinding {
  const ThemeFinding(this.message, {this.notice = false});
  final String message;
  final bool notice;

  @override
  String toString() => message;
}

/// How people read a role's name in a sentence.
String roleWords(ColourRole r) => switch (r) {
      ColourRole.ink => 'text (ink)',
      ColourRole.inkMuted => 'secondary text (ink-muted)',
      ColourRole.bg => 'the window background (bg)',
      ColourRole.surface => 'cards (surface)',
      _ => r.key,
    };

String _ratio(double v) => v.toStringAsFixed(2);
String _need(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Themes whose text is checked at 7:1 at normal contrast too (ARCHITECTURE.md 2.2: accessibility-first).
const accessibilityFirst = {'mydata.high-contrast', 'mydata.e-ink'};

/// The accessibility themes: the accessibility-first two and Large. Their faint text (a disabled item,
/// another month's day) is drawn at 4.5:1 in the Mac window, as at increased contrast (MacTheme.colorsFor).
const accessibilityThemes = {...accessibilityFirst, 'mydata.large'};

/// The 2.2 checks of one resolved palette. [defaults] gives the reference hues of `danger` and the calendar
/// colours. At increased contrast, text needs 7:1 and materials count as solid (2.3).
List<ThemeFinding> checkColours(ThemeFile theme, ResolvedPalette p, RoleDefaults defaults, {String? palette}) {
  final out = <ThemeFinding>[];
  final mode = p.mode == LookMode.dark ? 'dark' : 'light';
  final where = [
    ?palette,
    '$mode mode',
    if (p.increasedContrast) 'increased contrast',
  ].join(', ');
  final textNeed = p.increasedContrast || accessibilityFirst.contains(theme.id) ? 7.0 : 4.5;
  final style = theme.style;
  Rgb v(ColourRole r) => p[r];

  void pair(String fgName, Rgb fg, String bgName, Rgb bg, double need, {bool notice = false}) {
    final r = contrast(fg, bg);
    if (r < need - 1e-9) {
      out.add(ThemeFinding('$where: $fgName on $bgName is ${_ratio(r)}:1; it needs ${_need(need)}:1.', notice: notice));
    }
  }

  void roles(ColourRole fg, ColourRole bg, double need) => pair(roleWords(fg), v(fg), roleWords(bg), v(bg), need);

  // Text (SC 1.4.3; 1.4.6 at increased contrast).
  for (final g in textGrounds) {
    roles(ColourRole.ink, g, textNeed);
    roles(ColourRole.inkMuted, g, textNeed);
  }
  for (final soft in ColourRole.status.values) {
    roles(ColourRole.ink, soft, textNeed);
  }
  for (final g in const [
    ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.surfaceSunken, ColourRole.sidebar,
    ColourRole.accentSoft,
  ]) {
    roles(ColourRole.link, g, textNeed);
  }
  roles(ColourRole.onAccent, ColourRole.accent, textNeed);
  roles(ColourRole.onSelection, ColourRole.selection, textNeed);
  roles(ColourRole.onDanger, ColourRole.danger, textNeed);
  pair('avatar initials', p.onAvatar, 'avatar-fill', v(ColourRole.avatarFill), textNeed);
  if (accentIsText(style.components)) {
    for (final g in const [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised]) {
      pair('accent drawn as text', v(ColourRole.accent), roleWords(g), v(g), textNeed);
    }
  }
  for (final e in ColourRole.status.entries) {
    for (final g in [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, e.value]) {
      roles(e.key, g, textNeed);
    }
  }

  // Non-text (SC 1.4.11).
  for (final g in const [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised, ColourRole.sidebar]) {
    roles(ColourRole.lineStrong, g, 3);
  }
  // A disabled filled button's outline on a sunken ground (a well, a footer): disabled controls are exempt
  // from SC 1.4.11, but the button should still read as a button.
  pair('the disabled button outline (line-strong)', v(ColourRole.lineStrong), roleWords(ColourRole.surfaceSunken),
      v(ColourRole.surfaceSunken), 3, notice: true);
  if (style.borders.colour == BorderColour.edge) {
    roles(ColourRole.edge, ColourRole.bg, 3);
    roles(ColourRole.edge, ColourRole.surface, 3);
  }
  roles(ColourRole.accent, ColourRole.bg, 3);
  roles(ColourRole.accent, ColourRole.surface, 3);
  for (final g in focusGrounds) {
    roles(ColourRole.focus, g, 3);
  }
  roles(ColourRole.focusOnDanger, ColourRole.dangerSoft, 3);
  roles(ColourRole.focusOnDanger, ColourRole.surface, 3);
  for (final g in const [ColourRole.bg, ColourRole.surface, ColourRole.surfaceRaised]) {
    roles(ColourRole.surfaceHover, g, 1.3);
  }

  // The selection marker, and the focus ring kept apart from it.
  final sel = style.components.values['selection'] ?? 'tint';
  final markerRole = switch (sel) {
    'tint' => ColourRole.accentSoft,
    'inverse' => ColourRole.ink,
    'highlighter' => ColourRole.accent,
    _ => ColourRole.selection,
  };
  final marker = v(markerRole);
  if (sel == 'tint') {
    if (contrast(marker, v(ColourRole.surface)) < 3) {
      out.add(ThemeFinding('$where: the tint selection is under 3:1 on surface, so a 2px selection edge is drawn.',
          notice: true));
      roles(ColourRole.selection, ColourRole.surface, 3);
      roles(ColourRole.selection, ColourRole.accentSoft, 3);
    }
  } else {
    pair('the $sel selection marker (${markerRole.key})', marker, roleWords(ColourRole.surface), v(ColourRole.surface), 3);
  }
  // A double ring always has its `surface` keyline between it and what it surrounds (2.3), so it is checked
  // against the grounds only.
  if ((sel == 'solid' || sel == 'inverse') && style.borders.focus != FocusRingStyle.doubleRing) {
    pair('focus', v(ColourRole.focus), 'the $sel selection fill', marker, 3);
  }
  final other = sel == 'inverse' ? v(ColourRole.ink) : v(ColourRole.selection);
  final f = Oklch.of(v(ColourRole.focus)), s = Oklch.of(other);
  if (!focusKeptApart(v(ColourRole.focus), other)) {
    out.add(ThemeFinding('$where: the focus ring and the selection differ by '
        '${_ratio(contrast(v(ColourRole.focus), other))}:1 and ${hueDistance(f.h, s.h).round()}° of hue; '
        'they need 3:1, a ring much more colourful than a grey selection, or 60° of hue.'));
  }

  // Meanings that stay.
  final danger = Oklch.of(v(ColourRole.danger)), todayDanger = Oklch.of(defaults.of(p.mode)[ColourRole.danger]!);
  // A danger without colour (E-ink's, in ink) cannot be taken for another status: it has no hue to move, and
  // danger always carries its word (2.3). Only a coloured danger keeps to the red.
  if (danger.c < 0.04) {
    out.add(ThemeFinding('$where: danger has no colour; it is told by its word alone.', notice: true));
  } else if (hueDistance(danger.h, todayDanger.h) > 25) {
    out.add(ThemeFinding('$where: danger is ${hueDistance(danger.h, todayDanger.h).round()}° from the red it '
        'has always been; it may move at most 25°.'));
  }
  final accent = Oklch.of(v(ColourRole.accent));
  if (accent.c > 0.04 && danger.c > 0.04 && hueDistance(accent.h, danger.h) < 25) {
    out.add(ThemeFinding('$where: the accent is within 25° of danger, so Approve and filled primary buttons are '
        'drawn in ink.', notice: true));
  }
  if ((style.components.values['data-colours'] ?? 'colour') == 'colour') {
    for (final d in ColourRole.data) {
      final ref = Oklch.of(defaults.of(p.mode)[d]!), got = Oklch.of(v(d));
      if (ref.c > 0.04 && hueDistance(ref.h, got.h) > 30) {
        out.add(ThemeFinding('$where: ${d.key} is ${hueDistance(ref.h, got.h).round()}° from its usual hue; it may '
            'move at most 30°.'));
      }
      if (contrast(v(d), v(ColourRole.surface)) < 3) {
        out.add(ThemeFinding('$where: ${d.key} is under 3:1 on surface, so its dot is drawn with an edge.',
            notice: true));
      }
    }
    for (var i = 0; i < ColourRole.data.length; i++) {
      for (var j = i + 1; j < ColourRole.data.length; j++) {
        final a = ColourRole.data[i], b = ColourRole.data[j];
        if (deltaE(v(a), v(b)) < 0.08) {
          out.add(ThemeFinding('$where: ${a.key} and ${b.key} are too close to tell apart.'));
        }
      }
    }
  }

  // Grounds that are not flat. Increased contrast makes them solid (2.3).
  if (!p.increasedContrast) {
    final m = style.materials;
    if (m.bars != BarMaterial.solid || m.sidebar == SidebarMaterial.translucent) {
      for (final under in const [ColourRole.bg, ColourRole.surface, ColourRole.ink, ColourRole.accent, ColourRole.selection]) {
        final glass = v(ColourRole.glassFill).over(v(under));
        pair(roleWords(ColourRole.ink), v(ColourRole.ink), 'glass over ${under.key}', glass, textNeed);
        pair(roleWords(ColourRole.inkMuted), v(ColourRole.inkMuted), 'glass over ${under.key}', glass, textNeed);
      }
    }
    if (m.window == WindowKind.gradient) {
      for (final stop in p.gradient ?? const <Rgb>[]) {
        for (final fg in const [ColourRole.ink, ColourRole.inkMuted, ColourRole.link]) {
          pair(roleWords(fg), v(fg), 'the gradient stop ${stop.hex}', stop, textNeed);
        }
      }
    }
    if (m.window == WindowKind.pattern && m.pattern != null) {
      final pat = m.pattern!;
      final alpha = (pat.opacity * 255).round();
      for (final g in const [ColourRole.bg, ColourRole.sidebar]) {
        final ground = v(pat.colour).withAlpha(alpha).over(v(g));
        for (final fg in const [ColourRole.ink, ColourRole.inkMuted, ColourRole.link]) {
          pair(roleWords(fg), v(fg), '${g.key} under the ${pat.kind} pattern', ground, textNeed);
        }
        pair('focus', v(ColourRole.focus), '${g.key} under the ${pat.kind} pattern', ground, 3);
      }
    }
  }
  return out;
}

/// The 2.3 rules on type and density, and the catalogue references of 2.1 step 6.
List<ThemeFinding> checkStyle(ThemeFile theme) {
  final out = <ThemeFinding>[];
  final type = theme.style.type;
  for (final s in TypeStack.values) {
    final stack = type.stack(s);
    final unknown = stack.where((id) => !fontCatalogue.containsKey(id) && !genericFonts.contains(id)).toList();
    if (unknown.isNotEmpty) {
      out.add(ThemeFinding('The ${s.key} fonts name ${unknown.join(', ')}, which myData does not have; they are '
          'skipped.', notice: true));
    }
    if (stack.length == unknown.length) {
      out.add(ThemeFinding('The ${s.key} fonts name no font myData has.'));
    }
    final notBundled = stack.where((id) => fontCatalogue[id]?.bundled == false).toList();
    if (notBundled.isNotEmpty) {
      out.add(ThemeFinding('${notBundled.map((id) => fontCatalogue[id]!.name).join(', ')} comes with a later '
          'version of myData; until then the next font in the ${s.key} list is used.', notice: true));
    }
    if (s != TypeStack.display && stack.any((id) => fontCatalogue[id]?.displayOnly ?? false)) {
      out.add(ThemeFinding('A display-only font cannot be in the ${s.key} fonts.'));
    }
  }
  for (final e in type.roles.entries) {
    final role = e.key, r = e.value;
    final first = type.stack(r.stack).firstWhere(
        (id) => fontCatalogue.containsKey(id) || genericFonts.contains(id),
        orElse: () => '');
    if ((fontCatalogue[first]?.displayOnly ?? false) && r.size < 16) {
      out.add(ThemeFinding('${role.key} is set in ${fontCatalogue[first]!.name}, a display font, at '
          '${_need(r.size)} px; it needs 16 px or more.'));
    }
    if ((role == TypeRole.body || role == TypeRole.bodyStrong) && r.lineHeight < 1.25) {
      out.add(ThemeFinding('${role.key} has a line height of ${r.lineHeight}; it needs at least 1.25.'));
    }
    if ((role == TypeRole.displayXl || role == TypeRole.displayLg) && r.lineHeight < 1.1) {
      out.add(ThemeFinding('${role.key} has a line height of ${r.lineHeight}; it needs at least 1.1.'));
    }
    if (r.upper) {
      if (role != TypeRole.label && role != TypeRole.caption) {
        out.add(ThemeFinding('Only label and caption may be in upper case, not ${role.key}.'));
      }
      if ((r.tracking ?? 0) < 0.04) {
        out.add(ThemeFinding('${role.key} is in upper case, which needs letter spacing of at least 0.04 em.'));
      }
    }
    if (role == TypeRole.caption && r.size < 11) out.add(const ThemeFinding('caption is under 11 px.'));
    if (role == TypeRole.body && r.size < 12) out.add(const ThemeFinding('body is under 12 px.'));
  }
  final icons = theme.style.icons;
  if (!bundledIconSets.contains(icons.set)) {
    out.add(ThemeFinding('The ${icons.set} icons come with a later version of myData; until then Lucide is used.',
        notice: true));
  } else if (!bundledIconWeights[icons.set]!.contains(icons.weight)) {
    out.add(ThemeFinding('The ${icons.set} icons have no ${icons.weight} weight; the nearest one is used.',
        notice: true));
  }
  if (icons.fillSelected && !(bundledIconWeights[icons.set]?.contains('fill') ?? false)) {
    out.add(ThemeFinding('The ${bundledIconSets.contains(icons.set) ? icons.set : 'lucide'} icons have no '
        'filled glyphs; a selected icon is drawn as the others.', notice: true));
  }
  if (theme.style.materials.window == WindowKind.image) {
    out.add(const ThemeFinding('Background images come with a later version of myData.'));
  }
  return out;
}
