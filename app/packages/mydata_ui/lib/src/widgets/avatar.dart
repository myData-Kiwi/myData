import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'pressable.dart' show MyDataRadii;

/// The two sizes of [Avatar] (design/components/Avatar).
enum AvatarSize {
  /// `icon-tile` (36px): in a list row, in the icon tile's place.
  small,

  /// 96px: at the top of a contact's page (ContactHeader). The icon is twice the `icon` size.
  large,

  /// The Mac frame's `avatar` (64pt), at the top of a record's page (MacRecordHeader), with the initials in
  /// the system font.
  mac;

  /// The preview's large avatar: `.av{width:96px}`.
  static const largeDiameter = 96.0;

  /// The circle's width and height.
  double diameter(MyDataLook look) => switch (this) {
        small => look.density.iconTile,
        large => largeDiameter,
        mac => MyDataMacSize.avatar,
      };

  /// The person icon's size when there are no letters to use.
  double iconSize(MyDataLook look) => switch (this) {
        small => look.density.icon,
        large => look.density.icon * 2,
        mac => look.density.icon * 1.5,
      };

  /// The initials' type style, without colour: `body-strong` at 36px, `display-lg` at 96px.
  TextStyle letterStyle(MyDataLook look) => switch (this) {
        small => look.typeScale.bodyStrong,
        large => look.typeScale.displayLg,
        mac => MyDataMacType.avatar,
      };
}

/// A round picture of a person: their photo when the host has one, otherwise their initials
/// (design/components/Avatar).
///
/// - A circle (`radius-pill`) in two sizes ([AvatarSize]). Every contact gets the same `kiwi-wash` fill;
///   there is no colour per person. It is not an icon tile and does not count toward a screen's tile tones.
/// - **Photo:** [photo], cropped to fill the circle and centred, with no border or ring. Pass it only when the
///   contact has one (the host's `has_photo`), so nothing is fetched otherwise. Until it arrives, and when it
///   cannot be read, the initials show. It appears with a `fast` fade; with reduced motion it simply appears.
/// - **Initials:** up to two letters in `ink` ([avatarInitials]). When there are no letters to use (the name
///   shown is a phone number or an email address), a person outline icon in `ink-muted`.
/// - **Semantics:** next to the name it is decoration ([decorative], the default) and has no accessible name.
///   On its own, pass `decorative: false` and it is an image named with [name].
/// - Never a target by itself: the row or header that holds it is. It has no focus, hover or press.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.givenName = '',
    this.familyName = '',
    this.size = AvatarSize.small,
    this.photo,
    this.decorative = true,
  });

  /// The name to show, as the host gives it (`display_name`): never empty; the organisation, an email
  /// address or a phone number when the card has no name.
  final String name;

  /// The card's given name, or empty.
  final String givenName;

  /// The card's family name, or empty.
  final String familyName;

  final AvatarSize size;

  /// The contact's photo, or null when the contact has none.
  final ImageProvider? photo;

  /// True (the default) beside the name, where the avatar has no accessible name. False when it stands
  /// alone: it is then an image named with [name].
  final bool decorative;

  /// The letters shown, or null for the person icon.
  String? get initials => avatarInitials(name: name, givenName: givenName, familyName: familyName);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final letters = _Letters(initials: initials, size: size);
    final photo = this.photo;

    Widget body = DecoratedBox(
      decoration: context.radius.decorate(BoxDecoration(color: c.kiwiWash, borderRadius: MyDataRadii.pill(context.look))),
      child: photo == null
          ? letters
          : context.radius.clip(
              MyDataRadii.pill(context.look),
              child: _Photo(image: photo, diameter: size.diameter(context.look), letters: letters),
            ),
    );
    body = SizedBox.square(dimension: size.diameter(context.look), child: body);

    if (decorative) return ExcludeSemantics(child: body);
    return Semantics(container: true, image: true, label: name, child: ExcludeSemantics(child: body));
  }
}

/// The initials, or the person icon when there are none, centred in the circle.
class _Letters extends StatelessWidget {
  const _Letters({required this.initials, required this.size});

