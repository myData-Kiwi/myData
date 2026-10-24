/// The theme preview harness (design/themes/ARCHITECTURE.md 5, phase 3½): any theme file, in any of its
/// palettes, drawn by the real apps on the same four screens at the same window size, light and dark, with
/// synthetic data, off-screen, into PNGs. One validator (the Dart one, `validateThemeText`) decides first;
/// a file it refuses is reported and never drawn.
///
/// Run it with `app/tool/preview_themes.sh` (`all`, a slug of design/themes or a theme file's path). The
/// steps, each a `flutter test` with `--dart-define`s:
///
/// 1. **Check** (mydata_ui's `test/theme/theme_preview_test.dart`, [themePreviewChecks]): each file through
///    the validator, both modes at normal and increased contrast, into `<out>/<slug>/check.txt`.
/// 2. **Screens** (each app's `test/theme_preview_test.dart`, [themePreview]): myContacts' people with a
///    contact open, myCalendar's month, myAssistant's chat with an approval card and myData's Settings,
///    Sources, inside the Mac window at [previewWindow], into `<out>/<slug>/<app>-<screen>.<palette>-<mode>.png`.
/// 3. **Sheets** ([themePreviewSheets]): one contact sheet per theme, `<out>/<slug>.png`, a row per palette
///    and mode and a column per app.
///
/// Without `MYDATA_PREVIEW` every step but a smoke test is skipped: each app draws Kiwi's file once into a
/// temporary folder, so the harness is exercised by every run of the suites.
library;

// A test helper package: it registers the file under test with the theme library as a test would.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import '../mydata_testing.dart';

/// The folder the harness writes to (`--dart-define=MYDATA_PREVIEW=<absolute folder>`); empty when it is off.
const previewFolder = String.fromEnvironment('MYDATA_PREVIEW');

/// Which themes (`MYDATA_PREVIEW_THEMES`): `all` (every folder of design/themes), or a comma-separated list
/// of slugs of design/themes and paths to theme files.
const previewThemesArg = String.fromEnvironment('MYDATA_PREVIEW_THEMES', defaultValue: 'all');

/// One palette's id (`MYDATA_PREVIEW_PALETTE`) instead of every palette; a theme without it is refused.
const previewPaletteArg = String.fromEnvironment('MYDATA_PREVIEW_PALETTE');

/// Also every case at increased contrast (`MYDATA_PREVIEW_CONTRAST=true`; [ThemeLibrary.debugIncreasedContrast]).
const previewContrastArg = bool.fromEnvironment('MYDATA_PREVIEW_CONTRAST');

/// Each app's other screens too, in each theme's default palette (`MYDATA_PREVIEW_ALL_SCREENS=true`).
const previewAllScreensArg = bool.fromEnvironment('MYDATA_PREVIEW_ALL_SCREENS');

/// Whether the apps' tests load the Mac's own system font ([loadMacFonts] with `systemFont`): in a preview
/// run, whose pictures are written outside the checkout (preview_themes.sh refuses a folder inside it), so
/// System is seen in SF Pro, as on a Mac. Committed screenshots keep the bundled Figtree.
const previewSystemFont = previewFolder != '';

/// The modes, in the sheet's order.
const previewModes = [Brightness.light, Brightness.dark];

/// The window every screen is drawn in: the same for every app, tall enough for myCalendar's month.
const previewWindow = Size(1280, 900);

/// The four apps, in the sheet's order, and the screen each shows first (its [themePreview] list's first).
const previewScreens = {
  'mycontacts': 'people',
  'mycalendar': 'month',
  'myassistant': 'approval',
  'mydata': 'settings',
};

/// The repo's root: the first folder up from the test's that has design/themes.
Directory get repoRoot {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/design/themes').existsSync()) {
    final up = dir.parent;
    if (up.path == dir.path) throw StateError('No design/themes above ${Directory.current.path}');
    dir = up;
  }
  return dir;
}

/// design/themes, where the built-ins' files are.
Directory get designThemes => Directory('${repoRoot.path}/design/themes');

/// One theme file as the harness sees it: where it is, its name in file names, and the validator's answer.
class PreviewTheme {
  PreviewTheme._(this.path, this.slug, this.builtIn, this.check, this.text);

