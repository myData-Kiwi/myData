// The designed built-ins of design/themes (the phase 3 looks), as the tests read them: bundled in
// assets/themes, validated as built-ins, resolved like any theme.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/strict_json.dart';
import 'package:mydata_ui/src/theme/validate.dart';

/// The designed theme files as bundled, by id.
Map<String, String> designedThemeTexts() => {
      for (final f in Directory('assets/themes').listSync().whereType<File>())
        'mydata.${f.uri.pathSegments.last.replaceAll('.json', '')}': f.readAsStringSync(),
    };

/// The validator's format, with the designed styles as built-ins to be based on.
ThemeFormat designedThemeFormat() => ThemeLibrary.format(extraStyles: {
      for (final e in designedThemeTexts().entries)
        if (e.key != ThemeLibrary.kiwiId && e.key != ThemeLibrary.systemId)
          e.key: readStrictJson(e.value) as Map<String, Object?>,
    });

/// The six drawn built-ins, in the gallery's order.
const drawnBuiltIns = [
  'mydata.kiwi', 'mydata.hairline', 'mydata.frosted', 'mydata.journal', 'mydata.sticker', 'mydata.paperback',
];

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
