import 'dart:ui' show SemanticsAction, SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The preview's card: 520px wide, space-5 padding, surface, radius-lg, shadow-1.
Widget _card(BuildContext context, Widget child) => Container(
      width: 520,
      padding: const EdgeInsets.all(MyDataSpace.s5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: MyDataRadii.lg(kiwiLook),
        boxShadow: context.shadows.shadow1,
      ),
      child: child,
    );

Finder get _fill =>
    find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox));

Finder get _track => find
    .ancestor(of: find.byType(TweenAnimationBuilder<double>), matching: find.byType(SizedBox))
    .first;

Widget _bar(double value, {String? valueLabel, TextDirection direction = TextDirection.ltr}) => Directionality(
      textDirection: direction,
      child: SizedBox(
        width: 400,
        child: MyDataProgressBar(
          label: 'Downloading the assistant model',
          value: value,
          valueLabel: valueLabel,
          caption: 'You can keep using myData while this finishes.',
        ),
      ),
    );

void main() {
  goldenMatrix(
    'progress_bar',
    () => Builder(
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        _card(
            context,
            const MyDataProgressBar(
              label: 'Getting ready to download',
              value: 0,
              caption: 'Nothing has arrived yet. You can keep using myData.',
            )),
        const SizedBox(height: MyDataSpace.s4),
        _card(
            context,
            const MyDataProgressBar(
              label: 'Downloading the assistant model',
              value: 0.35,
              caption: '3.4 GB of 9.8 GB. You can keep using myData while this finishes.',
            )),
        const SizedBox(height: MyDataSpace.s4),
        _card(
            context,
            const MyDataProgressBar(
              label: 'Importing photos',
              value: 0.62,
              valueLabel: '1,240 of 2,000',
              caption: 'Photos appear in myPhotos as they arrive.',
            )),
        const SizedBox(height: MyDataSpace.s4),
        _card(
            context,
            const MyDataProgressBar(
              label: 'Downloaded the assistant model',
              value: 1,
              caption: 'The assistant is ready to use.',
            )),
      ]),
    ),
    size: const Size(568, 544),
  );

  testWidgets('shows the label, the figure and the caption; the figure defaults to a whole percentage',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.354)));
    expect(find.text('Downloading the assistant model'), findsOneWidget);
    expect(find.text('35%'), findsOneWidget);
    expect(find.text('You can keep using myData while this finishes.'), findsOneWidget);

    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.62, valueLabel: '1,240 of 2,000')));
    expect(find.text('1,240 of 2,000'), findsOneWidget);
    expect(find.text('62%'), findsNothing);
  });

  testWidgets('the track is 8px, fully rounded, surface-sunken; the fill is accent', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.5)));
    expect(MyDataProgressBar.trackHeight, 8);
    expect(tester.getSize(_track).height, 8);
    final context = tester.element(find.byType(MyDataProgressBar));
    final decorations = tester
        .widgetList<DecoratedBox>(
            find.descendant(of: find.byType(MyDataProgressBar), matching: find.byType(DecoratedBox)))
        .map((d) => d.decoration as BoxDecoration)
        .toList();
    expect(decorations.map((d) => d.color), [context.colors.surfaceSunken, context.colors.accent]);
    for (final d in decorations) {
      expect(d.borderRadius, MyDataRadii.pill(kiwiLook));
    }
  });

  testWidgets('values outside 0..1 are clamped', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(1.7)));
    expect(find.text('100%'), findsOneWidget);
    expect(tester.getSize(_fill).width, tester.getSize(_track).width);

    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(-0.2)));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
    expect(_fill, findsNothing);

    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(double.nan)));
    await tester.pumpAndSettle();
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('the first value shows at once; a new value eases over base', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.2)));
    final track = tester.getSize(_track).width;
    expect(tester.getSize(_fill).width, moreOrLessEquals(track * 0.2));

    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.8)));
    await tester.pump(MyDataMotion.base ~/ 2);
    final mid = tester.getSize(_fill).width;
    expect(mid, greaterThan(track * 0.2));
    expect(mid, lessThan(track * 0.8));

    await tester.pump(MyDataMotion.base ~/ 2);
    expect(tester.getSize(_fill).width, moreOrLessEquals(track * 0.8));
  });

  testWidgets('with reduced motion a new value jumps', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.2), reduceMotion: true));
    final track = tester.getSize(_track).width;
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.8), reduceMotion: true));
    await tester.pump();
    expect(tester.getSize(_fill).width, moreOrLessEquals(track * 0.8));
  });

  testWidgets('the fill starts at the leading edge in right-to-left text', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.25, direction: TextDirection.rtl)));
    expect(tester.getTopRight(_fill).dx, moreOrLessEquals(tester.getTopRight(_track).dx));
    expect(tester.getTopLeft(_fill).dx, greaterThan(tester.getTopLeft(_track).dx));
  });

  testWidgets('screen readers get one progress bar with the label, a percentage and the caption',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.35)));
    final node = tester.getSemantics(find.byType(MyDataProgressBar));
    final data = node.getSemanticsData();
    expect(data.role, SemanticsRole.progressBar);
    expect(data.label, 'Downloading the assistant model');
    expect(data.value, '35%');
    expect(data.minValue, '0');
    expect(data.maxValue, '100');
    expect(data.hint, 'You can keep using myData while this finishes.');
    // The texts inside are not read a second time, and the bar is not focusable or tappable.
    expect(find.bySemanticsLabel('35%'), findsNothing);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('a custom figure is read too, before the caption', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _bar(0.35, valueLabel: '3.4 GB of 9.8 GB')));
    final data = tester.getSemantics(find.byType(MyDataProgressBar)).getSemanticsData();
    expect(data.label, 'Downloading the assistant model');
    // The value stays a percentage, so the web build still sets aria-valuenow.
    expect(data.value, '35%');
    expect(data.hint, '3.4 GB of 9.8 GB. You can keep using myData while this finishes.');
    // Heard once, on the bar's node, not again from the text inside.
    expect(find.bySemanticsLabel('3.4 GB of 9.8 GB'), findsNothing);
    handle.dispose();
  });
}
