/// The theme fonts at run time (design/themes/ARCHITECTURE.md 3.6): the core three are registered by the
/// engine from the pubspec; every other catalogue font is loaded from this package's assets the first time
/// a theme that needs it is chosen or previewed, and kept for the session.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'catalogue.dart';
import 'theme_file.dart';

abstract final class ThemeFonts {
  static final _loading = <String, Future<void>>{};
  static final _loaded = <String>{};

  /// The family name a bundled catalogue font is drawn under (`packages/mydata_ui/Inter`).
  static String familyOf(CatalogueFont font) => 'packages/$fontPackage/${font.family}';

  /// Whether [id] can be drawn now: a core font, or one loaded already.
  static bool isReady(String id) {
    final f = fontCatalogue[id];
    return f != null && f.bundled && (f.core || _loaded.contains(id));
  }

  /// The bundled catalogue fonts [type] draws: the first bundled font of each stack and those after it,
  /// which carry glyphs the first lacks.
  static Set<String> of(TypeSpec type) => {
        for (final s in TypeStack.values)
          for (final id in type.stack(s))
            if (fontCatalogue[id]?.bundled ?? false) id,
      };

  /// Whether every font [theme]'s type names can be drawn now.
  static bool readyFor(ThemeFile theme) => of(theme.style.type).every(isReady);

  /// Loads [ids] (unknown, unbundled and core fonts are skipped) and completes when every one can be drawn.
  /// A font that cannot be loaded is reported and left out; its text falls back to the next font.
  static Future<void> ensure(Iterable<String> ids, {AssetBundle? bundle}) async {
    final waits = <Future<void>>[];
    for (final id in ids) {
      final f = fontCatalogue[id];
      if (f == null || !f.variable || _loaded.contains(id)) continue;
      waits.add(_loading[id] ??= _load(f, bundle ?? rootBundle));
    }
    if (waits.isNotEmpty) await Future.wait(waits);
  }

  /// [ensure] for every font [theme]'s type names.
  static Future<void> ensureFor(ThemeFile theme, {AssetBundle? bundle}) =>
      ensure(of(theme.style.type), bundle: bundle);

  /// Every bundled font, for tests and for a gallery that shows every theme.
  static Future<void> ensureAll({AssetBundle? bundle}) => ensure(fontCatalogue.keys, bundle: bundle);

  static Future<void> _load(CatalogueFont f, AssetBundle bundle) async {
    try {
      final loader = FontLoader(familyOf(f));
      for (final a in f.assets) {
        loader.addFont(bundle.load('packages/$fontPackage/$a'));
      }
      await loader.load();
      _loaded.add(f.id);
    } on Object catch (e) {
      // Text in this font falls back to the next font in its stack; a later ensure tries again.
      _loading.remove(f.id);
      FlutterError.reportError(FlutterErrorDetails(
          exception: e, library: 'mydata_ui', context: ErrorDescription('while loading the font ${f.name}')));
    }
  }
}
