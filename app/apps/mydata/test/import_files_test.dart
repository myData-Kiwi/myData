// What a drop leaves in the temporary folder is deleted once read; nothing else is ever touched.
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata/src/import/import_files.dart';

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('mydata-drops-test-'));
  tearDown(() => temp.deleteSync(recursive: true));

  File write(String path) => File('${temp.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync('BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ava Fictional\r\nEND:VCARD\r\n');

  test('a card dragged out of another app: its Drops folder goes once read', () async {
    final f = write('Drops/20261014_093000_000Z/Ava Fictional.vcf');
    final picked = XPickedFile(XFile(f.path), dropped: true, tempRoot: temp.path);
    expect(await picked.read(), isNotEmpty);
    await picked.discard();
    expect(f.existsSync(), isFalse);
    expect(Directory('${temp.path}/Drops/20261014_093000_000Z').existsSync(), isFalse);
    expect(Directory('${temp.path}/Drops').existsSync(), isTrue, reason: 'only this drop\'s folder');
  });

  test('a file dropped from the Finder, or chosen, stays where it is', () async {
    final own = write('Documents/contacts.vcf');
    await XPickedFile(XFile(own.path), dropped: true, tempRoot: temp.path).discard();
    expect(own.existsSync(), isTrue);
    final chosen = write('Drops/20261014_093000_000Z/chosen.vcf');
    await XPickedFile(XFile(chosen.path), tempRoot: temp.path).discard();
    expect(chosen.existsSync(), isTrue, reason: 'not from a drop');
    final deeper = write('Other/Drops/20261014_093000_000Z/x.vcf');
    await XPickedFile(XFile(deeper.path), dropped: true, tempRoot: temp.path).discard();
    expect(deeper.existsSync(), isTrue, reason: 'Drops must sit right in the temporary folder');
  });
}
