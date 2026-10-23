/// A theme file in memory (design/themes/theme.schema.json, format 1): the envelope, the style and the
/// palettes. Built only from JSON that passed the schema ([validateThemeText] in `validate.dart` does both);
/// pure Dart, so the generator can use it.
library;

import 'colour.dart';
import 'roles.dart';

/// A value of one of the format's enumerations, by its key in the file.
mixin KeyedEnum on Enum {
  String get key;
}

T _byKey<T extends KeyedEnum>(List<T> values, Object? key) =>
    values.firstWhere((v) => v.key == key, orElse: () => throw FormatException('unknown value $key'));

enum ThemeFrame with KeyedEnum {
  system('system'),
  drawn('drawn');

  const ThemeFrame(this.key);
  @override
  final String key;
}

/// A text role (theme.schema.json `type.roles`; design/tokens.json `type.groups`).
enum TypeRole with KeyedEnum {
  displayXl('display-xl'),
  displayLg('display-lg'),
  title('title'),
  heading('heading'),
  body('body'),
  bodyStrong('body-strong'),
  label('label'),
  caption('caption'),
  mono('mono');

  const TypeRole(this.key);
  @override
  final String key;

  /// The stack a role is set in when the file does not say (as design/tokens.json today).
  TypeStack get defaultStack => switch (this) {
        displayXl || displayLg || title => TypeStack.display,
        mono => TypeStack.mono,
        _ => TypeStack.body,
      };
}

enum TypeStack with KeyedEnum {
  display('display'),
  body('body'),
  mono('mono');

  const TypeStack(this.key);
  @override
  final String key;
}

/// One text role's numbers. [tracking] is in em; null when the file leaves it out (no letter spacing).
class TypeRoleSpec {
  const TypeRoleSpec({
    required this.size,
    required this.lineHeight,
    required this.weight,
    this.tracking,
    this.upper = false,
    required this.stack,
  });

  final double size;
  final double lineHeight;
  final int weight;
  final double? tracking;
  final bool upper;
  final TypeStack stack;
}

class TypeSpec {
  const TypeSpec({
    required this.display,
    required this.body,
    required this.mono,
    required this.base,
    required this.ratio,
    required this.tabular,
    required this.secondaryItalic,
    required this.roles,
  });

  /// Font stacks: catalogue ids and generics, in order of preference.
  final List<String> display, body, mono;
  final double base, ratio;
  final bool tabular;
  final bool secondaryItalic;
  final Map<TypeRole, TypeRoleSpec> roles;

  List<String> stack(TypeStack s) => switch (s) {
        TypeStack.display => display,
        TypeStack.body => body,
        TypeStack.mono => mono,
      };
}

enum CornerStyle with KeyedEnum {
  round('round'),
  continuous('continuous'),
  cut('cut'),
  square('square');

  const CornerStyle(this.key);
  @override
  final String key;
}

class ShapeSpec {
  const ShapeSpec({
    required this.corners,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.pillControls,
    required this.cutSize,
  });

  final CornerStyle corners;
  final double xs, sm, md, lg, xl;

  /// Buttons, chips, switches and search fields are capsules (`controls: pill`), else they take [sm].
  final bool pillControls;
  final double cutSize;
}

/// One class's density (theme.schema.json `densitySet`).
class DensitySet {
  const DensitySet({required this.control, required this.row, required this.icon, required this.space});
  final double control, row, icon, space;
}

class DensitySpec {
  const DensitySpec({required this.desktop, required this.phone});
  final DensitySet desktop, phone;
}

enum BorderWidth with KeyedEnum {
  hairline('hairline'),
  one('1'),
  two('2'),
  three('3');

  const BorderWidth(this.key);
  @override
  final String key;
}

enum BorderStyleKind with KeyedEnum {
  solid('solid'),
  dashed('dashed'),
  doubleLine('double');

  const BorderStyleKind(this.key);
  @override
  final String key;
}