  /// Reads and validates the file at [path]: as a built-in (its `mydata.` id allowed, every palette required
  /// to pass and to give every role) when it is in design/themes or its id is a built-in's, as a theme being
  /// ported is before it moves there; else as an imported theme would be.
  factory PreviewTheme.load(String path) {
    final file = File(path).absolute;
    final slug = _slugOf(file);
    var builtIn = file.parent.parent.path == designThemes.absolute.path;
    String? text;
    ThemeCheck check;
    try {
      text = file.readAsStringSync();
      builtIn = builtIn || _namesBuiltIn(text);
      check = validateThemeText(text, ThemeLibrary.format(), builtIn: builtIn);
    } on FileSystemException catch (e) {
      check = ThemeCheck(errors: ['The file cannot be read: ${e.osError?.message ?? e.message}.'], notices: const []);
    }
    return PreviewTheme._(file.path, slug, builtIn, check, text);
  }

  final String path;

  /// The theme's name in file and folder names: its folder's for a `theme.json`, else the file's.
  final String slug;
  final bool builtIn;
  final ThemeCheck check;
  final String? text;

  ThemeFile? get theme => check.theme;

  /// The palettes to draw: [previewPaletteArg] or every palette; one null (the accent) for System.
  List<String?> palettes({String palette = previewPaletteArg}) {
    final t = theme;
    if (t == null) return const [];
    if (t.palettes.isEmpty) return const [null];
    if (palette.isNotEmpty) return [if (t.palettes.any((p) => p.id == palette)) palette];
    return [for (final p in t.palettes) p.id];
  }

  /// Why the harness will not draw it: the validator's errors, a palette that fails, or a palette asked
  /// for that it lacks. Empty when it draws.
  List<String> refusals({String palette = previewPaletteArg}) => [
        ...check.errors,
        for (final p in check.palettes)
          for (final f in p.failures) 'Palette ${p.paletteId}: $f',
        if (theme != null && palette.isNotEmpty && theme!.palettes.isNotEmpty && palettes(palette: palette).isEmpty)
          'It has no palette "$palette" (it has ${theme!.palettes.map((p) => p.id).join(', ')}).',
      ];

  bool get draws => refusals().isEmpty;

  /// The check as `check.txt` gives it.
  String report({String palette = previewPaletteArg}) {
    final t = theme;
    final refused = refusals(palette: palette);
    return [
      'File: $path',
      if (t != null) 'Theme: ${t.name} (${t.id}), ${t.frame.key} frame${builtIn ? ', checked as a built-in' : ''}',
      'Verdict: ${refused.isEmpty ? 'passes' : 'refused'}',
      if (refused.isNotEmpty) ...['', 'Why:', for (final r in refused) '- $r'],
      if (check.palettes.isNotEmpty) ...[
        '',
        'Palettes (each in light and dark, at normal and increased contrast):',
        for (final p in check.palettes) '- ${p.paletteId}: ${p.passes ? 'passes' : '${p.failures.length} failing'}',
      ],
      // The validator lists each palette's notices here too, named by palette and mode.
      if (check.notices.isNotEmpty) ...['', 'Notices:', for (final n in check.notices) '- $n'],
      '',
    ].join('\n');
  }

  static bool _namesBuiltIn(String text) {
    try {
      return switch (jsonDecode(text)) {
        {'id': final String id} => id.startsWith('mydata.'),
        _ => false,
      };
    } on FormatException {
      return false;
    }
  }

  static String _slugOf(File file) {
    final name = file.uri.pathSegments.last;
    if (name == 'theme.json') return file.parent.uri.pathSegments.where((s) => s.isNotEmpty).last;
    return name.endsWith('.json') ? name.substring(0, name.length - 5) : name;
  }
}

/// The themes [arg] names ([previewThemesArg]), loaded and validated, built-ins in the gallery's order.
List<PreviewTheme> previewThemes({String arg = previewThemesArg}) {
  final paths = <String>[];
  for (final part in arg.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty)) {
    if (part == 'all') {
      final order = [for (final t in ThemeLibrary.builtIns) t.id.replaceFirst('mydata.', '')];
      final slugs = designThemes
          .listSync()
          .whereType<Directory>()
          .where((d) => File('${d.path}/theme.json').existsSync())
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort((a, b) {
          final ia = order.indexOf(a), ib = order.indexOf(b);
          if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
          if (ia >= 0 || ib >= 0) return ia >= 0 ? -1 : 1;
          return a.compareTo(b);
        });
      paths.addAll(slugs.map((s) => '${designThemes.path}/$s/theme.json'));
    } else if (!part.contains('/') && !part.endsWith('.json')) {
      paths.add('${designThemes.path}/$part/theme.json');
    } else {
      paths.add(part);
    }
  }
  final seen = <String>{};
  return [
    for (final p in paths)
      if (seen.add(File(p).absolute.path)) PreviewTheme.load(p),
  ];
}

