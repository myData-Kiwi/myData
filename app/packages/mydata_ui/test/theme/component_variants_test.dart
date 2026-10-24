// The component variants (design/themes/ARCHITECTURE.md 3.2 and 5, phase 3): one golden per value of each
// `components` key, in light and dark, on a specimen of the shared widgets that draw it. Each look is Kiwi
// with that one value changed, so the golden shows what the variant does and nothing else.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'variant_harness.dart';

/// Every role of button, the primary focused by keyboard, then the disabled ones.
class ButtonSpecimen extends StatelessWidget {
  const ButtonSpecimen({super.key, required this.focus});
  final FocusNode focus;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButtonRow(children: [
            Button(label: 'Approve and send', variant: ButtonVariant.filled, focusNode: focus, onPressed: noop),
            const Button(label: 'Edit', onPressed: noop),
            const Button(label: 'Cancel', variant: ButtonVariant.plain, onPressed: noop),
            const Button(label: 'Delete', variant: ButtonVariant.danger, onPressed: noop),
          ]),
          SizedBox(height: context.space(4)),
          const ButtonRow(children: [
            Button(label: 'Add a device', variant: ButtonVariant.filled, onPressed: null),
            Button(label: 'Rename', onPressed: null),
            Button(label: 'Revoke', variant: ButtonVariant.plainDanger, onPressed: noop),
          ]),
        ],
      );
}

/// A frame with its sidebar (the current section marked), a contact list with one selected row, and a grouped
/// list whose selected row has keyboard focus.
class SelectionSpecimen extends StatelessWidget {
  const SelectionSpecimen({super.key, required this.focus});
  final FocusNode focus;

  static final people = [
    ContactListEntry(id: 'a1', name: 'Ava Fictional', givenName: 'Ava', familyName: 'Fictional', caption: 'Example Labs'),
    ContactListEntry(id: 'a2', name: 'Ben Sample', givenName: 'Ben', familyName: 'Sample', caption: 'ben@example.org'),
    ContactListEntry(id: 'a3', name: 'Cleo Placeholder', givenName: 'Cleo', familyName: 'Placeholder'),
  ];

  @override
  Widget build(BuildContext context) => AppFrame(
        appName: 'myContacts',
        sections: const [
          AppSection(icon: MyDataIcon.people, label: 'Contacts'),
          AppSection(icon: MyDataIcon.review, label: 'Review', count: 4),
        ],
        current: 0,
        onSelect: (_) {},
        child: Padding(
          padding: EdgeInsets.all(context.space(4)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: ContactList(contacts: people, selectedId: 'a2', onOpen: (_) {}, showSearch: false)),
            SizedBox(width: context.space(4)),
            Expanded(
              child: GroupedList(heading: 'Calendars', rows: [
                const GroupedRow(icon: MyDataIcon.calendar, title: 'Home', subtitle: '12 events', onPressed: noop),
                GroupedRow(
                    icon: MyDataIcon.calendar,
                    title: 'Work',
                    subtitle: '48 events',
                    trailing: const GroupedValueChevron('Shown'),
                    selected: true,
                    focusNode: focus,
                    onPressed: noop),
                const GroupedRow(title: 'Holidays', trailing: GroupedBadge('Read only', tone: MyDataTone.neutral)),
              ]),
            ),
          ]),
        ),
      );
}

