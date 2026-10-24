import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

// Invented people and places only: example.com addresses and the UK's reserved drama numbers (07700 900xxx).

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

/// An image provider whose loading the test controls: [arrive] delivers the portrait, [fail] an error.
/// With [ready] it is already in memory and arrives synchronously, as a cached photo does.
class _TestPhoto extends ImageProvider<_TestPhoto> {
  _TestPhoto({this.ready = false});

  final bool ready;
  final _completer = _ControlledCompleter();

  void arrive() => _completer.setImage(ImageInfo(image: _portrait.clone()));
  void fail() => _completer.reportError(exception: StateError('unreadable photo'));

  @override
  Future<_TestPhoto> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TestPhoto key, ImageDecoderCallback decode) {
    if (ready) return OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: _portrait.clone())));
    return _completer;
  }
}

class _ControlledCompleter extends ImageStreamCompleter {
  @override
  void setImage(ImageInfo image) => super.setImage(image);
}

/// One avatar with its caption under it, as the preview's figures.
Widget _figure(String caption, Widget avatar) => Builder(
      builder: (context) => SizedBox(
        width: AvatarSize.large.diameter(kiwiLook),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          avatar,
          const SizedBox(height: MyDataSpace.s2),
          Text(caption,
              textAlign: TextAlign.center,
              style: MyDataType.caption.copyWith(color: context.colors.inkMuted)),
        ]),
      ),
    );

Widget _row(List<Widget> children) => Wrap(spacing: MyDataSpace.s6, runSpacing: MyDataSpace.s6, children: children);

late _TestPhoto _pendingPhoto;
late _TestPhoto _failedPhoto;

/// The preview's two sets (96px, then 36px), plus the states that look like initials: a photo still loading,
/// a photo that cannot be read, a single name and an email address; then wide and narrow letters side by side,
/// which must all be the same type size.
Widget _all() {
  _pendingPhoto = _TestPhoto();
  _failedPhoto = _TestPhoto();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _row([
        _figure('Photo', Avatar(name: 'Ava Fictional', size: AvatarSize.large, photo: _TestPhoto(ready: true))),
        _figure('Initials', const Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample', size: AvatarSize.large)),
        _figure('Organisation', const Avatar(name: 'Example Labs', size: AvatarSize.large)),
        _figure('No letters', const Avatar(name: '+44 7700 900456', size: AvatarSize.large)),
      ]),
      const SizedBox(height: MyDataSpace.s6),
      _row([
        _figure('Photo, 36px', Avatar(name: 'Ava Fictional', photo: _TestPhoto(ready: true))),
        _figure('Initials, 36px', const Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample')),
        _figure('Organisation, 36px', const Avatar(name: 'Example Labs')),
        _figure('No letters, 36px', const Avatar(name: '+44 7700 900456')),
      ]),
      const SizedBox(height: MyDataSpace.s6),
      _row([
        _figure('Loading', Avatar(name: 'Noor Example', givenName: 'Noor', familyName: 'Example', photo: _pendingPhoto)),
        _figure('Unreadable', Avatar(name: 'Lee Placeholder', givenName: 'Lee', familyName: 'Placeholder', photo: _failedPhoto)),
        _figure('One name', const Avatar(name: 'Ava', givenName: 'Ava')),
        _figure('Email', const Avatar(name: 'sam@example.com')),
      ]),
      const SizedBox(height: MyDataSpace.s6),
      _row([
        _figure('Wide letters', const Avatar(name: 'Widget Works', size: AvatarSize.large)),
        _figure('Wide, 36px', const Avatar(name: 'Widget Works')),
        _figure('Mixed, 36px', const Avatar(name: 'Model Works')),
        _figure('Narrow, 36px', const Avatar(name: 'Ivy Ilex', givenName: 'Ivy', familyName: 'Ilex')),
      ]),
    ],
  );
}

Avatar _avatar(WidgetTester tester, String name) =>
    tester.widget<Avatar>(find.byWidgetPredicate((w) => w is Avatar && w.name == name).first);

Finder _in(String name, Finder matching) =>
    find.descendant(of: find.byWidgetPredicate((w) => w is Avatar && w.name == name), matching: matching);

/// The opacity the letters (index 0) or the photo (index 1) are heading to inside a photo avatar.
double _opacity(WidgetTester tester, String name, int index) =>
    tester.widgetList<AnimatedOpacity>(_in(name, find.byType(AnimatedOpacity))).elementAt(index).opacity;

