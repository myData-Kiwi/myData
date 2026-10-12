import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

/// The preview's sample data.
const _args = [
  ('To', 'marco.bianchi@example.com'),
  ('Subject', 'Booking reference for the Mysuru train'),
  ('Message', 'Booking reference RB-58213. Train 16231 departs Bengaluru at 07:15 on Sunday 29 March.'),
];

ApprovalCard _card({
  ApprovalState state = ApprovalState.pending,
  VoidCallback? onApprove = _noop,
  VoidCallback? onEdit = _noop,
  VoidCallback? onReject = _noop,
  VoidCallback? onSourceTap = _noop,
  String? error,
  List<(String, String)> arguments = _args,
}) => ApprovalCard(
  question: 'Send this email?',
  arguments: arguments,
  approveLabel: 'Approve and send',
  decidedLabel: 'Sent',
  state: state,
  onApprove: onApprove,
  onEdit: onEdit,
  onReject: onReject,
  sourceNote: 'Every fact in this message came from your data.',
  sourceLabel: 'Train booking confirmation',
  onSourceTap: onSourceTap,
  error: error,
);

/// The preview's max-width.
const _cardWidth = 560.0;

/// The four states, two by two: pending and approved, then rejected and failed.
Widget _allStates() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _cardWidth, child: _card()),
        const SizedBox(width: MyDataSpace.s4),
        SizedBox(
          width: _cardWidth,
          child: _card(state: ApprovalState.approved),
        ),
      ],
    ),
    // Room for the pending card's shadow-2.
    const SizedBox(height: MyDataSpace.s6),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _cardWidth,
          child: _card(state: ApprovalState.rejected),
        ),
        const SizedBox(width: MyDataSpace.s4),
        SizedBox(
          width: _cardWidth,
          child: _card(
            state: ApprovalState.failed,
            error: 'The mail server did not answer. Nothing was sent; try again in a minute.',
          ),
        ),
      ],
    ),
  ],
);

/// A card whose state can be changed from the test.
class _Harness extends StatefulWidget {
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  ApprovalState state = ApprovalState.pending;
  int approved = 0;
  int rejected = 0;
  void set(ApprovalState s) => setState(() => state = s);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: _cardWidth,
    child: _card(state: state, onApprove: () => approved++, onReject: () => rejected++),
  );
}

BoxDecoration _cardDecoration(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first).decoration! as BoxDecoration;

