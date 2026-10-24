// The chat variants (design/themes/ARCHITECTURE.md 3.2): myAssistant's conversation as bubbles, blocks or a
// transcript, one golden per value in light and dark, each Kiwi with that one value changed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/theme/builtin_themes.g.dart';

import 'chat_view_test.dart' show ScriptedBackend;

ThemeFile _kiwiWithChat(String chat) {
  final json = jsonDecode(kiwiThemeJson) as Map<String, dynamic>;
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
}
