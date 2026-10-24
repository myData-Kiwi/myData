/// Test helpers for the myData packages and apps. Dev dependency only.
///
/// - [loadMyDataFonts]: render the bundled fonts (and Material icons) in widget and golden tests instead of
///   Flutter's test font. Call it from each package's test/flutter_test_config.dart.
/// - [themeMatrix] and [goldenMatrix]: one golden per theme and mode (Kiwi and Hairline, light and dark).
/// - [loadMacFonts] and [macMatrix]: the Mac frame's fonts (the system font, Lucide) and its two appearances.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

export 'src/theme_preview.dart';

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
///
/// In the Mac frame's tests a case is System with its accent set in System Settings, unless [drawnOnMac]: then
/// the device has chosen the theme itself, and the Mac window draws it inside ([macThemes]).
class ThemeCase {
  const ThemeCase(this.themeId, this.brightness, {this.palette, this.drawnOnMac = false});
  final String themeId;
  final Brightness brightness;
  final String? palette;
  final bool drawnOnMac;
  String get label => palette == null ? '$themeId-${brightness.name}' : '$themeId-$palette-${brightness.name}';

  /// The theme and palette this case draws.
  ThemeChoice get choice {
    final c = MyDataTheme.choiceNamed(themeId);
    return palette == null ? c : ThemeChoice(c.theme, palette);
  }

  ThemeData get data => MyDataTheme.dataFor(choice, brightness);

  /// What a Mac frame test adds to the device's settings: this case's theme everywhere when [drawnOnMac],
  /// else nothing (the Mac shell draws System).
  Map<String, Object?> get macThemes => drawnOnMac
      ? {
          'themes': {'everywhere': choice.toJson()},
        }
      : const {};

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

/// The drawn built-ins (every built-in but System), by slug, in the gallery's order.
final drawnThemes = [for (final t in ThemeLibrary.builtIns.skip(1)) t.id.replaceFirst('mydata.', '')];

/// Each drawn built-in in its default palette, light and dark, drawn in the Mac window.
final drawnMacMatrix = [
  for (final slug in drawnThemes)
    for (final b in Brightness.values) ThemeCase(slug, b, drawnOnMac: true),
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

/// One of an app's screens for the theme screenshots ([themeScreens]) and the preview harness ([themePreview]).
class ThemeScreen {
  const ThemeScreen(this.name, this.build, {this.before});

  /// Its name in file names (`people`).
  final String name;

  /// The app in a case's theme and mode, on this screen's data.
  final Widget Function(ThemeCase theme) build;

  /// What to do before the picture (open a tab, wait for the data).
  final Future<void> Function(WidgetTester tester)? before;
}

/// The app's key screen in each drawn built-in's default palette, inside the Mac window, light and dark, as
/// goldens (design/themes/ARCHITECTURE.md 5, phase 3: every theme on an app scene in both modes):
/// `screenshots/theme_<screen>.<theme>-<mode>.png` (12 per app). Pictures of every theme file and palette for
/// review come from the preview harness ([themePreview], `app/tool/preview_themes.sh`).
void themeScreens(ThemeScreen key, {Size size = const Size(1280, 800)}) {
  Future<void> shoot(WidgetTester tester, ThemeScreen screen, ThemeCase theme, String file) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    painting.debugDisableShadows = false;
    try {
      await tester.pumpWidget(screen.build(theme));
      if (screen.before != null) await screen.before!(tester);
      await tester.pump(const Duration(seconds: 1));
      await expectLater(find.byType(MaterialApp).first, matchesGoldenFile(file));
    } finally {
      painting.debugDisableShadows = true;
    }
  }

  bool? macBefore;
  setUp(() {
    macBefore = MacLook.debugOverride;
    MacLook.debugOverride = true;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() {
    MacLook.debugOverride = macBefore;
    EditableText.debugDeterministicCursor = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacSystemColorsScope.channel, null);
  });

  for (final theme in drawnMacMatrix) {
    macTestWidgets('theme screenshot: ${key.name} (${theme.label})',
        (tester) => shoot(tester, key, theme, 'screenshots/theme_${key.name}.${theme.label}.png'));
  }
}

/// [key] in the largest-type and the edge-heaviest themes (Large, High Contrast; light) in the Mac window at
/// its smallest, 720 by 480 (MacShell.swift's minimum): nothing overflows, as golden
/// `screenshots/theme_<screen>.<theme>-narrow.png`. The 1280-wide pictures above never showed what Large's
/// wider sidebar and 19 px text leave room for.
void themeNarrow(ThemeScreen key, {List<String> slugs = const ['large', 'high-contrast'], Size size = macMinSize}) {
  for (final slug in slugs) {
    macTestWidgets('${key.name} at the smallest window in $slug', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final before = MacLook.debugOverride;
      MacLook.debugOverride = true;
      addTearDown(() => MacLook.debugOverride = before);
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      painting.debugDisableShadows = false;
      try {
        await tester.pumpWidget(key.build(ThemeCase(slug, Brightness.light, drawnOnMac: true)));
        if (key.before != null) await key.before!(tester);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: 'nothing overflows at ${size.width}x${size.height}');
        await expectLater(find.byType(MaterialApp).first, matchesGoldenFile('screenshots/theme_${key.name}.$slug-narrow.png'));
      } finally {
        painting.debugDisableShadows = true;
      }
    });
  }
}