enum BorderColour with KeyedEnum {
  line('line'),
  lineStrong('line-strong'),
  edge('edge'),
  accent('accent');

  const BorderColour(this.key);
  @override
  final String key;
}

enum Separators with KeyedEnum {
  none('none'),
  inset('inset'),
  full('full');

  const Separators(this.key);
  @override
  final String key;
}

enum TitleRule with KeyedEnum {
  none('none'),
  single('single'),
  doubleLine('double');

  const TitleRule(this.key);
  @override
  final String key;
}

class BordersSpec {
  const BordersSpec({
    required this.width,
    required this.style,
    required this.colour,
    required this.cards,
    required this.controls,
    required this.separators,
    required this.titleRule,
  });

  final BorderWidth width;
  final BorderStyleKind style;
  final BorderColour colour;
  final bool cards, controls;
  final Separators separators;
  final TitleRule titleRule;
}

enum ElevationStyle with KeyedEnum {
  none('none'),
  soft('soft'),
  hard('hard'),
  offset('offset'),
  bevel('bevel'),
  glow('glow');

  const ElevationStyle(this.key);
  @override
  final String key;
}

class ElevationSpec {
  const ElevationSpec({required this.style, required this.strength, required this.offset, required this.collapse});
  final ElevationStyle style;
  final double strength, offset;

  /// A pressed hard or offset shadow drops to 0 (`press: collapse`).
  final bool collapse;
}

enum WindowKind with KeyedEnum {
  solid('solid'),
  gradient('gradient'),
  pattern('pattern'),
  image('image');

  const WindowKind(this.key);
  @override
  final String key;
}

enum SidebarMaterial with KeyedEnum {
  solid('solid'),
  translucent('translucent'),
  native('native');

  const SidebarMaterial(this.key);
  @override
  final String key;
}

enum BarMaterial with KeyedEnum {
  solid('solid'),
  translucent('translucent'),
  blur('blur');

  const BarMaterial(this.key);
  @override
  final String key;
}

class PatternSpec {
  const PatternSpec({required this.kind, required this.spacing, required this.opacity, required this.colour});
  final String kind;
  final double spacing, opacity;

  /// `line`, `ink` or `accent`.
  final ColourRole colour;
}

class MaterialsSpec {
  const MaterialsSpec({
    required this.window,
    this.gradientAngle,
    this.pattern,
    required this.sidebar,
    required this.bars,
    required this.blur,
  });

  final WindowKind window;
  final double? gradientAngle;
  final PatternSpec? pattern;
  final SidebarMaterial sidebar;
  final BarMaterial bars;
  final double blur;
}

class IconsSpec {
  const IconsSpec({required this.set, required this.weight, required this.fillSelected, required this.tiles});
  final String set, weight;
  final bool fillSelected;

  /// `tinted`, `outlined` or `none`.
  final String tiles;
}

enum MotionPersonality with KeyedEnum {
  none('none'),
  calm('calm'),
  standard('standard'),
  crisp('crisp'),
  lively('lively');

  const MotionPersonality(this.key);
  @override
  final String key;
}

enum PressStyle with KeyedEnum {
  none('none'),
  dim('dim'),
  dimScale('dim-scale'),
  sink('sink'),
  invert('invert');

  const PressStyle(this.key);
  @override
  final String key;
}

enum EnterStyle with KeyedEnum {
  none('none'),
  fade('fade'),
  fadeRise('fade-rise');

  const EnterStyle(this.key);
  @override
  final String key;
}

class MotionSpec {
  const MotionSpec({required this.personality, required this.scale, required this.press, required this.enter});
  final MotionPersonality personality;
  final double scale;
  final PressStyle press;
  final EnterStyle enter;
}

/// How each component is drawn (theme.schema.json `components`): the enumerations' keys, read by the
/// widgets' variant switches from phase 3.
class ComponentsSpec {
  const ComponentsSpec(this.values);

  /// `button.primary` → `filled`, `list` → `inset`, ...
  final Map<String, String> values;

  String operator [](String key) => values[key]!;
}

