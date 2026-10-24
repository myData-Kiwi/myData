import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

void _noop() {}
void _noopString(String _) {}
void _noopBool(bool _) {}
void _noopMode(_Mode _) {}

enum _Mode { light, dark, system }

/// The Appearance section as Settings builds it.
GroupedSection _appearance() => GroupedSection(
  heading: 'Appearance',
  parts: [
    const GroupedContentPart(
      child: GroupedStack(
        children: [
          GroupedControl(label: 'Theme', child: ThemePicker(selected: 'kiwi', onChanged: _noopString)),
          GroupedControl(
            label: 'Mode',
            child: SegmentedControl<_Mode>(
              segments: [(_Mode.light, 'Light'), (_Mode.dark, 'Dark'), (_Mode.system, 'Match system')],
              selected: _Mode.system,
              onChanged: _noopMode,
              semanticLabel: 'Mode',
            ),
          ),
          ThemeSample(themeId: 'kiwi'),
        ],
      ),
    ),
    const GroupedRow.toggle(
      icon: MyDataIcon.assistant,
      title: 'Assistant',
      subtitle: 'Ready. Switching it off unloads the model.',
      value: true,
      onChanged: _noopBool,
    ),
  ],
);

final _name = TextEditingController();

/// The Agents section: a note, a field and the one filled button, then the agents.
GroupedSection _agents() => GroupedSection(
  heading: 'Agents',
  parts: [
    GroupedContentPart(
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "An agent reaches myData's tools with a token of its own.",
              style: MyDataType.body.copyWith(color: context.colors.inkMuted),
            ),
            const SizedBox(height: MyDataSpace.s4),
            MyDataTextField(
              label: 'Name',
              controller: _name,
              placeholder: 'For example, Claude on my laptop',
              help: 'Name it after the agent and the computer it runs on.',
            ),
            const SizedBox(height: MyDataSpace.s4),
            const Button(label: 'Create an agent token', variant: ButtonVariant.filled, onPressed: _noop),
          ],
        ),
      ),
    ),
    ActionRow(
      icon: MyDataIcon.key,
      title: 'Claude on my laptop',
      subtitle: 'Created 1 Oct, last seen today',
      badge: const MyDataBadge('Connected', tone: MyDataTone.success),
      actions: const [Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: _noop)],
    ),
    ActionRow(
      icon: MyDataIcon.key,
      title: 'Old test agent',
      subtitle: 'Created 1 Oct, never used',
      badge: const MyDataBadge('Revoked', tone: MyDataTone.neutral),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(themedFrame(themeMatrix.first, SizedBox(width: 700, child: child)));
}

