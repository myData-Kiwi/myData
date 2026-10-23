import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

const _detail = 'ConnectionRefusedError: [Errno 61] Connection refused\n127.0.0.1:8765';

Widget _working() => const StatusPanel(
      kind: StatusPanelKind.working,
      title: 'Starting your host',
      message: 'This takes a few seconds.',
    );

Widget _progress() => StatusPanel(
      kind: StatusPanelKind.working,
      title: 'Preparing the assistant',
      message: 'You can keep using myData while this finishes.',
      progress: 0.35,
      progressLabel: 'Downloading qwen3:14b',
      actions: [Button(label: 'Skip for now', variant: ButtonVariant.plain, onPressed: _noop)],
    );

Widget _info() => StatusPanel(
      kind: StatusPanelKind.info,
      title: 'The assistant is off',
      message: 'myData works without it. Switching it on downloads its model if it is not on this computer yet.',
      actions: [
        Button(label: 'Continue', variant: ButtonVariant.filled, onPressed: _noop),
        Button(label: 'Switch the assistant on', onPressed: _noop),
      ],
    );

Widget _error() => StatusPanel(
      kind: StatusPanelKind.error,
      title: 'The host did not start',
      message: 'Check that nothing else is using its port, then retry.',
      detail: _detail,
      actions: [Button(label: 'Retry', variant: ButtonVariant.filled, onPressed: _noop)],
    );

Widget _cell(Widget panel) => SizedBox(width: StatusPanel.maxWidth, child: panel);

Future<void> _pump(WidgetTester tester, Widget child, {bool reduceMotion = false}) async {
  tester.view.physicalSize = const Size(800, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, child, reduceMotion: reduceMotion));
}

