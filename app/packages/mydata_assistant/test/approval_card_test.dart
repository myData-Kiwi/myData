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
      theme: MyDataTheme.data('kiwi', Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssistantApprovalCard(
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

Pressable button(WidgetTester tester, String label) =>
    tester.widget<Pressable>(find.ancestor(of: find.text(label), matching: find.byType(Pressable)).first);

ApprovalOut _otherTool() => ApprovalOut.fromJson({
  ...approvalJson(),
  'tool': 'create_event',
  'args': {'title': 'Dentist', 'start_time': '2026-03-20T09:30', 'attendees': ['a@example.com', 'b@example.com']},
  'summary': 'Create an event: Dentist on 2026-03-20T09:30',
})!;

void main() {
  testWidgets('renders the design-system card: the question, the summary, who asked and every argument in full',
      (tester) async {
    await show(tester, approval());
    expect(find.byType(ApprovalCard), findsOneWidget);
    final card = tester.widget<ApprovalCard>(find.byType(ApprovalCard));
    expect(card.state, ApprovalState.pending);
    expect(card.onEdit, isNull, reason: 'the host has no way to edit a held call');
    expect(find.text('Send this email?'), findsOneWidget);
    expect(find.text(ApprovalCard.pendingLabel), findsOneWidget);
    // The host's summary of the call, whole.
    expect(find.text('Send an email to rishita@example.com: Dentist on Friday'), findsOneWidget);
    expect(find.text('Asked by assistant'), findsOneWidget);
    for (final name in ['To', 'Subject', 'Body']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Dentist on Friday'), findsOneWidget);
    // The address is mono; the whole multi-line body, character for character, in one unclipped text.
    final to = tester.widget<Text>(find.text('rishita@example.com'));
    expect(to.style?.fontFamily, MyDataType.mono.fontFamily);
    final body = tester.widget<Text>(find.text(longBody));
    expect(body.maxLines, isNull);
    expect(body.overflow, isNot(TextOverflow.ellipsis));
    expect(find.text('Approve and send'), findsOneWidget);
    expect(find.text(ApprovalCard.editLabel), findsNothing);
  });

  testWidgets('another tool: "Run <tool>?", its summary, "Approve and run", names in sentence case, values whole',
      (tester) async {
    await show(tester, _otherTool());
    // The question names the tool (create_event) in plain words.
    expect(find.text('Run create event?'), findsOneWidget);
    expect(find.text('Create an event: Dentist on 2026-03-20T09:30'), findsOneWidget);
    expect(find.text('Approve and run'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('2026-03-20T09:30'), findsOneWidget);
    // A list is shown whole, as JSON.
    expect(find.textContaining('"a@example.com"'), findsOneWidget);
    expect(find.textContaining('"b@example.com"'), findsOneWidget);
  });

  testWidgets('Approve and Reject call their callbacks', (tester) async {
    var approved = 0, rejected = 0;
    await show(tester, approval(), onApprove: () => approved++, onReject: () => rejected++);
    await tester.tap(find.text('Approve and send'));
    await tester.tap(find.text('Reject'));
    expect((approved, rejected), (1, 1));
  });

  testWidgets('buttons are disabled while deciding, with a loader and the reason', (tester) async {
    var taps = 0;
    await show(tester, approval(), deciding: true, onApprove: () => taps++, onReject: () => taps++);
    expect(button(tester, 'Approve and send').onPressed, isNull);
    expect(button(tester, 'Reject').onPressed, isNull);
    expect(find.byType(KiwiLoader), findsOneWidget);
    expect(find.text(AssistantApprovalCard.sendingText), findsOneWidget);
    await tester.tap(find.text('Approve and send'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('a failed decision is shown and the call can be decided again', (tester) async {
    await show(tester, approval(), error: 'already decided');
    expect(find.textContaining('already decided'), findsOneWidget);
    expect(button(tester, 'Approve and send').onPressed, isNotNull);
  });

  testWidgets('approved: "Sent", who decided, the result, the arguments, and no buttons', (tester) async {
    await show(
      tester,
      approval(
        status: 'approved',
        decidedBy: 'app:myassistant',
        result: {'status': 'sent', 'to': 'rishita@example.com'},
      ),
    );
    expect(tester.widget<ApprovalCard>(find.byType(ApprovalCard)).state, ApprovalState.approved);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Decided by app:myassistant'), findsOneWidget);
    expect(find.textContaining('"status": "sent"'), findsOneWidget);
    expect(find.text('Approve and send'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text(longBody), findsOneWidget);
  });

  testWidgets('another tool approved: "Done"', (tester) async {
    await show(tester, ApprovalOut.fromJson({...approvalJson(status: 'approved'), 'tool': 'create_event'})!);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('rejected and failed outcomes', (tester) async {
    await show(tester, approval(status: 'rejected', decidedBy: 'app:mydata'));
    expect(tester.widget<ApprovalCard>(find.byType(ApprovalCard)).state, ApprovalState.rejected);
    expect(find.text(ApprovalCard.rejectedLabel), findsOneWidget);
    expect(find.text('Decided by app:mydata'), findsOneWidget);
    expect(find.text('Approve and send'), findsNothing);

    await show(tester, approval(status: 'failed', decidedBy: 'app:myassistant', error: 'SMTP refused'));
    expect(tester.widget<ApprovalCard>(find.byType(ApprovalCard)).state, ApprovalState.failed);
    expect(find.text(ApprovalCard.failedLabel), findsOneWidget);
    expect(find.textContaining('SMTP refused'), findsOneWidget);
    expect(find.text('Approve and send'), findsNothing);
  });
}
