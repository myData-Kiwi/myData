/// What a theme file may name: fonts, generic families, icon sets and licences (design/themes/ARCHITECTURE.md
/// 1.5 and 2.1, step 6). A name outside these is skipped or refused by the validator; nothing is ever fetched.
library;

/// A font a theme may name, by its catalogue id.
class CatalogueFont {
  const CatalogueFont(
    this.id,
    this.name, {
    this.family,
    this.core = false,
    this.italic = false,
    this.displayOnly = false,
    this.opticalSizes,
    this.staticWeight,
  });

  /// The id a theme file uses (`plus-jakarta-sans`).
  final String id;

  /// The font's name as people write it.
  final String name;

  /// The family it is drawn under, in this package (`packages/mydata_ui/<family>`), when this build bundles
  /// it; null for a font a later phase bundles (a stack then falls through to its next entry).
  final String? family;

  /// One of the three core fonts, declared in the pubspec as static weights: registered when the app starts.
  /// Every other bundled font is a Latin subset in assets/fonts/catalogue/ (`<id>.ttf`, and
  /// `<id>-italic.ttf` when [italic]), loaded when a theme that needs it is chosen or previewed
  /// (`ThemeFonts.ensure` in fonts.dart) and drawn at any weight through its `wght` axis, or at its
  /// [staticWeight] alone.
  final bool core;

  /// It has an italic of its own; otherwise an italic is slanted by the text engine.
  final bool italic;

  /// Display-only fonts are allowed only in `display` and in roles of 16 px or more (Research B).
  final bool displayOnly;

  /// The optical sizes its `opsz` axis covers (min, max), when it keeps that axis: a role is drawn at the
  /// optical size of its own size, so display sizes get display optics. Null for a font cut at one size.
  final (double, double)? opticalSizes;

  /// The one weight of a font loaded on demand that has no weight axis (Kalam's bold, Archivo Black's
  /// regular, which is black); null for a variable font.
  final int? staticWeight;

  bool get bundled => family != null;

  /// Loaded from assets/fonts/catalogue when a theme needs it (every bundled font but the core three).
  bool get onDemand => bundled && !core;

  /// A variable font: weights are drawn through its `wght` axis.
  bool get variable => onDemand && staticWeight == null;

  /// Its files in this package's assets, for a font loaded on demand.
  List<String> get assets => onDemand
      ? ['assets/fonts/catalogue/$id.ttf', if (italic) 'assets/fonts/catalogue/$id-italic.ttf']
      : const [];

  /// Its licence text in assets/fonts (every catalogue font is SIL OFL 1.1, with no Reserved Font Name).
  String get licence => switch (id) {
        'plus-jakarta-sans' => 'OFL-plusjakartasans.txt',
        'jetbrains-mono' => 'OFL-jetbrainsmono.txt',
        _ => 'OFL-$id.txt',
      };
}

/// The package that holds the bundled fonts.
const fontPackage = 'mydata_ui';

/// ARCHITECTURE.md 1.5. All are OFL fonts with no Reserved Font Name. Three are core fonts, as before phase 3;
/// phase 3 bundles the fonts the six built-ins name, as Latin subsets cut by tool/subset_fonts.sh; the fonts
/// of the thirteen new themes come with them in phase 4 (Atkinson Hyperlegible Next and Mono with High
/// Contrast and Large, Kalam and Newsreader with Notebook).
const fontCatalogue = <String, CatalogueFont>{
  'figtree': CatalogueFont('figtree', 'Figtree', family: 'Figtree', core: true),
  'plus-jakarta-sans': CatalogueFont('plus-jakarta-sans', 'Plus Jakarta Sans', family: 'PlusJakartaSans', core: true),
  'jetbrains-mono': CatalogueFont('jetbrains-mono', 'JetBrains Mono', family: 'JetBrainsMono', core: true),
  'inter': CatalogueFont('inter', 'Inter', family: 'Inter', opticalSizes: (14, 32)),
  'inter-tight': CatalogueFont('inter-tight', 'Inter Tight'),
  'sora': CatalogueFont('sora', 'Sora', family: 'Sora'),
  'manrope': CatalogueFont('manrope', 'Manrope', family: 'Manrope'),
  'fraunces': CatalogueFont('fraunces', 'Fraunces', family: 'Fraunces'),
  'instrument-sans': CatalogueFont('instrument-sans', 'Instrument Sans', family: 'InstrumentSans', italic: true),
  'instrument-serif': CatalogueFont('instrument-serif', 'Instrument Serif'),
  'fredoka': CatalogueFont('fredoka', 'Fredoka', family: 'Fredoka', displayOnly: true),
  'nunito': CatalogueFont('nunito', 'Nunito', family: 'Nunito'),
  'literata': CatalogueFont('literata', 'Literata', family: 'Literata', italic: true, opticalSizes: (7, 72)),
  'hanken-grotesk': CatalogueFont('hanken-grotesk', 'Hanken Grotesk'),
  'newsreader': CatalogueFont('newsreader', 'Newsreader', family: 'Newsreader', italic: true),
  'kalam': CatalogueFont('kalam', 'Kalam', family: 'Kalam', displayOnly: true, staticWeight: 700),
  'archivo-black': CatalogueFont('archivo-black', 'Archivo Black', displayOnly: true),
  'space-grotesk': CatalogueFont('space-grotesk', 'Space Grotesk'),
  'space-mono': CatalogueFont('space-mono', 'Space Mono'),
  'pixelify-sans': CatalogueFont('pixelify-sans', 'Pixelify Sans', displayOnly: true),
  'atkinson-hyperlegible-next': CatalogueFont('atkinson-hyperlegible-next', 'Atkinson Hyperlegible Next',
      family: 'AtkinsonHyperlegibleNext', italic: true),
  'atkinson-hyperlegible-mono': CatalogueFont('atkinson-hyperlegible-mono', 'Atkinson Hyperlegible Mono',
      family: 'AtkinsonHyperlegibleMono'),
  'azeret-mono': CatalogueFont('azeret-mono', 'Azeret Mono'),
  'chakra-petch': CatalogueFont('chakra-petch', 'Chakra Petch'),
  'outfit': CatalogueFont('outfit', 'Outfit'),
  'jost': CatalogueFont('jost', 'Jost'),
  'shippori-mincho': CatalogueFont('shippori-mincho', 'Shippori Mincho'),
  'zen-kaku-gothic-new': CatalogueFont('zen-kaku-gothic-new', 'Zen Kaku Gothic New'),
};

