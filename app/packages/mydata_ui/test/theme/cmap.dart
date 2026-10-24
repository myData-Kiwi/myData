// Reading a TrueType font's character map in tests (icons_test.dart, fonts_test.dart).
import 'dart:typed_data';

/// The code points a TrueType font maps, from its `cmap` table (formats 4 and 12).
Set<int> codePoints(Uint8List font) {
  final d = ByteData.sublistView(font);
  final tables = d.getUint16(4);
  for (var i = 0; i < tables; i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes(font.sublist(rec, rec + 4)) != 'cmap') continue;
    final cmap = d.getUint32(rec + 8);
    final out = <int>{};
    for (var j = 0; j < d.getUint16(cmap + 2); j++) {
      final sub = cmap + d.getUint32(cmap + 4 + 8 * j + 4);
      switch (d.getUint16(sub)) {
        case 4:
          final segs = d.getUint16(sub + 6) ~/ 2;
          for (var s = 0; s < segs; s++) {
            final end = d.getUint16(sub + 14 + 2 * s);
            final start = d.getUint16(sub + 16 + 2 * segs + 2 * s);
            for (var c = start; c <= end && c != 0xffff; c++) {
              out.add(c);
            }
          }
        case 12:
          final groups = d.getUint32(sub + 12);
          for (var g = 0; g < groups; g++) {
            final at = sub + 16 + 12 * g;
            for (var c = d.getUint32(at); c <= d.getUint32(at + 4); c++) {
              out.add(c);
            }
          }
      }
    }
    return out;
  }
  return const {};
}
