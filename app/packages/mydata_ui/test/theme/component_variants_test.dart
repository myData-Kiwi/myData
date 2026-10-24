// The component variants (design/themes/ARCHITECTURE.md 3.2 and 5, phase 3): one golden per value of each
// `components` key, in light and dark, on a specimen of the shared widgets that draw it. Each look is Kiwi
// with that one value changed, so the golden shows what the variant does and nothing else.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A contact list, a multi-select list and a grouped list with a heading, in the theme's list style.
class ListSpecimen extends StatefulWidget {
  const ListSpecimen({super.key});

  @override
  State<ListSpecimen> createState() => _ListSpecimenState();
}

class _ListSpecimenState extends State<ListSpecimen> {
  final _rows = MultiSelectController<String>(rows: const ['a', 'b', 'c']);

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: ContactList(contacts: SelectionSpecimen.people, selectedId: null, onOpen: (_) {}, showSearch: false)),
        SizedBox(width: context.space(4)),
        Expanded(
          child: MultiSelectList<String>(
            controller: _rows,
            label: 'Devices',
            itemBuilder: (context, k) => Text('Device $k', style: context.typeScale.body.copyWith(color: context.colors.ink)),
            semanticLabelOf: (k) => 'Device $k',
            countLabel: (n) => '$n selected',
          ),
        ),
        SizedBox(width: context.space(4)),
        Expanded(
          child: GroupedList(heading: 'Phone', rows: const [
            GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
            GroupedRow(icon: MyDataIcon.cloud, title: 'iCloud', trailing: GroupedBadge('Connected', tone: MyDataTone.success)),
            GroupedRow(title: 'Open in myContacts', trailing: GroupedChevron(), onPressed: noop),
          ]),
        ),
      ]);
}

/// A text field with keyboard focus, one in error, a select and an empty field with a placeholder.
class InputSpecimen extends StatefulWidget {
  const InputSpecimen({super.key, required this.focus});
  final FocusNode focus;

  @override
  State<InputSpecimen> createState() => _InputSpecimenState();
}

class _InputSpecimenState extends State<InputSpecimen> {
  final _name = TextEditingController(text: 'Kitchen Mac');
  final _mail = TextEditingController(text: 'ava@example');
  final _empty = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _mail.dispose();
    _empty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: MyDataTextField(
                  label: 'Device name', controller: _name, focusNode: widget.focus, help: 'Shown to your other devices.')),
          SizedBox(width: context.space(4)),
          Expanded(child: MyDataTextField(label: 'Email', controller: _mail, error: 'Add the part after the @.')),
        ]),
        SizedBox(height: context.space(4)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: MyDataSelect<String>(
              label: 'Calendar',
              items: const [SelectItem(value: 'home', title: 'Home'), SelectItem(value: 'work', title: 'Work')],
              value: 'home',
              onChanged: (_) {},
            ),
          ),
          SizedBox(width: context.space(4)),
          Expanded(child: MyDataTextField(label: 'Notes', controller: _empty, placeholder: 'Add a note')),
        ]),
      ]);
}

/// Small avatars for four people, a large one, and a contact's header.
class AvatarSpecimen extends StatelessWidget {
  const AvatarSpecimen({super.key});

  static const names = ['Ava Fictional', 'Ben Sample', 'Cleo Placeholder', 'Dev Example'];

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (final n in names) ...[Avatar(name: n), SizedBox(width: context.space(2))],
          const Avatar(name: 'Ava Fictional', size: AvatarSize.large),
          SizedBox(width: context.space(2)),
          const Avatar(name: '+44 7700 900123'),
        ]),
        SizedBox(height: context.space(4)),
        ContactHeader(
          name: 'Ben Sample',
          jobTitle: 'Head of research',
          organisation: 'Example Labs',
          sourceLine: 'From iCloud, ben@example.org',
          avatar: const Avatar(name: 'Ben Sample', size: AvatarSize.large),
        ),
      ]);
}

/// October 2026 with today (the 13th) apart from the selected day (the 16th), events in four calendars.
class MonthSpecimen extends StatelessWidget {
  const MonthSpecimen({super.key, this.focus});
  final FocusNode? focus;

