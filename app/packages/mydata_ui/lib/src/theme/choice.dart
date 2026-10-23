import 'package:flutter/foundation.dart';

/// One choice of look: a theme and, for a theme with palettes, one of them (design/themes/ARCHITECTURE.md
/// 4.1). Stored per app and per device as `{"theme": "mydata.kiwi", "palette": "plum"}`.
///
/// - [palette] null means the theme's default palette. A theme without palettes (System) never takes one:
///   [ThemeLibrary.normalise] drops it, and nothing writes one for it.
/// - Palette ids belong to one theme: a choice of another theme never carries the old palette.
@immutable
class ThemeChoice {
  const ThemeChoice(this.theme, [this.palette]);

  /// System, the default everywhere: the platform's own look.
  static const system = ThemeChoice('mydata.system');

  final String theme;
  final String? palette;

  /// As stored in the device's settings.
  Map<String, Object?> toJson() => {'theme': theme, 'palette': ?palette};

  /// A stored choice, or null when [value] is not one (a hand-edited file): no theme, or not text.
  static ThemeChoice? fromJson(Object? value) {
    if (value is! Map) return null;
    final theme = value['theme'];
    if (theme is! String || theme.isEmpty) return null;
    final palette = value['palette'];
    return ThemeChoice(theme, palette is String && palette.isNotEmpty ? palette : null);
  }

  @override
  bool operator ==(Object other) => other is ThemeChoice && other.theme == theme && other.palette == palette;

  @override
  int get hashCode => Object.hash(theme, palette);

  @override
  String toString() => palette == null ? theme : '$theme/$palette';
}
