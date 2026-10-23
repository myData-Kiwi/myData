import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The preview's six chips, one per row (spec: do not stack statuses side by side).
Widget _all() => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyDataBadge.host('Host running'),
        SizedBox(height: MyDataSpace.s2),
        MyDataBadge('Up to date', tone: MyDataTone.success),
        SizedBox(height: MyDataSpace.s2),
        MyDataBadge('Needs approval', tone: MyDataTone.warning),
        SizedBox(height: MyDataSpace.s2),
        MyDataBadge('Backup failed', tone: MyDataTone.danger),
        SizedBox(height: MyDataSpace.s2),
        MyDataBadge('Update available', tone: MyDataTone.info),
        SizedBox(height: MyDataSpace.s2),
        MyDataBadge('Offline', tone: MyDataTone.neutral),
      ],
    );

BoxDecoration _decoration(WidgetTester tester, String label) {
  final box = tester.widget<Container>(
      find.ancestor(of: find.text(label), matching: find.byType(Container)).last);
  return box.decoration! as BoxDecoration;
}

void main() {
  goldenMatrix('badge', _all, size: const Size(200, 244));

  testWidgets('every chip is 26px tall and a pill', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all()));
    for (final label in ['Host running', 'Up to date', 'Needs approval', 'Backup failed', 'Update available', 'Offline']) {
      final chip = find.ancestor(of: find.text(label), matching: find.byType(MyDataBadge));
      expect(tester.getSize(chip).height, MyDataBadge.height);
      expect(_decoration(tester, label).borderRadius, MyDataRadii.pill(kiwiLook));
    }
  });

  testWidgets('status chips use the -soft fill and the strong colour; neutral is surface-sunken with ink-muted',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all()));
    final c = tester.element(find.byType(MyDataBadge).first).colors;
    final cases = {
      'Up to date': (c.successSoft, c.success),
      'Needs approval': (c.warningSoft, c.warning),
      'Backup failed': (c.dangerSoft, c.danger),
      'Update available': (c.infoSoft, c.info),
      'Offline': (c.surfaceSunken, c.inkMuted),
    };
    for (final e in cases.entries) {
      final d = _decoration(tester, e.key);
      expect(d.color, e.value.$1, reason: e.key);
      expect(d.boxShadow, isNull, reason: e.key);
      expect(tester.widget<Text>(find.text(e.key)).style!.color, e.value.$2, reason: e.key);
    }
  });

  testWidgets('the host chip is surface with shadow-1, ink text and the only brand dot', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all()));
    final context = tester.element(find.byType(MyDataBadge).first);
    final c = context.colors;
    final d = _decoration(tester, 'Host running');
    expect(d.color, c.surface);
    expect(d.boxShadow, context.shadows.shadow1);
    expect(tester.widget<Text>(find.text('Host running')).style!.color, c.ink);

    final dots = find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == c.brand);
    expect(dots, findsOneWidget);
    expect(find.descendant(of: find.byType(MyDataBadge).first, matching: dots), findsOneWidget);
    expect(tester.getSize(dots), const Size(MyDataBadge.dotSize, MyDataBadge.dotSize));
  });

  testWidgets('the word is always present: semantics read the label, never a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all()));
    expect(find.bySemanticsLabel('Host running'), findsOneWidget);
    expect(find.bySemanticsLabel('Needs approval'), findsOneWidget);
    expect(tester.getSemantics(find.byType(MyDataBadge).at(2)),
        isSemantics(label: 'Needs approval', isButton: false, isFocusable: false, hasTapAction: false));
    handle.dispose();
  });

  testWidgets('not tappable: no Pressable, and Tab does not reach it', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all()));
    expect(find.descendant(of: find.byType(MyDataBadge), matching: find.byType(Pressable)), findsNothing);
    expect(find.descendant(of: find.byType(MyDataBadge), matching: find.byType(Focus)), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused == null || find.byType(MyDataBadge).evaluate().every((e) => !_isAncestor(e, focused)), isTrue);
  });

  testWidgets('a long label stays on one line, 26px tall, and ends in an ellipsis when squeezed', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const SizedBox(width: 120, child: MyDataBadge('Backup failed on the external drive', tone: MyDataTone.danger))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(MyDataBadge)).height, MyDataBadge.height);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('scaled text grows the chip instead of clipping the word', (tester) async {
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyDataBadge.host('Host running'),
              SizedBox(height: MyDataSpace.s2),
              MyDataBadge('Needs approval', tone: MyDataTone.warning),
            ],
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    for (final label in ['Host running', 'Needs approval']) {
      final chip = find.ancestor(of: find.text(label), matching: find.byType(MyDataBadge));
      final chipHeight = tester.getSize(chip).height;
      final textHeight = tester.getSize(find.text(label)).height;
      expect(textHeight, greaterThan(MyDataBadge.height), reason: label);
      expect(chipHeight, greaterThanOrEqualTo(textHeight), reason: label);
    }
  });

  testWidgets('accent is refused: it is for icon tiles, not statuses', (tester) async {
    expect(() => MyDataBadge('Up to date', tone: MyDataTone.values.first), throwsAssertionError);
  });

  testWidgets('it renders the same with reduced motion and reduced transparency (nothing moves, nothing is glass)',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, _all(), reduceMotion: true, reduceTransparency: true));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_decoration(tester, 'Host running').color, tester.element(find.byType(MyDataBadge).first).colors.surface);
  });
}

bool _isAncestor(Element ancestor, BuildContext descendant) {
  var found = false;
  descendant.visitAncestorElements((e) {
    if (e == ancestor) found = true;
    return !found;
  });
  return found;
}
