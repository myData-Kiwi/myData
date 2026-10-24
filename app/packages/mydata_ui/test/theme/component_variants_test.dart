// The component variants (design/themes/ARCHITECTURE.md 3.2 and 5, phase 3): one golden per value of each
// `components` key, in light and dark, on a specimen of the shared widgets that draw it. Each look is Kiwi
// with that one value changed, so the golden shows what the variant does and nothing else.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';
import 'package:mydata_ui/src/widgets/toggle_target.dart' show InsetRingPainter;

import 'designed_themes.dart';
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

/// Three outlined lists of one letter's group, the selected row first, in the middle and last: the
/// selection's ring must show on all four sides, never under the list's outline.
class OutlinedListSelectionSpecimen extends StatelessWidget {
  const OutlinedListSelectionSpecimen({super.key});

  static final people = [
    for (final n in ['Ava Fictional', 'Amy Example', 'Ann Sample'])
      ContactListEntry(id: n, name: n, givenName: n.split(' ').first, familyName: n.split(' ').last),
  ];

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, p) in people.indexed) ...[
          if (i > 0) SizedBox(width: context.space(4)),
          Expanded(child: ContactList(contacts: people, selectedId: p.id, onOpen: (_) {}, showSearch: false)),
        ],
      ]);
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

/// The approval card, as myAssistant shows it in a phone's column.
class PhoneApprovalSpecimen extends StatelessWidget {
  const PhoneApprovalSpecimen({super.key});

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.topCenter,
        child: ApprovalCard(
          question: 'Send this email?',
          arguments: [('To', 'ava@example.org'), ('Subject', 'Train on Friday')],
          approveLabel: 'Approve and send',
          decidedLabel: 'Sent',
          onApprove: noop,
          onEdit: noop,
          onReject: noop,
        ),
      );
}

/// A contact list over a grouped list, in one column as a phone shows them.
class PhoneListSpecimen extends StatelessWidget {
  const PhoneListSpecimen({super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 380,
            child: ContactList(contacts: SelectionSpecimen.people, selectedId: null, onOpen: (_) {}, showSearch: false)),
        SizedBox(height: context.space(4)),
        GroupedList(heading: 'Phone', rows: const [
          GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
          GroupedRow(title: 'Open in myContacts', trailing: GroupedChevron(), onPressed: noop),
        ]),
      ]);
}

/// Tabs and segmented controls too wide for a phone's row.
class PhoneTabsSpecimen extends StatelessWidget {
  const PhoneTabsSpecimen({super.key});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MyDataTabs(
            tabs: const ['General', 'Accounts', 'Privacy', 'Devices', 'Advanced'], current: 3, onChanged: (_) {}),
        SizedBox(height: context.space(4)),
        SegmentedControl<int>(segments: const [(0, 'Day'), (1, 'Week'), (2, 'Month')], selected: 2, onChanged: (_) {}),
        SizedBox(height: context.space(4)),
        SegmentedControl<int>(
            segments: const [(0, 'Light'), (1, 'Dark'), (2, 'Match system')], selected: 0, onChanged: (_) {}),
      ]);
}