/// Everything in a theme but colour (ARCHITECTURE.md 1.6).
class ThemeStyle {
  const ThemeStyle({
    required this.type,
    required this.shape,
    required this.density,
    required this.borders,
    required this.elevation,
    required this.materials,
    required this.icons,
    required this.motion,
    required this.components,
    required this.illustration,
  });

  final TypeSpec type;
  final ShapeSpec shape;
  final DensitySpec density;
  final BordersSpec borders;
  final ElevationSpec elevation;
  final MaterialsSpec materials;
  final IconsSpec icons;
  final MotionSpec motion;
  final ComponentsSpec components;
  final String illustration;
}

/// One palette: the colours a palette gives in each mode (its seeds and overrides together), its own
/// increased-contrast set, and its gradient stops.
class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
    this.contrastLight = const {},
    this.contrastDark = const {},
    this.gradientLight,
    this.gradientDark,
  });

  final String id;
  final String name;
  final Map<ColourRole, Rgb> light, dark;
  final Map<ColourRole, Rgb> contrastLight, contrastDark;
  final List<Rgb>? gradientLight, gradientDark;

  Map<ColourRole, Rgb> given(LookMode mode) => mode == LookMode.dark ? dark : light;
  Map<ColourRole, Rgb> contrastSet(LookMode mode) => mode == LookMode.dark ? contrastDark : contrastLight;
  List<Rgb>? gradient(LookMode mode) => mode == LookMode.dark ? gradientDark : gradientLight;
  bool get hasContrastSet => contrastLight.isNotEmpty || contrastDark.isNotEmpty;
}

/// A whole theme file.
class ThemeFile {
  const ThemeFile({
    required this.id,
    required this.name,
    required this.version,
    required this.licence,
    required this.frame,
    this.author,
    this.description,
    this.basedOn,
    this.blurb,
    this.scene,
    required this.palettes,
    this.defaultPaletteId,
    required this.sameAs,
    required this.style,
    required this.json,
  });

  final String id, name, version, licence;
  final ThemeFrame frame;
  final String? author, description, basedOn, blurb, scene;
  final List<ThemePalette> palettes;
  final String? defaultPaletteId;

  /// `colour-use.same-as`: roles this style always draws in another role's colour.
  final Map<ColourRole, ColourRole> sameAs;

  /// The style, with every group the file leaves out filled from the theme it is based on.
  final ThemeStyle style;

  /// The file as read (after unknown keys were dropped).
  final Map<String, Object?> json;

  bool get builtIn => id.startsWith('mydata.');

  ThemePalette? get defaultPalette =>
      palettes.isEmpty ? null : palettes.firstWhere((p) => p.id == defaultPaletteId, orElse: () => palettes.first);

  /// The palette [id], else the default one (null for a theme without palettes, as System).
  ThemePalette? palette(String? id) {
    for (final p in palettes) {
      if (p.id == id) return p;
    }
    return defaultPalette;
  }

  /// Builds a theme from [json] that passed the schema. Style groups the file leaves out, and fields a group
  /// leaves out, come from [base] (the built-in it is `based-on`, else Kiwi).
  factory ThemeFile.fromJson(Map<String, Object?> json, {required Map<String, Object?> base}) {
    final preview = json['preview'] as Map<String, Object?>?;
    final colourUse = json['colour-use'] as Map<String, Object?>?;
    final same = (colourUse?['same-as'] as Map<String, Object?>?) ?? const {};
    return ThemeFile(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      licence: json['licence'] as String,
      frame: _byKey(ThemeFrame.values, json['frame']),
      author: json['author'] as String?,
      description: json['description'] as String?,
      basedOn: json['based-on'] as String?,
      blurb: preview?['blurb'] as String?,
      scene: preview?['scene'] as String?,
      palettes: [
        for (final p in (json['palettes'] as List? ?? const []).cast<Map<String, Object?>>()) _palette(p),
      ],
      defaultPaletteId: json['default-palette'] as String?,
      sameAs: {for (final e in same.entries) ColourRole.byKey(e.key)!: ColourRole.byKey(e.value as String)!},
      style: styleFromJson(mergeStyle(base, json)),
      json: json,
    );
  }
}

