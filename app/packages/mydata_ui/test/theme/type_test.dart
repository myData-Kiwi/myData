// A theme's type (design/themes/ARCHITECTURE.md 1.2 `type`, 1.5 and 2.3): each role in the theme's own font
// at its own weight, figures, italic secondary text and upper case where allowed; one golden per type of the
// six built-ins, in light and dark.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/catalogue.dart';
import 'package:mydata_ui/src/theme/strict_json.dart';
import 'package:mydata_ui/src/theme/theme_file.dart';

import 'designed_themes.dart';

TypeSpec _spec({
  List<String> display = const ['fredoka', 'nunito', 'sans'],
  List<String> body = const ['inter', 'sans'],
  List<String> mono = const ['mono'],
  bool tabular = false,
  bool italic = false,
  Map<TypeRole, TypeRoleSpec> roles = const {},
}) =>
    TypeSpec(
      display: display,
      body: body,
      mono: mono,
      base: 15,
      ratio: 1.2,
      tabular: tabular,
      secondaryItalic: italic,
      roles: {
        for (final r in TypeRole.values)
          r: roles[r] ?? TypeRoleSpec(size: r == TypeRole.displayXl ? 40 : 13, lineHeight: 1.4, weight: 400, stack: r.defaultStack),
      },
    );

/// One look's type, every role once, on its ground: what a type golden shows.
class TypeSpecimen extends StatelessWidget {
  const TypeSpecimen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.typeScale;
    final c = context.colors;
    Widget line(MyDataTypeRole role, String text, {Color? colour}) => Padding(
          padding: EdgeInsets.only(bottom: context.space(1)),
          child: Text(t.cased(role, text), style: t(role).copyWith(color: colour ?? c.ink)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(MyDataTypeRole.displayXl, 'Ava Fictional'),
        line(MyDataTypeRole.displayLg, 'Thursday 14 October'),
        line(MyDataTypeRole.title, 'Merge 2 contacts?'),
        line(MyDataTypeRole.heading, 'After merging'),
        line(MyDataTypeRole.body, 'Lunch with Ava at the café, 12:30 to 13:45. Łódź, Dvořák, Ærøskøbing.'),
        // Names a font may lack (fonts_test.dart, acceptedGaps) and the keys menus write.
        line(MyDataTypeRole.bodyStrong, 'Ștefan Erdős · Nguyễn · O’Brien · ⌘⇧E'),
        line(MyDataTypeRole.bodyStrong, 'Restore 3 contacts'),
        line(MyDataTypeRole.label, 'Email'),
        Text('ava@example.org, added 11 Oct 2026', style: t.secondary(t.body).copyWith(color: c.inkMuted)),
        line(MyDataTypeRole.caption, '1,234 contacts · 11:11 · 0123456789', colour: c.inkMuted),
        line(MyDataTypeRole.mono, '~/Library/Application Support/myData'),
      ],
    );
  }
}

