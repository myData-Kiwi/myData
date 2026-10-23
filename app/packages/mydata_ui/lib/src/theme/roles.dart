/// The colour roles a palette gives (design/themes/theme.schema.json, `colourSetPartial`; ARCHITECTURE.md 1.3).
library;

/// One of the 43 colour roles of a palette, by its key in a theme file.
enum ColourRole {
  bg('bg'),
  surface('surface'),
  surfaceRaised('surface-raised'),
  surfaceSunken('surface-sunken'),
  surfaceHover('surface-hover'),
  sidebar('sidebar'),
  toolbar('toolbar'),
  line('line'),
  lineStrong('line-strong'),
  edge('edge'),
  ink('ink'),
  inkMuted('ink-muted'),
  accent('accent'),
  onAccent('on-accent'),
  accentSoft('accent-soft'),
  link('link'),
  selection('selection'),
  onSelection('on-selection'),
  selectionInactive('selection-inactive'),
  focus('focus'),
  focusOnDanger('focus-on-danger'),
  success('success'),
  successSoft('success-soft'),
  warning('warning'),
  warningSoft('warning-soft'),
  danger('danger'),
  dangerSoft('danger-soft'),
  onDanger('on-danger'),
  info('info'),
  infoSoft('info-soft'),
  avatarFill('avatar-fill'),
  dataRed('data-red'),
  dataOrange('data-orange'),
  dataYellow('data-yellow'),
  dataGreen('data-green'),
  dataBlue('data-blue'),
  dataPurple('data-purple'),
  dataBrown('data-brown'),
  dataGrey('data-grey'),
  scrim('scrim'),
  glassFill('glass-fill'),
  glassStroke('glass-stroke'),
  shadow('shadow');

  const ColourRole(this.key);

  /// The role's key in a theme file (`ink-muted`).
  final String key;

  static final Map<String, ColourRole> _byKey = {for (final r in values) r.key: r};

  /// The role named [key] in a theme file, or null.
  static ColourRole? byKey(String key) => _byKey[key];

  /// The six roles every palette gives in each mode.
  static const seeds = {bg, surface, ink, inkMuted, accent, onAccent};

  /// The roles that may carry alpha (`#RRGGBBAA`); every other one is opaque.
  static const translucent = {scrim, glassFill, glassStroke};

  /// The status colours, each with its `-soft` fill.
  static const status = {success: successSoft, warning: warningSoft, danger: dangerSoft, info: infoSoft};

  /// The calendar colours myData owns (`data-*`), in the ColourPicker's order.
  static const data = [dataRed, dataOrange, dataYellow, dataGreen, dataBlue, dataPurple, dataBrown, dataGrey];

  bool get isSeed => seeds.contains(this);
}

/// Light or dark: which half of a palette.
enum LookMode {
  light,
  dark;

  String get key => name;
}
