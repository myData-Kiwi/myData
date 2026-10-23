// The M1a stack gate's screenshots of the Flutter side: the People screen in the Mac frame with the gate's
// shared synthetic address book (prototypes/stack-gate/people.json, the same file the SwiftUI prototype's
// off-screen renderer reads), in its three states (an owned contact with every kind of field, a followed
// contact with a photo, three contacts selected), light and dark, at 1280x800 points and 2x (2560x1600
// pixels, as the Mac's Retina screen and the SwiftUI renderer). The list holds the keyboard, so the selection
// is in the accent, as in the SwiftUI screenshots.
//
// Written only when MYDATA_GATE_OUT names a folder outside the checkout, in the Mac's own system font
// (flutter_test_config.dart), and never committed: the images hold rasterised SF Pro.
//
//   MYDATA_GATE_OUT=/some/folder flutter test test/stack_gate_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mycontacts/src/app.dart';
import 'package:mycontacts/src/contacts_controller.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';
import 'flutter_test_config.dart';

/// The shared fixture, from app/apps/mycontacts (where `flutter test` runs).
final fixture = File('../../../prototypes/stack-gate/people.json');

({List<ContactDetailOut> cards, Map<String, Uint8List> photos, Map<String, List<String>> states}) readFixture() {
  final json = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  return (
    cards: [for (final c in json['contacts'] as List) ContactDetailOut.fromJson(c)!],
    photos: {for (final e in (json['photos'] as Map).entries) e.key as String: base64Decode(e.value as String)},
    states: {
      for (final e in (json['states'] as Map).entries)
        e.key as String: [for (final n in (e.value as Map)['select'] as List) n as String],
    },
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _row(String name) =>
    find.descendant(of: find.byType(ContactList), matching: find.text(name, findRichText: true));

void main() {
  final out = gateOut;
  final data = readFixture();

  test('the fixture is the host\'s shape and has the gate\'s states', () {
    expect(data.cards.length, greaterThanOrEqualTo(40));
    expect(data.states.keys, containsAll(['owned', 'followed', 'several']));
    final names = {for (final c in data.cards) c.displayName};
    for (final s in data.states.values) {
      expect(names, containsAll(s));
    }
  });

  setUp(() => MacLook.debugOverride = true);
  tearDown(() => MacLook.debugOverride = false);

  for (final state in data.states.entries) {
    for (final t in macMatrix) {
      testWidgets('stack gate ${state.key} (${t.brightness.name})', (tester) async {
        tester.view.physicalSize = const Size(2560, 1600);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        painting.debugDisableShadows = false;
        try {
          final idOf = {for (final c in data.cards) c.displayName: c.id};
          final first = state.value.first;
          await tester.pumpWidget(
            MyContactsApp(
              host: FakeHost(
                phaseOnConnect: HostPhase.running,
                statusOnConnect: hostStatus(theme: t.themeId),
              ),
              store: MemoryDeviceStore({
                'mode': t.brightness.name,
                'lastTheme': t.themeId,
                ContactsController.lastOpenedKey: idOf[first],
              }),
              backend: FakeBackend(cards: [...data.cards], photos: data.photos),
              links: const Stream.empty(),
              onOpenLink: (_) {},
            ),
          );
          await settle(tester);
          // Click the first, then Command-click the others (the tests run as Android, where Ctrl is Command).
          await tester.tap(_row(first));
          await settle(tester);
          for (final name in state.value.skip(1)) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.tap(_row(name));
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await settle(tester);
          }
          await tester.pump(const Duration(seconds: 1));
          if (out == null || out.isEmpty) return;
          final element = find.byType(MaterialApp).evaluate().first;
          await tester.runAsync(() async {
            final image = await captureImage(element);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('$out/flutter-${state.key}-${t.brightness.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        } finally {
          painting.debugDisableShadows = true;
        }
      });
    }
  }
}
