import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoDesktopTextSelectionToolbar, CupertinoDesktopTextSelectionToolbarButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented values only: example.com addresses, reserved phone ranges (UK 07700 900xxx, US 555-01xx).

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

final _opened = <Uri>[];
void _open(Uri url) => _opened.add(url);

final _kiwi = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;

Future<void> _pump(WidgetTester tester, Widget child, {double width = 480, bool reduceMotion = false}) =>
    tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(width: width, child: child),
        reduceMotion: reduceMotion,
      ),
    );

Finder _copyButton(Finder row) => find.descendant(of: row, matching: find.byType(Pressable)).last;

IconData? _copyIcon(WidgetTester tester, Finder row) =>
    tester.widget<Icon>(find.descendant(of: _copyButton(row), matching: find.byType(Icon))).icon;

String _tooltip(WidgetTester tester, Finder row) {
  final t = tester.widget<Tooltip>(find.descendant(of: row, matching: find.byType(Tooltip)));
  return t.message ?? t.richMessage!.toPlainText();
}

/// A contact's page as in the preview: the left column holds Phone, Email and Address; the right column
/// Birthday, Links and Notes. The work number has just been copied.
Widget _page() => SizedBox(
  width: 824,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        child: FieldGroups(
          fields: [
            FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
            FieldRow(key: ValueKey('copied'), kind: FieldKind.phone, label: 'Work', value: '+1 555 0142'),
            FieldRow(kind: FieldKind.email, label: 'Home', value: 'ava.fictional@example.com'),
            FieldRow(kind: FieldKind.email, label: 'Work', value: 'ava@example.com'),
            FieldRow(
              kind: FieldKind.address,
              label: 'Home',
              value: '12 Sample Street\nExampleton ZZ1 2AB\nUnited Kingdom',
            ),
          ],
        ),
      ),
      const SizedBox(width: MyDataSpace.s6),
      Expanded(
        child: FieldGroups(
          fields: [
            FieldRow(kind: FieldKind.birthday, value: formatBirthday('--05-12')!),
            const FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com/ava', onOpenLink: _open),
            const FieldRow(
              kind: FieldKind.link,
              label: 'Other',
              value: 'x-example-app://open?id=ava',
              onOpenLink: _open,
            ),
            const FieldRow(kind: FieldKind.note, value: 'Met at the example meetup.\nPrefers calls in the morning.'),
          ],
        ),
      ),
    ],
  ),
);

/// The states the page does not show: keyboard focus on a copy button, the pointer over a copied button
/// (its tooltip reads Copied), a custom label, a long value wrapping, and links that are not safe.
Widget _states() => SizedBox(
  width: 400,
  child: FieldGroup(
    heading: 'States',
    rows: const [
      FieldRow(key: ValueKey('focused'), kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900456'),
      FieldRow(key: ValueKey('hovered'), kind: FieldKind.phone, label: "Partner's work", value: '+1 555 0199'),
      FieldRow(
        kind: FieldKind.email,
        label: 'Other',
        value: 'a.very.long.example.address.that.does.not.fit.on.one.line@subdomain.example.com',
      ),
      FieldRow(kind: FieldKind.link, label: 'Home page', value: 'javascript:alert(1)', onOpenLink: _open),
      FieldRow(kind: FieldKind.link, label: 'Files', value: 'file:///Users/example/notes.txt', onOpenLink: _open),
    ],
  ),
);

/// A link with keyboard focus (the label and the value are its target) above a long link that wraps, with
/// the pointer over it (no fill: a link only changes the cursor).
Widget _links() => SizedBox(
  width: 400,
  child: FieldGroup(
    heading: 'Links',
    rows: const [
      FieldRow(kind: FieldKind.link, label: 'Website', value: 'https://example.com/ava', onOpenLink: _open),
      FieldRow(
        key: ValueKey('long'),
        kind: FieldKind.link,
        label: 'Blog',
        value: 'https://blog.example.org/2026/10/a-post-with-a-long-address-that-wraps',
        onOpenLink: _open,
      ),
    ],
  ),
);

Future<void> _keyboardMode(WidgetTester tester) async {
  tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => tester.binding.focusManager.highlightStrategy = FocusHighlightStrategy.automatic);
}

