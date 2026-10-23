/// A strict JSON reader for theme files (design/themes/ARCHITECTURE.md 2.1, step 2): RFC 8259 only, at most
/// 128 KB and 8 levels deep, duplicate keys refused, and no number that is not a finite double (6a: `NaN`,
/// `Infinity` and overflowing exponents). `dart:convert` keeps the last of two equal keys without a word, so it
/// is not used for files from outside.
library;

/// Why a theme file could not be read, as a sentence for the person importing it.
class StrictJsonError implements Exception {
  StrictJsonError(this.message, [this.offset]);
  final String message;
  final int? offset;

  @override
  String toString() => offset == null ? message : '$message (at character $offset)';
}

/// Limits from ARCHITECTURE.md 2.1.
const maxThemeJsonBytes = 128 * 1024;
const maxThemeJsonDepth = 8;

/// Reads [text] as one JSON value: maps keep their keys in file order. A leading byte-order mark is skipped.
Object? readStrictJson(String text, {int maxBytes = maxThemeJsonBytes, int maxDepth = maxThemeJsonDepth}) {
  // UTF-16 code units are at most the UTF-8 byte count, so this is a cheap first bound; the exact one follows.
  if (text.length > maxBytes || _utf8Length(text) > maxBytes) {
    throw StrictJsonError('The theme file is larger than ${maxBytes ~/ 1024} KB.');
  }
  final p = _Parser(text, maxDepth);
  // A byte-order mark at the start (as Windows Notepad saves UTF-8) is not part of the JSON; anywhere else it
  // is refused like any other stray character.
  if (text.startsWith('\uFEFF')) p.i = 1;
  p.skipSpace();
  final v = p.value(0);
  p.skipSpace();
  if (!p.done) throw StrictJsonError('The theme file has text after its end.', p.i);
  return v;
}

int _utf8Length(String s) {
  var n = 0;
  for (final r in s.runes) {
    n += r < 0x80 ? 1 : r < 0x800 ? 2 : r < 0x10000 ? 3 : 4;
  }
  return n;
}

class _Parser {
  _Parser(this.s, this.maxDepth);
  final String s;
  final int maxDepth;
  int i = 0;

  bool get done => i >= s.length;

  Never fail(String what) => throw StrictJsonError('The theme file is not valid JSON: $what.', i);

  void skipSpace() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        i++;
      } else {
        break;
      }
    }
  }

  Object? value(int depth) {
    if (done) fail('it ends too early');
    final c = s[i];
    if (c == '{') return object(depth + 1);
    if (c == '[') return array(depth + 1);
    if (c == '"') return string();
    if (s.startsWith('true', i)) return _word('true', true);
    if (s.startsWith('false', i)) return _word('false', false);
    if (s.startsWith('null', i)) return _word('null', null);
    return number();
  }

  Object? _word(String w, Object? v) {
    i += w.length;
    return v;
  }

  void _depth(int depth) {
    if (depth > maxDepth) throw StrictJsonError('The theme file is nested more than $maxDepth levels deep.', i);
  }

  Map<String, Object?> object(int depth) {
    _depth(depth);
    i++; // {
    final out = <String, Object?>{};
    skipSpace();
    if (!done && s[i] == '}') {
      i++;
      return out;
    }
    while (true) {
      skipSpace();
      if (done || s[i] != '"') fail('a key must be a string in quotes');
      final key = string();
      if (out.containsKey(key)) throw StrictJsonError('The theme file gives "$key" twice in one place.', i);
      skipSpace();
      if (done || s[i] != ':') fail('a colon must follow a key');
      i++;
      skipSpace();
      out[key] = value(depth);
      skipSpace();
      if (done) fail('it ends inside an object');
      if (s[i] == ',') {
        i++;
        continue;
      }
      if (s[i] == '}') {
        i++;
        return out;
      }
      fail('a comma or a closing brace must follow a value');
    }
  }

  List<Object?> array(int depth) {
    _depth(depth);
    i++; // [
    final out = <Object?>[];
    skipSpace();
    if (!done && s[i] == ']') {
      i++;
      return out;
    }
    while (true) {
      skipSpace();
      out.add(value(depth));
      skipSpace();
      if (done) fail('it ends inside a list');
      if (s[i] == ',') {
        i++;
        continue;
      }
      if (s[i] == ']') {
        i++;
        return out;
      }
      fail('a comma or a closing bracket must follow a value');
    }
  }

  String string() {
    i++; // "
    final b = StringBuffer();
    while (true) {
      if (done) fail('a string is not closed');
      final c = s.codeUnitAt(i);
      if (c == 0x22) {
        i++;
        return b.toString();
      }
      if (c < 0x20) fail('a string holds a raw control character');
      if (c == 0x5C) {
        i++;
        if (done) fail('a string ends in a backslash');
        final e = s[i];
        i++;
        switch (e) {
          case '"':
            b.write('"');
          case r'\':
            b.write(r'\');
          case '/':
            b.write('/');
          case 'b':
            b.write('\b');
          case 'f':
            b.write('\f');
          case 'n':
            b.write('\n');
          case 'r':
            b.write('\r');
          case 't':
            b.write('\t');
          case 'u':
            if (i + 4 > s.length) fail('a \\u escape is cut short');
            final hex = s.substring(i, i + 4);
            final v = int.tryParse(hex, radix: 16);
            if (v == null || !RegExp(r'^[0-9A-Fa-f]{4}$').hasMatch(hex)) fail('a \\u escape is not four hex digits');
            b.writeCharCode(v);
            i += 4;
          default:
            fail('a string has an unknown escape');
        }
        continue;
      }
      b.writeCharCode(c);
      i++;
    }
  }

  static final _number = RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?');

  num number() {
    final m = _number.matchAsPrefix(s, i);
    if (m == null || m.end == i) fail('a value is not a string, number, list, object, true, false or null');
    final text = m[0]!;
    i = m.end;
    final isInt = !text.contains(RegExp('[.eE]'));
    if (isInt && text.length <= 15) return int.parse(text);
    final d = double.parse(text);
    if (!d.isFinite) throw StrictJsonError('The theme file has a number too large to read: $text.', i);
    return d;
  }
}
