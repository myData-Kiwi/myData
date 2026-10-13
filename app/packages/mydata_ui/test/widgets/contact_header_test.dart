import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented people and places only: example.com addresses and the UK's reserved drama numbers (07700 900xxx).

const _mac = 'From this Mac. Change it in Contacts.';
const _icloud = 'From the iCloud account you@example.com. Change it in your iCloud account.';

/// A made-up portrait, drawn like the preview's: a head and shoulders on cream. Test data, not a token.
late ui.Image _portrait;

Future<ui.Image> _drawPortrait() {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFFFBF7EC));
  final skin = Paint()..color = const Color(0xFF6B4F35);
  canvas.drawCircle(const Offset(48, 38), 17, skin);
  canvas.drawPath(
      Path()
        ..moveTo(14, 96)
        ..cubicTo(17, 76, 31, 65, 48, 65)
        ..cubicTo(65, 65, 79, 76, 82, 96)
        ..close(),
      skin);
  return recorder.endRecording().toImage(size.toInt(), size.toInt());
}

/// The portrait, already in memory, so it shows at once.
class _Portrait extends ImageProvider<_Portrait> {
  const _Portrait();

  @override
  Future<_Portrait> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Portrait key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: _portrait.clone())));
}

ContactHeader _ava({String source = _icloud, bool photo = false}) => ContactHeader(
      name: 'Ava Fictional',
      jobTitle: 'Head of research',
      organisation: 'Example Labs',
      sourceLine: source,
      avatar: Avatar(
        name: 'Ava Fictional',
        givenName: 'Ava',
        familyName: 'Fictional',
        size: AvatarSize.large,
        photo: photo ? const _Portrait() : null,
      ),
    );

ContactHeader _labs() => ContactHeader(
      name: 'Example Labs',
      organisation: 'Example Labs',
      sourceLine: _mac,
      avatar: const Avatar(name: 'Example Labs', size: AvatarSize.large),
    );

ContactHeader _orgOnly() => ContactHeader(
      name: 'Sam Sample',
      organisation: 'Sample Bakery',
      sourceLine: _mac,
      avatar: const Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample', size: AvatarSize.large),
    );

ContactHeader _jobOnly() => ContactHeader(
      name: 'Noor Example',
      jobTitle: 'Piano teacher',
      sourceLine: _mac,
      avatar: const Avatar(name: 'Noor Example', givenName: 'Noor', familyName: 'Example', size: AvatarSize.large),
    );

ContactHeader _phoneOnly() => ContactHeader(
      name: '+44 7700 900456',
      sourceLine: _mac,
      avatar: const Avatar(name: '+44 7700 900456', size: AvatarSize.large),
    );

const _longName = 'Maximiliana Wilhelmina Placeholder-Fictional-Examplesworth';

ContactHeader _long() => ContactHeader(
      name: _longName,
      jobTitle: 'Senior coordinator of regional example programmes',
      organisation: 'Example Labs',
      sourceLine: _icloud,
      avatar: const Avatar(
        name: _longName,
        givenName: 'Maximiliana Wilhelmina',
        familyName: 'Placeholder-Fictional-Examplesworth',
        size: AvatarSize.large,
      ),
    );

/// Headers one under another, `space-10` apart, as wide as the frame allows.
Widget _stack(List<Widget> headers) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < headers.length; i++) ...[if (i > 0) const SizedBox(height: MyDataSpace.s10), headers[i]],
      ],
    );

/// Pumps [header] in a window [width] wide, the header [paneWidth] wide (by default, the window less the
/// frame's padding), with the system text size [textScale].
Future<void> _pump(WidgetTester tester, Widget header,
    {double width = 800, double? paneWidth, double textScale = 1, ThemeCase theme = const ThemeCase('kiwi', Brightness.light)}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(themedFrame(theme, SizedBox(width: paneWidth ?? width - 48, child: header)));
  await tester.pumpAndSettle();
}