void main() {
  goldenMatrix(
    'status_panel',
    () => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cell(_working()),
        const SizedBox(width: MyDataSpace.s6),
        _cell(_progress()),
      ]),
      const SizedBox(height: MyDataSpace.s6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cell(_info()),
        const SizedBox(width: MyDataSpace.s6),
        _cell(_error()),
      ]),
    ]),
    size: const Size(1112, 640),
    // The loading kiwi turns forever; still, it settles.
    reduceMotion: true,
  );

  testWidgets('working: the loading kiwi, no tile, no bar', (tester) async {
    await _pump(tester, _working(), reduceMotion: true);
    expect(find.byType(KiwiLoader), findsOneWidget);
    expect(find.byType(IconTile), findsNothing);
    expect(find.byType(MyDataProgressBar), findsNothing);
  });

  testWidgets('working with progress: a progress bar labelled with what is in progress, the message as caption',
      (tester) async {
    await _pump(tester, _progress());
    expect(find.byType(KiwiLoader), findsNothing);
    final bar = tester.widget<MyDataProgressBar>(find.byType(MyDataProgressBar));
    expect(bar.value, 0.35);
    expect(bar.label, 'Downloading qwen3:14b');
    expect(bar.caption, 'You can keep using myData while this finishes.');
    expect(find.text('35%'), findsOneWidget);
  });

  testWidgets('info: an accent tile; error: a danger tile and the detail in a selectable mono well',
      (tester) async {
    await _pump(tester, _info());
    expect(tester.widget<IconTile>(find.byType(IconTile)).tone, MyDataTone.accent);
    expect(find.byType(MonoWell), findsNothing);

    await _pump(tester, _error());
    final c = tester.element(find.byType(StatusPanel)).colors;
    expect(tester.widget<IconTile>(find.byType(IconTile)).tone, MyDataTone.danger);
    final well = tester.widget<MonoWell>(find.byType(MonoWell));
    expect(well.value, _detail);
    expect(well.copyLabel, isNull);
    final text = tester.widget<SelectableText>(find.descendant(of: find.byType(MonoWell), matching: find.byType(SelectableText)));
    expect(text.data, _detail);
    expect(text.style!.fontFamily, MyDataType.mono.fontFamily);
    final box = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(MonoWell), matching: find.byType(DecoratedBox)).first)
        .decoration as BoxDecoration;
    expect(box.color, c.surfaceSunken);
    expect(box.border, isNull);
  });

  testWidgets('layout: centred, at most maxWidth, title then message in ink-muted', (tester) async {
    await _pump(tester, SizedBox(width: 752, child: _info()));
    final c = tester.element(find.byType(StatusPanel)).colors;
    final column = tester.getRect(find.descendant(of: find.byType(StatusPanel), matching: find.byType(Column)).first);
    expect(column.width, lessThanOrEqualTo(StatusPanel.maxWidth));
    expect(column.center.dx, moreOrLessEquals(tester.getRect(find.byType(StatusPanel)).center.dx));
    final title = tester.widget<Text>(find.text('The assistant is off'));
    expect(title.style!.fontSize, MyDataType.title.fontSize);
    expect(title.style!.color, c.ink);
    final message = tester.widget<Text>(find.textContaining('myData works without it'));
    expect(message.style!.color, c.inkMuted);
    expect(tester.getTopLeft(find.textContaining('myData works without it')).dy,
        tester.getBottomLeft(find.text('The assistant is off')).dy + StatusPanel.titleGap(kiwiLook));
    expect(tester.getSemantics(find.text('The assistant is off')),
        matchesSemantics(label: 'The assistant is off', isHeader: true));
  });

  testWidgets('actions: tap and keyboard run them', (tester) async {
    var continued = 0;
    var switched = 0;
    await _pump(
        tester,
        StatusPanel(
          kind: StatusPanelKind.info,
          title: 'The assistant is off',
          message: 'myData works without it.',
          actions: [
            Button(label: 'Continue', variant: ButtonVariant.filled, onPressed: () => continued++),
            Button(label: 'Switch the assistant on', onPressed: () => switched++),
          ],
        ));
    await tester.tap(find.text('Continue'));
    expect(continued, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(switched, 1);
  });

  testWidgets('a long detail in a short window scrolls instead of overflowing, and clears the bottom inset',
      (tester) async {
    var retried = 0;
    final trace = List.generate(60, (i) => '  File "mydatad/host.py", line ${100 + i}, in start').join('\n');
    await _pump(
      tester,
      MediaQuery(
        // A phone frame's tab bar clearance arrives as MediaQuery padding.
        data: const MediaQueryData(size: Size(400, 300), padding: EdgeInsets.only(bottom: 80)),
        child: SizedBox(
          width: 400,
          height: 300,
          child: StatusPanel(
            kind: StatusPanelKind.error,
            title: 'The host did not start',
            message: 'Check that nothing else is using its port, then retry.',
            detail: trace,
            actions: [Button(label: 'Retry', variant: ButtonVariant.filled, onPressed: () => retried++)],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    // Scrolled to the end, the button is reachable and stops above the inset.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final retry = tester.getRect(find.widgetWithText(Button, 'Retry'));
    // The pumped frame has 24px of padding around the 400 x 300 box.
    expect(retry.bottom, moreOrLessEquals(24 + 300 - 80 - StatusPanel.padding(kiwiLook)));
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('a short panel in a tall box stays centred', (tester) async {
    await _pump(tester, SizedBox(width: 600, height: 600, child: _info()));
    final panel = tester.getRect(find.byType(StatusPanel));
    final column = tester.getRect(find.descendant(of: find.byType(StatusPanel), matching: find.byType(Column)).first);
    expect(column.center.dy, moreOrLessEquals(panel.center.dy, epsilon: 0.5));
    expect(column.center.dx, moreOrLessEquals(panel.center.dx, epsilon: 0.5));
  });

  testWidgets('no actions: no button row', (tester) async {
    await _pump(tester, _working(), reduceMotion: true);
    expect(find.byType(ButtonRow), findsNothing);
  });
}