/// The style groups of a theme file.
const styleGroups = [
  'type', 'shape', 'density', 'borders', 'elevation', 'materials', 'icons', 'motion', 'components', 'illustration',
];

/// [file]'s style over [base]'s: a group the file leaves out is [base]'s; a field a group leaves out is
/// [base]'s field (one level down, and per role in `type.roles`). A density `preset` replaces the base's
/// numbers for the classes the file does not spell out. A `type` that gives `base` or `ratio` and no roles is
/// sized from them alone: the base's role sizes are dropped (its weights, line heights and stacks kept).
Map<String, Object?> mergeStyle(Map<String, Object?> base, Map<String, Object?> file) {
  final out = <String, Object?>{};
  for (final g in styleGroups) {
    final b = base[g], f = file[g];
    if (f is Map<String, Object?> && b is Map<String, Object?>) {
      final m = <String, Object?>{...b};
      if (g == 'density' && f['preset'] is String) {
        m
          ..remove('desktop')
          ..remove('phone');
      }
      if (g == 'type' &&
          (f.containsKey('base') || f.containsKey('ratio')) &&
          (f['roles'] is! Map || (f['roles'] as Map).isEmpty) &&
          m['roles'] is Map<String, Object?>) {
        m['roles'] = {
          for (final r in (m['roles'] as Map<String, Object?>).entries)
            r.key: r.value is Map<String, Object?> ? ({...r.value as Map<String, Object?>}..remove('size')) : r.value,
        };
      }
      for (final e in f.entries) {
        final bv = m[e.key];
        if (e.value is Map<String, Object?> && bv is Map<String, Object?>) {
          if (g == 'type' && e.key == 'roles') {
            m[e.key] = {
              ...bv,
              for (final r in (e.value as Map<String, Object?>).entries)
                r.key: {...?(bv[r.key] as Map<String, Object?>?), ...(r.value as Map<String, Object?>)},
            };
          } else {
            m[e.key] = {...bv, ...(e.value as Map<String, Object?>)};
          }
        } else {
          m[e.key] = e.value;
        }
      }
      out[g] = m;
    } else {
      out[g] = f ?? b;
    }
  }
  return out;
}

ThemePalette _palette(Map<String, Object?> p) {
  Map<ColourRole, Rgb> roles(Object? m) => {
        for (final e in ((m as Map<String, Object?>?) ?? const {}).entries)
          ColourRole.byKey(e.key)!: Rgb.parse(e.value as String),
      };
  final overrides = p['overrides'] as Map<String, Object?>?;
  final contrast = p['contrast'] as Map<String, Object?>?;
  final gradient = p['gradient'] as Map<String, Object?>?;
  List<Rgb>? stops(String mode) => (gradient?[mode] as List?)?.map((s) => Rgb.parse(s as String)).toList();
  return ThemePalette(
    id: p['id'] as String,
    name: p['name'] as String,
    light: {...roles(p['light']), ...roles(overrides?['light'])},
    dark: {...roles(p['dark']), ...roles(overrides?['dark'])},
    contrastLight: roles(contrast?['light']),
    contrastDark: roles(contrast?['dark']),
    gradientLight: stops('light'),
    gradientDark: stops('dark'),
  );
}

/// Density presets (ARCHITECTURE.md 1.4).
const densityPresets = <String, DensitySpec>{
  'compact': DensitySpec(
      desktop: DensitySet(control: 28, row: 28, icon: 16, space: 0.75),
      phone: DensitySet(control: 44, row: 48, icon: 20, space: 1)),
  'regular': DensitySpec(
      desktop: DensitySet(control: 36, row: 44, icon: 18, space: 1),
      phone: DensitySet(control: 48, row: 56, icon: 22, space: 1)),
  'roomy': DensitySpec(
      desktop: DensitySet(control: 48, row: 56, icon: 22, space: 1.25),
      phone: DensitySet(control: 56, row: 64, icon: 24, space: 1.25)),
};

