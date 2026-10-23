// The generated tokens, the generated built-in themes and the copied theme and logo files must match design/,
// like host/openapi.json matches the host.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mydata_ui/mydata_ui.dart';

import '../tool/themes_codegen.dart';
import '../tool/tokens_codegen.dart';

const _rerun = 'run `dart run tool/generate_tokens.dart` in app/packages/mydata_ui';

void main() {
  final tokens = File('$designDir/tokens.json').readAsStringSync();
  final themes = File('$designDir/themes.json').readAsStringSync();
  final designKiwi = File('$themesDir/kiwi/theme.json').readAsStringSync();

  test('tokens.g.dart is generated from design/tokens.json, design/themes.json and the Kiwi theme', () {
    expect(File(generatedPath).readAsStringSync() == generateTokens(tokens, themes, designKiwi), isTrue,
        reason: '$generatedPath is stale: $_rerun');
  });

  test('builtin_themes.g.dart is generated from design/themes, design/tokens.json and design/themes.json', () {
    final expected = generateBuiltinThemes(
      schemaText: File('$themesDir/theme.schema.json').readAsStringSync(),
      systemText: File('$themesDir/system/theme.json').readAsStringSync(),
      kiwiText: kiwiTodayThemeText(tokens, themes, designKiwi),
      tokensJson: tokens,
      assetSlugs: designThemeSlugs(),
    );
    expect(File(builtinThemesPath).readAsStringSync() == expected, isTrue,
        reason: '$builtinThemesPath is stale: $_rerun');
  });

  test('the bundled theme files are the ones in design/themes, and only those', () {
    final slugs = designThemeSlugs();
    expect(slugs, containsAll(['system', 'kiwi', 'hairline', 'frosted', 'journal', 'sticker', 'paperback']));
    final bundled = Directory(themeAssetsDir).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()
      ..sort();
    expect(bundled, [for (final s in slugs) '$s.json']..sort(), reason: '$themeAssetsDir is stale: $_rerun');
    for (final slug in slugs) {
      expect(File('$themeAssetsDir/$slug.json').readAsBytesSync(), File('$themesDir/$slug/theme.json').readAsBytesSync(),
          reason: '$themeAssetsDir/$slug.json is stale: $_rerun');
    }
  });

  test('the bundled logo files are the ones in design/assets/Logos', () {
    for (final name in logoFiles) {
      expect(File('assets/logo/$name').readAsBytesSync(), File('$designDir/assets/Logos/$name').readAsBytesSync(),
          reason: 'assets/logo/$name is stale: $_rerun');
    }
  });

  test('the hand-written durations in motion.dart match design/motion.md', () {
    final md = File('$designDir/motion.md').readAsStringSync();
    String row(String name) => RegExp('^\\| `$name` \\| ([^|]+) \\|', multiLine: true).firstMatch(md)!.group(1)!.trim();
    expect(row('fast'), '${MyDataMotion.fast.inMilliseconds}ms');
    expect(row('base'), '${MyDataMotion.base.inMilliseconds}ms');
    expect(row('slow'), '${MyDataMotion.slow.inMilliseconds}ms');
    expect(row('toast-duration'), '${MyDataMotion.toastDuration.inSeconds}s');
  });
}