  final String? initials;
  final AvatarSize size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = this.initials;
    return Center(
      child: initials == null
          ? Icon(context.icon(MyDataIcon.person), size: size.iconSize(context.look), color: c.inkMuted)
          // At the default text size the letters keep their type size: the preview's 36px circle has no inset,
          // and two wide capitals ("WW", about 30px of body-strong) fit. A small side inset (2.25px at 36px)
          // keeps the corners of letters scaled down for a large system text size inside the circle: they are
          // scaled down, never cut. No inset above and below: the line box is narrower than the circle there.
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: size.diameter(context.look) / 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: size.letterStyle(context.look).copyWith(color: c.onAvatar),
                ),
              ),
            ),
    );
  }
}

/// The photo over the initials: the initials show until the first frame arrives and when the image cannot be
/// read; then the photo fades in over `fast` (at once with reduced motion, or when it was already in memory).
///
/// The photo is decoded only as large as the circle needs on this screen ([_CoverResize]), not at its full
/// size: a list of contacts with photos of up to 2 MB each would otherwise hold tens of MB per photo.
class _Photo extends StatelessWidget {
  const _Photo({required this.image, required this.diameter, required this.letters});

  final ImageProvider image;
  final double diameter;
  final Widget letters;

  @override
  Widget build(BuildContext context) {
    final duration = MyDataMotion.reduced(context) ? Duration.zero : context.motion.fast;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
    return Image(
      image: _CoverResize(image, (diameter * dpr).ceil()),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final shown = frame != null;
        final d = wasSynchronouslyLoaded ? Duration.zero : duration;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(opacity: shown ? 0 : 1, duration: d, child: letters),
            AnimatedOpacity(opacity: shown ? 1 : 0, duration: d, child: child),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) => letters,
    );
  }
}

/// [image] decoded just large enough to cover a square of [side] pixels: its shorter side is brought down to
/// [side] (never up) and its proportions are kept, so `BoxFit.cover` still fills the circle sharply.
///
/// Flutter's `ResizeImage` cannot do this: its `exact` policy with both sides set stretches a photo that is not
/// square, and its `fit` policy brings the longer side down to [side], leaving the shorter one too small.
@immutable
class _CoverResize extends ImageProvider<_CoverResizeKey> {
  const _CoverResize(this.image, this.side);

  final ImageProvider image;

  /// The circle's diameter in device pixels.
  final int side;

  @override
  Future<_CoverResizeKey> obtainKey(ImageConfiguration configuration) =>
      // Stays synchronous when the photo's own key is (a photo already in memory shows without a fade).
      image.obtainKey(configuration).then((key) => _CoverResizeKey(key, side));

  @override
  ImageStreamCompleter loadImage(_CoverResizeKey key, ImageDecoderCallback decode) {
    Future<ui.Codec> decodeCovering(ui.ImmutableBuffer buffer, {ui.TargetImageSizeCallback? getTargetSize}) {
      assert(getTargetSize == null, 'the photo given to Avatar must not be resized already');
      return decode(buffer, getTargetSize: (width, height) {
        if (math.min(width, height) <= side) return const ui.TargetImageSize();
        // One side given: the decoder works out the other, keeping the proportions.
        return width <= height ? ui.TargetImageSize(width: side) : ui.TargetImageSize(height: side);
      });
    }

    final completer = image.loadImage(key.image, decodeCovering);
    // As ResizeImage does: forget a photo that failed, so that showing it again tries again.
    completer.addEphemeralErrorListener((exception, stackTrace) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) => other is _CoverResize && other.image == image && other.side == side;

  @override
  int get hashCode => Object.hash(image, side);
}

@immutable
class _CoverResizeKey {
  const _CoverResizeKey(this.image, this.side);

  /// The photo's own key.
  final Object image;
  final int side;

  @override
  bool operator ==(Object other) => other is _CoverResizeKey && other.image == image && other.side == side;

