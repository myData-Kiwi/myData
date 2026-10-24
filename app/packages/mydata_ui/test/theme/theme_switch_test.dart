// A theme switch draws the new type at once (design/themes/ARCHITECTURE.md 3.5 and 3.6): no frame shows text
// at in-between sizes, weights or fonts, as MaterialApp's theme animation would draw it.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'designed_themes.dart';

class _Body extends StatelessWidget {
  const _Body();
  @override
  Widget build(BuildContext context) => Text('Lunch with Ava', style: context.typeScale.body);
}

TextStyle _drawn(WidgetTester tester) =>
    (tester.renderObject<RenderParagraph>(find.text('Lunch with Ava')).text as TextSpan).style!;

Widget _app(MyDataLook look, {Duration? duration}) => MaterialApp(
      theme: MyDataTheme.fromLook(look),
      themeAnimationDuration: duration ?? MyDataTheme.switchDuration,
      home: const Material(child: _Body()),
    );

void main() {
  final kiwi = designedLook('mydata.kiwi', Brightness.light);
  final paperback = designedLook('mydata.paperback', Brightness.light);

  test('the switch takes no time', () => expect(MyDataTheme.switchDuration, Duration.zero));

  testWidgets('one frame after a switch, text has the new family and size', (tester) async {
    await tester.pumpWidget(_app(kiwi));
    expect(_drawn(tester).fontFamily, kiwi.typeScale.body.fontFamily);
    await tester.pumpWidget(_app(paperback));
    expect(_drawn(tester).fontFamily, paperback.typeScale.body.fontFamily);
    expect(_drawn(tester).fontSize, paperback.typeScale.body.fontSize);
    expect(_drawn(tester).fontVariations, paperback.typeScale.body.fontVariations);
    // Colours too: nothing is left to animate.
    expect(tester.element(find.byType(_Body)).colors.bg, paperback.colors.bg);
  });

  testWidgets('even under an animated theme, type never passes through in-between styles', (tester) async {
    expect(paperback.typeScale.body.fontSize, isNot(kiwi.typeScale.body.fontSize));
    await tester.pumpWidget(_app(kiwi, duration: const Duration(milliseconds: 200)));
    await tester.pumpWidget(_app(paperback, duration: const Duration(milliseconds: 200)));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_drawn(tester).fontFamily, paperback.typeScale.body.fontFamily, reason: 'frame $i');
      expect(_drawn(tester).fontSize, paperback.typeScale.body.fontSize, reason: 'frame $i');
    }
    await tester.pumpAndSettle();
  });

  test('the look lerps colours but snaps type', () {
    final mid = kiwi.lerp(paperback, 0.1);
    expect(mid.typeScale, same(paperback.typeScale));
    expect(kiwi.lerp(paperback, 0).typeScale, same(kiwi.typeScale));
    expect(mid.colors.bg, Color.lerp(kiwi.colors.bg, paperback.colors.bg, 0.1));
  });
}