void main() {
  goldenMatrix('approval_card', _allStates, size: const Size(1184, 640));

  testWidgets('pending: surface, radius-lg, shadow-2, the warning chip and the three actions in order', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    final context = tester.element(find.byType(ApprovalCard));
    final d = _cardDecoration(tester);
    expect(d.color, context.colors.surface);
    expect(d.borderRadius, MyDataRadii.lg);
    expect(d.boxShadow, context.shadows.shadow2);

    final chip = tester.widget<MyDataBadge>(find.byType(MyDataBadge));
    expect(chip.label, 'Needs approval');
    expect(chip.tone, MyDataTone.warning);

    expect(tester.widget<Text>(find.text('Send this email?')).style!.fontSize, MyDataType.title.fontSize);

    final buttons = tester.widgetList<Button>(find.byType(Button)).toList();
    expect(buttons.map((b) => b.label), ['Approve and send', 'Edit', 'Reject']);
    expect(buttons.map((b) => b.variant), [ButtonVariant.filled, ButtonVariant.tonal, ButtonVariant.plain]);
    final xs = [
      for (final l in ['Approve and send', 'Edit', 'Reject']) tester.getRect(find.widgetWithText(Button, l)),
    ];
    expect(xs[1].left - xs[0].right, MyDataSpace.s2);
    expect(xs[2].left - xs[1].right, MyDataSpace.s2);
  });

  testWidgets('every argument is shown in full: names caption ink-muted, addresses mono, the rest body', (
    tester,
  ) async {
    const long =
        'A very long message that goes on and on, line after line, so that it must wrap across several '
        'lines in the well and is still shown to the very last word, with nothing cut: the end.';
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(
          width: _cardWidth,
          child: _card(arguments: [..._args, ('Note', long), ('Attachment', '')]),
        ),
      ),
    );
    final c = tester.element(find.byType(ApprovalCard)).colors;
    for (final (name, value) in [..._args, ('Note', long)]) {
      final nameText = tester.widget<Text>(find.text(name));
      expect(nameText.style!.fontSize, MyDataType.caption.fontSize, reason: name);
      expect(nameText.style!.color, c.inkMuted, reason: name);
      final valueText = tester.widget<Text>(find.text(value));
      expect(valueText.maxLines, isNull, reason: name);
      expect(valueText.overflow, isNull, reason: name);
      expect(valueText.style!.color, c.ink, reason: name);
    }
    expect(tester.widget<Text>(find.text('marco.bianchi@example.com')).style!.fontFamily, MyDataType.mono.fontFamily);
    expect(tester.widget<Text>(find.text(_args[1].$2)).style!.fontFamily, MyDataType.body.fontFamily);
    // An empty value is still a visible row.
    expect(find.text('Attachment'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    // The well: surface-sunken, radius-md.
    final well = tester.widget<Container>(
      find.ancestor(of: find.byType(Table), matching: find.byType(Container)).first,
    );
    expect((well.decoration! as BoxDecoration).color, c.surfaceSunken);
    expect((well.decoration! as BoxDecoration).borderRadius, MyDataRadii.md);
    expect(tester.takeException(), isNull);
  });

  test('looksLikeAddress: addresses, URLs and paths, not sentences', () {
    for (final v in [
      'marco.bianchi@example.com',
      'Marco Bianchi <marco@example.com>',
      'a@example.com, b@example.org',
      'https://mydata.kiwi/help',
      '/Users/me/Documents/report.pdf',
      '~/Pictures',
      r'C:\Users\me',
    ]) {
      expect(ApprovalCard.looksLikeAddress(v), isTrue, reason: v);
    }
    for (final v in ['', 'Booking reference for the Mysuru train', 'Meet at 7/8', 'a/b', 'see a@b.com today']) {
      expect(ApprovalCard.looksLikeAddress(v), isFalse, reason: v);
    }
  });

  testWidgets('tap, Enter and Space call the callbacks; Tab order is source link, approve, edit, reject', (
    tester,
  ) async {
    var approved = 0, edited = 0, rejected = 0, opened = 0;
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(
          width: _cardWidth,
          child: _card(
            onApprove: () => approved++,
            onEdit: () => edited++,
            onReject: () => rejected++,
            onSourceTap: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Approve and send'));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.text('Reject'));
    await tester.tap(find.text('Train booking confirmation'));
    expect((approved, edited, rejected, opened), (1, 1, 1, 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(approved, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(edited, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(rejected, 2);
  });

  testWidgets('Edit is left out without onEdit; null callbacks disable approve and reject', (tester) async {
    var approved = 0;
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(width: _cardWidth, child: _card(onEdit: null, onApprove: null, onReject: null)),
      ),
    );
    expect(find.text('Edit'), findsNothing);
    expect(find.byType(Button), findsNWidgets(2));
    await tester.tap(find.text('Approve and send'), warnIfMissed: false);
    expect(approved, 0);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.widgetWithText(Button, 'Approve and send')),
      isSemantics(label: 'Approve and send', isButton: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('every target is at least 44px, including the source link', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    for (final f in [
      find.widgetWithText(Button, 'Approve and send'),
      find.widgetWithText(Button, 'Edit'),
      find.widgetWithText(Button, 'Reject'),
      find.ancestor(of: find.text('Train booking confirmation'), matching: find.byType(Pressable)),
    ]) {
      final size = tester.getSize(f);
      expect(size.height, greaterThanOrEqualTo(MyDataSize.controlHeight));
      expect(size.width, greaterThanOrEqualTo(MyDataSize.controlHeight));
    }
  });

  testWidgets('the source is an underlined accent link; without onSourceTap it is plain caption text', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    final c = tester.element(find.byType(ApprovalCard)).colors;
    final link = tester.widget<Text>(find.text('Train booking confirmation'));
    expect(link.style!.color, c.accent);
    expect(link.style!.decoration, TextDecoration.underline);
    expect(find.text('Every fact in this message came from your data. Source: '), findsOneWidget);

    await tester.pumpWidget(
      themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card(onSourceTap: null))),
    );
    expect(find.byType(Pressable), findsNWidgets(3));
    expect(find.textContaining('Source: Train booking confirmation', findRichText: true), findsOneWidget);
  });

  testWidgets('the note takes its own line when it does not fit beside the link', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    final noteTop = tester.getRect(find.textContaining('Every fact')).center.dy;
    final linkTop = tester.getRect(find.text('Train booking confirmation')).center.dy;
    expect((noteTop - linkTop).abs(), lessThan(1), reason: 'one line at the preview width');

    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: 340, child: _card())));
    final note = tester.getRect(find.text('Every fact in this message came from your data.'));
    final link = tester.getRect(find.text('Train booking confirmation'));
    final well = tester.getRect(find.ancestor(of: find.byType(Table), matching: find.byType(Container)).first);
    expect(link.top, greaterThan(note.bottom));
    expect(note.top - well.bottom, MyDataSpace.s3);
    expect(
      tester
          .getSize(find.ancestor(of: find.text('Train booking confirmation'), matching: find.byType(Pressable)))
          .height,
      greaterThanOrEqualTo(MyDataSize.controlHeight),
    );
  });

  testWidgets('semantics: the question is a header, the chip is a live region, the source a link', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    expect(tester.getSemantics(find.text('Send this email?')), isSemantics(label: 'Send this email?', isHeader: true));
    expect(find.bySemanticsLabel('Needs approval'), findsOneWidget);
    final live = find.ancestor(
      of: find.byType(MyDataBadge),
      matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true),
    );
    expect(live, findsOneWidget);
    expect(
      find.semantics.byPredicate((n) => n.label == 'Train booking confirmation' && n.flagsCollection.isLink),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('marco.bianchi@example.com'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('semantics: the card is a region named "Approval needed", then "Approval request"', (tester) async {
    final handle = tester.ensureSemantics();
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Harness(key: key)));
    final region = find.semantics.byPredicate((n) => n.label == ApprovalCard.pendingRegionLabel);
    expect(region, findsOneWidget);
    // The region holds the question, the arguments and the actions as its own children.
    final node = region.evaluate().single;
    final labels = <String>[];
    node.visitChildren((child) {
      void walk(SemanticsNode n) {
        labels.add(n.label);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(child);
      return true;
    });
    expect(labels, containsAll(['Send this email?', 'Needs approval', 'Approve and send', 'Reject']));

    key.currentState!.set(ApprovalState.approved);
    await tester.pumpAndSettle();
    expect(find.semantics.byPredicate((n) => n.label == ApprovalCard.pendingRegionLabel), findsNothing);
    expect(find.semantics.byPredicate((n) => n.label == ApprovalCard.decidedRegionLabel), findsOneWidget);
    handle.dispose();
  });

  testWidgets('keyboard: after deciding with Enter, focus moves to the card and Tab continues inside it', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pressable(onPressed: _noop, borderRadius: MyDataRadii.sm, child: const Text('Before')),
            _Harness(key: key),
          ],
        ),
      ),
    );
    Element cardElement() => tester.element(find.byType(ApprovalCard));
    bool insideCard(FocusNode? n) {
      final ctx = n?.context;
      if (ctx == null) return false;
      var inside = false;
      ctx.visitAncestorElements((e) {
        if (e == cardElement()) inside = true;
        return !inside;
      });
      return inside;
    }

    // Before, the source link, then Approve.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    final approveContext = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(
        of: find.byElementPredicate((e) => e == approveContext),
        matching: find.widgetWithText(Button, 'Approve and send'),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(key.currentState!.approved, 1);

    key.currentState!.set(ApprovalState.approved);
    await tester.pumpAndSettle();
    expect(find.byType(Button), findsNothing);
    final focused = FocusManager.instance.primaryFocus;
    expect(insideCard(focused), isTrue, reason: 'focus stays in the card, not at the window');
    // It is the card itself, which shows the focus ring.
    final ring = tester.widget<FocusRing>(
      find.descendant(of: find.byType(ApprovalCard), matching: find.byType(FocusRing)).first,
    );
    expect(ring.visible, isTrue);
    expect(ring.borderRadius, MyDataRadii.lg);

    // The next Tab reaches the source link, inside the card.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final linkPressable = find.ancestor(of: find.text('Train booking confirmation'), matching: find.byType(Pressable));
    final next = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.ancestor(of: find.byElementPredicate((e) => e == next), matching: linkPressable).evaluate().isNotEmpty ||
          find.descendant(of: linkPressable, matching: find.byElementPredicate((e) => e == next)).evaluate().isNotEmpty,
      isTrue,
    );
    // The card is not a Tab stop of its own: Shift+Tab from the link goes back to Before.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();
    expect(insideCard(FocusManager.instance.primaryFocus), isFalse);
  });

  testWidgets('a decision does not take focus when the actions did not have it', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Harness(key: key)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // the source link
    await tester.pump();
    final link = FocusManager.instance.primaryFocus;
    key.currentState!.set(ApprovalState.rejected);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(link));
  });

  testWidgets('a decision changes the chip, removes the actions and drops the shadow over fast', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Harness(key: key)));
    final context = tester.element(find.byType(ApprovalCard));
    final pendingHeight = tester.getSize(find.byType(ApprovalCard)).height;

    key.currentState!.set(ApprovalState.approved);
    await tester.pump();
    // Mid-change: the outgoing buttons fade and cannot be pressed.
    await tester.pump(MyDataMotion.fast ~/ 2);
    expect(tester.hasRunningAnimations, isTrue);
    await tester.tap(find.text('Reject'), warnIfMissed: false);
    expect(key.currentState!.rejected, 0);

    await tester.pumpAndSettle();
    expect(find.byType(Button), findsNothing);
    final chip = tester.widget<MyDataBadge>(find.byType(MyDataBadge));
    expect((chip.label, chip.tone), ('Sent', MyDataTone.success));
    expect(_cardDecoration(tester).boxShadow, context.shadows.shadow1);
    expect(tester.getSize(find.byType(ApprovalCard)).height, lessThan(pendingHeight));
  });

  testWidgets('rejected is a neutral "Rejected" chip; failed is a danger "Failed" chip with the error', (tester) async {
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(
          width: _cardWidth,
          child: _card(state: ApprovalState.rejected),
        ),
      ),
    );
    var chip = tester.widget<MyDataBadge>(find.byType(MyDataBadge));
    expect((chip.label, chip.tone), ('Rejected', MyDataTone.neutral));
    expect(find.byType(Button), findsNothing);

    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        SizedBox(
          width: _cardWidth,
          child: _card(state: ApprovalState.failed, error: 'The mail server did not answer. Try again.'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    chip = tester.widget<MyDataBadge>(find.byType(MyDataBadge));
    expect((chip.label, chip.tone), ('Failed', MyDataTone.danger));
    final c = tester.element(find.byType(ApprovalCard)).colors;
    expect(tester.widget<Text>(find.text('The mail server did not answer. Try again.')).style!.color, c.danger);
    expect(find.byType(Button), findsNothing);
  });

  testWidgets('reduced motion: only fades, no size easing; the decision lands after a fast fade', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(themedFrame(themeMatrix.first, _Harness(key: key), reduceMotion: true));
    expect(find.descendant(of: find.byType(ApprovalCard), matching: find.byType(AnimatedSize)), findsNothing);
    expect(find.descendant(of: find.byType(ApprovalCard), matching: find.byType(ScaleTransition)), findsNothing);

    key.currentState!.set(ApprovalState.rejected);
    await tester.pump(); // rebuilds; the fades start on the next frame
    await tester.pump(MyDataMotion.fast);
    await tester.pump(MyDataMotion.fast);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(Button), findsNothing);
    expect(tester.widget<MyDataBadge>(find.byType(MyDataBadge)).label, 'Rejected');
  });

  testWidgets('without reduced motion the chip and actions ease their size', (tester) async {
    await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: _cardWidth, child: _card())));
    expect(find.descendant(of: find.byType(ApprovalCard), matching: find.byType(AnimatedSize)), findsNWidgets(2));
  });

  testWidgets('scaled text and a narrow width wrap instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedFrame(
        themeMatrix.first,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: SizedBox(width: 340, child: _card()),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
