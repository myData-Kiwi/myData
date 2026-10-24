/// Test helpers for the myData packages and apps. Dev dependency only.
///
/// - [loadMyDataFonts]: render the bundled fonts (and Material icons) in widget and golden tests instead of
///   Flutter's test font. Call it from each package's test/flutter_test_config.dart.
/// - [themeMatrix] and [goldenMatrix]: one golden per theme and mode (Kiwi and Hairline, light and dark).
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

/// Loads the bundled fonts under the names Flutter gives package fonts (the core three, every theme font the
/// catalogue bundles, as the apps load them on demand, and every icon set), and Material Icons when the package under test
/// bundles them.
Future<void> loadMyDataFonts() async {
  await ThemeFonts.ensureAll();
  // The icon sets, as the pubspec declares them (the engine registers them in an app; tests load them).
  for (final family in iconFontFamilies) {
    await (FontLoader('packages/${MyDataFontFamily.package}/$family')
          ..addFont(rootBundle.load('packages/${MyDataFontFamily.package}/assets/fonts/$family-subset.ttf')))
        .load();
  }
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

/// Loads the Mac frame's fonts: Lucide (bundled in mydata_ui; [loadMyDataFonts] loads it too) and a font under the names Flutter's macOS
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

/// Kiwi's look in its own colour, light: what the widgets' static measures (`Card.gap`) are in a
/// test that has no BuildContext at hand. Spacing, sizes, radii and type do not change with the colour or
/// the mode, so it serves goldens in every theme.
final kiwiLook = MyDataLook.fallback(Brightness.light);

/// Kiwi with its `label` and `caption` roles set in upper case (`case: upper`, as the Terminal port sets
/// labels): for tests that a widget's own labels follow the theme's case and names keep theirs.
MyDataLook upperCaseLook(Brightness brightness) {
  final look = MyDataLook.fallback(brightness);
  final t = look.typeScale;
  return look.copyWith(
    typeScale: MyDataTypeScale(
      displayXl: t.displayXl,
      displayLg: t.displayLg,
      title: t.title,
      heading: t.heading,
      body: t.body,
      bodyStrong: t.bodyStrong,
      label: t.label,
      caption: t.caption,
      mono: t.mono,
      upper: const {MyDataTypeRole.label, MyDataTypeRole.caption},
    ),
  );
}

/// [icon]'s glyph as Kiwi and System draw it (Lucide, in both the branded frame and the Mac frame): for a
/// finder or a comparison with an [Icon]'s `icon`.
IconData iconOf(MyDataIcon icon, {bool selected = false}) => kiwiLook.icons(icon, selected: selected);

/// Finds the [Icon]s that draw [icon] as Kiwi and System do ([iconOf]).
Finder findIcon(MyDataIcon icon) => find.byIcon(iconOf(icon));

/// For test/flutter_test_config.dart:
/// `Future<void> testExecutable(FutureOr<void> Function() main) => myDataTestExecutable(main);`
///
/// Flutter tests run as Android unless a test says otherwise, so the theme's density floor is held at the
/// desktop's 24 ([MyDataDensity.debugFloor]): the shared goldens show each theme's own sizes, and Android's
/// 48 and iOS's 44 are tested on their own (mydata_ui's look_test).
Future<void> myDataTestExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  MyDataDensity.debugFloor = MyDataDensity.desktopFloor;
  await loadMyDataFonts();
  await testMain();
}

/// A decoration read back as the BoxDecoration a widget built it from: `context.radius.decorate` turns a box
/// into a ShapeDecoration where the look's corners are continuous or cut (Kiwi's are continuous), so tests
/// that check a fill, radius, border or shadow read it through [box].
extension DecorationAsBox on Decoration? {
  /// Whether this is a box, or the ShapeDecoration `decorate` made of one.
  bool get isBox {
    final d = this;
    return d is BoxDecoration ||
        d is ShapeDecoration &&
            (d.shape is RoundedSuperellipseBorder ||
                d.shape is RoundedRectangleBorder ||
                d.shape is BeveledRectangleBorder);
  }

