// The theme preview harness's check and sheet steps (mydata_testing's theme_preview.dart;
// app/tool/preview_themes.sh), and the tests that keep the harness itself working in every run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  group('the preview harness', () {
    test('reads every theme in design/themes, the built-ins in the gallery order, and passes each', () {
      final themes = previewThemes(arg: 'all');
      expect([for (final t in themes) t.theme?.id].take(ThemeLibrary.builtIns.length),
          [for (final t in ThemeLibrary.builtIns) t.id]);
      for (final t in themes) {
        expect(t.builtIn, isTrue, reason: t.slug);
        expect(t.refusals(palette: ''), isEmpty, reason: t.report(palette: ''));
        expect(t.report(palette: ''), contains('Verdict: passes'));
      }
    });

    test('names a theme by its slug or its path, once each', () {
      final kiwi = '${designThemes.path}/kiwi/theme.json';
      final themes = previewThemes(arg: 'kiwi, $kiwi,system');
      expect([for (final t in themes) t.slug], ['kiwi', 'system']);
      expect(themes.first.palettes(palette: ''), ['kiwi', 'sky', 'violet']);
      expect(themes.first.palettes(palette: 'sky'), ['sky']);
      expect(themes.last.palettes(palette: ''), [null], reason: 'System draws the Mac accent, no palette');
    });

    test('refuses a file the validator refuses, a palette that fails and a palette it lacks, saying why', () {
      final dir = Directory.systemTemp.createTempSync('mydata-preview-');
      addTearDown(() => dir.deleteSync(recursive: true));

      // A prototype from before palettes: its colours at the top level.
      final old = File('${dir.path}/old/theme.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"format": 1, "id": "7f3c2a9e-5b1d-4c8e-9a2f-000000000002", "name": "Old", "version": "1.0.0", '
            '"licence": "CC0-1.0", "frame": "drawn", "colours": {"light": {}, "dark": {}}}');
      final refused = PreviewTheme.load(old.path);
      expect(refused.slug, 'old');
      expect(refused.builtIn, isFalse);
      expect(refused.draws, isFalse);
      expect(refused.report(palette: ''), contains('Verdict: refused'));

      // Kiwi with its default palette's muted text made unreadable.
      final kiwi = File('${designThemes.path}/kiwi/theme.json').readAsStringSync();
      final faint = File('${dir.path}/faint.json')..writeAsStringSync(kiwi.replaceFirst('"mydata.kiwi"', '"7f3c2a9e-5b1d-4c8e-9a2f-000000000001"'));
      final json = faint.readAsStringSync();
      final light = json.indexOf('"ink-muted"');
      expect(light, isNonNegative);
      final end = json.indexOf(',', light);
      faint.writeAsStringSync('${json.substring(0, light)}"ink-muted": "#F2F2F2"${json.substring(end)}');
      final failing = PreviewTheme.load(faint.path);
      expect(failing.slug, 'faint');
      expect(failing.refusals(palette: ''), contains(startsWith('Palette kiwi: ')));

      // A built-in's id outside design/themes (a theme being ported) is checked as a built-in.
      final copy = File('${dir.path}/draft/theme.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(kiwi);
      final draft = PreviewTheme.load(copy.path);
      expect(draft.builtIn, isTrue);
      expect(draft.draws, isTrue);

      final missing = PreviewTheme.load('${designThemes.path}/kiwi/theme.json');
      expect(missing.refusals(palette: 'plum'), [contains('no palette "plum"')]);

      expect(PreviewTheme.load('${dir.path}/none.json').refusals(palette: ''), [startsWith('The file cannot be read')]);
    });

    test('a theme added for testing is drawn in place of the built-in with its id', () {
      addTearDown(ThemeLibrary.clearForTesting);
      final file = PreviewTheme.load('${designThemes.path}/hairline/theme.json').theme!;
      expect(identical(ThemeLibrary.byId('mydata.hairline'), file), isFalse);
      ThemeLibrary.addForTesting(file);
      expect(identical(ThemeLibrary.byId('mydata.hairline'), file), isTrue);
    });

    test('increased contrast for every look, as --contrast asks', () {
      addTearDown(() => ThemeLibrary.debugIncreasedContrast = false);
      const choice = ThemeChoice('mydata.kiwi', 'kiwi');
      final normal = ThemeLibrary.lookFor(choice, Brightness.light);
      ThemeLibrary.debugIncreasedContrast = true;
      final more = ThemeLibrary.lookFor(choice, Brightness.light);
      expect(more.increasedContrast, isTrue);
      expect(normal.increasedContrast, isFalse);
      expect(more.colors.inkMuted, isNot(normal.colors.inkMuted));
    });

    testWidgets('puts each row of drawings on one sheet, and lists the drawings that are missing', (tester) async {
      final dir = Directory.systemTemp.createTempSync('mydata-preview-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final png = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(Offset.zero & previewWindow, Paint()..color = kiwiLook.colors.accent);
        final image = await recorder.endRecording().toImage(previewWindow.width.toInt(), previewWindow.height.toInt());
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final drawn = File('${dir.path}/a.png')..writeAsBytesSync(png!);
      final missing = await tester.runAsync(() => composePreviewSheet(
            'Test',
            ['one', 'two'],
            [
              PreviewRow('light', [drawn.path, '${dir.path}/b.png']),
              PreviewRow('dark', [drawn.path, drawn.path]),
            ],
            '${dir.path}/sheet.png',
            thumbWidth: 160,
          ));
      expect(missing, ['${dir.path}/b.png']);
      final size = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(File('${dir.path}/sheet.png').readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        final s = Size(image.width.toDouble(), image.height.toDouble());
        image.dispose();
        codec.dispose();
        return s;
      });
      // Two columns of 160 with 16 between and around; a title, the headings, and two rows of 160 x 900/1280.
      expect(size!.width, 16 + 2 * (160 + 16));
      expect(size.height, (40 + 28 + 2 * (28 + 160 * 900 / 1280 + 16) + 16).ceilToDouble());
    });
  });

  // `app/tool/preview_themes.sh` runs these with --dart-define=MYDATA_PREVIEW=<folder>.
  themePreviewChecks();
  themePreviewSheets();
}