void main() {
  group('buttons', () {
    for (final key in ['button.primary', 'button.secondary', 'button.plain', 'button.shape']) {
      variantGoldens(key, (focus) => ButtonSpecimen(focus: focus), size: const Size(560, 150));
    }

    test('an underlined plain button underlines Cancel and Revoke alike; a text one neither', () {
      for (final (plain, underlined) in [('text', false), ('underline', true)]) {
        final look = ThemeLibrary.look(kiwiWith(component('button.plain', plain)), brightness: Brightness.light);
        expect(ButtonPaint.of(look, ButtonVariant.plain).underline, underlined, reason: plain);
        expect(ButtonPaint.of(look, ButtonVariant.plainDanger).underline, underlined, reason: plain);
      }
      for (final id in ['mydata.high-contrast', 'mydata.e-ink', 'mydata.large']) {
        expect(designedLook(id, Brightness.light).variants.plain, PlainStyle.underline, reason: id);
      }
    });

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

    test('near red, no label but a destructive one is in the accent', () {
      for (final secondary in componentValues['button.secondary']!) {
        for (final b in Brightness.values) {
          final look =
              ThemeLibrary.look(kiwiWith(all([nearRedAccent, component('button.secondary', secondary)])), brightness: b);
          for (final v in [ButtonVariant.plain, ButtonVariant.tonal]) {
            expect(ButtonPaint.of(look, v).foreground, look.colors.ink, reason: '$secondary ${b.name} $v');
          }
          expect(ButtonPaint.of(look, ButtonVariant.plainDanger).foreground, look.colors.danger);
        }
      }
    });

    // The full specimen in the designed Sticker (Rose, a pink accent beside danger's red; not within 25°).
    for (final b in Brightness.values) {
      testWidgets('variant golden: buttons in sticker rose, ${b.name}', (tester) async {
        debugDisableShadows = false;
        try {
          final focus = FocusNode();
          addTearDown(focus.dispose);
          await pumpVariant(tester, designedTheme('mydata.sticker'), b, ButtonSpecimen(focus: focus),
              size: const Size(620, 170), focus: focus);
          expect(tester.takeException(), isNull);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.buttons-sticker.${b.name}.png'));
        } finally {
          debugDisableShadows = true;
        }
      });
    }

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

    // The designed Sticker (brutal, a hard 4px drop that collapses, 2px edge outlines) and a bevel elevation:
    // Approve stays filled with no drop, no bevel and a 1px line-strong outline at most.
    for (final b in Brightness.values) {
      testWidgets('variant golden: approval in sticker, ${b.name}', (tester) async {
        debugDisableShadows = false;
        try {
          await pumpVariant(tester, designedTheme('mydata.sticker'), b, card(), size: const Size(520, 260));
          expect(tester.takeException(), isNull);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.approval-sticker.${b.name}.png'));
        } finally {
          debugDisableShadows = true;
        }
      });
    }
    variantGoldens('button.primary', (_) => card(),
        size: const Size(520, 260),
        focused: false,
        values: ['bevel'],
        name: 'approval-bevel-elevation',
        also: all([
          styleGroup('elevation', {'style': 'bevel', 'strength': 1, 'offset': 2, 'press': 'collapse'}),
          styleGroup('borders', {'controls': true, 'width': 2, 'colour': 'edge'}),
        ]));
    // Near red: Approve in ink, and Edit and Reject in ink too, so only a destructive action is red.
    variantGoldens('button.primary', (_) => card(),
        size: const Size(520, 260), focused: false, values: ['filled'], name: 'approval-near-red', also: nearRedAccent);

    test('Approve is filled or outlined, never brutal, bevelled, a push button or on a drop', () {
      final elevations = <String, Map<String, Object?>>{
        'soft': {'style': 'soft', 'strength': 0.5},
        'hard': {'style': 'hard', 'strength': 1, 'offset': 4, 'press': 'collapse'},
        'offset': {'style': 'offset', 'strength': 1, 'offset': 3},
        'bevel': {'style': 'bevel', 'strength': 1, 'offset': 2},
        'glow': {'style': 'glow', 'strength': 1},
      };
      for (final value in componentValues['button.primary']!) {
        for (final e in elevations.entries) {
          for (final outlined in [false, true]) {
            final look = ThemeLibrary.look(
                kiwiWith(all([
                  component('button.primary', value),
                  styleGroup('elevation', e.value),
                  styleGroup('borders', {'controls': outlined, 'width': 2, 'colour': 'edge'}),
                ])),
                brightness: Brightness.light);
            final approve = ButtonPaint.of(look, ButtonVariant.filled, approval: true);
            final why = '$value ${e.key} outlined: $outlined';
            expect(approve.bevel, isNull, reason: why);
            expect(approve.collapses, isFalse, reason: why);
            expect(approve.shadows.where((s) => s.blurRadius == 0 || s.offset != Offset.zero), isEmpty, reason: why);
            if (value == 'outline') {
              expect((approve.fill, approve.side?.width), (null, ButtonPaint.outlineWidth), reason: why);
            } else {
              expect(approve.fill, look.colors.accent, reason: why);
              expect(approve.side, outlined ? BorderSide(color: look.colors.lineStrong) : null, reason: why);
            }
          }
        }
      }
    });

    test("Sticker's Approve has no drop and no edge outline", () {
      final look = designedLook('mydata.sticker', Brightness.light);
      expect(ButtonPaint.of(look, ButtonVariant.filled).shadows, isNotEmpty);
      final approve = ButtonPaint.of(look, ButtonVariant.filled, approval: true);
      expect(approve.shadows, isEmpty);
      expect(approve.side, BorderSide(color: look.colors.lineStrong));
    });
  });

  group('selection', () {
    variantGoldens('selection', (focus) => SelectionSpecimen(focus: focus), size: const Size(1100, 340));
    // An outline (Large's) and a tint's ring in a bordered list with 2 px outlines: the selected row's ring
    // shows on all four sides, on the group's first, middle and last row.
    variantGoldens('selection', (_) => const OutlinedListSelectionSpecimen(),
        size: const Size(1000, 300),
        focused: false,
        values: ['outline', 'tint'],
        name: 'bordered',
        also: all([
          component('list', 'bordered'),
          styleGroup('borders', {'controls': true, 'cards': true, 'width': 2, 'colour': 'line-strong'}),
        ]));

    testWidgets("a selected row's ring in a bordered list is drawn over the list's outline", (tester) async {
      await pumpVariant(
          tester,
          kiwiWith(all([
            component('list', 'bordered'),
            component('selection', 'outline'),
            styleGroup('borders', {'width': 2, 'colour': 'line-strong'}),
          ])),
          Brightness.light,
          const OutlinedListSelectionSpecimen(),
          size: const Size(1000, 300));
      final c = tester.element(find.byType(ContactList).first).colors;
      for (final (i, name) in ['Ava Fictional', 'Amy Example', 'Ann Sample'].indexed) {
        // Innermost first: the list's outline is painted inside the selection's ring.
        final row = find.descendant(of: find.byType(ContactList).at(i), matching: find.text(name));
        final painters = [
          for (final w in tester.widgetList<CustomPaint>(find.ancestor(of: row, matching: find.byType(CustomPaint))))
            if (w.foregroundPainter case final InsetRingPainter p) p,
        ];
        final ring = painters.indexWhere((p) => p.color == c.selection);
        final outline = painters.indexWhere((p) => p.color == c.lineStrong);
        expect(ring, isNot(-1), reason: name);
        expect(outline, isNot(-1), reason: name);
        expect(ring, greaterThan(outline), reason: name);
      }
    });
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

  testWidgets("a table contact list starts its zebra stripes again in each letter's group", (tester) async {
    final people = [
      for (final n in ['Ava Fictional', 'Amy Example', 'Ann Sample', 'Ben Sample'])
        ContactListEntry(id: n, name: n, givenName: n.split(' ').first, familyName: n.split(' ').last),
    ];
    await pumpVariant(tester, kiwiWith(component('list', 'table')), Brightness.light,
        ContactList(contacts: people, selectedId: null, onOpen: (_) {}, showSearch: false),
        size: const Size(400, 500));
    final colors = tester.element(find.byType(ContactList)).colors;
    // A palette that gives no stripe gets one halfway to `surface-sunken`, so the header band stays the
    // stronger.
    expect(colors.stripe, isNot(colors.surfaceSunken));
    bool striped(String name) => find
        .ancestor(
            of: find.text(name),
            matching: find.byWidgetPredicate(
                (w) => w is DecoratedBox && w.decoration.isBox && (w.decoration.box).color == colors.stripe))
        .evaluate()
        .isNotEmpty;
    expect([for (final p in people) striped(p.name)], [false, true, false, false]);
  });

  group('inputs', () {
    variantGoldens('inputs', (focus) => InputSpecimen(focus: focus), size: const Size(640, 260));

    testWidgets("an underlined field's ring clears its text; a boxed one's stays 2px out", (tester) async {
      for (final (style, clear) in [('underlined', 8.0), ('outlined', 0.0), ('filled', 0.0)]) {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await pumpVariant(tester, kiwiWith(component('inputs', style)), Brightness.light, InputSpecimen(focus: focus),
            size: const Size(640, 260), focus: focus);
        final ring = tester.widget<FocusRing>(find.ancestor(of: find.text('Kitchen Mac'), matching: find.byType(FocusRing)).first);
        expect((ring.visible, ring.clearance), (true, clear), reason: style);
      }
    });
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

  // Boxed tabs too wide for their row: each run is its own group, outer corners rounded, straight dividers.
  variantGoldens(
      'tabs',
      (_) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 250,
              child: MyDataTabs(
                  tabs: const ['General', 'Accounts', 'Privacy', 'Devices'], current: 2, onChanged: (_) {}),
            ),
          ),
      size: const Size(300, 150),
      focused: false,
      values: ['boxed'],
      name: 'wrapped');

  group('the month', () {
    const size = Size(900, 840);
    variantGoldens('month', (focus) => MonthSpecimen(focus: focus), size: size);
    variantGoldens('today', (focus) => MonthSpecimen(focus: focus), size: size, focused: false);
    variantGoldens('data-colours', (focus) => MonthSpecimen(focus: focus), size: size, focused: false);
    // The selected day in each selection style, focused by keyboard.
    variantGoldens('selection', (focus) => MonthSpecimen(focus: focus), size: size, name: 'month');

    testWidgets("swatches on today's inverse cell and a filled selected day take the edge rule against that fill",
        (tester) async {
      await pumpVariant(tester, kiwiWith(all([component('today', 'inverse'), component('selection', 'solid')])),
          Brightness.dark, const MonthSpecimen(),
          size: const Size(900, 840));
      List<DataGround> groundsBeside(String title) => [
            for (final e in find
                .ancestor(of: find.text(title), matching: find.byType(Row))
                .first
                .evaluate()) ...[
              for (final b in find.descendant(of: find.byWidget(e.widget), matching: find.byType(DataBar)).evaluate())
                (b.widget as DataBar).ground,
            ],
          ];
      expect(groundsBeside('Dentist'), [DataGround.ink]);
      expect(groundsBeside('Dinner'), [DataGround.selection]);
      expect(groundsBeside('Market'), [DataGround.surface]);
      // Dentist's cyan on dark Kiwi's near-white ink is under 3:1, so it gets the edge: measured on the
      // cell's ink, not on the `bg` its text takes there.
      final look = tester.element(find.byType(MonthGrid)).look;
      final dentist = tester.widget<DataBar>(
          find.descendant(of: find.ancestor(of: find.text('Dentist'), matching: find.byType(Row)).first, matching: find.byType(DataBar)));
      expect(dentist.groundColour, look.colors.ink);
      expect(dataColourNeedsEdge(parseDataColour('#1BADF8')!, look.colors.ink), isTrue);
    });

    test('a pattern gives every default calendar colour its own mark', () {
      // The schema's data-* roles in Kiwi's palette, and the usual calendar colours.
      const kiwi = {
        'red': '#D34730', 'orange': '#EA700F', 'yellow': '#E7BD1B', 'green': '#36A462',
        'blue': '#159CE2', 'purple': '#8B51E1', 'brown': '#8A6859', 'grey': '#939393',
      };
      const calendars = {
        'red': '#FF2968', 'orange': '#FF9500', 'yellow': '#FFCC00', 'green': '#63DA38',
        'blue': '#1BADF8', 'purple': '#CC73E1', 'brown': '#A2845E',
      };
      for (final set in [kiwi, calendars]) {
        final marks = <DataPattern, String>{};
        for (final e in set.entries) {
          final colour = parseDataColour(e.value)!;
          expect(DataPattern.familyOf(colour), e.key, reason: e.value);
          final mark = DataPattern.of(colour);
          expect(marks[mark], isNull, reason: '${e.key} has the same mark as ${marks[mark]}');
          marks[mark] = e.key;
        }
      }
    });

    testWidgets("a month cell shows each event's calendar initial when calendars are patterns", (tester) async {
      await pumpVariant(tester, kiwiWith(component('data-colours', 'pattern')), Brightness.light, const MonthSpecimen(),
          size: const Size(900, 840));
      for (final initial in ['P', 'C', 'W', 'F', 'H']) {
        expect(find.text(initial), findsWidgets, reason: initial);
      }
      await pumpVariant(tester, kiwiWith(component('data-colours', 'colour')), Brightness.light, const MonthSpecimen(),
          size: const Size(900, 840));
      expect(find.text('P'), findsNothing);
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

    testWidgets('sidebar tabs read each section as the sidebar does: "Review, 4", not "Review 4"', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpVariant(tester, kiwiWith(component('sidebar', 'tabs')), Brightness.light, frame(FocusNode()),
          size: const Size(1100, 360));
      expect(find.bySemanticsLabel('Review, 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Review 4'), findsNothing);
      semantics.dispose();
    });

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

  group('window grain', () {
    // Paperback's ground: one tile of grain repeated, the same at every window size.
    final grain = styleGroup('materials', {
      'window': {
        'kind': 'pattern',
        'pattern': {'kind': 'grain', 'opacity': 0.3, 'colour': 'ink'},
      },
    });
    for (final b in Brightness.values) {
      testWidgets('variant golden: window grain, ${b.name}', (tester) async {
        await pumpVariant(tester, kiwiWith(grain), b, const WindowGround(child: SizedBox.expand()),
            size: const Size(300, 200));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.window-grain.${b.name}.png'));
      });
    }

    test('the grain tile is made once per colour, whatever the window size', () {
      const colour = Color(0x0A000000);
      final tile = PatternPainter.grainImage(colour);
      expect((tile.width, tile.height), (PatternPainter.grainTile, PatternPainter.grainTile));
      expect(PatternPainter.grainImage(colour), same(tile));
    });
  });

  // Frosted's gradient and Paperback's grain in the Mac window: behind the content column (not the sidebar),
  // with Frosted's floating toolbar in its blur material, and beside the window's buttons with no sidebar.
  group("a drawn theme's material in the Mac window", () {
    for (final (id, controls) in [('mydata.frosted', false), ('mydata.paperback', false), ('mydata.frosted', true)]) {
      for (final b in Brightness.values) {
        final name = '${id.substring('mydata.'.length)}${controls ? '-window-controls' : ''}';
        testWidgets('variant golden: mac window $name, ${b.name}', (tester) async {
          debugDisableShadows = false;
          tester.view.physicalSize = const Size(900, 320);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final look = designedLook(id, b, platform: TargetPlatform.macOS);
          final pane = MacPane(
            toolbar: MacToolbar(
              title: 'Contacts',
              windowControls: controls,
              trailing: [MacToolbarButton(icon: MyDataIcon.add, label: 'New contact', onPressed: noop)],
            ),
            child: Builder(
              builder: (context) => Padding(
                padding: EdgeInsets.all(context.space(4)),
                child: GroupedList(heading: 'Phone', rows: const [
                  GroupedRow(icon: MyDataIcon.call, title: 'Mobile', subtitle: '+44 7700 900123'),
                  GroupedRow(title: 'Open in myContacts', trailing: GroupedChevron(), onPressed: noop),
                ]),
              ),
            ),
          );
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: MacTheme.drawn(look),
            home: Material(
              color: look.colors.bg,
              child: controls
                  ? MacContentGround(child: pane)
                  : MacAppFrame(
                      sections: const [
                        AppSection(icon: MyDataIcon.people, label: 'Contacts'),
                        AppSection(icon: MyDataIcon.review, label: 'Review', count: 4),
                      ],
                      current: 0,
                      onSelect: (_) {},
                      connection: const AppConnection.connected(),
                      child: pane,
                    ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(MacContentGround.drawsMaterial(look), isTrue);
          try {
            await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/variant.mac-window-$name.${b.name}.png'));
          } finally {
            debugDisableShadows = true;
          }
        });
      }
    }

    testWidgets("a floating toolbar's capsule makes room for a theme's taller title and subtitle", (tester) async {
      tester.view.physicalSize = const Size(900, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Sticker's heading and caption are taller than the capsule's usual height inside the band.
      final look = designedLook('mydata.sticker', Brightness.light, platform: TargetPlatform.macOS);
      expect(look.variants.toolbar, ToolbarStyle.floating);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MacTheme.drawn(look),
        home: const Material(
          child: MacPane(
            toolbar: MacToolbar(title: 'Email Rishita the time of my dentist appointment', subtitle: 'Demo data'),
            child: SizedBox.expand(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(tester.getSize(find.byType(MacToolbar)).height, MyDataMacSize.toolbarHeight);
    });

    test("a solid window keeps the Mac's content background; System always does", () {
      expect(MacContentGround.drawsMaterial(designedLook('mydata.kiwi', Brightness.light, platform: TargetPlatform.macOS)),
          isFalse);
      expect(MacContentGround.drawsMaterial(designedLook('mydata.sticker', Brightness.dark, platform: TargetPlatform.macOS)),
          isFalse);
    });
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

  // Every value of the variants that change most at a phone's width, light only: tabs and buttons wrapping,
  // a brutal drop in a wrapping row, the approval card, lists in a column, the compact month, avatars.
  group('at phone width', () {
    void phone(String key, Widget Function(FocusNode focus) build, {bool focused = false, String? name}) =>
        variantGoldens(key, build,
            size: phoneSize, focused: focused, modes: const [Brightness.light], minTarget: 44, name: name == null ? 'phone' : '$name-phone');
    for (final key in ['button.primary', 'button.secondary', 'button.shape']) {
      phone(key, (focus) => ButtonSpecimen(focus: focus), focused: true);
    }
    phone('button.primary', (_) => const PhoneApprovalSpecimen(), name: 'approval');
    phone('list', (_) => const PhoneListSpecimen());
    phone('tabs', (_) => const PhoneTabsSpecimen());
    phone('month', (focus) => MonthSpecimen(focus: focus), focused: true);
    phone('avatar', (_) => const AvatarSpecimen());
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