double _d(Object? v) => (v as num).toDouble();

/// The typed style of a merged style map (every group present).
ThemeStyle styleFromJson(Map<String, Object?> s) {
  final type = s['type'] as Map<String, Object?>;
  final base = _d(type['base']), ratio = _d(type['ratio']);
  final rolesJson = (type['roles'] as Map<String, Object?>?) ?? const {};
  final roles = <TypeRole, TypeRoleSpec>{};
  for (final role in TypeRole.values) {
    final r = rolesJson[role.key] as Map<String, Object?>? ?? const {};
    final fallback = _derivedRole(role, base, ratio);
    roles[role] = TypeRoleSpec(
      size: r['size'] == null ? fallback.size : _d(r['size']),
      lineHeight: r['line-height'] == null ? fallback.lineHeight : _d(r['line-height']),
      weight: r['weight'] == null ? fallback.weight : (r['weight'] as num).toInt(),
      tracking: r['tracking'] == null ? null : _d(r['tracking']),
      upper: r['case'] == 'upper',
      stack: r['stack'] == null ? role.defaultStack : _byKey(TypeStack.values, r['stack']),
    );
  }
  List<String> stack(String k) => (type[k] as List).cast<String>();

  final shape = s['shape'] as Map<String, Object?>;
  final radius = shape['radius'] as Map<String, Object?>;

  final density = s['density'] as Map<String, Object?>;
  final preset = densityPresets[density['preset'] ?? 'regular']!;
  DensitySet set(String cls, DensitySet fallback) {
    final d = density[cls] as Map<String, Object?>?;
    if (d == null) return fallback;
    return DensitySet(
      control: d['control'] == null ? fallback.control : _d(d['control']),
      row: d['row'] == null ? fallback.row : _d(d['row']),
      icon: d['icon'] == null ? fallback.icon : _d(d['icon']),
      space: d['space'] == null ? fallback.space : _d(d['space']),
    );
  }

  final borders = s['borders'] as Map<String, Object?>;
  final elevation = s['elevation'] as Map<String, Object?>;
  final materials = s['materials'] as Map<String, Object?>;
  final window = materials['window'] as Map<String, Object?>;
  final pattern = window['pattern'] as Map<String, Object?>?;
  final icons = s['icons'] as Map<String, Object?>;
  final motion = s['motion'] as Map<String, Object?>;
  final components = s['components'] as Map<String, Object?>;
  final button = (components['button'] as Map<String, Object?>?) ?? const {};

  return ThemeStyle(
    type: TypeSpec(
      display: stack('display'),
      body: stack('body'),
      mono: stack('mono'),
      base: base,
      ratio: ratio,
      tabular: type['numerals'] == 'tabular',
      secondaryItalic: type['secondary-italic'] == true,
      roles: roles,
    ),
    shape: ShapeSpec(
      corners: _byKey(CornerStyle.values, shape['corners']),
      xs: _d(radius['xs']),
      sm: _d(radius['sm']),
      md: _d(radius['md']),
      lg: _d(radius['lg']),
      xl: _d(radius['xl']),
      pillControls: shape['controls'] != 'match',
      cutSize: shape['cut-size'] == null ? 6 : _d(shape['cut-size']),
    ),
    density: DensitySpec(desktop: set('desktop', preset.desktop), phone: set('phone', preset.phone)),
    borders: BordersSpec(
      width: _byKey(BorderWidth.values, '${borders['width']}'),
      style: _byKey(BorderStyleKind.values, borders['style'] ?? 'solid'),
      colour: _byKey(BorderColour.values, borders['colour'] ?? 'line'),
      cards: borders['cards'] == true,
      controls: borders['controls'] == true,
      separators: _byKey(Separators.values, borders['separators'] ?? 'inset'),
      titleRule: _byKey(TitleRule.values, borders['title-rule'] ?? 'none'),
    ),
    elevation: ElevationSpec(
      style: _byKey(ElevationStyle.values, elevation['style']),
      strength: elevation['strength'] == null ? 0.5 : _d(elevation['strength']),
      offset: elevation['offset'] == null ? 0 : _d(elevation['offset']),
      collapse: elevation['press'] == 'collapse',
    ),
    materials: MaterialsSpec(
      window: _byKey(WindowKind.values, window['kind']),
      gradientAngle: (window['gradient'] as Map<String, Object?>?)?['angle'] == null
          ? null
          : _d((window['gradient'] as Map<String, Object?>)['angle']),
      pattern: pattern == null
          ? null
          : PatternSpec(
              kind: pattern['kind'] as String,
              spacing: pattern['spacing'] == null ? 24 : _d(pattern['spacing']),
              opacity: pattern['opacity'] == null ? 0.06 : _d(pattern['opacity']),
              colour: ColourRole.byKey((pattern['colour'] as String?) ?? 'line')!,
            ),
      sidebar: _byKey(SidebarMaterial.values, materials['sidebar'] ?? 'solid'),
      bars: _byKey(BarMaterial.values, materials['bars'] ?? 'solid'),
      blur: materials['blur'] == null ? 24 : _d(materials['blur']),
    ),
    icons: IconsSpec(
      set: icons['set'] as String? ?? 'lucide',
      weight: icons['weight'] as String? ?? 'regular',
      fillSelected: icons['selected'] == 'fill',
      tiles: icons['tiles'] as String? ?? 'tinted',
    ),
    motion: MotionSpec(
      personality: _byKey(MotionPersonality.values, motion['personality'] ?? 'standard'),
      scale: motion['scale'] == null ? 1 : _d(motion['scale']),
      press: _byKey(PressStyle.values, motion['press'] ?? 'dim-scale'),
      enter: _byKey(EnterStyle.values, motion['enter'] ?? 'fade-rise'),
    ),
    components: ComponentsSpec({
      for (final e in components.entries)
        if (e.value is String) e.key: e.value as String,
      for (final e in button.entries) 'button.${e.key}': e.value as String,
    }),
    illustration: s['illustration'] as String? ?? 'flat',
  );
}