/// One drawing's file name: `<app>-<screen>.<palette>-<mode>[-contrast].png` (no palette for System).
String previewFileName(String app, String screen, String? palette, Brightness brightness, {bool contrast = false}) =>
    '$app-$screen.${palette == null ? '' : '$palette-'}${brightness.name}${contrast ? '-contrast' : ''}.png';

/// Draws [screen] of [app] in [theme] ([palette], [brightness]) inside the Mac window at [previewWindow] and
/// writes it to [folder] as [previewFileName]. System is drawn with the Mac's own accent (no System
/// Settings colour is mocked), a drawn theme as the device's choice everywhere.
Future<File> shootPreview(WidgetTester tester, String app, ThemeScreen screen, PreviewTheme theme, String? palette,
    Brightness brightness, String folder,
    {bool contrast = false}) async {
  final file = theme.theme!;
  tester.view.physicalSize = previewWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ThemeLibrary.addForTesting(file);
  addTearDown(ThemeLibrary.clearForTesting);
  ThemeLibrary.debugIncreasedContrast = contrast;
  addTearDown(() => ThemeLibrary.debugIncreasedContrast = false);
  final macBefore = MacLook.debugOverride;
  MacLook.debugOverride = true;
  addTearDown(() => MacLook.debugOverride = macBefore);
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);

  final system = file.frame == ThemeFrame.system;
  final app_ = screen.build(ThemeCase(file.id, brightness, palette: palette, drawnOnMac: !system));
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // The app's builder sets the system's accent to its theme's for its own screenshots; System here is the
  // Mac's default (the channel answers nothing, so MacSystemPalette.fallback).
  if (system) messenger.setMockMethodCallHandler(MacSystemColorsScope.channel, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(MacSystemColorsScope.channel, null));

  painting.debugDisableShadows = false;
  Uint8List? png;
  try {
    await tester.pumpWidget(app_);
    if (screen.before != null) await screen.before!(tester);
    await tester.pump(const Duration(seconds: 1));
    final element = find.byType(MaterialApp).first.evaluate().single;
    png = await tester.runAsync(() async {
      final image = await captureImage(element);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
  } finally {
    painting.debugDisableShadows = true;
  }
  final out = File('$folder/${previewFileName(app, screen.name, palette, brightness, contrast: contrast)}');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(png!);
  return out;
}

/// The screens step for one app: [screens] in every theme [previewThemesArg] names that the validator
/// passes, each palette, light and dark (and at increased contrast with [previewContrastArg]). The first
/// screen is the app's in the sheet ([previewScreens]); the others are drawn with [previewAllScreensArg],
/// in each theme's default palette. A refused theme is skipped here: the check step reports it.
///
/// Off (no [previewFolder]): a smoke test draws Kiwi's file, light, into a temporary folder.
void themePreview(String app, List<ThemeScreen> screens) {
  assert(screens.first.name == previewScreens[app], '$app shows ${previewScreens[app]} first');
  if (previewFolder.isEmpty) {
    macTestWidgets('the preview harness draws $app from a theme file', (tester) async {
      final kiwi = PreviewTheme.load('${designThemes.path}/kiwi/theme.json');
      expect(kiwi.refusals(palette: ''), isEmpty);
      final dir = Directory.systemTemp.createTempSync('mydata-preview-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = await shootPreview(tester, app, screens.first, kiwi, 'kiwi', Brightness.light, dir.path);
      final size = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final frame = await codec.getNextFrame();
        final s = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
        codec.dispose();
        return s;
      });
      expect(size, previewWindow);
    });
    return;
  }
  for (final theme in previewThemes()) {
    if (!theme.draws) {
      test('preview: ${theme.slug}', () {}, skip: 'refused by the validator: see ${theme.slug}/check.txt');
      continue;
    }
    final palettes = theme.palettes();
    final first = theme.theme!.defaultPalette?.id;
    for (final palette in palettes) {
      final isDefault = palette == first || palettes.length == 1;
      for (final screen in previewAllScreensArg && isDefault ? screens : [screens.first]) {
        for (final b in previewModes) {
          for (final contrast in [false, if (previewContrastArg) true]) {
            macTestWidgets(
              'preview: ${theme.slug} ${palette ?? 'accent'} ${b.name}${contrast ? ' contrast' : ''} ${screen.name}',
              (tester) => shootPreview(tester, app, screen, theme, palette, b, '$previewFolder/${theme.slug}',
                  contrast: contrast),
            );
          }
        }
      }
    }
  }
}

