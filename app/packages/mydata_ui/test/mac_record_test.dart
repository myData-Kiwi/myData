// A record's labelled values in the Mac window (lib/src/mac/mac_record.dart): each label sits on its value's
// baseline in every look, whatever its role's size and line height.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

void main() {
  double baseline(WidgetTester tester, String text) {
    final p = tester.renderObject<RenderParagraph>(find.text(text));
    final painter = TextPainter(text: p.text, textDirection: TextDirection.ltr, textScaler: p.textScaler)..layout();
    addTearDown(painter.dispose);
    return p.localToGlobal(Offset.zero).dy + painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  // Notebook's 14 px bold italic labels on a 20 px line beside 16 px values on a 28 px one sat 4 to 6 px
  // high; Paperback and Journal mix a serif and an italic too.
  for (final slug in [null, 'notebook', 'paperback', 'journal', 'terminal']) {
    testWidgets('a field\'s label is on its value\'s baseline in ${slug ?? 'System'}', (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: slug == null
            ? MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light)
            : MacTheme.forChoice(ThemeChoice('mydata.$slug'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MacFieldTable(groups: [
              [const MacField(label: 'mobile', value: '+44 7700 900123')],
              [MacField(label: 'website', value: 'example.com/ava', onOpen: () {})],
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final (label, value) in [('mobile', '+44 7700 900123'), ('website', 'example.com/ava')]) {
        expect(baseline(tester, label), moreOrLessEquals(baseline(tester, value), epsilon: 0.5), reason: label);
      }
    });
  }
}
