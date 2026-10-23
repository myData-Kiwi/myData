import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}

ActionRow _connected() => ActionRow(
  icon: Icons.key_outlined,
  title: 'Claude on my laptop',
  subtitle: 'Created 1 Oct, last seen today',
  badge: const MyDataBadge('Connected', tone: MyDataTone.success),
  actions: const [Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop)],
);

Widget _frame(Widget child, {double width = 640}) => themedFrame(themeMatrix.first, SizedBox(width: width, child: child));

void main() {
  goldenMatrix(
    'action_row',
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 640,
          child: GroupedSection(
            heading: 'Agents',
            parts: [
              _connected(),
              ActionRow(
                icon: Icons.key_outlined,
                title: 'Notes sync script',
                subtitle: 'Created 1 Oct, last seen 9 Oct',
                badge: const MyDataBadge('Not connected', tone: MyDataTone.neutral),
                actions: const [Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop)],
              ),
              ActionRow(
                icon: Icons.key_outlined,
                title: 'Old test agent',
                subtitle: 'Created 1 Oct, never used',
                badge: const MyDataBadge('Revoked', tone: MyDataTone.neutral),
              ),
              ActionRow(
                title: 'The agent list could not be read',
                subtitle: 'The host did not answer. Check that it is running, then try again.',
                actions: const [Button(label: 'Retry', onPressed: _noop)],
              ),
            ],
          ),
        ),
        const SizedBox(height: MyDataSpace.s6),
        SizedBox(
          width: 340,
          child: GroupedSection(
            heading: 'Agents, narrow',
            parts: [
              _connected(),
              // A short title with a long caption also moves its chip and button under the text.
              ActionRow(
                icon: Icons.key_outlined,
                title: 'Laptop',
                subtitle: 'Created 1 Oct at home, last seen today at the office',
                badge: const MyDataBadge('Connected', tone: MyDataTone.success),
                actions: const [Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop)],
              ),
            ],
          ),
        ),
      ],
    ),
    size: const Size(688, 640),
  );

  testWidgets('wide: chip and buttons beside the text, at the end, centred on the row', (tester) async {
    await tester.pumpWidget(_frame(GroupedSection(heading: 'Agents', parts: [_connected()])));
    final row = tester.getRect(find.byType(ActionRow));
    final title = tester.getRect(find.text('Claude on my laptop'));
    final revoke = tester.getRect(find.byType(Button));
    final chip = tester.getRect(find.byType(MyDataBadge));
    final tile = tester.getRect(find.byType(IconTile));
    // The 44px button and the row's vertical padding make it taller than row-height, as in the preview.
    expect(row.height, MyDataSize.controlHeight + GroupedRow.padding(kiwiLook).vertical);
    expect(revoke.right, row.right - GroupedRow.padding(kiwiLook).right);
    expect(revoke.left - chip.right, ActionRow.endGap(kiwiLook));
    expect(revoke.center.dy, moreOrLessEquals(row.center.dy));
    expect(chip.center.dy, moreOrLessEquals(row.center.dy));
    expect(tile.left, row.left + GroupedRow.padding(kiwiLook).left);
    expect(title.left, tile.right + GroupedRow.gap(kiwiLook));
  });

  ActionRow laptop(String subtitle) => ActionRow(
    icon: Icons.key_outlined,
    title: 'Laptop',
    subtitle: subtitle,
    badge: const MyDataBadge('Connected', tone: MyDataTone.success),
    actions: const [Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop)],
  );
  const longCaption = 'Created 1 Oct at home, last seen today at the office in town';
  final captionLine = MyDataType.caption.fontSize! * MyDataType.caption.height!;
  final titleLine = MyDataType.bodyStrong.fontSize! * MyDataType.bodyStrong.height!;

  testWidgets('when it narrows the caption wraps first, the title stays on one line beside the buttons',
      (tester) async {
    await tester.pumpWidget(_frame(laptop(longCaption), width: 560));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Laptop'));
    final caption = tester.getRect(find.text(longCaption));
    final revoke = tester.getRect(find.byType(Button));
    // Beside: the button is to the right of the text, not under it.
    expect(revoke.left, greaterThan(caption.right));
    expect(revoke.top, lessThan(caption.bottom));
    // The caption wrapped (more than one caption line); the title did not.
    expect(caption.height, greaterThan(captionLine * 1.5));
    expect(title.height, moreOrLessEquals(titleLine, epsilon: 0.5));
  });

  testWidgets('a short title with a long caption: the end part moves under the text rather than squeeze '
      'the caption into a narrow column', (tester) async {
    // At 340 the short title alone would leave room for the chip and button, but only about 60px of text.
    await tester.pumpWidget(_frame(laptop(longCaption), width: 340));
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Laptop'));
    final caption = tester.getRect(find.text(longCaption));
    final chip = tester.getRect(find.byType(MyDataBadge));
    expect(chip.left, title.left);
    expect(chip.top, greaterThanOrEqualTo(caption.bottom + GroupedRow.gap(kiwiLook) - 0.01));
    expect(caption.width, greaterThanOrEqualTo(ActionRow.minTextWidth(kiwiLook)));
    expect(caption.height, lessThanOrEqualTo(captionLine * 2 + 0.5), reason: 'at most two caption lines');
  });

  testWidgets('a short title with a short caption keeps the end part beside it', (tester) async {
    await tester.pumpWidget(_frame(laptop('Created today'), width: 420));
    expect(tester.takeException(), isNull);
    final caption = tester.getRect(find.text('Created today'));
    final revoke = tester.getRect(find.byType(Button));
    expect(revoke.left, greaterThan(caption.right));
    expect(revoke.top, lessThan(caption.bottom));
    expect(caption.height, moreOrLessEquals(captionLine, epsilon: 0.5));
  });

  testWidgets('narrow (340): chip and buttons move under the text, aligned to its start; no overflow',
      (tester) async {
    await tester.pumpWidget(_frame(GroupedSection(heading: 'Agents', parts: [_connected()]), width: 340));
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(ActionRow));
    final title = tester.getRect(find.text('Claude on my laptop'));
    final caption = tester.getRect(find.text('Created 1 Oct, last seen today'));
    final chip = tester.getRect(find.byType(MyDataBadge));
    final revoke = tester.getRect(find.byType(Button));
    expect(chip.left, title.left);
    expect(chip.top, greaterThanOrEqualTo(caption.bottom + GroupedRow.gap(kiwiLook) - 0.01));
    expect(revoke.left - chip.right, ActionRow.endGap(kiwiLook));
    expect(revoke.right, lessThanOrEqualTo(row.right - GroupedRow.padding(kiwiLook).right));
    expect(row.height, greaterThan(MyDataSize.rowHeight));
    expect(revoke.bottom, lessThanOrEqualTo(row.bottom - GroupedRow.padding(kiwiLook).bottom + 0.01));
    // The title kept one line now that it has the full width.
    expect(title.height, moreOrLessEquals(MyDataType.bodyStrong.fontSize! * MyDataType.bodyStrong.height!, epsilon: 0.5));
  });

  testWidgets('very narrow with two buttons: everything wraps, nothing overflows', (tester) async {
    await tester.pumpWidget(_frame(
      ActionRow(
        icon: Icons.key_outlined,
        title: 'Claude on my laptop and the long name of its computer',
        subtitle: 'Created 1 Oct, last seen today',
        badge: const MyDataBadge('Not connected', tone: MyDataTone.neutral),
        actions: const [
          Button(label: 'Reconnect', onPressed: _noop),
          Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop),
        ],
      ),
      width: 220,
    ));
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(ActionRow));
    for (final e in find.byType(Button).evaluate()) {
      expect(tester.getRect(find.byWidget(e.widget)).right, lessThanOrEqualTo(row.right));
    }
  });

  testWidgets('the buttons are the only targets: the row is not pressable and has no hover fill',
      (tester) async {
    var retried = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_frame(ActionRow(
      title: 'The agent list could not be read',
      subtitle: 'The host did not answer.',
      actions: [Button(label: 'Retry', onPressed: () => retried++)],
    )));
    final pressables = find.descendant(of: find.byType(ActionRow), matching: find.byType(Pressable));
    expect(pressables, findsOneWidget);
    expect(find.descendant(of: pressables, matching: find.text('Retry')), findsOneWidget);
    expect(tester.widget<Pressable>(pressables).hoverFill, isNull);
    // Tapping the text does nothing; the title is plain text, not a button.
    await tester.tap(find.text('The agent list could not be read'), warnIfMissed: false);
    expect(retried, 0);
    expect(tester.getSemantics(find.text('The agent list could not be read')).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    handle.dispose();
  });

  testWidgets('a revoked item keeps its row and neutral chip and has no buttons', (tester) async {
    await tester.pumpWidget(_frame(ActionRow(
      icon: Icons.key_outlined,
      title: 'Old test agent',
      subtitle: 'Created 1 Oct, never used',
      badge: const MyDataBadge('Revoked', tone: MyDataTone.neutral),
    )));
    expect(find.byType(Button), findsNothing);
    expect(tester.widget<MyDataBadge>(find.byType(MyDataBadge)).tone, MyDataTone.neutral);
    expect(tester.widget<IconTile>(find.byType(IconTile)).tone, MyDataTone.neutral);
    final row = tester.getRect(find.byType(ActionRow));
    final chip = tester.getRect(find.byType(MyDataBadge));
    expect(chip.right, row.right - GroupedRow.padding(kiwiLook).right);
  });

  testWidgets('a plain danger action is danger text with no fill', (tester) async {
    await tester.pumpWidget(_frame(_connected()));
    final c = tester.element(find.byType(ActionRow)).colors;
    expect(tester.widget<Text>(find.text('Revoke')).style!.color, c.danger);
    final fill = (tester.widget<Container>(
      find.ancestor(of: find.text('Revoke'), matching: find.byType(Container)).first,
    ).decoration! as BoxDecoration).color;
    expect(fill, isNull);
  });

  test('at most two actions, and never filled or danger', () {
    expect(
      () => ActionRow(
        title: 'x',
        actions: const [
          Button(label: 'a', onPressed: _noop),
          Button(label: 'b', onPressed: _noop),
          Button(label: 'c', onPressed: _noop),
        ],
      ),
      throwsAssertionError,
    );
    expect(
      () => ActionRow(title: 'x', actions: const [Button(label: 'a', variant: ButtonVariant.filled, onPressed: _noop)]),
      throwsAssertionError,
    );
    expect(
      () => ActionRow(title: 'x', actions: const [Button(label: 'a', variant: ButtonVariant.danger, onPressed: _noop)]),
      throwsAssertionError,
    );
    for (final v in ActionRow.allowedVariants) {
      ActionRow(title: 'x', actions: [Button(label: 'a', variant: v, onPressed: _noop)]);
    }
  });

  testWidgets('measured inside IntrinsicHeight it lays out the same', (tester) async {
    await tester.pumpWidget(_frame(IntrinsicHeight(child: _connected()), width: 340));
    expect(tester.takeException(), isNull);
    final intrinsic = tester.getSize(find.byType(ActionRow)).height;
    await tester.pumpWidget(_frame(_connected(), width: 340));
    expect(tester.getSize(find.byType(ActionRow)).height, intrinsic);
  });
}