void main() {
  goldenMatrix(
    'grouped_section',
    () => SizedBox(
      width: 700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_appearance(), const SizedBox(height: MyDataSpace.s6), _agents()],
      ),
    ),
    size: const Size(748, 1072),
  );

  testWidgets('a full-width line divider between every two parts, none at the ends', (tester) async {
    await _pump(tester, _agents());
    final c = tester.element(find.byType(GroupedSection)).colors;
    final dividers = find.descendant(
      of: find.byType(GroupedSection),
      matching: find.byType(EdgeRule),
    );
    expect(dividers, findsNWidgets(2));
    expect(tester.element(dividers.first).look.edges.colour, c.line);
    expect(tester.getSize(dividers.first).height, GroupedList.dividerWidth);
    final group = tester.getRect(find.byType(GroupedContentPart));
    for (final e in dividers.evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      expect(r.left, group.left);
      expect(r.right, group.right);
    }
    // Ordered: content, divider, row, divider, row.
    final rows = find.byType(ActionRow);
    expect(tester.getRect(dividers.first).top, tester.getRect(find.byType(GroupedContentPart)).bottom);
    expect(tester.getRect(rows.first).top, tester.getRect(dividers.first).bottom);
    expect(tester.getRect(rows.last).top, tester.getRect(dividers.last).bottom);
  });

  testWidgets('the group looks like a GroupedList: surface, radius-lg, shadow-1; heading label in ink-muted',
      (tester) async {
    await _pump(tester, _agents());
    final c = tester.element(find.byType(GroupedSection)).colors;
    final box = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(GroupedSection), matching: find.byType(DecoratedBox)).first)
        .decoration as BoxDecoration;
    expect(box.color, c.surface);
    expect(box.borderRadius, MyDataRadii.lg(kiwiLook));
    expect(box.boxShadow, tester.element(find.byType(GroupedSection)).shadows.shadow1);
    expect(box.border, isNull);
    final heading = tester.widget<Text>(find.text('Agents'));
    expect(heading.style!.fontSize, MyDataType.label.fontSize);
    expect(heading.style!.color, c.inkMuted);
  });

  testWidgets('the heading is a semantics header', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _agents());
    expect(tester.getSemantics(find.text('Agents')), matchesSemantics(label: 'Agents', isHeader: true));
    handle.dispose();
  });

  testWidgets("a control's visible name is not read twice: the control carries it", (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _appearance());
    expect(find.bySemanticsLabel('Mode'), findsOneWidget);
    expect(find.bySemanticsLabel('Theme'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('content part: space-5 padding; controls stacked space-5 apart at their own width, named above',
      (tester) async {
    await _pump(tester, _appearance());
    final c = tester.element(find.byType(GroupedSection)).colors;
    final part = tester.getRect(find.byType(GroupedContentPart));
    final stack = tester.getRect(find.byType(GroupedStack));
    expect(stack.left - part.left, MyDataSpace.s5);
    expect(stack.top - part.top, MyDataSpace.s5);
    expect(part.bottom - stack.bottom, MyDataSpace.s5);

    final theme = tester.getRect(find.widgetWithText(GroupedControl, 'Theme'));
    final mode = tester.getRect(find.widgetWithText(GroupedControl, 'Mode'));
    final sample = tester.getRect(find.byType(ThemeSample));
    expect(mode.top - theme.bottom, GroupedStack.gap(kiwiLook));
    expect(sample.top - mode.bottom, GroupedStack.gap(kiwiLook));
    // Start-aligned, each at its own width: the mode control is narrower than the part.
    expect(mode.left, stack.left);
    expect(sample.left, stack.left);
    expect(tester.getSize(find.byType(SegmentedControl<_Mode>)).width, lessThan(stack.width));

    final label = tester.widget<Text>(find.text('Mode'));
    expect(label.style!.fontSize, MyDataType.label.fontSize);
    expect(label.style!.fontWeight, MyDataType.label.fontWeight);
    expect(label.style!.color, c.ink);
    expect(
      tester.getTopLeft(find.byType(SegmentedControl<_Mode>)).dy - tester.getBottomLeft(find.text('Mode')).dy,
      GroupedControl.labelGap(kiwiLook),
    );
  });

  testWidgets('a row in a section keeps the group corners for its hover fill', (tester) async {
    await _pump(tester, _appearance());
    final pressable = tester.widget<Pressable>(
      find.descendant(of: find.byType(GroupedRow), matching: find.byType(Pressable)),
    );
    expect(pressable.borderRadius, const BorderRadius.vertical(bottom: Radius.circular(MyDataRadius.lg)));
  });

  test('at most three tile tones across its rows and action rows', () {
    GroupedRow row(MyDataTone tone) => GroupedRow(icon: MyDataIcon.clear, tone: tone, title: tone.name);
    expect(
      () => GroupedSection(
        heading: 'Too many',
        parts: [
          row(MyDataTone.accent),
          row(MyDataTone.info),
          row(MyDataTone.warning),
          ActionRow(icon: MyDataIcon.key, tone: MyDataTone.success, title: 'Agent'),
        ],
      ),
      throwsAssertionError,
    );
    // The untinted tile is no colour (ImportFlow's summary: accent, info, warning, and neutral rows).
    GroupedSection(
      heading: 'Summary',
      parts: [row(MyDataTone.accent), row(MyDataTone.info), row(MyDataTone.warning), row(MyDataTone.neutral)],
    );
    // Rows without icons and content parts do not count.
    GroupedSection(
      heading: 'Fine',
      parts: [
        row(MyDataTone.accent),
        row(MyDataTone.info),
        ActionRow(icon: MyDataIcon.key, title: 'Agent'),
        ActionRow(title: 'No tile', tone: MyDataTone.danger),
        const GroupedRow(title: 'No tile', tone: MyDataTone.success),
        const GroupedContentPart(child: SizedBox()),
      ],
    );
  });

  testWidgets('without a heading: the group alone, as a GroupedList may be', (tester) async {
    await tester.pumpWidget(themedFrame(
      themeMatrix.first,
      SizedBox(
        width: 480,
        child: GroupedSection(parts: const [
          GroupedRow(title: '3 updated'),
          GroupedContentPart(child: Text('A note')),
        ]),
      ),
    ));
    expect(find.text('3 updated'), findsOneWidget);
    expect(find.text('A note'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2), reason: 'no heading above the group');
  });
}
