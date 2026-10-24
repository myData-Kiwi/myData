// The generated tokens, the generated built-in themes and the copied theme and logo files must match design/,
// like host/openapi.json matches the host.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

import '../tool/themes_codegen.dart';
import '../tool/tokens_codegen.dart';

const _rerun = 'run `dart run tool/generate_tokens.dart` in app/packages/mydata_ui';

void main() {
  final tokens = File('$designDir/tokens.json').readAsStringSync();
  final themes = builtInThemeTexts();

  test('tokens.g.dart is generated from design/tokens.json and the Kiwi theme', () {
    expect(File(generatedPath).readAsStringSync() == generateTokens(tokens, themes['kiwi']!), isTrue,
        reason: '$generatedPath is stale: $_rerun');
  });

  test('builtin_themes.g.dart is generated from design/themes and design/tokens.json', () {
    final expected = generateBuiltinThemes(
      schemaText: File('$themesDir/theme.schema.json').readAsStringSync(),
      themeTexts: themes,
      tokensJson: tokens,
    );
    expect(File(builtinThemesPath).readAsStringSync() == expected, isTrue,
        reason: '$builtinThemesPath is stale: $_rerun');
  });

  test('the built-ins are every theme file of design/themes, byte for byte, System first', () {
    expect(designThemeSlugs(), [
      'system', 'kiwi', 'hairline', 'frosted', 'journal', 'sticker', 'paperback', 'high-contrast', 'e-ink', 'large', 'terminal', 'notebook',
    ]);
    expect(builtInThemeJson.keys, [for (final s in designThemeSlugs()) 'mydata.$s']);
    for (final slug in designThemeSlugs()) {
      expect(builtInThemeJson['mydata.$slug'], File('$themesDir/$slug/theme.json').readAsStringSync(),
          reason: '$builtinThemesPath is stale for $slug: $_rerun');
    }
  });

  test('design/themes.json is gone: the theme files are the only source of a theme\'s colours', () {
    expect(File('$designDir/themes.json').existsSync(), isFalse);
  });

  test('tokens.json\'s colours are Kiwi\'s default palette, so the first frame is Kiwi', () {
    // extraColourValues refuses a tokens.json colour Kiwi's file does not give.
    expect(() => extraColourValues(tokens, themes['kiwi']!), returnsNormally);
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
