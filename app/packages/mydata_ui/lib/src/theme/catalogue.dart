/// What a theme file may name: fonts, generic families, icon sets and licences (design/themes/ARCHITECTURE.md
/// 1.5 and 2.1, step 6). A name outside these is skipped or refused by the validator; nothing is ever fetched.
library;

/// A font a theme may name, by its catalogue id.
class CatalogueFont {
  const CatalogueFont(this.id, this.name, {this.family, this.displayOnly = false});

  /// The id a theme file uses (`plus-jakarta-sans`).
  final String id;

  /// The font's name as people write it.
  final String name;

  /// The family registered in this package's pubspec, when the font is bundled today; null until phase 3
  /// bundles it (a stack then falls through to its next entry).
  final String? family;

  /// Display-only fonts are allowed only in `display` and in roles of 16 px or more (Research B).
  final bool displayOnly;

  bool get bundled => family != null;
}

/// The package that holds the bundled fonts.
const fontPackage = 'mydata_ui';

/// ARCHITECTURE.md 1.5. All are OFL fonts with no Reserved Font Name. Phase 1 bundles the three the apps
/// draw today; the rest are bundled as Latin subsets with the themes that use them (phase 3).
const fontCatalogue = <String, CatalogueFont>{
  'figtree': CatalogueFont('figtree', 'Figtree', family: 'Figtree'),
  'plus-jakarta-sans': CatalogueFont('plus-jakarta-sans', 'Plus Jakarta Sans', family: 'PlusJakartaSans'),
  'jetbrains-mono': CatalogueFont('jetbrains-mono', 'JetBrains Mono', family: 'JetBrainsMono'),
  'inter': CatalogueFont('inter', 'Inter'),
  'inter-tight': CatalogueFont('inter-tight', 'Inter Tight'),
  'sora': CatalogueFont('sora', 'Sora'),
  'manrope': CatalogueFont('manrope', 'Manrope'),
  'fraunces': CatalogueFont('fraunces', 'Fraunces'),
  'instrument-sans': CatalogueFont('instrument-sans', 'Instrument Sans'),
  'instrument-serif': CatalogueFont('instrument-serif', 'Instrument Serif'),
  'fredoka': CatalogueFont('fredoka', 'Fredoka', displayOnly: true),
  'nunito': CatalogueFont('nunito', 'Nunito'),
  'literata': CatalogueFont('literata', 'Literata'),
  'hanken-grotesk': CatalogueFont('hanken-grotesk', 'Hanken Grotesk'),
  'newsreader': CatalogueFont('newsreader', 'Newsreader'),
  'kalam': CatalogueFont('kalam', 'Kalam', displayOnly: true),
  'archivo-black': CatalogueFont('archivo-black', 'Archivo Black', displayOnly: true),
  'space-grotesk': CatalogueFont('space-grotesk', 'Space Grotesk'),
  'space-mono': CatalogueFont('space-mono', 'Space Mono'),
  'pixelify-sans': CatalogueFont('pixelify-sans', 'Pixelify Sans', displayOnly: true),
  'atkinson-hyperlegible-next': CatalogueFont('atkinson-hyperlegible-next', 'Atkinson Hyperlegible Next'),
  'atkinson-hyperlegible-mono': CatalogueFont('atkinson-hyperlegible-mono', 'Atkinson Hyperlegible Mono'),
  'azeret-mono': CatalogueFont('azeret-mono', 'Azeret Mono'),
  'chakra-petch': CatalogueFont('chakra-petch', 'Chakra Petch'),
  'outfit': CatalogueFont('outfit', 'Outfit'),
  'jost': CatalogueFont('jost', 'Jost'),
  'shippori-mincho': CatalogueFont('shippori-mincho', 'Shippori Mincho'),
  'zen-kaku-gothic-new': CatalogueFont('zen-kaku-gothic-new', 'Zen Kaku Gothic New'),
};

/// Generic families: the platform's own fonts, reached through the OS, never bundled (SF Pro, New York and
/// Segoe never are).
const genericFonts = {'system', 'system-mono', 'sans', 'serif', 'mono'};

/// The icon sets a theme may name (theme.schema.json). Phase 1 draws Lucide only; the others are cut as
/// subset fonts in phase 3, and until then a theme naming one is drawn in Lucide, with a notice.
const iconSets = {
  'lucide', 'phosphor', 'tabler', 'material-outlined', 'material-rounded', 'material-sharp', 'pixelarticons',
  'iconoir',
};
const bundledIconSets = {'lucide'};

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
