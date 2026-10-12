import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

const _title = 'No photos yet';
const _sentence = 'Import a folder from this computer, or open myPhotos on your phone to back up its camera roll.';
const _action = 'Import photos';
const _reason = 'The host cannot be reached. Open myData to start it.';

/// Left: the preview's state, with its action. Right: the action needs the host, which cannot be reached.
Widget _allStates() => const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: EmptyState.maxWidth,
        child: _Top(EmptyState(title: _title, sentence: _sentence, actionLabel: _action, onAction: _noop)),
      ),
      SizedBox(width: MyDataSpace.s6),
      SizedBox(
        width: EmptyState.maxWidth,
        child: _Top(EmptyState(
            title: _title, sentence: _sentence, actionLabel: _action, onAction: null, disabledReason: _reason)),
      ),
    ]);

/// EmptyState centres itself in the space it is given; a min-size column gives it only its own height, so
/// both states line up at the top of the golden.
class _Top extends StatelessWidget {
  const _Top(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [child]);
}

void main() {
  goldenMatrix('empty_state', _allStates, size: const Size(872, 330));

  testWidgets('tap, Enter and Space run the action', (tester) async {
    var imported = 0;
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        EmptyState(title: _title, sentence: _sentence, actionLabel: _action, onAction: () => imported++)));
    await tester.tap(find.text(_action));
    expect(imported, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(imported, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(imported, 3);
  });

  testWidgets('disabled: the button ignores taps and focus, and the reason shows under it', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        const EmptyState(
            title: _title, sentence: _sentence, actionLabel: _action, onAction: null, disabledReason: _reason)));
    final button = tester.widget<Button>(find.byType(Button));
    expect(button.onPressed, isNull);
    expect(find.text(_reason), findsOneWidget);
    expect(tester.getTopLeft(find.text(_reason)).dy,
        tester.getBottomLeft(find.byType(Button)).dy + EmptyState.reasonGap);
    final reason = tester.widget<Text>(find.text(_reason));
    final c = tester.element(find.byType(EmptyState)).colors;
    expect(reason.style!.fontSize, MyDataType.caption.fontSize);
    expect(reason.style!.color, c.inkMuted);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Button>(), isNull);
  });

  testWidgets('the reason is shown only while the action is disabled', (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        const EmptyState(
            title: _title, sentence: _sentence, actionLabel: _action, onAction: _noop, disabledReason: _reason)));
    expect(find.text(_reason), findsNothing);
  });

  testWidgets('layout: centred, at most 400px wide, a 96px radius-xl kiwi tile with a 72px-wide mark, title then sentence then a filled button',
      (tester) async {
    await tester.pumpWidget(themedFrame(
        themeMatrix.first,
        const SizedBox(
            width: 600,
            child: EmptyState(title: _title, sentence: _sentence, actionLabel: _action, onAction: _noop))));
    final column = tester.getRect(find.descendant(of: find.byType(EmptyState), matching: find.byType(Column)));
    expect(column.width, lessThanOrEqualTo(EmptyState.maxWidth));
    final frame = tester.getRect(find.byType(EmptyState));
    expect(column.center.dx, frame.center.dx);

    final mark = find.descendant(of: find.byType(EmptyState), matching: find.byType(KiwiMark));
    final tileFinder = find.ancestor(of: mark, matching: find.byType(Container)).first;
    final tile = tester.getRect(tileFinder);
    expect(tile.size, const Size.square(EmptyState.tileSize));
    final tileBox = tester.widget<Container>(tileFinder).decoration! as BoxDecoration;
    expect(tileBox.borderRadius, MyDataRadii.xl);
    expect(tileBox.color, tester.element(find.byType(EmptyState)).colors.paper);
    expect(tileBox.boxShadow, tester.element(find.byType(EmptyState)).shadows.shadow1);
    final markRect = tester.getRect(mark);
    expect(markRect.width, moreOrLessEquals(EmptyState.markWidth));
    expect(markRect.width / tile.width, moreOrLessEquals(0.75));
    expect(markRect.center, tile.center);
    expect(tile.center.dx, frame.center.dx);
    final title = tester.getRect(find.text(_title));
    final sentence = tester.getRect(find.text(_sentence));
    final button = tester.getRect(find.byType(Button));
    expect(title.top, tile.bottom + EmptyState.wideGap);
    expect(sentence.top, title.bottom + EmptyState.gap);
    expect(button.top, sentence.bottom + EmptyState.wideGap);
    expect(button.center.dx, frame.center.dx);
    expect(button.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
    expect(button.width, greaterThanOrEqualTo(MyDataSize.controlHeight));

    final c = tester.element(find.byType(EmptyState)).colors;
    final titleText = tester.widget<Text>(find.text(_title));
    expect(titleText.style!.fontSize, MyDataType.title.fontSize);
    expect(titleText.style!.fontWeight, MyDataType.title.fontWeight);
    expect(titleText.style!.color, c.ink);
    expect(titleText.textAlign, TextAlign.center);
    final sentenceText = tester.widget<Text>(find.text(_sentence));
    expect(sentenceText.style!.fontSize, MyDataType.body.fontSize);
    expect(sentenceText.style!.color, c.inkMuted);
    expect(sentenceText.textAlign, TextAlign.center);
    expect(tester.widget<Button>(find.byType(Button)).variant, ButtonVariant.filled);
  });

  testWidgets('semantics: the title is a header, the kiwi is decorative, the button is named by its label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const EmptyState(title: _title, sentence: _sentence, actionLabel: _action, onAction: _noop)));
    expect(find.bySemanticsLabel('myData'), findsNothing);
    expect(tester.getSemantics(find.text(_title)), matchesSemantics(label: _title, isHeader: true));
    expect(
      tester.getSemantics(find.byType(Button)),
      matchesSemantics(
        label: _action,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('no animation: it settles at once, with or without reduced motion and transparency',
      (tester) async {
    for (final reduce in [false, true]) {
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          const EmptyState(title: _title, sentence: _sentence, actionLabel: _action, onAction: _noop),
          reduceMotion: reduce, reduceTransparency: reduce));
      // A frame or two for the kiwi drawing to load; an animation would take dozens or never settle.
      expect(await tester.pumpAndSettle(), lessThanOrEqualTo(3));
    }
  });
}