void main() {
  goldenMatrix(
    'field_row',
    _page,
    size: const Size(872, 560),
    before: (tester) async {
      _mockClipboard(tester);
      await tester.tap(_copyButton(find.byKey(const ValueKey('copied'))));
    },
  );

  goldenMatrix(
    'field_row_states',
    _states,
    size: const Size(448, 520),
    before: (tester) async {
      _mockClipboard(tester);
      await _keyboardMode(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final hovered = _copyButton(find.byKey(const ValueKey('hovered')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(hovered));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.down(tester.getCenter(hovered));
      await mouse.up();
      await tester.pump();
      // Away and back again, so its tooltip shows: Copied.
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(hovered));
      await tester.pump();
    },
  );

  goldenMatrix(
    'field_row_links',
    _links,
    size: const Size(448, 280),
    before: (tester) async {
      await _keyboardMode(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.textContaining('a-post-with')));
      addTearDown(mouse.removePointer);
      await tester.pump();
    },
  );

  group('safeWebLink', () {
    test('http and https addresses are links, in any case, exactly as written', () {
      expect(safeWebLink('https://example.com/ava'), Uri.parse('https://example.com/ava'));
      expect(safeWebLink('http://example.com'), Uri.parse('http://example.com'));
      expect(safeWebLink('HTTPS://Example.COM/Ava')?.host, 'example.com');
      expect(safeWebLink('  https://example.com/ava  '), Uri.parse('https://example.com/ava'));
      expect(safeWebLink('https://example.com:8443/a?b=c#d'), Uri.parse('https://example.com:8443/a?b=c#d'));
      // With an explicit scheme, any host: a machine name, an IP address.
      expect(safeWebLink('http://localhost:3000'), isNotNull);
      expect(safeWebLink('http://192.0.2.10/status'), isNotNull);
      expect(safeWebLink('http://[2001:db8::1]/'), isNotNull);
    });

    test('a bare host name with a dot opens with https:// added', () {
      expect(safeWebLink('example.com/ava'), Uri.parse('https://example.com/ava'));
      expect(safeWebLink('www.example.org'), Uri.parse('https://www.example.org'));
      expect(safeWebLink('example.com:8080/x'), Uri.parse('https://example.com:8080/x'));
      expect(safeWebLink('sub.example.co.uk?q=1'), Uri.parse('https://sub.example.co.uk?q=1'));
      expect(safeWebLink('xn--bcher-kva.example'), isNotNull);
    });

    test('no other scheme is ever a link', () {
      for (final v in [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        ' javascript:alert(1)',
        'javascript://example.com/%0Aalert(1)',
        'file:///etc/hosts',
        'file://example.com/share',
        'data:text/html,<script>alert(1)</script>',
        'data:text/html;base64,PHNjcmlwdD4=',
        'mailto:ava@example.com',
        'tel:+15550142',
        'ftp://example.com/file',
        'x-example-app://open?id=ava',
        'mycontacts://contact/abc',
        'vbscript:msgbox(1)',
        'blob:https://example.com/uuid',
        'about:blank',
      ]) {
        expect(safeWebLink(v), isNull, reason: v);
      }
    });

    test('values that do not parse as a web address are not links', () {
      for (final v in [
        '',
        '   ',
        'Example Labs',
        'example',
        'localhost:3000',
        '1.5',
        '12.05.1990',
        '192.0.2.10',
        'e.g.',
        'example.com.',
        '.example.com',
        '-example.com',
        'exa mple.com',
        'https://exa mple.com',
        'java\nscript:alert(1)',
        'https://example.com/\u0000',
        r'example.com\@evil.example',
        '//example.com/ava',
        '/ava',
        'https:example.com',
        'https:/example.com',
        'https:///example.com',
        'https://',
        'ava@example.com',
        'https://user:secret@example.com',
        'https://example.com@evil.example',
        'https://bad_host.example',
        'https://x' * 1200,
      ]) {
        expect(safeWebLink(v), isNull, reason: v);
      }
    });
  });

  group('formatBirthday', () {
    test('the long form without a weekday; without a year, the day and month', () {
      expect(formatBirthday('1990-05-12'), '12 May 1990');
      expect(formatBirthday('--05-12'), '12 May');
      expect(formatBirthday('--0512'), '12 May');
      expect(formatBirthday('2000-01-01'), '1 January 2000');
      expect(formatBirthday('--02-29'), '29 February');
      expect(formatBirthday('2004-02-29'), '29 February 2004');
    });

    test('not a real date: null', () {
      for (final v in ['', 'May 12', '1990-13-01', '1990-00-10', '1990-04-31', '2001-02-29', '--02-30', '12/05/1990']) {
        expect(formatBirthday(v), isNull, reason: v);
      }
    });
  });

  group('FieldRow.copyNameFor', () {
    test('the names in the preview', () {
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Mobile'), 'Copy mobile number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Work'), 'Copy work number');
      expect(FieldRow.copyNameFor(FieldKind.email, 'Home'), 'Copy home email');
      expect(FieldRow.copyNameFor(FieldKind.address, 'Home'), 'Copy home address');
      expect(FieldRow.copyNameFor(FieldKind.birthday, null), 'Copy birthday');
      expect(FieldRow.copyNameFor(FieldKind.link, 'Website'), 'Copy website');
      expect(FieldRow.copyNameFor(FieldKind.link, 'Other'), 'Copy other link');
      expect(FieldRow.copyNameFor(FieldKind.note, null), 'Copy notes');
    });

    test('no label, a label that names the thing, and custom labels', () {
      expect(FieldRow.copyNameFor(FieldKind.phone, null), 'Copy phone number');
      expect(FieldRow.copyNameFor(FieldKind.phone, ''), 'Copy phone number');
      expect(FieldRow.copyNameFor(FieldKind.email, null), 'Copy email');
      expect(FieldRow.copyNameFor(FieldKind.link, null), 'Copy link');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Work fax'), 'Copy work fax');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Fax'), 'Copy fax');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Pager'), 'Copy pager');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Main'), 'Copy main number');
      expect(FieldRow.copyNameFor(FieldKind.link, 'Home page'), 'Copy home page');
      expect(FieldRow.copyNameFor(FieldKind.email, 'School'), 'Copy school email');
    });

    test('only the host\'s sentence-case built-ins are lower-cased; every other label is used as written', () {
      // Names, the host's own among them.
      expect(FieldRow.copyNameFor(FieldKind.phone, 'iPhone'), 'Copy iPhone number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Apple Watch'), 'Copy Apple Watch number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Google Voice'), 'Copy Google Voice number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Skype'), 'Copy Skype number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'VoIP'), 'Copy VoIP number');
      expect(FieldRow.copyNameFor(FieldKind.link, 'Facebook'), 'Copy Facebook link');
      // Custom labels, exactly as written.
      expect(FieldRow.copyNameFor(FieldKind.phone, "Partner's work"), "Copy Partner's work number");
      expect(FieldRow.copyNameFor(FieldKind.email, 'Work email'), 'Copy Work email');
      expect(FieldRow.copyNameFor(FieldKind.link, 'blog'), 'Copy blog');
      // A built-in only when it is the whole label, in the host's own case.
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Home Assistant'), 'Copy Home Assistant number');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'MOBILE'), 'Copy MOBILE number');
    });

    test('a label names the thing only with a whole last word, not a word ending in one', () {
      expect(FieldRow.copyNameFor(FieldKind.email, 'Gmail'), 'Copy Gmail email');
      expect(FieldRow.copyNameFor(FieldKind.email, 'Hotmail'), 'Copy Hotmail email');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Smartphone'), 'Copy Smartphone number');
      expect(FieldRow.copyNameFor(FieldKind.link, 'Portfolio site'), 'Copy Portfolio site');
      expect(FieldRow.copyNameFor(FieldKind.email, 'Work e-mail'), 'Copy Work e-mail');
      expect(FieldRow.copyNameFor(FieldKind.phone, 'Car phone'), 'Copy Car phone');
    });
  });

  group('FieldRow', () {
    testWidgets('row-height, space-4 across and space-2 down; label in caption ink-muted above the value in body ink', (
      tester,
    ) async {
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      final row = tester.getRect(find.byType(FieldRow));
      expect(row.height, greaterThanOrEqualTo(MyDataSize.rowHeight));
      final label = tester.widget<Text>(find.text('Mobile'));
      expect(label.style!.fontSize, MyDataType.caption.fontSize);
      expect(label.style!.color, _kiwi.inkMuted);
      final value = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(value.data, '+44 7700 900123');
      expect(value.style!.fontSize, MyDataType.body.fontSize);
      expect(value.style!.fontWeight, MyDataType.body.fontWeight);
      expect(value.style!.color, _kiwi.ink);
      final labelRect = tester.getRect(find.text('Mobile'));
      final valueRect = tester.getRect(find.byType(SelectableText));
      expect(labelRect.left - row.left, MyDataSpace.s4);
      expect(valueRect.left, labelRect.left);
      expect(valueRect.top, labelRect.bottom);
      final button = tester.getRect(_copyButton(find.byType(FieldRow)));
      expect(button.size, const Size.square(MyDataSize.controlHeight));
      expect(row.right - button.right, MyDataSpace.s4);
      expect(button.top - row.top, greaterThanOrEqualTo(MyDataSpace.s2));
      expect(row.bottom - button.bottom, greaterThanOrEqualTo(MyDataSpace.s2));
    });

    testWidgets('a value with no label has no label line', (tester) async {
      await _pump(tester, const FieldRow(kind: FieldKind.birthday, value: '12 May'));
      expect(find.byType(Text), findsNothing); // only the SelectableText (and the icon)
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: '  ', value: '+1 555 0142'));
      expect(find.text('  '), findsNothing);
      final row = tester.getRect(find.byType(FieldRow));
      expect(row.height, MyDataSize.controlHeight + 2 * MyDataSpace.s2);
    });

    testWidgets('an address keeps its lines and a note its line breaks', (tester) async {
      const address = '12 Sample Street\nExampleton ZZ1 2AB\nUnited Kingdom';
      await _pump(tester, const FieldRow(kind: FieldKind.address, label: 'Home', value: address));
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, address);
      final line = MyDataType.body.fontSize! * MyDataType.body.height!;
      expect(tester.getSize(find.byType(SelectableText)).height, closeTo(3 * line, 1));
    });

    testWidgets('a long value wraps inside the row, never under the copy button', (tester) async {
      const long = 'a.very.long.example.address.that.does.not.fit.on.one.line@subdomain.example.com';
      await _pump(tester, const FieldRow(kind: FieldKind.email, label: 'Other', value: long), width: 320);
      expect(tester.takeException(), isNull);
      final value = tester.getRect(find.byType(SelectableText));
      final button = tester.getRect(_copyButton(find.byType(FieldRow)));
      expect(value.right, lessThanOrEqualTo(button.left - FieldRow.gap(kiwiLook)));
      expect(value.height, greaterThan(MyDataType.body.fontSize! * MyDataType.body.height! * 1.5));
    });

    testWidgets('the copy button: a plain round icon button in ink-muted, surface-hover on hover', (tester) async {
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      final row = find.byType(FieldRow);
      final pressable = tester.widget<Pressable>(_copyButton(row));
      expect(pressable.borderRadius, MyDataRadii.pill(kiwiLook));
      expect(pressable.hoverFill, _kiwi.surfaceHover);
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.copy));
      expect(tester.widget<Icon>(find.byType(Icon)).color, _kiwi.inkMuted);
      expect(tester.widget<Icon>(find.byType(Icon)).size, MyDataSize.icon);
      expect(_tooltip(tester, row), 'Copy mobile number');
      // The row has no hover fill: the copy button is its only target, and the only Pressable.
      expect(find.byType(Pressable), findsOneWidget);
    });

    testWidgets('Copy puts the value on the clipboard exactly; the icon becomes a check, the tooltip reads Copied, '
        'screen readers hear Copied', (tester) async {
      _mockClipboard(tester);
      final handle = tester.ensureSemantics();
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      final row = find.byType(FieldRow);
      expect(tester.getSemantics(_copyButton(row)).label, 'Copy mobile number');
      await tester.tap(_copyButton(row));
      await tester.pump();
      expect(_clipboard, '+44 7700 900123');
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));
      expect(_tooltip(tester, row), FieldRow.copiedLabel);
      expect(tester.takeAnnouncements().map((a) => a.message), [FieldRow.copiedLabel]);
      final node = tester.getSemantics(_copyButton(row));
      expect(node.label, 'Copy mobile number');
      expect(node.value, FieldRow.copiedLabel);
      handle.dispose();
    });

    testWidgets('Copied stays until another row copies something, or the value changes', (tester) async {
      _mockClipboard(tester);
      Widget two(String first) => Column(
        children: [
          FieldRow(key: const ValueKey('a'), kind: FieldKind.phone, label: 'Mobile', value: first),
          const FieldRow(key: ValueKey('b'), kind: FieldKind.email, label: 'Home', value: 'ava@example.com'),
        ],
      );
      final a = find.byKey(const ValueKey('a'));
      final b = find.byKey(const ValueKey('b'));
      await _pump(tester, two('+44 7700 900123'));
      await tester.tap(_copyButton(a));
      await tester.pump();
      expect(_copyIcon(tester, a), iconOf(MyDataIcon.check));
      // Rebuilt with the same value: still copied.
      await _pump(tester, two('+44 7700 900123'));
      expect(_copyIcon(tester, a), iconOf(MyDataIcon.check));
      await tester.tap(_copyButton(b));
      await tester.pump();
      expect(_clipboard, 'ava@example.com');
      expect(_copyIcon(tester, a), iconOf(MyDataIcon.copy));
      expect(_tooltip(tester, a), 'Copy mobile number');
      expect(_copyIcon(tester, b), iconOf(MyDataIcon.check));
      // A new value in the copied row: it offers to copy again.
      await _pump(tester, two('+44 7700 900999'));
      expect(_copyIcon(tester, b), iconOf(MyDataIcon.check));
      await _pump(
        tester,
        Column(
          children: [
            const FieldRow(key: ValueKey('a'), kind: FieldKind.phone, label: 'Mobile', value: '+1 555 0100'),
            const FieldRow(key: ValueKey('b'), kind: FieldKind.email, label: 'Home', value: 'ava.new@example.com'),
          ],
        ),
      );
      expect(_copyIcon(tester, b), iconOf(MyDataIcon.copy));
    });

    testWidgets('keyboard: the value is not a Tab stop; the copy button is, and Enter and Space copy', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('FieldRow value'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_clipboard, '+44 7700 900123');
      _clipboard = null;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_clipboard, '+44 7700 900123');
    });

    testWidgets('a safe web address is a link in `link`, underlined, shown as written, opened through the opener', (
      tester,
    ) async {
      _opened.clear();
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com/ava', onOpenLink: _open),
      );
      final text = tester.widget<Text>(find.text('example.com/ava'));
      expect(text.style!.color, _kiwi.link);
      expect(text.style!.decoration, TextDecoration.underline);
      expect(text.style!.fontSize, MyDataType.body.fontSize);
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.text('example.com/ava'));
      await tester.pump();
      expect(_opened, [Uri.parse('https://example.com/ava')]);
    });

    testWidgets('the link target is at least 44px and does not make the row taller; it is apart from the copy button', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            FieldRow(
              key: ValueKey('link'),
              kind: FieldKind.link,
              label: 'Website',
              value: 'example.com',
              onOpenLink: _open,
            ),
            FieldRow(key: ValueKey('plain'), kind: FieldKind.email, label: 'Home', value: 'ava@example.com'),
          ],
        ),
      );
      final link = find.descendant(of: find.byKey(const ValueKey('link')), matching: find.byType(Pressable)).first;
      final target = tester.getRect(link);
      expect(target.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(target.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(
        tester.getSize(find.byKey(const ValueKey('link'))).height,
        tester.getSize(find.byKey(const ValueKey('plain'))).height,
      );
      final copy = tester.getRect(_copyButton(find.byKey(const ValueKey('link'))));
      expect(target.right, lessThanOrEqualTo(copy.left));
      // The link's text sits where a plain value's would.
      expect(
        tester.getTopLeft(find.text('Website')).dy - tester.getTopLeft(find.byKey(const ValueKey('link'))).dy,
        tester.getTopLeft(find.text('Home')).dy - tester.getTopLeft(find.byKey(const ValueKey('plain'))).dy,
      );
    });

    testWidgets('keyboard on a link row: Tab reaches the link, Enter opens it; Tab again reaches Copy', (tester) async {
      _mockClipboard(tester);
      _opened.clear();
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.link, label: 'Website', value: 'https://example.com/ava', onOpenLink: _open),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_opened, [Uri.parse('https://example.com/ava')]);
      expect(_clipboard, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_clipboard, 'https://example.com/ava');
      expect(_opened, hasLength(1));
    });

    testWidgets('screen readers hear the link as a link, with its label and address', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com/ava', onOpenLink: _open),
      );
      expect(find.bySemanticsLabel('Website, example.com/ava'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('Website, example.com/ava'));
      expect(node.flagsCollection.isLink, isTrue);
      expect(node.linkUrl, Uri.parse('https://example.com/ava'));
      handle.dispose();
    });

    testWidgets('an unsafe or non-web value is plain ink text that nothing opens, still selectable and copyable', (
      tester,
    ) async {
      _mockClipboard(tester);
      _opened.clear();
      for (final v in [
        'javascript:alert(1)',
        'file:///etc/hosts',
        'data:text/html,hi',
        'mailto:ava@example.com',
        'x-example-app://open?id=ava',
        'not a link',
      ]) {
        await _pump(tester, FieldRow(kind: FieldKind.link, label: 'Other', value: v, onOpenLink: _open));
        final text = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(text.data, v);
        expect(text.style!.color, _kiwi.ink);
        expect(text.style!.decoration, isNot(TextDecoration.underline));
        await tester.tap(find.byType(SelectableText));
        await tester.pump();
        expect(_opened, isEmpty, reason: v);
        await tester.tap(_copyButton(find.byType(FieldRow)));
        await tester.pump();
        expect(_clipboard, v);
      }
    });

    testWidgets('only a link-kind value can be a link, and only with an opener', (tester) async {
      await _pump(tester, const FieldRow(kind: FieldKind.note, value: 'example.com/ava', onOpenLink: _open));
      expect(find.byType(SelectableText), findsOneWidget);
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.email, label: 'Home', value: 'ava@example.com', onOpenLink: _open),
      );
      expect(find.byType(SelectableText), findsOneWidget);
      await _pump(tester, const FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com/ava'));
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(Pressable), findsOneWidget);
    });

    testWidgets('right-click on the row offers Copy, which copies the value; a tap elsewhere closes the menu', (
      tester,
    ) async {
      _mockClipboard(tester);
      await _pump(
        tester,
        const Column(
          children: [
            FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
            SizedBox(height: 200),
          ],
        ),
      );
      final row = find.byType(FieldRow);
      await tester.tapAt(tester.getCenter(find.text('Mobile')) + const Offset(200, 0), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, '+44 7700 900123');
      expect(find.text(FieldRow.copyMenuLabel), findsNothing);
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));

      // Open it on the label, then click away.
      await tester.tapAt(tester.getCenter(find.text('Mobile')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.tapAt(tester.getBottomLeft(row) + const Offset(10, 100));
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsNothing);
    });

    testWidgets('right-click on the value itself offers the row\'s Copy: the whole value, and Copied', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      final row = find.byType(FieldRow);
      await tester.tapAt(tester.getCenter(find.byType(SelectableText)), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, '+44 7700 900123');
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));
      expect(find.text(FieldRow.copyMenuLabel), findsNothing);
    });

    testWidgets('a long press on the value on a touch screen offers the row\'s Copy', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      final row = find.byType(FieldRow);
      await tester.longPressAt(tester.getCenter(find.byType(SelectableText)));
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, '+44 7700 900123');
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));
    }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

    testWidgets('Escape closes the row\'s menu and gives focus back', (tester) async {
      _mockClipboard(tester);
      await _keyboardMode(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      await tester.tapAt(tester.getCenter(find.text('Mobile')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsNothing);
      expect(FocusManager.instance.primaryFocus, before);
      expect(_clipboard, isNull);
    });

    testWidgets('Escape closes the value\'s menu', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
      await tester.tapAt(tester.getCenter(find.byType(SelectableText)), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(FieldRow.copyMenuLabel), findsNothing);
      expect(_clipboard, isNull);
    });

    testWidgets('a long press on a touch screen offers Copy', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.email, label: 'Home', value: 'ava@example.com'));
      await tester.longPressAt(tester.getCenter(find.text('Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, 'ava@example.com');
    });

    testWidgets('right-click on a link offers Copy and does not open it', (tester) async {
      _mockClipboard(tester);
      _opened.clear();
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com/ava', onOpenLink: _open),
      );
      await tester.tapAt(tester.getCenter(find.text('example.com/ava')), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(_opened, isEmpty);
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, 'example.com/ava');
    });

    testWidgets('reduced motion: pressing the copy button does not scale it', (tester) async {
      await _pump(
        tester,
        const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+1 555 0142'),
        reduceMotion: true,
      );
      expect(
        find.descendant(of: _copyButton(find.byType(FieldRow)), matching: find.byType(AnimatedScale)),
        findsNothing,
      );
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+1 555 0142'));
      expect(
        find.descendant(of: _copyButton(find.byType(FieldRow)), matching: find.byType(AnimatedScale)),
        findsOneWidget,
      );
    });
  });

  group('FieldGroups', () {
    testWidgets('one group per kind in the spec order, headed in label and ink-muted, space-6 apart', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        const FieldGroups(
          fields: [
            FieldRow(kind: FieldKind.note, value: 'A note.'),
            FieldRow(kind: FieldKind.link, label: 'Website', value: 'example.com'),
            FieldRow(kind: FieldKind.birthday, value: '12 May'),
            FieldRow(kind: FieldKind.address, label: 'Home', value: '1 Example Road'),
            FieldRow(kind: FieldKind.email, label: 'Home', value: 'ava@example.com'),
            FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
            FieldRow(kind: FieldKind.phone, label: 'Work', value: '+1 555 0142'),
          ],
        ),
      );
      final headings = ['Phone', 'Email', 'Address', 'Birthday', 'Links', 'Notes'];
      final tops = [for (final h in headings) tester.getTopLeft(find.text(h)).dy];
      expect([...tops]..sort(), tops);
      final heading = tester.widget<Text>(find.text('Phone'));
      expect(heading.style!.fontWeight, MyDataType.label.fontWeight);
      expect(heading.style!.color, _kiwi.inkMuted);
      // Within a kind, the order given.
      expect(
        tester.getTopLeft(find.text('+44 7700 900123')).dy,
        lessThan(tester.getTopLeft(find.text('+1 555 0142')).dy),
      );
      final groups = find.byType(FieldGroup);
      expect(groups, findsNWidgets(6));
      expect(tester.getTopLeft(groups.at(1)).dy - tester.getBottomLeft(groups.at(0)).dy, FieldGroups.gap(kiwiLook));
    });

    testWidgets('a kind with no values, or only empty values, is left out entirely: no Notes from This Mac', (
      tester,
    ) async {
      await _pump(
        tester,
        const FieldGroups(
          fields: [
            FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
            FieldRow(kind: FieldKind.email, label: 'Home', value: '  '),
            FieldRow(kind: FieldKind.note, value: ''),
          ],
        ),
      );
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Notes'), findsNothing);
      expect(find.byType(FieldRow), findsOneWidget);
      expect(find.byType(FieldGroup), findsOneWidget);
    });

    testWidgets('rows in a group are separated by a full-width line divider', (tester) async {
      await _pump(
        tester,
        FieldGroup(
          rows: const [
            FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
            FieldRow(kind: FieldKind.phone, label: 'Work', value: '+1 555 0142'),
          ],
        ),
      );
      final dividers = find.descendant(
        of: find.byType(FieldGroup),
        matching: find.byWidgetPredicate((w) => w is Container && w.color == _kiwi.line),
      );
      expect(dividers, findsOneWidget);
      expect(tester.getSize(dividers).width, tester.getSize(find.byType(FieldGroup)).width);
    });
  });

  group('on a Mac, right-click on the value', () {
    final mac = TargetPlatformVariant.only(TargetPlatform.macOS);
    const value = '+44 7700 900123';

    // The value's text geometry, for clicking on one word of it.
    Offset at(WidgetTester tester, String part) {
      final box = tester.getRect(find.byType(SelectableText));
      final fraction = (value.indexOf(part) + part.length / 2) / value.length;
      return Offset(box.left + box.width * fraction, box.center.dy);
    }

    testWidgets('with nothing selected: one item, Copy, which copies the whole value and says Copied', (tester) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: value));
      final row = find.byType(FieldRow);
      await tester.tapAt(at(tester, '7700'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsOneWidget);
      // The whole value is shown selected, since that is what Copy copies; not the word under the pointer.
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)).textEditingValue.selection,
        const TextSelection(baseOffset: 0, extentOffset: value.length),
      );
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, value);
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));
      expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsNothing);
    }, variant: mac);

    testWidgets('with a selection the user made: the platform text menu, whose Copy copies that selection', (
      tester,
    ) async {
      _mockClipboard(tester);
      await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: value));
      final row = find.byType(FieldRow);
      // A double-click selects the word "7700".
      final word = at(tester, '7700');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: word);
      addTearDown(mouse.removePointer);
      await mouse.down(word);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.down(word);
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.tapAt(word, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(_clipboard, '7700');
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.copy));

      // A right-click on another word, outside that selection, is the row's Copy again.
      await tester.tapAt(at(tester, '900123'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsOneWidget);
      await tester.tap(find.text(FieldRow.copyMenuLabel));
      await tester.pumpAndSettle();
      expect(_clipboard, value);
      expect(_copyIcon(tester, row), iconOf(MyDataIcon.check));
    }, variant: mac);
  });

  // The context menu is the platform's own (design/platforms.md), so it has no golden: its label is drawn in
  // the system font, which tests cannot render. These check that a Mac gets its desktop menu with one item.
  testWidgets('on a Mac, right-click shows the platform desktop menu with one item, Copy', (tester) async {
    _mockClipboard(tester);
    await _pump(tester, const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'));
    await tester.tapAt(tester.getCenter(find.text('Mobile')), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsOneWidget);
    expect(find.byType(CupertinoDesktopTextSelectionToolbarButton), findsOneWidget);
    await tester.tap(find.text(FieldRow.copyMenuLabel));
    await tester.pumpAndSettle();
    expect(_clipboard, '+44 7700 900123');
    expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
