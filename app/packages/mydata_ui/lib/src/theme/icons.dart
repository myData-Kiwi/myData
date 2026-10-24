/// Icons by meaning (design/themes/ARCHITECTURE.md 1.5 and 3.6): widgets and apps name a [MyDataIcon]; the
/// look's icon set and weight decide the glyph (`context.icon(MyDataIcon.add)`). One table per set and weight
/// (icon_sets.g.dart, from tool/icons.json); every set maps every id (test/theme/icons_test.dart).
library;

import 'package:flutter/widgets.dart';

import 'icon_sets.g.dart';
import 'theme_file.dart';

/// An icon by what it means, not by how a set draws it. Add one: here, in tool/icons.json with a glyph in
/// every set, then run tool/subset_icons.sh.
enum MyDataIcon {
  // Sections and records.
  people,
  person,
  personAdd,
  contact,
  calendar,
  calendarMonth,
  calendarCheck,
  clock,
  photo,
  assistant,
  chat,
  status,
  importFile,
  settings,
  layers,
  review,
  list,
  note,
  trash,
  // Sources and the host.
  thisMac,
  host,
  cloud,
  sync,
  agents,
  key,
  // Actions.
  add,
  remove,
  edit,
  copy,
  search,
  clear,
  close,
  more,
  send,
  check,
  fileCheck,
  report,
  download,
  // Quick actions on a record.
  message,
  call,
  video,
  mail,
  map,
  // States.
  info,
  warning,
  error,
  success,
  // Navigation.
  sidebar,
  back,
  chevronLeft,
  chevronRight,
  chevronDown,
  upDown,
}

/// Every bundled icon font's family (each is `assets/fonts/<family>-subset.ttf`, declared in the pubspec).
Set<String> get iconFontFamilies => {
      for (final weights in iconTables.values)
        for (final table in weights.values) table.values.first.fontFamily!,
    };

/// The weights a theme may name, lightest first; `fill` is a solid glyph, after `bold`.
const iconWeights = ['thin', 'light', 'regular', 'bold', 'fill'];

/// The weight [set] draws for [weight]: the weight itself when the set has it, else the nearest it has (a
/// tie goes to the lighter one, `fill` to `bold` then `regular`). Lucide has one weight.
String nearestIconWeight(String set, String weight) {
  final have = iconTables[set] ?? iconTables['lucide']!;
  if (have.containsKey(weight)) return weight;
  final want = iconWeights.indexOf(weight).clamp(0, iconWeights.length - 1);
  String? best;
  var distance = iconWeights.length;
  for (final w in iconWeights) {
    if (!have.containsKey(w)) continue;
    final d = (iconWeights.indexOf(w) - want).abs();
    if (d < distance) {
      best = w;
      distance = d;
    }
  }
  return best!;
}

/// A look's icons: its set at its weight, and the filled glyphs for a selected item when the theme fills
/// them (`selected: fill`) and the set has a fill. A set this build does not have is drawn in Lucide.
@immutable
class MyDataIconTheme {
  factory MyDataIconTheme(IconsSpec spec) {
    final set = iconTables.containsKey(spec.set) ? spec.set : 'lucide';
    final weight = nearestIconWeight(set, spec.weight);
    final glyphs = iconTables[set]![weight]!;
    final fill = iconTables[set]!['fill'];
    return MyDataIconTheme._(spec, set, weight, glyphs, spec.fillSelected && fill != null ? fill : glyphs);
  }

  const MyDataIconTheme._(this.spec, this.set, this.weight, this._glyphs, this._selected);

  /// The theme's `icons` group as written.
  final IconsSpec spec;

  /// The set drawn: the theme's, or Lucide when this build does not have it.
  final String set;

  /// The weight drawn: the theme's, or the nearest the set has.
  final String weight;

  final Map<MyDataIcon, IconData> _glyphs, _selected;

  /// How icon tiles are drawn: `tinted`, `outlined` or `none` (the widgets' variants, from phase 3).
  String get tiles => spec.tiles;

  /// [icon]'s glyph, filled when [selected] and the theme fills selected icons.
  IconData call(MyDataIcon icon, {bool selected = false}) => (selected ? _selected : _glyphs)[icon]!;
}
