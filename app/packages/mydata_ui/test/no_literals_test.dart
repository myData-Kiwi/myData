// No widget or app contains a literal colour, radius or font name, a token nudged by a number or a numeric
// border width: they come from the generated tokens (lib/src/generated/tokens.g.dart), which is the only file
// allowed to hold them, besides the font catalogue (lib/src/theme/catalogue.dart), the one place a font is
// named. And no widget or app reads a themeable token statically (`MyDataSpace.s4`, `MyDataType.body`): it
// reads the look through its context (`context.space(4)`, `context.typeScale.body`), so a theme can change it
// (design/themes/ARCHITECTURE.md 3.1). Only lib/src/theme/ and lib/src/generated/ may name the static
// classes. This test scans the source of every app and package and fails `flutter test` when one appears
// anywhere else.
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

/// The font catalogue: the one place a font is named.
const catalogue = '../mydata_ui/lib/src/theme/catalogue.dart';

/// Where the static token classes are defined and turned into looks.
const themeDirs = ['../mydata_ui/lib/src/theme/', '../mydata_ui/lib/src/generated/'];

/// Static reads of a value a theme can change. Not refused: the layout widths a theme never changes
/// (`MyDataSize.contentMax`, `dialogWidth`), `MyDataMotion.toastDuration` and `MyDataMotion.reduced`, and the
/// Mac frame's own tokens (`MyDataMac*`), which are the System look's.
final staticTokenRead = RegExp(r'\bMyData(?:Space|Type|Radius|Blur|Shadows|Colors)\.\w'
    r'|\bMyDataSize\.(?:controlHeight|controlHeightCompact|rowHeight|iconTile|icon)\b'
    r'|\bMyDataMotion\.(?:fast|base|slow|standard|springDuration|spring|pressScale|pressOpacity|entranceRise'
    r'|entranceStagger|entranceMaxStaggered|sheetDrop)\b'
    // Kiwi's look and its groups, reached statically: the same themeable values.
    r'|\bMyData(?:TypeScale|Shape|Density|MotionSpec)\.kiwi\b|\bMyDataLook\.fallback\(');

/// Where Kiwi's look may be read statically besides lib/src/theme/: the test helpers, whose `kiwiLook` is
/// the look tests draw against.
const kiwiLookAllowed = ['../mydata_testing/lib/'];
final kiwiLookRead = RegExp(r'\bMyDataLook\.fallback\(');

final rules = <String, RegExp>{
  'literal colour': RegExp(r'\bColor\(\s*0x|\bColor\.from(?:ARGB|RGBO)\(|\bColors\.(?!transparent\b)\w+|\bCupertinoColors\.'),
  'literal radius': RegExp(r'\b(?:Radius\.(?:circular|elliptical)|BorderRadius\.circular)\(\s*[\d.]'),
  // A token nudged by a pixel or two (`MyDataSpace.s1 + 2`, `MyDataMacRadius.selection - 2`, `fontSize! + 2`):
  // the in-between value wants a token of its own (`tight`, `hairline`).
  'token arithmetic': RegExp(
      r'(?:\b(?:MyDataSpace|MyDataSize|MyDataRadius|MyDataMacSize|MyDataMacRadius)\.\w+'
      r'|\b(?:context|look)\.(?:space\(\d+\)|density\.\w+|radius\.\w+))'
      r'\s*[-+]\s*\d+(?:\.\d+)?(?!\s*[*\d.])|\bfontSize!?\s*[-+]\s*\d'),
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

List<String> violations(File f) => violationsIn(f.path, f.readAsLinesSync());

/// The violations in [lines], judged as the file at [path].
List<String> violationsIn(String path, List<String> lines) {
  final out = <String>[];
  final inTheme = themeDirs.any(path.startsWith);
  for (var n = 0; n < lines.length; n++) {
    final code = stripComments(lines[n]);
    for (final r in rules.entries) {
      if (r.key == 'literal font name' && path == catalogue) continue;
      if (r.value.hasMatch(code)) out.add('$path:${n + 1}: ${r.key}: ${lines[n].trim()}');
    }
    final allowedKiwiLook = kiwiLookAllowed.any(path.startsWith) && kiwiLookRead.hasMatch(code) &&
        !staticTokenRead.hasMatch(code.replaceAll(kiwiLookRead, ''));
    if (!inTheme && !allowedKiwiLook && staticTokenRead.hasMatch(code)) {
      out.add('$path:${n + 1}: static token read: ${lines[n].trim()}');
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
    expect(found, isEmpty,
        reason: 'Use the look (context.colors, context.space(4), context.typeScale.body, context.radius.lg) '
            'instead:\n${found.join('\n')}');
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
    expect(check('padding: EdgeInsets.all(context.space(1) + 2),'), 'token arithmetic');
    expect(check('height: context.density.controlHeight - 4,'), 'token arithmetic');
    expect(check('width: context.space(1) + MyDataMacSize.tight,'), '');
  });

  test('the static token rule catches themeable reads and lets the rest through', () {
    bool flags(String line) => staticTokenRead.hasMatch(stripComments(line));
    expect(flags('padding: EdgeInsets.all(MyDataSpace.s4),'), isTrue);
    expect(flags('style: MyDataType.body,'), isTrue);
    expect(flags('Radius.circular(MyDataRadius.lg)'), isTrue);
    expect(flags('height: MyDataSize.controlHeight,'), isTrue);
    expect(flags('duration: MyDataMotion.fast,'), isTrue);
    expect(flags('final c = MyDataColors.light;'), isTrue);
    expect(flags('maxWidth: MyDataSize.contentMax,'), isFalse);
    expect(flags('if (MyDataMotion.reduced(context)) return;'), isFalse);
    expect(flags('duration: MyDataMotion.toastDuration,'), isFalse);
    expect(flags('height: MyDataMacSize.rowHeight,'), isFalse);
    expect(flags('/// Rises [MyDataMotion.entranceRise] into place.'), isFalse);
    expect(flags('style: MyDataTypeScale.kiwi.body,'), isTrue);
    expect(flags('radius: MyDataShape.kiwi.lg,'), isTrue);
    expect(flags('height: MyDataDensity.kiwi.rowHeight,'), isTrue);
    expect(flags('duration: MyDataMotionSpec.kiwi.fast,'), isTrue);
    expect(flags('final look = MyDataLook.fallback(Brightness.light);'), isTrue);
    expect(flags('final s = MyDataTypeScale.of(spec);'), isFalse);
    expect(flags('final look = MyDataLook.of(context);'), isFalse);
  });

  test('only the test helpers may read Kiwi\'s look statically, and only that', () {
    const line = 'final kiwiLook = MyDataLook.fallback(Brightness.light);';
    expect(violationsIn('../mydata_testing/lib/mydata_testing.dart', [line]), isEmpty);
    expect(violationsIn('../../apps/mycontacts/lib/main.dart', [line]), hasLength(1));
    expect(
        violationsIn('../mydata_testing/lib/mydata_testing.dart',
            ['final s = MyDataLook.fallback(b).typeScale ?? MyDataType.body;']),
        hasLength(1));
  });
}

