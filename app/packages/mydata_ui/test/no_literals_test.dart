// No widget or app contains a literal colour, radius or font name, a token nudged by a number or a numeric
// border width: they come from the generated tokens
// (lib/src/generated/tokens.g.dart), which is the only file allowed to hold them. This test scans the source
// of every app and package and fails `flutter test` when one appears anywhere else.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source folders scanned, relative to this package. mydata_client is generated from the host API and has no UI.
const roots = [
  '../../apps',
  '../mydata_ui/lib',
  '../mydata_core/lib',
  '../mydata_assistant/lib',
  '../mydata_testing/lib',
];

/// The one file allowed to contain literals.
const generated = '../mydata_ui/lib/src/generated/tokens.g.dart';

final rules = <String, RegExp>{
  'literal colour': RegExp(r'\bColor\(\s*0x|\bColor\.from(?:ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w+|\bCupertinoColors\.'),
  'literal radius': RegExp(r'\b(?:Radius\.(?:circular|elliptical)|BorderRadius\.circular)\(\s*[\d.]'),
  // A token nudged by a pixel or two (`MyDataSpace.s1 + 2`, `MyDataMacRadius.selection - 2`, `fontSize! + 2`):
  // the in-between value wants a token of its own (`tight`, `hairline`).
  'token arithmetic': RegExp(
      r'\b(?:MyDataSpace|MyDataSize|MyDataRadius|MyDataMacSize|MyDataMacRadius)\.\w+\s*[-+]\s*\d+(?:\.\d+)?(?!\s*[*\d.])|\bfontSize!?\s*[-+]\s*\d'),
  // A border's width as a number: hairlines and focus rings are tokens (`hairline`, `focus-ring-width`).
  'literal border width': RegExp(r'\bBorder(?:Side)?(?:\.all)?\([^)]*\bwidth:\s*(?:[^,)]*[?:]\s*)?\d'),
  // A one-number nudge in the Mac frame's insets (`vertical: 2`, `top: 2`) or a half-point line: `tight`,
  // `hairline`.
  'literal small inset': RegExp(r'\b(?:vertical|horizontal|top|bottom):\s*[1-3](?:\.\d+)?\s*[,)]|height:\s*0\.5\b'),
  'literal font name': RegExp(
      r'''fontFamily:\s*['"]|['"](?:Figtree|PlusJakartaSans|Plus Jakarta Sans|JetBrainsMono|JetBrains Mono|BricolageGrotesque|Bricolage Grotesque|Roboto|Inter|Helvetica(?: Neue)?|Menlo|SF Pro(?: Text| Display)?|Courier(?: New)?|monospace)['"]'''),
};

/// Dart files under [roots] that are app or package source (not build output or platform folders).
Iterable<File> sources() sync* {
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final p = f.path;
      if (!p.endsWith('.dart')) continue;
      if (RegExp(r'/(?:build|\.dart_tool|macos|windows|linux|ios|android|web)/').hasMatch(p)) continue;
      if (root == '../../apps' && !RegExp(r'^\.\./\.\./apps/[^/]+/lib/').hasMatch(p)) continue;
      yield f;
    }
  }
}

/// Removes // comments (outside string literals, roughly) so documentation may mention values.
String stripComments(String line) {
  final i = line.indexOf('//');
  if (i < 0) return line;
  final before = line.substring(0, i);
  final quotes = "'".allMatches(before).length + '"'.allMatches(before).length;
  return quotes.isEven ? before : line;
}

List<String> violations(File f) {
  final out = <String>[];
  final lines = f.readAsLinesSync();
  for (var n = 0; n < lines.length; n++) {
    final code = stripComments(lines[n]);
    for (final r in rules.entries) {
      if (r.value.hasMatch(code)) out.add('${f.path}:${n + 1}: ${r.key}: ${lines[n].trim()}');
    }
  }
  return out;
}

void main() {
  test('no literal colour, radius, font name, token arithmetic or border width outside the generated tokens', () {
    final found = <String>[];
    var scanned = 0;
    for (final f in sources()) {
      if (f.path == generated) continue;
      scanned++;
      found.addAll(violations(f));
    }
    expect(scanned, greaterThan(20), reason: 'the scan found too few files; are the roots right?');
    expect(found, isEmpty, reason: 'Use the tokens (context.colors, MyDataRadius, MyDataType) instead:\n${found.join('\n')}');
  });

  test('the rules catch what they should', () {
    String check(String line) => rules.entries.where((r) => r.value.hasMatch(stripComments(line))).map((r) => r.key).join(',');
    expect(check('color: Color(0xFF4C7814),'), 'literal colour');
    expect(check('color: Colors.green,'), 'literal colour');
    expect(check('color: Colors.transparent,'), '');
    expect(check('borderRadius: BorderRadius.circular(12),'), 'literal radius');
    expect(check('borderRadius: BorderRadius.all(Radius.circular(MyDataRadius.lg)),'), '');
    expect(check("style: TextStyle(fontFamily: 'Figtree'),"), 'literal font name');
    expect(check('// a comment about Color(0xFF000000)'), '');
    expect(check('padding: EdgeInsets.all(MyDataSpace.s1 + 2),'), 'token arithmetic');
    expect(check('Radius.circular(MyDataMacRadius.selection - 2)'), 'token arithmetic');
    expect(check('cursorHeight: style.fontSize! + 2,'), 'token arithmetic');
    expect(check('width: MyDataSpace.s1 + MyDataMacSize.tight,'), '');
    expect(check('minHeight: MyDataMacSize.pushButtonHeight + 2 * MyDataSpace.s2,'), '');
    expect(check('border: Border.all(color: c.line, width: 0.5),'), 'literal border width');
    expect(check('border: Border.all(color: c.line, width: MyDataMacSize.hairline),'), '');
    expect(check('border: Border.all(color: c.line, width: focused ? 2 : 0.5),'), 'literal border width');
    expect(check('padding: const EdgeInsets.only(top: 2),'), 'literal small inset');
    expect(check('padding: const EdgeInsets.only(top: MyDataMacSize.tight),'), '');
  });
}