  static final events = <DateTime, List<MonthGridEvent>>{
    DateTime(2026, 10, 13): [
      MonthGridEvent(title: 'Dentist', calendarName: 'Personal', colour: parseDataColour('#1BADF8')),
      MonthGridEvent(title: 'Choir', calendarName: 'Choir', colour: parseDataColour('#CC73E1')),
    ],
    DateTime(2026, 10, 16): [
      MonthGridEvent(title: 'Train to Leeds', calendarName: 'Work', colour: parseDataColour('#FF2968'), allDay: true),
      MonthGridEvent(title: 'Dinner', calendarName: 'Family', colour: parseDataColour('#63DA38')),
    ],
    DateTime(2026, 10, 21): [
      MonthGridEvent(title: 'Quarter review', calendarName: 'Work', colour: parseDataColour('#FF2968')),
    ],
    DateTime(2026, 10, 24): [
      MonthGridEvent(title: 'Market', calendarName: 'Family', colour: parseDataColour('#63DA38')),
      MonthGridEvent(title: 'Bins', calendarName: 'Home', colour: parseDataColour('#FFCC00')),
    ],
  };

  @override
  Widget build(BuildContext context) => MonthGrid(
        month: DateTime(2026, 10),
        today: DateTime(2026, 10, 13),
        selected: DateTime(2026, 10, 16),
        firstDayOfWeek: DateTime.monday,
        events: events,
        focusNode: focus,
        onSelected: (_) {},
        onMonthChanged: (_) {},
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

  group('lists', () {
    variantGoldens('list', (_) => const ListSpecimen(), size: const Size(1000, 380), focused: false);
    // Rules and outlines in a theme whose borders are the edge colour, two wide.
    variantGoldens('list', (_) => const ListSpecimen(),
        size: const Size(1000, 380),
        focused: false,
        values: ['ruled', 'table'],
        name: 'edge',
        also: styleGroup('borders', {'colour': 'edge', 'width': 2}));
  });

  group('inputs', () {
    variantGoldens('inputs', (focus) => InputSpecimen(focus: focus), size: const Size(640, 260));
  });

  group('avatars', () {
    variantGoldens('avatar', (_) => const AvatarSpecimen(), size: const Size(640, 300), focused: false);

    test('a shape avatar is the same shape for the same name, and the four names show all three', () {
      expect(Avatar.shapeFor('Ava Fictional'), Avatar.shapeFor('Ava Fictional'));
      expect({for (final n in AvatarSpecimen.names) Avatar.shapeFor(n)}, AvatarShape.values.toSet());
    });
  });

  group('tabs', () {
    variantGoldens(
        'tabs',
        (focus) => Builder(
              builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MyDataTabs(tabs: const ['General', 'Accounts', 'Privacy'], current: 1, onChanged: (_) {}),
                SizedBox(height: context.space(4)),
                SegmentedControl<int>(
                    segments: const [(0, 'Day'), (1, 'Week'), (2, 'Month')], selected: 2, onChanged: (_) {}),
                SizedBox(height: context.space(4)),
                Focus(
                  focusNode: focus,
                  skipTraversal: true,
                  child: SegmentedControl<int>(
                      segments: const [(0, 'Light'), (1, 'Dark'), (2, 'Match system')], selected: 0, onChanged: (_) {}),
                ),
              ]),
            ),
        size: const Size(480, 220),
        focused: false,
        before: (tester) async {
          // Keyboard focus on the third control's selected segment, to show its ring.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        });
  });

  group('the month', () {
    const size = Size(900, 840);
    variantGoldens('month', (focus) => MonthSpecimen(focus: focus), size: size);
    variantGoldens('today', (focus) => MonthSpecimen(focus: focus), size: size, focused: false);
    variantGoldens('data-colours', (focus) => MonthSpecimen(focus: focus), size: size, focused: false);
    // The selected day in each selection style, focused by keyboard.
    variantGoldens('selection', (focus) => MonthSpecimen(focus: focus), size: size, name: 'month');

    test('a pattern tells eight hues apart by grey and hatch', () {
      final seen = {
        for (final hex in ['#FF2968', '#FF9500', '#FFCC00', '#63DA38', '#1BADF8', '#5856D6', '#CC73E1', '#A2845E'])
          () {
            final p = DataPattern.of(parseDataColour(hex)!);
            return (p.level, p.hatched);
          }(),
      };
      expect(seen.length, greaterThanOrEqualTo(6));
    });
  });

  group('the frame', () {
    Widget frame(FocusNode focus) => AppFrame(
          appName: 'myContacts',
          sections: const [
            AppSection(icon: MyDataIcon.people, label: 'Contacts'),
            AppSection(icon: MyDataIcon.trash, label: 'Deleted'),
            AppSection(icon: MyDataIcon.review, label: 'Review', count: 4),
          ],
          current: 0,
          onSelect: (_) {},
          child: const PageScaffold(title: 'Contacts', children: [Text('Ava Fictional')]),
        );
    // The branded frame over 1024px, in each sidebar style, on Frosted's gradient where it is translucent.
    variantGoldens('sidebar', frame, size: const Size(1100, 360), focused: false);
    variantGoldens('sidebar', frame,
        size: const Size(1100, 360),
        focused: false,
        values: ['column'],
        name: 'translucent-pattern',
        also: styleGroup('materials', {
          'window': {
            'kind': 'pattern',
            'pattern': {'kind': 'margin-rule', 'spacing': 24, 'opacity': 0.12, 'colour': 'accent'},
          },
          'sidebar': 'translucent',
        }));

    // A drawn theme in the Mac window: its source list and toolbar band in each toolbar style.
    for (final toolbar in componentValues['toolbar']!) {
      for (final b in Brightness.values) {
        testWidgets('variant golden: toolbar $toolbar in the Mac window, ${b.name}', (tester) async {
          debugDisableShadows = false;
          tester.view.physicalSize = const Size(900, 260);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final look = ThemeLibrary.look(kiwiWith(component('toolbar', toolbar)), brightness: b, platform: TargetPlatform.macOS);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: MacTheme.drawn(look),
            home: Builder(
              builder: (context) => Material(
                color: context.mac.contentBackground,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  MacSourceList(
                    sections: const [
                      AppSection(icon: MyDataIcon.people, label: 'Contacts'),
                      AppSection(icon: MyDataIcon.review, label: 'Review', count: 4),
                    ],
                    current: 0,
                    onSelect: (_) {},
                    connection: const AppConnection.connected(),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      MacToolbar(
                        title: 'Contacts',
                        trailing: [MacToolbarButton(icon: MyDataIcon.add, label: 'New contact', onPressed: noop)],
                      ),
                      const Expanded(child: SizedBox()),
                    ]),
                  ),
                ]),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          try {
            await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.toolbar-$toolbar.${b.name}.png'));
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }
  });

  group('icon tiles', () {
    for (final tiles in ['tinted', 'outlined', 'none']) {
      for (final b in Brightness.values) {
        testWidgets('variant golden: tiles $tiles, ${b.name}', (tester) async {
          await pumpVariant(
            tester,
            kiwiWith(styleGroup('icons', {'tiles': tiles})),
            b,
            GroupedList(heading: 'Sync', rows: const [
              GroupedRow(icon: MyDataIcon.mail, title: 'Mail', subtitle: '2 accounts'),
              GroupedRow(icon: MyDataIcon.calendar, tone: MyDataTone.info, title: 'Calendar', subtitle: '3 calendars'),
              GroupedRow(icon: MyDataIcon.photo, tone: MyDataTone.neutral, title: 'Photos'),
            ]),
            size: const Size(420, 260),
          );
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.tiles-$tiles.${b.name}.png'));
        });
      }
    }
  });

  // Pairs that meet in one widget (ARCHITECTURE.md 5, "pairwise golden sets for risky pairs").
  group('risky pairs', () {
    variantGoldens('selection', (focus) => SelectionSpecimen(focus: focus),
        size: const Size(1100, 340), values: ['inverse'], name: 'table', also: component('list', 'table'));
    variantGoldens('selection', (focus) => SelectionSpecimen(focus: focus),
        size: const Size(1100, 340), values: ['highlighter'], name: 'ruled', also: component('list', 'ruled'));
    variantGoldens('button.primary', (focus) => ButtonSpecimen(focus: focus),
        size: const Size(560, 150),
        values: ['brutal'],
        name: 'pressed-cut',
        also: all([component('button.shape', 'cut'), styleGroup('elevation', {'press': 'collapse'})]),
        before: (tester) async {
          await tester.startGesture(tester.getCenter(find.text('Delete')));
          await tester.pump();
        });
  });
}
