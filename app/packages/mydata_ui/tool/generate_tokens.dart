/// Regenerates, from design/ (run from this package's folder: `dart run tool/generate_tokens.dart`):
///
/// - lib/src/generated/tokens.g.dart from design/tokens.json and design/themes/kiwi/theme.json;
/// - lib/src/theme/builtin_themes.g.dart: the theme schema and every built-in theme file of design/themes
///   (System, Kiwi, Hairline, Frosted, Journal, Sticker, Paperback) as JSON text (tool/themes_codegen.dart);
/// - assets/logo/, copies of the logo files in design/assets/Logos.
///
/// test/generated_tokens_test.dart fails when any of them is stale.
library;

import 'dart:io';

import 'themes_codegen.dart';
import 'tokens_codegen.dart';

void main() {
  final tokens = File('$designDir/tokens.json').readAsStringSync();
  final themes = builtInThemeTexts();
  // Written exactly as generated (not run through dart format), so the staleness test can compare bytes.
  File(generatedPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generateTokens(tokens, themes['kiwi']!));
  File(builtinThemesPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(generateBuiltinThemes(
      schemaText: File('$themesDir/theme.schema.json').readAsStringSync(),
      themeTexts: themes,
      tokensJson: tokens,
    ));
  for (final name in logoFiles) {
    File('$designDir/assets/Logos/$name').copySync('assets/logo/$name');
  }
  stdout.writeln('Generated $generatedPath and $builtinThemesPath (${themes.length} themes), and copied '
      '${logoFiles.length} logo files from $designDir');
}