/// The Mac windows' smallest size (MacShell.swift's `minSize`).
const macMinSize = Size(720, 480);

/// Every control a pointer can press on [key] in the theme [slug] (inside the Mac window, light) is at least
/// [least] by [least]: its accessible node's box, which is the area that takes the press (a search field's
/// whole box). Large promises 52 px targets on the desktop (design/themes/large/RULES.md); the density tokens
/// alone did not reach the Mac widgets. A link inside a line of text is exempt, as WCAG 2.5.5 exempts it.
void themeTargets(ThemeScreen key, {String slug = 'large', double least = 52, Size size = const Size(1280, 800)}) {
  macTestWidgets('every target on ${key.name} is $least px or more in $slug', (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final before = MacLook.debugOverride;
    MacLook.debugOverride = true;
    addTearDown(() => MacLook.debugOverride = before);
    final semantics = tester.ensureSemantics();
    try {
      await _checkTargets(tester, key, slug: slug, least: least, size: size);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _checkTargets(
  WidgetTester tester,
  ThemeScreen key, {
  required String slug,
  required double least,
  required Size size,
}) async {
  await tester.pumpWidget(key.build(ThemeCase(slug, Brightness.light, drawnOnMac: true)));
  if (key.before != null) await key.before!(tester);
  await tester.pump(const Duration(seconds: 1));
  final small = <String>[];
  void visit(SemanticsNode node, Matrix4 transform) {
    final t = node.transform == null ? transform : (transform.clone()..multiply(node.transform!));
    final data = node.getSemanticsData();
    final f = data.flagsCollection;
    final pressable =
        (data.hasAction(SemanticsAction.tap) ||
            f.isButton ||
            f.isToggled != ui.Tristate.none ||
            f.isChecked != ui.CheckedState.none) &&
        !f.isHidden;
    // A text field is measured by its control's box below: its own node is its line of text.
    if (pressable && !f.isLink && !f.isTextField && !node.isMergedIntoParent) {
      final r = MatrixUtils.transformRect(t, node.rect);
      // Only what is on screen: a list's rows below the window are not drawn.
      final shown = r.intersect(Offset.zero & size);
      if (!shown.isEmpty && shown == r && (r.width < least - 0.5 || r.height < least - 0.5)) {
        small.add('"${data.label.isEmpty ? data.tooltip : data.label}" ${r.width.round()}x${r.height.round()}');
      }
    }
    node.visitChildren((c) {
      visit(c, t);
      return true;
    });
  }

  final roots = {for (final view in tester.binding.renderViews) ?view.owner?.semanticsOwner?.rootSemanticsNode};
  expect(roots, isNotEmpty);
  for (final root in roots) {
    visit(root, Matrix4.identity());
  }
  for (final field in tester.widgetList<MacSearchField>(find.byType(MacSearchField))) {
    final box = tester.getSize(find.byWidget(field));
    if (box.height < least - 0.5) small.add('the search field ${box.width.round()}x${box.height.round()}');
  }
  expect(small, isEmpty, reason: 'targets under $least px in $slug');
}

/// How far apart two pictures of one screen are in their shapes, not their colours (a drawn theme against
/// another): each picture becomes a map of its edges (a pixel whose lightness differs from its right or
/// lower neighbour's by more than [edgeStep]), counted in [edgeBlock]-pixel blocks; the score is the sum of
/// the blocks' differences over the sum of their counts, from 0 (the same shapes) to 1 (none shared).
/// Colour alone hardly moves it: one theme's palettes score 0.00 to 0.02 against each other on myContacts'
/// people (measured 2026-10-24, all 18 palettes), while another type, density, corner style, selection or
/// rule moves the edges. A text blur of a pixel or two stays inside its block.
double shapeDifference(ByteData a, ByteData b, Size size) {
  final w = size.width.toInt(), h = size.height.toInt();
  final bw = w ~/ edgeBlock, bh = h ~/ edgeBlock;
  List<int> blocks(ByteData d) {
    double lum(int x, int y) {
      final i = (y * w + x) * 4;
      return 0.2126 * d.getUint8(i) + 0.7152 * d.getUint8(i + 1) + 0.0722 * d.getUint8(i + 2);
    }

    final counts = List<int>.filled(bw * bh, 0);
    for (var y = 0; y < bh * edgeBlock; y++) {
      for (var x = 0; x < bw * edgeBlock; x++) {
        if (x + 1 >= w || y + 1 >= h) continue;
        final l = lum(x, y);
        if ((l - lum(x + 1, y)).abs() > edgeStep || (l - lum(x, y + 1)).abs() > edgeStep) {
          counts[(y ~/ edgeBlock) * bw + x ~/ edgeBlock]++;
        }
      }
    }
    return counts;
  }

  final ba = blocks(a), bb = blocks(b);
  var differ = 0, total = 0;
  for (var i = 0; i < ba.length; i++) {
    differ += (ba[i] - bb[i]).abs();
    total += ba[i] + bb[i];
  }
  return total == 0 ? 0 : differ / total;
}

/// The step in lightness (0 to 255) that counts as an edge in [shapeDifference].
const edgeStep = 24.0;

/// The side of the blocks [shapeDifference] counts edges in.
const edgeBlock = 16;

/// How far under its measured score a pair [themesDistinct] lets through may drift: a picture's small
/// changes (a line of text, a mark's shape) move a score by a hundredth or so.
const alikeSlack = 0.02;

/// Checks that the theme screenshots of [screen] ([themeScreens]' goldens, light mode) of every pair of
/// drawn themes differ by more than colour: a [shapeDifference] of at least [least]. A drawn theme in the
/// Mac window is its whole look, not the Mac's widgets in its colours (design/themes/ARCHITECTURE.md 3.4);
/// before that was built Kiwi and Hairline scored 0.22 on myContacts' people. It reads the goldens the theme
/// screens test keeps up to date, so it runs after them.
///
/// [alike] names pairs (`'notebook and paperback'`, in either order) that may score under [least] on this
/// screen, each with the score it was measured at and the reason the metric cannot see what sets them apart
/// (a ruled ground fainter than [edgeStep], a handwritten face where the other sets a serif): an exception
/// said out loud, never a lower bar for all. It has a floor: the pair fails when it drifts more than
/// [alikeSlack] under its measured score, and when it clears [least] (the exception is then stale and goes).
/// A key that names no pair of drawn themes fails too.
void themesDistinct(String screen,
    {double least = 0.3, Size size = const Size(1280, 800), Map<String, (double, String)> alike = const {}}) {
  testWidgets('every pair of drawn themes draws $screen in more than its colours', (tester) async {
    final pictures = <String, ByteData>{};
    for (final slug in drawnThemes) {
      final bytes = File('test/screenshots/theme_$screen.$slug-light.png').readAsBytesSync();
      pictures[slug] = (await tester.runAsync<ByteData?>(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        frame.image.dispose();
        codec.dispose();
        return data;
      }))!;
    }
    final scores = <String, double>{
      for (var i = 0; i < drawnThemes.length; i++)
        for (var j = i + 1; j < drawnThemes.length; j++)
          themePair(drawnThemes[i], drawnThemes[j]):
              shapeDifference(pictures[drawnThemes[i]]!, pictures[drawnThemes[j]]!, size),
    };
    expect(distinctProblems(scores, least: least, alike: alike, themes: drawnThemes), isEmpty,
        reason: 'these draw $screen in little more than their colours, or their exception is off');
  });
}

/// Two themes' pair as [themesDistinct] names it: their slugs in alphabetical order (`notebook and paperback`).
String themePair(String a, String b) => ([a, b]..sort()).join(' and ');

/// What [themesDistinct] fails on, given every pair's [scores] (keyed by [themePair]): a pair under [least]
/// that [alike] does not name; a pair it names that is more than [alikeSlack] under the score it was measured
/// at, or that clears [least] now (a stale exception); and a key of [alike] that names no pair of [themes].
List<String> distinctProblems(Map<String, double> scores,
    {required double least, required Map<String, (double, String)> alike, required List<String> themes}) {
  final problems = <String>[];
  final allowed = <String, double>{};
  for (final e in alike.entries) {
    final slugs = e.key.split(' and ');
    if (slugs.length != 2 || slugs[0] == slugs[1] || !slugs.every(themes.contains)) {
      problems.add('"${e.key}" names no pair of drawn themes');
    } else {
      allowed[themePair(slugs[0], slugs[1])] = e.value.$1;
    }
  }
  for (final e in scores.entries) {
    final score = allowed[e.key];
    final shown = e.value.toStringAsFixed(2);
    if (score == null) {
      if (e.value < least) problems.add('${e.key}: $shown');
    } else if (e.value < score - alikeSlack) {
      problems.add('${e.key}: $shown, under the ${score.toStringAsFixed(2)} its exception was measured at');
    } else if (e.value >= least) {
      problems.add('${e.key}: $shown clears $least now; drop its exception');
    }
  }
  return problems;
}