/// A role's numbers when the file gives none: a modular scale from `base` and `ratio`.
TypeRoleSpec _derivedRole(TypeRole role, double base, double ratio) {
  double step(int n) {
    var v = base;
    for (var i = 0; i < n.abs(); i++) {
      v = n > 0 ? v * ratio : v / ratio;
    }
    return v.roundToDouble();
  }

  return switch (role) {
    TypeRole.displayXl => TypeRoleSpec(size: step(4), lineHeight: 1.15, weight: 700, stack: role.defaultStack),
    TypeRole.displayLg => TypeRoleSpec(size: step(3), lineHeight: 1.2, weight: 700, stack: role.defaultStack),
    TypeRole.title => TypeRoleSpec(size: step(2), lineHeight: 1.27, weight: 700, stack: role.defaultStack),
    TypeRole.heading => TypeRoleSpec(size: step(1), lineHeight: 1.41, weight: 600, stack: role.defaultStack),
    TypeRole.body => TypeRoleSpec(size: step(0), lineHeight: 1.47, weight: 400, stack: role.defaultStack),
    TypeRole.bodyStrong => TypeRoleSpec(size: step(0), lineHeight: 1.47, weight: 600, stack: role.defaultStack),
    TypeRole.label => TypeRoleSpec(size: step(-1), lineHeight: 1.38, weight: 600, stack: role.defaultStack),
    TypeRole.caption => TypeRoleSpec(size: step(-1), lineHeight: 1.38, weight: 400, stack: role.defaultStack),
    TypeRole.mono => TypeRoleSpec(size: step(-1), lineHeight: 1.54, weight: 400, stack: role.defaultStack),
  };
}