  @override
  int get hashCode => Object.hash(image, side);
}

/// The letters an [Avatar] shows for a contact, or null when there are none to use (the person icon).
///
/// - The first letters of [givenName] and [familyName], in the order [name] shows them ("Sam Sample" gives
///   "SS"; a name shown family name first gives the family initial first), or one letter for a single name.
/// - Names in Chinese, Japanese or Korean script use their first character only ("王小明" gives "王").
/// - Without a given or family name, or when [name] contains neither as whole words, the name shown is used: an
///   organisation's name gives the first letters of its first and last words ("Example Labs" gives "EL"), one
///   word gives one letter.
/// - Null when the name shown is an email address or a phone number, or has no letters at all.
///
/// Letters are upper-cased. A pure function: the same input always gives the same letters.
String? avatarInitials({required String name, String givenName = '', String familyName = ''}) {
  final given = givenName.trim();
  final family = familyName.trim();
  final shown = name.trim();

  // The given and family names are used when the name shown is made of them: when the given name's words, or
  // the family name's words, appear in it as whole words, one after another. A card shown by another name (an
  // organisation's card that also names a person, or a full name set by hand) uses the name shown, even when
  // a short name is part of a longer word ("Sam" in "Sample Bakery").
  final givenAt = _position(shown, given);
  final familyAt = _position(shown, family);
  final partsShown = shown.isEmpty || givenAt != null || familyAt != null;
  if ((given.isNotEmpty || family.isNotEmpty) && partsShown) {
    final parts = <String>[
      if (given.isNotEmpty) given,
      if (family.isNotEmpty) family,
    ];
    // Family name first when both are shown and it comes first ("Sample Sam", or "王小明" with family "王").
    // When only one is shown, the usual order: given, then family.
    final familyFirst = familyAt != null && givenAt != null && familyAt < givenAt;
    if (parts.length == 2 && familyFirst) parts.setAll(0, [family, given]);
    final letters = _fromWords(parts);
    if (letters != null) return letters;
  }

  if (shown.isEmpty || _isEmail(shown) || _isPhone(shown)) return null;
  final words = shown.split(RegExp(r'\s+')).where((w) => _firstLetter(w) != null).toList();
  if (words.isEmpty) return null;
  return _fromWords(words.length > 2 ? [words.first, words.last] : words);
}

/// Up to two letters from [words] (already in the order shown): the first letter of each word, or the first
/// character alone when a word is in a script without initials.
String? _fromWords(List<String> words) {
  final letters = [for (final w in words) _firstLetter(w)].whereType<String>().toList();
  if (letters.isEmpty) return null;
  // One character in Chinese, Japanese or Korean script; a name mixing scripts also keeps only its first.
  if (letters.any(_isCjk)) return _upper(letters.first);
  return letters.take(2).map(_upper).join();
}

/// Where [part] (a given or family name) appears in [shown], as a character offset into [shown] in lower
/// case, or null when it does not appear. Case is ignored.
///
/// Whole words only: [part]'s words must appear in [shown] one after another ("Mary Ann" in "Mary Ann
/// Example", not "Sam" in "Sample Bakery"). Punctuation separates words. A name in Chinese, Japanese or Korean
/// script is written without spaces, so it is looked for as text instead ("王" in "王小明").
int? _position(String shown, String part) {
  if (part.isEmpty) return null;
  final text = shown.toLowerCase();
  if (part.characters.any(_isCjk)) {
    final at = text.indexOf(part.toLowerCase());
    return at < 0 ? null : at;
  }
  final words = _word.allMatches(text).toList();
  final run = [for (final m in _word.allMatches(part.toLowerCase())) m[0]];
  if (run.isEmpty) return null;
  for (var i = 0; i + run.length <= words.length; i++) {
    var all = true;
    for (var j = 0; j < run.length && all; j++) {
      all = words[i + j][0] == run[j];
    }
    if (all) return words[i].start;
  }
  return null;
}

/// The first character of [word] that is a letter (with any marks that belong to it), or null.
String? _firstLetter(String word) {
  for (final ch in word.characters) {
    if (_letter.hasMatch(ch)) return ch;
  }
  return null;
}

/// Upper-cases one letter, unless that would turn it into more than one character ("ß").
String _upper(String letter) {
  final up = letter.toUpperCase();
  return up.characters.length == 1 ? up : letter;
}

bool _isCjk(String ch) => _cjk.hasMatch(ch);

bool _isEmail(String s) => _email.hasMatch(s);

bool _isPhone(String s) => _phone.hasMatch(s);

/// A word: a run of letters, marks and digits. Anything else (space, punctuation) separates words.
final _word = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);

final _letter = RegExp(r'^\p{L}', unicode: true);

final _cjk = RegExp(r'^[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]', unicode: true);

final _email = RegExp(r'^[^\s@]+@[^\s@]+$');

/// Digits with the usual separators, an optional leading "+", and an optional extension ("ext. 12", "x12").
final _phone = RegExp(r'^\+?[\d\s().\-‐–/]*\d[\d\s().\-‐–/]*(?:\s*(?:ext\.?|x)\s*\d+)?$', caseSensitive: false);
