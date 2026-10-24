import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

// The spec's sentences (design/components/Notice/README.md), with invented dates.
const _range = 'myData reads events from this Mac between 13 October 2025 and 13 October 2028.';
const _outside = '$_range This month is outside that range.';
const _notReadYet = 'myData has not read the events from this Mac yet. They appear here when it has.';
const _notAllowed = 'myData is not allowed to read this Mac’s calendars. Allow it in myData, under Settings, Sources.';
const _refused = 'myData is not allowed to read this Mac’s calendars. Turn on myData in System Settings, '
    'under Privacy & Security, Calendars.';
const _openMyData = 'Open myData';
const _openSettings = 'Open System Settings';

/// Every state the spec names, stacked as one screen would stack them (one per source, `space-2` apart),
/// above a stand-in for the list they are about.
Widget _allStates() => SizedBox(
      width: MyDataSize.contentMax,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const NoticeStack(notices: [
          Notice(message: _range),
          Notice(message: _outside),
          Notice(message: _notReadYet),
          Notice(message: _notAllowed, tone: NoticeTone.warning, actionLabel: _openMyData, onAction: _noop),
          Notice(message: _refused, tone: NoticeTone.warning, actionLabel: _openSettings, onAction: _noop),
        ]),
        Builder(
          builder: (context) => Container(
            height: MyDataSize.rowHeight,
            decoration: BoxDecoration(color: context.colors.surface, borderRadius: MyDataRadii.lg(kiwiLook)),
          ),
        ),
      ]),
    );

/// A phone-width column: the button keeps its width and stays beside the words, which wrap to more lines
/// (the preview's `flex:none` button beside `flex:1; min-width:0` words).
Widget _narrow() => const SizedBox(
      width: 360,
      child: NoticeStack(notices: [
        Notice(message: _outside),
        Notice(message: _refused, tone: NoticeTone.warning, actionLabel: _openSettings, onAction: _noop),
      ]),
    );

Widget _frame(Widget child, {double width = MyDataSize.contentMax, bool reduceMotion = false}) =>
    themedFrame(themeMatrix.first, SizedBox(width: width, child: child), reduceMotion: reduceMotion);

/// Pumps [frame] into a view wide enough for a content-width notice (the test default is 800px).
Future<void> _pump(WidgetTester tester, Widget frame) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(frame);
}

