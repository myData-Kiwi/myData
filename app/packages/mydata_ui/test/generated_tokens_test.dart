// The generated tokens and the copied logos must match design/, like host/openapi.json matches the host.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/tokens_codegen.dart';

void main() {
  test('tokens.g.dart is generated from design/tokens.json and design/themes.json', () {
    final expected = generateTokens(File('$designDir/tokens.json').readAsStringSync(),
        File('$designDir/themes.json').readAsStringSync());
    expect(File(generatedPath).readAsStringSync() == expected, isTrue,
        reason: '$generatedPath is stale: run `dart run tool/generate_tokens.dart` in app/packages/mydata_ui');
  });

  test('the bundled logo files are the ones in design/assets/Logos', () {
    for (final name in logoFiles) {
      expect(File('assets/logo/$name').readAsBytesSync(), File('$designDir/assets/Logos/$name').readAsBytesSync(),
          reason: 'assets/logo/$name is stale: run `dart run tool/generate_tokens.dart` in app/packages/mydata_ui');
    }
  });
}
