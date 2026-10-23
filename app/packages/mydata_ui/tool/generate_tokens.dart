/// Regenerates, from design/ (run from this package's folder: `dart run tool/generate_tokens.dart`):
///
/// - lib/src/generated/tokens.g.dart from design/tokens.json and design/themes.json;
/// - lib/src/theme/builtin_themes.g.dart: the theme schema, System and Kiwi as the apps draw it today
///   (tool/themes_codegen.dart);
/// - `assets/themes/<slug>.json`, copies of `design/themes/<slug>/theme.json`;
/// - assets/logo/, copies of the logo files in design/assets/Logos.
///
/// test/generated_tokens_test.dart fails when any of them is stale.
library;

import 'dart:io';

import 'themes_codegen.dart';
import 'tokens_codegen.dart';

void main() {
  final tokens = File('$designDir/tokens.json').readAsStringSync();
  final themes = File('$designDir/themes.json').readAsStringSync();
  final designKiwi = File('$themesDir/kiwi/theme.json').readAsStringSync();
  // Written exactly as generated (not run through dart format), so the staleness test can compare bytes.
  File(generatedPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generateTokens(tokens, themes, designKiwi));
  final slugs = designThemeSlugs();
  File(builtinThemesPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generateBuiltinThemes(
      schemaText: File('$themesDir/theme.schema.json').readAsStringSync(),
      systemText: File('$themesDir/system/theme.json').readAsStringSync(),
      kiwiText: kiwiTodayThemeText(tokens, themes, designKiwi),
      tokensJson: tokens,
      assetSlugs: slugs,
    ));
  final assets = Directory(themeAssetsDir)..createSync(recursive: true);
  for (final f in assets.listSync().whereType<File>()) {
    f.deleteSync();
  }
  for (final slug in slugs) {
    File('$themesDir/$slug/theme.json').copySync('$themeAssetsDir/$slug.json');
  }
  for (final name in logoFiles) {
    File('$designDir/assets/Logos/$name').copySync('assets/logo/$name');
  }
  stdout.writeln('Generated $generatedPath and $builtinThemesPath, copied ${slugs.length} themes to $themeAssetsDir '
      'and ${logoFiles.length} logo files from $designDir');
}
