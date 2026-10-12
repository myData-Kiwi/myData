/// Test helpers for the myData packages and apps. Dev dependency only.
///
/// - [loadMyDataFonts]: render the bundled fonts (and Material icons) in widget and golden tests instead of
///   Flutter's test font. Call it from each package's test/flutter_test_config.dart.
/// - [themeMatrix] and [goldenMatrix]: one golden per theme and mode (Kiwi and Graphite, light and dark).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _fonts = {
  MyDataFontFamily.display: ['PlusJakartaSans-700.ttf'],
  MyDataFontFamily.body: ['Figtree-400.ttf', 'Figtree-600.ttf'],
  MyDataFontFamily.mono: ['JetBrainsMono-400.ttf'],
};

/// Loads the bundled fonts under the names Flutter gives package fonts, and Material Icons when the package
/// under test bundles them.
Future<void> loadMyDataFonts() async {
  for (final e in _fonts.entries) {
    final loader = FontLoader('packages/${MyDataFontFamily.package}/${e.key}');
    for (final file in e.value) {
      loader.addFont(rootBundle.load('packages/${MyDataFontFamily.package}/assets/fonts/$file'));
    }
    await loader.load();
  }
  try {
    final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
  } on FlutterError {
    // The package under test does not use Material icons.
  }
}

/// For test/flutter_test_config.dart:
/// `Future<void> testExecutable(FutureOr<void> Function() main) => myDataTestExecutable(main);`
Future<void> myDataTestExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadMyDataFonts();
  await testMain();
}

/// One theme and mode to render a golden in.
class ThemeCase {
  const ThemeCase(this.themeId, this.brightness);
  final String themeId;
  final Brightness brightness;
  String get label => '$themeId-${brightness.name}';
  ThemeData get data => MyDataTheme.data(themeId, brightness);
}

/// The four combinations every widget golden and screenshot is made in.
const themeMatrix = [
  ThemeCase('kiwi', Brightness.light),
  ThemeCase('kiwi', Brightness.dark),
  ThemeCase('graphite', Brightness.light),
  ThemeCase('graphite', Brightness.dark),
];

/// Wraps [child] the way an app does: the theme, accessibility settings, a `bg` ground and padding.
Widget themedFrame(ThemeCase theme, Widget child,
        {bool reduceMotion = false, bool reduceTransparency = false, EdgeInsets padding = const EdgeInsets.all(24)}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.data,
      home: MyDataAccessibility(
        reduceMotion: reduceMotion,
        reduceTransparency: reduceTransparency,
        child: Builder(
          builder: (context) => ColoredBox(
            color: context.colors.bg,
            child: Padding(padding: padding, child: Align(alignment: Alignment.topLeft, child: child)),
          ),
        ),
      ),
    );

/// Defines one golden test per [themeMatrix] case: `goldens/<name>.<theme>-<mode>.png`, at [size].
void goldenMatrix(String name, Widget Function() build,
    {Size size = const Size(560, 360), bool reduceMotion = false, bool reduceTransparency = false,
    Future<void> Function(WidgetTester tester)? before}) {
  for (final theme in themeMatrix) {
    testWidgets('$name golden (${theme.label})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themedFrame(theme, build(),
          reduceMotion: reduceMotion, reduceTransparency: reduceTransparency));
      if (before != null) await before(tester);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.${theme.label}.png'));
    });
  }
}