void main() {
  test('a role is set in the first bundled font of its stack, the later ones as fallbacks', () {
    final scale = MyDataTypeScale.of(_spec(), platform: TargetPlatform.macOS);
    // Fredoka is display-only: at 40 px it is used, at 13 px the next font is.
    expect(scale.displayXl.fontFamily, 'packages/mydata_ui/Fredoka');
    expect(scale.displayXl.fontFamilyFallback, ['packages/mydata_ui/Nunito']);
    expect(scale.title.fontFamily, 'packages/mydata_ui/Nunito');
    expect(scale.body.fontFamily, 'packages/mydata_ui/Inter');
    expect(scale.body.fontFamilyFallback, isNull, reason: 'a generic ends the stack');
  });

  test('a generic is the platform\'s own font, a generic mono its monospace', () {
    final mac = MyDataTypeScale.of(_spec(body: ['system']), platform: TargetPlatform.macOS);
    expect(mac.body.fontFamily, isNull);
    expect(mac.mono.fontFamily, genericMonoFamilies['macOS']);
    final windows = MyDataTypeScale.of(_spec(), platform: TargetPlatform.windows);
    expect(windows.mono.fontFamily, genericMonoFamilies['windows']);
  });

  test('a font not bundled yet is skipped for the next in its stack', () {
    final scale = MyDataTypeScale.of(_spec(body: ['inter-tight', 'inter', 'sans']));
    expect(fontCatalogue['inter-tight']!.bundled, isFalse);
    expect(scale.body.fontFamily, 'packages/mydata_ui/Inter');
  });

  test('a variable font draws the exact weight; a core font the nearest it has, with no variation', () {
    final scale = MyDataTypeScale.of(_spec(
      body: ['inter', 'sans'],
      roles: {
        TypeRole.bodyStrong: const TypeRoleSpec(size: 14, lineHeight: 1.43, weight: 550, stack: TypeStack.body),
        TypeRole.mono: const TypeRoleSpec(size: 13, lineHeight: 1.5, weight: 400, stack: TypeStack.mono),
      },
      mono: ['jetbrains-mono', 'mono'],
    ));
    // Inter keeps its optical size axis: a 14 px role is drawn at optical size 14.
    expect(scale.bodyStrong.fontVariations, [const FontVariation('wght', 550), const FontVariation('opsz', 14)]);
    expect(scale.bodyStrong.fontWeight, FontWeight.w600);
    expect(scale.mono.fontVariations, isNull);
    expect(scale.mono.fontFamily, 'packages/mydata_ui/JetBrainsMono');
  });

  test('tabular figures, italic secondary text, tracking and upper case come from the file', () {
    final scale = MyDataTypeScale.of(_spec(tabular: true, italic: true, roles: {
      TypeRole.label: const TypeRoleSpec(
          size: 12, lineHeight: 1.3, weight: 600, tracking: 0.06, upper: true, stack: TypeStack.body),
    }));
    expect(scale.body.fontFeatures, [const FontFeature.tabularFigures()]);
    expect(scale.caption.fontStyle, FontStyle.italic);
    expect(scale.body.fontStyle, isNull);
    expect(scale.secondary(scale.body).fontStyle, FontStyle.italic);
    expect(scale.label.letterSpacing, closeTo(0.72, 0.001));
    expect(scale.cased(MyDataTypeRole.label, 'Email'), 'EMAIL');
    expect(scale.cased(MyDataTypeRole.label, 'myAssistant', holdsName: true), 'myAssistant');
    expect(scale.cased(MyDataTypeRole.caption, 'Email'), 'Email');
    expect(MyDataTypeScale.kiwi.cased(MyDataTypeRole.label, 'Email'), 'Email');
    expect(MyDataTypeScale.kiwi.secondary(MyDataType.body), MyDataType.body);
  });

  test('the six built-ins set their type as their rules say', () {
    final hairline = designedLook('mydata.hairline', Brightness.light).typeScale;
    expect(hairline.body.fontFamily, 'packages/mydata_ui/Inter');
    expect(hairline.body.fontFeatures, [const FontFeature.tabularFigures()]);
    expect(hairline.bodyStrong.fontVariations, [const FontVariation('wght', 550), const FontVariation('opsz', 14)]);
    // Display sizes get display optics: Inter's axis ends at 32, Literata's at 72.
    expect(hairline.displayXl.fontVariations!.last, const FontVariation('opsz', 32));
    final journal = designedLook('mydata.journal', Brightness.light).typeScale;
    expect(journal.displayXl.fontFamily, 'packages/mydata_ui/Fraunces');
    expect(journal.body.fontFamily, 'packages/mydata_ui/InstrumentSans');
    expect(journal.caption.fontStyle, FontStyle.italic);
    final sticker = designedLook('mydata.sticker', Brightness.light).typeScale;
    expect(sticker.heading.fontFamily, 'packages/mydata_ui/Fredoka');
    expect(sticker.label.fontVariations, [const FontVariation('wght', 800)]);
    final paperback = designedLook('mydata.paperback', Brightness.dark).typeScale;
    expect(paperback.body.fontFamily, 'packages/mydata_ui/Literata');
    expect(paperback.secondaryItalic, isTrue);
    expect(paperback.displayXl.fontVariations!.last, const FontVariation('opsz', 40));
    expect(paperback.body.fontVariations!.last, const FontVariation('opsz', 16));
    final frosted = designedLook('mydata.frosted', Brightness.light).typeScale;
    expect(frosted.title.fontFamily, 'packages/mydata_ui/Sora');
    expect(frosted.body.fontFamily, 'packages/mydata_ui/Manrope');
    expect(designedLook('mydata.kiwi', Brightness.light).typeScale.body.fontFamily, MyDataType.body.fontFamily);
    // The sizes the rules' typography tables give for the small roles (frosted and paperback RULES.md).
    expect([frosted.label.fontSize, frosted.caption.fontSize, frosted.mono.fontSize], [13, 13, 13]);
    expect(frosted.label.fontVariations, [const FontVariation('wght', 600)]);
    expect([paperback.label.fontSize, paperback.caption.fontSize, paperback.mono.fontSize], [14, 13, 14]);
  });

  test("Material's text roles keep each role's own family, and a platform family is never prefixed", () {
    final journal = MyDataTheme.fromLook(designedLook('mydata.journal', Brightness.light)).textTheme;
    expect(journal.displayLarge!.fontFamily, 'packages/mydata_ui/Fraunces');
    expect(journal.titleLarge!.fontFamily, 'packages/mydata_ui/Fraunces');
    expect(journal.bodyMedium!.fontFamily, 'packages/mydata_ui/InstrumentSans');
    final kiwi = designedLook('mydata.kiwi', Brightness.light);
    final mono = kiwi.copyWith(typeScale: MyDataTypeScale.of(_spec(body: ['mono']), platform: TargetPlatform.macOS));
    final text = MyDataTheme.fromLook(mono).textTheme;
    expect(text.bodyMedium!.fontFamily, genericMonoFamilies['macOS']);
  });

  testWidgets('Bold Text draws a variable font heavier: its wght moves, not only its fontWeight', (tester) async {
    final hairline = designedLook('mydata.hairline', Brightness.light);
    expect(hairline.typeScale.bold.body.fontVariations, [const FontVariation('wght', 700), const FontVariation('opsz', 14)]);
    expect(hairline.typeScale.bold.label.fontVariations!.first, const FontVariation('wght', 800));
    expect(MyDataTypeScale.kiwi.bold.body, same(MyDataTypeScale.kiwi.body), reason: "a static font is Text's to bolden");
    Future<double> width({required bool bold}) async {
      await tester.pumpWidget(MaterialApp(
        theme: MyDataTheme.fromLook(hairline),
        home: MediaQuery(
          data: MediaQueryData(boldText: bold),
          child: Center(child: Builder(builder: (context) => Text('Hamburgefonstiv', style: context.typeScale.body))),
        ),
      ));
      return tester.getSize(find.text('Hamburgefonstiv')).width;
    }

    expect(await width(bold: true), greaterThan(await width(bold: false)));
  });

  test('every designed built-in sets every type role itself: none is left to the base and ratio', () {
    for (final e in designedThemeTexts().entries) {
      final type = (readStrictJson(e.value) as Map<String, Object?>)['type'] as Map<String, Object?>?;
      if (type == null) continue; // System: the platform's own type.
      final roles = (type['roles'] as Map<String, Object?>).keys.toSet();
      expect(roles, {for (final r in TypeRole.values) r.key}, reason: e.key);
    }
  });

  testWidgets('a theme with upper-case labels sets a control\'s label and a status in capitals, never a name',
      (tester) async {
    final kiwi = designedLook('mydata.kiwi', Brightness.light);
    final t = kiwi.typeScale;
    final upper = kiwi.copyWith(
      typeScale: MyDataTypeScale(
        displayXl: t.displayXl, displayLg: t.displayLg, title: t.title, heading: t.heading, body: t.body,
        bodyStrong: t.bodyStrong, label: t.label, caption: t.caption, mono: t.mono, upper: {MyDataTypeRole.label},
      ),
    );
    await tester.pumpWidget(MaterialApp(
      theme: MyDataTheme.fromLook(upper),
      home: const Material(
        child: Column(children: [
          GroupedControl(label: 'Mode', child: SizedBox()),
          MyDataBadge('Connected', tone: MyDataTone.success),
        ]),
      ),
    ));
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.bySemanticsLabel('Connected'), findsOneWidget);
    expect(upper.typeScale.cased(MyDataTypeRole.label, 'myAssistant', holdsName: true), 'myAssistant');
  });

  for (final id in drawnBuiltIns) {
    for (final b in Brightness.values) {
      final slug = id.substring('mydata.'.length);
      testWidgets('type golden ($slug-${b.name})', (tester) async {
        tester.view.physicalSize = const Size(640, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final look = designedLook(id, b);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MyDataTheme.fromLook(look),
          home: Builder(
            builder: (context) => Material(
              color: context.colors.bg,
              child: Padding(padding: EdgeInsets.all(context.space(6)), child: const TypeSpecimen()),
            ),
          ),
        ));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/type.$slug-${b.name}.png'));
      });
    }
  }
}