  BoxDecoration get box {
    final d = this;
    if (d is BoxDecoration) return d;
    if (d is ShapeDecoration) {
      final (radius, side) = switch (d.shape) {
        RoundedSuperellipseBorder(:final borderRadius, :final side) => (borderRadius, side),
        RoundedRectangleBorder(:final borderRadius, :final side) => (borderRadius, side),
        BeveledRectangleBorder(:final borderRadius, :final side) => (borderRadius, side),
        final other => throw StateError('$other is not a rounded box'),
      };
      return BoxDecoration(
        color: d.color,
        gradient: d.gradient,
        image: d.image,
        boxShadow: d.shadows,
        borderRadius: radius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
      );
    }
    throw StateError('$d is not a box');
  }
}

/// One theme and mode to render a golden in.
///
/// [themeId] names it in file names and says which theme it draws ([MyDataTheme.choiceNamed]): a built-in's
/// slug (`hairline`, in its default palette unless [palette] says), or one of today's old colours, which the
/// Mac frame's tests use as the accent set in System Settings (`graphite` draws Hairline in Graphite off the
/// Mac shell).
class ThemeCase {
  const ThemeCase(this.themeId, this.brightness, {this.palette});
  final String themeId;
  final Brightness brightness;
  final String? palette;
  String get label => palette == null ? '$themeId-${brightness.name}' : '$themeId-$palette-${brightness.name}';

  /// The theme and palette this case draws.
  ThemeChoice get choice {
    final c = MyDataTheme.choiceNamed(themeId);
    return palette == null ? c : ThemeChoice(c.theme, palette);
  }

  ThemeData get data => MyDataTheme.dataFor(choice, brightness);

  /// A device's settings that draw this case in every app: its mode, and its theme everywhere.
  Map<String, Object?> get deviceSettings => {
        'mode': brightness.name,
        'themes': {'everywhere': choice.toJson()},
      };
}

/// The four combinations every widget golden and screenshot is made in: Kiwi, the house style, and
/// Hairline, the quietest of the drawn looks, in light and dark.
const themeMatrix = [
  ThemeCase('kiwi', Brightness.light),
  ThemeCase('kiwi', Brightness.dark),
  ThemeCase('hairline', Brightness.light),
  ThemeCase('hairline', Brightness.dark),
];

/// The six drawn built-ins, by slug, in the gallery's order.
const drawnThemes = ['kiwi', 'hairline', 'frosted', 'journal', 'sticker', 'paperback'];

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
      // As every app: a theme change is one rebuild, never a lerp through in-between looks.
      themeAnimationDuration: MyDataTheme.switchDuration,
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

/// The Mac frame's tests run as macOS: `defaultTargetPlatform` and the theme's platform are macOS, so the
/// keys are ⌘ and the menus write "⌘E" and "⌘⌫", as on a Mac (set for the test and reset after it).
final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

/// A widget test of the Mac frame, run as macOS ([macOS]).
void macTestWidgets(String description, WidgetTesterCallback callback, {bool? skip}) =>
    testWidgets(description, callback, variant: macOS, skip: skip);

/// [screenMatrix] for the Mac frame: run as macOS ([macOS]), in [macMatrix] unless [themes] says.
void macScreenMatrix(String name, Widget Function(ThemeCase theme) build,
        {Size size = const Size(1280, 800), Future<void> Function(WidgetTester tester)? before,
        List<ThemeCase> themes = macMatrix}) =>
    screenMatrix(name, build, size: size, before: before, themes: themes, variant: macOS);

/// Defines one screenshot test per [themes] case (every [themeMatrix] case unless given) for a whole app
/// screen: [build] gets the theme case and returns the app (its own MaterialApp, themed with `theme.data`),
/// rendered at [size] into `screenshots/<name>.<theme>-<mode>.png`. Run with --update-goldens to refresh them.
/// [variant]: the platform to run as ([macOS] for the Mac frame).
void screenMatrix(String name, Widget Function(ThemeCase theme) build,
    {Size size = const Size(1280, 800), Future<void> Function(WidgetTester tester)? before,
    List<ThemeCase> themes = themeMatrix, TestVariant<Object?> variant = const DefaultTestVariant()}) {
  for (final theme in themes) {
    testWidgets('$name screenshot (${theme.label})', variant: variant, (tester) async {
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