/// Whether the text sits beside the avatar (rather than under it).
bool _side(WidgetTester tester) => tester.getRect(find.byType(SelectionArea)).left >= _avatarRect(tester).right;

Rect _avatarRect(WidgetTester tester) => tester.getRect(find.byType(Avatar));

void main() {
  setUpAll(() async => _portrait = await _drawPortrait());

  // From 600px: the preview's first header, then the states the spec names: a photo, an organisation's card
  // (no line under the name), the organisation alone, the job title alone, no letters (the person icon) with
  // nothing under the name, and a long name and job title that wrap.
  goldenMatrix(
    'contact_header_wide',
    () => _stack([_ava(), _ava(source: _mac, photo: true), _labs(), _orgOnly(), _jobOnly(), _phoneOnly(), _long()]),
    size: const Size(720, 1080),
  );

  // Under 600px: avatar above, everything centred; the preview's second header, a person with a photo and the
  // long name.
  goldenMatrix(
    'contact_header_phone',
    () => _stack([_labs(), _ava(photo: true), _long()]),
    size: const Size(390, 860),
  );

  // The narrowest two-pane window (600px) leaves the contact pane narrow beside the rail and the list pane: a
  // 280px pane stacks like a phone, even with the long name; a 360px pane, just over sideMinWidth, still puts
  // the text beside the avatar, and the long name breaks between its words.
  goldenMatrix(
    'contact_header_pane',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 280, child: _stack([_ava(), _long()])),
        const SizedBox(height: MyDataSpace.s10),
        SizedBox(width: 360, child: _stack([_ava(photo: true), _long()])),
      ],
    ),
    size: const Size(600, 1180),
  );

  group('roleLine', () {
    String? r(String name, [String job = '', String org = '']) =>
        ContactHeader.roleLine(name: name, jobTitle: job, organisation: org);

    test('the job title and the organisation joined by a comma', () {
      expect(r('Ava Fictional', 'Head of research', 'Example Labs'), 'Head of research, Example Labs');
    });

    test('either one alone', () {
      expect(r('Sam Sample', '', 'Sample Bakery'), 'Sample Bakery');
      expect(r('Noor Example', 'Piano teacher'), 'Piano teacher');
    });

    test('none when the card has neither', () {
      expect(r('Ava Fictional'), isNull);
      expect(r('Ava Fictional', '  ', ' '), isNull);
    });

    test('none when the name shown is the organisation, ignoring case and spaces at the ends', () {
      expect(r('Example Labs', '', 'Example Labs'), isNull);
      expect(r('Example Labs', 'Front desk', 'Example Labs'), isNull);
      expect(r('example labs ', '', ' Example Labs'), isNull);
    });

    test('spaces at the ends of each part are dropped', () {
      expect(r('Ava Fictional', ' Head of research ', ' Example Labs '), 'Head of research, Example Labs');
    });
  });

  group('sourceLineFor', () {
    test('this Mac points to Contacts', () {
      expect(ContactHeader.sourceLineFor('this Mac', thisMac: true), _mac);
    });

    test('an iCloud account points to the iCloud account', () {
      expect(ContactHeader.sourceLineFor('the iCloud account you@example.com', thisMac: false), _icloud);
      expect(
        ContactHeader.sourceLineFor('an iCloud account', thisMac: false),
        'From an iCloud account. Change it in your iCloud account.',
      );
    });
  });

  group('layout', () {
    testWidgets('from 600px the text sits beside the 96px avatar, space-5 away and centred on it', (tester) async {
      await _pump(tester, _ava(), width: 600);
      final avatar = _avatarRect(tester);
      expect(avatar.size, const Size.square(96));
      final name = tester.getRect(find.text('Ava Fictional'));
      final role = tester.getRect(find.text('Head of research, Example Labs'));
      final source = tester.getRect(find.text(_icloud));
      expect(name.left - avatar.right, ContactHeader.sideGap);
      expect(role.left, name.left);
      expect(source.left, name.left);
      // The text block, top of the name to bottom of the source line, is centred on the avatar.
      expect((name.top + source.bottom) / 2, moreOrLessEquals(avatar.center.dy, epsilon: 0.5));
      expect(role.top, name.bottom);
      expect(source.top - role.bottom, ContactHeader.captionGap);
    });

    testWidgets('under 600px the avatar is above the text, space-4 apart, and everything is centred', (tester) async {
      await _pump(tester, _ava(), width: 599);
      final avatar = _avatarRect(tester);
      final frame = tester.getRect(find.byType(ContactHeader));
      final name = tester.getRect(find.text('Ava Fictional'));
      final role = tester.getRect(find.text('Head of research, Example Labs'));
      final source = tester.getRect(find.text(_icloud));
      expect(avatar.center.dx, frame.center.dx);
      expect(name.top - avatar.bottom, ContactHeader.stackGap);
      expect(name.center.dx, moreOrLessEquals(frame.center.dx, epsilon: 0.5));
      expect(role.center.dx, moreOrLessEquals(frame.center.dx, epsilon: 0.5));
      expect(source.top - role.bottom, ContactHeader.captionGap);
      for (final t in ['Ava Fictional', 'Head of research, Example Labs', _icloud]) {
        expect(tester.widget<Text>(find.text(t)).textAlign, TextAlign.center);
      }
    });

    testWidgets('in a wider window, a header narrower than sideMinWidth stacks like a phone', (tester) async {
      final min = ContactHeader.sideMinWidth(TextScaler.noScaling);
      expect(min, AvatarSize.large.diameter + ContactHeader.sideGap + ContactHeader.sideTextMin);

      await _pump(tester, _ava(), width: 600, paneWidth: min - 1);
      expect(_side(tester), isFalse);
      final avatar = _avatarRect(tester);
      final frame = tester.getRect(find.byType(ContactHeader));
      final name = tester.getRect(find.text('Ava Fictional'));
      expect(avatar.center.dx, frame.center.dx);
      expect(name.top - avatar.bottom, ContactHeader.stackGap);
      expect(name.center.dx, moreOrLessEquals(frame.center.dx, epsilon: 0.5));
      expect(tester.widget<Text>(find.text('Ava Fictional')).textAlign, TextAlign.center);

      await _pump(tester, _ava(), width: 600, paneWidth: min);
      expect(_side(tester), isTrue);
      expect(tester.widget<Text>(find.text('Ava Fictional')).textAlign, TextAlign.start);
    });

    testWidgets('a larger system text size needs a wider header to stay side by side', (tester) async {
      await _pump(tester, _ava(), width: 1280, paneWidth: 400);
      expect(_side(tester), isTrue);
      await _pump(tester, _ava(), width: 1280, paneWidth: 400, textScale: 1.5);
      expect(_side(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone window stacks even when the header would be wide enough', (tester) async {
      await _pump(tester, _ava(), width: 599, paneWidth: 599);
      expect(_side(tester), isFalse);
    });

    testWidgets('a long name wraps and is never cut short', (tester) async {
      await _pump(tester, _long(), width: 640);
      final text = tester.widget<Text>(find.text(_longName));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.text(_longName), matching: find.byType(RichText)));
      expect(paragraph.didExceedMaxLines, isFalse);
      // display-lg is 36px a line; the name takes more than one.
      expect(paragraph.size.height, greaterThan(MyDataType.displayLg.fontSize! * MyDataType.displayLg.height! * 1.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a word longer than a narrow line breaks rather than overflowing', (tester) async {
      const word = 'Placeholderfictionalexamplesworthington';
      await _pump(
        tester,
        ContactHeader(name: word, sourceLine: _mac, avatar: const Avatar(name: word, size: AvatarSize.large)),
        width: 360,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text(word)).right, lessThanOrEqualTo(tester.getRect(find.byType(ContactHeader)).right));
    });
  });

  group('content', () {
    testWidgets('the name in display-lg and ink; the line under it in body, the source in caption, both ink-muted',
        (tester) async {
      await _pump(tester, _ava());
      final colors = MyDataTheme.data('kiwi', Brightness.light).extension<MyDataColors>()!;
      TextStyle style(String t) => tester.widget<Text>(find.text(t)).style!;
      expect(style('Ava Fictional').fontSize, MyDataType.displayLg.fontSize);
      expect(style('Ava Fictional').fontFamily, MyDataType.displayLg.fontFamily);
      expect(style('Ava Fictional').color, colors.ink);
      expect(style('Head of research, Example Labs').fontSize, MyDataType.body.fontSize);
      expect(style('Head of research, Example Labs').color, colors.inkMuted);
      expect(style(_icloud).fontSize, MyDataType.caption.fontSize);
      expect(style(_icloud).color, colors.inkMuted);
    });

    testWidgets('an organisation card shows no line under the name', (tester) async {
      await _pump(tester, _labs());
      expect(find.text('Example Labs'), findsOneWidget);
      expect(find.text(_mac), findsOneWidget);
      final texts = tester.widgetList<Text>(find.descendant(of: find.byType(SelectionArea), matching: find.byType(Text)));
      expect(texts.length, 2);
    });

    testWidgets('no source line when it is empty', (tester) async {
      await _pump(
        tester,
        ContactHeader(name: 'Ava Fictional', sourceLine: ' ', avatar: const Avatar(name: 'Ava Fictional', size: AvatarSize.large)),
      );
      final texts = tester.widgetList<Text>(find.descendant(of: find.byType(SelectionArea), matching: find.byType(Text)));
      expect(texts.map((t) => t.data), ['Ava Fictional']);
    });

    test('the header takes the 96px avatar only', () {
      expect(
        () => ContactHeader(name: 'Ava Fictional', sourceLine: _mac, avatar: const Avatar(name: 'Ava Fictional')),
        throwsAssertionError,
      );
    });
  });

  group('selection and focus', () {
    testWidgets('all the text is in one selection area, selectable across its lines', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await _pump(tester, _ava());
      final area = find.byType(SelectionArea);
      expect(area, findsOneWidget);
      for (final t in ['Ava Fictional', 'Head of research, Example Labs', _icloud]) {
        expect(find.descendant(of: area, matching: find.text(t)), findsOneWidget);
      }

      // Drag with the mouse from the start of the name to the end of the source line, then copy.
      final from = tester.getTopLeft(find.text('Ava Fictional')) + const Offset(1, 4);
      final to = tester.getBottomRight(find.text(_icloud)) - const Offset(1, 4);
      final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final copy = defaultTargetPlatform == TargetPlatform.macOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;
      await tester.sendKeyDownEvent(copy);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(copy);
      await tester.pumpAndSettle();
      expect(copied, isNotNull);
      expect(copied, contains('Ava Fictional'));
      expect(copied, contains('Head of research, Example Labs'));
      expect(copied, contains('Change it in your iCloud account'));
    });

    testWidgets('it is not a Tab stop: Tab passes over it', (tester) async {
      var pressed = 0;
      await _pump(
        tester,
        Column(children: [
          _ava(),
          Pressable(onPressed: () => pressed++, borderRadius: MyDataRadii.sm, semanticLabel: 'After', child: const SizedBox.square(dimension: 44)),
        ]),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('ContactHeader selection'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, 1);
    });
  });

  group('semantics', () {
    testWidgets('the name is a heading; the avatar is decoration', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _ava(photo: true));
      expect(
        tester.getSemantics(find.text('Ava Fictional')),
        matchesSemantics(label: 'Ava Fictional', isHeader: true),
      );
      expect(find.bySemanticsLabel('Ava Fictional'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Avatar), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      handle.dispose();
    });
  });
}
