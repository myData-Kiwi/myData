import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_assistant/mydata_assistant.dart';
import 'package:mydata_client/api.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'fixtures.dart';

Future<void> show(
  WidgetTester tester,
  ApprovalOut a, {
  bool deciding = false,
  String? error,
  VoidCallback? onApprove,
  VoidCallback? onReject,
}) {
  // Tall enough that the whole card, buttons included, is on screen.
  tester.view
    ..physicalSize = const Size(900, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: legacyTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ApprovalCard(
            approval: a,
            deciding: deciding,
            error: error,
            onApprove: onApprove ?? () {},
            onReject: onReject ?? () {},
          ),
        ),
      ),
    ),
  );
}

ButtonStyleButton button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
  find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()),
);

void main() {
  testWidgets('shows the tool, the summary, who asked and every argument in full', (tester) async {
    await show(tester, approval());
    expect(find.text('send_mail'), findsOneWidget);
    expect(find.text('Send an email to rishita@example.com: Dentist on Friday'), findsOneWidget);
    expect(find.text('assistant'), findsOneWidget);
    for (final key in ['to', 'subject', 'body']) {
      expect(find.text(key), findsOneWidget);
    }
    expect(find.text('rishita@example.com'), findsOneWidget);
    expect(find.text('Dentist on Friday'), findsOneWidget);
    // The whole multi-line body, character for character, in one unclipped text.
    final full = find.byWidgetPredicate((w) => w is SelectableText && w.data == longBody);
    expect(full, findsOneWidget);
    final body = tester.widget<SelectableText>(full);
    expect(body.maxLines, isNull);
    expect(body.style?.fontFamily, contains(LegacyFonts.mono));
  });

  testWidgets('Approve and Reject call their callbacks', (tester) async {
    var approved = 0, rejected = 0;
    await show(tester, approval(), onApprove: () => approved++, onReject: () => rejected++);
    await tester.tap(find.text('Approve'));
    await tester.tap(find.text('Reject'));
    expect((approved, rejected), (1, 1));
  });

  testWidgets('buttons are disabled while deciding', (tester) async {
    var taps = 0;
    await show(tester, approval(), deciding: true, onApprove: () => taps++, onReject: () => taps++);
    expect(button(tester, 'Approve').onPressed, isNull);
    expect(button(tester, 'Reject').onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Approve'));
    expect(taps, 0);
  });

  testWidgets('a failed decision is shown and the call can be decided again', (tester) async {
    await show(tester, approval(), error: 'already decided');
    expect(find.textContaining('already decided'), findsOneWidget);
    expect(button(tester, 'Approve').onPressed, isNotNull);
  });

  testWidgets('approved: outcome, who decided, the result, and no buttons', (tester) async {
    await show(
      tester,
      approval(
        status: 'approved',
        decidedBy: 'app:myassistant',
        result: {'status': 'sent', 'to': 'rishita@example.com'},
      ),
    );
    expect(find.text('Approved and sent'), findsOneWidget);
    expect(find.text('Decided by app:myassistant'), findsOneWidget);
    expect(find.textContaining('"status": "sent"'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text(longBody), findsOneWidget);
  });

  testWidgets('rejected and failed outcomes', (tester) async {
    await show(tester, approval(status: 'rejected', decidedBy: 'app:mydata'));
    expect(find.text('Rejected. Nothing was done.'), findsOneWidget);
    expect(find.text('Decided by app:mydata'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);

    await show(tester, approval(status: 'failed', decidedBy: 'app:myassistant', error: 'SMTP refused'));
    expect(find.text('Failed: SMTP refused'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });
}