void main() {
  goldenMatrix('notice', _allStates, size: const Size(928, 410));
  goldenMatrix('notice_narrow', _narrow, size: const Size(408, 472));

  testWidgets('layout: a surface-sunken radius-md well, space-4 across and space-3 down, icon then words',
      (tester) async {
    await _pump(tester, _frame(const Notice(message: _range)));
    final notice = tester.getRect(find.byType(Notice));
    expect(notice.width, MyDataSize.contentMax);
    final c = tester.element(find.byType(Notice)).colors;
    final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(Notice), matching: find.byType(DecoratedBox)).first);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, c.surfaceSunken);
    expect(decoration.borderRadius, MyDataRadii.md(kiwiLook));
    expect(decoration.border, isNull);

    final icon = tester.getRect(find.byType(Icon));
    final words = tester.getRect(find.text(_range));
    expect(icon.size, const Size.square(MyDataSize.icon));
    expect(icon.left, notice.left + MyDataSpace.s4);
    expect(words.left, icon.right + MyDataSpace.s3);
    expect(words.top, notice.top + MyDataSpace.s3);
    expect(notice.bottom, words.bottom + MyDataSpace.s3);
    expect(icon.center.dy, moreOrLessEquals(notice.center.dy));
    final text = tester.widget<Text>(find.text(_range));
    expect(text.style!.fontSize, MyDataType.body.fontSize);
    expect(text.style!.fontWeight, MyDataType.body.fontWeight);
    expect(text.style!.color, c.ink);
    expect(find.byType(Button), findsNothing);
  });

  testWidgets('tones: info is an info outline in info, warning a warning outline in warning', (tester) async {
    for (final tone in NoticeTone.values) {
      await _pump(tester, _frame(Notice(message: _notReadYet, tone: tone)));
      final c = tester.element(find.byType(Notice)).colors;
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, iconOf(tone == NoticeTone.info ? MyDataIcon.info : MyDataIcon.warning));
      expect(icon.color, tone == NoticeTone.info ? c.info : c.warning);
      expect(icon.size, MyDataSize.icon);
    }
  });

  testWidgets('action: a plain button at the end that bleeds space-2 into the padding; the words do not move',
      (tester) async {
    await _pump(tester, _frame(const Notice(message: _notReadYet)));
    final plainWords = tester.getRect(find.text(_notReadYet)).top - tester.getRect(find.byType(Notice)).top;

    await _pump(tester, _frame(
        const Notice(message: _notReadYet, tone: NoticeTone.warning, actionLabel: _openMyData, onAction: _noop)));
    final notice = tester.getRect(find.byType(Notice));
    final button = tester.getRect(find.byType(Button));
    final words = tester.getRect(find.text(_notReadYet));
    expect(tester.widget<Button>(find.byType(Button)).variant, ButtonVariant.plain);
    expect(button.height, MyDataSize.controlHeight);
    expect(button.right, notice.right - (MyDataSpace.s4 - Notice.actionBleed(kiwiLook)));
    expect(button.top, notice.top + MyDataSpace.s3 - Notice.actionBleed(kiwiLook));
    expect(notice.bottom, button.bottom + MyDataSpace.s3 - Notice.actionBleed(kiwiLook));
    expect(button.left, greaterThanOrEqualTo(words.right + MyDataSpace.s3));
    // One line of words beside a 44px button: the words sit centred, and never closer than space-3 to the
    // edge, as they do without a button.
    expect(words.center.dy, moreOrLessEquals(notice.center.dy));
    expect(words.top - notice.top, greaterThanOrEqualTo(plainWords));
    expect(find.byType(Button), findsOneWidget);
  });

  testWidgets('action: two lines of words beside the button keep space-3 above and below', (tester) async {
    await _pump(tester, _frame(
        const Notice(message: _refused, tone: NoticeTone.warning, actionLabel: _openSettings, onAction: _noop),
        width: 640));
    final notice = tester.getRect(find.byType(Notice));
    final words = tester.getRect(find.text(_refused));
    final button = tester.getRect(find.byType(Button));
    expect(words.height, greaterThan(MyDataSize.controlHeight));
    expect(words.top, notice.top + MyDataSpace.s3);
    expect(notice.bottom, words.bottom + MyDataSpace.s3);
    expect(button.left, greaterThanOrEqualTo(words.right + MyDataSpace.s3));
    expect(button.center.dy, moreOrLessEquals(notice.center.dy));
  });

  testWidgets('narrow: the button stays beside the words, at its own width; the words wrap', (tester) async {
    await _pump(tester, _frame(
        const Notice(message: _refused, tone: NoticeTone.warning, actionLabel: _openSettings, onAction: _noop),
        width: 360));
    final notice = tester.getRect(find.byType(Notice));
    final words = tester.getRect(find.text(_refused));
    final button = tester.getRect(find.byType(Button));
    final icon = tester.getRect(find.byType(Icon));
    expect(words.left, icon.right + MyDataSpace.s3);
    expect(button.left, words.right + MyDataSpace.s3);
    expect(button.right, notice.right - (MyDataSpace.s4 - Notice.actionBleed(kiwiLook)));
    expect(button.height, MyDataSize.controlHeight);
    expect(button.center.dy, moreOrLessEquals(notice.center.dy));
    expect(icon.center.dy, moreOrLessEquals(notice.center.dy));
    expect(words.top, notice.top + MyDataSpace.s3);
    expect(notice.bottom, words.bottom + MyDataSpace.s3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the action runs on tap, Enter and Space, with a focus ring from Tab', (tester) async {
    var opened = 0;
    await _pump(tester, _frame(Notice(
        message: _notAllowed, tone: NoticeTone.warning, actionLabel: _openMyData, onAction: () => opened++)));
    await tester.tap(find.text(_openMyData));
    expect(opened, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<Button>()?.label,
        _openMyData);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(opened, 3);
  });

  testWidgets('without an action nothing in it takes focus, and it cannot be dismissed', (tester) async {
    await _pump(tester, _frame(const Notice(message: _range)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused == null || focused.findAncestorWidgetOfExactType<Notice>() == null, isTrue);
    expect(find.byType(Button), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('an action needs both a label and a callback', (tester) async {
    expect(() => Notice(message: _range, actionLabel: _openMyData), throwsAssertionError);
    expect(() => Notice(message: _range, onAction: () {}), throwsAssertionError);
  });

  testWidgets('semantics: a polite live region named by the words; the icon is silent; the button is its own node',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _frame(
        const Notice(message: _refused, tone: NoticeTone.warning, actionLabel: _openSettings, onAction: _noop)));
    final node = tester.getSemantics(find.byType(Notice));
    expect(node.label, _refused);
    expect(node.flagsCollection.isLiveRegion, isTrue);
    // The words are said once, by the live region, not again by the text.
    expect(find.bySemanticsLabel(_refused), findsOneWidget);
    // No icon name: the tone is never the only signal.
    expect(find.bySemanticsLabel(RegExp('info|warning', caseSensitive: false)), findsNothing);
    expect(
      tester.getSemantics(find.byType(Button)),
      matchesSemantics(
        label: _openSettings,
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

  testWidgets('new words update the live region label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _frame(const Notice(message: _range)));
    expect(tester.getSemantics(find.byType(Notice)).label, _range);
    await _pump(tester, _frame(const Notice(message: _outside)));
    expect(tester.getSemantics(find.byType(Notice)).label, _outside);
    handle.dispose();
  });

  testWidgets('stack: space-2 between notices, space-4 below the last; nothing at all with no notices',
      (tester) async {
    await _pump(tester, _frame(Column(mainAxisSize: MainAxisSize.min, children: [
      const NoticeStack(notices: [Notice(message: _range), Notice(message: _notReadYet)]),
      Container(key: const Key('content'), height: MyDataSize.rowHeight),
    ])));
    final notices = find.byType(Notice);
    final first = tester.getRect(notices.at(0));
    final second = tester.getRect(notices.at(1));
    expect(second.top, first.bottom + Notice.stackGap(kiwiLook));
    expect(tester.getRect(find.byKey(const Key('content'))).top, second.bottom + Notice.contentGap(kiwiLook));
    expect(first.width, MyDataSize.contentMax);

    await _pump(tester, _frame(Column(mainAxisSize: MainAxisSize.min, children: [
      const NoticeStack(notices: []),
      Container(key: const Key('content'), height: MyDataSize.rowHeight),
    ])));
    expect(tester.getSize(find.byType(NoticeStack)).height, 0);
  });

  testWidgets('no animation: it settles at once, with or without reduced motion', (tester) async {
    for (final reduce in [false, true]) {
      await _pump(tester, _frame(
          const Notice(message: _notAllowed, tone: NoticeTone.warning, actionLabel: _openMyData, onAction: _noop),
          reduceMotion: reduce));
      // A frame or two for the icon font; an animation would take dozens or never settle.
      expect(await tester.pumpAndSettle(), lessThanOrEqualTo(3));
    }
  });
}
