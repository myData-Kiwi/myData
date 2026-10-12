/// Regenerates lib/src/generated/tokens.g.dart from design/tokens.json and design/themes.json, and copies the
/// logo files from design/assets/Logos. Run from this package's folder:
///
///   dart run tool/generate_tokens.dart
///
/// test/generated_tokens_test.dart fails when the committed output no longer matches design/.
library;

import 'dart:io';

import 'tokens_codegen.dart';

void main() {
  final tokens = File('$designDir/tokens.json').readAsStringSync();
  final themes = File('$designDir/themes.json').readAsStringSync();
  final out = File(generatedPath)..createSync(recursive: true);
  // Written exactly as generated (not run through dart format), so the staleness test can compare bytes.
  out.writeAsStringSync(generateTokens(tokens, themes));
  for (final name in logoFiles) {
    File('$designDir/assets/Logos/$name').copySync('assets/logo/$name');
  }
  stdout.writeln('Generated $generatedPath and copied ${logoFiles.length} logo files from $designDir');
}