/// The check step: each theme [previewThemesArg] names through the validator, its report written to
/// `<out>/<slug>/check.txt`; a theme refused fails its test with the reasons.
void themePreviewChecks() {
  group('theme preview: check', skip: previewFolder.isEmpty ? 'only with --dart-define=MYDATA_PREVIEW=<folder>' : null,
      () {
    for (final theme in previewThemes()) {
      test('${theme.slug} passes the validator', () {
        final report = File('$previewFolder/${theme.slug}/check.txt');
        report.parent.createSync(recursive: true);
        report.writeAsStringSync(theme.report());
        expect(theme.refusals(), isEmpty, reason: theme.report());
      });
    }
  });
}

/// The sheets step: one contact sheet per theme the validator passed, `<out>/<slug>.png`, from the
/// screens step's PNGs. A drawing that is missing is a grey box, and fails the test.
void themePreviewSheets() {
  group('theme preview: sheets', skip: previewFolder.isEmpty ? 'only with --dart-define=MYDATA_PREVIEW=<folder>' : null,
      () {
    final themes = previewThemes().where((t) => t.draws).toList();
    // So that a run where the validator refused every theme still has a test here, and says why.
    if (themes.isEmpty) test('no sheet', () {}, skip: 'the validator refused every theme: see check.txt');
    for (final theme in themes) {
      testWidgets('${theme.slug} on one sheet', (tester) async {
        final t = theme.theme!;
        final rows = <PreviewRow>[
          for (final palette in theme.palettes())
            for (final b in previewModes)
              for (final contrast in [false, if (previewContrastArg) true])
                PreviewRow(
                  '${palette == null ? 'Mac accent' : t.palette(palette)!.name}, ${b.name}${contrast ? ', increased contrast' : ''}',
                  [
                    for (final e in previewScreens.entries)
                      '$previewFolder/${theme.slug}/${previewFileName(e.key, e.value, palette, b, contrast: contrast)}',
                  ],
                ),
        ];
        final title = '${t.name} (${t.id})  ·  ${theme.builtIn ? 'design/themes/${theme.slug}' : theme.path}'
            '  ·  validator: passes${theme.check.notices.isEmpty ? '' : ', ${theme.check.notices.length} notices'}';
        final missing = await tester.runAsync(
            () => composePreviewSheet(title, [...previewScreens.keys], rows, '$previewFolder/${theme.slug}.png'));
        expect(missing, isEmpty, reason: 'not drawn by the screens step');
      });
    }
  });
}

/// One row of a contact sheet: its label and one PNG per column.
class PreviewRow {
  const PreviewRow(this.label, this.files);
  final String label;
  final List<String> files;
}

/// Writes a contact sheet to [out]: [title], [columns] as headings, then each of [rows] scaled to
/// [thumbWidth] per picture. Returns the files that were missing (drawn as empty boxes). Run it in
/// `tester.runAsync`.
Future<List<String>> composePreviewSheet(String title, List<String> columns, List<PreviewRow> rows, String out,
    {double thumbWidth = 480}) async {
  final colours = kiwiLook.colors;
  const pad = 16.0, labelHeight = 28.0, titleHeight = 40.0;
  final scale = thumbWidth / previewWindow.width;
  final thumbHeight = previewWindow.height * scale;
  final width = pad + columns.length * (thumbWidth + pad);
  final height = titleHeight + labelHeight + rows.length * (labelHeight + thumbHeight + pad) + pad;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = colours.surfaceSunken);

  void text(String s, Offset at, {double size = 14, bool strong = false, double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: MyDataFontFamily.body,
          package: MyDataFontFamily.package,
          fontSize: size,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
          color: strong ? colours.ink : colours.inkMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? width - 2 * pad);
    painter.paint(canvas, at);
    painter.dispose();
  }

  text(title, const Offset(pad, 12), size: 16, strong: true);
  for (var c = 0; c < columns.length; c++) {
    text(columns[c], Offset(pad + c * (thumbWidth + pad), titleHeight + 4), strong: true, maxWidth: thumbWidth);
  }
  final missing = <String>[];
  var y = titleHeight + labelHeight;
  for (final row in rows) {
    text(row.label, Offset(pad, y + 6));
    y += labelHeight;
    for (var c = 0; c < row.files.length; c++) {
      final rect = Rect.fromLTWH(pad + c * (thumbWidth + pad), y, thumbWidth, thumbHeight);
      final f = File(row.files[c]);
      if (!f.existsSync()) {
        missing.add(row.files[c]);
        canvas.drawRect(rect, Paint()..color = colours.line);
        continue;
      }
      final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
      final image = (await codec.getNextFrame()).image;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.drawRect(rect, Paint()
        ..style = PaintingStyle.stroke
        ..color = colours.lineStrong);
      image.dispose();
      codec.dispose();
    }
    y += thumbHeight + pad;
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.ceil(), math.max(1, height.ceil()));
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(data!.buffer.asUint8List());
  return missing;
}
