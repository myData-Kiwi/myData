/// Test helpers for the myData packages and apps. Dev dependency only.
///
/// - [loadMyDataFonts]: render the bundled fonts (and Material icons) in widget and golden tests instead of
///   Flutter's test font. Call it from each package's test/flutter_test_config.dart.
/// - [themeMatrix] and [goldenMatrix]: one golden per theme and mode (Kiwi and Graphite, light and dark).
/// - [loadMacFonts] and [macMatrix]: the Mac frame's fonts (the system font, Lucide) and its two appearances.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
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

/// Where macOS keeps the system font (SF Pro, a variable font). Read, never copied into the repo.
const macSystemFontFile = '/System/Library/Fonts/SFNS.ttf';

/// Loads the Mac frame's fonts: Lucide (bundled in mydata_ui) and a font under the names Flutter's macOS
/// engine gives the system font ([MyDataMacFont.text] and [MyDataMacFont.display]).
///
/// - By default that font is the bundled Figtree (SIL OFL), so committed screenshots of the Mac frame hold no
///   rasterised SF Pro (Apple's font licence; the repo is public) and look the same on any machine.
/// - With [systemFont], on a Mac, it is the system font itself, read from [macSystemFontFile] and never copied
///   into the repo: for a local check of the real font, written outside the checkout and never committed.
///   Elsewhere the system font is missing and Figtree is used.
///
/// Returns whether the system font was loaded.
Future<bool> loadMacFonts({bool systemFont = false}) async {
  final icons = FontLoader('packages/${MyDataFontFamily.package}/${MyDataMacFont.icons}')
    ..addFont(rootBundle.load('packages/${MyDataFontFamily.package}/assets/fonts/Lucide-subset.ttf'));
  await icons.load();
  final file = File(macSystemFontFile);
  if (systemFont && file.existsSync()) {
    final bytes = file.readAsBytesSync();
    for (final family in const [MyDataMacFont.text, MyDataMacFont.display]) {
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    return true;
  }
  for (final family in const [MyDataMacFont.text, MyDataMacFont.display]) {
    final loader = FontLoader(family);
    for (final f in const ['Figtree-400.ttf', 'Figtree-600.ttf']) {
      loader.addFont(rootBundle.load('packages/${MyDataFontFamily.package}/assets/fonts/$f'));
    }
    await loader.load();
  }
  return false;
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

/// The Mac frame's two appearances. Its accent is the system's, not the host's theme, so one theme is enough.
const macMatrix = [
  ThemeCase('kiwi', Brightness.light),
  ThemeCase('kiwi', Brightness.dark),
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
          builder: (context) => Material(
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
      // flutter_test draws shadows without blur by default; goldens should look like the app.
      painting.debugDisableShadows = false;
      await tester.pumpWidget(themedFrame(theme, build(),
          reduceMotion: reduceMotion, reduceTransparency: reduceTransparency));
      if (before != null) await before(tester);
      await tester.pumpAndSettle();
      try {
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.${theme.label}.png'));
      } finally {
        painting.debugDisableShadows = true;
      }
    });
  }
}

/// Defines one screenshot test per [themes] case (every [themeMatrix] case unless given) for a whole app
/// screen: [build] gets the theme case and returns the app (its own MaterialApp, themed with `theme.data`),
/// rendered at [size] into `screenshots/<name>.<theme>-<mode>.png`. Run with --update-goldens to refresh them.
void screenMatrix(String name, Widget Function(ThemeCase theme) build,
    {Size size = const Size(1280, 800), Future<void> Function(WidgetTester tester)? before,
    List<ThemeCase> themes = themeMatrix}) {
  for (final theme in themes) {
    testWidgets('$name screenshot (${theme.label})', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      painting.debugDisableShadows = false;
      try {
        await tester.pumpWidget(build(theme));
        if (before != null) await before(tester);
        await tester.pump(const Duration(seconds: 1));
        await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screenshots/$name.${theme.label}.png'));
      } finally {
        painting.debugDisableShadows = true;
      }
    });
  }
}
