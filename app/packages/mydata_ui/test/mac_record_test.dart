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

  // A value never breaks inside a word beside its label: where one would (Terminal's wide face in the record
  // at the smallest window: "ava@example.c / om"), every label goes above its value, and each value keeps
  // its line; with room, labels stay beside their values.
  for (final (width, stacked) in [(200.0, true), (600.0, false)]) {
    // 200 px is wider than the label column, the gap and a short value: the old rule kept the labels beside.
    testWidgets('a record ${stacked ? 'stacks its labels' : 'keeps its labels beside'} at $width px in terminal',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: MacTheme.forChoice(ThemeChoice('mydata.terminal'), Brightness.light, MyDataMacColors.light),
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: MacFieldTable(groups: [
                [const MacField(label: 'mobile', value: '+44 7700 900123')],
                [const MacField(label: 'work', value: 'ava@example.com')],
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final (label, value) in [('mobile', '+44 7700 900123'), ('work', 'ava@example.com')]) {
        final l = tester.getRect(find.text(label)), v = tester.getRect(find.text(value));
        expect(l.bottom <= v.top, stacked, reason: '$label above its value');
        final p = tester.renderObject<RenderParagraph>(find.text(value));
        expect(p.size.height, lessThan(1.5 * p.text.style!.fontSize! * (p.text.style!.height ?? 1.2)),
            reason: '$value on one line');
      }
    });
  }
}
