// The Mac frame's grouped forms (lib/src/mac/mac_form.dart): what the controls do.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydata_ui/mydata_ui.dart';

Widget frame(Widget child) => MaterialApp(
  theme: MacTheme.data('kiwi', Brightness.light, MyDataMacColors.light),
  home: Scaffold(body: MacForm(children: [MacFormSection(heading: 'Group', footer: 'A note.', rows: [child])])),
);

void main() {
  testWidgets('a switch flips on a click and is announced as toggled', (tester) async {
    var value = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacFormRow(
            title: 'Assistant',
            trailing: [MacSwitch(value: value, onChanged: (v) => setState(() => value = v), semanticLabel: 'Assistant')],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MacSwitch));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Assistant').last).flagsCollection.isToggled, isNotNull);
  });

  testWidgets('a disabled switch does nothing', (tester) async {
    await tester.pumpWidget(frame(const MacSwitch(value: false, onChanged: null)));
    await tester.tap(find.byType(MacSwitch));
    await tester.pumpAndSettle();
  });

  testWidgets('a segmented control changes on a click and with the arrow keys', (tester) async {
    var mode = 'light';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacSegmented<String>(
            segments: const [('light', 'Light'), ('dark', 'Dark'), ('system', 'Match system')],
            selected: mode,
            onChanged: (m) => setState(() => mode = m),
            semanticLabel: 'Appearance',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(mode, 'dark');
    Focus.of(tester.element(find.text('Dark'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(mode, 'system');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(mode, 'system', reason: 'the last segment stays');
  });

  testWidgets('a disclosure shows its content only while open', (tester) async {
    var open = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => frame(
          MacDisclosure(
            title: 'Details',
            open: open,
            onToggle: () => setState(() => open = !open),
            child: const Text('Host version'),
          ),
        ),
      ),
    );
    expect(find.text('Host version'), findsNothing);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Host version'), findsOneWidget);
  });

  testWidgets('a text field takes typing and names itself', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(frame(MacEditField(controller: controller, label: 'Name', placeholder: 'For example')));
    await tester.enterText(find.byType(TextField), 'Claude');
    expect(controller.text, 'Claude');
    expect(find.bySemanticsLabel(RegExp('^Name')), findsWidgets);
  });
}
