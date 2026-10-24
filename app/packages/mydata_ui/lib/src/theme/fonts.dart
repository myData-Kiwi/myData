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
      waits.add(_loading[id] ??= _load(f, bundle ?? testBundle ?? rootBundle));
    }
    if (waits.isNotEmpty) await Future.wait(waits);
  }

  /// [ensure] for every font [theme]'s type names.
  static Future<void> ensureFor(ThemeFile theme, {AssetBundle? bundle}) =>
      ensure(of(theme.style.type), bundle: bundle);

  /// The bundle fonts load from instead of the app's, for a test that controls when a load completes.
  @visibleForTesting
  static AssetBundle? testBundle;

  /// Forgets every font loaded or loading, so a test sees the app as it starts, and [testBundle].
  @visibleForTesting
  static void resetForTesting() {
    _loading.clear();
    _loaded.clear();
    testBundle = null;
  }

  /// Every bundled font, for tests and for a gallery that shows every theme.
  static Future<void> ensureAll({AssetBundle? bundle}) => ensure(fontCatalogue.keys, bundle: bundle);

  static Future<void> _load(CatalogueFont f, AssetBundle bundle) async {
    try {
      // Every file is read first, together, so a file that cannot be read is one error here and never an
      // unhandled one inside FontLoader (which would leave its other files' errors unseen).
      final reads = [for (final a in f.assets) bundle.load('packages/$fontPackage/$a')];
      await Future.wait(reads);
      final loader = FontLoader(familyOf(f));
      for (final read in reads) {
        loader.addFont(read);
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