/// The most the fonts and icon fonts bundled in one app may weigh (decided 2026-10-23: Latin subsets, a cap
/// of 6 MB per app; test/theme/fonts_test.dart).
const fontBudgetBytes = 6 * 1024 * 1024;

/// Generic families: the platform's own fonts, reached through the OS, never bundled (SF Pro, New York and
/// Segoe never are).
const genericFonts = {'system', 'system-mono', 'sans', 'serif', 'mono'};

/// The family a generic monospace (`mono`, `system-mono`) is drawn in, by platform (`TargetPlatform.name`);
/// the other generics are the platform's default font. Only macOS's is verified (2026-10-23).
const genericMonoFamilies = {
  'macOS': 'Menlo',
  'iOS': 'Menlo',
  'windows': 'Consolas',
  'linux': 'monospace',
  'android': 'monospace',
  'fuchsia': 'monospace',
};

/// The icon sets a theme may name (theme.schema.json). Lucide, Tabler and Phosphor are bundled (phase 3,
/// tool/subset_icons.sh), Material Symbols Outlined and Rounded since High Contrast and Large (phase 4); the
/// others come with the first theme that draws them, and until then a theme naming one is drawn in Lucide,
/// with a notice.
const iconSets = {
  'lucide', 'phosphor', 'tabler', 'material-outlined', 'material-rounded', 'material-sharp', 'pixelarticons',
  'iconoir',
};

/// The weights each bundled set has (the icon fonts of icon_sets.g.dart; test/theme/icons_test.dart checks
/// the two agree). A weight a set lacks is drawn in the nearest it has.
const bundledIconWeights = {
  'lucide': {'regular'},
  'tabler': {'thin', 'light', 'regular'},
  'phosphor': {'light', 'regular', 'bold', 'fill'},
  'material-outlined': {'light', 'regular', 'bold', 'fill'},
  'material-rounded': {'light', 'regular', 'bold', 'fill'},
};
final bundledIconSets = bundledIconWeights.keys.toSet();

/// Licences a theme may carry: SPDX identifiers (https://spdx.org/licenses/) for the licences people share
/// designs and fonts under, plus NOASSERTION for a theme that is not shared. Not the whole SPDX list: an id
/// missing here is refused with a sentence naming it, and is added when someone needs it.
const spdxLicences = {
  'NOASSERTION', '0BSD', 'AGPL-3.0-only', 'AGPL-3.0-or-later', 'Apache-2.0', 'Artistic-2.0', 'BSD-2-Clause',
  'BSD-3-Clause', 'BSL-1.0', 'CC-BY-3.0', 'CC-BY-4.0', 'CC-BY-NC-4.0', 'CC-BY-NC-SA-4.0', 'CC-BY-ND-4.0',
  'CC-BY-SA-3.0', 'CC-BY-SA-4.0', 'CC0-1.0', 'EPL-2.0', 'EUPL-1.2', 'GPL-2.0-only', 'GPL-2.0-or-later',
  'GPL-3.0-only', 'GPL-3.0-or-later', 'ISC', 'LGPL-2.1-only', 'LGPL-2.1-or-later', 'LGPL-3.0-only',
  'LGPL-3.0-or-later', 'MIT', 'MIT-0', 'MPL-2.0', 'OFL-1.1', 'Unlicense', 'WTFPL', 'Zlib',
};