/// The opacity painted right now for the letters (index 0) or the photo (index 1).
double _painted(WidgetTester tester, String name, int index) => tester
    .renderObjectList<RenderAnimatedOpacity>(_in(name, find.byType(AnimatedOpacity)))
    .elementAt(index)
    .opacity
    .value;

Duration _duration(WidgetTester tester, String name) =>
    tester.widgetList<AnimatedOpacity>(_in(name, find.byType(AnimatedOpacity))).first.duration;

void main() {
  setUpAll(() async => _portrait = await _drawPortrait());

  goldenMatrix('avatar', _all, size: const Size(512, 540), before: (tester) async {
    _failedPhoto.fail();
    await tester.pump();
  });

  group('avatarInitials', () {
    String? i(String name, [String given = '', String family = '']) =>
        avatarInitials(name: name, givenName: given, familyName: family);

    test('the first letters of the given and family names, in the order the name is shown', () {
      expect(i('Sam Sample', 'Sam', 'Sample'), 'SS');
      expect(i('Ava Fictional', 'Ava', 'Fictional'), 'AF');
      expect(i('Fictional Ava', 'Ava', 'Fictional'), 'FA');
      expect(i('Mary Ann Example', 'Mary Ann', 'Example'), 'ME');
      expect(i('Jan van der Example', 'Jan', 'van der Example'), 'JV');
      expect(i('Dr Ava Fictional', 'Ava', 'Fictional'), 'AF');
    });

    test('one letter for a single name', () {
      expect(i('Ava', 'Ava'), 'A');
      expect(i('Fictional', '', 'Fictional'), 'F');
      expect(i('Example'), 'E');
    });

    test('an organisation uses its name: first and last words', () {
      expect(i('Example Labs'), 'EL');
      expect(i('Bank of Example'), 'BE');
      expect(i('Example & Sample Ltd'), 'EL');
      expect(i('example labs'), 'EL');
    });

    test('a card shown by another name uses the name shown', () {
      // An organisation's card that also names a person: the organisation is shown.
      expect(i('Example Labs', 'Sam', 'Sample'), 'EL');
      // A full name set by hand that contains neither part.
      expect(i('Sammy', 'Samuel', 'Sample'), 'S');
      // A short given or family name inside a longer word of the organisation's name is not the name shown.
      expect(i('Sample Bakery', 'Sam', 'Example'), 'SB');
      expect(i('Annex Example', 'Ann', 'Sample'), 'AE');
      expect(i('Edison Labs', 'Ed', 'Son'), 'EL');
    });

    test('given and family names are matched as whole words, ignoring case and punctuation', () {
      expect(i("O'Example, Ava", 'Ava', "O'Example"), 'OA');
      expect(i('ava-mae fictional', 'Ava-Mae', 'Fictional'), 'AF');
      // Only the family name shown: still given, then family.
      expect(i('Dr. Example', 'Ava', 'Example'), 'AE');
      // Only the given name shown.
      expect(i('Ava', 'Ava', 'Fictional'), 'AF');
    });

    test('Chinese, Japanese and Korean names use their first character', () {
      expect(i('王小明', '小明', '王'), '王');
      expect(i('山田太郎', '太郎', '山田'), '山');
      expect(i('山田 太郎', '太郎', '山田'), '山');
      expect(i('김민준', '민준', '김'), '김');
      expect(i('やまだ'), 'や');
      expect(i('例示株式会社'), '例');
      expect(i('サンプル 商事'), 'サ');
    });

    test('a phone number or an email address gives no letters (the person icon)', () {
      expect(i('+44 7700 900456'), isNull);
      expect(i('(555) 010-0199'), isNull);
      expect(i('+1 555-010-0199 ext. 12'), isNull);
      expect(i('555 0100 x7'), isNull);
      expect(i('sam@example.com'), isNull);
      expect(i('Ava.Fictional@example.com'), isNull);
    });

    test('nothing with letters gives the person icon', () {
      expect(i(''), isNull);
      expect(i('   '), isNull);
      expect(i('🙂'), isNull);
      expect(i('— · —'), isNull);
    });

    test('letters are upper-cased, accents and marks kept, other symbols skipped', () {
      expect(i('émile exemple', 'émile', 'exemple'), 'ÉE');
      expect(i('Émile Exemple'), 'ÉE');
      expect(i('Øystein Åsen'), 'ØÅ');
      expect(i("'Ava' (Fictional)"), 'AF');
      expect(i('Ava 🙂 Fictional'), 'AF');
      expect(i('ßample'), 'ß');
    });

    test('given and family names with no letters fall back to the name shown', () {
      expect(i('Example Labs', '1', '2'), 'EL');
      expect(i('+44 7700 900456', '+44', '7700'), isNull);
    });

    test('surrounding space is ignored', () {
      expect(i('  Sam Sample ', ' Sam ', ' Sample '), 'SS');
    });

    test('the same input always gives the same letters', () {
      expect(i('Sam Sample', 'Sam', 'Sample'), i('Sam Sample', 'Sam', 'Sample'));
    });
  });

  testWidgets('a circle in the two sizes: 36px (icon-tile) and 96px, filled kiwi-wash', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample'),
      Avatar(name: 'Example Labs', size: AvatarSize.large),
    ])));
    final c = tester.element(find.byType(Avatar).first).colors;
    expect(tester.getSize(find.byType(Avatar).first), const Size.square(MyDataSize.iconTile));
    expect(tester.getSize(find.byType(Avatar).last), const Size.square(96));
    for (final name in ['Sam Sample', 'Example Labs']) {
      final box = tester.widget<DecoratedBox>(_in(name, find.byType(DecoratedBox)).first);
      final d = box.decoration.box;
      expect(d.color, c.kiwiWash, reason: name);
      expect(d.borderRadius, MyDataRadii.pill(kiwiLook), reason: name);
      expect(d.border, isNull, reason: name);
      expect(d.boxShadow, isNull, reason: name);
    }
  });

  testWidgets('every contact gets the same fill: no colour per person', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Column(children: [
      Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample'),
      Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional'),
      Avatar(name: 'Example Labs'),
      Avatar(name: '+44 7700 900456'),
    ])));
    final fills = tester
        .widgetList<DecoratedBox>(find.descendant(of: find.byType(Avatar), matching: find.byType(DecoratedBox)))
        .map((b) => (b.decoration.box).color)
        .toSet();
    expect(fills, hasLength(1));
  });

  testWidgets('initials: ink, body-strong at 36px and display-lg at 96px', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample'),
      Avatar(name: 'Example Labs', size: AvatarSize.large),
    ])));
    final c = tester.element(find.byType(Avatar).first).colors;
    final small = tester.widget<Text>(find.text('SS')).style!;
    expect(small, MyDataType.bodyStrong.copyWith(color: c.ink));
    final large = tester.widget<Text>(find.text('EL')).style!;
    expect(large, MyDataType.displayLg.copyWith(color: c.ink));
    // Centred in the circle.
    expect(tester.getCenter(find.text('SS')), tester.getCenter(find.byType(Avatar).first));
    expect(tester.getCenter(find.text('EL')), tester.getCenter(find.byType(Avatar).last));
  });

  testWidgets('no letters: a person outline icon in ink-muted, icon size at 36px and twice that at 96px',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      Avatar(name: '+44 7700 900456'),
      Avatar(name: 'sam@example.com', size: AvatarSize.large),
    ])));
    final c = tester.element(find.byType(Avatar).first).colors;
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons, hasLength(2));
    expect(icons.map((i) => i.icon), everyElement(iconOf(MyDataIcon.person)));
    expect(icons.map((i) => i.color), everyElement(c.inkMuted));
    expect(icons.first.size, MyDataSize.icon);
    expect(icons.last.size, MyDataSize.icon * 2);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a photo in memory fills the circle, cropped and centred, with no border and no letters showing',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', size: AvatarSize.large,
            photo: _TestPhoto(ready: true))));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.alignment, Alignment.center);
    expect(tester.getSize(find.byType(Image)), const Size.square(96));
    expect(tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius, MyDataRadii.pill(kiwiLook));
    expect(_opacity(tester, 'Ava Fictional', 0), 0, reason: 'letters hidden');
    expect(_opacity(tester, 'Ava Fictional', 1), 1, reason: 'photo shown');
    expect(_duration(tester, 'Ava Fictional'), Duration.zero, reason: 'already in memory: no fade');
  });

  testWidgets('until the photo arrives the initials show; then it fades in over fast', (tester) async {
    final photo = _TestPhoto();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', photo: photo)));
    expect(find.text('AF'), findsOneWidget);
    expect(_opacity(tester, 'Ava Fictional', 0), 1);
    expect(_opacity(tester, 'Ava Fictional', 1), 0);

    photo.arrive();
    await tester.pump();
    expect(_opacity(tester, 'Ava Fictional', 0), 0);
    expect(_opacity(tester, 'Ava Fictional', 1), 1);
    expect(_duration(tester, 'Ava Fictional'), MyDataMotion.fast);
    expect(tester.hasRunningAnimations, isTrue);
    // Halfway through, the photo is partly shown; a frame after `fast`, the fade is over.
    await tester.pump();
    await tester.pump(MyDataMotion.fast ~/ 2);
    final half = _painted(tester, 'Ava Fictional', 1);
    expect(half, greaterThan(0));
    expect(half, lessThan(1));
    await tester.pump(MyDataMotion.fast ~/ 2);
    await tester.pump(const Duration(milliseconds: 17));
    expect(_painted(tester, 'Ava Fictional', 1), 1);
    expect(_painted(tester, 'Ava Fictional', 0), 0);
  });

  testWidgets('with reduced motion the photo simply appears', (tester) async {
    final photo = _TestPhoto();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', photo: photo),
        reduceMotion: true));
    photo.arrive();
    await tester.pump();
    expect(_opacity(tester, 'Ava Fictional', 1), 1);
    expect(_duration(tester, 'Ava Fictional'), Duration.zero);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a photo that cannot be read leaves the initials, and reports no error', (tester) async {
    final photo = _TestPhoto();
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', photo: photo)));
    photo.fail();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('AF'), findsOneWidget);
    expect(find.descendant(of: find.byType(Avatar), matching: find.byType(RawImage)), findsNothing);
  });

  testWidgets('without a photo nothing is fetched: no Image at all', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Avatar(name: 'Sam Sample')));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('beside the name it is decoration: no accessible name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, Row(children: [
      Avatar(name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', photo: _TestPhoto(ready: true)),
      const Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample'),
      const Text('Sam Sample'),
    ])));
    expect(find.bySemanticsLabel('Ava Fictional'), findsNothing);
    expect(find.bySemanticsLabel('SS'), findsNothing);
    expect(find.bySemanticsLabel('Sam Sample'), findsOneWidget, reason: 'only the visible name');
    handle.dispose();
  });

  testWidgets('on its own it is an image named with the contact\'s name, never the letters', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Row(children: [
      Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample', decorative: false),
      Avatar(name: '+44 7700 900456', decorative: false),
    ])));
    expect(tester.getSemantics(find.byType(Avatar).first),
        isSemantics(label: 'Sam Sample', isImage: true, isButton: false, isFocusable: false, hasTapAction: false));
    expect(find.bySemanticsLabel('+44 7700 900456'), findsOneWidget);
    expect(find.bySemanticsLabel('SS'), findsNothing);
    handle.dispose();
  });

  testWidgets('never a target: no Pressable, no focus, Tab does not reach it', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const Avatar(name: 'Sam Sample', decorative: false)));
    expect(find.descendant(of: find.byType(Avatar), matching: find.byType(Pressable)), findsNothing);
    expect(find.descendant(of: find.byType(Avatar), matching: find.byType(Focus)), findsNothing);
    expect(find.descendant(of: find.byType(Avatar), matching: find.byType(GestureDetector)), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused == null || !find.byType(Avatar).evaluate().any((e) => _isAncestor(e, focused)), isTrue);
  });

  testWidgets('large system text: the letters scale down inside the circle and never overflow', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(3)),
      child: themedFrame(themeMatrix.first, const Row(children: [
        Avatar(name: 'Mary Mary', givenName: 'Mary', familyName: 'Mary'),
        Avatar(name: 'Mary Mary', givenName: 'Mary', familyName: 'Mary', size: AvatarSize.large),
      ])),
    ));
    expect(tester.takeException(), isNull);
    for (var n = 0; n < 2; n++) {
      final letters = find.text('MM').at(n);
      // The painted size: the text's own box scaled by the FittedBox around it.
      final box = tester.renderObject<RenderBox>(letters);
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
      final avatar = tester.getRect(find.byType(Avatar).at(n));
      expect(avatar.inflate(0.01).contains(topLeft) && avatar.inflate(0.01).contains(bottomRight), isTrue,
          reason: 'size ${box.size}');
    }
    expect(_avatar(tester, 'Mary Mary').initials, 'MM');
  });

  testWidgets('at the default text size wide letters keep their type size: nothing is scaled down',
      (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, const Wrap(children: [
      Avatar(name: 'Widget Works'),
      Avatar(name: 'Model Works'),
      Avatar(name: 'Mary Mary', givenName: 'Mary', familyName: 'Mary'),
      Avatar(name: 'Widget Works', size: AvatarSize.large),
      Avatar(name: 'Model Works', size: AvatarSize.large),
      Avatar(name: 'Mary Mary', givenName: 'Mary', familyName: 'Mary', size: AvatarSize.large),
    ])));
    for (final letters in ['WW', 'MW', 'MM']) {
      for (var n = 0; n < 2; n++) {
        final text = find.text(letters).at(n);
        // Laid out (the text's own box) and painted (after the FittedBox's scale) sizes are the same.
        final laidOut = tester.getSize(text);
        final painted = tester.getRect(text).size;
        expect(painted.width, closeTo(laidOut.width, 0.01), reason: '$letters, avatar ${n + 1}');
        expect(painted.height, closeTo(laidOut.height, 0.01), reason: '$letters, avatar ${n + 1}');
        // And the letters fit inside the circle's box.
        final avatar = tester.getRect(find.ancestor(of: text, matching: find.byType(Avatar)));
        expect(avatar.inflate(0.01).contains(tester.getRect(text).topLeft), isTrue, reason: letters);
        expect(avatar.inflate(0.01).contains(tester.getRect(text).bottomRight), isTrue, reason: letters);
      }
    }
  });

  group('the photo is decoded only as large as the circle needs', () {
    /// A [width] x [height] PNG, as the host would send one.
    Future<Uint8List> png(int width, int height) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF6B4F35));
      final image = await recorder.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    /// The decoded photo's size in an avatar of [size] on a screen with [dpr] device pixels per pixel.
    Future<Size> decoded(WidgetTester tester, Uint8List bytes, AvatarSize size, double dpr) async {
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      imageCache.clear();
      await tester.pumpWidget(themedFrame(themeMatrix.first,
          Avatar(name: 'Ava Fictional', size: size, photo: MemoryImage(bytes))));
      ui.Image? image;
      for (var tries = 0; image == null && tries < 50; tries++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        image = tester.widgetList<RawImage>(find.byType(RawImage)).firstOrNull?.image;
      }
      expect(image, isNotNull, reason: 'the photo never arrived');
      return Size(image!.width.toDouble(), image.height.toDouble());
    }

    testWidgets('a large landscape photo: its shorter side becomes the diameter in device pixels',
        (tester) async {
      final bytes = (await tester.runAsync(() => png(800, 600)))!;
      // 36px at 3x: 108 device pixels. Proportions kept, so the circle is still covered.
      expect(await decoded(tester, bytes, AvatarSize.small, 3), const Size(144, 108));
      // 96px at 2x: 192.
      expect(await decoded(tester, bytes, AvatarSize.large, 2), const Size(256, 192));
    });

    testWidgets('a large portrait photo: its width becomes the diameter', (tester) async {
      final bytes = (await tester.runAsync(() => png(600, 800)))!;
      expect(await decoded(tester, bytes, AvatarSize.small, 2), const Size(72, 96));
    });

    testWidgets('a photo smaller than the circle is never scaled up', (tester) async {
      final bytes = (await tester.runAsync(() => png(120, 90)))!;
      expect(await decoded(tester, bytes, AvatarSize.large, 2), const Size(120, 90));
    });
  });

  testWidgets('it renders the same with reduced transparency', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first,
        const Avatar(name: 'Sam Sample', givenName: 'Sam', familyName: 'Sample'), reduceTransparency: true));
    final c = tester.element(find.byType(Avatar)).colors;
    expect((tester.widget<DecoratedBox>(_in('Sam Sample', find.byType(DecoratedBox))).decoration.box).color,
        c.kiwiWash);
    expect(find.descendant(of: find.byType(Avatar), matching: find.byType(BackdropFilter)), findsNothing);
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
