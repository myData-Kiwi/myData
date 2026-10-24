// The chat variants (design/themes/ARCHITECTURE.md 3.2): myAssistant's conversation as bubbles, blocks or a
// transcript, one golden per value in light and dark, each Kiwi with that one value changed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

import 'chat_view_test.dart' show ScriptedBackend;

ThemeFile _kiwiWithChat(String chat) {
  final json = jsonDecode(builtInThemeJson[ThemeLibrary.kiwiId]!) as Map<String, dynamic>;
  (json['components'] as Map<String, dynamic>)['chat'] = chat;
  return ThemeFile.fromJson(json, base: json);
}

void main() {
  for (final chat in ['bubbles', 'blocks', 'transcript']) {
    for (final b in Brightness.values) {
      testWidgets('chat golden: $chat, ${b.name}', (tester) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final look = ThemeLibrary.look(_kiwiWithChat(chat), brightness: b, platform: TargetPlatform.linux);
        expect(look.variants.chat.key, chat);
        final backend = ScriptedBackend();
        final controller = ChatController(backend);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
          home: Material(child: ChatView(controller: controller)),
        ));
        await tester.enterText(find.byKey(ChatView.inputKey), 'When is the dentist?');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        backend.replies.last
          ..add(const MessageEvent(text: 'Your dentist appointment is on Tuesday 13 October at 09:30.', outcome: 'answered'))
          ..add(const DoneEvent());
        await backend.replies.last.close();
        await tester.pumpAndSettle();
        // Every style tells a screen reader who said what.
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel(RegExp(r'^You:\nWhen is the dentist\?$')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^myAssistant:\nYour dentist appointment')), findsOneWidget);
        semantics.dispose();
        if (chat == 'transcript') {
          expect(find.text(ChatView.youLabel), findsOneWidget);
          expect(find.text(ChatView.assistantLabel), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/chat.$chat.${b.name}.png'));
      });
    }
  }

  // Send is the composer's primary action, drawn as the theme draws a primary: a filled circle in Kiwi, an
  // outlined square with no fill in Journal (its rules: square corners, plum almost never a fill).
  for (final (slug, filled, square) in [('kiwi', true, false), ('journal', false, true)]) {
    testWidgets('send is drawn as $slug draws a primary button', (tester) async {
      tester.view.physicalSize = const Size(640, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final look = ThemeLibrary.lookFor(ThemeChoice('mydata.$slug'), Brightness.light, platform: TargetPlatform.linux);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
        home: Material(child: ChatView(controller: ChatController(ScriptedBackend()))),
      ));
      await tester.pumpAndSettle();
      final box = tester.widget<Container>(
          find.descendant(of: find.byKey(ChatView.sendKey), matching: find.byType(Container)).first);
      final paint = ButtonPaint.of(look, ButtonVariant.filled);
      final d = box.decoration!;
      final (Color? fill, ShapeBorder? border) = switch (d) {
        BoxDecoration() => (d.color, null),
        ShapeDecoration() => (d.color, d.shape),
        _ => (null, null),
      };
      expect(fill, filled ? look.colors.accent : isNull);
      expect(paint.side != null, !filled);
      if (square) {
        expect(d, isA<BoxDecoration>());
        expect((d as BoxDecoration).shape, BoxShape.rectangle);
        expect(d.borderRadius, BorderRadius.zero);
        expect(d.border, Border.fromBorderSide(paint.side!));
      } else {
        expect(border, isNull);
        expect((d as BoxDecoration).shape, BoxShape.circle);
      }
      await expectLater(find.byKey(ChatView.sendKey), matchesGoldenFile('goldens/send.$slug.light.png'));
    });
  }

  // The composer is a place to type: on E-ink's solid, unboxed page it takes a field's 1px ink outline, as
  // every field there has (its rules: inputs outlined); High Contrast and Large keep their card outline.
  for (final (slug, b) in [('e-ink', Brightness.light), ('e-ink', Brightness.dark)]) {
    testWidgets('the composer is outlined as a field in $slug, ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(640, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final look = ThemeLibrary.lookFor(ThemeChoice('mydata.$slug'), b, platform: TargetPlatform.linux);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
        home: Material(color: look.colors.bg, child: ChatView(controller: ChatController(ScriptedBackend()))),
      ));
      await tester.pumpAndSettle();
      final bar = find.ancestor(of: find.byKey(ChatView.inputKey), matching: find.byType(FloatingBarSurface));
      final edges = [
        for (final d in tester.widgetList<DecoratedBox>(find.descendant(of: bar, matching: find.byType(DecoratedBox))))
          switch (d.decoration) {
            BoxDecoration(:final Border border) => border.top,
            ShapeDecoration(:final OutlinedBorder shape) => shape.side,
            _ => BorderSide.none,
          },
      ].where((s) => s != BorderSide.none);
      expect(edges, contains(BorderSide(color: look.colors.ink)));
      await expectLater(bar, matchesGoldenFile('goldens/composer.$slug.${b.name}.png'));
    });
  }

  // A theme whose fields are underlined (Terminal's "underlined, like a prompt line", Journal, Paperback,
  // Notebook) draws the composer as a field there: the page's ground with a field's line under it, no box,
  // no card edge; an outlined theme keeps its box.
  for (final (slug, underlined) in [('terminal', true), ('journal', true), ('notebook', true), ('e-ink', false)]) {
    testWidgets('the composer is ${underlined ? 'underlined' : 'boxed'} in $slug', (tester) async {
      tester.view.physicalSize = const Size(640, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final look = ThemeLibrary.lookFor(ThemeChoice('mydata.$slug'), Brightness.light, platform: TargetPlatform.linux);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
        home: Material(color: look.colors.bg, child: ChatView(controller: ChatController(ScriptedBackend()))),
      ));
      await tester.pumpAndSettle();
      final bar = find.ancestor(of: find.byKey(ChatView.inputKey), matching: find.byType(FloatingBarSurface));
      final boxes = tester
          .widgetList<DecoratedBox>(find.descendant(of: bar, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .toList();
      final outer = boxes.first;
      if (underlined) {
        expect(outer, isA<BoxDecoration>());
        final d = outer as BoxDecoration;
        expect(d.color, look.colors.bg);
        expect(d.borderRadius, isNull);
        expect(d.boxShadow, isNull);
        expect((d.border! as Border).bottom, FloatingBarSurface.fieldSide(look));
        expect((d.border! as Border).top, BorderSide.none);
        expect(find.descendant(of: bar, matching: find.byType(CardEdge)), findsNothing);
      } else {
        expect(outer.isBox && outer.box.borderRadius != null, isTrue);
      }
    });
  }

  // A result is a card: where a theme's lists are plain but its cards are outlined (Terminal), the result's
  // rows sit in the card outline, as its rules box the result card; Notebook (no card outlines) and Sticker
  // (a bordered list that outlines itself) take no extra edge.
  for (final (slug, boxed) in [('terminal', true), ('notebook', false), ('sticker', false)]) {
    for (final b in Brightness.values) {
      testWidgets('a result is ${boxed ? '' : 'not '}boxed by its card edge in $slug, ${b.name}', (tester) async {
        final look = ThemeLibrary.lookFor(ThemeChoice('mydata.$slug'), b, platform: TargetPlatform.linux);
        await tester.pumpWidget(MaterialApp(
          theme: MyDataTheme.fromLook(look).copyWith(platform: TargetPlatform.linux),
          home: Material(
            color: look.colors.bg,
            child: const ResultCard(kind: 'events', header: '1 event: Dentist', items: [
              {'title': 'Dentist', 'date': '2026-03-20', 'start': '09:30', 'end': '10:15'},
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        final edge = find.ancestor(of: find.text('Dentist'), matching: find.byType(CardEdge));
        expect(edge, boxed ? findsOneWidget : findsNothing);
        if (boxed) expect(look.edges.card, isNotNull);
      });
    }
  }
}
