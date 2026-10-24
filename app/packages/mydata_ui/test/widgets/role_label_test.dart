// Upper case on the label and caption roles (design/themes/ARCHITECTURE.md 2.3): under a theme that sets
// them so, every widget's own labels are in upper case, names keep their own case, and sentences and the
// user's data never change case.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_testing/mydata_testing.dart';
import 'package:mydata_ui/mydata_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child, {MyDataLook? look}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MyDataTheme.fromLook(look ?? upperCaseLook(Brightness.light)),
    home: Material(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
  ));
  await tester.pump();
}

void main() {
  testWidgets('RoleLabel: upper case where the role is, its own case for a name; readers hear it as written',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const Column(children: [
        RoleLabel('Email'),
        RoleLabel('myAssistant', holdsName: true),
        RoleLabel('Mon', role: MyDataTypeRole.caption),
        RoleLabel('After merging', role: MyDataTypeRole.heading),
      ]),
    );
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    expect(find.text('myAssistant'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('After merging'), findsOneWidget, reason: 'heading never changes case');
    handle.dispose();
  });

  testWidgets('Kiwi keeps every label as written', (tester) async {
    await _pump(tester, const RoleLabel('Email'), look: kiwiLook);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets("every widget's own label follows the theme's case; help, errors and data keep theirs",
      (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await _pump(
      tester,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MyDataTextField(label: 'Device name', controller: c, help: 'Shown to your other devices.'),
        TokenField(label: 'Groups', values: const [], onChanged: (_) {}),
        SizedBox(
          width: 300,
          child: MyDataSelect<String>(
            label: 'Calendar',
            items: const [SelectItem.dotted(value: 'home', title: 'Home', dot: null)],
            value: 'home',
            onChanged: (_) {},
          ),
        ),
        TimePicker(label: 'Starts', semanticLabel: 'Start time', value: const TimeOfDay(hour: 9, minute: 30),
            use24HourFormat: true, onChanged: (_) {}),
        ColourPicker(value: const Color(0xFF3366CC), onChanged: (_) {}),
        const FormRow(label: 'Birthday', error: 'That date is not real.', child: SizedBox(height: 10)),
        const FormRow(label: 'Ava Fictional', holdsName: true, child: SizedBox(height: 10)),
        const FormGroupHeading('Phone'),
        const MonoWell(label: 'Token', value: 'abc'),
        GroupedList(heading: 'Appearance', rows: const [GroupedRow(title: 'Theme')]),
        GroupedList(heading: 'iCloud, ava@example.org', headingHoldsName: true, rows: const [GroupedRow(title: 'Home')]),
        GroupedSection(heading: 'Apps', parts: const [
          GroupedContentPart(
            child: GroupedStack(children: [
              GroupedControl(label: 'Mode', child: SizedBox(height: 10)),
              GroupedControl(label: 'myAssistant', holdsName: true, child: SizedBox(height: 10)),
            ]),
          ),
        ]),
        const MyDataBadge('Connected', tone: MyDataTone.success),
        const FieldRow(kind: FieldKind.phone, label: 'Mobile', value: '+44 7700 900123'),
      ]),
    );
    for (final upper in [
      'DEVICE NAME', 'GROUPS', 'CALENDAR', 'STARTS', ColourPicker.defaultLabel.toUpperCase(), 'BIRTHDAY', 'PHONE',
      'TOKEN', 'APPEARANCE', 'APPS', 'MODE', 'CONNECTED',
    ]) {
      expect(find.text(upper), findsOneWidget, reason: upper);
    }
    for (final kept in [
      'Shown to your other devices.', 'That date is not real.', 'Ava Fictional', 'iCloud, ava@example.org',
      'myAssistant', 'Home', 'Theme',
      // The source's own field label is data, shown exactly as written.
      'Mobile',
    ]) {
      expect(find.text(kept), findsWidgets, reason: kept);
    }
  });

  testWidgets('tab labels under an icon and the month grid\'s weekdays follow the theme\'s case', (tester) async {
    await _pump(
      tester,
      Column(children: [
        SizedBox(
          width: 400,
          child: FloatingBar(current: 0, items: [
            FloatingBarItem(label: 'Library', icon: MyDataIcon.photo, onPressed: () {}),
            FloatingBarItem(label: 'People', icon: MyDataIcon.people, onPressed: () {}),
          ]),
        ),
        SizedBox(
          width: 700,
          child: MonthGrid(
            month: DateTime(2026, 3),
            today: DateTime(2026, 3, 18),
            selected: DateTime(2026, 3, 18),
            onSelected: (_) {},
            onMonthChanged: (_) {},
          ),
        ),
      ]),
    );
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('Mon'), findsNothing);
  });
}