void main() {
  group('buttons', () {
    for (final key in ['button.primary', 'button.secondary', 'button.shape']) {
      variantGoldens(key, (focus) => ButtonSpecimen(focus: focus), size: const Size(560, 150));
    }

    // An accent near `danger`'s red: the primary is drawn in `ink`, so Approve never looks like Delete.
    variantGoldens('button.primary', (focus) => ButtonSpecimen(focus: focus),
        size: const Size(560, 150), values: ['filled', 'outline'], also: nearRedAccent, name: 'near-red');

    testWidgets('a primary near red is ink with its label in bg; danger stays red', (tester) async {
      await pumpVariant(tester, kiwiWith(nearRedAccent), Brightness.light, ButtonSpecimen(focus: FocusNode()));
      final look = tester.element(find.byType(ButtonSpecimen)).look;
      expect(look.accentNearDanger, isTrue);
      final primary = ButtonPaint.of(look, ButtonVariant.filled);
      expect(primary.fill, look.colors.ink);
      expect(primary.foreground, look.colors.bg);
      expect(ButtonPaint.of(look, ButtonVariant.danger).fill, look.colors.danger);
    });

    test('every primary looks like a button: a fill or an outline, never text alone', () {
      for (final value in componentValues['button.primary']!) {
        for (final b in Brightness.values) {
          final look = ThemeLibrary.look(kiwiWith(component('button.primary', value)), brightness: b);
          final p = ButtonPaint.of(look, ButtonVariant.filled);
          expect(p.fill != null || (p.side?.width ?? 0) >= 2, isTrue, reason: value);
        }
      }
    });
  });

  group('the approval card', () {
    Widget card() => ApprovalCard(
          question: 'Send this email?',
          arguments: const [('To', 'ava@example.org'), ('Subject', 'Train on Friday')],
          approveLabel: 'Approve and send',
          decidedLabel: 'Sent',
          onApprove: noop,
          onEdit: noop,
          onReject: noop,
        );

    // Its structure stays in every theme: a brutal, bevelled or push primary draws its Approve filled, and an
    // outline primary outlined; the card keeps its solid surface and line-strong edge.
    variantGoldens('button.primary', (_) => card(),
        size: const Size(520, 260), focused: false, values: ['outline', 'brutal'], name: 'approval');

    test('Approve is filled or outlined, never brutal, bevelled or a push button', () {
      for (final value in componentValues['button.primary']!) {
        final look = ThemeLibrary.look(kiwiWith(component('button.primary', value)), brightness: Brightness.light);
        final approve = ButtonPaint.of(look, ButtonVariant.filled, approval: true);
        final filled = ButtonPaint.of(
            ThemeLibrary.look(kiwiWith(component('button.primary', 'filled')), brightness: Brightness.light),
            ButtonVariant.filled);
        if (value == 'outline') {
          expect(approve.fill, isNull);
        } else {
          expect((approve.fill, approve.side, approve.collapses), (filled.fill, filled.side, false), reason: value);
          expect(approve.shadows, filled.shadows, reason: value);
        }
      }
    });
  });

  group('selection', () {
    variantGoldens('selection', (focus) => SelectionSpecimen(focus: focus), size: const Size(1100, 340));
    // A theme that outlines its controls marks a faint tint with an outline, not a bar.
    variantGoldens('selection', (focus) => SelectionSpecimen(focus: focus),
        size: const Size(1100, 340),
        values: ['tint'],
        name: 'outlined',
        also: styleGroup('borders', {'controls': true, 'cards': true, 'width': 2, 'colour': 'edge'}));

    test('a tint under 3:1 on surface is never colour alone: it draws a bar or an outline', () {
      final kiwi = ThemeLibrary.look(kiwiWith(component('selection', 'tint')), brightness: Brightness.light);
      expect(SelectionPaint.tintNeedsMark(kiwi.colors), isTrue);
      expect(SelectionPaint.of(kiwi).bar, kiwi.colors.selection);
      final outlined = ThemeLibrary.look(kiwiWith(all([component('selection', 'tint'), styleGroup('borders', {'controls': true})])),
          brightness: Brightness.light);
      expect(SelectionPaint.of(outlined).bar, isNull);
      expect(SelectionPaint.of(outlined).outline?.color, outlined.colors.selection);
    });

    test('every selection style marks the item by more than a faint fill', () {
      for (final value in componentValues['selection']!) {
        for (final b in Brightness.values) {
          final look = ThemeLibrary.look(kiwiWith(component('selection', value)), brightness: b);
          final p = SelectionPaint.of(look);
          final fillMarks = p.fill != null && SelectionPaint.contrastOf(p.fill!, look.colors.surface) >= 3;
          expect(fillMarks || p.bar != null || p.outline != null, isTrue, reason: '$value ${b.name}');
        }
      }
    });
  });
}
