// The designed built-ins of design/themes, as the tests read them: generated into builtin_themes.g.dart,
// validated as built-ins, resolved like any theme.
import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

/// The built-in theme files, by id.
Map<String, String> designedThemeTexts() => builtInThemeJson;

/// The validator's format, every built-in's style known to be based on.
ThemeFormat designedThemeFormat() => ThemeLibrary.format();

/// The drawn built-ins (every built-in but System), in the gallery's order.
final drawnBuiltIns = [for (final id in builtInThemeJson.keys) if (id != 'mydata.system') id];

final _files = <String, ThemeFile>{};

/// The designed theme [id], validated as a built-in.
ThemeFile designedTheme(String id) => _files[id] ??= () {
      final r = validateThemeText(designedThemeTexts()[id]!, designedThemeFormat(), builtIn: true);
      if (!r.ok) throw StateError('$id fails: ${r.errors.join('; ')}');
      return r.theme!;
    }();

/// [id]'s look in its default palette (or [palette]) for [brightness], drawn off the Mac shell.
MyDataLook designedLook(String id, Brightness brightness, {String? palette, TargetPlatform? platform}) =>
    ThemeLibrary.look(designedTheme(id), paletteId: palette, brightness: brightness, platform: platform);
