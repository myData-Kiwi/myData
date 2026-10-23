import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

const _token = 'mdk_7Qp2vX9sLr4TgW8nZcA1bY6eH3uJ5kM0';
const _url = 'http://127.0.0.1:47821/mcp';
const _error = 'search_mail: the mail index is not built yet';
const _long =
    'mdk_7Qp2vX9sLr4TgW8nZcA1bY6eH3uJ5kM0aQ8wE2rT6yU1iO9pL3kJ7hG5fD4sA0zX2cV8bN6mQ1wE3rT5yU7iO9pA2sD4fG6hJ8kL0';

/// Holds the clipboard of the test platform.
String? _clipboard;

void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _clipboard = (call.arguments as Map)['text'] as String?;
    if (call.method == 'Clipboard.getData') return {'text': _clipboard};
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

/// A card-like `surface` behind the wells, as in the preview.
Widget _onSurface(Widget child) => Builder(
  builder: (context) => DecoratedBox(
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: MyDataRadii.lg(kiwiLook)),
    child: Padding(padding: const EdgeInsets.all(MyDataSpace.s5), child: child),
  ),
);

Future<void> _pump(WidgetTester tester, Widget child, {double width = 560}) =>
    tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: width, child: child)));

void main() {
  goldenMatrix(
    'mono_well',
    () => SizedBox(
      width: 560,
      child: _onSurface(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoWell(label: 'Token', value: _token, copyLabel: 'Copy token'),
            SizedBox(height: MyDataSpace.s4),
            MonoWell(key: ValueKey('copied'), label: 'MCP URL', value: _url, copyLabel: 'Copy URL'),
            SizedBox(height: MyDataSpace.s4),
            MonoWell(label: 'Error', value: _error),
            SizedBox(height: MyDataSpace.s4),
            MonoWell(label: 'A long token', value: _long, copyLabel: 'Copy token'),
          ],
        ),
      ),
    ),
    size: const Size(608, 448),
    before: (tester) async {
      _mockClipboard(tester);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('copied')), matching: find.byType(Button)));
    },
  );

  testWidgets('the well: surface-sunken, radius-md, no border, space-3 across and space-2 down; mono in ink',
      (tester) async {
    await _pump(tester, const MonoWell(value: _url));
    final c = tester.element(find.byType(MonoWell)).colors;
    final box = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(MonoWell), matching: find.byType(DecoratedBox)).first)
        .decoration as BoxDecoration;
    expect(box.color, c.surfaceSunken);
    expect(box.borderRadius, MyDataRadii.md(kiwiLook));
    expect(box.border, isNull);
    final well = tester.getRect(find.byType(MonoWell));
    final text = tester.getRect(find.byType(SelectableText));
    expect(text.left - well.left, MyDataSpace.s3);
    expect(text.top - well.top, MyDataSpace.s2);
    final style = tester.widget<SelectableText>(find.byType(SelectableText)).style!;
    expect(style.fontFamily, MyDataType.mono.fontFamily);
    expect(style.fontSize, MyDataType.mono.fontSize);
    expect(style.color, c.ink);
    expect(find.byType(Button), findsNothing);
  });

  testWidgets('a label sits above in label style and ink, space-2 above the well', (tester) async {
    await _pump(tester, const MonoWell(label: 'Token', value: _token));
    final c = tester.element(find.byType(MonoWell)).colors;
    final label = tester.widget<Text>(find.text('Token'));
    expect(label.style!.fontSize, MyDataType.label.fontSize);
    expect(label.style!.fontWeight, MyDataType.label.fontWeight);
    expect(label.style!.color, c.ink);
    final well = tester.getRect(find.descendant(of: find.byType(MonoWell), matching: find.byType(DecoratedBox)).first);
    expect(well.top - tester.getRect(find.text('Token')).bottom, MonoWell.gap(kiwiLook));
  });

  testWidgets('Copy puts the value on the clipboard, reads Copied and announces it, until the value changes',
      (tester) async {
    _mockClipboard(tester);
    await _pump(tester, const MonoWell(value: _token, copyLabel: 'Copy token'));
    final button = tester.widget<Button>(find.byType(Button).last);
    expect(button.variant, ButtonVariant.tonal);
    final before = tester.getSize(find.byType(Button).last);
    final wellRect = tester.getRect(find.descendant(of: find.byType(MonoWell), matching: find.byType(DecoratedBox)).first);
    expect(tester.getRect(find.byType(Button).last).left - wellRect.right, MonoWell.gap(kiwiLook));

    await tester.tap(find.text('Copy token'));
    await tester.pump();
    expect(_clipboard, _token);
    expect(find.text(MonoWell.copiedLabel), findsOneWidget);
    expect(find.text('Copy token'), findsNothing);
    expect(tester.takeAnnouncements().map((a) => a.message), [MonoWell.copiedLabel]);
    // The button keeps its width, so the well does not shift.
    expect(tester.getSize(find.byType(Button).last), before);

    // The same value: still Copied. A new value: the button offers to copy again.
    await _pump(tester, const MonoWell(value: _token, copyLabel: 'Copy token'));
    expect(find.text(MonoWell.copiedLabel), findsOneWidget);
    await _pump(tester, const MonoWell(value: _url, copyLabel: 'Copy token'));
    expect(find.text('Copy token'), findsOneWidget);
  });

  testWidgets('neither the copy label nor Copied is cut short', (tester) async {
    _mockClipboard(tester);
    bool cut() => tester
        .renderObject<RenderParagraph>(find.descendant(of: find.byType(Button), matching: find.byType(RichText)))
        .didExceedMaxLines;
    await _pump(tester, const MonoWell(value: _token, copyLabel: 'Copy token'));
    expect(cut(), isFalse);
    await tester.tap(find.byType(Button));
    await tester.pump();
    expect(find.text(MonoWell.copiedLabel), findsOneWidget);
    expect(cut(), isFalse);
  });

  testWidgets('the copy button is the keyboard target; the well is not a Tab stop', (tester) async {
    _mockClipboard(tester);
    await _pump(tester, const MonoWell(value: _token, copyLabel: 'Copy token'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_clipboard, _token);
  });

  testWidgets('a long unbroken token wraps inside the well at any character', (tester) async {
    await _pump(tester, const MonoWell(value: _long, copyLabel: 'Copy token'), width: 320);
    expect(tester.takeException(), isNull);
    final well = tester.getRect(find.descendant(of: find.byType(MonoWell), matching: find.byType(DecoratedBox)).first);
    final text = tester.getRect(find.byType(SelectableText));
    expect(text.right, lessThanOrEqualTo(well.right - MyDataSpace.s3));
    final line = MyDataType.mono.fontSize! * MyDataType.mono.height!;
    expect(text.height, greaterThan(line * 3));
    // Every line but the last is filled: the token breaks at any character.
    final lines = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable
        .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: _long.length));
    expect(lines.length, greaterThan(3));
    for (final l in lines.take(lines.length - 1)) {
      expect(l.right - l.left, greaterThan(text.width - 2 * MyDataType.mono.fontSize!));
    }
  });

  testWidgets('selecting all and copying gives the value exactly', (tester) async {
    _mockClipboard(tester);
    await _pump(tester, const MonoWell(value: _long), width: 320);
    // Click into the well (focusing it), then select all and copy with the keyboard.
    await tester.tap(find.byType(SelectableText));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(_clipboard, _long);
  });

  testWidgets('the value can be found as written, by tests and by screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const MonoWell(value: _token));
    expect(find.text(_token), findsOneWidget);
    final node = tester.getSemantics(find.byType(EditableText));
    expect('${node.label}${node.value}', _token);
    handle.dispose();
  });
}
