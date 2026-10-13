// No widget or app contains a literal colour, radius or font name: they come from the generated tokens
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
  test('no literal colour, radius or font name outside the generated tokens', () {
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
  });
}
